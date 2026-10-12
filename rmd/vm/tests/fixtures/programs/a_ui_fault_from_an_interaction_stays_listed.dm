/turf/floor

/datum/demir/test
    var/hours = 10

/datum/demir/test/ui(atom/target)
    if(!imgui_begin("Panel"))
        imgui_end()
        return
    var/new_hours = imgui_slider("Hour", hours, 0, 24)
    if(new_hours != hours)
        hours = new_hours
        world.Reboot()
    imgui_end()
