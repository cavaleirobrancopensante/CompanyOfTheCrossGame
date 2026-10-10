extends Control
## Root: owns the theme and swaps one screen at a time.

const SCREENS := {
	"title": preload("res://scripts/screens/title_screen.gd"),
	"map": preload("res://scripts/screens/map_screen.gd"),
	"town": preload("res://scripts/screens/town_screen.gd"),
	"event": preload("res://scripts/screens/event_screen.gd"),
	"battle": preload("res://scripts/screens/battle_screen.gd"),
	"company": preload("res://scripts/screens/company_screen.gd"),
	"squad": preload("res://scripts/screens/squad_screen.gd"),
	"character": preload("res://scripts/screens/character_screen.gd"),
	"baggage": preload("res://scripts/screens/baggage_screen.gd"),
	"gameover": preload("res://scripts/screens/gameover_screen.gd"),
}

var current: Control


func _ready() -> void:
	theme = UI.make_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	Game.screen_requested.connect(_on_screen_requested)
	_on_screen_requested("title", {})


func _on_screen_requested(screen_name: String, args: Dictionary) -> void:
	# Deferred so a screen can request a change from inside its own button callback.
	call_deferred("_swap", screen_name, args)


func _swap(screen_name: String, args: Dictionary) -> void:
	if current:
		current.queue_free()
		current = null
	var scr: Control = SCREENS[screen_name].new()
	scr.set("args", args)
	scr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scr)
	current = scr
