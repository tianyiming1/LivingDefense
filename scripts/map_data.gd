# CO-022：单图 PATH / 展示键数据（独立 Resource，不进波次公式）
extends Resource
class_name MapData

@export var id: String = "map_a"
@export var display_name_key: String = "map_a"
@export var path_points: PackedVector2Array = PackedVector2Array()

func to_path_array() -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(path_points)
	return out
