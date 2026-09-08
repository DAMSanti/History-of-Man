class_name BandaCrowd
extends Node3D
## La banda entera, dibujada como UN MultiMesh por variante de piel.
##
## `SettlementSim` tenía un `Node3D` con una cápsula por persona -veinticinco
## está bien, pero el aviso del propio `Inhabitant.gd` dice que esto puede
## llegar a los miles, y ahí un nodo por persona no aguanta: es memoria de
## escena y una llamada de dibujo por cabeza.
##
## La salida es la misma que `Forest` usa para los árboles: un solo dibujo
## para todos, y la pose de cada uno sale de una TEXTURA DE VÉRTICE horneada
## en frío por `scripts/tools/BandaAtlas.gd` -ver ese fichero para el cómo y
## el porqué del horneado-. El coste de animar pasa entero a la GPU; la CPU
## sólo pone la transformada y el nombre del estado de cada persona.
##
## El addon `AnimatedMultiMeshInstance3D` (en `addons/animated_multimeshinstance3d`)
## pone el shader y el `play()`; lo que hornea el horneador de este proyecto
## es sólo la textura, porque el botón de hornear del addon es de editor y
## esto tiene que poder correr en una partida sin abrir Godot.

const MESH_PATH := "res://models/people/banda_mesh.res"
const SKIN_MATERIALS := [
	"res://models/people/banda_material_ClothedLightSkin.tres",
	"res://models/people/banda_material_ClothedDarkSkin.tres",
	"res://models/people/banda_material_NakedLightSkin.tres",
	"res://models/people/banda_material_NakedDarkSkin.tres",
]

## Fotograma de inicio y longitud de cada clip, calculados por
## `BandaAtlas.gd` y pegados aquí a mano: son los mismos siete cuerpos
## siempre que no se vuelva a hornear, y no vale la pena leer un recurso
## aparte sólo para esto.
const CLIPS := {
	"idle": [0, 120],
	"walk": [120, 13],
	"run": [133, 8],
	"jump": [141, 12],
	"punch": [153, 13],
	"work": [166, 78],
	"death": [244, 43],
}

## Cuánto mide el bulto horneado antes de escalarlo, en metros: la altura de
## la caja de la malla en reposo -T-pose- multiplicada por el x69,18 que
## trae el nodo «Human Armature» del FBX. Es de origen, no un número puesto
## a ojo -ver `models/people/source/Animated Human.fbx`, hereda escala de
## exportar el rig en centímetros desde Blender-, y se corrige aquí a la
## escala real del juego (`docs/REVAMP_GRAFICO.md` §4: 1,70 m).
const _MEASURED_BAKE_HEIGHT_M := 5.535281
const TARGET_HEIGHT_M := 1.70
const HEIGHT_SCALE := TARGET_HEIGHT_M / _MEASURED_BAKE_HEIGHT_M

## Por [Inhabitant.Age]. La cápsula que había sí distinguía niño de adulto
## -2,1 m contra 3,2 m, ver el `_make_body` que quitó este fichero-; perderlo
## sería un paso atrás, no una simplificación.
const AGE_SCALE := {
	0: 0.6,  # NINO
	1: 1.0,  # ADULTO
	2: 0.95, # ANCIANO: encogido, no infantil
}

## Qué estado de [Inhabitant] usa qué clip. `DURMIENDO` y `COMIENDO` caen en
## reposo porque no hay clip propio todavía -ver docs/REVAMP_GRAFICO.md, G6-;
## cuando lo haya, sólo cambia esta tabla.
const STATE_CLIP := {
	0: "idle",  # DURMIENDO
	1: "walk",  # YENDO
	2: "walk",  # BUSCANDO
	3: "work",  # TRABAJANDO
	4: "walk",  # VOLVIENDO
	5: "idle",  # COMIENDO
	6: "idle",  # OCIOSO
	7: "walk",  # RECONOCIENDO
}

var _groups: Array[AnimatedMultiMeshInstance3D] = []
var _counts: Array[int] = []
var _rng := RandomNumberGenerator.new()


func setup(capacity: int) -> void:
	_rng.randomize()
	var mesh: ArrayMesh = load(MESH_PATH)
	if mesh == null:
		push_error("BandaCrowd: falta %s; ¿se corrió BandaAtlas.gd?" % MESH_PATH)
		return

	# Cada grupo se reserva para la banda ENTERA, no para una cuarta parte.
	# El reparto por piel es un sorteo persona a persona, así que por puro
	# azar un grupo puede tocarle a mucho más de un cuarto -con quince
	# personas ya salió un 5/4/1/5-, y `instance_count` no se toca nunca más
	# despues de aqui: cambiarlo BORRA las transformadas ya puestas de todo
	# el grupo, no sólo añade hueco. Lo que crece con cada alta es
	# `visible_instance_count`, que no tiene ese efecto.
	for skin_path in SKIN_MATERIALS:
		var node := AnimatedMultiMeshInstance3D.new()
		node.name = "Banda_%s" % skin_path.get_file().get_basename()
		node.material_override = load(skin_path)
		node.sampling_fps = 12.0
		var multi := MultiMesh.new()
		multi.mesh = mesh
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.instance_count = maxi(capacity, 1)
		multi.visible_instance_count = 0
		node.multimesh = multi
		for key: String in CLIPS:
			var entry: Array = CLIPS[key]
			node.animation_list[key] = MultimeshAnimationData.new().set_values(
				entry[0], entry[1])
		add_child(node)
		_groups.append(node)
		_counts.append(0)


## Da de alta a una persona nueva y devuelve su sitio en la multitud, que
## luego hace falta pasarle a [update] cada vez que se mueve o cambia de
## estado. `Vector2i(grupo, indice)`: el grupo es la variante de piel -da
## igual cuál, es sólo variedad visual-, el índice es su hueco dentro de ese
## `MultiMesh`.
func add_person() -> Vector2i:
	var group := _rng.randi() % maxi(_groups.size(), 1)
	var index := _counts[group]
	_counts[group] += 1
	var multi := _groups[group].multimesh
	if index >= multi.instance_count:
		# `capacity` se quedó corta -se dio de alta más gente de la que
		# `setup` reservó-. Aquí SÍ hay que estirar `instance_count`, con el
		# coste de perder las transformadas puestas hasta ahora en este
		# grupo; quien llame a esto sabe que es el caso raro, no el normal.
		multi.instance_count = index + 1
	multi.visible_instance_count = index + 1
	return Vector2i(group, index)


## Al fotograma: sitúa a la persona y le pone el clip de su estado actual.
## `heading` es el ángulo alrededor de Y hacia el que mira, en radianes.
func update(slot: Vector2i, position: Vector3, heading: float, state: int,
		age: int = 1) -> void:
	if slot.x < 0 or slot.x >= _groups.size():
		return
	var scale: float = HEIGHT_SCALE * float(AGE_SCALE.get(age, 1.0))
	var basis := Basis(Vector3.UP, heading).scaled(Vector3.ONE * scale)
	_groups[slot.x].multimesh.set_instance_transform(
		slot.y, Transform3D(basis, position))
	_groups[slot.x].play(slot.y, STATE_CLIP.get(state, "idle"))
