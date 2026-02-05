# Collision- und Door-Matching-Hilfen

class_name MGCollision

func _scene_is_corridor(gen, scene: PackedScene) -> bool:
    if scene == null:
        return false
    var key := scene.resource_path
    if gen._corridor_cache.has(key):
        return bool(gen._corridor_cache[key])
    var inst := scene.instantiate()
    var is_corr := false
    if inst != null:
        is_corr = ("is_corridor" in inst) and bool(inst.get("is_corridor"))
        inst.queue_free()
    gen._corridor_cache[key] = is_corr
    return is_corr


func is_corridor_room(gen, room: Node) -> bool:
    if room == null:
        return false
    if not ("is_corridor" in room):
        return false
    var value = room.get("is_corridor")
    return typeof(value) == TYPE_BOOL and value


func _get_room_rects(room: Node2D) -> Array:
    var rects: Array = []
    var area := room.get_node_or_null("Area2D") as Area2D
    if area == null:
        return rects
    for child in area.get_children():
        if child is CollisionShape2D:
            var cs := child as CollisionShape2D
            var shape := cs.shape as RectangleShape2D
            if shape == null:
                continue
            var center := cs.global_position
            rects.append(Rect2(center - shape.extents, shape.extents * 2.0))
    return rects


class OverlapResult:
    var overlaps: bool = false
    var other_name: String = ""


func check_overlap_aabb(new_room: Node2D, against: Array) -> OverlapResult:
    var result := OverlapResult.new()
    var new_rects := _get_room_rects(new_room)
    if new_rects.is_empty():
        result.overlaps = true
        result.other_name = "missing_collision"
        return result
    for room in against:
        if room == null or room == new_room:
            continue
        var rects := _get_room_rects(room)
        if rects.is_empty():
            continue
        for a in new_rects:
            for b in rects:
                if a.intersects(b):
                    result.overlaps = true
                    result.other_name = room.name
                    return result
    return result


func find_matching_door(gen, room: Node, from_direction: String):
    var opposite := {"north": "south", "south": "north", "east": "west", "west": "east"}
    if not opposite.has(from_direction):
        return null
    for d in room.get_free_doors():
        if d.direction == opposite[from_direction]:
            return d
    return null


func _find_any_door_node(root: Node) -> Node:
    if root == null:
        return null
    if root.has_node("Doors"):
        var doors := root.get_node("Doors")
        for d in doors.get_children():
            if d != null and ("direction" in d):
                return d
    return null
