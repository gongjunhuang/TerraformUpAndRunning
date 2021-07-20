#### Deployment 部署假设

假设一个应用所有Pod都是完全一样的，但是实际情况中，多个实例之间往往有依赖关系：主从关系，主备关系

这种实例之间有不对等关系，以及实例怼外部数据有依赖关系的应用，称为有状态应用 stateful application

#### statefulset 设计

* 拓扑状态。多个实例之间不是完全对等的关系。这些应用必须按照某些顺序启动
* 存储状态。多个实例分别绑定了不同的存储顺序

StatefulSet的核心功能就是记录这些状态，然后在Pod被重新创建时，能够为新Pod恢复这些状态。




#### Headless service

Service是Kubernetes中用来将一组pod暴露给外界访问的一种机制。例如一个Deployment有3个pod，就可以定义一个service，用户只要能访问到这个service，就能访问到某个具体pod。

如何访问这个serivce？
* 访问Service 的VIP（虚拟IP），如访问10.0.23.1，会把请求转发到service所代理的某个pod上
* 以Service的DNS方式。例如访问“my-svc.my-namespace.svc.cluster.local”这个dns，就可以访问my-svc代理的某一个pod

-- Normal service，访问“my-svc.my-namespace.svc.cluster.local”的时候解析到的就是my-svc这个service的VIP，后面流程就和VIP方式一致
-- Headless Service，这时候访问“my-svc.my-namespace.svc.cluster.local”解析到的就是my-svc代理的某一个Pod的IP地址。Headless不需要分配一个VIP，可以直接根据DNS记录解析出被代理的Pod的IP


```
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None    # headless 的定义
  selector:
    app: nginx
```

创建一个如上所示的headless service之后，所代理的所有Pod的IP地址，都会被绑定一个这个格式的DNS记录:
**<pod-name>.<svc-name>.<namespace>.svc.cluster.local**



#### StatefulSet如何使用DNS记录来维持Pod的拓扑状态？

```
apiVersion: app/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 2
  selectors:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.9.1
        ports:
        - containerPort: 80
          name: web
```

拓扑状态按照Pod的名字+编号的方式固定下来，把Pod的DNS记录作为固定并且唯一的访问入口。

*对于有状态应用的访问，必须使用DNS记录而不是IP，因为IP会变*



#### statefulset 存储状态

* Persistent Volume Claim

```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pv-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

生命Volume之后，在Pod中生命使用这个PVC

```
apiVerison: v1
kind: Pod
metadata:
  kind: pv-pod
spec:
  containers:
    - name: pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: pv-storage
  volumes:
    - name: pv-storage
      persistentVolumeClaim:
        claimName: pv-claim
```

对存储状态的管理：

```
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx # has to match .spec.template.metadata.labels
  serviceName: "nginx"
  replicas: 3 # by default is 1
  template:
    metadata:
      labels:
        app: nginx # has to match .spec.selector.matchLabels
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "my-storage-class"
      resources:
        requests:
          storage: 1Gi
```

**volumeClaimTemplates**说明被这个StatefulSet管理的Pod都会声明一个PVC。PVC是一种特殊的Volume，只不过一个PVC具体是什么类型的Volume，要在跟某个PV绑定之后才知道。PVC和PV的绑定得以实现的前提是运维人员已经在系统里创建好了符合条件的PV；或者K8S集群运行在公有云上，这样K8S就会通过Dynamic Provisioning的方式，自动为你创建与PVC匹配的PV。


* StatefulSet的控制器直接管理的是Pod。
* K8S通过Headless service，为这些有编号的Pod，在DNS服务器中生成带有同样编号的DNS记录。
* StatefulSet还未每个Pod分配并创建一个同样编号的PVC。K8S可以通过Persistent Volume机制为这个PVC绑定上对应的PV，从而保证每个Pod拥有一个独立的volume。这样即使Pod被删除，对应的PVC和PV仍然会保留下来。当Pod被重建之后，K8S会为它寻找同样编号的PVC，挂在这个PVC对应的Volume




#### 如何部署StatefulSet
