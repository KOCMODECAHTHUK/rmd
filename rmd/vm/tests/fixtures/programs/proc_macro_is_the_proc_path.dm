/datum/thing
/datum/proc/work()
    return __PROC__ == /datum/proc/work
/datum/thing/work()
    return __PROC__ == /datum/thing/proc/work
/proc/test()
    var/datum/d = new
    var/datum/thing/t = new
    return d.work() + t.work() * 2
