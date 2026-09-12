class_name FirmaDiaria
extends RefCounted
## La huella de una jornada: con qué se compara si dos corridas son la misma
## partida.
##
## Es la «huella diaria» de docs/specs/LO_MISMO_MAS_DEPRISA.md §1. No se llama
## `Huella` porque ese nombre ya lo tienen la forma de un paraje ([Huella],
## `Paraje.huella`) y su sonda (`HuellaProbe`).
##
## Tres piezas, cada una para una cosa:
##
## - **[firma]**: SHA-256 de la [Instantanea] entera. Es la que decide: igual
##   o distinta, sin tolerancias, a precisión completa. Una millonésima de
##   hambre en una persona ya la cambia.
## - **[resumen]**: lo que pide la spec en claro —gente, despensa, técnicas,
##   heridos…— para leer DE QUÉ va una diferencia cuando la firma no cuadra.
## - **[detalle]**: un número corto por «Clase.campo», para saber DÓNDE está
##   la diferencia sin tener que abrir las dos instantáneas.
##
## Se toma en `day_passed`, o sea DENTRO del paso en que se cierra la jornada:
## mirar `sim.day` desde el bucle de la sonda, una vez por fotograma, la toma
## unos pasos después según lo cargada que esté la máquina.

var dia: int = 0
var firma: String = ""
var resumen: Dictionary = {}
var detalle: Dictionary = {}
var errores: Array[String] = []


static func de(sim: SettlementSim, fauna: WildlifeHerds = null,
		cuevas: Array = []) -> FirmaDiaria:
	var foto := Instantanea.tomar(sim, fauna, cuevas)
	var huella := FirmaDiaria.new()
	huella.dia = sim.day
	var sha := HashingContext.new()
	sha.start(HashingContext.HASH_SHA256)
	sha.update(foto.bytes())
	huella.firma = sha.finish().hex_encode()
	huella.errores = foto.errores
	huella.resumen = resumen_de(sim)
	huella.detalle = detalle_de(foto)
	return huella


## Lo que pide la queja —despensa, técnicas, heridos— y lo que delataría una
## diferencia antes. Los números van como texto para que JSON no les recorte
## cifras: esto se lee, pero también se compara.
static func resumen_de(sim: SettlementSim) -> Dictionary:
	var ids: Array = []
	var heridos := 0
	for persona: Inhabitant in sim.people:
		ids.append(persona.id)
		if persona.hurt_days > 0:
			heridos += 1
	var tecnicas: Array = []
	if sim.techs != null:
		for tecnica: Variant in sim.techs.known:
			tecnicas.append(tecnica)
		tecnicas.sort()
	# Pasado ya por JSON: el resumen que se toma y el que se lee de un fichero
	# tienen que ser el mismo diccionario, y JSON devuelve los enteros como
	# decimales.
	return JSON.parse_string(JSON.stringify({
		"gente": sim.people.size(),
		"ids": ids,
		"raciones": str(sim.store.food_rations()),
		"lena": str(sim.store.amount(Materia.Kind.LENA)),
		"tecnicas": tecnicas,
		"heridos": heridos,
		"parajes": sim.parajes.list.size(),
		"cacerias": sim.caceria.hunts.size() if sim.caceria != null else 0,
		"cronica": sim.chronicle.entries.size() if sim.chronicle != null else 0,
		"desenlace": int(sim.desenlace),
		"azar": str(sim._rng.state),
	}))


## Un número corto por campo. Las raíces, por su nombre («sim.day»); los
## objetos de la tabla, por su clase («Inhabitant.hunger»), juntando todos los
## de la misma clase en uno.
static func detalle_de(foto: Instantanea) -> Dictionary:
	var sumas: Dictionary = {}
	for raiz: String in foto.raices:
		var pares: Array = foto.raices[raiz]
		for i in range(0, pares.size(), 2):
			sumas[raiz + "." + String(pares[i])] = _hash_de(foto, pares[i + 1], {})
	for entrada: Array in foto.objetos:
		var clase := Instantanea.clase_de(entrada)
		var pares: Array = entrada[1]
		for i in range(0, pares.size(), 2):
			var clave := clase + "." + String(pares[i])
			var antes := int(sumas.get(clave, 0))
			sumas[clave] = ((antes * 16777619) ^ _hash_de(foto, pares[i + 1], {})) & 0xffffffff
	var detalle: Dictionary = {}
	for clave: String in sumas:
		detalle[clave] = "%08x" % (int(sumas[clave]) & 0xffffffff)
	return detalle


## El hash de un valor codificado, ABRIENDO los contenedores.
##
## Una lista o un diccionario se guardan aparte y el campo sólo trae «el
## contenedor número 37» —ver [Instantanea.contenedores]—, así que un hash del
## valor a secas diría que dos partidas son iguales porque las dos apuntan al
## 37. Se abre, con memoria de por dónde se ha pasado: hay ciclos.
static func _hash_de(foto: Instantanea, valor: Variant, vistos: Dictionary) -> int:
	if valor is Array and (valor as Array).size() == 2 \
			and (valor as Array)[0] == Instantanea.CONTENEDOR:
		var indice := int((valor as Array)[1])
		if vistos.has(indice):
			return 7919
		vistos[indice] = true
		var suma := 0
		for elemento: Variant in (foto.contenedores[indice] as Array):
			suma = ((suma * 16777619) ^ _hash_de(foto, elemento, vistos)) & 0xffffffff
		return suma
	return hash(var_to_bytes(valor)) & 0xffffffff


## Una línea de texto por jornada: jornada, firma, resumen y detalle,
## separados por tabuladores.
func linea() -> String:
	return "%d\t%s\t%s\t%s" % [dia, firma, JSON.stringify(resumen),
		JSON.stringify(detalle)]


## Lo contrario de [linea]. Devuelve null si la línea no es una firma.
static func desde_linea(texto: String) -> FirmaDiaria:
	var partes := texto.strip_edges().split("\t")
	if partes.size() < 4 or not partes[0].is_valid_int():
		return null
	var huella := FirmaDiaria.new()
	huella.dia = int(partes[0])
	huella.firma = partes[1]
	var resumen_leido: Variant = JSON.parse_string(partes[2])
	var detalle_leido: Variant = JSON.parse_string(partes[3])
	huella.resumen = resumen_leido if resumen_leido is Dictionary else {}
	huella.detalle = detalle_leido if detalle_leido is Dictionary else {}
	return huella
