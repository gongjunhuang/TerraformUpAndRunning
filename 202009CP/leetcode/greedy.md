### 贪心算法
#### 算法解释
贪心算法采用贪心的策略，保证每次操作都是局部最优的，从而使得最后的结果是全局最优的。

#### 分配问题
#### 455 [assign cookies](https://leetcode-cn.com/problems/assign-cookies/)
* 描述： 假设你是一位很棒的家长，想要给你的孩子们一些小饼干。但是，每个孩子最多只能给一块饼干。

对每个孩子 i，都有一个胃口值 g[i]，这是能让孩子们满足胃口的饼干的最小尺寸；并且每块饼干 j，都有一个尺寸 s[j] 。如果 s[j] >= g[i]，我们可以将这个饼干 j 分配给孩子 i ，这个孩子会得到满足。你的目标是尽可能满足越多数量的孩子，并输出这个最大数值。
* 输入数组g表示孩子的胃口值，输入饼干尺寸数组s，输入得到满足的孩子数量
```
输入: g = [1,2,3], s = [1,1]
输出: 1
解释:
你有三个孩子和两块小饼干，3个孩子的胃口值分别是：1,2,3。
虽然你有两块小饼干，由于他们的尺寸都是1，你只能让胃口值是1的孩子满足。
所以你应该输出1。
```
因为饥饿度最小的孩子最容易吃饱，所以我们优先考虑这个孩子，为了尽量使得剩下的饼干可以满足饥饿度更大的孩子，我们应该把大于等于该孩子饥饿度的、且大小最小的饼干给这个孩子。满足这个孩子之后，再以同样的方法考虑下面的孩子。
简而言之，此处贪心策略就是给剩余孩子里最小饥饿度的孩子提供最小的能饱腹的饼干。因此在开始之前需要对两个数组进行从小到大的排序。

```go
func findContentChildren(g []int, s []int) int {
    if len(g) == 0 || len(s) == 0 {
        return 0
    }
    sort.Ints(g)
    sort.Ints(s)
    i, j := 0, 0
    for i < len(g) && j < len(s){
        if g[i] <= s[j] {
            i ++
        }
        j++
    }

    return i
}
```

#### 135 [candy](https://leetcode-cn.com/problems/candy/)
* 描述：一群孩子站在一起，每个孩子都有自己的评分，现在需要给这些孩子发糖果，规则是如果一个孩子的评分比身边的一个孩子要高，那么这个孩子就必须得到比身旁孩子更多的糖果，所有孩子都至少有一个糖果。求解最少需要有多少糖果。
* 输入一个数组，表示孩子的评分，输出最少需要糖果的数量。
```
输入: [1,0,2]
输出: 5
解释: 你可以分别给这三个孩子分发 2、1、2 颗糖果。
```
该题可以运用贪心策略进行两次遍历：把所有小孩的糖果数初始化为1；从左往右遍历，如果右边孩子评分比左边的高，则右边孩子的糖果数更新为左边孩子的糖果数加一；再从右往左遍历一遍，如果左边孩子的评分比右边的高且左边孩子的糖果数不大于右边孩子的糖果数，则左边孩子的糖果数更新为右边孩子的糖果数加一。通过两次遍历，分配的糖果数可以满足题目要求。该题的贪心策略为，每次的糖果数量更新中，只考虑更新相邻一侧的大小关系。

```go
func candy(ratings []int) int {
    n := len(ratings)
    if n < 2 {
        return n
    }

    candies := make([]int, n)
    for i:=0; i<n; i++ {
        candies[i] = 1
        if i > 0 && ratings[i] > ratings[i-1] {
            candies[i] = candies[i-1] + 1
        }
    }

    for i := n-2; i >= 0; i-- {
        if ratings[i] > ratings[i+1] && candies[i] <= candies[i+1] {
            candies[i] = candies[i+1] + 1
        }
    }

    res := 0
    for i := 0; i < n; i++ {
        res += candies[i]
    }

    return res
}
```

#### 区间问题
#### 435[non overlapping intervals](https://leetcode-cn.com/problems/non-overlapping-intervals/)
* 描述：给定一个区间的集合，找到需要移除区间的最小数量，使剩余区间互不重叠。
* 输入区间的集合，输出需要移除的区间的最小数量。
```
输入: [ [1,2], [2,3], [3,4], [1,3] ]
输出: 1
解释: 移除 [1,3] 后，剩下的区间没有重叠。
```
选择保留区间时，区间的结尾很重要，选择的区间结尾越小，余留给其他区间的空间就越大，就越能保留更多的区间。因此此处的贪心策略为，优先保留结尾小且不相交的区间。
具体实现方法为，先将区间按照结尾的大小进行增序排序，每次选择结尾最小且与前一个不重合的区间，结合自带的sort.Slice()方法进行排序。
```go
func eraseOverlapIntervals(intervals [][]int) int {
    if len(intervals) == 0 {
        return 0
    }

    sort.Slice(intervals, func(i, j int) bool {
        return intervals[i][1] < intervals[j][1]
    })

    total := 0
    pre := intervals[0][1]
    for i:=1; i<len(intervals); i++ {
        if intervals[i][0] < pre {
            total ++
        }else {
            pre = intervals[i][1]
        }
    }

    return total
}
```


#### 605[can place flowers](https://leetcode-cn.com/problems/can-place-flowers/)
* 描述：假设你有一个很长的花坛，一部分地块种植了花，另一部分却没有。可是，花卉不能种植在相邻的地块上，它们会争夺水源，两者都会死去。

* 给定一个花坛（表示为一个数组包含0和1，其中0表示没种植花，1表示种植了花），和一个数 n 。能否在不打破种植规则的情况下种入 n 朵花？能则返回True，不能则返回False。
```
输入: flowerbed = [1,0,0,0,1], n = 1
输出: True
```
该题可以用贪心策略从头开始，如果连续三个花坛为0，则中间花坛可以种花，将中间花坛置为1，继续遍历。考虑到头尾两端不需要连续三个0，将数组头尾各加0，则不用特殊处理头尾情况，一次遍历即可。
```go
func canPlaceFlowers(flowerbed []int, n int) bool {
   for i:=0; i<len(flowerbed); i++ {
       if flowerbed[i] == 0 && (i== 0 || flowerbed[i-1]==0) && (i==len(flowerbed)-1 || flowerbed[i+1] == 0) {
           n--
           flowerbed[i] = 1
       }
   }

   return n<=0
}
```


#### 452 [minimum number of arrows](https://leetcode-cn.com/problems/minimum-number-of-arrows-to-burst-balloons/)
* 描述：在二维空间中有许多球形的气球。对于每个气球，提供的输入是水平方向上，气球直径的开始和结束坐标。由于它是水平的，所以纵坐标并不重要，因此只要知道开始和结束的横坐标就足够了。开始坐标总是小于结束坐标。一支弓箭可以沿着 x 轴从不同点完全垂直地射出。在坐标 x 处射出一支箭，若有一个气球的直径的开始和结束坐标为 xstart，xend， 且满足  xstart ≤ x ≤ xend，则该气球会被引爆。可以射出的弓箭的数量没有限制。 弓箭一旦被射出之后，可以无限地前进。我们想找到使得所有气球全部被引爆，所需的弓箭的最小数量。

* 输入一个数组 points ，其中 points [i] = [xstart,xend] ，返回引爆所有气球所必须射出的最小弓箭数。

```
输入：points = [[10,16],[2,8],[1,6],[7,12]]
输出：2
解释：对于该样例，x = 6 可以射爆 [2,8],[1,6] 两个气球，以及 x = 11 射爆另外两个气球
```

和其他合并区间类的题目套路一样, 都是贪心思想, 先排序, 然后遍历检查是否满足合并区间的条件
这里判断是否有交叉区间, 所以其实是计算已知区间的交集数量.
这里以[[10,16],[2,8],[1,6],[7,12]] 为例子:

* 先排序, 我是按区间开始位置排序, 排序后: [[1,6],[2,8],[7,12],[10,16]]
* 遍历计算交叉区间(待发射箭头),
** 待发射箭头的区间range = [1, 6], 需要的箭数量 arrows = 1;
** 区间[2, 8], 和带发射区间[1, 6]有交集:
** 更新发射区域为它们的交集 range = [2, 6]区间[7, 12], 和待发射区间[2, 6]没有任何交集, 说明需要增加一个新的发射区域, 新的待发射区域range = [7, 12
** 区间[10,16], 和待发射区域[7, 12]有交集, 待发射区域更新为[10, 12]
* 返回需要待发射区间的个数

```go
func findMinArrowShots(points [][]int) int {
    if len(points) == 0 {
        return 0
    }

    sort.Slice(points, func(i, j int) bool {
        return points[i][1] < points[j][1]
    })

    res := 1
    pre := points[0][1]
    for i := 1; i < len(points); i++ {
        if points[i][0] > pre {
            res ++
            pre = points[i][1]
        }
    }

    return res
}
```


#### 763 [partition labels](https://leetcode-cn.com/problems/partition-labels/)

* 描述：字符串 S 由小写字母组成。我们要把这个字符串划分为尽可能多的片段，同一字母最多出现在一个片段中。返回一个表示每个字符串片段的长度的列表。
* 输入一个字符串S，输出字符串划分长度列表
```
输入：S = "ababcbacadefegdehijhklij"
输出：[9,7,8]
解释：
划分结果为 "ababcbaca", "defegde", "hijhklij"。
每个字母最多出现在一个片段中。
像 "ababcbacadefegde", "hijhklij" 的划分是错误的，因为划分的片段数较少。
```

想切割，要有首尾两个指针，确定了结尾指针，就能确定下一个切割的开始指针。
遍历字符串，如果已扫描部分的所有字符，都只出现在已扫描的范围内，即可做切割。
```go
func partitionLabels(S string) []int {
	maxPos := map[byte]int{}
	for i := 0; i < len(S); i++ {
		maxPos[S[i]] = i
	}

	res := []int{}
	start := 0
	scannedCharMaxPos := 0
	for i := 0; i < len(S); i++ {
		curCharMaxPos := maxPos[S[i]]
		if curCharMaxPos > scannedCharMaxPos {
			scannedCharMaxPos = curCharMaxPos
		}
		if i == scannedCharMaxPos {
			res = append(res, i-start+1)
			start = i + 1
		}
	}
	return res
}
```

#### 122 [best time to buy and sell stock](https://leetcode-cn.com/problems/best-time-to-buy-and-sell-stock-ii/)

* 给定一个数组，它的第 i 个元素是一支给定股票第 i 天的价格。设计一个算法来计算你所能获取的最大利润。你可以尽可能地完成更多的交易（多次买卖一支股票）。
* 输入股票数组，输出最大利润。
```
输入: [7,1,5,3,6,4]
输出: 7
解释: 在第 2 天（股票价格 = 1）的时候买入，在第 3 天（股票价格 = 5）的时候卖出, 这笔交易所能获得利润 = 5-1 = 4 。
     随后，在第 4 天（股票价格 = 3）的时候买入，在第 5 天（股票价格 = 6）的时候卖出, 这笔交易所能获得利润 = 6-3 = 3 。
```

这道题目可能我们只会想，选一个低的买入，在选个高的卖，在选一个低的买入.....循环反复。假如第0天买入，第3天卖出，那么利润为：prices[3] - prices[0]。
相当于(prices[3] - prices[2]) + (prices[2] - prices[1]) + (prices[1] - prices[0])。此时就是把利润分解为每天为单位的维度，而不是从0天到第3天整体去考虑.那么根据prices可以得到每天的利润序列：(prices[i] - prices[i -1]).....(prices[1] - prices[0])。

```go
func maxProfit(prices []int) int {
    res := 0
    if len(prices) == 0 {
        return res
    }

    for i := 1; i<len(prices); i++ {
        if prices[i-1] < prices[i] {
            res += prices[i] - prices[i-1]
        }
    }

    return res
}
```

#### 406 [queue reconstruction by height](https://leetcode-cn.com/problems/queue-reconstruction-by-height/)

* 描述：假设有打乱顺序的一群人站成一个队列，数组 people 表示队列中一些人的属性（不一定按顺序）。每个 people[i] = [hi, ki] 表示第 i 个人的身高为 hi ，前面 正好 有 ki 个身高大于或等于 hi 的人。

* 请你重新构造并返回输入数组 people 所表示的队列。返回的队列应该格式化为数组 queue ，其中 queue[j] = [hj, kj] 是队列中第 j 个人的属性（queue[0] 是排在队列前面的人）。

```
输入：people = [[7,0],[4,4],[7,1],[5,0],[6,1],[5,2]]
输出：[[5,0],[7,0],[5,2],[6,1],[4,4],[7,1]]
解释：
编号为 0 的人身高为 5 ，没有身高更高或者相同的人排在他前面。
编号为 1 的人身高为 7 ，没有身高更高或者相同的人排在他前面。
编号为 2 的人身高为 5 ，有 2 个身高更高或者相同的人排在他前面，即编号为 0 和 1 的人。
编号为 3 的人身高为 6 ，有 1 个身高更高或者相同的人排在他前面，即编号为 1 的人。
编号为 4 的人身高为 4 ，有 4 个身高更高或者相同的人排在他前面，即编号为 0、1、2、3 的人。
编号为 5 的人身高为 7 ，有 1 个身高更高或者相同的人排在他前面，即编号为 1 的人。
因此 [[5,0],[7,0],[5,2],[6,1],[4,4],[7,1]] 是重新构造后的队列。
```

先按照个子从高到低排序，如果个子一样，则按照k从小到大排列，这样就得到了一个方便后面插入的队列
before: [[7,0] [4,4] [7,1] [5,0] [6,1] [5,2]]
after : [[7 0] [7 1] [6 1] [5 0] [5 2] [4 4]]

得到了预处理的队列，然后遍历这个队列，按照k值来插入到队列的index位置
比如现在遍历到了[6 1], k = 1, 那么就插入到 index = 1 的位置
变成：[[7 0] [6 1] [7 1] [5 0] [5 2] [4 4]]
以此类推。。。

```go
func reconstructQueue(people [][]int) [][]int {
    // 排序，先按照身高h排序，如果身高一样高，那就按照人数k排序
	sort.Slice(people, func(i, j int) bool {
		return (people[i][0] > people[j][0]) || (people[i][0] == people[j][0] && people[i][1] < people[j][1])
	})
	// 按照k值插入到index=k的地方，index之后的往后移动
	for i, p := range people {
		copy(people[p[1]+1:i+1], people[p[1]:i])
		people[p[1]] = p
	}
	return people
}
```
