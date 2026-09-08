class_name HearthFire
extends Node3D
## El hogar del abrigo, visto.
##
## Existía como un booleano —`SettlementSim.hearth_lit`— y como una línea en la
## crónica. En pantalla no había nada: la banda levantaba su primera obra, la
## mantenía encendida todo el año y el valle seguía igual de vacío que el día
## que llegaron.
##
## El fuego en sí lo pone [Bonfire]; esto sólo decide DÓNDE va y CUÁNDO arde,
## que es lo que lo distingue de la hoguera de vivac: el hogar está en la campa
## de la boca y responde al estado del campamento —construido, encendido,
## apagado por falta de leña—, no a que sea de noche.

var _fire: Bonfire
var _sim: SettlementSim


func setup(sim: SettlementSim, terrain: TerrainGenerator, where: Vector3) -> void:
	_sim = sim
	var ground := where
	if terrain != null:
		ground.y = terrain.get_height_at(where)
	global_position = ground

	_fire = Bonfire.new()
	add_child(_fire)
	_fire.build(20260907, 1.0)
	visible = false


func _process(_delta: float) -> void:
	if _sim == null or _fire == null:
		return
	# Construido: se ven las piedras y los leños. Encendido: además arde. Es la
	# misma diferencia que lleva la simulación, y ahora se ve sin abrir nada.
	var built: bool = _sim.camp_built.get(CampProjects.Kind.HOGAR, false)
	visible = built
	_fire.lit = built and _sim.hearth_lit
