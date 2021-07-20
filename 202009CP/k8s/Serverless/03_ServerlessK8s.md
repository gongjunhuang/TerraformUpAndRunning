#### Serverless 容器

 Serverless 理念的核心价值，其 中包括无需管理底层基础设施，无需关心底层 OS 的升级和维护，因为 Serverless 可以 让我们更加关注应用开发本身，所以应用的上线时间更短。同时 Serverless 架构是天然 可扩展的，当业务用户数或者资源消耗增多时，我们只需要创建更多的应用资源即可，其背 后的扩展性是用户自己购买机器所无法比拟的。Serverless 应用一般是按需创建，用户无 需为闲置的资源付费，可以降低整体的计算成本。

 Serverless 容器和其他 Serverless 形态的差异， 在于它是基于容器的交付形态。

 基于容器意味着通用性和标准性，我们可以 Build once and Run anywhere，容 器不受语言和库的限制，无论任何应用都可以制作成容器镜像，然后以容器的部署方式启动。 基于容器的标准化，开源社区以 Kubernetes 为中心构建了丰富的云原生 Cloud Native 生态，极大地丰富了 Serverless 容器的周边应用框架和工具，比如可以非常方便地部署 Helm Chart 包。基于容器和 Kubernetes 标准化，我们可以轻松地在不同环境中(线 上线下环境)，甚至在不同云厂商之间进行应用迁移，而不用担心厂商锁定。这些都是 Serverless 容器的核心价值。


 * AWS: EKS on Fargate and ECS on Fargate
 * Azure: ACI
 * Aliyun: ASK



 #### ECI

 ECI 全称是“Elastic Container Instance 弹性容器实例”，是 Serverless 容器 的底层基础设施，实现了容器镜像的启动。ECI 底层运行环境基于安全容器技术进行强隔离，每个 ECI 拥有一个独立的 OS 运行环 境，保证运行时的安全性。ECI 支持 0.25c 到 64c 的 CPU 规格，也支持 GPU，按 需创建按秒收费。

 ECI 只可以做到单个容器实例的创建，而没有编排的能力，比如让应用多副本扩容， 让 SLB 和 Ingress 接入 Pod 流量，所以我们需要在编排系统 Kubernetes 中使用 ECI，我们提供了两种在 Kubernetes 中使用 ECI 的方式。一个是 ACK on ECI，另 外一个是 ASK。

 在与 Kubernetes 编排系统的集成中，我们以 Pod 的形式管理每个 ECI 容器实 例，每个 Pod 对应一个 ECI 实例， ECI Pod 之间相互隔离，一个 ECI Pod 的启动 时间约是 10s。因为是在 Kubernetes 集群中管理 ECI Pod，所以完全连接了 Kubernetes 生态，有以下几点体现:

* 很方便地用 Kubectl 管理 ECI Pod，可以使用标准的 Kubernetes 的 API 操作资 源;
* 通过 Service 和 Ingress 连接 SLB 和 ECI Pod;
* 使用 Deployment / Statefulset 进行容器编排，使用 HPA 进行动态扩容;
* 可以使用 Proms 来监控 ECI Pod;
* 运行 Istio 进行流量管理，Spark / Presto 做数据计算，使用 Kubeflow 进行机器学习;
* 部署各种 Helm Chart。

需要留意的是 Kubernetes 中的 ECI Pod 是 Serverless 容器，所以与普通的 Pod 相比，不支持一些功能(比如 Daemonset)，不支持 Prividge 权限，不支持 HostPort 等。除此之外，ECI Pod 与普通 Pod 能力一样，比如支持挂载云盘、NAS 和 OSS 数 据卷等。


#### ACK on ECI

这种方式适合于用 户已经有了一个 ACK 集群，集群中已经有了很多 ECS 节点，此时可以基于 ECI 的弹 性能力来运行一些短时间 Short-Run 的应用，以解决元集群资源不足的问题，或者使用 ECI 来支撑应用的快速扩容，因为使用 ECI 进行扩容的效率要高于 ECS 节点扩容。



#### ASK

与 ACK on ECI 不同的是，ASK(Serverless Kubernetes)集群中没有 ECS 节 点，这是和传统 Kubernetes 集群最主要的差异，所以在 ASK 集群中无需管理任何节点， 实现了彻底的免节点运维环境，是一个纯粹的 Serverless 环境，它让 Kubernetes 的使 用门槛大大降低，也丢弃了繁琐的底层节点运维工作，更不会遇到节点 Notready 等问题。 在 ASK 集群中，用户只需关注应用本身，而无需关注底层基础设施管理。

ASK 的弹性能力会优于普通 Kubernetes 集群，目前是 30s 创建 500 个 Pod 到 Running 状态。集群中 ECI Pod 默认是按量收费，但也支持 Spot 和预留实例劵来 降低成本。在兼容性方面，ASK 中没有真实节点存在，所以不支持 Daemonset 等与节 点相关的功能，像 Deployment / Statefulset / Job / Service / Ingress / CRD 等 都是无缝支持的。
