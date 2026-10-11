/datum/demir/example
    default = TRUE

/datum/demir/example/bake(atom/target)
    if(istype(target, /turf))
        world.Reboot()

/datum/demir/example/ui(atom/target)
    world.Reboot()
