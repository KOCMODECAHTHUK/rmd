/area/zone
/turf/floor
/turf/wall
    opacity = 1
/obj/curtain
    opacity = 1
/proc/describe(list/found)
    var/list/parts = list()
    for(var/turf/entry in found)
        parts += "[entry.x],[entry.y]"
    return jointext(parts, " ")

/datum/demir/test/bake(atom/target)
    if(!istype(target, /turf/floor) || target.x != 3 || target.y != 3)
        return
    target.name = "[describe(view(2, target))] | [describe(oview(target, 2))]"
