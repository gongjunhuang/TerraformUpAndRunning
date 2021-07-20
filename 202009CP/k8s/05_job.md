#### Basic knowledge

* LRS: Long running service    长作业/计算业务
* Batch Jobs   离线业务

```
piVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  parallelism: 2
  completions: 4
  template:
    spec:
      containers:
        - name: pi
          image: resouer/ubuntu-bc
          command: ["sh", "-c", "echo scale=10000; 4*a(1)' | bc -l "]
      restartPolicy: Never
  backoffLimit: 4
```

#### Job controller

首先，Job Controller 控制的对象，直接就是 Pod。
其次，Job Controller 在控制循环中进行的调谐(Reconcile)操作，是根据实际在 Running 状态 Pod 的数目、已经成功退出的 Pod 的数目，以及 parallelism、completions 参数的值共 同计算出在这个周期里，应该创建或者删除的 Pod 数目，然后调用 Kubernetes API 来执行这 个操作。


#### 如何使用Job

* 外部管理器 +Job 模板

把 Job 的 YAML 文件定义为一个“模板”，然后用一个外部工具控制 这些“模板”来生成 Job

```
apiVersion: batch/v1
kind: Job
metadata:
name: process-item-$ITEM labels:
    jobgroup: jobexample
spec:
  template:
    metadata:
      name: jobexample
      labels:
        jobgroup: jobexample
    spec:
      containers: - name: c
        image: busybox
        command: ["sh", "-c", "echo Processing item $ITEM && sleep 5"]
      restartPolicy: Never
```

在这个 Job 的 YAML 里，定义了 $ITEM 这样的“变量”.

在控制这种 Job 时，我们只要注意如下两个方面即可:
1. 创建 Job 时，替换掉 $ITEM 这样的变量;
2. 所有来自于同一个模板的 Job，都有一个 jobgroup: jobexample 标签，也就是说这一组 Job 使用这样一个相同的标识。

```
$ for i in apple banana cherry
do
  cat job-tmpl.yml | sed "s/\$ITEM/$i/" > job-$i.yml
done
```

* 拥有固定任务数目的并行 Job

work queue

```
apiVersion: batch/v1
kind: Job
metadata:
  name: job-wq-1
spec:
  completions: 8
  parallelism: 2
  template:
    metadata:
      name: job-wq-1
    spec:
      containers:
        - name: c
          image: myrepo/job-wq-1
          env:
            - name: BROKER_URL
              value: amqp://guest:guest@rabbitmq-service:5672
            - name: QUEUE
              value: job1
      restartPolicy: OnFailure
```

我选择充当工作队列的是一个运行在 Kubernetes 里的 RabbitMQ。所以，我 们需要在 Pod 模板里定义 BROKER_URL，来作为消费者。
所以，一旦你用 kubectl create 创建了这个 Job，它就会以并发度为 2 的方式，每两个 Pod 一 组，创建出 8 个 Pod。每个 Pod 都会去连接 BROKER_URL，从 RabbitMQ 里读取任务，然后 各自进行处理。

* 指定并行度(parallelism)，但不设置固定的 completions 的值。

```
apiVersion: batch/v1
kind: Job
metadata:
name: job-wq-2 spec:
  parallelism: 2
  template:
    metadata:
      name: job-wq-2
    spec:
      containers:
        - name: c
          image: gcr.io/myproject/job-wq-2
          env:
            - name: BROKER_URL
              value: amqp://guest:guest@rabbitmq-service:5672
            - name: QUEUE
              value: job2
      restartPolicy: OnFailure
```

#### Cron Job

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            name: hello
            image: busybox
            args:
              - /bin/sh
              - -c
              - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```

在这个 YAML 文件中，最重要的关键词就是jobTemplate。看到它，你一定恍然大悟，原来 CronJob 是一个 Job 对象的控制器(Controller)


**Cron 表达式中的五个部分分别代表:分钟、小时、日、月、星期。**

需要注意的是，由于定时任务的特殊性，很可能某个 Job 还没有执行完，另外一个新 Job 就产 生了。这时候，你可以通过 spec.concurrencyPolicy 字段来定义具体的处理策略。比如:
1. concurrencyPolicy=Allow，这也是默认情况，这意味着这些 Job 可以同时存在;
2. concurrencyPolicy=Forbid，这意味着不会创建新的 Pod，该创建周期被跳过;
3. concurrencyPolicy=Replace，这意味着新产生的 Job 会替换旧的、没有执行完的 Job。



#### 声明式API

**kubectl apply**

kubectl replace 的执行过程，是使用新的 YAML 文件中的 API 对象，替换原有的 API 对象;而kubectl apply，则是执行了一个对原有 API 对象的 PATCH 操
这意味着 kube-apiserver 在响应命令式请求(比如，kubectl replace)的时候， 一次只能处理一个写请求，否则会有产生冲突的可能。而对于声明式请求(比如，kubectl apply)，一次能处理多个写操作，并且具备 Merge 能力。


* 首先，所谓“声明式”，指的就是我只需要提交一个定义好的 API 对象来“声明”，我所期 望的状态是什么样子。

* 其次，“声明式 API”允许有多个 API 写端，以 PATCH 的方式对 API 对象进行修改，而无 需关心本地原始 YAML 文件的内容。
* 最后，也是最重要的，有了上述两个能力，Kubernetes 项目才可以基于对 API 对象的增、 删、改、查，在完全无需外界干预的情况下，完成对“实际状态”和“期望状态”的调谐 (Reconcile)过程。


#### Istio

Istio 最根本的组件，是运行在 每一个应用 Pod 里的 Envoy 容器。
这个 Envoy 项目是 Lyft 公司推出的一个高性能 C++ 网络代理，也是 Lyft 公司对 Istio 项目的 唯一贡献。
而 Istio 项目，则把这个代理服务以 sidecar 容器的方式，运行在了每一个被治理的应用 Pod 中。我们知道，Pod 里的所有容器都共享同一个 Network Namespace。所以，Envoy 容器就 能够通过配置 Pod 里的 iptables 规则，把整个 Pod 的进出流量接管下来。
这时候，Istio 的控制层(Control Plane)里的 Pilot 组件，就能够通过调用每个 Envoy 容器的 API，对这个 Envoy 代理进行配置，从而实现微服务治理。

Istio 项目使用的，是 Kubernetes 中的一个非常重要的功能，叫作 *Dynamic Admission Control*。

在 Kubernetes 项目中，当一个 Pod 或者任何一个 API 对象被提交给 APIServer 之后，总有一 些“初始化”性质的工作需要在它们被 Kubernetes 项目正式处理之前进行。比如，自动为所有 Pod 加上某些标签(Labels)。
而这个“初始化”操作的实现，借助的是一个叫作 Admission 的功能。它其实是 Kubernetes 项目里一组被称为 Admission Controller 的代码，可以选择性地被编译进 APIServer 中，在 API 对象创建之后会被立刻调用到。
但这就意味着，如果你现在想要添加一些自己的规则到 Admission Controller，就会比较困 难。因为，这要求重新编译并重启 APIServer。显然，这种使用方法对 Istio 来说，影响太大 了。
所以，Kubernetes 项目为我们额外提供了一种“热插拔”式的 Admission 机制，它就是 Dynamic Admission Control，也叫作:**Initializer**。

**Istio 要做的，就是编写一个用来为 Pod“自动注入”Envoy 容器的 Initializer**

* Istio 会将这个 Envoy 容器本身的定义，以 ConfigMap 的方式保存在 Kubernetes 当 中。这个 ConfigMap(名叫:envoy-initializer)的定义如下所示:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-initializer
data:
  config: |
    containers:
      - name: envoy
        image: lyft/envoy:845747db88f102c0fd262ab234308e9e22f693a1 command: ["/usr/local/bin/envoy"]
        args:
          - "--concurrency 4"
          - "--config-path /etc/envoy/envoy.json"
          - "--mode serve"
        ports:
          - containerPort: 80
            protocol: TCP
        resources:
          limits:
            cpu: "1000m"
            memory: "512Mi"
          requests:
            cpu: "100m"
            memory: "64Mi"
        volumeMounts:
          - name: envoy-conf
            mountPath: /etc/envoy
      volumes:
        - name: envoy-conf
          configMap:
            name: envoy
```

* 接下来，Istio 将一个编写好的 Initializer，作为一个 Pod 部署在 Kubernetes 中

```
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: envoy-initializer
  name: envoy-initializer
spec:
  containers:
    - name: envoy-initializer
      image: envoy-initializer:0.0.1
      imagePullPolicy: Always
```


Kubernetes 的控制器，实际上就是一个“死循环”:它不断地获取“实际状态”，然后与“期 望状态”作对比，并以此为依据决定下一步的操作。
而 Initializer 的控制器，不断获取到的“实际状态”，就是用户新创建的 Pod。而它的“期望 状态”，则是:这个 Pod 里被添加了 Envoy 容器的定义。

这个 envoy-initializer 使用的 envoy-initializer:0.0.1 镜像，就是一个事先编写 好的“自定义控制器”(Custom Controller), Initializer 的控制器，不断获取到的“实际状态”，就是用户新创建的 Pod。而它的“期望 状态”，则是:这个 Pod 里被添加了 Envoy 容器的定义。


```
for {
  # get latest pod
  pod := client.GetLatestPod()
  # diff to see if it's been initialized
  if !isInitialized(pod) {
    doSomething(pod)...
  }
}
```

* 如果这个 Pod 里面已经添加过 Envoy 容器，那么就“放过”这个 Pod，进入下一个检查周 期。
* 而如果还没有添加过 Envoy 容器的话，它就要进行 Initialize 操作了，即:修改该 Pod 的 API 对象(doSomething 函数)。

```
func doSomething(pod) {
  cm := client.Get(configMap, "envoy-initializer")

  newPod := Pod{}
  newPod.Spec.Containers = cm.Containers
  newPod.Spec.Volumes = cm.Volumes

  // Generate patch
  patchBytes := strategicpatch.CreateTwoWayMergePatch(pod, newPod)

  // send patch request, modify this pod
  client.Patch(pod.Name, patchBytes)
}
```

有了这个 TwoWayMergePatch 之后，Initializer 的代码就可以使用这个 patch 的数据，调用 Kubernetes 的 Client，发起一个 PATCH 请求。
这样，一个用户提交的 Pod 对象里，就会被自动加上 Envoy 容器相关的字段。

Kubernetes 还允许你通过配置，来指定要对什么样的资源进行这个 Initialize 操作，比 如下面这个例子:
```
apiVersion: admissionregistration.k8s.io/v1alpha1
kind: InitializerConfiguration
metadata:
  name: envoy-config
initializers:
  // 这个名字必须至少包括两个 "."
  - name: envoy.initializer.kubernetes.io
    rules:
      - apiGroups:
        - "" // 前面说过， "" 就是 core API Group 的意思 apiVersions:
      - v1 resources:
        - pods

```

一旦这个 InitializerConfiguration 被创建，Kubernetes 就会把这个 Initializer 的名字，加 在所有新创建的 Pod 的 Metadata 上，格式如下所示:
```
...
metadata:
  initializers:
    pending:
      - name: envoy.initializer.kubernetes.io
```
每一个新创建的 Pod，都会自动携带了 metadata.initializers.pending 的 Metadata 信息。这个 Metadata，正是接下来 Initializer 的控制器判断这个 Pod 有没有执行过自己所负责的初 始化操作的重要依据(也就是前面伪代码中 isInitialized() 方法的含义)。


以上，就是关于 Initializer 最基本的工作原理和使用方法了。相信你此时已经明白，Istio 项目 的核心，就是由无数个运行在应用 Pod 中的 Envoy 容器组成的服务代理网格。这也正是 Service Mesh 的含义。



#### CRD Custom rsource definition

Network.yml
```
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: networks.samplecrd.k8s.io
spec:
  group: samplecrd.k8s.io
  version: v1
  names:
    kind: Network
    plural: networks
  scope: Namespaced
```
我指定了“group: samplecrd.k8s.io”“version: v1”这样的 API 信息，也指定了这个 CR 的资源类型叫作 Network，复数(plural)是 networks。
然后，我还声明了它的 scope 是 Namespaced，即:我们定义的这个 Network 是一个属于 Namespace 的对象，类似于 Pod。


example-network.yml
```
apiVersion: samplecrd.k8s.io/v1
kind: Network
metadata:
  name: example-network
spec:
  cidr: "192.168.0.0/16"
  gateway: "192.168.0.1"
```

可以看到，我想要描述“网络”的 API 资源类型是 Network;API 组是 samplecrd.k8s.io;API 版本是 v1。
那么，Kubernetes 又该如何知道这个 API(samplecrd.k8s.io/v1/network)的存在呢?
其实，上面的这个 YAML 文件，就是一个具体的“自定义 API 资源”实例，也叫 CR(Custom Resource)。而为了能够让 Kubernetes 认识这个 CR，你就需要让 Kubernetes 明白这个 CR 的宏观定义是什么，也就是 CRD(Custom Resource Definition)。


doc.go
```
// +k8s:deepcopy-gen=package

// +groupName=samplecrd.k8s.io 4

package v1
```

+<tag_name>[=value] 格式的注释，这就是 Kubernetes 进行代码 生成要用的 Annotation 风格的注释。

其中，+k8s:deepcopy-gen=package 意思是，请为整个 v1 包里的所有类型定义自动生成 DeepCopy 方法;而+groupName=samplecrd.k8s.io，则定义了这个包对应的 API 组的名 字。
可以看到，这些定义在 doc.go 文件的注释，起到的是全局的代码生成控制的作用，所以也被称 为Global Tags。
