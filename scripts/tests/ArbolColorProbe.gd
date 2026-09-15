extends SceneTree
## El color de cada especie de árbol, contra sus fotos de referencia. GRAFICOS §7.1.
##
## **Con ventana**, y un escalón por corrida porque el bosque monta uno:
##
##   ESCALON=0 godot --path . --script res://scripts/tests/ArbolColorProbe.gd
##   ESCALON=1 godot --path . --script res://scripts/tests/ArbolColorProbe.gd
##
## Monta el valle con la luz del juego a mediodía, y delante de una cámara suya pone un
## árbol suelto de cada especie, con los materiales que tiene el bosque en esa
## estación. Mide el color medio en CIELAB y lo compara con
## `models/arboles/color_de_referencia.json`: **ΔE ≤ 10** es la cifra de la spec.
##
## Qué se mide en cada escalón:
##   Mínimo       la lámina de lejos, y de cerca con sus tres cruzadas encima, enteras,
##                contra la copa.
##   Medio y más  el 3D con sólo la hoja contra la copa, con sólo la corteza contra la
##                corteza; y el impostor entero contra el 3D entero, que es lo que
##                decide si el relevo se nota.
##
## CÓMO SE SEPARA EL ÁRBOL DEL FONDO: la misma foto con él y sin él, y se quedan los
## píxeles que cambian, menos su borde —el borde mezcla árbol y fondo—. Y el fondo es UN
## TELÓN plano sin luz, no el valle: con el valle detrás, algo del fondo se movía entre
## foto y foto, y en el pino fino de Mínimo pesaba más que el árbol —medía L 42, a −2,
## b −4, que es cielo, y el tinte no le hacía nada—.
##
## SIN NIEBLA: las fotos de referencia son de cerca, y la bruma de lejos es cosa del
## cielo, no del color del árbol. Medirla aquí haría que el árbol «corrigiera» el aire.
##
## CALIBRAR=1 además propone, por especie y estación, el tinte que lleva la media al
## color de la referencia. Es una propuesta: lo que va a `Forest` se escribe a mano.

const SITE_ID := 56
const SALIDA := "user://capturas"
const ESPECIES := ["pino", "pino_joven", "abedul", "roble", "avellano"]
const VARIANTES_MEDIDAS := [0, 3]
const MARGEN_DE := 10.0
## Las vueltas del calibrado: con medio paso, a la séptima el tinte ya no se mueve más
## que la medida.
const VUELTAS := 7
## Las fotos a 1/4: basta para una media, y recorrer 2 millones de píxeles en
## GDScript cuesta segundos por foto.
const REDUCE := 4

var _referencia: Dictionary = {}
var _camara: Camera3D
var _setup: Node3D
var _bosque: Forest
var _invisible: ShaderMaterial
var _telon: MeshInstance3D
var _fallos := 0
var _calibrar := false
## La luz del impostor calibrada en verano, por especie: de ahí arranca la de otoño.
var _luz: Dictionary = {}


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var escalon := int(OS.get_environment("ESCALON")) if not OS.get_environment("ESCALON").is_empty() else 1
	_calibrar = OS.get_environment("CALIBRAR") == "1"
	Configuracion.graficos["arboles"] = escalon
	_referencia = JSON.parse_string(FileAccess.get_file_as_string("res://models/arboles/color_de_referencia.json"))
	_preparar()
	change_scene_to_file("res://scenes/demo_main.tscn")
	for _i in range(900):
		await process_frame
		if current_scene != null and current_scene.get("camera") != null:
			break
	var demo := current_scene
	_bosque = _buscar(demo, "Bosque") as Forest
	_setup = _buscar_entorno(demo)
	if _bosque == null or _setup == null:
		print("sin bosque o sin entorno"); quit(1); return
	_ocultar_interfaz(demo)
	paused = true
	_setup.set("follow_time_of_day", false)
	_setup.set("fixed_hour", 12.0)
	var env: Environment = _setup.call("get_environment")
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	var sombra := Shader.new()
	sombra.code = "shader_type spatial;\nvoid fragment() { discard; }\n"
	_invisible = ShaderMaterial.new()
	_invisible.shader = sombra

	var casa: Vector3 = demo.get("sim").get("home_position")
	_camara = Camera3D.new()
	_camara.fov = 30.0
	_camara.far = 20000.0
	demo.add_child(_camara)
	# Muy por encima del valle: detrás del árbol, cielo o monte lejano, y nada delante.
	_camara.global_position = casa + Vector3(0.0, 700.0, 0.0)
	_camara.make_current()
	_telon = MeshInstance3D.new()
	var plano := QuadMesh.new()
	plano.size = Vector2(900.0, 900.0)
	_telon.mesh = plano
	var tela := StandardMaterial3D.new()
	tela.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tela.albedo_color = Color(0.5, 0.0, 0.5)
	tela.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telon.material_override = tela
	_telon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	demo.add_child(_telon)
	# Que asienten la luz de ambiente y las sombras: con 60 fotogramas, la corteza del
	# primer árbol medido salía 16 puntos de L más oscura que en otra corrida.
	for _i in range(240):
		await process_frame

	print("escalón %d" % _bosque.escalon)
	for especie: String in ESPECIES:
		if not OS.get_environment("SOLO").is_empty() and especie != OS.get_environment("SOLO"):
			continue
		var k := _indice(especie)
		var caduco := bool(Forest.KINDS[k].get("caduco", false))
		var estaciones := [Subsistence.Season.VERANO, Subsistence.Season.OTONO,
			Subsistence.Season.INVIERNO] if caduco else [Subsistence.Season.VERANO]
		for estacion: Subsistence.Season in estaciones:
			GameState.season = estacion
			_setup.call("_apply_fixed_sun")
			_bosque.set_season(estacion, estacion, 1.0)
			await _mirar_hacia_el_sol()
			if estacion == Subsistence.Season.INVIERNO:
				await _medir_invierno(especie, k)
			elif _bosque.escalon == 0:
				await _medir_minimo(especie, k, estacion)
			else:
				await _medir_3d(especie, k, estacion)
	print("fuera de margen: %d" % _fallos)
	quit()


# --- Medio, Alto, Ultra -----------------------------------------------------------------

func _medir_3d(especie: String, k: int, estacion: Subsistence.Season) -> void:
	var nombre := _nombre_estacion(estacion)
	var base := especie.trim_suffix("_joven")
	var verano := estacion == Subsistence.Season.VERANO
	var mats: Array = _bosque._mat_3d[k]
	var corteza := _copia(mats[0])
	var hoja := _copia(mats[1])
	var vistas := _copia(_bosque._mat_vistas[k])
	var obj_copa := _lab_de("%s.copa.%s" % [base, nombre])
	var obj_corteza := _lab_de("%s.corteza" % base)
	var fondo := await _foto()
	var copa := Vector3.ZERO
	var tronco := Vector3.ZERO
	for vuelta in range(VUELTAS if _calibrar else 1):
		if vuelta > 0:
			_acercar(hoja, copa, obj_copa)
			if verano:
				_acercar(corteza, tronco, obj_corteza)
		var copa_lab: Array = []
		var corteza_lab: Array = []
		for v: int in VARIANTES_MEDIDAS:
			var nodo := _plantar_3d(k, v, corteza, hoja)
			nodo.set_surface_override_material(0, _invisible)
			copa_lab.append(_media(fondo, await _foto()))
			# LA CORTEZA DE CERCA: de lejos el tronco son dos píxeles, el borde se los come
			# y la media salía de cuatro ramas —el pino calibrado salió rosa—.
			nodo.set_surface_override_material(0, corteza)
			nodo.set_surface_override_material(1, _invisible)
			nodo.position = _sitio_de_tronco(nodo.position, (_bosque._modelos[k][v] as ArbolModelo).alto_m)
			corteza_lab.append(_media(fondo, await _foto()))
			nodo.queue_free()
		copa = _promedio(copa_lab)
		tronco = _promedio(corteza_lab)

	# El impostor con los mismos tintes que acaba de tener el 3D, contra el 3D entero.
	vistas.set_shader_parameter("tint", hoja.get_shader_parameter("tint"))
	vistas.set_shader_parameter("tint_corteza", corteza.get_shader_parameter("tint"))
	var entero_lab: Array = []
	var sitios: Array[Vector3] = []
	for v: int in VARIANTES_MEDIDAS:
		var nodo := _plantar_3d(k, v, corteza, hoja)
		var entero := await _foto()
		entero_lab.append(_media(fondo, entero))
		if v == VARIANTES_MEDIDAS[0]:
			entero.save_png("%s/color_%d_%s_%s.png" % [SALIDA, _bosque.escalon, especie, nombre])
		sitios.append(nodo.position)
		nodo.queue_free()
	# La luz del impostor, contra el 3D; el otoño arranca de la del verano.
	if _calibrar and not verano and _luz.has(especie):
		vistas.set_shader_parameter("luz", _luz[especie])
	var impostor_lab: Array = []
	for vuelta in range(VUELTAS if _calibrar else 1):
		if vuelta > 0:
			var ent := _srgb_lineal_de_lab(_promedio(entero_lab))
			var imp := _srgb_lineal_de_lab(_promedio(impostor_lab))
			var antes: Vector3 = vistas.get_shader_parameter("luz")
			vistas.set_shader_parameter("luz", Vector3(
				antes.x * sqrt(ent.x / maxf(imp.x, 0.001)),
				antes.y * sqrt(ent.y / maxf(imp.y, 0.001)),
				antes.z * sqrt(ent.z / maxf(imp.z, 0.001))))
		impostor_lab.clear()
		for i in range(VARIANTES_MEDIDAS.size()):
			var v: int = VARIANTES_MEDIDAS[i]
			vistas.set_shader_parameter("ojo", sitios[i])
			var impostor := _impostor_vistas(vistas, v, sitios[i])
			var foto := await _foto()
			impostor_lab.append(_media(fondo, foto))
			if i == 0:
				foto.save_png("%s/color_%d_%s_%s_impostor.png" % [SALIDA, _bosque.escalon, especie, nombre])
			impostor.queue_free()
	if verano:
		_luz[especie] = vistas.get_shader_parameter("luz")
	if _calibrar:
		var l: Vector3 = vistas.get_shader_parameter("luz")
		print("TABLA %s.%s = Vector3(%.3f, %.3f, %.3f)" % [especie,
			"impostor" if verano else "impostor_otono", l.x, l.y, l.z])

	_informe("%s %s · 3D copa" % [especie, nombre], copa, obj_copa,
		hoja, "otono" if not verano else "copa", especie)
	if verano:
		_informe("%s · 3D corteza" % especie, tronco, obj_corteza, corteza, "corteza", especie)
	_informe("%s %s · impostor contra 3D" % [especie, nombre], _promedio(impostor_lab),
		_promedio(entero_lab), null, "", especie)


func _plantar_3d(k: int, variante: int, corteza: ShaderMaterial, hoja: ShaderMaterial) -> MeshInstance3D:
	var modelo: ArbolModelo = _bosque._modelos[k][variante]
	var sitio := _sitio_para(modelo.alto_m)
	for m: ShaderMaterial in [corteza, hoja]:
		m.set_shader_parameter("ojo", sitio)
		m.set_shader_parameter("radio_3d", 1.0e6)
	var nodo := MeshInstance3D.new()
	nodo.mesh = modelo.niveles[0]
	nodo.position = sitio
	current_scene.add_child(nodo)
	nodo.set_surface_override_material(0, corteza)
	nodo.set_surface_override_material(1, hoja)
	return nodo


## EL INVIERNO DE LOS CADUCOS, pelados: no hay foto de copa, pero lo que queda es rama,
## así que en Mínimo se mide contra la corteza —y se calibra `rama`—, y en Medio el
## impostor contra el 3D, que es donde se veían los caducos lejanos de color lila.
func _medir_invierno(especie: String, k: int) -> void:
	var fondo := await _foto()
	if _bosque.escalon == 0:
		var lejos := _copia(_bosque._far_material[k])
		var talla: Vector2 = _bosque._sizes[k]
		var sitio := _sitio_para(talla.y)
		var objetivo := _lab_de("%s.corteza" % especie)
		var lamina := _multi(_bosque._card_mesh(), Basis().scaled(Vector3(talla.x, talla.y, 1.0)), lejos, sitio)
		var medido := Vector3.ZERO
		for vuelta in range(VUELTAS if _calibrar else 1):
			if vuelta > 0:
				_acercar(lejos, medido, objetivo, "rama")
			var foto := await _foto()
			medido = _media(fondo, foto)
			foto.save_png("%s/color_0_%s_invierno.png" % [SALIDA, especie])
		lamina.queue_free()
		await process_frame
		_informe("%s invierno · Mínimo contra corteza" % especie, medido, objetivo, lejos, "rama", especie, "rama")
		return
	var mats: Array = _bosque._mat_3d[k]
	var corteza := _copia(mats[0])
	var hoja := _copia(mats[1])
	var vistas := _copia(_bosque._mat_vistas[k])
	var entero_lab: Array = []
	var impostor_lab: Array = []
	for v: int in VARIANTES_MEDIDAS:
		var nodo := _plantar_3d(k, v, corteza, hoja)
		var foto := await _foto()
		entero_lab.append(_media(fondo, foto))
		if v == VARIANTES_MEDIDAS[0]:
			foto.save_png("%s/color_%d_%s_invierno.png" % [SALIDA, _bosque.escalon, especie])
		var sitio := nodo.position
		nodo.queue_free()
		vistas.set_shader_parameter("ojo", sitio)
		var impostor := _impostor_vistas(vistas, v, sitio)
		var imp := await _foto()
		impostor_lab.append(_media(fondo, imp))
		if v == VARIANTES_MEDIDAS[0]:
			imp.save_png("%s/color_%d_%s_invierno_impostor.png" % [SALIDA, _bosque.escalon, especie])
		impostor.queue_free()
	_informe("%s invierno · impostor contra 3D" % especie, _promedio(impostor_lab),
		_promedio(entero_lab), null, "", especie)


func _impostor_vistas(material: ShaderMaterial, variante: int, sitio: Vector3) -> Node3D:
	material.set_shader_parameter("oculto_hasta", -1.0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _bosque._cuadro_de_vistas()
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D.IDENTITY)
	multi.set_instance_custom_data(0, Color(float(variante) / 255.0, 0.0, 0.0, 0.0))
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = multi
	nodo.material_override = material
	nodo.position = sitio
	nodo.custom_aabb = AABB(Vector3(-40.0, -10.0, -40.0), Vector3(80.0, 60.0, 80.0))
	current_scene.add_child(nodo)
	return nodo


# --- Mínimo -------------------------------------------------------------------------

func _medir_minimo(especie: String, k: int, estacion: Subsistence.Season) -> void:
	var nombre := _nombre_estacion(estacion)
	var lejos := _copia(_bosque._far_material[k])
	var cerca := _copia(_bosque._near_material[k])
	var talla: Vector2 = _bosque._sizes[k]
	var sitio := _sitio_para(talla.y)
	var objetivo := _lab_de("%s.copa.%s" % [especie.trim_suffix("_joven"), nombre])
	var fondo := await _foto()
	# DE LEJOS, la lámina que mira a la cámara; DE CERCA, esa misma y las tres cruzadas
	# encima, que es como se pinta un árbol de Mínimo dentro de `near_distance`.
	var lamina := _multi(_bosque._card_mesh(), Basis().scaled(Vector3(talla.x, talla.y, 1.0)), lejos, sitio)
	var cruzadas := _multi(_bosque._crossed, Basis().scaled(Vector3(talla.x, talla.y, talla.x)), cerca, sitio)
	var medido_lejos := Vector3.ZERO
	var medido_cerca := Vector3.ZERO
	for vuelta in range(VUELTAS if _calibrar else 1):
		if vuelta > 0:
			# El tinte es uno para las dos: se acerca con la media de las dos medidas.
			_acercar(lejos, (medido_lejos + medido_cerca) * 0.5, objetivo)
			cerca.set_shader_parameter("tint", lejos.get_shader_parameter("tint"))
		cruzadas.visible = false
		medido_lejos = _media(fondo, await _foto())
		cruzadas.visible = true
		var foto_cerca := await _foto()
		medido_cerca = _media(fondo, foto_cerca)
		foto_cerca.save_png("%s/color_0_%s_%s.png" % [SALIDA, especie, nombre])
	lamina.queue_free()
	cruzadas.queue_free()
	await process_frame
	var clave := "minimo_otono" if estacion == Subsistence.Season.OTONO else "minimo"
	_informe("%s %s · Mínimo de lejos" % [especie, nombre], medido_lejos, objetivo, null, clave, especie)
	_informe("%s %s · Mínimo de cerca" % [especie, nombre], medido_cerca, objetivo, lejos, clave, especie)


func _multi(malla: Mesh, forma: Basis, material: ShaderMaterial, sitio: Vector3) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = malla
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D(forma, Vector3.ZERO))
	var nodo := MultiMeshInstance3D.new()
	nodo.multimesh = multi
	nodo.material_override = material
	nodo.position = sitio
	nodo.custom_aabb = AABB(Vector3(-40.0, -10.0, -40.0), Vector3(80.0, 60.0, 80.0))
	current_scene.add_child(nodo)
	return nodo


## Una copia del material CON sus uniformes: `duplicate()` no se lleva los que se
## pusieron por código —medía el abedul de otoño verde y con toda la hoja—.
func _copia(original: ShaderMaterial) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = original.shader
	for u: Dictionary in original.shader.get_shader_uniform_list():
		var nombre := String(u["name"])
		m.set_shader_parameter(nombre, original.get_shader_parameter(nombre))
	return m


# --- la cámara y la foto ---------------------------------------------------------------

## El sol A LA ESPALDA y un poco de lado, como se hace una foto de un árbol: de frente
## al sol se mediría su cara en sombra.
func _mirar_hacia_el_sol() -> void:
	var sol: DirectionalLight3D = _setup.call("get_sun")
	var va := -sol.global_transform.basis.z
	var llano := Vector3(va.x, 0.0, va.z)
	llano = llano.normalized() if llano.length() > 0.01 else Vector3.FORWARD
	llano = llano.rotated(Vector3.UP, deg_to_rad(35.0))
	_camara.look_at(_camara.global_position + llano, Vector3.UP)
	_telon.global_transform = Transform3D(_camara.global_transform.basis,
		_camara.global_position + llano * 400.0)
	await process_frame


## Dónde poner un árbol de `alto` metros para que ocupe dos tercios del alto del cuadro.
func _sitio_para(alto: float) -> Vector3:
	var lejos := alto / (0.66 * 2.0 * tan(deg_to_rad(_camara.fov * 0.5)))
	var delante := -_camara.global_transform.basis.z
	return _camara.global_position + delante * lejos - Vector3(0.0, alto * 0.5, 0.0)


## El árbol acercado para que el tercio bajo del tronco llene el centro del cuadro.
func _sitio_de_tronco(_lejos: Vector3, alto: float) -> Vector3:
	var delante := -_camara.global_transform.basis.z
	return _camara.global_position + delante * alto * 0.8 - Vector3(0.0, alto * 0.3, 0.0)


func _foto() -> Image:
	for _i in range(20):
		await process_frame
	var imagen := root.get_texture().get_image()
	imagen.resize(imagen.get_width() / REDUCE, imagen.get_height() / REDUCE, Image.INTERPOLATE_NEAREST)
	return imagen


## El Lab medio de lo que cambia entre `fondo` y `con`, sin el borde.
##
## Como `color_de_referencia.py`: Lab por píxel y luego la media, y fuera lo casi negro
## (brillo < 0,06), que son huecos y no color. Si no, la sonda y la foto medirían cosas
## distintas y el ΔE saldría de la diferencia de método.
func _media(fondo: Image, con: Image) -> Vector3:
	var w := con.get_width()
	var h := con.get_height()
	var mascara := PackedByteArray()
	mascara.resize(w * h)
	for y in range(h):
		for x in range(w):
			var a := fondo.get_pixel(x, y)
			var b := con.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.03:
				mascara[y * w + x] = 1
	var suma := Vector3.ZERO
	var n := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if mascara[i] == 0 or mascara[i - 1] == 0 or mascara[i + 1] == 0 					or mascara[i - w] == 0 or mascara[i + w] == 0:
				continue
			var c := con.get_pixel(x, y)
			if (c.r + c.g + c.b) / 3.0 < 0.06:
				continue
			suma += lab_de_srgb(c)
			n += 1
	if n < 50:
		return Vector3(-1.0, 0.0, 0.0)
	return suma / float(n)


## sRGB (D65) a CIELAB, la misma cuenta que `skimage.color.rgb2lab`.
static func lab_de_srgb(c: Color) -> Vector3:
	var r := _lineal(c.r)
	var g := _lineal(c.g)
	var b := _lineal(c.b)
	var x := (0.412453 * r + 0.357580 * g + 0.180423 * b) / 0.95047
	var y := 0.212671 * r + 0.715160 * g + 0.072169 * b
	var z := (0.019334 * r + 0.119193 * g + 0.950227 * b) / 1.08883
	var fx := _f(x)
	var fy := _f(y)
	var fz := _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lineal(v: float) -> float:
	v = clampf(v, 0.0, 1.0)
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


# --- el informe -------------------------------------------------------------------------

## Imprime la medida contra su objetivo; al calibrar, con el tinte que la dio.
func _informe(que: String, medido: Vector3, objetivo: Vector3, material: ShaderMaterial,
		clave: String, especie: String, uniforme := "tint") -> void:
	if medido.x < 0.0 or objetivo.x < 0.0:
		print("  %-40s sin medida" % que)
		return
	var de := medido.distance_to(objetivo)
	var mal := de > MARGEN_DE
	if mal:
		_fallos += 1
	print("  %-40s L %5.1f a %6.1f b %6.1f  objetivo L %5.1f a %6.1f b %6.1f  ΔE %5.1f %s" % [
		que, medido.x, medido.y, medido.z, objetivo.x, objetivo.y, objetivo.z, de,
		"FUERA" if mal else "ok"])
	if _calibrar and material != null:
		var t := _tinte(material, uniforme)
		print("TABLA %s.%s = Color(%.3f, %.3f, %.3f)" % [especie, clave, t.r, t.g, t.b])


## Un paso del tinte hacia el objetivo: el cociente en sRGB lineal entre objetivo y
## medida, A MEDIAS —su raíz—. La luz no es sólo proporcional al albedo (hay ambiente,
## tonemap), y con el paso entero el tinte rebotaba de una vuelta a otra sin acercarse.
func _acercar(material: ShaderMaterial, medido: Vector3, objetivo: Vector3,
		uniforme := "tint") -> void:
	if medido.x < 0.0 or objetivo.x < 0.0:
		return
	var antes := _tinte(material, uniforme)
	var m := _srgb_lineal_de_lab(medido)
	var o := _srgb_lineal_de_lab(objetivo)
	material.set_shader_parameter(uniforme, Color(
		clampf(antes.r * sqrt(o.x / maxf(m.x, 0.001)), 0.01, 6.0),
		clampf(antes.g * sqrt(o.y / maxf(m.y, 0.001)), 0.01, 6.0),
		clampf(antes.b * sqrt(o.z / maxf(m.z, 0.001)), 0.01, 6.0)))


func _tinte(material: ShaderMaterial, uniforme := "tint") -> Color:
	var dato: Variant = material.get_shader_parameter(uniforme)
	if dato is Color:
		return dato
	if dato is Vector3:
		return Color(dato.x, dato.y, dato.z)
	return Color(1, 1, 1)


static func _srgb_lineal_de_lab(lab: Vector3) -> Vector3:
	var fy := (lab.x + 16.0) / 116.0
	var fx := fy + lab.y / 500.0
	var fz := fy - lab.z / 200.0
	var x := _f_inv(fx) * 0.95047
	var y := _f_inv(fy)
	var z := _f_inv(fz) * 1.08883
	return Vector3(
		3.240479 * x - 1.537150 * y - 0.498535 * z,
		-0.969256 * x + 1.875992 * y + 0.041556 * z,
		0.055648 * x - 0.204043 * y + 1.057311 * z).max(Vector3.ZERO)


static func _f_inv(t: float) -> float:
	return t * t * t if t > 0.206893 else (t - 16.0 / 116.0) / 7.787


func _lab_de(clave: String) -> Vector3:
	if not _referencia.has(clave):
		return Vector3(-1.0, 0.0, 0.0)
	var lab: Array = _referencia[clave]["lab"]
	return Vector3(float(lab[0]), float(lab[1]), float(lab[2]))


func _promedio(labs: Array) -> Vector3:
	var suma := Vector3.ZERO
	var n := 0
	for lab: Vector3 in labs:
		if lab.x >= 0.0:
			suma += lab
			n += 1
	return suma / float(n) if n > 0 else Vector3(-1.0, 0.0, 0.0)


func _nombre_estacion(estacion: Subsistence.Season) -> String:
	return "otono" if estacion == Subsistence.Season.OTONO else "verano"


func _indice(especie: String) -> int:
	for k in range(Forest.KINDS.size()):
		if String(Forest.KINDS[k]["model"]) == especie:
			return k
	return -1


# --- montar el valle ---------------------------------------------------------------------

func _buscar(nodo: Node, nombre: String) -> Node:
	if nodo.name == nombre:
		return nodo
	for hijo: Node in nodo.get_children():
		var hallado := _buscar(hijo, nombre)
		if hallado != null:
			return hallado
	return null


func _buscar_entorno(nodo: Node) -> Node3D:
	if nodo.has_method("get_sun") and nodo.has_method("get_environment"):
		return nodo as Node3D
	for hijo: Node in nodo.get_children():
		var hallado := _buscar_entorno(hijo)
		if hallado != null:
			return hallado
	return null


## La interfaz no la ilumina nada, y en el cuadro cambiaría el fondo entre dos fotos.
func _ocultar_interfaz(nodo: Node) -> void:
	if nodo is CanvasLayer:
		(nodo as CanvasLayer).visible = false
		return
	for hijo: Node in nodo.get_children():
		_ocultar_interfaz(hijo)


func _preparar() -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))
