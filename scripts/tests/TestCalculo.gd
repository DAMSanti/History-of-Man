class_name TestCalculo
extends TestCase
## `exp` y `pow` que dan el mismo último bit en cualquier hilo.
##
## SISTEMAS §23, «un hilo por campamento». Medido el 2026-09-14: `exp` y `pow`
## de la librería difieren en el último bit entre el hilo principal y un hilo del
## pool —un 15 % y un 5 % de los valores—, mientras que sumar, multiplicar,
## dividir, `floor`, `log`, `sqrt`, `sin` y `atan2` coinciden siempre, y los
## hilos del pool coinciden entre sí. Un campamento que se mira da su paso en el
## hilo principal y uno que no, en el pool: con la librería, la misma partida
## podía separarse por un bit.


func suite_name() -> String:
	return "Calculo"


func test_la_exponencial_vale_lo_que_exp() -> void:
	var peor := 0.0
	for i in range(-400, 401):
		var x := float(i) * 0.037
		var esperado := exp(x)
		peor = maxf(peor, absf(Calculo.exponencial(x) - esperado) / esperado)
	assert_lt(peor, 1e-13, "la exponencial propia no se aleja de exp: %g relativo" % peor)


func test_la_potencia_vale_lo_que_pow() -> void:
	var peor := 0.0
	for base: float in [0.07, 0.5, 0.97, 1.0, 1.3, 7.5, 240.0, 1500.0]:
		for exponente: float in [-2.0, 0.35, 1.0 / 3.0, 1.0, 2.0, 5.0]:
			var esperado := pow(base, exponente)
			peor = maxf(peor, absf(Calculo.potencia(base, exponente) - esperado) / esperado)
	assert_lt(peor, 1e-12, "la potencia propia no se aleja de pow: %g relativo" % peor)
	assert_eq(Calculo.potencia(0.0, 1.0 / 3.0), 0.0, "cero elevado a algo positivo es cero")
	assert_eq(Calculo.potencia(0.0, 0.0), 1.0, "y a cero, uno")


var _en_pool: PackedFloat64Array


func _calcula_en_pool(i: int) -> void:
	var x := float(i) * 0.0013 - 2.0
	_en_pool[i * 2] = Calculo.exponencial(x)
	_en_pool[i * 2 + 1] = Calculo.potencia(absf(x) + 0.1, 0.35)


func test_da_el_mismo_bit_en_el_hilo_principal_y_en_el_pool() -> void:
	# La razón de que exista. Se calcula lo mismo aquí y en el pool y se exige
	# igualdad EXACTA, que es lo que `exp` de la librería no cumple.
	var n := 3000
	_en_pool.resize(n * 2)
	var tarea := WorkerThreadPool.add_group_task(_calcula_en_pool, n)
	WorkerThreadPool.wait_for_group_task_completion(tarea)
	var distintos := 0
	for i in range(n):
		var x := float(i) * 0.0013 - 2.0
		if Calculo.exponencial(x) != _en_pool[i * 2]:
			distintos += 1
		if Calculo.potencia(absf(x) + 0.1, 0.35) != _en_pool[i * 2 + 1]:
			distintos += 1
	assert_eq(distintos, 0, "ni un bit distinto entre hilos")


func test_el_paso_no_llama_a_exp_ni_a_pow_de_la_libreria() -> void:
	# EL INVARIANTE, comprobado: en el código que corre dentro de un paso no hay
	# `exp(` ni `pow(` de la librería. Quedan fuera el relieve al generarse y la
	# ingesta regional, que corren en el hilo principal al montar.
	var fuera := ["TerrainGenerator.gd", "MallaDelTerreno.gd", "Calculo.gd"]
	var encontrados: Array[String] = []
	var patron := RegEx.create_from_string("(?<![A-Za-z_.])(exp|pow)\\(")
	for carpeta: String in ["res://scripts/sim", "res://scripts/mundo",
			"res://scripts/banda", "res://scripts/economia"]:
		for fichero: String in DirAccess.get_files_at(carpeta):
			if not fichero.ends_with(".gd") or fuera.has(fichero):
				continue
			var texto := FileAccess.get_file_as_string("%s/%s" % [carpeta, fichero])
			var linea := 0
			for renglon: String in texto.split("\n"):
				linea += 1
				var sin_comentario := renglon.split("#")[0]
				if patron.search(sin_comentario) != null:
					encontrados.append("%s:%d" % [fichero, linea])
	assert_eq(encontrados.size(), 0,
		"exp/pow de la librería en código de paso: %s" % str(encontrados))
