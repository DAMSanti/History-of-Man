class_name BandaCrowd
extends Node3D
## LA BANDA ENTERA: una persona por nodo, con su esqueleto, su ropa y su gesto.
##
## **Esto era un `MultiMesh` con la animación horneada en una textura de vértices**, y se
## cambió el 2026-09-18 porque aquello no tenía huesos: no había de dónde colgar una
## azagaya ni a qué coser una túnica, y los siete clips genéricos hacían que tallar, raspar
## y avivar el fuego se vieran igual. Con los cuerpos nuevos el horneado además dejaba de
## caber —cada pieza de ropa habría necesitado su propia textura de vértices, unos 25 MB por
## pieza—, así que la decisión no era de gusto sino de aritmética.
##
## Lo que costaba y lo que cuesta, medido con `EsqueletosProbe` en el valle 56 a 1080p:
##
##   | | GPU | CPU |
##   |---|---|---|
##   | horneado en textura | 0,18 ms | 0,05 ms |
##   | esqueletos con ropa | 0,38 ms | 0,57 ms |
##
## El presupuesto de GRAFICOS §1 para «Personajes» son **2,0 ms**, así que cabe con holgura,
## y lo que se compra con la diferencia es todo lo que la spec pedía.
##
## Cómo se monta cada persona, en [Cuerpo]; de dónde salen las piezas, en
## [CatalogoDeCuerpos]; qué gesto le toca a cada oficio, en [ClipsDeLaBanda].

## La talla de un adulto. Se conserva el nombre porque [WildlifeHerds] lo cita al explicar
## de dónde saca la suya.
const TARGET_HEIGHT_M := CatalogoDeCuerpos.ALTO_M

## Por debajo de esta cota, lo que hay es alguien a quien la simulación ha mandado bajo
## tierra para sacarlo de la vista —ver `SettlementSim._sacar_del_mapa`—. Con el `MultiMesh`
## había que enterrarlos porque los huecos van por índice; con nodos se apagan, que además
## ahorra animarlos.
const BAJO_TIERRA := -500.0

var _cuerpos: Array[Cuerpo] = []
var _rng := RandomNumberGenerator.new()
var _era: Site.Era = Site.Era.PALEOLITICO
var _reservados := 0


func setup(capacity: int) -> void:
	# `randomize`, no la semilla de la partida: el pelo, la barba y el desfase de los gestos
	# son variedad visual y no pueden tocar el azar del que sale la simulación (SPECS §7).
	_rng.randomize()
	_reservados = maxi(capacity, 1)
	_era = Expedition.la_de_ahora()


## Da de alta a una persona y devuelve su sitio, que luego hay que pasarle a [update].
##
## Sigue siendo un `Vector2i` por lo que fue: con el `MultiMesh` el primer número era la
## variante de piel y el segundo el hueco. Ahora la variedad va dentro del propio cuerpo
## —sexo, pelo, barba, color— así que el primero es siempre cero y el que cuenta es el
## segundo.
func add_person(sexo: int = Inhabitant.Sex.MUJER,
		edad: int = Inhabitant.Age.ADULTO) -> Vector2i:
	if _cuerpos.size() >= _reservados:
		# No es un fallo: la banda crece cuando nace o llega alguien. Se anota para que el
		# tamaño que pidió `setup` siga sirviendo de referencia.
		_reservados = _cuerpos.size() + 1
	var cual := CatalogoDeCuerpos.Sexo.HOMBRE if sexo == Inhabitant.Sex.HOMBRE \
		else CatalogoDeCuerpos.Sexo.MUJER
	var cuerpo := Cuerpo.nueva(cual, _era, edad, _rng)
	if cuerpo == null:
		return Vector2i(0, -1)
	add_child(cuerpo)
	cuerpo.desacompasar(_rng)
	_cuerpos.append(cuerpo)
	return Vector2i(0, _cuerpos.size() - 1)


## Al fotograma: sitúa a la persona, le pone el gesto que le toca, le da o le quita el apero
## de su oficio y la viste o la desnuda. `heading` es el ángulo alrededor de Y hacia el que
## mira, en radianes.
##
## `vestido` viene de fuera y **por defecto es `false`**: el utillaje empieza la partida con
## cero vestidos, así que lo honesto es que quien no lo diga no vista a nadie. Quién lo
## lleva lo reparte [Vestuario.quien_va_vestido].
func update(slot: Vector2i, position: Vector3, heading: float, state: int,
		age: int = 1, speciality: int = Profession.Speciality.NINGUNA,
		vestido: bool = false, sentado: bool = false) -> void:
	if slot.y < 0 or slot.y >= _cuerpos.size():
		return
	var cuerpo := _cuerpos[slot.y]
	if position.y < BAJO_TIERRA:
		cuerpo.visible = false
		return
	cuerpo.visible = true
	cuerpo.poner(position, heading, age)
	cuerpo.vestir(vestido)
	cuerpo.gesto(ClipsDeLaBanda.clip(state, speciality, sentado))
	cuerpo.apero(ClipsDeLaBanda.apero(state, speciality))
