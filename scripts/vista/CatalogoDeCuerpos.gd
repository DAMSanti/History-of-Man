class_name CatalogoDeCuerpos
## DE DÓNDE SALEN LOS CUERPOS DE LA BANDA, y cómo se montan.
##
## Un solo sitio que sabe dónde están los ficheros y qué hay que hacer con ellos, porque
## montar una persona de este pack tiene tres reglas que no se adivinan y que se pagaron con
## capturas (GRAFICOS §5.1):
##
##   1. **La ropa trae su propia piel.** La pieza de brazos lleva dos materiales, el del
##      atuendo y el de la carne. Así que el cuerpo desnudo **no se dibuja**: si se deja,
##      asoma por las costuras.
##   2. **Pero el cuerpo es una sola malla con la cabeza dentro**, así que esconderlo deja a
##      la persona sin cabeza. La cabeza va aparte, partida en frío por
##      `scripts/tools/CabezaSuelta.gd`.
##   3. **Las animaciones son de otro fichero.** Vienen con sus pistas apuntando al
##      esqueleto de su propio maniquí; hay que re-enraizarlas al de cada persona. Los 65
##      huesos son los mismos en los tres packs -comprobado, no supuesto-.
##
## Todo lo que se carga aquí se cachea: las veinticinco personas comparten mallas, texturas
## y **los mismos recursos `Animation`**. Lo único propio de cada una es su `AnimationPlayer`.
##
## Los tres packs son CC0 de Quaternius; ver `docs/CREDITOS.md`.

const RAIZ := "res://models/people/universal"
const CUERPO := RAIZ + "/cuerpos/Superhero_%s_FullBody.gltf"
const CABEZA := RAIZ + "/cuerpos/cabeza_%s.res"
const ANIMACIONES := RAIZ + "/animaciones/AL_Standard.fbx"

## A cuánto se dibuja una persona adulta. El pack viene en otra escala, así que se mide la
## caja del modelo y se lleva a esto.
const ALTO_M := 1.70

## El hueso del que cuelga lo que se lleva en la mano. Con esqueleto de verdad esto es un
## `BoneAttachment3D` y ya está: no hace falta hornear la pose de la mano como hacía falta
## con la animación en textura.
const MANO := "hand_r"

enum Sexo { HOMBRE, MUJER }

static var _escenas: Dictionary = {}
static var _biblioteca: AnimationLibrary = null
static var _escala: Dictionary = {}


static func sufijo(sexo: int) -> String:
	return "Female" if sexo == Sexo.MUJER else "Male"


static func mote(sexo: int) -> String:
	return "female" if sexo == Sexo.MUJER else "male"


## La escena del cuerpo, cacheada. Trae el esqueleto, los ojos y las cejas.
static func cuerpo(sexo: int) -> PackedScene:
	return _cache(CUERPO % sufijo(sexo))


static func cabeza(sexo: int) -> ArrayMesh:
	var ruta := CABEZA % mote(sexo)
	if not _escenas.has(ruta):
		_escenas[ruta] = load(ruta)
	return _escenas[ruta] as ArrayMesh


## Una pieza de ropa o de pelo. `carpeta` es «ropa» o «pelo».
static func pieza(carpeta: String, nombre: String) -> PackedScene:
	return _cache("%s/%s/%s.gltf" % [RAIZ, carpeta, nombre])


## Cuánto hay que escalar el modelo para que mida [constant ALTO_M]. Se mide una vez por
## sexo sobre la caja del modelo en reposo.
static func escala(sexo: int) -> float:
	if _escala.has(sexo):
		return _escala[sexo]
	var escena := cuerpo(sexo)
	var valor := 1.0
	if escena != null:
		var raiz := escena.instantiate()
		var caja := AABB()
		var primera := true
		for m in mallas(raiz):
			var aabb: AABB = (m as MeshInstance3D).get_aabb()
			caja = aabb if primera else caja.merge(aabb)
			primera = false
		if caja.size.y > 0.001:
			valor = ALTO_M / caja.size.y
		raiz.queue_free()
	_escala[sexo] = valor
	return valor


## Las cuarenta y cinco animaciones, con las pistas apuntando a `esqueleto` colgando de
## `raiz`. **Se construye una sola vez**: los `Animation` se comparten entre las veinticinco
## personas y sólo el reproductor es de cada una, que es lo que hace que esto quepa.
##
## Las rutas son las mismas para todos porque todos se montan igual —mismo árbol, mismo
## nombre de nodo—; si algún día dejaran de serlo, esta caché sería un fallo silencioso.
static func biblioteca(ruta_al_esqueleto: NodePath) -> AnimationLibrary:
	if _biblioteca != null:
		return _biblioteca
	var fuente: PackedScene = _cache(ANIMACIONES)
	if fuente == null:
		push_error("CatalogoDeCuerpos: no carga %s" % ANIMACIONES)
		return AnimationLibrary.new()
	var escena := fuente.instantiate()
	var player := buscar(escena, "AnimationPlayer") as AnimationPlayer
	var lib := AnimationLibrary.new()
	for nombre: String in player.get_animation_list():
		var anim: Animation = player.get_animation(nombre).duplicate(true)
		# SÓLO LAS ROTACIONES. El FBX de animaciones trae la pose de reposo **aplastada**
		# —medido: `pelvis` a 0,0005 m y `Head` a −0,0001, con todos los huesos encima del
		# origen—, que es justo el fallo del que avisa el propio pack en su léeme: «known
		# scaling bug when importing rigged FBXs from Blender». Sus pistas de POSICIÓN
		# llevan esa geometría rota dentro, y aplicarlas dejaba a la persona con la pelvis
		# a 8 mm del suelo y **los pies 83 cm por debajo**: hundida hasta la cintura.
		#
		# Las rotaciones sí valen, porque no tienen unidades ni dependen del reposo: las
		# posturas se leían bien —arrodillarse, andar, lanzar— aunque el cuerpo estuviera
		# aplastado. Así que se quedan ésas y **las longitudes de hueso salen del esqueleto
		# del cuerpo**, que sí está sano (pelvis 0,949 m, cabeza 1,600 m, planta 0,015 m).
		# Es lo mismo que hace el «rest fixer» de Godot al reorientar un rig.
		#
		# Lo que se pierde es el balanceo vertical de la cadera, que en estos clips era de
		# milímetros de basura. Ver `scripts/tests/PiesProbe.gd`, que lo mide.
		for t in range(anim.get_track_count() - 1, -1, -1):
			if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				anim.remove_track(t)
		for t in range(anim.get_track_count()):
			var hueso := anim.track_get_path(t).get_concatenated_subnames()
			anim.track_set_path(t, NodePath("%s:%s" % [ruta_al_esqueleto, hueso]))
		# El FBX las trae sin bucle: sin esto, cada clip se para en su último fotograma y
		# la banda entera se queda congelada a los dos segundos.
		anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(corto(nombre), anim)
	escena.queue_free()
	_biblioteca = lib
	return lib


## El nombre que usa el juego: el FBX los trae como «Rig|Walk».
static func corto(nombre: String) -> String:
	return nombre.get_slice("|", 1) if "|" in nombre else nombre


## LAS CEJAS SE RECORTAN, no se pintan enteras. Cuarta regla del pack que no se adivina.
##
## Las cejas y las pestañas son **cartas**: un cuadrilátero con la forma dibujada en la
## textura y el resto en transparente. El glTF del pack las trae con `alphaMode` OPACO, así
## que Godot las importa sin recorte y lo que se ve es el cuadrilátero entero: **una banda
## oscura cruzando los ojos, como un antifaz**. Visto en captura con `AperosCaptura` el
## 2026-09-19, después de que el usuario dijera «algunos miembros de la banda no tienen
## texturas en las cejas» — no era falta de textura, era el fondo de la carta.
##
## Se corrige con recorte por alfa y no con mezcla: una carta de pelo mezclada se ordena mal
## contra la cara y parpadea al girar la cámara. El material corregido se cachea por
## material de origen, así que las veinticinco personas comparten dos copias, no cincuenta.
static func cejas_que_se_recortan(mi: MeshInstance3D) -> void:
	if mi == null or mi.mesh == null:
		return
	for s in range(mi.mesh.get_surface_count()):
		var base := mi.mesh.surface_get_material(s)
		if base == null:
			continue
		var clave := "recorte_%d" % base.get_instance_id()
		if not _escenas.has(clave):
			var copia := base.duplicate()
			if copia is BaseMaterial3D:
				var m := copia as BaseMaterial3D
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				# Medio: la carta del pack tiene el borde difuminado y con un umbral alto
				# las cejas salen deshilachadas.
				m.alpha_scissor_threshold = 0.5
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			_escenas[clave] = copia
		mi.set_surface_override_material(s, _escenas[clave])


static func mallas(nodo: Node) -> Array[Node]:
	var out: Array[Node] = []
	if nodo is MeshInstance3D:
		out.append(nodo)
	for h in nodo.get_children():
		out.append_array(mallas(h))
	return out


static func buscar(nodo: Node, clase: String) -> Node:
	if nodo.get_class() == clase:
		return nodo
	for h in nodo.get_children():
		var f := buscar(h, clase)
		if f != null:
			return f
	return null


static func _cache(ruta: String) -> PackedScene:
	if not _escenas.has(ruta):
		_escenas[ruta] = load(ruta)
	return _escenas[ruta] as PackedScene
