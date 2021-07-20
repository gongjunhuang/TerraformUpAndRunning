#### Pod 本质

Pod 是在 Kubernetes 集群中运行部署应用或服务的最小单元，它是可以支持多容器的。Pod 的设计理念是支持多个容器在一个 Pod 中共享网络地址和文件系统，可以通过进程间通信和文件共享这种简单高效的方式组合完成服务。
对容器的进一步抽象封装；容器的升级版，对容器进行了组合，添加了更多的属性和字段

目前 Kubernetes 中的业务主要可以分为长期伺服型（long-running）、批处理型（batch）、节点后台支撑型（node-daemon）和有状态应用型（stateful application）；分别对应的Pod控制器为 Deployment、Job、DaemonSet 和 StatefulSet

```
apiVersion: apps/v1
kind: deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:   #PodTemplate
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9
        ports:
        - containerPort: 80
```
确保label为nginx的pod数量为2


#### kube-controller-manager

这是一系列控制器的集合

pkg/controller

* Deployment控制器从Etcd中获取到所有带有 “app：nginx”标签的pod，统计他们的数量，这是实际状态；
* Deployment对象的replicas字段的值是期望状态
* Deployment控制器将两个状态作比较，然后根据比较结果，确定是创建pod还是删除已有pod

**Reconcile** 调谐



#### Deployment
Pod的水平扩展、收缩   horizontal scaling out/in

**Deployment的控制器，实际上控制的是ReplicaSet的数目，以及每个ReplicaSet的属性**
一个应用的版本，对应的正式一个RS；而这个版本应用的Pod的数量，则由ReplicaSet通过它自己的控制器来保证。

**应用版本和ReplicaSet一一对应**

rolling update:  replicaset
```
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-set
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.7.9

```


```
$ kubectl create -f nginx-deployment.yml --record

# 扩展与收缩
$ kubectl scale deployment nginx-deployment --replicas=4

# 查看状态
$ kubectl get deployments

# 实时查看deployment对象的状态变化
$ kubectl rollout status deployment/nginx-deployment

# 查看控制的replicaset
$ kubectl get rs

# kubectl edit

# 回滚
$ kubectl rollout undo deployment/nginx-deployment
$ kubectl rollout history deployment/nginx-deployment

# 暂停/恢复
$ kubectl rollout pause
$ kubectl rollout resume
```


#### 滚动更新策略 RollingUpdate
```
spec:
...
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
```
