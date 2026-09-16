class_name Configuracion
extends RefCounted
## La configuración del equipo: pantalla, gráficos y sonido.
##
## INTERFAZ §8. **No es de la partida**: es de quien juega y del equipo en el que
## juega, así que no va en `Guardado` ni en `Partidas` sino en su propio fichero,
## y se aplica al abrir el juego antes de la primera pantalla.
##
## Estado estático, como `GameState` —sin autoload, SPECS §2.2—. **Los niveles
## viven aquí y sólo aquí** ([NIVELES]): la tabla de GRAFICOS §7 los copia con su
## coste, y si las dos discreparan, gana ésta.

enum Nivel { BAJO, MEDIO, ALTO, ULTRA, PERSONALIZADO }
enum Modo { PANTALLA_COMPLETA, VENTANA, MAXIMIZADA }

## Las sombras de la luz del sol, de peor a mejor. Ver [_SOMBRAS].
enum Sombras { APAGADAS, BAJAS, MEDIAS, ALTAS, ULTRA }

## El sombreado de contacto: nada, SSAO, o SSAO con la luz rebotada de SSIL.
enum Oclusion { NADA, SSAO, SSAO_Y_SSIL }

## Dónde se guarda DE VERDAD. Es la del jugador en el juego y otra en las pruebas
## y las sondas, por lo mismo que `Guardado.carpeta`: una prueba no toca nunca lo
## del jugador. Una sonda de dos procesos la pasa por `CONFIGURACION=`.
const RUTA := "user://configuracion.cfg"
static var ruta: String = OS.get_environment("CONFIGURACION") \
	if not OS.get_environment("CONFIGURACION").is_empty() else RUTA

## Los topes de fotogramas que se pueden elegir. Cero es sin tope.
const TOPES: Array[int] = [0, 30, 60, 120, 144]

## Las resoluciones habituales que se ofrecen si caben en el monitor. Godot no
## sabe listar los modos del monitor —sólo su tamaño nativo—, así que la lista es
## la nativa y éstas. Ver INTERFAZ §8.5.
const HABITUALES: Array[Vector2i] = [Vector2i(3840, 2160), Vector2i(2560, 1440),
	Vector2i(1920, 1200), Vector2i(1920, 1080), Vector2i(1680, 1050),
	Vector2i(1600, 900), Vector2i(1366, 768), Vector2i(1280, 720)]

## Los ajustes que NO se aplican en caliente: entran al montar el próximo mapa, y
## la ventana lo dice. La vegetación, porque rehacer la siembra congela la
## pantalla unos 10 s (GRAFICOS §7); los árboles, porque cambiar de escalón es montar
## otro bosque —cargar los modelos 3D y los impostores— (GRAFICOS §7.1).
const AL_MONTAR_EL_MAPA: Array[String] = ["vegetacion", "arboles"]

## Los ajustes de gráficos sueltos, en el orden en que salen en la ventana.
const AJUSTES: Array[String] = ["sombras", "oclusion", "niebla", "nubes", "escala",
	"vegetacion", "arboles", "radio_3d", "agua", "clima", "normales", "orm"]

## La distancia del 3D más larga que se ofrece. **Había «sin límite»** (100 km, todo el
## mapa en 3D), decisión del usuario del 2026-09-15, y **rompía el motor**: el 3D va por
## bloques de 32 m con un grupo de árboles por especie, variante y nivel de detalle, y
## los 16 384 bloques del mapa son cientos de miles de grupos. Godot dejó de crearlos
## («Element limit reached», `GpuProfile ARBOLES=1 RADIO=100000`, más de 7 000 errores y
## 5,2 GB de RAM). A 1000 m monta —57 s— y cuesta 34-67 ms de GPU de bosque. Que quepa
## el mapa entero es otro trabajo, por /spec: agrupar lejos en bloques mayores
## (ROADMAP).
const RADIO_3D_MAXIMO := 1000.0

## LO QUE FIJA CADA NIVEL. Decisiones del usuario del 2026-09-14 (INTERFAZ §8.5):
## **Medio es el de «1070 a 60 fps»** —lo que el juego llevaba hasta ahora—, Alto
## va por encima, **Ultra no tiene límite** —cada ajuste a su máximo— y Bajo por
## debajo de Medio, con los valores de la columna Bajo de GRAFICOS §7.
##
## **Las nubes y la vegetación, con la medida delante** (`GpuProfile NIVELES=1`, dos
## corridas, 1080p, GRAFICOS §7): de 0 a 32 pasos de nube cuestan 0,5-0,75 ms, así
## que las nubes no son donde se ahorra y cada nivel sube un escalón (planas en
## Bajo, 12 las de siempre, 20, y el tope del shader); la vegetación al 25 % ahorra
## 2,3-2,5 ms sobre la entera, y va en Bajo.
##
## **Los árboles** (GRAFICOS §7.1, INTERFAZ §8.7): `arboles` es el escalón —0 Mínimo, el
## bosque de siempre, de láminas; 1 Medio, 2 Alto y 3 Ultra— y `radio_3d` hasta dónde
## llega el 3D, en metros. Cada nivel pone el escalón de su mismo nombre, y Bajo el
## Mínimo, que es «los gráficos mínimos». El jugador mueve la distancia en un slider,
## de 10 m a 1000 ([RADIO_3D_MAXIMO]).
##
## **El agua** (GRAFICOS §7.3, INTERFAZ §8.8): `agua` es el escalón del agua del valle
## —0 Bajo, el río de siempre; 1 Medio, la orilla; 2 Alto, la lámina propia; 3 Ultra,
## salpicaduras y reflejos—, y cada nivel pone el de su mismo nombre. Decisión del
## usuario del 2026-09-15.
##
## **El clima** (GRAFICOS §7.4, INTERFAZ §8.8): `clima` enciende lo que el tiempo dibuja
## —lluvia y nieve, suelo mojado y nieve cuajada, niebla de valle, la luz del temporal—.
## Encendido en Medio, Alto y Ultra y apagado en Bajo, decisión del usuario del
## 2026-09-15. Apagado, el tiempo sigue haciendo en la partida lo que hace.
##
## **Las distancias, medidas con `GpuProfile ARBOLES=1`** (2026-09-15, dos corridas): el
## 3D sólo cuesta en los encuadres de juego —desde la vista de medida no hay un árbol a
## menos de 40 m del ojo—, y en el bajo Medio paga 3,8-4,0 ms de bosque contra 3,2-3,3
## de Mínimo. **Eran 90 / 160 / 260 y hubo que bajarlas**: el valle tiene un millón de
## árboles, y con 160 m Alto pintaba 541 millones de triángulos a 6 FPS. Bajo lleva la
## de Medio aunque no la use: así ningún ajuste baja al subir de nivel.
const NIVELES := {
	Nivel.BAJO: {"sombras": Sombras.BAJAS, "oclusion": Oclusion.NADA, "niebla": false,
		"nubes": 0, "escala": 0.6, "vegetacion": 0.25, "arboles": 0, "radio_3d": 40.0, "agua": 0, "clima": false, "normales": false, "orm": false},
	Nivel.MEDIO: {"sombras": Sombras.MEDIAS, "oclusion": Oclusion.SSAO, "niebla": true,
		"nubes": 12, "escala": 1.0, "vegetacion": 1.0, "arboles": 1, "radio_3d": 40.0, "agua": 1, "clima": true, "normales": true, "orm": true},
	Nivel.ALTO: {"sombras": Sombras.ALTAS, "oclusion": Oclusion.SSAO, "niebla": true,
		"nubes": 20, "escala": 1.0, "vegetacion": 1.0, "arboles": 2, "radio_3d": 70.0, "agua": 2, "clima": true, "normales": true, "orm": true},
	Nivel.ULTRA: {"sombras": Sombras.ULTRA, "oclusion": Oclusion.SSAO_Y_SSIL, "niebla": true,
		"nubes": 32, "escala": 1.0, "vegetacion": 1.0, "arboles": 3, "radio_3d": 120.0, "agua": 3, "clima": true, "normales": true, "orm": true},
}

## Cuántos pasos de relieve (parallax con oclusión) admite lo que hay puesto.
##
## **Sale del nivel y no de un ajuste propio**: decisión del usuario del
## 2026-09-16 —«parallax de verdad en Alto y Ultra»—, no un interruptor más en una
## ventana que ya tiene doce. En Personalizado se toma el agua como medida del
## equipo: quien pone la lámina del río de Alto tiene GPU para esto, y quien la
## quita, no. La altura sale del color, así que no depende del ORM.
static func pasos_de_relieve() -> int:
	match nivel:
		Nivel.ULTRA:
			return 24
		Nivel.ALTO:
			return 12
		Nivel.PERSONALIZADO:
			return 12 if int(graficos.get("agua", 0)) >= 2 else 0
		_:
			return 0


## Lo que es cada escalón de sombras: cortes de la direccional, lado del atlas y
## calidad del suavizado. MEDIAS es lo que había —cuatro cortes, el atlas por
## defecto de Godot y la calidad 3 de `project.godot`—.
const _SOMBRAS := {
	Sombras.APAGADAS: {"activas": false, "cortes": 2, "atlas": 2048, "suave": 0},
	Sombras.BAJAS: {"activas": true, "cortes": 2, "atlas": 2048, "suave": 2},
	Sombras.MEDIAS: {"activas": true, "cortes": 4, "atlas": 4096, "suave": 3},
	Sombras.ALTAS: {"activas": true, "cortes": 4, "atlas": 4096, "suave": 4},
	Sombras.ULTRA: {"activas": true, "cortes": 4, "atlas": 8192, "suave": 5},
}

# --- el estado -----------------------------------------------------------------

static var modo: Modo = Modo.MAXIMIZADA
static var resolucion: Vector2i = Vector2i(1920, 1080)
static var vsync: bool = true
static var tope: int = 0
static var nivel: Nivel = Nivel.MEDIO
static var graficos: Dictionary = (NIVELES[Nivel.MEDIO] as Dictionary).duplicate()
static var volumen_general: float = 1.0
static var volumen_musica: float = 1.0
static var volumen_efectos: float = 1.0


## Lo de siempre: lo que hacía el juego antes de haber configuración —ventana
## maximizada de `project.godot`, sincronización de Godot, sin tope, Medio—.
static func por_defecto() -> void:
	modo = Modo.MAXIMIZADA
	resolucion = Vector2i(1920, 1080)
	vsync = true
	tope = 0
	poner_nivel(Nivel.MEDIO)
	volumen_general = 1.0
	volumen_musica = 1.0
	volumen_efectos = 1.0


## Pone un nivel: todos los ajustes a su valor. Personalizado no se pone: se llega.
static func poner_nivel(cual: Nivel) -> void:
	if not NIVELES.has(cual):
		return
	nivel = cual
	graficos = (NIVELES[cual] as Dictionary).duplicate()


## Toca un ajuste suelto. El nivel pasa a ser el que coincida con todos los
## ajustes, y si no coincide ninguno, Personalizado.
static func poner_ajuste(nombre: String, valor: Variant) -> void:
	if not AJUSTES.has(nombre):
		return
	graficos[nombre] = valor
	nivel = _nivel_que_encaja()


static func _nivel_que_encaja() -> Nivel:
	for cual: int in NIVELES:
		var tabla: Dictionary = NIVELES[cual]
		var igual := true
		for nombre: String in AJUSTES:
			if not is_equal_approx(float(tabla[nombre]), float(graficos.get(nombre, -1.0))):
				igual = false
		if igual:
			return cual as Nivel
	return Nivel.PERSONALIZADO


static func nombre_del_nivel(cual: Nivel) -> String:
	return ["Bajo", "Medio", "Alto", "Ultra", "Personalizado"][cual]


# --- guardar -------------------------------------------------------------------

## Se guarda en disco. Lo llama la ventana al cambiar cualquier cosa.
static func guardar() -> Error:
	var fichero := ConfigFile.new()
	fichero.set_value("pantalla", "modo", int(modo))
	fichero.set_value("pantalla", "resolucion", resolucion)
	fichero.set_value("pantalla", "vsync", vsync)
	fichero.set_value("pantalla", "tope", tope)
	fichero.set_value("graficos", "nivel", int(nivel))
	for nombre: String in AJUSTES:
		fichero.set_value("graficos", nombre, graficos[nombre])
	fichero.set_value("sonido", "general", volumen_general)
	fichero.set_value("sonido", "musica", volumen_musica)
	fichero.set_value("sonido", "efectos", volumen_efectos)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta.get_base_dir()))
	return fichero.save(ruta)


## Lee lo guardado. Sin fichero, o con un fichero que no se lee, se queda lo de
## siempre y devuelve false.
static func cargar() -> bool:
	por_defecto()
	var fichero := ConfigFile.new()
	if fichero.load(ruta) != OK:
		return false
	modo = int(fichero.get_value("pantalla", "modo", int(modo))) as Modo
	resolucion = fichero.get_value("pantalla", "resolucion", resolucion) as Vector2i
	vsync = bool(fichero.get_value("pantalla", "vsync", vsync))
	tope = int(fichero.get_value("pantalla", "tope", tope))
	# Un ajuste que el fichero no trae —guardado antes de que existiera— toma el valor
	# del nivel que tenía guardado, no el de Medio: si no, quien jugaba en Bajo abriría
	# en Personalizado con árboles de Medio.
	var guardado := int(fichero.get_value("graficos", "nivel", int(Nivel.MEDIO)))
	var del_nivel: Dictionary = NIVELES.get(guardado, NIVELES[Nivel.MEDIO])
	for nombre: String in AJUSTES:
		graficos[nombre] = fichero.get_value("graficos", nombre, del_nivel[nombre])
	# La distancia «sin límite» de antes rompe el motor: se lee como el máximo.
	graficos["radio_3d"] = minf(float(graficos["radio_3d"]), RADIO_3D_MAXIMO)
	# El nivel se deduce de los ajustes y no se cree lo escrito: si alguien edita
	# el fichero a mano, lo que manda es lo que se aplica.
	nivel = _nivel_que_encaja()
	volumen_general = clampf(float(fichero.get_value("sonido", "general", 1.0)), 0.0, 1.0)
	volumen_musica = clampf(float(fichero.get_value("sonido", "musica", 1.0)), 0.0, 1.0)
	volumen_efectos = clampf(float(fichero.get_value("sonido", "efectos", 1.0)), 0.0, 1.0)
	return true


# --- aplicar ---------------------------------------------------------------------

## Las resoluciones que se ofrecen: la nativa del monitor donde está la ventana y
## las habituales que quepan en él, de mayor a menor. Sin monitor —una sonda sin
## ventana—, las habituales.
static func resoluciones() -> Array[Vector2i]:
	var nativa := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var salida: Array[Vector2i] = []
	if nativa.x > 0 and nativa.y > 0:
		salida.append(nativa)
	for habitual: Vector2i in HABITUALES:
		if salida.has(habitual):
			continue
		if nativa.x <= 0 or (habitual.x <= nativa.x and habitual.y <= nativa.y):
			salida.append(habitual)
	salida.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y > b.x * b.y)
	return salida


## El modo de ventana, su tamaño, la sincronización y el tope de fotogramas.
##
## **La resolución sólo vale en ventana** —decisión del usuario del 2026-09-14—: a
## pantalla completa y maximizada Godot usa el tamaño del monitor.
static func aplicar_pantalla() -> void:
	match modo:
		Modo.PANTALLA_COMPLETA:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Modo.MAXIMIZADA:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		Modo.VENTANA:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolucion)
			# Centrada en su monitor, que si no una ventana más grande que la de
			# antes se sale por la esquina.
			var pantalla := DisplayServer.screen_get_usable_rect(
				DisplayServer.window_get_current_screen())
			if pantalla.size.x > 0:
				DisplayServer.window_set_position(pantalla.position
					+ (pantalla.size - resolucion) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync
		else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = tope


## Los buses de sonido que hacen falta, por nombre. Hoy no suena nada; cuando
## suene, la música va a su bus y los efectos al suyo, y los dos pasan por el
## general.
const BUS_GENERAL := "Master"
const BUS_MUSICA := "Musica"
const BUS_EFECTOS := "Efectos"


## Los volúmenes a sus buses, creando los que falten.
static func aplicar_sonido() -> void:
	for pareja: Array in [[BUS_GENERAL, volumen_general], [BUS_MUSICA, volumen_musica],
			[BUS_EFECTOS, volumen_efectos]]:
		var indice := AudioServer.get_bus_index(String(pareja[0]))
		if indice < 0:
			AudioServer.add_bus()
			indice = AudioServer.bus_count - 1
			AudioServer.set_bus_name(indice, String(pareja[0]))
			AudioServer.set_bus_send(indice, BUS_GENERAL)
		var volumen := float(pareja[1])
		AudioServer.set_bus_mute(indice, volumen <= 0.0)
		AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(volumen, 0.0001)))


## El grupo de los nodos que aplican ajustes de gráficos: el entorno, el relieve y
## el bosque. Cada uno sabe qué es suyo; aquí no se busca a nadie por nombre.
const GRUPO := "configuracion_grafica"


## Los gráficos, **en caliente**: lo que es del servidor de render —el atlas y el
## suavizado de las sombras—, la escala de render de la ventana, y lo de cada
## nodo del grupo. Sin árbol, sólo lo del servidor.
static func aplicar_graficos(arbol: SceneTree = null) -> void:
	var sombras: Dictionary = _SOMBRAS[int(graficos["sombras"])]
	# El atlas de las sombras direccionales es del servidor, no de la luz: uno para
	# todas. Rehacerlo en caliente es lo que hace Godot al cambiarlo en el editor.
	RenderingServer.directional_shadow_atlas_set_size(int(sombras["atlas"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		int(sombras["suave"]) as RenderingServer.ShadowQuality)
	if arbol == null:
		return
	var escala := float(graficos["escala"])
	var raiz := arbol.root
	# Por debajo de 1, con FSR2, que es lo que la tabla de GRAFICOS §7 pide y lo
	# que midió `GpuProfile`; a 1, sin escalar.
	raiz.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if escala < 0.999 \
		else Viewport.SCALING_3D_MODE_BILINEAR
	raiz.scaling_3d_scale = escala
	arbol.call_group(GRUPO, "aplicar_configuracion")


## Lo que es cada escalón de sombras, para quien lo aplica.
static func sombras() -> Dictionary:
	return _SOMBRAS[int(graficos["sombras"])]

