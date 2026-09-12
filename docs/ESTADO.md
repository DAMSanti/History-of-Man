# Estado de la slice del Paleolítico

Qué hace hoy el juego, qué le falta para ser jugable y qué cambiaría. Todo lo
que se afirma aquí está medido con sondas del repositorio, y se dice con cuál.

Contrasta con [archivo/SLICE_PALEOLITICO.md](archivo/SLICE_PALEOLITICO.md), que es lo que el
proyecto dijo que iba a construir.

---

## Dónde mirar

Todo lo que se afirma aquí está medido con una sonda del repositorio, y se dice
con cuál.

| Si buscas… | Ve a |
|---|---|
| **El estado de la partida en una página**, con el año medido | **§1** |
| Por qué un recolector alimenta a siete y un cazador no se alimenta ni a sí mismo | §2 |
| Por qué la caza mayor no llega en un año (la cadena de prerrequisitos) | §2, «Por qué la caza da 0,27» |
| **Qué sistemas están sólidos, y con qué sonda se comprobó** | **§3** |
| Qué pide el diseño y no existe | §4 |
| **Qué haría por orden**, con lo ya hecho tachado | **§5** |
| El agotamiento de la pesca y por qué la banda no se muda | §5, «Segundo» |
| Los atascos, los tirones y lo que costó quitarlos | §5, «Cuarto: depurar» |
| Qué cambiaría de fidelidad histórica (el arco, la bellota, el perro) | §6 |
| Qué falta para poder jugarlo | §7 |

Las tareas vivas no están aquí: están en [ROADMAP.md](ROADMAP.md) «En curso».

---

## 1. Resumen en una página

**Lo que está montado es mucho y es bueno.** Hay un valle de relieve real con
hidrografía derivada, una banda de quince personas con pericia que crece y se
transmite de noche, catorce oficios con sus especialidades, un árbol de veinte
técnicas que se aprenden practicando, cacería por fases —acecho, persecución,
lance, despiece, acarreo— sobre fauna que de verdad anda por el mapa, líneas de
trampas y de nasas, meteorología, estaciones con su efecto real, y una crónica
que lo cuenta.

**Y con todo eso, no se puede perder.** Un año completo con el reparto por
defecto, medido con `scripts/tests/AnoProbe.gd`:

| día | estación | gente | despensa | días de comida | heridos | técnicas |
|---|---|---|---|---|---|---|
| 1 | Primavera | 15 | 160 | 6,3 | 0 | 1 |
| 46 | Verano | 15 | 2 380 | 93,7 | 0 | 3 |
| 91 | Otoño | 15 | 2 927 | 115,2 | 0 | 3 |
| 136 | Invierno | 15 | 3 067 | **120,7** | 0 | 5 |

La despensa sube de 6 a 120 días de comida y no baja nunca. **El otoño no se
distingue del verano y el invierno no cuesta nada**, que es justo lo contrario
de lo que dice el documento de diseño: *«el otoño decide si sobrevives al
invierno»*.

Nadie se hiere en 180 días. Nadie nace, nadie muere, nadie envejece. Se
aprenden 5 técnicas de 20 en un año.

**El juego está construido. La partida no.**

> **Hecho (2026-09-11).** Ver [QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md).
> La tabla de arriba ya no describe la partida actual. Un año completo de
> 180 jornadas, misma banda de quince y reparto por defecto, corrido esta
> vez hasta el cierre (`TironAnualProbe.gd`, semilla 123):
>
> | día | estación | gente | despensa | leña |
> |---|---|---|---|---|
> | 1 | Primavera | 15 | 84 | 24 |
> | 46 | Verano | 15 | **502** (pico) | **105** (pico) |
> | 86 | Otoño | **8** | 37 | 33 |
> | 136 | Invierno | 8 | 555 | 32 |
> | **180** | **Invierno (cierre)** | **8** | 113 | **5** |
>
> El día 86, con la despensa en cero varios días seguidos, mueren de hambre
> Anda, Beru, Caro, Duna, Eiga, Fusto y Gala — los cinco niños y los dos
> ancianos de la banda, ids 0 a 6 de `Inhabitant.create_band`. Los ocho
> adultos pasan la misma hambruna y sobreviven. Del pico de verano al cierre
> del invierno la leña cae un 95 %. Quince al empezar, ocho al terminar, y
> la crónica dice por qué: **ya se puede perder.**

---

## 2. El hallazgo central: la caza está cerrada con llave

**Aviso sobre las cifras anteriores.** La versión previa de esta sección daba
una tabla de «lo que produjo la banda en 45 jornadas» que estaba mal:
`produced_days` es una **ventana rodante de 30 días** (`CONSUMO_DIAS`), y
`AnoProbe` la sumaba al final creyendo que era la partida entera y luego dividía
entre 180. Además el divisor contaba a quien tenía el oficio **al final**, no
las jornadas-persona trabajadas. Las dos sondas están arregladas —se apunta cada
jornada al cerrarse— y lo que sigue sale de la contabilidad nueva.

Un año entero, 4 recolectores · 3 cazadores · 2 pescadores y el resto repartido
entre hogar y taller (`BandaProbe`):

| oficio | jornadas-persona | raciones | % | por persona y día |
|---|---|---|---|---|
| **Recolección** | 716 | **10 232** | 93 % | **14,29** |
| Ribera | 358 | 639 | 6 % | 1,79 |
| **Caza** | 537 | **147** | 1 % | **0,27** |

Lo que entró, por material: fruto seco 6 306 raciones, raíz 2 066, bellota 741,
pescado 639, baya 399, grasa 236, miel 204, caracol 186, **carne 147**, huevo 68,
seta 27. Por estación: primavera 2 231, verano 3 656, **otoño 4 397, invierno
735**.

**Un recolector alimenta a siete personas; un cazador no se alimenta ni a sí
mismo.** Eso sigue siendo la partida.

**Re-medido el 2026-09-12, después de los tres arreglos de `/depurar`** (el asta
que no se entregaba, la caza menor que pedía una azagaya imposible, y el rodeo
del río que era el recargo por riesgo). `SEMILLA=42 DIAS=95 BANDA=4,3,2` sobre
`AnoProbe`, o sea 95 jornadas y no un año: la tabla de arriba, de un año entero,
no se sustituye con ésta sino que se pone al lado.

| oficio | jornadas-persona | raciones | por persona y día |
|---|---|---|---|
| **Ribera** | 192 | **4 558** | **23,74** |
| Recolección | 384 | 5 495 | 14,31 |
| **Caza** | 288 | **283** | **0,98** |

Una persona come **1,69 raciones al día**.

**La caza ha pasado de 0,27 a 0,98 y sigue sin alimentar a quien la hace**: tres
veces y media más, y aún así un cazador no llega a lo que come. La cadena de
prerrequisitos de abajo explica por qué, y el arreglo de la azagaya abrió la
puerta sin cambiar el resultado: en 95 jornadas se saben **5 técnicas de 20**.

**Y la ribera es ahora el oficio que más rinde**, con una caída estacional que
sigue ahí y es la que `archivo/SECADERO_Y_RIO.md` perseguía:

| estación | raciones | jornadas-persona | por día | parajes |
|---|---|---|---|---|
| Primavera | 3 731 | 90 | **41,45** | 5 |
| Verano | 504 | 90 | **5,60** | 4 |
| Otoño | 324 | 12 | 26,97 | 3 |

De 41,45 a 5,60 es **−86,5 % con el mismo número de pescadores**, y el reparto
del día lo señala: en primavera el pescador se pasa el **36,2 %** de la jornada
en «sin sitio» y el 14,1 % reconociendo, y en verano eso baja a 2,1 % y 0,8 %
mientras el tiempo trabajando sube del 21,9 % al 37,2 %. O sea que **trabaja más
y saca mucho menos**: la caída no es de acceso al sitio, es de rendimiento del
sitio.

### Por qué la caza da 0,27

No es calibración. Es una **cadena de prerrequisitos**:

```
Tech.AZAGAYA → needs Tech.HOJA → needs Tech.NUCLEO → needs Tech.LASCA
```

`AZAGAYA` se practica cazando (140 jornadas) pero cuelga de `HOJA`, que se
practica en **manufactura** (110 jornadas). En el año medido se aprendieron
Lazo, Cepo, Red de aves, Foso y Núcleo preparado: **nunca llegó la talla
laminar, así que nunca llegó la azagaya, así que no hubo caza mayor en todo el
año**. Los tres cazadores vivieron de trampas y acabaron con dos azagayas de un
utillaje que ni siquiera sabían diseñar.

Una banda con uno o dos en el taller no llega a la caza mayor en un año de
partida. Ése es el nudo, y está antes de cualquier número de rendimiento.

> **Medido de cerca (2026-09-12, `ArbolPasoProbe`, 60 jornadas), y el nudo no
> era el que este párrafo decía.** Dos correcciones y un hallazgo:
>
> - **Las jornadas no se suman.** `NUCLEO` y `HOJA` comparten el contador de
>   manufactura —`progress` es `days_in(oficio) / days`—, así que la espina no
>   son 155 jornadas sino **110**, las de la laminar.
> - **El material no frenaba nada.** Con 2 038 de cuarcita en el almacén,
>   **cero** técnicas paradas por material: el núcleo preparado pasó **61
>   jornadas de 61** frenado por jornadas. La causa que parecía invisible
>   —`_ir_pagando` deteniendo el progreso— no se estaba dando.
> - **Lo que manda es la gente en el oficio.** El reloj de una técnica es
>   literalmente *una jornada por persona que salió a trabajar de eso*. Con el
>   reparto por defecto la manufactura corre a **0,62 jornadas/día** —o sea,
>   menos de un artesano, y saliendo el 62 % de los días— y la laminar cae
>   hacia el **día 177**. Con el taller ocupado va a **2,00/día** y el núcleo se
>   aprende hacia el **día 26**.
>
> Y de ahí el arreglo que sí tocaba: **el panel no decía cuál de las tres
> puertas estaba cerrada**. Un «82 %» que no se mueve no distingue «faltan
> jornadas de manufactura» de «falta asta», y son dos decisiones opuestas. Ver
> [INTERFAZ.md](INTERFAZ.md) §4 y `TechTree.freno`.

### El rodeo del río era el miedo, no el agua

**Arreglado el 2026-09-12 (`/depurar`).** Queja: «empezamos en primavera con el
río sin vadear y todos los que van a un paraje de la otra orilla dan el mismo
rodeo largo hacia el oeste hasta un vado; cuando llega el verano y el río sí se
vadea, siguen haciendo el mismo rodeo».

**No era ninguna de las tres cosas que parecía.** El horno de rejillas termina
la rejilla de la estación que se le pide antes de devolverla, los caminos
guardados se tiran en cada cambio de rejilla, y el destino no se hereda: las
tres comprobadas. Y el rodeo **no rodeaba un río**. Coste de una celda en el
sitio 56, medido con `RodeoProbe`:

| | coste |
|---|---|
| Prado llano | 1,0 |
| Ladera de 26° | 4,8 |
| Vado, con el agua por la rodilla | **20** |
| Canchal a 49° | hasta **587** |

Cruzar el río era de lo barato. Lo caro era la ladera, y de esas 587 sólo 58
son el **tiempo** que de verdad se tarda: el resto era el recargo por riesgo,
que multiplicaba sin tope. Como el trazado minimiza coste, cambiaba cientos de
metros de camino por no pisar cuarenta de cuesta.

**Y por eso se veía en verano.** Es cuando bajan los ríos y se abren 98 celdas
de vado —comprobado que ninguna es agua honda—, y con ellas aparecen recorridos
por el llano que en primavera no existían.

Los mismos 213 trayectos, antes y después de poner tope al miedo
(`Navgrid.RIESGO_MAXIMO`, que **es** `Marcha.RODEO_QUE_SE_ANDA`):

| | antes | después |
|---|---|---|
| Rodeo medio, primavera / otoño / invierno | x1,24 | **x1,18** |
| Rodeo medio, verano | x2,40 | **x1,43** |
| Los mismos 213 trayectos en verano | x2,50 | **x1,31** |
| Trayectos que empeoran al llegar el verano | 84 | **25** |
| Sitios admitidos por la regla del rodeo y andados **por encima** de ella | 88 | **1** |
| Sitios con camino en verano | 281 de 282 | 281 de 282 |

**Lo segundo que se arregló, y venía de lo mismo.** La regla del rodeo se
comprobaba sobre el camino más corto **en metros** y el viaje se hacía por el
más barato **en esfuerzo**: dos Dijkstra, dos caminos, y de ahí los 88. Ahora es
uno solo —`Wayfinder.metros_desde` acumula los metros sobre el árbol que
construye— y encima se ahorra un Dijkstra por estación. El segundo se había
puesto para tapar que «44 parajes de 182 se volvían inalcanzables el día que
baja el río»; con el coste arreglado eso **no vuelve**: los sitios alcanzables
en primavera siguen siendo 213 de 282, los mismos que antes.

**Lo que sigue abierto.** Queda 1 sitio de 282 que se admite y se anda por
encima de x2,5, y el rodeo de verano sigue por encima del de las otras tres
estaciones (x1,43 contra x1,18). Es pequeño y ya no se ve, pero no es cero.

### 🔴 El taller se para solo hacia la jornada 31

**Sin arreglar. Encontrado el 2026-09-12 buscando otra cosa**, y es la causa de
verdad de que la talla laminar no llegue. Medido con `ArbolPasoProbe`, 60
jornadas, con gente puesta a mano en el taller (`MANU=1`):

| jornada | jornadas de manufactura acumuladas | cuarcita en el almacén |
|---|---|---|
| 11 | 20 | 59 |
| 21 | 40 | 111 |
| 31 | **60** | 100 |
| 41 | 62 | 96 |
| 51 | 64 | **1 203** |
| 61 | 67 | **3 054** |

**Corre a 2,00 jornadas/día treinta días y luego se cae a 0,3**, y no se
recupera. No es falta de material: en esas mismas jornadas la cuarcita pasa de
96 a 3 054, o sea que la banda se fue al canchal y no volvió al taller. Con esa
caída la laminar (110 jornadas) no llega ni en un año, que es exactamente lo
que midió §2 desde fuera.

**Bajar las jornadas de la talla laminar taparía esto**, y por eso no se
tocaron: con el taller parándose en la jornada 31, cualquier cifra nueva
tampoco se alcanza, y el síntoma vuelve con la siguiente técnica de
manufactura.

**Y el 2026-09-12 se diagnosticó, y no es un fallo: el taller ha terminado su
trabajo.** Medido con `TestTaller.gd`, que **construye** el estado de la
jornada 31 en vez de simularlo —utillaje lítico cubierto y 3 054 de piedra en
el almacén, la cifra de la jornada 61 de la tabla de arriba—:

- `Taller._next_piece(TALLA)` devuelve **−1**. La demanda natural de utillaje
  —`tool_natural_demand`: LASCA `gente/2`, RAEDERA 2, BURIL 2, PUNTA 2— es
  **fija y pequeña**, y cubierta a `RESERVA_UTILLAJE` (1,3) no deja nada que
  tallar. Con 3 054 de piedra delante.
- `_speciality_can_work(TALLA)` es `_next_piece(...) >= 0`, o sea **false**, y
  `Reparto.apply_priorities` manda entonces al artesano a su siguiente oficio.
  **Eso es deliberado y está comentado en `Reparto.gd`**: «el artesano se va a
  su siguiente oficio en vez de quedarse el día entero delante de un banco
  vacío». La cuarcita del almacén es la consecuencia, no la causa.
- **No es falta de material**: con el almacén así, `_workshop_short` dice que
  no falta nada. La sospecha que había aquí escrita —que el fallo estuviera en
  `SettlementSim.gd:2388`, el recado del artesano— **queda descartada**.
- Y el taller **vuelve** cuando la cobertura baja: con el utillaje gastado,
  `_next_piece` da pieza otra vez.

**Cómo hay que leer la tabla de arriba, entonces:** 2,00 jornadas/día son el
transitorio de equipar a una banda que empieza con dos puntas, y 0,3 es el
**régimen permanente de reposición**. El problema no es que el taller se pare:
es que **el régimen permanente no da para la práctica que el árbol exige** —110
jornadas de talla laminar a 0,3/día son más de un año de partida—. Eso es
balanceo, y la decisión de qué se toca está abierta.

### Lo que se arregló del bucle de la azagaya

2026-09-12, por `/depurar`. **Ninguna de estas cifras está re-medida todavía**:
lo que sigue es qué puertas se abrieron, no cuánto subió la caza. El 0,27 de
arriba sigue siendo la última medida buena, y volver a medirlo es trabajo de la
spec de [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md) §10.1, que lo pide al
cerrar la fase: **la cifra nueva se escribe aquí**, que es la única copia.

- **El asta se podía buscar y no se entregaba.** `Parajes.MATERIA_PRIMA_POOL`
  reserva cuatro papeletas de quince para el desmogadero, y ninguna tabla de
  rendimiento de materia prima daba asta: se iba y se volvía vacío. Medido: 11
  parajes bautizados en 60 jornadas y **0 anunciando asta**. Ahora el asta está
  en los extras de recolección y de materia prima, y `Tajo.ASTA_DE_DESMOGUE` es
  la única cifra —la usan el recolector, el cantero y la materia prima sin
  especialidad—.
- **La caza menor pedía la azagaya que no se podía aprender.** Sin tendón no se
  aprende la azagaya y el tendón sale de la caza; `Fauna` ya decía que al corzo
  se le entra con lanza de mano y `SPECIALITY_TOOL` decía que no. Ahora pide
  `PUNTA`.
- **El utillaje inicial llevaba dos azagayas** que la banda no sabría reponer.
  Van dos puntas líticas, y `SettlementSim.UTILLAJE_INICIAL` tiene prueba de que
  nada de la lista pide técnica.

### Y el otro hallazgo: se tira más de lo que se come

La banda produjo **11 018 raciones y se comió 4 572**. La despensa se queda
clavada en 937 durante otoño e invierno temprano porque **no cabe más**: con el
tope por recipientes (ver §5.11), más de la mitad del trabajo de los recolectores
se pierde en la puerta. El mecanismo limita como debe; lo que está descalibrado
es la recolección, que produce el doble de lo que la banda puede comer *y*
guardar.

Los cestos son la mitad de esa cifra: **7,53 raciones/día sin taller, 14,29 con
seis cestos**. Es el multiplicador declarado de `Tool.Kind.CESTO`.

### La línea base del fotograma malo, para la tanda 1

**Medida el 2026-09-12** con `PicoProbe` —`VEL=5 DIAS=4 LIMITE=100`, **con
ventana**— antes de tocar nada de la tanda 1 del Paleolítico (EPOCA_01 §10.1).
Existe porque **el cepo mide reloj de pared**: las cifras de SPECS.md §6.1 son
de otra corrida y otra máquina, y sin una medida propia del día no hay contra
qué comparar el re-medido.

| | |
|---|---|
| Cuadros vistos por el cepo | 2 329 en 90 s |
| Fotograma medio | **38,6 ms** |
| Peor fotograma | **112,8 ms** |
| Tirones de más de 100 ms | **1** en 2 330 cuadros |

**Y el único tirón es el cierre de jornada**, no el dibujo: día 1 a las 23:58,
113 ms de los que 97 son `simulacion (SettlementSim)` y 42 `cierre de jornada`.
El motor —pintar y física— pone 8 ms de esos 113. O sea que el fotograma malo
de esta partida es **contabilidad diaria**, y sale una vez al día.

Es la cifra contra la que se compara la noche acelerada (tarea M4 de ROADMAP
«En curso» → Tanda 1), en la misma máquina y con la misma sonda.

> **Un defecto del informe de la sonda, apuntado y no arreglado:** su línea
> «SIN MARCAR» sale en negativo (−265 ms, −235 %) porque suma tramos que están
> **anidados** unos dentro de otros —`paso de simulacion` va dentro de
> `simulacion (SettlementSim)`—, así que el total de la suma pasa del tirón. No
> afecta a las cuatro cifras de la tabla, que las da el cepo y no esa suma.

### La vereda por destino no sale, y por qué: medido

**Medido el 2026-09-12** con `AtascoProbe`, **`SEMILLA=42`**, 8 jornadas, sitio
56, al construir las veredas de EPOCA_01 §10.1, frente 1. Es un hallazgo contra
la spec: **lo que ésta pedía —«se guarda por destino», no por trayecto— no
funciona**, y el motivo es geométrico.

| clave de la memoria de caminos | pasos que el terreno corta con camino trazado | atascos |
|---|---|---|
| Sin memoria: se busca siempre | **10** | 0 |
| **Par origen-destino** (lo que ya había) | **17** | 1 |
| **Par, con enganche y remate catados** (lo que queda) | **33** | 0 |
| Sólo el destino, remate sin catar | **803** | 3 |
| Sólo el destino, enganche y remate catados | **2 295** | 2 |

**Por qué el destino solo no puede funcionar.** Con el par, quien reutiliza la
vereda está siempre dentro del cubo de origen —setenta metros como mucho del
primer hito—, así que el tramo de enganche es corto. Con la clave por destino
quien la reutiliza puede estar a kilómetros, y el enganche pasa a ser una recta
larguísima que ninguna cata razonable cubre: `Wayfinder.linea_limpia` mira el
eje cada veinte metros, y **lo que se anda no es el eje** —cada persona va por
su carril, hasta `SettlementSim.LANE_SPREAD` al lado—. Se intentó catar más
fino y con el ancho del carril, y la sonda pasó de 48 segundos a más de diez
minutos: la comprobación sale más cara que la búsqueda que ahorraba.

**Lo que sí se queda: los dos extremos se catan.** Una vereda tiene dos tramos
que antes no miraba nadie —de la persona al primer hito, y del último hito al
punto exacto al que va—. Catarlos cuesta 33 pasos cortados contra 17, y a
cambio deja los atascos en 0 y baja la proporción de caminos que no merecen
andarse (1,36 % contra 1,51 %), con más reuso: 5 868 caminos entregados contra
4 645.

> **Y el aviso que vale más que la tabla: estas cifras son las SEGUNDAS.**
>
> Las primeras se tomaron **sin fijar la semilla**, y son basura. `SettlementSim`
> siembra con el reloj si nadie le pasa `SEMILLA=` —lo dice su propio comentario,
> que avisa exactamente de esto— así que cada corrida era una partida distinta:
> el mismo código, sin tocar una línea, dio 2 200, 1 747, 303 y 219 pasos
> cortados en cuatro corridas seguidas. Con `SEMILLA=42` da 2 295 dos veces
> seguidas, exacto.
>
> Sobre esas cifras sin semilla se llegó a concluir —y se escribió aquí— que el
> remate sin catar multiplicaba los pasos cortados por 18 y que el afinado de
> veredas empeoraba el andar. **Ninguna de las dos conclusiones se sostiene**:
> eran ruido. La regla está en ARQUITECTURA.md §5.1.

### Lo que las veredas ahorran: el 39 % de las búsquedas

**Medido el 2026-09-12** con `AtascoProbe`, `SEMILLA=42`, 8 jornadas, sitio 56.
Es la mitad del frente 1 que la spec mandaba medir aparte —«que no se busque de
cero»— y, retirado el afinado (C3), es **lo único que el frente entrega**.

| | búsquedas completas por jornada | caminos entregados sin buscar | pasos cortados |
|---|---|---|---|
| Sin memoria de veredas | **265,8** | 1 108 | 10 |
| Con memoria de veredas | **161,1** | 4 579 | 33 |

Las cuenta `Wayfinder.busquedas`, **dentro de `find`** y no en quien llama: todo
el que busca pasa por ahí, y un contador que se puede rodear no cuenta nada.

**La salvedad:** apagar la memoria cambia los caminos y con ellos la partida, así
que las dos corridas no andan exactamente los mismos trayectos aunque compartan
semilla. La comparación es por jornada y sobre el mismo arranque, no trayecto a
trayecto.

**Y el rodeo sigue donde estaba**: x1,18 en primavera y x1,43 en verano. Nada de
esta tanda lo ha tocado, porque lo que iba a bajarlo era el afinado de veredas y
se retiró.

### La noche acelerada no cambia la partida: 60 jornadas cotejadas

**Medido el 2026-09-12.** Dos corridas de `TironAnualProbe` de 60 jornadas a
`VEL=5`, misma semilla, una con la noche acelerada y otra con `NOCHE=0`, cada
una escribiendo la firma de cada jornada; `Cotejo` las compara.

```
en común: 60 jornadas
IGUALES: las 60 jornadas en común, de la 2 a la 61, tienen la misma firma
```

Y de paso, el reloj: **18 min 51 s acelerando contra 24 min 21 s sin acelerar,
un 22,6 % menos**. Es menos que el 31 % medido con ventana, y tiene explicación:
esto es `--headless` —no hay nada que dibujar, así que el fotograma pesa menos y
saltárselo ahorra menos— y además cada jornada paga una instantánea completa por
reflexión, que cuesta igual en las dos ramas.

> **Un aviso de método que costó hora y media, y que está en ARQUITECTURA.md
> §5.1:** la primera pasada de esta comprobación dijo que las firmas se
> separaban en la jornada 26. **No era cierto**: se lanzó a las 18:38 y, mientras
> corría, se cambiaron tres cosas de la propia noche —la condición de entrada,
> el presupuesto por cuadro y el corte al cerrar la jornada—. Aquella corrida no
> comparaba dos configuraciones sino **dos versiones del código**. Con el código
> final, idénticas. Una sonda larga es una foto del árbol de trabajo en el
> momento de lanzarla.

### La noche se salta: el 31 % del reloj

**Medido el 2026-09-12** con `PicoProbe`, `VEL=5`, 4 jornadas, **con ventana** y
**en la misma sesión** que su línea base —el cepo mide reloj de pared y dos
sesiones no se comparan—. EPOCA_01 §10.1, tanda 1, frente 2.

| | reloj de 4 jornadas | fotograma medio | tirones >100 ms |
|---|---|---|---|
| Sin saltarse la noche | **90 s** | 38,5 ms | 1 |
| Con «todos duermen» | 71 s | 40,4 ms | 2 |
| **Con «nadie trabaja»** | **62 s** | 41,0 ms | **1** |

**La condición de entrada valía más que el dial.** Se construyó primero con la
lectura estricta —todos en `DURMIENDO`— y el usuario lo probó en el juego y dijo
que la noche seguía yendo lenta. Subir el presupuesto de fotograma no arreglaba
nada (8 ms → 24 ms, 71 s → 70 s): lo que frenaba era que **la banda no se
acuesta a la vez**, y el que volvía andando del monte bloqueaba la aceleración
esa hora larga. La spec decía «cuando nadie está trabajando» desde el
principio; la lectura estricta era del plan, no de la spec.

**El presupuesto, barrido y medido** (con «nadie trabaja»):

| `MS_DE_NOCHE_POR_CUADRO` | 4 | **8** | 16 | 24 | 48 | 96 |
|---|---|---|---|---|---|---|
| reloj de 4 jornadas | 66 s | **62 s** | 62 s | 60 s | 59 s | 58 s |
| fotograma medio | 39,9 | **41,0** | 41,4 | 42,5 | 45,1 | 46,7 |
| tirones >100 ms | 1 | **1** | 1 | 2 | 14 | 70 |

El ahorro se agota en 8 ms. De ahí en adelante se compran uno o dos segundos y
se paga en fotograma medio; pasados los 24, en tirones.

**Y la partida no cambia**, que es la mitad que de verdad importa: acelerar es
dar **más pasos del mismo tamaño**, no pasos más largos, así que la sucesión de
`_advance` es idéntica. `PASO_FIJO`, `time_scale` y `Engine.time_scale` no se
tocan. Comprobado con `Cotejo` sobre las firmas diarias de la misma semilla con
y sin acelerar.

> **Un aviso sobre el «peor fotograma», y vale para cualquiera que lo use aquí:
> no se puede leer de una sola corrida.** Es **una muestra suelta**, el máximo
> de un solo evento, y el cepo mide reloj de pared. En configuraciones que
> ahorran exactamente lo mismo dio 117, 122, 124, 125,7, 138,8, 144,9 y
> 146,1 ms; con el presupuesto **más pequeño** de todos (4 ms) dio 144,9, que
> mecánicamente no tiene sentido.
>
> Por eso el criterio «el peor fotograma no empeora» de EPOCA_01 §10.1 frente 4
> **queda sin poder darse por cumplido con lo medido aquí**. Lo que sí se
> sostiene es el **recuento de tirones**, que es un agregado y no un máximo: se
> queda en 1, igual que la línea base. Quien quiera comparar peores fotogramas
> necesita varias corridas y una mediana, no una cifra.

## 3. Lo que está construido y funciona

Para no perderlo de vista mientras se habla de lo que falta.

| sistema | estado | comprobado con |
|---|---|---|
| Relieve real (IGN 5 m) y region de Cantabria | sólido | `RejillaProbe`, `DatosProbe` |
| Hidrografía y vadeo | sólido | `TestHydrography`, `TestFording` |
| Trazado de caminos y marcha por carriles | sólido | `MarchaProbe`, `TestWayfinder` |
| Pericia que crece practicando y se transmite de noche | sólido | `TestTeaching` |
| Cacería por fases sobre fauna viva | sólido, mal calibrado | `CaceriaProbe`, `DespieceProbe` |
| Trampas y nasas que cobran solas | sólido | `TestFishing`, `CaceriaProbe` |
| Estaciones con efecto real | sólido | `TestSubsistence` |
| Meteorología | sólido | `TestWeather` |
| Árbol de técnicas por práctica | sólido | `ArbolProbe` |
| Utillaje que se gasta y se rompe | sólido | `TestToolkit` |
| Crónica y momentos | sólido | `TestChronicle`, `MomentoProbe` |
| Parajes con nombre y conocimiento del territorio | sólido | `TestParajes` |

**979 pruebas y 6 994 comprobaciones en verde (2026-09-12).**

> **Ésta es la única copia de esa cifra en el repositorio, y es a propósito.**
> Llegó a estar escrita en ocho sitios —CLAUDE.md, README.md, ARQUITECTURA.md,
> ROADMAP.md ×2, SPECS.md ×2 y aquí—, y el 2026-09-12 caducó tres veces en una
> tarde: cada vez que alguien añade una prueba, las ocho mienten a la vez. Al
> actualizarlas se corrigieron siete y se quedó una, que es exactamente el modo
> en que falla una cifra repetida.
>
> Los otros siete sitios llevan ahora **la regla, sin número**: la suite tiene
> que estar en verde y el total de comprobaciones no puede bajar del que dé al
> empezar a trabajar. Esa regla no envejece; la cifra sí. **Si mides la suite y
> quieres dejar constancia, actualiza aquí y no añadas la cifra en ningún otro
> documento.**

---

## 4. Lo que el diseño pide y NO existe

Comprobado por búsqueda en todo el código: **cero coincidencias** para cada uno.

| pedido en SLICE_PALEOLITICO | estado |
|---|---|
| **El conchero crece** y modifica el terreno | **hecho** — `Desechos` + `Conchero` |
| **Vestido** como necesidad (piel curtida) | no existe |
| **Plazas de cueva** (cuánta gente cabe en el abrigo) | no existe |
| **Sílex importado / intercambio** | no existe |
| Población que cambia con el año | **hecho** — nacimientos, muertes por hambre/frío/vejez/percance, y la edad avanza. Ver [QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md) |
| Saber tácito que **decae** | sólo se transmite, no decae |

El criterio de aceptación número 1 del documento —*«un año pasa y la
población cambia según lo que se haya conseguido»*— ya no falla: medido en
§1, quince al empezar y ocho al terminar, con la crónica contando por qué.

---

## 5. Qué haría, por orden

### ~~Primero: que se pueda perder~~ Hecho

Ver [QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md) para la spec
completa, sus 13 tareas y sus criterios de aceptación medidos uno a uno.

~~1. **Hambre con consecuencia.**~~ **Hecho.** Enferma antes de morir
   (`Inhabitant.hunger_sick_days`), y muere si la privación sigue. Empieza
   por los viejos y los críos: en la corrida medida en §1, los cinco niños y
   los dos ancianos mueren de hambre el mismo día y los ocho adultos
   sobreviven a la misma hambruna, tal como pedía este punto.
~~2. **Invierno con dientes.**~~ **Hecho, y ya estaba medio resuelto.** La
   reserva se consume de verdad: leña y comida caen sin parar durante todo
   el invierno (ver la tabla de §1). La recolección de invierno y el coste
   de leña ya estaban calibrados en el árbol; lo que faltaba era medirlo, y
   además un vector de frío directo (`Inhabitant.cold`, antes declarado y
   nunca alimentado) que enferma y mata sin que medie el hambre.
~~3. **Nacimientos y muertes.**~~ **Hecho.** Un nacimiento si el año cierra
   con reserva sobrada y sin rachas largas de hambre severa, y una mujer en
   edad fértil. Muerte por vejez, sola, sin decisión del jugador. Y un
   percance grave (una caída) puede matar, pocas veces — `Mishap.gd` pasa de
   «nada de esto mata a nadie» a «casi nada».

### Segundo: que la carne importe

Ver [SECADERO_Y_RIO.md](archivo/SECADERO_Y_RIO.md) para la spec de los puntos 5
y 6. El punto 4 se revisó al escribirla y se dejó fuera: la estacionalidad y
el agotamiento del avellanar ya están en el código: lo único que queda de él
es un número de kcal por puñado, que es balanceo, no mecánica.

4. **Reequilibrar recolección contra caza.** No subiendo la caza —ya se
   calibró— sino **bajando la avellana**: menos kcal por puñado, o —mejor—
   haciéndola *estacional de verdad* (el fruto seco es de otoño, no de todo el
   año) y con agotamiento del avellanar. Que la despensa vegetal sea el suelo y
   no el techo.
5. **El otoño como pico.** La berrea ya multiplica ×1,70 la caza. Hace falta
   que además sea **la única ventana** en la que se puede acumular carne seca
   para el invierno, y que el secadero sea el cuello de botella.
6. **La pesca se agota en un mes y nadie se muda.** Medido con `ParajesProbe`,
   dos pescadores y un año: el tajo de ribera baja al 75 % en **8 jornadas**, al
   50 % en 15, al 25 % en 24 y al **1 % en 32**, y ahí se queda el resto del año
   —sube al 3 % y no pasa de ahí—. Eso explica por sí solo que la ribera dé 1,79
   raciones por persona y día en un año cuando en las diez primeras jornadas
   daba 13,26: no está mal calibrada, está **esquilmada**.

   Y lo que lo convierte en un callejón sin salida: **el resto del río está al
   93,9 %**. Hay dónde pescar; la banda no va. `_rank_known_spots` sólo ofrece
   celdas con familiaridad ≥ 0,35, o sea **sitios ya conocidos**, y en un año
   con nadie en exploración la banda descubre **4 parajes en total**. El
   agotamiento sin alternativas no es una decisión, es un tope disfrazado.

   La recolección, en cambio, está bien: baja hasta el 63 % en otoño y se
   recupera al 85 %. Es el único recurso que hace lo que tiene que hacer.

   Dos apuntes del mismo sitio:
   - **`ResourceField.deplete_at` no lo llama nadie del juego**, sólo dos
     pruebas. Lo que gasta de verdad es `take_from_cell`, proporcional a lo
     recogido. Es código muerto que además documenta un modelo que no está en
     uso.
   - **La curva de reposición no deja volver de casi cero.** A 1 % de carga
     crece un 0,18 % de la capacidad al día: de 1 % a 50 % son unas 275
     jornadas **si se le deja en paz**, y no se le deja.

### Tercero: lo que el diseño pidió y falta

Ver [ABRIGO_Y_TRUEQUE.md](archivo/ABRIGO_Y_TRUEQUE.md) para la spec de los
puntos 7, 8 y 10. El punto 9 se revisó al escribirla y se dejó fuera: el
conchero ya está hecho —ver §4 más arriba—, así que esta entrada quedaba
duplicada.

7. **Vestido.** Piel curtida como necesidad de invierno. Ya existen `PIEL`,
   `PELETERIA`, `AGUJA` y la técnica de coser: falta la necesidad que las
   justifique.
8. **Plazas de abrigo.** Cuánta gente cabe en la cueva; crecer más obliga a
   levantar paravientos o a partir la banda.
10. **Sílex por intercambio.** No hay sílex bueno en Cantabria: es la mecánica
    de comercio servida por la geología real, y está a medio camino —el
    material existe, el intercambio no—.

### Cuarto: depurar

11. ~~**`food_cap` arranca en 0 = sin tope.**~~ **Hecho, y de otra manera.** Un
    tope en raciones no es una mecánica: es un número, y nada en el mundo
    impedía a la banda seguir amontonando. Ahora lo que limita es **en qué se
    guarda** —`Storehouse.capacidad_de_comida`: a granel más lo que cabe en los
    cestos y odres que haya, recalculado al cerrar cada jornada porque los
    cestos se rompen—. La banda arranca sin cestos, con unos 30 días de
    capacidad, y ampliarla cuesta jornadas de cordelería. `food_cap` sigue
    existiendo en cero y pasa a ser sólo lo que pida el jugador.
12. ~~**El atasco «llegó y el estado no se enteró»**, 2–5 por partida.~~
    **Hecho, y con él todos los demás.** Medido con `AtascoProbe` en el sitio
    56, ocho jornadas: los atascos pasan de **41 a 6** —entre 0 y 6 según la
    semilla— y los pasos que el terreno corta con camino trazado, de **5.741
    a 18**, ninguno de ellos por agua. Nadie da ya un paso sin un camino
    debajo: ese contador está en cero. Y el peor fotograma baja de 950 ms a
    242.

    No era un fallo: eran seis capas contestando distinto a la misma
    pregunta.

    Lo que había, y está en el código con su porqué:

    - **El agua, cuatro respuestas.** `Navgrid` la medía sólo en el centro de
      la celda; el A\* sólo prohibía diagonales; el recorte de la escalera
      deshacía el rodeo del vado con una recta de sesgo; y el atajo de la
      recta corta ni miraba. Ahora una sola regla, `Navgrid.paso_entre`, y una
      sola pregunta, `Marcha.agua_deja_pasar`.
    - **`_send_to` dejaba la ruta vacía por cuatro motivos** y los cinco
      sitios que la llaman veían sólo el vacío. «No me ha dado tiempo a
      mirar» se leía como «no hay camino»: seis personas la jornada 1 con «no
      hay camino hasta ningún tajo» a 211 m de casa. Ahora `Marcha.Traza`.
    - **Sin camino no se anda.** `next_waypoint` cae al destino cuando la
      ruta está vacía, así que quedarse sin ruta era salir DERECHO hacia él,
      cruzara lo que cruzara: el 22,9 % de los fotogramas andando.
    - **La regla del rodeo, dos fórmulas** —`alcanzable_de_verdad` y
      `merece_el_camino`— encadenadas decidiendo sobre lo mismo.
    - **El coste de andar un metro, dos modelos**, y el comentario de la
      rejilla jurando que era uno. Ahora `Traversal.pace_fraction`.
    - **La estación, contada de dos maneras**: la rejilla con el caudal de
      destino y el andador con el del paisaje, que va interpolado; y la
      rejilla clasificando el suelo siempre en seco.
    - **El esquive de orilla sin tope**, que como mueve a la persona nunca
      dejaba saltar el replanteo: horas barriendo la ribera.
    - **La misma pregunta desde dos sitios.** «¿Merece la pena ir a este
      paraje?» se hacía desde el abrigo en una capa y desde la persona en la
      siguiente. Dos orígenes, dos respuestas, y la de la persona no se podía
      guardar —se mueve—, así que era una búsqueda entera por candidato y sin
      pasar por ningún presupuesto: treinta y dos A\* en el cuadro del
      reparto de la mañana.

    - **El repaso de rezagados era un barrido, no una cola.** Los sitios que
      se ganan un nombre salen de uno en uno —para que el jugador no vea
      siete chapas de golpe—, así que siempre hay cola. Pero la lista de los
      que esperaban se calculaba entera, se usaba para sacar uno y **se
      tiraba**; para encontrar a los demás había que volver a barrer las
      4.096 celdas del campo a cada hora de luz. Se troceó por oficios y
      franjas para que el tirón no se notara, que es esconder el coste, no
      quitarlo —y de paso metía hasta día y medio de espera antes de que a un
      sitio le tocara su casilla—.

      Ahora la cola se guarda ([Parajes.cola]) y sacar al siguiente no cuesta
      barrido ninguno. El campo se repasa **sólo cuando hay motivo**: cuando
      cambia por dónde se pasa —la estación, la barca— porque eso vuelve
      candidato a un sitio sin que nadie haya ido a mirarlo. Y lo que rebrota
      por encima del umbral se apunta donde se sabe, en el propio rebrote.

      Medido: el peor fotograma baja de 950 ms a **156**, los tirones de más
      de 100 ms de 24 a 12 en tres jornadas, y el repaso en sí de 852 ms a
      111. Y descubre **más**: 11 parajes en ocho jornadas con la cola vacía,
      frente a los 7-8 de antes.

    - **La pregunta cara que no lo era.** «¿Se llega de verdad desde casa?»
      —no «¿hay camino?», sino «¿sin dar la vuelta al valle?»— se contestaba
      con una búsqueda A\* **por pregunta**, y se hace por cada paraje
      candidato, cada vez que alguien decide su salida, y dentro de barridos.
      Encima de eso había tres parches: memoria por celda, un presupuesto por
      cuadro, y aplazar la respuesta. Y aun así se colaban: medido en el panel
      de F3, **79 búsquedas en un fotograma de 2.541 ms**.

      No hacía falta ninguna de las tres. **El origen es siempre el mismo —el
      abrigo—**, y para un origen fijo un solo Dijkstra da los metros exactos
      hasta cada celda del mapa por lo que costaba UNA de aquellas búsquedas.
      Se rehace al cambiar la rejilla, o sea una vez por estación. Ver
      [Wayfinder.metros_desde].

    - **El arranque del camino no lo comprobaba nadie.** Una ruta es una cadena
      de CENTROS de celda, y quien anda arranca donde esté —hasta 28 m en
      diagonal—. La recta de ahí al primer hito no está vetada por nadie, y
      eso vale para cualquier camino, no sólo para los guardados. Se amarra
      metiendo el centro de la celda propia como primer hito cuando esa recta
      no está limpia: ni descarta el camino ni busca otro.

    - **El horno se había puesto un presupuesto que no podía cumplir.** Cuatro
      milisegundos por cuadro, y el trozo más pequeño que sabía cortar era una
      FILA entera: entre nueve y diecisiete. Un presupuesto más fino que tu
      grano no es un presupuesto. Ahora corta a mitad de fila.

    Y **se quitaron los topes de distancia** de expedición y ascensión —un
    radio de 2.600 m con mínimo de plantilla, y otro de 2.200 para buscar
    cumbres—. No es así como se limita a quien duerme fuera: lo que lo limita
    es la comida que puede llevar encima, y de eso ya decide
    [Despensa._provision].

    Con todo junto: **un tirón cada 2,08 s** (era uno cada 0,7) y el peor
    fotograma en **143 ms** (eran 2.541). El A\* desaparece del desglose.

    - **Y el panel decía «SIN EXPLICAR»** para el 84 % de un tirón de 917 ms.
      Todos los `_process` del juego están marcados, así que lo que falta es
      siempre el motor. Ahora se llaman **EL JUEGO** y **EL MOTOR**, y el
      segundo lleva al lado los nodos, los objetos y las llamadas de dibujo
      del cuadro: un tirón que crece con los días se lee de un vistazo.

    Y con eso se encontraron los dos que **empeoraban solos con los días**:

    - **`TrailView` congelaba la jornada** al abrir el panel de rastros. La
      ventana de diez días —[Inhabitant.RASTRO_DIAS]— dejaba de deslizarse y
      pasaba a ser «todo lo posterior a cuando abriste el panel», con un
      repintado cuatro veces por segundo que creaba y tiraba una malla por
      salida. Cada jornada metía más y no salía ninguna.

    - **`_nearest_prey` recorría los ochocientos animales preguntándole a cada
      uno su dieta**, y preguntarla son dos diccionarios y un texto. Se
      mantiene la lista de presas igual que ya se mantenía la de carnívoros:
      misma respuesta, sin preguntar.

    Medido con `PicoProbe` sobre **doce jornadas**: los tirones de más de
    100 ms pasan de **177 a 31** —de uno cada 0,40 s a uno cada 2,28— y en el
    mismo tiempo de reloj caben un 42 % más de fotogramas.

    Queda **`Cumbres`**, que para elegir monte pregunta sólo si hay camino y
    no si merece andarse. Con los topes de distancia fuera puede elegir una
    cima al otro lado del valle; si eso molesta, la regla ya existe con el
    factor por parámetro en `Marcha.rodeo_aceptable`.

    Lo que queda de los tirones —medido sobre el año entero, no sobre doce
    jornadas— y la regla para quitarlos sin tocar la partida: ver
    [LO_MISMO_MAS_DEPRISA.md](archivo/LO_MISMO_MAS_DEPRISA.md). En marcha, con
    el paso 0 cerrado —la misma semilla da la misma partida, año entero— y
    tres optimizaciones dentro: los tirones graves del año pasan de **819 a
    329** sin que cambie una sola cifra de la partida.


---

## 6. Fidelidad histórica: qué cambiaría

Lo que hay está bien documentado y con fuentes. Tres cosas que retocaría:

**El arco no debería estar.** `TechTree.Tech.ARCO` está en el árbol y el propio
`archivo/SLICE_PALEOLITICO.md` lo pone en la lista de lo que la época **no** conoce
(*«Arco · cerámica · agricultura…»*). El arco es Mesolítico. Hoy es además el
peldaño que más sube la caza en la escalera. O se quita, o se marca
explícitamente como el salto que abre la época siguiente.

~~**La bellota necesita su proceso.**~~ **Hecho.** La bellota cruda pasa a 0 kcal
y aparece `BELLOTA_DULCE`; en medio, el `LAVADERO`, con tres jornadas de remojo
y un tope de 30 puñados que es el cuello de botella del otoño. Ver
[archivo/PERRO_Y_BELLOTA.md](archivo/PERRO_Y_BELLOTA.md) §2.

~~**Falta el perro.**~~ **Hecho, y no como técnica.** No es un peldaño del árbol:
es una relación con la manada que arranca en el montón de desechos —la hipótesis
comensal— y va por cinco decisiones hasta el perro o hasta la manada en contra.
Medido: perro en la jornada 161 eligiendo lo amable, manada hostil en la 12
eligiendo matar. Ver [archivo/PERRO_Y_BELLOTA.md](archivo/PERRO_Y_BELLOTA.md) §1.

---

## 7. Qué falta para poder jugarlo

Ver [QUE_FALTA_PARA_JUGARLO.md](archivo/QUE_FALTA_PARA_JUGARLO.md) para la spec
completa de los puntos 1-4, sus 10 tareas y sus criterios de aceptación
medidos uno a uno.

~~1. **Un objetivo.**~~ **Hecho.** El objetivo es doble y fijo: sobrevivir el
   año Y dejar la cueva pintada — no una elección entre alternativas. Medido
   en la corrida compartida de 180 jornadas con reparto por defecto
   (`TironAnualProbe.gd`, semilla 123): `desenlace: NINGUNO (0 relatos
   pintados de 3 para ganar)`. La banda cerró el año viva y no ganó, porque
   no pintó nada — confirma en partida real que sobrevivir solo no basta.
   Con un solo dato no se sabe si `CUEVA_PINTADA_MINIMO := 3` es alto o si
   el problema es el mismo de §2 —la banda por defecto no llega a tener
   sobrante para pintar—; queda anotado, sin tocar la constante a ciegas.
~~2. **Un modo de perder**~~ (§5.1). **Hecho, y ahora además visible.** Un
   indicador de riesgo permanente en la barra de arriba —proporción de la
   banda enferma de frío o de hambre, todo el año y no sólo en la ventana de
   otoño— y un momento de cierre con la causa cuando la banda se extingue,
   en vez de una entrada suelta en la crónica que hay que ir a buscar.
~~3. **Que la primera hora enseñe.**~~ **Hecho.** Un único momento al fundar
   el asentamiento dice el objetivo doble, que se puede perder, y la primera
   decisión —repartir los oficios de la banda—. Confirmado que llega de
   verdad a la interfaz en una escena real, antes de cualquier acción del
   jugador, no sólo en prueba unitaria.
4. **Ritmo.** Sigue sin resolver, pero ya no es una sospecha: medido con
   `RitmoProbe.gd`, la primavera con el reparto por defecto pasa **cero
   momentos en cuarenta y cinco jornadas** —un único hueco de 44 días sin
   nada que decidir—. Verano, otoño e invierno quedan sin medir: una corrida
   de un año a `time_scale = 5` cuesta más de una hora, y el día que tocaba
   medirlo había cuatro agentes con sondas distintas compitiendo por la
   misma máquina. La dirección elegida es llenar la estación de decisiones,
   no acortarla; construir esas decisiones es trabajo aparte, no de esta
   spec.
5. **La interfaz** (ver [INTERFAZ.md](INTERFAZ.md)).
