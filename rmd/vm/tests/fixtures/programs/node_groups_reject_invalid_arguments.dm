/obj/pipe
/obj/other
/turf/closed

/datum/demir/subtype
    default = TRUE

    New()
        ..()
        demir_node_group("not a type", /turf/closed)

/datum/demir/blocker
    New()
        ..()
        demir_node_group(/obj/pipe, list(/turf/closed, "not a type"))

/datum/demir/orientable
    New()
        ..()
        demir_node_group(/obj/pipe, null, /obj/other)

/datum/demir/matching
    New()
        ..()
        demir_node_group(/obj/pipe, null, null, list("pipe_color", 2))
