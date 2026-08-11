extends Node3D
## WorldEnvironmentSetup - Configura el entorno gráfico del mundo.
## Activa SDFGI, Volumetric Fog, ACES Tone Mapping y otros efectos.

@export_group("Environment Settings")
## Activar SDFGI (iluminación global)
@export var enable_sdfgi: bool = true

## Activar niebla volumétrica
@export var enable_volumetric_fog: bool = true

## Activar SSR (reflejos)
@export var enable_ssr: bool = false

## Activar SSAO (oclusión ambiental)
@export var enable_ssao: bool = true

@export_group("Sky Settings")
## Color superior del cielo
@export var sky_top_color: Color = Color(0.3, 0.5, 0.85)

## Color del horizonte
@export var sky_horizon_color: Color = Color(0.65, 0.75, 0.9)

## Color inferior del cielo (reflejo del suelo)
@export var sky_bottom_color: Color = Color(0.25, 0.2, 0.15)

## Energía del sol
@export var sun_energy: float = 1.2

@export_group("Fog Settings")
## Densidad de la niebla
@export var fog_density: float = 0.002

## Color de la niebla
@export var fog_color: Color = Color(0.75, 0.82, 0.92, 1.0)

## Altura de la niebla
@export var fog_height: float = 5.0

## Densidad de la niebla según altura
@export var fog_height_density: float = 0.05

## Nodos del entorno
var _world_environment: WorldEnvironment
var _directional_light: DirectionalLight3D
var _environment: Environment
var _sky: Sky
var _sky_material: ProceduralSkyMaterial


func _ready() -> void:
	_setup_environment()
	_setup_sky()
	_setup_lighting()
	_connect_time_manager()


func _setup_environment() -> void:
	# Crear WorldEnvironment si no existe
	_world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not _world_environment:
		_world_environment = WorldEnvironment.new()
		_world_environment.name = "WorldEnvironment"
		add_child(_world_environment)
	
	# Crear Environment
	_environment = Environment.new()
	
	# Background - Sky
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	
	# Tone Mapping - ACES para colores más cinematográficos
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_exposure = 1.0
	_environment.tonemap_white = 6.0
	
	# SDFGI - Iluminación global en tiempo real
	_environment.sdfgi_enabled = enable_sdfgi
	_environment.sdfgi_use_occlusion = true
	_environment.sdfgi_bounce_feedback = 0.5
	_environment.sdfgi_cascades = 4
	_environment.sdfgi_min_cell_size = 0.2
	_environment.sdfgi_energy = 1.0
	
	# SSAO
	_environment.ssao_enabled = enable_ssao
	_environment.ssao_radius = 1.0
	_environment.ssao_intensity = 2.0
	
	# SSR
	_environment.ssr_enabled = enable_ssr
	
	# SSIL (iluminación indirecta)
	_environment.ssil_enabled = true
	_environment.ssil_radius = 5.0
	_environment.ssil_intensity = 1.0
	
	# Volumetric Fog
	_environment.volumetric_fog_enabled = enable_volumetric_fog
	_environment.volumetric_fog_density = fog_density
	_environment.volumetric_fog_albedo = fog_color
	_environment.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	_environment.volumetric_fog_emission_energy = 0.0
	_environment.volumetric_fog_length = 64.0
	_environment.volumetric_fog_detail_spread = 2.0
	_environment.volumetric_fog_ambient_inject = 0.0
	
	# Glow
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.5
	_environment.glow_bloom = 0.1
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Adjustments
	_environment.adjustment_enabled = true
	_environment.adjustment_brightness = 1.0
	_environment.adjustment_contrast = 1.05
	_environment.adjustment_saturation = 1.1
	
	_world_environment.environment = _environment


func _setup_sky() -> void:
	# Crear cielo procedural
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = sky_top_color
	_sky_material.sky_horizon_color = sky_horizon_color
	_sky_material.ground_bottom_color = sky_bottom_color
	_sky_material.ground_horizon_color = sky_horizon_color
	_sky_material.sun_angle_max = 30.0
	_sky_material.sun_curve = 0.15
	
	_sky = Sky.new()
	_sky.sky_material = _sky_material
	_sky.radiance_size = Sky.RADIANCE_SIZE_256
	
	_environment.sky = _sky


func _setup_lighting() -> void:
	# Crear luz direccional (sol) si no existe
	_directional_light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if not _directional_light:
		_directional_light = DirectionalLight3D.new()
		_directional_light.name = "Sun"
		add_child(_directional_light)
	
	# Configurar sol - ángulo para luz más cálida de atardecer/mañana
	_directional_light.rotation_degrees = Vector3(-35, -45, 0)
	_directional_light.light_color = Color(1.0, 0.96, 0.88)  # Ligeramente cálido
	_directional_light.light_energy = sun_energy
	_directional_light.light_indirect_energy = 1.2
	_directional_light.light_volumetric_fog_energy = 1.5
	_directional_light.light_angular_distance = 0.5  # Sol más suave
	
	# Sombras de alta calidad
	_directional_light.shadow_enabled = true
	_directional_light.shadow_blur = 1.5
	_directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_directional_light.directional_shadow_max_distance = 200.0
	_directional_light.directional_shadow_split_1 = 0.05
	_directional_light.directional_shadow_split_2 = 0.15
	_directional_light.directional_shadow_split_3 = 0.35


func _connect_time_manager() -> void:
	# Conectar al TimeManager para cambios de luz según hora
	if Engine.has_singleton("TimeManager") or has_node("/root/TimeManager"):
		var tm = get_node_or_null("/root/TimeManager")
		if tm:
			if tm.has_signal("tick_advance"):
				tm.tick_advance.connect(_on_time_tick)
			if tm.has_signal("season_changed"):
				tm.season_changed.connect(_on_season_changed)


func _on_time_tick(_tick: int, _day: int, _season: int, _year: int) -> void:
	if not _directional_light:
		return
	
	var tm = get_node_or_null("/root/TimeManager")
	if not tm:
		return
	
	var hour: float = tm.get_hour_of_day()
	var sunlight: float = tm.get_sunlight_factor()
	
	# Rotar el sol según la hora del día
	# Amanecer al Este (90°), Mediodía al Sur (0°), Atardecer al Oeste (-90°)
	var sun_angle := lerpf(-90, 90, hour / 24.0)
	_directional_light.rotation_degrees.x = -30 - sin(hour / 24.0 * PI) * 60
	_directional_light.rotation_degrees.y = sun_angle - 90
	
	# Ajustar energía del sol
	_directional_light.light_energy = sun_energy * sunlight
	
	# Cambiar color del cielo según hora
	if _sky_material:
		var dawn_color := Color(0.8, 0.5, 0.3)
		var day_color := sky_top_color
		var dusk_color := Color(0.7, 0.4, 0.3)
		var night_color := Color(0.05, 0.05, 0.15)
		
		if hour < 6.0:
			_sky_material.sky_top_color = night_color.lerp(dawn_color, hour / 6.0)
		elif hour < 8.0:
			_sky_material.sky_top_color = dawn_color.lerp(day_color, (hour - 6.0) / 2.0)
		elif hour < 17.0:
			_sky_material.sky_top_color = day_color
		elif hour < 19.0:
			_sky_material.sky_top_color = day_color.lerp(dusk_color, (hour - 17.0) / 2.0)
		elif hour < 21.0:
			_sky_material.sky_top_color = dusk_color.lerp(night_color, (hour - 19.0) / 2.0)
		else:
			_sky_material.sky_top_color = night_color


func _on_season_changed(season: int, _season_name: String) -> void:
	# Ajustar niebla según estación
	match season:
		0:  # Primavera
			_environment.volumetric_fog_density = fog_density
			_environment.volumetric_fog_albedo = Color(0.8, 0.9, 1.0)
		1:  # Verano
			_environment.volumetric_fog_density = fog_density * 0.5
			_environment.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
		2:  # Otoño
			_environment.volumetric_fog_density = fog_density * 1.5
			_environment.volumetric_fog_albedo = Color(0.85, 0.8, 0.7)
		3:  # Invierno
			_environment.volumetric_fog_density = fog_density * 2.0
			_environment.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)


## Activa/desactiva SDFGI en tiempo de ejecución
func set_sdfgi_enabled(enabled: bool) -> void:
	enable_sdfgi = enabled
	if _environment:
		_environment.sdfgi_enabled = enabled


## Activa/desactiva niebla volumétrica
func set_volumetric_fog_enabled(enabled: bool) -> void:
	enable_volumetric_fog = enabled
	if _environment:
		_environment.volumetric_fog_enabled = enabled


## Obtiene el Environment actual
func get_environment() -> Environment:
	return _environment


## Obtiene la luz direccional (sol)
func get_sun() -> DirectionalLight3D:
	return _directional_light
