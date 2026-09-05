class_name Chronicle
extends RefCounted
## El diario de la partida: lo que pasa, contado cuando pasa.
##
## Existe porque el juego ya SABE cuándo ocurren las cosas —se rompe la última
## azagaya, se descubre una cavidad, entra el otoño, se termina el secadero— y
## no contaba ninguna. Todo eso se reflejaba en un número que había que ir a
## buscar a una pestaña, y un número no se recuerda.
##
## No lleva simulación debajo: sólo recoge lo que otros ya detectan. Es la
## mejora con mejor relación entre esfuerzo y efecto que había pendiente.

## De qué habla cada anotación. Sirve para filtrar y para el color.
enum Kind {
	TIERRA,     ## Estaciones, clima, el paso del tiempo
	HALLAZGO,   ## Cuevas, cumbres, parajes nuevos
	TALLER,     ## Herramientas rotas y hechas
	PENURIA,    ## Hambre, almacén lleno, parajes esquilmados
	OBRA,       ## Mejoras del abrigo terminadas
	GENTE,      ## Nacimientos, muertes, quien deja de criar
}

const KIND_NAMES := {
	Kind.TIERRA: "La tierra",
	Kind.HALLAZGO: "Hallazgos",
	Kind.TALLER: "El taller",
	Kind.PENURIA: "Penurias",
	Kind.OBRA: "Obras",
	Kind.GENTE: "La banda",
}

## Cuántas anotaciones se guardan. Al pasarse, se olvidan las más viejas.
##
## Cuatrocientas son más de un año de juego a un puñado de sucesos por
## jornada. Guardarlo todo sin tope haría crecer la partida sin límite por un
## texto que nadie va a releer entero.
const MAX_ENTRIES := 400

## Una anotación. Diccionario y no clase por una razón práctica: así se
## guarda y se carga con la partida sin escribir nada de serialización.
##   day, season, year · cuándo
##   kind              · de qué habla
##   text              · qué pasó, ya redactado
##   weight            · 0 rutina, 1 digno de contar, 2 no se olvida
var entries: Array[Dictionary] = []

## Cuántas anotaciones se han añadido desde la última vez que se miró. Lo usa
## la interfaz para avisar sin tener que comparar listas.
var unread: int = 0


## Anota algo. `weight` decide si sobrevive a la criba y cómo se destaca.
func record(day: int, season: int, year: int, kind: Kind,
		text: String, weight: int = 1) -> void:
	entries.append({
		"day": day, "season": season, "year": year,
		"kind": kind, "text": text, "weight": weight,
	})
	unread += 1

	if entries.size() > MAX_ENTRIES:
		_forget()


## Al llenarse, se olvida lo rutinario antes que lo importante.
##
## Tirar por orden de antigüedad a secas borraría el día que se descubrió la
## cueva para dejar sitio a «se rompió una lasca». Se van las de peso 0 más
## viejas, y sólo si no queda ninguna se toca lo demás.
func _forget() -> void:
	for i in range(entries.size()):
		if int(entries[i]["weight"]) <= 0:
			entries.remove_at(i)
			return
	entries.remove_at(0)


## Las últimas anotaciones, de la más reciente a la más vieja.
func recent(count: int = 40, kind: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(entries.size() - 1, -1, -1):
		if kind >= 0 and int(entries[i]["kind"]) != kind:
			continue
		out.append(entries[i])
		if out.size() >= count:
			break
	return out


## Cuántas anotaciones hay de cada tipo, para los filtros.
func counts() -> Dictionary:
	var out := {}
	for entry: Dictionary in entries:
		var kind := int(entry["kind"])
		out[kind] = int(out.get(kind, 0)) + 1
	return out


func mark_read() -> void:
	unread = 0


## La fecha de una anotación, en una línea.
static func stamp(entry: Dictionary) -> String:
	return "Día %d · %s, año %d" % [
		int(entry["day"]),
		Subsistence.season_name(int(entry["season"]) as Subsistence.Season),
		int(entry["year"])]


static func kind_name(kind: Kind) -> String:
	return String(KIND_NAMES.get(kind, "Otros"))
