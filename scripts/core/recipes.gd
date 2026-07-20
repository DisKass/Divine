class_name Recipes
extends RefCounted

## Decoupled database of all building recipes.
## Structure:
## {
##   "building_type": [
##     {
##       "id": "recipe_id",
##       "name": "Display Name",
##       "inputs": { "resource_name": amount },
##       "outputs": { "resource_name": amount },
##       "duration": float (in ticks/seconds)
##     },
##     ...
##   ]
## }
const DATA: Dictionary = {
	"portal": [
		{
			"id": "portal_receive",
			"name": "Deliver Milestones",
			"inputs": {},
			"outputs": {},
			"duration": 1.0
		}
	],
	"miner": [

		{
			"id": "iron_ore",
			"name": "Mine Iron Ore",
			"inputs": {},
			"outputs": { "iron_ore": 1.0 },
			"duration": 1.0
		}
	],
	"miner_iron": [
		{
			"id": "iron_ore",
			"name": "Mine Iron Ore",
			"inputs": {},
			"outputs": { "iron_ore": 1.0 },
			"duration": 1.0
		}
	],
	"miner_coal": [
		{
			"id": "coal",
			"name": "Mine Coal",
			"inputs": {},
			"outputs": { "coal": 1.0 },
			"duration": 1.0
		}
	],
	"miner_crystal": [
		{
			"id": "mana_crystal",
			"name": "Mine Mana Crystal",
			"inputs": {},
			"outputs": { "mana_crystal": 1.0 },
			"duration": 1.0
		}
	],
	"crusher": [
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
			"inputs": { "crushed_iron": 1.0, "coal": 1.0 },
			"outputs": { "iron_ingot": 1.0 },
			"duration": 1.0
		}
	],
	"constructor": [
		{
			"id": "iron_gear",
			"name": "Construct Iron Gear",
			"inputs": { "iron_plate": 1.0 },
			"outputs": { "iron_gear": 1.0 },
			"duration": 1.0
		}
	],
	"alchemy_lab": [
		{
			"id": "mana_essence",
			"name": "Craft Mana Essence",
			"inputs": { "crystal_dust": 2.0 },
			"outputs": { "mana_essence": 1.0 },
			"duration": 2.0
		},
		{
			"id": "runesteel_ingot",
			"name": "Craft Runesteel Ingot",
			"inputs": { "iron_ingot": 1.0, "mana_essence": 1.0 },
			"outputs": { "runesteel_ingot": 1.0 },
			"duration": 3.0
		}
	],
	"artifact_altar": [
		{
			"id": "runesteel_amulet",
			"name": "Craft Runesteel Amulet",
			"inputs": { "runesteel_ingot": 2.0, "mana_essence": 1.0 },
			"outputs": { "runesteel_amulet": 1.0 },
			"duration": 5.0
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
	]
}
