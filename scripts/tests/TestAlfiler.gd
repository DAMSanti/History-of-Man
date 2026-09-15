class_name TestAlfiler
extends TestCase
## El alfiler horneado sobrevive a la escena que lo horneó.
##
## Queja del usuario del 2026-09-14: «he ido de la partida al mapa regional y
## vuelta; no me muestra ningún marcador de los que tenía, pero sí los que
## descubre nuevos», y en la consola «Viewport Texture must be set to use it».
## La caché de [Alfiler] es estática y la textura sale de un [SubViewport] que
## cuelga de la escena: al cambiar de escena el viewport se libera, la textura
## sigue siendo un objeto válido y se entregaba una textura sin viewport.


func suite_name() -> String:
	return "Alfiler"


func test_la_textura_de_una_escena_muerta_no_se_reutiliza() -> void:
	var clave := "prueba_alfiler_escena_muerta"
	Alfiler._horneados.erase(clave)
	var primera_escena := Node.new()
	var vieja := Alfiler.textura(primera_escena, clave, MateriaIcon.Glyph.BAYAS,
		Color.WHITE)
	assert_true(vieja != null, "se hornea")
	# La escena se va, y con ella el SubViewport que horneó el alfiler.
	primera_escena.free()

	var segunda_escena := Node.new()
	var nueva := Alfiler.textura(segunda_escena, clave, MateriaIcon.Glyph.BAYAS,
		Color.WHITE)
	assert_true(nueva != null, "se vuelve a hornear")
	assert_false(nueva == vieja,
		"no se entrega la textura de un viewport que ya no existe")

	# Y mientras la escena siga viva, sí se comparte: es para lo que está la caché.
	var otra_vez := Alfiler.textura(segunda_escena, clave, MateriaIcon.Glyph.BAYAS,
		Color.WHITE)
	assert_true(otra_vez == nueva, "con la escena viva, la misma")
	segunda_escena.free()
	Alfiler._horneados.erase(clave)
