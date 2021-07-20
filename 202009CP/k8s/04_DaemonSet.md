#### DaemonSet 容器化守护进程

DaemonSet 的主要作用，是让你在 Kubernetes 集群里，运行一个 Daemon Pod。 所以，这个 Pod 有如下三个特征:
1. 这个 Pod 运行在 Kubernetes 集群里的每一个节点(Node)上;
2. 每个节点上只有一个这样的 Pod 实例;
3. 当有新的节点加入 Kubernetes 集群后，该 Pod 会自动地在新节点上被创建出来;而当旧 节点被删除后，它上面的 Pod 也相应地会被回收掉。


作用：

1. 各种网络插件的 Agent 组件，都必须运行在每一个节点上，用来处理这个节点上的容器网络;
2. 各种存储插件的 Agent 组件，也必须运行在每一个节点上，用来在这个节点上挂载远程存储目录，操作容器的 Volume 目录;
3. 各种监控组件和日志组件，也必须运行在每一个节点上，负责这个节点上的监控信息和日志 搜集。

```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      # this toleration is to have the daemonset runnable on master nodes
      # remove it if your masters can't run pods
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers

```


DaemonSet Controller，首先从 Etcd 里获取所有的 Node 列表，然后遍历所有的 Node。这 时，它就可以很容易地去检查，当前这个 Node 上是不是有一个携带了 name=fluentd- elasticsearch 标签的 Pod 在运行。
而检查的结果，可能有这三种情况:
1. 没有这种 Pod，那么就意味着要在这个 Node 上创建这样一个 Pod;
2. 有这种 Pod，但是数量大于 1，那就说明要把多余的 Pod 从这个 Node 上删除掉;
3. 正好只有一个这种 Pod，那说明这个节点是正常的



#### nodeAffinity 创建新的pod
```
apiVersion: v1
kind: Pod
metadata:
  name: with-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: metadata.name
                operator: In
                values:
                  - node
```

DaemonSet 其实是一个非常简单的控制器。在它 的控制循环中，只需要遍历所有节点，然后根据节点上是否有被管理 Pod 的情况，来决定是否 要创建或者删除一个 Pod。
只不过，在创建每个 Pod 的时候，DaemonSet 会自动给这个 Pod 加上一个 nodeAffinity，从 而保证这个 Pod 只会在指定节点上启动。同时，它还会自动给这个 Pod 加上一个 Toleration，从而忽略节点的 unschedulable“污点”。

DaemonSet 使用 ControllerRevision，来保存和管理自己对应的“版本”。这 种“面向 API 对象”的设计思路，大大简化了控制器本身的逻辑，也正是 Kubernetes 项 目“声明式 API”的优势所在。
