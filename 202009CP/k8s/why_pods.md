#### docker

Docker本质是进程，K8S就是操作系统，POD是虚拟机

* Namespace做隔离
* Cgroups做限制
* rootfs做文件系统

*pstree -g*

展示系统中正在运行的进程的树状结构。一个操作系统中，进程并不是单独运行，而是以进程组的方式，有原则地组织在一起。

K8S就是将进程组的概念映射到了容器技术中。


#### 为什么需要pod

因为K8S中类似与进程组概念的存在，不同进程中可能存在互相依赖，所以将POD作为了Kubernetes中原子调度单位，K8S项目的调度器，是统一按照pod而不是容器的资源需求进行计算的。

imklog、imuxsock和main可以组成三个容器的pod。

* 互相之间会发生直接的文件交换
* 使用localhost或者socket文件进行本地通信
* 会发生非常频繁的远程调用
* 需要共享某些linux namespace


**并不是所有有关系的容器都属于同一pod**


#### pod：容器设计模式，它只是一个逻辑概念

K8S真正处理的还是宿主机操作系统上Linux容器的Namespace和Cgroups，而并不存在一个所谓的pod边界或者隔离环境。

**pod本质上是一组共享了某些资源的容器**，Pod里所有容器，共享同一个Network Namespace，并且可以声明共享同一个volume

POD的实现需要使用一个中间infra容器，它总是第一个被创建，其他容器通过Join network namespace的方式，与infra容器关联在一起。

对于POD里所有容器：

* 它们可以直接使用localhost通信
* 它们看到的网络设备跟Infra容器看到的完全一样
* 一个Pod只有一个IP地址，也就是这个Pod的network namespace对应的IP地址
* 其他网络资源，都是一个Pod一份，并且被该Pod中所有容器共享
* Pod的生命周期只跟infra容器一致，与其他容器无关

**War包和Tomcat服务器**   sidecar，容器组合方式

将war包和Tomcat分别做成镜像，然后把他们作为一个Pod里两个容器组合在一起。

* Init container 容器都会比spec.containers定义的用户容器先启动，并且它们会逐一启动，直到他们都启动并且退出了，用户容器才会启动
```
apiVersion: v1
kind: Pod
metadata:
  name: javaweb-2
spec:
  initContainers:
    - image: sample:v2
      name: war
      # 将war包拷贝到/app目录下，并将/app目录挂载为app-volume
      command: ["cp", "/sample.war", "/app"]
      volumeMounts:
        - mountPath: /app
          name: app-volume
  containers:
    - image: tomcat:7.0
      name: tomcat
      command: ["sh", "-c", "/root/apache-tomcat-7.0.42-v2/bin/start.sh"]
      # 因为tomcat也挂载了app-volume，所以它启动之后webapps肯定会存在一个sample.war包
      volumeMounts:
        - mountPath: /root/apache-tomcat-7.0.42/webapps
          name: app-volume
      ports:
        - containerPort: 8080
          hostPost: 8001
  volumes:
    - name: app-volume
      emptyDir: {}
```



#### POD主要字段

* NodeSelector：供用户将Pod与Node进行绑定的字段
```
spec:
  nodeSelector:
  disktype: ssd
```

* NodeName: 一旦Pod这个字段被赋值，K8S就会认为这个Pod已经经过了调度，调度的结果就是赋值节点名字。

* HostAlias：定义了Pod的hosts文件 /etc/hosts里的内容
```
spec:
  hostAliases:
  - ip: "10.1.2.3"
    hostNames:
    - "foo.remote"
    - "bar.remote"
```

tty: Linux给用户提供一个常驻小程序，用于接收用户的标准输入，返回操作系统的标准输出
stdin： 标准输入流

* container
- image
- command 启动命令
- workingDir： 容器工作目录
- Ports：容器开放的端口
- volumeMounts：容器要挂载的volume
- **imagePullPolicy**：定义了镜像拉取策略
- **LifeCycle**：container lifecycle hooks
```
spec:
  containers:
  - name: lifecycle-demo-container
    image: nginx
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo hello from the postStart handler > /usr/share/message"]
      preStop:
        exec:
          command: ["/usr/sbin/nginx", "-s", "quit"]
```
-- postStart: 在容器启动之后，立刻执行的一个操作，如果PostStart执行超时或者错误，K8S会在该Pod的Events中报出该容器启动失败的信息。
-- preStop：容器被杀死之前，会阻塞当前的容器杀死流程，知道这个hook定义操作完成之后，才允许容器被杀死




#### Pod生命周期

* Pending：pod的YML文件已经提交给K8S，API对象已经被创建并且保存在ETCD中，但是因为某些原因这个Pod不能创建成功
* Running：这个状态下Pod已经调度成功，跟某一具体节点绑定，其包含的容器都已经创建成功，并且至少有一个正在运行中。
* Succeeded：这个状态意味着Pod中的容器都已经正常运行完毕，并且已经推出。一次性任务中比较常见
* Failed：Pod中至少有一个容器以不正常的状态退出
* Unknown：异常状态，意味着Pod的状态不能持续地被kubelet汇报给kube-apiserver，有可能是主从节点间通信出了问题。



#### projected-volume

K8S中存在几种特殊的volume，它们存在的意义不是为了存放容器里的数据，也不是用来进行容器和宿主机的数据交换。这些volume的作用是为容器提供预先定义好的数据。

Projected volume
* Secret：作用是把Pod想要访问的数据存放到ETCD中，之后就可以通过在Pod中挂在Volume的方式访问这些secret中保存的信息。

```
apiVersion: v1
kind: Pod
metadata:
  name: projected-volume
spec:
  containers:
  - name: test-secret-volume
    image: busybox
    args:
    - sleep
    - "86400"
    volumeMounts:
    - name: mysql-cred
      mountPath: "/projected-volume"
      readOnly: true
  volumes:
  - name: mysql-cred
    projected:
      sources:
      - secret:
          name: user
      - secret:
          name: pass

$kubectl create secret generic user --from-file=./username.txt
$kubectl create secret generic pass --from-file=./password.txt
```

* Configmap: 用法和secrets类似，ConfigMap保存是不需要加密的

```
$ kubectl create configmap ui-config --from-file=example/ui.properties
```

* Downward API：让Pod里的容器能够直接获取这个Pod API对象本身的信息

```
apiVersion: v1
kind: Pod
metadata:
  name: kubernetes-downwardapi-volume-example
  labels:
    zone: us-est-coast
    cluster: test-cluster1
    rack: rack-22
  annotations:
    build: two
    builder: john-doe
spec:
  containers:
    - name: client-container
      image: k8s.gcr.io/busybox
      command: ["sh", "-c"]
      args:
      - while true; do
          if [[ -e /etc/podinfo/labels ]]; then
            echo -en '\n\n'; cat /etc/podinfo/labels; fi;
          if [[ -e /etc/podinfo/annotations ]]; then
            echo -en '\n\n'; cat /etc/podinfo/annotations; fi;
          sleep 5;
        done;
      volumeMounts:
        - name: podinfo
          mountPath: /etc/podinfo
          readOnly: false
  volumes:
    - name: podinfo
      downwardAPI:
        items:
          - path: "labels"
            fieldRef:
              fieldPath: metadata.labels
          - path: "annotations"
            fieldRef:
              fieldPath: metadata.annotations

```
声明了一个projected volume，volume数据来源是Downward api，声明了要暴露Pod的metadata.labels信息给容器。当前Pod的labels字段的值，会被kubernetes自动挂载成为额容器中的/etc/podinfo/labels文件。

* ServiceAccountToken: 特殊权限的Secret

一旦pod创建完成，容器里的应用就可以直接从这个默认的ServiceAccountToken的挂在目录里访问到授权信息和文件。路径：**/var/run/secrets/kubernetes.io/serviceaccount**，程序只要加载这个目录下的文件，就可以访问并且操作Kubernetes API。



#### 容器健康检查和恢复机制

**Probe**

Liveness probe
```
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5

```

* 只要Pod的restartPolicy制定的策略允许重启一场的容器，那么这个pod就会保持Running状态，并进行容器重启
* 对于包含多个容器的Pod，只有它里面所有怼额容器都进入异常状态之后，Pod才会进行failed状态


HTTP liveness HTTP request
```
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/liveness
    args:
    - /server
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3

```
