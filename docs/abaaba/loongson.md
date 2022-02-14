# 在龙芯的生活

> 胡老师[^1]的想法很简单，不惜一切代价搞好龙芯。所有龙芯人都是代价。

> 我后来才意识到，不是实验室不想构建培养体系，而是没有能力构建培养体系。

现在到龙芯已经快四年了，相比于计算所的研究生，感觉自己更加像是一个龙芯人。
对于龙芯的想法是起起伏伏，变化了很多次。

## 从计算所研究生的角度看
本科是在华科读的，读了几年之后，对于大学教育非常的失望，感觉高等教育就是一个骗局，本来是不想读研究生的。
但是发现自己有一个保研名额，而且投递的腾讯实习生没有回复了，就去参加了计算所夏令营。
当时是准备做系统结构，找了微处理器中心(也就是龙芯)，还面一下编译方面的实验室的，但是龙芯这边很快就通知我可以录取，我就没面编译实验室了。

面试的地方在融科，办公楼很气派，和周围的 Intel VMware AMD Google 等大公司的办公楼融为一体，但是那几天是在融科的 95% 的时间，之后我都是在环保园。
环保园这个地方非常的鬼畜，离地铁最近的地方都是荒地，在 2018 年的夏天，出地铁到龙芯办公楼的时候甚至会经过一大片玉米地。从环保园到融科很不方便，大约需要一个小时，我真不知道那些转博的同学因为上课的原因一周往返好几次两地是如何坚持下来的。

来龙芯第一天，被安排做一个 bios 相关的事情，我并不是很想做，然后又被安排去做 android 到 mips 上的移植。这个项目让我意识到一些情况不对:
- android 在 mips 上跑不起来，没有一个明确的解决思路
- 明明知道我没有能力解决这个问题（好吧，直到今天，我也感觉这个东西很难），但是没有人告诉我应该学什么
- 每周的例会，感觉没有什么反馈，表示没有什么进度，好像也没有什么对策

我感觉在这样的状态下“吃枣药丸”，所以开始自己看看 Linux kernel 这个样子维持一下生活。
事实证明，这个决定极其正确，如果你掌握了硬核的技术，你才有有机会做一些更加硬核的项目。

android 移植这个项目给我伤害很大，虽然这一年我也没有闲着:
- 看了量化，程序员的自我修养
- 做了 ucore 操作系统实验
- 南大的系统结构实验（俗称 pa），看了 Linux Kernel

但是做的事情很不连续，反正就是我感觉应该看的东西看一下。

后来就是在怀柔上课，说实话，这段时间除了认识了我现在的女朋友，结识了一些新朋友，没有太多有意思的东西。
上了很多课，但是基本都是混学分，现在不到两年时间，现在都是模模糊糊的。但是李炼老师的编译原理有四个实验，做完之后收获很大。

怀柔上课中间，基本和龙芯公司没有沟通。

之后就是写 Loongson Dune 和 BMBT 的时间了，这段时间主要和张福新老师打交道，其实感觉还是很不错的:
- 每周汇报五分钟，接下来想干啥干啥
- 做的事情不是特别的偏向工程
- 做这两个项目的过程中学到很多东西
- 感觉同学的水平都非常不错，可以给我很多启发。
  - 其实这一条是最重要的，我猜没有人喜欢和傻子在一起工作，和怠惰的人在一起工作，大家都在积极地在推动一件有意思的事情，这种氛围很不错。

但是也存在一些感觉可以改进的地方:
- 我几乎没看论文
- 感觉作息越来越鬼畜，睡觉睡的很晚，午觉时间很长，第二天早上很难醒来。

看到这里，也许你发现，其实看上去是在计算所读研，但是实际上是在龙芯打工，这个问题在学生中争论了非常长时间，不同的人看法差别很大，曾经我非常强力的吐槽了这个事情，
但是我现在从过来人的角度来说几句:
- 什么是工程，什么是科研?
  - 计算机中绝大多数问题都是工程技术问题，只有很少的人在做计算机的理论的问题。大多数的科研就是在改进工程技术，当我们在抱怨在龙芯读研的时候，其实是在抱怨在龙芯做的事情没有创新。
- 为什么在龙芯读研会没有创新?
  - 按照胡老师的说话，之前的龙芯一直都是在补课的阶段。龙芯在没有达到主流水平的情况下，不去摸着石头过河，用别人探明的方案，去重新试错，是很蠢的。
  - 别人写文章介绍了方法，然后自己实现出来，这种摸别人的石头的操作对于博士毕业没有什么意义，但是对于龙芯意义很大。
- 似乎以后不会那么糟糕了
  - 龙芯现在的水平实际上正在快速接近主流水平，实际上，现在已经没有特别工程的事情。
  - 龙芯现在逐渐可以维持生活了，很多工程任务可以通过招聘工程师来做。
- 但是没有人愿意放弃学生
  - 每一个学生一个月的工资大约在 2000 ~ 14000 左右（这个数目因为年纪，所在部门等因素差别很大，但感觉总体在 6000 左右）
  - 工程师的工资感觉是这个的 5 到 10 倍
  - 有一些学生的水平很不错
  - 如果直接招聘，一个人培养是需要花很长时间的，如果是自己培养的学生，那么可以直接干活了。

## 从龙芯员工的角度看
虽然，胡老师说补课完成，但是我认为龙芯还有很长的路要走。

不过，自从我把我的[工作环境切换到龙芯](../loongarch/neovim.md)上，并且可以几乎不再使用我的小米笔记本之后，
我感觉龙芯还是很有信心的。在信创的浪潮中，龙芯的走的一条道路基本上[^3]是无可替代的。

因为龙芯最近几年一直都是在快速上升的过程中，比如我作为实习生的工资从 2000 也涨到了快 7000 块，
身边的人一般都比较有干劲。

我在字节跳动实习过一段时间，感觉龙芯和互联网大厂之间的管理水平上还会存在一些距离的:
- 没有统一的代码管理仓库
- 根本不知道其他的部门在干什么，别人也不知道我在干什么
- 虽然各个部门的 leader 非常厉害，比如我的老板张福新，但是感觉普通员工和大厂的普通员工水平存在差距。

在龙芯写软件，实际上主要的工作都是架构相关移植，写硬件我就不了解了。

## 微处理器生存指南
靠自己，靠自己，靠自己。

每个人做的方向都不同，说实话，目前没有办法做出一个覆盖所有人的建议:

- [打好基础](../learn-cs.md)
- [学好内核](../learn-linux-kernel.md)
- [略懂虚拟化](../learn-virtualization.md)
- 掌握二进制翻译 (wip)

[^1]: https://zh.wikipedia.org/wiki/%E8%83%A1%E4%BC%9F%E6%AD%A6
[^2]: [如何看待华中科技大学研究生跳楼自杀事件？](https://www.zhihu.com/question/344298388)
[^3]: [unicore](https://en.wikipedia.org/wiki/Unicore)

<script src="https://giscus.app/client.js"
        data-repo="martins3/martins3.github.io"
        data-repo-id="MDEwOlJlcG9zaXRvcnkyOTc4MjA0MDg="
        data-category="Show and tell"
        data-category-id="MDE4OkRpc2N1c3Npb25DYXRlZ29yeTMyMDMzNjY4"
        data-mapping="pathname"
        data-reactions-enabled="1"
        data-emit-metadata="0"
        data-theme="light"
        data-lang="zh-CN"
        crossorigin="anonymous"
        async>
</script>

本站所有文章转发 **CSDN** 将按侵权追究法律责任，其它情况随意。