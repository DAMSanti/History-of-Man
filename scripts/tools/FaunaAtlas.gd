extends SceneTree
## Hornea a textura de vértice los ocho bichos base de la fauna.
##
## Ver `VertexAnimBaker.gd` para el cómo -es el mismo horneado que
## `BandaAtlas.gd` usa para la banda, sacado a un sitio común porque aquí hay
## ocho mallas en vez de una-.
##
## No hay una malla por cada una de las doce especies de [Fauna.SPECIES], pero
## la caza mayor ya no anda prestada. El pack «Ultimate Animated Animals» de
## Quaternius —CC0, el mismo autor que el resto de la fauna— trae ciervo, venado
## y toro CON CICLO DE MARCHA, que es justo lo que no tenían cerdo y oveja: ese
## pack de granja sólo horneó reposo y salto, y por eso jabalí, corzo y rebeco
## andaban con las patas quietas. Comprobado uno a uno con
## `scripts/tools/ClipProbe.gd`, no supuesto.
##
## Lo que sigue faltando, y queda declarado en [WildlifeHerds] y en CREDITOS:
##
## - **Cabra montés y rebeco.** No hay bóvido de montaña CC0 descargable por
##   script en ninguno de los packs de Quaternius. El rebeco toma la malla del
##   corzo con otra talla y otro tinte: anda bien y no es una oveja, pero
##   comparte silueta con el corzo.
## - **Jabalí.** Tampoco hay suido con marcha. Toma la del toro, que es lo más
##   parecido que anda: cuerpo bajo y macizo con la cabeza pesada delante.
## - **La cuerna del venado.** El `Stag.fbx` lleva las astas en una malla APARTE,
##   colgada de un hueso, y el horneado a textura de vértice sólo se lleva una
##   malla con pesos. Se hornea el cuerpo; las astas se pierden.
##
## Correr con:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path . \
##     --script res://scripts/tools/FaunaAtlas.gd

const OUT_DIR := "res://models/animals"
const SAMPLING_FPS := 12.0

## Cada entrada es un bicho BASE, no una especie de caza: `WildlifeCrowd`
## decide qué especie usa qué base.
const MODELS := [
	{
		"prefix": "wolf", "source": "res://models/animals/source/Wolf.fbx",
		"armature": "WolfArmature", "mesh": "WolfArmature/Skeleton3D/Wolf",
		"clips": {"idle": "WolfArmature|Idle", "walk": "WolfArmature|Walking"},
	},
	{
		"prefix": "horse", "source": "res://models/animals/source/Horse.fbx",
		"armature": "Armature", "mesh": "Armature/Skeleton3D/Horse",
		"clips": {"idle": "Armature|Idle", "walk": "Armature|Walk", "run": "Armature|Run"},
	},
	{
		"prefix": "cow", "source": "res://models/animals/source/Cow.fbx",
		"armature": "Armature", "mesh": "Armature/Skeleton3D/Cow",
		"clips": {"idle": "Armature|Idle", "walk": "Armature|Walk", "run": "Armature|Run"},
	},
	{
		# Sin marcha propia -el pack de granja sólo trae Idle y Jump, y la
		# versión de la web del autor tampoco: comprobado-. Ya no lo usa
		# ninguna especie de caza mayor; se sigue horneando por si vuelve a
		# hacer falta un bicho de granja.
		"prefix": "pig", "source": "res://models/animals/source/Pig.fbx",
		"armature": "Armature", "mesh": "Armature/Skeleton3D/Pig",
		"clips": {"idle": "Armature|Idle"},
	},
	{
		"prefix": "sheep", "source": "res://models/animals/source/Sheep.fbx",
		"armature": "Armature", "mesh": "Armature/Skeleton3D/Sheep",
		"clips": {"idle": "Armature|Idle"},
	},
	{
		# --- Los tres del pack «Ultimate Animated Animals» ------------------
		#
		# Tienen Walk y Gallop de verdad. Se hornean sólo esos tres clips de los
		# doce que traen: cada clip son otra tanda de columnas en la textura de
		# vértice, y en el juego un animal sólo hace tres cosas -estarse quieto,
		# andar y huir-.
		"prefix": "deer", "source": "res://models/animals/source/Deer.fbx",
		"armature": "AnimalArmature", "mesh": "AnimalArmature/Skeleton3D/Deer",
		"clips": {"idle": "AnimalArmature|Idle", "walk": "AnimalArmature|Walk",
			"run": "AnimalArmature|Gallop"},
	},
	{
		"prefix": "stag", "source": "res://models/animals/source/Stag.fbx",
		"armature": "AnimalArmature", "mesh": "AnimalArmature/Skeleton3D/Stag",
		"clips": {"idle": "AnimalArmature|Idle", "walk": "AnimalArmature|Walk",
			"run": "AnimalArmature|Gallop"},
	},
	{
		# La malla se llama «Cow» dentro del fichero del toro: es el mismo
		# cuerpo con otra cabeza, y ése es el nombre que trae.
		"prefix": "bull", "source": "res://models/animals/source/Bull.fbx",
		"armature": "AnimalArmature", "mesh": "AnimalArmature/Skeleton3D/Cow",
		"clips": {"idle": "AnimalArmature|Idle", "walk": "AnimalArmature|Walk",
			"run": "AnimalArmature|Gallop"},
	},
	{
		"prefix": "eagle", "source": "res://models/animals/source/Eagle.fbx",
		"armature": "EagleArmature", "mesh": "EagleArmature/Skeleton3D/Eagle",
		"clips": {"idle": "EagleArmature|Idle", "fly": "EagleArmature|Flying"},
	},
	{
		"prefix": "bird", "source": "res://models/animals/source/bird.fbx",
		"armature": "Armature", "mesh": "Armature/Skeleton3D/Cylinder",
		"clips": {"idle": "Armature|ArmatureAction"},
	},
	{
		"prefix": "duck", "source": "res://models/animals/source/Duck.glb",
		"armature": "RootNode/Root/Root2", "mesh": "RootNode/Root/Root2/Skeleton3D/Duck",
		"clips": {"idle": "clip"},
	},
]


func _init() -> void:
	for spec: Dictionary in MODELS:
		var animation_list: Dictionary = VertexAnimBaker.bake(
			self, spec["source"], spec["armature"], spec["mesh"], spec["clips"],
			SAMPLING_FPS, OUT_DIR, spec["prefix"], "")
		if animation_list.is_empty():
			print("  FALLO horneando %s" % spec["prefix"])
			continue
		print("  animation_list de %s:" % spec["prefix"])
		for key: String in animation_list:
			var entry: Dictionary = animation_list[key]
			print('    "%s": [%d, %d],' % [key, entry["start_frame"], entry["length"]])
	quit()
