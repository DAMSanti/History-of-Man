class_name Intercambio
extends RefCounted
## Trueque con una banda vecina: sílex a cambio de lo que sobra.
##
## Primer peldaño de la escalera de comercio que ya diseña
## `SISTEMAS_COMPARTIDOS.md` §5. Sin la capa exterior de exploración todavía
## -no hay ningún `Site` que represente a la banda vecina, ver esa misma
## nota §4-, esto es el objeto ligero que la propia spec describe: qué se
## ofrece, qué se pide, y si el otro extremo tiene de sobra este intento o
## no. No hace falta "ver" a la banda vecina para que el trueque funcione.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Lo que la banda entrega. Fruto seco y no otra cosa: es el material del
## que la banda produce el doble de lo que puede comer y guardar -ver
## `ESTADO_DE_LA_SLICE.md` §2-, así que es lo único que de verdad le sobra.
const SE_OFRECE := Materia.Kind.FRUTO_SECO
const SE_OFRECE_CANTIDAD := 6.0

## Lo que se pide. El sílex no existe en Cantabria -`SLICE_PALEOLITICO.md`
## §4-, así que es la única vía de conseguirlo sin veta local.
const SE_PIDE := Materia.Kind.SILEX
const SE_PIDE_CANTIDAD := 3.0

## Probabilidad de que la banda vecina tenga sílex de sobra este intento.
## `SISTEMAS_COMPARTIDOS.md` §5 ya avisa de que puede no tenerlo: "una banda
## vecina que este año no tiene sílex de sobra".
const PROBABILIDAD_EXITO := 0.55

## Si ya ha salido bien alguna vez. Sólo el primero es un hito -"la concha
## de lejos", `EPOCA_01_PALEOLITICO.md` §3-; los siguientes son ya trato
## corriente, y un diario que destacara cada uno dejaría de leerse.
var logrado_alguna_vez := false


## Intenta un trueque. Devuelve si ha salido bien. No cuesta jornadas de
## nadie -es un envío, no una expedición simulada persona a persona-; el
## coste real es el material que se entrega y no vuelve.
func intentar() -> bool:
	if sim.store.amount(SE_OFRECE) < SE_OFRECE_CANTIDAD:
		sim._note(Chronicle.Kind.TRUEQUE,
			"No hay bastante para tantear el trueque con la banda vecina.", 0)
		return false

	if sim._rng.randf() > PROBABILIDAD_EXITO:
		sim._note(Chronicle.Kind.TRUEQUE,
			"Se manda aviso a la banda vecina, pero este año no tienen sílex "
				+ "de sobra.", 0)
		return false

	sim.store.take(SE_OFRECE, SE_OFRECE_CANTIDAD)
	sim.store.add(SE_PIDE, SE_PIDE_CANTIDAD)

	if not logrado_alguna_vez:
		logrado_alguna_vez = true
		sim._note(Chronicle.Kind.TRUEQUE,
			"Llega el primer sílex de la banda vecina, a cambio de fruto "
				+ "seco. La primera prueba de que hay alguien más en el valle.",
			2)
	else:
		sim._note(Chronicle.Kind.TRUEQUE,
			"La banda vecina cambia sílex por fruto seco: %.0f por %.0f."
				% [SE_PIDE_CANTIDAD, SE_OFRECE_CANTIDAD], 1)
	return true
