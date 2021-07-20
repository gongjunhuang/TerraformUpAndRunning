#### 性能调优

![常用命令](https://pic4.zhimg.com/80/v2-22400eb0948e28e986ee3a6d9fa5b588_1440w.jpg?source=1940ef5c)


* 不同层详解

![](https://pic1.zhimg.com/80/v2-9d70261114d9a29d55d152e265299108_1440w.jpg?source=1940ef5c)



* 静态代码检测工具或平台：cppcheck、PC-lint、Coverity、QAC C/C++、Clang-Tidy、Clang Static Analyzer、SonarCube+sonar-cxx（推荐）、Facebook的infer
* profiling工具：gnu prof、Oprofile、google gperftools（推荐）、perf、intel VTune、AMD CodeAnalyst
* 内存泄漏：valgrind、AddressSanitizer（推荐）、mtrace、dmalloc、ccmalloc、memwatch、debug_new
* CPU使用率：pidstat（推荐）、vmstat、mpstat、top、sar
* 上下文切换：pidstat（推荐）、vmstat
* 网络I/O：dstat、tcpdump（推荐）、sar
* 磁盘I/O：iostat（推荐）、dstat、sar
* 系统调用追踪：strace（推荐）
* 网络吞吐量：iftop、nethogs、sar
* 网络延迟：ping
* 文件系统空间：df
* 内存容量：free、vmstat（推荐）、sar
* 进程内存分布：pmap
* CPU负载：uptime、top
* 软中断硬中断：/proc/softirqs、/proc/interrupts


#### vmstat: Linux中常用监控内存工具，可以对操作系统虚拟内存、进程、CPU等整体情况进行监视
vmstat interval times即每隔interval秒采样一次，共采样times次

* procs: r 列现实多少进程正在等待CPU，b列现实多少进程正在不可中断的休眠（等待IO）
* memory： swapd列显示多少进程正在等待CPU，剩下的是未被使用free、缓冲区buff以及缓存cache
* swap：显示交换活动，每秒有多少块被换入和换出
* IO： 现实多少块从设备读取和写入，通常反应硬盘IO
* system：显示每秒中断和上下文切换的数量
* cpu：现实所有的CPU时间花费在各类操作的百分比，包括执行用户代码、执行系统代码，空闲以及等待IO


#### iostat 用于报告中央处理器统计信息

常见linux的磁盘IO指标的缩写习惯：rq是request,r是read,w是write,qu是queue，sz是size,a是verage,tm是time,svc是service

* rrqm/s和wrqm/s：每秒合并的读和写请求，“合并的”意味着操作系统从队列中拿出多个逻辑请求合并为一个请求到实际磁盘。

* r/s和w/s：每秒发送到设备的读和写请求数。
* rsec/s和wsec/s：每秒读和写的扇区数。
* avgrq –sz：请求的扇区数。
* avgqu –sz：在设备队列中等待的请求数。
* await：每个IO请求花费的时间。
* svctm：实际请求（服务）时间。
* %util：至少有一个活跃请求所占时间的百分比。


#### dstat

dstat显示了cpu使用情况，磁盘io情况，网络发包情况和换页情况，输出是彩色的，可读性较强，相对于vmstat和iostat的输入更加详细且较为直观。在使用时，直接输入命令即可，当然也可以使用特定参数。

**dstat -cdlmnpsy**

#### iotop linux进程实时监控工具

iotop命令是专门显示硬盘IO的命令，界面风格类似top命令，可以显示IO负载具体是由哪个进程产生的。是一个用来监视磁盘I/O使用状况的top类工具，具有与top相似的UI，其中包括PID、用户、I/O、进程等相关信息

#### pidstat 监控系统资源情况

pidstat主要用于监控全部或指定进程占用系统资源的情况,如CPU,内存、设备IO、任务切换、线程等。使用方法：pidstat –d interval；pidstat还可以用以统计CPU使用信息：pidstat –u interval；统计内存信息：Pidstat –r interval。


#### top

top命令的汇总区域显示了五个方面的系统性能信息：
* 负载：时间，登陆用户数，系统平均负载；
* 进程：运行，睡眠，停止，僵尸；
* cpu:用户态，核心态，NICE,空闲，等待IO,中断等；
* 内存：总量，已用，空闲（系统角度），缓冲，缓存；
* 交换分区：总量，已用，空闲

任务区域默认显示：进程ID,有效用户，进程优先级，NICE值，进程使用的虚拟内存，物理内存和共享内存，进程状态，CPU占用率，内存占用率，累计CPU时间，进程命令行信息。


#### mpstat

mpstat 是Multiprocessor Statistics的缩写，是实时系统监控工具。其报告与CPU的一些统计信息，这些信息存放在/proc/stat文件中。在多CPUs系统里，其不但能查看所有CPU的平均状况信息，而且能够查看特定CPU的信息。常见用法：mpstat –P ALL interval times。


#### netstat

Netstat用于显示与IP、TCP、UDP和ICMP协议相关的统计数据，一般用于检验本机各端口的网络连接情况。▲常见用法： netstat –npl   可以查看你要打开的端口是否已经打开。netstat –rn    打印路由表信息。netstat –in    提供系统上的接口信息，打印每个接口的MTU,输入分组数，输入错误，输出分组数，输出错误，冲突以及当前的输出队列的长度。

#### ps 显示当前进程的状态

ps参数太多，具体使用方法可以参考man ps，常用的方法：ps  aux  #hsserver；ps –ef |grep #hundsun
* 杀掉某一程序的方法：ps  aux | grep mysqld | grep –v grep | awk ‘{print $2 }’ xargs kill -9
* 杀掉僵尸进程：ps –eal | awk ‘{if ($2 == “Z”){print $4}}’ | xargs kill -9



#### strace

跟踪程序执行过程中产生的系统调用及接收到的信号，帮助分析程序或者命令执行中遇到的各种情况

e.g： 查看mysqld在linux上加载哪种配置文件，可以通过运行下面的命令：strace –e stat64 mysqld –print –defaults > /dev/null



#### uptime

能够打印系统总共运行了多长时间和系统的平均负载，uptime命令最后输出的三个数字的含义分别是1分钟，5分钟，15分钟内系统的平均负荷。



#### lsof

lsof(list open files)是一个列出当前系统打开文件的工具。通过lsof工具能够查看这个列表对系统检测及排错，常见的用法：
* 查看文件系统阻塞  lsof /boot
* 查看端口号被哪个进程占用   lsof  -i : 3306
* 查看用户打开哪些文件   lsof –u username
* 查看进程打开哪些文件   lsof –p  4838
* 查看远程已打开的网络链接  lsof –i @192.168.34.128



#### 性能测试工具

* perf_events: 一款随 Linux 内核代码一同发布和维护的性能诊断工具，由内核社区维护和发展。Perf 不仅可以用于应用程序的性能统计分析，也可以应用于内核代码的性能统计和分析。

* eBPF tools: 一款使用bcc进行的性能追踪的工具,eBPF map可以使用定制的eBPF程序被广泛应用于内核调优方面，也可以读取用户级的异步代码。重要的是这个外部的数据可以在用户空间管理。这个k-v格式的map数据体是通过在用户空间调用bpf系统调用创建、添加、删除等操作管理的

* perf-tools: 一款基于 perf_events (perf) 和 ftrace 的Linux性能分析调优工具集。Perf-Tools 依赖库少，使用简单。支持Linux 3.2 及以上内核版本

* bcc(BPF Compiler Collection): 一款使用eBPF的perf性能分析工具。一个用于创建高效的内核跟踪和操作程序的工具包，包括几个有用的工具和示例。利用扩展的BPF（伯克利数据包过滤器），正式称为eBPF，一个新的功能，首先被添加到Linux 3.15。多用途需要Linux 4.1以上BCC。

* ktap: 一种新型的linux脚本动态性能跟踪工具。允许用户跟踪Linux内核动态。ktap是设计给具有互操作性，允许用户调整操作的见解，排除故障和延长内核和应用程序。它类似于Linux和Solaris DTrace SystemTap。

* Flame Graphs:是一款使用perf,system tap,ktap可视化的图形软件，允许最频繁的代码路径快速准确地识别，可以是使用http://github.com/brendangregg/flamegraph中的开发源代码的程序生成。
