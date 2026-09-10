extends Node3D
## WorldEnvironmentSetup - Configura el entorno gráfico del mundo.
## Activa SDFGI, Volumetric Fog, ACES Tone Mapping y otros efectos.

@export_group("Environment Settings")
## Activar SDFGI (iluminación global en tiempo real).
## Medido en un mundo de 2 km: SDFGI + SSIL cuestan ~13 FPS de 43. En una
## vista cenital aportan muy poco para ese precio, asi que van apagados.
@export var enable_sdfgi: bool = false

## Activar SSIL (iluminación indirecta en espacio de pantalla)
@export var enable_ssil: bool = false

## Activar niebla volumétrica
@export var enable_volumetric_fog: bool = true

## Activar SSR (reflejos)
@export var enable_ssr: bool = false

## Activar SSAO (oclusión ambiental)
@export var enable_ssao: bool = true

@export_group("Sky Settings")
## Color superior del cielo
@export var sky_top_color: Color = Color(0.3, 0.5, 0.85)

## Color del horizonte
@export var sky_horizon_color: Color = Color(0.65, 0.75, 0.9)

## Color inferior del cielo (reflejo del suelo)
@export var sky_bottom_color: Color = Color(0.25, 0.2, 0.15)

## --- El sol de mediodía ------------------------------------------------
##
## Los tres números con los que se ajusta la luz, y están aquí porque antes NO
## se podían ajustar: la altura del sol salía de una fórmula
## -`-30 - sin(hora/24·π)·60`- que a las doce da exactamente noventa grados, o
## sea el sol EN VERTICAL. Eso tiene dos consecuencias malas y una imposible.
## Ilumina al máximo el suelo llano mientras oscurece cualquier ladera con el
## coseno de su pendiente, no deja sombras largas que den relieve, y además no
## puede pasar: en Cantabria, a 43° de latitud, el sol de mediodía no sube de
## unos setenta grados ni en pleno solsticio de verano, y en los equinoccios se
## queda en cuarenta y siete.

## Energía del sol
@export var sun_energy: float = 1.2

## Fuerza de la luna llena, en fracción de la del sol.
##
## Una luna llena de verdad da unas cuatrocientas mil veces menos luz que el
## sol. Aquí se exagera —como en el cine— porque la pantalla no tiene el rango
## que tiene el ojo.
##
## De 0,07 a 0,25, medido con `scripts/tests/NocheLuzProbe.gd`. Con 0,07 la
## luna estaba ahí, alta y encendida, y la imagen no cambiaba NADA: 0,0101 de
## brillo con luna llena contra 0,0100 sin ella. Con 0,25 una noche de luna
## llena da 0,031, que es el nivel del crepúsculo civil —se ve el valle y se
## sigue leyendo como noche—, y la luna nueva se queda en 0,014, que es la
## diferencia entre una noche y otra que antes no existía.
@export var moon_energy: float = 0.25

## Color de la luna. Azulado y desaturado a propósito: de noche el ojo pasa a
## los bastones, que no distinguen color y son más sensibles al azul. Por eso
## una noche de luna se RECUERDA azul aunque la luz de la luna sea casi blanca.
@export var moon_color: Color = Color(0.62, 0.72, 1.0)

## Latitud de reserva, en grados, por si aún no hay emplazamiento cargado.
##
## Lo normal es que NO se use: la latitud sale de `Expedition.site`, que es el
## sitio de verdad. Cueva los Pendios está a 43,28° N.
@export var fallback_latitude: float = 43.28

## Color del sol. Blanco tirando a cálido; cuanto más bajo el sol, más ámbar.
@export var sun_color: Color = Color(1.0, 0.96, 0.88)

## Energía de la luz de relleno, en fracción de la del sol.
##
## Es lo que impide que las laderas de espaldas al sol salgan NEGRAS, y hace
## falta porque el motor no tiene rebote de luz: sin ella, una ladera en sombra
## sólo recibe el cielo, y con el cielo de un amanecer nublado eso es casi nada.
##
## No es la primera opción que se probó, es la que quedó en pie. Medido en
## `ReboteProbe`: SDFGI cuesta entre 2,6 y 6,6 ms según el tamaño de celda y
## MEDIO GIGA de VRAM, y comparando las capturas la hondonada de la cueva sigue
## igual de negra. También queda falsada de paso la sospecha de que SDFGI
## estuviera mal configurado para exterior: con celda de 4 m cubre el valle
## entero y sigue sin arreglarlo. Y la razón de fondo es sencilla: estas sombras
## no son de oclusión local sino media ladera de espaldas al sol, y el rebote
## real de la ladera de enfrente es genuinamente flojo.
##
## APAGADA de momento, y con motivo medido: en `SombraProbe` no mueve el suelo
## de luz ni al TRESCIENTOS por ciento de la energía del sol -0,1504 contra
## 0,1510-, así que está desconectada del render por algo que no he encontrado
## todavía. Se queda a cero para que no ensucie el ajuste del sol.
@export var fill_energy: float = 0.0

## Color de la luz de relleno. Azulado, y no por gusto: al aire libre una sombra
## es azul porque quien la ilumina es la bóveda celeste, no el sol.
@export var fill_color: Color = Color(0.55, 0.66, 0.92)

## --- El suelo de luz de las sombras -------------------------------------
##
## Lo que impide de verdad que una ladera a contraluz salga negra, ahora que se
## sabe que la luz de relleno no llega al render y por qué el ambiente del cielo
## tampoco alcanzaba.
##
## Medido con `SombraDiaProbe`, que fotografía el mismo terreno con el sol y sin
## él y da la razón entre los dos —o sea, cuánto queda de una ladera cuando algo
## se interpone entre ella y el sol—. Tal como estaba: **5,8 %**, por debajo del
## 8 % que ya se lee como negro. La medida de REVAMP_GRAFICO §6 que daba 18,5 %
## comparaba dos rectángulos dibujados a mano sobre una captura de mediodía, y
## el que hacía de sombra no lo estaba: era terreno al sol de albedo oscuro.
##
## El ambiente del cielo no servía de palanca porque con
## `ambient_light_source = SKY` la contribución del cielo es 1 y entonces
## `ambient_light_energy` NO MULTIPLICA NADA —de ahí que quedara descartado en
## `ReboteProbe` como «probado y no hace nada»—. Hay que bajar la contribución
## para que el término de color entre en la mezcla; con eso sí se gobierna.

## Energía del ambiente de color, el que hace de bóveda celeste.
##
## 0,9 deja la razón sombra/sol en 17,4 % a mediodía de primavera y 18,1 % a
## mediodía de invierno: el centro del 15-20 % de una foto de campo. Con el sol
## bajo sube a 24-27 %, y eso NO es un fallo del ajuste: con el sol rasante el haz
## directo atraviesa mucha más atmósfera y pierde fuerza mientras el cielo sigue
## alumbrando igual, así que la sombra de un amanecer es de verdad menos profunda
## que la de mediodía. Pendiente de playtest: es el número con el que se decide si
## el valle en sombra se lee o no.
@export var ambient_energy: float = 0.9

## Qué parte del ambiente se sigue pidiendo a la radiancia del cielo.
##
## No se pone a cero: el cielo aporta el tinte que cambia con la hora, y lo que
## falta es potencia, no color. Con 1,0 -lo que había- el término de color queda
## fuera de la mezcla y no hay nada que ajustar.
@export var ambient_sky_share: float = 0.5

## Cuánto ambiente queda en la noche cerrada, en fracción de `ambient_energy`.
##
## No es cero porque una noche despejada sin luna tampoco lo es, y sobre todo
## porque a cero el crepúsculo se corta de golpe.
##
## De 0,14 a 0,55, y esta vez MEDIDO con `scripts/tests/NocheLuzProbe.gd`, que
## fotografía la boca de la cueva y saca el brillo medio de la imagen. Las
## anclas del sitio 56: mediodía 0,190 y crepúsculo civil 0,026. Con 0,14 una
## noche sin hoguera daba 0,0004 en la boca —cero pantalla, no una metáfora— y
## con 0,55 da 0,012: oscuro, pero se distingue el terreno.
##
## Sigue siendo una concesión de juego y no física: una noche cerrada de verdad
## es más negra que esto. Pendiente de playtest.
@export var ambient_night_floor: float = 0.55

## Seguir la hora de la partida. Con false el sol se queda fijo a la hora
## de `fixed_hour` y no hay ciclo dia/noche.
##
## De momento va desactivado: el ciclo esta implementado y funciona, pero para
## trabajar en el terreno y los emplazamientos estorba tener medio mapa a
## oscuras. El codigo se conserva entero, solo se puentea la conexion.
@export var follow_time_of_day: bool = false

## Hora fija cuando follow_time_of_day es false
@export_range(0.0, 24.0, 0.5) var fixed_hour: float = 12.0

@export_group("Fog Settings")
## Densidad de la niebla
@export var fog_density: float = 0.002

## Color de la niebla
@export var fog_color: Color = Color(0.75, 0.82, 0.92, 1.0)

## Altura de la niebla
@export var fog_height: float = 5.0

## Densidad de la niebla según altura
@export var fog_height_density: float = 0.05

## Nodos del entorno
var _world_environment: WorldEnvironment
var _directional_light: DirectionalLight3D
var _fill_light: DirectionalLight3D

## Última hora de la que se dio parte, para no repetir la línea a cada tick.
var _last_reported_hour := -1

## El reloj de la partida. Ver `_connect_time_manager`.
var _sim: Node = null
var _moon_light: DirectionalLight3D
var _environment: Environment
var _sky: Sky
var _sky_material: ProceduralSkyMaterial


func _ready() -> void:
	_setup_environment()
	_setup_sky()
	_setup_lighting()
	_connect_time_manager()


func _setup_environment() -> void:
	# Crear WorldEnvironment si no existe
	_world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not _world_environment:
		_world_environment = WorldEnvironment.new()
		_world_environment.name = "WorldEnvironment"
		add_child(_world_environment)
	
	# Crear Environment
	_environment = Environment.new()
	
	# Background - Sky
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_update_ambient(90.0)
	
	# Tone Mapping - ACES para colores más cinematográficos
	_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	_environment.tonemap_exposure = 1.0
	_environment.tonemap_white = 6.0
	
	# SDFGI - Iluminación global en tiempo real
	_environment.sdfgi_enabled = enable_sdfgi
	_environment.sdfgi_use_occlusion = true
	_environment.sdfgi_bounce_feedback = 0.5
	_environment.sdfgi_cascades = 4
	_environment.sdfgi_min_cell_size = 0.2
	_environment.sdfgi_energy = 1.0
	
	# SSAO
	_environment.ssao_enabled = enable_ssao
	_environment.ssao_radius = 1.0
	_environment.ssao_intensity = 2.0
	
	# SSR
	_environment.ssr_enabled = enable_ssr
	
	# SSIL (iluminación indirecta)
	_environment.ssil_enabled = enable_ssil
	_environment.ssil_radius = 5.0
	_environment.ssil_intensity = 1.0
	
	# Volumetric Fog
	_environment.volumetric_fog_enabled = enable_volumetric_fog
	_environment.volumetric_fog_density = fog_density
	_environment.volumetric_fog_albedo = fog_color
	_environment.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	_environment.volumetric_fog_emission_energy = 0.0
	_environment.volumetric_fog_length = 64.0
	_environment.volumetric_fog_detail_spread = 2.0
	_environment.volumetric_fog_ambient_inject = 0.0
	
	# Glow
	_environment.glow_enabled = true
	# Un bloom de 0.1 hace que TODO el encuadre sangre luz, no solo lo que pasa
	# el umbral, y en combinacion con el especular del terreno remataba el
	# aspecto barnizado. El glow se queda solo para el cielo y el agua.
	_environment.glow_intensity = 0.25
	_environment.glow_bloom = 0.0
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Adjustments
	_environment.adjustment_enabled = true
	_environment.adjustment_brightness = 1.0
	_environment.adjustment_contrast = 1.05
	_environment.adjustment_saturation = 1.1
	
	_world_environment.environment = _environment


func _setup_sky() -> void:
	# Crear cielo procedural
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = sky_top_color
	_sky_material.sky_horizon_color = sky_horizon_color
	_sky_material.ground_bottom_color = sky_bottom_color
	_sky_material.ground_horizon_color = sky_horizon_color
	_sky_material.sun_angle_max = 30.0
	_sky_material.sun_curve = 0.15
	
	_sky = Sky.new()
	_sky.sky_material = _sky_material
	_sky.radiance_size = Sky.RADIANCE_SIZE_256
	
	_environment.sky = _sky


func _setup_lighting() -> void:
	# Crear luz direccional (sol) si no existe
	_directional_light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if not _directional_light:
		_directional_light = DirectionalLight3D.new()
		_directional_light.name = "Sun"
		add_child(_directional_light)
	
	# Configurar sol - ángulo para luz más cálida de atardecer/mañana
	_directional_light.rotation_degrees = Vector3(-35, -45, 0)
	_directional_light.light_color = sun_color
	_directional_light.light_energy = sun_energy
	_directional_light.light_indirect_energy = 1.2
	_directional_light.light_volumetric_fog_energy = 1.5
	_directional_light.light_angular_distance = 0.5  # Sol más suave
	
	# Sombras de alta calidad
	_directional_light.shadow_enabled = true
	_directional_light.shadow_blur = 1.5
	_directional_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	# Al menos hasta donde llega la malla de verdad del bosque (Forest.near_distance,
	# 300 m): por debajo de eso hay árboles con malla real pero sin sombra, y el
	# borde de ese anillo se ve en pantalla como un arco que los apaga.
	_directional_light.directional_shadow_max_distance = 320.0
	_directional_light.directional_shadow_split_1 = 0.05
	_directional_light.directional_shadow_split_2 = 0.15
	_directional_light.directional_shadow_split_3 = 0.35

	# --- La luz de relleno -------------------------------------------------
	#
	# Una segunda direccional SIN SOMBRAS que viene del lado contrario al sol y
	# algo desde arriba. Lo que hace es dar un suelo de luz a lo que el sol no
	# toca, que es lo que en la realidad hace el cielo y aquí no llegaba.
	#
	# Sin sombras a propósito, y hay que saber lo que eso significa: NO respeta
	# la oclusión, así que ilumina por igual una ladera y el fondo de la cueva.
	# Es el precio de que cueste casi nada. Si algún día molesta dentro de las
	# cuevas, la salida no es subirle sombras -eso la haría tan cara como el
	# sol- sino oscurecer esos interiores con su propia oclusión.
	#
	# Y sin brillo especular: es luz difusa de relleno, y un reflejo suyo en el
	# agua o en la roca delataría que hay un segundo sol.
	_fill_light = get_node_or_null("FillLight") as DirectionalLight3D
	if not _fill_light:
		_fill_light = DirectionalLight3D.new()
		_fill_light.name = "FillLight"
		add_child(_fill_light)
	_fill_light.shadow_enabled = false
	_fill_light.light_specular = 0.0
	_fill_light.light_color = fill_color
	_fill_light.light_energy = sun_energy * fill_energy
	# No entra en la niebla volumétrica: son dos rayos de sol donde sólo hay uno.
	_fill_light.light_volumetric_fog_energy = 0.0
	_update_fill()

	# --- La luna -----------------------------------------------------------
	#
	# Con sombras, y a diferencia del relleno: de noche es la ÚNICA luz que las
	# proyecta, y una noche de luna llena sin sombras no se lee como noche de
	# luna, se lee como un día apagado. Y sale barata porque sólo está encendida
	# cuando el sol no lo está: nunca se pagan dos pases de sombra a la vez.
	_moon_light = get_node_or_null("MoonLight") as DirectionalLight3D
	if not _moon_light:
		_moon_light = DirectionalLight3D.new()
		_moon_light.name = "MoonLight"
		add_child(_moon_light)
	_moon_light.light_color = moon_color
	_moon_light.shadow_enabled = true
	_moon_light.shadow_blur = 2.5
	# El mismo alcance que el sol y por la misma razón: por debajo de
	# Forest.near_distance (300 m) queda malla de verdad sin sombra.
	_moon_light.directional_shadow_max_distance = 320.0
	# Un poco de brillo sí: el reflejo de la luna en el agua es la mitad de la
	# gracia de una noche despejada.
	_moon_light.light_specular = 0.6
	_moon_light.light_angular_distance = 0.5
	_moon_light.visible = false


## Coloca el sol donde de verdad estaría, para este sitio y este día.
##
## Nada de esto es ajustable y ésa es la gracia: sabemos dónde está el
## emplazamiento y sabemos qué día es, así que la altura y la dirección del sol
## salen de la mecánica celeste. Ver [SolarPosition], que explica de dónde sale
## cada número y por qué la fórmula anterior -noventa grados a mediodía, igual
## en verano que en invierno- no podía estar bien.
func _place_sun(hour: float, season: int, season_day: int) -> void:
	if not _directional_light:
		return

	var latitude := fallback_latitude
	var site: Site = Expedition.site if Expedition != null else null
	if site != null:
		latitude = site.lat

	var day := SolarPosition.day_of_year(season, season_day,
		Subsistence.DAYS_PER_SEASON, 4)

	var sun := SolarPosition.at(latitude, day, hour)
	var to_sun: Vector3 = sun["to_sun"]
	var elevation: float = sun["elevation"]
	_directional_light.global_transform = Transform3D(
		SolarPosition.light_basis(to_sun),
		_directional_light.global_position)

	# La energía se apaga cuando el sol se pone, y no antes: la inclinación ya
	# oscurece las superficies por su cuenta -es el coseno del ángulo- y volver a
	# aplicarla aquí la contaría dos veces. Lo que sí es real es que un sol muy
	# bajo atraviesa mucha más atmósfera, así que pierde fuerza y se vuelve
	# ámbar; eso es lo que hace esta franja de los ocho grados.
	var above := rad_to_deg(elevation)
	var daylight := smoothstep(-3.0, 8.0, above)
	_directional_light.light_energy = sun_energy * daylight
	_directional_light.light_color = sun_color.lerp(Color(1.0, 0.72, 0.45),
		1.0 - smoothstep(3.0, 25.0, above))
	_directional_light.visible = daylight > 0.001
	_update_ambient(above)

	# El cielo va con la ALTURA DEL SOL, no con el reloj.
	#
	# Con horas fijas -amanece a las 6, anochece a las 19- el invierno cantábrico
	# salía con cielo de mediodía sobre un valle ya a oscuras: el sol se pone a
	# las 16:50 y el cielo no se enteraba hasta las 17. Es el mismo error que
	# [SolarPosition] vino a arreglar en la luz, sin arreglar de paso en el color.
	# Y el horizonte no se tocaba en absoluto, con lo que la franja más ancha del
	# cielo se quedaba en gris de día toda la noche.
	if _sky_material:
		# Dos colores de sol rasante, no uno: el ámbar es sólo del horizonte y el
		# cenit de un amanecer es violeta oscuro. Con un color único el cielo
		# entero salía de un naranja plano que no se parece a ningún amanecer.
		var low_sky := Color(0.24, 0.24, 0.40)
		var low_horizon := Color(0.85, 0.48, 0.28)
		var night := Color(0.05, 0.05, 0.15)
		# El ámbar del amanecer se pega al HORIZONTE y el cenit vuelve a azul
		# mucho antes: teñir los dos por igual daba una plancha naranja de arriba
		# abajo, que es lo que no se parece a un amanecer. Y por debajo del ocaso
		# se pierde el cielo entero, en el tramo del crepúsculo.
		var warm_top := smoothstep(-2.0, 12.0, above)
		var warm_low := smoothstep(0.0, 25.0, above)
		var risen := smoothstep(-8.0, 1.0, above)
		_sky_material.sky_top_color = night.lerp(
			low_sky.lerp(sky_top_color, warm_top), risen)
		_sky_material.sky_horizon_color = night.lerp(
			low_horizon.lerp(sky_horizon_color, warm_low), risen)
		_sky_material.ground_horizon_color = _sky_material.sky_horizon_color

	_place_moon(latitude, day, hour, above)

	# UNA LINEA POR JORNADA, no por hora de juego.
	#
	# Era una por hora, o sea veinticuatro por jornada, y en una partida a
	# velocidad rápida eso son diez líneas por segundo: la consola dejaba de
	# servir para ver cualquier otra cosa. Y encima confundía, porque lo que
	# imprimía era el día del año SOLAR -«dia 88», «dia 90»- que no es el día de
	# la partida y salta de dos en dos.
	#
	# Salta de dos en dos porque el año del juego son ciento ochenta jornadas y
	# el año astronómico trescientos sesenta y cinco: cada jornada vale 2,03
	# días solares. Y empieza en el 80 porque el 80 es el equinoccio de marzo,
	# que es cuando arranca la primavera. Las dos cosas son correctas y las dos
	# parecían un fallo, así que ahora se dice el mediodía y se dice ENTERO:
	# qué jornada de la partida, qué mes, y de paso a qué día solar cae.
	# Sin excepcion para la primera: con ella la linea de arranque salia a la
	# hora que fuera y decia «altura -0,3º», o sea el sol bajo el horizonte a
	# «mediodia».
	if absf(hour - 12.0) > 0.55:
		_update_fill()
		return
	var stamp := int(day)
	if stamp != _last_reported_hour:
		_last_reported_hour = stamp
		print("Sol: mediodia · %s · dia %.0f del año solar · altura %5.1fº" % [
			Subsistence.month_name(season as Subsistence.Season, season_day),
			day, above])
	_update_fill()


## Coloca la luna, con su fase, y decide cuánto alumbra.
##
## La fase sale de los días transcurridos de partida convertidos a días reales,
## porque una lunación es un periodo físico y el calendario del juego es una
## convención. Ver [SolarPosition].
func _place_moon(latitude: float, day: float, hour: float,
		sun_above: float) -> void:
	if not _moon_light:
		return

	var elapsed := _elapsed_real_days()
	var phase := SolarPosition.moon_phase(elapsed)
	var moon := SolarPosition.moon_at(latitude, day, hour, phase)
	var to_moon: Vector3 = moon["to_moon"] if moon.has("to_moon") 		else moon["to_sun"]
	var above := rad_to_deg(moon["elevation"])

	# Tres cosas la apagan, y las tres son ciertas: que esté bajo el horizonte,
	# que esté en fase nueva, y que sea de día. La última es la que evita el
	# error clásico de dejar la luna alumbrando a mediodía: la luna SÍ está ahí
	# de día, pero su luz no cuenta contra el sol.
	var risen := smoothstep(-2.0, 6.0, above)
	var lit := SolarPosition.moon_lit(phase)
	var night := 1.0 - smoothstep(-6.0, 2.0, sun_above)
	var strength := risen * lit * night

	_moon_light.visible = strength > 0.002
	if not _moon_light.visible:
		return
	_moon_light.global_transform = Transform3D(
		SolarPosition.light_basis(to_moon),
		_moon_light.global_position)
	_moon_light.light_energy = sun_energy * moon_energy * strength
	_moon_light.light_color = moon_color


## Días reales transcurridos desde el principio de la partida.
##
## El calendario del juego va a 45 días por estación y 180 al año; el año real
## tiene 365. La proporción entre los dos es la que convierte una cosa en otra, y
## sale a poco más de dos días reales por día de juego.
func _elapsed_real_days() -> float:
	var sim := _find_sim()
	if sim == null:
		return 0.0
	var seasons := (GameState.year - 1) * 4 + int(GameState.season)
	var days := float(seasons * Subsistence.DAYS_PER_SEASON + sim.season_day)
	return days * SolarPosition.YEAR_DAYS 		/ float(Subsistence.DAYS_PER_SEASON * 4)


## Cuánta luz de cielo llega a lo que el sol no toca, para esta altura de sol.
##
## Sigue al sol y no es constante por una razón que se ve al medirla de noche:
## un ambiente fijo deja el valle iluminado a las tres de la madrugada por una
## luz que no viene de ningún sitio. La curva se apaga en el CREPÚSCULO, no en
## el ocaso: el civil acaba con el sol a -6° y el náutico a -12°, y en ese tramo
## el cielo sigue claro aunque el sol ya no se vea. Es justo el momento en que el
## valle se iba a negro debajo de un cielo todavía azul.
func _update_ambient(sun_above_deg: float) -> void:
	if not _environment:
		return
	var twilight := smoothstep(-12.0, 2.0, sun_above_deg)
	_environment.ambient_light_sky_contribution = ambient_sky_share
	_environment.ambient_light_color = fill_color
	_environment.ambient_light_energy = ambient_energy * lerpf(
		ambient_night_floor, 1.0, twilight)


## Pone el relleno enfrente del sol. Se llama cada vez que el sol se mueve.
##
## Enfrente en acimut y con una inclinación fija hacia abajo: así le da de lleno
## justo a las caras que el sol no ve, que son las que se estaban yendo a negro.
## Su energía sigue a la del sol, para que de noche no quede el valle iluminado
## por una luz azul que no viene de ninguna parte.
func _update_fill() -> void:
	if not _fill_light or not _directional_light:
		return
	_fill_light.rotation_degrees = Vector3(-40.0,
		_directional_light.rotation_degrees.y + 180.0, 0.0)
	_fill_light.light_color = fill_color
	_fill_light.light_energy = _directional_light.light_energy * fill_energy


## El sol sigue al reloj QUE MANDA, que es el de la partida.
##
## Aquí hubo un fallo de raíz que explica por qué la luz no cambiaba nunca:
## había DOS relojes. Un autoload `TimeManager` que corría por su cuenta, y
## `SettlementSim`, que es el que el jugador ve en el HUD -`sim.hour`, `sim.day`-
## y el que gobiernan los botones de velocidad. El sol estaba enganchado al
## primero, o sea al que nadie controlaba.
##
## El autoload ya no existe: no era dueño de nada -la simulación le paraba el
## reloj y le empujaba su hora cada fotograma- y sostenía una copia del tiempo
## cuyo único consumidor era una etiqueta de depuración. Queda una sola fuente.
##
## Se consulta por fotograma en vez de por señal porque `SettlementSim` no
## emite una por hora: lleva la hora como un flotante que avanza continuo, y
## leerlo es más barato que inventarle una señal.
func _connect_time_manager() -> void:
	if not follow_time_of_day:
		_apply_fixed_sun()
		return
	# La estación sí llega por señal, y del reloj del juego: es la que cambia la
	# niebla.
	var demo := get_tree().current_scene
	if demo != null and demo.has_signal("ready"):
		call_deferred("_hook_sim")


## Engancha la niebla al cambio de estación del reloj de la partida.
func _hook_sim() -> void:
	var sim := _find_sim()
	if sim != null and sim.has_signal("season_changed"):
		sim.season_changed.connect(func(season: int, _year: int) -> void:
			_on_season_changed(season, ""))


## El reloj de la partida, buscado una vez y recordado.
func _find_sim() -> Node:
	if _sim != null and is_instance_valid(_sim):
		return _sim
	var demo := get_tree().current_scene
	if demo != null and "sim" in demo:
		_sim = demo.sim
	return _sim


func _process(_delta: float) -> void:
	Cronometro.tramo_raiz("vista: entorno")
	if not follow_time_of_day:
		Cronometro.cierra("vista: entorno")
		return
	var sim := _find_sim()
	if sim == null:
		Cronometro.cierra("vista: entorno")
		return
	# `season_day` cuenta desde cero los días cumplidos de la estación; el
	# cálculo del día del año los quiere desde uno.
	_place_sun(sim.hour, GameState.season, sim.season_day + 1)


## Deja el sol clavado a la hora de `fixed_hour`, con el cielo que le toque.
	Cronometro.cierra("vista: entorno")


func _apply_fixed_sun() -> void:
	if not _directional_light:
		return

	_place_sun(fixed_hour, GameState.season, 1)
	_update_fill()


func _on_season_changed(season: int, _season_name: String) -> void:
	# Ajustar niebla según estación
	match season:
		0:  # Primavera
			_environment.volumetric_fog_density = fog_density
			_environment.volumetric_fog_albedo = Color(0.8, 0.9, 1.0)
		1:  # Verano
			_environment.volumetric_fog_density = fog_density * 0.5
			_environment.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
		2:  # Otoño
			_environment.volumetric_fog_density = fog_density * 1.5
			_environment.volumetric_fog_albedo = Color(0.85, 0.8, 0.7)
		3:  # Invierno
			_environment.volumetric_fog_density = fog_density * 2.0
			_environment.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)


## Activa/desactiva SDFGI en tiempo de ejecución
func set_sdfgi_enabled(enabled: bool) -> void:
	enable_sdfgi = enabled
	if _environment:
		_environment.sdfgi_enabled = enabled


## Activa/desactiva niebla volumétrica
func set_volumetric_fog_enabled(enabled: bool) -> void:
	enable_volumetric_fog = enabled
	if _environment:
		_environment.volumetric_fog_enabled = enabled


## Obtiene el Environment actual
func get_environment() -> Environment:
	return _environment


## Obtiene la luz direccional (sol)
func get_sun() -> DirectionalLight3D:
	return _directional_light
