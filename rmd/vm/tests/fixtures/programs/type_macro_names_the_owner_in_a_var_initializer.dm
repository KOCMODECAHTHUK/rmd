/datum/thing
    var/owner = __TYPE__
/proc/test()
    var/datum/thing/t = new
    return t.owner == /datum/thing
