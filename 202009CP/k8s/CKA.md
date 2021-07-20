#### 1. RBAC
* 创建一个名为deployment-clusterrole的clusterrole,并且对该clusterrole只绑定对Deployment，Daemonset,Statefulset的创建权限
* 在指定namespace app-team1创建一个名为cicd-token的serviceaccount，并且将上一步创建clusterrole和该serviceaccount绑定

```
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: deployment-clusterrole
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "daemonsets", "statefulsets"]
    verbs: ["create"]
```

* 创建serviceaccount
```
kubectl -n app-team1 create serviceaccount cicd-token
```

* role binding
```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: deployment-rolebinding
  namespace: app-team1
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deployment-clusterrole
subjects:
  - kind: ServiceAccount
    name: cicd-token
    namespace: app-team1
```


#### 2. 指定node设置为不可用
* 将名为ek8s-node-1的node设置为不可用，并且重新调度该node上所有允许的pods

You can use kubectl drain to safely evict all of your pods from a node before you perform maintenance on the node

```
$ kubectl cordon ek8s-node-1
$ kubectl drain ek8s-node-1 --delete-local-data --ignore-daemonsets --force
```


#### 3. 升级k8s节点

* 现有的Kubernetes集权正在运行的版本是1.18.8，仅将主节点上的所有kubernetes控制面板和组件升级到版本1.19.0另外，在主节点上升级kubelet和kubectl

```
#将节点标记为不可调度状态
$ kubectl cordon k8s-master
#驱逐节点上面的pod
$ kubectl drain k8s-master--delete-local-data --ignore-daemonsets --force
#升级组件
$ apt-get install kubeadm=1.19.0-00 kubelet=1.19.0-00 kubectl=1.19.0-00
#重启kubelet服务
$ systemctl restart kubelet
#升级集群其他组件
$ kubeadm upgrade apply v1.19.0
```


#### 4. backup etcd to snapshot

首先，为运行在https://127.0.0.1:2379上的现有etcd实力创建快照并且将快照保存到/etc/data/etcd-snapshot.db
然后还原与/var/lib/backup/etcd-snapshot-previoys.db的现有先前快照
提供了以下TLS证书和密钥，已通过etcdctl连接到服务器

* etcd backup: https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/

```
#备份：要求备份到指定路径及指定文件名
$ ETCDCTL_API=3  etcdctl --endpoints="https://127.0.0.1:2379" --cacert=/opt/KUIN000601/ca.crt --cert=/opt/KUIN000601/etcd-client.crt --key=/opt/KUIN000601/etcd-client.key  snapshot save /etc/data/etcd-snapshot.db
#还原：要求使用指定文件进行还原
$ ETCDCTL_API=3  etcdctl --endpoints="https://127.0.0.1:2379" --cacert=/opt/KUIN000601/ca.crt --cert=/opt/KUIN000601/etcd-client.crt --key=/opt/KUIN000601/etcd-client.key   snapshot restore /var/lib/backup/etcd-snapshot-previoys.db

```


#### 5. network policy
创建networkPolicy，针对namespace internal下的pod，只允许同样namespace下的pod访问，并且可访问pod的9000端口。

不允许不是来自这个namespace的pod访问。

不允许不是监听9000端口的pod访问。

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: all-port-from-namespace
  namespace: internal
spec:
  podSelector:
    matchLabels: {}
  ingress:
  - from:
    - podSelector: {}
    ports:
    - port: 9000
```

Example
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: test-network-policy
  namespace: default
spec:
  podSelector:
    matchLabels:
      role: db
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - ipBlock:
        cidr: 172.17.0.0/16
        except:
        - 172.17.1.0/24
    - namespaceSelector:
        matchLabels:
          project: myproject
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 6379
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/24
    ports:
    - protocol: TCP
      port: 5978
```



#### 6. 创建svc
* reconfiguring the existing deployment front-end and add a port specification named http exposing port 80/tcp of the existing container nginx
* Create a new svc named front-end-svc exposing the container port http
* Configuring the new svc to also expose the individual pods via a nodeport on the nodes

```
$ kubectl expose deployment front-end --name=front-end-svc --port=80 --tarport=80 --type=NodePort
```


#### 7. Ingress

* 创建Ingress，将指定的Service的指定端口暴露出来

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pong
  namespace: ing-internal
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /hi
        pathType: Prefix
        backend:
          service:
            name: hi
            port:
              number: 5678
```


#### 8. 扩展deployment

* 将指定的deployment扩展至6个pods
* scale the deployment loadbalancer to 6 pods

```
$ kubectl scale --replicas=6 deployment/loadbalancer
```


#### 9. 将pod名称为nginx-kusc00401,pod镜像名称为nginx，部署到标签为disk-spinning的node节点上
```
apiVersion: v1
kind: pod
metadata:
  name: nginx-kusc00401
  labels:
    role: nginx-kusc00401
spec:
  nodeSelector:
    disk: spinning
  containers:
    - name: nginx
      image: nginx
```


#### 10. 检查节点ready状态数量

```
# 查询集群Ready节点数量
$ kubectl get node | grep -i ready
# 判断节点有误不可调度污点
$ kubectl describe nodes <nodeName>  |  grep -i taints | grep -i noSchedule

```


#### 11. 创建多个container的pod

* 创建一个拥有多个container容器的Pod:nginx+redis+memcached+consul

```
apiVersion: v1
kind: Pod
metadata:
  name: kucc1
spec:
  containers:
  - image: nginx
    name: nginx
  - image: redis
    name: redis
  - image: memchached
    name: memcached
  - image: consul
    name: consul
```


#### 12. 创建pv

* 创建一个名为app-config的PV，PV的容量为2Gi访问模式为ReadWriteMany，volume的类型为hostPath，位置为/src/app-config

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: app-config
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteMany
  hostPath:
    path: "/src/app-config"
```

#### 13. 创建pvc
1.使用指定storageclass创建一个pvc
2.大小为10M 将这个nginx容器的/var/nginx/html目录使用该pvc挂在出来
3.将这个pvc的大小从10M更新成70M

```
#创建PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 10Mi
  storageClassName: csi-hostpath-sc
#创建pod
---
apiVersion: v1
kind: Pod
metadata:
  name: web-server
spec:
  containers:
    - name: nginx
      image: nginx
      volumeMounts:
      - mountPath: "/usr/share/nginx/html"
        name: pv-volume
  volumes:
    - name: pv-volume
      persistentVolumeClaim:
        claimName: pv-volume

#通过kubectl edit pvc pv-volume可以进行修改容量
$ kubectl edit pvc pv-volume
```



#### 14. pod logs

* Monitor the logs of pod foobar and extract the lines corresponding to error unable-to-access-website and write them to /opt/KUTR00101/foobar

```
$ kubectl logs foobar | grep unable-to-access-website > /opt/KUTR00101/foobar
```

#### 15. sidecar container

* add a busybox sidecar container to the existing Pod legacy-app, the new sidecar container has to run the cmd: /bin/sh -c tail -n+1 -f /var/log/legacy-app.log
* use a volume mount named logs to make the file available to the sidecar container


```
$ kubectl get podname -o yaml

---
apiVersion: v1
kind: Pod
metadata:
  name: podname
spec:
  containers:
  - name: count
    image: busybox
    args:
    - /bin/sh
    - -c
    - >
      i=0;
      while true;
      do
        echo "$(date) INFO $i" >> /var/log/legacy-ap.log;
        i=$((i+1));
        sleep 1;
      done
    volumeMounts:
    - name: logs
      mountPath: /var/log
  - name: count-log-1
    image: busybox
    args: [/bin/sh, -c, 'tail -n+1 -f /var/log/legacy-ap.log']
    volumeMounts:
    - name: varlog
      mountPath: /var/log
  volumes:
  - name: logs
    emptyDir: {}

#验证：
$ kubectl logs <pod_name> -c <container_name>

```



#### 16. 查看CPU利用率最高的pod

* 查看Pod标签为name=cpu-user的CPU使用率并且把cpu使用率最高的pod名称写入/opt/KUTR00401/KUTR00401.txt文件里

```
$ kubectl top pod --sort-by=cpu --selector=name=cpu-user | awk 'NR==2{print $1}' >> /opt/KUTR00401/KUTR00401.txt

```


#### 17. 集群故障排除

```
# 连接到NotReady节点
$ ssh wk8s-node-0
获取权限
$ sudo -i
# 查看服务是否运行正常
$ systemctl status kubelet
#如果服务非正常运行进行恢复
$ systemctl start kubelet
#设置开机自启
$ systemctl enable kubelet

```
