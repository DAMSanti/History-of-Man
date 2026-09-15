class_name TestMinimapa
extends TestCase
## Un clic en el minimapa lleva la cámara al sitio del valle que se ha pinchado.
## Petición del usuario del 2026-09-14.


func suite_name() -> String:
	return "Minimapa"


func test_el_punto_del_mapa_es_el_mismo_sitio_del_valle() -> void:
	var mundo := Vector2(4096.0, 4096.0)
	var lado := Vector2(256.0, 256.0)
	assert_eq(Minimapa.punto_del_valle(Vector2.ZERO, lado, mundo), Vector3.ZERO,
		"la esquina de arriba a la izquierda es el origen del recuadro")
	assert_eq(Minimapa.punto_del_valle(Vector2(128.0, 64.0), lado, mundo),
		Vector3(2048.0, 0.0, 1024.0), "el centro en ancho y un cuarto en alto")
	assert_eq(Minimapa.punto_del_valle(Vector2(300.0, -5.0), lado, mundo),
		Vector3(4096.0, 0.0, 0.0), "fuera del mapa se queda en el borde")
