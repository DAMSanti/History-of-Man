class_name NieblaDeValle
extends MeshInstance3D
## La niebla de valle: nubes bajas con volumen que se quedan en el fondo del valle y no en
## lo alto (GRAFICOS §7.4).
##
## **Una caja sobre el valle** con un shader que la recorre por dentro
## (`niebla_de_valle.gdshader`) y se corta con la profundidad de la escena. Lo que decide
## la densidad está aquí, en GDScript, para poderlo probar: **el fondo del valle**, que
## se hornea al montar, y **el perfil**, que la apaga con la altura sobre ese fondo. El
## shader lo recibe como textura y uniformes y no repite la cuenta del fondo.
##
## Es vista: no toca la partida. Sale sólo con niebla ([ClimaEnPantalla.hay_niebla_de_valle]).

## Cuántos metros sobre el fondo del valle es niebla entera, y a cuántos se ha apagado ya.
## Decisión aceptada por el usuario el 2026-09-16 («unos 60 m»); se ajusta con captura.
const ESPESOR_M := 60.0
const SE_APAGA_M := 120.0

## Hasta dónde se busca lo más bajo para decir cuál es el fondo del valle, en metros. Lo
## bastante para que una ladera tome el fondo de su valle y no su propio pie.
const RADIO_DEL_FONDO_M := 500.0

## El lado de la celda del fondo horneado, en metros: la niebla no necesita más detalle.
const CELDA_M := 50.0

## Desde cuánta densidad se da la cámara por metida en la niebla.
const DENTRO_DESDE := 0.35

## El fondo del valle por celda, en metros, y dónde empieza y cuántas celdas tiene de lado.
var fondo := PackedFloat32Array()
var celdas := 0
var origen := Vector2.ZERO
var lado_m := 0.0

## Cuánta niebla hay ahora, de 0 a 1, y cuánta se quiere: entra y sale despacio.
var fuerza := 0.0
var objetivo := 0.0

var _material: ShaderMaterial = null


## Hornea el fondo del valle del terreno y monta la caja. Unos milisegundos: sesenta y
## tantas celdas por lado y un mínimo en dos pasadas (fila y columna).
func montar(terreno: TerrainGenerator) -> void:
	name = "NieblaDeValle"
	hornear(terreno)
	_montar_la_caja()
	visible = false


## El fondo del valle: por celda, la cota más baja a [RADIO_DEL_FONDO_M], suavizada.
func hornear(terreno: TerrainGenerator) -> void:
	var inicio := terreno._origen()
	origen = Vector2(inicio.x, inicio.z)
	lado_m = float(maxi(terreno.terrain_size.x, terreno.terrain_size.y))
	celdas = maxi(int(ceil(lado_m / CELDA_M)) + 1, 2)
	var paso := lado_m / float(celdas - 1)
	var alturas := PackedFloat32Array()
	alturas.resize(celdas * celdas)
	for z in range(celdas):
		for x in range(celdas):
			alturas[z * celdas + x] = terreno.get_height_at(
				Vector3(origen.x + float(x) * paso, 0.0, origen.y + float(z) * paso))
	var radio := int(ceil(RADIO_DEL_FONDO_M / paso))
	# Un mínimo cuadrado en dos pasadas: por filas y luego por columnas.
	var por_filas := _minimo(alturas, radio, true)
	fondo = _suavizar(_minimo(por_filas, radio, false))


## La cota del fondo del valle bajo un punto del mundo, en metros.
func fondo_en(x: float, z: float) -> float:
	if fondo.is_empty():
		return 0.0
	var paso := lado_m / float(celdas - 1)
	var fx := clampf((x - origen.x) / paso, 0.0, float(celdas - 1))
	var fz := clampf((z - origen.y) / paso, 0.0, float(celdas - 1))
	var x0 := mini(int(fx), celdas - 2)
	var z0 := mini(int(fz), celdas - 2)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var arriba := lerpf(fondo[z0 * celdas + x0], fondo[z0 * celdas + x0 + 1], tx)
	var abajo := lerpf(fondo[(z0 + 1) * celdas + x0], fondo[(z0 + 1) * celdas + x0 + 1], tx)
	return lerpf(arriba, abajo, tz)


## Cuánta niebla hay a `sobre_el_fondo_m` metros por encima del fondo: entera hasta
## [ESPESOR_M] y apagada a [SE_APAGA_M]. Por debajo del fondo, entera.
static func perfil(sobre_el_fondo_m: float) -> float:
	return 1.0 - smoothstep(ESPESOR_M, SE_APAGA_M, sobre_el_fondo_m)


## La densidad de la niebla en un punto del mundo ahora mismo, de 0 a 1.
func densidad(punto: Vector3) -> float:
	return fuerza * perfil(punto.y - fondo_en(punto.x, punto.z))


## Si un punto —la cámara— está metido en la niebla. Es lo que empaña la imagen.
func dentro(punto: Vector3) -> bool:
	return densidad(punto) > DENTRO_DESDE


## Que haya niebla o no: entra y sale en unos segundos.
func poner(hay: bool) -> void:
	objetivo = 1.0 if hay else 0.0


## La deja sin niebla al momento: el clima apagado no espera a que se vaya.
func quitar() -> void:
	objetivo = 0.0
	fuerza = 0.0
	visible = false


func _process(delta: float) -> void:
	fuerza = move_toward(fuerza, objetivo, delta * 0.25)
	visible = fuerza > 0.001
	if _material != null:
		_material.set_shader_parameter("fuerza", fuerza)


func _montar_la_caja() -> void:
	var bajo := INF
	var alto := -INF
	for cota: float in fondo:
		bajo = minf(bajo, cota)
		alto = maxf(alto, cota)
	var caja := BoxMesh.new()
	var alto_de_la_caja := (alto - bajo) + SE_APAGA_M + 20.0
	caja.size = Vector3(lado_m, alto_de_la_caja, lado_m)
	mesh = caja
	position = Vector3(origen.x + lado_m * 0.5, bajo - 10.0 + alto_de_la_caja * 0.5, origen.y + lado_m * 0.5)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Y que no la recorte la distancia de la caja: se ve desde fuera y desde dentro.
	extra_cull_margin = lado_m
	var imagen := Image.create_from_data(celdas, celdas, false, Image.FORMAT_RF, fondo.to_byte_array())
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/niebla_de_valle.gdshader") as Shader
	_material.set_shader_parameter("fondo_tex", ImageTexture.create_from_image(imagen))
	_material.set_shader_parameter("origen", origen)
	_material.set_shader_parameter("lado", lado_m)
	_material.set_shader_parameter("espesor", ESPESOR_M)
	_material.set_shader_parameter("se_apaga", SE_APAGA_M)
	_material.set_shader_parameter("caja_min", Vector3(origen.x, bajo - 10.0, origen.y))
	_material.set_shader_parameter("caja_max", Vector3(origen.x + lado_m, bajo - 10.0 + alto_de_la_caja, origen.y + lado_m))
	material_override = _material


static func _minimo(valores: PackedFloat32Array, radio: int, por_filas: bool) -> PackedFloat32Array:
	var lado := int(sqrt(float(valores.size())))
	var salida := PackedFloat32Array()
	salida.resize(valores.size())
	for a in range(lado):
		for b in range(lado):
			var menor := INF
			for d in range(maxi(b - radio, 0), mini(b + radio, lado - 1) + 1):
				var i := a * lado + d if por_filas else d * lado + a
				menor = minf(menor, valores[i])
			salida[a * lado + b if por_filas else b * lado + a] = menor
	return salida


static func _suavizar(valores: PackedFloat32Array) -> PackedFloat32Array:
	var lado := int(sqrt(float(valores.size())))
	var salida := valores.duplicate()
	for z in range(lado):
		for x in range(lado):
			var suma := 0.0
			var cuantas := 0
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx
					var zz := z + dz
					if xx >= 0 and zz >= 0 and xx < lado and zz < lado:
						suma += valores[zz * lado + xx]
						cuantas += 1
			salida[z * lado + x] = suma / float(cuantas)
	return salida
