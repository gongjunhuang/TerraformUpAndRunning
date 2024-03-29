#### importance

持续交付
* 必须以平台化的思想去看待
* 顺应技术变迁
* 与系统架构/运维体系息息相关

CI：我们通常会把软件研发工作拆解，拆分成不同模块或不同团队后进行编码，编码完成后，进行集成构建和测试。这个从编码到构建再到测试的反复持续过程，就叫作“持续集成”

CD：
* 这个在“持续集成”之后，获取外部对软件的反馈再通过“持续集成”进行优化的过程就叫作“持续交付”，它是“持续集成”的自然延续

* 而“持续部署”就是将可交付产品，快速且安全地交付用户使用的一套方法和系统，它是“持续交付”的最后“一公里”

“持续交付”是一个承上启下的过程，它使“持续集成”有了实际业务价值，形成了闭环，而又为将来达到“持续部署”的高级目标做好了铺垫。通常我们在实施持续交付后，都能够做到在保证交付质量的前提下，加快交付速度，从而更快地得到市场反馈，引领产品的方向，最终达到扩大收益的目的。

持续交付的价值不仅仅局限于简单地提高产品交付的效率，它还通过统一标准、规范流程、工具化、自动化等等方式，影响着整个研发生命周期。持续交付最终的使命是打破一切影响研发的“阻碍墙”，为软件研发工作本身赋能。无论你是持续交付的老朋友还是新朋友，无论你在公司担任管理工作还是普通的研发人员，持续交付都会对你的工作产生积极的作用。


#### 影响持续交付的架构因素

影响持续交付的架构因素，主要有两大部分：系统架构和部署架构

#### 系统架构

系统架构指系统的组成结构，它决定了系统的运行模式，层次结构，调用关系等。我们通常会遇到的系统架构包括：
* 单体架构，一个部署包，包含了应用所有功能

对单体架构来说：
1. 整个应用使用一个代码仓库，在系统简单的情况下，因为管理简单，可以快速简单地做
到持续集成；但是一旦系统复杂起来，仓库就会越变越大，开发团队也会越来越大，多
团队维护一个代码仓库简直就是噩梦，会产生大量的冲突；而且持续集成的编译时间也
会随着仓库变大而变长，团队再也承受不起一次编译几十分钟，结果最终失败的痛苦。
2. 应用变复杂后，测试需要全回归，因为不管多么小的功能变更，都会引起整个应用的重
新编译和打包。即使在有高覆盖率的自动化测试的帮助下，测试所要花费的时间成本仍
旧巨大，且错误成本昂贵。
3. 在应用比较小的情况下，可以做到单机部署，简单直接，这有利于持续交付；但是一旦
应用复杂起来，每次部署的代价也变得越来越高，这和之前说的构建越来越慢是一个道
理。而且部署代价高会直接影响生产稳定性。这显然不是持续交付想要的结果。
总而言之，一个你可以完全驾驭的单体架构应用，是最有容易做到持续交付的，但一旦它变
得复杂起来，一切就都会失控。

* SOA 架构，面向服务，通过服务间的接口和契约联系；

对 SOA 架构来说：
1. 由于服务的拆分，使得应用的代码管理、构建、测试都变得更轻量，这有利于持续集成
的实施。
2. 因为分布式的部署，使得测试环境的治理，测试部署变得非常复杂，这里就需要持续交
付过程中考虑服务与服务间的依赖，环境的隔离等等。
3. 一些新技术和组件的引入，比如服务发现、配置中心、路由、网关等，使得持续交付过
程中不得不去考虑这些中间件的适配。
总体来说，SOA 架构要做到持续交付比单体架构要难得多。但也正因架构解耦造成的分散
化开发问题，持续集成、持续交付能够在这样的架构下发挥更大的威力。

* 微服务架构，按业务领域划分为独立的服务单元，可独立部署，松耦合。

对微服务架构来说：
其实，微服务架构是一种 SOA 架构的演化，它给持续交付带来的影响和挑战也基本与
SOA 架构一致。



#### 部署架构

部署架构指的是，系统在各种环境下的部署方法，验收标准，编排次序等的集合。它将直接
影响你持续交付的“最后一公里”。

* 首先，你需要考虑，是否有统一的部署标准和方式。 在各个环境，不同的设备上，应用的
部署方式和标准应该都是一样的，可复用的；除了单个应用以外，最好能做到组织内所有应
用的部署方式都是一样的。否则可以想象，每个应用在每个环境上都有不同的部署方式，都
要进行持续交付的适配，成本是巨大的。

* 其次，需要考虑发布的编排次序。 特别是在大集群、多机房的情况下。我们通常会采用金
丝雀发布（之后讲到灰度发布时，我会详解这部分内容），或者滚动发布等灰度发布策略。
那么就需要持续交付系统或平台能够支持这样的功能了。

* 再次，是 markdown 与 markup 机制。 为了应用在部署时做到业务无损，我们需要有完
善的服务拉入拉出机制来保证。否则每次持续交付都伴随着异常产生，肯定不是大家愿意见
到的。

* 最后，是预热与自检。 持续交付的目的是交付有效的软件。而有些软件在启动后需要处理
加载缓存等预热过程，这些也是持续交付所要考虑的关键点，并不能粗暴启动后就认为交付
完成了。同理，如何为应用建立统一的自检体系，也就自然成为持续交付的一项内容了。





#### DevOps and CD

DevOps 的概念一直在向外延伸，包括了：运营和用户，以及快速、良好、及时的
反馈机制等内容，已经超出了“持续交付”本身所涵盖的范畴。而持续交付则一直被视作
DevOps 的核心实践之一被广泛谈及。

人们对 DevOps 的看法，可以大致概括为 DevOps 是一组技术，一个职能、一种
文化，和一种组织架构四种。

第一，DevOps 是一组技术，包括：自动化运维、持续交付、高频部署、Docker 等内
容。

第二，DevOps 是一个职能，这也是我在各个场合最常听到的观点

第三，DevOps 是一种文化，推倒 Dev 与 Ops 之间的阻碍墙

第四，DevOps 是一种组织架构，将 Dev 和 Ops 置于一个团队内，一同工作，同化目
标，以达到 DevOps 文化地彻底贯彻。

1. DevOps 的本质其实是一种鼓励协作的研发文化；
2. 持续交付与 DevOps 所追求的最终目标是一致的，即快速向用户交付高质量的软件产
品；
3. DevOps 的概念比持续交付更宽泛，是持续交付的继续延伸；
4. 持续交付更专注于技术与实践，是 DevOps 的工具及技术实现。
