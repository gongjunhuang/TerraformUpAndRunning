### 双指针
### 算法解释
双指针主要用于遍历数组，两个指针指向不同的元素，从而协同完成任务。
* 如果两个指针指向同一个数组，遍历方向相同且不会相交，这称为滑动窗口，这经常用于区间搜索。
* 如果两个指针指向同一个数组，遍历方向相反，则可以用来搜索，待搜索的数组最好是排好序的。

### 示例
#### 167 [Two Sum](https://leetcode-cn.com/problems/two-sum-ii-input-array-is-sorted/)
* 描述：为一个增序的数组里找到两个数，使它们的值为一定值，已知有且仅有一对解。
* 输入是为一个数组numbers和一个定值target，输出是两个数的位置，位置从1开始。
```
Input: numbers = [2,7,11,15], target = 9
Output: [1,2]
```

因为数组已经排好序，所以可以采用方向相反的双指针来寻找两个数字，一个初始指向数组的最左边，向右遍历；一个指向数组的最大元素，向左遍历。
如果两个指针指向的元素的和等于定值，那么它们就是我们要的结果，如果两个指针指向的值之和小于定值，则把左边的指针右移一位；反之则把右边的指针左移一位。

```
func twoSum(numbers []int, target int) []int {
    length := len(numbers)
    for i, j := 0, length-1; i<j; {
        sum := numbers[i] + numbers[j]
        if sum == target {
            return []int{i+1, j+1}
        } else if sum < target {
            i++
        } else {
            j--
        }
    }

    return []int{}
}
```

#### 88 [归并两个有序数组](https://leetcode-cn.com/problems/merge-sorted-array)
* 描述：给定两个有序数组，把两个数组合成一个
* 输入两个数组长度为m和n，其中第一个数组被延长至m+n，多出的n位被0填补。
```
Input: nums1 = [1,2,3,0,0,0], m = 3, nums2 = [2,5,6], n = 3
Output: nums1 = [1,2,2,3,5,6]
```
因为两个数组已经排好序，可以将两个指针放在两个数组的结尾，比较两个数组的最大值，将大值放在数组1的结尾，即m+n-1处，然后向前移动一位。

```
func merge(nums1 []int, m int, nums2 []int, n int) {
    left, right, tail := m - 1, n - 1, m + n - 1
    for left >= 0 && right >= 0 {
        if nums1[left] > nums2[right] {
            nums1[tail] = nums1[left]
            left --
        } else {
            nums1[tail] = nums2[right]
            right --
        }

            tail --
    }

    for right >= 0 {
        nums1[tail] = nums2[right]
        tail--
        right --
    }
}
```

#### 快慢指针 142[环形链表](https://leetcode-cn.com/problems/linked-list-cycle-ii/)

* 描述：给定一个链表，如果有环路，找出环路的开始点
* 输入一个链表，输出链表的结点，如果没有环路，返回空指针

链表环路问题，有个通用解法，快慢指针[Floyd判圈法](https://en.wikipedia.org/wiki/Cycle_detection): 给定两个指针，分别命名为slow和fast，起始位置在链表的开头，每次fast前进两步，slow前进一步。如果fast可以走到尽头，则说明链表没有环路；如果fast可以无限走下去，则说明肯定有环路，那么slow和fast一定会相遇。当slow和fast第一次相遇的时候，我们将fast移动到链表的开头，slow和fast每次都前进一步，那么当slow和fast再次相遇的时候，相遇的节点即为环路的开始点。

```
/**
 * Definition for singly-linked list.
 * type ListNode struct {
 *     Val int
 *     Next *ListNode
 * }
 */
func detectCycle(head *ListNode) *ListNode {
  slow, fast := head, head
  for fast != nil && fast.Next != nil {
      slow = slow.Next
      fast = fast.Next.Next
      if slow == fast {
          fast = head
          for {
              if slow == fast {
                  return slow
              }
              slow, fast = slow.Next, fast.Next
          }
      }
  }

  return nil
}
```



#### Test for two pointers

#### 633 [sum of square numbers](https://leetcode-cn.com/problems/sum-of-square-numbers/)

* 描述：给定一个非负整数c，判断是否存在两个整数a，b使得a^2+b^2=c
* 输入整数c，输出true 或者false

```
输入：c = 5
输出：true
解释：1 * 1 + 2 * 2 = 5
```
因为c已知非负，求两数平方和是否等于c，则两数中绝对值最大值为sqrt(c)，可以设两书均为大于等于0，因为平方之后均为正数，则在[0, sqrt(c)]区间内求是否存在两个整数。可以采用双指针，一个指向0，一个指向sqrt(c), 如果两数平方之和大于c，则右边指针减1，反之左边加1，直到得到结果。

```
func judgeSquareSum(c int) bool {
    j := int(math.Sqrt(float64(c)))
    i := 0
    for i <= j {
        total := i*i + j*j
        if total > c {
            j --
        } else if total < c {
            i ++
        } else {
            return true
        }
    }

    return false
}
```

#### 680 [valid palindrome](https://leetcode-cn.com/problems/valid-palindrome-ii/)

* 描述：给定一个非空字符串 s，最多删除一个字符。判断是否能成为回文字符串。
* 输入一个字符串，输出true或false
```
输入: "aba"
输出: True
```

判断回文串显然可以使用双指针，指针i指向字符串头部，从前往后遍历；指针j指向字符串尾部，从后往前遍历。该题的难点是如何判断删除一个字符串之后是否为回文串：当发现s[i] != s[j]时，通过观察可以发现，字符串s[i+1, j]和s[i, j-1]只要有一个字符串为回文串，则该字符串为回文串，否则删除一个字符之后仍旧无法将字符串变为回文串。

```
func validPalindrome(s string) bool {
    i, j := 0, len(s)-1
    for i < j {
        if s[i] != s[j] {
            return isValid(s, i+1, j) || isValid(s, i, j-1)
        }
        i++
        j--
    }

    return true
}

func isValid(s string, i, j int) bool {
    for i < j {
        if s[i] != s[j] {
            return false
        }
        i ++
        j --
    }

    return true
}
```

#### 524[longest word in dic through deleting](https://leetcode-cn.com/problems/longest-word-in-dictionary-through-deleting/)

* 描述：给定一个字符串和一个字符串字典，找到字典里面最长的字符串，该字符串可以通过删除给定字符串的某些字符来得到。如果答案不止一个，返回长度最长且字典顺序最小的字符串。如果答案不存在，则返回空字符串。
* 输入字符串和字典，输出符合条件最长的字符串，如果没有答案，返回空
```
输入:
s = "abpcplea", d = ["ale","apple","monkey","plea"]

输出:
"apple"
```
因为要求的为最长的字符串，所以可以对目标字典进行排序，先按长度再按字典序进行排序，然后从第一个开始遍历，首个符合条件的即为答案。

```
func findLongestWord(s string, d []string) string {
    sort.Slice(d, func(i, j int) bool {
        return len(d[i]) == len(d[j]) && d[i] < d[j] || len(d[i]) > len(d[j])
    })
    t := []rune(s)
    n := len(t)
    for _, c := range d {
        i, res := 0, true
        for _, j := range c {
            for ; i < n; i++ {
                if t[i] == j {
                    break
                }
            }
            if i == n {
                res = false
                break
            }
            i++
        }
        if res {
            return c
        }
    }
    return ""
}
```

#### 340 [longest substring with at most k distinct char](https://leetcode-cn.com/problems/longest-substring-with-at-most-k-distinct-characters/)

* 描述： 给定一个字符串 s ，找出 至多 包含 k 个不同字符的最长子串 T。
* 输入字符串s，输出最长字串T，其中不同字符最多k
```
输入: s = "eceba", k = 2
输出: 3
解释: 则 T 为 "ece"，所以长度为 3。
```

为了通过一次遍历解决这个问题，我们使用滑动窗口方法，使用两个指针 left 和 right 标记窗口的边界。

思路是将左右指针都设置为 0，然后向右移动 right 指针保证区间内含有不超过 k 个不同字符。当移动到含有 k + 1 个不同字符的时候，移动 left 指针直到区间内不含有超过 k + 1 个不同字符。

```
func lengthOfLongestSubstringKDistinct(s string, k int) int {
    n := len(s)
    if n <= 0 || k <= 0 {
        return 0
    }

    m, count, res := make(map[byte]int, 0), 0, 1
    for left, right:=0, 0; right < n; right ++ {
        tmp := s[right]
        if m[tmp] == 0 {
            count++
        }

        m[tmp]++
        for count > k{
            m[s[left]] --
            if m[s[left]] == 0 {
                count --
            }
            left ++
        }
        if right - left + 1 > res {
            res = right - left + 1
        }
    }

    return res
}
```
