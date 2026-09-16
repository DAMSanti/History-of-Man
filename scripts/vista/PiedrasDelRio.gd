class_name PiedrasDelRio
extends Node3D
## Las piedras que asoman en los rápidos, desde Medio (GRAFICOS §7.3).
##
## Vuelta pedida por el usuario el 2026-09-15 mirando las fotos del Pas: el rápido del
## juego era una tira blanca de espuma, y en un río de verdad el agua es clara entre
## piedras y la espuma sale DETRÁS de cada una. Dónde hay piedra lo decide
## [AguaDelCauce.piedra]; aquí se ponen las peñas bajas de la biblioteca de props,
## hundidas en el agua, y se hace la textura con la que los shaders del agua pintan la
## estela aguas abajo de cada una.
##
## **Es vista: no toca la partida.** Nadie tropieza con estas piedras ni cambian por
## dónde se vadea.

## Las peñas que sirven de piedra de río, de la biblioteca de props (`PropModels`).
const MODELOS: Array[String] = ["pena3", "pena2"]

## Cuánto asoma una piedra de río, en metros: de la más chica a la más grande. Decisión
## mirando la foto del Pas.
const ALTO_MINIMO_M := 0.45
const ALTO_MAXIMO_M := 1.3

## Qué parte de su alto queda bajo el agua.
const HUNDIDA := 0.45

var _terreno: TerrainGenerator
var _textura: ImageTexture = null


func setup(terreno: TerrainGenerator, biblioteca: PropLibrary) -> void:
	_terreno = terreno
	name = "PiedrasDelRio"
	add_to_group(Configuracion.GRUPO)
	var piedras := piedras_de(terreno)
	_textura = textura_de_piedras(terreno.resolution, piedras)
	if biblioteca != null:
		_poner_las_penas(piedras, biblioteca)
	aplicar_configuracion()
	print("Piedras del rio: %d" % piedras.size())


## Desde Medio. Y a los shaders del agua, la textura de dónde hay piedra.
func aplicar_configuracion() -> void:
	var nivel := int(Configuracion.graficos.get("agua", 1))
	visible = nivel >= 1
	var materiales: Array[ShaderMaterial] = []
	if _terreno._material_manager != null and _terreno._material_manager.get_material() != null:
		materiales.append(_terreno._material_manager.get_material())
	if _terreno.malla.lamina != null:
		materiales.append(_terreno.malla.lamina.material_override as ShaderMaterial)
	for m: ShaderMaterial in materiales:
		m.set_shader_parameter("piedras_tex", _textura)
		m.set_shader_parameter("con_piedras", nivel >= 1 and _textura != null)
		m.set_shader_parameter("lado_de_celda",
			float(_terreno.terrain_size.x) / float(maxi(_terreno.resolution - 1, 1)))
		m.set_shader_parameter("res_del_terreno", float(_terreno.resolution))
		var origen := _terreno.global_position if _terreno.is_inside_tree() else _terreno.position
		m.set_shader_parameter("origen_del_terreno", Vector2(origen.x, origen.z))


## Las piedras del terreno: {celda: Vector2i, fuerza: float, pos: Vector3 —relativa al
## terreno, a la cota del agua—, dir: Vector2 —la corriente—}.
static func piedras_de(terreno: TerrainGenerator) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	var res := terreno.resolution
	var lamina := terreno._river_map
	if res <= 1 or lamina.size() < res * res:
		return salida
	var paso := float(terreno.terrain_size.x) / float(res - 1)
	for i in range(lamina.size()):
		if lamina[i] < AguaDelCauce.LINEA_DEL_AGUA:
			continue
		var gx := i % res
		var gz := i / res
		var fuerza := AguaDelCauce.piedra(terreno._height_map, lamina, terreno._flow_map, res, gx, gz, paso)
		if fuerza > 0.0:
			var f := terreno._flow_map[i] if i < terreno._flow_map.size() else Vector2.ZERO
			salida.append({"celda": Vector2i(gx, gz), "fuerza": fuerza,
				"pos": Vector3(float(gx) * paso, terreno._height_map[i], float(gz) * paso),
				"dir": f.normalized() if f.length() > 0.01 else Vector2.RIGHT})
	return salida


## Una textura del tamaño de la rejilla del terreno con la fuerza de la piedra de cada
## celda: los shaders la miran aguas arriba para pintar la estela.
static func textura_de_piedras(res: int, piedras: Array[Dictionary]) -> ImageTexture:
	if res <= 1:
		return null
	var imagen := Image.create(res, res, false, Image.FORMAT_R8)
	for p: Dictionary in piedras:
		var c: Vector2i = p["celda"]
		imagen.set_pixel(c.x, c.y, Color(float(p["fuerza"]), 0.0, 0.0))
	return ImageTexture.create_from_image(imagen)


func _poner_las_penas(piedras: Array[Dictionary], biblioteca: PropLibrary) -> void:
	var por_modelo: Dictionary = {}
	for p: Dictionary in piedras:
		var c: Vector2i = p["celda"]
		var cual := MODELOS[(c.x * 7 + c.y * 13) % MODELOS.size()]
		if not biblioteca.has(cual):
			continue
		if not por_modelo.has(cual):
			por_modelo[cual] = []
		(por_modelo[cual] as Array).append(p)
	var origen := _terreno.global_position if _terreno.is_inside_tree() else _terreno.position
	for cual: String in por_modelo:
		var lista: Array = por_modelo[cual]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = biblioteca.mesh(cual, 0)
		multi.instance_count = lista.size()
		var alto_del_modelo := float((PropModels.CATALOGUE[cual] as Dictionary).get("height_m", 1.0))
		for k in range(lista.size()):
			var p: Dictionary = lista[k]
			var c: Vector2i = p["celda"]
			var azar := fposmod(sin(float(c.x) * 12.9898 + float(c.y) * 78.233) * 43758.5453, 1.0)
			var alto := lerpf(ALTO_MINIMO_M, ALTO_MAXIMO_M, float(p["fuerza"]) * 0.6 + azar * 0.4)
			var escala := biblioteca.scale_for(cual) * alto / maxf(alto_del_modelo, 0.01)
			var base := Basis().rotated(Vector3.UP, azar * TAU).scaled(Vector3.ONE * escala)
			var pos: Vector3 = p["pos"]
			pos.y -= alto * HUNDIDA / maxf(_terreno.meters_per_unit, 0.0001) * _terreno.vertical_exaggeration
			multi.set_instance_transform(k, Transform3D(base, origen + pos))
		var nodo := MultiMeshInstance3D.new()
		nodo.multimesh = multi
		nodo.material_overlay = ClimaEnPantalla.material_encima()
		nodo.name = "Piedras_%s" % cual
		add_child(nodo)
