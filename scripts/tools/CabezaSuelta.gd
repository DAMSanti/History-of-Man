extends SceneTree
## SACA LA CABEZA DEL CUERPO A UNA MALLA APARTE. GRAFICOS §5.1.
##
## La ropa modular del pack **trae su propia piel**: la pieza de brazos lleva dos materiales,
## el del atuendo y el de la piel (`MI_Regular_Male`). O sea que el cuerpo desnudo no se
## dibuja debajo: se esconde, y la ropa pone el cuerpo entero.
##
## Se comprobó en captura, y salió un hombre vestido y **sin cabeza**: el cuerpo del pack es
## UNA sola malla que incluye la cabeza. Así que hay que partirla. Esto guarda la parte de
## arriba —la que cuelga de `Head` y `neck_01`— como malla propia, con sus pesos intactos,
## para poder ponerla encima de la ropa.
##
##   godot --headless --path . --script res://scripts/tools/CabezaSuelta.gd

const CUERPOS := {
	"male": "res://models/people/universal/cuerpos/Superhero_Male_FullBody.gltf",
	"female": "res://models/people/universal/cuerpos/Superhero_Female_FullBody.gltf",
}
## Los huesos que se quedan con la cabeza. `neck_01` entra para que no haya un corte seco
## en la garganta: el cuello asoma por encima de la túnica.
const DE_LA_CABEZA := ["Head", "neck_01"]
## Cuánto peso tiene que llevar un vértice de esos huesos para contarlo de la cabeza. Medio
## es lo justo: por debajo entran hombros, por encima se pierde la base del cuello.
const PESO_MINIMO := 0.5


func _init() -> void:
	for sexo: String in CUERPOS:
		_partir(sexo, CUERPOS[sexo])
	quit()


func _partir(sexo: String, ruta: String) -> void:
	var escena: PackedScene = load(ruta)
	if escena == null:
		print("%s: no carga %s" % [sexo, ruta])
		return
	var raiz := escena.instantiate()
	var esqueleto := _buscar(raiz, "Skeleton3D") as Skeleton3D
	var cuerpo: MeshInstance3D = null
	for m in _mallas(raiz):
		var mi := m as MeshInstance3D
		if mi.skin != null and mi.mesh != null and mi.mesh.surface_get_arrays(0)[
				Mesh.ARRAY_VERTEX].size() > 3000:
			cuerpo = mi
	if esqueleto == null or cuerpo == null:
		print("%s: falta esqueleto o malla de cuerpo" % sexo)
		return

	var skin := cuerpo.skin
	var de_la_cabeza := {}
	for b in range(skin.get_bind_count()):
		var hueso := skin.get_bind_bone(b)
		if hueso < 0:
			hueso = esqueleto.find_bone(skin.get_bind_name(b))
		if hueso >= 0 and DE_LA_CABEZA.has(esqueleto.get_bone_name(hueso)):
			de_la_cabeza[b] = true

	var arrays := cuerpo.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var por_vertice := bones.size() / maxi(verts.size(), 1)

	var arriba := PackedInt32Array()
	arriba.resize(verts.size())
	for v in range(verts.size()):
		var peso := 0.0
		for k in range(por_vertice):
			if de_la_cabeza.has(bones[v * por_vertice + k]):
				peso += weights[v * por_vertice + k]
		arriba[v] = 1 if peso >= PESO_MINIMO else 0

	# Se queda el triángulo si CUALQUIERA de sus tres vértices es de la cabeza: así el borde
	# del cuello solapa un poco con la túnica en vez de dejar un agujero entre las dos.
	var caras := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		if arriba[indices[i]] + arriba[indices[i + 1]] + arriba[indices[i + 2]] > 0:
			caras.append(indices[i]); caras.append(indices[i + 1]); caras.append(indices[i + 2])

	var nuevas := arrays.duplicate()
	nuevas[Mesh.ARRAY_INDEX] = caras
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, nuevas)
	malla.surface_set_material(0, cuerpo.mesh.surface_get_material(0))
	var destino := "res://models/people/universal/cuerpos/cabeza_%s.res" % sexo
	var err := ResourceSaver.save(malla, destino)
	print("%s: %d de %d triangulos -> %s (%s)" % [sexo, caras.size() / 3,
		indices.size() / 3, destino, error_string(err)])


func _mallas(nodo: Node) -> Array[Node]:
	var out: Array[Node] = []
	if nodo is MeshInstance3D:
		out.append(nodo)
	for h in nodo.get_children():
		out.append_array(_mallas(h))
	return out


func _buscar(nodo: Node, clase: String) -> Node:
	if nodo.get_class() == clase:
		return nodo
	for h in nodo.get_children():
		var f := _buscar(h, clase)
		if f != null:
			return f
	return null
