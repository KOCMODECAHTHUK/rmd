// TODO: move back into prelude/demir.dm when modular maps ship.
#define DEMIR_MODULAR_LOADER_TG "tgstation"

/datum/demir
    var/modular_loader = null as text|null

/datum/demir/test
    modular_loader = DEMIR_MODULAR_LOADER_TG

    New()
        ..()
        modular_loader = "constructor"

    prepare(atom/target)
        modular_loader = null
