/proc/nameof(X)
    set __demir_intrin = 400
/proc/global_name()
    return nameof(__PROC__)
/datum/thing
/datum/proc/work()
    return nameof(__PROC__)
/datum/thing/work()
    return "[..()] [nameof(__PROC__)]"
/proc/test()
    var/datum/thing/t = new
    return "[global_name()] [t.work()]"
