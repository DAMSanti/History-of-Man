class_name TestBandaClips
extends TestCase
## NADIE SE QUEDA EN POSE T, NINGÚN OFICIO SIN GESTO Y NINGUNA ERA SIN ROPA.
##
## Es la red que pide GRAFICOS §5.1. La tabla de [ClipsDeLaBanda] reparte veinte
## especialidades entre once gestos y siete aperos, y [Vestuario] cinco eras entre dos
## atuendos: el modo de fallar de tablas así no es reventar, es que a una línea se le
## escriba mal el nombre del clip y esa persona se quede plantada sin que nadie se entere.
##
## Por eso las pruebas no se conforman con que la tabla tenga la entrada: **comprueban que
## lo que dice existe de verdad** —el clip, en la biblioteca de animaciones; la malla del
## apero; el fichero de cada pieza de ropa—.


func suite_name() -> String:
	return "Banda: gestos y ropa"


## Los nombres de los cuarenta y cinco clips del pack, leídos del fichero. Se hace una vez
## por corrida: abrir el FBX cuesta, y la respuesta no cambia entre pruebas.
static var _clips: PackedStringArray = PackedStringArray()


func _horneados() -> PackedStringArray:
	if not _clips.is_empty():
		return _clips
	var escena: PackedScene = load(CatalogoDeCuerpos.ANIMACIONES)
	if escena == null:
		return _clips
	var raiz := escena.instantiate()
	var player := CatalogoDeCuerpos.buscar(raiz, "AnimationPlayer") as AnimationPlayer
	if player != null:
		for n: String in player.get_animation_list():
			_clips.append(CatalogoDeCuerpos.corto(n))
	raiz.queue_free()
	return _clips


func test_la_biblioteca_de_animaciones_esta() -> void:
	assert_gt(float(_horneados().size()), 30.0,
		"el pack de animaciones trae sus clips")


func test_todo_estado_tiene_gesto_y_el_gesto_existe() -> void:
	var hay := _horneados()
	for estado: int in Inhabitant.State.values():
		var nombre := ClipsDeLaBanda.clip(estado, Profession.Speciality.NINGUNA)
		assert_false(nombre.is_empty(), "el estado %d tiene gesto" % estado)
		assert_true(hay.has(nombre),
			"y el gesto «%s» del estado %d existe en el pack" % [nombre, estado])


func test_toda_especialidad_tiene_gesto_y_el_gesto_existe() -> void:
	var hay := _horneados()
	for especialidad: int in Profession.Speciality.values():
		assert_true(ClipsDeLaBanda.POR_ESPECIALIDAD.has(especialidad),
			"la especialidad %d tiene línea en la tabla de gestos" % especialidad)
		var nombre := ClipsDeLaBanda.clip(Inhabitant.State.TRABAJANDO, especialidad)
		assert_true(hay.has(nombre), "y su gesto «%s» existe en el pack" % nombre)


## Manos vacías vale; **no tener línea, no**. `SIN_APERO` es una decisión escrita —quien
## bate el monte va mirando— y una ausencia es un olvido.
func test_toda_especialidad_decide_su_apero_y_el_apero_existe() -> void:
	for especialidad: int in Profession.Speciality.values():
		assert_true(ClipsDeLaBanda.APEROS.has(especialidad),
			"la especialidad %d dice qué lleva en la mano" % especialidad)
		var cual: String = ClipsDeLaBanda.APEROS[especialidad]
		if cual == ClipsDeLaBanda.SIN_APERO:
			continue
		assert_true(Aperos.montar(cual) != null,
			"y el modelo del apero «%s» se monta" % cual)


func test_el_oficio_solo_manda_trabajando() -> void:
	# Andar es andar: un cazador y una peletera de camino al tajo se mueven igual.
	for especialidad: int in Profession.Speciality.values():
		assert_eq(ClipsDeLaBanda.clip(Inhabitant.State.YENDO, especialidad), "Walk",
			"yendo, la especialidad %d anda" % especialidad)


func test_el_apero_no_se_lleva_durmiendo_ni_comiendo() -> void:
	for estado: int in [Inhabitant.State.DURMIENDO, Inhabitant.State.COMIENDO,
			Inhabitant.State.OCIOSO]:
		assert_eq(ClipsDeLaBanda.apero(estado, Profession.Speciality.CAZA_MAYOR),
			ClipsDeLaBanda.SIN_APERO, "sin azagaya en el estado %d" % estado)


func test_el_apero_se_lleva_de_camino_al_tajo() -> void:
	# La mitad de lo que hace legible una cuadrilla de caza es verla salir armada.
	assert_eq(ClipsDeLaBanda.apero(Inhabitant.State.YENDO,
		Profession.Speciality.CAZA_MAYOR), "azagaya", "sale con la azagaya")
	assert_eq(ClipsDeLaBanda.apero(Inhabitant.State.VOLVIENDO,
		Profession.Speciality.FORRAJEO), "cesto", "y vuelve con el cesto")


## Arponear y forrajear no pueden leerse igual (GRAFICOS §6). Con once gestos para veinte
## oficios, el apero es lo que acaba de separarlos.
func test_los_oficios_de_un_mismo_sitio_se_distinguen() -> void:
	var ribera := ClipsDeLaBanda.apero(Inhabitant.State.TRABAJANDO,
		Profession.Speciality.ORILLA)
	var marisco := ClipsDeLaBanda.apero(Inhabitant.State.TRABAJANDO,
		Profession.Speciality.MARISQUEO)
	assert_true(ribera != marisco, "el arpón no se confunde con el cesto")
	var talla := ClipsDeLaBanda.apero(Inhabitant.State.TRABAJANDO,
		Profession.Speciality.TALLA)
	var piel := ClipsDeLaBanda.apero(Inhabitant.State.TRABAJANDO,
		Profession.Speciality.PELETERIA)
	assert_true(talla != piel, "ni el percutor con el raspador")


## Y que no sea un desfile de lo mismo: si las veinte especialidades hicieran el mismo
## gesto estaríamos donde estábamos antes de este trabajo, que es de donde viene la queja.
func test_hay_gestos_de_trabajo_de_verdad_distintos() -> void:
	var vistos: Array[String] = []
	for especialidad: int in Profession.Speciality.values():
		var nombre := ClipsDeLaBanda.clip(Inhabitant.State.TRABAJANDO, especialidad)
		if not vistos.has(nombre):
			vistos.append(nombre)
	assert_gt(float(vistos.size()), 7.0,
		"más de siete posturas de trabajo distintas (hay %d)" % vistos.size())


func test_todas_las_eras_visten_y_su_ropa_existe() -> void:
	for era: int in Site.Era.values():
		assert_true(Vestuario.CONJUNTOS.has(era), "la era %d tiene conjunto" % era)
		for sexo: int in [CatalogoDeCuerpos.Sexo.HOMBRE, CatalogoDeCuerpos.Sexo.MUJER]:
			var piezas := Vestuario.piezas(era, sexo)
			assert_gt(float(piezas.size()), 2.0,
				"la era %d viste al sexo %d con varias piezas" % [era, sexo])
			for pieza: String in piezas:
				assert_true(ResourceLoader.exists(
					"%s/ropa/%s.gltf" % [CatalogoDeCuerpos.RAIZ, pieza]),
					"y la pieza «%s» existe" % pieza)


func test_los_cuerpos_y_las_cabezas_estan() -> void:
	for sexo: int in [CatalogoDeCuerpos.Sexo.HOMBRE, CatalogoDeCuerpos.Sexo.MUJER]:
		assert_true(CatalogoDeCuerpos.cuerpo(sexo) != null,
			"el cuerpo del sexo %d está" % sexo)
		# La cabeza va aparte porque la ropa trae su propia piel y el cuerpo se esconde:
		# sin este fichero la banda sale decapitada. Ver `scripts/tools/CabezaSuelta.gd`.
		assert_true(CatalogoDeCuerpos.cabeza(sexo) != null,
			"y su cabeza suelta también")


func test_los_pelos_del_pack_existen() -> void:
	for sexo: int in Vestuario.PELOS:
		for pelo: String in Vestuario.PELOS[sexo]:
			assert_true(ResourceLoader.exists(
				"%s/pelo/%s.gltf" % [CatalogoDeCuerpos.RAIZ, pelo]),
				"el pelo «%s» existe" % pelo)
	assert_true(ResourceLoader.exists(
		"%s/pelo/%s.gltf" % [CatalogoDeCuerpos.RAIZ, Vestuario.BARBA]),
		"y la barba también")


## LAS ANIMACIONES NO PUEDEN TRAER PISTAS DE POSICIÓN. Es la causa de que la banda saliera
## hundida hasta la cintura el 2026-09-18: el FBX del pack trae la pose de reposo aplastada
## —«known scaling bug when importing rigged FBXs from Blender», lo avisa su propio léeme— y
## sus pistas de posición llevan esa geometría dentro. Con ellas, los pies quedaban 83 cm
## por debajo del suelo.
##
## No se puede comprobar la pose sin cuadros, pero sí la causa: si alguien vuelve a dejar
## pasar una pista de posición, esto lo caza aquí y no jugando.
func test_las_animaciones_van_solo_de_rotaciones() -> void:
	var lib := CatalogoDeCuerpos.biblioteca(NodePath("Skeleton3D"))
	assert_gt(float(lib.get_animation_list().size()), 30.0, "la biblioteca trae sus clips")
	var sueltas := 0
	for nombre: StringName in lib.get_animation_list():
		var anim := lib.get_animation(nombre)
		for t in range(anim.get_track_count()):
			if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				sueltas += 1
	assert_eq(sueltas, 0, "ninguna pista que no sea de rotación")


## Y el cuerpo tiene los huesos con los que se asienta en el suelo. Sin ellos,
## [Cuerpo._plantar] no tiene de dónde medir y la persona vuelve a flotar o a hundirse.
func test_el_cuerpo_tiene_huesos_de_planta() -> void:
	var escena := CatalogoDeCuerpos.cuerpo(CatalogoDeCuerpos.Sexo.HOMBRE)
	assert_true(escena != null, "el cuerpo está")
	var raiz := escena.instantiate()
	var esqueleto := CatalogoDeCuerpos.buscar(raiz, "Skeleton3D") as Skeleton3D
	assert_true(esqueleto != null, "y trae esqueleto")
	for hueso: String in Cuerpo.PLANTA:
		assert_gt(float(esqueleto.find_bone(hueso)), -0.5,
			"el hueso «%s» existe" % hueso)
	# Y el esqueleto está de pie, no aplastado: es lo que distinguía al cuerpo bueno del
	# FBX roto, donde la pelvis estaba a 0,0005 m.
	var pelvis := esqueleto.find_bone("pelvis")
	assert_gt(esqueleto.get_bone_global_rest(pelvis).origin.y, 0.5,
		"y la pelvis está a la altura de una cadera, no en el suelo")
	raiz.queue_free()


## SÓLO VA VESTIDO QUIEN TENGA VESTIDO. El utillaje lleva un número —`Tool.Kind.VESTIDO`— y
## no dice de quién es ninguno; quién se dibuja abrigado lo decide la vista, y la regla es
## **primero los que salen del campamento**. Hasta el 2026-09-18 la banda salía vestida
## siempre, incluso el día 1, que es cuando hay cero vestidos y la barra superior pone «sin
## vestidos». GRAFICOS §5.1.
class _Falsa:
	var state: int = Inhabitant.State.OCIOSO
	func _init(estado: int) -> void:
		state = estado


func _banda(estados: Array) -> Array:
	var out: Array = []
	for e: int in estados:
		out.append(_Falsa.new(e))
	return out


func test_sin_vestidos_nadie_va_vestido() -> void:
	var gente := _banda([Inhabitant.State.TRABAJANDO, Inhabitant.State.OCIOSO,
		Inhabitant.State.YENDO])
	var puestos := Vestuario.quien_va_vestido(gente, 0)
	for i in range(puestos.size()):
		assert_eq(int(puestos[i]), 0, "con cero vestidos, nadie lleva (índice %d)" % i)


func test_los_vestidos_van_a_los_que_salen() -> void:
	# Dos vestidos y cinco personas: van a los dos que están fuera, no a los de la cueva.
	var gente := _banda([Inhabitant.State.DURMIENDO, Inhabitant.State.TRABAJANDO,
		Inhabitant.State.COMIENDO, Inhabitant.State.YENDO, Inhabitant.State.OCIOSO])
	var puestos := Vestuario.quien_va_vestido(gente, 2)
	assert_eq(int(puestos[1]), 1, "el que trabaja fuera va abrigado")
	assert_eq(int(puestos[3]), 1, "y el que va de camino también")
	assert_eq(int(puestos[0]), 0, "el que duerme no")
	assert_eq(int(puestos[2]), 0, "ni el que come")
	assert_eq(int(puestos[4]), 0, "ni el ocioso")


func test_los_que_sobran_visten_a_los_de_dentro() -> void:
	# Cuatro vestidos y un solo trabajador: los otros tres se quedan en el campamento.
	var gente := _banda([Inhabitant.State.DURMIENDO, Inhabitant.State.TRABAJANDO,
		Inhabitant.State.COMIENDO, Inhabitant.State.OCIOSO])
	var puestos := Vestuario.quien_va_vestido(gente, 4)
	for i in range(puestos.size()):
		assert_eq(int(puestos[i]), 1, "con vestidos de sobra, todos (índice %d)" % i)


func test_nunca_se_reparten_mas_vestidos_de_los_que_hay() -> void:
	var gente := _banda([Inhabitant.State.TRABAJANDO, Inhabitant.State.TRABAJANDO,
		Inhabitant.State.TRABAJANDO, Inhabitant.State.OCIOSO])
	for cuantos: int in [0, 1, 2, 3, 4, 9]:
		var puestos := Vestuario.quien_va_vestido(gente, cuantos)
		var llevan := 0
		for b: int in puestos:
			llevan += b
		assert_eq(llevan, mini(cuantos, gente.size()),
			"con %d vestidos se reparten %d" % [cuantos, mini(cuantos, gente.size())])


## EN EL TRONCO SE ESTÁ SENTADO, no de pie encima.
##
## La simulación reparte los asientos del corro del fuego desde el 2026-09-13
## —`Destino._home_spot`— y la vista no se había enterado: el ocio seguía siendo
## `Idle_Talking`, de pie, así que la banda salía plantada sobre los leños manoseándose las
## manos. Queja del usuario del 2026-09-19: «¿podemos sentarles en los bancos?».
func test_el_ocio_en_el_tronco_es_sentado() -> void:
	var de_pie := ClipsDeLaBanda.clip(Inhabitant.State.OCIOSO,
		Profession.Speciality.NINGUNA, false)
	var en_el_tronco := ClipsDeLaBanda.clip(Inhabitant.State.OCIOSO,
		Profession.Speciality.NINGUNA, true)
	assert_true(not de_pie.begins_with("Sitting"),
		"fuera del corro el ocio sigue siendo de pie (%s)" % de_pie)
	assert_true(en_el_tronco.begins_with("Sitting"),
		"en el tronco, sentado (%s)" % en_el_tronco)

	# Y EL TRABAJO NO: quien talla arrodillado junto al fuego sigue arrodillado. El tronco
	# decide el OCIO, no lo que se está haciendo con las manos.
	assert_eq(ClipsDeLaBanda.clip(Inhabitant.State.TRABAJANDO,
		Profession.Speciality.TALLA, true),
		ClipsDeLaBanda.clip(Inhabitant.State.TRABAJANDO, Profession.Speciality.TALLA, false),
		"sentado o no, tallar es tallar")


## QUIÉN ESTÁ SENTADO lo contesta el corro, y se contesta por el sitio de verdad: pasar al
## lado a atizar el fuego no es estar sentado.
func test_solo_esta_sentado_quien_esta_en_su_asiento() -> void:
	var centro := Vector3(100.0, 0.0, 100.0)
	var asiento := CorroDelHogar.asiento_de(centro, 0)
	assert_true(asiento != Vector3.ZERO, "el corro reparte asiento al puesto 0")
	assert_true(CorroDelHogar.sentado(centro, 0, asiento, 6.0), "en su sitio, sentado")
	assert_false(CorroDelHogar.sentado(centro, 0, centro, 0.5),
		"junto al fuego pero no en el tronco: de pie")
	assert_false(CorroDelHogar.sentado(Vector3.ZERO, 0, asiento, 6.0),
		"sin hogar levantado no hay corro en el que sentarse")

	# Y mira AL FUEGO, que es para lo que se sienta uno ahí. El rumbo va en la convención
	# del andador, `atan2(x, z)`.
	var rumbo := CorroDelHogar.mirando_al_fuego(centro, asiento)
	var hacia := Vector3(sin(rumbo), 0.0, cos(rumbo))
	var deberia := (centro - asiento).normalized()
	assert_lt(Traversal.en_llano(hacia, deberia), 0.01,
		"sentado, se mira a la hoguera")
