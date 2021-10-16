# QEMU 中的 seabios : fw_cfg

<!-- vim-markdown-toc GitLab -->

- [Why QEMU needs fw_cfg](#why-qemu-needs-fw_cfg)
- [Implement details](#implement-details)
  - [transfer method](#transfer-method)
    - [IO transfer](#io-transfer)
    - [DMA transfer](#dma-transfer)
    - [file](#file)
  - [ROM](#rom)
    - [ROM migration](#rom-migration)
  - [modify](#modify)
  - [FWCfgEntry callback](#fwcfgentry-callback)
- [kernel image 是如何被加载的](#kernel-image-是如何被加载的)
  - [QEMU's preparation](#qemus-preparation)
  - [Seabios](#seabios)
  - [linuxboot_dma.bin](#linuxboot_dmabin)

<!-- vim-markdown-toc -->

## Why QEMU needs fw_cfg
seabios 可以在裸机上，也可以在 QEMU 中运行，在 QEMU 中运行时，通过 fw_cfg 从 host 获取 guest 的各种配置或者 rom 会相当的方便。

比如在 ./hw/i386/fw_cfg.c 中 fw_cfg_arch_create 中，使用 fw_cfg 可以容易将 guest 的主板的 CPU 的数量通知给 guest。
```c
    fw_cfg_add_i16(fw_cfg, FW_CFG_MAX_CPUS, apic_id_limit);
```

## Implement details
fw_cfg 出现在两个文件中， hw/nvram/fw_cfg.c 和 hw/i386/fw_cfg.c，
前者是通用的实现，后者主要是为架构中添加一些细节。

- fw_cfg_arch_create
  - fw_cfg_init_io_dma(FW_CFG_IO_BASE, FW_CFG_IO_BASE + 4, &address_space_memory) : 第一参数是 IO, 第二个是 DMA
    - qdev_new(TYPE_FW_CFG_IO)
    - sysbus_realize_and_unref --> fw_cfg_io_realize
      - fw_cfg_file_slots_allocate : 初始化两个 FWCfgState::entries, 用于保存数据，其 key 就是事先定义好的宏，
      - 创建 fwcfg 和 fwcfg.dma 两个 MemoryRegion
      - fw_cfg_common_realize
        - 一堆 fw_cfg_add_i16 之类的，添加架构无关配置，比如 FW_CFG_SIGNATURE
    - sysbus_add_io
      - memory_region_add_subregion : 将 fwcfg 和 fwcfg.dma 添加到 system_io 中
    - 一堆 fw_cfg_add_i16 添加 x86 特有的配置，比如 FW_CFG_MAX_CPUS

### transfer method

#### IO transfer
和其他任何 pio 相同，fw_cfg 传输也是通过在注册 MemoryRegion 的方式.

具体来说就是, 在 `fw_cfg_io_realize` 中初始化 MemoryRegion comb_iomem
```c
    memory_region_init_io(&s->comb_iomem, OBJECT(s), &fw_cfg_comb_mem_ops,
                          FW_CFG(s), "fwcfg", FW_CFG_CTL_SIZE);
```
然后在 `fw_cfg_init_io_dma` 中添加进去
```c
    sysbus_add_io(sbd, iobase, &ios->comb_iomem); // iobase = FW_CFG_IO_BASE，也就是 0x510
```
之后 guest 只要读写 FW_CFG_IO_BASE 的位置，就会触发 fw_cfg_comb_mem_ops 的操作。

```c
static void fw_cfg_comb_write(void *opaque, hwaddr addr,
                              uint64_t value, unsigned size)
{
    switch (size) {
    case 1:
        fw_cfg_write(opaque, (uint8_t)value);
        break;
    case 2:
        fw_cfg_select(opaque, (uint16_t)value);
        break;
    }
}
```

在 seabios 这一侧的定义是对应的

./src/fw/paravirt.h
```c
#define PORT_QEMU_CFG_CTL           0x0510
#define PORT_QEMU_CFG_DATA          0x0511
```
例如 seabios 想要获取 CPU 数量的执行流程
- qemu_get_present_cpus_count
  - qemu_cfg_read_entry
    - qemu_cfg_select : 应该传递的内容有多个，首选进行选择
    - qemu_cfg_read : 选择了之后，从 PORT_QEMU_CFG_DATA 端口中读取
      - insb(PORT_QEMU_CFG_DATA, buf, len);

注意，实际上 QEMU 关于 fw_cfg 实现了两套方案，默认使用的是 fw_cfg_io_info
```c
static void fw_cfg_register_types(void)
{
    type_register_static(&fw_cfg_info);    // parent
    type_register_static(&fw_cfg_io_info); // 采用的这一套解决方法
    type_register_static(&fw_cfg_mem_info);
}
```

#### DMA transfer
使用 pio 传输，每次最多只能传输 long 的大小，但是代价是一次 vmexit，传输大量数据的时候，效率会很低。

为此需要多注册一个端口 fwcfg.dma，传输 QemuCfgDmaAccess 的地址

```c
static void
qemu_cfg_dma_transfer(void *address, u32 length, u32 control)
{
    QemuCfgDmaAccess access;

    access.address = cpu_to_be64((u64)(u32)address);
    access.length = cpu_to_be32(length);
    access.control = cpu_to_be32(control);

    barrier();

    outl(cpu_to_be32((u32)&access), PORT_QEMU_CFG_DMA_ADDR_LOW);

    while(be32_to_cpu(access.control) & ~QEMU_CFG_DMA_CTL_ERROR) {
        yield();
    }
}
```
在 QEMU 这里 QemuCfgDmaAccess 的信息在 fw_cfg_dma_transfer 中解析，最后调用到 dma_memory_write / dma_memory_read 完成数据传输。

#### file
fw_cfg 可以支持多种数据类型,
- fw_cfg_add_i16
- fw_cfg_add_i32
- fw_cfg_add_i64
- fw_cfg_add_string
- fw_cfg_add_file


file 类型和其他的类型有一些区别，并不是因为数据保存在文件中的原因，
不管那种类型的，数据的地址保存 FWCfgEntry::data 中的。
也不是因为数据大小的原因。file 的类型主要是为了**灵活性**。

实际上，fw_cfg 需要让 host 和 guest 传输多种数据，这些数据都是保存在数组 FWCfgState::entries 中的，
对于一些常用/有名的，host 和 guest 存在公共的约定索引

架构无关的在: include/standard-headers/linux/qemu_fw_cfg.h
```c
/* selector key values for "well-known" fw_cfg entries */
#define FW_CFG_SIGNATURE	0x00
#define FW_CFG_ID		0x01
#define FW_CFG_UUID		0x02
#define FW_CFG_RAM_SIZE		0x03
#define FW_CFG_NOGRAPHIC	0x04
// ...
```

和架构相关的内容放到了 ./hw/i386/fw_cfg.h
```c
#define FW_CFG_ACPI_TABLES      (FW_CFG_ARCH_LOCAL + 0)
#define FW_CFG_SMBIOS_ENTRIES   (FW_CFG_ARCH_LOCAL + 1)
#define FW_CFG_IRQ0_OVERRIDE    (FW_CFG_ARCH_LOCAL + 2)
#define FW_CFG_E820_TABLE       (FW_CFG_ARCH_LOCAL + 3)
#define FW_CFG_HPET             (FW_CFG_ARCH_LOCAL + 4)
```

如果想要添加一个新的内容，比如 smbios 的配置，就需要修改所有的 host 和 guest 的代码，
于是设计出来了 file

因为很多 fw_cfg 使用约定好的 index，但是新添加的，有一些采用名称来区分

文件的处理方法:
- 文件的常规内容都存贮在 FWCfgState::entries
- FWCfgState::files 指向一个 FWCfgFiles 是为了记录文件的属性
- FW_CFG_FILE_FIRST 开始, FWCfgState::entries[index - FW_CFG_FILE_FIRST] 持有 FWCfgState::files[index] 的内容是对应的，前者持有 file 的内容，后者持有 file 的属性
- FWCfgState::entries[FW_CFG_FILE_DIR] 保存的是 FWCfgFiles 的内容，也就是文件的属性，seabios 可以给出一个文件名可以知道其在 FWCfgState::entries

使用图形表示就是:
![](../img/fw_cfg.svg)

在去分析具体的源码就很容易了:

在 QEMU 这一侧进行组装:
```c
void fw_cfg_add_file_callback(FWCfgState *s,  const char *filename,
                              FWCfgCallback select_cb,
                              FWCfgWriteCallback write_cb,
                              void *callback_opaque,
                              void *data, size_t len, bool read_only)
{

    // ...
    if (!s->files) {
        dsize = sizeof(uint32_t) + sizeof(FWCfgFile) * fw_cfg_file_slots(s);
        s->files = g_malloc0(dsize);
        fw_cfg_add_bytes(s, FW_CFG_FILE_DIR, s->files, dsize);
    }

    // ...
    fw_cfg_add_bytes_callback(s, FW_CFG_FILE_FIRST + index,
                              select_cb, write_cb,
                              callback_opaque, data, len,
                              read_only);

    s->files->f[index].size   = cpu_to_be32(len);
    s->files->f[index].select = cpu_to_be16(FW_CFG_FILE_FIRST + index);
    s->entry_order[index] = order;
```

在 seabios 中首先读取所有的 file 信息
```c
void qemu_cfg_init(void)
{
    // Load files found in the fw_cfg file directory
    u32 count;
    qemu_cfg_read_entry(&count, QEMU_CFG_FILE_DIR, sizeof(count));
    count = be32_to_cpu(count); // 一共有多少个文件
    u32 e;
    for (e = 0; e < count; e++) {
        struct QemuCfgFile qfile;
        qemu_cfg_read(&qfile, sizeof(qfile)); // 读取一个 FWCfgFile
        qemu_romfile_add(qfile.name, be16_to_cpu(qfile.select) // 添加 file 到 RomfileRoot 数组中，之后可以通过文件名调用  romfile_find
                         , 0, be32_to_cpu(qfile.size));
    }
```

之后通过文件名就可以找到 index
```c
static int
get_field(int type, int offset, void *dest)
{
    char name[128];
    snprintf(name, sizeof(name), "smbios/field%d-%d", type, offset);
    struct romfile_s *file = romfile_find(name);
    if (!file)
        return 0;
    file->copy(file, dest, file->size);
    return file->size;
}
```

在 fw_cfg_add_file_callback 可以截获所有的 file :

```txt
etc/boot-fail-wait
etc/e820
genroms/kvmvapic.bin
genroms/linuxboot_dma.bin
etc/system-states
etc/acpi/tables
etc/table-loader
etc/tpm/log
etc/acpi/rsdp
etc/smbios/smbios-tables
etc/smbios/smbios-anchor
bootorder
bios-geometry
```

### ROM
QEMU 让 guest 访问 rom 大致可以如此划分:

- rom_insert
  - **映射 MemoryRegion 到 guest 地址空间** : 这和 fw_cfg 无关
    - /home/maritns3/core/seabios/out/bios.bin
  - **guest 通过 fw_cfg 读取**
    - **未关联 MemoryRegion**
      - kvmvapic.bin
      - linuxboot_dma.bin
    - **关联 MemoryRegion**
      - etc/acpi/tables
      - etc/table-loader
      - etc/acpi/rsdp

分析具体的代码:
- rom_add_file / rom_add_blob / rom_add_elf_program: 将数据读到 Rom::data 中
    - rom_insert : 将 rom 添加 `roms` 中
- rom_reset : 遍历 `roms` 中的所有的 rom, 如果 `rom->fw_file == NULL`，那么 rom 的数据需要拷贝到 MemoryRegion 中

rom_reset 包含了有意思的小问题
- [pc.bios 如何映射到 guest 空间的](https://martins3.github.io/qemu/bios-memory.html)
- 为什么 rom 通过 fw_cfg 访问，为什么还是需要将数据拷贝到 MemoryRegion::RamBlock::host 中

#### ROM migration
之所以需要进行 ROM 的拷贝到 MemoryRegion 的原因:
1. 被 MemoryRegion 的管理的数据在 migration 的时候会被 migration
2. 但是 Rom::data 的数据不会
3. 如果 guest 读取 Rom::data

```diff
tree 90921644ff0d58e6e165cc439321328e5d771256
parent 0851c9f75ccb0baf28f5bf901b9ffe3c91fcf969
author Michael S. Tsirkin <mst@redhat.com> Mon Aug 19 17:26:55 2013 +0300
committer Michael S. Tsirkin <mst@redhat.com> Wed Aug 21 00:18:39 2013 +0300

loader: store FW CFG ROM files in RAM

ROM files that are put in FW CFG are copied to guest ram, by BIOS, but
they are not backed by RAM so they don't get migrated.

Each time we change two bytes in such a ROM this breaks cross-version
migration: since we can migrate after BIOS has read the first byte but
before it has read the second one, getting an inconsistent state.

Future-proof this by creating, for each such ROM,
an MR serving as the backing store.
This MR is never mapped into guest memory, but it's registered
as RAM so it's migrated with the guest.

Naturally, this only helps for -M 1.7 and up, older machine types
will still have the cross-version migration bug.
Luckily the race window for the problem to trigger is very small,
which is also likely why we didn't notice the cross-version
migration bug in testing yet.

Signed-off-by: Michael S. Tsirkin <mst@redhat.com>
Reviewed-by: Laszlo Ersek <lersek@redhat.com>
```

让 rom 和 mr 关联的原因: 因为 bios 无法自动同步，所以使用 MemoryRegion 保存 bios 从而可以自动 migration
解决方法:
1. 创建 rom_set_mr : 将 rom 关联一个 mr, 并且将 rom 中的数据拷贝到 mr 的空间中
2. 修改 rom_add_file  : fw_cfg 提供数据给 guest 注册的时候只是需要一个指针，如果配置了 option_rom_has_mr 的话，那么这个指针来自于 memory_region_get_ram_ptr

### modify
fw_cfg_add_bytes_callback 对于一个 entry 只能调用一次，如果想要修改就需要调用
fw_cfg_modify_bytes_read

- fw_cfg_modify_file
  - fw_cfg_modify_bytes_read
  - fw_cfg_add_file_callback

- fw_cfg_modify_i16
  - fw_cfg_modify_bytes_read

### FWCfgEntry callback

实际上注册了可选的 callback，
- fw_cfg_select => FWCfgEntry::select_cb
- fw_cfg_dma_transfer => FWCfgEntry::write_cb

FWCfgEntry::select_cb 的唯一注册者为 acpi_build_update, 而 write_cb 从未使用过。

- acpi_build_update
  - acpi_build_tables_init : 初始化 tables 的数值
  - acpi_build : 构建整个 acpi table
  - acpi_ram_update

## kernel image 是如何被加载的
QEMU 提供了 -kernel 参数，让 guest 运行的内核可以随意指定，这对于调试内核非常的方便，现在说明一下 -kernel 选项是如何实现的:

### QEMU's preparation
1. 通过 [QEMU 的参数解析](https://martins3.github.io/qemu/options.html) 机制，将参数保存到 MachineState::kernel_filename 中
```c
static void machine_set_kernel(Object *obj, const char *value, Error **errp)
{
    MachineState *ms = MACHINE(obj);

    g_free(ms->kernel_filename);
    ms->kernel_filename = g_strdup(value);
}
```

2. 在 `x86_load_linux` 中添加 linuxboot_dma.bin 到 `option_rom` 数组中

```c
    f = fopen(kernel_filename, "rb");

    if (fread(kernel, 1, kernel_size, f) != kernel_size) { // 读去文件内容
        fprintf(stderr, "fread() failed\n");
        exit(1);
    }

    fw_cfg_add_bytes(fw_cfg, FW_CFG_KERNEL_DATA, kernel, kernel_size); // 通过 FW_CFG_KERNEL_DATA 告知 seabios

    option_rom[nb_option_roms].bootindex = 0;
    option_rom[nb_option_roms].name = "linuxboot.bin";
    if (linuxboot_dma_enabled && fw_cfg_dma_enabled(fw_cfg)) {
        option_rom[nb_option_roms].name = "linuxboot_dma.bin";
    }
```

3. 在 pc_memory_init 中调用 rom_add_option 添加到 fw_cfg 中，之后 seabios 就可以通过 fw_cfg 读取 `linuxboot_dma.bin`
```c
    for (i = 0; i < nb_option_roms; i++) {
        rom_add_option(option_rom[i].name, option_rom[i].bootindex);
    }
```

4. rom_add_option 会进一步调用 add_boot_device_path 中，记录到 `fw_boot_order`

5. fw_cfg_machine_reset 中修改 "bootorder"
```c
    buf = get_boot_devices_list(&len); // 返回内容 /rom@genroms/linuxboot_dma.bin
    ptr = fw_cfg_modify_file(s, "bootorder", (uint8_t *)buf, len);
```

到此，QEMU 的准备完成，实际上就是修改 "bootorder"，让 seabios 通过执行 linuxboot_dma.bin 来启动

### Seabios

- maininit
  - interface_init
    - boot_init
      - loadBootOrder : 构建 Bootorder
  - optionrom_setup
    - run_file_roms
      - deploy_romfile : 将 linuxboot_dma.bin 加载进来
      - init_optionrom
        - callrom : 执行 linuxboot_dma.bin 部分代码，初始化 pnp 相关内容
      - setRomSource
    - get_pnp_rom : linuxboot_dma.bin 是按照 pnp 规则的构建的 optionrom
    - boot_add_bev : Registering bootable: Linux loader DMA (type:128 prio:1 data:cb000054)
      - getRomPriority
        - find_prio : 根据 Bootorder 的内容返回 prio
      - bootentry_add : 将 kernel image 添加到 BootList 中，在 BootList 的排序根据 getRomPriority 获取的 prio 确定
  - prepareboot
    - bcv_prepboot : 连续调用 add_bev, 调用顺序是按照 BootList 构建 `BEV`
  - startBoot
    - call16_int(0x19, &br)
      - handle_19
        - do_boot
          - boot_rom : 默认使用第一个 BEV，也就是 kernel image
            - call_boot_entry : linuxboot_dma.bin 上，然后 linuxboot_dma.bin 进一步跳转到 kernel image 上开始执行

其实，总体来说，seabios 做了两个事情:
- 执行 optionrom linuxboot_dma.bin 将 kernel image 加载进来
- 根据 "bootorder" 将 kernel image 作为 boot 默认启动方式

### linuxboot_dma.bin
linuxboot_dma.bin 是通过 `pc-bios/optionrom/linuxboot_dma.c` 编译出来的，通过前面的分析，其实我们已经可以大致的猜测出来到底

第一个部分是 pnp optionrom 规范的内容，第二个就是通过 fw_cfg 获取到 kernel image 的地址，然后跳转过去了


<script src="https://utteranc.es/client.js" repo="Martins3/Martins3.github.io" issue-term="url" theme="github-light" crossorigin="anonymous" async> </script>

本站所有文章转发 **CSDN** 将按侵权追究法律责任，其它情况随意。