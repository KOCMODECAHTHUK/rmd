/turf/floor
    icon_state = "floor"

/datum/demir/test/bake(atom/target)
    target.icon_state = "baked"
    reboot_from(target)

/datum/demir/test/proc/reboot_from(atom/target)
    var/state = target.icon_state
    world.Reboot()
