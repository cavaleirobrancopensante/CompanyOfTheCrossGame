extends Control
## Towns, cities, villages and monasteries: market, recruiting, contracts, Mass, rest.

var args := {}
var root_box: VBoxContainer
var message := ""
var tab := "main"


func _ready() -> void:
	var paid := Game.collect_contract_here()
	var notes := Game.pop_notices()
	message = "\n".join([notes, paid]).strip_edges()
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	root_box = UI.page(self)
	var n: Dictionary = Game.nodes[Game.current_node]
	var fac: String = n["faction"]
	root_box.add_child(UI.label(n["name"], 46, UI.GOLD, true))
	var sub := GameData.kind_label(n["kind"])
	if fac != "":
		sub += "  -  %s (standing %+d)" % [fac, int(Game.reputation.get(fac, 0))]
	root_box.add_child(UI.label(sub, 22, UI.DIM, true))
	root_box.add_child(UI.label(UI.status_line(), 22, UI.DIM))
	if message != "":
		var p := UI.panel()
		p.add_child(UI.label(message, 23))
		root_box.add_child(p)
	match tab:
		"recruit":
			_build_recruit()
		"contracts":
			_build_contracts()
		_:
			_build_main(n)


func _act(text: String) -> void:
	message = text
	_build()


func _build_main(n: Dictionary) -> void:
	var kind: String = n["kind"]
	var price := Game.food_price()
	var buy := UI.button("Buy 20 food (%d gold)" % price, func():
		Game.gold -= price
		Game.food += 20
		_act("The quartermaster loads sacks of grain and dried fish."))
	buy.disabled = Game.gold < price or kind == "monastery"
	root_box.add_child(buy)

	if not Game.recruits_here().is_empty():
		root_box.add_child(UI.button("Recruit squads", func():
			tab = "recruit"
			message = ""
			_build()))
	if kind in ["city", "town"]:
		root_box.add_child(UI.button("Contracts board", func():
			tab = "contracts"
			message = ""
			_build()))

	var mass_text := "Hear Mass with Father Martin (1 day)"
	if kind == "monastery":
		mass_text = "Pray with the monks and receive their blessing (1 day)"
	root_box.add_child(UI.button(mass_text, func():
		Game.pass_days(1)
		var gain := 15 if kind == "monastery" else 8
		Game.faith = mini(100, Game.faith + gain)
		Game.morale = mini(100, Game.morale + gain / 2)
		var healed := _heal(0.3 if kind == "monastery" else 0.1)
		_act("Father Martin says Mass beneath the banner. +%d faith, +%d morale. %d wounded return to the ranks.\n%s" % [gain, gain / 2, healed, Game.pop_notices()])))

	root_box.add_child(UI.button("Rest and tend the wounded (1 day)", func():
		Game.pass_days(1)
		var healed := _heal(0.5 if kind == "monastery" else 0.35)
		Game.morale = mini(100, Game.morale + 3)
		_act("The company rests. %d wounded return to the ranks.\n%s" % [healed, Game.pop_notices()])))

	root_box.add_child(UI.button("The Company", func(): Game.goto("company", {"back": "town"})))
	root_box.add_child(UI.button("March out to the map", func():
		Game.save_game()
		Game.goto("map"), 90))
	_contract_note()


func _heal(frac: float) -> int:
	var total := 0
	for s in Game.squads:
		var w := int(s["wounded"])
		var h := int(ceil(w * frac))
		s["wounded"] = w - h
		s["men"] = int(s["men"]) + h
		total += h
	return total


func _contract_note() -> void:
	if Game.contract.is_empty():
		return
	var c := Game.contract
	var where: String = Game.nodes[int(c["target"])]["name"]
	var txt := "Current contract: %s\nTarget: %s - %d days left - %d gold" % [c["title"], where, int(c["days_left"]), int(c["reward"])]
	if c.get("done", false):
		txt = "Contract done: return to %s for %d gold." % [Game.nodes[int(c["giver"])]["name"], int(c["reward"])]
	root_box.add_child(UI.label(txt, 22, UI.GOLD))


func _build_recruit() -> void:
	var full := Game.squads.size() >= Game.MAX_SQUADS
	root_box.add_child(UI.label("Free companies for hire (max %d squads)" % Game.MAX_SQUADS, 28, UI.GOLD))
	for t in Game.recruits_here():
		var type: String = t
		var u: Dictionary = Game.unit(type)
		var cost := Game.hire_cost(type)
		var b := UI.button("%s  x%d  -  %d gold\natk %d  def %s  %s" % [u["name"], u["size"], cost, int(u["atk"]), str(u["def"]), _unit_note(u)], func():
			Game.gold -= cost
			Game.squads.append(Game.make_squad(type, int(u["size"])))
			_act("A new squad of %s swears on the Cross." % u["name"]), 96)
		b.disabled = full or Game.gold < cost
		root_box.add_child(b)
	var rc := Game.reinforce_cost()
	var rb := UI.button("Reinforce all squads to full (%d gold)" % rc, func():
		Game.gold -= rc
		Game.reinforce_all()
		_act("Fresh men fill the gaps in the ranks."))
	rb.disabled = rc == 0 or Game.gold < rc
	root_box.add_child(rb)
	root_box.add_child(UI.button("Back", func():
		tab = "main"
		message = ""
		_build()))


func _unit_note(u: Dictionary) -> String:
	if u["cav"]:
		return "fast cavalry, deadly charge"
	if float(u["range"]) > 0:
		return "range %d" % int(u["range"])
	if float(u["anti_cav"]) > 1.0:
		return "holds against horse"
	return "solid infantry"


func _build_contracts() -> void:
	root_box.add_child(UI.label("Contracts", 30, UI.GOLD))
	if not Game.contract.is_empty():
		root_box.add_child(UI.label("You already hold a contract. Finish it before taking another.", 24, UI.DIM))
		_contract_note()
	else:
		var offers := Game.offers_here()
		if offers.is_empty():
			root_box.add_child(UI.label("No work posted today.", 24, UI.DIM))
		for o in offers:
			var offer: Dictionary = o
			var where: String = Game.nodes[int(offer["target"])]["name"]
			var desc := "%s\n%s - %d gold - %d days" % [offer["title"], where, int(offer["reward"]), int(offer["days_left"])]
			root_box.add_child(UI.button(desc, func():
				Game.accept_contract(offer)
				tab = "main"
				_act("You sign for the %s. Target: %s." % [offer["faction"], where]), 110))
	root_box.add_child(UI.button("Back", func():
		tab = "main"
		message = ""
		_build()))
