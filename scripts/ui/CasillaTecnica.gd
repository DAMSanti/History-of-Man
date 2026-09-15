class_name CasillaTecnica
extends PanelContainer
## La casilla de una técnica en el árbol, con su aviso emergente escrito en
## BBCode.
##
## Existe por el aviso: el de Godot es texto plano, y el usuario pidió el
## 2026-09-13 que lo que le falta a una técnica saliera EN ROJO dentro de él. El
## texto lo compone [TechGraph._tooltip]; esto sólo lo pinta con color.

## Ancho del aviso. Sin él, un RichTextLabel que se ajusta al contenido se
## queda en una columna de una letra.
const ANCHO_DEL_AVISO := 380.0


func _make_custom_tooltip(for_text: String) -> Object:
	var texto := RichTextLabel.new()
	texto.bbcode_enabled = true
	texto.fit_content = true
	texto.scroll_active = false
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size = Vector2(ANCHO_DEL_AVISO, 0.0)
	texto.text = for_text
	return texto
