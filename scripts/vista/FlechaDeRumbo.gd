class_name FlechaDeRumbo
extends MeshInstance3D
## La flecha del rumbo de una expedición, antes de mandarla.
##
## INTERFAZ §4: «sale una flecha con el pasillo que se va a recorrer». En el mapa
## regional se dibuja **el pasillo mismo** —el [Pasillo] de la ficha, que es el
## que se descubrirá—; en el valle, donde el pasillo no cabe, la dirección desde
## la cueva hasta la puerta por la que saldrían.

const COLOR := Color(0.851, 0.588, 0.267, 0.45)
const COLOR_DEL_EJE := Color(0.851, 0.588, 0.267, 0.95)

## El pasillo que se dibujó por última vez en el mapa regional.
var pasillo: Pasillo = null


func _init() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material_override = material


## El pasillo sobre el relieve regional: la franja de su ancho, el eje y la punta.
## `alzado`, en unidades del mundo, por encima del relieve.
func trazar_pasillo(terreno: TerrainGenerator, recorrido: Pasillo, alzado: float) -> void:
	pasillo = recorrido
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tramos := maxi(int(recorrido.largo_m / 1000.0), 1)
	var coseno := cos(deg_to_rad(recorrido.lat))
	var este := sin(deg_to_rad(recorrido.rumbo))
	var norte := cos(deg_to_rad(recorrido.rumbo))
	# A la derecha del rumbo, en grados.
	var lado := Vector2(norte * Pasillo.MEDIO_ANCHO_M / (Viaje.METROS_POR_GRADO * coseno),
		-este * Pasillo.MEDIO_ANCHO_M / Viaje.METROS_POR_GRADO)
	var eje := lado * 0.12
	for i in range(tramos):
		var a := _punto(recorrido, float(i) / float(tramos))
		var b := _punto(recorrido, float(i + 1) / float(tramos))
		_franja(st, terreno, a, b, lado, alzado, COLOR)
		_franja(st, terreno, a, b, eje, alzado * 1.2, COLOR_DEL_EJE)
	# La punta, donde se da la vuelta.
	var fin := Vector2(recorrido.fin_lon, recorrido.fin_lat)
	var delante := Vector2(este * 2.0 * Pasillo.MEDIO_ANCHO_M / (Viaje.METROS_POR_GRADO * coseno),
		norte * 2.0 * Pasillo.MEDIO_ANCHO_M / Viaje.METROS_POR_GRADO)
	_triangulo(st, terreno, fin + lado * 1.6, fin - lado * 1.6, fin + delante,
		alzado * 1.2, COLOR_DEL_EJE)
	mesh = st.commit()


## La dirección en el valle: de la cueva a la puerta del valle, con punta.
func trazar_rumbo(terreno: TerrainGenerator, desde: Vector3, hasta: Vector3) -> void:
	pasillo = null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plano := Vector3(hasta.x - desde.x, 0.0, hasta.z - desde.z)
	var largo := plano.length()
	if largo < 1.0:
		mesh = null
		return
	var direccion := plano / largo
	var lado := Vector3(-direccion.z, 0.0, direccion.x) * 6.0
	var tramos := maxi(int(largo / 40.0), 1)
	for i in range(tramos):
		var a := desde + plano * float(i) / float(tramos)
		var b := desde + plano * float(i + 1) / float(tramos)
		a.y = terreno.get_height_at(a) + 3.0
		b.y = terreno.get_height_at(b) + 3.0
		_quad(st, a - lado, a + lado, b + lado, b - lado, COLOR_DEL_EJE)
	var punta := hasta + direccion * 40.0
	punta.y = terreno.get_height_at(punta) + 3.0
	var base := hasta
	base.y = terreno.get_height_at(base) + 3.0
	st.set_color(COLOR_DEL_EJE)
	st.add_vertex(base - lado * 3.0)
	st.add_vertex(base + lado * 3.0)
	st.add_vertex(punta)
	mesh = st.commit()


static func _punto(recorrido: Pasillo, t: float) -> Vector2:
	return Vector2(lerpf(recorrido.lon, recorrido.fin_lon, t),
		lerpf(recorrido.lat, recorrido.fin_lat, t))


func _sobre(terreno: TerrainGenerator, geo: Vector2, alzado: float) -> Vector3:
	var p := terreno.geo_to_world(geo.x, geo.y)
	p.y += alzado
	return p


func _franja(st: SurfaceTool, terreno: TerrainGenerator, a: Vector2, b: Vector2,
		lado: Vector2, alzado: float, color: Color) -> void:
	_quad(st, _sobre(terreno, a - lado, alzado), _sobre(terreno, a + lado, alzado),
		_sobre(terreno, b + lado, alzado), _sobre(terreno, b - lado, alzado), color)


func _triangulo(st: SurfaceTool, terreno: TerrainGenerator, a: Vector2, b: Vector2,
		c: Vector2, alzado: float, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(_sobre(terreno, a, alzado))
	st.add_vertex(_sobre(terreno, b, alzado))
	st.add_vertex(_sobre(terreno, c, alzado))


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
