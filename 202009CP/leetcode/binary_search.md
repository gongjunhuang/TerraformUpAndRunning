### Binary Search 二分查找

#### 算法解释
二分查找也通常被称为二分法，每次查找时通过将区间分成两部分并只查找其中一部分，将查找的负责度大大减少，对于一个长度为n的数组，二分查找的时间复杂度为O(lgn)。

具体到代码上，二分查找时区间的左右端取开区间还是闭区间在绝大多数情况都可以。TIPS：第一是尝试使用一种写法，比如左闭右开或者左开右闭，尽量只保持这一种写法；第二是思考如果最后区间只剩下一个数或者两个数，自己写法是否会陷入死循环，如果某种写法无法跳出死循环，则考虑尝试换种写法。

二分查找也可以看作双指针的一种特殊情况。

#### Examples
#### 69 [Sqrt](https://leetcode-cn.com/problems/sqrtx/)
* 描述：实现 int sqrt(int x) 函数。
* 计算并返回 x 的平方根，其中 x 是非负整数。

```
输入: 4
输出: 2
```

```go
func mySqrt(x int) int {
    l, r, ans := 0, x, -1
    for l <= r {
        mid := l+(r-l)/2
        if mid*mid <= x {
            ans = mid
            l = mid +1
        }else{
            r = mid - 1
        }
    }

    return ans
}
```


#### 34 [find first and last in array](https://leetcode-cn.com/problems/find-first-and-last-position-of-element-in-sorted-array/)
* 描述：给定一个按照升序排列的整数数组 nums，和一个目标值 target。找出给定目标值在数组中的开始位置和结束位置。如果数组中不存在目标值 target，返回 [-1, -1]。
* 输入数组，输出[index1, index2]

```
输入：nums = [5,7,7,8,8,10], target = 8
输出：[3,4]
```

这道题类似于实现python中find()和rfind()函数。尝试使用左闭右开的写法。

```go
func searchRange(nums []int, target int) []int {
    if len(nums) == 0 {
        return []int{-1, -1}
    }

    return []int{searchFirstEqualElement(nums, target), searchLastEqualElement(nums, target)}
}

func searchFirstEqualElement(nums []int, target int) int {
    low, high := 0, len(nums)-1
    for low <= high {
        mid := low + (high-low)/2
        if nums[mid] > target {
            high = mid - 1
        } else if nums[mid] < target {
            low = mid + 1
        } else {
            if (mid == 0) || (nums[mid-1] != target) {
                return mid
            } else {
                high = mid - 1
            }
        }
    }

    return -1
}

func searchLastEqualElement(nums []int, target int) int {
    low, high := 0, len(nums)-1
    for low <= high {
        mid := low + (high-low)/2
        if nums[mid] > target {
            high = mid - 1
        } else if nums[mid] < target {
            low = mid + 1
        } else {
            if (mid == len(nums)-1) || (nums[mid+1] != target) {
                return mid
            }
            low = mid + 1
        }
    }

    return -1
}
```
