class_name ImpostorVistas
extends RefCounted
## Las cuentas del impostor de varias vistas: de una dirección de mirada a su foto
## en el atlas, y al revés. GRAFICOS §7.1.
##
## **Hemi-octaédrico**: la semiesfera de direcciones de arriba se aplana en un
## cuadrado, y el cuadrado se parte en `VISTAS × VISTAS` fotos. Así cabe mirar desde
## el horizonte y desde encima con el mismo reparto de fotos, sin que las del polo
## se amontonen. Lo usa el horneado (`ArbolImpostores`) y **la misma cuenta está
## escrita en `arbol_impostor_vistas.gdshader`**: si se toca aquí, se toca allí.

## Fotos por lado del atlas.
const VISTAS := 8

## Píxeles de cada foto en el atlas. 64: de lejos un árbol ocupa menos que eso en
## pantalla, y a 128 los treinta atlas pasaban de 100 MB en crudo. Decisión.
const PIXELES := 64


## De una dirección (en el marco del árbol, y arriba) al cuadrado [-1, 1]².
static func codificar(direccion: Vector3) -> Vector2:
	var d := direccion.normalized()
	d.y = maxf(d.y, 0.0)
	var suma := absf(d.x) + absf(d.y) + absf(d.z)
	if suma <= 0.0:
		return Vector2.ZERO
	var p := Vector2(d.x, d.z) / suma
	return Vector2(p.x + p.y, p.x - p.y)


## Del cuadrado [-1, 1]² a la dirección, siempre por encima del horizonte.
static func decodificar(uv: Vector2) -> Vector3:
	var p := Vector2((uv.x + uv.y) * 0.5, (uv.x - uv.y) * 0.5)
	var y := 1.0 - absf(p.x) - absf(p.y)
	return Vector3(p.x, maxf(y, 0.0), p.y).normalized()


## La dirección desde la que se hace la foto `(i, j)`: el centro de su celda.
static func direccion_de(i: int, j: int) -> Vector3:
	var uv := Vector2((float(i) + 0.5) / VISTAS, (float(j) + 0.5) / VISTAS) * 2.0 - Vector2.ONE
	return decodificar(uv)


## La foto más cercana a una dirección de mirada.
static func celda_de(direccion: Vector3) -> Vector2i:
	var uv := codificar(direccion) * 0.5 + Vector2(0.5, 0.5)
	return Vector2i(clampi(int(uv.x * VISTAS), 0, VISTAS - 1),
		clampi(int(uv.y * VISTAS), 0, VISTAS - 1))


## La base de la cámara que hace la foto desde `direccion`: derecha y arriba. El
## shader arma el cuadrado del impostor con la misma cuenta, así que la foto cae
## derecha en él.
static func base_de(direccion: Vector3) -> Array[Vector3]:
	var mira := direccion.normalized()
	var derecha := Vector3.UP.cross(mira)
	if derecha.length() < 0.001:
		derecha = Vector3.RIGHT
	derecha = derecha.normalized()
	var arriba := mira.cross(derecha).normalized()
	return [derecha, arriba]
