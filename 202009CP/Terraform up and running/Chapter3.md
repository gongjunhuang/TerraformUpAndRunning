### 第三章：如何管理Terraform状态文件

第二章中，在使用Terraform创建以及更新资源的时候，你可能已经注意到当你每次执行*terraform plan*或者*terrraform apply*的时候，Terraform能够找到它之前创建的资源并逐个更新。但是Terraform是如何了解它要管理哪些资源呢？在你的阿里云账号下面，你可以用各种各样不同的方式部署各种资源，包括手动部署、CLI命令部署以及Terraform部署，所以Terraform是如何了解它应该负责管理哪些资源？

本章中，你将了解Terraform是如何追踪基础设施的状态以及状态对Terraform项目中文件布局、隔离以及状态锁的影响。下列是关键主题：
* 什么是Terraform状态？
* 状态文件的共享存储
* 状态文件的锁
* 隔离状态文件
* 文件布局
* 只读状态

**什么是Terraform状态？**

每次你运行Terraform，它会在一个*Terraform状态文件*记录创建的所有基础设施。当你在*/foo/bar*文件夹下运行Terraform，Terraform会创建文件*/foo/bar/terraform.tfstate*。这个文件包含自定义Json格式，其中记录了从配置文件中的Terraform资源到现实世界中这些资源的表现形式的映射。例如，如果你的Terraform是如下配置的：
```
resource "alicloud_resource_manager_resource_group" "rg" {
  name         = var.resource_group_name
  display_name = var.resource_group_display_name
}
```

在运行`terraform apply`命令之后，下面是`terraform.tfstate`的一部分内容：
```
{
      "mode": "managed",
      "type": "alicloud_resource_manager_resource_group",
      "name": "cp-rg",
      "provider": "provider[\"registry.terraform.io/aliyun/alicloud\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "account_id": "xxxxxxxxxx",
            "create_date": "2021-01-14T18:07:45+08:00",
            "display_name": "{Display name}",
            "id": "rg-aexxxxxxxxxxxxxxxxx",
            "name": "{resource group name}",
            "region_statuses": [
              {
                "region_id": "ap-northeast-1",
                "status": "OK"
              }
            ],
            "status": "OK",
            "timeouts": null
          },
          "private": "XXXXXXXX=="
        }
      ]
    },
```

使用这种简单的Json格式，Terraform能够了解`alicloud_resource_group_manager.default`对应你账号中的一个资源组，并且该资源组的ID为**。每次你运行Terraform的时候，它能从阿里云获得这个资源组的最新状态，并且与Terraform配置中的状态进行比较，以确定是否要对这个资源进行更改。

如果你在个人项目中使用Terraform，可以把状态文件存储为本地的`terraform.tfstate`文件。但是如果整个团队要在实际项目中使用Terraform，把状态文件存储在本地就会出现问题：

* 状态文件的共享存储：为了能够使用Terraform更新基础设施，团队中的每个成员都必须能够访问同一个状态文件。这意味着状态文件需要被存储在可以被公共访问的地方。

* 状态文件锁：一旦数据被共享，你就会面临一个新的问题：锁。如果没有锁，两个团队成员在同一时间运行Terraform文件，这时多个Terraform进程对状态文件同时进行更新，可能会导致更改冲突、数据丢失以及状态文件崩溃。

* 隔离状态文件：当对基础设施做变更的时候，最好隔离不同的环境。例如，当对test或staging环境进行更改的时候，你需要确认不会对production产生任何影响。但是当你所有的基础设施都是以同一个状态文件定义的，你要怎么去隔离你对不同环境的变更？

在下文中，我将深入这些问题并教你如何解决这些问题。

**状态文件的共享存储**

允许不同团队成员访问同一组文件最常用的方式是将这些文件放到版本控制仓库中。但是版本控制不适用于状态文件，主要有两个原因：

* 人工错误：在运行Terraform之前很容易就会忘记从版本控制中拉取最新的更新，或者忘记在运行Terraform之后把最新的状态文件推送到版本控制仓库中。 团队中成员执行使用的状态文件导致基础设施回退到之前的部署只是时间问题。

* 密码：Terraform状态文件中所有文件都是明文存储的，这是一个问题，因为一些Terraform资源需要存储敏感信息。例如，如果你使用`alicloud_db_instance`资源去创建一个数据库实例，Terraform会将用户名和密码以铭文存储在状态文件中。将密码铭文存储在任何地方都是一种坏习惯，包括存储在版本控制中。

管理共享的状态文件最好的方式是用Terraform内置的*远程状态存储*而不是使用版本控制仓库。使用*terrform remote config*命令，你可以配置Terraform让它在每次运行的时候从远端存储获取状态文件。当前已经支持一些远端存储，包括AWS S3、Azure Storage以及阿里云OSS存储等。

如果在阿里云上使用Terraform，则可以使用阿里云OSS存储（Object storage service），有以下原因：

* 不需要额外的部署来使用，阿里云portal上手动创建或者也可以通过Terraform创建

* 提供99.9999999999%(12个9)的数据持久性

* OSS支持加密，这样即便在状态文件中存储敏感信息也不需要担心。团队中所有可以访问这个OSS存储的人都可以看到未加密的状态文件，所以这也仍是一个不完美的解决方案，但是至少数据在传输过程中都是加密的。

* 支持版本控制，所以你每个版本的状态文件都会被存储，如果新版本出现问题可以很容易回退到之前正常的版本。

* 价格便宜

使用OSS远端存储的第一步就是创建一个OSS存储。在新文件夹中建立一个*main.tf*文件，在文件最开始，指定阿里云为provider：
```
provider "alicloud" {}
```

下一步，使用*alicloud_oss_bucket*来创建OSS存储：
```
resource "alicloud_oss_bucket" "terraform_state" {
  bucket = "bucket-170309-versioning"
  acl    = "private"

  versioning {
    status = "Enabled"
  }
}
```

上面代码设置三个变量：

* bucket：OSS存储的名字。注意这个名字必须是唯一的，记住这个名字以及OSS所属的区域，后续要用到。

* acl：限制访问权限，有private、public-read以及public-read-write。

* versioning：这个代码块在OSS存储上启用版本控制，所以每个对文件的更新实际上都是创建了一个新版本。版本控制可以让你看到之前的老版本并且需要的话能够回退到老版本。

运行*terraform plan*，如果一切看起来正常的话就运行*terraform apply*。结束之后你就有一个OSS存储，但是这次运行的Terraform状态文件仍然是存储在本地的。想要让Terraform将状态文件存储到OSS存储中，运行下面的命令：
```
> terraform remote config \
    -backend=oss \
    -backend-config="bucket=(Your bucket name)" \
    -backedn-config="key=staging/terraform.tfstate"
    -backend-config="region=cn-shanghai"
    -backend-config="encrypt=true"
```

运行这个命令之后，你的Terraform状态文件会存储在OSS存储中。你可以在浏览器中登陆阿里云控制台去查看你创建的OSS存储。因为启用了版本控制，Terraform在运行命令时会自动从OSS存储中拉取最新的状态文件，并且自动将运行命令后生成的最新状态文件上推送到OSS存储中。为了查看这个特性，可以在代码中加入一个输出变量：
```
output "oss_bucket_id" {
  value = alicloud_oss_bucket.terraform_state.id
}
```

这个变量将把这个存储的ID打印出来，运行*terraform apply*将会看到输出。再去OSS控制台，刷新页面之后你将会看到OSS存储中有不同版本的*terraform.tfstate*状态文件。这说明Terraform自动推送和拉取最新的状态文件，OSS中也存储着状态文件的每次更改，对debug以及出现问题时回退到老版本非常有效。

**状态文件锁**

启用远程状态文件能够让组内成员共享这个状态文件，但同时也引入了两个新问题：

* 团队中每个成员都需要记住为每个项目运行*terraform remote config*命令，这很容易忘记或者搞乱这个长命令。

* 尽管Terraform远端存储能够确保你的状态文件存储在OSS中，但是没有给这个存储加锁，因此，两个开发同时在同一状态文件运行Terraform命令的情况仍然存在。

当前Terraform支持使用*backend*配置远端状态文件存储。OSS Backend是基于阿里云的表格存储服务（Tablestore）和对象存储服务（OSS）实现的Standard Backend，其中Tablestore用来存储运行过程中产生的“Locking”，保证State的正确性和完整性；OSS用来存储最终的State文件。接下来将详细介绍OSS Backend。OSS Backend的工作流程可以分为加锁、存储State、释放锁三步，主要包含以下几个部分：
* 运行Terraform命令后，Backend首先会从Tablestore中获取LockID，如果已经存在，表明State被损坏或者有人正在操作，返回报错，否则，自动生成一个LockID并存储在Tablestore中。
* 如果是init命令，初次会生成一个新的state文件并存储在OSS的特定目录下，并释放LockID。
* 如果是plan、apply、destroy等涉及到修改State的命令，会在命令结束后将最新的数据同步更新到State文件中，并释放LockID。
* 如果是 state、show 等不涉及修改的操作，会直接读取State内容并返回。

和Provider和Provisioner一样，Backend在使用时同样需要在模板中定义。Backend 通过关键字backend来声明。如下代码声明了一个oss backend，其state存储在名为terraform-oss-backend-1024的bucket中，对应的文件为prod/terraform.tfstate，并声明state文件为只读和加密；锁信息存储在一个名为terraform-oss-backend-1024的表格中，这个表格位于杭州的Tablestore实例tf-oss-backend中：
```
terraform {
  backend "oss" {
    profile             = "terraform"
    bucket              = "terraform-oss-backend-1024"
    key                 = "prod/terraform.tfstate"
    tablestore_endpoint = "https://tf-oss-backend.cn-hangzhou.Tablestore.aliyuncs.com"
    tablestore_table    = "terraform-oss-backend-1024"
    acl                 = "private"
    encrypt             = true
    ...
  }
}
```

对backend的定义包含如下几个部分：
* terraform为运行主体，定义了Backend的操作主体。Backend的逻辑实现是存放在Terraform仓库中的，服务于所有Provider和Provisioner，因此它的运行主体是terraform ，而不是具体某个Provider。
* oss 为Backend类型，用来标识一个特定的Backend。
* 大括号里面的内容为参数配置，用来定义Backend属性，例如鉴权信息，OSS Bucket的名称，存放路径，Tablestore配置信息等。更多参数和含义可参考[官方文档](https://www.terraform.io/docs/backends/types/oss.html)。


**隔离状态文件**

使用远端存储以及加锁之后，合作使用Terraform就非常容易，但是仍然存在一个问题：数据隔离。当你刚开始使用Terraform的时候，你可能将所有的基础设施资源都定义在一个文件或是同一个文件夹中。这样做的问题就是你所有的资源状态都将存储在一个状态文件中，一个小的错误将会导致状态不可用。

例如，当你想要在staging环境部署一个新版本的APP，你可能会将production中的APP弄崩溃。更严重的是，整个状态文件可能会崩溃，可能是没有用锁，也可能是Terraform本身的bug。

使用不同环境的重点在于将这些环境互相隔离，如果使用同一组Terraform配置管理所有的环境，就不能将环境互相隔离。为了让环境互相隔离，需要将每个环境的配置文件放到单独的文件夹中。例如，staging环境所有的Terraform相关代码放到staging文件夹中，production也同样。如果用这种方式，Terraform会为每个环境创建独立的状态文件，这样每个环境的状态文件不会影响到其他环境。

实际上，你可能想要将隔离的概念超出环境并落到组件的级别上，组件就是关系比较紧密、通常会一起部署的资源。例如，一旦你为你的基础设施建立好网络拓扑结构-阿里云中的VPC（virtual private network）以及所有相关的subnets、VPN以及ACL规则，之后可能很长时间都不会对这些网络结构进行变动。换句话说，你可能每天都会部署新版本的网络服务器，如果你将VPC相关的Terraform配置和网络服务器的相关配置放到一起，这样就会不可避免的把整个网络结构放到可能会被破坏的风险当中。

因此，我建议将每个环境以及每个组件放入不同的文件夹当中，这样每个组件都会创建各自的状态文件。

Terraform顶级文件布局：
```
stage: 非生产环境
production: 生产环境
mgmt: DevOps tooling环境
glabal: 所有环境适用资源，如OSS
```

每个环境中，每个组件都有自己的文件夹，每个项目中的组件各有不同，但是基本上类似于这样：
```
vpc: 环境的网络拓扑结构
services: 环境中运行的APP或者为服务等
data-storage: 数据存储，如MSSQL或者mysql等。
```

每个组件内部，就是Terraform配置文件，以类似下列的命名规则来命名：
```
vars.tf: 输入变量
outputs.tf: 输出变量
main.tf: 实际上要创建的资源
```

当你运行Terraform的时候，它就会在当前的文件夹下寻找扩展名为*.tf*的文件，所以你可以给文件取任何名字。用一个一致的命名规则可以更容易浏览查阅代码，如果Terraform配置文件变得很大，也可以将文件以不同的功能分成多个文件，这也说明你应该将代码分成更小的模块，我们将在第四章中谈到这个。

之前创建的OSS存储应该移到*global/oss*文件夹中，注意需要把*oss_bucket_id*移动到*outputs.tf*中。如果配置了远端存储，注意不要忘记拷贝*.terraform*文件夹。第二章中创建的服务器集群需要移到*stage/services/webserver-cluster*中，将输入变量放入*inputs.tf*中，输出变量移动到*outputs.tf*中。

这样的文件布局可以更容易地阅读代码并且了解每个环境中部署了哪些资源。这也对不同环境以及每个环境中的不同组件进行了很大程度的隔离，这样可以确保即便代码发生了问题，也只局限在某个很小的部分当中。

这种做法在某种程度上也有缺点：虽然可以避免执行某条命令造成很多组件的损坏，但也不能用一条命令创建所有的资源。如果所有的组件都定义在一个Terraform配置文件中，你可以用一个*terraform apply*命令创建所有的资源。如果所有的组件都是放在不同的文件夹中，那么需要在每个文件夹中分别运行*terraform apply*命令。

这种文件布局还有一个问题：更难使用资源依赖。如果应用代码都在一个配置文件中定义，那么你可以通过插补愈发非常简单地使用其他资源的属性。但是如果应用代码和数据库代码在不同的文件夹中定义，就不能简单通过插补语法引用。幸运的是，Terraform提供一个解决方案：只读状态。


**只读状态**

第二章中，你使用数据源获取阿里云中的只读信息，例如*alicloud_avalability_zones*这样返回一个可用区列表的数据源。在使用状态文件的时候，有另一个非常有用的数据源叫做*terraform_remote_state*。你可以使用这个数据源以只读方式去获取其他Terraform配置运行之后产生的Terraform状态文件。

例如，如果你的网络服务器集群需要和MySQL数据库通信，运行一个安全、持久的以及高可用的数据库需要很大的努力。同样的，你可以让阿里云来为你做这些事情，使用阿里云的RDS数据库（Relational Database Service，关系型云数据库）。RDS支持很多数据库，包括MySQL、MSSQL以及PostgreSQL等。

你可能不想把数据库相关的Terraform配置和网络服务器的配置放在一起，因为网络服务器经常会部署更新，如果所有配置文件放在一起，每次更新的时候数据库会有被弄错配置而挂掉的风险。因此，第一步应该做的就是创建一个新的文件夹*stage/data-stores/mysql*并且创建基本的Terraform配置文件（*main.tf, vars.tf, outputs.tf*)。下一步就是在*main.tf*中写入相关配置：
```
provider "alicloud" {}

data "alicloud_zones" "example" {
  available_resource_creation = "Rds"
}

resource "alicloud_vpc" "example" {
  name       = "testdbinstance"
  cidr_block = "172.16.0.0/16"
}

resource "alicloud_vswitch" "example" {
  vpc_id            = alicloud_vpc.example.id
  cidr_block        = "172.16.0.0/24"
  availability_zone = data.alicloud_zones.example.zones[0].id
  name              = var.name
}

resource "alicloud_db_instance" "example" {
  engine               = "MySQL"
  engine_version       = "5.6"
  instance_type        = "rds.mysql.s2.large"
  instance_storage     = "30"
  instance_charge_type = "Postpaid"
  instance_name        = var.name
  vswitch_id           = alicloud_vswitch.example.id
  monitoring_period    = "60"
}
```

配置文件的最上面就是*provider*，而创建RDS最主要的是*alicloud_db_instance*资源，这个资源在阿里云中创建一个数据库。代码中的配置创建一个运行MySQL的RDS，30G大小运行在*rds.mysql.s2.large*实例上。

下一步，配置远端状态存储让RDS把状态储存在OSS上，把key设置成*stage/data-stores/mysql/terraform.tfstate*。提醒一下，Terraform将所有变量以明文存储在状态文件中，包括数据库密码（如果设置的话），所以请确保配置远端存储时使用加密。注意，如果配置中有密码的话，在*variables.tf*中定义时一定不要加上*default*参数，必须确保不要将密码或者其他敏感信息以明文存储，应该用密码管理工具存储所有的密码，例如1Password、LastPass以及OS X KeyChain等，并且以环境变量的形式将密码传给Terraform。对于每个变量*foo*，你可以用环境变量的形式*TF_VAR_foo*将这个变量的值传给Terraform。例如*var.name*输入变量，下面就是在Unix/Linux中如何传入这个变量值的示例：

```
> export TF_VAR_name = "you db name"
```

下一步运行*terraform plan*， 如果结果没有问题就运行*terraform apply*来创建数据库。注意创建RDS的过程一般比较长，这一步需要耐心等待。运行之后，一个RDS数据库就被创建出来，但是如何给网络服务器集群提供端口和地址呢？第一步就是在*stage/data-stores/mysql/outputs.tf*中加入两个输出变量：

```
output "connection_string" {
  description = "connection string for the RDS"
  value = alicloud_db_instance.example.connection_string
}

output "port" {
  description = "Port number for the RDS mysql instance"
  value = alicloud_db_instance.example.port
}
```

加入输出变量之后再运行*terraform apply*命令，可以在终端中看到新加入的输出变量：
```
> terraform apply
(...)

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

connection_string: ********
port: 3306
```

现在这些输出变量现在存储在RDS的OSS远端存储中：*stage/data_stores/mysql/terraform.tfstate*。可以在网络服务器集群的Terraform配置*stage/services/webserver-cluster/main.tf*中通过数据源*terraform_remote_state*调用RDS的状态文件：

```
data "terraform_remote_state" "db" {
  backend = "oss"

  config {
    bucket = "{YOUR_BUCKET_NAME}"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "cn-shanghai"
  }
}
```

此处*terraform_remote_state*的意思是：网络服务器集群的配置从OSS存储中读取RDS数据库的状态文件，并作为数据源使用该状态文件的输出变量。这里非常重要的一点是：同所有其他的Terraform数据源一样，*terraform_remote_state* 返回的所有数据都是只读的。网络服务的Terraform配置无法对RDS的状态文件作出任何更改，所以可以毫无风险地使用从OSS存储中拉取RDS的状态文件，引用它的输出变量，不用担心会对数据库自身造成任何影响。

所有数据库的输出变量都存放在状态文件中，可以通过插补语法用*terraform_remote_state*从状态文件中读取这些输出变量：
`data.terraform_remote_state.NAME.ATTRIBUTE`

例如，可以在利用*terraform_remote_state*中获取的connection_string以及port变量更新网络服务器*user_data*中的HTTP响应数据：
```
user_data = <<EOF
#!/bin/bash
echo "Hello, World" >> index.html
echo data.terraform_remote_state.db.connection_string >> index.html
echo data.terraform_remote_state.db.port >> index.html
nohup busybox httpd -f -p var.server_port &
EOF
```

当*user_data*脚本越来越长，在Terraform配置中内置定义这些语句就变得越来越容易混乱。总体而言，在一个编程语言中嵌入另一个脚本语言（Bash，Python），维护起来会非常困难，所以最好将Bash脚本以单独文件存放。可以使用*file*方法以及*template_file*数据源来做这件事。插补方法就是以如下方式使用Terraform以插补语法：

*${some_function(...)}*

例如，以如下方式使用*format*方法：“${format(FMT, ARGS, ....)}”， 这个方法根据字符串*FMT*中的*sprintf*语法来格式化*ARGS*中的参数。运行*terraform console*命令是一个非常好的学习方式，运行命令后会弹出一个交互命令窗，在那里可以尝试不同的Terraform语法，也可以查询基础设施的状态，输入命令后即刻返回结果：

```
terraform console

> format("%.3f", 3.1415926)
3.142
```

注意*terraform console*的交互窗口是只读的，所以不用担心会改变基础设施或者状态文件。

Terraform有很多内置的方法，可以用于字符串、数字、队列等。*file* 就是常用的Terraform内置方法：*${file(PATH)}*。这个方法读取*PATH*文件中的内容并将其作为字符串返回。例如，可以将User Data的脚本存放在*stage/services/web-servers/user-data.sh*中，并在*alicloud_instance*中以*user_data*来加载这个脚本：
```
resource "alicloud_instance" "instance" {
  ...
  user_data = file("ser-data.sh")
}
```

需要注意的是网络服务器的User Data脚本需要从Terraform获取一些动态的数据，包括服务器端口号、数据库连接字符串以及数据库端口等。当脚本内置于Terraform代码中，可以使用插补语法从Terraform资源中获取这些值，但是使用*file*方法的时候，就没法在脚本文件中使用插补语法。Terraform为此提供了*template_file*数据源来应对这种情况，在*stage/services/web-servers/main.tf*文件中加入*template_file*数据源：

```
data "template_file" "user_data" {
  template = file("user_data.sh")

  vars {
    db_connection_str  = data.terraform_remote_state.db.connection_string
    db_port            = data.terraform_remote_state.db.port
    server_port        = var.server_port
  }
}
```

这个data数据源将*user_data.sh*中的内容设置为*template*参数，并将脚本中需要的两个参数*connection_string*以及*db_port*用*vars*来设置。为了能够使用这些变量，需要对*user_data.sh*脚本进行相应更改：
```
#!/bin/bash

cat > index.html <<EOF

<h1>Hello, World!</h1>
<p>DB connection string: ${db_connection_str}</p>
<p>DB port: ${db_port}</p>
EOF

nohup busybox httpd -f -p "$server_port}" &
```

注意Bash脚本与原来相比，变更了几个地方：
* 它使用Terraform标准的插补语法查询变量，但是只有在*data_template*数据源*vars*参数下的变量才是有效的变量。在脚本中访问变量的时候不需要加前缀，应该使用*server_port*而不是*var.server_port*。

* 脚本当前加入HTML语法，让输出在网络浏览器中更易于阅读。

最后一步就是在*alicloud_ess_scaling_configuration*中更新*user_data*参数，指向*template_file*数据源的*rendered*输出：
```
resource "alicloud_ess_scaling_configuration" "default" {
  scaling_group_id  = alicloud_ess_scaling_group.default.id
  image_id          = "ubuntu_18_04_64_20G_alibase_20190624.vhd"
  instance_type     = "ecs.n2.small"
  security_group_id = alicloud_security_group.default.id
  force_delete      = true
  active            = true

  user_data = data.template_file.user_data.rendered
}
```

通过*terraform apply*命令部署更新之后，等到服务器和负载均衡绑定之后，打开负载均衡的URL，就能看到*user_data.sh*返回的内容。

**结论**

在写Terraform代码的时候需要考虑很多关于隔离、加锁以及状态文件管理的原因是：基础设施即代码（IaC）相对传统写代码有很多基于自身的考量。当写一个普通APP的时候，大多数的bug相对来说都是很小的、只会影响app的部分功能。当使用代码管理你的基础设施，一旦出现bug，相对来说更严重，因为一个bug可以影响到所有运行在该基础设施上的app，同样也可能影响数据库、网络等一切其他服务。因此，相比其他代码，在写IaC相关代码的时候，我建议引入更严格的安全机制。

对于使用建议的文件布局，一个常见的担忧是重复文件太多。如果想要在staging以及production环境中都运行网络服务器集群，该如何避免复制粘贴很多同样的代码？答案就是应该使用Terraform模块，这就是第四章的主题。
