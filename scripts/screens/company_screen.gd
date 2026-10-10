extends Control
## Roster, standing with the powers of Italy, and the current contract.

var args := {}


func _ready() -> void:
	var v := UI.page(self)
	v.add_child(UI.label("The Company", 44, UI.GOLD, true))
	v.add_child(UI.label(UI.status_line(), 22, UI.DIM))
	v.add_child(UI.label("Renown %d   Wages %d gold/day" % [Game.renown, Game.daily_wage()], 22, UI.DIM))
	v.add_child(UI.label("Tap a squad to see every man's sheet.", 22, UI.DIM))
	for i in Game.squads.size():
		var s: Dictionary = Game.squads[i]
		var u: Dictionary = Game.unit(s["type"])
		var st := BX.group_stats(s["members"])
		var stars := " " + "★".repeat(Game.squad_level(s)) if Game.squad_level(s) > 0 else ""
		var idx := i
		var txt := "%s%s\n%s - %d/%d men, %d wounded - AC %.0f, THAC0 %.0f" % [
			s["name"], stars, u["name"], int(s["men"]), Game.squad_max(s), int(s["wounded"]), st["ac"], st["thac0"]]
		v.add_child(UI.button(txt, func(): Game.goto("squad", {"squad": idx, "back": args.get("back", "map")}), 100))
	v.add_child(UI.button("Baggage train (%d mules, %d carts)" % [Game.mules, Game.carts], func(): Game.goto("baggage", {"back": "company", "back2": args.get("back", "map")})))
	v.add_child(UI.label("Standing", 30, UI.GOLD))
	for f in GameData.FACTIONS:
		var r := int(Game.reputation.get(f, 0))
		v.add_child(UI.label("%s: %+d" % [f, r], 24, UI.GOOD if r >= 0 else UI.BAD))
	if not Game.contract.is_empty():
		var c := Game.contract
		v.add_child(UI.label("Contract", 30, UI.GOLD))
		var state := "done - collect at %s" % Game.nodes[int(c["giver"])]["name"] if c.get("done", false) else "%d days left" % int(c["days_left"])
		v.add_child(UI.label("%s\nTarget: %s - %d gold - %s" % [c["title"], Game.nodes[int(c["target"])]["name"], int(c["reward"]), state], 23))
	v.add_child(UI.button("Back", func(): Game.goto(args.get("back", "map")), 90))
