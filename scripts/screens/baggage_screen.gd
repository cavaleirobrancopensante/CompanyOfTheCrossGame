extends Control
## The baggage train: mules, carts, what they carry, and how heavy it is.

var args := {}


func _ready() -> void:
	var v := UI.page(self)
	v.add_child(UI.label("Baggage Train", 44, UI.GOLD, true))
	var cap := Game.capacity_cn()
	var load := Game.load_cn()
	v.add_child(UI.label("%d mules (%d cn each), %d carts (%d cn each)\nThe men carry %d cn of company stores themselves." % [
		Game.mules, BX.MULE_CN, Game.carts, BX.CART_CN, BX.BASE_CN], 22, UI.DIM, true))
	var bar := ProgressBar.new()
	bar.max_value = cap
	bar.value = mini(load, cap)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 26)
	v.add_child(bar)
	var over := Game.overloaded()
	v.add_child(UI.label("Load %d / %d cn%s" % [load, cap, "  - OVERLOADED: marches take half again as long" if over else ""], 24, UI.BAD if over else UI.PARCHMENT))
	v.add_child(UI.label("Food: %d rations (%d cn)" % [Game.food, Game.food * BX.FOOD_CN], 22))
	v.add_child(UI.label("Stores", 30, UI.GOLD))
	if Game.stash.is_empty():
		v.add_child(UI.label("Nothing but dust and an old saddle blanket.", 22, UI.DIM))
	var keys := Game.stash.keys()
	keys.sort()
	for k in keys:
		var it: Dictionary = BX.ITEMS[k]
		v.add_child(UI.label("%s x%d   (%d cn, worth %d gp each)" % [it["name"], int(Game.stash[k]), int(it["cn"]) * int(Game.stash[k]), int(it["gp"])], 23))
	v.add_child(UI.label("Give gear to men from their squad or character sheet. Buy mules and carts in town stables.", 20, UI.DIM))
	var back: String = args.get("back", "map")
	v.add_child(UI.button("Back", func():
		if back == "company":
			Game.goto("company", {"back": args.get("back2", "map")})
		else:
			Game.goto(back), 90))
