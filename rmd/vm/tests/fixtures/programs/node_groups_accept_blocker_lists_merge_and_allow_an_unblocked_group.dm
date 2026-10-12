
/obj/cable
/obj/pipe
/obj/grille
/obj/window
/turf/closed

/datum/demir/test
    New()
        ..()
        demir_node_group(/obj/cable, list(/turf/closed, /obj/grille, /obj/window, /turf/closed))
        demir_node_group(/obj/cable, /obj/grille)
        demir_node_group(/obj/cable, /turf/closed)
        demir_node_group(/obj/pipe, null)
