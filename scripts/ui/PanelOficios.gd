class_name PanelOficios
extends RefCounted
## El mapa de los oficios: cuales existen y quien los ejerce.
##
## Sale de [GameUI]. Que oficios hay, en que especialidades se abre cada uno,
## que hace falta para cada una y quien la ejerce hoy. No hay que confundirlo
## con «Trabajos», que es la mesa de mando -cuanta gente en que, con sus
## prioridades-, ni con «Tecnicas», que es lo que cada oficio SABE HACER y su
## arbol: eso vive en [PanelTecnicas].
##
## Sin esta ventana, la unica forma de saber que la pesca de altura existe y
## pide embarcacion era leer el codigo.
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


## El árbol de oficios: qué sabe hacer la banda y en qué se puede repartir.
##
## Va aparte de «Trabajos» y no es lo mismo. Aquélla es la mesa de mando —cuánta
## gente en qué, con sus prioridades— y ésta es el mapa: qué oficios hay, en qué
## especialidades se abre cada uno, qué hace falta para cada especialidad y
## quién la ejerce hoy. Sin esto, la única forma de saber que la pesca de altura
## existe y pide embarcación era leer el código.
func show_professions() -> void:
	var body := ui._window("oficios", "Oficios")
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	ui._text(body, "Un oficio es cómo se organiza la banda; una especialidad es "
		+ "qué parte del monte se toca. Casi nadie vive de un solo trabajo: en "
		+ "una banda de quince, la especialización es la recompensa de haber "
		+ "crecido.", true)

	var counts := _job_headcount()
	for job: int in Profession.Job.values():
		if job == Profession.Job.OCIOSO:
			continue
		body.add_child(HSeparator.new())
		var here: int = counts.get(job, 0)
		ui._heading(body, "%s · %d %s" % [
			Profession.job_name(job as Profession.Job).to_upper(), here,
			"persona" if here == 1 else "personas"])
		ui._text(body, Profession.job_desc(job as Profession.Job), true)
		ui._text(body, "   pueden: %s" % _who_can(job as Profession.Job), true)

		var specialities := Profession.specialities_of(job as Profession.Job)
		if specialities.is_empty():
			ui._text(body, "   no se reparte en especialidades", true)
			continue
		for speciality: int in specialities:
			_speciality_line(body, job as Profession.Job,
				speciality as Profession.Speciality)


## Cuánta gente hay hoy en cada oficio.
func _job_headcount() -> Dictionary:
	var counts: Dictionary = {}
	for person: Inhabitant in ui.sim.people:
		counts[person.job] = int(counts.get(person.job, 0)) + 1
	return counts


## Quién puede con un oficio, dicho en una línea.
func _who_can(job: Profession.Job) -> String:
	var entry: Dictionary = Profession.CATALOGUE[job]
	var parts: Array[String] = ["de %d a %d años" % [
		int(entry["min_age"]), int(entry["max_age"])]]
	if bool(entry["mobile"]):
		parts.append("adultos, y no quien esté criando")
	var able := 0
	for person: Inhabitant in ui.sim.people:
		if Profession.can_do(job, person):
			able += 1
	parts.append("%d de los %d de la banda" % [able, ui.sim.people.size()])
	return " · ".join(parts)


## Una especialidad: qué es, qué le hace falta y quién la ejerce hoy.
func _speciality_line(body: VBoxContainer, job: Profession.Job,
		speciality: Profession.Speciality) -> void:
	var doing: Array[String] = []
	for person: Inhabitant in ui.sim.people:
		if person.job == job and person.current_speciality == speciality:
			doing.append(person.given_name)

	var blocked := _speciality_blocked(speciality)
	var mark := "·" if not blocked.is_empty() else ("◆" if not doing.is_empty() else "▸")
	ui._text(body, "   %s %s" % [mark,
		Profession.speciality_name(speciality)], blocked.is_empty() == false)
	ui._text(body, "       %s" % Profession.speciality_desc(speciality), true)
	if not blocked.is_empty():
		ui._text(body, "       falta: %s" % blocked, true)
	elif not doing.is_empty():
		ui._text(body, "       hoy: %s" % ", ".join(doing), true)


## Qué le falta a una especialidad para poder ejercerse, o "" si nada.
##
## Es la pregunta que no tenía respuesta en pantalla: por qué la pesca de altura
## sale en la tabla y no se puede elegir, o por qué el ahumado no hace nada.
func _speciality_blocked(speciality: Profession.Speciality) -> String:
	match speciality:
		Profession.Speciality.ALTURA:
			return "embarcación, y todavía no se sabe hacer"

	return ""
