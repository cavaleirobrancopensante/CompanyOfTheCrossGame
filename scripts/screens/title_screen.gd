extends Control

var args := {}


func _ready() -> void:
	var v := UI.page(self)
	v.add_child(_spacer(120))
	v.add_child(UI.label("✠", 110, UI.RED, true))
	v.add_child(UI.label("THE COMPANY\nOF THE CROSS", 54, UI.GOLD, true))
	v.add_child(UI.label("Anno Domini 2987 - the Papal States", 24, UI.DIM, true))
	v.add_child(_spacer(30))
	v.add_child(UI.label("A thousand years after the Fall, Italy is ruins, hill brigands and machine-cultists. Captain Mateo 'Hammerhead' leads a free company under the Cross, with Father Martin to keep their souls - and their nerve.", 24, UI.PARCHMENT, true))
	v.add_child(_spacer(40))
	if Game.has_save():
		v.add_child(UI.button("Continue the campaign", _continue, 96))
	v.add_child(UI.button("New campaign", _new, 96))
	v.add_child(_spacer(40))
	v.add_child(UI.label("Salgadoido's version %s" % ProjectSettings.get_setting("application/config/version", "?"), 20, UI.DIM, true))


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _continue() -> void:
	if Game.load_game():
		Game.goto("map")
	else:
		_new()


func _new() -> void:
	Game.new_game()
	Game.goto("town")
