#### introduction
Kubernetes管理的是集群，Kubernetes中的网络要解决的核心问题就是每台主机的IP地址网段划分，以及单个容器的IP地址分配。概括为：

* 保证每个Pod拥有一个集群内唯一的IP地址
* 保证不同节点的IP地址划分不会重复
* 保证跨节点的Pod可以互相通信
* 保证不同节点的Pod可以与跨节点的主机互相通信


Kubernetes集群内部存在三类IP，分别是：

* Node IP：宿主机的IP地址
* Pod IP：使用网络插件创建的IP（如flannel），使跨主机的Pod可以互通
* Cluster IP：虚拟IP，通过iptables规则访问服务


#### Flannel

Flannel是作为一个二进制文件的方式部署在每个node上，主要实现两个功能：

* 为每个node分配subnet，容器将自动从该子网中获取IP地址
* 当有node加入到网络中时，为每个node增加路由配置

![](https://jimmysong.io/kubernetes-handbook/images/flannel-networking.png)

Flannel 项目是 CoreOS 公司主推的容器网络方案。事实上，Flannel 项目本身只是一个框架，真 正为我们提供容器网络功能的，是 Flannel 的后端实现。目前，Flannel 支持三种后端实现，分别 是:
1. VXLAN;
2. host-gw;
3. UDP。


在这个例子中，我有两台宿主机。
* 宿主机 Node 1 上有一个容器 container-1，它的 IP 地址是 100.96.1.2，对应的 docker0 网桥 的地址是:100.96.1.1/24。
* 宿主机 Node 2 上有一个容器 container-2，它的 IP 地址是 100.96.2.3，对应的 docker0 网桥 的地址是:100.96.2.1/24。

现在的任务，就是让 container-1 访问 container-2。

container-1 容器里的进程发起的 IP 包，其源地址就是 100.96.1.2，目的地址就是 100.96.2.3。由于目的地址 100.96.2.3 并不在 Node 1 的 docker0 网桥的网段里，所以这个 IP 包 会被交给默认路由规则，通过容器的网关进入 docker0 网桥(如果是同一台宿主机上的容器间通 信，走的是直连规则)，从而出现在宿主机上。这个 IP 包的下一个目的地，就取决于宿主机上的路由规则了。此时，Flannel 已经在宿主 机上创建出了一系列的路由规则

由于我们的 IP 包的目的地址是 100.96.2.3，它匹配不到本机 docker0 网桥对应的 100.96.1.0/24 网段，只能匹配到第二条、也就是 100.96.0.0/16 对应的这条路由规则，从而进入 到一个叫作 flannel0 的设备中。

 flannel0 设备的类型就比较有意思了:它是一个 TUN 设备(Tunnel 设备)。
在 Linux 中，TUN 设备是一种工作在三层(Network Layer)的虚拟网络设备。TUN 设备的功能
非常简单，即:**在操作系统内核和用户应用程序之间传递 IP 包。**


当操作系统将一个 IP 包发送给 flannel0 设备之后，flannel0 就会把这个 IP 包，交给创建这个设备的应用程序，也就是 Flannel 进程。这是一个从内核态(Linux 操作系统) 向用户态(Flannel 进程)的流动方向。
反之，如果 Flannel 进程向 flannel0 设备发送了一个 IP 包，那么这个 IP 包就会出现在宿主机网络 栈中，然后根据宿主机的路由表进行下一步处理。这是一个从用户态向内核态的流动方向。
所以，当 IP 包从容器经过 docker0 出现在宿主机，然后又根据路由表进入 flannel0 设备后，宿主 机上的 flanneld 进程(Flannel 项目在每个宿主机上的主进程)，就会收到这个 IP 包。然后， flanneld 看到了这个 IP 包的目的地址，是 100.96.2.3，就把它发送给了 Node 2 宿主机。

*flanneld 又是如何知道这个 IP 地址对应的容器，是运行在 Node 2 上的呢?*
这里，就用到了 Flannel 项目里一个非常重要的概念:子网(Subnet)。

在由 Flannel 管理的容器网络里，一台宿主机上的所有容器，都属于该宿主机被分配的一 个“子网”。在我们的例子中，Node 1 的子网是 100.96.1.0/24，container-1 的 IP 地址是 100.96.1.2。Node 2 的子网是 100.96.2.0/24，container-2 的 IP 地址是 100.96.2.3。

而这些子网与宿主机的对应关系，正是保存在 Etcd 当中，如下所示:

```
$ etcdctl ls /coreos.com/network/subnets
2 /coreos.com/network/subnets/100.96.1.0-24
3 /coreos.com/network/subnets/100.96.2.0-24
4 /coreos.com/network/subnets/100.96.3.0-24
```

Flannel UDP 模式提供的其实是一个三层的 Overlay 网络，即:它首先对发出端的 IP 包进行 UDP 封装，然后在接收端进行解封装拿到原始的 IP 包，进而把这个 IP 包转发给目标容 器。这就好比，Flannel 在不同宿主机上的两个容器之间打通了一条“隧道”，使得这两个容器可 以直接使用 IP 地址进行通信，而无需关心容器和宿主机的分布情况。

**性能原因**

* 第一次:用户态的容器进程发出的 IP 包经过 docker0 网桥进入内核态;
* 第二次:IP 包根据路由表进入 TUN(flannel0)设备，从而回到用户态的 flanneld 进程; 第三次:flanneld 进行 UDP 封包之后重新进入内核态，将 UDP 包通过宿主机的 eth0 发出去。
* 此外，我们还可以看到，Flannel 进行 UDP 封装(Encapsulation)和解封装(Decapsulation) 的过程，也都是在用户态完成的。在 Linux 操作系统中，上述这些上下文切换和用户态操作的代价 其实是比较高的，这也正是造成 Flannel UDP 模式性能不好的主要原因。


#### Flannel VXLAN

VXLAN，即 Virtual Extensible LAN(虚拟可扩展局域网)，是 Linux 内核本身就支持的一种网络 虚似化技术。所以说，VXLAN 可以完全在内核态实现上述封装和解封装的工作，从而通过与前面 相似的“隧道”机制，构建出覆盖网络(Overlay Network)。
VXLAN 的覆盖网络的设计思想是:在现有的三层网络之上，“覆盖”一层虚拟的、由内核 VXLAN 模块负责维护的二层网络，使得连接在这个 VXLAN 二层网络上的“主机”(虚拟机或者容器都可 以)之间，可以像在同一个局域网(LAN)里那样自由通信。当然，实际上，这些“主机”可能分 布在不同的宿主机上，甚至是分布在不同的物理机房里。
而为了能够在二层网络上打通“隧道”，VXLAN 会在宿主机上设置一个特殊的网络设备作为“隧 道”的两端。这个设备就叫作 VTEP，即:VXLAN Tunnel End Point(虚拟隧道端点)。
而 VTEP 设备的作用，其实跟前面的 flanneld 进程非常相似。只不过，它进行封装和解封装的对 象，是二层数据帧(Ethernet frame);而且这个工作的执行流程，全部是在内核里完成的(因为VXLAN 本身就是 Linux 内核中的一个模块)。

我们的 container-1 的 IP 地址是 10.1.15.2，要访问的 container-2 的 IP 地址是 10.1.16.3。
那么，与前面 UDP 模式的流程类似，当 container-1 发出请求之后，这个目的地址是 10.1.16.3 的 IP 包，会先出现在 docker0 网桥，然后被路由到本机 flannel.1 设备进行处理。也就是说，来 到了“隧道”的入口。为了方便叙述，我接下来会把这个 IP 包称为“原始 IP 包”。

为了能够将“原始 IP 包”封装并且发送到正确的宿主机，VXLAN 就需要找到这条“隧道”的出 口，即:目的宿主机的 VTEP 设备。
而这个设备的信息，正是每台宿主机上的 flanneld 进程负责维护的。

当 Node 2 启动并加入 Flannel 网络之后，在 Node 1(以及所有其他节点)上，flanneld 就会添加一条如下所示的路由规则:
```
$ route -n
Kernel IP routing table
Destination    Gateway          Genmask       Flags metric ref      use interface
10.1.16.0     10.1.16.0       255.255.255.0    UG    0      0        0 Flannel.1
```
凡是发往 10.1.16.0/24 网段的 IP 包，都需要经过 flannel.1 设备发出，并 且，它最后被发往的网关地址是:10.1.16.0。

为了方便叙述，接下来我会把 Node 1 和 Node 2 上的 flannel.1 设备分别称为“源 VTEP 设 备”和“目的 VTEP 设备”。
而这些 VTEP 设备之间，就需要想办法组成一个虚拟的二层网络，即:通过二层数据帧进行通信。
所以在我们的例子中，“源 VTEP 设备”收到“原始 IP 包”后，就要想办法把“原始 IP 包”加上 一个目的 MAC 地址，封装成一个二层数据帧，然后发送给“目的 VTEP 设备”(当然，这么做还 是因为这个 IP 包的目的地址不是本机)。
这里需要解决的问题就是:**目的 VTEP 设备”的 MAC 地址是什么?**
此时，根据前面的路由记录，我们已经知道了“目的 VTEP 设备”的 IP 地址。而要根据三层 IP 地 址查询对应的二层 MAC 地址，这正是 ARP(Address Resolution Protocol )表的功能。



### Kubernetes 网络模型

Kubernetes 是通过一个叫作 CNI 的接口，维护了一个单独的网桥来代替 docker0。这个网桥 的名字就叫作:CNI 网桥，它在宿主机上的设备名称默认是:cni0。

Kubernetes 为 Flannel 分配的子网范围是 10.244.0.0/16。这个参数可以在部署的时 候指定，比如:
*$ kubeadm init --pod-network-cidr=10.244.0.0/16*

也可以在部署完成后，通过修改 kube-controller-manager 的配置文件来指定。

假设 Infra-container-1 要访问 Infra-container-2(也就是 Pod-1 要访问 Pod-2)， 这个 IP 包的源地址就是 10.244.0.2，目的 IP 地址是 10.244.1.3。而此时，Infra-container-1 里的 eth0 设备，同样是以 Veth Pair 的方式连接在 Node 1 的 cni0 网桥上。所以这个 IP 包就 会经过 cni0 网桥出现在宿主机上。

CNI 网桥只是接管所有 CNI 插件负责的、即 Kubernetes 创建的容器 (Pod)。而此时，如果你用 docker run 单独启动一个容器，那么 Docker 项目还是会把这个 容器连接到 docker0 网桥上。所以这个容器的 IP 地址，一定是属于 docker0 网桥的 172.17.0.0/16 网段。

Kubernetes 之所以要设置这样一个与 docker0 网桥功能几乎一样的 CNI 网桥，主要原因包括 两个方面:
* 一方面，Kubernetes 项目并没有使用 Docker 的网络模型(CNM)，所以它并不希望、也 不具备配置 docker0 网桥的能力;
* 另一方面，这还与 Kubernetes 如何配置 Pod，也就是 Infra 容器的 Network Namespace 密切相关。

CNI 的设计思想，就是:Kubernetes 在启动 Infra 容器之后，就可以直接调用 CNI 网络 插件，为这个 Infra 容器的 Network Namespace，配置符合预期的网络栈。



1. 所有容器都可以直接使用 IP 地址与其他容器通信，而无需使用 NAT。
2. 所有宿主机都可以直接使用 IP 地址与所有容器通信，而无需使用 NAT。反之亦然。
3. 容器自己“看到”的自己的 IP 地址，和别人(宿主机或者容器)看到的地址是完全一样 的。
