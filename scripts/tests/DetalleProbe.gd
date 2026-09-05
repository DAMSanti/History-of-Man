extends SceneTree
## Cuanto cambia el terreno el ruido de detalle, sobre dato del IGN.
##
## `detail_amplitude` se escribio para relieve procedural y para el terrarium
## de 13,9 m, donde de verdad rellenaba un hueco. Pero el mapa local se carga
## hoy del MDT05 del IGN -5,00 m por muestra- y la malla va a 4,97 m por
## vertice: el dato ya mide la verdad a la escala de la malla.
##
## Y el recorte anti-alias deja la onda mas fina en 25 m (ver
## `_safe_detail_frequency`), o sea CINCO VECES mas gruesa que el dato. Asi que
## el ruido no puede anadir detalle: solo ondular relieve medido.
##
## Esto no lo decide un razonamiento, lo decide mirarlo. Se genera el mismo
## sitio con tres amplitudes, se guarda la misma vista de cada una y se mide
## cuanto se ha movido el suelo en metros.
##
## RESULTADO (sitio 56, 5-sep-2026): con amplitud 3 el monte se cubre de bultos
## redondos que se comen las crestas y las vaguadas del LiDAR; con 1,5 ya se
## nota. En la simulacion, en cambio, apenas toca: 24 casillas de 9216 cambian
## de andable a pared y el ritmo medio de marcha se queda en 100,4 %. O sea que
## era un problema de vista, no de juego.
##
## De ahi salio `TerrainGenerator._effective_detail_amplitude`, que apaga el
## ruido cuando el paso del dato ya iguala al de la malla. Con esa regla puesta,
## sobre dato del IGN LAS TRES VARIANTES SALEN IGUALES, y eso es lo correcto:
## la sonda queda como guarda de esa regla. La columna «efectiva» del informe es
## la que hay que mirar.
##
## Correr con:
##   Godot_v4.5.1-stable_win64_console.exe --path . --resolution 1600x900 \
##     --script res://scripts/tests/DetalleProbe.gd

const SITE_ID := 56
const RESOLUTION := 825

## Las tres que interesan: sin nada, lo que hay puesto hoy, y el doble.
const AMPLITUDES := [0.0, 1.5, 3.0]

## Rejilla sobre la que se compara la cota. No hace falta mas: es una medida
## de cuanto se mueve el suelo, no un mapa.
const SAMPLES := 96

var _site: Site
var _heightmap: HeightmapData
var _offset: Vector2
var _baseline: PackedFloat32Array = PackedFloat32Array()
var _baseline_slope: PackedFloat32Array = PackedFloat32Array()
var _out_dir: String = ""


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	if not _load_site():
		quit()
		return

	_out_dir = ProjectSettings.globalize_path("user://")
	print("=== detalle inventado sobre MDT del IGN ===")
	print("sitio %d · %s" % [SITE_ID, _site.display_name()])
	print("dato %.2f m/muestra · malla %.2f m/vertice" % [
		_heightmap.meters_per_sample,
		float(Expedition.local_size_m) / float(RESOLUTION - 1)])
	print("")

	var env := (load("res://scenes/WorldEnvironment.tscn") as PackedScene).instantiate()
	root.add_child(env)

	for amplitude: float in AMPLITUDES:
		await _run_one(amplitude)

	print("")
	print("capturas en %s" % _out_dir)
	quit()


func _load_site() -> bool:
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if sites == null:
		print("no hay cantabria_sites.res")
		return false
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			_site = s
	if _site == null:
		print("no esta el emplazamiento %d" % SITE_ID)
		return false

	_heightmap = load("res://data/dem/local/site_%d.res" % SITE_ID)
	if _heightmap == null:
		print("no hay MDT local del emplazamiento %d" % SITE_ID)
		return false

	# El mismo encuadre que usa la fundacion desde el mapa regional
	var size_m := _heightmap.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	_offset = Vector2(
		clampf(_heightmap.u_for_lon(_site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(_heightmap.v_for_lat(_site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))
	return true


func _run_one(amplitude: float) -> void:
	var terrain := TerrainGenerator.new()
	terrain.name = "TerrainGenerator"
	terrain.terrain_size = Vector2i(Expedition.local_size_m, Expedition.local_size_m)
	terrain.resolution = RESOLUTION
	terrain.max_height = 30.0
	terrain.seed_value = 12345
	terrain.sea_level = 0.0
	terrain.height_source = TerrainGenerator.HeightSource.HEIGHTMAP
	terrain.heightmap = _heightmap
	terrain.heightmap_region_offset = _offset
	terrain.bands_relative = true
	terrain.detail_amplitude = amplitude
	# Sin cache: la cache se nombra solo por resolucion, asi que las tres
	# variantes se pisarian el fichero y saldrian tres capturas iguales.
	terrain.use_generation_cache = false
	root.add_child(terrain)
	terrain.generate()

	for i in range(30):
		await process_frame

	_measure(terrain, amplitude)

	var centre := Vector3(2048.0, 0.0, 2048.0)
	centre.y = terrain.get_height_at(centre)
	var tag := String("%0.1f" % amplitude).replace(".", "_")
	await _shoot(terrain, "user://detalle_%s_orbita.png" % tag,
		centre + Vector3(0.0, 75.0, 130.0), centre)
	await _shoot(terrain, "user://detalle_%s_rasante.png" % tag,
		centre + Vector3(0.0, 26.0, 70.0), centre)

	terrain.queue_free()
	await process_frame


## Cuanto se ha movido el suelo, y -lo que de verdad importa- cuanto se ha
## movido la PENDIENTE, que es lo que consulta la simulacion: transitabilidad
## (`Traversal.is_passable`), ritmo de marcha (`hiking_speed`), riesgo, reparto
## de recursos y sitio de la fauna.
func _measure(terrain: TerrainGenerator, amplitude: float) -> void:
	var heights := PackedFloat32Array()
	var slopes := PackedFloat32Array()
	heights.resize(SAMPLES * SAMPLES)
	slopes.resize(SAMPLES * SAMPLES)
	var step := float(Expedition.local_size_m) / float(SAMPLES)
	for z in range(SAMPLES):
		for x in range(SAMPLES):
			var point := Vector3(float(x) * step, 0.0, float(z) * step)
			heights[z * SAMPLES + x] = terrain.get_height_at(point)
			slopes[z * SAMPLES + x] = terrain.get_slope_at(point)

	var span := terrain.get_height_range()
	var effective: float = terrain.call("_effective_detail_amplitude")
	if _baseline.is_empty():
		_baseline = heights
		_baseline_slope = slopes
		print("amplitud %.1f (efectiva %.3f)  (referencia)   cotas %.1f a %.1f u" % [
			amplitude, effective, span.x, span.y])
		return

	var sum_sq := 0.0
	var peak := 0.0
	var slope_sum := 0.0
	var slope_peak := 0.0
	var flips := 0
	var slowed := 0.0
	for i in range(heights.size()):
		var d: float = heights[i] - _baseline[i]
		sum_sq += d * d
		peak = maxf(peak, absf(d))

		var s0: float = _baseline_slope[i]
		var s1: float = slopes[i]
		slope_sum += absf(s1 - s0)
		slope_peak = maxf(slope_peak, absf(s1 - s0))
		# Cruzar el limite de escalada cambia una casilla de andable a pared
		if (s0 > Traversal.CLIMB_LIMIT) != (s1 > Traversal.CLIMB_LIMIT):
			flips += 1
		# Tobler es exponencial: un error de pendiente sale caro en el ritmo
		slowed += Traversal.hiking_speed(s1) / maxf(Traversal.hiking_speed(s0), 0.001)

	var n := float(heights.size())
	print("amplitud %.1f (efectiva %.3f)  cotas %.1f a %.1f u" % [
		amplitude, effective, span.x, span.y])
	print("   altura   RMS %.2f m · maximo %.2f m" % [sqrt(sum_sq / n), peak])
	print("   pendiente  media |delta| %.3f · maximo %.3f  (limite de escalada %.1f)" % [
		slope_sum / n, slope_peak, Traversal.CLIMB_LIMIT])
	print("   casillas que cambian de andable a pared: %d de %d (%.1f %%)" % [
		flips, int(n), 100.0 * float(flips) / n])
	print("   ritmo de marcha medio respecto a sin ruido: %.1f %%" % [100.0 * slowed / n])


func _shoot(terrain: Node, path: String, from_point: Vector3, at: Vector3) -> void:
	var camera := Camera3D.new()
	camera.far = 20000.0
	terrain.add_child(camera)
	camera.global_position = from_point
	camera.look_at(at, Vector3.UP)
	camera.make_current()

	for i in range(8):
		await process_frame

	root.get_texture().get_image().save_png(path)
	camera.queue_free()
