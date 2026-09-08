class_name Poblaciones
extends RefCounted
## La fauna se acaba o se repone según se la cace.
##
## Hasta ahora una pieza cobrada **no moría**: `WildlifeHerds.taken_by_band`
## llamaba a `_catch`, que la reaparecía en otra querencia. El comentario lo
## decía con todas las letras —«la presa cazada no muere: reaparece»— y era
## defendible mientras la caza no importara, porque mantenía el valle poblado.
## Pero convierte el coto en un grifo: se puede cazar el mismo valle mil años y
## el censo no se mueve.
##
## Aquí la caza **resta**, y la fauna **cría**, y las dos cosas se equilibran
## solas o no se equilibran. Sobre dos reglas:
##
## ## 1. Crecimiento logístico, no exponencial
##
## Una población no crece al mismo ritmo siempre: crece deprisa cuando hay
## sitio y se para cuando llena el valle. `nacen = r · N · (1 − N/K)`, que es
## la ecuación de siempre y da las tres cosas que se quieren: una manada
## diezmada se recupera despacio (poca N), una a medias se recupera deprisa, y
## una llena no crece.
##
## Eso es literalmente lo pedido: «tampoco debe reproducirse infinito, igual
## que las poblaciones reales, el límite de recursos limita la población de las
## camadas».
##
## ## 2. Cada especie cría a su ritmo
##
## Y es lo que hace que la presión cinegética se note distinto según a qué se
## tire. Una liebre repone una manada en una estación; un uro tarda años. Cazar
## caza mayor a fondo **vacía el valle durante años**, y cazar menor no. Esa
## diferencia es la mitad del juego que había en decidir a qué se caza.
##
## ## Lo que NO se ha hecho, y por qué
##
## No hay inmigración desde fuera del valle. Una especie que llega a cero se
## queda a cero, y eso es duro a propósito: el valle son cuatro kilómetros y la
## banda vive dentro. Si se quisiera suavizar, el sitio es aquí y la forma es
## un goteo pequeño cuando `N == 0` y `K > 0`.

## Cuánto cría cada especie AL AÑO, en crías por adulto y a población baja.
##
## No son cifras de balanceo: son el orden de magnitud real de cada bicho —una
## liebre tiene tres camadas al año y un uro un ternero cada dos—. Lo que sí
## queda a playtest es el conjunto, porque el año del juego dura 180 jornadas.
const CRIA_AL_ANO := {
	"liebre": 2.20,
	"anade": 1.30,
	"perdiz": 1.30,
	"corzo": 0.42,
	"rebeco": 0.34,
	"cabra": 0.34,
	"jabali": 0.55,
	"ciervo": 0.30,
	"caballo": 0.20,
	"uro": 0.18,
	"lobo": 0.26,
}
const CRIA_POR_DEFECTO := 0.35

## Jornadas que dura el año del juego. Ver [Subsistence.DAYS_PER_SEASON].
const JORNADAS_DEL_ANO := Subsistence.DAYS_PER_SEASON * 4

## En qué estación nacen. Casi todo pare en primavera, y eso importa: cazar a
## fondo en invierno pilla a la población en su punto más bajo del año.
const PARE_EN := {
	Subsistence.Season.PRIMAVERA: 2.6,
	Subsistence.Season.VERANO: 1.0,
	Subsistence.Season.OTONO: 0.4,
	Subsistence.Season.INVIERNO: 0.0,
}

var herds: WildlifeHerds = null

## Techo de cada especie: lo que el valle aguanta. Se toma del reparto inicial,
## que es el que dice cuánta fauna cabe en estos cuatro kilómetros.
var techo: Dictionary = {}

## Crías a medias. Sin esto, una especie con doce individuos y ritmo bajo
## generaría 0,4 crías al día, `int()` lo dejaría en cero y no criaría NUNCA.
var _pendiente: Dictionary = {}

## Lo que se ha cobrado de cada especie en toda la partida, para la ficha.
var cobradas: Dictionary = {}

## Especies que se han quedado sin uno solo.
var extintas: Dictionary = {}


func _init(wildlife: WildlifeHerds) -> void:
	herds = wildlife
	if herds == null:
		return
	# El techo es lo que el valle tenía al empezar: ni más ni menos gente de la
	# que cabe aquí. Se toma del censo real y no del catálogo por si el terreno
	# no dio para poner todas las manadas.
	for especie: String in herds.tally():
		techo[especie] = float(int((herds.tally() as Dictionary)[especie]))


## Un día de vida y muerte. Se llama al cerrar la jornada.
func nuevo_dia(season: Subsistence.Season) -> void:
	if herds == null:
		return
	var empuje := float(PARE_EN.get(season, 1.0))
	if empuje <= 0.0:
		return
	var censo := herds.tally()
	for especie: String in techo:
		var k := float(techo[especie])
		if k <= 0.0:
			continue
		var n := float(int(censo.get(especie, 0)))
		if n <= 0.0:
			# Sin un solo individuo no hay camada. Es el precio de vaciar el
			# valle de una especie, y es definitivo.
			if not extintas.has(especie):
				extintas[especie] = true
			continue
		if n >= k:
			continue
		# Logística: deprisa a media carga, nada al llenar el valle.
		var ritmo := float(CRIA_AL_ANO.get(especie, CRIA_POR_DEFECTO)) \
			/ float(JORNADAS_DEL_ANO)
		var nacen := ritmo * empuje * n * (1.0 - n / k)
		_pendiente[especie] = float(_pendiente.get(especie, 0.0)) + nacen
		while float(_pendiente[especie]) >= 1.0 and n < k:
			_pendiente[especie] = float(_pendiente[especie]) - 1.0
			if not herds.nacer(especie):
				break
			n += 1.0


## Apunta una pieza cobrada.
func cobrada(especie: String) -> void:
	cobradas[especie] = int(cobradas.get(especie, 0)) + 1


## En qué punto está cada especie respecto de lo que el valle aguanta, para la
## ficha y las sondas.
func estado() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if herds == null:
		return out
	var censo := herds.tally()
	var especies: Array = techo.keys()
	especies.sort()
	for especie: String in especies:
		var k := float(techo[especie])
		var n := float(int(censo.get(especie, 0)))
		out.append({
			"especie": especie,
			"vivos": int(n),
			"techo": int(k),
			"fraccion": clampf(n / maxf(k, 1.0), 0.0, 1.0),
			"cobradas": int(cobradas.get(especie, 0)),
			"cria_al_ano": float(CRIA_AL_ANO.get(especie, CRIA_POR_DEFECTO)),
		})
	return out
