// rmd embeds this integration for the Forced bundled profile setting. To make the profile part of a
// cmss13 checkout instead, copy it there and `#include` it from `colonialmarines.dme` after
// `// END_INCLUDE`, the guard keeps BYOND compiling it to nothing.
//
// Walls pick corner states from their neighbors in LateInitialize(), and windows, frames and a
// few floors pick a junction state through relativewall(). Lights follow TGMC's three systems:
// static and hybrid lights are corner lights here, and movable lights are masks.
#ifdef __DEMIR_BAKE__

#define DEMIR_GROUP_POWER (1<<0)

/datum/controller/global_vars/demir_preview/New()
	GLOB = src
	gvars_datum_init_order = list()
	InitGlobalcardinals()
	InitGlobaldiagonals()
	InitGlobalalldirs()

/datum/demir/cmss13
	default = TRUE
	var/power_all = TRUE

	New()
		..()
		if(!GLOB)
			GLOB = new /datum/controller/global_vars/demir_preview

		demir_define_group(DEMIR_GROUP_POWER, /obj/structure/machinery)

// ui() rolls its writes back on every frame but the one the viewer touched something on, so panel
// state lives in the profile's own vars.
/datum/demir/cmss13/ui(atom/target)
	if(!imgui_begin("Demir"))
		imgui_end()
		return

	imgui_separator("Power")
	var/powered_all = imgui_checkbox("All areas powered", src.power_all)
	if(powered_all != src.power_all)
		src.power_all = powered_all
		demir_rebake(DEMIR_BAKE_LIGHT, DEMIR_GROUP_POWER)
		demir_rebake(DEMIR_BAKE_APPEARANCE, DEMIR_GROUP_POWER)

	imgui_end()

/proc/demir_area_powered(area/A, chan)
	var/datum/demir/cmss13/profile = demir_profile()
	if(profile.power_all)
		return TRUE

	// Unchecked shows the map as if no APC were charged. Areas that need no power keep it.
	return A && (!A.requires_power || A.unlimited_power)

/obj/structure/machinery/powered(chan = -1)
	if(!src.loc)
		return 0

	var/area/A = src.loc.loc
	if(!A || !isarea(A))
		return 0

	if(chan == -1)
		chan = power_channel

	return demir_area_powered(A, chan)

// Round start has not charged anything, and the native power_change() waits in a spawn() the bake
// skips. This mirrors it, minus the redraw and the power draw bookkeeping.
/obj/structure/machinery/demir_apply_light()
	if(needs_power && !demir_area_powered(get_area(src), power_channel))
		stat |= NOPOWER
	else
		stat &= ~NOPOWER

	return ..()

// LIGHT_OK is 0, and lightreplacer.dm undefines it before this profile is included. update() would
// also wear the bulb out at random, so the state is set directly.
/obj/structure/machinery/light/demir_apply_light()
	var/area/fixture_area = get_area(src)
	if(fixture_area)
		var/is_switched = fixture_area.lightswitch
		if(needs_power)
			is_switched = is_switched && demir_area_powered(fixture_area, POWER_CHANNEL_LIGHT)

		on = is_switched && status == 0
		light_range = on ? brightness : 0

	return ..()

// Walls fill a shared damage overlay cache on first draw. Filling it here keeps it out of every
// rolled-back preview.
/turf/closed/wall/demir_prepare_state()
	if(!damage_overlays[1])
		generate_damage_overlays()
	return ..()

/atom/proc/demir_prepare_state()
	return

// `set_light_on(on)` from Initialize()
/obj/item/device/flashlight/demir_prepare_state()
	light_on = on

// update_icon() colors the screen by charge state and only lights a closed, working APC.
// Round start has not charged anything yet. APC_NOT_CHARGING is 0 and apc.dm undefines it.
/obj/structure/machinery/power/apc/demir_prepare_state()
	if(stat & (BROKEN|MAINT) || !cell_type)
		light_range = 0
		return
	light_color = charging == 0 ? LIGHT_COLOR_RED : LIGHT_COLOR_GREEN

// `Initialize()` makes an open poddoor see-through before update_icon() shows it open
/obj/structure/machinery/door/poddoor/demir_prepare_state()
	opacity = density

/datum/demir/cmss13/prepare(atom/target)
	target.demir_prepare_state()

/proc/demir_overlay_icon(pixel_bounds)
	switch(pixel_bounds)
		if(32)
			return 'icons/effects/light_overlays/light_32.dmi'
		if(64)
			return 'icons/effects/light_overlays/light_64.dmi'
		if(96)
			return 'icons/effects/light_overlays/light_96.dmi'
		if(128)
			return 'icons/effects/light_overlays/light_128.dmi'
		if(160)
			return 'icons/effects/light_overlays/light_160.dmi'
		if(192)
			return 'icons/effects/light_overlays/light_192.dmi'
		if(224)
			return 'icons/effects/light_overlays/light_224.dmi'
		if(256)
			return 'icons/effects/light_overlays/light_256.dmi'
		if(288)
			return 'icons/effects/light_overlays/light_288.dmi'
		if(320)
			return 'icons/effects/light_overlays/light_320.dmi'
		if(352)
			return 'icons/effects/light_overlays/light_352.dmi'
		if(384)
			return 'icons/effects/light_overlays/light_384.dmi'
		if(416)
			return 'icons/effects/light_overlays/light_416.dmi'
	return null

// The overlay lighting component's mask and cone, without components, signals or lumcounts.
/atom/movable/proc/demir_add_overlay_light()
	if((light_system != MOVABLE_LIGHT && light_system != DIRECTIONAL_LIGHT) || !light_on || !light_range)
		return

	var/range = clamp(CEILING(light_range, 0.5), 1, 7)
	var/pixel_bounds = ((range - 1) * 64) + 32
	var/image/mask = new
	mask.icon = demir_overlay_icon(pixel_bounds)
	mask.icon_state = "light"
	mask.plane = O_LIGHTING_VISUAL_PLANE
	mask.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
	mask.alpha = min(230, (abs(light_power) * 120) + 30)
	mask.color = light_color
	mask.demir_overlay_light = light_power < 0 ? -1 : 1
	mask.pixel_x = -((range - 1) * 32)
	mask.pixel_y = mask.pixel_x

	if(light_system == DIRECTIONAL_LIGHT)
		// `cast_directional_light()`, with SHORT_CAST at 2
		var/final_distance = clamp(floor(light_range * 0.5), 1, 3)
		if(final_distance > 2 && !(ALL_CARDINALS & dir))
			final_distance -= 1
		var/turf/scanning = get_turf(src)
		for(var/i in 1 to final_distance)
			var/turf/next_turf = get_step(scanning, dir)
			if(isnull(next_turf) || next_turf.opacity)
				final_distance = i
				break
			scanning = next_turf

		switch(dir)
			if(NORTH)
				mask.pixel_y += 32 * final_distance
			if(SOUTH)
				mask.pixel_y -= 32 * final_distance
			if(EAST)
				mask.pixel_x += 32 * final_distance
			if(WEST)
				mask.pixel_x -= 32 * final_distance

		var/image/cone = new
		cone.icon = 'icons/effects/light_overlays/light_cone.dmi'
		cone.icon_state = "light"
		cone.dir = dir
		cone.plane = O_LIGHTING_VISUAL_PLANE
		cone.appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM
		cone.alpha = min(200, (abs(light_power) * 90) + 20)
		cone.color = light_color
		cone.pixel_x = -32
		cone.pixel_y = -32
		cone.demir_overlay_light = mask.demir_overlay_light
		underlays += cone

	underlays += mask

/atom/proc/demir_bake_icon()
	return

/turf/closed/wall/demir_bake_icon()
	update_connections(FALSE)
	update_icon()

/obj/structure/machinery/demir_bake_icon()
	update_icon()

// These redraws read the static lighting queue or SShijack, which a bake never sets up, or assign
// `overlays = 0`, which the VM rejects.
/obj/structure/machinery/power/apc/demir_bake_icon()
	return

/obj/structure/machinery/fuelpump/demir_bake_icon()
	return

/obj/structure/machinery/portable_atmospherics/demir_bake_icon()
	return

/obj/structure/machinery/recharger/demir_bake_icon()
	return

/obj/structure/machinery/door/poddoor/demir_bake_icon()
	update_icon()

/obj/structure/machinery/door/airlock/demir_bake_icon()
	update_icon()

/obj/item/device/flashlight/demir_bake_icon()
	update_icon()

/image/proc/demir_tag_emissive()
	if(plane == EMISSIVE_PLANE && islist(color))
		var/list/color_matrix = color
		if(color_matrix[17] || color_matrix[18])
			demir_emissive = TRUE
		else if(color_matrix[16] && !color_matrix[19])
			demir_emissive_blocker = TRUE
	for(var/image/underlay in underlays)
		underlay.demir_tag_emissive()
	for(var/image/overlay in overlays)
		overlay.demir_tag_emissive()

/atom/proc/demir_tag_emissive()
	for(var/image/underlay in underlays)
		underlay.demir_tag_emissive()
	for(var/image/overlay in overlays)
		overlay.demir_tag_emissive()

/atom/proc/demir_finish_appearance()
	if(tiles_with)
		relativewall()

// Walls already derive their connections in demir_bake_icon().
/turf/closed/wall/demir_finish_appearance()
	return

/atom/movable/demir_finish_appearance()
	..()
	demir_add_overlay_light()

/datum/demir/cmss13/bake(atom/target)
	target.demir_bake_icon()
	target.demir_finish_appearance()
	target.demir_tag_emissive()

// Initialize() hands every light that is neither movable nor directional to update_light(), which
// builds a static source or a hybrid mask source. Neither checks light_on.
/atom/proc/demir_apply_light()
	if(light_system == MOVABLE_LIGHT || light_system == DIRECTIONAL_LIGHT || !light_range || !light_power)
		return
	demir_light_range = max(light_range, MINIMUM_USEFUL_LIGHT_RANGE)
	demir_light_power = light_power
	demir_light_color = light_color
	demir_light_height = LIGHTING_HEIGHT

/area/demir_apply_light()
	demir_fullbright = !static_lighting
	demir_ambient_color = base_lighting_color
	demir_ambient_power = base_lighting_alpha / 255

/datum/demir/cmss13/light(atom/target)
	target.demir_apply_light()

#undef DEMIR_GROUP_POWER

#endif
