# Los sistemas del juego

Los sistemas que no son de una época concreta: los que están construidos y
mueven la partida de hoy, y los que atraviesan las once épocas y hay que
construir una sola vez.

Es la capa que falta entre [EPOCAS.md](EPOCAS.md) —qué hito cierra cada época—
y las fichas de época, que dicen qué hay que construir para llegar a cada hito.
Lo que hace hoy el juego **medido**, con qué sonda y con qué cifra, está en
[ESTADO.md](ESTADO.md); aquí está el **mecanismo**.

## Qué hay aquí

**Construido y funcionando** — cómo se comporta el juego hoy:

| | |
|---|---|
| [§10](#10-la-despensa-lo-que-se-pudre-y-lo-que-se-salva) | La despensa: lo que se pudre y lo que se salva |
| [§11](#11-la-caza) | La caza: la puerta del arma, las fases, y qué se lleva a casa |
| [§12](#12-la-pesca) | La pesca: la nasa no es un peldaño, es un objeto en el río |
| [§13](#13-lo-que-se-cuenta-y-lo-que-se-pinta) | Lo que se cuenta al volver, y lo que se queda en la pared |
| [§14](#14-los-desechos-y-el-lobo) | Los desechos, el conchero y el lobo que viene a ellos |
| [§15](#15-la-bellota) | La bellota: la comida que hay que preparar en otoño |
| [§16](#16-el-curtido-de-piel-y-el-taller-que-practica) | El curtido de piel |
| [§17](#17-el-agua-odres-y-por-qué-llenar-uno-puede-ser-una-salida) | El agua: odres, y por qué llenar uno puede ser una salida |

**Diseño de destino** — lo que cruza las once épocas y aún no existe entero:

| | |
|---|---|
| [§1](#1-las-tres-escaleras) | Las tres escaleras: térmica, del soporte, del alimento |
| [§2](#2-el-sistema-de-hito) | El sistema de hito |
| [§3](#3-los-oficios-a-través-de-las-épocas) | Los oficios a través de las épocas |
| [§4](#4-la-exploración-en-tres-capas) | La exploración en tres capas |
| [§5](#5-el-comercio-de-la-concha-de-lejos-al-mercado-nacional) | El comercio |
| [§6](#6-los-tres-hitos-que-se-sufren) | Los tres hitos que se sufren |
| [§7](#7-el-asentamiento-cambia-de-escala-no-sólo-de-nombre) | El asentamiento cambia de escala |
| [§8](#8-fidelidad-histórica) | Fidelidad histórica |
| [§9](#9-cómo-se-usa-esto-con-el-roadmap) | Cómo se usa esto con el ROADMAP |
| [§18](#18-los-caminos-que-la-banda-aprende) | Los caminos que la banda aprende, y por qué caducan |
| [§19](#19-la-temperatura-y-el-abrigo-que-se-lleva-puesto) | La temperatura, y el abrigo que se lleva puesto |
| [§20](#20-la-pasarela-una-obra-en-un-cruce-no-un-permiso) | La pasarela: una obra en un cruce, y no un permiso sobre el mapa |
| [§21](#21-el-hogar-cuidarlo-va-por-delante-de-todo-lo-demás) | El hogar: por qué se apagaba teniendo leña, y el corro del fuego |
| [§22](#22-lo-que-el-jugador-prioriza-materiales-presas-y-la-cola-del-taller) | **Spec**: lo que el jugador prioriza —materiales, presas— y la cola del taller |
| [§23](#23-varios-campamentos-migrar-y-la-partida-que-no-se-mira) | **Spec**: varios campamentos, migrar, y la partida que sigue mientras no se mira |

Las once fichas de época (`EPOCA_01_PALEOLITICO.md`… `EPOCA_11_EL_VAPOR.md`)
serían once listas sueltas sin este esqueleto. Fueron doce: el siglo corto
(1900–1982) se retiró el 2026-09-12 y está en
[archivo/EPOCA_12_SIGLO_CORTO.md](archivo/EPOCA_12_SIGLO_CORTO.md). El
Paleolítico es la única construida; las diez siguientes son diseño de destino,
no compromiso de plan — ver ROADMAP.md §Riesgos.

> Los §10–§15 absorbieron el 2026-09-12 los antiguos `archivo/CAZA_Y_PESCA.md` y
> `archivo/PERRO_Y_BELLOTA.md`, al reorganizar la documentación para que lo único
> específico fueran las épocas. Los originales, con el relato completo de cómo
> se llegó a cada decisión, están en [archivo/](archivo/).

**Corrección de partida.** ROADMAP.md B2 y EPOCAS.md §5 daban la escalera
térmica por escrita: *"`RawMaterial` guarda punto de fusión e ignición... el
árbol tecnológico ya está escrito y sólo hay que leerlo"*. Es falso:
`RawMaterial` no existe en `scripts/`; se retiró con el resto de la capa de
*city builder* (ARQUITECTURA.md §8). La escalera sigue siendo la idea correcta
—la secuencia de temperaturas acierta—, pero **hay que escribirla de cero**
cuando le toque, no leerla de un sitio que ya no existe. El resto de este
documento parte de ese hecho.

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
imprenta (10) → **prensa y fotografía (11)**.

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
comercio de la villa (9) → maíz y ultramar (10) → **mercado nacional por
ferrocarril (11)**.

Esta escalera se queda **sin último peldaño** al haberse retirado la 12: el
cierre del círculo —frío, conserva y salario, la comida suelta de la estación
y del sitio— era el peldaño doce. Con el ferrocarril la restricción se afloja
y no se levanta, y se deja así a propósito: levantarla es justo lo que el
motor de jornadas y calorías no sabe simular. Ver EPOCAS.md §5.

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

**Los tres que se sufren** —el bosque cierra el valle, la legión en el
collado, el Estado se va— no comprueban una condición del
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

**Quien está tocado no sale del abrigo** (2026-09-13). Un percance que todavía
dura —`Inhabitant.esta_tocado()`— deja a esa persona en **trabajo de hogar y
nada más**, que es el que se hace en la campa de la boca, y la aparta de la
expedición y de la cumbre. **No se le tocan las prioridades**: son del jugador,
así que al curarse vuelve solo a su oficio sin que nadie tenga que devolvérselas
—al revés que la berrea, que sí las cambia y por eso sí las guarda—. Antes el
percance sólo bajaba lo que rendía y se salía igual, con la pierna mal. Con
prueba: `TestHerido`.

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
| **Regional** | Descubrir otros `Site` del mapa de Cantabria por proximidad o por expedición larga desde el emplazamiento fundado | **La niebla, construida; quien la levanta, no.** Ver el aviso de abajo |
| **Exterior** | Contacto con otra banda, otro poblado, otra villa: gente que no es la tuya y con la que se puede tratar, temer o pelear | No existe ni como diseño de sistema fuera de este documento |

> **Corregido el 2026-09-12, midiendo antes de construir.** Este apartado decía
> que la capa regional estaba «no construida» y que «hoy se ven los 862
> emplazamientos de golpe». **No es cierto, y no lo era desde hacía tiempo:**
> `GameState.discovered` arranca con sólo la cueva y `RegionMap` filtra por él.
> Al empezar la partida se ve **uno**.
>
> **Lo que de verdad falta es quién descubre.** Nadie llama a
> `GameState.discover` desde la partida, así que la niebla no se levanta nunca
> y el mapa regional se queda en la cueva para siempre. Eso es lo que construye
> el frente 5 de EPOCA_01 §10.1.
>
> Y de paso, dos cifras que este documento repetía mal: el conjunto horneado
> tiene **869** emplazamientos, no 862 —los siete de más son los de prueba—, y
> de ellos sólo **72** son usables en el Paleolítico con el mar a −120 m. Los
> «puntos regionales nuevos» que cierran la fase se miden contra 72, no contra
> 862. Ver [ESTADO.md](ESTADO.md) §2.

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

> **Construido el 2026-09-12: quien levanta la niebla, y quien hay detrás.**
>
> **`Expedicion` (`sim/`)** es la salida larga. Tres adultos como mínimo, 12
> jornadas fuera y **las raciones de todo el viaje sacadas antes de salir**
> —`Despensa.sacar_raciones`, en la cuenta de siempre—. Quien sale **deja de
> existir en el mapa local**: no recibe tick ni entra en el reparto, porque si
> no «salir del valle» era seguir paseando por él. Al volver descubre el
> destino y sus vecinos más cercanos, y es **el único sitio de la partida que
> llama a `GameState.discover`**. Y cuesta igual si vuelve sin nada: el coste
> es haber salido.
>
> **`Contacto` (`sim/`)** es la capa exterior. Qué emplazamientos tienen gente
> —uno de cada cinco, sorteado con el `_rng` **una sola vez**— y el trato con
> cada contraparte. **No vive en `Site`**, que es un recurso horneado de sólo
> lectura, ni en `GameState`, que es lo que cruza escenas: el trato es estado
> de simulación y la instantánea tiene que recorrerlo.
>
> Las cifras que no salen de una medida —12 jornadas, 4 descubiertos por
> vuelta, 3 adultos, uno de cada cinco ocupado— **son decisiones y lo dicen en
> el código**. Se ajustan con la partida delante.
>
> **Y se les ve salir y volver** (2026-09-13): salen andando de la cueva hasta
> la celda del borde del mapa **alcanzable** que mira al destino, y al llegar
> dejan de estar en el valle; a la vuelta aparecen por esa misma puerta y andan
> a casa. Las jornadas del paseo van DENTRO de las doce. Y **despejan el
> minimapa por donde pasan**, con la misma ojeada que cualquiera que anda.
>
> **Y se lleva el vivac** (2026-09-13): además de las raciones, una piel de
> tienda por persona —que vuelve al abrigo— y una de leña por persona y noche
> más la de margen, con **las constantes de la acampada de la cumbre**
> (`SettlementSim.VIVAC_PIEL`, `VIVAC_LENA`, `VIVAC_MARGEN_NOCHES`). Con tres
> personas y doce jornadas: 72 raciones, 3 pieles y 39 de leña. Si falta algo, la
> tarjeta enseña el botón apagado diciendo qué falta, y no se sale.
>
> **Y la primera expedición siempre encuentra gente** (2026-09-13, decisión del
> usuario): su destino se puebla al volver (`Contacto.poblar`), lo hubiera
> sorteado o no. Sólo el destino deja contacto, y con uno de cada cinco
> ocupados dos años de partida acabaron **sin conocer a nadie y sin un trato**
> —ESTADO §2—. De la segunda en adelante, el sorteo.
>
> **Coronar una cumbre bautiza de golpe lo que se ve, y lo cuenta una vez**
> (2026-09-14, petición del usuario: «un solo mensaje diciendo se han descubierto
> X parajes»). `Reconocimiento.bautizar_desde_la_cumbre` pone nombre sin tope a
> todo lo que `_reveal_from_summit` deja conocido en el alcance de la vista, sin
> la tarjeta de «un sitio con nombre» de cada uno, y la tarjeta de la cumbre dice
> cuántos y los cinco primeros. Antes esos sitios salían de la cola **uno por
> vuelta** —`Reconocimiento.DE_UNA_VUELTA`, que sigue siendo la regla para quien
> vuelve de batir el monte— y cada uno con su tarjeta. `TestExploration`.
>
> **Y quien sube, corona** (2026-09-14, segundo `/depurar`: «se queda
> explorando en lugar de hacer la subida, coronar y terminar»). La marcha amarra
> el destino a la celda abierta más cercana y la de una cumbre empinada está
> cerrada: el camino acababa una celda más abajo, a más de los 12 m de
> `Cumbres._is_on_peak`, y al llegar la persona caía en la rama del explorador
> —reconocer y bautizar parajes—. Ahora quien sale a subir lleva su cumbre
> (`Inhabitant.cumbre_objetivo`), y **llegar a su destino es intentar coronarla**.
> Los parajes salen al coronar, en el aviso único de arriba. `TestExploration`.
>
> **Y los nombres no se acaban**: 60 palabras de lugar (`Paraje.LUGARES`) en vez
> de 15, sacadas de la toponimia menor de Cantabria. Con quince, el decimosexto
> sitio del mismo material ya salía «(2)».

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

> **Spec (2026-09-12), de `/epoca 1` y `/spec`.** Las dos capas que faltan se
> construyen **juntas y en ese orden**, y el propósito de la expedición es
> **encontrar gente con la que tratar**, no sólo descubrir terreno: la capa
> regional pone la niebla, y la exterior pone a alguien al final del camino.
> Descubrir puntos regionales y haber mandado una expedición fuera pasan a ser
> **dos de las tres condiciones que cierran la primera fase** del Paleolítico
> —ver [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md) §10.1—, así que esto
> deja de ser infraestructura opcional y se vuelve el camino crítico.
>
> Los criterios están en §10.1, tanda 2, frente 5, y son cuatro: que al empezar
> `PanelSitios` liste un puñado de emplazamientos y no 862; que una expedición
> suba ese número, y cuánto; que **cueste** jornadas-persona y raciones contadas,
> también si vuelve sin llegar; y que alcanzar un `Site` ocupado deje **contacto**
> que sobreviva a la expedición, porque es lo que el trueque de §5 va a usar.
> **La capa regional va antes**: sin niebla no hay nada que descubrir, y la
> expedición no tendría adonde llegar.

> **Spec (2026-09-13): la expedición se equipa, se elige y se ve.** Lleva la
> piel y la leña del vivac con **la misma regla que la cumbre**, no con una
> copia: una piel de tienda por persona, que vuelve, y leña por persona y
> noche. **La gente la elige el jugador**, 3 adultos como mínimo. **Sale y
> vuelve andando por el borde del mapa.** Y lo que descubre **tiene que llegar
> al mapa regional, y quedar guardado**. La regla que cruza épocas es que salir
> del mapa local cuesta equipo, no sólo comida: en la Edad Media será una
> recua. Criterios en [EPOCA_01](EPOCA_01_PALEOLITICO.md) §10.1 → Tanda 3,
> frentes 10 y 15.

### Spec (2026-09-14): explorar hacia un rumbo, y la niebla del mapa regional

Dos piezas que se piden juntas porque una no se entiende sin la otra: **el
jugador elige hacia dónde sale la gente**, y **el mapa regional sólo enseña lo
que alguien ha visto**.

**Por qué.** La expedición de hoy sale una vez al año, en la tarjeta de
primavera, y va sola al sitio sin descubrir **más cercano**: el jugador decide
si sale y quién, pero no adónde. Y el mapa regional esconde los sitios no
descubiertos pero enseña el relieve entero de Cantabria, así que «descubrir»
quita alfileres de encima de un mapa que ya se ve. Las dos cosas vacían la
exploración de decisión: no hay rumbo que elegir ni nada que ver aparecer.

**Lo que se pide.**

1. **Salir cuando se quiera, hacia donde se quiera.** El jugador elige tres
   cosas: **el rumbo** —pinchando en el mapa regional, o en el borde del valle—,
   **quién va** —como hoy, adultos que puedan, tres como mínimo— y **cuántas
   jornadas** dura. La partida sale por el borde del mapa hacia ese rumbo,
   recorre un pasillo en esa dirección durante la mitad de las jornadas y vuelve.
   Lo que cuesta sigue la regla de hoy —raciones por persona y jornada, la piel
   y la leña del vivac, y cuesta igual si vuelve sin nada—.
2. **Descubre lo que tiene a la vista.** Los sitios que caen dentro del pasillo
   recorrido quedan descubiertos, y los que estén ocupados dejan contacto como
   hoy. Ya no se descubre «el destino y sus cuatro vecinos».
3. **Sustituye a la tarjeta de primavera.** La primavera se queda sin decisión
   del año —ver [EPOCA_01](EPOCA_01_PALEOLITICO.md), las cuatro decisiones—: es
   una consecuencia aceptada, porque salir cuando se quiere hace que esa tarjeta
   sobre.
4. **La niebla del mapa regional.** Lo no descubierto se tapa con una niebla
   opaca clara, dejando intuir **el perfil de la costa de la época** para no
   perder la orientación; ni sitios, ni ríos, ni frontera se ven bajo ella.
   Levantan la niebla, y queda levantada para siempre en la partida:
   - **el recuadro entero de cada campamento** —ver §23—, habitado o abandonado;
   - **el pasillo de cada expedición**, de ida y de vuelta;
   - **lo que se ve desde cada cumbre coronada**, con el mismo alcance de vista
     que ya descubre parajes (1,4 km), aunque salga del recuadro;
   - **cada mapa visitado**, entero.
5. **Y en el mapa visitado, la misma niebla.** Al entrar de visita, el minimapa
   y el valle están en niebla salvo lo que las expediciones hayan recorrido, y
   los parajes y cuevas que encontraron se ven con su alfiler.

Cómo se ve la niebla y lo que cuesta: [GRAFICOS.md](GRAFICOS.md) §3. Cómo se
elige el rumbo: [INTERFAZ.md](INTERFAZ.md) §4.

**Criterios de aceptación.**

- Con la partida recién empezada, **la fracción del mapa regional sin niebla es
  la del recuadro del primer campamento** y nada más —medida sobre la máscara de
  niebla, en celdas—.
- Una expedición mandada hacia un rumbo durante N jornadas descubre **sólo**
  sitios cuyo punto cae dentro del pasillo recorrido, y **todos** los de dentro:
  prueba con un catálogo de sitios puesto a mano a los dos lados del pasillo.
- Dos expediciones de las mismas jornadas y gente hacia rumbos opuestos
  descubren **conjuntos disjuntos** de sitios y levantan niebla en lados
  opuestos del campamento.
- Mandarla no depende de la estación: una prueba la manda en invierno y sale.
- Coronar una cumbre junto al borde del recuadro levanta niebla **fuera** del
  recuadro, hasta el alcance de vista.
- La niebla sobrevive a guardar y cargar, y a ir y volver del mapa regional:
  prueba de ida y vuelta sobre la máscara.
- En el mapa regional, un sitio bajo niebla **no se puede seleccionar** ni sale
  en ninguna lista.

**Fuera de alcance.**

- **Rutas con varios tramos** o puntos de paso: un rumbo, una ida y una vuelta.
- **Niebla que vuelve** con el tiempo: lo visto no se olvida.
- **Cambiar el alcance de vista de las cumbres**, o el coste de la expedición:
  se usan los que hay.
- **Contacto y trueque**: siguen como están; esto sólo cambia qué se descubre.

### Plan técnico: rumbo y niebla (2026-09-14)

**Lo que hay hoy en el código, que es lo que manda el plan.**

- `Expedicion` (`sim/`) sale con `mandar_a(quienes, hacia)` hacia **un sitio**
  (`destino_de_hoy`, el más cercano sin descubrir), dura `JORNADAS_FUERA` = 12 y al
  volver descubre el destino y `SE_DESCUBREN` = 4 vecinos (`_descubrir_alrededor`),
  por la cola de la barrera (`SettlementSim.descubrir`). La propone sólo
  `proponer_la_salida`, desde `SettlementSim._decision_de_la_estacion` en primavera.
- **La niebla regional de hoy son alfileres**: `RegionMap._refresh_sites` enseña
  sólo lo de `GameState.discovered`, y el relieve, los ríos, el mar y la frontera
  (`_border`, una cinta de malla) se ven enteros. El relieve es un
  `TerrainGenerator` con `shaders/triplanar.gdshader`, que ya tiene una máscara
  sobre el mundo (`region_mask_tex`, la del territorio de la época): el patrón de
  una textura de máscara en el shader existe.
- **La niebla del valle** es la del minimapa (`Minimapa._refresh_minimap_fog`), de
  lo explorado por la banda de ese mapa. Una visita tiene simulación sin gente, así
  que su minimapa sale todo en niebla.
- La cumbre ve `Cumbres.ASCENT_SIGHT_RANGE` = 1 400 m, sólo dentro del recuadro
  (`_reveal_from_summit` recorre la rejilla local).
- No hay paso de mundo local a geográfico: `TerrainGenerator.geo_to_world` sólo va
  en un sentido.

**Módulos afectados.**

1. **`NieblaRegional` (`region/`, nuevo)**: una rejilla sobre el recuadro del
   relieve regional con dos capas de bits —**vista** (lo que levanta la niebla) y
   **recorrida por expediciones** (lo que se enseña en el minimapa de una visita)—.
   Levanta rectángulos geográficos, círculos y pasillos **por exceso** (toda celda
   que la forma toque), para que un sitio descubierto no caiga nunca en una celda
   con niebla. Cuelga de `GameState.niebla`: es estado que cruza escenas, como
   `discovered`, y sin autoload (SPECS §2.2).
2. **`Pasillo` (`sim/`, nuevo)**: la geometría de una salida —origen, rumbo,
   jornadas— y `contiene(lon, lat)`. **Una sola**: la usan la expedición al
   volver, la flecha del mapa regional y la del valle. Así la flecha cubre el
   mismo pasillo que se descubre por construcción, y la prueba lo compara.
3. **Levantar la niebla pasa por la barrera**, igual que descubrir (§23, SPECS
   §3.1): quien la levanta dentro del paso —la expedición al volver, la cumbre al
   coronar— lo deja en una cola de su simulación, y el reloj lo junta en
   `GameState.niebla` en orden de campamento. Al levantar, se descubren los sitios
   **cuyo punto está dentro de la forma** —geométrico, no por celdas—.
4. **`Expedicion`** con rumbo y jornadas: `mandar_a(quienes, rumbo, jornadas)`,
   el coste con las jornadas elegidas y la regla de hoy, `puerta_del_valle` por
   rumbo, y al volver el pasillo: sitios, contacto de los ocupados y niebla. Se
   van `destino_de_hoy`, `SE_DESCUBREN`, `_descubrir_alrededor` y
   `proponer_la_salida`; la primavera se queda sin decisión.
5. **`Cumbres`** levanta un círculo de `ASCENT_SIGHT_RANGE` alrededor del pico,
   con `TerrainGenerator.world_to_geo` (nuevo, el inverso del que hay).
6. **`Campamentos`/`GameState.begin`/la visita**: el recuadro de un campamento al
   darse de alta, y el de un mapa visitado al entrar.
7. **`Guardado`**: la niebla en el fichero, sumada al cargar como `discovered`.
8. **`shaders/triplanar.gdshader`, el agua y la frontera del regional**: la calima
   encima de lo no visto, el trazo de costa, el borde fundido. `RegionMap` pone la
   textura de `GameState.niebla`.
9. **Mandar**: en el mapa regional (pinchar el rumbo desde un campamento, flecha
   con el pasillo, ficha de quién y cuántas jornadas) y en el valle (pinchar el
   rumbo desde la cueva, la misma ficha). La ficha es de interfaz y va en
   `ui/`; la flecha, en `vista/`.
10. **La visita**: su minimapa, en niebla salvo la capa de lo recorrido por
    expediciones, y las cuevas de dentro con su alfiler.

**Decisiones del usuario (2026-09-14).**

- **El pasillo tiene 700 m a cada lado** del rumbo: la mitad de lo que se ve desde
  una cumbre, porque desde el fondo de un valle se ve menos.
- **La ida avanza con el andar de siempre** sobre el relieve regional —el de
  `Viaje.camino`: Tobler y 11 horas útiles por jornada— durante la mitad de las
  jornadas; por la montaña se llega menos lejos.
- **Se eligen de 4 a 24 jornadas, de 2 en 2.**
- **La primera expedición encuentra gente en el sitio del pasillo más lejano** del
  campamento, el más cerca de donde se da la vuelta. Si en el pasillo no hay
  ningún sitio, no hay a quién encontrar.
- **En la visita salen con alfiler sólo las cuevas** de lo recorrido por
  expediciones: una expedición no bautiza parajes en valles ajenos.
- **La niebla del pasillo se levanta al volver**, con los sitios y el contacto.
- **Todas las tareas seguidas.**

**Qué contrato cambia, dicho**: `GameState` gana `niebla` (SPECS §2.2 y §4.x), y
se escribe sólo en la barrera o fuera del paso (SPECS §3.1, §7). EPOCA_01 pierde
la decisión de primavera.

**Orden de dependencias.** La niebla y el pasillo, antes que nada que los use; la
barrera antes que la expedición y la cumbre; la expedición antes que las fichas;
el shader antes que las capturas; y el coste de GPU se mide al final, con todo
pintado.

**Riesgos técnicos.**

- **Cambia la partida**: sin tarjeta de primavera y con otra forma de descubrir,
  las firmas de las sondas largas se desplazan una vez. No hay línea que conservar.
- **La frontera es una malla**, no un shader del relieve: esconderla bajo la
  niebla pide que su material lea la misma textura.
- **El trazo de costa se calcula en el shader** a partir de la cota y el mar de la
  época; en el relieve regional la costa cae entre vértices de ~111 m, y el trazo
  puede salir dentado. Se mira en la captura.
- **Las sondas que contestaban la tarjeta de primavera** (`TironAnualProbe` y
  otras) dejan de mandar expediciones solas. Si alguna cuenta con ellas, se dice.

### Cómo quedó: rumbo y niebla (2026-09-14)

**La niebla** (`NieblaRegional`, `region/`) es la rejilla del relieve regional
—1 792 × 1 280 celdas de 111 m— con dos capas: **vista**, que levanta la niebla
del mapa regional, y **recorrida**, lo que pisaron las expediciones. Se levanta
**por exceso** (toda celda que la forma toque) y sólo con
`GameState.levantar_niebla`, que **descubre los sitios cuyo punto cae dentro**: lo
que se ve se descubre, una sola regla. Dentro del paso de un campamento va a la
cola de la barrera, como lo descubierto. La levantan el recuadro de cada
campamento al empezar o darse de alta, el mapa visitado, el pasillo de cada
expedición al volver (las dos capas) y un círculo de 1 400 m alrededor de cada
cumbre coronada (`TerrainGenerator.world_to_geo`, nuevo). Se guarda en cada
fichero de campamento y se suma al cargar. Un sitio se enseña si
`GameState.se_ve`: descubierto **y** fuera de la niebla.

**El pasillo** (`Pasillo`, `sim/`) es una geometría sola para las tres preguntas
—qué se descubre, qué niebla se levanta y qué dibuja la flecha—: se anda por el
rumbo a tramos de 250 m con `Viaje.andar_un_tramo` —la misma cuenta del viaje
entre campamentos— hasta gastar las horas útiles de media salida, **parando en la
costa de la época** y en el borde del relieve, con 700 m a cada lado.

**La expedición** (`Expedicion`) sale con `mandar_a(quienes, rumbo, jornadas)`
cuando se quiera, de 4 a 24 jornadas de 2 en 2, con el coste de siempre; traza el
pasillo **al salir** —el que enseñó la flecha— y al volver descubre lo de dentro,
levanta la niebla y deja contacto con los sitios ocupados del pasillo. La primera
encuentra gente en el sitio del pasillo más lejano. **La primavera se quedó sin
decisión**: ver EPOCA_01.

**Se manda** desde el mapa regional (tecla R y un clic hacia dónde) o desde el
valle (botón **Rumbo** bajo el minimapa), con la misma `FichaDeRumbo` y una
`FlechaDeRumbo`. Cómo se ve, en [GRAFICOS.md](GRAFICOS.md) §3; las ventanas, en
[INTERFAZ.md](INTERFAZ.md) §4. **La visita** enseña en su minimapa sólo lo
recorrido por expediciones, con las cuevas de dentro
(`Campamento.ver_lo_recorrido`).

**Medido.**

- Al empezar se ven **1 482 celdas** de 2 293 760: el recuadro de 4 km.
- **Un pasillo de 12 jornadas hacia el este desde Cueva los Pendios: 130,8 km de
  ida y 11 sitios**. Con el andar de siempre salen unos **22 km por jornada** sobre
  el relieve real, así que las salidas largas llegan casi siempre a la costa o al
  borde de la comarca.
- La niebla cuesta **entre −0,02 y +0,24 ms de GPU** a 1080p en cinco corridas
  (GRAFICOS §3), dentro del presupuesto de 1 ms.

**Lo que salió al hacerlo.**

- **El pasillo cruzaba el mar** hasta el filo del mapa. Ahora se para en la costa.
- **Un punto justo en el borde de un pasillo caía en una celda sin levantar**, por
  0,3 m de descuadre entre el coseno de la celda y el de la forma: se levanta con
  un metro de holgura (`NieblaRegional.HOLGURA_M`).
- **Un guardado de antes de la niebla** traía descubiertos sin niebla, y al
  abrirlo quedaban tapados: al cargarlo se levanta el recuadro de cada uno.
- **`TestIntercambio` dependía del año global** que dejaba cambiado
  `TestDecisiones`: salió al quitar la tarjeta de primavera, y ahora fija su fecha.

**Deuda que queda, dicha.**

- **La niebla se levanta al volver**, entera: no se ve avanzar a la expedición por
  el mapa regional mientras está fuera.
- **Tras cerrar el juego, se manda desde el regional sólo con campamentos vivos**:
  hasta entrar en el mapa de la banda la tecla R dice que no hay desde dónde (la
  misma deuda de §23).
- El trazo de costa bajo la niebla sale del relieve regional a 111 m: se ve bien a
  la distancia de la captura, y de muy cerca puede dentarse.

---

> **Levantar niebla no descubre sitios** (2026-09-14). Dos quejas del usuario a
> la vez —«en una nueva partida sólo debe aparecer 1 sitio en el mapa regional» y
> «cuando el jugador visita un punto del mapa regional que ha descubierto, al
> volver le han aparecido puntos nuevos»— resultaron ser **el mismo fallo**.
> `GameState.levantar_niebla` descubría todo yacimiento que quedara bajo la forma
> levantada, bajo la regla «lo que se ve, se descubre»; y **entrar en un mapa
> levanta un recuadro alrededor** (`DemoMain`, `Campamentos`). Así que empezar
> partida descubría a los vecinos de casa, y visitar un sitio descubría los
> suyos: el mapa se regalaba solo.
>
> Ahora la niebla y el descubrimiento van por separado. Levantar niebla **sólo
> levanta niebla**; descubrir lo pide la forma con `"descubre": true`, y **la
> única que lo pide es la expedición** (`Expedicion`). **Decisión del usuario**:
> descubren las expediciones; la cumbre levanta niebla y da pistas de por dónde
> mirar, pero no regala el yacimiento. La cueva de casa se descubre al empezar,
> y punto. `TestNieblaRegional`.
>
> Una prueba pedía lo contrario y se reescribió diciéndolo: se llamaba «levantar
> descubre lo de dentro y nada de fuera» y comprobaba bien la regla de entonces.
> Lo que estaba mal era la regla.

## 5. El comercio, de la concha de lejos al mercado nacional

> **Hecho (2026-09-13)**: `Intercambio.PRECIO` —fruto seco 1, sílex 2 y
> concha 3 heredados de los tratos de antes; lo demás, decisión—, la relación
> como factor a los dos lados, `se_acepta` con el 10 % y `cambiar` exacto, con
> historial. Lo que traen los visitantes sale de la semilla y se gasta por
> estación. **La tarjeta de trueque de cada estación, y su viaje de cuatro
> jornadas, se quitaron el mismo día**: el trueque es sólo la ventana. Con ella
> se fue pedir gente a otra banda.
>
> **Spec (2026-09-13)**: el trueque pasa a ser **una ventana como la del
> almacén**, con los materiales de la banda a un lado y lo que traen los
> visitantes al otro. Cada cosa tiene un precio interno que **mueve la relación**
> con esa gente, y el trato sale si los dos lados no se separan más de un 10 %.
> Y una **ventana de relaciones** con lo que se sabe de cada banda. Criterios en
> EPOCA_01 §10.1 → Tanda 4, frentes 25 y 26.

Es una sola escalera con cuatro peldaños reales, y el primero **ya está
obligado por los datos**: `archivo/SLICE_PALEOLITICO.md` §4 dice sin rodeos que el
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

> **Construido el 2026-09-12: el trueque se decide, se paga y se recuerda.**
>
> Ya no ocurre solo. Una vez por estación, **si se conoce a alguien** —y a
> alguien se le conoce con una expedición, §4—, se propone con un `Moment` de
> tipo `TRUEQUE`. La primera opción es **no ir**, y cada opción dice lo que
> cuesta antes de elegir.
>
> Las cuatro decisiones de la spec quedan así: **con quién** lo decide la
> memoria —se trata con la gente de mejor trato—; **qué se ofrece y cuánto**
> es fruto seco, carne seca o piel, regateando, lo justo o siendo generosos;
> **qué se pide** es sílex, concha o que venga alguien a vivir; y **si se va**
> es la opción de no ir, más las cuatro jornadas que alguien pasa fuera del
> mapa salga como salga.
>
> **La memoria** es `Contacto.trato`, con la forma del `trato` de `ElLobo`:
> regatear lo baja, ser generosos lo sube, y la probabilidad de que salga bien
> parte del 0,55 heredado y se mueve con él. **Se lee antes de moverlo**, porque
> lo que la otra gente recuerda es lo de las veces anteriores.
>
> Medido en la prueba: 0,950 siendo generosos contra 0,080 regateando, **en
> trescientos intentos seguidos, que llevan el trato a sus topes** — en una
> partida se trata unas cuatro veces al año y la diferencia será menor. La
> magnitud jugada se mide con el año corriendo (M1).

**El campaniforme del Calcolítico** (EPOCAS.md, "un recipiente que se
enseña, no que se usa") y **el ajuar desigual del Bronce** son la misma
mecánica de comercio vista desde el prestigio en vez de desde la necesidad:
el sistema no necesita distinguir "trueque de subsistencia" de "trueque de
estatus" en el código, sólo en qué materiales mueve cada ruta.

> **Spec (2026-09-12), de `/epoca 1` y `/spec`.** El primer peldaño **ya está
> construido y es demasiado poco**: `Intercambio.gd` ofrece `FRUTO_SECO` 6,0,
> pide `SILEX` 3,0, acierta el 55 % de las veces, se intenta solo una vez por
> estación y **el jugador no decide nada ni se entera**. Lo que falta es
> convertirlo en decisión, y son cuatro:
>
> - **con quién**, y eso tiene memoria — la contraparte recuerda si fuiste
>   generoso o si regateaste, igual que `ElLobo.trato`, y el 55 % fijo deja de
>   ser fijo;
> - **qué se ofrece y cuánto** — hoy está clavado en fruto seco porque es lo
>   que sobra (ESTADO.md §2); desprenderse de lo que **no** sobra tiene que
>   doler en invierno;
> - **qué se pide** — sílex, concha (el hito "la concha de lejos"), o gente,
>   que es como funcionaban de verdad las redes paleolíticas;
> - **si se va** — el trueque deja de ocurrir solo: hay que mandar a alguien, y
>   esas jornadas no se recolectan.
>
> La memoria de la contraparte es lo que hace que este peldaño escale a los
> otros tres de la tabla sin rehacerse: una ruta fiable del Bronce y una lonja
> con fuero son la misma relación con más historia detrás.
>
> **Cómo se sabe que está hecho** (criterios completos en §10.1, tanda 2, frente
> 6): en un año simulado sin que el jugador decida nada, **cero** intercambios
> consumados —hoy ocurren solos—; dos corridas con la misma semilla, una siendo
> generoso y otra regateando, dan tasas de éxito **distintas**, con lo que el 55 %
> fijo deja de ser fijo; ofrecer lo que no sobra se nota en la despensa de las
> jornadas siguientes; las jornadas del que va no se recolectan; y se puede pedir
> sílex, concha o gente, con las tres llegando. **Depende de §4**: sin contacto no
> hay «con quién», y sin «con quién» no hay memoria que recordar.

---

## 6. Los tres hitos que se sufren

El bosque cierra el valle (1) · la legión en el collado (6) · el Estado se
va (7). Los tres comparten forma: el jugador no los dispara, y el juego no
debe ofrecer ganarlos.

Eran cuatro. El cuarto era la guerra de 1937, y se fue con el siglo corto.
**Esto simplifica el sistema**, y conviene apuntarlo: era el único que iba
por fecha de calendario absoluta en vez de por condición de estado, así que
`Hitos` ya no necesita dos caminos de disparo distintos. Los tres que quedan
son condiciones de contexto, todas de la misma forma.

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
general de los tres hitos que se sufren: al disparar, cada obra
(`CampProjects`, y sus equivalentes de época posterior) comprueba si su
`requires` seguía dependiendo de la institución que se va —el molino
hidráulico no necesita el Estado para seguir moliendo, la ferrería de monte
sí necesita comercio para tener metal— y se apaga sólo la que de verdad
dependía de lo perdido.

---

## 7. El asentamiento cambia de escala, no sólo de nombre

`Settlement`/`SettlementSim` es hoy una banda de unas quince personas en un
abrigo. La unidad de juego cambia de forma a lo largo de las once épocas
exactamente en los puntos que marca la "cuarta regla" de EPOCAS.md §3 —quién
decide—, y son cambios de **quién es la unidad**, no sólo de cuántos:

banda (1–2) → aldea/poblado (3–5) → castro (6) → ciudad bajo el Estado (7) →
valle con concejo (8) → villa con fuero (9–10) → **cuenca industrial (11)**.

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
que exista, este documento y las once fichas de época son la única
enciclopedia que hay, y por eso llevan la etiqueta en cada afirmación en vez
de darla por sentada.

**El método cambia en la época 11**, y su ficha lo dice porque importa: hasta
la Edad Media todo se apoya en cultura material excavada; desde la Edad
Moderna, en archivo; en el XIX, en archivo y prensa. No es peor fuente, es
otra, y conviene no mezclarlas bajo la misma etiqueta.

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

---

# Construido y funcionando

Lo que sigue **no es diseño de destino: es cómo se comporta el juego hoy**.
Los tres sistemas que dan de comer —la caza, la pesca y la despensa— eran tablas
de rendimiento: se ponía gente en un oficio, corrían las horas y aparecían
números en el almacén. Los ciervos que `WildlifeHerds` pinta cruzando el valle
no tenían nada que ver con la carne que llegaba. Hoy sí.

Las cifras de rendimiento de cada uno, y si están bien calibradas, en
[ESTADO.md](ESTADO.md).

---

## 10. La despensa: lo que se pudre y lo que se salva

> **Lo que se pierde HOY es el paso de la edad de ayer a la de hoy** (arreglado
> el 2026-09-13). `Storehouse.age` calculaba la fracción podrida de la edad
> ENTERA —cero hasta la mitad de la vida, y de ahí a uno al final— y se la
> aplicaba **a lo que quedaba, cada día**. Eso se acumula: pasada la mitad de
> vida, el pescado seco perdía un 1 %, un 2 %, un 3 %… de lo que le quedaba, y
> en quince días se iba el 70 %. El usuario lo vio en el día 123 —«he perdido
> 2 000 raciones de pescado seco en pocos días»— y tenía razón: no le había
> dado tiempo a pudrirse. Ahora `age` divide lo que queda a la edad de hoy
> entre lo que quedaba a la de ayer, así que envejecer día a día pierde
> exactamente lo mismo que envejecer de una vez, que es lo que la regla decía.
> Lo defiende `TestStorehouse.test_envejecer_dia_a_dia_pierde_lo_mismo_que_de_una_vez`.
>
> **Y la grasa ya no es comida** (decisión del usuario, 2026-09-13): «no quiero
> que se coman la grasa, quiero que la utilicen sólo como material». Es la
> lámpara de explorar cuevas, el curtido y el aglutinante de la pintura, y con
> la grasa contando como ración no quedaba para ninguna de las tres —que es la
> razón de fondo de que no se curtiera ni una piel—. `Materia.Kind.GRASA` tiene
> `kcal: 0` y sale de `LO_QUE_AGUANTA_EL_VIAJE`.
>
> **El almacén arranca con topes** (decisión del usuario, misma tarde): 50 de
> cada material, 100 de leña y 10 de cada pieza de utillaje
> (`SettlementSim.TOPE_DE_MATERIAL`, `TOPE_DE_LENA`, `TOPE_DE_UTILLAJE`,
> puestos en `setup`). Sin ellos, «en unos cuantos días se llena de morralla».
> La comida no lleva tope de material: tiene el suyo, el de la despensa. Y el
> número del utillaje pasó de ser un ENCARGO a ser un TOPE: el taller hace lo
> que pide el trabajo y nunca más de ese número.

`Storehouse.age` aplica la podredumbre desde siempre, y **no se veía**. Desde
fuera, un montón que no crece porque nadie lo trae y uno que no crece porque se
pudre se leen exactamente igual, y no son lo mismo: el primero se arregla
mandando gente y el segundo, no.

Se cuenta todos los días, con nombre, cantidad **y motivo**:

> Se echó a perder 12,4 de pescado y 3,1 de carne. Sin secadero no hay forma de
> guardarlo.

**Esa segunda frase es la mitad del parte.** Un aviso que sólo dice cuánto se ha
perdido deja al jugador sin nada que hacer con el dato; lo que lo convierte en
una decisión es saber qué le falta. El peso en la crónica sale de la cantidad:
una merma normal es rutina y se olvida, perder la despensa no.

**El ahumado es automático**, y es lo que es un secadero: un bastidor sobre las
brasas. La carne se cuelga por la mañana y el humo trabaja solo. Pide tres
cosas, y cada una falla distinto:

- sin bastidor no hay dónde colgar,
- sin brasas no hay humo,
- **y sin nadie en `Job.HOGAR` el fuego se aviva mal y la carne se ahúma de un
  lado**. Ésa es la supervisión, y es lo que hace que dejar el oficio de hogar
  vacío se pague en la despensa y no sólo en el fuego.

Cuánto se cura sale de **cuántos** supervisan y de lo que saben, no de cuántas
horas le echan: el bastidor tiene el tamaño que tiene, y una segunda persona al
hogar es una segunda tanda colgada, no la misma vigilada el doble.

**Y lo que limita la despensa es en qué se guarda**, no un número. Ver
[SPECS.md](SPECS.md) §4.5.

---

## 11. La caza

### La puerta del arma

Cada especie de `Fauna` declara con qué se le puede entrar:

| | arma | por qué |
|---|---|---|
| Conejo, liebre, perdiz, ánade, urogallo | — | Lazo y palo. Es la comida del primer día |
| Corzo, rebeco | azagaya **o** punta | Una lanza de mano basta, y es muchísimo más vieja que la azagaya de asta |
| Lobo | azagaya | La única pieza MENOR que no admite lanza: a un lobo no se le espera a corta distancia |
| Ciervo, jabalí, caballo, uro | azagaya | A mil kilos no se le entra con un palo endurecido |

> **Y la especialidad pide lo mismo que la pieza (2026-09-12, `/depurar`).**
> `SettlementSim.SPECIALITY_TOOL` exigía **azagaya** para la caza menor mientras
> esta tabla decía que al corzo y al rebeco se les entra con lanza de mano. No
> era una discrepancia de adorno: cerraba un bucle: el tendón para aprender la
> azagaya sale de la caza, y la caza menor pedía la azagaya que no se podía
> aprender. Gana la tabla, que es la que describe la pieza. La caza **mayor**
> sigue pidiendo azagaya.

Tres decisiones que conviene tener escritas:

- **Es un FILTRO, no una penalización.** Media pieza de uro sin azagaya no es
  media pieza: es una cuadrilla que vuelve corriendo. Lo que no se puede cobrar
  desaparece de la lista de lo que hay en ese sitio, así que la valoración del
  coto cae sola y la cuadrilla se va a donde sí puede cobrar algo.
- **Lo que no se caza tampoco cuesta.** `risk_at` mira la misma puerta: sin
  azagaya no se le entra al uro, así que tampoco se corre su riesgo. Antes una
  banda desarmada se llevaba las cornadas de una caza que no estaba haciendo.
- **La trampa se la salta, y ÉSA es su razón de ser.** Un foso coge un jabalí
  sin que nadie le tenga que entrar. Si el foso pidiera azagaya no serviría para
  nada.

**Y se dice.** Cerrar la puerta en silencio es la peor versión de sí misma: una
cuadrilla que vuelve de vacío de un cotarro lleno de ciervos se ve, desde fuera,
igual que una que fue a un sitio pelado.

### Las fases

La caza que no es sorpresiva se ve. La trampa se queda como estaba, y no es un
olvido: **una trampa es lo sorpresivo**, cae sola mientras la banda duerme y no
hay acecho que mirar.

1. **Rastreo.** La mayor parte del día. Se bate el monte y no se cobra nada,
   porque cazar es sobre todo no encontrar.
2. **Acecho.** Se anda hasta tenerla a noventa metros y desde ahí se acecha, a
   algo más de medio paso: nadie cruza dos kilómetros agachado. Cada rato hay
   riesgo de que la pieza levante la cabeza, y sube al acercarse. El ojeo lo
   tapa: batir con un plan es literalmente que la pieza no sepa por dónde le
   viene.
3. **Persecución.** Ya ha arrancado. Se pierden muchas, y lo que decide no es el
   fondo del cazador: es que el monte se la traga.
4. **Lance.** Una tirada. Llegar a tiro sin que te vean la mejora mucho —una
   pieza parada y de costado no es la misma que una que ya corre— y la cuadrilla
   también.
5. **Despiece o acarreo**, según el tamaño.

Dos reglas de cuadrilla: **rodea UNA pieza, no cuatro** —quien llega a un coto
con una batida en marcha se suma a ella— y **la caza menor no se suma**, que se
hace al acecho, solo o de a dos.

**El tiempo no se inventó de cero.** Lo que gobierna cuántas piezas cobra una
jornada sigue siendo `Hunting.pieces_per_day`, que está medido. Lo que hace la
cacería visible es **gastar esas horas donde se ven** en vez de hacerlas
desaparecer en una multiplicación: si una jornada perfecta cobra `p` piezas,
cada pieza cuesta `HORAS_UTILES / p` horas de jornada perfecta, y lo que la
persona tenga de menos alarga ese rastreo en la misma proporción en la que antes
reducía el rendimiento.

### ¿Se lleva la pieza a casa o se abre donde cae?

**Las dos cosas, según el tamaño**, y no es una comodidad de código: es el efecto
*schlepp*, de lo mejor documentado que hay en zooarqueología. En los abrigos
aparecen esqueletos casi completos de pieza pequeña y perfiles sesgados a las
partes buenas de la grande, porque lo pequeño se echa al hombro y lo grande se
abre donde cae.

- Por debajo de veinte raciones —un corzo— la pieza se lleva entera.
- Por encima se abre en el sitio, y eso cuesta tiempo **y filo**. Sin lasca no
  es que se tarde más: es que no se pasa del cuero, y lo que se aprovecha de la
  piel y el tendón se cae.
- **Lo que no cabe en una espalda se queda en el monte.** Un uro son varios
  viajes, y hay tres jornadas para volver a por lo que quedó: después se pierde,
  y no sólo porque se pudra — hay lobos, y una res abierta se anuncia sola.

Volver a por una espalda de ciervo rinde más que salir a por otra pieza, así que
el cazador que sale por la mañana va primero a lo que dejó abierto.

---

## 12. La pesca

> **Un tramo en descanso no se pesca, llegue quien llegue** (2026-09-13). El
> barbecho existía y saltaba —`Barbecho.revisar`—, pero no impedía pescar: la
> lista de sitios adonde mandar a alguien (`SettlementSim._work_candidates`)
> añadía detrás del mejor **todos** los sitios conocidos del oficio y el de
> reserva de la fundación sin mirar si descansaban, así que en cuanto el bueno
> no tenía camino el pescador acababa en el tramo en descanso y allí `Tajo` le
> sacaba los peces a la celda más rica a 80 m. Ahora la lista se filtra, y
> además `Tajo.celda_trabajada` no da celda en un paraje en descanso: el que
> pasa por allí buscando o tanteando tampoco saca nada.
>
> **Y la pesca descansa antes y vuelve más tarde que lo demás**: por debajo del
> **30 %** se deja en barbecho y no se vuelve hasta el **90 %**
> (`Barbecho.PESCA_ESQUILMADA` y `PESCA_REPUESTA`, decisión del usuario). El
> resto de oficios sigue en el 20 % / 55 %: un río se vacía por tramos y tarda
> más en llenarse que un avellanar.
>
> **Y cada primavera, el remonte** (`ResourceField.remonte`, 2026-09-14,
> decisión del usuario). Con el rebrote común —0,045 al día, logístico— un remanso
> vaciado en primavera tardaba **unas 130 jornadas** en volver al 90 %: casi el
> año entero en barbecho. El usuario lo vio así: «el paraje está con peces, al
> rato el marcador se apaga y cuando miro sólo tiene cuarcita». Ahora al entrar la
> primavera todo tramo con río vuelve lleno —el salmón que sube el Deva y el
> Nansa, que es lo que ya contaba `seasonal_factor`—, y el barbecho lo devuelve
> al cerrar esa jornada. Lo secado por `dry_cell` no remonta: no tiene río.
>
> **La ficha no se calla el pescado de un remanso esquilmado**
> (`Paraje.fill_contents`). Por debajo del umbral se saltaba la actividad entera
> y quedaba la piedra de la orilla por toda ficha; ahora lo que nombra el sitio
> sigue en la lista con lo que quede, si está en temporada.

**Una nasa no es un peldaño de una escalera de rendimiento: es un objeto que se
queda en el río.** Tenerla en la escalera junto al arpón y el sedal significaba
que una banda con nasas y sin arpón se pasaba el día de pie en la orilla con una
cesta, y una con arpón no calaba ninguna.

`Fishing.ACTIVAS` son las jornadas en el agua —mano, pesquera, sedal, red,
arpón— y **la nasa está fuera**. El pescador que sabe hacerlas revisa la línea
por la mañana y luego pesca con lo mejor que tenga.

- La nasa **es** la pieza del utillaje (`Tool.Kind.NASA`). Al calarla sale del
  abrigo y se queda en el agua gastándose; el día que se pudre se pierde.
- **Cebo.** Una nasa sin cebar sigue cogiendo lo que se mete a refugiarse —una
  anguila se mete en cualquier agujero— pero mucho menos. Ponerlo a cero
  convertiría el cebo en un interruptor y la nasa en una pieza inútil el día que
  se acaban los caracoles.
- Lo que cobra se acumula **pesado por lo que valía cada día**, no resuelto
  mirando cómo está hoy: una nasa que estuvo cuatro días cebada y cuatro sin
  cebo no se paga entera a precio de mala ni entera a precio de buena.
- Y se ve en la orilla, con su cesto medio hundido y ladeado hacia el cauce
  (`NasaMarkers`).

---

> **Lo que está en el agua se nombra por el agua** (2026-09-14). Queja del
> usuario: la ventana de técnicas ponía nasas en «la veta de ocre» o «la veta de
> sílex». La nasa se cala donde pesca el pescador —junto al agua, `Nasas._room_for_nasa`—
> y eso no siempre cae en un paraje de pesca; cuando no había ninguno a menos de
> `Parajes.MERGE_RANGE` (320 m), el nombre caía en el paraje más cercano **de
> cualquier clase**. Ahora, sin paraje de agua al alcance, se nombra por la orilla
> —«la orilla al norte del abrigo, a 900 m»—. **Decisión del usuario**: «donde
> pesca, pero bien nombrada». `TestParajes`.

## 13. Lo que se cuenta, y lo que se pinta

> **Mudarse de cueva (2026-09-13)**: `Traslado`. Sólo a una cueva a la que se
> llegue andando; cada cual carga hasta su capacidad —comida primero— y el resto
> se queda en la cueva vieja; la banda entera anda hasta allí sin trabajar; y al
> llegar, las obras son las del sitio, ninguna si es nuevo. Volver devuelve lo
> que se dejó y las obras que había. Medido en ROADMAP, «Tras la tanda 4».
>
> **Hecho (2026-09-13)**: explorar y pintar ya van así —`Exploracion`,
> `Repertorio` y `Pinturas`—, con lo medido en ROADMAP, tanda 4, E1 a P1. La
> lámpara es el útil `Tool.Kind.LAMPARA`, el mismo para las dos cosas.
>
> **Spec (2026-09-13)**: **sólo se pinta lo explorado, y donde se puede.**
> Explorar una cueva pide lámpara, grasa y una jornada de alguien del hogar, y
> trae dos o tres decisiones de un repertorio de al menos treinta, con riesgo de
> verdad. Al acabar se sabe si tiene zona pintable: una de cada tres, y la de la
> banda siempre. Y **la sepultura** entra: una decisión al morir alguien, que
> queda en el relato, en el mapa y, la primera con ajuar, como hito. Criterios en
> EPOCA_01 §10.1 → Tanda 4, frentes 22, 23 y 27.

La mitad existía y no se veía: `_knowledge_transmission` acerca cada noche a los
que duermen en la cueva a lo que sabe el mejor de ellos, y eso **es** contar la
cacería junto al fuego. Lo que faltaba era enseñárselo al jugador y, sobre todo,
**la diferencia entre contarlo y pintarlo**.

- El relato se **arma donde pasa** —al cobrar la pieza, que es donde están los
  hechos— y se **cuenta al llegar**, que es cuando hay quien lo oiga.
- **Sólo la pieza mayor.** En el Paleolítico una gran caza no era algo diario;
  contar cada conejo del lazo convertiría el relato en ruido.
- **El cómo importa más que el qué**, que es lo que lo hace un relato y no una
  entrada de almacén. No es lo mismo llegar a tiro sin que te vean que reventar
  el monte detrás de la pieza hasta acorralarla.

### Pintar, y por qué cambia la partida

Contado, un relato dura lo que dure quien estuvo. Pintado, no. Es lo que dice
`TechTree.Tech.ARTE` con todas las letras: *«fijar lo que se sabe de los animales
y transmitirlo a quien no estaba: es la primera tecnología de la memoria»*.

**Efecto:** cada relato pintado sube el techo de lo que se puede aprender de
oídas sobre esa tarea. La transmisión nocturna está topada en el **75 %** de lo
que sabe el mejor presente, porque contar no es hacer; con la pared, ese techo
sube **seis puntos por escena** y se para en el **95 %**. Nunca llega al 100 y
no debe: una parte de lo que sabe un cazador es la mano, y eso no se aprende
mirando una pared. Lo que la pared hace es que **no haya que empezar de cero
cada vez que se muere el que sabía**.

Una escena de caza mayor enseña a cazar pieza mayor, no a trenzar cordel. La
excepción es el relato de una técnica, que no tiene especialidad y cubre el
oficio entero.

**Qué cuesta:** saber pintar (`Tech.ARTE`, que ya pedía hogar levantado), ocre,
grasa, dos jornadas de alguien del hogar y una **lámpara** (`Tool.Kind.LAMPARA`,
un canto ahuecado con grasa y una mecha — la de Lascaux es literalmente eso).
Es de las poquísimas piezas cuyo rendimiento sin ella es **cero**: a oscuras no
se pinta ni despacio ni deprisa. **El taller pide UNA lámpara desde el primer
día** (`Taller.tool_natural_demand`). Hasta el 2026-09-14 la pedía sólo al saber
pintar —«nadie ahueca un canto para tener luz dentro de la cueva antes de tener
algo que hacer dentro»—, pero desde la tanda 4 **explorar** también la pide, y
eso se hace desde el principio: con la demanda a cero la talla no hacía ninguna y
no se podía explorar. Queja del usuario: «no me está haciendo lámparas». Era la
misma regla escrita en dos sitios con dos respuestas.

> **Y la talla que «se salta» a veces no es un fallo.** La meta del utillaje es
> un tope, no un encargo (decisión del usuario del 2026-09-13): cuando lo que
> pide el trabajo está cubierto, el tallador sólo practica si queda técnica que
> aprender y hay piedra. Tener menos piezas que la meta no le da trabajo.

**Lo que NO levanta relato**, y por qué: el bautizo de un paraje. Un relato es un
`Moment`, o sea el reloj parado, y si cada sitio con nombre parara la partida a
preguntar si se pinta, en dos estaciones el jugador aprendería a cerrar la
tarjeta sin leerla. **Se pinta lo que pasa pocas veces**: una caza mayor, una
cumbre, una técnica.

---

### Spec (2026-09-15): la pared que se ve, y lo que otros pintaron antes

**El problema.** Pintar hoy es un dato: el relato pasa a la lista de pintados, la
crónica dice «está en la pared del fondo» y el techo de aprendizaje sube. **No hay
pared.** Nadie la ha visto nunca, y por eso no hay razón de juego ni de curiosidad
para mirar dentro de una cueva: explorar una dice «tiene zona pintable» y ahí se
acaba. Y el mapa tiene **cuevas reales con arte paleolítico documentado** —de las
más importantes de Europa— que en el juego son un alfiler como cualquier otro.

La petición del usuario: un sistema de pintar al fondo de la cueva **con
visualización**, y algo de lore que dé sentido a entrar a mirar las cuevas y ver
las pinturas.

**Lo decidido, a preguntas del usuario:**

1. **Se entra en la cueva, en 3D.** Una sala donde está **la pared del fondo** y
   se mira con la cámara, a la luz de la lámpara. No es una ventana con un dibujo
   encima: es un sitio en el que se entra.
2. **La pared es roca con su relieve**, y **la pintura tiene su sitio**: se sabe
   que en el Paleolítico se aprovechaban las formas de la roca —un abombamiento
   para el vientre de un bisonte, una grieta para el lomo, una repisa para el
   suelo— y así se pinta aquí. **La figura no la coloca el jugador ni cae en un
   hueco cualquiera**: va donde la roca la recalca, y usa el relieve para
   recalcarse.
3. **Arte parietal desbloquea pintar, y pintar lo de antes.** Los relatos se
   guardan desde el primer día —cacerías grandes, hallazgos, técnicas—, sepa o no
   la banda pintar. Al aprender la técnica, **lo vivido antes de saber pintar se
   puede pintar también**, no sólo lo que pase después.
4. **En las cuevas con arte documentado se ve el arte real**: las ciervas de
   Covalanas, las manos de El Castillo, los bisontes de Altamira. Cada panel lleva
   un texto corto sobre **los que estuvieron antes**, fiel a lo documentado —qué
   hay y de cuándo es— y con sus fuentes en CREDITOS.
5. **Mirar pinturas ajenas es relato y lore, sin efecto de juego.** Entra en la
   crónica y en lo que la banda cuenta; no sube techos, no enseña técnicas ni da
   motivos nuevos.
6. **Los motivos se dibujan a mano, calcados en vectorial** a partir de
   referencias publicadas, con el trazo y la paleta del Paleolítico cantábrico
   —ocre rojo, carbón negro, ocre amarillo—, y cada uno cita su referencia en
   CREDITOS.

**Entrar a mirar no pide la técnica** —confirmado por el usuario al planear,
2026-09-15—: cualquier cueva explorada tiene sala. Sin la técnica, la de la banda
está vacía y las ajenas enseñan su arte y su lore.

**Y dos decisiones más del usuario al planear (2026-09-15):**

- **Lo que no es caza se pinta con signos y manos**: los hallazgos con signos
  —puntos, escaleriformes—, las técnicas con signos tectiformes o claviformes, y
  la primera vez de algo importante con una mano en negativo. La caza mayor lleva
  su animal.
- **Con la pared llena se pinta encima**, como en las cuevas reales —La Pasiega
  está llena de figuras superpuestas—: cuando no queda sitio que recalque bien, la
  figura nueva va sobre la más antigua **de la banda**, nunca sobre una
  documentada. No hay tope.

#### Criterios de aceptación

**La sala**

- De una cueva **explorada** se puede entrar a su sala, desde el mapa de la banda
  y desde el alfiler de un sitio visitado. De una sin explorar no, y la ficha dice
  por qué. Prueba.
- **Todo relato pintado en esa cueva está en su pared**, y nada más: el número de
  figuras propias de la sala es el de relatos pintados allí. Prueba sobre una
  pared con cinco pintados.
- **Entrar y salir no cuesta como ir al mapa regional**: ni la entrada ni la salida
  tardan más de **2 s** en el sitio 56, medido como `TransitoProbe` (ESTADO §2 dice
  por qué importa: hoy la vuelta al mapa de la banda son 18 s). Si la sala no puede
  cumplirlo sin arreglar antes esa vuelta, se dice al planear.
- **Cabe en el fotograma**: en Medio y a 1080p, la sala no cuesta más GPU que la
  vista del valle en ese mismo nivel (18,1 ms en el equipo de medida, GRAFICOS §7),
  con `GpuProfile`, dos corridas.
- Mientras se mira dentro, **la partida sigue o se pausa como con cualquier otra
  ventana**, sin regla nueva. Prueba.

**La pared y el sitio de cada figura**

- **La figura va donde la roca la recalca**, y se mide: para cada figura puesta, el
  ajuste entre su contorno y el relieve de la pared en su sitio es **mejor que el
  del 90 % de los sitios tomados al azar donde podía ir** —libres de otras
  figuras— en la misma zona pintable. Sonda sobre una pared con al menos veinte
  figuras.
  > *Decía «de los sitios tomados al azar», sin más, hasta el 2026-09-15.* Al
  > medirlo, con la pared ya llena la figura quince se comparaba con huecos
  > ocupados por otras catorce: salía al 88 % contra cualquier sitio y al 99 % contra
  > los libres. **Decisión del usuario**: vale contra los libres, que es la pregunta
  > de verdad —si eligió el mejor hueco disponible—.
- **La misma partida pone las mismas figuras en los mismos sitios**: con la misma
  semilla y los mismos relatos, dos corridas dan la misma pared. Prueba.
- **Una figura nueva nunca va encima de una figura documentada** de una cueva con
  arte real. Prueba.

**Pintar lo de antes**

- Un relato del día 10, con la técnica aprendida el día 50, **se puede encargar el
  día 51** y acaba en la pared con la fecha de lo que cuenta, no la del día en que
  se pintó. Prueba.
- La lista de lo que se puede pintar **incluye lo anterior a la técnica** y dice de
  cuándo es cada cosa. Prueba de la ventana.
- **Sin la técnica no se encarga nada**, ni antiguo ni nuevo, y la ventana dice
  por qué. Prueba.

**Los motivos**

- **Todo relato pintable tiene su motivo**: cada especie que se caza como pieza
  mayor, cada clase de hallazgo y cada técnica pintable tienen un dibujo propio.
  **Ninguno cae en un motivo genérico de relleno.** Prueba que recorre las especies
  y los tipos de relato del juego.
- **Cada motivo cita su referencia** en CREDITOS: la figura o el panel real del que
  se calcó y dónde está publicado. Prueba que cruza el catálogo con CREDITOS.

**El arte de los que estuvieron antes**

- **Cada cueva del mapa con arte parietal paleolítico documentado tiene su panel**.
  La lista se saca de fuentes, no de memoria, y se escribe en EPOCA_01 §12 con la
  fuente de cada una; como punto de partida, las cuevas cántabras del bien «Cueva
  de Altamira y arte rupestre paleolítico del norte de España» de la UNESCO que
  estén en el conjunto de sitios. Prueba: toda cueva de esa lista tiene panel, y
  ninguna cueva sin arte documentado lo tiene.
- **Cada panel dice lo que hay y de cuándo es**, sin inventar: qué motivos, qué
  técnica y la cronología publicada. Si la cronología está discutida, lo dice. Y si
  el panel es **anterior** a la banda —las manos de El Castillo lo son por muchos
  miles de años—, el texto lo cuenta así: es exactamente el lore que se pide.
- **La primera vez que la banda entra** en una cueva con arte, el texto del panel
  entra en la crónica y en lo que la banda cuenta; **al volver a entrar, no se
  repite**. Prueba.
- **Mirarlo no cambia nada más**: ni techos de aprendizaje, ni técnicas, ni
  motivos. Prueba de que el estado de la banda es el mismo antes y después, salvo
  la crónica y el relato.

#### Fuera de alcance

- **Que mirar pinturas ajenas tenga efecto de juego.** Decisión del usuario.
- **Reproducir los paneles reales tal cual**: son calcos interpretados de
  referencias —qué motivos hay, con qué técnica, en qué disposición—, no réplicas.
- **Pintar a mano**, elegir el sitio de una figura o moverla.
- **Ver la pintura mientras se está pintando**, a medias: la figura aparece al
  terminar.
- **El grabado**, el arte mueble —plaquetas, propulsores decorados— y el arte de
  otras épocas (el levantino, el esquemático).
- **Recorrer la cueva entera**: la sala es la pared del fondo, no las galerías.
  Explorar sigue siendo lo que es hoy (§13 y EPOCA_01, frente 22).
- **Cambiar lo que la pintura propia hace en la partida**: el techo de aprendizaje
  sigue como está arriba.

#### Plan técnico (2026-09-15)

**Lo que hay, comprobado en el código antes de planear.**

- **Pintar sólo pasa en la cueva de la banda** (`Exploracion.cueva_de_la_banda`),
  y lo pintado es `SettlementSim.paintings`, una lista de `Tale` **sin cueva ni
  sitio**. Si la banda se muda (`Traslado`), las pinturas viejas se verían en la
  cueva nueva: hay que atarlas a la suya.
- **Una cueva es un elemento del mapa local**, identificado por su índice en el
  catálogo del sitio (`CaveMouth.id`), con nombre y **lat/lon** de
  OpenStreetMap. Lo explorado y lo pintable vive en cada campamento
  (`Exploracion._sabido`).
- **Las diez cuevas cántabras del bien de la UNESCO están en los datos**: Altamira,
  El Castillo, Las Monedas, Las Chimeneas, La Pasiega, El Pendo, La Garma, Chufín,
  Covalanas y Hornos de la Peña. Unas son sitio regional (ids 1, 6, 7, 8, 15, 16 y
  17) y **todas son elemento de algún mapa local**: El Castillo, Las Monedas y Las
  Chimeneas están dentro del de La Pasiega. Algunas salen repetidas con nombres
  casi iguales, así que **se reconocen por coordenadas y no por nombre**.
- **Los relatos y las pinturas se guardan solos**: `Instantanea` guarda por
  reflexión toda variable de la simulación. Un campo nuevo en `Tale` se guarda
  sin tocar el guardado, y una partida vieja lo trae a su valor por defecto.
- **Pintar ya se encarga desde el momento del relato**, con el botón «pintarlo»,
  y la pared se lista en la ventana de Técnicas (`PanelTecnicas`, bloque del
  hogar). No hay forma de encargar un relato viejo.
- **Los relatos pintables son los que tienen tarea**: la caza mayor —ciervo,
  jabalí, caballo, uro—, los hallazgos con tarea (la cumbre coronada) y las
  técnicas.

**Módulos.**

| Qué | Dónde | Contrato |
|---|---|---|
| **Los motivos**: cada figura como polígonos en coordenadas de la figura, con su color, su técnica (tinta plana, contorno, puntos, mano en negativo) y la referencia de la que se calcó | nuevo, `scripts/datos/Motivos.gd` | SPECS §4.1: datos puros, **constantes en código y no un `.tres`**, porque la pared se calcula dentro del paso de campamentos fuera del árbol (§3.1) y cargar recursos desde ahí no es seguro |
| **El arte de los que estuvieron antes**: las diez cuevas con su lat/lon, sus paneles —qué motivos, cuántos, técnica—, la cronología publicada y la fuente | nuevo, `scripts/datos/ArteDeLosDeAntes.gd` | §4.1 |
| **La pared**: el relieve de una zona pintable a partir de la semilla de la partida, el sitio y la cueva; la medida de cuánto recalca la roca una figura en un sitio; y la colocación, voraz y en orden —primero lo documentado, después lo pintado por la banda por fecha de pintado— | nuevo, `scripts/sim/ParedDeLaCueva.gd` | §4.4, puro y sin nodos. **Azar con su propio generador sembrado, no el `_rng` de la simulación** (§7), como `Exploracion.hay_zona_pintable` |
| **La figura en su sitio**: `Tale` gana la cueva donde se pintó y su sitio en la pared (posición, escala, giro) | `scripts/banda/Tale.gd` | se guarda solo |
| **Pintar**: al terminar, la figura se coloca y queda en el relato; la lista de lo que se puede pintar, incluidos los relatos de antes de la técnica | `scripts/sim/Pinturas.gd` | §4.4 |
| **Lo que se ve al entrar por primera vez**: el texto del panel a la crónica y a los relatos, **sin tarea**, así que no es pintable ni sube ningún techo; y qué cuevas ha mirado ya este campamento | `Pinturas.gd` | §4.4 |
| **La sala**: un `SubViewport` con **su propio `World3D`** encima de la escena, con la malla de la pared, la luz de la lámpara y las figuras | nuevo, `scripts/vista/SalaDeLaCueva.gd` y `shaders/pared_pintada.gdshader` | §4.7: lee la simulación, no la cambia |
| **Entrar y salir**: el botón en la ficha de la cueva del mapa de la banda y en la del sitio del mapa regional, con el motivo cuando no se puede | `scripts/ui/GameUI.gd` y la ficha del sitio de `RegionMap` | §4.7 |
| **Pintar lo de antes**, en la ventana de Técnicas | `scripts/ui/PanelTecnicas.gd` | §4.7 |

**Decisiones de arquitectura, sólo las que la spec obliga a tomar.**

1. **La sala NO es un cambio de escena.** La spec pide entrar y salir en menos de
   2 s, y cambiar de escena cuesta hoy 18 s de vuelta (ESTADO §2). Es una capa
   encima de lo que haya, con su mundo 3D propio: así **ni el sol, ni la niebla,
   ni el cielo del valle entran en la cueva**, y al salir no hay nada que
   reconstruir.
2. **La figura se coloca al terminar de pintarla y se guarda en el relato**, no se
   recalcula al entrar. «La pintura tiene su sitio»: si mañana cambia cómo se mide
   el ajuste, lo ya pintado no se mueve. Lo documentado sí se coloca al entrar,
   porque es de los datos y siempre sale igual.
3. **La colocación es de la simulación y la pared también**, aunque la pared sea
   algo que se ve: el sitio de cada figura es un hecho de la partida, y lo decide
   el paso, no la vista. La vista sólo dibuja la misma pared con más detalle.
4. **Cuánto recalca la roca una figura, medido así**: el relieve abombado dentro
   del cuerpo —convexidad media bajo la silueta— más cómo sigue el contorno a las
   crestas y grietas —alineación del contorno con el gradiente—, con escala y
   giro dentro de un margen. **El criterio de la spec (mejor que el 90 % de los
   sitios al azar) se mide con esta misma cuenta**, así que por construcción
   sale; lo que de verdad hay que mirar es que la cuenta sea la buena, y eso se
   ve en las capturas.
5. **Las cuevas con arte se reconocen por coordenadas**: un elemento del mapa local
   a menos de 150 m de una cueva de `ArteDeLosDeAntes`.
6. **Lo pintado antes de este cambio** —relatos con la cueva a su valor por
   defecto— se da por pintado en la cueva de la banda, y se coloca la primera vez
   que se entra.

**Orden de dependencias.** Los motivos y el arte documentado, antes que la pared
(que coloca motivos); la pared, antes que pintar con sitio y que la sala; la sala,
antes que entrar y salir; y todo, antes de medir.

**Riesgos técnicos.**

- **Dibujar los motivos es el trabajo más incierto.** Se calcan en vectorial a
  partir de referencias publicadas —calcos de Breuil y de las monografías, fotos
  de los paneles—, y la calidad depende de poder **ver** esas referencias al
  trazar. Si una referencia no se puede consultar, el motivo se para y se dice; no
  se dibuja de memoria como si fuera un calco.
- **Algunas cronologías están discutidas**: el signo escaleriforme de La Pasiega
  fechado en más de 64 000 años y atribuido a neandertales se discute en la
  literatura. El texto lo dice discutido, como pide la spec.
- **Ver Altamira pide un campamento que la haya explorado**: la visita desde el
  mapa regional no lleva gente y no explora. Para la mayoría de las partidas, las
  cuevas con arte sólo se verán fundando o migrando cerca. Es lo que dice la spec,
  pero conviene saberlo.
- **Una capa 3D encima de la escena** tiene que quedarse con la entrada del ratón y
  del teclado mientras está abierta, y soltarla al salir, sin que la cámara del
  valle se mueva por debajo.
- **La pared se calcula en el paso de campamentos fuera del árbol**: nada de nodos,
  recursos ni texturas en `ParedDeLaCueva`. Si hace falta rasterizar un motivo a
  textura, eso es de la vista.

#### Cómo quedó (2026-09-15)

**Lo construido, pieza a pieza.**

- **Los motivos** son doce calcos (`Motivos`, generado por
  `scripts/tools/calcar_motivos.py` desde Wikimedia Commons): bisonte, jabalí,
  cierva, ciervo, caballo, uro, mano, serie de puntos, bastoncillos, claviformes,
  tectiforme y escaleriforme. Once son cántabros; **el uro es de Lascaux**, porque no
  hay uno cántabro con licencia libre (CREDITOS). Qué figura lleva cada relato lo
  dice `Tale.motivo()`.
- **El arte de los que estuvieron antes** son las diez cuevas de `ArteDeLosDeAntes`,
  reconocidas **al metro** por las coordenadas de OpenStreetMap, con muestra de
  paneles, texto y fuentes (EPOCA_01 §12).
- **La pared** (`ParedDeLaCueva`) es de la simulación: relieve sembrado, convexidad y
  pendiente, y colocación en dos pasadas. Colocar una figura cuesta **~50 ms**.
- **Pintar** deja la figura con su cueva y su sitio en el relato (`Pinturas`); mudarse
  no se lleva las pinturas; lo pintado de antes va a la cueva de la banda.
- **Pintar lo de antes**: la ventana de Técnicas lista todo lo pintable, también sin
  la técnica, con el motivo.
- **Entrar** en la sala (`SalaDeLaCueva`) desde la ficha de la cueva o desde el mapa
  regional; la primera vez en una cueva con arte, su texto va a la crónica y a los
  relatos, sin tarea.

**Medido.** Con `ParedProbe` (60 figuras en 3 paredes): la peor figura recalca mejor
que el **100 % de los sitios libres**. Con `CuevaCaptura` (dos corridas): entrar
**0,4–0,6 s**, salir 1–3 ms, GPU **2,0–2,1 ms**.

**Lo que salió distinto del plan, y conviene saber.**

- **«Por construcción sale» no salía**: con la pared llena, una figura quedaba al 88 %
  contra cualquier sitio, porque se comparaba con huecos ya ocupados. **Decisión del
  usuario**: el criterio es contra los sitios libres (arriba, en los criterios, con lo
  que decía antes).
- **El listón de pintar encima volvió a la mediana** tras probar el 90 %, que pintaba
  encima con la pared a medias. Y **una lectura mía, dicha para que se corrija**: con
  la pared llena, la figura va encima de la más antigua de la banda sólo si ahí
  recalca al menos igual que en el mejor hueco libre.
- **Pisar a otra figura cuenta también por el contorno**, no sólo por el cuerpo.
- **El determinismo del paso prohíbe `exp`** de la librería (`TestCalculo`): la pared
  usa `Calculo.exponencial`.
- **Mirar desde el mapa regional pide un campamento vivo en ese sitio** que haya
  explorado la cueva: lo explorado es de cada campamento.

**Queda pendiente.**

- **De cerca, el trazo se ve escalonado**: la textura de pinturas es de 110 px por
  metro. Subirla cuesta tiempo de entrada; está medido que hoy sobra margen (0,6 s de
  2).
- **La primera sepultura no es pintable**: su hito no lleva tarea, aunque su
  comentario dice que se puede dejar en la pared. Es anterior a este trabajo y queda
  en ESTADO §2 para `/depurar`.

## 14. Los desechos, y el lobo

### El montón

Lo que se come deja lo que no se come, y eso **no desaparece**. Litros de residuo
por ración comida:

| material | litros por ración | por qué |
|---|---|---|
| Marisco | 2,40 | casi todo es concha |
| Caracol | 1,10 | concha más menuda |
| Bellota lavada | 0,45 | cascarilla y cúpula |
| Fruto seco | 0,40 | cáscara de avellana |
| Carne | 0,14 | hueso y asta que no se aprovechan |
| Pescado | 0,09 | espina |

El montón se ve a partir de **400 litros** —un año de marisqueo fuerte— y se
dibuja en tres capas que crecen juntas: un `Decal` que tiñe el suelo, una loma
baja que se desparrama (un conchero no es un cono) y la cáscara suelta en
`MultiMesh`. **El color sale de la dieta**: blanco de concha si la banda vivió
del marisco, pardo si vivió de la bellota. A los cinco años, el montón dice de
qué ha vivido la banda sin abrir una ventana.

Los concheros cantábricos —El Mazo, La Fragua, Santimamiñe— son montones de
metros de espesor hechos de una sola cosa: cáscara. Son la prueba de que la
gente estuvo comiendo ahí durante años, y a menudo lo único que queda.

### El lobo, que viene al montón

`ElLobo.gd`. **No es una técnica del árbol**, y ésa es la decisión que ordena
todo lo demás: una técnica se aprende acumulando jornadas, pero **una relación se
construye o se rompe, y se puede perder**. Meterlo en el árbol lo habría
convertido en otra casilla que se llena sola, y no tendría dos finales.

Arranca en el montón porque la hipótesis con más apoyo no es la del cazador que
sale a buscar un cachorro: es la **comensal**. Los lobos menos miedosos se
acercaron solos a los desperdicios, comieron mejor, criaron más, y la selección
hizo el resto. **La domesticación no la empezó la gente: la empezaron los
lobos.** Y eso encadena dos sistemas que si no serían dos adornos sueltos: la
basura que la banda genera es lo que trae al animal que va a cambiarle la caza.

Atestiguado en Europa hacia 15 000–14 000 a.C. (Bonn-Oberkassel), o sea
**dentro** del Magdaleniense. No hay que estirar nada.

Cinco pasos, cada uno un `Moment` con el reloj parado:

| paso | qué pasa | qué se decide |
|---|---|---|
| **Merodean** | vienen al montón de noche | dejarlos comer · espantarlos · matar al que se acerque |
| **Uno se queda** | uno no huye cuando alguien sale | echarle una tajada · dejarlo estar · cobrárselo |
| **La lobera** | se da con la camada | coger un cachorro · dejarla en paz |
| **El cachorro** | 120 jornadas de cría, y come | — |
| **El perro** | caza con la cuadrilla | se pinta en la pared |

El `trato` va de −100 a +100. Lo suben las decisiones amables y, sobre todo,
**cada noche que vienen y no pasa nada**: la relación no la hacen los gestos, la
hace el tiempo.

**El otro final:** por debajo de −45, o con dos lobos muertos, la manada está en
contra y el riesgo de una noche fuera se multiplica por **1,9**. Cada muerto
cuesta **1,8 veces el anterior**, y hace falta casi un año de partida por lobo
para que se olvide. No es un castigo por jugar mal —matar al lobo que te ronda la
despensa es razonable—: es la otra rama.

**Lo que cambia cuando llega**, y ataca un problema medido (de quince cacerías
levantadas sólo se cobran cuatro, y el 73 % se pierde en el acecho):

| efecto | dónde | cuánto |
|---|---|---|
| Corta el rastro perdido | `Caceria._stalk` | 55 % de las veces |
| Para la pieza | `Caceria._chase` | ×1,60 de fuelle |
| Guarda el vivac | `Percances` | ×0,55 de riesgo |
| **Y come** | `ElLobo._dar_de_comer` | **0,6 raciones/día** |

Esas 0,6 son 108 raciones al año, y la caza entera dio 147 en la corrida de un
año con tres cazadores. **Por eso es una decisión y no un regalo**: sale a cuenta
sólo si la banda caza de verdad.

> **Dos fallos que sólo encontró la sonda**, y que no se ven leyendo el código:
> el camino amable era **imposible de andar** —las dos decisiones previas a la
> camada sumaban 24 de trato y la camada pedía 55— y el camino del enemigo era
> **inalcanzable**, porque los momentos se preguntaban una sola vez y en toda la
> partida había dos ocasiones de matar un lobo. Se arreglaron con `POR_NOCHE` y
> haciendo que los momentos **vuelvan**: un lobo no deja de venir porque le tires
> una piedra, deja de venir esa noche.

---

## 15. La bellota

`Materia.Kind.BELLOTA` estaba en el catálogo con 1 300 kcal y su propio
comentario decía *«necesita desamargado: agua, recipiente y tiempo»* — **y se
comía directamente**. La bellota cruda tiene tanino: es astringente, sienta mal
y en cantidad es tóxica. Comérsela sin tratar no es una simplificación, es un
error.

- **`BELLOTA` pasa a 0 kcal.** `Materia.is_food` es `kcal > 0`, así que sale
  sola de la despensa sin tocar nada más.
- **`BELLOTA_DULCE`**, 1 300 kcal y 300 días: la harina del invierno.
- **`CampProjects.Kind.LAVADERO`**: un cesto lastrado en el remanso. Dos
  jornadas, 6 de fibra y 4 de piedra. **No depende del hogar** —es agua
  corriente, no fuego—, así que es la primera obra que se puede levantar sin
  tener nada encendido.
- **Tres jornadas de remojo** y **30 puñados por lavadero**. Ese tope es el
  punto: en un otoño bueno sobra bellota sin tratar.

De los tres métodos atestiguados —agua corriente, lixiviación con ceniza,
enterrarla— se eligió el primero porque la banda ya tiene río y ya sabe dónde
está.

**Lo que cambia:** el otoño deja de ser «recoge y ya» y hay que decidir cuánta
bellota se pone a lavar —712 puñados recogidos en un año son 24 cestadas—;
aparece una razón para tener el campamento cerca del agua que no es la pesca; y
la bellota pasa a ser lo que fue: **comida de reserva que se prepara en otoño o
no la tienes en enero**.

---

## 16. El curtido de piel, y el taller que practica

> **Todo lo que se cose o se tensa pide piel CURTIDA** (2026-09-13). La cruda se
> seguía gastando en tres sitios —la tienda del vivac, la de la expedición y el
> paraviento— y por eso desaparecía sin que se curtiera nada: «se gastan pieles
> crudas, pero no han hecho aún ninguna piel curtida… ¿en qué coño se usan?».
> Una tienda de pellejo sin curar se pudre en doce días, que es justo lo que
> dura una expedición. La cruda queda para **curtirla y para el trueque**, que
> es lo que se comercia de verdad.
>
> Y la otra mitad de por qué no se curtía: **curtir pide grasa**, y la grasa se
> la comían. Ver §10.

`Materia.Kind.PIEL` estaba en el catálogo con `dias: 0` —no se pudre— y su
propia ficha decía *«sin curtir se pudre»*. `Profession.SPECIALITY_INFO`
describía la peletería como «descarnar y curtir con raederas, ocre y grasa»
y ninguna receta gastaba ocre ni grasa: la piel cruda servía tal cual para
coser un odre o un vestido. Vino de arreglar
[ABRIGO_Y_TRUEQUE.md](archivo/ABRIGO_Y_TRUEQUE.md) (vestido como necesidad
de invierno): el usuario preguntó *«¿no hará falta curtir la piel con ocre y
algo más?»*, y la respuesta, mirando el propio catálogo, era que sí.

- **`PIEL` pasa a ser la piel CRUDA**, con `dias: 12` — se pudre de verdad
  si no se trata a tiempo.
- **`PIEL_CURTIDA`**, nueva, `dias: 0` — no se pudre, y es la que de verdad
  sirve: `Tool.recipe(ODRE)` y `Tool.recipe(VESTIDO)` la piden a ella, no a
  la cruda.
- **`Taller._curar_piel`**: un peletero con una `RAEDERA` en el taller cura
  piel cruda gastando ocre y grasa (0,3 y 0,5 por piel), a 1,2 pieles por
  jornada completa. Sin raedera no se descarna, y sin ocre o grasa la
  jornada se gasta en el intento sin producir nada — no se cae a tallar
  un odre a medio curtir.
- **Reserva de 4 pieles curtidas.** Sin este tope, un peletero con piel de
  sobra curtiría sin parar y nunca cosería nada; con él, se para y talla
  en cuanto hay para un par de piezas.
- Curtir va SIEMPRE antes que tallar dentro de `Taller._craft`: una prenda
  no se hace con piel cruda.
- **Coser pide una aguja HECHA, no sólo la técnica** (`Tool.needs_tool`): el
  vestido pide `AGUJA` en el utillaje y el odre `RAEDERA`, y cada pieza cosida
  gasta media jornada de la aguja. El usuario lo dudó el 2026-09-14 al ver
  vestidos y ninguna aguja; lo fijan `TestTaller` —diez jornadas de peletería
  sin aguja no sacan un vestido, con una sí— y la de curtir sin raedera. Tener
  vestidos y cero agujas es lo normal **después**: las agujas se gastan cosiendo
  y los vestidos quedan.

**Lo que cambia:** curtir deja de ser una frase de sabor y pasa a competir
por el tiempo del peletero y por el ocre y la grasa del almacén — los
mismos materiales que ya usa la pintura parietal, así que el ocre deja de
ser sólo cosa del arte.

---


> **Y se curte aunque nadie pida prendas** (2026-09-13, tanda 3, frente 14). El
> curtido existía, pero a peletería sólo se mandaba a alguien si había una
> **pieza pedida** que llevara piel —`Taller._next_piece`—, así que sin demanda
> de odres ni vestidos las pieles crudas se amontonaban y se pudrían sin que
> nadie las tocara. Lo vio el usuario jugando. Ahora `Taller.hay_que_curtir`
> abre la puerta del reparto por sí sola.
>
> **Lo mismo con la talla**: si no hay pieza pedida pero queda una técnica de
> manufactura por aprender y hay materia prima, el artesano **talla para
> aprender**, gastando una unidad de la materia del oficio por jornada —una
> decisión, no una medida—. Si no queda nada que aprender, no practica: no se
> gasta piedra por gastarla. Es lo que cierra el 🔴 «el taller se para solo», y
> la salida que eligió el usuario entre cuatro.

### El esfuerzo es de la pieza, no del oficio (2026-09-14)

Queja del usuario: «tarda mucho en fabricar las cosas, diría que varios días de
trabajo en hacer un simple punzón… dame los tiempos y vamos a revisarlos, porque
no me gustan de momento».

**Los tiempos de entonces, medidos.** La velocidad era una sola cifra por
especialidad —`SettlementSim.CRAFT_PER_DAY`, ya borrada— y todas las piezas de un
oficio costaban igual. Con 11 horas útiles al día (`SettlementSim.HORAS_UTILES`):

| Oficio | Piezas/jornada | Horas por pieza | Piezas |
|---|---|---|---|
| Talla | 3,0 | 3,7 h | lasca, raedera, buril, punta, lámpara |
| Cordelería | 1,2 | 9,2 h | cuerda, cesto, nasa, **red** |
| Asta | 0,6 | **18,3 h** | azagaya, arpón, aguja, **punzón**, anzuelo |
| Peletería | 0,5 | 22 h | odre, vestido |

El usuario tenía razón, y la tabla destapaba algo peor que la escala: **la red
—9,0 de fibra, «la pieza más cara de la banda» según su propia receta— salía en
9,2 horas y el punzón de hueso en 18,3**. El orden estaba invertido.

**Lo que hay ahora**: [Tool.HORAS_DE_TRABAJO], horas de trabajo **por pieza**,
en órdenes de magnitud de arqueología experimental —lo caro de una aguja es
perforarle el ojo; lo de un arpón, sacarle los dientes uno a uno; una red son
semanas de tarde—. Punzón 1 h, aguja 3, azagaya 6, arpón 12, red 45, vestido 30,
lasca 0,25. Revisadas y aceptadas por el usuario antes de aplicarlas. El oficio
**sigue contando, pero como destreza** (`Inhabitant.effectiveness()`), no como
velocidad única. `TestTaller`.

**Y mueve la partida, avisado antes de tocarlo**: el utillaje pequeño pasa a ser
casi gratis y el aparejo de pesca y la ropa se vuelven inversiones. Se vio en el
acto: `test_sin_aguja_hecha_no_se_cose_un_vestido` daba diez jornadas al peletero
y con el vestido a 30 h —más los odres que hace antes— ya no llegaba. La prueba
comprueba la regla de la aguja, no el ritmo, así que se le dio holgura; **pero
queda dicho que la ropa se encareció** y hay que mirar que la banda siga llegando
vestida al invierno.

## 17. El agua: odres, y por qué llenar uno puede ser una salida

> **Un odre lleno no es un odre vacío** (2026-09-13). Cuántos hay vacíos lo
> contestaban por su cuenta cuatro sitios —el llenado en casa, la salida a por
> agua, la vuelta de la orilla y la capacidad de la despensa—, ninguno
> descontaba el que va fuera con alguien, y la capacidad de guardar comida
> sumaba **doce litros por cada odre**, también por los que llevan agua: el
> mismo odre contaba dos veces. Ahora lo contesta `Despensa.odres_vacios()` —los
> hechos, menos los llenos, menos los que lleva alguien encima— y de ahí beben
> los cuatro. En el almacén, la fila del odre dice los **vacíos**; los llenos ya
> salen como Agua.

`Materia.Kind.AGUA` —«un odre lleno»— se sincronizaba solo:
`Despensa._sync_waterskins` igualaba su cantidad a «odres que ha hecho el
taller menos los que hay fuera con alguien», así que un odre recién tallado
aparecía lleno sin que nadie lo hubiera llenado, y volvía lleno al abrigo
sin que nadie hubiera ido al río. El usuario lo notó mirando la ventana de
almacén —*«veo odres y agua como si fueran lo mismo»*— y, al corregirlo,
hizo la pregunta que de verdad importaba: *«quizá haya cuevas que no estén
pegadas al agua»*.

- **`Hogar._home_by_water()`**: si el abrigo está de verdad junto al agua,
  mirando el terreno (`Tajo._water_beside(home_position)`), no si "hay un
  río en el valle". Sin terreno que consultar —montajes de prueba a
  medias— se asume que sí, mismo criterio permisivo que ya usa
  `Taller.knows_tool` sin árbol de técnicas.
- **Junto al agua:** llenar odres sigue siendo una tarea pasiva de quien
  trabaja de HOGAR (`Hogar._fill_waterskins`, hasta 4 odres por jornada y
  persona), y beber en el abrigo sigue siendo gratis.
- **Lejos del agua:** llenar dejó de ser gratis. `Hogar._fetch_water` manda
  a alguien de HOGAR a la orilla más cercana —`state = YENDO`,
  `marcha._send_to`, mismo mecanismo que cualquier otro viaje del juego—, y
  `Hogar._arrive_at_water` llena al llegar y lo manda de vuelta
  (`VOLVIENDO`). Es una salida de verdad: cuenta metros, deja rastro y
  cierra su `journey` al entregar en el abrigo, exactamente como una
  expedición o una jornada de caza.
- Y beber en un abrigo lejos del agua ya no es gratis por estar dentro:
  `Despensa._drink_and_thirst` gasta `Materia.Kind.AGUA` de la reserva que
  trajeron esas salidas (0,08 por hora); sin reserva, seguir en casa no
  quita la sed, igual que estar lejos del agua en cualquier otro sitio.
- `Despensa._sync_waterskins` deja de igualar y pasa a ser sólo un tope: el
  agua nunca puede superar los odres que existen, para que un odre que se
  rompe se lleve su agua con él.

> **El agua del río no es agua gastada** (2026-09-14). Queja del usuario: con la
> cueva junto al río, **1 277 de agua gastada en 167 jornadas**. Eran tres cosas,
> y la primera era la gorda:
>
> 1. **Un odre por salida, bebiera o no.** Los recipientes vuelven en
>    `Despensa._deliver`, y quien sale sin haber traído carga no pasa por ahí: se
>    quedaba el odre puesto, y `_hand_out_containers` le sacaba **otro lleno**
>    del almacén en la salida siguiente. Ahora quien ya lleva odre no coge otro.
> 2. **El odre contaba como bebido al salir.** Ahora sale del almacén sin
>    apuntarse (`Storehouse.take(…, false)`) y al volver devuelve lo que no se
>    bebió (`Despensa.agua_en_el_odre`, que sale de `water_left`: las horas por
>    encima de `SED_HORAS_SIN_ODRE` son las del odre). Beber junto al río lo
>    rellena, así que un odre que pasa el día en la orilla vuelve lleno. **Lo
>    gastado es sólo lo bebido del odre** (`Storehouse.apuntar_gasto`), y lo que
>    se pierde al romperse uno tampoco cuenta: se pierde, no se bebe.
> 3. **El sorbo en casa miraba a la persona, no a la cueva.** Quien estaba en la
>    campa o dentro, a más de veinte metros del cauce, bebía del almacén aunque
>    la cueva diera al río. Ahora en casa manda `Hogar._home_by_water`.
>
> Pruebas en `TestJornada`, «el agua del río no es agua gastada».

**Lo que cambia:** una cueva mal elegida —lejos del río, aunque abrigada—
tiene un coste real y recurrente en jornadas de HOGAR, no solo narrativo.
Fundar junto al agua vuelve a ser una decisión con consecuencia, no un
supuesto de diseño.

---

## 18. Los caminos que la banda aprende

> **Spec (2026-09-12).** Escrita con `/spec` sobre la intención de `/epoca 1`.
> Los criterios de aceptación, con las cifras de partida, están en
> [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md) §10.1, tanda 1, frente 1 —
> aquí está el mecanismo y **por qué es de las once épocas**, no de una.

**Qué se quiere.** Que la ruta a un sitio al que se va muchas veces **mejore
con el uso y se reutilice**, en vez de buscarse entera cada vez. Es un sistema
de las once épocas, no del Paleolítico: la vereda que se afina es la misma
pieza que después es camino de carro, calzada y carretera. Lo que cambia por
época es cuánto baja el coste y quién lo mantiene, no el mecanismo.

**Por qué así y no de la otra manera.** La alternativa era la senda física —el
paso repetido abarata la celda del terreno— y se descartó a propósito: es
bonita, pero no explica el síntoma del que sale la petición. El jugador lo
describió como conocimiento, no como suelo:

> «al principio no saben llegar de otra manera […] con el tiempo, cosa de un
> par de estaciones como mucho, que vayan depurando el camino».

Así que lo que mejora es lo que la banda **sabe**, y encaja donde ya vive lo
que la banda sabe: `BandKnowledge`. La ruta se guarda por destino y se
reintenta mejor cada recorrido hasta converger.

> **Corregido (2026-09-12, `/depurar`).** Este apartado daba por hecho que el
> rodeo del río era una ruta memorizada que no caducaba. **No lo era**, y
> conviene saberlo antes de diseñar encima: era el coste del riesgo, que
> multiplicaba el tiempo sin tope y hacía que cuarenta metros de ladera
> costaran kilómetros de rodeo. Está arreglado y medido —ver
> [ESTADO.md](ESTADO.md) §2—. Lo que este apartado propone sigue en pie como
> sistema, pero **ya no tiene un fallo que arreglar debajo**: si se implementa,
> es porque la vereda que se afina es una pieza de las once épocas, no porque
> el rodeo esté roto.

**El riesgo, y es el que decide el diseño.** `Navgrid` se rehorna **una vez por
estación** (`Navgrid.from_terrain`, `HornoDeRejillas`), porque el caudal y el
encharcamiento cambian qué se vadea y qué es marisma. Un vado que no existe en
primavera existe en verano. Si la ruta aprendida se guarda sin caducar, un
camino puede sobrevivir a la rejilla con la que se trazó y quedarse dando una
vuelta que ya no hace falta: **hoy eso no pasa** —`Marcha.forget_routes` tira
los caminos guardados en cada cambio de rejilla, comprobado— y el sistema nuevo
no puede reintroducirlo.

**La regla, entonces:** ninguna ruta memorizada sobrevive a la rejilla con la
que se trazó. `Navgrid.built_with_caudal` y `built_with_encharque` ya dicen con
qué se horneó cada una, así que la memoria se sella con ese par y se tira al
cambiar. Converger otra vez cuesta unos recorridos, que es exactamente lo que
debe costar: el valle ha cambiado.

> **Construido el 2026-09-12.** La memoria es `BandKnowledge.veredas`, y cada
> entrada es una [Vereda]: sus hitos más el caudal y el encharcamiento de la
> rejilla que la trazó. `BandKnowledge.vereda(clave, rejilla)` **la descarta al
> leerla** si el sello no coincide, y la borra en vez de dejarla ocupando
> sitio. El tope es `BandKnowledge.VEREDAS_QUE_SE_RECUERDAN` (200).
>
> **Y esto cambió algo que este apartado daba por resuelto.** Decía que la
> regla ya se cumplía porque `Marcha.forget_routes` vacía la memoria en cada
> cambio de rejilla, y es cierto — pero eso es **un aviso**, y un aviso no se
> puede comprobar con una prueba: sólo se puede confiar en que nadie toque ese
> camino. Con el sello pegado al dato la regla es comprobable, y lo está:
> `TestVeredas`, once pruebas, de las que tres se ponen rojas si se quita el
> sello. `forget_routes` se queda —también levanta `Parajes.revisar_el_mapa`—
> pero ya no es lo único que sostiene la regla.
>
> Antes vivía en `SettlementSim._route_cache` / `_route_order`, que es donde
> acaban las cosas cuando nadie decide de quién son.

> **Y lo de «por destino» se probó y NO sale. Corregido el 2026-09-12, contra
> lo que este apartado pedía.** La idea era que la vereda fuese «el camino al
> avellanar» y la compartieran todos los que van allí, enganchándose por donde
> les pillara. Medido, multiplica por 135 los pasos que el terreno corta
> teniendo camino trazado: de 17 con la clave por par a 2 295 con la clave por
> destino (`AtascoProbe`, `SEMILLA=42`, 8 jornadas; la tabla entera en
> [ESTADO.md](ESTADO.md) §2).
>
> **El motivo es geométrico, no de afinado.** Con la clave por par, quien
> reutiliza la vereda está siempre dentro del cubo de origen —setenta metros
> como mucho del primer hito—. Con la clave por destino puede estar a
> kilómetros, y el enganche pasa a ser una recta larguísima que ninguna cata
> razonable cubre: `Wayfinder.linea_limpia` mira el eje cada veinte metros, y
> **lo que la banda anda no es el eje** —cada persona va por su carril—. Catar
> más fino y con el ancho del carril llevó la sonda de 48 segundos a más de
> diez minutos: la comprobación sale más cara que la búsqueda que ahorraba.
>
> **Lo que sí quedó, y es la mejora de verdad: los dos extremos se catan.** Una
> vereda tiene dos tramos que antes no miraba nadie —de la persona al primer
> hito (`Vereda.enganchar`) y del último hito al punto exacto al que va
> (`Vereda.remate`)—. Con ellos: 0 atascos contra 1, menos proporción de
> caminos que no merecen andarse, y más reuso.
>
> **Lo que el sistema SÍ entrega, medido: el 39 % de las búsquedas.**
> `Wayfinder.busquedas` cuenta las búsquedas completas dentro de `find`, que es
> por donde pasan todas. Con `SEMILLA=42` y ocho jornadas: **265,8 búsquedas
> por jornada sin memoria de veredas, 161,1 con ella**. Era la otra mitad de lo
> que este apartado pedía —«y que no se busque de cero»— y resultó ser la mitad
> que de verdad aporta.
>
> **Y lo de que la vereda mejore con el uso no está hecho.** Se construyó
> —borrar el hito que sobra cuando el atajo se ve *y* sale más barato por la
> vara del trazado— y se retiró: fabricar tramos rectos nuevos es exactamente
> lo que este mismo apartado acaba de aprender que es caro de comprobar. Ver
> ROADMAP «En curso» → Tanda 1, tarea C3.

### La obra que abre un cruce

> **Spec (2026-09-13).** Criterios en
> [EPOCA_01](EPOCA_01_PALEOLITICO.md) §10.1 → Tanda 3, frente 13.

**Qué se quiere.** Que cruzar un cauce todo el año sea **una obra en un sitio**,
no una técnica que abre el mapa entero. Hoy aprender la pasarela abre todos los
cruces a la vez. Pasa a esto: la técnica permite construir, **la banda elige
sola** el cruce de sus caminos aprendidos que más rodeo le ahorra, y **sólo ese
cruce** queda abierto, en las cuatro estaciones. La obra tiene límite de ancho y
coste, se ve sobre el terreno, y **una crecida de la rejilla estacional** puede
llevársela.

**Por qué es de las once épocas y va aquí.** Los caminos aprendidos dicen por
dónde pasa la banda, y la obra se pone donde esos caminos más la necesitan. Es
la misma pieza que después serán el puente de piedra y el viaducto: cambian el
ancho que salvan, lo que cuestan y lo que aguantan, pero no el mecanismo.

---

> **Y se olvidan enteras cada vez que se rehace la rejilla** (2026-09-14, al
> depurar las pasarelas): `Marcha.forget_routes` llama a
> `BandKnowledge.olvidar_veredas`, y eso pasa **en cada cambio de estación** y cada
> vez que se levanta una pasarela. El comentario del código lo llama «limpieza»
> —el sello de `Vereda` ya impide andar una vereda de otra rejilla—, pero el efecto
> es que lo aprendido no dura de una estación a la siguiente, y §20 se apoyaba en
> ello.

### Plan técnico: que lo aprendido dure el año (2026-09-14)

**El síntoma, y de dónde sale.** Al depurar las pasarelas se vio que la regla del
vado casi nunca tenía veredas que mirar. La causa: `Marcha.forget_routes` vacía
`BandKnowledge.veredas` **entera** en cada cambio de rejilla, y la rejilla cambia
al entrar cada estación, al levantar una pasarela y al cerrar una celda a mano.

**Lo que hay hoy, comprobado en el código.**

- Cada vereda lleva **su sello**: `Vereda.caudal` y `Vereda.encharque`, los de la
  rejilla que la trazó, y `BandKnowledge.vereda(clave, grid)` la **descarta al
  leerla** si no coinciden (`Vereda.sirve_en`). Once pruebas lo sostienen
  (`TestVeredas`).
- `forget_routes` se llama en cuatro sitios: al **cerrar una celda** a mano
  (`Marcha`, cuando alguien no pasa por donde la rejilla decía), al **amasar** una
  rejilla nueva, al **cambiar de estación** y al **mudarse de cueva** (`Traslado`).
- El tope de memoria es `VEREDAS_QUE_SE_RECUERDAN` = 200, y hoy guarda las de
  **una** rejilla.

**Lo que cambia.** El borrado en bloque se quita de donde el sello ya protege —el
amasado y el cambio de estación—, y **se queda donde el sello no ve nada**: cerrar
una celda a mano cambia por dónde se pasa **sin tocar el caudal ni el
encharcamiento**, así que una vereda de esa misma rejilla puede cruzar por la celda
que se acaba de tachar. La mudanza de cueva no cambia la rejilla; se mira aparte.

Con eso, una vereda de primavera **duerme** el resto del año y **vuelve a valer**
cuando su rejilla vuelve: es lo que pide §18 —«ninguna ruta se anda con otra
rejilla»— sin tirar lo aprendido.

**Módulos afectados.**

1. **`Marcha`**: `forget_routes` deja de olvidar veredas; se separa en dos —lo que
   hay que hacer siempre (avisar a `Parajes.revisar_el_mapa`) y el olvido, que sólo
   pide quien cierra una celda—.
2. **`BandKnowledge`**: el tope pasa a contarse por rejilla o se sube, para que
   cuatro estaciones no se pisen entre ellas (decisión de abajo). Y `olvidar_veredas`
   se queda para quien de verdad tenga que tirarlas.
3. **`Pasarelas`**: nada que tocar —su regla del vado vuelve a tener veredas que
   mirar—, pero su prueba pasa a cubrir el caso «la estación vuelve».
4. **`TestVeredas`**: la prueba nueva de que una vereda sobrevive a un ciclo de
   estaciones y se vuelve a andar cuando su rejilla vuelve.

**Decisiones del usuario (2026-09-14).**

- **El tope se cuenta por rejilla**: 200 veredas por estación, así que ninguna
  echa a las de las otras antes de que su estación vuelva.
- **Cerrar una celda a mano sigue tirándolas todas**, por ahora: es lo de hoy y es
  seguro. Afinarlo —tirar sólo las que pasan por esa celda— queda dicho como deuda.
- **Todas las tareas seguidas.**

**Riesgos técnicos.**

- **Cambia la partida**: con más veredas guardadas se buscan menos caminos y la
  gente anda por donde ya anduvo. Las firmas de las sondas se desplazan una vez.
- **Memoria**: 200 veredas de una rejilla pasan a ser 200 repartidas entre cuatro;
  si el tope se queda corto, el ciclo las expulsa antes de que su estación vuelva y
  el cambio no sirve de nada. Es la decisión de abajo.
- **Cerrar una celda sigue tirándolo todo**: es un borrado en bloque por una celda.
  Afinarlo —tirar sólo las veredas que pasan por ahí— es trabajo aparte y se dice.

### Cómo quedó: lo aprendido dura el año (2026-09-14)

**Lo que cambió, en tres sitios:**

- `Marcha.forget_routes` **ya no olvida las veredas**: tira las rutas en curso y
  levanta `Parajes.revisar_el_mapa`, nada más. Quien sí las tira es
  `Marcha._cerrar_y_olvidar`, el único caso en que cambia por dónde se pasa **sin
  cambiar el río**, que es lo que el sello no ve.
- `BandKnowledge.vereda` **ya no borra la caducada al leerla**: la deja dormida.
  Eso era lo que de verdad impedía que una vereda llegase a la estación siguiente,
  y no estaba en el plan: se vio al escribir la primera prueba.
- El tope es **200 por rejilla** (decisión del usuario), con su lista de orden por
  sello, así que una estación muy andada no echa a las otras.

**Medido** con `VeredasProbe` (sitio 56, `SEMILLA=42`, cuatro jornadas por tramo:
primavera, invierno y primavera otra vez):

| | guardando las veredas | tirándolas, como antes |
|---|---|---|
| búsquedas por jornada, primera primavera | 152,0 | 152,0 |
| búsquedas por jornada, al volver la primavera | **150,5** | **151,0** |
| veredas guardadas al final | 350 | 200 |

**O sea: un 0,3 %.** El cambio es el correcto —lo aprendido no se tira, y la regla
del vado de §20 vuelve a tener veredas que mirar—, pero **no es una mejora de
rendimiento**, y conviene que quede escrito antes de que alguien lo cuente como
tal. La sonda dice por qué: **el tope de 200 se satura en cuatro jornadas**, así
que de una estación a la siguiente sobrevive sólo lo último que se anduvo, y los
destinos cambian a diario. Si alguna vez se quiere el ahorro de verdad, la palanca
es el tope o la clave de la vereda, no el olvido.

**Deuda que queda:** cerrar una celda a mano sigue tirando **todas** las veredas,
no sólo las que cruzan por ella.
## 19. La temperatura, y el abrigo que se lleva puesto

> **Spec (2026-09-12).** Escrita con `/spec` sobre la intención de `/epoca 1`.
> Los criterios están en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
> §10.1, y **las tres piezas van en tandas distintas**: los grados visibles se
> comprueban en una jornada (tanda 1, frente 3), y el vestido como necesidad y el
> frío que cierra sitios sólo se comprueban en dos inviernos (tanda 2, frente 7).

**El hueco.** El juego tiene frío pero no tiene temperatura. `Inhabitant.cold`
es un 0 a 100 abstracto que sube durmiendo lejos del fuego y que
`Relevo.revisar_frio` convierte en enfermedad y en muerte; el vestido existe
como pieza (`Tool.Kind.VESTIDO`), se gasta 0,6 al día
(`SettlementSim.VESTIDO_WEAR_PER_DAY`) y quita el 60 % del frío
(`VESTIDO_COLD_MITIGATION`). **Nada de eso se ve en pantalla, y no hay grados
en ninguna parte del juego.** Es la razón de que el sistema de ropa esté sin
probar: no se puede jugar con lo que no se puede leer.

**Qué se quiere, en tres piezas.**

1. **Temperatura en grados, visible.** Sale de estación, hora, altitud y el
   paleoclima, que ya está calculado para el nivel del mar (`RegionEras`,
   EPOCAS.md §2). Que exista en grados es lo que hace legibles a la vez la
   escalera térmica (§1.1), el hogar, el vivac y la ropa.
2. **El vestido como necesidad**, no como modificador. La ficha del Paleolítico
   §4 ya lo listaba como necesidad del grupo y decía que no existía; pasa a
   existir, con la consecuencia que ya sabe aplicar `Relevo.revisar_frio`.
3. **El frío cierra sitios.** Sin ropa buena no se sube al roquedo en invierno
   ni se duerme al raso. Eso convierte la peletería en una **puerta** —como la
   azagaya lo es para la caza mayor— en vez de en un porcentaje, y le da al
   invierno una decisión propia que hoy no tiene.

> **Construido el 2026-09-12: `Termometro` (`scripts/mundo/`), y contesta solo
> él.** Tres sumandos, cada uno con fuente o con razón: la media de la estación
> al nivel del mar hoy, más el desfase frío de la época, más la vuelta del día,
> menos lo que enfría subir. Las fuentes, en [CREDITOS.md](CREDITOS.md).
>
> **Y la época se fija al FINAL del Magdaleniense, hacia el 12 000 a.C.**
> (decidido por el usuario el 2026-09-12). Hacía falta decidirlo: el
> Magdaleniense cantábrico va de ~17 000 a ~11 700 a.C. y **abarca la
> deglaciación entera**, así que «la temperatura del Magdaleniense» no era una
> sola cosa. 12 000 a.C. son ~14 ka cal BP, dentro del interestadial
> Bølling–Allerød.
>
> **El hallazgo, y no es la cifra sino la forma: aquello no era «como hoy pero
> más frío», era MÁS ESTACIONAL.** De Tarroso et al. (2016), cuyo grupo C1 es
> la Iberia del norte y noroeste:
>
> | | desfase respecto de hoy |
> |---|---|
> | Invierno | **−5 °C** — su mínima de enero sube ~5,5 °C en 15 000 años |
> | Verano | **−2 °C** — su julio sólo se mueve ~2,5 |
>
> El verano se parecía al de ahora y el invierno no se parecía en nada. **Eso
> es lo que sostiene que el abrigo sea una puerta y no un porcentaje**, que es
> lo que pedía la pieza 3 de aquí abajo: si la época fuera uniformemente cinco
> grados más fría, el verano también cerraría sitios y la peletería sería un
> impuesto en vez de una decisión de invierno.
>
> En la boca de la cueva (~120 m) sale una tarde de verano a ~20,7 °C y una
> noche de invierno a ~0,7 °C.
>
> **Lo que NO es una cifra de balanceo y no se toca:** el gradiente vertical,
> 0,65 °C por cada 100 m, que es física. Si el roquedo sale inhabitable, lo que
> se cambia es el roquedo.

> **Piezas 2 y 3, construidas el 2026-09-12: el frío se coge por grados, y
> cierra lo alto.**
>
> **El frío por grados.** `SettlementSim.frio_por_hora` convierte la
> temperatura en frío por hora durmiendo sin fuego: cero por encima de
> `Termometro.GRADOS_DE_ABRIGO` (5 °C), proporcional a cuánto se baja por
> debajo. La usan **las tres ramas de sueño**, y dos no miraban antes el frío:
> **al raso no se cogía frío en ninguna estación**, sólo cansancio. La
> pendiente está calibrada para que una madrugada de invierno al nivel del mar
> dé el `HEARTH_COLD_RISE` de siempre, así que el invierno de la cueva
> habitual no se ha movido; lo que sí se mueve es que **la altitud enfría** y
> que un abrigo alto coge frío también en otoño.
>
> **El frío cierra lo alto.** `Cumbres.motivo_del_frio`: sin un vestido por
> cada uno de la cordada no se sube adonde de madrugada se coge frío. Es la
> peletería como puerta, igual que la cuerda para una pared, y el roquedo de la
> spec resultó ser la ascensión, que es la única salida a lo alto modelada.
> **La puerta y el frío que castiga son la misma regla**, así que no pueden
> decir cosas distintas.
>
> **Es estricta a propósito, y tiene un precio que hay que conocer:** sin ropa
> se cierra todo en invierno y, en primavera, cualquier cosa por encima de
> 164 m. La banda empieza en primavera sin vestidos, así que **la primera
> ascensión espera al verano o a la peletería**. Se decidió así con esos
> números delante; la pasada larga dirá si retrasa la fase de más.

> **Y la nieve también sale de aquí** (2026-09-12). Era `Temporada.COTA_DE_NIEVE`,
> una fracción del relieve del mapa local, así que dependía del mapa y no del
> clima, y describía el mismo frío que el termómetro sin hablarse con él. Ahora
> es `Termometro.cota_de_hielo`: **la cota donde hiela de madrugada**, la misma
> hora que usa el frío de la gente. En el valle de partida nieva en invierno
> desde ~221 m —antes desde 357— y el resto del año no nieva.

**Por qué cruza las once épocas.** La temperatura ambiente no cambia de
naturaleza con la época: cambia con qué se responde a ella. Paravientos y piel
cosida aquí; casa de adobe, hogar cerrado, chimenea, estufa y vidrio en las
ventanas después. Es la misma magnitud leída por escaleras distintas, y hasta
que exista en grados ninguna de esas respuestas se puede calibrar contra nada.

**Qué se mide, y la única cifra que no se discute.** El gradiente vertical es el
**físico** —del orden de 0,65 °C por cada 100 m de cota—: no es una cifra de
balanceo y no se toca para que cuadre una partida. Lo demás sí se calibra, y con
grados en pantalla se puede: que mediodía de verano y noche de invierno no se
parezcan, que la cueva y el roquedo se lleven la diferencia que les toca por
altitud, y que dormir al raso en enero no sea lo mismo que en julio
(`Inhabitant.cold`). Y una regla de arquitectura: «¿cuántos grados hace aquí y
ahora?» se contesta **desde un solo sitio** —invariante 3 de SPECS.md §7—, porque
el hogar, el vivac, la ropa y la escalera térmica van a preguntarlo los cuatro.

---

---

## 20. La pasarela: una obra en un cruce, no un permiso

**Construida el 2026-09-13** (EPOCA_01 §10.1, tanda 3, frente 13). Antes,
aprender la técnica ponía `SettlementSim.has_bridge = true` y con eso se vadeaba
**cualquier** cauce del valle menos la mar abierta: dos troncos funcionaban como
un permiso sobre el mapa entero, y sobre el terreno no aparecía nada.

| | |
|---|---|
| La técnica | **Permite construir**, no abre nada por sí sola |
| Dónde | Lo elige **la banda**, no el jugador. Por este orden: **(1) hacia la parte del valle que no se alcanza** —la más grande, mirando la rejilla de caminos—; (2) **un vado de sus veredas (§18) que la crecida cierra**; (3) el cruce que más rodeo ahorra |
| Hasta qué ancho | **Dos celdas de la rejilla de caminos**, 80 m (la celda es de 40 m; aquí ponía «unos 16 m», que era falso). Decisión del usuario |
| Qué cuesta | **40 de leña y 6 jornadas-persona**. Decisión del usuario: el doble de lo que cuesta aprender la técnica |
| Qué abre | **Ese cruce, las cuatro estaciones**, que es lo que un vado no da |
| Cómo se pierde | Cuando la crecida de la estación que entra pasa **de lo que la pasarela salva** —calado 1,0, `Hydrography.tope_de_vado` con pasarela— en esa celda. **Sin sorteo** |

> **Corregido el 2026-09-14, a petición del usuario.** Se perdía cuando la
> crecida pasaba de `FORD_IMPASSABLE` (0,70), que es **el mismo umbral que cierra
> el vado**: la pasarela sólo sobrevivía donde el cauce no se cerraba nunca, o sea
> donde no hacía falta, y la riada se la llevaba justo la estación en que servía.
> Y la elección sólo miraba rodeos con el agua de hoy: un río que la banda cruza
> andando en verano no salía nunca, porque su vereda no rodea nada. Queja del
> usuario: «no se están construyendo pasarelas; gracias a ellas deberíamos tener
> acceso a todo el mapa».
| Se ven | En la ventana **Obras**, sección «Pasarelas de troncos»: las armadas, la que está en marcha con sus jornadas, y **por qué no hay ninguna** —sin técnica, sin cruce que valga, sin nadie explorando o sin leña— |
| Dónde vive | `Pasarelas` (`sim/`), `Navgrid._hay_pasarela`, `PasarelaView` (`vista/`), `PanelObras` (`ui/`) |

> **Corregido otra vez el 2026-09-14, con la queja repetida** —«creo que no se
> están construyendo pasarelas… gracias a ellas deberíamos tener acceso a todo el
> mapa»—, y esta vez la causa estaba **debajo** de la regla:
>
> - **Las dos reglas de antes se apoyaban en las veredas** (§18), y a la otra
>   orilla de un río que la banda no ha cruzado nunca **no hay vereda**: esa mitad
>   del valle no se abría jamás. Ahora lo primero que se mira es la rejilla de
>   caminos: desde la zona de casa, ¿hay otra zona al otro lado de dos celdas de
>   agua? De las que haya, la más grande. Lo comprueba `TestPasarela` con una
>   orilla sin vereda ninguna.
> - **Y rehacer la rejilla borra todas las veredas aprendidas**
>   (`Marcha.forget_routes` → `BandKnowledge.olvidar_veredas`), o sea **cada cambio
>   de estación y cada pasarela nueva**. Así que la regla del vado casi nunca tenía
>   veredas que mirar. Se deja dicho aquí y en §18: es de donde viene, en el fondo,
>   que no se construyeran. **Arreglado el mismo día** —las veredas ya duran el
>   año, §18—, así que la regla del vado vuelve a tener de dónde elegir. La primera versión de la regla nueva pedía la rejilla
>   con `sim.navgrid()` y **disparaba ese borrado el mismo día**; ahora lee la que
>   ya hay.
> - **No abre todo el valle**: lo que está al otro lado de un cauce de más de 80 m
>   —o de un acantilado— sigue sin abrirse, y la ventana de Obras lo dice.

> **Y la regla nueva salió con dos fallos, corregidos el mismo día** con dos
> quejas más del usuario. Los dos son del mismo sitio —`_hacia_lo_que_no_se_alcanza`—
> y conviene que queden escritos, porque los dos son de creerse una cifra por lo
> que parece decir su nombre:
>
> - **«Está construyendo pasarelas de troncos en el monte, no para cruzar los
>   ríos… las pasarelas son para ponerlas de vereda a vereda de ríos.»** El hueco
>   se buscaba con `cost <= Navgrid.BLOCKED`, y en la rejilla eso significa **«no
>   se pasa»**, no «hay agua»: un cantil cuenta igual que un cauce. Se armaban
>   pasarelas sobre roca seca. Ahora la celda tiene que llevar agua, preguntado
>   **al terreno y con el mismo criterio que la regla del vado**
>   (`crossing_difficulty_at` + `Hydrography.can_cross`). El intento intermedio
>   —`Navgrid.moja`— parecía lo suyo y no vale: se rinde y dice que no en cuanto
>   la rejilla no guarda la máscara de vados entera, y dejó tres pruebas en rojo
>   sin elegir ningún cruce.
> - **«Ha hecho una pasarela para cruzar el río pegado al borde del mapa, como a
>   3 km de la cueva. Deben estar cerca de la cueva, la clave es la
>   eficiencia.»** Se elegía la zona más grande del mapa estuviera donde
>   estuviera. Ahora se puntúa **lo que abre entre lo que cuesta llegar**, y no
>   se mira nada más allá de 1 500 m del abrigo —la escala en que la banda sale y
>   vuelve en el día—. `TestPasarela` cubre las dos con un cantil seco y un mapa
>   de dos ríos.

**Cómo elige el sitio, y por qué así.** La vereda que más se desvía de la línea
recta entre sus dos extremos es, por definición, la que rodea algo, y lo que se
rodea en un valle con río es el río. Se mira dónde corta esa recta el agua y se
cuentan las celdas seguidas. **No se mide rehaciendo la rejilla con la pasarela
puesta**: eso es hornear una rejilla por candidato —900 ms cada una— para
contestar la misma pregunta.

**Y la piragua monóxila salió del Paleolítico**: es del Mesolítico, y la trae
[EPOCA_02](EPOCA_02_MESOLITICO.md). La rama de exploración de esta época se
queda en la pasarela. **El arco, también**, a petición del usuario el mismo día:
la caza del Paleolítico termina en el propulsor, y los factores que el arco
daba a la caza (×1,70 menor, ×1,20 mayor) vuelven con él en el Mesolítico.

---

## 21. El hogar: cuidarlo va por delante de todo lo demás

El fuego se apaga por dos motivos y los dos son del diseño: que se acabe la leña
y que **no lo cuide nadie** —un hogar sin nadie encima se apaga en una noche, y
es lo que hace que el mínimo de gente en el oficio de Hogar signifique algo—.

Lo que estaba mal (2026-09-13): dentro de `Hogar._tend_camp`, **la obra en cola
iba por delante del fuego**. Quien llevaba el hogar se ponía con la obra antes
de mirarlo, y si a esa obra le faltaba material se pasaba la jornada esperándolo
sin hacer nada más. Dos consecuencias, y el usuario vio las dos: el fuego se
apagaba esa noche «teniendo leña» —porque nadie lo había cuidado— y no se volvía
a prender mientras la obra siguiera en cola, que podían ser días.

El orden es ahora:

1. **Prender, si está apagado.** Cuesta media jornada de alguien y leña
   (`HEARTH_RELIGHT_DAYS`, `HEARTH_RELIGHT_WOOD`), y no se hace nada más hasta
   conseguirlo: sin brasas no se ahúma, no se cura y no se trabaja de noche.
2. **Darlo por cuidado**, que es lo que impide que se apague esta noche. Echar
   un leño es un momento, así que no gasta la jornada.
3. Y después, lo demás: la obra en cola, el agua, la pintura, los heridos y el
   secadero.

Lo defienden `TestCampProjects.test_con_una_obra_parada_el_hogar_se_sigue_cuidando`
y `..._el_hogar_apagado_se_prende_primero`.

**Y la banda se junta alrededor** (`CorroDelHogar`): quien está en el abrigo sin
tajo en el monte —ocioso, comiendo, al hogar o tallando— se pone en uno de los
diez sitios de los cinco troncos que rodean la hoguera, y quien no coge sitio se
queda por la campa. Ver [GRAFICOS.md](GRAFICOS.md) §4.1.

---

## 22. Lo que el jugador prioriza: materiales, presas y la cola del taller

> **Spec (2026-09-14)**, de `/spec`. Petición del usuario: «tenemos que tener
> una forma de dar prioridad a los materiales, para que prioricen recoger unos
> sobre otros a elección del jugador; lo mismo con la manufactura y con la caza
> —priorizar conejos, o uros—. Quiero también ver la cola de producción y poder
> editarla».

**Qué hay hoy, y por qué no basta.** Las prioridades que existen son **de
persona y oficio**: quién recolecta, quién caza, quién talla. Dentro del oficio
no decide nadie:

- el recolector se trae **todo lo que hay en temporada** en su sitio, hasta
  llenar lo que carga, y el tope del almacén sólo le hace dejar en el monte lo
  que ya sobra;
- el cazador elige la pieza por **raciones entre distancia**, y ya está;
- el taller hace **la pieza menos cubierta** de lo que pide el trabajo, sin que
  se vea qué va a hacer después, y la meta del utillaje es un tope, no un
  encargo —decisión del 2026-09-13—.

Así que el jugador que necesita sílex para la talla laminar, o piel para el
invierno, no tiene más palanca que poner más gente: no puede decir **qué**.

### La prioridad

**Cada material, cada especie y cada tipo de pieza lleva un nivel**: **alta**,
**normal**, **baja** o **nunca**. Todo empieza en normal. Varios pueden compartir
nivel. Se guarda con la partida, por campamento —ver §23—.

**Materiales** —lo que recogen recolección, materia prima, pesca y marisqueo—.
Cambia dos cosas:

1. **Adónde va la gente.** Al elegir paraje, pesa lo que abunda de alta
   prioridad: entre dos sitios igual de alcanzables, se va al que tiene más de
   lo prioritario aunque tenga menos de lo demás. Lo que está en **nunca** no
   cuenta para elegir sitio.
2. **Qué entra primero en la carga.** Cuando no cabe todo, entra primero lo de
   alta, luego normal, luego baja. Lo de **nunca** se deja en el monte, igual que
   lo que tiene el tope lleno. Lo demás se sigue cogiendo si cabe: priorizar no
   es dejar de coger.

**Especies de caza.** La prioridad **manda sobre el valor de la pieza, dentro de
lo que tiene a su alcance**: de las piezas al alcance de la búsqueda, el cazador
va a por las de mayor nivel, y entre las de un mismo nivel elige como hoy, por
raciones y distancia. Así va a por el uro aunque haya un ciervo más cerca, pero
si no hay uro a su alcance caza otra cosa. Lo que está en **nunca** no se caza
aunque sea lo único que hay. No cambia adónde va a cazar.

**Piezas del taller.** Ordenan la parte automática de la cola, abajo.

### La cola del taller

**Una lista visible, y editable, de lo que se va a hacer y en qué orden.** Tiene
dos clases de entrada:

- **Encargos del jugador**: una pieza y una cantidad —«3 azagayas»—. Se hacen
  **aunque pasen de la meta del utillaje**: la meta sigue siendo un tope para lo
  automático, y un encargo es una orden. Se añaden, se reordenan y se quitan.
- **Lo que pide el trabajo**, marcado como automático: lo que hoy decide el
  taller por su cuenta. Se ordena por su nivel de prioridad y, dentro del mismo
  nivel, como hoy —lo menos cubierto primero—. **Subir o bajar una entrada
  automática cambia el nivel de prioridad de esa pieza; quitarla la pone en
  nunca.** Una sola palanca con dos puertas, no dos reglas.

**Los encargos van delante de lo automático.** El artesano coge **la primera
entrada que puede hacer**: la de su especialidad, con la técnica sabida, la
herramienta previa y la materia prima en el abrigo. Una entrada que no se puede
hacer **dice por qué** —falta aguja, falta hueso, nadie de peletería— y **no
para la cola**: se salta y se hace la siguiente. Un encargo cumplido desaparece.

Dónde se ven y se tocan las prioridades y la cola: [INTERFAZ.md](INTERFAZ.md) §4.

### Criterios de aceptación

- **Carga**: una persona en un sitio con avellana (alta) y baya (normal), con
  sitio para menos de lo que hay de las dos, vuelve con avellana hasta llenar y
  baya sólo en lo que sobre. Con la baya en nunca, vuelve sin baya aunque le
  quepa. Prueba.
- **Sitio**: con dos parajes igual de lejos, uno rico en sílex y otro en
  cuarcita, y el sílex en alta, el cantero elige el del sílex; con los dos en
  normal, el que elegía hoy. Prueba.
- **Caza**: con un uro y un ciervo a su alcance, el ciervo más cerca y con más
  raciones, y el uro en alta, se persigue el uro. Sin uro a su alcance, el
  ciervo. Con el ciervo en nunca y sólo ciervo a su alcance, no se persigue
  nada. Prueba sobre la elección de pieza.
- **Cola, orden**: con un encargo de 2 azagayas y la demanda automática de
  lascas, el astero hace primero las 2 azagayas; con el encargo cumplido, la
  entrada desaparece y siguen las automáticas. Prueba.
- **Cola, bloqueo**: un encargo de vestido sin aguja hecha aparece con su motivo
  y el peletero hace la siguiente entrada que sí puede. Prueba.
- **Cola, encargo sobre meta**: con la meta de azagayas cubierta, un encargo de
  3 azagayas saca 3 azagayas más. Prueba.
- **Cola, automático**: bajar una entrada automática la pone por detrás de las
  del nivel normal; quitarla deja esa pieza en nunca y no vuelve a aparecer
  mientras siga en nunca. Prueba.
- **Lo que se ve es lo que se hace**: durante 20 jornadas con encargos y
  prioridades puestos, la pieza que termina cada artesano es siempre la primera
  entrada de la cola que podía hacer en ese momento. Sonda que compara la cola
  pintada con lo terminado.
- **Nada cambia sin tocar nada**: con todo en normal y la cola sin encargos, la
  firma diaria de una partida con semilla fija es **la misma** que antes de este
  trabajo durante 10 jornadas.
- Las prioridades y los encargos **sobreviven a guardar y cargar**.

### Fuera de alcance

- **Prioridad de oficios o de personas**: ya existe, y no se toca.
- **Prioridades del hogar y de la exploración**: no recogen material.
- **Qué especie cae en las trampas** y en la red de aves: no se elige la presa.
- **Encargos con fecha** («para el invierno») o repetidos («siempre 5»): un
  encargo es una cantidad y se acaba.
- **Cambiar cuánto rinde nada**: esto elige qué, no cuánto.

### Plan técnico

> `/plan-tarea` del 2026-09-14, contrastado contra `scripts/`. Tareas en
> [ROADMAP.md](ROADMAP.md) «En curso». Lo que al implementar se caiga de aquí
> se corrige aquí.

**Dónde decide hoy cada cosa**, que es donde entra la prioridad:

| Regla | Dónde está | Qué hace hoy |
|---|---|---|
| Carga | `Tajo._fill_the_basket` | Recorre la tabla de rendimientos en su orden y mete cada material mientras quepa, **tick a tick**. Con eso sólo, ordenar el recorrido no basta: en cada tick entra un poco de todo, y al llenarse el zurrón va mezclado |
| Sitio | `Tajo._rank_known_spots` → `_best_known_spot` | Puntúa por abundancia **de la actividad**, sin distinguir material; se reordena una vez al día y se queda con los veinte mejores |
| Presa | `Caceria._pick_quarry` | `Fauna.rations_of / distancia^0,35` entre lo que hay a `Hunt.BUSCA_PIEZA_M` |
| Pieza | `Taller._next_piece(especialidad)` | La menos cubierta de `SettlementSim.SPECIALITY_MAKES` con demanda, técnica, herramienta previa y materia prima, por debajo de `RESERVA_UTILLAJE`; la usan `_craft`, `crafting_now`, `_workshop_short` y `SettlementSim._speciality_can_work` |
| A quién se manda al taller | `Reparto._speciality_pressure` | La peor cobertura de lo que hace la especialidad |

**Módulos afectados.**

1. **`scripts/sim/Prioridades.gd`, nuevo.** `RefCounted` sin referencia al
   simulador: `enum Nivel { ALTA, NORMAL, BAJA, NUNCA }` y tres diccionarios
   —material (`Materia.Kind`), especie (`String` de `Fauna.SPECIES`), pieza
   (`Tool.Kind`)— que **sólo guardan lo que no es normal**. Lo tiene
   `SettlementSim.prioridades`, **una instancia por simulación y nada
   estático**: así §23 se lo lleva con cada campamento sin tocarlo. No da pasos,
   no emite señales y no pide azar: no le aplica ningún contrato de §3 de
   SPECS salvo el de guardarse, que sale solo del recorrido de `Instantanea`.
   El jugador lo toca por `SettlementSim` (fachada), porque cambiar un nivel de
   material tiene que reordenar los sitios (`tajo._rank_known_spots()`).
2. **`Tajo._fill_the_basket`, la carga.** Con todo en normal, **el mismo
   recorrido de hoy, sin tocar**. Con algún nivel puesto: se recorre por nivel
   —empate, el orden de la tabla—, lo de nunca se salta como lo que tiene el
   tope lleno, y **cuando no cabe algo de un nivel, se descarga lo que la
   persona lleva de un nivel más bajo** hasta hacerle sitio. Es lo que hace
   verdad «vuelve con avellana hasta llenar y baya sólo en lo que sobre».
3. **`Tajo._rank_known_spots`, el sitio.** La puntuación de cada sitio con
   paraje se multiplica por un **peso por nivel** de lo que el paraje tiene:
   `Σ abundancia × peso(nivel) / Σ abundancia`, sólo sobre lo que la banda
   **sabe** que hay (`Paraje.sabidos`) —lo no averiguado no se usa para elegir,
   igual que `Paraje.listing` no delata lo bueno—. Monte sin paraje, o sin nada
   sabido, pesa 1. Todo en normal da 1 en todas partes. No se aplica a la caza:
   la especie no cambia adónde se va.
4. **`Caceria._pick_quarry`, la presa.** Fuera lo de nunca; de lo que queda,
   gana el nivel más alto, y dentro del nivel la cuenta de hoy.
5. **`Taller`, la cola.** `encargos: Array[Dictionary]` (`tool`, `faltan`), en
   orden, con `encargar`, `mover_encargo` y `quitar_encargo`. **`cola(especialidad
   := -1)` es la única función que construye la lista**: los encargos en su
   orden y detrás lo automático —demanda mayor que cero, técnica sabida,
   cobertura bajo `RESERVA_UTILLAJE`, nivel distinto de nunca— ordenado por
   nivel, cobertura y posición en `SPECIALITY_MAKES`. Esa última clave es
   explícita porque `sort_custom` no es estable, y es la que reproduce el
   desempate de hoy. Cada entrada lleva su `motivo` si no se puede hacer (falta
   la herramienta previa, falta un material) y quién la hará. **`_next_piece`
   pasa a ser «la primera entrada sin motivo de `cola(especialidad)`»**, así que
   `_craft`, `crafting_now`, `_workshop_short` y `_speciality_can_work` ven la
   cola sin tocarse; y la ventana pinta `cola()`. `_craft` no mira la reserva
   cuando la pieza es de un encargo, y al terminarla le resta una.
6. **`Reparto._speciality_pressure`.** Un encargo que se puede hacer pone la
   presión de su especialidad a cero —si no, con la meta cubierta nadie iría al
   taller a hacerlo—, y las piezas en nunca no cuentan para la peor cobertura.
   Sin encargos y todo en normal, la cuenta de hoy.
7. **Ventanas** ([INTERFAZ.md](INTERFAZ.md) §4): el nivel en la fila de
   `PanelAlmacen._material_row`, sólo en lo que se recoge; las especies en
   `PanelTrabajos._speciality_picker` cuando el oficio es la caza —no hay
   ventana de caza—, con las del valle (`WildlifeHerds`) y apagadas con
   `Fauna.weapon_missing` las que no se pueden cazar; y **`PanelTaller`**, nuevo,
   con su botón en la barra de `GameUI`. Las tres leen el estado y llaman a la
   fachada: la vista no guarda niveles propios (SPECS §4.7).

**Decisiones que la spec obliga a tomar**, las dos **del usuario, 2026-09-14**:

- **El peso de cada nivel al elegir sitio**: **×2 lo alto, ×1 lo normal, ×0,5 lo
  bajo, ×0 lo de nunca.** Es un empujón y no una orden: el sitio con lo
  prioritario gana a uno mediano, pero un paraje el doble de rico en lo demás
  todavía puede ganarle. Es una decisión, no una medida —no hay corrida previa
  de la que saliera—.
- **Lo que se descarga del zurrón vuelve al paraje**, como si no se hubiera
  cogido: se le devuelve lo que se le restó y el libro de trabajo no lo apunta.
  Es lo más cercano al «se deja en el monte» de la spec.

Y una que la spec no contempla y se resuelve aquí: **quitar una entrada
automática la deja en nunca, y hay que poder sacarla de ahí**. La ventana Taller
lleva al pie una línea de «apartadas» con las piezas en nunca y un botón para
devolverlas a normal; sin eso, quitar una entrada sería irreversible desde la
única ventana donde se quita.

**Orden de dependencias.**

1. **La firma de antes, lo primero y sin tocar un `.gd`**: diez jornadas con
   semilla fija sobre el árbol de hoy. Después ya no se puede sacar.
2. `Prioridades` y su sitio en `SettlementSim`: lo leen todas las demás.
3. Presa, carga y sitio no dependen entre sí.
4. La cola antes que el reparto, y las dos antes que `PanelTaller`.
5. El guardado se comprueba con todo el estado ya puesto.

**Riesgos técnicos.**

- **La firma cambia aunque la partida no.** `Instantanea` recorre por reflexión,
  así que tres diccionarios vacíos nuevos cambian el SHA desde la jornada cero.
  «Nada cambia sin tocar nada» se comprueba con `Cotejo` **ignorando esos
  campos**; si `Cotejo` no sabe ignorar, se le enseña, y se dice.
- **Coste de la cola.** `_next_piece` se pregunta mucho —`crafting_now` para la
  chapa de cada artesano, `_craft` en cada paso— y ya hoy llama a
  `tool_demand()`, que construye un diccionario, dentro de un bucle. Por eso
  `cola` admite especialidad y sólo construye esa. Si el F3 enseña al taller, se
  mide antes de optimizar.
- **Guardados de antes.** Un fichero sin estos campos tiene que cargar con todo
  en normal y sin encargos; si `Instantanea.volcar` no lo tolera, se sube la
  versión de `Guardado` y se dice.
- **Deuda heredada, no se toca**: `craft_progress` es de la persona y no de la
  pieza, así que al saltar a un encargo el progreso de la anterior se lo lleva
  la nueva. Pasa hoy igual cuando cambia la pieza menos cubierta.

### Cómo quedó (2026-09-14)

Construido y en verde. Lo que hace el juego hoy:

| Regla | Dónde vive | Qué hace |
|---|---|---|
| Los niveles | `Prioridades` (`sim/`), colgado de `SettlementSim.prioridades` | Material, especie y pieza; **sólo se guarda lo que no es normal**, y `hay_algo_puesto()` es el interruptor del camino de siempre. Se toca por `fijar_prioridad_material/especie/pieza`, y el de material reordena los parajes ahí mismo |
| La carga | `Tajo._por_prioridad` y `Tajo._soltar_lo_de_menos_nivel` | Se recorre por nivel, lo de nunca se deja en el monte, y cuando no cabe algo de un nivel se suelta lo de nivel inferior que ya se llevaba. **Lo soltado vuelve al paraje** (`ResourceField.give_back_to_cell`): se le devuelve lo que se le restó y el libro de trabajo no lo apunta |
| El sitio | `Tajo._peso_de_prioridad` | Pesa la puntuación del paraje con `Σ abundancia × peso / Σ abundancia` sobre **lo que la banda sabe** que hay ahí. Uno si no hay prioridades, si el monte no tiene paraje, o si es caza |
| La presa | `Caceria._pick_quarry` | El nivel va aparte de la puntuación: manda, pero sólo entre lo que hay a su alcance. Lo de nunca no se caza aunque sea lo único |
| La cola | `Taller.cola_de_trabajo(especialidad)` | **La única lista**: encargos delante en su orden, automáticas detrás por nivel, cobertura y orden de `SPECIALITY_MAKES`. `_next_piece` es «la primera sin motivo», así que el artesano y la ventana miran lo mismo |
| Los encargos | `Taller.encargos`, `encargar_pieza`, `mover_encargo`, `quitar_encargo` | Se hacen **aunque pasen de la meta** —la meta es un tope de lo automático—, y al cumplirse desaparecen |
| Quién va al taller | `Reparto._speciality_pressure` | Un encargo hacedero pone la presión a cero; lo apartado no cuenta para la peor cobertura |

Lo que se ve y se toca, en [INTERFAZ.md](INTERFAZ.md) §4. Y dos cosas que sólo
se saben por haberlo construido:

- **Los nombres de método de una fachada son globales de hecho.**
  `tools/LlamadasHuerfanas.gd` casa por nombre, así que `cola` y `encargar`
  —que ya eran del horno de rejillas y del Wayfinder— daban cinco huérfanas
  falsas. Pasaron a `cola_de_trabajo` y `encargar_pieza`.
- **El desempate de la cola se escribe.** `sort_custom` no es estable, y al
  empezar la partida media docena de piezas están a cobertura cero: sin la
  clave del orden de `SPECIALITY_MAKES`, dos corridas con la misma semilla
  dejarían de dar la misma partida (SPECS §3.3).

---

## 23. Varios campamentos, migrar, y la partida que no se mira

> **Spec (2026-09-14)**, de `/spec`. Petición del usuario: «sistema para
> migración y simulación cuando estamos fuera», y en el segundo `/depurar` del
> mismo día: «sería mejor que continúen simulando mientras estoy en otro mapa».
> Sustituye a la visita con el reloj parado, que se dejó como arreglo mínimo.

**Qué hay hoy.** La banda vive en **un** mapa, el primero. Entrar en otro es una
visita sin gente y **con el reloj parado**: si corriera, al volver la banda
estaría en otra fecha que el mundo. Y **nada simula lo que no se está mirando**:
la simulación de la banda depende de la escena, que se destruye al cambiar de
mapa. Por eso no se puede migrar, ni mirar otro valle mientras la banda vive.

**Esto cambia tres decisiones escritas**, y lo dice aquí para que no queden dos
reglas: la de **una sola banda en un mapa** —SPECS §6.4, del 2026-09-14—, la de
**varias bandas vivas a la vez, fuera de alcance** —INTERFAZ §7.5 y SPECS §6.4— y
la **visita con el reloj parado** —SPECS §6.4—.

### Lo que se pide

1. **Campamentos.** La partida empieza con uno, en el primer mapa. Un
   campamento es un mapa con gente, con su propia despensa, utillaje, obras,
   parajes, prioridades y cola del taller (§22). **No hay tope de campamentos.**
2. **Migrar.** El jugador elige **quién sale** de un campamento y **a qué sitio
   descubierto** va. Salen por el borde del mapa cargando lo que pueden —la
   misma regla del traslado dentro del valle—, viajan **las jornadas que salgan
   de la distancia y el relieve**, con la marcha de la expedición, gastan
   raciones por persona y jornada y pueden tener percances por el camino. Al
   llegar:
   - a un mapa **sin campamento**, lo fundan;
   - a uno **abandonado**, lo vuelven a ocupar con todo lo que se dejó;
   - a uno **con gente**, se suman a él.
3. **Mover gente entre campamentos, cuando se quiera**, con la misma regla: se
   elige quién y adónde, y viaja. Mientras viaja no está en ningún campamento.
4. **Todo lo que tiene gente se simula siempre**, se mire o no: **la misma
   simulación**, sin dibujar, al mismo reloj. Lo que no se mira no es una cuenta
   resumida: al entrar, el campamento está exactamente como si se hubiera
   estado mirando.
5. **Una sola fecha para toda la partida.** Todos los campamentos, los que
   viajan y los mapas de visita van al mismo reloj; la velocidad y la pausa son
   de todos. **La noche se acelera cuando no trabaja nadie en ningún
   campamento**; los que viajan no la frenan.
6. **Un campamento sin gente queda abandonado**: conserva su estado —obras,
   almacén, parajes— y no se simula hasta que alguien vuelva.
7. **Las decisiones de cualquier campamento salen igual**, con el nombre del
   campamento en la tarjeta: se para el reloj de todos y se decide desde donde
   se esté. Los avisos sin decisión van a la crónica con el nombre del
   campamento.
8. **Cambiar de campamento**: desde el mapa regional se entra en cualquiera, y
   dentro del juego una **lista de campamentos** —gente, estado, alerta— salta
   directo a otro sin pasar por el regional. Ver [INTERFAZ.md](INTERFAZ.md) §4.
9. **La visita** es entrar en un mapa sin campamento: sin gente, **con el reloj
   corriendo**, y con la niebla de §4.

### Criterios de aceptación

- **Lo que no se mira es la misma partida**: con semilla fija, un campamento
  simulado 10 jornadas sin dibujar mientras se mira otro mapa da **la misma
  firma diaria**, jornada a jornada, que el mismo campamento mirado esas 10
  jornadas. Sonda de cotejo, dos corridas.
- **La fecha es una**: tras 5 jornadas mirando el campamento B, el campamento A
  y los viajeros están en la misma jornada y hora que B. Prueba.
- **Migrar cuesta**: un grupo que migra a un sitio a distancia D tarda las
  jornadas que salen de D y del relieve, gasta raciones por persona y jornada
  del campamento de origen y llega con lo que cargó. Prueba con un sitio puesto a
  mano; y dos destinos a distinta distancia tardan distinto.
- **Llegar funda, reocupa o suma**: las tres, cada una con su prueba —en la de
  reocupar, las obras y el almacén que se dejaron están—.
- **Un campamento vaciado** se guarda y no gasta simulación: su jornada no avanza
  ni cambia su estado mientras está vacío. Prueba.
- **Decisiones de otro campamento**: una decisión levantada en un campamento que
  no se mira para el reloj de todos y sale con su nombre. Prueba.
- **La noche**: con un campamento durmiendo y otro con alguien trabajando, no se
  acelera; con los dos durmiendo, sí. Prueba.
- **Guardar y cargar** una partida con dos campamentos y un grupo de viaje:
  vuelven los dos y el grupo sigue en su jornada de camino. Prueba de ida y
  vuelta.
- **El coste se mide y se escribe**: lo que cuesta cada campamento simulado sin
  dibujar, en milisegundos por jornada de juego y en fotograma, con 1, 2 y 4
  campamentos, en [ESTADO.md](ESTADO.md). **No hay tope**, pero la cifra tiene
  que estar: sin ella no se sabe cuándo la partida empieza a ir lenta.

### Fuera de alcance

- **Bandas de IA** o gente que no sea del jugador en los campamentos.
- **Caminos entre mapas** que se construyan, o viajes con varios tramos: se va
  de un campamento o sitio a otro.
- **Comercio entre campamentos** más allá de lo que carga quien viaja.
- **Una cuenta resumida** para campamentos lejanos o muchos a la vez: se decidió
  simular siempre de verdad.
- **Cambiar la simulación** de un campamento: se ejecuta la que hay, fuera de la
  pantalla.

### Plan técnico

> `/plan-tarea` del 2026-09-14, contrastado contra `scripts/`. Tareas en
> [ROADMAP.md](ROADMAP.md) «En curso». Lo que al implementar se caiga de aquí se
> corrige aquí.

**Lo que hay hoy en el código, que es lo que manda el plan.**

| Hecho | Dónde | Por qué importa |
|---|---|---|
| **La partida es de la escena.** `SettlementSim`, `TerrainGenerator`, `WildlifeHerds`, `ResourceField` y las `CaveMouth` son nodos de `DemoMain`, y `change_scene_to_file` los destruye | `DemoMain._start_settlement` y `_levantar_*` | Lo que no se mira no puede seguir vivo si vive en la escena. Hoy sólo sobrevive en disco (`Guardado`) |
| **La escena todavía decide partida.** `_check_discoveries` descubre cuevas y escribe en la crónica, `_on_tecnica_aprendida` llama a `sim.tell_technique`, `_on_campamento_trasladado` reelige tajos | `DemoMain`, colgado de `hour_passed`, `tecnica_aprendida` y el traslado | Un campamento que no se mira dejaría de descubrir, de contar técnicas y de elegir tajos: **otra partida**, y la firma lo delataría |
| **El reloj es de cada simulación.** Cada `SettlementSim` lleva su `day`, `hour`, `_pendiente`, `time_scale` y su noche acelerada | `SettlementSim._process` | Dos simulaciones con su propio `_process` se desincronizan en cuanto una salta la noche y la otra no |
| **La estación y el año son globales y los avanza cada simulación** | `SettlementSim._advance_local_season` escribe `GameState.season` y `GameState.year` | Con dos campamentos, la primavera llegaría dos veces |
| **La fauna ya va en el paso fijo**: con partida, el fotograma sólo pinta | `WildlifeHerds._process` → `avanzar` desde el paso | Bien: dejar de dibujar no cambia la caza |
| **El terreno construye malla y agua dentro de `generate`** | `TerrainGenerator.generate` → `malla._create_terrain_mesh`, `_create_water` | No hay hoy un modo «sólo datos»: un campamento sin mirar arrastra su malla, y la memoria es el riesgo gordo |
| **Viajar fuera del mapa no depende de la distancia**: la expedición está fuera `JORNADAS_FUERA := 12` | `Expedicion` | «Las jornadas que salgan de la distancia y el relieve» no tiene hoy regla ninguna que reutilizar |
| **El guardado ya es por mapa**, con `sitio_<n>.sav` y la partida como carpeta | `Guardado`, `Partidas` | Varios campamentos caben: un fichero cada uno, más lo que es de la partida |

**Módulos afectados.**

1. **`scripts/region/Campamentos.gd`, nuevo — el registro.** `static var` con los
   campamentos vivos, cada uno un `Node3D` **colgado de la raíz del árbol y no de
   la escena**, con su terreno, campo, fauna, cuevas y simulación dentro. Así
   sobreviven a `change_scene_to_file`. **Cambia el contrato de SPECS §2.2 y
   §6.4, y se declara**: no es un autoload —nada en `project.godot`—, pero sí es
   estado que vive fuera de las escenas, y SPECS dice que eso va en estáticas con
   su porqué. Aquí la estática es sólo el índice; los nodos cuelgan de la raíz
   porque un `Node` que simula necesita estar en el árbol.
2. **`scripts/sim/Campamento.gd`, nuevo — un mapa con gente.** Lo que hoy monta
   `DemoMain._start_settlement` **sin la vista**: terreno, campo, fauna, cuevas,
   simulación y el cableado de §2.3. Y la lógica de partida que hoy está en la
   escena —descubrir cuevas, contar técnicas, reelegir tajos— **se muda aquí**,
   para que corra se mire o no. Contrato: construye, no dibuja; `DemoMain`
   pasa a ser la **vista** de un campamento, no su dueño.
3. **`scripts/sim/RelojDeLaPartida.gd`, nuevo — una sola fecha.** Da los pasos de
   `PASO_FIJO` **a todos los campamentos por igual** en cada fotograma, lleva
   `time_scale` y la pausa de todos, decide la noche acelerada con
   `nadie_trabaja` de **todos**, y gira estación y año **una vez**.
   `SettlementSim._process` deja de dar pasos por su cuenta; `_advance` y el
   contrato de §3.1 y §3.2 no cambian —mismo tamaño de paso, mismas señales—.
   `_advance_local_season` deja de escribir `GameState` y lo pide al reloj.
4. **`scripts/sim/Viaje.gd`, nuevo — los que están en camino.** Un grupo con sus
   personas, lo que carga, origen, destino y jornada de llegada; avanza por
   jornadas del reloj, no por pasos, porque fuera del mapa no hay monte que
   simular. Al llegar llama a `Campamentos` para **fundar, reocupar o sumar**.
5. **`Expedicion` y `Traslado`**, lo que se reutiliza: la salida por la puerta
   del valle (`Expedicion.puerta_del_valle`) y cargar lo que cabe (`Traslado._cargar`).
   No se copian: se llaman.
6. **`Guardado` y `Partidas`**: un `sitio_<n>.sav` por campamento, abandonados
   incluidos, y en la cabecera de la partida **los viajes y la fecha**. Se sube
   `Guardado.VERSION`: un fichero de una sola banda se sigue abriendo como
   partida de un campamento.
7. **`GameUI` y `BarraSuperior`**: las decisiones se escuchan de **todos** los
   campamentos y paran el reloj de la partida, con el nombre del campamento en la
   tarjeta. Las ventanas de INTERFAZ §4 —lista de campamentos, ficha para migrar y
   mover gente— son un panel nuevo, `PanelCampamentos`.
8. **`RegionMap`**: entrar en un mapa con campamento es mirarlo; sin campamento,
   una visita **con el reloj corriendo**. `Expedition.visita` y
   `DemoMain._montar_la_visita` dejan de parar el reloj.

**Decisiones del usuario (2026-09-14).**

- **Se hace la fase 1 y se para en la puerta**: sacar el campamento de la escena,
  el reloj único y dos campamentos vivos, y enseñar la firma y el coste antes de
  construir la migración encima.
- **Las jornadas de viaje salen del andar de siempre**: se recorre el relieve
  regional con el mismo coste por metro del valle (`Traversal.pace_fraction`) y
  las horas útiles de una jornada. No se inventa una cifra de kilómetros.
- **Los percances del camino son un riesgo propio del viaje**, no el de la caza:
  una probabilidad por persona y jornada de camino. **Decidido al llegar a la
  fase 2 (2026-09-14)**: la misma cuenta que una jornada de expedición
  (`Mishap.chance`) —4 % de base, ×2,2 si el tramo del día es canchal o roca,
  ×1,8 con cansancio—; se llega herido, no se muere.
- **El valle de destino se prepara al mandar el viaje** (2026-09-14): si su
  relieve fino no está horneado, la ficha lo descarga y lo hornea antes de
  confirmar, como fundar hoy. Al llegar, el campamento se monta sin red.
- **Las tareas 7 a 16, todas seguidas** (2026-09-14).
- **Se miden las tres corridas** de la puerta: 1, 2 y 4 campamentos.

**Orden de dependencias.**

1. **Primero, medir si cabe** —la recomendación del ROADMAP, y es la puerta del
   resto—: sacar `Campamento` de `DemoMain`, el reloj único, y **dos campamentos
   vivos a la vez**, uno mirado y otro no. Con eso se miden la firma (el criterio
   de «lo que no se mira es la misma partida») y el coste con 1, 2 y 4. Si un
   campamento sin mirar cuesta lo que hoy cuesta la escena entera, **se para y se
   pregunta** antes de construir migración encima.
2. Después, el viaje y la llegada.
3. Después, guardar y cargar con varios campamentos y viajes.
4. Al final, las ventanas y la visita con el reloj corriendo.

**Lo que cambió al implementarlo (2026-09-14).**

- **Había una cuarta cosa de partida en la escena**: `_on_dia_para_el_paisaje`
  fijaba el caudal del río junto a la nieve y el color. Va al campamento.
- **La tarea 3 cupo en la 2**: mudar la lógica de partida era parte de sacar el
  campamento, y la firma igual la cubre.
- **La pausa no tiene dueño aparte.** La interfaz y las decisiones siguen tocando
  la velocidad de una simulación, y el reloj adopta lo que cambie en cualquiera.
  Así la barra de arriba no se entera de que hay varios.
- **La estación se gira con una marca, no con un contador.** `gira_la_estacion`
  la tiene sólo el primer campamento del reloj; los demás hacen lo suyo con la
  estación ya girada. **Deuda para la fase 2**: esto supone que todos cumplen
  estación la misma jornada, y un campamento fundado a mitad de estación
  llevaría su `season_day` desfasado. Al fundar, `season_day` tiene que salir de
  la fecha de la partida.
- **`DemoMain` todavía monta su propio campamento como hijo**: mirar un
  campamento que ya existe —entrar desde el regional o desde la lista— necesita
  montar la vista sobre un campamento ya montado, y eso es la tarea 14. Para la
  puerta basta la sonda, que monta campamentos sin vista colgados de la raíz.
- **En la suite no hay árbol** (`Engine.get_main_loop()` es nulo mientras corre
  el `_init` de `RunTests`), así que lo que necesita la raíz —el registro, el
  cambio de escena— se comprueba en `CampamentosProbe`, no en una prueba.
- **La sonda reproduce a `TironAnualProbe` paso a paso**, incluida la resolución
  del relieve que pone la escena (825, no el 513 del script): comparar contra
  otro instrumento es comparar dos partidas (§22).

- **La vista decidía partida en un sitio más, y lo cazó la firma**:
  `Cumbres._find_peaks()` es perezoso y la primera vez apunta en la crónica «hay
  un alto que nadie sabe cómo subir». Lo llamaba primero el alfiler de cima al
  montar la escena; sin escena, nadie en diez jornadas. Ahora lo llama el
  campamento (`mirar_las_cumbres`) en el mismo momento.
- **Y el reloj tenía que respetar la pausa del arranque**: `setup` deja la
  simulación parada, y el primer `dirigir` le ponía la velocidad del reloj.
- **`dirigido` y `gira_la_estacion` no entran en la firma** (`Instantanea.FUERA`):
  son cómo se lleva el reloj, y con ellas dentro un campamento mirado y el mismo
  sin mirar darían firmas distintas siempre.

- **La puerta dio que la partida es la misma y que la CPU no cabe** (ESTADO §2):
  memoria ~130 MB por campamento, pero cada uno es una simulación entera en un
  solo núcleo, y a ×5 no caben dos. Quitar lo que sobraba —el agua de la casa
  recordada, no pintar cuerpos sin mirar— dio un 8 %. **El riesgo de la memoria
  resultó no ser el gordo; el gordo es la CPU.**

**Riesgos técnicos.**

- **La memoria.** La sonda anual marca 1,3 GB de RAM con un mapa; la malla, el
  agua y la colisión se construyen dentro de `generate`. Si cuatro campamentos
  son cuatro veces eso, «no hay tope» choca con la máquina. La fase 1 lo mide;
  si hace falta un `generate` sin malla para lo que no se mira, es una tarea
  nueva y se dice.
- **Construir un mapa tarda segundos** (`terrain.generate` con caché), y fundar al
  llegar lo haría a mitad de partida: un tirón. Se mide en la misma corrida.
- **Todo lo que la escena hace por la partida** hay que encontrarlo. Hay tres
  localizados; puede haber más, y la firma de dos corridas es lo que los caza.
- **Las decisiones** se levantan desde dentro de un paso y la interfaz para el
  reloj ahí mismo (SPECS §4.6). Con el reloj único, parar a todos a mitad de la
  vuelta de campamentos tiene que cortar igual que hoy corta a mitad de fotograma.
- **La visita con niebla** (punto 9) depende de la spec de la niebla de §4, que
  no está hecha: aquí la visita corre el reloj y se ve como hoy.
- **Deuda heredada**: `GameState.home`, `population` y `food` son de una sola
  banda. Con varios campamentos dejan de tener sentido como globales; se
  retiran donde estorben, y lo que los lea se apunta.

### Plan técnico: un hilo por campamento

> `/plan-tarea`, 2026-09-14, **decisión del usuario tras la puerta**: la partida
> sin mirar es la misma, pero cada campamento es una simulación entera en un
> solo núcleo y a ×5 no caben dos (ESTADO §2). Con doce núcleos, la salida que
> cumple «no hay tope» es que cada campamento dé su paso en su hilo. **Aún sin
> código**: esto es lo que hay que resolver antes.

**Decisiones del usuario (2026-09-14)**: se hacen las tareas 1b-1 a 1b-4 —sacar
del paso lo compartido, con el reloj todavía en serie— y se para antes de meter
hilos; y **las decisiones se contestan en la barrera entre pasos**, aunque cambie
la partida de las sondas, porque es lo que hace un jugador.

**La regla que lo hace posible, y la que se rompería en silencio.** Un paso en
paralelo sólo da la misma partida si **nada de lo que hace un campamento en su
paso lo lee ni lo escribe otro**. GDScript no avisa de una carrera: dos
campamentos que se pisan un número dan partidas que no se repiten, y la firma es
lo único que lo ve.

**Lo que hoy comparte un paso con otros**, buscado en `scripts/`:

| Qué | Dónde | Por qué rompe | Qué se hace |
|---|---|---|---|
| **La estación y el año** | `GameState.season` (64 lecturas en la simulación) y `year` (12); los escribe `_advance_local_season` | Un campamento lee la estación mientras otro la gira | Cada simulación lleva **su copia** (`sim.estacion`, `sim.anyo`) y la gira ella; el reloj publica la del primero en `GameState` **entre pasos** |
| **El presupuesto de caminos** | `Wayfinder.last_nodes`, estático que escribe cada búsqueda y que `Marcha` suma a `_path_nodes_this_frame` | **Decide partida**: con ese número se corta el buscar caminos en el paso, y otro campamento lo pisaría | La búsqueda devuelve sus nodos; nada de estático |
| **Lo descubierto de la comarca** | `GameState.discover` desde `Expedicion` | Un diccionario compartido escrito desde dos hilos | Se apunta en el campamento y el reloj lo junta entre pasos, en orden |
| `GameState.last_report` | `_advance_local_season` | Idem | Por campamento |
| **Las señales del paso** | `day_passed`, `hour_passed`, `paso_cerrado`, `season_changed`, `moment_raised`, `tecnica_aprendida`, `campamento_trasladado` | Quien las escucha corre **en el hilo del paso**: la vista, la interfaz y la barra no pueden | Las del campamento (`Campamento`) siguen en su hilo, que es el suyo; las de vista van diferidas al hilo principal |
| **Las decisiones** | `moment_raised` → `BarraSuperior` | La barra encola en una lista compartida, y las sondas contestan dentro del paso | Se encolan por campamento y se entregan **en la barrera entre pasos**, en orden de campamento. Es lo que hace un jugador, que nunca contesta a mitad de paso; **cambia el instrumento** y la firma de referencia se toma de nuevo con contestación en la barrera |
| **La malla de la fauna al nacer** | `Poblaciones` → `WildlifeHerds.nacer` → `_spawn`, dentro del paso | Toca un nodo del árbol desde otro hilo | Verificar si añade instancias a la malla; si sí, diferirlo |
| **Los cuerpos pintados** | `_pintar_a` | Malla de la multitud | Sólo en el campamento que se mira (`se_mira`), y ése en el hilo principal |
| **El cepo** | `Cronometro.tramo`/`cierra`, estáticos | Diccionarios compartidos | No cuenta fuera del hilo principal; el coste por campamento lo mide el reloj |
| Contadores de diagnóstico | `Wayfinder.busquedas` | Sólo los lee `AtascoProbe` | Por instancia, o se aceptan perdidos y se dice |

**Módulos afectados.** `SettlementSim` y los 64 sitios que leen la estación
(sustitución mecánica), `Wayfinder` y `Marcha` (el presupuesto de caminos),
`Expedicion` (descubrir), `RelojDeLaPartida` (el paso en paralelo con
`WorkerThreadPool.add_group_task` y la barrera), `Campamento` (las señales),
`BarraSuperior` (las decisiones en la barrera), `WildlifeHerds` (nacer),
`Cronometro`. Contrato nuevo en SPECS §3: **nada de lo que corre en un paso toca
el árbol de escena ni un estático**, con su invariante en §7.

**Orden de dependencias.**

1. **Primero lo que no necesita hilos**: sacar del paso todo lo compartido —la
   estación por campamento, el presupuesto de caminos, descubrir, la barra en la
   barrera—, **con el reloj todavía en serie**. Cada cambio se coteja con un
   campamento: la partida no puede moverse. La contestación en la barrera sí la
   mueve, y por eso la firma de referencia se toma otra vez justo ahí.
2. Después, el reloj en paralelo con un interruptor, para poder cotejar el mismo
   código **en serie y en paralelo**.
3. Y la comprobación que caza las carreras: **dos corridas en paralelo del mismo
   código tienen que dar la misma firma**, y las dos la de en serie.

**Riesgos.**

- **Las carreras no dan error.** Una que se escape da partidas que casi se
  repiten; por eso el cotejo es de dos corridas en paralelo, no de una.
- **El árbol de escena**: los campamentos cuelgan de él para que les llegue
  `_process`, pero el paso sólo lee datos suyos. Godot no garantiza leer un nodo
  del árbol desde otro hilo; si da problemas, los campamentos que no se miran
  salen del árbol y los mueve sólo el reloj.
- **Puede escalar menos de lo que parece**: GDScript crea y suelta muchos
  `Variant` y diccionarios por tick, y el reparto de memoria entre hilos tiene
  su coste. La ganancia se mide, no se supone.
- **Se hereda**: `GameState.home` sigue siendo de una sola banda (fase 2).

**Lo que salió al hacerlo (2026-09-14).**

- **La salida del árbol no era un plan B: era la única.** La primera corrida en
  paralelo con los campamentos dentro del árbol dio 46 000 errores de Godot y
  ninguna firma. Fuera del árbol, cero.
- **La carrera que se temía no existe; lo que había era `exp`.** Dos corridas en
  paralelo coincidían entre sí; lo que no coincidía con la serie era el último bit
  de `exp` y `pow`, que dependen del hilo. Con `Calculo`, serie y paralelo dan la
  misma firma en los dos campamentos. Y eso vale también para lo que pide §23: el
  campamento que se mira da su paso en el hilo principal y los demás en el pool.
- **Lo que queda de la fase 1b**: `Huella` y los ayudantes estáticos de nombres de
  `Parajes` leen la estación global, sin carrera porque sólo cambia en el giro,
  que va en serie. La malla de la fauna al nacer se toca desde el pool a través
  del `RenderingServer`, que admite hilos; en diez jornadas no dio ni un error.

### Cómo quedó: migrar, varios campamentos y la visita con reloj (fases 2 a 4, 2026-09-14)

**El viaje** (`Viaje`). Las jornadas salen de recorrer la recta sobre el relieve
regional a tramos de 250 m, con el andar de Tobler de `Traversal.pace_fraction`,
la carga y 11 horas útiles por jornada. Las raciones de todo el camino se cobran
**al salir**, y `Viaje.lo_que_cuesta` es la misma cuenta que se enseña antes de
confirmar. Por jornada, cada persona tira `Mishap.chance` con el suelo más duro
del tramo del día —decisión del usuario—, con un azar propio sembrado por
partida, jornada, destino y grupo, que no pide tiradas al de ningún campamento.
**Se llega herido, no se muere.** Mientras viaja, el grupo no está en ningún
campamento: sale de uno con `SettlementSim.despedir` y entra en el otro con
`recibir`, con ids nuevos y lo que carga a la despensa.

**Llegar** (`Campamentos._llegar`). Con gente, **se suman**; vacío, **se
reocupa** con todo lo que se dejó; sin campamento, **se funda**:
`Campamento.montar` levanta el valle sin vista, en la fecha de la partida, y lo da
de alta sin mirar. Reocupar y fundar ponen el campamento en la jornada, la hora y
el **día de estación** del reloj (`Campamentos.a_la_fecha`): sin el día de
estación giraría la estación en otra jornada que los demás. No estaba en el plan.

**El campamento vacío** no da pasos. Si todos van de camino, la fecha la lleva el
reloj solo (`RelojDeLaPartida._andar_la_fecha_sola`).

**Las decisiones** llevan su origen (`Moment.desde`); con más de un campamento la
tarjeta dice de cuál. Los avisos de uno que no se mira van a la crónica del que se
mira, con su nombre. Una decisión que sale sin interfaz delante —en el mapa
regional— **para la partida** y se enseña al entrar en cualquier mapa
(`Campamentos.sin_ver`). **Efecto a saber**: la firma cuenta las entradas de la
crónica, así que la del campamento que se mira depende de los avisos de los otros;
la crónica no la lee ninguna regla.

**La escena adopta, no monta.** Entrar en un mapa con campamento vivo lo mete en
la escena y le pone la vista encima (`DemoMain._montar_el_campamento`); montar
otro sería una segunda simulación del mismo valle. Al irse, la escena guarda la
partida y lo suelta (`_dejar_la_escena`), y sigue simulando fuera del árbol. Se
entra desde el mapa regional o se salta desde la lista de campamentos
(`Campamentos.traspaso_de`). **La visita, con campamentos vivos, va con el reloj**:
su simulación sin gente la toma el reloj —los botones de velocidad mueven la
partida— y copia la fecha en cada fotograma.

**Guardar** es guardar la partida: un `sitio_<n>.sav` por campamento y
`partida.sav` con la fecha y los grupos de camino. El contrato, en
[SPECS.md](SPECS.md) §6.4. Las personas de un grupo se guardan en una instantánea
de una simulación de paso: `Instantanea` recorre simulaciones y un grupo no está
en ninguna.

**Preparar el valle** salió del mapa regional a `PreparaValle`, que usan el mapa,
la ficha de mover gente y `RehacerSitio`: una sola receta para los tres.

**Lo que salió al hacerlo.**

- `Campamento.montar` **pisaba el traspaso de la escena** (`Expedition`): fundar
  con el jugador mirando otro mapa le cambiaba el relieve con el que luego se
  guardaba. Ahora lo devuelve como estaba, y cada campamento guarda su relieve y
  su recuadro.
- **Fundar bloquea el fotograma** lo que tarda en montarse un valle: medido en
  `MigracionProbe`, 16,6 s de `terrain.generate` y 1,6 s de la rejilla de
  navegación en esta máquina y sin ventana, más lo que no se cronometra. Pasa una
  vez por campamento nuevo, en la barrera de la jornada.

**Deuda que queda, dicha.**

- **Se sale sin andar hasta el borde del valle**: el grupo desaparece del
  campamento al mandarlo y aparece en el otro al llegar.
- **Fundar al llegar bloquea** el fotograma (arriba). Troceado en varios
  fotogramas o en otro hilo, es trabajo aparte.
- **Tras cerrar el juego, los campamentos vuelven al entrar en el mapa de la
  banda**, no al abrir el mapa regional: una visita antes de eso sigue con el
  reloj parado, como antes de esta spec.
- **El mapa regional no enseña la decisión pendiente**: la partida se para y la
  tarjeta sale al entrar en un mapa.
- `Huella` y los ayudantes estáticos de nombres de `Parajes` leen la estación
  global; `GameState.home` sigue siendo una sola cueva.

