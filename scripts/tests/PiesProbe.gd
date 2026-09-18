extends SceneTree
## ¿DÓNDE CAEN LOS PIES? Depurar del 2026-09-18: «se hunden en el terreno».
##
## La simulación pone a cada persona con su `position.y` en la cota del terreno, y
## [BandaCrowd] la dibuja ahí: o sea que **el origen del modelo tiene que estar en la planta
## del pie**. Si el pack lo trae en la cadera o en el centro del bulto, la persona se hunde
## media altura y no hay forma de verlo salvo midiéndolo.
##
## Mide DESPUÉS del asiento de [Cuerpo._plantar], que corre cada cuadro: por eso se dejan
## pasar cuadros antes de leer.
##
## Se mide con los huesos del pie, no con la caja de la malla: para una malla con piel la
## `AABB` que devuelve Godot es la de la pose de reposo, no la del clip que se está
## dibujando, así que diría que todo está bien aunque el clip baje al personaje.
##
## Sin valle y sin simulación: aquí sólo se pregunta por la geometría.
##
##   godot --path . --script res://scripts/tests/PiesProbe.gd

## Los clips que se miran: el de estar de pie, los de andar y los que agachan o sientan,
## que son los que podrían bajar el esqueleto por su cuenta.
const CLIPS := ["Idle", "Walk", "Jog_Fwd", "Crouch_Idle", "Fixing_Kneeling",
	"Sitting_Idle", "PickUp_Table", "Sword_Attack", "Idle_Torch", "Push"]
## Los huesos de la planta. `ball_*` es la almohadilla del pie, lo más bajo del esqueleto.
const PIES := ["ball_l", "ball_r", "foot_l", "foot_r"]


## La cota en el mundo de un hueso, o NAN si no está.
func _y(esqueleto: Skeleton3D, hueso: String) -> float:
	var idx := esqueleto.find_bone(hueso)
	if idx < 0:
		return NAN
	return (esqueleto.global_transform * esqueleto.get_bone_global_pose(idx)).origin.y


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(640, 360))
	get_root().size = Vector2i(640, 360)

	var mundo := Node3D.new()
	get_root().add_child(mundo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1

	var cuerpo := Cuerpo.nueva(CatalogoDeCuerpos.Sexo.HOMBRE, Site.Era.PALEOLITICO,
		Inhabitant.Age.ADULTO, rng)
	if cuerpo == null:
		print("PiesProbe: no se monta el cuerpo")
		quit(1)
		return
	mundo.add_child(cuerpo)
	# Donde lo pone la simulación: el origen, en la cota del suelo. El suelo es y = 0.
	cuerpo.poner(Vector3.ZERO, 0.0, Inhabitant.Age.ADULTO)
	await process_frame

	var esqueleto := CatalogoDeCuerpos.buscar(cuerpo, "Skeleton3D") as Skeleton3D
	if esqueleto == null:
		print("PiesProbe: sin esqueleto")
		quit(1)
		return

	print("=== ¿DÓNDE CAEN LOS PIES? · el suelo es y = 0 ===")
	print("%-18s %9s %9s %9s %9s" % ["clip", "pie", "root", "pelvis", "cabeza"])
	for clip: String in CLIPS:
		cuerpo.gesto(clip)
		# Unos cuantos cuadros: el gesto entra con mezcla y la primera pose es la anterior.
		for i in range(25):
			await process_frame
		var bajo := INF
		for hueso: String in PIES:
			var idx := esqueleto.find_bone(hueso)
			if idx < 0:
				continue
			bajo = minf(bajo, (esqueleto.global_transform
				* esqueleto.get_bone_global_pose(idx)).origin.y)
		print("%-18s %9.3f %9.3f %9.3f %9.3f" % [clip, bajo, _y(esqueleto, "root"),
			_y(esqueleto, "pelvis"), _y(esqueleto, "Head")])

	print("")
	print("Si «pie» sale negativo, el modelo se hunde esa cantidad: su origen no está en la")
	print("planta. La simulación pone `position.y` en la cota del terreno (SettlementSim).")
	quit()
