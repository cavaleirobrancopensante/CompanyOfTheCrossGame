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
		"armoury":
			_build_armoury()
		"stables":
			_build_stables()
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
		root_box.add_child(UI.button("Armoury and market", func():
			tab = "armoury"
			message = ""
			_build()))
	if kind != "monastery":
		root_box.add_child(UI.button("Stables (mules and carts)", func():
			tab = "stables"
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

	root_box.add_child(UI.button("The Company - sheets and gear", func(): Game.goto("company", {"back": "town"})))
	root_box.add_child(UI.button("March out to the map", func():
		Game.save_game()
		Game.goto("map"), 90))
	_contract_note()


func _heal(frac: float) -> int:
	var total := 0
	for s in Game.squads:
		total += Game.heal_squad(s, int(ceil(int(s["wounded"]) * frac)))
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
		var kit: Dictionary = u["kit"]
		var kit_txt := ", ".join(kit.values().map(func(k): return BX.ITEMS[k]["name"].to_lower()))
		var b := UI.button("%s  x%d  -  %d gold\n%s %d, %s - %s" % [u["name"], u["size"], cost, u["cls"], int(u["level"]), kit_txt, _unit_note(u)], func():
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


func _back_button() -> void:
	root_box.add_child(UI.button("Back", func():
		tab = "main"
		message = ""
		_build()))


func _build_armoury() -> void:
	root_box.add_child(UI.label("Armoury - buy into the baggage", 28, UI.GOLD))
	root_box.add_child(UI.label("Load %d / %d cn" % [Game.load_cn(), Game.capacity_cn()], 22, UI.BAD if Game.overloaded() else UI.DIM))
	for item in BX.SHOP_ITEMS:
		var it: String = item
		var info: Dictionary = BX.ITEMS[it]
		var price := Game.item_price(it)
		var stat := ""
		if info.has("dmg"):
			stat = " d%d" % int(info["dmg"])
		elif info.has("ac"):
			stat = " AC %d" % int(info["ac"]) if info["slot"] == "armor" else " AC -1"
		var b := UI.button("%s%s - %d gp (%d cn)" % [info["name"], stat, price, int(info["cn"])], func():
			Game.gold -= price
			Game.add_item(it)
			_act("Bought: %s. It goes on the mules." % info["name"]), 66)
		b.disabled = Game.gold < price
		root_box.add_child(b)
	if not Game.stash.is_empty():
		root_box.add_child(UI.label("Sell from the baggage (half price)", 28, UI.GOLD))
		var keys := Game.stash.keys()
		keys.sort()
		for item in keys:
			var it: String = item
			var p := Game.sell_price(it)
			root_box.add_child(UI.button("Sell %s (%d left) - %d gp" % [BX.ITEMS[it]["name"], int(Game.stash[it]), p], func():
				if Game.take_item(it):
					Game.gold += p
				_act("Sold: %s." % BX.ITEMS[it]["name"]), 66))
	_back_button()


func _build_stables() -> void:
	root_box.add_child(UI.label("Stables", 28, UI.GOLD))
	root_box.add_child(UI.label("%d mules, %d carts. Load %d / %d cn." % [Game.mules, Game.carts, Game.load_cn(), Game.capacity_cn()], 22, UI.BAD if Game.overloaded() else UI.DIM))
	var bm := UI.button("Buy a mule - %d gp (+%d cn)" % [BX.MULE_GP, BX.MULE_CN], func():
		Game.gold -= BX.MULE_GP
		Game.mules += 1
		_act("A mule with a mean eye joins the train."))
	bm.disabled = Game.gold < BX.MULE_GP
	root_box.add_child(bm)
	var bc := UI.button("Buy a cart and its horses - %d gp (+%d cn)" % [BX.CART_GP, BX.CART_CN], func():
		Game.gold -= BX.CART_GP
		Game.carts += 1
		_act("A creaking cart joins the train."))
	bc.disabled = Game.gold < BX.CART_GP
	root_box.add_child(bc)
	var sm := UI.button("Sell a mule - %d gp" % (BX.MULE_GP / 2), func():
		Game.mules -= 1
		Game.gold += BX.MULE_GP / 2
		_act("Sold a mule."))
	sm.disabled = Game.mules <= 0
	root_box.add_child(sm)
	var sc := UI.button("Sell a cart - %d gp" % (BX.CART_GP / 2), func():
		Game.carts -= 1
		Game.gold += BX.CART_GP / 2
		_act("Sold a cart."))
	sc.disabled = Game.carts <= 0
	root_box.add_child(sc)
	root_box.add_child(UI.button("Look over the baggage", func(): Game.goto("baggage", {"back": "town"})))
	_back_button()
