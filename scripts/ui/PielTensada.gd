class_name PielTensada
extends Control
## El fondo de una ventana: una piel tensada con correas, no un rectangulo.
##
## Es la pieza que hace que la interfaz sea un OBJETO de la epoca en vez de un
## panel de cristal flotando sobre el mundo. Va colgada como primer hijo del
## marco -por debajo de todo lo escrito- y se dibuja sola al cambiar de tamano.
##
## Tres cosas la separan de un `StyleBoxFlat`, y las tres importan:
##
##   - El BORDE no es recto. Una piel tirante sobresale en la atadura y se comba
##     entre dos ataduras. Un radio de esquina de seis pixeles es lo contrario
##     de eso: es lo que delata a un widget.
##   - El relleno tiene VETA -ver `shaders/piel.gdshader`-, asi que el tono se
##     mueve por dentro en vez de ser plano.
##   - Las ATADURAS estan dibujadas: el ojal y la correa que pasa por el. Es el
##     detalle que explica por que el borde tiene esa forma.
##
## Ver docs/INTERFAZ.md.

## Cuanto sobresale la piel en cada atadura, en pixeles.
const PICO := 3.5

## Cuanto se comba entre dos ataduras. Mas que el pico, siempre: una piel
## tirante se hunde entre los puntos de tension, no se abomba.
const COMBADO := 6.0

## Cada cuantos pixeles va una atadura.
const SEPARACION := 78.0

## Cuantos puntos se dibujan de un tramo al siguiente. Siete bastan para que la
## comba se lea como curva y no como un pico.
const PUNTOS_POR_TRAMO := 7

## Cuanto se aparta el contorno del rectangulo de la piel. Es el sitio que
## necesitan el pico y el ojal para no salirse.
const MARGEN := 9.0

## Cuanto se sale la piel de su propio control, en pixeles.
##
## Hace falta porque un [PanelContainer] estira a TODOS sus hijos al hueco util
## -el marco menos los margenes de la caja de estilo-, asi que la piel salia
## del tamano del texto y no del de la ventana: el contenido quedaba pegado al
## borde combado. Se dibuja fuera del propio rectangulo, que en Godot se puede
## mientras `clip_contents` este apagado, y asi la piel es el MARCO y el texto
## va por dentro.
##
## Es el mismo numero que el margen de la caja hueca de [GameUI._window]: si se
## toca uno hay que tocar el otro, por eso se lee de aqui.
const DESBORDE := 22.0

## El filete de ocre por dentro, a esta distancia del borde. Asi se enmarca una
## pintura parietal: un filete de carbon fuera y otro de ocre dentro.
const FILETE := 7.0

## Grosor del reborde de la piel. Es el canto del cuero, que es grueso.
const CANTO := 3.0

## Radio del ojal por donde pasa la correa.
const OJAL := 2.6

## Cada cuantos pixeles se repite el grano en la piel.
##
## Menos que el lado de la textura -[Pigmento.LADO]- porque la piel se mira de
## cerca y el pigmento de lejos: el mismo grano tiene que salir mas apretado
## aqui. Y no se nota la costura porque la textura es sin junta.
const POROS := 96.0

## Semilla del temblor del borde. Fija: la ventana tiene que tener la misma
## forma cada vez que se abre.
const SEMILLA := 8112026

var _borde: PackedVector2Array = PackedVector2Array()
var _normales: PackedVector2Array = PackedVector2Array()
var _ataduras: Array[Dictionary] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# El fondo no come raton: lo hace el marco, que es quien sabe si la ventana
	# esta delante. Ver [GameUI._swallow_mouse].
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El grano se lee en coordenadas de la piel y se repite: sin esto, una
	# ventana mas grande que la textura sale con la junta a la vista.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var mat := ShaderMaterial.new()
	var shader := load("res://shaders/piel.gdshader") as Shader
	if shader != null:
		mat.shader = shader
		# Seis veces el grano de la era y no once: a 0,60 la veta tapaba el
		# fondo en vez de moverlo, y una piel curtida no es una nube.
		mat.set_shader_parameter("fuerza",
			clampf(PielDeEra.grano_de(UISkin.era) * 6.0, 0.0, 1.0))
		mat.set_shader_parameter("veta", UISkin.GROUND.darkened(0.35))
		material = mat
	resized.connect(_rehacer)


func _rehacer() -> void:
	_cortar()
	queue_redraw()


## Recorta la piel al tamano que tenga ahora la ventana.
##
## Se hace aqui y no en `_draw` porque el contorno no depende de nada mas que
## del tamano: rehacerlo en cada repintado seria calcular ciento y pico puntos
## sesenta veces por segundo para que salgan siempre iguales.
func _cortar() -> void:
	_borde = PackedVector2Array()
	_normales = PackedVector2Array()
	_ataduras.clear()
	var fuera := DESBORDE - MARGEN
	var r := Rect2(Vector2(-fuera, -fuera), size + Vector2(fuera, fuera) * 2.0)
	if r.size.x < 40.0 or r.size.y < 40.0:
		return

	_ataduras = _repartir_ataduras(r)
	if _ataduras.size() < 4:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	for i in range(_ataduras.size()):
		var a: Dictionary = _ataduras[i]
		var b: Dictionary = _ataduras[(i + 1) % _ataduras.size()]
		# Un temblor por tramo, no por punto: una piel curtida tiene el borde
		# irregular a lo largo, no dentado.
		var temblor := rng.randf_range(-1.6, 1.6)
		for paso in range(PUNTOS_POR_TRAMO):
			var t := float(paso) / float(PUNTOS_POR_TRAMO)
			var recta: Vector2 = (a["pos"] as Vector2).lerp(b["pos"] as Vector2, t)
			var normal: Vector2 = (a["n"] as Vector2).lerp(b["n"] as Vector2, t).normalized()
			# Sobresale en la atadura y se hunde en medio, que es lo que hace
			# una piel tirante.
			var salida := PICO - (PICO + COMBADO + temblor) * sin(PI * t)
			_borde.append(recta + normal * salida)
			_normales.append(normal)


## Donde van las correas. Una cada [SEPARACION] pixeles, y siempre una en cada
## esquina: la esquina es el punto que mas tira.
func _repartir_ataduras(r: Rect2) -> Array[Dictionary]:
	var esquinas: Array[Vector2] = [
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	]
	var normales: Array[Vector2] = [
		Vector2(0.0, -1.0), Vector2(1.0, 0.0),
		Vector2(0.0, 1.0), Vector2(-1.0, 0.0),
	]
	var salida: Array[Dictionary] = []
	for lado in range(4):
		var a: Vector2 = esquinas[lado]
		var b: Vector2 = esquinas[(lado + 1) % 4]
		var n: Vector2 = normales[lado]
		var previa: Vector2 = normales[(lado + 3) % 4]
		var cuantas := maxi(2, int(round(a.distance_to(b) / SEPARACION)))
		for i in range(cuantas):
			# La esquina tira en diagonal, no hacia el lado que empieza.
			var normal := ((previa + n).normalized() if i == 0 else n)
			salida.append({
				"pos": a.lerp(b, float(i) / float(cuantas)),
				"n": normal,
				"esquina": i == 0,
			})
	return salida


func _draw() -> void:
	if _borde.size() < 8:
		_cortar()
		if _borde.size() < 8:
			return

	# 1. La piel. El color va en el vertice y la veta en la textura: el
	#    sombreador los mezcla. Ver `shaders/piel.gdshader`.
	var uvs := PackedVector2Array()
	for punto: Vector2 in _borde:
		uvs.append(punto / POROS)
	draw_colored_polygon(_borde, UISkin.GROUND.lightened(0.06), uvs,
		Pigmento.grano())

	# 2. El canto del cuero, que es grueso y mas oscuro que la cara.
	var cerrado := _borde.duplicate()
	cerrado.append(_borde[0])
	draw_polyline(cerrado, UISkin.GROUND.darkened(0.55), CANTO, true)
	draw_polyline(cerrado, UISkin.RULE.darkened(0.25), 1.0, true)

	# 3. El filete de ocre por dentro. Ver [FILETE].
	var dentro := PackedVector2Array()
	for i in range(_borde.size()):
		dentro.append(_borde[i] - _normales[i] * FILETE)
	dentro.append(dentro[0])
	draw_polyline(dentro, UISkin.OCHRE.darkened(0.35), 1.0, true)

	# 4. Las correas, que son lo que explica la forma del borde.
	for atadura: Dictionary in _ataduras:
		_correa(atadura["pos"] as Vector2, atadura["n"] as Vector2,
			bool(atadura["esquina"]))


## Un ojal con su correa pasada. La correa sale hacia fuera, que es hacia donde
## tira el bastidor.
func _correa(en: Vector2, normal: Vector2, esquina: bool) -> void:
	var largo := 7.0 if esquina else 5.0
	var tinta := UISkin.INK_FAINT
	draw_line(en - normal * 2.0, en + normal * largo, tinta, 1.4, true)
	# El nudo: un travesano corto sobre la correa.
	var cruz := normal.orthogonal() * (2.6 if esquina else 2.0)
	draw_line(en + normal * (largo * 0.55) - cruz,
		en + normal * (largo * 0.55) + cruz, tinta, 1.2, true)
	# Y el ojal, que es un agujero: se ve el fondo, no la piel.
	draw_circle(en - normal * 1.5, OJAL, UISkin.GROUND.darkened(0.7))
	draw_arc(en - normal * 1.5, OJAL, 0.0, TAU, 10,
		UISkin.RULE.darkened(0.4), 1.0, true)
