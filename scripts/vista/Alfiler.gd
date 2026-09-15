class_name Alfiler
extends RefCounted
## El alfiler de un marcador: la chapa con su glifo dentro, horneada una vez y
## compartida por todo el que la pida.
##
## Vivía dentro de [ParajeMarkers], y por eso las cuevas tenían marcador PROPIO
## —un cono amarillo con un rótulo— mientras los parajes y las cimas llevaban
## alfiler. Queja del usuario del 2026-09-13: «quiero que los markers de cuevas
## sigan el estilo de los markers que tenemos». Un estilo de marcador escrito en
## dos sitios acaba siendo dos estilos.
##
## El dibujo es el mismo [MateriaIcon] que usa el almacén, así que cambiar el
## glifo de una cosa lo cambia en los tres sitios donde sale.

## Tamaño de la chapa horneada, en píxeles.
const ANCHO := 72
const ALTO := 94

## Lo que mide un píxel de la chapa en metros del mundo. Lo usan el tamaño de la
## chapa y los radios de pinchado; va aquí para que no se separen.
const PIXEL := 0.14

## Las horneadas, por clave: `{"textura", "viewport"}`. Estáticas: hay una por
## material y son de 72x94, o sea nada, y así el alfiler de la avellana es el
## MISMO dibujo lo pida quien lo pida.
##
## **Con su viewport al lado**, porque es él lo que muere al cambiar de escena y
## no la textura. Se comprobaba `is_instance_valid(textura)`, que sigue siendo
## cierto con el viewport ya liberado: al volver del mapa regional los alfileres
## de lo ya horneado salían en blanco y la consola decía «Viewport Texture must be
## set to use it» —queja del usuario del 2026-09-14, «no me muestra ningún
## marcador de los que tenía, pero sí los nuevos»—. Ver `TestAlfiler`.
static var _horneados: Dictionary = {}


## La textura de un alfiler. `bajo` es el nodo del que cuelga el [SubViewport]
## que lo hornea: tiene que estar en el árbol.
static func textura(bajo: Node, clave: String, glyph: MateriaIcon.Glyph,
		tinte: Color) -> Texture2D:
	# La caché sobrevive a la escena y el SubViewport que horneó no: se mira EL
	# VIEWPORT antes de dar la textura. Ver [_horneados].
	var guardada: Dictionary = _horneados.get(clave, {})
	if not guardada.is_empty() and is_instance_valid(guardada["viewport"]):
		return guardada["textura"]

	var view := SubViewport.new()
	view.size = Vector2i(ANCHO, ALTO)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	bajo.add_child(view)

	var pin := ParajePin.new()
	pin.body_tint = tinte
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(pin)
	# El tamaño, DESPUÉS de entrar en el árbol: puesto antes se lo puede comer el
	# primer redimensionado y el Control se queda a cero, que se ve como un
	# alfiler en blanco.
	pin.size = Vector2(ANCHO, ALTO)

	# El glifo, centrado en la cabeza del alfiler y oscurecido para que se lea
	# sobre el hueco claro. El color sigue siendo el suyo.
	var cabeza := float(ANCHO) * 0.5 - ParajePin.BORDER
	var caja := cabeza * 0.9
	var icon := MateriaIcon.new()
	icon.glyph = glyph
	icon.tint = tinte.darkened(0.3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(icon)
	icon.size = Vector2(caja, caja)
	icon.position = Vector2(float(ANCHO) * 0.5 - caja * 0.5,
		ParajePin.BORDER + cabeza - caja * 0.5)

	var texture := view.get_texture()
	_horneados[clave] = {"textura": texture, "viewport": view}
	return texture
