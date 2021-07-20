#### Role based access control

Authorization 授权


1. Role:角色，它其实是一组规则，定义了一组对 Kubernetes API 对象的操作权限。
2. Subject:被作用者，既可以是“人”，也可以是“机器”，也可以使你在 Kubernetes 里 定义的“用户”。
3. RoleBinding:定义了“被作用者”和“角色”的绑定关系。

ROLE
```
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: mynamespace
  name: example-role
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "watch", "list"]
```

namespace 逻辑隔离
$ kubectl get pods -n mynamespace


**RoleBinding**

```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-rolebinding
  namespace: mynamespace
subjects:
  - kind: User
    name: example-user
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: example-role
  apiGroup: rbac.authorization.k8s.io
```

Role 和 RoleBinding 对象都是 Namespaced 对象(Namespaced Object)，它们对权限的限制规则仅在它们自己的 Namespace 内有效，roleRef 也只能引用当 前 Namespace 里的 Role 对象。
对于非 Namespaced(Non-namespaced)对象(比如:Node)，或者，某一个 Role 想要作用于所有的 Namespace 的时候，我们又该如何去做授权呢?

**必须要使用 ClusterRole 和 ClusterRoleBinding 这两个组合**, 这两个 API 对 象的用法跟 Role 和 RoleBinding 完全一样。只不过，它们的定义里，没有了 Namespace 字 段

```
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-clusterrole
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "watch", "list"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-clusterrolebinding
subjects:
  - kind: User
    name: example-user
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: example-clusterrole
  apiGroup: rbac.authorization.k8s.io
```
上面的例子里的 ClusterRole 和 ClusterRoleBinding 的组合，意味着名叫 example-user 的用 户，拥有对所有 Namespace 里的 Pod 进行 GET、WATCH 和 LIST 操作的权限。

* rules字段所有权限：verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

* 在大多数时候，我们其实都不太使用“用户”这个功能，而是直接使用 Kubernetes 里的“内置用户”。这个由 Kubernetes 负责管理的“内置用户”，正是我们前面曾经提到过的: ServiceAccount。

```
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: mynamespace
  name: example-sa
```

我们通过编写 RoleBinding 的 YAML 文件，来为这个 ServiceAccount 分配权限:
```
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-rolebinding
  namespace: mynamespace
subjects:
  - kind: ServiceAccount
    name: example-sa
    namespace: mynamespace
roleRef:
  kind: Role
  name: example-role
  apiGroup: rbac.authorization.k8s.io
```

在这个 RoleBinding 对象里，subjects 字段的类型(kind)，不再是一个 User， 而是一个名叫 example-sa 的 ServiceAccount。而 roleRef 引用的 Role 对象，依然名叫 example-role

用户声明使用ServiceAccount：
```
apiVersion: v1
kind: Pod
metadata:
  namespace: mynamespace
  name: sa-token-test
spec:
  containers:
    - name: nginx
      image: nginx:1.7.9
  serviceAccountName: example-sa
```

在这个例子里，我定义了 Pod 要使用的要使用的 ServiceAccount 的名字是:example-sa。等这个 Pod 运行起来之后，我们就可以看到，该 ServiceAccount 的 token，也就是一个 Secret 对象，被 Kubernetes 自动挂载到了容器的 /var/run/secrets/kubernetes.io/serviceaccount 目录下


*system:kube-scheduler*的 ClusterRole，就会被绑定给 kube-system Namesapce 下名 叫 kube-scheduler 的 ServiceAccount，它正是 Kubernetes 调度器的 Pod 声明使用的 ServiceAccount。
除此之外，Kubernetes 还提供了四个预先定义好的 ClusterRole 来供用户直接使用:
1. cluster-amdin;
2. admin;
3. edit;
4. view。

角色(Role)，其实就是一组权限规则列表。而我们分配这 些权限的方式，就是通过创建 RoleBinding 对象，将被作用者(subject)和权限列表进行绑 定。另外，与之对应的 ClusterRole 和 ClusterRoleBinding，则是 Kubernetes 集群级别的 Role 和 RoleBinding，它们的作用范围不受 Namespace 限制。

而尽管权限的被作用者可以有很多种(比如，User、Group 等)，但在我们平常的使用中，最 普遍的用法还是 ServiceAccount。所以，Role + RoleBinding + ServiceAccount 的权限分配 方式是你要重点掌握的内容。我们在后面编写和安装各种插件的时候，会经常用到这个组合。
