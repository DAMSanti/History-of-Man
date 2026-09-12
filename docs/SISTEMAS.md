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
| [§16](#16-el-curtido-de-piel) | El curtido de piel |
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

---

## 5. El comercio, de la concha de lejos al mercado nacional

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

## 13. Lo que se cuenta, y lo que se pinta

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
se pinta ni despacio ni deprisa. Y el taller no hace lámparas antes de saber
pintar: nadie ahueca un canto para tener luz dentro de la cueva antes de tener
algo que hacer dentro de la cueva.

**Lo que NO levanta relato**, y por qué: el bautizo de un paraje. Un relato es un
`Moment`, o sea el reloj parado, y si cada sitio con nombre parara la partida a
preguntar si se pinta, en dos estaciones el jugador aprendería a cerrar la
tarjeta sin leerla. **Se pinta lo que pasa pocas veces**: una caza mayor, una
cumbre, una técnica.

---

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

## 16. El curtido de piel

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

**Lo que cambia:** curtir deja de ser una frase de sabor y pasa a competir
por el tiempo del peletero y por el ocre y la grasa del almacén — los
mismos materiales que ya usa la pintura parietal, así que el ocre deja de
ser sólo cosa del arte.

---

## 17. El agua: odres, y por qué llenar uno puede ser una salida

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

---

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
