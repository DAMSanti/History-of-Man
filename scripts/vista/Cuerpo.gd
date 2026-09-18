class_name Cuerpo
extends Node3D
## UNA PERSONA DE LA BANDA: su cuerpo, su ropa, su pelo, su gesto y lo que lleva en la mano.
##
## Con esqueleto de verdad, que es lo que hacía falta para que hubiera algo de lo que
## colgar una azagaya y algo a lo que coser una túnica. La versión anterior dibujaba a las
## veinticinco personas como un `MultiMesh` con la animación horneada en una textura: más
## barato —0,2 ms contra 0,4 de GPU y 0,6 de CPU, medido—, pero **sin huesos**, y sin huesos
## no hay ni herramienta ni ropa. Con los cuerpos nuevos el horneado además dejaba de caber:
## cada pieza de ropa habría necesitado su propia textura de vértices, unos 25 MB por pieza.
##
## Cabe: quince personas vestidas cuestan 0,38 ms de GPU y 0,57 de CPU de los **2,0 ms** que
## el presupuesto de GRAFICOS §1 le da a «Personajes». Medido con `EsqueletosProbe`.
##
## Cómo se monta, y por qué, en [CatalogoDeCuerpos]. GRAFICOS §5.1.

## Cuánto tarda en pasar de un gesto a otro. Un cuarto de segundo: lo justo para que no dé
## un tirón al cambiar de andar a trabajar, y no tanto como para que se note el
## deslizamiento cuando la simulación cambia de estado a menudo.
const MEZCLA := 0.25

## Por [Inhabitant.Age]. Se conserva de la versión anterior, que a su vez lo heredó de las
## cápsulas: distinguir de un vistazo a un crío de un adulto es información de juego.
const POR_EDAD := {
	0: 0.62,  # NINO
	1: 1.0,   # ADULTO
	2: 0.95,  # ANCIANO: encogido, no infantil
}

## Los huesos de la planta, para asentar a la persona en el suelo. Ver [_plantar].
const PLANTA := ["ball_l", "ball_r"]

var _raiz: Node3D = null
var _planta := PackedInt32Array()
## A qué cota está la planta del pie en la pose de reposo, en el espacio de esta persona.
## Es el cero contra el que se asienta: poner el hueso a 0 hundiría la suela.
var _reposo_planta := 0.0
var _esqueleto: Skeleton3D = null
var _player: AnimationPlayer = null
var _percha: BoneAttachment3D = null
var _aperos: Dictionary = {}
## La malla del cuerpo entero —la que trae la cabeza dentro—, la cabeza suelta y las piezas
## de ropa. Se guardan para poder vestir y desvestir encendiendo y apagando, sin rehacer
## nada: cambiar de estado cuesta lo mismo que poner un `visible`.
var _bulto: MeshInstance3D = null
var _cabeza: MeshInstance3D = null
var _ropa: Array[MeshInstance3D] = []
var _vestido := true
var _apero_puesto := ""
var _gesto_puesto := ""
var _base := 1.0

## Materiales teñidos, compartidos por todos: teñir es duplicar el material, y duplicarlo
## por persona serían veinticinco copias del mismo verde. La clave lleva el color dentro.
static var _tenidos: Dictionary = {}


## Monta una persona entera. `rng` es el de la vista, no el de la simulación: el pelo y la
## barba son variedad visual y no pueden tocar el azar del que sale la partida (SPECS §7).
static func nueva(sexo: int, era: Site.Era, edad: int, rng: RandomNumberGenerator) -> Cuerpo:
	var escena := CatalogoDeCuerpos.cuerpo(sexo)
	if escena == null:
		push_error("Cuerpo: no carga el cuerpo de %s" % CatalogoDeCuerpos.sufijo(sexo))
		return null
	var yo := Cuerpo.new()
	yo.name = "Cuerpo"
	var raiz := escena.instantiate() as Node3D
	yo.add_child(raiz)
	yo._raiz = raiz
	yo._esqueleto = CatalogoDeCuerpos.buscar(raiz, "Skeleton3D") as Skeleton3D
	if yo._esqueleto == null:
		push_error("Cuerpo: el modelo no trae esqueleto")
		return yo
	yo._base = CatalogoDeCuerpos.escala(sexo)
	raiz.scale = Vector3.ONE * yo._base

	yo._quitar_el_bulto(raiz, sexo)
	yo._vestir(era, sexo)
	yo._peinar(sexo, edad, rng)

	yo._player = AnimationPlayer.new()
	raiz.add_child(yo._player)
	yo._player.add_animation_library("",
		CatalogoDeCuerpos.biblioteca(raiz.get_path_to(yo._esqueleto)))

	yo._percha = BoneAttachment3D.new()
	yo._percha.name = "Mano"
	yo._esqueleto.add_child(yo._percha)
	yo._percha.bone_name = CatalogoDeCuerpos.MANO

	# La cota de reposo de la planta, que es el cero contra el que se asienta: el hueso de la
	# almohadilla está 1,5 cm por encima de la suela, así que ponerlo a ras de suelo
	# enterraría el pie ese centímetro y medio.
	var reposo := INF
	for hueso: String in PLANTA:
		var idx := yo._esqueleto.find_bone(hueso)
		if idx < 0:
			continue
		yo._planta.append(idx)
		reposo = minf(reposo, yo._esqueleto.get_bone_global_rest(idx).origin.y * yo._base)
	yo._reposo_planta = 0.0 if is_inf(reposo) else reposo
	# Nace en cueros y la simulación dirá: el utillaje empieza con cero vestidos y vestir
	# por defecto era justo el fallo -la banda salía abrigada el día 1-.
	yo._vestido = true
	yo.vestir(false)
	return yo


## ASIENTA A LA PERSONA EN EL SUELO, cada cuadro.
##
## La simulación pone `position.y` en la cota del terreno y da por hecho que el modelo se
## apoya ahí. No se apoya solo: las animaciones de este pack se usan **sólo por sus
## rotaciones** —las de posición traían la geometría rota del FBX, ver [CatalogoDeCuerpos]—
## y sin la traslación de la cadera, al doblar las piernas el cuerpo no baja: quien se
## agacha o se arrodilla queda **flotando entre 36 y 46 cm** (medido con `PiesProbe`).
##
## Así que se mira dónde ha quedado el pie más bajo y se corrige la altura del modelo para
## que apoye. Vale para las dos mitades del problema con una sola regla, y no hace falta
## adivinar en qué unidades venía nada. Son dos consultas de hueso por persona y cuadro.
func _process(_delta: float) -> void:
	_plantar()


func _plantar() -> void:
	if _esqueleto == null or _raiz == null or _planta.is_empty() or not is_inside_tree():
		return
	var inverso := global_transform.affine_inverse()
	var bajo := INF
	for idx: int in _planta:
		var donde := _esqueleto.global_transform * _esqueleto.get_bone_global_pose(idx)
		bajo = minf(bajo, (inverso * donde.origin).y)
	if is_inf(bajo):
		return
	_raiz.position.y += _reposo_planta - bajo


## Dónde está y hacia dónde mira. La talla sale de la edad, que es la única razón por la
## que dos personas de la banda tienen tamaños distintos.
func poner(donde: Vector3, rumbo: float, edad: int) -> void:
	position = donde
	rotation.y = rumbo
	var talla: float = POR_EDAD.get(edad, 1.0)
	scale = Vector3.ONE * talla


## El gesto que toca. Se ignora si ya está puesto: `play` con el mismo clip lo reiniciaría
## desde el principio cada fotograma y la persona se quedaría temblando en el primer cuadro.
func gesto(clip: String) -> void:
	if clip == _gesto_puesto or _player == null:
		return
	if not _player.has_animation(clip):
		return
	_gesto_puesto = clip
	_player.play(clip, MEZCLA)


## VESTIDO O EN CUEROS. Sólo va vestido quien tenga un vestido del utillaje: el número lo
## lleva la simulación y a quién le toca lo decide [Vestuario.quien_va_vestido].
##
## Es encender y apagar mallas, no rehacerlas, así que cambia en el mismo cuadro en que se
## cose o se rompe una prenda. Y **la cabeza va con la ropa**: la malla del cuerpo entero
## trae la cabeza dentro, así que cuando se enseña el cuerpo hay que esconder la cabeza
## suelta o se dibujarían las dos encima. Ver [CatalogoDeCuerpos], regla 2.
func vestir(si: bool) -> void:
	if si == _vestido:
		return
	_vestido = si
	if _bulto != null:
		_bulto.visible = not si
	if _cabeza != null:
		_cabeza.visible = si
	for pieza: MeshInstance3D in _ropa:
		pieza.visible = si


## Adelanta el gesto un trozo al azar. Sin esto las veinticinco personas hacen exactamente
## lo mismo en el mismo fotograma y la banda parece un cuerpo de baile.
func desacompasar(rng: RandomNumberGenerator) -> void:
	if _player != null and _player.is_playing():
		_player.seek(rng.randf() * _player.current_animation_length, true)


## Lo que lleva en la mano, o "" para nada. Las mallas se crean la primera vez que hacen
## falta y se quedan: cambiar de oficio es enseñar una y esconder las demás.
func apero(nombre: String) -> void:
	if nombre == _apero_puesto or _percha == null:
		return
	_apero_puesto = nombre
	for cual: String in _aperos:
		(_aperos[cual] as Node3D).visible = cual == nombre
	if nombre.is_empty() or _aperos.has(nombre):
		return
	var apero := Aperos.montar(nombre)
	if apero == null:
		return
	apero.name = "Apero_%s" % nombre
	_percha.add_child(apero)
	# CONTRA-ESCALA, Y MEDIDA, NO CALCULADA. Todo lo que cuelga de un hueso hereda la escala
	# acumulada del modelo, que no es sólo la que le pone esta clase: el propio glTF trae
	# escalas en el nodo del armature y en el esqueleto. Calcularla a mano dejó un canto de
	# río del tamaño de una rueda de molino, así que se pregunta al motor y se divide.
	#
	# Se recorre a mano la cadena de nodos del hueso hasta esta persona multiplicando sus
	# escalas, en vez de preguntar por la global: el nodo puede no estar todavía en el árbol
	# cuando se pide el primer apero, y `global_basis` devuelve entonces la identidad sin
	# avisar más que con un error en consola.
	var contra := 1.0 / maxf(_acumulada(), 0.000001)
	var sostener := Aperos.agarre(nombre)
	apero.transform = Transform3D(sostener.basis, sostener.origin * contra)
	apero.scale = apero.scale * contra
	_aperos[nombre] = apero


## Cuánto escala el modelo entre esta persona y el hueso de la mano. No es sólo la escala
## que le pone esta clase: el propio glTF trae la suya en el nodo del armature y en el
## esqueleto, y calcularla a ojo dejó un canto de río del tamaño de una rueda de molino.
func _acumulada() -> float:
	var factor := 1.0
	var nodo: Node = _percha
	while nodo != null and nodo != self:
		if nodo is Node3D:
			factor *= (nodo as Node3D).scale.x
		nodo = nodo.get_parent()
	return factor


## El cuerpo desnudo no se dibuja —la ropa trae su propia piel— pero sí la cabeza, que en
## este pack va dentro de la misma malla. Ver [CatalogoDeCuerpos], regla 2.
func _quitar_el_bulto(raiz: Node3D, sexo: int) -> void:
	var cabeza := CatalogoDeCuerpos.cabeza(sexo)
	for m in CatalogoDeCuerpos.mallas(raiz):
		var mi := m as MeshInstance3D
		if mi.skin == null or mi.name.begins_with("Eye"):
			continue
		_bulto = mi
		if cabeza != null:
			var solo := MeshInstance3D.new()
			solo.name = "Cabeza"
			solo.mesh = cabeza
			solo.skin = mi.skin
			_esqueleto.add_child(solo)
			solo.skeleton = NodePath("..")
			_cabeza = solo


func _vestir(era: Site.Era, sexo: int) -> void:
	var tinte := Vestuario.tinte(era)
	for pieza: String in Vestuario.piezas(era, sexo):
		_coser("ropa", pieza, tinte)


func _peinar(sexo: int, edad: int, rng: RandomNumberGenerator) -> void:
	var cuales: Array = Vestuario.PELOS.get(sexo, [])
	if cuales.is_empty():
		return
	# Los viejos, canosos: es el último color de la lista y por eso se elige aparte.
	var pelaje: Color = Vestuario.PELAJES[Vestuario.PELAJES.size() - 1] if edad == 2 \
		else Vestuario.PELAJES[rng.randi() % (Vestuario.PELAJES.size() - 1)]
	_coser("pelo", cuales[rng.randi() % cuales.size()], pelaje)
	if sexo == CatalogoDeCuerpos.Sexo.HOMBRE and edad != 0 and rng.randf() < 0.6:
		_coser("pelo", Vestuario.BARBA, pelaje)


## Cose una malla al esqueleto de esta persona. La pieza viene en su propia escena con su
## propio esqueleto; aquí se coge sólo la malla y la piel, que es lo que la ata a los huesos
## —y los huesos son los mismos en los tres packs—.
func _coser(carpeta: String, pieza: String, tinte: Color) -> void:
	var escena := CatalogoDeCuerpos.pieza(carpeta, pieza)
	if escena == null:
		return
	var suelta := escena.instantiate()
	var origen := CatalogoDeCuerpos.buscar(suelta, "MeshInstance3D") as MeshInstance3D
	if origen == null or origen.mesh == null:
		suelta.queue_free()
		return
	var copia := MeshInstance3D.new()
	copia.name = pieza
	copia.mesh = origen.mesh
	copia.skin = origen.skin
	for s in range(origen.mesh.get_surface_count()):
		copia.set_surface_override_material(s,
			_tenido(origen.mesh.surface_get_material(s), tinte))
	_esqueleto.add_child(copia)
	copia.skeleton = NodePath("..")
	if carpeta == "ropa":
		_ropa.append(copia)
	suelta.queue_free()


## El material del pack, multiplicado por un color. Se cachea por material y color: son
## cinco tintes de ropa y cinco de pelo en toda la partida, no veinticinco copias.
static func _tenido(base: Material, tinte: Color) -> Material:
	if base == null or tinte.is_equal_approx(Color.WHITE):
		return base
	var clave := "%d_%s" % [base.get_instance_id(), tinte.to_html()]
	if _tenidos.has(clave):
		return _tenidos[clave]
	var copia := base.duplicate()
	if copia is BaseMaterial3D:
		(copia as BaseMaterial3D).albedo_color = tinte
	_tenidos[clave] = copia
	return copia
