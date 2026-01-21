extends RefCounted
class_name LootGenerator

static func generate_loot(min_total := 10, max_total := 15) -> Dictionary:
	var data := JsonData.item_data if JsonData and "item_data" in JsonData else {}
	if data.is_empty():
		return {}

	# Pool: nur Items mit weight
	var pool: Array[Dictionary] = []
	var sum := 0.0
	for name in data.keys():
		var info: Dictionary = data[name]
		if not info.has("weight"):
			continue
		var w := float(info.weight)
		if w <= 0.0:
			continue
		pool.append({"name": name, "w": w})
		sum += w

	if pool.is_empty():
		return {}

	var target := randi_range(min_total, max_total)
	var used := 0
	var loot := {}

	while used < target:
		var r := randf() * sum
		var acc := 0.0
		var picked := ""

		for e in pool:
			acc += e.w
			if r <= acc:
				picked = e.name
				break

		if picked == "":
			break

		loot[picked] = int(loot.get(picked, 0)) + 1
		used += int(data[picked].weight)

	return loot
