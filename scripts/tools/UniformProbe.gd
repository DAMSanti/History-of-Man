extends SceneTree
## Que los uniforms de ARRAY lleguen de verdad al material.
##
## `set_shader_parameter` sobre un `vec3[]` o un `float[]` no protesta si el
## tipo no encaja: se queda sin poner y el shader usa el valor por defecto, que
## para un array sin inicializar es cero. Es un fallo mudo, y la unica forma de
## descartarlo es leerlo de vuelta.

func _init() -> void:
	var manager := TerrainMaterialManager.new()
	var material := manager.create_terrain_material()
	if material == null:
		print("sin material"); quit(1); return

	for name: String in ["layer_tile_m", "layer_tint", "layer_saturation"]:
		var value: Variant = material.get_shader_parameter(name)
		print("%-18s %s" % [name, "NO PUESTO (null)" if value == null else str(value)])
	quit()
