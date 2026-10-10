extends Control
## One squad: its men, and handing out gear from the baggage to all of them at once.

var args := {}
var message := ""


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var idx := int(args.get("squad", 0))
	if idx >= Game.squads.size():
		Game.goto("company", {"back": args.get("back", "map")})
		return
	var s: Dictionary = Game.squads[idx]
	var u: Dictionary = Game.unit(s["type"])
	var st := BX.group_stats(s["members"])
	var v := UI.page(self)
	v.add_child(UI.label(s["name"], 40, UI.GOLD, true))
	v.add_child(UI.label("%s - %d fit, %d wounded (max %d)\nAverage AC %.1f   THAC0 %.1f   damage %.1f   HP %.1f" % [
		u["name"], int(s["men"]), int(s["wounded"]), Game.squad_max(s), st["ac"], st["thac0"], st["dmg"], st["hp"]], 22, UI.DIM, true))
	if message != "":
		var p := UI.panel()
		p.add_child(UI.label(message, 22))
		v.add_child(p)

	var gear_items := []
	for item in Game.stash:
		if BX.ITEMS[item]["slot"] in ["weapon", "missile", "armor", "shield"]:
			gear_items.append(item)
	if not gear_items.is_empty():
		v.add_child(UI.label("Outfit the squad from the baggage", 26, UI.GOLD))
		for item in gear_items:
			var it: String = item
			v.add_child(UI.button("Give %s to all (%d in baggage)" % [BX.ITEMS[it]["name"], int(Game.stash[it])], func():
				var n := Game.outfit_squad(s, it)
				message = "%d men take up the %s." % [n, BX.ITEMS[it]["name"].to_lower()]
				_build(), 70))

	v.add_child(UI.label("The men", 26, UI.GOLD))
	for m in s["members"].size():
		var c: Dictionary = s["members"][m]
		var mi: int = m
		var tag := ""
		if c.get("hero", false):
			tag = "✠ "
		var status := "" if c["status"] == "ok" else "  [WOUNDED]"
		var txt := "%s%s%s\n%s %d   HP %d/%d   AC %d   %s" % [tag, c["name"], status, c["cls"], int(c["level"]),
			int(c["hp"]), int(c["max_hp"]), BX.ac(c), BX.ITEMS[c["weapon"]]["name"] if c["weapon"] != "" else "unarmed"]
		v.add_child(UI.button(txt, func(): Game.goto("character", {"squad": idx, "member": mi, "back": args.get("back", "map")}), 84))
	v.add_child(UI.button("Back to the Company", func(): Game.goto("company", {"back": args.get("back", "map")}), 90))
