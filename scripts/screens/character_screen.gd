extends Control
## A B/X character sheet with equipment you can change from the baggage.

var args := {}
var message := ""
var choosing := ""   # slot whose options are open


func _ready() -> void:
	_build()


func _char() -> Dictionary:
	var s: Dictionary = Game.squads[int(args.get("squad", 0))]
	return s["members"][int(args.get("member", 0))]


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	var c := _char()
	var v := UI.page(self)
	v.add_child(UI.label(c["name"], 38, UI.GOLD, true))
	var nxt := BX.next_xp(c)
	var xp_txt := "XP %d" % int(c["xp"]) + (" / %d" % nxt if nxt > 0 else "")
	var status := "Wounded - in the wagons" if c["status"] == "wounded" else "Fit for duty"
	v.add_child(UI.label("%s, level %d   -   %s\n%s" % [c["cls"], int(c["level"]), xp_txt, status], 22, UI.DIM, true))
	if message != "":
		var mp := UI.panel()
		mp.add_child(UI.label(message, 22))
		v.add_child(mp)

	# Abilities
	var ab := UI.panel()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.add_child(grid)
	for a in BX.ABILITIES:
		var score := int(c[a])
		var l := UI.label("%s %d (%+d)" % [a.to_upper(), score, BX.mod(score)], 24)
		grid.add_child(l)
	v.add_child(ab)

	# Combat block
	var cb := UI.panel()
	var cv := UI.vbox(4)
	cb.add_child(cv)
	var melee := "%s d%d%s" % [BX.ITEMS[c["weapon"]]["name"] if c["weapon"] != "" else "Fists", BX.weapon_die(c), _signed(BX.melee_bonus(c))]
	cv.add_child(UI.label("HP %d / %d     AC %d     THAC0 %d" % [int(c["hp"]), int(c["max_hp"]), BX.ac(c), BX.thac0(c)], 26, UI.GOLD))
	cv.add_child(UI.label("Melee: %s  (to-hit %+d)" % [melee, BX.melee_bonus(c)], 22))
	if c["missile"] != "":
		cv.add_child(UI.label("Missile: %s d%d  (to-hit %+d)" % [BX.ITEMS[c["missile"]]["name"], BX.missile_die(c), BX.missile_bonus(c)], 22))
	var sv := BX.saves(c)
	cv.add_child(UI.label("Saves - Death %d  Wands %d  Paralysis %d  Breath %d  Spells %d" % [sv[0], sv[1], sv[2], sv[3], sv[4]], 20, UI.DIM))
	if c["cls"] == "Cleric" and int(c["level"]) >= 2:
		cv.add_child(UI.label("Spells: Cure Light Wounds - raises one wounded man each day.", 20, UI.GOOD))
	if c["cls"] == "Cleric":
		cv.add_child(UI.label("Clerics fight only with blunt weapons.", 20, UI.DIM))
	v.add_child(cb)

	# Equipment
	v.add_child(UI.label("Equipment  (%d cn carried)" % BX.carried_cn(c), 26, UI.GOLD))
	for slot in ["weapon", "missile", "armor", "shield"]:
		var sl: String = slot
		var cur: String = c.get(sl, "")
		var name_txt: String = BX.ITEMS[cur]["name"] if cur != "" else "- none -"
		var row := UI.hbox(8)
		row.add_child(UI.button("%s: %s" % [sl.capitalize(), name_txt], func():
			choosing = "" if choosing == sl else sl
			message = ""
			_build(), 70))
		if cur != "":
			var rb := UI.button("To baggage", func():
				Game.unequip(c, sl)
				message = "%s goes back to the baggage." % BX.ITEMS[cur]["name"]
				_build(), 70)
			rb.size_flags_horizontal = Control.SIZE_SHRINK_END
			rb.custom_minimum_size = Vector2(200, 70)
			row.add_child(rb)
		v.add_child(row)
		if choosing == sl:
			_options(v, c, sl)
	for gi in c["gear"].size():
		var g: String = c["gear"][gi]
		var gidx: int = gi
		v.add_child(UI.button("Gear: %s  (to baggage)" % BX.ITEMS[g]["name"], func():
			Game.unequip(c, "gear", gidx)
			_build(), 64))
	v.add_child(UI.button("Give gear from the baggage", func():
		choosing = "" if choosing == "gear" else "gear"
		_build(), 70))
	if choosing == "gear":
		_options(v, c, "gear")
	v.add_child(UI.button("Back to the squad", func(): Game.goto("squad", {"squad": args.get("squad", 0), "back": args.get("back", "map")}), 90))


func _options(v: VBoxContainer, c: Dictionary, slot: String) -> void:
	var any := false
	for item in Game.stash:
		var it: String = item
		if BX.ITEMS[it]["slot"] != slot:
			continue
		any = true
		var info: Dictionary = BX.ITEMS[it]
		var stat := ""
		if info.has("dmg"):
			stat = "d%d" % int(info["dmg"])
		elif info.has("ac"):
			stat = "AC %d" % int(info["ac"]) if slot == "armor" else "AC -1"
		var why := BX.can_use(c, it)
		var b := UI.button("   Equip %s %s (%d)%s" % [info["name"], stat, int(Game.stash[it]), "" if why == "" else " - " + why], func():
			var r := Game.equip(c, it)
			message = r if r != "" else "%s takes the %s." % [c["name"], info["name"].to_lower()]
			choosing = ""
			_build(), 64)
		b.disabled = why != ""
		v.add_child(b)
	if not any:
		v.add_child(UI.label("   Nothing of that kind in the baggage. Buy some at a town armoury.", 22, UI.DIM))


func _signed(n: int) -> String:
	return "" if n == 0 else "%+d" % n
