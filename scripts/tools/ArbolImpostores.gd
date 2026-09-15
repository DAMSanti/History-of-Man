extends SceneTree
## Hornea los impostores de varias vistas de los árboles 3D. GRAFICOS §7.1.
##
## **Con ventana**: se fotografía con el render de verdad.
##
##   godot --path . --script res://scripts/tools/ArbolImpostores.gd
##
## De cada árbol, `ImpostorVistas.VISTAS²` fotos desde la semiesfera de arriba, en
## dos atlas: **color con alfa** y **normal** en el marco del árbol, con **qué es hoja**
## en el alfa del de normales —ver `SHADER_HOJA`—. Con luz blanca
## plana y sin sol, como `TreeAtlas`: se guarda el color propio, y la luz la pone el
## shader en la partida. Deja `models/arboles/impostores/<especie>_<variante>_{color,normal}.res`.
##
## **Las seis variantes, no tres** (se probó con tres el 2026-09-15): si el 3D es la
## variante 3 y su impostor la 0, al cruzar la distancia de relevo cambia de forma.

const ESPECIES := ["pino", "pino_joven", "abedul", "roble", "avellano"]
const VARIANTES_CON_IMPOSTOR := 6
const DESTINO := "res://models/arboles/impostores"
## Se hace cada foto al doble y se reduce: sale suavizada sin pagar antialiasing.
const SOBREMUESTREO := 2

const SHADER_COLOR := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform float recorte = 0.5;
void fragment() {
	vec4 c = texture(textura, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = recorte;
}
"""

## Qué es hoja: 1 en la superficie de hoja y 0 en la de corteza. El impostor no tiene
## otra forma de saberlo, y lo necesita para teñir cada una con su color —separarlas
## «por lo verde» fallaba con la aguja del pino, que es oliva oscuro—.
const SHADER_HOJA := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform float recorte = 0.5;
uniform float es_hoja = 0.0;
void fragment() {
	vec4 c = texture(textura, UV);
	ALBEDO = vec3(es_hoja);
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = recorte;
}
"""

const SHADER_NORMAL := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D textura : source_color, filter_linear_mipmap;
uniform float recorte = 0.5;
varying vec3 normal_local;
void vertex() {
	normal_local = NORMAL;
}
void fragment() {
	vec4 c = texture(textura, UV);
	vec3 n = normalize(normal_local) * (FRONT_FACING ? 1.0 : -1.0);
	ALBEDO = n * 0.5 + 0.5;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = recorte;
}
"""


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DESTINO)
	var vista := SubViewport.new()
	var lado := ImpostorVistas.PIXELES * SOBREMUESTREO
	vista.size = Vector2i(lado, lado)
	vista.transparent_bg = true
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_4X
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	entorno.environment = env
	vista.add_child(entorno)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	vista.add_child(camara)
	camara.current = true
	var nodo := MeshInstance3D.new()
	vista.add_child(nodo)

	for especie: String in ESPECIES:
		for v in range(VARIANTES_CON_IMPOSTOR):
			# SALTA LO HECHO: la tanda entera son varios minutos con ventana, y si se
			# corta —el 2026-09-15 se cerró la ventana a mano a mitad— el siguiente
			# arranque sigue donde se quedó. Para rehornear todo, REHORNEAR=1.
			if FileAccess.file_exists("%s/%s_%d.json" % [DESTINO, especie, v]) 					and not OS.get_environment("REHORNEAR") == "1":
				continue
			var modelo: ArbolModelo = load(ArbolModelo.ruta(especie, v))
			var malla := modelo.niveles[0]
			nodo.mesh = malla
			var caja := malla.get_aabb()
			var centro := caja.get_center()
			var radio := maxf(maxf(caja.size.x, caja.size.z), caja.size.y) * 0.5 * 1.04
			camara.size = radio * 2.0
			camara.far = radio * 6.0
			var atlas_color := Image.create(ImpostorVistas.VISTAS * ImpostorVistas.PIXELES,
				ImpostorVistas.VISTAS * ImpostorVistas.PIXELES, false, Image.FORMAT_RGBA8)
			var atlas_normal := Image.create(atlas_color.get_width(), atlas_color.get_height(),
				false, Image.FORMAT_RGBA8)
			var atlas_hoja := Image.create(atlas_color.get_width(), atlas_color.get_height(),
				false, Image.FORMAT_RGBA8)
			for pase: String in ["color", "normal", "hoja"]:
				_poner_materiales(nodo, malla, pase)
				for j in range(ImpostorVistas.VISTAS):
					for i in range(ImpostorVistas.VISTAS):
						var dir := ImpostorVistas.direccion_de(i, j)
						var base := ImpostorVistas.base_de(dir)
						camara.global_transform = Transform3D(
							Basis(base[0], base[1], dir), centro + dir * radio * 3.0)
						await process_frame
						await process_frame
						var foto := vista.get_texture().get_image()
						foto.resize(ImpostorVistas.PIXELES, ImpostorVistas.PIXELES,
							Image.INTERPOLATE_LANCZOS)
						foto.convert(Image.FORMAT_RGBA8)
						var destino: Image = {"color": atlas_color, "normal": atlas_normal,
							"hoja": atlas_hoja}[pase]
						destino.blit_rect(foto, Rect2i(Vector2i.ZERO, foto.get_size()),
							Vector2i(i, j) * ImpostorVistas.PIXELES)
			# El alfa del de normales lleva QUÉ ES HOJA: el recorte ya lo da el de color.
			for y in range(atlas_color.get_height()):
				for x in range(atlas_color.get_width()):
					var n := atlas_normal.get_pixel(x, y)
					n.a = atlas_hoja.get_pixel(x, y).r
					atlas_normal.set_pixel(x, y, n)
			ResourceSaver.save(atlas_color, "%s/%s_%d_color.res" % [DESTINO, especie, v],
				ResourceSaver.FLAG_COMPRESS)
			ResourceSaver.save(atlas_normal, "%s/%s_%d_normal.res" % [DESTINO, especie, v],
				ResourceSaver.FLAG_COMPRESS)
			atlas_color.save_png("user://capturas/impostor_%s_%d.png" % [especie, v])
			var ficha := {"radio": radio, "centro_y": centro.y}
			FileAccess.open("%s/%s_%d.json" % [DESTINO, especie, v], FileAccess.WRITE) \
				.store_string(JSON.stringify(ficha))
			print("  %s %d · radio %.2f m · centro %.2f m" % [especie, v, radio, centro.y])
	quit()


func _poner_materiales(nodo: MeshInstance3D, malla: Mesh, pase: String) -> void:
	var shader := Shader.new()
	shader.code = {"color": SHADER_COLOR, "normal": SHADER_NORMAL, "hoja": SHADER_HOJA}[pase]
	for s in range(malla.get_surface_count()):
		var original := malla.surface_get_material(s) as StandardMaterial3D
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("textura", original.albedo_texture)
		# La superficie 1 es la hoja: así las escribe `ArbolesImport`.
		m.set_shader_parameter("es_hoja", 1.0 if s == 1 else 0.0)
		m.set_shader_parameter("recorte",
			original.alpha_scissor_threshold
			if original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0)
		nodo.set_surface_override_material(s, m)
