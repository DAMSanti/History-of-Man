class_name Partida
extends RefCounted
## El objetivo de la partida: victoria, derrota, y el momento que abre todo.
##
## Sale de `SettlementSim` por lo mismo que [Relevo] o [Percances]: es un tema
## cerrado. Nace de docs/specs/QUE_FALTA_PARA_JUGARLO.md — sin esto el
## mecanismo de morir de [Relevo] no es una partida, porque no hay nada que
## ganar ni nada que avise cuando se pierde.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## --- La derrota: la banda entera se extingue ------------------------------
##
## Se llama desde `SettlementSim._person_dies` cuando la última persona sale
## de `people`. No hace falta parar el reloj a mano: `SettlementSim._process`
## ya corta la simulación entera en cuanto `people` está vacío -es una guarda
## que existía por otra razón y que sirve tal cual como el cierre que pide
## esta spec.

## Se llama con la CAUSA de quien murió último -el mismo texto que ya trae
## `_person_dies`-, así que el momento de cierre no repite trabajo ni
## inventa una segunda redacción de lo mismo.
func declarar_derrota(causa: String) -> void:
	if sim.desenlace != SettlementSim.Desenlace.NINGUNO:
		return
	sim.desenlace = SettlementSim.Desenlace.DERROTA
	sim.desenlace_dia = sim.day

	var moment := Moment.new()
	moment.kind = Moment.Kind.DERROTA
	moment.title = "La banda se ha extinguido"
	moment.text = "%s\n\nNo queda nadie. La partida ha terminado." % causa
	sim.raise_moment(moment)


## --- La victoria: un año cerrado, vivo, y con la cueva pintada ------------
##
## Se llama desde `SettlementSim._advance_local_season` en el giro a
## primavera, junto a `relevo.evaluar_nacimiento()` -el único sitio que ya
## sabe que ha pasado un año entero. Cumplir sólo una de las dos condiciones
## no marca nada: la partida sigue, sin premio, camino del año que empieza.

## Si hay pintado en la pared lo bastante como para que la cueva "cuente"
## como pintada. Sin calibrar -ver `SettlementSim.CUEVA_PINTADA_MINIMO`.
func cueva_pintada() -> bool:
	return sim.paintings.size() >= SettlementSim.CUEVA_PINTADA_MINIMO


## Si ya se ha mandado una expedición fuera del mapa. Segunda condición.
func expedicion_mandada() -> bool:
	return sim.expedicion != null and sim.expedicion.mandada_alguna_vez


## Si alguna expedición ha traído puntos nuevos del mapa regional. Tercera.
##
## Los que ha descubierto una expedición, no los que se conocían: la cueva de
## partida no cuenta, y mandar dos veces al mismo sitio tampoco infla la cuenta
## —`Expedicion._descubrir_alrededor` sólo suma los que eran nuevos de verdad—.
func puntos_nuevos() -> bool:
	return sim.expedicion != null and sim.expedicion.descubiertos > 0


## Cuáles de las tres condiciones faltan, para poder decirlo. Vacío si están.
func lo_que_falta_para_cerrar() -> Array[String]:
	var falta: Array[String] = []
	if not cueva_pintada():
		falta.append("la cueva pintada")
	if not expedicion_mandada():
		falta.append("una expedición fuera del valle")
	if not puntos_nuevos():
		falta.append("sitios nuevos traídos de fuera")
	return falta


## La primera fase se cierra con TRES condiciones, no una.
##
## Hasta el 2026-09-12 bastaba con un año vivo y la cueva pintada. La spec
## —EPOCA_01 §10.1, «El cierre de la fase»— pide además una expedición mandada
## fuera y puntos nuevos en el mapa regional, porque son exactamente las dos que
## obligan a construir la capa regional: sin ellas la fase se cerraba sin haber
## salido nunca del valle.
func evaluar_victoria() -> void:
	if sim.desenlace != SettlementSim.Desenlace.NINGUNO:
		return
	if sim.population() <= 0 or not lo_que_falta_para_cerrar().is_empty():
		return

	sim.desenlace = SettlementSim.Desenlace.VICTORIA
	sim.desenlace_dia = sim.day
	var moment := Moment.new()
	moment.kind = Moment.Kind.VICTORIA
	moment.title = "La banda ya no es sólo de este valle"
	moment.text = ("La banda ha cerrado el año viva, la cueva guarda %d relatos "
		+ "pintados, y ha salido a ver qué había más allá: %d sitios nuevos.") % [
			sim.paintings.size(), sim.expedicion.descubiertos]
	sim.raise_moment(moment)


## --- El momento inicial: lo que hay que saber antes de tocar nada --------
##
## Sólo lo CONSTRUYE: no llama a `raise_moment`. Quien lo dispara es
## `SettlementSim.iniciar_partida()`, porque `setup()` -donde vive este
## módulo desde el primer momento- corre antes de que la interfaz conecte
## `moment_raised` (`ui.barra.watch_moments`), y levantarlo aquí dentro se
## perdería sin que nadie se enterara.
func momento_inicial() -> Moment:
	var moment := Moment.new()
	moment.kind = Moment.Kind.INICIO
	moment.title = "Un abrigo, una banda"
	moment.text = ("El objetivo: sobrevivir el año y dejar la cueva pintada "
		+ "con lo vivido. Si la banda se extingue, la partida termina ahí. "
		+ "Lo primero: repartir los oficios de la banda.")
	return moment
