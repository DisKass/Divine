class_name Recipes
extends RefCounted

## Decoupled database of all building recipes.
## Categories:
## 1. miner: 0 in, 1 out
## 2. smelter: 1 solid in, 1 out
## 3. converter: 1 solid in, 1 out
## 4. assembler: 2 solid in, 1 out
## 5. extractor: 1 solid in, 1 liquid/aetherial out
## 6. infuser: 2 in (1 solid + 1 liquid/aetherial), 1 out
## 7. portal & seller & vault_gateway: unique buildings (variable in, 0 out)
## 8. splitter_2 & splitter_3: logic buildings (1 in, 2 or 3 outputs)
## 9. shell_forge: crafts artifact bases

const DATA: Dictionary = {
	"miner": [
		{
			"id": "iron_ore",
			"name": "Mine Iron Ore",
			"inputs": {},
			"outputs": { "iron_ore": 1.0 },
			"duration": 1.0
		},
		{
			"id": "coal",
			"name": "Mine Coal",
			"inputs": {},
			"outputs": { "coal": 1.0 },
			"duration": 1.0
		},
		{
			"id": "mana_crystal",
			"name": "Mine Mana Crystal",
			"inputs": {},
			"outputs": { "mana_crystal": 1.0 },
			"duration": 1.0
		}
	],

	"smelter": [
		{
			"id": "smelt_plate",
			"name": "Smelt Iron Plate",
			"inputs": { "iron_ore": 1.0 },
			"outputs": { "iron_plate": 1.0 },
			"duration": 1.0
		},
		{
			"id": "smelt_ingot",
			"name": "Smelt Iron Ingot",
			"inputs": { "crushed_iron": 1.0 },
			"outputs": { "iron_ingot": 1.0 },
			"duration": 1.0
		}
	],

	"converter": [
		{
			"id": "iron_gear",
			"name": "Convert Iron Gear",
			"inputs": { "iron_plate": 1.0 },
			"outputs": { "iron_gear": 1.0 },
			"duration": 1.0
		},
		{
			"id": "crush_iron",
			"name": "Crush Iron Ore",
			"inputs": { "iron_ore": 1.0 },
			"outputs": { "crushed_iron": 1.0 },
			"duration": 1.0
		},
		{
			"id": "crush_crystal",
			"name": "Crush Mana Crystal",
			"inputs": { "mana_crystal": 1.0 },
			"outputs": { "crystal_dust": 1.0 },
			"duration": 1.0
		}
	],

	"assembler": [
		{
			"id": "steel_ingot",
			"name": "Assemble Steel Ingot",
			"inputs": { "iron_ingot": 1.0, "coal": 1.0 },
			"outputs": { "steel_ingot": 1.0 },
			"duration": 1.5
		}
	],

	"extractor": [
		{
			"id": "mana_essence",
			"name": "Extract Mana Essence",
			"inputs": { "crystal_dust": 2.0 },
			"outputs": { "mana_essence": 1.0 },
			"duration": 2.0
		}
	],

	"infuser": [
		{
			"id": "runesteel_ingot",
			"name": "Infuse Runesteel Ingot",
			"inputs": { "iron_ingot": 1.0, "mana_essence": 1.0 },
			"outputs": { "runesteel_ingot": 1.0 },
			"duration": 3.0
		},
		{
			"id": "runesteel_amulet",
			"name": "Infuse Runesteel Amulet",
			"inputs": { "runesteel_ingot": 2.0, "mana_essence": 1.0 },
			"outputs": { "runesteel_amulet": 1.0 },
			"duration": 5.0
		}
	],

	"portal": [
		{
			"id": "portal_receive",
			"name": "Deliver Milestones",
			"inputs": {},
			"outputs": {},
			"duration": 1.0
		}
	],

	"seller": [
		{
			"id": "sell_gear",
			"name": "Sell Iron Gear",
			"inputs": { "iron_gear": 1.0 },
			"outputs": { "credits": 5.0 },
			"duration": 1.0
		},
		{
			"id": "sell_runesteel",
			"name": "Sell Runesteel Ingot",
			"inputs": { "runesteel_ingot": 1.0 },
			"outputs": { "credits": 50.0 },
			"duration": 2.0
		}
	],

	"shell_forge": [
		{
			"id": "runesteel_amulet",
			"name": "Forge Runesteel Amulet",
			"inputs": { "runesteel_ingot": 2.0, "mana_essence": 1.0 },
			"outputs": { "runesteel_amulet": 1.0 },
			"duration": 5.0
		}
	],

	"vault_gateway": [
		{
			"id": "vault_deposit",
			"name": "Deposit to Vault",
			"inputs": { "<artifact>": 1.0 },
			"outputs": { "<artifact>": 1.0 },
			"duration": 1.0
		}
	],

	"the_void": [
		{
			"id": "void_destroy",
			"name": "Destroy Items",
			"inputs": { "<all>": 1.0 },
			"outputs": {},
			"duration": 1.0
		}
	],

	"splitter_2": [
		{
			"id": "split_2",
			"name": "Split 2 Streams",
			"inputs": {},
			"outputs": {},
			"duration": 0.0
		}
	],

	"splitter_3": [
		{
			"id": "split_3",
			"name": "Split 3 Streams",
			"inputs": {},
			"outputs": {},
			"duration": 0.0
		}
	],

	# Backwards compatibility fallbacks for older saves
	"miner_iron": [
		{ "id": "iron_ore", "name": "Mine Iron Ore", "inputs": {}, "outputs": { "iron_ore": 1.0 }, "duration": 1.0 }
	],
	"miner_coal": [
		{ "id": "coal", "name": "Mine Coal", "inputs": {}, "outputs": { "coal": 1.0 }, "duration": 1.0 }
	],
	"miner_crystal": [
		{ "id": "mana_crystal", "name": "Mine Mana Crystal", "inputs": {}, "outputs": { "mana_crystal": 1.0 }, "duration": 1.0 }
	],
	"crusher": [
		{ "id": "crush_iron", "name": "Crush Iron Ore", "inputs": { "iron_ore": 1.0 }, "outputs": { "crushed_iron": 1.0 }, "duration": 1.0 },
		{ "id": "crush_crystal", "name": "Crush Mana Crystal", "inputs": { "mana_crystal": 1.0 }, "outputs": { "crystal_dust": 1.0 }, "duration": 1.0 }
	],
	"constructor": [
		{ "id": "iron_gear", "name": "Construct Iron Gear", "inputs": { "iron_plate": 1.0 }, "outputs": { "iron_gear": 1.0 }, "duration": 1.0 }
	],
	"alchemy_lab": [
		{ "id": "mana_essence", "name": "Craft Mana Essence", "inputs": { "crystal_dust": 2.0 }, "outputs": { "mana_essence": 1.0 }, "duration": 2.0 },
		{ "id": "runesteel_ingot", "name": "Craft Runesteel Ingot", "inputs": { "iron_ingot": 1.0, "mana_essence": 1.0 }, "outputs": { "runesteel_ingot": 1.0 }, "duration": 3.0 }
	]
}
