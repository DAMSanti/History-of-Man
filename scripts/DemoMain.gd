extends Node3D
## Demo principal que integra todos los sistemas:
## TerrainGenerator, Chunk, MultiMeshVegetation, Architecto, TimeManager y WorldEnvironment

@export_group("Demo Settings")
@export var terrain_size: Vector2i = Vector2i(128, 128)
@export var terrain_resolution: int = 129
@export var max_height: float = 30.0
@export var seed_value: int = 12345

@export_group("Debug")
@export var show_debug_ui: bool = true
@export var spawn_test_buildings: bool = true

## Referencias a nodos
var terrain: TerrainGenerator
var chunk: Chunk
var vegetation: MultiMeshVegetation
var architecto: Architecto
var camera: Camera3D
var debug_label: Label

## Materiales cargados
var materials: Dictionary = {}

## Edificio de prueba
var test_building_mesh: BoxMesh

## Estado del demo
var _selected_weight: float = 500.0


func _ready() -> void:
	print("=== Iniciando Demo ===")
	_load_materials()
	_setup_terrain()
	_setup_chunk()
	_setup_vegetation()
	_setup_architecto()
	_setup_camera()
	_setup_ui()
	_connect_signals()
	
	# Generar mundo
	print("Generando terreno...")
	terrain.generate()
	print("Terreno generado. Mesh: ", terrain._terrain_mesh)
	
	# Poblar recursos
	_populate_resources()
	
	# Spawn edificios de prueba
	if spawn_test_buildings:
		_spawn_test_buildings()
	
	print("=== Demo inicializado correctamente ===")


func _load_materials() -> void:
	# Cargar todos los materiales
	var material_files := [
		"res://materials/Iron.tres",
		"res://materials/Stone.tres",
		"res://materials/Straw.tres",
		"res://materials/Coal.tres",
		"res://materials/Wood.tres",
		"res://materials/Copper.tres",
		"res://materials/Clay.tres"
	]
	
	for path in material_files:
		if ResourceLoader.exists(path):
			var mat := load(path) as RawMaterial
			if mat:
				var key := mat.display_name.to_lower()
				materials[key] = mat
				print("Material cargado: ", mat.display_name)


func _setup_terrain() -> void:
	terrain = TerrainGenerator.new()
	terrain.name = "TerrainGenerator"
	terrain.terrain_size = terrain_size
	terrain.resolution = terrain_resolution
	terrain.max_height = max_height
	terrain.seed_value = seed_value
	add_child(terrain)


func _setup_chunk() -> void:
	chunk = Chunk.new()
	chunk.name = "MainChunk"
	chunk.chunk_size = terrain_size
	chunk.cell_size = 1.0
	add_child(chunk)


func _setup_vegetation() -> void:
	vegetation = MultiMeshVegetation.new()
	vegetation.name = "Vegetation"
	
	# Crear mesh simple de árbol (cono + cilindro)
	var tree_mesh := _create_simple_tree_mesh()
	vegetation.vegetation_mesh = tree_mesh
	vegetation.max_instances = 3000
	vegetation.min_spacing = 4.0
	vegetation.base_scale = Vector3(1, 1, 1)
	vegetation.scale_variation = 0.4
	vegetation.min_humidity = 0.35
	vegetation.max_slope = 0.5
	
	add_child(vegetation)


func _create_simple_tree_mesh() -> ArrayMesh:
	# Crear un árbol simple con primitivas
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Tronco (cilindro simple - cubo estirado por ahora)
	var trunk_height := 2.0
	var trunk_radius := 0.15
	
	# Color del tronco
	st.set_color(Color(0.4, 0.25, 0.1))
	
	# Simplificado: usar un cubo para el tronco
	_add_box(st, Vector3(0, trunk_height / 2, 0), Vector3(trunk_radius * 2, trunk_height, trunk_radius * 2))
	
	# Copa del árbol (pirámide/cono simplificado como caja)
	st.set_color(Color(0.2, 0.5, 0.2))
	_add_cone(st, Vector3(0, trunk_height + 1.5, 0), 1.5, 3.0, 8)
	
	st.generate_normals()
	return st.commit()


func _add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var half := size / 2.0
	
	# Frente
	st.add_vertex(center + Vector3(-half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(half.x, half.y, half.z))
	st.add_vertex(center + Vector3(-half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(half.x, half.y, half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, half.z))
	
	# Atrás
	st.add_vertex(center + Vector3(half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(-half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, half.y, -half.z))
	
	# Arriba
	st.add_vertex(center + Vector3(-half.x, half.y, half.z))
	st.add_vertex(center + Vector3(half.x, half.y, half.z))
	st.add_vertex(center + Vector3(half.x, half.y, -half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, half.z))
	st.add_vertex(center + Vector3(half.x, half.y, -half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, -half.z))
	
	# Abajo
	st.add_vertex(center + Vector3(-half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(-half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(-half.x, -half.y, half.z))
	
	# Izquierda
	st.add_vertex(center + Vector3(-half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(-half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, half.z))
	st.add_vertex(center + Vector3(-half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, half.z))
	st.add_vertex(center + Vector3(-half.x, half.y, -half.z))
	
	# Derecha
	st.add_vertex(center + Vector3(half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(half.x, -half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, -half.y, half.z))
	st.add_vertex(center + Vector3(half.x, half.y, -half.z))
	st.add_vertex(center + Vector3(half.x, half.y, half.z))


func _add_cone(st: SurfaceTool, tip: Vector3, base_radius: float, height: float, segments: int) -> void:
	var base_center := tip - Vector3(0, height, 0)
	
	for i in range(segments):
		var angle1 := float(i) / float(segments) * TAU
		var angle2 := float(i + 1) / float(segments) * TAU
		
		var p1 := base_center + Vector3(cos(angle1) * base_radius, 0, sin(angle1) * base_radius)
		var p2 := base_center + Vector3(cos(angle2) * base_radius, 0, sin(angle2) * base_radius)
		
		# Lado del cono
		st.add_vertex(tip)
		st.add_vertex(p1)
		st.add_vertex(p2)
		
		# Base del cono
		st.add_vertex(base_center)
		st.add_vertex(p2)
		st.add_vertex(p1)


func _setup_architecto() -> void:
	architecto = Architecto.new()
	architecto.name = "Architecto"
	add_child(architecto)
	architecto.initialize(chunk, terrain)
	
	# Crear mesh de prueba para edificios
	test_building_mesh = BoxMesh.new()
	test_building_mesh.size = Vector3(2, 3, 2)


func _setup_camera() -> void:
	# Cargar la escena de cámara preconfigurada
	var camera_scene := load("res://scenes/OrbitalCamera.tscn")
	if camera_scene:
		camera = camera_scene.instantiate() as Camera3D
		camera.name = "MainCamera"
		add_child(camera)
		
		# Configurar posición inicial del target
		camera.target_position = Vector3(float(terrain_size.x) / 2.0, 0, float(terrain_size.y) / 2.0)
		camera.orbit_distance = 80.0
		camera.current = true
		print("Cámara configurada en: ", camera.target_position)
	else:
		push_error("No se pudo cargar la escena de cámara")


func _setup_ui() -> void:
	if not show_debug_ui:
		return
	
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)
	
	# Panel de debug
	var panel := PanelContainer.new()
	panel.name = "DebugPanel"
	panel.position = Vector2(10, 10)
	canvas.add_child(panel)
	
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	
	# Label de información
	debug_label = Label.new()
	debug_label.name = "DebugLabel"
	debug_label.text = "CityBuilder Demo\n"
	vbox.add_child(debug_label)
	
	# Instrucciones
	var instructions := Label.new()
	instructions.text = """
Controles:
WASD - Mover cámara
Click derecho + arrastrar - Rotar cámara
Scroll - Zoom
Click izquierdo - Colocar edificio
P - Pausar/Reanudar tiempo
+/- - Velocidad del tiempo
"""
	vbox.add_child(instructions)


func _connect_signals() -> void:
	# Conectar señales del TerrainGenerator
	terrain.generation_complete.connect(_on_terrain_generated)
	
	# Conectar señales del Architecto
	architecto.building_placed.connect(_on_building_placed)
	architecto.building_collapsed.connect(_on_building_collapsed)
	architecto.placement_denied.connect(_on_placement_denied)
	
	# Conectar al TimeManager
	if has_node("/root/TimeManager"):
		var tm = get_node("/root/TimeManager")
		tm.tick_advance.connect(_on_time_tick)
		tm.season_changed.connect(_on_season_changed)


func _on_terrain_generated() -> void:
	print("Terreno generado")
	
	# Inicializar vegetación después de generar terreno
	vegetation.initialize(terrain)


func _populate_resources() -> void:
	print("Poblando recursos...")
	
	var materials_map := {
		"iron": materials.get("iron"),
		"coal": materials.get("coal"),
		"stone": materials.get("stone")
	}
	
	terrain.populate_chunk_resources(chunk, materials_map, 0.65)
	
	var cells := chunk.get_all_resource_cells()
	print("Recursos colocados en ", cells.size(), " celdas")


func _spawn_test_buildings() -> void:
	# Colocar algunos edificios de prueba
	var test_positions := [
		Vector3(40, 0, 40),
		Vector3(50, 0, 50),
		Vector3(60, 0, 45),
		Vector3(70, 0, 60),
	]
	
	for pos in test_positions:
		_place_building_at(pos, 300.0)


func _place_building_at(world_pos: Vector3, weight: float) -> void:
	var building := MeshInstance3D.new()
	building.mesh = test_building_mesh
	
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.6, 0.4)
	building.material_override = material
	
	if architecto.place_building_node(world_pos, building, weight):
		add_child(building)


func _on_building_placed(world_pos: Vector3, _building: Node3D) -> void:
	print("Edificio colocado en: ", world_pos)


func _on_building_collapsed(world_pos: Vector3, _building: Node3D) -> void:
	print("¡Edificio colapsado en: ", world_pos, "!")


func _on_placement_denied(world_pos: Vector3, reason: String) -> void:
	print("No se puede colocar edificio en ", world_pos, ": ", reason)


func _on_time_tick(_tick: int, _day: int, _season: int, _year: int) -> void:
	if debug_label and show_debug_ui:
		var tm = get_node("/root/TimeManager")
		debug_label.text = "CityBuilder Demo\n"
		debug_label.text += "Fecha: " + tm.format_full() + "\n"
		debug_label.text += "Velocidad: x" + str(tm.time_speed) + "\n"
		debug_label.text += "Pausado: " + str(tm.is_paused) + "\n"
		debug_label.text += "Edificios: " + str(architecto.get_all_buildings().size()) + "\n"
		debug_label.text += "Vegetación: " + str(vegetation.get_instance_count()) + "\n"


func _on_season_changed(_season: int, season_name: String) -> void:
	print("Nueva estación: ", season_name)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:
				if has_node("/root/TimeManager"):
					get_node("/root/TimeManager").toggle_pause()
			KEY_EQUAL, KEY_KP_ADD:
				if has_node("/root/TimeManager"):
					var tm = get_node("/root/TimeManager")
					tm.set_speed(minf(tm.time_speed + 0.5, 10.0))
			KEY_MINUS, KEY_KP_SUBTRACT:
				if has_node("/root/TimeManager"):
					var tm = get_node("/root/TimeManager")
					tm.set_speed(maxf(tm.time_speed - 0.5, 0.0))
	
	# Click para colocar edificios
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_place_building_at_mouse()


func _try_place_building_at_mouse() -> void:
	if not camera:
		return
	
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		_place_building_at(hit_pos, _selected_weight)
