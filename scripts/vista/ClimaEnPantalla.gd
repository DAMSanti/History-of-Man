class_name ClimaEnPantalla
extends RefCounted
## Lo que se le pide a la vista con cada tiempo, y cómo se moja y se nieva el suelo.
## GRAFICOS §7.4.
##
## Sin nodos, para probarlo sin ventana: [WeatherView], el shader del terreno, la
## niebla de valle y la luz leen de aquí. **No es partida**: lee el tiempo de `Weather`
## y avanza con las horas de juego, pero nada de la simulación mira esto.
##
## Las cifras son **decisiones mirando capturas** (aceptadas por el usuario el
## 2026-09-16), no medidas: se ajustan con `ClimaCaptura` delante.

## La lluvia de cada tiempo: cuántas partículas, de qué tamaño —en metros de ancho de la
## gota— y **cuánto la inclina el viento**, en grados desde la vertical. Orbayu, lluvia y
## temporal distintos: más gotas, más gordas y más inclinadas de uno a otro.
const LLUVIA := {
	Weather.Kind.ORBAYU: {"cantidad": 3000, "tamano": 0.03, "inclinacion": 8.0},
	Weather.Kind.LLUVIA: {"cantidad": 8000, "tamano": 0.06, "inclinacion": 16.0},
	Weather.Kind.TEMPORAL: {"cantidad": 16000, "tamano": 0.08, "inclinacion": 38.0},
}

## La nieve que cae: la de hoy, que ya se leía como nieve.
const NIEVE := {
	Weather.Kind.NIEVE: {"cantidad": 2600, "tamano": 0.22, "inclinacion": 6.0},
}

## La luz de cada tiempo, como factores sobre la que pone la hora: energía del sol,
## opacidad de las sombras y luz ambiente. **Plana** con nublado, orbayu y niebla —poco
## sol, sombras blandas, algo más de ambiente—; **más oscura** con temporal.
const LUZ := {
	Weather.Kind.DESPEJADO: {"sol": 1.0, "sombra": 1.0, "ambiente": 1.0},
	Weather.Kind.NUBLADO: {"sol": 0.45, "sombra": 0.35, "ambiente": 1.15},
	Weather.Kind.ORBAYU: {"sol": 0.38, "sombra": 0.3, "ambiente": 1.1},
	Weather.Kind.LLUVIA: {"sol": 0.32, "sombra": 0.25, "ambiente": 1.0},
	Weather.Kind.TEMPORAL: {"sol": 0.2, "sombra": 0.15, "ambiente": 0.72},
	Weather.Kind.NIEBLA: {"sol": 0.4, "sombra": 0.25, "ambiente": 1.15},
	Weather.Kind.NIEVE: {"sol": 0.5, "sombra": 0.35, "ambiente": 1.2},
}

## Sin tiempo que dibujar —el clima apagado—, la luz de la hora sin tocar.
const LUZ_SIN_CLIMA := {"sol": 1.0, "sombra": 1.0, "ambiente": 1.0}

## Hasta dónde moja cada tiempo, y cuánto por hora de juego: el orbayu moja a medias en
## unas seis horas, la lluvia del todo en tres y el temporal en una.
const MOJA_HASTA := {Weather.Kind.ORBAYU: 0.6, Weather.Kind.LLUVIA: 1.0, Weather.Kind.TEMPORAL: 1.0}
const MOJA_POR_HORA := {Weather.Kind.ORBAYU: 0.1, Weather.Kind.LLUVIA: 1.0 / 3.0,
	Weather.Kind.TEMPORAL: 1.0}

## Lo que seca por hora sin llover: del todo en unas dieciocho horas.
const SECA_POR_HORA := 1.0 / 18.0

## Lo que cuaja la nieve por hora nevando —del todo en unas ocho— y lo que se quita sin
## nevar, en unos dos días: al día siguiente de parar todavía se ve.
const CUAJA_POR_HORA := 1.0 / 8.0
const SE_QUITA_POR_HORA := 1.0 / 48.0

## Los modelos de la biblioteca que son piedra: los que se mojan y se nievan por encima
## (`clima_encima.gdshader`). Los árboles, las plantas y las obras, no: fuera de alcance.
const MODELOS_DE_PIEDRA: Array[String] = ["canto", "bloque", "nodulo", "pena", "pena2", "pena3"]

static var _encima: ShaderMaterial = null

## Lo mojado del suelo y la nieve cuajada, de 0 a 1.
var mojado := 0.0
var nieve := 0.0


## Lo que la lluvia pide con este tiempo, o cantidad cero.
static func lluvia(tiempo: Weather.Kind) -> Dictionary:
	return LLUVIA.get(tiempo, {"cantidad": 0, "tamano": 0.0, "inclinacion": 0.0})


static func nieve_que_cae(tiempo: Weather.Kind) -> Dictionary:
	return NIEVE.get(tiempo, {"cantidad": 0, "tamano": 0.0, "inclinacion": 0.0})


static func luz(tiempo: Weather.Kind) -> Dictionary:
	return LUZ.get(tiempo, LUZ_SIN_CLIMA)


## La niebla de valle, sólo con niebla. Decisión aceptada por el usuario el 2026-09-16.
static func hay_niebla_de_valle(tiempo: Weather.Kind) -> bool:
	return tiempo == Weather.Kind.NIEBLA


## Una hora de juego con este tiempo: el suelo se moja o se seca, y la nieve cuaja o se
## quita, poco a poco y sin saltos.
func una_hora(tiempo: Weather.Kind) -> void:
	var hasta := float(MOJA_HASTA.get(tiempo, 0.0))
	if mojado < hasta:
		mojado = minf(hasta, mojado + float(MOJA_POR_HORA[tiempo]))
	else:
		# Sin llover, o con orbayu tras un aguacero: seca hasta lo que moja el que hace.
		mojado = maxf(hasta, mojado - SECA_POR_HORA)
	if tiempo == Weather.Kind.NIEVE:
		nieve = minf(1.0, nieve + CUAJA_POR_HORA)
	else:
		nieve = maxf(0.0, nieve - SE_QUITA_POR_HORA)


## Deja el suelo en lo que toca con el tiempo que hace, sin transición: al montar el mapa
## o al cargar. **Lo mojado y la nieve no se guardan**, que son vista (decisión aceptada
## por el usuario el 2026-09-16): se asientan por el tiempo de ahora.
func asentar(tiempo: Weather.Kind) -> void:
	mojado = float(MOJA_HASTA.get(tiempo, 0.0))
	nieve = 1.0 if tiempo == Weather.Kind.NIEVE else 0.0


## Cuánta nieve cuaja en un punto a `altura_m`, con la cota de nieve en `cota_m`, la nieve
## de ahora y la normal hacia arriba `arriba` (1 en llano): **encima de la cota** y más en
## lo tendido. Es la regla que pintan el terreno y `clima_encima.gdshader`.
static func cuaja(altura_m: float, cota_m: float, nieve_de_ahora: float, arriba: float) -> float:
	return nieve_de_ahora * smoothstep(cota_m - 2.0, cota_m + 2.0, altura_m) \
		* smoothstep(0.35, 0.75, arriba)


## La capa del tiempo encima de las piedras: una sola para todas, que [WeatherView] pone
## al día.
static func material_encima() -> ShaderMaterial:
	if _encima == null:
		_encima = ShaderMaterial.new()
		_encima.shader = load("res://shaders/clima_encima.gdshader") as Shader
	return _encima

