extends Control

var args := {}


func _ready() -> void:
	Game.delete_save()
	var v := UI.page(self)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 200)
	v.add_child(gap)
	v.add_child(UI.label("✠", 100, UI.RED, true))
	v.add_child(UI.label("The Company is no more", 44, UI.GOLD, true))
	v.add_child(UI.label("On day %d the last of the men fell or scattered. Father Martin buried the banner with them.\n\nRenown at the end: %d" % [Game.day, Game.renown], 26, UI.PARCHMENT, true))
	v.add_child(UI.button("Raise a new company", func(): Game.goto("title"), 96))
