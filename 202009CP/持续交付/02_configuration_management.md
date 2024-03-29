#### branch policy

“采用不同的代码分支策略，意味着实施不同的代码集成与上线流程，这会影响整个研发团队每日的协作方式，因此研发团队通常会很认真地选择自己的策略"


**questions**

* Google 和 Facebook 这两个互联网大咖都在用主干开发（Trunk Based Development，简称 TBD），我们是不是也参照它俩，采用主干开发分支策略？

主干开发是一个源代码控制的分支模型，开发者在一个称为 “trunk” 的分支（Git 称master） 中对代码进行协作，除了发布分支外没有其他开发分支。“主干开发”确实避免了合并分支时的麻烦，因此像 Google 这样的公司一般就不采用分支开发，分支只用来发布。

大多数时候，发布分支是主干某个时点的快照。以后的改 Bug 和功能增强，都是提交到主干，必要时 cherry-pick （选择部分变更集合并到其他分支）到发布分支。与主干长期并行的特性分支极为少见。
由于不采用“特性分支开发”，所有提交的代码都被集成到了主干，为了保证主干上线后的有效性，一般会使用特性切换（feature toggle）。特性切换就像一个开关可以在运行期间隐藏、启用或禁用特定功能，项目团队可以借助这种方式加速开发过程。特性切换在大型项目持续交付中变得越来越重要，因为它有助于将部署从发布中解耦出来。
但据吉姆 · 伯德（Jim Bird）介绍，特性切换会导致代码更脆弱、更难测试、更难理解和维护、更难提供技术支持，而且更不安全

* 用 Google 搜索一下，会发现有个排名很靠前的分支策略，叫“A successful Git branching model”（简称 Git Flow），它真的好用吗？团队可以直接套用吗？

[Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)

* GitHub 和 GitLab 这两个当下最流行的代码管理平台，各自推出了 GitHub Flow 和 GitLab Flow，它们有什么区别？适合我使用吗？
* 像阿里、携程和美团点评这样国内知名的互联网公司，都在用什么样的分支策略？


* Github flow

在 GitHub Flow 中，master 分支中包含稳定的代码，它已经或即将被部署到生产环境。
任何开发人员都不允许把未测试或未审查的代码直接提交到 master 分支。对代码的任何
修改，包括 Bug 修复、热修复、新功能开发等都在单独的分支中进行。不管是一行代码的
小改动，还是需要几个星期开发的新功能，都采用同样的方式来管理。

当需要修改时，从 master 分支创建一个新的分支，所有相关的代码修改都在新分支中进
行。开发人员可以自由地提交代码和提交到远程仓库。


#### Dependency management 依赖管理

* 操作系统的依赖管理工具，比如 CentOS 的 yum，Debian 的 apt，Arch 的Packman，macOS 的 Homebrew；
* 编程语言的依赖管理工具，比如 Java 的 Maven， .Net 的 nuget，Node.js的 npm，Golang 的 go get，Python 的 pip，Ruby 的 Gem

一个典型的依赖管理工具通常会有以下几个特性：
1. 统一的命名规则，也可以说是坐标，在仓库中是唯一的，可以被准确定位到；
2. 统一的中心仓库可以存储管理依赖和元数据；
3. 统一的依赖配置描述文件；
4. 本地使用的客户端可以解析上述的文件以及拉取所需的依赖


#### Maven

Maven 是 Java 生态系统里面一款非常强大的构建工具，其中一项非常重要的工作就是对项目依赖进行管理。
Maven 使用 XML 格式的文件进行依赖配置描述的方式，叫作 POM（Project Object Model ）

在 POM 中，根元素 project 下的 dependencies 可以包含一个或多个 dependency 元素，以声明一个或者多个项目依赖。每个依赖可以包含的元素有：
1. groupId、artifactId、version： 依赖的基本坐标；
2. type： 依赖的类型，默认为 jar；
3. scope： 依赖的范围；
4. optional： 标记依赖是否可选；
5. exclusions： 用来排除传递性依赖；


Maven 的依赖仲裁原则如下：

* 第一原则： 最短路径优先原则
* 第二原则： 第一声明优先原则



#### 代码回滚 rollback
* 第一种情况：开发人员独立使用的分支上，如果最近产生的 commit 都没有价值，应该废弃掉，此时就需要把代码回滚到以前的版本。
* 第二种情况：代码集成到团队的集成分支且尚未发布，但在后续测试中发现这部分代码有问题，且一时半会儿解决不掉，为了不把问题传递给下次的集成，此时就需要把有问题的代码从集成分支中回滚掉。
* 第三种情况：代码已经发布到线上，线上包回滚后发现是新上线的代码引起的问题，且需要一段时间修复，此时又有其他功能需要上线，那么主干分支必须把代码回滚到产品包对应的 commit。



#### 代码回滚必须遵循的原则
集成分支上的代码回滚坚决不用 reset --hard 的方式，原因如下：
* 集成分支上的 commit 都是项目阶段性的成果，即使最近的发布不需要某些 commit 的功能，但仍然需要保留这些 commit ，以备后续之需。
* 开发人员会基于集成分支上的 commit 拉取新分支，如果集成分支采用 reset 的方式清除了该 commit ，下次开发人员把新分支合并回集成分支时，又会把被清除的 commit申请合入，很可能导致不需要的功能再次被引入到集成分支。


* 个人分支回滚
```
$ git checkout feature-x
$ git reset --hard (hash for commit)
$ git push -f origin feature-x
```

* 集成分支上线前回滚


```
1. 假定走特性分支开发模式，上面的 commit 都是特性分支通过 merge request 合入
master 产生的 commit。
2. 集成后，测试环境中发现 C4 和 C6 的功能有问题，不能上线，需马上回滚代码，以便
C5 的功能上线。
3. 团队成员可以在 GitLab 上找到 C4 和 C6 合入 master 的合并请求，然后点击 revert
4. 回滚后C4’是 revert C4 产生的 commit，C6’是 revert
C6 产生的 commit。通过 revert 操作，C4 和 C6 变更的内容在 master 分支上就被清除
掉了，而 C5 变更的内容还保留在 master 分支上。
```


* 集成分支上线后回滚

```
1. C3 打包并上线，生成线上的版本 V0529，运行正确。之后 C6 也打包并上线，生成线上
版本 V0530，运行一段时间后发现有问题。C4 和 C5 并没有单独打包上线，所以没有对
应的线上版本。
2. 项目组把产品包从 V0530 回滚到 V0529，经过定位，V0530 的代码有问题，但短时间
不能修复，于是，项目组决定回滚代码。
3. C4 和 C5 没有单独上过线，因此从线上包的角度看，不能回滚到 C4 或 C5，应该回滚到
C3。
4. 考虑到线上包可以回滚到曾发布过的任意一个正确的版本。为了适应线上包的这个特
点，线上包回滚触发的代码回滚我们决定不用 一个个 revert C4、C5 和 C6 的方式，而
是直接创建一个新的 commit，它的内容等于 C3 的内容。

$ git fetch origin
$ git checkout master
$ git reset --hard V0529 # 把本地的 master 分支的指针回退到 V0529，此时暂存区 (ind
$ git reset --soft origin/master # --soft 使得本地的 master 分支的指针重新回到 V05javasc
$ git commit -m "rollback to V0529" # 把暂存区里的内容提交，这样一来新生成的 commit 的内容和
$ git push origin master
```
