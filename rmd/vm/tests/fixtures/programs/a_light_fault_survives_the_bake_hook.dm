/obj/lamp
    icon_state = "lamp"

/datum/demir/test/light(atom/target)
    var/datum/missing
    missing.Reboot()

/datum/demir/test/bake(atom/target)
    target.icon_state = "baked"
