// TODO: move back into prelude/demir.dm when modular maps ship.
#define DEMIR_MODULAR_LOADER_TG "tgstation"

/datum/demir
    var/modular_loader = null as text|null

/proc/loader_name()
    return "tgstation"

/datum/demir/invalid
    default = TRUE
    modular_loader = 42

    New()
        world.log << "constructed"

/datum/demir/invalid/list
    modular_loader = list("tgstation")

/datum/demir/invalid/nonconstant
    modular_loader = loader_name()

/datum/demir/invalid/constructor_failure
    modular_loader = DEMIR_MODULAR_LOADER_TG

    New()
        throw "profile initialization failed"

/datum/demir/invalid/constructor_invalid
    modular_loader = DEMIR_MODULAR_LOADER_TG

    New()
        modular_loader = 42
