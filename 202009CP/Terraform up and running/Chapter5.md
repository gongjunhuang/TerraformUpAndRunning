### 第五章：Terraform技巧和窍门：循环、IF语句、不停机部署和陷阱

Terraform是个声明式的语言。如第一章所说，用声明式语言写的基础设施即代码与程序性语言相比，提供有关实际部署内容的更准确视图，所以声明式代码更容易推理并且能让代码库更小。但是，一些类型的任务用声明式语言更难完成。

例如，因为声明式语言中很少有for循环，那么一个重复的逻辑，例如创建多个类似的资源，怎么样才能不依赖复制粘贴完成？如果声明式语言不支持if判断，那么将如何根据条件配置资源？最后，如何通过声明式语言表达内在的程序性想法，例如零停机时间部署？

幸运的是，Terraform提供了一些原型：一个元参数叫做*count*，一个生命周期代码块叫做*create_before_destroy*，一个三元运算符，以及很多的插补方法，可以使用这些原型实现for循环、if判断以及零停机部署。你可能不会经常使用这些语法，但是当你使用的时候，能够意识到什么是可以使用的以及哪里可能有陷阱是非常棒的。下面是本章中将要讨论的主题：

* 循环
* If语句
* If-else语句
* 零停机部署
* Terraform陷阱

**循环**

当我们自己创建VPC（virtual private network）的时候，需要创建虚拟交换机，如下所示，代码应该放在*live/global/vpc/main.tf*：

```
resource "alicloud_vpc" "vpc" {
  name       = "tf_test_foo"
  cidr_block = "172.16.0.0/12"
}

resource "alicloud_vswitch" "vsw" {
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = "172.16.0.0/21"
  availability_zone = "cn-beijing-b"
}
```

上面代码用*alicloud_switch*资源创建一个虚拟交换机。如果想要创建两个虚拟交换机该怎么做？在一般编程语言中，可能会用for循环来实现：
```
# 伪代码，Terraform中不能正常运行
for i=0; i< 2; i++ {
  resource "alicloud_vswitch" "vsw" {
    vpc_id            = alicloud_vpc.vpc.id
    cidr_block        = "172.16.0.0/21"
    availability_zone = "cn-beijing-b"
    name              = "public-switch"
  }
}
```

Terraform没有在语言中内置for循环或者其他传统的程序逻辑，所以类似上面这种的语法不会正常运行。但是基本上每种Terraform资源都有一种元参数叫做*count*，这个参数定义了要创建多少份同样的资源。因此，可以通过如下方式创建三个虚拟交换机：
```
variable "public_vswitch_cidrs" {
  type = list(string)
  default = ["172.16.0.0/24", "172.17.0.0/24"]
}

resource "alicloud_vswitch" "public_default" {
  count             = 2
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = var.public_vswitch_cidrs[count.index]
  name              = "public-vswitch"
}
```

上面代码还有个小问题就是所有的虚拟交换机的名字都一样，这会在创建资源的过程中抛出错误，因为资源的名称必须不同。如果使用传统的for循环，你可能会使用index来给每个资源赋予不同的名称：
```
# 伪代码，Terraform中不能正常运行
for i=0; i< 2; i++ {
  resource "alicloud_vswitch" "vsw" {
    vpc_id            = alicloud_vpc.vpc.id
    cidr_block        = "172.16.0.0/21"
    availability_zone = "cn-beijing-b"
    name              = "public-switch.{i}"
  }
}
```

在Terraform代码中也可以做类似的事情，可以使用*count.index*来获取循环中每个迭代的index：
```
resource "alicloud_vswitch" "public_default" {
  count             = 2
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = var.public_vswitch_cidrs[count.index]
  name              = "public-vswitch.{count.index}"
}
```

如果对上述代码运行*plan*命令，你可以看到输出中Terraform会创建2个虚拟交换机，每个交换机的名字都不相同：public-vswitch.0、public-vswitch.1以及public-vswitch.2。

显而易见的是，public-vswitch.0这样的名字不是非常好。如果将*count.index*与Terraform内置的插补语法相结合，就可以自定义循环中的每个迭代。例如，可以将虚拟交换机的名称定义为变量，在*live/global/vpc/var.tf*中加入一个输入变量：
```
variable "vswitch_names" {
  description = "Create VSwtich with these names"
  type        = list(string)
  default     = ["trinity", "morpheus"]
}
```

如果在Python等常见的编程语言中，如果对列表使用循环，可能像下面伪代码一样对循环中的index i进行操作：
```
for i=0; i<2; i++ {
  resource "alicloud_vswitch" "public_default" {
    name = var.vswitch_names[i]
  }
}
```

在Terraform中，可以通过*count*以及两个插补语法实现同样的效果：
```
element(LIST, INDEX)
length(LIST)
```

*element* 方法返回指定*LIST*中位于*INDEX*的元素，*length* 方法返回指定*LIST*中元素的数量（strings以及maps同样适用）。将这两个插补语法结合到一起，类似下面代码：
```
resource "alicloud_vswitch" "public_default" {
  count             = length(var.vswitch_names)
  vpc_id            = alicloud_vpc.vpc.id
  cidr_block        = var.public_vswitch_cidrs[count.index]
  name              = element(var.vswitch_names, count.index)
}
```

需要注意当前你在*resource*上使用*count*，这就变为多个资源，而不仅仅是单个资源。因为*alicloud_vswitch*是多个虚拟交换机，不同于以前用标准的语法*TYPE.NAME.ATTRIBUTE*获取资源的某个属性，当前需要用*INDEX*指定想要获取序列中哪个资源的相关属性：
```
TYPE.NAME.INDEX.ATTRIBUTE
```


例如，如果想要将其中一个虚拟交换机的ID作为输出变量，需要在*outputs.tf*中指定index：
```
output "trinity_id" {
  value = alicloud_vswitch.public_default.0.id
}
```

同样，如果想要输出所有虚拟交换机的ID，就用*代替index，需要注意的是，因为输出的是ID序列，因此需要用中括号将输出变量括住：
```
output "ids" {
  value = [alicloud_vswitch.public_default.*.id]
}
```

当运行*apply*命令的时候，就会看到*ids*显示在屏幕输出中。


**If语句**

如上文所示，可以使用*count*来实现基本的循环操作。下个部分我们将开始学习if语句并实现更加复杂的功能。

*简单的IF判断*

第四章中你创建了一个Terraform模块可以用来部署网络服务器集群，模块创建ASG、负载均衡SLB、安全组以及一些其他资源。模块没有直接创建的是自动弹缩规则，因为只需要在生产环境上控制集群的大小，所以直接将*alicloud_ess_scaling_rule*资源定义在生产环境中。有没有一种方式可以将*alicloud_ess_scaling_rule*定义在*webserver-cluster*模块中并有条件的创建这个资源呢？

可以通过下面方式来做。首先在输入变量*modules/services/webserver-cluster/vars.tf*中加入一个boolean变量，用来判断当前模块是否需要创建自动弹缩规则：

```
variable "enable_autoscaling" {
  description = "If set to true, enable auto scaling"
  type        = bool
}
```

如果是Python之类的编程语言，可以用if语句判断这个输入变量的值：
```
if var.enable_autoscaling {
  resource "alicloud_ess_scaling_rule" "default" {
    scaling_group_id = "{YOUR_ASG_ID}"
    adjustment_type  = "TotalCapacity"
    adjustment_value = 2
    cooldown         = 60
  }

  resource "alicloud_ess_scheduled_task" "default" {
    scheduled_action    = alicloud_ess_scaling_rule.default.ari
    launch_time         = "2021-01-22T11:37Z"
    scheduled_task_name = var.name
    recurrence_type     = "Daily"
    recurrence_value    = "0 17 * * *"
    recurrence_end_time = "2022-01-22T11:37Z"
  }
}
```

Terraform不支持如上的if语句，所以这个代码不会正常运行，但是可以通过count实现同样的效果，其中用到Terraform自带的两个特性：

* Terraform中如果将变量设置为*true*，它就自动将变量转为1；*false* 则转为0。
* 如果将*count*设置为1，那么就会创建一个资源；如果为0，则不会创建该资源。

将上述两个特性结合到一起，可以更新*webserver-cluster*模块：
```
resource "alicloud_ess_scaling_rule" "default" {
  count            = var.enable_autoscaling
  scaling_group_id = "{YOUR_ASG_ID}"
  adjustment_type  = "TotalCapacity"
  adjustment_value = 2
  cooldown         = 60
}

resource "alicloud_ess_scheduled_task" "default" {
  count               = var.enable_autoscaling
  scheduled_action    = alicloud_ess_scaling_rule.default.ari
  launch_time         = "2021-01-22T11:37Z"
  scheduled_task_name = var.name
  recurrence_type     = "Daily"
  recurrence_value    = "0 17 * * *"
  recurrence_end_time = "2022-01-22T11:37Z"
}
```

如果*var.enable_autoscaling*设置为true，那么*alicloud_ess_scaling_rule*和*alicloud_ess_scheduled_task*的资源数量都将为1，所以每个资源都将创建一个；反之如果*var.enable_autoscaling*为false，那么这两个资源都不会创建。这就是条件逻辑的实现方式。

在staging环境中，可以更新这个模块，将*enable_autoscaling*设置为*false*：
```
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  cluster_name           = "webserver-staging"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

  instance_type      = "ecs.n2.medium"
  min_size           = 2
  max_size           = 2
  enable_autoscaling = false
}
```

同样的可以将production环境中的*enable_autoscaling*设置为true：
```
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  cluster_name           = "webserver-production"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "production/data-stores/mysql/terraform.tfstate"

  instance_type      = "ecs.g6e.xlarge"
  min_size           = 2
  max_size           = 10
  enable_autoscaling = false
}
```

*更复杂的IF语句*

如果开发人员在使用过程中传递给模块一个非常明确的true或者false，上述使用方式就非常方便，但是如果boolean是由一个非常复杂的对比得出的，比如字符串是否相等，那么这种方式是不是仍然好用呢？为了应对更复杂的情形，与其设置一个boolean变量，不如根据条件语句的返回值来设置变量。Terraform中的条件语句与其他编程语言中的三元比较很相似：
```
CONDITION ? TRUEVAL : FALSEVAL
```

所以在前面内容中，可以使用如下更简单的方式执行if语句：

```
count = "${var.enalbe_autoscaling ? 1: 0}"
```

我们举个更复杂的例子。如果想把CMS告警作为*webserver-cluster*中的一部分，当某个指标超过设定的门槛时，CMS告警可以配置成以不同的机制（短信、电话等）来提醒你。在*modules/services/webserver-cluster/main.tf*中可以使用*alicloud_cms_alarm*创建一个告警，当CPU使用率连续五分钟超出90%的时候就发送告警：

```
resource "alicloud_cms_alarm" "basic" {
  name    = "${var.cluster_name}-high-cpu-utilization"
  project = "acs_ecs_dashboard"
  metric  = "CPUUtilization"
  dimensions = {
    instanceId = "i-bp1247,i-bp11gd"
  }
  escalations_critical {
    statistics = "Maximum"
    comparison_operator = "<="
    threshold = 90
    times = 2
  }
  period             = 300
  contact_groups     = ["test-group"]
  effective_interval = "0:00-2:00"
  webhook            = "https://${data.alicloud_account.current.id}.eu-central-1.fc.aliyuncs.com/2016-08-15/proxy/Terraform/AlarmEndpointMock/"
}
```

将当前代码加入*webserver-cluster*之后，在staging和production环境中都会创建这个告警，如果只想在production环境中创建这个告警，就可以使用条件语句：

```
resource "alicloud_cms_alarm" "basic" {
  count = var.environment == "production" ? 1 : 0

  name    = "${var.cluster_name}-high-cpu-utilization"
  project = "acs_ecs_dashboard"
  metric  = "CPUUtilization"
  dimensions = {
    instanceId = "i-bp1247,i-bp11gd"
  }
  escalations_critical {
    statistics = "Maximum"
    comparison_operator = "<="
    threshold = 90
    times = 2
  }
  period             = 300
  contact_groups     = ["test-group"]
  effective_interval = "0:00-2:00"
  webhook            = "https://${data.alicloud_account.current.id}.eu-central-1.fc.aliyuncs.com/2016-08-15/proxy/Terraform/AlarmEndpointMock/"
}
```

告警资源的代码和上面一样，只是添加了一行条件判断，使用*count*参数：
```
count = var.environment == "production" ? 1: 0
```

这个条件判断语句判断当前代码运行环境是否为生产环境，如果是，则将count设置为1；如果不是，则设置为0。通过这种方式，将这个告警资源设置为只为生产环境创建。

**if-else语句**

当前你知道如何使用if语句，但是如何使用*if-else*语句呢？我们同样从简单的*if-else*语句开始逐渐学习到复杂的语句。

*简单的IF-ELSE语句*

上一章中，我们默认为网络服务器创建一块数据盘。想象一下，如果你想为网络服务器增加一块数据盘，让运行Terraform代码的人来决定增加这块数据盘的大小。这个例子有点拧巴，但是能够让我们对简单的IF-ELSE语句有一个直观的理解，直观的是如果if-else的一个分支被执行，另外的分支就会被忽略。

这是阿里云上网络服务器数据盘的相关代码：
```
resource "alicloud_disk" "ecs_disk" {
  name        = "disk2"
  size        = 200
  category    = "cloud_efficiency"
  description = "disk2"
  encrypted   = true
  kms_key_id  = alicloud_kms_key.key.id
}

resource "alicloud_disk_attachment" "ecs_disk_att" {
  disk_id     = alicloud_disk.ecs_disk.id
  instance_id = alicloud_instance.ecs_instance.id
}
```

我们的目标是根据输入参数*is_production*来判断这个数据盘的大小，如果是production环境，则为200GB；如果是staging环境，则为20GB：
```
variable "is_production" {
  description = "If true, we will create this data disk with 200GB"
}
```

如果使用诸如Python这样的编程语言，可能像下面这样写if-else代码：

```
if var.is_production:
  resource "alicloud_disk" "ecs_disk" {
    name        = "disk2"
    size        = 200
    category    = "cloud_efficiency"
    description = "disk2"
    encrypted   = true
    kms_key_id  = alicloud_kms_key.key.id
  }
else:
  resource "alicloud_disk" "ecs_disk" {
    name        = "disk2"
    size        = 200
    category    = "cloud_efficiency"
    description = "disk2"
    encrypted   = true
    kms_key_id  = alicloud_kms_key.key.id
  }
```

在Terraform中使用IF-ELSE的话，同样也可以使用*count* ，这次，可以利用Terraform插补语法允许使用简单数学计算的特性：

```
resource "alicloud_disk" "ecs_disk_production" {
  count       = var.is_prodcution
  name        = "disk2"
  size        = 200
  category    = "cloud_efficiency"
  description = "disk2"
  encrypted   = true
  kms_key_id  = alicloud_kms_key.key.id
}

resource "alicloud_disk" "ecs_disk_staging" {
  count       = 1 - var.is_production
  name        = "disk2"
  size        = 200
  category    = "cloud_efficiency"
  description = "disk2"
  encrypted   = true
  kms_key_id  = alicloud_kms_key.key.id
}
```

上面代码创建了两个*alicloud_disk*资源，第一个创建的数据盘大小为200GB，将参数*count*设置为*var.is_production*，所以这个资源只在*var.is_prodcution*为*true*的时候创建；第二个则相反，将参数*count*设置为*1-var.is_production*，则只在*var.is_prodcution*为*false*的时候创建。

*更复杂的IF-ELSE语句*

上述方法可以在Terraform代码不确定哪个IF-ELSE分支的代码会被运行时非常有效。但是如果你想使用IF-ELSE相关资源的输出变量，那该怎么办？例如，如果你想为*webserver-cluster*模块提供两个自定义脚本，让使用者可以选择想要执行的脚本，那该怎么做？当前*webserver-cluster*模块中通过*template_file*数据源获取*user-data.sh*脚本：

```
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars {
    db_connection_str  = data.terraform_remote_state.db.connection_string
    db_port            = data.terraform_remote_state.db.port
    server_port        = var.server_port
  }
}
```

当前*user-data.sh*脚本如下所示：

```
#!/bin/bash

cat > index.html <<EOF

<h1>Hello, World!</h1>
<p>DB connection string: ${db_connection_str}</p>
<p>DB port: ${db_port}</p>
EOF

nohup busybox httpd -f -p "$server_port}" &
```

现在，如果你想允许一些网络服务器集群使用一个更简单的脚本，叫做*user-data-new.sh*：
```
#!/bin/bash

echo "Hello, World, v2" > index.html
nohup busybox httpd -f -p "$server_port}" &
```

为了使用这个脚本，需要新建一个*template_file*数据源：

```
data "template_file" "user_data_new" {
  template = file("${path.module}/user-data-new.sh")

  vars {
    server_port        = var.server_port
  }
}
```

问题是，如何允许*webserver-cluster*模块选取相应的User Data脚本？首先，可以在*modules/services/webserver-cluster/vars.tf*中新建一个bool变量：
```
variable "enable_new_user_data" {
  description = "if set to true, use the new User Data Script"
}
```

如果在一般编程语言当中，可以在*user_data* 参数上加上IF-ELSE判断来选择相应的*template_file*数据源：

```
resource "alicloud_ess_scaling_configuration" "default" {
  scaling_group_id  = alicloud_ess_scaling_group.default.id
  image_id          = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
  instance_type     = "ecs.n2.small"
  security_group_id = alicloud_security_group.default.id
  force_delete      = true
  active            = true

  if var.enable_new_user_data:
    user_data = data.template_file.user_data.rendered
  else:
    user_data = data.template_file.user_data_new.rendered
}
```

在实际Terraform代码中，首先需要对*template_file*数据源使用IF-ELSE判断，确保只有一个*template_file*数据源被创建：
```
data "template_file" "user_data" {
  count    = 1 - var.enable_new_user_data
  template = file("${path.module}/user_data.sh")

  vars {
    db_connection_str  = data.terraform_remote_state.db.connection_string
    db_port            = data.terraform_remote_state.db.port
    server_port        = var.server_port
  }
}

data "template_file" "user_data_new" {
  count    = var.enable_new_user_data
  template = file("${path.module}/user-data-new.sh")

  vars {
    server_port        = var.server_port
  }
}
```

如果*var.enable_new_user_data*为true，那么*data.template_file.user_data_new*就会被创建而*data.template_file.user_data*则不会；如果*var.enable_new_user_data*为false，则相反。当前你需要做的事情就是将*alicloud_ess_scaling_configuration*中的*user_data*参数设置为实际存在的*template_file*资源。可以使用Terraform中*concat*方法：
```
concat(LIST1, LIST2, ...)
```

*concat*将两个或多个列表结合成一个列表。下面例子中与*element*方法结合起来选择合适的template_file：
```
resource "alicloud_ess_scaling_configuration" "default" {
  scaling_group_id  = alicloud_ess_scaling_group.default.id
  image_id          = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
  instance_type     = "ecs.n2.small"
  security_group_id = alicloud_security_group.default.id
  force_delete      = true
  active            = true

  user_data = element(concat(data.template_file.user_data.*.rendered, data.template_file.user_data_new.*.rendered), 0)
}
```

我们一点一点分析*user_data*参数。首先看最里面的部分：
```
concat(data.template_file.user_data.*.rendered, data.template_file.user_data_new.*.rendered)
```

注意到此处两个*template_file*数据源都是列表，因为它们都使用了*count*参数。这两个列表因为根据*var.enable_new_user_data*的值，只会创建一个，所以一个为空，一个长度为1。所以用*concat*方法将两个列表结合起来之后，列表长度为1。现在看外部*element*部分：
```
user_data = element(<INNER>, 0)
```

这里的代码就是通过*element*方法选取*concat*之后的列表的第0个元素。

所以，当上述代码完成之后，可以根据*enable_new_user_data*来设置是否使用新的User Data脚本，可以为staing和production环境设置不同的值。

总体而言，使用*count*以及*concat*、*element* 等插补语法来模拟IF-ELSE语法是不那么简明，但是这样做效果很好，可以很大程度上简化代码，易于阅读。



*零停机部署*

当前你的模块可以使用干净简单的API部署一个服务器集群，一个重要的问题是：你要如何更新这个集群？当更新代码之后，例如更改虚拟机镜像之后，如何将新的镜像部署到整个集群中？如何在更新的同时不影响到当前的用户？

第一步是将镜像作为一个输入变量在*modules/services/webserver-cluster/vars.tf*中暴露出来。在实际工程中，这就是你唯一需要做的，因为服务器配置相关的代码都会用Packer等工具打包在镜像当中。然而在本书简化的例子中，所有服务器相关的代码都在*User_data*当中，虚拟机景象就是一个Ubuntu镜像ID。当前例子中，换一个Ubuntu镜像的版本并不会有很大的影响，所以除了增加一个新的镜像ID作为输入变量，你可以同样增加一个输入变量，以控制从*User Data*脚本相关的HTTP服务器中返回的文本：
```
variable "image_id" {
  description = "The image id to run in the cluster"
  default     = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
}

variable "server_text" {
  description = "The text the web server should return"
  default     = "Hello, World"
}
```

前文中，为了联系*if-else*语句，你创建了两个*User Data*脚本。让我们来把这两个脚本合并成一个让代码库更简洁。第一步，删除*modules/services/webserver-cluster/vars.tf*中*enable_new_user_data*这个输入变量；第二步，在*modules/services/webserver-cluster/main.tf*中删除*user_data_new*这个数据源；第三步，在同一个文件中，更新*user_data*这个数据源，删除*enable_new_user_data*的相关引用，并在*vars*中加上我们刚刚定义的*server_text*输入变量：

```
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")

  vars {
    db_connection_str  = data.terraform_remote_state.db.connection_string
    db_port            = data.terraform_remote_state.db.port
    server_port        = var.server_port
    server_text        = var.server_text
  }
}
```

现在你需要更新*modules/services/webserver-cluster/user_data.sh*脚本，加入*server_text*在 *<h1>* 标签中。
```
#!/bin/bash

cat > index.html <<EOF
<h1>${server_text}</h1>
<p>DB connection string: ${db_connection_str}</p>
<p>DB port: ${db_port}</p>
EOF

nohup busybox httpd -f -p "$server_port}" &
```

最后，在*modules/services/webserver-cluster/main.tf*的scaling configuration中，将*user_data*参数设置为仅剩的*template_file*数据源，并将*image_id*设置为新增的输入变量：

```
resource "alicloud_ess_scaling_configuration" "default" {
  scaling_group_id  = alicloud_ess_scaling_group.default.id
  image_id          = var.image_id
  instance_type     = "ecs.n2.small"
  security_group_id = alicloud_security_group.default.id
  force_delete      = true
  active            = true

  user_data = element(concat(data.template_file.user_data.*.rendered, data.template_file.user_data_new.*.rendered), 0)
}
```

现在，在staging环境中，可以将*live/stage/services/webserver-cluster/main.tf*中的image_id以及server_text设置为新增的输入变量：

```
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  image_id    = var.image_id
  server_text = var.server_text

  cluster_name           = "webserver-staging"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

  instance_type      = "ecs.n2.medium"
  min_size           = 2
  max_size           = 2
  enable_autoscaling = false
}
```

Staging中的代码还是使用同样的Ubuntu虚拟机镜像，将Http服务器返回的*server_text*设置为一个新的值。如果运行*plan*命令的话，你可以看到，Terraform想要替换原有的*scaling configuration*，并更新*user_data*。
