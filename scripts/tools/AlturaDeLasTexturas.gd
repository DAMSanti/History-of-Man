extends SceneTree
## ¿TRAEN ALTURA LAS TEXTURAS DEL SUELO, Y SE PARECE AL DIBUJO? GRAFICOS §7.7.
##
## Se queda como herramienta y no como sonda de usar y tirar: es la red que avisa si
## alguien vuelve a empaquetar los arrays sin altura —el alfa saldría plano— o si una
## textura nueva trae un `Displacement` de adorno.
##
## El relieve del terreno sale hoy del brillo del albedo; el `Displacement` descargado vive
## sin usar en el alfa del ORM. Antes de cambiar el shader hay que saber **si eso cambia
## algo**: si en las texturas de verdad el brillo y la altura fueran casi lo mismo, el
## cambio sería cosmético.
##
## Mide, capa por capa:
##
##   - cuánto relieve trae el alfa del ORM (su desviación típica): si es plano, no hay
##     altura que enchufar y el empaquetado está mal;
##   - la **correlación** entre el brillo del dibujo y esa altura. Uno es «son lo mismo»;
##     cero, «no tienen nada que ver».
##
##   godot --headless --path . --script res://scripts/tools/AlturaDeLasTexturas.gd

## De cuántos píxeles se mide, en rejilla. 128 x 128 por capa son 16 384 muestras: de sobra
## para una correlación y en un pestañeo.
const MUESTRAS := 128


func _init() -> void:
	var arrays: TerrainTextureArrays = load(TerrainLayers.ARRAYS_PATH)
	if arrays == null:
		print("AlturaDeLasTexturas: faltan los arrays del terreno")
		quit(1)
		return
	print("%-18s %10s %10s %12s" % ["capa", "altura σ", "brillo σ", "correlación"])
	for i in range(arrays.albedo_images.size()):
		var albedo := _legible(arrays.albedo_images[i])
		var orm := _legible(arrays.orm_images[i])
		var brillos := PackedFloat32Array()
		var alturas := PackedFloat32Array()
		for z in range(MUESTRAS):
			for x in range(MUESTRAS):
				var u := int(float(x) / float(MUESTRAS) * float(albedo.get_width()))
				var v := int(float(z) / float(MUESTRAS) * float(albedo.get_height()))
				var c := albedo.get_pixel(u, v)
				brillos.append(c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
				var uo := int(float(x) / float(MUESTRAS) * float(orm.get_width()))
				var vo := int(float(z) / float(MUESTRAS) * float(orm.get_height()))
				alturas.append(orm.get_pixel(uo, vo).a)
		var nombre: String = TerrainLayers.CATALOGUE[i]["name"] if i < TerrainLayers.CATALOGUE.size() else "?"
		print("%-18s %10.3f %10.3f %12.2f" % [nombre, _tipica(alturas), _tipica(brillos),
			_correlacion(brillos, alturas)])
	quit()


static func _legible(original: Image) -> Image:
	var copia := Image.new()
	copia.copy_from(original)
	if copia.is_compressed():
		copia.decompress()
	return copia


static func _tipica(valores: PackedFloat32Array) -> float:
	var suma := 0.0
	for v in valores:
		suma += v
	var media := suma / maxf(float(valores.size()), 1.0)
	var acum := 0.0
	for v in valores:
		acum += (v - media) * (v - media)
	return sqrt(acum / maxf(float(valores.size()), 1.0))


## Correlación de Pearson, en valor absoluto: lo que interesa es si dicen lo mismo, no el
## signo —una textura con la piedra clara y otra con la piedra oscura son el mismo caso—.
static func _correlacion(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var n := float(mini(a.size(), b.size()))
	if n < 2.0:
		return 0.0
	var ma := 0.0
	var mb := 0.0
	for i in range(int(n)):
		ma += a[i]
		mb += b[i]
	ma /= n
	mb /= n
	var arriba := 0.0
	var sa := 0.0
	var sb := 0.0
	for i in range(int(n)):
		var da := a[i] - ma
		var db := b[i] - mb
		arriba += da * db
		sa += da * da
		sb += db * db
	if sa <= 0.0 or sb <= 0.0:
		return 0.0
	return absf(arriba / sqrt(sa * sb))
