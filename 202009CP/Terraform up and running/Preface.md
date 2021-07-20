### 前言

**本书中所有例子都将用Aliyun来展示**

*中二风*

很久很久以前，在遥远的数据中心，有一群古老且强大的生物被称作系统管理员。每一个服务器、负载均衡、数据库乃至网络配置的每一个部分，都是由他们手动创建并管理的。这是一个黑暗的、令人恐惧的时代：对停机的恐惧、对偶然错误配置的恐慌、对缓慢而易错的部署过程的担忧等，其中最让人害怕的还是系统管理员堕入黑暗面（比如外出度假）。好消息是随着DevOps概念的兴起，现在我们有了一个更好的选择来做这些事：Terraform。

Terraform是由HashiCorp开源的自动化部署工具，可以让你以陈述式的编程语言定义你的基础设置即代码（IaC），并且支持在不同的公有云平台（Azure，AWS，Aliyun，Google Cloud）或私有云平台（Openstack，VMWare）上方便地部署且管理你的基础设施。例如，相比于在网页上手动点击或者输入很多命令，这是在Aliyun上创建一个虚拟机所需要的所有Terraform代码：
```
# Configure the Alicloud Provider
provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

data "alicloud_instance_types" "c2g4" {
  cpu_core_count = 2
  memory_size    = 4
}

data "alicloud_images" "default" {
  name_regex  = "^ubuntu"
  most_recent = true
  owners      = "system"
}

# Create a web server
resource "alicloud_instance" "web" {
  image_id              = "${data.alicloud_images.default.images.0.id}"
  internet_charge_type  = "PayByBandwidth"

  instance_type        = "${data.alicloud_instance_types.c2g4.instance_types.0.id}"
  system_disk_category = "cloud_efficiency"
  security_groups      = ["${alicloud_security_group.default.id}"]
  instance_name        = "web"
  vswitch_id           = "vsw-abc12345"
}
```
部署这些代码，你只需要运行一条命令：

`> terraform apply`

由于用起来简单并且功能强大，Terraform在DevOps工作中发挥着越来越重要的作用。它能够让你将日常工作中乏味的、易错的、手动的系统管理工作替换成稳定的、自动化 的平台，在上面你可以创建几乎所有其他的DevOps实践，例如自动化测试，CI/CD和工具配置（Docker，Ansible等）。

*看这本书是让Terraform跑起来最快的方式。*（雾）

你将从最基础的Terraform版本的“hello, world”开始学起，在仅仅几个章节中你将学习如何运行能够支持大量流量和大量开发人员的完整技术栈（服务器集群、负载均衡、数据库等）。这是一个需要亲自上手的教程，不仅仅教你什么是DevOps以及创建基础设施即代码的原则，而且带你过一些你可以在家动手尝试的代码例子，所以请确保你手边有台可用的电脑。

等到你学完这本书，你一定能够在实际工作中使用Terraform。

**谁应该看这本书**

这本书适合任何需要对代码负责的人，包括但不限于系统管理员、运维人员、SRE、DevOps工程师、基础架构开发、全栈开发乃至开发经理和CTO。不管你的头衔是什么，如果你负责你团队的基础设施或是负责部署代码，或者你需要配置服务器、扩展集群、备份数据、监控应用和告警等，这本书就是为你准备的。

以上这些行为在一般统称为`运维`。在以前，开发通常是只知道怎么写代码，但是不知道如何运维；同样的，系统管理员通常只知道运维而不清楚如何写代码。你可以摆脱过去那种鸿沟，但是在当今世界，随着云计算的兴起，DevOps变得无处不在，当前可能每一个开发者都需要了解如何运维自己写的代码，同时每个运维都得了解如何去写代码。

这本书并没有假定你已经是开发或者系统管理方面的专家，对编程和系统知识有基本了解已经足够学习这本书中的内容。*你需要的所有其他内容都可以随手取用*，因此，到本书末尾，你将牢固掌握现代化开发和操作最关键的方面之一：如何管理基础设施即代码。

实际上，你不仅仅可以学到如何管理基础设施即代码，并且可以学习如何将IaC带入到DevOps工作当中。以下这些问题看完这本书后你就能知道如何回答：
* 为什么使用IaC ？
* 配置管理、服务器模板之间有什么区别？
* 什么时候你应该使用Terraform、Chef、Ansible、Docker或是Packer？
* Terraform是如何工作的？你是怎么通过Terraform管理你的基础设施的？
* 如何将Terraform集成到自动化测试部署的一部分？
* 团队使用Terraform的最佳实践是什么？

*学习这本书你只需要一台能联网的电脑以及一颗想学习的心。*（雾）

**为什么写这本书？**

Terraform是一个强大的工具，它在所有流行的云平台上都能使用。它使用一种简单、干净的编程语言，并且支持复用、测试和版本控制。它是开源的，开源社区活跃且友善。但是它有一个缺点：太年轻了。
写这本书的时候，Terraform才开源两年。所以很难找到Terraform相关的书籍、博客或是相关专家来帮助你如何使用这个工具。如果你尝试从Terraform官方文档去学习如何使用Terraform，你会发现官方文档很好地介绍了基本语法和特性，但是它几乎没有介绍Terraform的惯用模式、最佳实践、测试以及如何复用，或是如何在团队中使用，就像想要流利说法语却只学习词汇而不学习语法和成语一样。

我写这本书的原因是想让开发们熟悉Terraform。我用Terraform已经超过一年，我花了很多时间去实验Terraform有哪些特性能够工作，有哪些不能。我的目标是分享我学到的知识，从而你可以避免漫长的学习路径，在短时间能够熟悉Terraform。

显而易见，你不能仅仅通过阅读就能熟悉Terraform。想要流利说法语，你必须花时间和法国本地人交谈、看法国电影、听法语歌曲。想要熟悉Terraform，你必须动手去写Terraform代码，用这些代码去管理真正的应用，并在真正的服务器上部署这些应用。因此，准备好阅读、写并且执行大量的代码。

**主要章节**

*第一章：为什么用Terraform？*

DevOps是如何改变我们运行软件的方式？对IaC工具的概述，包括配置管理、服务器模板等；IaC的优势；Terraform、Puppet、Ansible、OpenStack和CloudFormation等工具的比较。

*第二章：开始使用Terraform*

安装Terraform；Terraform语法概述；Terraform CLI工具介绍；如何部署单个服务器；如何部署网络服务器；如何部署网络服务器集群；如何部署负载均衡；如何清除你创建的资源。

*第三章：如何管理Terraform状态文件？*

什么是Terraform状态文件；如何存放状态文件从而让团队成员都能访问；如何给状态文件加锁从而防止被误改；如何隔离文件以限制错误造成的损害；Terraform项目的文件结构的最佳实践；如何使用read-only状态。

*第四章：如何通过Terraform模块创建可复用基础设施？*

什么是模块；如何建立一个基础模块；如何让一个模块可配置；版本化模块；模块的小技巧和窍门；使用模块去定义可复用、可配置的基础设施。

*第五章：Terraform技巧和窍门：循环、IF语句、部署和陷阱*

高级Terraform语法：循环；if语句；if-else语句；插补方法；不停机部署；常见Terraform陷阱

*第六章：团队中如何协同使用Terraform？*

版本控制；Terraform的黄金法则；编码准则；Terraform风格；Terraform自动化测试；文档；团队的工作流；Terraform自动化


**这本书中没有的内容**

这本书不是Terraform的详尽使用手册。我没有涵盖所有流行的云服务商，同时也没有触及到云服务下的所有资源，抑或Terraform中的每条命令。对于这些细节，请查阅[官方文档](https://www.terraform.io/docs/index.html)。

官方文档涵盖了很多有用的答案，但是如果你刚接触Terraform、IaC或者运维，你可能不知道该问什么问题。因此，这本书主要着重在官方文档没有涵盖的内容上：即，如何超过入门示例，在实际工程中使用Terraform。我的目标是通过探讨为什么你肯恩恶搞想要使用Terraform，如何让Terraform进入你的工作技能栈，让你很快入门Terraform。

为了展示这些模式，我在书中加入了很多代码示例。我尝试减少对第三方的依赖，从而尽可能简单的让你在家运行这些例子。

**开源代码**

[书中示例开源仓库](https://github.com/brikis98/terraform-up-and-running-code)

`> git clone https://github.com/brikis98/terraform-up-and-running-code.git`

Github仓库中的代码是按章节划分的，大多数示例在本章末尾向你展示的代码是毫无意义的。为了最大化你的学习，你最好从头开始自己写代码。

在第二章你将开始写代码，你将会学习如何使用Terraform从头开始部署网络服务器集群。在那之后，将跟随每个章节的指导去改进网络服务器集群。从头开始自己写代码，跟着每章的指导去改动，仅仅把Github仓库中的代码当作参考。
