extends Control
## Roster, standing with the powers of Italy, and the current contract.

var args := {}


func _ready() -> void:
	var v := UI.page(self)
	v.add_child(UI.label("The Company", 44, UI.GOLD, true))
	v.add_child(UI.label(UI.status_line(), 22, UI.DIM))
	v.add_child(UI.label("Renown %d   Wages %d gold/day" % [Game.renown, Game.daily_wage()], 22, UI.DIM))
	for s in Game.squads:
		var u: Dictionary = Game.unit(s["type"])
		var p := UI.panel()
		var inner := UI.vbox(4)
		p.add_child(inner)
		var stars := "★".repeat(Game.squad_level(s))
		inner.add_child(UI.label("%s %s" % [s["name"], stars], 28, UI.GOLD))
		inner.add_child(UI.label("%s - %d / %d men, %d wounded - xp %d" % [u["name"], int(s["men"]), Game.squad_max(s), int(s["wounded"]), int(s["xp"])], 23))
		v.add_child(p)
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
