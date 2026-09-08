@tool
class_name ResourceMapper
extends RefCounted
## Deriva del terreno dónde hay de cada cosa, y lo reparte en manchas.
##
## Nada de esto es arbitrario: cada actividad busca en el terreno la condición
## que de verdad la determina. La pesca sigue el agua corriente, y más donde el
## cauce se remansa; la caza busca el llano abierto lejos del ruido del
## poblado; la recolección quiere ladera suave y soleada; el marisqueo, orilla
## de mar; la materia prima, la barra de cantos del río y el afloramiento en
## pendiente.
##
## Ver [ResourceField] para el reparto y la estación, y [BandKnowledge] para lo
## que la banda llega a saber de todo esto.

## Lado de celda del campo de recursos, en metros. Grueso a propósito: una
## mancha de avellanos o un cotarro de ciervos es una zona de decenas de
## metros, no un punto, y a esta resolución el campo entero cabe de sobra.
const CELL_METERS := 64.0


## Construye el campo a partir del terreno ya generado.
static func build(terrain: TerrainGenerator, home: Vector3) -> ResourceField:
	var field := ResourceField.new()
	var size := Vector2(float(terrain.terrain_size.x), float(terrain.terrain_size.y))
	var cells_x := maxi(int(size.x / CELL_METERS), 4)
	var cells_z := maxi(int(size.y / CELL_METERS), 4)
	field.setup(cells_x, cells_z, size)

	for z in range(cells_z):
		for x in range(cells_x):
			var point := field.cell_center(x, z)
			point.y = terrain.get_height_at(point)

			var slope := terrain.get_slope_at(point)
			var water := terrain.crossing_difficulty_at(point)
			var underwater := terrain.is_underwater(point)
			var distance := Vector2(point.x - home.x, point.z - home.z).length()

			# --- Pesca ---------------------------------------------------
			# Sigue al agua corriente. El mejor sitio no es el rápido sino el
			# tramo ancho y remansado, donde el salmón para: por eso puntúa la
			# cantidad de agua y penaliza la pendiente.
			if water > 0.05 and not underwater:
				field.set_abundance(Subsistence.Activity.PESCA, x, z,
					clampf(water * 1.3 - slope * 1.5, 0.0, 1.0))

			# --- Marisqueo -----------------------------------------------
			# Solo hay donde hay mar. Si el emplazamiento no tiene costa, este
			# campo se queda vacío entero, y eso es correcto.
			if underwater:
				field.set_abundance(Subsistence.Activity.MARISQUEO, x, z, 0.9)

			# --- Caza ----------------------------------------------------
			# Llano abierto, y no pegado a casa: la presa se va del entorno
			# inmediato de un campamento ocupado.
			if not underwater and water < 0.3:
				var open := 1.0 - clampf(slope * 2.2, 0.0, 1.0)
				var away := clampf(distance / 600.0, 0.0, 1.0)
				field.set_abundance(Subsistence.Activity.CAZA, x, z,
					clampf(open * (0.35 + 0.65 * away), 0.0, 1.0))

			# --- Recolección ---------------------------------------------
			# Ladera suave y cerca de agua, que es donde está el avellanar
			if not underwater and water < 0.3:
				var gentle := 1.0 - clampf(absf(slope - 0.12) * 4.0, 0.0, 1.0)
				var moist := clampf(_water_nearby(terrain, point) * 1.4, 0.0, 1.0)
				field.set_abundance(Subsistence.Activity.RECOLECCION, x, z,
					clampf(gentle * (0.45 + 0.55 * moist), 0.0, 1.0))

			# --- Materia prima -------------------------------------------
			# Canto rodado en la orilla del río y afloramiento en pendiente
			if not underwater:
				var gravel := clampf(_water_nearby(terrain, point) * 1.6, 0.0, 1.0) \
					if water < 0.3 else 0.0
				var outcrop := clampf((slope - 0.25) * 2.5, 0.0, 1.0)
				field.set_abundance(Subsistence.Activity.MATERIA_PRIMA, x, z,
					clampf(maxf(gravel, outcrop), 0.0, 1.0))

	# Las manchas: cada núcleo se extiende a su entorno con un centro mejor y
	# unos bordes peores, que es la forma que tiene un recurso de verdad.
	field.spread(Subsistence.Activity.CAZA, 3)
	field.spread(Subsistence.Activity.RECOLECCION, 2)
	field.spread(Subsistence.Activity.PESCA, 1)
	field.spread(Subsistence.Activity.MARISQUEO, 2)
	field.spread(Subsistence.Activity.MATERIA_PRIMA, 2)

	return field


## Cuánta agua hay en el entorno de un punto, de 0 a 1. Sirve de indicador de
## humedad: lo que crece cerca del arroyo no es lo que crece en el alto.
static func _water_nearby(terrain: TerrainGenerator, point: Vector3) -> float:
	var best := 0.0
	for spoke in range(8):
		var angle := TAU * float(spoke) / 8.0
		for radius: float in [60.0, 130.0]:
			var probe := point + Vector3(cos(angle), 0.0, sin(angle)) * radius
			best = maxf(best, terrain.crossing_difficulty_at(probe))
	return best
