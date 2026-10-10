class_name GameData
extends RefCounted
## Static tables: unit types, enemy armies, the map of Italy, and road events.

const FACTIONS := ["Holy See", "Venice", "Milan", "Naples"]

const FACTION_COLORS := {
	"Holy See": Color(0.86, 0.75, 0.35),
	"Venice": Color(0.75, 0.25, 0.25),
	"Milan": Color(0.35, 0.55, 0.8),
	"Naples": Color(0.45, 0.7, 0.45),
	"": Color(0.6, 0.6, 0.6),
}

# Mass-combat profile of each troop type. The fighting numbers come from B/X:
# class + level + kit (weapon, missile, armour, shield). cost = gold per man; wage = gold per man per 5 days.
const UNITS := {
	"sword": {"name": "Sergeants", "short": "SW", "cls": "Fighter", "level": 1,
		"kit": {"weapon": "sword", "armor": "chain", "shield": "shield"},
		"speed": 42.0, "range": 0.0, "reload": 0.0, "cost": 14, "wage": 1.0, "size": 24,
		"cav": false, "anti_cav": 1.0, "nerve": 1.0, "color": Color(0.85, 0.82, 0.75)},
	"spear": {"name": "Spearmen", "short": "SP", "cls": "Normal Man", "level": 0,
		"kit": {"weapon": "spear", "armor": "leather", "shield": "shield"},
		"speed": 38.0, "range": 0.0, "reload": 0.0, "cost": 9, "wage": 0.8, "size": 30,
		"cav": false, "anti_cav": 2.5, "nerve": 1.0, "color": Color(0.8, 0.8, 0.85)},
	"xbow": {"name": "Crossbowmen", "short": "XB", "cls": "Normal Man", "level": 0,
		"kit": {"weapon": "dagger", "missile": "crossbow", "armor": "leather"},
		"speed": 38.0, "range": 270.0, "reload": 2.6, "cost": 14, "wage": 1.1, "size": 20,
		"cav": false, "anti_cav": 1.0, "nerve": 1.2, "color": Color(0.75, 0.85, 0.7)},
	"knight": {"name": "Knights", "short": "KN", "cls": "Fighter", "level": 1,
		"kit": {"weapon": "lance", "armor": "plate", "shield": "shield"},
		"speed": 105.0, "range": 0.0, "reload": 0.0, "cost": 40, "wage": 3.0, "size": 12,
		"cav": true, "anti_cav": 1.0, "nerve": 0.8, "color": Color(0.95, 0.9, 0.6)},
	# --- enemies only ---
	"brigand": {"name": "Brigands", "short": "BR", "cls": "Normal Man", "level": 0,
		"kit": {"weapon": "spear", "armor": "leather"},
		"speed": 42.0, "range": 0.0, "reload": 0.0, "cost": 0, "wage": 0.0, "size": 24,
		"cav": false, "anti_cav": 1.0, "nerve": 1.4, "color": Color(0.6, 0.5, 0.4)},
	"bowman": {"name": "Bowmen", "short": "BW", "cls": "Normal Man", "level": 0,
		"kit": {"weapon": "dagger", "missile": "short_bow"},
		"speed": 40.0, "range": 240.0, "reload": 2.2, "cost": 0, "wage": 0.0, "size": 16,
		"cav": false, "anti_cav": 1.0, "nerve": 1.4, "color": Color(0.55, 0.6, 0.45)},
	"raider": {"name": "Hill Raiders", "short": "RD", "cls": "Fighter", "level": 1,
		"kit": {"weapon": "spear", "armor": "leather", "shield": "shield"},
		"speed": 95.0, "range": 0.0, "reload": 0.0, "cost": 0, "wage": 0.0, "size": 14,
		"cav": true, "anti_cav": 1.0, "nerve": 1.2, "color": Color(0.7, 0.55, 0.35)},
	"zealot": {"name": "Votaries", "short": "VO", "cls": "Normal Man", "level": 0,
		"kit": {"weapon": "two_handed_sword"},
		"speed": 44.0, "range": 0.0, "reload": 0.0, "cost": 0, "wage": 0.0, "size": 22,
		"cav": false, "anti_cav": 1.0, "nerve": 0.5, "color": Color(0.4, 0.75, 0.85)},
}

# Loot that can turn up after a victory, by army.
const LOOT_ITEMS := {
	"brigands_small": ["spear", "leather", "dagger", "short_bow"],
	"brigands_large": ["spear", "leather", "sword", "shield", "short_bow", "wineskin"],
	"raiders": ["spear", "shield", "leather"],
	"votaries": ["two_handed_sword", "old_world_relic", "holy_water"],
	"scavengers": ["dagger", "rope", "old_world_relic", "leather"],
	"condottieri": ["sword", "chain", "crossbow", "plate", "shield"],
}

const PLAYER_UNITS := ["sword", "spear", "xbow", "knight"]

# Enemy armies: list of [unit_type, men], plus loot gold.
const ARMIES := {
	"brigands_small": {"name": "Road brigands", "squads": [["brigand", 18], ["bowman", 10]], "loot": 80},
	"brigands_large": {"name": "Brigand warband", "squads": [["brigand", 24], ["brigand", 20], ["bowman", 14], ["raider", 10]], "loot": 220},
	"raiders": {"name": "Hill raiders", "squads": [["raider", 14], ["raider", 12]], "loot": 90},
	"votaries": {"name": "Votaries of the Engine", "squads": [["zealot", 22], ["zealot", 18], ["bowman", 10]], "loot": 130},
	"scavengers": {"name": "Ruin scavengers", "squads": [["brigand", 16], ["bowman", 8]], "loot": 60},
	"condottieri": {"name": "Rival condottieri", "squads": [["spear", 26], ["sword", 20], ["xbow", 14], ["knight", 10]], "loot": 320},
}

const SQUAD_NAMES := ["Mateo's Own", "The Hammers", "Black Lances", "St. Michael's Bows",
	"The Ragged Cross", "Viterbo Levy", "The Bells", "Grey Brothers", "Martin's Flock",
	"The Iron Rosary", "Sons of Tiber", "Old Wolves", "The Penitents", "Lamb's Guard"]

# Normalised map positions inside the drawn land rectangle (x 0..1, y 0..1).
const MAP_NODES := [
	{"name": "Turin", "kind": "town", "x": 0.11, "y": 0.17, "faction": "Milan"},
	{"name": "Milan", "kind": "city", "x": 0.23, "y": 0.13, "faction": "Milan"},
	{"name": "Genoa", "kind": "town", "x": 0.21, "y": 0.225, "faction": "Milan"},
	{"name": "Verona", "kind": "town", "x": 0.45, "y": 0.12, "faction": "Venice"},
	{"name": "Padua", "kind": "village", "x": 0.57, "y": 0.165, "faction": "Venice"},
	{"name": "Venice", "kind": "city", "x": 0.67, "y": 0.13, "faction": "Venice"},
	{"name": "Glass Fields", "kind": "ruins", "x": 0.34, "y": 0.2, "faction": ""},
	{"name": "Bologna", "kind": "town", "x": 0.46, "y": 0.245, "faction": "Holy See"},
	{"name": "Ravenna", "kind": "village", "x": 0.6, "y": 0.25, "faction": "Holy See"},
	{"name": "Pisa", "kind": "village", "x": 0.33, "y": 0.32, "faction": ""},
	{"name": "Ruins of Florence", "kind": "ruins", "x": 0.42, "y": 0.32, "faction": ""},
	{"name": "Apennine Hold", "kind": "camp", "x": 0.53, "y": 0.31, "faction": ""},
	{"name": "Ancona", "kind": "town", "x": 0.665, "y": 0.35, "faction": "Holy See"},
	{"name": "Siena", "kind": "village", "x": 0.42, "y": 0.41, "faction": ""},
	{"name": "Perugia", "kind": "town", "x": 0.52, "y": 0.41, "faction": "Holy See"},
	{"name": "Assisi", "kind": "monastery", "x": 0.58, "y": 0.385, "faction": "Holy See"},
	{"name": "Spoleto", "kind": "village", "x": 0.6, "y": 0.47, "faction": "Holy See"},
	{"name": "Gran Sasso Hold", "kind": "camp", "x": 0.69, "y": 0.47, "faction": ""},
	{"name": "Orvieto", "kind": "town", "x": 0.5, "y": 0.475, "faction": "Holy See"},
	{"name": "Viterbo", "kind": "town", "x": 0.5, "y": 0.535, "faction": "Holy See"},
	{"name": "Rome", "kind": "city", "x": 0.56, "y": 0.585, "faction": "Holy See"},
	{"name": "Montecassino", "kind": "monastery", "x": 0.64, "y": 0.63, "faction": "Holy See"},
	{"name": "Naples", "kind": "city", "x": 0.69, "y": 0.7, "faction": "Naples"},
	{"name": "Bari", "kind": "town", "x": 0.86, "y": 0.615, "faction": "Naples"},
	{"name": "Taranto", "kind": "village", "x": 0.84, "y": 0.67, "faction": "Naples"},
	{"name": "The Silent Array", "kind": "ruins", "x": 0.75, "y": 0.76, "faction": ""},
	{"name": "Cosenza", "kind": "village", "x": 0.78, "y": 0.82, "faction": "Naples"},
	{"name": "Reggio", "kind": "town", "x": 0.76, "y": 0.91, "faction": "Naples"},
]

const START_NODE := "Rome"

# A rough outline of the peninsula, normalised like MAP_NODES.
const OUTLINE := [
	Vector2(0.04, 0.16), Vector2(0.08, 0.09), Vector2(0.25, 0.04), Vector2(0.45, 0.06),
	Vector2(0.62, 0.03), Vector2(0.78, 0.07), Vector2(0.8, 0.15), Vector2(0.72, 0.2),
	Vector2(0.66, 0.22), Vector2(0.68, 0.3), Vector2(0.74, 0.4), Vector2(0.8, 0.48),
	Vector2(0.88, 0.57), Vector2(0.97, 0.65), Vector2(0.99, 0.7), Vector2(0.93, 0.72),
	Vector2(0.86, 0.68), Vector2(0.8, 0.7), Vector2(0.8, 0.78), Vector2(0.84, 0.86),
	Vector2(0.8, 0.95), Vector2(0.74, 0.93), Vector2(0.72, 0.84), Vector2(0.68, 0.74),
	Vector2(0.62, 0.66), Vector2(0.54, 0.61), Vector2(0.46, 0.54), Vector2(0.38, 0.46),
	Vector2(0.32, 0.38), Vector2(0.3, 0.3), Vector2(0.24, 0.245), Vector2(0.14, 0.265),
	Vector2(0.06, 0.24),
]

# Road events. Effects: gold, food, morale, faith, renown, men (lost), wounded,
# rep {faction: delta}, recruit_men, days, battle (army key),
# chance {p, win {...}, lose {...}, win_text, lose_text}. "requires" gates a choice.
const ROAD_EVENTS := [
	{"id": "hermit", "title": "The Hermit at the Wayside Cross",
		"text": "An old hermit kneels at a rusted iron cross by the road. He asks nothing for himself, only bread for the children of the next valley.",
		"choices": [
			{"label": "Give him bread (5 food)", "requires": {"food": 5},
				"effects": {"food": -5, "faith": 5, "morale": 3}, "text": "He blesses the banner. Father Martin says nothing, but he smiles for the rest of the day."},
			{"label": "Ride past", "effects": {"faith": -2}, "text": "The men look back at him over their shoulders for a long while."},
		]},
	{"id": "machine_voice", "title": "The Voice in the Station",
		"text": "In a collapsed Old World station a machine still hums. A gentle voice offers answers to every question - where the grain is hidden, which lord will die, how to win.",
		"choices": [
			{"label": "Let the men listen", "effects": {"chance": {"p": 0.5,
				"win": {"gold": 80, "faith": -5}, "win_text": "It speaks of a buried cache. The gold is real. So is the unease that follows the company afterwards.",
				"lose": {"faith": -12, "morale": -10}, "lose_text": "It answers too well. For days the men whisper about it, and some stop coming to Mass."}}},
			{"label": "Have Father Martin bless the place", "effects": {"faith": 6},
				"text": "Martin prays the old prayers over the dead machine. Its voice falters and is silent."},
			{"label": "Smash it", "effects": {"renown": 4, "chance": {"p": 0.5,
				"win": {}, "win_text": "Mateo's hammer ends the conversation.",
				"lose": {"battle": "votaries"}, "lose_text": "Its keepers, the Votaries of the Engine, come screaming out of the dark!"}}},
		]},
	{"id": "deserters", "title": "Venetian Deserters",
		"text": "Four ragged men in Venetian colours beg to march under the Cross. Their captain left them unpaid in a ditch.",
		"choices": [
			{"label": "Take them in", "effects": {"recruit_men": 4, "rep": {"Venice": -3}},
				"text": "They kiss the banner. Venice will hear of it."},
			{"label": "Send them on their way", "effects": {"rep": {"Venice": 1}}, "text": "They curse you in three dialects."},
		]},
	{"id": "ambush", "title": "Brigands on the Road",
		"text": "Felled trees block the road. Men with crossbows and rusted blades rise from the ditches and demand a toll.",
		"choices": [
			{"label": "Form up and fight", "effects": {"battle": "brigands_small"}, "text": "Mateo spits and lifts his hammer."},
			{"label": "Pay the toll (40 gold)", "requires": {"gold": 40}, "effects": {"gold": -40, "morale": -4},
				"text": "The men grumble at paying thieves."},
		]},
	{"id": "flood", "title": "The Swollen River",
		"text": "Autumn rain has turned the ford into brown, roaring water.",
		"choices": [
			{"label": "Wait for it to fall (2 days)", "effects": {"days": 2}, "text": "Two days of mud and dice."},
			{"label": "Ford it now", "effects": {"chance": {"p": 0.6,
				"win": {}, "win_text": "Soaked to the bone, but everyone makes it.",
				"lose": {"food": -15, "men": 2}, "lose_text": "A wagon overturns. Two men and much of the bread are lost to the river."}}},
		]},
	{"id": "pilgrims", "title": "Pilgrims for Rome",
		"text": "A band of pilgrims with walking staves and painted shells ask to walk in the company's shadow for a day.",
		"choices": [
			{"label": "Escort them (1 day)", "effects": {"days": 1, "faith": 8, "renown": 3, "gold": 20},
				"text": "They sing the whole way, and leave a purse at the chaplain's feet."},
			{"label": "We have no time", "effects": {}, "text": "They go on alone."},
		]},
	{"id": "relic", "title": "The Relic Peddler",
		"text": "A peddler unrolls a cloth: a fingerbone of Saint George, he swears, for only 60 gold.",
		"choices": [
			{"label": "Ask Father Martin to examine it", "effects": {"chance": {"p": 0.3,
				"win": {"gold": -60, "faith": 15, "morale": 10}, "win_text": "Martin goes pale and kneels. He pays from his own purse and yours.",
				"lose": {"renown": 2}, "lose_text": "Martin names it a pig's knuckle. The peddler runs, the men laugh."}}},
			{"label": "Buy it without question", "requires": {"gold": 60}, "effects": {"gold": -60, "morale": 8},
				"text": "The men cheer the relic. Martin looks at you for a long time."},
			{"label": "Ignore him", "effects": {}, "text": "He tries his luck with the baggage boys instead."},
		]},
	{"id": "quarrel", "title": "Knives over Dice",
		"text": "Two sergeants quarrel over a game of dice. Knives come out.",
		"choices": [
			{"label": "Let Mateo settle it with his fists", "effects": {"chance": {"p": 0.7,
				"win": {"morale": 5}, "win_text": "Two blows, one apology. Order is restored.",
				"lose": {"wounded": 2, "morale": -3}, "lose_text": "It turns into a brawl. Two men end up in the wagon."}}},
			{"label": "Father Martin intervenes", "effects": {"faith": 3, "morale": 2},
				"text": "He takes the dice, blesses them, and keeps them."},
		]},
	{"id": "wolves", "title": "Wolves in the Night",
		"text": "Wolves - big ones, bred wild since the Fall - circle the baggage.",
		"choices": [
			{"label": "Double the watch", "effects": {"morale": -3}, "text": "Nobody sleeps much."},
			{"label": "Hunt them at dawn", "effects": {"chance": {"p": 0.6,
				"win": {"food": 10, "renown": 1}, "win_text": "Wolf stew. Not good, but warm.",
				"lose": {"wounded": 2}, "lose_text": "The pack turns on the hunters."}}},
		]},
	{"id": "raiders", "title": "Riders on the Ridge",
		"text": "Horsemen watch from the ridge. Hill raiders - they will strike the column at the next ford.",
		"choices": [
			{"label": "Form up and meet them", "effects": {"battle": "raiders"}, "text": "Spears to the front!"},
			{"label": "Force-march away", "effects": {"chance": {"p": 0.5,
				"win": {"morale": -2}, "win_text": "You outpace them by nightfall.",
				"lose": {"food": -15, "wounded": 3}, "lose_text": "They catch the rearguard and loot the wagons."}}},
		]},
	{"id": "famine", "title": "The Hungry Hamlet",
		"text": "A hamlet of thin faces. The harvest failed and the granary was burned by raiders.",
		"choices": [
			{"label": "Share our bread (15 food)", "requires": {"food": 15},
				"effects": {"food": -15, "faith": 8, "rep": {"Holy See": 3}}, "text": "The village priest rings his one bell for you."},
			{"label": "Requisition what they have left", "effects": {"food": 10, "faith": -10, "morale": 2},
				"text": "The men eat well. Martin will not look at you."},
		]},
	{"id": "votaries", "title": "The Procession of the Engine",
		"text": "Votaries of the Engine march past, carrying a glowing idol from the Old World. They sing to it as if it could hear them.",
		"choices": [
			{"label": "Disperse them", "effects": {"battle": "votaries", "renown": 4}, "text": "Father Martin lifts the cross. The Votaries lift their blades."},
			{"label": "Let them pass", "effects": {"faith": -4}, "text": "Some of the men stare at the idol's light too long."},
		]},
]

const RUIN_EVENT := {"id": "ruins", "title": "",
	"text": "Broken towers of glass and steel from before the Fall. Somewhere below lie vaults the scavengers have not yet emptied.",
	"choices": [
		{"label": "Search the vaults", "effects": {"chance": {"p": 0.55,
			"win": {"gold": 110, "food": 10}, "win_text": "Sealed tins of food and old coin. The men bless their luck.",
			"lose": {"battle": "scavengers"}, "lose_text": "Scavengers have claimed these vaults - and they will not share!"}}},
		{"label": "Leave the dead in peace", "effects": {"faith": 2}, "text": "Martin says a prayer for whoever lived here."},
	]}

const CAMP_EVENT := {"id": "camp", "title": "",
	"text": "A brigand hold squats on the mountainside: palisades, smoke, and the gibbets of those who resisted them.",
	"choices": [
		{"label": "Assault the hold", "effects": {"battle": "brigands_large"}, "text": "The company forms up beneath the banner."},
		{"label": "Withdraw", "effects": {}, "text": "Another day."},
	]}


static func build_map() -> Array:
	var nodes: Array = []
	for i in MAP_NODES.size():
		var d: Dictionary = MAP_NODES[i].duplicate(true)
		d["id"] = i
		d["links"] = []
		d["visited"] = false
		d["cleared"] = false
		nodes.append(d)
	# Minimum spanning tree (Prim) guarantees every node is reachable.
	var in_tree := {0: true}
	while in_tree.size() < nodes.size():
		var best := Vector2i(-1, -1)
		var best_d := 99.0
		for a in in_tree.keys():
			for b in nodes.size():
				if in_tree.has(b):
					continue
				var dd := _dist(nodes[a], nodes[b])
				if dd < best_d:
					best_d = dd
					best = Vector2i(a, b)
		_link(nodes, best.x, best.y)
		in_tree[best.y] = true
	# Extra short roads make loops and choices.
	for a in nodes.size():
		for b in range(a + 1, nodes.size()):
			if _dist(nodes[a], nodes[b]) < 0.105:
				_link(nodes, a, b)
	return nodes


static func _dist(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a["x"], a["y"]).distance_to(Vector2(b["x"], b["y"]))


static func _link(nodes: Array, a: int, b: int) -> void:
	if not nodes[a]["links"].has(b):
		nodes[a]["links"].append(b)
	if not nodes[b]["links"].has(a):
		nodes[b]["links"].append(a)


static func travel_days(a: Dictionary, b: Dictionary) -> int:
	return maxi(1, int(ceil(_dist(a, b) * 14.0)))


static func kind_label(kind: String) -> String:
	match kind:
		"city": return "City"
		"town": return "Town"
		"village": return "Village"
		"monastery": return "Monastery"
		"ruins": return "Old World ruins"
		"camp": return "Brigand hold"
	return kind
