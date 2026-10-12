// TODO: move back into prelude/demir.dm when modular maps ship.
#define DEMIR_MODULAR_LOADER_TG "tgstation"

/datum/demir
    var/modular_loader = null as text|null

/datum/demir/loader
    default = TRUE
    modular_loader = DEMIR_MODULAR_LOADER_TG

/datum/demir/loader/inherited

/datum/demir/loader/disabled
    modular_loader = null

/datum/demir/loader/custom
    modular_loader = "custom-loader"

/datum/demir/loader/empty
    modular_loader = ""

/datum/demir/no_loader

/datum/demir/loader/constructor_enabled
    modular_loader = null

    New()
        ..()
        modular_loader = DEMIR_MODULAR_LOADER_TG

/datum/demir/loader/constructor_disabled
    New()
        ..()
        modular_loader = null
