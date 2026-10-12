/datum/demir/example
    default = TRUE
    var/hours = 10

/datum/demir/example/ui(atom/target)
    if(!imgui_begin("Panel"))
        imgui_end()
        return
    var/new_hours = imgui_slider("Hour", hours, 0, 24)
    if(new_hours != hours)
        hours = new_hours
        world.Reboot()
    imgui_end()
