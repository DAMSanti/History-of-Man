class_name PanelRelaciones
extends RefCounted
## Lo que se sabe de las otras bandas: cada una conocida, dónde vive, el trato, y
## lo que se ha cambiado con ella.
##
## Frente 26 de EPOCA_01 §10.1, tanda 4. Sólo lee [Contacto] y el historial de
## [Intercambio].

var ui: GameUI

## Los emplazamientos, para ponerle nombre a cada banda. Se cargan una vez.
static var _sitios: SiteSet = null


func _init(panel: GameUI) -> void:
	ui = panel


## El nombre del sitio donde vive una banda.
static func nombre_de(id: int) -> String:
	if _sitios == null:
		_sitios = SiteSet.comarca()
	if _sitios != null:
		for site: Site in _sitios.sites:
			if site.id == id:
				return "La gente de %s" % site.display_name()
	return "La gente de más allá"


## El trato, en palabras. Las lindes son las del trueque: cada cincuenta de
## trato mueve un cuarto el precio. Ver [Intercambio.TRATO_QUE_DOBLA].
static func como_va(trato: float) -> String:
	if trato >= 50.0:
		return "muy bueno"
	if trato >= 10.0:
		return "bueno"
	if trato > -10.0:
		return "ni bueno ni malo"
	if trato > -50.0:
		return "malo"
	return "muy malo"


## Una fila por banda CONOCIDA, y ninguna de las que no: `{id, nombre, trato,
## tratos, ultimo}`. Ordenadas por id, que no dependa del orden del diccionario.
static func filas(sim: SettlementSim) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	if sim == null or sim.contacto == null:
		return salida
	var ids: Array = sim.contacto.trato.keys()
	ids.sort()
	for id: int in ids:
		var tratos := 0
		var ultimo := -1
		for hecho: Dictionary in sim.intercambio.historial:
			if int(hecho["con"]) == id:
				tratos += 1
				ultimo = maxi(ultimo, int(hecho["dia"]))
		salida.append({"id": id, "nombre": nombre_de(id),
			"trato": sim.contacto.trato_con(id), "tratos": tratos, "ultimo": ultimo})
	return salida


func show_relations() -> void:
	var body := ui._window("relaciones", "Relaciones")
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return
	var todas := filas(ui.sim)
	if todas.is_empty():
		ui._text(body, "No se conoce a ninguna otra banda todavía.")
		return
	for fila: Dictionary in todas:
		ui._heading(body, String(fila["nombre"]).to_upper())
		ui._text(body, "Trato %s." % como_va(float(fila["trato"])))
		if int(fila["tratos"]) == 0:
			ui._text(body, "No se ha cambiado nada con ellos.", true)
		else:
			ui._text(body, "%d %s. El último, el día %d." % [int(fila["tratos"]),
				"trato" if int(fila["tratos"]) == 1 else "tratos", int(fila["ultimo"])], true)
