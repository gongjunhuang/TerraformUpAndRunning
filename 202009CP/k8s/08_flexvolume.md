#### 存储插件：flexvolume & CSI

FlexVolume PV
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-flex-nfs
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  flexVolume:
    driver: "k8s/nfs"    
    fsType: "nfs"
    options:
      server: "10.10.0.25"
      share: "export"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    component: jenkins-master
  name: jenkins
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      component: jenkins-master
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: jenkins
        component: jenkins-master
    spec:
      containers:
      - image: registry.cn-hangzhou.aliyuncs.com/acs/jenkins-master:serverless-2.277
        imagePullPolicy: Always
        name: jenkins
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        - containerPort: 50000
          name: slavelistener
          protocol: TCP
        resources: {}
        volumeMounts:
          - mountPath: /var/jenkins_home
            name: jenkins-home
      volumes:
        - name: jenkins-home
          flexVolume:
            driver: "alicloud/nas"
            options:
              server: "309ac4820e-cjs6.cn-shanghai.nas.aliyuncs.com"
              path: "/k8s"
              vers: "3"
              options: "nolock,tcp,noresvport"
```

像这样的 FlexVolume 实现方式，虽然简单，但局限性却很大。
比如，跟 Kubernetes 内置的 NFS 插件类似，这个 NFS FlexVolume 插件，也不能支持 Dynamic Provisioning(即:为每个 PVC 自动创建 PV 和对应的 Volume)。除非你再为它编 写一个专门的 External Provisioner。
再比如，我的插件在执行 mount 操作的时候，可能会生成一些挂载信息。这些信息，在后面执 行 unmount 操作的时候会被用到。可是，在上述 FlexVolume 的实现里，你没办法把这些信 息保存在一个变量里，等到 unmount 的时候直接使用。


#### CSI container storage interface
