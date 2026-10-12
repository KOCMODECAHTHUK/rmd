/datum/thing
/datum/thing/sub
/datum/thing/proc/declared_on()
    return __TYPE__
/proc/test()
    var/datum/thing/sub/s = new
    return (s.declared_on() == /datum/thing) + (s.declared_on() != /datum/thing/sub) * 2
