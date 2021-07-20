#### 索引

```
关系数据库 -> 数据库 -> 表 -> 行 -> 列

ES   -> 索引   -> 类型 -> 文档 -> 字段

一篇文档通过`_index`, `_type`以及'_id'来确定它的唯一性
```

分片 shard 是working unit底层的一员

health status为yellow，意味着所有的主分片primary shards都启动并且运行了，这时集群可以成功的处理任意请求，但是从分片replica shards没有完全被激活。

第二个节点与第一个节点的`cluster.name`相同（./config/elasticsearch.yml中配置），它就能自动发现并加入第一个节点的集群中


#### 文档

大部分程序中，实体或者对象 - 序列化为包含键值对的JSON对象
```
{
  "name" : "Java",
  "age"  : "42",
  "home": {
    "lat": 51.5,
    "lon": 0.1
  },
  "accounts": {

  }
}
```

object: 仅仅是一个JSON对象，类似于哈希，字典或者关联数组
Objects：可以包含其他对象

ES中，`文档指的是在ES中被存储到唯一ID下由最高优先级或者根对象序列化而来的JSON`


* metadata 文档元数据，
 `_index`： 文档存储的地方，索引类似于数据库中的“数据库”，是我们存储并且索引相关数据的地方
 `_type`：文档中代表的对象种类，我们使用的对象代表物品，比如一个用户、一篇博文、一条留言以及一个邮件。每个对象都属于一个类型，类型定义了对象的属性或者与数据的关联。ES中，我们使用都同样的文档来代表同类事物，因为他们的数据结构是相同的。
  `_id`：文档的唯一编号。POST或者PUT来生成唯一ID


#### 搜索文档

GET /_index/_type/_id?pretty

curl -i -XGET /_index/_type/_id?pretty

*文档一部分搜索*
GET /_index/_type/_id?_source=title,text

*检查文档是否存在*

HEAD
curl -i XHEAD /_index/_type/_id?pretty


#### 冲突 conflicts
多人同时对一个文档进行更新等操作，导致冲突

* 悲观并发控制 PCC pessimistic concurrent control

假设这种情况很常见，我们就可以阻止对这一资源的访问。典型的例子就是当我们在读取一个数据前先锁定这一行，然后确保只有读取数据的这个线程可以修改这行数据。

* 乐观并发控制

ElasticSearch使用的。假设这种情况不会经常发生，不会去阻止某一数据的访问。如果基础数据在我们读取和写入的间隔中发生了变化，更新就会失败。这时候就由程序来决定如何处理这个冲突。

ES是分布式的，当文档被创建、更新或者删除时，新版本的文档就会被复制到集群中的其他节点上。*每当有索引、PUT和删除的操作时*，_version都会增加。ES使用version来确保所有的改变操作都被正确排序。如果一个旧版本出现在新版本之后，它就会被忽略。

**PUT /website/blog/1?version=1**


#### 更新文档  update    POST /website/blog/1/_update
**文档不能被修改，只能被替换，Version会变**

* 脚本更新   MVEL      ctx._source

```
POST /website/blog/1/_update
{
  "script": "ctx._source.views+=1"
}

POST /website/blog/1/_update
{
  "script": "ctx._source.tags+=new_tag",
  "params": {
    "new_tag": "search"
  }
}

POST /website/blog/1/_update
{
  "script": "ctx.op = ctx._source.views==count ? 'delete': 'none'",
  "params": {
    "count": 1
  }
}
```

* 更新一篇可能不存在的文档

**upsert** 不能确保某个属性已经存在，用upsert假定该文档不存在，其应该被创建

```
POST /website/pageviews/1/_update
{
  "script": "ctx._source.views+=1",
  "upsert": {
    "views": 1
  }
}
```


* 更新和冲突    

**retry_on_conflicts**

```
POST /website/pageviews/1/_update?retry_on_conflicts=5
```

#### 获取多个文档

* multi-get / mget

```
GET /_mget
{
  "docs": [
    {
      "_index": "website",
      "_type": "blog",
      "_id": 2
    },
    {
      "_index": "website",
      "_type": "pageviews",
      "_id": 1,
      "_source": "views"
    }
  ]
}

GET /website/blog/_mget
{
  "docs": [
    {"_id": 2},
    {"_type": "pageviews", "_id": 1}
  ]
}
```

#### 批量  bulk

*bulk*可以同时执行多个请求，比如create、index、update以及delete。

主体：
```
{ action: { metadata }}\n
{ request body }\n
{ action: { metadata }}\n
{ request body }\n
```
* 每一行结尾必须有换行符*\n*，最后一行也要有
* 行里不能包含非转义字符
* action必须是create, index, update以及delete
* 每个请求单独执行，互不影响
* bulk请求可以在url中声明 */_index* 或者*/_index/_type*

```
{ "delete": {"_index": "website", "_type": "blog", "_id": "123" }}

{ "create": {"_index": "website", "_type": "blog", "_id": "123" }}
{ "title": "My first blog post" }
```



#### 重点关注概念

* 映射mapping：每个字段中的数据如何被解释
* 统计analysis：可搜索的全文是如何被处理的
* 查询query DSL：ES使用的查询语言


* 分页
- size: 每次返回多少结果，默认值为10
- from：忽略最初的几条结果，默认值为0

```
GET /_search?size=5
GET /_search?size=5?from=5
GET /_search?size=5?from=10
```



#### 精简搜索

GET /_all/tweet/_search?q=tweet:elasticsearch

```
GET /_all/tweet/_search?q=tweet:elasticsearch

查询name为john，tweet字段为mary的文档

+name:john +tweet:mary

百分号编码 percent encoding

':'	'/'	'?'	'#'	'['	']'	'@'	'!'	'$'	'&'	"'"	'('	')'	'*'	'+'	','	';'	'='	'%'	' '
%3A	%2F	%3F	%23	%5B	%5D	%40	%21	%24	%26	%27	%28	%29	%2A	%2B	%2C	%3B	%3D	%25	%20 or +

GET /_search?q=%2Bname%3Ajohn+%2Btweet%3Amary
```
