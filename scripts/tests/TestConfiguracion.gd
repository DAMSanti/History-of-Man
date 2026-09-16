class_name TestConfiguracion
extends TestCase
## La configuración del equipo: INTERFAZ §8.
##
## Lo que se comprueba aquí es el fichero y las reglas de los niveles. Que se
## aplica al abrir el juego lo mira `ConfiguracionProbe`, con dos procesos; que se
## aplica en caliente, sobre la escena montada.

## LA RUTA DE LAS PRUEBAS, nunca la del jugador. Ver [Configuracion.ruta].
const RUTA_DE_PRUEBAS := "user://pruebas/configuracion.cfg"

var _ruta_antes := ""


func suite_name() -> String:
	return "Configuracion"


func before_each() -> void:
	if _ruta_antes.is_empty():
		_ruta_antes = Configuracion.ruta
	Configuracion.ruta = RUTA_DE_PRUEBAS
	Configuracion.por_defecto()
	if FileAccess.file_exists(RUTA_DE_PRUEBAS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_DE_PRUEBAS))


func test_las_pruebas_no_tocan_la_del_jugador() -> void:
	assert_true(Configuracion.ruta != Configuracion.RUTA, "las pruebas escriben en su carpeta")


func test_lo_que_se_elige_es_lo_que_queda() -> void:
	Configuracion.modo = Configuracion.Modo.VENTANA
	Configuracion.resolucion = Vector2i(1366, 768)
	Configuracion.vsync = false
	Configuracion.tope = 120
	Configuracion.poner_nivel(Configuracion.Nivel.ALTO)
	Configuracion.poner_ajuste("nubes", 6)
	Configuracion.poner_ajuste("escala", 0.77)
	Configuracion.volumen_general = 0.4
	Configuracion.volumen_musica = 0.25
	Configuracion.volumen_efectos = 0.9
	var graficos := Configuracion.graficos.duplicate()
	assert_eq(Configuracion.guardar(), OK, "se guarda")
	Configuracion.por_defecto()
	assert_true(Configuracion.cargar(), "y se vuelve a leer")
	assert_eq(Configuracion.modo, Configuracion.Modo.VENTANA, "el modo")
	assert_eq(Configuracion.resolucion, Vector2i(1366, 768), "la resolución")
	assert_false(Configuracion.vsync, "la sincronización")
	assert_eq(Configuracion.tope, 120, "el tope")
	for nombre: String in Configuracion.AJUSTES:
		assert_near(float(Configuracion.graficos[nombre]), float(graficos[nombre]), 0.0001,
			"el ajuste %s" % nombre)
	assert_eq(Configuracion.nivel, Configuracion.Nivel.PERSONALIZADO, "y el nivel, personalizado")
	assert_near(Configuracion.volumen_general, 0.4, 0.0001, "el volumen general")
	assert_near(Configuracion.volumen_musica, 0.25, 0.0001, "el de la música")
	assert_near(Configuracion.volumen_efectos, 0.9, 0.0001, "y el de los efectos")


func test_sin_fichero_queda_lo_de_siempre() -> void:
	Configuracion.nivel = Configuracion.Nivel.ULTRA
	assert_false(Configuracion.cargar(), "no hay nada que leer")
	assert_eq(Configuracion.nivel, Configuracion.Nivel.MEDIO, "Medio")
	assert_eq(Configuracion.modo, Configuracion.Modo.MAXIMIZADA, "y la ventana maximizada de siempre")


func test_bajo_fija_sus_ajustes() -> void:
	_un_nivel_fija_sus_ajustes(Configuracion.Nivel.BAJO)


func test_medio_fija_sus_ajustes() -> void:
	_un_nivel_fija_sus_ajustes(Configuracion.Nivel.MEDIO)


func test_alto_fija_sus_ajustes() -> void:
	_un_nivel_fija_sus_ajustes(Configuracion.Nivel.ALTO)


func test_ultra_fija_sus_ajustes() -> void:
	_un_nivel_fija_sus_ajustes(Configuracion.Nivel.ULTRA)


func _un_nivel_fija_sus_ajustes(cual: Configuracion.Nivel) -> void:
	Configuracion.poner_nivel(Configuracion.Nivel.BAJO if cual != Configuracion.Nivel.BAJO
		else Configuracion.Nivel.ULTRA)
	Configuracion.poner_nivel(cual)
	var tabla: Dictionary = Configuracion.NIVELES[cual]
	for nombre: String in Configuracion.AJUSTES:
		assert_near(float(Configuracion.graficos[nombre]), float(tabla[nombre]), 0.0001,
			"%s: %s" % [Configuracion.nombre_del_nivel(cual), nombre])
	assert_eq(Configuracion.nivel, cual, "y queda puesto")
	Configuracion.poner_ajuste("nubes", 7)
	assert_eq(Configuracion.nivel, Configuracion.Nivel.PERSONALIZADO,
		"tocar un ajuste después lo deja en Personalizado")


func test_cada_nivel_pone_su_escalon_de_arboles() -> void:
	# INTERFAZ §8.7: Bajo, el bosque Mínimo de siempre; los demás, el de su nombre.
	var esperado := {Configuracion.Nivel.BAJO: 0, Configuracion.Nivel.MEDIO: 1,
		Configuracion.Nivel.ALTO: 2, Configuracion.Nivel.ULTRA: 3}
	for cual: int in esperado:
		Configuracion.poner_nivel(cual as Configuracion.Nivel)
		assert_eq(int(Configuracion.graficos["arboles"]), int(esperado[cual]),
			"%s: árboles" % Configuracion.nombre_del_nivel(cual as Configuracion.Nivel))
	var distancias := {Configuracion.Nivel.MEDIO: 40.0, Configuracion.Nivel.ALTO: 70.0,
		Configuracion.Nivel.ULTRA: 120.0}
	for cual: int in distancias:
		Configuracion.poner_nivel(cual as Configuracion.Nivel)
		assert_near(float(Configuracion.graficos["radio_3d"]), float(distancias[cual]), 0.001,
			"%s: la distancia de su escalón" % Configuracion.nombre_del_nivel(cual as Configuracion.Nivel))
	Configuracion.poner_nivel(Configuracion.Nivel.MEDIO)
	Configuracion.poner_ajuste("radio_3d", Configuracion.RADIO_3D_MAXIMO)
	assert_eq(Configuracion.nivel, Configuracion.Nivel.PERSONALIZADO,
		"mover la distancia del 3D personaliza")
	assert_false(Configuracion.AL_MONTAR_EL_MAPA.has("radio_3d"), "y se aplica en caliente")
	assert_near(VentanaDeConfiguracion.DISTANCIAS_3D[-1], Configuracion.RADIO_3D_MAXIMO, 0.001,
		"el último punto del slider es el máximo, 1000 m: «sin límite» rompía el motor")
	assert_eq(VentanaDeConfiguracion.texto_de_distancia(Configuracion.RADIO_3D_MAXIMO), "1000 m",
		"y se lee en metros")
	assert_true(VentanaDeConfiguracion.DISTANCIAS_3D[0] <= 10.0, "y el primero, 10 m")
	Configuracion.poner_nivel(Configuracion.Nivel.MEDIO)
	Configuracion.poner_ajuste("arboles", 3)
	assert_eq(Configuracion.nivel, Configuracion.Nivel.PERSONALIZADO,
		"Medio con árboles Ultra ya no es Medio")
	assert_true(Configuracion.AL_MONTAR_EL_MAPA.has("arboles"),
		"y no se aplica en caliente: la ventana lo avisa")


func test_un_fichero_de_antes_de_los_arboles_sigue_en_su_nivel() -> void:
	var fichero := ConfigFile.new()
	fichero.set_value("graficos", "nivel", int(Configuracion.Nivel.BAJO))
	var bajo: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.BAJO]
	for nombre: String in Configuracion.AJUSTES:
		if nombre != "arboles":
			fichero.set_value("graficos", nombre, bajo[nombre])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Configuracion.ruta.get_base_dir()))
	assert_eq(fichero.save(Configuracion.ruta), OK, "se escribe un fichero sin árboles")
	Configuracion.cargar()
	assert_eq(Configuracion.nivel, Configuracion.Nivel.BAJO, "sigue en Bajo, no en Personalizado")
	assert_eq(int(Configuracion.graficos["arboles"]), 0, "con el bosque de Bajo")


## Un fichero guardado con la distancia «sin límite» de antes (100 km) no se aplica tal
## cual: con todos los árboles del mapa en 3D Godot se queda sin identificadores y deja de
## montar el bosque (GRAFICOS §7.1, 2026-09-15). Se lee como el máximo.
func test_la_distancia_sin_limite_guardada_se_lee_como_el_maximo() -> void:
	var fichero := ConfigFile.new()
	fichero.set_value("graficos", "nivel", int(Configuracion.Nivel.ULTRA))
	var ultra: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.ULTRA]
	for nombre: String in Configuracion.AJUSTES:
		fichero.set_value("graficos", nombre, ultra[nombre])
	fichero.set_value("graficos", "radio_3d", 100000.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Configuracion.ruta.get_base_dir()))
	assert_eq(fichero.save(Configuracion.ruta), OK, "se escribe un fichero con la distancia de antes")
	Configuracion.cargar()
	assert_near(float(Configuracion.graficos["radio_3d"]), Configuracion.RADIO_3D_MAXIMO, 0.001,
		"se lee como el máximo del slider")


func test_ultra_es_el_maximo_de_cada_ajuste() -> void:
	# Decisión del usuario: Ultra no tiene límite.
	var ultra: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.ULTRA]
	for cual: int in Configuracion.NIVELES:
		var tabla: Dictionary = Configuracion.NIVELES[cual]
		for nombre: String in Configuracion.AJUSTES:
			assert_true(float(ultra[nombre]) >= float(tabla[nombre]),
				"Ultra no queda por debajo de %s en %s" % [
					Configuracion.nombre_del_nivel(cual as Configuracion.Nivel), nombre])


func test_los_niveles_van_de_menos_a_mas() -> void:
	var bajo: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.BAJO]
	var medio: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.MEDIO]
	var alto: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.ALTO]
	var mal := 0
	for nombre: String in Configuracion.AJUSTES:
		if float(bajo[nombre]) > float(medio[nombre]) or float(medio[nombre]) > float(alto[nombre]):
			mal += 1
	assert_eq(mal, 0, "ningún ajuste baja al subir de nivel")


func test_las_resoluciones_van_de_mayor_a_menor_y_caben() -> void:
	var lista := Configuracion.resoluciones()
	var nativa := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	assert_gt(float(lista.size()), 0.0, "hay alguna")
	var desordenadas := 0
	var no_caben := 0
	for i in range(lista.size()):
		if i > 0 and lista[i].x * lista[i].y > lista[i - 1].x * lista[i - 1].y:
			desordenadas += 1
		if nativa.x > 0 and (lista[i].x > nativa.x or lista[i].y > nativa.y):
			no_caben += 1
	assert_eq(desordenadas, 0, "de mayor a menor")
	assert_eq(no_caben, 0, "y ninguna más grande que el monitor")


func test_los_volumenes_llegan_a_sus_buses() -> void:
	Configuracion.volumen_general = 0.5
	Configuracion.volumen_musica = 0.0
	Configuracion.volumen_efectos = 1.0
	Configuracion.aplicar_sonido()
	var general := AudioServer.get_bus_index(Configuracion.BUS_GENERAL)
	var musica := AudioServer.get_bus_index(Configuracion.BUS_MUSICA)
	var efectos := AudioServer.get_bus_index(Configuracion.BUS_EFECTOS)
	assert_true(musica >= 0 and efectos >= 0, "los buses existen")
	assert_near(AudioServer.get_bus_volume_db(general), linear_to_db(0.5), 0.01, "el general a la mitad")
	assert_true(AudioServer.is_bus_mute(musica), "la música a cero, callada")
	assert_near(AudioServer.get_bus_volume_db(efectos), 0.0, 0.01, "los efectos enteros")
	assert_eq(AudioServer.get_bus_send(musica), Configuracion.BUS_GENERAL, "y pasan por el general")
	Configuracion.volumen_general = 1.0
	Configuracion.volumen_musica = 1.0
	Configuracion.aplicar_sonido()


func test_el_tope_llega_al_motor() -> void:
	var antes := Engine.max_fps
	Configuracion.tope = 60
	Configuracion.aplicar_pantalla()
	var puesto := Engine.max_fps
	Configuracion.tope = 0
	Engine.max_fps = antes
	assert_eq(puesto, 60, "el tope de fotogramas es el del motor")


# --- la ventana --------------------------------------------------------------------

func test_la_cuenta_atras_vuelve_a_lo_de_antes_si_no_se_confirma() -> void:
	Configuracion.modo = Configuracion.Modo.MAXIMIZADA
	Configuracion.resolucion = Vector2i(1920, 1080)
	var ventana := VentanaDeConfiguracion.new()
	ventana.elegir_modo(Configuracion.Modo.VENTANA)
	ventana.elegir_resolucion(Vector2i(1280, 720))
	var esperando := ventana.pendiente
	var puesto := Configuracion.resolucion
	ventana.avanzar(9.9)
	var a_los_nueve := ventana.pendiente
	ventana.avanzar(0.2)
	var vuelto_modo := Configuracion.modo
	var vuelta_resolucion := Configuracion.resolucion
	var guardado := Configuracion.cargar()
	var en_disco := Configuracion.resolucion
	ventana.free()
	assert_true(esperando, "cambiar la resolución espera confirmación")
	assert_eq(puesto, Vector2i(1280, 720), "y mientras tanto está puesta")
	assert_true(a_los_nueve, "a los 9,9 s todavía espera")
	assert_eq(vuelto_modo, Configuracion.Modo.MAXIMIZADA, "a los 10 s vuelve el modo de antes")
	assert_eq(vuelta_resolucion, Vector2i(1920, 1080), "y la resolución de antes")
	assert_true(guardado, "y queda guardado")
	assert_eq(en_disco, Vector2i(1920, 1080), "lo de antes, no lo que se probó")


func test_confirmando_se_queda() -> void:
	Configuracion.modo = Configuracion.Modo.MAXIMIZADA
	var ventana := VentanaDeConfiguracion.new()
	ventana.elegir_modo(Configuracion.Modo.VENTANA)
	ventana.confirmar()
	ventana.avanzar(20.0)
	var modo := Configuracion.modo
	Configuracion.cargar()
	var en_disco := Configuracion.modo
	ventana.free()
	assert_eq(modo, Configuracion.Modo.VENTANA, "confirmado, la cuenta atrás no lo deshace")
	assert_eq(en_disco, Configuracion.Modo.VENTANA, "y se guarda")


func test_desde_la_ventana_el_nivel_fija_y_el_ajuste_personaliza() -> void:
	var ventana := VentanaDeConfiguracion.new()
	ventana.elegir_nivel(Configuracion.Nivel.BAJO)
	var bajo := Configuracion.graficos.duplicate()
	ventana.elegir_ajuste("niebla", true)
	var nivel := Configuracion.nivel
	Configuracion.cargar()
	var en_disco := Configuracion.nivel
	ventana.free()
	assert_eq(bajo, Configuracion.NIVELES[Configuracion.Nivel.BAJO], "elegir Bajo pone lo de Bajo")
	assert_eq(nivel, Configuracion.Nivel.PERSONALIZADO, "y tocar la niebla, Personalizado")
	assert_eq(en_disco, Configuracion.Nivel.PERSONALIZADO, "guardado al momento")


## Los controles de una ventana, en orden: clase y texto.
func _controles(nodo: Node) -> Array[String]:
	var salida: Array[String] = []
	var texto := ""
	if nodo is Label:
		texto = (nodo as Label).text
	elif nodo is Button:
		texto = (nodo as Button).text
	if nodo is Control:
		salida.append("%s:%s" % [nodo.get_class(), texto])
	for hijo: Node in nodo.get_children():
		salida.append_array(_controles(hijo))
	return salida


func test_los_dos_menus_abren_la_misma_ventana() -> void:
	var principal := MenuPrincipal.new()
	var de_esc := MenuDelJuego.new()
	var una := principal.abrir_configuracion()
	var otra := de_esc.abrir_configuracion()
	var controles_una := _controles(una)
	var controles_otra := _controles(otra)
	principal.free()
	de_esc.free()
	assert_gt(float(controles_una.size()), 10.0, "la ventana tiene sus controles")
	assert_eq(controles_una, controles_otra, "y son los mismos desde los dos menús")


## GRAFICOS §7.3: el agua tiene su escalón en cada nivel —el de su mismo nombre—, y
## moverla personaliza.
func test_cada_nivel_pone_su_agua() -> void:
	var esperado := {Configuracion.Nivel.BAJO: 0, Configuracion.Nivel.MEDIO: 1,
		Configuracion.Nivel.ALTO: 2, Configuracion.Nivel.ULTRA: 3}
	for cual: int in esperado:
		Configuracion.poner_nivel(cual as Configuracion.Nivel)
		assert_eq(int(Configuracion.graficos.get("agua", -1)), int(esperado[cual]),
			"%s: agua" % Configuracion.nombre_del_nivel(cual as Configuracion.Nivel))
	Configuracion.poner_nivel(Configuracion.Nivel.MEDIO)
	Configuracion.poner_ajuste("agua", 3)
	assert_eq(Configuracion.nivel, Configuracion.Nivel.PERSONALIZADO, "Medio con agua Ultra ya no es Medio")
	assert_true(VentanaDeConfiguracion.NIVELES_DE_AGUA.size() == 4, "y la ventana ofrece los cuatro")


## Un fichero de antes del agua abre en su nivel, con el agua de ese nivel.
func test_un_fichero_de_antes_del_agua_sigue_en_su_nivel() -> void:
	var fichero := ConfigFile.new()
	fichero.set_value("graficos", "nivel", int(Configuracion.Nivel.ALTO))
	var alto: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.ALTO]
	for nombre: String in Configuracion.AJUSTES:
		if nombre != "agua":
			fichero.set_value("graficos", nombre, alto[nombre])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Configuracion.ruta.get_base_dir()))
	assert_eq(fichero.save(Configuracion.ruta), OK, "se escribe un fichero sin agua")
	Configuracion.cargar()
	assert_eq(Configuracion.nivel, Configuracion.Nivel.ALTO, "sigue en Alto, no en Personalizado")
	assert_eq(int(Configuracion.graficos.get("agua", -1)), 2, "con el agua de Alto")


## GRAFICOS §7.4: el clima encendido en Medio, Alto y Ultra y apagado en Bajo, y moverlo
## personaliza.
func test_cada_nivel_pone_su_clima() -> void:
	var esperado := {Configuracion.Nivel.BAJO: false, Configuracion.Nivel.MEDIO: true,
		Configuracion.Nivel.ALTO: true, Configuracion.Nivel.ULTRA: true}
	for cual: int in esperado:
		Configuracion.poner_nivel(cual as Configuracion.Nivel)
		assert_eq(bool(Configuracion.graficos.get("clima", null)), bool(esperado[cual]),
			"%s: clima" % Configuracion.nombre_del_nivel(cual as Configuracion.Nivel))
	Configuracion.poner_nivel(Configuracion.Nivel.ALTO)
	Configuracion.poner_ajuste("clima", false)
	assert_eq(Configuracion.nivel, Configuracion.Nivel.PERSONALIZADO, "Alto sin clima ya no es Alto")


## Un fichero de antes del clima abre en su nivel, con el clima de ese nivel.
func test_un_fichero_de_antes_del_clima_sigue_en_su_nivel() -> void:
	var fichero := ConfigFile.new()
	fichero.set_value("graficos", "nivel", int(Configuracion.Nivel.BAJO))
	var bajo: Dictionary = Configuracion.NIVELES[Configuracion.Nivel.BAJO]
	for nombre: String in Configuracion.AJUSTES:
		if nombre != "clima":
			fichero.set_value("graficos", nombre, bajo[nombre])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Configuracion.ruta.get_base_dir()))
	assert_eq(fichero.save(Configuracion.ruta), OK, "se escribe un fichero sin clima")
	Configuracion.cargar()
	assert_eq(Configuracion.nivel, Configuracion.Nivel.BAJO, "sigue en Bajo, no en Personalizado")
	assert_eq(bool(Configuracion.graficos.get("clima", true)), false, "con el clima de Bajo, apagado")


# --- El relieve de las texturas, por nivel (GRAFICOS §4, 2026-09-16) ---------
#
# Sale del nivel y no de un ajuste propio: decisión del usuario, «parallax de
# verdad en Alto y Ultra». Lo que hay que asegurar es que Bajo y Medio no pagan
# nada y que Personalizado lo decide por el agua, que es la medida del equipo.


func test_el_relieve_solo_va_en_alto_y_ultra() -> void:
	Configuracion.poner_nivel(Configuracion.Nivel.BAJO)
	assert_eq(Configuracion.pasos_de_relieve(), 0, "Bajo, sin relieve")
	Configuracion.poner_nivel(Configuracion.Nivel.MEDIO)
	assert_eq(Configuracion.pasos_de_relieve(), 0, "Medio, sin relieve")
	Configuracion.poner_nivel(Configuracion.Nivel.ALTO)
	assert_true(Configuracion.pasos_de_relieve() > 0, "Alto, con relieve")
	var alto := Configuracion.pasos_de_relieve()
	Configuracion.poner_nivel(Configuracion.Nivel.ULTRA)
	assert_true(Configuracion.pasos_de_relieve() > alto, "y Ultra, con más pasos")


func test_en_personalizado_el_relieve_va_con_el_agua_de_alto() -> void:
	# Quien quita la lámina del río de Alto está diciendo que el equipo no da
	# para más: tampoco paga el relieve.
	Configuracion.poner_nivel(Configuracion.Nivel.ALTO)
	Configuracion.poner_ajuste("sombras", Configuracion.Sombras.BAJAS)
	assert_eq(Configuracion.nivel, Configuracion.Nivel.PERSONALIZADO,
		"tocar un ajuste deja el nivel en Personalizado")
	assert_true(Configuracion.pasos_de_relieve() > 0, "con el agua de Alto, relieve")
	Configuracion.poner_ajuste("agua", 1)
	assert_eq(Configuracion.pasos_de_relieve(), 0, "con el agua de Medio, no")
