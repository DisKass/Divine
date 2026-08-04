class_name ItemTagSystem
extends RefCounted

static var tags_db: TagDatabase = null
static var configs_loaded: bool = false
static var tag_map: Dictionary = {}

static func ensure_configs_loaded() -> void:
	if configs_loaded:
		return
	
	if ResourceLoader.exists("res://data/tags.tres"):
		tags_db = ResourceLoader.load("res://data/tags.tres")
		if tags_db:
			for category in tags_db.categories:
				if category != null:
					tag_map[category.tag_name] = category.items
	configs_loaded = true

static func has_tag(resource_name: String, tag: String) -> bool:
	if resource_name == tag:
		return true
	if tag == "<all>":
		return true
	if tag == "<artifact>":
		ArtifactSystem.ensure_configs_loaded()
		return ArtifactSystem.artifact_configs.has(resource_name)
	
	ensure_configs_loaded()
	if tag_map.has(tag):
		return resource_name in tag_map[tag]
		
	return false
