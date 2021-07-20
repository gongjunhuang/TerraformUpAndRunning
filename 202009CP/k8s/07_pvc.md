#### Definition

* PV: persistent volume 持久化存储数据卷。PV 对象是由运维人员事先创建在 Kubernetes 集群里待用的

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 10.244.1.4
    path: "/"
```

* PVC: Persistent volume claim    Pod希望使用的持久化存储的属性，PVC 对象通常由开发人员创建;或者以 PVC 模板的方式成为 StatefulSet 的一部分，然后由 StatefulSet 控制器负责创建带编号的 PVC。

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs
spec:
  accessMods:
    - ReadWriteMany
  storageClassName: manual
  resources:
    requests:
      storage: 1Gi
```

而用户创建的 PVC 要真正被容器使用起来，就必须先和某个符合条件的 PV 进行绑定。这里要 检查的条件，包括两部分:
1. 第一个条件，当然是 PV 和 PVC 的 spec 字段。比如，PV 的存储(storage)大小，就必须 满足 PVC 的要求。
2. 第二个条件，则是 PV 和 PVC 的 storageClassName 字段必须一样。


在成功地将 PVC 和 PV 进行绑定之后，Pod 就能够像使用 hostPath 等常规类型的 Volume 一 样，在自己的 YAML 文件里声明使用这个 PVC 了:
```
apiVersion: v1
kind: Pod
metadata:
  labels:
    role: web-frontend
spec:
  containers:
    - name: web
      image: nginx
      ports:
        - name: web
          containerPort: 80
      volumeMounts:
        - name: nfs
          mountPath: "/usr/share/nginx/html"
  volumes:
    - name: nfs
      persistentVolumeClaim:
        claimName: nfs
```

Pod 需要做的，就是在 volumes 字段里声明自己要使用的 PVC 名字。接下来，等 这个 Pod 创建之后，kubelet 就会把这个 PVC 所对应的 PV，也就是一个 NFS 类型的 Volume，挂载在这个 Pod 容器内的目录上。


在 Kubernetes 中，实际上存在着一个专门处理持久化存储的控制器，叫作 Volume Controller。这个 Volume Controller 维护着多个控制循环，其中有一个循环，扮演的就是撮合 PV 和 PVC 的“红娘”的角色。它的名字叫作 PersistentVolumeController。

PersistentVolumeController 会不断地查看当前每一个 PVC，是不是已经处于 Bound(已绑 定)状态。如果不是，那它就会遍历所有的、可用的 PV，并尝试将其与这个“单身”的 PVC 进行绑定。这样，Kubernetes 就可以保证用户提交的每一个 PVC，只要有合适的 PV 出现，它 就能够很快进入绑定状态，从而结束“单身”之旅。

而所谓将一个 PV 与 PVC 进行“绑定”，其实就是将这个 PV 对象的名字，填在了 PVC 对象的 **spec.volumeName**字段上。所以，接下来 Kubernetes 只要获取到这个 PVC 对象，就一定能 够找到它所绑定的 PV。

**所谓容器的 Volume，其实就是将一个宿主机上的目录，跟一个容器里的目录绑定挂载在了 一起。**

而所谓的“持久化 Volume”，指的就是这个宿主机上的目录，具备“持久性”。即:这个目录 里面的内容，既不会因为容器的删除而被清理掉，也不会跟当前的宿主机绑定。这样，当容器被 重启或者在其他节点上重建出来之后，它仍然能够通过挂载这个 Volume，访问到这些内容。

大多数情况下，持久化 Volume 的实现，往往依赖于一个远程存储服务，比如:远程文 件存储(比如，NFS、GlusterFS)、远程块存储(比如，公有云提供的远程磁盘)等等。


#### how to persist the volume?

* Attach

当一个 Pod 调度到一个节点上之后，kubelet 就要负责为这个 Pod 创建它的 Volume 目录。 默认情况下，kubelet 为 Volume 创建的目录是如下所示的一个宿主机上的路径.

如果你的 Volume 类型是远程块存储，比如 Google Cloud 的 Persistent Disk(GCE 提供的远 程磁盘服务)，那么 kubelet 就需要先调用 Goolge Cloud 的 API，将它所提供的 Persistent Disk 挂载到 Pod 所在的宿主机上。

* Mount

Attach 阶段完成后，为了能够使用这个远程磁盘，kubelet 还要进行第二个操作，即:格式化 这个磁盘设备，然后将它挂载到宿主机指定的挂载点上。不难理解，这个挂载点，正是 Volume 的宿主机目录。


Mount 阶段完成后，这个 Volume 的宿主机目录就是一个“持久化”的目录了，容器在它里面 写入的内容，会保存在 Google Cloud 的远程磁盘中。

而如果你的 Volume 类型是远程文件存储(比如 NFS)的话，kubelet 的处理过程就会更简单 一些。

在具体的 Volume 插件的实现接口上，Kubernetes 分别给这两个阶段提供了两种 不同的参数列表:
1. 对于“第一阶段”(Attach)，Kubernetes 提供的可用参数是 nodeName，即宿主机的名 字。
2. 而对于“第二阶段”(Mount)，Kubernetes 提供的可用参数是 dir，即 Volume 的宿主 机目录。


#### Storage Class

Kubernetes 为我们提供了一套可以自动创建 PV 的机制，即:Dynamic Provisioning

Dynamic Provisioning 机制工作的核心，在于一个名叫 StorageClass 的 API 对象。
而 StorageClass 对象的作用，其实就是创建 PV 的模板。
具体地说，StorageClass 对象会定义如下两个部分内容:
* 第一，PV 的属性。比如，存储类型、Volume 的大小等等。
* 第二，创建这种 PV 需要用到的存储插件。比如，Ceph 等等。

假如我们的 Volume 的类型是 GCE 的 Persistent Disk 的话，运维人员就需要定义 一个如下所示的 StorageClass:
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: block-service
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
```

StorageClass 的 parameters 字段，就是 PV 的参数。比如:上面例子里的 type=pd- ssd，指的是这个 PV 的类型是“SSD 格式的 GCE 远程磁盘”。

有了 StorageClass 的 YAML 文件之后，运维人员就可以在 Kubernetes 里创建这个 StorageClass 了:
*$ kubectl create -f sc.yml*

作为应用开发者，我们只需要在 PVC 里指定要使用的 StorageClass 名字即可:
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim1
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: block-service
  resources:
    requests:
      storage: 1Gi
```

当我们通过 kubectl create 创建上述 PVC 对象之后，Kubernetes 就会调用 Google Cloud 的 API，创建出一块 SSD 格式的 Persistent Disk。然后，再使用这个 Persistent Disk 的信息，自 动创建出一个对应的 PV 对象。


有了 Dynamic Provisioning 机制，运维人员只需要在 Kubernetes 集群里创建出数量有限的 StorageClass 对象就可以了。这就好比，运维人员在 Kubernetes 集群里创建出了各种各样的 PV 模板。这时候，当开发人员提交了包含 StorageClass 字段的 PVC 之后，Kubernetes 就会 根据这个 StorageClass 创建出对应的 PV。


* PVC 描述的，是 Pod 想要使用的持久化存储的属性，比如存储的大小、读写权限等。
* PV 描述的，则是一个具体的 Volume 的属性，比如 Volume 的类型、挂载目录、远程存储 服务器地址等。
* StorageClass 的作用，则是充当 PV 的模板。并且，只有同属于一个 StorageClass 的 PV 和 PVC，才可以绑定在一起。



#### Local persistent volume 本地持久化存储

用户希望 Kubernetes 能够直接使用宿主机上的本地磁盘目录，而不依赖于远程存储 服务，来提供“持久化”的容器 Volume。这样做的好处很明显，由于这个 Volume 直接使用的是本地磁盘，尤其是 SSD 盘，它的读写性 能相比于大多数远程存储来说，要好得多。这个需求对本地物理服务器部署的私有 Kubernetes 集群来说，非常常见。

首先需要明确的是，Local Persistent Volume 并不适用于所有应用。事实上，它的适用 范围非常固定，比如:高优先级的系统应用，需要在多个不同节点上存储数据，并且对 I/O 较 为敏感。典型的应用包括:分布式数据存储比如 MongoDB、Cassandra 等，分布式文件系统 比如 GlusterFS、Ceph 等，以及需要在本地磁盘上进行大量数据缓存的分布式应用。

其次，相比于正常的 PV，一旦这些节点宕机且不能恢复时，Local Persistent Volume 的数据 就可能丢失。这就要求使用 Local Persistent Volume 的应用必须具备数据备份和恢复的能力， 允许你把这些数据定时备份在其他位置。

第一个难点在于:如何把本地磁盘抽象成 PV。

事实上，你绝不应该把一个宿主机上的目录当作 PV 使用。这是因为，这种本地目录的存储行为 完全不可控，它所在的磁盘随时都可能被应用写满，甚至造成整个宿主机宕机。而且，不同的本 地目录之间也缺乏哪怕最基础的 I/O 隔离机制。

所以，一个 Local Persistent Volume 对应的存储介质，一定是一块额外挂载在宿主机的磁盘或 者块设备(“额外”的意思是，它不应该是宿主机根目录所使用的主硬盘)。这个原则，我们可 以称为“一个 PV 一块盘”。

第二个难点在于:调度器如何保证 Pod 始终能被正确地调度到它所请求的 Local Persistent Volume 所在的节点上呢?

对于常规的 PV 来说，Kubernetes 都是先调度 Pod 到某个节点 上，然后，再通过“两阶段处理”来“持久化”这台机器上的 Volume 目录，进而完成 Volume 目录与容器的绑定挂载。对于 Local PV 来说，节点上可供使用的磁盘(或者块设备)，必须是运维人员提前准备 好的。它们在不同节点上的挂载情况可以完全不同，甚至有的节点可以没这种磁盘。

所以，这时候，调度器就必须能够知道所有节点与 Local Persistent Volume 对应的磁盘的关联 关系，然后根据这个信息来调度 Pod。我们可以称为“在调度的时候考虑 Volume 分布”。在 Kubernetes 的调度器里， 有一个叫作 VolumeBindingChecker 的过滤条件专门负责这个事情。在 Kubernetes v1.11 中，这个过滤条件已经默认开启了。

在开始使用 Local Persistent Volume 之前，你首先需要在集群里配置好磁盘或 者块设备。在公有云上，这个操作等同于给虚拟机额外挂载一个磁盘，比如 GCE 的 Local SSD 类型的磁盘就是一个典型例子。

本地PV创建：
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/vol1
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
          - key: kubernetes.io/hostname
            operator: In
            values:
              - node-1
```

这个 PV 的定义里:local 字段，指定了它是一个 Local Persistent Volume;而 path 字段，指定的正是这个 PV 对应的本地磁盘的路径，即:/mnt/disks/vol1。

这也就意味着如果 Pod 要想使用这个 PV，那它就必须运行在 node-1 上。所以，在 这个 PV 的定义里，需要有一个 nodeAffinity 字段指定 node-1 这个节点的名字。这样，调度 器在调度 Pod 的时候，就能够知道一个 PV 与节点的对应关系，从而做出正确的选择。这正是 Kubernetes 实现“在调度的时候就考虑 Volume 分布”的主要方法。

对应的storageclass

```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```


上面手动创建 PV 的方式，即 Static 的 PV 管理方式，在删除 PV 时需要按 如下流程执行操作:
1. 删除使用这个 PV 的 Pod;
2. 从宿主机移除本地磁盘(比如，umount 它);
ß3. 删除 PVC;
4. 删除 PV。
