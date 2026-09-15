class_name Intercambio
extends RefCounted
## Trueque con la gente de ahí fuera: precios, la regla del 10 %, y lo que se ha
## cambiado.
##
## El primer peldaño de la escalera del comercio de docs/SISTEMAS.md §5. Tuvo tres
## formas: un envío automático sin que el jugador decidiera nada (hasta el
## 2026-09-12), una tarjeta por estación con tratos cerrados y un viaje de cuatro
## jornadas (tanda 2), y **una ventana como la del almacén** (tanda 4,
## `PanelTrueque`). La tarjeta y su viaje **se quitaron el 2026-09-13**, a
## petición del usuario, cuando la ventana ya estaba: dos maneras de tratar con la
## misma gente eran dos respuestas a la misma pregunta. Con la tarjeta se fue
## también pedir gente a otra banda, que sólo existía ahí.

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Cuánto mejora el trato con esa gente un cambio cerrado a gusto de los dos.
## Dos: es lo que movía «lo justo» en la tarjeta de antes, y se hereda. Decisión,
## no medida, con la misma forma que `ElLobo.trato`.
const TRATO_POR_CAMBIO := 2.0

# --- El trueque como el almacén: precios y la regla del 10 % ------------------
#
# Frente 25 de EPOCA_01 §10.1, tanda 4. Una ventana como la del almacén, con lo
# de la banda a un lado y lo de los visitantes al otro, y se pasan cosas. Cada
# cosa tiene un precio, la relación lo mueve, y el trato sale si los dos lados
# no se separan más de un 10 %.

## Lo que vale cada cosa, en «puñados de fruto seco», que es la moneda que ya
## usaba el trueque de antes. **Las tres primeras NO se inventan**: salen de los
## tratos que ya existían —6 de fruto seco por 3 de sílex, y por 2 conchas—. El
## resto son decisión, puestas a ojo de lo que cuesta conseguir cada cosa, y así
## se dice.
const PRECIO := {
	Materia.Kind.FRUTO_SECO: 1.0,
	Materia.Kind.SILEX: 2.0,
	Materia.Kind.CONCHA: 3.0,
	# Decisión: lo que se trae de lejos o cuesta días, más; lo que está a mano,
	# menos.
	Materia.Kind.OCRE: 3.0,
	Materia.Kind.PIEL: 4.0,
	Materia.Kind.ASTA: 2.0,
	Materia.Kind.GRASA: 2.0,
	Materia.Kind.PIEDRA: 0.5,
	Materia.Kind.LENA: 0.3,
}

## Lo que vale lo que no está en [PRECIO]. Uno, como el fruto seco: decisión.
const PRECIO_POR_DEFECTO := 1.0

## Cuánto pueden separarse los dos lados para que el trato salga. Decisión del
## usuario del 2026-09-13: «un intercambio equivalente», con un 10 % de margen.
const MARGEN := 0.10

## Cuánto mueve el trato el precio. Con trato 0 todo vale lo suyo; cada 100 de
## trato, lo de la banda vale un 50 % más a sus ojos y lo suyo un tercio menos.
## Con topes para que ni regalen ni roben. Decisión de forma, no medida.
const TRATO_QUE_DOBLA := 200.0

## Lo que se ha cambiado, para la ventana de relaciones: `{"con", "dia", "da",
## "recibe"}`.
var historial: Array[Dictionary] = []


## Lo que vale un material, sin relación de por medio.
static func precio(material: Materia.Kind) -> float:
	return float(PRECIO.get(material, PRECIO_POR_DEFECTO))


## Por cuánto multiplica la relación lo que da la banda. Lo que traen ellos va
## dividido por lo mismo.
func factor_con(con: int) -> float:
	var t := sim.contacto.trato_con(con) if sim.contacto != null else 0.0
	return clampf(1.0 + t / TRATO_QUE_DOBLA, 0.5, 2.0)


## Lo que vale para ELLOS lo que da la banda.
func valor_de_lo_que_se_da(lote: Dictionary, con: int) -> float:
	var total := 0.0
	for material: int in lote:
		total += float(lote[material]) * precio(material as Materia.Kind)
	return total * factor_con(con)


## Lo que vale lo que traen ELLOS, visto por la banda.
func valor_de_lo_que_se_recibe(lote: Dictionary, con: int) -> float:
	var total := 0.0
	for material: int in lote:
		total += float(lote[material]) * precio(material as Materia.Kind)
	return total / factor_con(con)


## Si el trato sale: los dos lados valen algo y no se separan más del margen.
func se_acepta(da: Dictionary, recibe: Dictionary, con: int) -> bool:
	var dado := valor_de_lo_que_se_da(da, con)
	var recibido := valor_de_lo_que_se_recibe(recibe, con)
	if dado <= 0.0 or recibido <= 0.0:
		return false
	return absf(dado - recibido) <= MARGEN * maxf(dado, recibido) + 0.0001


## Cambia: sale del almacén lo que se da y entra lo que se recibe, exactamente.
## Dice si ha salido. No sale si no se acepta o si no hay lo que se da.
func cambiar(con: int, da: Dictionary, recibe: Dictionary) -> bool:
	if not se_acepta(da, recibe, con):
		return false
	# No se lleva uno más de lo que traen.
	var quedan := quedan_de(con)
	for material: int in recibe:
		if float(quedan.get(material, 0.0)) + 0.0001 < float(recibe[material]):
			return false
	for material: int in da:
		if sim.store.amount(material as Materia.Kind) < float(da[material]):
			return false
	for material: int in da:
		sim.store.take(material as Materia.Kind, float(da[material]))
	for material: int in recibe:
		sim.store.add(material as Materia.Kind, float(recibe[material]))
	historial.append({"con": con, "dia": sim.day, "anyo": sim.anyo,
		"estacion": int(sim.estacion), "da": da.duplicate(),
		"recibe": recibe.duplicate()})
	# Un trato cerrado a gusto de los dos se recuerda. Ver [TRATO_POR_CAMBIO].
	if sim.contacto != null:
		sim.contacto.mover_el_trato(con, TRATO_POR_CAMBIO)
	consumados += 1
	# El primero es un hito en la crónica, como lo era con la tarjeta.
	sim._note(Chronicle.Kind.TRUEQUE, "Se cierra un trato con otra gente."
		if logrado_alguna_vez else "Primer trueque con otra gente: la banda ya "
		+ "no depende sólo de lo que da su valle.", 1 if logrado_alguna_vez else 2)
	logrado_alguna_vez = true
	return true


## Lo que trae esa gente cada estación. Sale de la semilla, el sitio y la
## estación, con azar propio (SPECS §7): la misma gente trae lo mismo en la misma
## estación de la misma partida. Traen lo que la banda no tiene a mano —sílex de
## fuera, conchas de la costa, ocre, pieles—, que es para lo que se trata.
## Cantidades: decisión.
func lo_que_traen(con: int) -> Dictionary:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([sim.game_seed, con, sim.anyo, int(sim.estacion), "traen"])
	var traen := {}
	for material: Materia.Kind in [Materia.Kind.SILEX, Materia.Kind.CONCHA,
			Materia.Kind.OCRE, Materia.Kind.PIEL]:
		if azar.randf() < 0.75:
			traen[material] = float(azar.randi_range(2, 8))
	if traen.is_empty():
		traen[Materia.Kind.SILEX] = 4.0
	return traen


## Lo que les queda por cambiar esta estación: lo que traían menos lo que ya se
## ha llevado la banda.
func quedan_de(con: int) -> Dictionary:
	var quedan := lo_que_traen(con)
	for trato_hecho: Dictionary in historial:
		if int(trato_hecho["con"]) != con or int(trato_hecho.get("anyo", -1)) != sim.anyo \
				or int(trato_hecho.get("estacion", -1)) != int(sim.estacion):
			continue
		for material: int in (trato_hecho["recibe"] as Dictionary):
			quedan[material] = maxf(float(quedan.get(material, 0.0))
				- float(trato_hecho["recibe"][material]), 0.0)
	return quedan


## Si ha salido bien alguna vez. El primero es un hito en la crónica.
var logrado_alguna_vez := false

## Los cambios cerrados, para la sonda del año.
var consumados := 0


## Con quién se trata: la gente conocida con mejor trato, y a igualdad, la de
## id más bajo, para que la elección no dependa del orden de un diccionario.
## -1 si no se conoce a nadie.
func con_quien() -> int:
	if sim.contacto == null:
		return -1
	var mejor := -1
	var mejor_trato := -INF
	var ids: Array = sim.contacto.trato.keys()
	ids.sort()
	for id: int in ids:
		var t := sim.contacto.trato_con(id)
		if t > mejor_trato:
			mejor_trato = t
			mejor = id
	return mejor
