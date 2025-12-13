extends Node
## TimeManager - Singleton global para gestión del tiempo del juego.
## Maneja ticks, días, estaciones y años.

## Emitido cada tick del juego
signal tick_advance(tick: int, day: int, season: int, year: int)

## Emitido cuando cambia el día
signal day_changed(new_day: int)

## Emitido cuando cambia la estación
signal cambio_de_estacion(new_season: int)
signal season_changed(new_season: int, season_name: String)

## Emitido cuando cambia el año
signal year_changed(new_year: int)

## Emitido cuando el tiempo se pausa/reanuda
signal time_paused(is_paused: bool)

## Nombres de las estaciones
const SEASON_NAMES := ["Primavera", "Verano", "Otoño", "Invierno"]
const SEASON_NAMES_EN := ["Spring", "Summer", "Autumn", "Winter"]

## Ticks por segundo (a velocidad normal)
@export var ticks_per_second: float = 10.0

## Ticks por día
@export var ticks_per_day: int = 240  # 24 segundos = 1 día a velocidad normal

## Días por estación
@export var days_per_season: int = 30

## Estaciones por año
@export var seasons_per_year: int = 4

## Velocidad del tiempo (multiplicador)
@export_range(0.0, 10.0) var time_speed: float = 1.0

## Tiempo actual
var current_tick: int = 0
var current_day: int = 1
var current_season: int = 0  # 0=Primavera, 1=Verano, 2=Otoño, 3=Invierno
var current_year: int = 1

## Estado
var is_paused: bool = false

## Acumulador de tiempo
var _time_accumulator: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("TimeManager inicializado")


func _process(delta: float) -> void:
	if is_paused or time_speed <= 0:
		return
	
	_time_accumulator += delta * time_speed * ticks_per_second
	
	while _time_accumulator >= 1.0:
		_time_accumulator -= 1.0
		_advance_tick()


func _advance_tick() -> void:
	current_tick += 1
	
	# Emitir señal de tick
	tick_advance.emit(current_tick, current_day, current_season, current_year)
	
	# Comprobar cambio de día
	if current_tick >= ticks_per_day:
		current_tick = 0
		_advance_day()


func _advance_day() -> void:
	current_day += 1
	day_changed.emit(current_day)
	
	# Comprobar cambio de estación
	if current_day > days_per_season:
		current_day = 1
		_advance_season()


func _advance_season() -> void:
	current_season += 1
	
	# Comprobar cambio de año
	if current_season >= seasons_per_year:
		current_season = 0
		_advance_year()
	
	cambio_de_estacion.emit(current_season)
	season_changed.emit(current_season, get_season_name())


func _advance_year() -> void:
	current_year += 1
	year_changed.emit(current_year)


## Pausa el tiempo
func pause() -> void:
	is_paused = true
	time_paused.emit(true)


## Reanuda el tiempo
func resume() -> void:
	is_paused = false
	time_paused.emit(false)


## Alterna pausa
func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()


## Establece la velocidad del tiempo
func set_speed(speed: float) -> void:
	time_speed = clampf(speed, 0.0, 10.0)


## Obtiene el nombre de la estación actual
func get_season_name(in_english: bool = false) -> String:
	if in_english:
		return SEASON_NAMES_EN[current_season]
	return SEASON_NAMES[current_season]


## Obtiene la hora del día (0-24) basada en ticks
func get_hour_of_day() -> float:
	return (float(current_tick) / float(ticks_per_day)) * 24.0


## Obtiene si es de día (6:00 - 20:00)
func is_daytime() -> bool:
	var hour := get_hour_of_day()
	return hour >= 6.0 and hour < 20.0


## Obtiene si es de noche
func is_nighttime() -> bool:
	return not is_daytime()


## Obtiene el factor de luz solar (0-1) basado en hora
func get_sunlight_factor() -> float:
	var hour := get_hour_of_day()
	
	if hour < 5.0:
		return 0.1  # Noche
	elif hour < 7.0:
		return lerpf(0.1, 1.0, (hour - 5.0) / 2.0)  # Amanecer
	elif hour < 18.0:
		return 1.0  # Día
	elif hour < 20.0:
		return lerpf(1.0, 0.1, (hour - 18.0) / 2.0)  # Atardecer
	else:
		return 0.1  # Noche


## Obtiene el modificador de temperatura por estación (-1 a 1)
func get_season_temperature_modifier() -> float:
	match current_season:
		0:  # Primavera
			return 0.0
		1:  # Verano
			return 1.0
		2:  # Otoño
			return 0.0
		3:  # Invierno
			return -1.0
	return 0.0


## Obtiene un diccionario con el estado actual del tiempo
func get_time_state() -> Dictionary:
	return {
		"tick": current_tick,
		"day": current_day,
		"season": current_season,
		"season_name": get_season_name(),
		"year": current_year,
		"hour": get_hour_of_day(),
		"is_day": is_daytime(),
		"speed": time_speed,
		"paused": is_paused
	}


## Establece el estado del tiempo desde un diccionario (para carga de partida)
func set_time_state(state: Dictionary) -> void:
	if state.has("tick"):
		current_tick = state["tick"]
	if state.has("day"):
		current_day = state["day"]
	if state.has("season"):
		current_season = state["season"]
	if state.has("year"):
		current_year = state["year"]
	if state.has("speed"):
		time_speed = state["speed"]
	if state.has("paused"):
		is_paused = state["paused"]


## Avanza el tiempo manualmente (útil para testing)
func skip_to_next_day() -> void:
	current_tick = 0
	_advance_day()


func skip_to_next_season() -> void:
	current_tick = 0
	current_day = 1
	_advance_season()


func skip_to_next_year() -> void:
	current_tick = 0
	current_day = 1
	current_season = 0
	_advance_year()


## Formatea el tiempo actual como string
func format_time() -> String:
	var hour := int(get_hour_of_day())
	var minute := int((get_hour_of_day() - hour) * 60)
	return "%02d:%02d" % [hour, minute]


func format_date() -> String:
	return "Día %d de %s, Año %d" % [current_day, get_season_name(), current_year]


func format_full() -> String:
	return "%s - %s" % [format_date(), format_time()]
