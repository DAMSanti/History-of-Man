# Sistemas compartidos entre épocas

Doce épocas contadas una por una (`EPOCA_01_PALEOLITICO.md`... `EPOCA_12_SIGLO_CORTO.md`)
serían doce listas sueltas si no compartieran el esqueleto. Este documento es
ese esqueleto: los sistemas que atraviesan las doce, cómo escalan de una época
a la siguiente, y dónde viven o deberían vivir en el código.

Es la capa que falta entre [EPOCAS.md](EPOCAS.md) —qué hito cierra cada
época— y las fichas de época —qué hay que construir para llegar a cada
hito—. [SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) sigue siendo el diseño
detallado de la primera época; `EPOCA_01_PALEOLITICO.md` la conecta con estos
sistemas y señala lo que falta. Las once siguientes son diseño de destino, no
compromiso de plan: ver ROADMAP.md §Riesgos.

**Corrección de partida.** ROADMAP.md B2 y EPOCAS.md §5 dan la escalera
térmica por escrita: *"`RawMaterial` guarda punto de fusión e ignición... el
árbol tecnológico ya está escrito y sólo hay que leerlo"*. Es falso hoy:
`RawMaterial` no existe en `scripts/`. Se retiró con el resto de la capa de
*city builder* de la encarnación anterior del proyecto —`Architecto`,
`Chunk`, `BlockData`, `RawMaterial`, `buildings/`, `materials/`—, según
ARQUITECTURA.md §8. La escalera sigue siendo la idea correcta —los ROADMAP.md
y EPOCAS.md aciertan en la secuencia de temperaturas—, pero **hay que
escribirla de cero** cuando le toque, no leerla de un sitio que ya no existe.
El resto de este documento parte de ese hecho, no del que estaba escrito.

---

## 1. Las tres escaleras

Ninguna es contenido nuevo por época: son el eje que hace que la progresión
*dentro* de una época no dependa sólo de acumular jornadas en `TechTree`.

### 1.1. La escalera térmica

Un peldaño de temperatura por época desde el Neolítico, y cada peldaño abre
un material o un proceso que el anterior no permitía:

| Época | Instalación | Máx. | Habilita |
|---|---|---|---|
| 1–2 | Hogar abierto | ~700 °C | Cocinar, calcinar concha (cal) |
| 3 | Horno de fosa | ~900 °C | Cerámica |
| 4 | Cubeta con fuelle | ~1100 °C | Cobre (funde a 1085 °C) |
| 5 | Horno mejorado | ~1200 °C | Bronce |
| 6 | Cuba baja | ~1250 °C | Hierro en esponja (no cuela) |
| 8 | Ferrería de monte | — | Poco hierro, caro |
| 9 | Ferrería hidráulica | ~1350 °C | Barras en cantidad |
| 10 | Alto horno | ~1550 °C | Hierro colado (funde a 1538 °C) |
| 11 | Coque | — | Se suelta del bosque: el límite pasa a ser el dinero |

**Cómo se construye, ahora que no hay `RawMaterial` que leer.** El punto de
fusión y de ignición vuelve a `Materia.gd`, junto al resto de la ficha de cada
material —es donde ya vive `kg`, `litros`, si `renews()`—, como dos campos
opcionales (`melts_at`, `ignites_at`) que sólo rellenan los materiales que
importan a la escalera (cobre, estaño, hierro, madera, carbón). La
instalación que da la temperatura —hogar, horno de fosa, cubeta, cuba,
ferrería, alto horno— es una obra de `CampProjects` como hoy lo es
`Kind.HOGAR`, no una técnica de `TechTree`: se levanta, no se aprende. La
condición de un proceso térmico (`ProcessRecipe`, FASE B1) es simplemente
"la instalación construida da más grados que el punto de fusión del
material". Así el árbol no está escrito en ningún sitio nuevo: sale de leer
`Materia.melts_at` contra la temperatura de la obra construida, exactamente
la idea original, con los datos donde tocan.

### 1.2. La escalera del soporte

De qué saber sobrevive al relevo generacional (FASE C). Hoy sólo existe el
primer peldaño: `Tale.gd` (el relato junto al fuego, oral) y `Tech.ARTE`
(parietal, permanente). El resto no tiene clase todavía:

pared y mobiliar (1) → canto pintado (2) → cerámica (3) → molde y marca de
propiedad (4–5) → estela (6) → escritura (7) → cartulario y fuero (8–9) →
imprenta (10) → prensa y fotografía (11) → radio (12).

El patrón se repite en cada peldaño y es el de FASE C1: `DESCONOCIDA` →
`TÁCITA` (decae con el relevo, como hoy) → `EXTERNALIZADA` (permanente, atada
al soporte). Lo que cambia de peldaño en peldaño es **el coste de
externalizar** (ocre y jornadas frente a un manuscrito de meses) y **si el
saber sigue atado a un sitio** —parietal y cartulario lo están; la imprenta
es el primer soporte que no lo está, y por eso EPOCAS.md lo marca como el
salto real de la escalera—. Cada época nueva no reescribe la escalera:
añade una clase `Soporte<Nombre>` con su coste y su condición de "atado al
sitio sí/no", y el estado de la técnica pasa a mirar la más alta disponible.

### 1.3. La escalera del alimento

Y con ella, cuánta gente cabe en el mismo sitio. Hoy sólo está construido el
primer escalón (`Subsistence.Activity`: `CAZA`, `MARISQUEO`, `PESCA`,
`RECOLECCION`, `MATERIA_PRIMA`). El resto es la secuencia de EPOCAS.md §5:

recolección y caza (1) → marisqueo y costa (2) → siembra y rebaño (3) →
excedente almacenable (4–6) → mercado y compra (7) → rotación y molino (8) →
comercio de la villa (9) → maíz y ultramar (10) → mercado nacional por
ferrocarril (11) → frío, conserva y salario (12).

El salto real está en el 3: `Subsistence.Activity` gana `SIEMBRA` y
`PASTOREO`, que ya no dependen de lo que el terreno regala (`ResourceField`)
sino de lo que la banda planta y cuida —una geometría de parcela, no un
`Paraje` que se agota y repone—. `Barbecho.gd` ya resuelve el patrón general
de "dejar descansar lo esquilmado y volver cuando se repone" para recursos
silvestres; el campo cultivado del Neolítico en adelante es el mismo patrón
con reglas propias (se siembra, no se encuentra) y es donde EPOCAS.md dice
literalmente que `Barbecho.gd` **deja de ser una prueba** en la Alta Edad
Media, cuando entra la rotación de tres hojas de verdad.

---

## 2. El sistema de hito

Formalizado en EPOCAS.md §6, con el recurso ya bosquejado:

```gdscript
class_name Hito
extends Resource

@export var id: StringName
@export var epoca: int
@export var nombre: String
@export var descripcion: String
@export var cierra_epoca: bool = false
@export var lo_sufre: bool = false
@export var evidencia: Site.Fidelity
@export var fuente: String
@export var deja_en_el_mapa: Site.Feature = Site.Feature.OTRO
@export var abre_tecnicas: Array[int] = []
@export var abre_procesos: Array[StringName] = []
```

**La condición de disparo no vive en el recurso.** Cada hito mira una cosa
distinta del estado —técnica aprendida, obra terminada, colada hecha,
documento escrito, ruta de intercambio con destino concreto— y eso es
código, no datos. El patrón que sigue el proyecto (`SettlementSim` de
fachada, subsistema con el tema cerrado) da la forma natural:

```gdscript
class_name Hitos
extends RefCounted
## Comprueba las condiciones de disparo de los hitos y aplica sus efectos.
var sim: SettlementSim

func _init(settlement: SettlementSim) -> void:
    sim = settlement

func revisar() -> void:
    for h: Hito in CATALOGUE:
        if alcanzado.get(h.id, false):
            continue
        if _condicion(h.id):
            _disparar(h)
```

**Los cuatro que se sufren** —el bosque cierra el valle, la legión en el
collado, el Estado se va, la guerra de 1937— no comprueban una condición del
jugador: comprueban una condición de **tiempo de partida** (turnos u años
transcurridos desde el hito de cierre anterior, con margen) y disparan solos.
No hay guardarraíl que impida ganarlos porque no se ganan: es el mismo
`Hitos.revisar()`, con `lo_sufre = true` marcando que la condición es
temporal y no una capacidad demostrada. Ver §6.

**`deja_en_el_mapa`** escribe una entrada en `Site.features` del
emplazamiento donde ocurrió —el mismo array que hoy guarda lo real de OSM—,
con la salvedad de que aquí el `Feature` lo añade la partida, no el dato de
origen. Es la misma idea que ya describe `Site.feature_era()`: lo natural
estaba desde el principio, lo construido aparece desde que se levanta, y con
`Hitos` ese "desde que se levanta" pasa a ser un hecho de la partida y no una
época fija.

---

## 3. Los oficios a través de las épocas

`Profession.Job` y `Profession.Speciality` son hoy enteros de un `enum`
cerrado, todos del Paleolítico. Añadir un oficio de época posterior es
añadir un valor al `enum`, una entrada a `CATALOGUE` y, si hace falta,
entradas a `SPECIALITIES`: el patrón no cambia, sólo crece. La tabla resume
**qué oficio nuevo introduce cada época** y **qué oficio paleolítico se
jubila o cambia de forma** — ninguno desaparece del todo antes de la Edad
Contemporánea, porque cazar, pescar y recolectar no dejan de alimentar nunca,
sólo dejan de ser el centro:

| Época | Oficio nuevo | Qué pasa con los de antes |
|---|---|---|
| 1 Paleolítico | `CAZA`, `RIBERA`, `RECOLECCION`, `MANUFACTURA`, `EXPLORACION`, `HOGAR` | — (son el punto de partida) |
| 2 Mesolítico | Ninguno nuevo: `RIBERA` gana la especialidad de conchero y `MANUFACTURA` la de arco | `CAZA` mayor de manada pierde peso: no hay reno ni caballo |
| 3 Neolítico | `LABRIEGO` (siembra y cosecha), `PASTOR` (rebaño y trashumancia corta) | `RECOLECCION` sigue, ya no sola: convive con el campo |
| 4 Calcolítico | `PROSPECTOR` (leer el color del monte, la especialidad "buscador" de EPOCAS.md), `METALURGO` embrionario (funde, no talla) | `MANUFACTURA` se parte de hecho, aunque tarde en partirse de `enum` |
| 5 Bronce | `ARTESANO` como oficio puro (no produce comida y aun así come) | `METALURGO` madura: molde, no sólo cubeta |
| 6 Hierro | `HERRERO` (forja, no sólo cuba), `GUERRERO` | `PROSPECTOR` se especializa en mineral de hierro local, ya no importado |
| 7 Roma | `FUNCIONARIO` (impuesto, censo), `MERCADER` de mercado fijo, `ESCLAVO` como estatuto de trabajo, no oficio elegible | `GUERRERO` cántabro se disuelve o se recicla como auxilar romano, según la partida |
| 8 Alta Edad Media | `MONJE`/`ESCRIBA` (el escritorio), `LABRIEGO` gana el arado de vertedera | `FUNCIONARIO` romano desaparece con el Estado: el impuesto lo cobra ahora el concejo o el monasterio, si lo cobra alguien |
| 9 Baja Edad Media | `MARINERO`/`BALLENERO`, `ARTESANO` gremial (fuero de oficio) | `MERCADER` pasa de mercado local a lonja con pesos públicos |
| 10 Edad Moderna | `OBRERO` de Real Fábrica (jornal, no cosecha), `IMPRESOR` | `HERRERO` de monte se vuelve minoritario frente al alto horno |
| 11 El vapor | `OBRERO` fabril generalizado, `MINERO` a cielo abierto, `MAQUINISTA` de ferrocarril | El jornal (§10) se convierte en la forma normal de trabajar, no la excepción |
| 12 El siglo corto | `VERANEANTE` no es oficio, es una clase de sitio nuevo; `TECNICO`/`QUIMICO` de fábrica | El éxodo rural vacía `LABRIEGO` y `PASTOR` de buena parte del mapa |

**Regla para añadir un oficio**: sigue exactamente `Profession.can_do()` —
edad, sexo (por defecto sin veto, con la misma nota histórica que ya lleva el
fichero), y si es `mobile`. Ningún oficio de época posterior necesita un
campo nuevo en `Inhabitant`; el `enum Job` crece, el resto del sistema no.

---

## 4. La exploración en tres capas

El código de hoy resuelve una sola capa, y **la capa que falta es
exactamente la que pide el objetivo de esta tanda de trabajo** ("nos falta
todavía introducir la exploración fuera del mapa").

| Capa | Qué es | Estado |
|---|---|---|
| **Local** | Batida (`Reconocimiento._batida_target`, `Exploration.best_frontier`) y expedición dentro de los 4 km del mapa local | Construida. Resuelve incógnitas de `Paraje`, abre monte sin nombre dentro del recuadro |
| **Regional** | Descubrir otros `Site` del mapa de Cantabria por proximidad o por expedición larga desde el emplazamiento fundado | **No construida.** Es la FASE A1 del ROADMAP.md, sin hacer: hoy se ven los 862 emplazamientos de golpe |
| **Exterior** | Contacto con otra banda, otro poblado, otra villa: gente que no es la tuya y con la que se puede tratar, temer o pelear | No existe ni como diseño de sistema fuera de este documento |

**Capa regional**, el hueco inmediato. El patrón ya está resuelto en local
—`Exploration.best_frontier` puntúa candidatos por cuánto abren entre lo que
cuestan— y se traslada de escala: en vez de puntos sobre una malla continua,
candidatos son los `Site` vecinos del emplazamiento fundado, y "cuánto se
descubre" es revelar su ficha (`Site.describe_for_player`) en vez de
terreno. Una expedición regional larga —EXPLORACION/EXPEDICION ya es la
especialidad que "abre comarca" según `Profession.SPECIALITY_INFO`— cuesta
jornadas y víveres de verdad (se sale del abrigo, no se vuelve el mismo día)
y revela un radio de `Site` alrededor del punto de llegada. Con la niebla de
guerra puesta de este modo, `PanelSitios` deja de mostrar los 862 desde el
minuto uno, que es justo lo que dice el criterio de A1: *"el jugador no ve
los 862 de golpe; los descubre"*.

**Capa exterior**, la base para lo que aún no tiene fecha. "Otra banda" no
es un `Settlement` jugable propio todavía —eso es una banda de IA rival o
neutra, que es contenido de más adelante—, pero el **encuentro** sí es una
mecánica que se puede sentar ya: un `Site` regional puede llevar una marca
de "ocupado por otro grupo" en vez de estar libre, y una expedición que lo
alcanza dispara un evento con tres desenlaces posibles —evitarlo, tratar
(ver §5, comercio), o el conflicto que a partir de la Edad del Hierro se
vuelve `GUERRERO` de verdad—. El primer indicio de esta capa **ya está en el
Paleolítico** y no hace falta inventarlo: la "concha de lejos" de EPOCAS.md
—materia que no es de aquí, y que obliga a que exista una red— es la prueba
de que hay banda vecina desde el principio, aunque nunca se la vea en
pantalla. Formalizar el contacto es sólo dar forma a algo que la ficha del
Paleolítico ya exige que exista.

---

## 5. El comercio, de la concha de lejos al mercado nacional

Es una sola escalera con cuatro peldaños reales, y el primero **ya está
obligado por los datos**: `SLICE_PALEOLITICO.md` §4 dice sin rodeos que el
sílex bueno no existe en Cantabria y hay que importarlo. Ese hecho geológico
es la semilla de todo el sistema de comercio del juego.

| Peldaño | Época | Qué se intercambia | Con quién |
|---|---|---|---|
| Trueque de banda a banda | 1–4 | Sílex, concha, luego estaño | Otro grupo humano, sin institución de por medio |
| Ruta y depósito | 5–6 | Estaño, luego nada (mineral de hierro local rompe la dependencia) | Redes de larga distancia, EPOCAS.md lo llama literalmente "la ruta del estaño" |
| Mercado con moneda | 7–9 | Todo, con un valor que no se come ni se pudre | El Estado romano, luego la villa con fuero y lonja |
| Mercado exterior que decide el valle | 10–12 | Maíz, mineral, capital | Un continente entero, y luego un consejo de administración que no vive en el valle |

**Diseño del primer peldaño**, porque es el que hace falta antes y el que se
apoya en la capa exterior de exploración (§4). Una `RutaComercio` no es un
`ProcessRecipe` —no hay receta, hay una contraparte con la que negociar— sino
un objeto ligero: qué se ofrece, qué se pide, cuánto tarda el viaje, y si el
otro extremo es fiable o puede fallar (una banda vecina que este año no tiene
sílex de sobra). Encaja en `sim/` como `Intercambio`, con el mismo patrón de
fachada que el resto: `sim.intercambio = Intercambio.new(self)`. El
`Materia.Kind.SILEX` ya existe con su nota "no existe aquí, es importado" —
literalmente sólo falta el objeto que lo hace llegar en vez de aparecer en
el almacén por magia de diseño de nivel.

**El campaniforme del Calcolítico** (EPOCAS.md, "un recipiente que se
enseña, no que se usa") y **el ajuar desigual del Bronce** son la misma
mecánica de comercio vista desde el prestigio en vez de desde la necesidad:
el sistema no necesita distinguir "trueque de subsistencia" de "trueque de
estatus" en el código, sólo en qué materiales mueve cada ruta.

---

## 6. Los cuatro hitos que se sufren

El bosque cierra el valle (1) · la legión en el collado (6) · el Estado se
va (7) · la guerra de 1937 (12). Los cuatro comparten forma: el jugador no
los dispara, y el juego no debe ofrecer ganarlos.

**Patrón de implementación.** No son un evento aleatorio ni un contador de
turnos puro: son una condición de contexto que, cumplida, no se puede evitar
pero sí se puede afrontar mejor o peor. El bosque cierra el valle cuando el
reconocimiento paleoclimático (ya calculado para el nivel del mar, EPOCAS.md
§2) cruza el umbral de fin de glaciación; la legión aparece a una cuenta de
años fija desde el inicio de la Edad del Hierro con variación pequeña, no a
voluntad del jugador. La diferencia entre "hito que se sufre" e "hito de
cierre normal" en el código de `Hitos` es un único booleano
(`lo_sufre`), y lo que cambia con él es la interfaz: no hay barra de
progreso hacia un hito sufrido, sólo el aviso cuando ya está encima, porque
mostrarlo con antelación exacta convertiría "sufrir la Historia" en "gestionar
una cuenta atrás", que es precisamente lo que EPOCAS.md quiere evitar.

**Qué se conserva es la mecánica, no el drama.** El texto de EPOCAS.md ya lo
dice para Roma: *"la época no termina en ruina, termina en una lista de
cosas que se conservan sin quien las mantenía"*. En código eso es una regla
general de los cuatro hitos que se sufren: al disparar, cada obra
(`CampProjects`, y sus equivalentes de época posterior) comprueba si su
`requires` seguía dependiendo de la institución que se va —el molino
hidráulico no necesita el Estado para seguir moliendo, la ferrería de monte
sí necesita comercio para tener metal— y se apaga sólo la que de verdad
dependía de lo perdido.

---

## 7. El asentamiento cambia de escala, no sólo de nombre

`Settlement`/`SettlementSim` es hoy una banda de unas quince personas en un
abrigo. La unidad de juego cambia de forma a lo largo de las doce épocas
exactamente en los puntos que marca la "cuarta regla" de EPOCAS.md §3 —quién
decide—, y son cambios de **quién es la unidad**, no sólo de cuántos:

banda (1–2) → aldea/poblado (3–5) → castro (6) → ciudad bajo el Estado (7) →
valle con concejo (8) → villa con fuero (9–10) → cuenca industrial (11) →
ciudad/comarca contemporánea (12).

**Lo que no cambia es el patrón de simulación.** Población, consumo,
reparto de tareas y prioridades son el mismo esqueleto (`SettlementSim`,
`Reparto`, `Poblaciones`) a cualquier escala; lo que crece es el número de
`Inhabitant` simulados y, desde el castro en adelante, la aparición de una
segunda unidad de decisión por encima del individuo —el castro pacta con
otro castro, la villa negocia su fuero— que hoy no tiene análogo y que
EPOCAS.md deja fuera de alcance salvo como consecuencia de mapa. El primer
sitio donde hace falta código nuevo de verdad, y no sólo más escala, es la
Edad del Hierro: el "pacto entre castros" es una relación entre dos
`Settlement`, y hasta ahí sólo ha existido uno.

---

## 8. Fidelidad histórica

Cada mecánica de cada ficha de época lleva su etiqueta —`ATESTIGUADO`,
`INFERIDO`, `PLAUSIBLE`—, ya definida en `Site.Fidelity` y extendida en
EPOCAS.md a hitos y técnicas. La FASE E4 del ROADMAP.md (enciclopedia dentro
del juego) es donde esas etiquetas se vuelven visibles al jugador; hasta
que exista, este documento y las doce fichas de época son la única
enciclopedia que hay, y por eso llevan la etiqueta en cada afirmación en vez
de darla por sentada.

**El método cambia en la época 11**, y las fichas de las dos últimas épocas
lo repiten porque importa: hasta la Edad Media todo se apoya en cultura
material excavada; desde la Edad Moderna, en archivo; en el siglo XX, en
prensa y memoria. No es peor fuente, es otra, y conviene no mezclarlas bajo
la misma etiqueta.

---

## 9. Cómo se usa esto con el ROADMAP

El orden de trabajo no lo cambia este documento: lo fija ROADMAP.md FASE D y
EPOCAS.md §6 —resolver el choque de `TechTree`/`SLICE_PALEOLITICO`, luego
Mesolítico, luego Neolítico, y de ahí en adelante de una en una—. Lo que
añade este documento es **qué construir una sola vez** para que las once
épocas que faltan no reinventen su propio sistema de hitos, de oficios, de
exploración o de comercio: la escalera térmica, `Hito`/`Hitos`, el `enum
Job` que crece, la exploración regional de §4 y `Intercambio` de §5 se
construyen la primera vez que una época los necesita —el Mesolítico no
necesita ninguno; el Neolítico necesita la escalera térmica y `LABRIEGO`— y
después ya están para las diez siguientes.
