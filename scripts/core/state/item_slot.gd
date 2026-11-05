class_name ItemSlot
extends RefCounted

var accepted_tags: Array[String] = []
var current_item: String = ""
var amount: float = 0.0
var capacity: float = 20.0
var payload: Dictionary = {}

func _init(tags: Array[String] = [], initial_capacity: float = 20.0):
	accepted_tags = tags
	capacity = initial_capacity

func is_empty() -> bool:
	return amount <= 0.0

func is_full() -> bool:
	if current_item != "" and ItemTagSystem.has_tag(current_item, "<artifact>"):
		return amount >= 1.0
	for tag in accepted_tags:
		if tag == "<artifact>" or ItemTagSystem.has_tag(tag, "<artifact>"):
			return amount >= 1.0
	return amount >= capacity

func get_available_space() -> float:
	var max_cap = capacity
	if current_item != "" and ItemTagSystem.has_tag(current_item, "<artifact>"):
		max_cap = 1.0
	else:
		for tag in accepted_tags:
			if tag == "<artifact>" or ItemTagSystem.has_tag(tag, "<artifact>"):
				max_cap = 1.0
				break
	return maxf(0.0, max_cap - amount)

## Returns true if this slot contains a non-zero item that matches the required resource_name or tag.
func matches_resource(resource_name_or_tag: String) -> bool:
	if is_empty():
		return false
	return ItemTagSystem.has_tag(current_item, resource_name_or_tag)

func can_accept(item: String) -> bool:
	if ItemTagSystem.has_tag(item, "<artifact>") and amount >= 1.0:
		return false

	if is_full():
		return false
	
	if current_item != "" and current_item != item:
		return false
		
	# Special case: If accepted_tags is empty, it acts as a generic slot (e.g. for outputs)
	if accepted_tags.is_empty():
		return true
		
	for tag in accepted_tags:
		if ItemTagSystem.has_tag(item, tag):
			return true
			
	return false

func push(item: String, push_amount: float, new_payload: Dictionary = {}) -> float:
	if not can_accept(item):
		return 0.0
		
	var max_cap = capacity
	if ItemTagSystem.has_tag(item, "<artifact>"):
		max_cap = 1.0
	else:
		for tag in accepted_tags:
			if tag == "<artifact>" or ItemTagSystem.has_tag(tag, "<artifact>"):
				max_cap = 1.0
				break
				
	var space = maxf(0.0, max_cap - amount)
	var actual_amount = minf(space, push_amount)
	
	if actual_amount > 0:
		current_item = item
		amount += actual_amount
		if not new_payload.is_empty():
			payload = new_payload.duplicate(true)
		
	return actual_amount

func pull(pull_amount: float) -> Dictionary:
	if amount <= 0.0:
		return {"amount": 0.0, "payload": {}}
		
	var actual_amount = minf(amount, pull_amount)
	amount -= actual_amount
	var pulled_payload = payload.duplicate(true)
	
	if amount <= 0.0:
		amount = 0.0
		current_item = ""
		payload = {}
		
	return {"amount": actual_amount, "payload": pulled_payload}

func clear() -> void:
	amount = 0.0
	current_item = ""
	payload = {}
	
func to_dict() -> Dictionary:
	return {
		"accepted_tags": accepted_tags,
		"current_item": current_item,
		"amount": amount,
		"capacity": capacity,
		"payload": payload.duplicate(true)
	}
	
func load_from_dict(data: Dictionary) -> void:
	var tags_array = data.get("accepted_tags", [])
	accepted_tags.clear()
	for t in tags_array:
		accepted_tags.append(str(t))
		
	current_item = data.get("current_item", "")
	amount = float(data.get("amount", 0.0))
	capacity = float(data.get("capacity", 20.0))
	payload = data.get("payload", {}).duplicate(true)
	
	for t in accepted_tags:
		if t == "<artifact>" or ItemTagSystem.has_tag(t, "<artifact>"):
			capacity = 1.0
			break
	if current_item != "" and ItemTagSystem.has_tag(current_item, "<artifact>"):
		capacity = 1.0
	if capacity <= 1.0 and amount > 1.0:
		amount = 1.0
