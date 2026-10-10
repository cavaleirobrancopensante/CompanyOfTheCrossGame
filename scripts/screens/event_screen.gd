extends Control
## Curious Expedition-style event card: text, choices, outcome, continue.

var args := {}
var box: VBoxContainer
var event: Dictionary
var after := "map"


func _ready() -> void:
	event = args.get("event", {})
	after = args.get("after", "map")
	box = UI.page(self)
	var notes := Game.pop_notices()
	if notes != "":
		box.add_child(UI.label(notes, 22, UI.DIM))
	box.add_child(UI.label(UI.status_line(), 22, UI.DIM))
	var card := UI.panel()
	var inner := UI.vbox(16)
	card.add_child(inner)
	box.add_child(card)
	inner.add_child(UI.label(str(event.get("title", "")), 36, UI.GOLD, true))
	inner.add_child(UI.label(str(event.get("text", "")), 27))
	var choices := UI.vbox(12)
	inner.add_child(choices)
	for c in event.get("choices", []):
		var choice: Dictionary = c
		var b := UI.button(str(choice["label"]), func(): _choose(choice, inner, choices), 84)
		if choice.has("requires") and not Game.can_afford(choice["requires"]):
			b.disabled = true
		choices.add_child(b)


func _choose(choice: Dictionary, inner: VBoxContainer, choices: VBoxContainer) -> void:
	choices.queue_free()
	var r := Game.resolve_choice(choice)
	inner.add_child(UI.label(r["text"], 26, UI.PARCHMENT))
	var battle: String = r["battle"]
	if battle != "":
		var army: Dictionary = GameData.ARMIES[battle]
		inner.add_child(UI.label("Enemy: %s" % army["name"], 26, UI.BAD))
		inner.add_child(UI.button("To battle!", func(): Game.start_battle(battle, after), 90))
	else:
		inner.add_child(UI.button("Continue", func(): Game.continue_after_event(after), 90))
