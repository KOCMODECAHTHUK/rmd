/datum/demir/example
    default = TRUE
    var/show = FALSE

/datum/demir/example/highlights(atom/target)
    if(show && istype(target, /turf))
        world.Reboot()
    return list()

/datum/demir/example/ui(atom/target)
    if(!imgui_begin("Panel"))
        imgui_end()
        return
    var/new_show = imgui_checkbox("Show", show)
    if(new_show != show)
        show = new_show
        demir_rebake(DEMIR_BAKE_HIGHLIGHT)
    imgui_end()
