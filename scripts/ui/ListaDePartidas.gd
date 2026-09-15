class_name ListaDePartidas
extends VBoxContainer
## La lista de partidas guardadas: una sola, la misma en el menú principal y en
## el modal de ESC.
##
## Spec: `docs/INTERFAZ.md` §7. Cada fila se arma con la CABECERA de su partida
## —ver [Partidas.lista]— y no con un índice aparte: un índice aparte se
## desincroniza en cuanto alguien borra una carpeta a mano, y entonces la lista
## ofrece partidas que no están.

## La partida que el jugador ha elegido cargar.
signal elegida(id: String)

## Se ha borrado una; quien la enseñe decide si tiene algo más que refrescar.
signal cambiada

## Los nombres de los emplazamientos, para poder decir DÓNDE está la banda y no
## sólo el número del mapa. Lo pone quien monta la lista, que es el único que
## sabe si el catálogo de sitios está cargado.
var sitios: SiteSet = null

var _confirmando := ""


func _init() -> void:
	add_theme_constant_override("separation", 6)


## Rehace la lista. Se llama al abrirla y después de borrar.
func refrescar() -> void:
	for hijo: Node in get_children():
		hijo.queue_free()
	_confirmando = ""

	var partidas := Partidas.lista()
	if partidas.is_empty():
		var vacio := Label.new()
		vacio.text = "No hay partidas guardadas todavía."
		vacio.add_theme_color_override("font_color", UISkin.INK_SOFT)
		add_child(vacio)
		return

	for entrada: Dictionary in partidas:
		add_child(_fila(entrada))


func _fila(entrada: Dictionary) -> Control:
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", UISkin.row_box())

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	marco.add_child(fila)

	var texto := VBoxContainer.new()
	texto.add_theme_constant_override("separation", 0)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(texto)

	var legible := bool(entrada.get("legible", false))
	var nombre := Label.new()
	nombre.text = String(entrada.get("nombre", "sin nombre"))
	nombre.add_theme_color_override("font_color",
		UISkin.INK if legible else UISkin.ALARM)
	texto.add_child(nombre)

	var pie := Label.new()
	pie.text = _resumen(entrada) if legible \
		else "De otra versión del juego: no se puede abrir."
	pie.add_theme_font_size_override("font_size", 11)
	pie.add_theme_color_override("font_color", UISkin.INK_SOFT)
	texto.add_child(pie)

	var id := String(entrada.get("id", ""))
	if legible:
		var abrir := Button.new()
		abrir.text = "Cargar"
		abrir.pressed.connect(func() -> void: elegida.emit(id))
		fila.add_child(abrir)

	var borrar := Button.new()
	borrar.text = "Borrar"
	borrar.pressed.connect(func() -> void: _pedir_borrado(id, borrar))
	fila.add_child(borrar)
	return marco


## Borrar pregunta. El segundo clic es el que borra, y el botón lo dice: es la
## confirmación más barata que no se salta sola.
func _pedir_borrado(id: String, boton: Button) -> void:
	if _confirmando == id:
		Partidas.borrar(id)
		refrescar()
		cambiada.emit()
		return
	_confirmando = id
	boton.text = "¿Seguro?"
	boton.add_theme_color_override("font_color", UISkin.ALARM)


## Lo que hace falta para elegir: dónde está la banda, en qué día y año, cuánta
## gente queda, y cuándo se guardó de verdad.
func _resumen(entrada: Dictionary) -> String:
	var partes: Array[String] = []
	var sitio := int(entrada.get("sitio", -1))
	partes.append(_donde(sitio))
	partes.append("día %d del año %d, %s" % [
		int(entrada.get("jornada", 0)), int(entrada.get("anyo", 1)),
		Subsistence.season_name(
			int(entrada.get("estacion", 0)) as Subsistence.Season).to_lower()])
	partes.append("%d personas" % int(entrada.get("poblacion", 0)))
	var cuando := int(entrada.get("cuando", 0))
	if cuando > 0:
		var fecha := Time.get_datetime_dict_from_unix_time(cuando)
		partes.append("guardada el %02d/%02d/%d a las %02d:%02d" % [
			int(fecha["day"]), int(fecha["month"]), int(fecha["year"]),
			int(fecha["hour"]), int(fecha["minute"])])
	return "  ·  ".join(partes)


func _donde(sitio: int) -> String:
	if sitios != null:
		for site: Site in sitios.sites:
			if site.id == sitio:
				return site.display_name()
	return "mapa %d" % sitio
