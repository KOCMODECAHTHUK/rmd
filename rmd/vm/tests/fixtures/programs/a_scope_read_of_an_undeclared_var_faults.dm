/obj/parent
/obj/parent/child
    var/only_child = 1

/proc/test()
    var/obj/parent/child/path = /obj/parent
    return path::only_child
