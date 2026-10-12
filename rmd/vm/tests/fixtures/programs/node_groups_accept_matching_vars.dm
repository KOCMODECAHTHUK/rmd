/obj/cable
/obj/pipe
/turf/closed

/datum/demir/test
    New()
        ..()
        demir_node_group(/obj/cable, /turf/closed, null, "cable_layer")
        demir_node_group(/obj/pipe, /turf/closed, null, list("piping_layer", "pipe_color", "piping_layer"))
        demir_node_group(/obj/pipe, null, null, list("pipe_color", "hidden"))
