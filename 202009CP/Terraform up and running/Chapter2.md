### Terraform入门

本章中，你将学习关于如何使用Terraform的基础知识。Terraform简单易学，所以在后面差不多30页的内容里，你将从运行第一条Terraform命令一直学习到使用Terraform来部署一个包含负载均衡的服务器集群。这个基础架构是运行可扩展的、高度可用的Web服务和微服务的良好起点。在后续章节中，你将进一步扩展示例。

Terraform可以在诸如AWS、Azure和阿里云等大部分公有云服务商以及诸如OpenStack和VMWare等私有云和虚拟化平台上预置基础设施。本章以及后续章节中，都将使用AWS作为示例（我使用阿里云是因为我现在在用阿里云:-)），AWS是学习Terraform的不二之选是因为：

* AWS是最流行的云服务提供商，迄今为止，它在公有云市场中占有45%的份额，大于其他三家主流竞争对手的总和（Azure、Google云以及IBM）。*2020年AWS占有32%，Azure 19%，Google云 7%，阿里云 6%，其他云共占37%*

* AWS提供非常多可靠的、可扩展的云服务，包括：EC2（弹性云计算），可以用来部署虚拟服务器；ASGs（Auto scaling groups, 自动缩放组），可以更容易地管理虚拟服务器集群；ELB（Elastic Load Balancer，弹性负载均衡），可以用来在虚拟服务器集群中分配流量。

* AWS提供慷慨的免费额度，可以免费在上面跑所有示例。如果你已经使用完你的免费额度，本书中的所有实例也仅仅会花费你几块钱。

如果你之前从未使用过AWS或是Terraform，不要担心，因为这本书就是为这两个技术的新手写的。我会引导你完成后续步骤：

* 设置AWS账户（这里是阿里云）
* 安装Terraform
* 部署一个网络服务器
* 部署一个可配置的网络服务器
* 部署一个网络服务器集群
* 部署一个负载均衡
* 清除所有资源

**设置阿里云账户**

如果你还没有阿里云账户，访问*aliyun.com*并[注册](https://help.aliyun.com/document_detail/37195.html)一个阿里云账户。当你第一次注册阿里云账户的时候，你是以root账户登陆的。这个账户有权限做任何事情，所以从安全角度来看，不应该在日常工作中用root账户。实际上，你应该使用root账户做的事情就是用它创建其他有限权限的账号，然后用这些账号来工作。

为了创建一个有限权限的账户，你需要使用RAM（Resource Access Management）。RAM是一个集中管理云上身份及访问权限的管理服务。可以通过RAM将阿里云资源的访问及管理权限分配给其他账户。

注册完账号之后，登陆控制台，申请AccessKey ID以及AccessKey Secret，[申请步骤](https://help.aliyun.com/knowledge_detail/38738.html)。建议在申请之后请立刻保存ID和secret，因为secret申请之后不会再次出现，如果没保存，就只能删除这个ID重新申请。

**安装Terraform**

你可以直接从[Terraform Homepage](https://www.terraform.io/)下载Terraform。点击下载链接，根据你的操作系统选择合适的包，下载Zip文件，解压到你想安装Terraform的文件夹中。解压出来的就是一个*terraform*可执行二进制文件，应该将其加入到PATH环境变量中。[详细安装流程请查阅](https://help.aliyun.com/document_detail/95825.html)。

配置之后运行`terraform`来验证配置是否正确：
```
[root]# terraform
Usage: terraform [global options] <subcommand> [args]

The available commands for execution are listed below.
The primary workflow commands are given first, followed by
less common or more advanced commands.

Main commands:
  init          Prepare your working directory for other commands
  validate      Check whether the configuration is valid
  plan          Show changes required by the current configuration
  apply         Create or update infrastructure
  destroy       Destroy previously-created infrastructure

All other commands:
  console       Try Terraform expressions at an interactive command prompt
  fmt           Reformat your configuration in the standard style
  force-unlock  Release a stuck lock on the current workspace
  get           Install or upgrade remote Terraform modules
  graph         Generate a Graphviz graph of the steps in an operation
  import        Associate existing infrastructure with a Terraform resource
  login         Obtain and save credentials for a remote host
  logout        Remove locally-stored credentials for a remote host
  output        Show output values from your root module
  providers     Show the providers required for this configuration
  refresh       Update the state to match remote systems
  show          Show the current state or a saved plan
  state         Advanced state management
  taint         Mark a resource instance as not fully functional
  untaint       Remove the 'tainted' state from a resource instance
  version       Show the current Terraform version
  workspace     Workspace management

Global options (use these before the subcommand, if any):
  -chdir=DIR    Switch to a different working directory before executing the
                given subcommand.
  -help         Show this help output, or the help for a specified subcommand.
  -version      An alias for the "version" subcommand.

```

为了让Terraform能够更改你的阿里云账户中的资源，需要把之前申请的AccessKey ID和Secret设置为环境变量：
```
export ALICLOUD_ACCESS_KEY="LTAIUrZCw3********"
export ALICLOUD_SECRET_KEY="zfwwWAMWIAiooj14GQ2*************"
export ALICLOUD_REGION="cn-beijing"
```

注意*export*这种设置方式只对当前是shell有效，如果重启shell或者开新的窗口，需要重新设置这3个环境变量。


**部署单个服务器**

Terraform使用HCL（HashiCorp configration language）语言来编写的，文件扩展名为*.tf*,它是一个解释型语言，所以你只需要用HCL描述你需要的基础设施，Terraform将会弄清楚如何创建它。Terraform可以被用来在非常广泛的平台上创建基础设施，包括AWS、Azure、阿里云等等。

你可以用大部分的编辑器来写Terraform代码，搜索一下就可以发现，大部分的编辑器都支持Terraform语法高亮，包括Vim、Emacs、sublime text、Atom、VS Code以及IntelliJ。

使用Terraform的第一步是配置你想使用的provider(s)，创建一个空的文件夹，新建一个`main.tf`文件，文件里写上：
```
provider "alicloud" {
  region = "cn-shanghai"
}
```
这告诉Terraform你将使用阿里云作为你的provider，并且你想在*cn-shanghai*这个区域部署你的infra。阿里云在全国各地都有数据中心，分成不同的`地域`和`可用区`。一个阿里云地域就是地理位置，例如*cn-shanghai*、*cn-hangzhou* 等等。在每个地域内部，有很多互相隔离的数据中心叫做`可用区`，[阿里云可用区列表](https://help.aliyun.com/document_detail/40654.html)。

对每一个provider，都有很多种不同的资源可以创建，例如服务器、数据库以及负载均衡等。例如，在阿里云上部署单个服务器（ECS弹性计算服务器），你可以在*main.tf*中加入`alicloud_instance`:

```
resource "alicloud_instance" "instance" {
  # series III
  instance_type        = "ecs.n2.small"
  system_disk_category = "cloud_efficiency"
  image_id             = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
  instance_name        = "terraform-example"
  vswitch_id = alicloud_vswitch.vsw.id
  internet_max_bandwidth_out =10
  password = "<replace_with_your_password>"
}
```

创建Terraform资源通用语法是：

```
resource "PROVIDER_TYPE" "NAME" {
  [CONFIG...]
}
```

`PROVIDER`就是provider的名字，类似`alicloud`，`TYPE`是要在provider中创建的资源类型，`NAME`是一个标识符，可以在Terraform代码中代表这个资源，`CONFIG`由想要创建的资源的参数组成。

在终端中，进入*main.tf*所在的文件夹，运行`terraform plan`，这个命令可以让你看到Terraform即将会做哪些事情。这是一种非常好的方式，可以在代码在真正运行前检查你的代码是否正常。`plan`命令的输出与Unix、Linux以及git中`diff`的输出非常相似：带有`+`号的资源将被创建，带有`-`号的资源将被删除，带有`~`号的资源会被更改。想要真的创建这个资源，需要运行`terraform apply`命令。

如果想要在为已经创建的ECS实例打上标签，就可以为实例加上*tags*参数：

```
resource "alicloud_instance" "instance" {
  tags {
    Name = "terraform-example"
  }
}
```

Terraform通过tf配置文件追踪它已经创建的所有资源，所以它知道ECS实例已经被创建并且如果你运行*terraform plan*命令，它会显示当前已经部署的资源和你代表中实例配置的区别。区别显示你想要创建一个名为*Name*的tag，这就是你需要的，所以可以直接运行*terraform apply*命令。

现在你已经有一些可以运行的Terraform代码，你可能想要把代码放在版本控制仓库中，这可以把代码分享给其他团队成员，追踪基础设施变更的记录，并且可以使用提交日志来debug。例如，可以用以下的命令来创建一个本地仓库并用它来存放自己的Terraform代码：
```
git init
git add main.tf
git commit -m "Initial commit"
```

你也应该同样创建一个*.gitignore*文件让git忽略某些类型的文件，以免不小心将这些文件提交到公共仓库：

```
.terraform
*.tfstate
*.tfstate.backup
```

*.gitignore* 程序文件让git忽略*.terraform*文件夹，这是terraform用来存储临时文件的文件夹；*tfstate* 是terraform用来存储状态的文件。你也应该把*.gitignore*文件提交到git仓库：

```
git add .gitignore
git commit -m "Add a .gitignore file"
```

要和你团队成员一起使用这个代码，建议创建一个所有人都有权限访问的共享代码仓库。一种可行的方式就是使用GitHub。访问[github.com](github.com)，如果还没有账户的话，先注册一个，然后创建一个新的仓库。用如下的命令把本地仓库连接到github远程仓库：

```
git remote add origin git@github.com:<your_username>/<your_repo_name>.git
```

配置好之后，无论你什么时候想要和你的团队成员共享你的代码，就直接把代码*push*到*origin*：

`git push origin master`

如果想看团队成员对代码做出的更改，直接从*origin*将代码*pull*到本地：

`git pull origin master`

当你用Terraform创建你的基础设施的时候，记得经常`git commit`以及`git push`你的代码变更。通过这种方式，一方面基于最新的代码，可以更容易和团队成员合作；另一方面，基础设施的变动也可以体现在commit日志中，对后期出现问题debug非常方便。

**部署单个网络服务器**

下一步就在在这个实例上运行网络服务器。目标就是部署一个可以用的、最简单的网络架构：单个网络服务器，可以响应HTTP请求。

在实际项目中，你可能用例如Ruby on Rails或者Django等网络框架来创建网络服务，为了让例子显得简洁，我们就运行一个非常简单的网络服务器，对所有请求只返回*Hello, World*：

```
#! /bin/bash
echo "Hello, World" > index.html
nohup busybox httpd -f -p 8080 &
```

这是一个Bash脚本，将“Hello, World”写入*index.html*文件中，并且运行一个*busybox*工具，在端口8080上启动web服务器并提供该文件作为响应。我将*busybox*命令和*nohup*以及&命令结合起来，这样程序可以一直在后台运行。

怎么让ECS实例运行这个脚本？就像在*服务器模板工具*讨论的那样，通常会使用诸如Packer这样的工具创建一个包含web服务器的自定义镜像，再用这个镜像创建ECS实例。但是因为本例中只有一行关于*busybox*的命令，就可以直接使用官方的ubuntu镜像，在创建ECS实例的*user-data*配置中运行"Hello, World"脚本，阿里云会在实例运行时启动这个脚本：

```
resource "alicloud_instance" "instance" {
  ...

  user_data = <<-EOF
              #! /bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags {
    Name = "terraform-example"
  }
}
```

`<<-EOF`和`EOF`使Terraform的`heredoc`语法，这样就可以创建多个字符串，而不必到处插入换行符。

在网络服务器运行之前，你还需要做一件事。阿里云默认关闭ECS上所有出入端口，你需要创建一个安全组：

```
resource "alicloud_security_group" "default" {
  name = "terraform-example"
}

resource "alicloud_security_group_rule" "allow_8080" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "internet"
  policy            = "accept"
  port_range        = "8080/8080"
  priority          = 1
  security_group_id = alicloud_security_group.default.id
  cidr_ip           = "0.0.0.0/0"
}
```

以上代码创建一个新的资源叫做*alicloud_security_group*，并为这个资源关联新的规则*alicloud_security_group_rule*，并且指定这个安全组允许来自CIDR的*0.0.0.0/0*，端口为8080的TCP请求。CIDR能够非常简洁的指明IP地址范围。例如，CIDR为10.0.0.0/24能够代表所有在10.0.0.0和10.0.0.255范围内的IP地址。CIDR为0.0.0.0/0包含了所有的IP地址，所以这个安全组允许所有IP对端口8080的传入请求。

简单创建一个安全组并不足够，需要让ECS实例去使用这个安全组。所以需要将安全组的ID传递给*alicloud_instance*资源中的参数*security_group_id*。想要取得安全组的ID，可以使用插补语法，如下所示：

`${something_to_interpolate}`

当看到一个`$`伴随大括号的时候，说明Terraform要对大括号中的文本做特殊处理。在这本书中你可以看到很多此类语法的使用，第一个用法就是查找资源的属性。Terraform中的每个资源都公开了可以使用插值访问的属性（你可以在每个资源的文档中查看可用的属性列表）。使用的语法如下：

`${TYPE.NAME.ATTRIBUTE}`

(新版本中单个参数可以直接使用`TYPE.NAME.ATTRIBUTE`)。

例如，可以使用这种方式获得安全组的ID：

`alicloud_security_group.default.id`

你可以把这个ID传递给*alicloud_instance*资源中的参数*security_group_id*：

```
resource "alicloud_instance" "instance" {
  ...
  security_group_id = alicloud_security_group.default.id

  user_data = <<-EOF
              #! /bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF
  tags {
    Name = "terraform-example"
  }
}
```

当你使用插补语法让一个资源引用另一个资源的时候，你创建了一个隐式依赖。Terraform解析这些依赖，用这些依赖建立了依赖图，并根据依赖图来理清需要创建哪些资源。例如，Terraform了解到需要在ECS创建之前创建安全组，因为ECS引用了安全组的ID。你可以通过运行*terraform graph*命令来查看依赖图。这个命令的输出格式为*DOT*的图描述语言，可以使用如Graphviz以及GraphvizOnline等应用将输出转为图片。

当Terraform遍历依赖树，它会同时尽可能多的创建需要的资源，意味着应用更改会非常快。这就是解释性语言的优美之处：你只需要表明你想要什么资源，Terraform会找到实现它最有效的方法。

如果你运行*plan*命令，你会发现Terraform想要增加一个安全组，并且将原来的ECS实例替换成包含*user_data*参数新的实例。

在Terraform中，除了标签之类的元数据，对于ECS实例的大多数更改实际上都会删除老的实例并创建一个新的实例（*和阿里云Solution Architect沟通过，如果选择包年包月的付费方式，删除原有实例并创建一个新的实例就会付双倍的钱，也不会对原有实例退费，所以对于自动化来说这是个很大的问题*）。这就是在服务器模板工具中讨论过的不可变基础设施的一个例子。值得一提的是，当网络服务器被替换的时候，你的客户会感知到停机的，你会在第五章中了解到如何用Terraform实现零停机部署。

如果*terraform plan*的结果符合你的预期，就可以执行*terraform apply*来执行所有的更改。


**部署可配置的网络服务器**

你可能注意到网络服务器代码中，端口8080重复出现在安全组和user_data配置中。这违反不要重复自己（Don't repeat yourself，DRY）的原则：每个知识点在系统内必须有单一、明确、权威的表现形式。如果同一个端口号在两个地方重复出现，那么就非常容易只更新一个地方而忘了更新另一个。

为了使得你的代码更加如何*DRY*原则并且更容易配置，Terraform允许使用输入变量（input variables）。声明一个变量的语法格式如下：

```
variable "NAME" {
  [CONFIG...]
}
```

声明变量的配置可以包含三个参数，所有参数都是可选的：

* 描述（description）：使用这个参数来记录如何使用变量。你的团队成员不仅仅会在读代码的时候看见这个参数，在执行*plan*以及*apply*的时候也会看到。

* default（默认值）：用很多不同的方式为变量赋值，包括在命令行中传递值（用-var选项）；用一个文件来传递（通过-var-file选项）；也可以通过环境变量（Terraform会去找TF_VAR_(variablename)格式的环境变量）。如果没有传递任何值，这个变量会恢复成这个默认值。

* type（变量类型）：关键字必须是string、bool或者number之一，可以结合list、set以及map构成不同类型，如list(string)等。如果没有声明一个变量类型，Terraform会根据default参数来猜测，如果没有设置default参数，Terraform则默认这个变量是一个string。

下面就是一个列变量的例子：

```
variable "list_example" {
  descrption = "An example of list variable"
  type = list(number)
  default = [1, 2, 3]
}
```

这是一个map(string)的例子：

```
variable "map_example" {
  description = "An example of map variable"
  type = map(string)
  default = {
    key1 = "value1",
    key2 = "value2",
    key3 = "value3"
  }
}
```

在网络服务器的例子中，你只需要一个数字来表示端口，这在Terraform中会自动转换为字符串，所以在变量中可以不写类型：

```
variable "server_port" {
  description = "The port the server will use for HTTP requests"
}
```

注意*server_port*参数没有设置默认值，所以如果你运行*plan*或者*apply*命令，Terraform会提示你输入这个参数的值并且显示这个参数的描述。

如果不想处理这种交互式的提醒，你可以在命令行中通过*-var*参数为变量提供一个值：

`>terraform plan -var server_port="8080"`

同样，如果也不想在每次执行命令时记住一些参数，那么可以直接为这个变量设置默认值：

```
variable "server_port" {
  description = "The port the server will use for HTTP requests"
  default = 8080
}
```

想在Terraform代码中使用这些变量的值，就可以使用插补语法。查找一个变量值的语法如下：

`${var.VARIABLE_NAME}`

新版本中，可以用`var.VARIABLE_NAME`。

例如，在ECS的*user_data*参数中，可以使用这种语法替代写成固定的端口号：

```
user_data = <<-EOF
            #! /bin/bash
            echo "Hello, World" > index.html
            nohup busybox httpd -f -p "${var.server_port}" &
            EOF
```

对于安全组中的端口号，也可以用同样的方式来赋值。

除了输入变量，Terraform也能够定义输出变量，定义格式如下：

```
output "NAME" {
  value = VALUE
}
```

例如，与其在ECS的控制面板上查看ECS的IP地址，你可以将IP地址作为输出变量：

```
output "public_ip" {
  value = alicloud_instance.instance.public_ip
}
```

上面代码同样用了插补语法，这次是引用*alicloud_instance*的*public_ip*。如果你再次运行*terraform apply*命令，因为你没有对配置做任何更改，Terraform不会做出任何更改，但是它会在输出的最后面显示最新的输出变量：

```
> terraform apply

Outputs:

public_ip = 8.133.180.4
```

如你所见，运行*terraform apply*命令之后，输出变量在控制台中出现。也可以运行*terraform output*命令来列出所有的输出变量，同时也可以指定要输出的变量 的名字来查看输出变量的值*terraform output VAR_NAME*。
```
terraform output public_ip
```

输入和输出变量是创建可配置和可重用基础设施代码的最基本要素。

**部署网络服务器集群**

运行一个服务器是一个好的开始，但是在实际生产中，单个服务器就是单点故障。如果这台服务器崩溃，或是它因为流量过多而超负荷，用户就无法访问你的网站。解决方案就是运行服务器集群，根据流量调整服务器集群的大小。

手动维护一个服务器集群工作量非常大。幸运的是，你可以让阿里云用弹性伸缩（auto scaling， ESS）来帮你维护这个集群，ESS可以完全自动地帮你做很多工作，包括部署一个服务器集群、监控每个服务器的健康状况、替换不能正常运行的服务器以及根据流量自动调整集群中服务器的数量。

以下例子展示了如何创建一个ESS以及ESS的相关配置：

```
resource "alicloud_ess_scaling_group" "default" {
  min_size           = 2
  max_size           = 10
  scaling_group_name = "terraform-example-ess"
  removal_policies   = ["OldestInstance", "NewestInstance"]
  vswitch_ids        = [alicloud_vswitch.vsw.id]

  tags {
    Name = "ess-example"
  }
}

resource "alicloud_ess_scaling_configuration" "default" {
  scaling_group_id  = alicloud_ess_scaling_group.default.id
  image_id          = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
  instance_type     = "ecs.n2.medium"
  security_group_id = alicloud_security_group.default.id
  force_delete      = true
  active            = true

  user_data = <<-EOF
              #! /bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF
}
```

在*alicloud_ess_scaling_configuration*中使用的参数和*alicloud_instance*中基本一致，所以如果需要创建ESS组，可以很容易将*alicloud_instance*中的参数复制过来。ESS配置利用插补语法引用之前创建的ESS弹性缩放组。

ESS将在2-10个ECS实例之间运行，每个实例都打上了*ess-example*标签。为了让这个ESS正常工作，需要指定一个参数：可用区*availability_zones*。这个参数告诉ESS应该将ECS实例部署到哪个AZs（可用区）。每个AZ代表一个阿里云独立的数据中心，所以可以将ECS实例部署到多个不同的数据中心，这样即使有些AZ断电，你也可以确保你的服务器一直运行。你可以写死你的AZ列表，但是每个AWS账号可以访问的AZ列表都略微不同，所以一个更好的做法就是用数据源取得你当前账号下所有的AZ：

```
data "alicloud_zones" "zones_ds" {
  available_instance_type = "ecs.n4.large"
  available_disk_category = "cloud_ssd"
}
```

*data source*代表是每次运行Terraform都会从provider获取的一条只读信息。在Terraform配置文件中加一个*data source*并不会增加新的内容；这只是查询provider的API数据的一种方法。有很多种数据源，不仅仅可以查询AZ列表，也可以查询镜像ID、IP地址范围等等。

可以根据如下格式使用*data source*:
`data.TYPE.NAME.ATTRIBUTE`

例如，可以将AZ的ID传递从*alicloud_zones*传递给*alicloud_vswitch*：
```
resource "alicloud_vswitch" "default" {
  vpc_id            = alicloud_vpc.default.id
  cidr_block        = "172.16.0.0/24"
  availability_zone = data.alicloud_zones.default.zones[0].id
  name              = "terraform-ess-example"
}
```

**部署一个负载均衡**

当前，你可以部署ESS，但是可能还有一个小问题：选择你有好几台服务器，每台都有自己的IP地址，但是通常你只想给用户提供一个IP地址来访问。解决这个问题的一种方式是部署一个负载均衡，用负载均衡在服务器之间分配流量，并为所有用户提供负载均衡的IP地址（实际上是DNS）。创建一个高可用和可扩展的负载均衡比较复杂，但是同样的，通过使用阿里云的SLB（Server Load Balancer），可以让阿里云帮你做这些工作。

用Terraform创建负载均衡，可以使用*alicloud_slb*:
```
resource "alicloud_slb" "default" {
  name          = "terraform-ess-example"
  specification = "slb.s2.small"
  vswitch_id    = alicloud_vswitch.default.id
}
```

这会创建一个SLB，在相应的*vswitch_id*下工作。显而易见，如果不为这个SLB配置规则，单单创建一个SLB也不会有很大的用处。为了更好配置SLB，可以为SLB绑定一个或者多个*listener*，指定SLB应该监听的端口以及请求需要转发的端口：
```
resource "alicloud_slb_listener" "default" {
  load_balancer_id          = alicloud_slb.default.id
  backend_port              = 80
  frontend_port             = 80
  protocol                  = "http"
  bandwidth                 = 10
  sticky_session            = "on"
  sticky_session_type       = "insert"
  cookie_timeout            = 86400
  cookie                    = "testslblistenercookie"
  x_forwarded_for {
    retrive_slb_ip = true
    retrive_slb_id = true
  }
  acl_status      = "on"
  acl_type        = "white"
  acl_id          = alicloud_slb_acl.default.id
  request_timeout = 80
  idle_timeout    = 30
}
```

使用SLB还有一个窍门：它可以周期性地检查ECS实例的健康状况，如果实例处于不健康状态，它会自动停止向该实例转发流量。可以通过*health_check*相关参数配置SLB的健康检查，如下是一个例子：向*ali.com*每隔5秒发送https请求，如果返回2或3开头的状态码即为正常，否则就是不健康状态。
```
resource "alicloud_slb_listener" "default" {
  ...
  health_check              = "on"
  health_check_domain       = "ali.com"
  health_check_uri          = "/cons"
  health_check_connect_port = 20
  healthy_threshold         = 8
  unhealthy_threshold       = 8
  health_check_timeout      = 8
  health_check_interval     = 5
  health_check_http_code    = "http_2xx,http_3xx"
  ...
}
```

SLB如何知道该向哪台服务器发送请求？可以用*alicloud_slb_attachment*将SLB与ECS实例连接起来，但是在ESS集群内，一个实例可以在任何时间开始或者停止运行，所以将实例ID与SLB结合硬编码很大可能会失效。所以回到最初的ESS资源*alicloud_ess_scaling_group*中，将*loadbalancer_ids*设置为目标SLB，这就让ESS中每个服务器在初始化结束之后都与该SLB连接：
```
resource "alicloud_ess_scaling_group" "default" {
  min_size           = 2
  max_size           = 10
  scaling_group_name = "terraform-example-ess"
  removal_policies   = ["OldestInstance", "NewestInstance"]
  vswitch_ids        = [alicloud_vswitch.vsw.id]

  loadbalancer_ids   = [alicloud_slb.default.id]

  tags {
    Name = "ess-example"
  }
}
```

在部署负载均衡之前最后应该做的一件事是将之前输出变量的单个服务器的*public_ip*修改成SLB的DNS记录：
```
output "slb_dns_name" {
  value = alicloud_slb.default.address
}
```

运行*plan*命令来验证你的更改。应该可以看到之前单个的ECS服务器已经被删除，Terraform会创建一个ESS，SLB和安全组。如果*plan*的结果符合预期，就可以运行*apply*。

**删除资源**

当你在本章结束或者本书结束，用Terraform完成你的实验之后，建议清除你创建的所有资源这样阿里云就不会继续收费。因为Terraform一直追踪所有你创建的资源，所以删除资源就非常简单。只需要运行*terraform destroy*命令：
`> terraform destroy`

确定删除之后，Terraform会创建依赖图并按正确的顺序删除所有资源。几分钟过后，所有Terraform创建的资源都会被清空。


**结论**

现在你对如何使用Terraform应该有了基本概念。因为使用的是解释性语言，所以很容易来描述你想要的具体是什么资源。*plan* 命令可以在实际部署之前验证更改以及发现bug。变量、插补语法以及依赖让代码更为简洁，易于更改配置。

但是现在也只接触到Terraform的表面，第三章中你将学习Terraform是如何追踪所有它已经创建的基础设施的，以及这对你Terraform代码结构的巨大影响；第四章，你将学习如何使用模块来创建可重复使用的Terraform代码。
