extends Node3D
class_name MoneyDrop

signal collected(amount: float)

var amount := 25000.0
var _mesh: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _t := 0.0
var picked := false


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.8, 2.2)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.9, 0.35)
	m.emission_enabled = true
	m.emission = Color(0.2, 0.9, 0.35)
	m.emission_energy_multiplier = 1.6
	mi.material_override = m
	mi.position.y = 1.0
	add_child(mi)
	_mesh = mi

	# 돈다발 띠
	var band := MeshInstance3D.new()
	var bbm := BoxMesh.new()
	bbm.size = Vector3(1.7, 0.85, 0.6)
	band.mesh = bbm
	var bm_mat := StandardMaterial3D.new()
	bm_mat.albedo_color = Color(1.0, 0.85, 0.2)
	band.material_override = bm_mat
	band.position.y = 1.0
	add_child(band)

	# 빛나는 링
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.8
	tm.outer_radius = 2.1
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.9, 0.3, 0.6)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.85, 0.2)
	rm.emission_energy_multiplier = 2.0
	ring.material_override = rm
	_ring_mat = rm
	ring.position.y = 0.2
	add_child(ring)
	_ring = ring


func _process(delta: float) -> void:
	if picked:
		return
	_t += delta
	_mesh.rotation.y += delta * 2.5
	_mesh.position.y = 1.0 + sin(_t * 4.0) * 0.3
	_ring.scale = Vector3.ONE * (1.0 + sin(_t * 5.0) * 0.15)


func check_pickup(car_pos: Vector3) -> bool:
	if picked:
		return false
	var flat_car := Vector2(car_pos.x, car_pos.z)
	var flat_me := Vector2(global_position.x, global_position.z)
	if flat_car.distance_to(flat_me) < 5.0:
		picked = true
		collected.emit(amount)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_mesh, "position:y", 4.0, 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(_mesh, "scale", Vector3.ZERO, 0.35)
		tw.tween_property(_ring, "scale", Vector3.ONE * 2.5, 0.35)
		tw.tween_property(_ring_mat, "albedo_color:a", 0.0, 0.35)
		tw.tween_property(_ring_mat, "emission_energy_multiplier", 0.0, 0.35)
		await tw.finished
		queue_free()
		return true
	return false
