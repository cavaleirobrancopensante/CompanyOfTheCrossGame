extends Control
## Campaign map: HUD on top, Italy in the middle, actions at the bottom.

const MapView := preload("res://scripts/screens/map_view.gd")

var args := {}
var view: MapView
var info_label: Label
var travel_btn: Button
var selected := -1


func _ready() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)

	var top := UI.panel()
	var top_box := UI.vbox(2)
	top.add_child(top_box)
	top_box.add_child(UI.label(UI.status_line(), 21))
	var contract_txt := "No contract - find work in a town or city."
	if not Game.contract.is_empty():
		var c := Game.contract
		if c.get("done", false):
			contract_txt = "Collect payment at %s" % Game.nodes[int(c["giver"])]["name"]
		else:
			contract_txt = "%s (%d days)" % [c["title"], int(c["days_left"])]
	top_box.add_child(UI.label(contract_txt, 20, UI.GOLD))
	v.add_child(top)

	view = MapView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.node_tapped.connect(_on_node_tapped)
	v.add_child(view)

	var bottom := UI.panel()
	var bb := UI.vbox(8)
	bottom.add_child(bb)
	info_label = UI.label("Tap a place on the map. Gold roads lead from where you stand.", 22, UI.PARCHMENT)
	bb.add_child(info_label)
	var row := UI.hbox(8)
	travel_btn = UI.button("Travel", _travel, 80)
	travel_btn.visible = false
	row.add_child(travel_btn)
	row.add_child(UI.button("Company", func(): Game.goto("company", {"back": "map"}), 80))
	row.add_child(UI.button("Baggage", func(): Game.goto("baggage", {"back": "map"}), 80))
	row.add_child(UI.button("Camp (1 day)", _camp, 80))
	bb.add_child(row)
	v.add_child(bottom)

	var notes := Game.pop_notices()
	if notes != "":
		info_label.text = notes


func _on_node_tapped(idx: int) -> void:
	selected = idx
	view.selected = idx
	view.queue_redraw()
	var n: Dictionary = Game.nodes[idx]
	var here: Dictionary = Game.nodes[Game.current_node]
	var txt := "%s - %s" % [n["name"], GameData.kind_label(n["kind"])]
	if n["faction"] != "":
		txt += " (%s)" % n["faction"]
	if n["kind"] in ["camp", "ruins"] and n["cleared"]:
		txt += " - cleared"
	if idx == Game.current_node:
		travel_btn.visible = n["kind"] in ["city", "town", "village", "monastery"]
		travel_btn.text = "Enter %s" % n["name"]
		info_label.text = txt + "\nYou are here."
		return
	if here["links"].has(idx):
		var d := Game.travel_days_to(idx)
		var need := Game.daily_food() * d
		txt += "\n%d days march - eats %d food, costs %d gold" % [d, need, Game.daily_wage() * d]
		travel_btn.text = "March to %s" % n["name"]
		travel_btn.visible = true
	else:
		txt += "\nNo road from here. Travel through a neighbouring place."
		travel_btn.visible = false
	info_label.text = txt


func _travel() -> void:
	if selected < 0:
		return
	travel_btn.disabled = true
	if selected == Game.current_node:
		Game.settle_node()
		return
	var target := selected
	view.animate_march(Game.current_node, target, func(): Game.travel_to(target))


func _camp() -> void:
	Game.pass_days(1)
	var healed := 0
	for s in Game.squads:
		healed += Game.heal_squad(s, int(ceil(int(s["wounded"]) * 0.15)))
	Game.save_game()
	Game.notice("The company makes camp. %d wounded recover." % healed)
	if Game.is_wiped():
		Game.goto("gameover")
	else:
		Game.goto("map")
