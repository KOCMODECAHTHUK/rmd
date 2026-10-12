/datum/thing
	var/name = "before"

/proc/test()
	var/datum/thing/thing = new
	var/list/held = thing.vars
	thing.name = "after"
	var/list/copy = thing.vars.Copy()
	var/copied = copy["name"]
	held -= "name"
	var/kept = ("name" in thing.vars) ? "kept" : "lost"
	var/same = held == thing.vars ? "same" : "new"
	return "[copied] [kept] [same]"
