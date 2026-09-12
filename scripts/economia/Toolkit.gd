class_name Toolkit
extends RefCounted
## El utillaje de la banda: todas las piezas, cada una con su desgaste.
##
## Esto es lo que convierte la manufactura en algo necesario en vez de en un
## adorno. Sin filo no se despieza, sin buril no se ranura el asta, sin cesto se
## trae a puñados lo que cabría en una carga. Las piezas se gastan y hay que
## reponerlas, así que la demanda del taller sale sola del uso y no de una cuota
## que haya que inventarse.

## Todas las piezas que tiene la banda, gastadas o no.
var pieces: Array[Tool] = []

## Piezas que se han roto hoy. Se vuelca a la crónica y se limpia cada jornada.
var broken_today: Array[String] = []

## Rendimiento cuando NO se tiene la herramienta que pide el trabajo.
##
## No es cero en casi ningún caso: sin azagaya se sigue cazando con trampa y
## carroñeo, y sin cesto se recolecta a brazadas. Pero el asta SÍ es cero,
## porque ranurar un asta sin buril no es que sea lento, es que no se hace.
const NO_TOOL_FLOOR := {
	# Sin azagaya no se deja de cazar: se caza con estaca endurecida al fuego,
	# con trampa y con ojeo. Cunde poco -y por eso el astero importa- pero
	# 0,25 castigaba dos veces, porque encima la pieza mayor no aparece en
	# cualquier ladera.
	Tool.Kind.AZAGAYA: 0.35,
	Tool.Kind.ARPON: 0.30,
	Tool.Kind.LASCA: 0.35,
	Tool.Kind.CESTO: 0.55,
	Tool.Kind.RAEDERA: 0.15,
	Tool.Kind.BURIL: 0.0,
	Tool.Kind.AGUJA: 0.40,
	Tool.Kind.PUNZON: 0.50,
	Tool.Kind.ODRE: 0.60,
	Tool.Kind.CUERDA: 0.45,
	Tool.Kind.PUNTA: 0.30,
	# Los aparejos de pesca no tienen suelo de verdad: sin ellos no se pesca
	# de esa manera, se pesca de la anterior -ver `Fishing.best_for`. El
	# numero solo cubre el hueco de un tick entre que se rompe la ultima
	# pieza y el reparto se entera.
	Tool.Kind.NASA: 0.35,
	Tool.Kind.ANZUELO: 0.35,
	Tool.Kind.RED: 0.35,
	# La lampara SI es cero, y es de las pocas. Sin luz no se pinta una cueva
	# despacio ni deprisa: no se pinta. Ver `SettlementSim._paint_wall`.
	Tool.Kind.LAMPARA: 0.0,
}


func add(tool: Tool) -> void:
	pieces.append(tool)


## Fabrica y guarda una pieza de una vez.
func craft(kind: Tool.Kind, stuff: Tool.Stuff, skill: float = 0.5) -> Tool:
	var tool := Tool.make(kind, stuff, skill)
	add(tool)
	return tool


## Piezas utilizables de un tipo.
func count(kind: Tool.Kind) -> int:
	var total := 0
	for tool: Tool in pieces:
		if tool.kind == kind and not tool.is_spent():
			total += 1
	return total


func total_count() -> int:
	var total := 0
	for tool: Tool in pieces:
		if not tool.is_spent():
			total += 1
	return total


## La pieza que toca usar de un tipo, o null si no queda ninguna.
##
## Se coge la MÁS gastada de las que aún sirven. Es lo que hace cualquiera con
## una herramienta desechable —se apura la que está a medias antes de estrenar
## otra— y de paso deja siempre piezas frescas en reserva en vez de tener todo
## el utillaje a medio gastar a la vez.
func pick(kind: Tool.Kind) -> Tool:
	var chosen: Tool = null
	var worst := -1.0
	for tool: Tool in pieces:
		if tool.kind != kind or tool.is_spent():
			continue
		if tool.used > worst:
			worst = tool.used
			chosen = tool
	return chosen


## Saca una pieza del utillaje y la devuelve, o null si no queda ninguna.
##
## Distinto de [pick], que devuelve la pieza SIN sacarla para poder gastarla y
## dejarla donde estaba. Esto es para lo que se lleva y se deja puesto: una
## nasa calada en el río está en el río, no en el abrigo, y mientras esté allí
## no la puede usar nadie ni cuenta para la cobertura del taller. Ver [Nasa].
func detach(kind: Tool.Kind) -> Tool:
	var tool := pick(kind)
	if tool == null:
		return null
	pieces.erase(tool)
	return tool


## Usa una pieza del tipo pedido. Devuelve si había alguna.
##
## `amount` son usos: una jornada entera de despiece gasta bastante más que un
## rato de trabajo.
func use(kind: Tool.Kind, amount: float = 1.0) -> bool:
	broke_last_use = ""
	var tool := pick(kind)
	if tool == null:
		return false
	if tool.wear(amount):
		broken_today.append(tool.display_name())
		# Se apunta APARTE de `broken_today` porque quien llama necesita saber
		# que se ha roto AHORA, en este uso, para poder contarlo con el nombre
		# de quien la llevaba. `broken_today` es el recuento de la jornada.
		broke_last_use = tool.display_name()
	return true


## Qué pieza se ha roto en la última llamada a [use], o vacío si ninguna.
var broke_last_use: String = ""


## Gasta TODAS las piezas de un tipo por igual, en vez de sólo la peor.
##
## `use()` es para lo que gasta UNA persona trabajando con UNA pieza; esto es
## para lo que se lleva puesto todo el rato -el vestido, ver [Tool.Kind.VESTIDO]-,
## donde cada pieza que existe se desgasta un poco cada jornada, la use quien
## la use.
func wear_all(kind: Tool.Kind, amount: float) -> void:
	for tool: Tool in pieces:
		if tool.kind == kind and not tool.is_spent():
			tool.wear(amount)


## Cuánto rinde un trabajo según el filo disponible, de 0 a 1.
##
## `needed` es cuántas piezas pide el trabajo para ir a pleno rendimiento -una
## por persona, normalmente-. Con la mitad se rinde a medias, y con ninguna se
## cae al suelo del tipo, que casi nunca es cero.
func efficiency(kind: Tool.Kind, needed: int = 1) -> float:
	var floor_value: float = float(NO_TOOL_FLOOR.get(kind, 0.3))
	if needed <= 0:
		return 1.0
	var have := count(kind)
	if have <= 0:
		return floor_value
	var coverage := minf(float(have) / float(needed), 1.0)
	return floor_value + (1.0 - floor_value) * coverage


## Estado medio del filo de un tipo, de 1 (nuevo) a 0. -1 si no hay ninguno.
func condition(kind: Tool.Kind) -> float:
	var total := 0.0
	var pieces_found := 0
	for tool: Tool in pieces:
		if tool.kind == kind and not tool.is_spent():
			total += tool.condition()
			pieces_found += 1
	if pieces_found == 0:
		return -1.0
	return total / float(pieces_found)


## Lo gastada que está la PEOR pieza de un tipo, de 1 (nueva) a 0. -1 si no hay.
##
## No es lo mismo que [condition], que da la media, y la diferencia importa
## para lo que se enseña: la media no se mueve cuando una sola pieza se está
## acabando, y es justo ésa la que se va a romper. El jugador tiene que poder
## mandar coser ANTES de quedarse sin abrigo, no después. Ver INTERFAZ.md §4.
func peor_condicion(kind: Tool.Kind) -> float:
	var peor := -1.0
	for tool: Tool in pieces:
		if tool.kind != kind or tool.is_spent():
			continue
		var suya := tool.condition()
		if peor < 0.0 or suya < peor:
			peor = suya
	return peor


## Tira las piezas agotadas. Devuelve cuántas se han retirado.
##
## Se hace al cerrar la jornada, no en el momento de romperse, para que el
## parte del día pueda contarlas.
func discard_spent() -> int:
	var kept: Array[Tool] = []
	var removed := 0
	for tool: Tool in pieces:
		if tool.is_spent():
			removed += 1
		else:
			kept.append(tool)
	pieces = kept
	return removed


## Qué hay en el taller, por tipo, para el panel de almacén.
##
## Va ordenado de menos a más existencias: lo primero que se lee es lo que está
## a punto de faltar, que es la información que hace falta.
func summary() -> Array[Dictionary]:
	var by_kind := {}
	for tool: Tool in pieces:
		if tool.is_spent():
			continue
		by_kind[tool.kind] = int(by_kind.get(tool.kind, 0)) + 1

	var rows: Array[Dictionary] = []
	for kind: int in by_kind:
		rows.append({
			"kind": kind,
			"name": Tool.kind_name(kind as Tool.Kind),
			"count": int(by_kind[kind]),
			"condition": condition(kind as Tool.Kind),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["count"]) < int(b["count"]))
	return rows
