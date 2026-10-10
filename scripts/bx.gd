class_name BX
extends RefCounted
## Basic/Expert D&D rules: abilities, classes, AC, THAC0, hit points, XP, equipment.

# ------------------------------------------------------------------ classes

const CLASSES := {
	"Normal Man": {"hd": 4, "xp": [0], "prime": "", "blunt_only": false},
	"Fighter": {"hd": 8, "xp": [0, 2000, 4000, 8000, 16000, 32000, 64000, 120000, 240000], "prime": "str", "blunt_only": false},
	"Cleric": {"hd": 6, "xp": [0, 1500, 3000, 6000, 12000, 25000, 50000, 100000, 200000], "prime": "wis", "blunt_only": true},
}

# Saving throws: Death/Poison, Wands, Paralysis/Stone, Breath, Spells.
const SAVES := {
	"Normal Man": [[99, [14, 15, 16, 17, 18]]],
	"Fighter": [[3, [12, 13, 14, 15, 16]], [6, [10, 11, 12, 13, 14]], [9, [8, 9, 10, 10, 12]]],
	"Cleric": [[4, [11, 12, 14, 16, 15]], [8, [9, 10, 12, 14, 12]], [12, [6, 7, 9, 11, 9]]],
}

const ABILITIES := ["str", "int", "wis", "dex", "con", "cha"]

# A Normal Man who earns this much XP becomes a 1st-level Fighter.
const NORMAL_MAN_PROMOTE := 100

# ------------------------------------------------------------------ equipment
# slot: weapon / missile / armor / shield / gear. Weights in coins (cn), prices in gp.

const ITEMS := {
	"dagger": {"name": "Dagger", "slot": "weapon", "dmg": 4, "gp": 3, "cn": 10, "blunt": false},
	"sword": {"name": "Sword", "slot": "weapon", "dmg": 8, "gp": 10, "cn": 60, "blunt": false},
	"two_handed_sword": {"name": "Two-handed sword", "slot": "weapon", "dmg": 10, "gp": 15, "cn": 150, "blunt": false, "two_handed": true},
	"spear": {"name": "Spear", "slot": "weapon", "dmg": 6, "gp": 3, "cn": 30, "blunt": false},
	"pole_arm": {"name": "Pole arm", "slot": "weapon", "dmg": 10, "gp": 7, "cn": 150, "blunt": false, "two_handed": true},
	"lance": {"name": "Lance", "slot": "weapon", "dmg": 10, "gp": 10, "cn": 180, "blunt": false},
	"mace": {"name": "Mace", "slot": "weapon", "dmg": 6, "gp": 5, "cn": 30, "blunt": true},
	"war_hammer": {"name": "War hammer", "slot": "weapon", "dmg": 6, "gp": 5, "cn": 30, "blunt": true},
	"crossbow": {"name": "Crossbow", "slot": "missile", "dmg": 6, "gp": 30, "cn": 50, "blunt": false},
	"short_bow": {"name": "Short bow", "slot": "missile", "dmg": 6, "gp": 25, "cn": 30, "blunt": false},
	"sling": {"name": "Sling", "slot": "missile", "dmg": 4, "gp": 2, "cn": 20, "blunt": true},
	"leather": {"name": "Leather armour", "slot": "armor", "ac": 7, "gp": 20, "cn": 200},
	"chain": {"name": "Chain mail", "slot": "armor", "ac": 5, "gp": 40, "cn": 400},
	"plate": {"name": "Plate mail", "slot": "armor", "ac": 3, "gp": 60, "cn": 500},
	"shield": {"name": "Shield", "slot": "shield", "ac": 1, "gp": 10, "cn": 100},
	"holy_symbol": {"name": "Holy symbol", "slot": "gear", "gp": 25, "cn": 1},
	"holy_water": {"name": "Holy water", "slot": "gear", "gp": 25, "cn": 10},
	"rope": {"name": "Rope, 50'", "slot": "gear", "gp": 1, "cn": 50},
	"wineskin": {"name": "Wineskin", "slot": "gear", "gp": 1, "cn": 20},
	"old_world_relic": {"name": "Old World relic", "slot": "gear", "gp": 60, "cn": 30},
}

const SHOP_ITEMS := ["dagger", "sword", "spear", "mace", "war_hammer", "pole_arm", "two_handed_sword",
	"crossbow", "short_bow", "sling", "leather", "chain", "plate", "shield", "holy_symbol", "holy_water", "rope", "wineskin"]

# Pack animals and vehicles (B/X: mule 2000 cn, cart 4000 cn).
const MULE_CN := 2000
const CART_CN := 4000
const MULE_GP := 30
const CART_GP := 150
const FOOD_CN := 10     # one day's ration for one man... well, a sack of them
const BASE_CN := 1500   # what the men carry on their own backs for the company

const FIRST_NAMES := ["Mateo", "Luca", "Marco", "Pietro", "Giovanni", "Paolo", "Andrea", "Tomaso",
	"Bruno", "Enzo", "Gino", "Dario", "Aldo", "Bernardo", "Cosimo", "Rinaldo", "Ugo", "Vito",
	"Nico", "Silvio", "Benedetto", "Lorenzo", "Filippo", "Giacomo", "Matteo", "Raffaele", "Sandro",
	"Taddeo", "Orsino", "Ercole", "Fabio", "Guido", "Leone", "Michele", "Simone", "Stefano"]
const EPITHETS := ["the Red", "One-Eye", "of Orvieto", "the Quiet", "Ironhand", "the Younger",
	"of the Marsh", "Bellringer", "the Lame", "Crowfoot", "of Spoleto", "the Pious", "Long-Arm",
	"the Ox", "Saltbeard", "of Viterbo", "the Deacon's Son", "Half-Ear", "the Smith", "Fishbone"]


# ------------------------------------------------------------------ dice

static func d(sides: int) -> int:
	return randi_range(1, sides)


static func roll(n: int, sides: int) -> int:
	var t := 0
	for i in n:
		t += d(sides)
	return t


static func mod(score: int) -> int:
	if score <= 3: return -3
	if score <= 5: return -2
	if score <= 8: return -1
	if score <= 12: return 0
	if score <= 15: return 1
	if score <= 17: return 2
	return 3


# ------------------------------------------------------------------ characters

static func random_name() -> String:
	return "%s %s" % [FIRST_NAMES[randi() % FIRST_NAMES.size()], EPITHETS[randi() % EPITHETS.size()]]


## Rolls a new character: 3d6 in order, as the old books say.
static func make(cls: String, level: int, kit: Dictionary, char_name: String = "") -> Dictionary:
	var c := {"name": char_name if char_name != "" else random_name(), "cls": cls, "level": level,
		"xp": 0, "weapon": "", "missile": "", "armor": "", "shield": "", "gear": [],
		"status": "ok", "hero": false}
	for a in ABILITIES:
		c[a] = roll(3, 6)
	# Fighters with a feeble arm don't last; reroll strength once like a kind referee.
	if cls == "Fighter" and c["str"] < 9:
		c["str"] = maxi(c["str"], roll(3, 6))
	var xp_table: Array = CLASSES[cls]["xp"]
	c["xp"] = int(xp_table[mini(level - 1, xp_table.size() - 1)]) if level > 0 else 0
	var hp := 0
	for i in maxi(1, level):
		hp += maxi(1, d(int(CLASSES[cls]["hd"])) + mod(c["con"]))
	c["max_hp"] = hp
	c["hp"] = hp
	for slot in ["weapon", "missile", "armor", "shield"]:
		if kit.has(slot):
			c[slot] = kit[slot]
	if kit.has("gear"):
		c["gear"] = kit["gear"].duplicate()
	return c


static func ac(c: Dictionary) -> int:
	var a := 9
	if c.get("armor", "") != "":
		a = int(ITEMS[c["armor"]]["ac"])
	if c.get("shield", "") != "":
		a -= 1
	return a - mod(int(c["dex"]))


static func thac0(c: Dictionary) -> int:
	var lvl := int(c["level"])
	match c["cls"]:
		"Fighter":
			if lvl <= 3: return 19
			if lvl <= 6: return 17
			if lvl <= 9: return 14
			return 12
		"Cleric":
			if lvl <= 4: return 19
			if lvl <= 8: return 17
			return 14
	return 20


static func melee_bonus(c: Dictionary) -> int:
	return mod(int(c["str"]))


static func missile_bonus(c: Dictionary) -> int:
	return mod(int(c["dex"]))


static func weapon_die(c: Dictionary) -> int:
	if c.get("weapon", "") == "":
		return 2  # fists
	return int(ITEMS[c["weapon"]]["dmg"])


static func missile_die(c: Dictionary) -> int:
	if c.get("missile", "") == "":
		return 0
	return int(ITEMS[c["missile"]]["dmg"])


static func saves(c: Dictionary) -> Array:
	var table: Array = SAVES[c["cls"]]
	for band in table:
		if int(c["level"]) <= int(band[0]):
			return band[1]
	return table[table.size() - 1][1]


static func next_xp(c: Dictionary) -> int:
	if c["cls"] == "Normal Man":
		return NORMAL_MAN_PROMOTE
	var t: Array = CLASSES[c["cls"]]["xp"]
	var lvl := int(c["level"])
	return int(t[lvl]) if lvl < t.size() else -1


## Adds XP; returns a message when the character advances.
static func gain_xp(c: Dictionary, amount: int) -> String:
	var prime: String = CLASSES[c["cls"]]["prime"]
	if prime != "":
		var p := int(c[prime])
		if p >= 16: amount = int(amount * 1.1)
		elif p >= 13: amount = int(amount * 1.05)
		elif p <= 5: amount = int(amount * 0.8)
		elif p <= 8: amount = int(amount * 0.9)
	c["xp"] = int(c["xp"]) + amount
	var msg := ""
	if c["cls"] == "Normal Man" and int(c["xp"]) >= NORMAL_MAN_PROMOTE:
		c["cls"] = "Fighter"
		c["level"] = 1
		c["xp"] = 0
		var gain := maxi(1, d(8) + mod(int(c["con"])))
		c["max_hp"] = maxi(int(c["max_hp"]), gain)
		c["hp"] = c["max_hp"]
		return "%s has proven himself: now a Fighter." % c["name"]
	while next_xp(c) > 0 and int(c["xp"]) >= next_xp(c) and int(c["level"]) < 9:
		c["level"] = int(c["level"]) + 1
		var gain := maxi(1, d(int(CLASSES[c["cls"]]["hd"])) + mod(int(c["con"])))
		c["max_hp"] = int(c["max_hp"]) + gain
		c["hp"] = int(c["hp"]) + gain
		msg = "%s reaches level %d (%s)." % [c["name"], int(c["level"]), c["cls"]]
	return msg


static func can_use(c: Dictionary, item: String) -> String:
	## Returns "" if allowed, else the reason.
	var it: Dictionary = ITEMS[item]
	if CLASSES[c["cls"]]["blunt_only"] and it["slot"] in ["weapon", "missile"] and not it.get("blunt", false):
		return "Clerics may not shed blood with edged weapons."
	if it["slot"] == "shield" and c.get("weapon", "") != "" and ITEMS[c["weapon"]].get("two_handed", false):
		return "Needs both hands for the %s." % ITEMS[c["weapon"]]["name"].to_lower()
	return ""


static func carried_cn(c: Dictionary) -> int:
	var t := 0
	for slot in ["weapon", "missile", "armor", "shield"]:
		if c.get(slot, "") != "":
			t += int(ITEMS[c[slot]]["cn"])
	for g in c.get("gear", []):
		t += int(ITEMS[g]["cn"])
	return t


## Average fighting numbers for a group of characters (mass combat).
static func group_stats(members: Array) -> Dictionary:
	var n := 0
	var s := {"ac": 0.0, "thac0": 0.0, "dmg": 0.0, "mdmg": 0.0, "hp": 0.0, "mthac0": 0.0}
	for c in members:
		if c["status"] != "ok":
			continue
		n += 1
		s["ac"] += ac(c)
		s["thac0"] += thac0(c) - melee_bonus(c)
		s["mthac0"] += thac0(c) - missile_bonus(c)
		s["dmg"] += maxf(1.0, (weapon_die(c) + 1) / 2.0 + melee_bonus(c))
		var md := missile_die(c)
		s["mdmg"] += (md + 1) / 2.0 if md > 0 else 0.0
		s["hp"] += maxf(1.0, float(c["max_hp"]))
	if n == 0:
		return {"ac": 9.0, "thac0": 20.0, "mthac0": 20.0, "dmg": 1.0, "mdmg": 0.0, "hp": 1.0}
	for k in s:
		s[k] = s[k] / n
	return s


## Chance a THAC0 hits an AC with a d20.
static func hit_chance(thac0_v: float, ac_v: float) -> float:
	return clampf((21.0 - (thac0_v - ac_v)) / 20.0, 0.05, 0.95)


static func describe(c: Dictionary) -> String:
	return "%s - %s %d - HP %d/%d - AC %d" % [c["name"], c["cls"], int(c["level"]), int(c["hp"]), int(c["max_hp"]), ac(c)]


## Stats for a squad that has no sheets (enemies): an average man with this kit.
static func kit_stats(cls: String, level: int, kit: Dictionary) -> Dictionary:
	var c := {"name": "", "cls": cls, "level": maxi(level, 0), "str": 10, "int": 10, "wis": 10,
		"dex": 10, "con": 10, "cha": 10, "status": "ok", "weapon": "", "missile": "", "armor": "", "shield": ""}
	for slot in kit:
		c[slot] = kit[slot]
	c["max_hp"] = (int(CLASSES[cls]["hd"]) + 1) / 2.0 * maxi(1, level)
	return group_stats([c])
