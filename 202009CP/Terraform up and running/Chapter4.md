### 第四章：如何通过Terraform模块创建可复用基础设施？

第三章中创建的基础设施，用户可以通过负载均衡访问网络服务器上的资源。但是如果只有staging一套环境的话，你不会想让用户访问程序员用来测试的环境，同时在生产环境上进行测试风险也太大了，所以你至少需要两套环境，staging和production。理想状况下，这两个环境应该是相同的，除了staging环境中的服务器等资源的规格可能会小一点以便节省开销。

如果只有预生产环境（staging），Terraform代码的文件布局类似于这样：
```
stage
  services
    webserver-cluster
      main.tf
      (etc)
  data-stores
    mysql
      main.tf
      (etc)
global
  s3
    main.tf
    (etc)
```

如果再加上一个生产环境，那么文件布局就如下所示：
```
stage
  services
    webserver-cluster
      main.tf
      (etc)
  data-stores
    mysql
      main.tf
      (etc)
production
  services
    webserver-cluster
      main.tf
      (etc)
  data-stores
    mysql
      main.tf
      (etc)
global
  s3
    main.tf
    (etc)
```

在这样的布局中要如何避免大量重复的代码呢？如何避免把staging环境中所有的代码都复制粘贴到production里面？在常用的编程语言中（python、Java等），如果你在几个地方都用到一段同样的代码，可以将这块代码抽象成方法并且直接复用这个方法：
```python
def example_function():
    print("Hello, World")

example_function()
```

在Terraform中，也可以将重复的代码放入*Terraform module*中，并且在其他地方复用这个模块。*stage/services/webserver-cluster*以及*prod/services/webserver-cluster* 都可以直接使用模块中的代码而不是拷贝粘贴所有代码。

本章中，我将带你通过以下主题学习如何创建和使用Terraform模块：
* 模块基础
* 模块输入变量
* 模块输出变量
* 模块小技巧
* 模块版本控制


**模块基础**

Terraform模块非常简单：任何在一个文件夹内的Terraform配置就是一个模块。迄今为止你写的所有配置本质上来说就是模块，尽管没有特别有趣怼，因为你直接部署所有的Terraform代码。想要知道模块真正适用范围，你需要从一个模块中调用另一个模块。

例如，在*stage/services/webserver-cluster*中包含了一个ASG（自动扩展组）、SLB（负载均衡）、安全组以及很多其他资源，我们可以将这个ASG改成可复用的模块。

首先，在*stage/services/webserver-cluster*中运行*terraform destroy*清除之前创建的资源。其次，新建一个叫做*modules*的文件夹，把*stage/services/webserver-cluster*中的文件都转移到*modules/services/webserver-cluster*。打开*modules/services/webserver-cluster*中的*main.tf*文件，删除关于*provider*的定义，这应该是模块的使用者定义而不是模块自身定义。

现在可以在staging环境中使用这个模块，使用模块的语法是：
```
module "NAME" {
  source = "SOURCE"

  [CONFIG ...]
}
```

在模块定义的内部，*source* 参数指定了模块代码所在的文件夹或者仓库地址。例如，可以在*stage/services/webserver-cluster*中创建一个新的*main.tf*，并在其中以下面这种方式使用*webserver-cluster*模块：

```
provider "alicloud" {
  region = "cn-shanghai"
}

module "webserver-cluster" {
  source = "../../modules/services/webserver-cluster"
}
```

在生产环境中，也可以通过相同方式使用这个模块，创建*prod/services/webserver-cluster/main.tf*，写入和上面类似的内容：

```
provider "alicloud" {
  region = "cn-shanghai"
}

module "webserver-cluster" {
  source = "../../modules/services/webserver-cluster"
}
```

所以这里可以看出，你可以复用代码，避免复制粘贴大量重复的代码。注意当你在Terraform代码中加入一个模块或者改变*source*参数的时候，在运行*plan*或者*apply*之前需要运行*terraform get*命令：

```
> terraform get
Get: /modules/webserver-cluster

> terraform plan
```

运行*apply*命令之前，需要注意*webserver-cluster*模块有一个问题：所有的参数都写死了，比如安全组的名字、负载均衡的名字以及其他资源。如果复用这个模块超过一次，就会引发名字冲突。甚至数据库的参数也写死了，因为模块的*main.tf*中引用了*terraform_remote_state*数据源来获取数据库的*connection_string*以及端口等参数，对于一个环境中的数据库而言，它的属性是不会变的。为了解决这个问题，需要在*webserver-cluster*模块中加入可配置的输入变量，这样它能在不同环境中使用。

**模块输入变量**

在常见编程语言当中，通常在方法中加入参数让方法变得可以适应不同配置：

```
def example_function(param1, param2):
    print("Hello, %s, %s", param1, param2)

example_function("foo", "bar")
```

Terraform模块也同样可以使用输入参数，可以使用前文的输入变量来定义。新建一个*modules/services/webserver-cluster/vars.tf*，增加三个变量描述：
```
variable "cluster_name" {
  description = "The name to use for all cluser resources"
}

variable "db_remote_state_bucket" {
  description = "The name for OSS bucket for the database's remote state"
}

variable "db_remote_state_key" {
  description = "The path for the database's remote state in OSS"
}
```

下一步，使用*var.cluster_name*代替硬编码的名字，例如，第二张的负载均衡可以改成下面这样：
```
resource "alicloud_slb" "default" {
  name          = "${var.cluster_name}-elb"
  specification = "slb.s2.small"
  vswitch_id    = alicloud_vswitch.default.id
}
```

注意此处*name*参数已经更改成*${var.cluster_name}-elb*。在之前阿里云的其他资源中也可以做类似的更改。在*terraform_remote_state*资源中，也应该把硬编码的参数转换成输入参数：
```
terraform {
  backend "oss" {
    profile             = "terraform"
    bucket              = var.db_remote_state_bucket
    key                 = var.db_remote_state_key
    tablestore_endpoint = "https://tf-oss-backend.cn-hangzhou.Tablestore.aliyuncs.com"
    tablestore_table    = "terraform-oss-backend-1024"
    acl                 = "private"
    encrypt             = true
    ...
  }
}
```

设置完成之后，对于staging环境，可以单独设置这三个参数的值：
```
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  cluster_name           = "webserver-stage"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"
}
```

生产环境也可以进行类似的配置：
```
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  cluster_name           = "webserver-production"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "production/data-stores/mysql/terraform.tfstate"
}
```

注意：当前生产环境的MySQL数据库不是真正存在的，留作练习，分别创建staging&production环境的MySQL数据库。

可以看出，为模块设置输入变量的语法和为资源设置输入变量的语法是类似的。输入变量就是模块的API，可以控制模块在不同环境中的配置。上面例子在不同环境中使用不同的名字，可能你也想把其他变量变成可以配置的。例如，你可能想把staging环境中的服务器规格调小以便节省开支；而生产环境中的服务器规格需要很大来应付非常多的流量。那么就可以在*modules/services/webserver-cluster/vars.tf*加入三个变量：

```
variable "instance_type" {
  description = "The type of ECS instance"
}

variable "min_size" {
  description = "The minimum number of ECS instance"
}

variable "max_size" {
  description = "The max number of ECS instance"
}
```

设置好新的变量之后，更新*alicloud_ess_scaling_configuration*，将*instance_type*设置为输入变量*var.instance_type*，同样的，在*alicloud_ess_scaling_group*中，将*max_size*和*min_size*设施成*var.max_size*以及*var.min_size*：

```
resource "alicloud_ess_scaling_group" "default" {
  min_size           = 2
  max_size           = 10
  scaling_group_name = "terraform-example-ess"
  removal_policies   = ["OldestInstance", "NewestInstance"]
  vswitch_ids        = [alicloud_vswitch.vsw.id]

  min_size = var.min_size
  max_size = var.max_size

  tags {
    Name = "ess-example"
  }
}

resource "alicloud_ess_scaling_configuration" "default" {
  scaling_group_id  = alicloud_ess_scaling_group.default.id
  image_id          = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
  instance_type     = var.instance_type
  security_group_id = alicloud_security_group.default.id
  force_delete      = true
  active            = true

  user_data = data.template_file.user_data.rendered
}
```

设置完成之后，为了减少staging环境的开销，可以将staging环境中web服务器集群保持在小的规模，同时实例规格设置为*ecs.n2.medium*：
```
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  cluster_name           = "webserver-staging"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

  instance_type = "ecs.n2.medium"
  min_size      = 2
  max_size      = 2
}
```

换句话说，在生产环境中，为了应对更多的流量，可以使用更大的*instance_type*，这样CPU和内存就更多，例如*ecs.g6e.xlarge*，并且可以将*max_size*设置为10，这样集群就可以根据负载来自动弹缩：

```
module "webserver_cluster" {
  source = "../../modules/services/webserver-cluster"

  cluster_name           = "webserver-production"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "production/data-stores/mysql/terraform.tfstate"

  instance_type = "ecs.g6e.xlarge"
  min_size      = 2
  max_size      = 10
}
```

如何将集群设置为根据负载自动弹缩？一种方法就是使用*自动缩放计划*，在每天固定的时间按计划缩放集群的大小。例如，如果访问你的网络集群的流量在工作时间比非工作时间要高很多，那么可以使用自动缩放计划，每天上午9点增加集群中机器的数量，下午五点再减少。

如果在*webserver-cluster*模块中定义自动缩放计划，它就会在staging以及production环境中都起作用，因为对于staging环境，已经将机器数量定义为最小，所以当前可以直接将自动缩放计划定义在生产环境中，想要这样做，就要学习如何使用模块输出变量。


**模块输出**

要定义自动缩放计划，在*prod/services/webserver-cluster/main.tf*中加上*alicloud_ess_scheduled_task*资源：
```
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
```

上面代码用一个*alicloud_ess_scheduled_task*将网络服务器集群中实例的数量在每天下午5点减少为2个，也可以加一个类似的任务，将实例数量每天上午9点加到10个：
```
resource "alicloud_ess_scaling_rule" "default1" {
  scaling_group_id = "{YOUR_ASG_ID}"
  adjustment_type  = "TotalCapacity"
  adjustment_value = 10
  cooldown         = 60
}

resource "alicloud_ess_scheduled_task" "default1" {
  scheduled_action    = alicloud_ess_scaling_rule.default.ari
  launch_time         = "2021-01-22T11:37Z"
  scheduled_task_name = var.name
  recurrence_type     = "Daily"
  recurrence_value    = "0 17 * * *"
  recurrence_end_time = "2022-01-22T11:37Z"
}
```

这里要注意的是，每个*alicloud_ess_scaling_rule*资源中都需要使用到*scaling_group_id*，应该指定为我们之前创建怼自动弹缩资源组的ID。由于ASG是由*webserver-cluster*模块定义的，所以该怎么去访问它的ID？在一般编程语言中，方法可以返回一个或者多个值：
```
def example_function(param1, param2):
    return "Hello, #{param1}, #{param2}"
end

return_value = example_function("foo", "bar")
```

Terraform中的模块同样可以返回值，这是通过你已经了解的输出变量的概念来实现的。可以将ASG的ID作为输出变量写在*modules/services/webserver-cluster/outputs.tf*中：
```
output "asg_id" {
  value = alicloud_ess_scaling_group.default.id
}
```

访问模块输出变量的方式和访问其他资源的变量一样，语法为：
```
module.MODULE_NAME.OUTPUT_NAME
```

在*prod/services/webserver-cluster/main.ft*中，可以用这样的语法为*alicloud_ess_scaling_rule*中的ASG指定ID：

```
resource "alicloud_ess_scaling_rule" "default1" {
  scaling_group_id = module.webserver_cluster.asg_id
  adjustment_type  = "TotalCapacity"
  adjustment_value = 10
  cooldown         = 60
}
```

在*webserver-cluster*模块中，你可能还想加一个输出变量：负载均衡的名字，因为在集群部署之后可能需要了解待测试的URL。同样的，在*modules/services/webserver-cluster/outputs.tf*中加入新的输出变量：
```
output "slb_address" {
  value = alicloud_slb.default.address
}
```

之后可以在*stage/services/webserver-cluster/outputs.tf*以及*prod/services/webserver-cluster/outputs.tf*中以下面语法传递这个输出变量：
```
output "slb_address" {
  value = module.webserver_cluster.slb_address
}
```

你的网络服务器集群差不多能部署了，唯一需要注意的就是使用模块的几个陷阱。

**模块陷阱**

创建模块时，需要注意这些陷阱：
* 文件路径
* 内嵌代码块

*文件路径*

第三章中，将网络服务器集群中User Data相关的脚本存储为单独的*user-data.sh*文件，并使用Terraform内置的*file*方法获取文件中的内容。使用*file*的小技巧就是使用相对路径（因为Terraform可能运行在很多不同的电脑上）- 但是相对路径的基准路径是什么？

Terraform默认根据当前的工作目录解析路径，如果你使用*file*方法的Terraform文件所在的文件夹就是你要运行*terraform apply*命令的文件夹，相对路径就可以正常使用；但是如果在一个模块中使用*file*方法，并定义为相对路径，在另一个文件夹中调用这个模块的时候就会无法找到正确的文件路径。

为了解决这个问题，可以使用*path.module*将一个文件路径转换成相对于模块的相对路径。将*template_file*数据源文件路径更改之后如下：

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

*内嵌代码块*

一些Terraform资源可以定义为内部代码块，也可以定义为单独的资源。当你创建一个模块的时候，应该总是倾向于创建一个单独的资源。例如，*alicloud_instance* 允许在资源内部通过内嵌代码块定义数据盘，如下所示：
```
resource "alicloud_instance" "instance" {
  ...
  data_disks {
    name        = "disk2"
    size        = 20
    category    = "cloud_efficiency"
    description = "disk2"
    encrypted   = true
    kms_key_id  = alicloud_kms_key.key.id
  }
}
```

在模块定义中，你应该将数据盘以单独的资源*alicloud_disk*来定义：

```
resource "alicloud_disk" "ecs_disk" {
  name        = "disk2"
  size        = 20
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

如果在模块定义中对同一资源同时使用内嵌代码块以及单独资源定义，就会导致冲突，两个资源定义会互相覆盖，因此两种定义方式只能选择一种。因为这个限制，在创建模块的时候，应该尽量定义单独的资源而不是使用内嵌代码块，如果不这样做的话，代码就会变得不是非常灵活且可配置。

例如，如果所有的数据盘都是以*alicloud_disk*资源单独定义的，那么这个模块就会非常灵活，允许用户在外部对这个模块加入自定义的配置。例如，将实例的ID以输出变量从模块中穿出来：

```
output "instance_id" {
  value = alicloud_instance.default.id
}
```

现在，假设在staging环境中，需要为及其单独另加一个数据盘，当前这种模块配置中，就很容易定义一个新的*alicloud_disk*资源，并挂载到实例上：
```
resource "alicloud_disk" "ecs_disk" {
  name        = "disk-NewestInstance"
  size        = 20
  category    = "cloud_efficiency"
  description = "disk2"
  encrypted   = true
  kms_key_id  = alicloud_kms_key.key.id
}

resource "alicloud_disk_attachment" "ecs_disk_att" {
  disk_id     = alicloud_disk.ecs_disk.id
  instance_id = module.alicloud_instance.instance_id
}
```

当前，你的代码已经能够部署在staging以及production环境中，运行*terraform plan*以及*terraform apply*命令进行部署。


**模块版本**

如果staging和production环境都同时使用一个模块，那么如果对这个模块作出更改的话，下次部署这个更改就会在staging以及production上生效。如果只想在staging环境上对更改进行测试而不影响生产环境，上面这种直接更改无疑是很难做到的。一个更好的方式是使用模块版本，可以在staging环境上使用一个版本（e.g., v0.0.2），在production上使用不同的版本（e.g., v0.0.1）。

在当前见到所有的模块示例中，当使用模块的时候，就将*source*参数设置为本地文件夹路径。除了文件路径，Terraform支持其他形式的模块源，包括Git URLs、Mercurial URLs以及HTTP URLs等。创建一个带版本模块最简单的方式是把代码放入一个单独的Git仓库中，并将*source*参数设置为仓库的URL。这意味着你Terrraform代码将引入至少两个Git仓库。

当前你的Terraform文件布局应该如下所示：

```
modules
  services
    webserver-cluster
live
  stage
    webserver-cluster
    data-stores
      mysql
  prod
    webserver-cluster
    data-stores
      mysql
  global
    oss
```

* modules，这个文件夹定义可复用的模块。将每个模块想像成你基础设施蓝图中的一个组件。
* live，这个文件夹中定义你正在运行的每个环境。

为了建立如上的文件布局，首先需要将stage、prod以及global转移到一个叫做live的文件夹中，下一步，将*live*和*modules*配置成不同的Git仓库。下面例子是将*modules*设置为一个Git 仓库：
```
> cd modules
> git init
> git add .
> git commit -m "Initial commit of modules repo"
> git remote add origin "(URL of remote git repo)"
> git push -u origin master
```

对于*modules*仓库，可以加入一个tag当作版本号。如果使用GitHub，可以使用GitHub UI来创建一个带有标签的发布。如果没有使用Github，可以使用Git CLI命令：
```
> git tag -a "v0.0.1" -m "First release of webserver-cluster module"
> git push --follow-tags
```

现在可以通过指定一个Git URL在staging和production环境上使用带版本的模块。如果*modules*模块的URL为*github.com/foo/modules*，那么staging环境中的配置*live/stage/services/webserver-cluster/main.tf*如下所示：

```
module "webserver_cluster" {
  source = "git::git@github.com:foo/modules.git//webserver-cluster?ref=v0.0.1"

  cluster_name           = "webserver-production"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "production/data-stores/mysql/terraform.tfstate"

  instance_type = "ecs.g6e.xlarge"
  min_size      = 2
  max_size      = 10
}
```

代码中的*ref*参数允许你通过sha1哈希、分支名称或者Git标签来指定一个特定的Git提交。一般建议将Git标签作为模块的版本号。分支名称并不是一直不变的，而sha1哈希值并不易读。一种非常好用的标签命名方式是*语义版本*？命名，以*MAJOR.MINOR.PATCH*（e.g.，1.0.4）的方式来命名，对于每部分的数字增加有相应的规则：
* MAJOR版本号，当作出不兼容的API更改
* MINOR版本号，增加了新的功能
* PATCH版本号，修复bug的时候

*语义版本*提供一种能与使用者沟通的方式，让使用者了解当前模块版本做了何种更改以及是否需要升级模块版本。在用版本控制模块更新了你的Terraform代码之后，需要执行*terraform get -update*命令：

```
> terraform get -update
Get: git::ssh://git@github.com/foo/modules.git?ref=v0.0.1

> terraform plan
(...)
```

运行命令之后，你会看到Terraform从Git仓库中下载模块代码而不是从本地文件中获取，一旦模块代码被下载到本地，你可以和之前一样运行*terraform plan*以及*terraform apply* 命令。

现在，想象你在*webserver-cluster*模块上作出了一些更改，你想在staging环境上测试这些更改。首先需要将这些更改提交到Git仓库中：
```
> cd modules
> git add .
> git commit -m "Made some changes to webserver-cluster"
> git push -u origin master
```

其次，需要为*modules*模块创建一个新的标签：
```
> git tag -a "v0.0.2" -m "Second commit of webserver-cluster"
> git push --follow-tags
```

更新之后，只需要更新staging环境中的*source*URL就能使用新版本的模块：
```
module "webserver_cluster" {
  source = "git::git@github.com:foo/modules.git//webserver-cluster?ref=v0.0.2"

  cluster_name           = "webserver-production"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "production/data-stores/mysql/terraform.tfstate"

  instance_type = "ecs.g6e.xlarge"
  min_size      = 2
  max_size      = 10
}
```

在production中，可以继续使用v0.0.1版本的模块。一旦v0.0.2版本的模块测试在staging环境中完成之后，就可以在production环境中使用这个模块。如果v0.0.2版本中有bug也只会影响staging环境。修复这个bug，发布一个新的版本，重复这个过程直到你得到一个可以在production环境上运行的稳定的版本。

**结论**

通过使用模块定义你的基础设施即代码，可以在你的基础设施中应用很多软件工程领域的最佳实践。可以通过代码审阅以及自动化测试验证模块中的代码变更；可以为模块设置版本号；可以在不同的环境中使用不同版本的模块，如果当前代码有问题，也可以回退到之前的版本。

所有这些措施可以帮助你更迅速地建立更稳定的基础设施，因为开发人员可以复用被测试过、文档化的基础设施。例如，你可以创建一个经典的模块来定义如何部署单个的微服务，包括如何部署集群，如何根据负载缩放集群以及如何为集群分配流量。仅需很少的代码，每个团队都可以使用这个模块来管理他们各自的微服务。

为了让多个团队都能使用同一个模块，这个模块的Terraform代码必须灵活可配置。例如，一个团队想使用你的模块部署单个服务器、没有负载均衡的微服务，而另一个团队需要部署多个服务器、一个负载均衡的微服务。对于这种情况，你该如何在Terraform中使用条件语句？可以使用for循环吗？这些高级Terraform语法就是第五章的主题。
