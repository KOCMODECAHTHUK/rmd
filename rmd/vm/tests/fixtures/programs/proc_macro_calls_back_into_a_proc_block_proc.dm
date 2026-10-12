/proc
    count(n)
        if(n <= 0)
            return 0

        return 1 + call(__PROC__)(n - 1)
/proc/test()
    return count(3)
