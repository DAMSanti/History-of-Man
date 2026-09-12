class_name TestVeredas
extends TestCase
## Las veredas: los caminos que la banda ya sabe andar.
##
## Lo que aquí se asegura es la regla que antes sólo se podía confiar: NINGUNA
## VEREDA SOBREVIVE A LA REJILLA CON LA QUE SE TRAZÓ. `Navgrid` se rehorna una
## vez por estación porque el caudal y el encharcamiento cambian qué se vadea,
## y una vereda de mayo puede dar en agosto una vuelta que ya no hace falta.
##
## Antes de [Vereda] eso lo sostenía un aviso —`Marcha.forget_routes`, llamado
## a mano al cambiar de rejilla— y un aviso no se puede comprobar: sólo se
## puede confiar en que nadie toque ese camino. Ahora el sello va pegado al
## dato y la vereda de otra rejilla se descarta AL LEERLA. Ver
## docs/SISTEMAS.md §18.


func suite_name() -> String:
	return "Veredas"


## Una rejilla sin medir ni una celda: aquí sólo interesa con qué río se horneó.
func _rejilla(caudal: float, encharque: float) -> Navgrid:
	return Navgrid.preparar(null, false, false, caudal, encharque)


func _camino() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(40.0, 0.0, 0.0),
		Vector3(80.0, 0.0, 0.0)])


# ----------------------------------------------- el sello de la rejilla --

func test_la_vereda_se_sella_con_la_rejilla_que_la_trazo() -> void:
	var grid := _rejilla(1.4, 0.2)
	var senda := Vereda.de(_camino(), grid)
	assert_near(senda.caudal, 1.4, 0.001, "se queda con el caudal de su rejilla")
	assert_near(senda.encharque, 0.2, 0.001, "y con su encharcamiento")


func test_la_vereda_sirve_en_su_propia_rejilla() -> void:
	var grid := _rejilla(1.0, 0.0)
	assert_true(Vereda.de(_camino(), grid).sirve_en(grid),
		"el camino de hoy vale hoy")


func test_ninguna_vereda_sobrevive_a_su_rejilla() -> void:
	# LA REGLA. El río crece, se cierran vados, y el camino de la semana
	# pasada puede cruzar por uno que ya no existe.
	var mayo := _rejilla(1.0, 0.0)
	var agosto := _rejilla(0.55, 0.0)
	assert_false(Vereda.de(_camino(), mayo).sirve_en(agosto),
		"con otro caudal, la vereda no vale")

	# Y lo mismo con la marisma, que es la otra mitad del sello: un llano que
	# en primavera se anda, encharcado no.
	var seco := _rejilla(1.0, 0.0)
	var charco := _rejilla(1.0, 0.45)
	assert_false(Vereda.de(_camino(), seco).sirve_en(charco),
		"con otro encharcamiento, tampoco")


# ------------------------------------------ la memoria de la banda --

func test_la_banda_recuerda_el_camino_y_lo_devuelve() -> void:
	var saber := BandKnowledge.new()
	var grid := _rejilla(1.0, 0.0)
	saber.recordar_vereda("casa>avellanar", _camino(), grid)
	var vuelta := saber.vereda("casa>avellanar", grid)
	assert_true(vuelta != null, "lo que se aprendió se sabe")
	assert_eq(vuelta.hitos.size(), 3, "y son los mismos hitos")


func test_un_trayecto_que_nadie_ha_andado_no_se_sabe() -> void:
	var saber := BandKnowledge.new()
	assert_true(saber.vereda("casa>el_mar", _rejilla(1.0, 0.0)) == null,
		"no se inventa un camino que nadie ha hecho")


func test_la_vereda_de_otra_rejilla_no_se_entrega() -> void:
	# Ésta es la prueba que falla si alguien quita el sello: sin él, la
	# memoria devolvería tan tranquila el camino de mayo en agosto.
	var saber := BandKnowledge.new()
	saber.recordar_vereda("casa>vado", _camino(), _rejilla(1.0, 0.0))
	assert_true(saber.vereda("casa>vado", _rejilla(0.55, 0.0)) == null,
		"la vereda de otro río no se anda")


func test_la_vereda_caducada_no_se_queda_ocupando_sitio() -> void:
	# Descartarla al leerla y dejarla en el diccionario sería una fuga lenta:
	# doscientas veredas muertas esperando a que el tope las empuje.
	var saber := BandKnowledge.new()
	saber.recordar_vereda("casa>vado", _camino(), _rejilla(1.0, 0.0))
	assert_eq(saber.veredas_recordadas(), 1, "se aprendió una")
	saber.vereda("casa>vado", _rejilla(0.55, 0.0))
	assert_eq(saber.veredas_recordadas(), 0, "y al caducar se borra de verdad")


func test_olvidarlas_todas_las_olvida() -> void:
	var saber := BandKnowledge.new()
	var grid := _rejilla(1.0, 0.0)
	saber.recordar_vereda("a", _camino(), grid)
	saber.recordar_vereda("b", _camino(), grid)
	saber.olvidar_veredas()
	assert_eq(saber.veredas_recordadas(), 0, "no queda ninguna")


func test_la_memoria_no_crece_sin_tope() -> void:
	# Criterio de EPOCA_01 §10.1, frente 4: una memoria que creciera todo el
	# año no se quejaría de nada hasta que la partida fuera larga.
	var saber := BandKnowledge.new()
	var grid := _rejilla(1.0, 0.0)
	for i in range(BandKnowledge.VEREDAS_QUE_SE_RECUERDAN + 50):
		saber.recordar_vereda("trayecto_%d" % i, _camino(), grid)
	assert_eq(saber.veredas_recordadas(),
		BandKnowledge.VEREDAS_QUE_SE_RECUERDAN,
		"se para en el tope")


func test_al_llegar_al_tope_se_suelta_la_mas_vieja() -> void:
	var saber := BandKnowledge.new()
	var grid := _rejilla(1.0, 0.0)
	for i in range(BandKnowledge.VEREDAS_QUE_SE_RECUERDAN + 1):
		saber.recordar_vereda("trayecto_%d" % i, _camino(), grid)
	assert_true(saber.vereda("trayecto_0", grid) == null,
		"la primera que se aprendió es la que se suelta")
	assert_true(saber.vereda("trayecto_1", grid) != null,
		"la segunda sigue ahí")


func test_reaprender_un_trayecto_no_lo_duplica() -> void:
	var saber := BandKnowledge.new()
	var grid := _rejilla(1.0, 0.0)
	saber.recordar_vereda("casa>tajo", _camino(), grid)
	saber.recordar_vereda("casa>tajo", _camino(), grid)
	assert_eq(saber.veredas_recordadas(), 1, "es el mismo trayecto")


# ------------------------------------------------------------- la clave --

func test_el_mismo_trayecto_es_la_misma_vereda() -> void:
	# La clave agrupa por cubos de `Vereda.CELDA`, gruesa a propósito: dos que
	# salen del abrigo con veinte metros de diferencia al mismo tajo no
	# necesitan dos caminos.
	var saber := BandKnowledge.new()
	var grid := _rejilla(1.0, 0.0)
	var salida := Vector3(100.0, 0.0, 100.0)
	var tajo := Vector3(500.0, 0.0, 500.0)
	saber.recordar_vereda(Vereda.clave_de(salida, tajo), _camino(), grid)
	var el_otro := Vereda.clave_de(salida + Vector3(20.0, 0.0, 20.0),
		tajo + Vector3(12.0, 0.0, 12.0))
	assert_true(saber.vereda(el_otro, grid) != null,
		"el mismo trayecto, la misma vereda")


func test_dos_destinos_distintos_no_se_prestan_la_vereda() -> void:
	# La queja de la que salió todo esto: «siguiendo el camino de otros
	# pobladores que van a sitios diferentes».
	var salida := Vector3(100.0, 0.0, 100.0)
	assert_true(Vereda.clave_de(salida, Vector3(500.0, 0.0, 500.0))
		!= Vereda.clave_de(salida, Vector3(900.0, 0.0, 900.0)),
		"mismo origen y destinos distintos, claves distintas")


func test_el_origen_cuenta_en_la_clave() -> void:
	# Y ÉSTA ES LA QUE GUARDA LA LECCIÓN: se intentó que la clave fuera sólo el
	# destino —que es lo que pedía la spec— y multiplicó por 135 los pasos que
	# el terreno corta, porque el tramo de enganche pasaba de setenta metros a
	# kilómetros. Ver `Vereda.clave_de` y ESTADO.md §2.
	var tajo := Vector3(500.0, 0.0, 500.0)
	assert_true(Vereda.clave_de(Vector3(100.0, 0.0, 100.0), tajo)
		!= Vereda.clave_de(Vector3(900.0, 0.0, 100.0), tajo),
		"quien viene de lejos no hereda la vereda del que vive al lado")


# ------------------------------------------- engancharse a la vereda --

func _recta() -> PackedVector3Array:
	# Cinco hitos en fila por terreno abierto de [FakeTerrain].
	var puntos := PackedVector3Array()
	for i in range(5):
		puntos.append(Vector3(600.0 + float(i) * 40.0, 0.0, 600.0))
	return puntos


func _abierto() -> Navgrid:
	if _grid_real == null:
		_grid_real = Navgrid.from_terrain(FakeTerrain.new(), false, false)
	return _grid_real


var _grid_real: Navgrid = null


func test_engancharse_por_el_hito_que_toca_no_por_el_primero() -> void:
	# Quien ya está a mitad de vereda no vuelve al principio a tomarla. Es lo
	# que evita el rodeo hacia atrás que daría engancharse siempre por el hito 0.
	var senda := Vereda.de(_recta(), _abierto())
	var desde := Vector3(720.0, 0.0, 600.0)  # a la altura del hito 3
	var trozo := senda.enganchar(desde, _abierto())
	assert_lt(float(trozo.size()), 5.0, "no se entrega la vereda entera")
	assert_eq(trozo[trozo.size() - 1], senda.hitos[senda.hitos.size() - 1],
		"y el final sigue siendo el destino")


func test_el_que_esta_al_principio_se_lleva_la_vereda_entera() -> void:
	var senda := Vereda.de(_recta(), _abierto())
	var trozo := senda.enganchar(Vector3(595.0, 0.0, 600.0), _abierto())
	assert_eq(trozo.size(), 5, "desde el principio se anda toda")


func test_enganchar_nunca_alarga_la_vereda() -> void:
	# Invariante barato y que valdría oro si alguien toca el orden: el trozo
	# entregado es un sufijo, así que no puede tener más hitos que la vereda.
	var senda := Vereda.de(_recta(), _abierto())
	for x in [590.0, 640.0, 700.0, 760.0, 800.0]:
		var trozo := senda.enganchar(Vector3(x, 0.0, 600.0), _abierto())
		assert_lt(float(trozo.size()), 6.0,
			"el enganche recorta o deja igual, nunca añade")


func test_sin_rejilla_no_se_cata_nada_y_se_entrega_entera() -> void:
	# Es el caso de las pruebas y del arranque: sin rejilla no hay nada que
	# catar, y devolver la vereda entera es lo que siempre hizo la caché.
	var senda := Vereda.de(_recta(), null)
	assert_eq(senda.enganchar(Vector3(720.0, 0.0, 600.0), null).size(), 5,
		"sin rejilla, la vereda entera")


func test_una_vereda_de_un_solo_hito_se_entrega_tal_cual() -> void:
	var senda := Vereda.de(PackedVector3Array([Vector3(600.0, 0.0, 600.0)]),
		_abierto())
	assert_eq(senda.enganchar(Vector3(0.0, 0.0, 0.0), _abierto()).size(), 1,
		"no hay por donde engancharse a un solo punto")


func test_el_enganche_no_cruza_lo_que_no_se_puede_cruzar() -> void:
	# LA PRUEBA QUE JUSTIFICA LA CATA. Sin `linea_limpia` el enganche es pura
	# aritmética, y la aritmética dice que al que está al sur del barranco le
	# conviene entrar por el hito de la otra orilla: está a 250 m y no le queda
	# vereda por andar. Sólo que en medio hay treinta metros de pared vertical.
	#
	# Es el mismo fallo que tenía la caché de antes —la recta de la persona al
	# primer hito no la comprobaba nadie— y de donde salían los pasos sobre
	# terreno cortado con camino trazado.
	var grid := _abierto()
	var rodeando := PackedVector3Array([
		Vector3(900.0, 0.0, 900.0),
		Vector3(900.0, 0.0, 600.0),
		Vector3(900.0, 0.0, 260.0),
		Vector3(1024.0, 0.0, 260.0),   # el único paso del barranco
		Vector3(1150.0, 0.0, 260.0),
		Vector3(1200.0, 0.0, 600.0),
		Vector3(1200.0, 0.0, 900.0)])
	var senda := Vereda.de(rodeando, grid)

	var trozo := senda.enganchar(Vector3(950.0, 0.0, 950.0), grid)
	assert_lt(trozo[0].x, FakeTerrain.GORGE_X,
		"no se entra a la vereda por la otra orilla del barranco")
	assert_true(Wayfinder.linea_limpia(grid, Vector3(950.0, 0.0, 950.0), trozo[0]),
		"y el primer tramo, el que nadie comprobaba, se ve limpio")


# ---------------------------------------------------- el remate del final --

func test_el_remate_se_cata_y_si_no_se_ve_la_vereda_no_sirve() -> void:
	# LA PRUEBA QUE SALIÓ DE UNA MEDIDA, no del plan. Una vereda es del SITIO,
	# y el sitio es un cubo de 48 m: su último hito puede estar a setenta
	# metros del punto exacto al que va esta persona. Rematar ahí sin mirar
	# multiplicaba por 18 los pasos que el terreno corta: 79 sin memoria de
	# veredas, 1 471 con ella. Ver ESTADO.md §2.
	var grid := _abierto()
	var senda := Vereda.de(_recta(), grid)

	# Un destino al otro lado del barranco: el remate no se ve desde el final
	# de la vereda, así que la vereda no sirve y hay que buscar camino.
	var tras_la_pared := Vector3(1100.0, 0.0, 600.0)
	assert_eq(senda.remate(Vector3(600.0, 0.0, 600.0), tras_la_pared, grid).size(),
		0, "si el remate no se ve, la vereda no se entrega")


func test_el_remate_limpio_se_anade_al_final() -> void:
	var grid := _abierto()
	var senda := Vereda.de(_recta(), grid)
	var cerca := Vector3(820.0, 0.0, 620.0)
	var camino := senda.remate(Vector3(600.0, 0.0, 600.0), cerca, grid)
	assert_true(camino.size() > 0, "con el remate limpio, la vereda sirve")
	assert_eq(camino[camino.size() - 1], cerca, "y acaba en el punto exacto")


func test_si_el_destino_ya_es_el_final_no_se_anade_hito() -> void:
	# Sin esto, cada viaje al mismo sitio añadiría un hito a dos metros del
	# anterior. Por debajo de media celda se remata sustituyendo, que es lo
	# que hacía siempre.
	var grid := _abierto()
	var senda := Vereda.de(_recta(), grid)
	var final := senda.hitos[senda.hitos.size() - 1]
	var camino := senda.remate(Vector3(600.0, 0.0, 600.0),
		final + Vector3(3.0, 0.0, 3.0), grid)
	assert_eq(camino.size(), senda.hitos.size(), "no crece por un metro")
