/datum/thing
    var/marker = 0
/datum/thing/proc/copy()
    var/datum/thing/made = new __TYPE__()
    made.marker = 7
    return made
/proc/test()
    var/datum/thing/t = new
    var/datum/thing/c = t.copy()
    return c.marker
