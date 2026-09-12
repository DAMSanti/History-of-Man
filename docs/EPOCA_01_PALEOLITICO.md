# Época 1 — Paleolítico: el valle helado

Magdaleniense cantábrico, ~17.000–11.700 a.C. `Site.Era.PALEOLITICO`.

**Es la única de las once que está construida**, así que esta ficha no es sólo
diseño de destino como las otras diez: es el diseño **y** lo que falta de él,
con el código delante. Lo que hace hoy el juego, medido, está en
[ESTADO.md](ESTADO.md); lo que comparten todas las épocas, en
[SISTEMAS.md](SISTEMAS.md).

> Esta ficha absorbió el antiguo `archivo/SLICE_PALEOLITICO.md` el 2026-09-12, cuando
> la documentación se reorganizó para que lo único específico fueran las
> épocas. El original está en [archivo/SLICE_PALEOLITICO.md](archivo/SLICE_PALEOLITICO.md).

**Punto de partida.** Ninguno: es la primera época.

---

## Dónde mirar

| Si buscas… | Ve a |
|---|---|
| Qué sabe la banda al empezar y qué marca el techo de la época | §1 |
| Qué significa «investigar» aquí | §2 |
| **El año, estación a estación, y la tensión central de la época** | **§3** |
| Necesidades y de qué atributo del mapa sale cada recurso | §4 |
| Dónde empieza la partida y por qué ahí | §5 |
| Exploración, y qué limita el alcance de una expedición | §6 |
| **El árbol de técnicas por oficio, y el nudo de la azagaya** | **§7** |
| Los hitos y su condición de disparo | §8 |
| Qué falta por construir de esta época | §10 |
| **Los dos primeros años: la spec, en dos tandas, con criterios** | **§10.1** |
| La trampa: alargarla porque es la que está hecha | §11 |

Es la única época construida: lo que hace hoy, medido, está en
[ESTADO.md](ESTADO.md).

---

## 1. No se empieza de cero

Un grupo del Paleolítico superior **no es primitivo**. Lleva cientos de miles de
años de acumulación técnica y sabe perfectamente cómo cubrir sus necesidades.
Empezar la partida «descubriendo el fuego» es un tópico de género, y además es
falso.

**Lo que la banda trae puesto:** fuego, talla sobre lasca, enmangue, curtido,
cordelería, conservación por secado y ahumado, ocupar cueva y levantar
paravientos, y el ciclo anual —cuándo sube el salmón, cuándo es la berrea—.

**Lo que NO sabe, y marca el techo de la época:**

> Arco · cerámica · agricultura · ganadería · metal · rueda · molienda intensiva.

Ese techo no se escribe como lista de bloqueos: **sale solo** de qué procesos
existen y de la temperatura alcanzable. Un hogar abierto no pasa de ~700 °C, y
ésa es la barrera —ver la escalera térmica de [SISTEMAS.md](SISTEMAS.md) §1.1—.

> **Corregido (2026-09-12).** La versión anterior de este párrafo decía que la
> banda ya sabía **talla laminar, propulsor, azagaya, arpón y aguja**. Chocaba
> de frente con `TechTree.gd`, donde esas cinco se aprenden practicando —el
> arpón, 850 jornadas de pesca—. Ganó el código: `TechTree.known` arranca con
> un solo valor (`{Tech.LASCA: true}`), y el resto —núcleo, hoja, azagaya,
> propulsor, arpón, aguja— es la escalera que se sube jugando. El choque estuvo
> escrito y sin resolver desde que EPOCAS.md §3 lo destapó.

**El arco no debería estar.** `TechTree.Tech.ARCO` está en el árbol y es el
peldaño que más sube la caza, pero el arco es Mesolítico. O se quita, o se marca
explícitamente como el salto que abre la época siguiente. Sigue sin decidirse.

---

## 2. Qué significa «investigar» en esta época

No es descubrir lo básico: es **afinarlo**. La progresión de la primera época es
de rendimiento, no de repertorio:

- más filo por kilo de cuarcita,
- menos jornadas por presa abatida,
- menos pérdida de alimento almacenado,
- más alcance de expedición,
- más gente en el mismo abrigo.

Y el mecanismo ya está construido: **se mejora haciendo** (saber tácito) y **se
fija externalizando** (arte parietal, permanente). No hay árbol de investigación
con botones. Falta la otra mitad: que el saber tácito **decaiga** con el relevo
generacional — hoy `TechTree.known` sólo sube.

---

## 3. El bucle: el año

La unidad de juego es el **año**, no el tick. Y el año cantábrico del
Magdaleniense tiene una forma muy marcada:

| Estación | Qué ocurre | Decisión |
|---|---|---|
| **Primavera** | Sube el salmón por los ríos | ¿Se baja al río o se sigue en el abrigo? |
| **Verano** | Cabra y rebeco en roquedo; recolección | Expediciones lejos: materia prima, contacto |
| **Otoño** | **Berrea del ciervo.** La mejor caza del año | Todo el esfuerzo aquí. Es cuando se decide el invierno |
| **Invierno** | Ocupación del abrigo, consumo de reservas | Si el otoño falló, marisqueo y hambre |

**La tensión central de la época: el otoño decide si sobrevives al invierno**, y
el marisqueo es la red de seguridad —fiable, de bajo rendimiento, y te obliga a
estar en la costa—. Es lo que documentan los yacimientos: el ciervo domina, la
cabra aparece en roquedo, y el molusco es recurso de temporada mala.

**Y esto es lo que todavía no se cumple del todo**: la recolección produce el
doble de lo que la banda puede comer y guardar, así que el otoño no se distingue
lo bastante. Medido y explicado en [ESTADO.md](ESTADO.md) §2; lo que falta para
arreglarlo, en [ROADMAP.md](ROADMAP.md).

---

## 4. Necesidades y recursos

**Necesidades del grupo:** `Alimento` · `Calor` (leña) · `Abrigo` (plazas de
cueva) · `Materia prima` · `Vestido` (piel curtida).

De ésas, **plazas de cueva y vestido no existen todavía** como necesidad; las
otras tres sí. Ver `ROADMAP.md`.

> **Decidido (2026-09-12), §10.1.** El vestido pasa a ser necesidad de verdad,
> y con temperatura en grados visible detrás. Las plazas de cueva siguen sin
> decidirse.

| Recurso | Sale de | Notas |
|---|---|---|
| Ciervo, caballo | valle y bosque | La caza mayor, base de todo |
| Cabra, rebeco | `prominence` alta, pendiente | Poco rendimiento, zonas malas |
| Salmón | `water_km` bajo | Estacional, primavera |
| Molusco | `coast_km` bajo | Todo el año, bajo rendimiento |
| **Cuarcita** | cauces (`river_mask`) | Cantos rodados. **La materia prima real de Cantabria** |
| **Sílex** | **no existe aquí** | Importado. Obliga al intercambio desde la primera época |
| Ocre (hematites) | afloramientos | Pigmento — y el mismo mineral que 30 000 años después se funde en hierro |
| Leña, madera | bosque | Cuello de botella del fuego |
| Asta, hueso, piel | subproducto de la caza | Nada se tira |

Que el sílex bueno no exista en Cantabria no es un obstáculo: **es la mecánica
de comercio, servida por la geología real**. Está a medio camino — el material
existe (`Materia.Kind.SILEX`), el intercambio no.

El catálogo real vivo es `Materia.CATALOGUE`, con su peso y su volumen; la
abundancia repartida por el territorio, `ResourceField` y `ResourceMapper`.

---

## 5. El enclave inicial

No se da a elegir sobre el mapa, y por dos razones: el jugador todavía no sabe
leer los atributos, y explorar un mapa que aún no conoce no es una decisión, es
una lotería. **La primera decisión real llega con la primera expedición.**

Está resuelto y fijado en `GameState.HOME_LAT/LON`: **Cueva los Pendios**, valle
del Nansa. Elegido a propósito por anodino —agua a 300 m con cantos de cuarcita,
ladera suave, nueve cavidades, y el mar a 12,8 km, lo bastante lejos para que la
costa sea una expedición de verdad—. Tiene tres yacimientos con entrada
enciclopédica a menos de 5 km, así que la exploración temprana paga.

> **El problema de las torcas, resuelto.** Los emplazamientos ocupables del
> Paleolítico estaban dominados por «Torca» y «Sima» —pozos verticales de
> catálogo espeleológico, no abrigos habitables—. Hoy `Site.Feature` distingue
> `SIMA` de `ABRIGO` y sólo el segundo es habitable; una torca sigue valiendo
> como señal de karst, que es donde hay más cuevas sin descubrir.

---

## 6. Exploración

- Al empezar se ve **el propio emplazamiento y poco más**.
- Las expediciones cuestan jornadas y víveres.
- Revelan emplazamientos, recursos y otros grupos.
- El alcance no se limita con un radio: lo limita **la comida que se puede
  llevar encima**, y de eso decide `Despensa._provision`. Los topes de distancia
  se quitaron a propósito.

Encaja con el registro: los grupos cantábricos tenían movilidad logística
estacional, no vagaban al azar.

**Dentro del valle esto funciona** (`Reconocimiento`, `Exploration`,
`BandKnowledge`, `Parajes`). **Fuera no existe**: el mapa regional enseña los
862 emplazamientos desde el minuto uno. Es la FASE A1 del ROADMAP, y es
infraestructura que sirve igual a las diez épocas siguientes — ver §9.

---

## 7. Desarrollos tecnológicos

Ya están en `TechTree.CATALOGUE` y `TechTree.BRANCHES`, con jornadas y coste en
material medidos, no inventados aquí. Resumen por oficio (el oficio sale de la
rama, `TechTree.job_of`):

| Oficio | Técnicas, en orden | Jornadas acumuladas hasta el final |
|---|---|---|
| `MANUFACTURA` | Lasca → Núcleo (45) → Hoja (110) → Aguja (190) | 345 |
| `CAZA` | Lazo (35) → Cepo (110) → Red de aves (190) → Foso (330) → Azagaya (140) → Ojeo (260) → Propulsor (420) → Arco (700) | hasta 2185 |
| `RIBERA` | Pesquera (60) → Nasa (180) → Anzuelo (320) → Red (560) → Arpón (850) | hasta 1970 |
| `EXPLORACION` | Pasarela (70) → Piragua (150, pide `Kind.HOGAR`) | 220 |
| `HOGAR` | Arte (200, pide `Kind.HOGAR`) | 200 |

**El nudo de esta época, y está medido:** `AZAGAYA` cuelga de `HOJA`, que se
practica en materia prima. Una banda con uno o dos en el taller **no llega a la
caza mayor en un año de partida**, así que los cazadores viven de trampas. No es
calibración, es una cadena de prerrequisitos. Ver [ESTADO.md](ESTADO.md) §2.

**Lo que falta de instalación, no de técnica:** `CampProjects.Kind` tiene
`HOGAR`, `SECADERO`, `LAVADERO` y `PARAVIENTO`. Es la lista correcta para esta
época —el hogar abierto es el techo térmico de todo el Paleolítico— y **no debe
crecer hasta el Neolítico**. La única que falta es la lámpara de grasa (§8).

---

## 8. Hitos

Usando el formato de `Hito` de [SISTEMAS.md](SISTEMAS.md) §2:

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| Núcleo preparado | interno | `TechTree.has(Tech.NUCLEO)` | — |
| Talla laminar | interno | `TechTree.has(Tech.HOJA)` | — |
| Azagaya y propulsor | interno | `TechTree.has(Tech.PROPULSOR)` | — |
| Aguja con ojo | interno | `TechTree.has(Tech.AGUJA)` | — |
| Lámpara de grasa | interno | obra nueva de `CampProjects` (no existe hoy) | — |
| El arpón de asta | interno | `TechTree.has(Tech.ARPON)` | — |
| El relato junto al fuego | interno | **ya implementado**, `Tale.gd` | — |
| El primer trazo en la pared | interno | `TechTree.has(Tech.ARTE)` y primera obra pintada | `Feature.OTRO` (no hay `Feature` de arte parietal; ver §9) |
| La sepultura | interno | pide un `Inhabitant` fallecido y una decisión de gasto de trabajo en el entierro | — |
| La concha de lejos | interno | primer intercambio recibido (SISTEMAS.md §5), aún sin construir | — |
| La agregación estacional | interno | exige más de un asentamiento: fuera de alcance | — |
| El santuario | interno | arte parietal en un sitio que no es el de habitación | — |
| Máximo Glacial | interno, consecuencia de mapa | ya calculado: `RegionEras` + `Site.coast_km_by_era` | cambia disponibilidad, no `Feature` |
| **El bosque cierra el valle** | **cierre, se sufre** | cuenta de años/hitos desde el inicio, ver SISTEMAS.md §6 | retirada de fauna de manada del `WildlifeHerds` local |

> **Añadido (2026-09-12), §10.1.** Lo que cierra la **primera fase** —los dos
> primeros años— no es un hito de esta tabla, sino los tres a la vez: arte
> parietal pintado, una expedición mandada fuera del mapa, y puntos nuevos
> descubiertos en el mapa regional. Las dos últimas condiciones no tienen hito
> propio todavía porque la capa regional no existe (SISTEMAS.md §4).

---

## 9. Oficios

Sin cambios: `Profession.Job` en su forma actual —`CAZA`, `RIBERA`,
`RECOLECCION`, `MANUFACTURA`, `EXPLORACION`, `HOGAR`, `OCIOSO`— es exactamente
el reparto de esta época. **Es la única ficha de las once donde esta sección no
pide nada nuevo.**

---

## 10. Lo que falta de esta época

No es «contenido de más adelante»: son piezas de esta misma época que siguen sin
construirse. El estado medido de cada una está en [ESTADO.md](ESTADO.md) y el
orden en que se atacan, en [ROADMAP.md](ROADMAP.md).

1. **Exploración regional** (§6). El objetivo es que el mapa de Cantabria deje de
   mostrarlo todo desde el minuto uno.
2. **Saber tácito que decae** (§2), la otra mitad de la FASE C1.
3. **Vestido** como necesidad de invierno. Ya existen `PIEL`, `PELETERIA`,
   `AGUJA` y la técnica de coser: falta la necesidad que las justifique.
4. **Plazas de abrigo**: cuánta gente cabe en la cueva. Crecer más obliga a
   levantar paravientos o a partir la banda.
5. **Sílex por intercambio** (§4).
6. **`Feature` de arte parietal.** `Site.Feature` no distingue «cueva con arte»
   de «abrigo cualquiera», así que no hay dónde anotar que un sitio se volvió
   santuario.
7. **La sepultura** y **la agregación estacional**: la primera pide una noción de
   «fallecido con ajuar»; la segunda, más de una banda simulada a la vez, que
   está fuera de alcance a propósito.

---

## 10.1. Spec: los dos primeros años

> **Spec (2026-09-12).** Escrita con `/spec` sobre la intención de `/epoca 1`,
> que se conserva entera debajo, desde «La intención, tal como salió de las
> preguntas». Lo que allí quedó decidido no se vuelve a discutir aquí.
>
> El mecanismo de lo que cruza épocas no está en esta ficha, está en
> [SISTEMAS.md](SISTEMAS.md): §4 exploración, §5 comercio, §18 caminos, §19
> temperatura. Lo que se ve, en [INTERFAZ.md](INTERFAZ.md) §4. Las cifras
> medidas, en [ESTADO.md](ESTADO.md) §2 y **sólo ahí**. Las tareas las cuelga
> `/plan-tarea` en [ROADMAP.md](ROADMAP.md) «En curso».

**Qué problema cierra.** La primera fase tiene principio y tiene final, y no
tiene medio. El final existe —`Partida.evaluar_victoria`: un año vivo y la cueva
pintada— y el principio también, pero entre los dos no hay nada que obligue al
jugador a volver mañana. Lo que se mide hoy lo dice sin adornos: un recolector
alimenta a siete personas, un cazador no se alimenta ni a sí mismo, y la banda
tira más de lo que come (ESTADO.md §2). Con eso, la fase dura lo que tarde el
jugador en ver que no pasa nada, y dos años de partida no se sostienen.

**Qué se pide.** Los siete frentes de la intención, **en dos tandas**. La
frontera entre las dos no es de importancia, es de **qué se puede medir**: la
tanda 1 se comprueba con sondas de días o de una estación, la tanda 2 necesita
que un año entero corra hasta el final sin colgarse.

**Criterio que ordena todo, y que puede recortar una tarea entera:** sólo entra
lo que sirva a las once épocas. Es la trampa de §11 y se descartó a propósito.
Si al implementar un frente sale una pieza que sólo vale en el Paleolítico, se
recorta la pieza, no se amplía el alcance.

---

### La puerta de entrada: los dos 🔴, dentro de esta spec

**Decidido al escribir la spec:** los dos 🔴 abiertos de ROADMAP «En curso»
entran aquí, en vez de quedarse fuera como prerrequisitos ajenos. La razón es
que ninguno es sólo un fallo: el taller que se para es el **reparto automático**
reasignando al artesano, que es diseño, y el cuelgue de la hambruna es lo que
impide medir cualquier cosa de la tanda 2.

**Aviso de dueño.** El cuelgue está asignado en ROADMAP a la sesión
`history-of-man-0e`, y a fecha de esta spec **no hay constancia de que esté
empezado**. Antes de tocarlo se pregunta o se comprueba; si lo coge esta tanda,
se dice en la pizarra primero.

| | Criterio de aceptación |
|---|---|
| 🔴 **El taller se para hacia la jornada 31** | Con el taller ocupado a mano, las jornadas de manufactura por día **no caen** de lo que valen los primeros treinta días (2,00/día medido, ESTADO.md §2) a lo largo de 90 jornadas; y si caen, la causa es una decisión del jugador y no el reparto automático. Medido con `ArbolPasoProbe` a 90 jornadas, con su tabla jornada a jornada. Y la consecuencia: **la talla laminar llega dentro del primer año** con el taller ocupado |
| 🔴 **El cuelgue de la hambruna total** | `SEMILLA=42 DIAS=95 BANDA=4,3,2` sobre `AnoProbe` **termina y escribe sus tablas**, con una prueba en `scripts/tests/` que falle antes del arreglo. Y se contesta la otra mitad: **si el reparto 4,3,2 es viable** o es hambre garantizada, que es un hallazgo de balanceo por sí solo |

**Ninguna cifra de la tanda 2 se da por buena antes de que estos dos estén
cerrados.** Una corrida de un año que se cuelga en otoño no mide medio año: no
mide nada.

> **LOS DOS CERRADOS (2026-09-12).** El detalle, en ROADMAP «En curso» → «La
> puerta de entrada», y las cifras en ESTADO.md §2.
>
> - **El taller no era un fallo:** termina su trabajo. La demanda de utillaje
>   es fija y pequeña, se cubre a `RESERVA_UTILLAJE` en unos treinta días, y a
>   partir de ahí el reparto manda al artesano a otro oficio —comportamiento
>   deliberado—. Lo que queda es balanceo y va por `/spec`.
> - **El cuelgue no era del juego:** era `AnoProbe` esperando `while sim.day <
>   hasta` con la banda ya extinta, o sea una jornada que `_process` no iba a
>   avanzar nunca. Arreglado con `SettlementSim.partida_terminada()`.
> - **Y el criterio se cumple:** `SEMILLA=42 DIAS=95 BANDA=4,3,2` termina y
>   escribe sus tablas, con los quince vivos. **4,3,2 es viable**, al contrario
>   de lo que hacía temer el parte: lo que ahogaba a la banda era el rodeo del
>   río, ya arreglado, no el reparto.
>
> **La tanda 2 queda desbloqueada.**

**Plan técnico.** (`/plan-tarea`, 2026-09-12. Las tareas, en
[ROADMAP.md](ROADMAP.md) «En curso».)

**Lo primero, porque cambia el punto de partida: la hipótesis que ROADMAP daba
para el cuelgue está descartada por lectura.** Decía «un bucle en el camino de
muertes masivas, por ejemplo recorrer `sim.people` mientras `_person_dies` lo
modifica», con `Relevo.gd` de sospechoso y sin leer. Leído: `Relevo.revisar_vejez`,
`revisar_frio` y `revisar_hambre` **ya recorren `sim.people.duplicate()`**, y el
comentario de `Relevo.gd:125` dice exactamente por qué. Los otros bucles de
salida variable de la simulación —`Reparto.set_job_count`,
`Inhabitant.create_band`— decrecen en cada vuelta y terminan. **El sospechoso
nombrado no es el culpable, así que el diagnóstico empieza de cero** y ésa es su
propia tarea, no un preámbulo de la del arreglo.

**Módulos afectados**

| Script | Qué cambia | Contrato |
|---|---|---|
| `sim/Taller.gd` | `_workshop_short` deja de contestar sólo *si* falta, y dice **qué** falta | §4.4 fachada: la clase del tema contesta la pregunta de su tema |
| `sim/SettlementSim.gd` (~2380, el recado del artesano) | Con lo que falta en la mano, el recado va **a por ese material** y no a materia prima genérica | §4.4 pasamanos; constantes por la clase |
| `sim/Reparto.gd` | Sólo si el diagnóstico lo señala: hoy no hay indicio de que reasigne al artesano | §4.4 |
| `tests/ArbolPasoProbe.gd` | Admite `MANU=n`, para medir con el taller ocupado a mano | §6.3 sonda: mide, no pasa ni falla |
| `tests/AnoProbe.gd` | Un **vigía** que deje en disco la fase en curso, para leer dónde se colgó sin esperar a que termine | §6.3 |
| `tests/` (nuevos) | Una prueba por regla: la del recado del artesano y la del cuelgue | §6.3 una prueba, una regla |

**Decisiones de arquitectura, sólo las que la spec obliga**

1. **Lo que falta se pregunta en un solo sitio.** Hoy `Taller._workshop_short`
   sabe qué material falta y **lo tira**: devuelve `bool`, y quien recibe ese
   `true` manda a la persona al mejor tajo de materia prima, que es el canchal.
   Por eso el almacén acumula cuarcita —de 96 a 3 054 medidas, ESTADO.md §2—
   mientras la manufactura se para: se sale a por piedra cuando lo que falta es
   fibra, asta o hueso. El arreglo es **devolver el material**, no un sí/no, y
   que el recado tenga destino. Es el invariante 3 de SPECS.md §7 —una pregunta,
   un sitio que la contesta— aplicado a «¿qué le falta al taller?».
2. **Y lo que hace el artesano cuando le falta es hacer otra cosa, no salir.**
   Decisión del jugador al aprobar el plan, entre tres opciones. `_next_piece`
   descarta la pieza cuyo material no está, **igual que ya descarta la que no se
   sabe hacer y la que nadie pide**, y sólo si ninguna pieza es posible se sale
   del taller. Es lo que el propio `Taller.gd` ya decía y no cumplía: «el taller
   es un SITIO, y la única razón por la que un artesano sale es que le falte».
   La alternativa —salir a por el material que falta, con destino correcto— se
   descartó porque pone al artesano a competir con los recolectores por el mismo
   tajo, y eso es alcance que la spec no pidió.
3. **Lo anterior es una hipótesis medida a medias y se comprueba antes de
   tocar nada**, con una prueba que construya el estado (almacén con piedra de
   sobra y sin fibra, artesano en `MANUFACTURA`) y mire qué pieza elige
   `_next_piece` y adónde le manda el reparto. Si la hipótesis cae, el plan
   cambia y se dice.
4. **El cuelgue se reproduce construyendo el estado, no simulándolo.** El
   síntoma —`SEMILLA=42 DIAS=95 BANDA=4,3,2`, cruce verano→otoño, despensa 0 y
   hambre 100 en los quince, 17 minutos de un núcleo sin escribir log— describe
   un estado que se puede **escribir**: despensa a cero, hambre al máximo,
   estación de verano al filo del cambio, y dar pasos. Es ARQUITECTURA.md §5.1.
   La corrida de 95 jornadas queda para **confirmar el criterio de aceptación**,
   que pide esa corrida literal, no para diagnosticar.
5. **El vigía escribe a disco, no a `stdout`.** Godot no suelta la salida hasta
   salir, y un proceso colgado no sale: por eso hubo 17 minutos «sin una línea
   de log». Un fichero con `flush()` por fase se puede leer **mientras** el
   proceso está colgado, y dice en qué fase se quedó sin matarlo a ciegas.

**Orden de dependencias**

- El frente del taller **no depende** del cuelgue: son ficheros distintos y
  escalas de tiempo distintas. Va primero porque su diagnóstico ya está medio
  hecho por lectura y se cierra con pruebas de segundos.
- Dentro del cuelgue: reproducir → diagnosticar → arreglar → confirmar. **La
  confirmación es la corrida literal del criterio** y no vale otra.
- Las dos corridas largas **no se juntan en una**, y es deliberado: la del
  cuelgue tiene que ser `SEMILLA=42 DIAS=95 BANDA=4,3,2` **sin tocar**, porque
  cambiar el reparto para meter un artesano cambia la partida y deja de
  reproducir lo que se quería reproducir. Van seguidas, no a la vez —Godot es de
  uno en uno, AGENTES.md §3.

**Corrección del plan (2026-09-12, al implementar A1).** Dos premisas de arriba
se cayeron nada más construir el estado, y se dejan escritas en vez de
reescribir el plan como si nunca las hubiera creído:

- **La decisión 1 era falsa.** `_workshop_short` no es lo que para al taller:
  con 3 054 de piedra en el almacén dice que no falta nada. La cuarcita
  acumulada es consecuencia de que el artesano se vaya, no su causa.
- **La decisión 2 ya estaba implementada.** `_next_piece` llama a
  `_can_pay_for` y descarta la pieza cuyo material no está, con un comentario
  que dice literalmente lo que el plan proponía añadir: «Antes esto no se
  miraba aquí: se elegía la pieza MENOS cubierta aunque no hubiera con que
  hacerla». La decisión de diseño que el jugador tomó al aprobar el plan **ya
  era el comportamiento del juego**.

**Lo que sí es:** la demanda natural de utillaje es fija y pequeña, se cubre en
unos treinta días, y a partir de ahí `_next_piece` da −1, `_speciality_can_work`
da false y el reparto manda al artesano a su siguiente oficio —lo cual es
deliberado y está comentado en `Reparto.gd`—. El taller no se para: **termina**.
Y el régimen permanente de reposición, 0,3 jornadas/día medidas, no da para las
110 jornadas de práctica que pide la talla laminar. Eso es balanceo, no un
fallo, y la decisión de qué se toca no estaba en esta spec. Ver ESTADO.md §2.

**Riesgos técnicos conocidos**

- **El cuelgue puede no ser un bucle infinito sino una explosión de coste.**
  3 101 s de CPU en 3 120 s de reloj es compatible con las dos cosas. Si es lo
  segundo, el criterio «termina y escribe sus tablas» se cumple sin arreglar
  nada más que la lentitud, y eso hay que decirlo tal cual en vez de venderlo
  como un bucle cazado.
- **La otra mitad de la pregunta puede contestar que no.** Si 4,3,2 resulta ser
  hambre garantizada, el cuelgue arreglado deja una corrida que termina con la
  banda muerta. Es un hallazgo de balanceo válido y va a ESTADO.md §2, pero
  entonces **la tanda 2 necesita otro reparto de referencia** y eso es una
  decisión que no se toma dentro de esta tarea.
- **Arreglar el recado del artesano toca el reparto de todos**, no sólo el suyo:
  si el destino del recado pasa a ser un tajo de fibra o de asta, compite con
  los recolectores por el mismo sitio. Se mira en la corrida del taller que la
  recolección no se resienta.
- **Deuda que se hereda:** `ArbolPasoProbe` extrapola cuándo llegaría cada
  técnica en vez de correr el año. Con el taller arreglado esa extrapolación
  vuelve a ser razonable, pero **sigue siendo una extrapolación**: «la laminar
  llega dentro del primer año» se dará por medido de verdad cuando corra el año
  de la tanda 2, no antes.

---

### Tanda 1 — lo que se mide sin un año entero

#### 1. La banda aprende los caminos

*Mecanismo: [SISTEMAS.md](SISTEMAS.md) §18.*

La ruta a un destino al que se va muchas veces se **guarda por destino** y se
afina en cada recorrido hasta converger, en vez de buscarse entera cada vez.
Vive donde vive lo que la banda sabe (`BandKnowledge`), y se sella con la
rejilla que la trazó (`Navgrid.built_with_caudal`, `built_with_encharque`).

**Lo que ya existe, y hay que saberlo antes de empezar:** `Marcha` ya recuerda
rutas y ya las tira al rehornear (`Marcha._remember_route`,
`Marcha.forget_routes`). Lo que falta no es la memoria: es que **mejore con el
uso**, y que sea por destino y no por trayecto suelto.

**Y el fallo que lo motivó ya no está.** El rodeo del río era el recargo por
riesgo sin tope, no una ruta rancia, y está arreglado (ESTADO.md §2). Esta tarea
**no se justifica como arreglo**: se justifica como la pieza que después es
camino de carro, calzada y carretera.

Criterios:

- **El rodeo baja, y se sabe desde dónde.** `RodeoProbe` sobre el mismo conjunto
  de trayectos, al empezar y dos estaciones después. El suelo medido **sin
  aprender nada** es x1,18 en primavera y x1,43 en verano: el rodeo medio con
  memoria de rutas tiene que quedar **estrictamente por debajo** del suelo de su
  propia estación, y la cifra se escribe en ESTADO.md §2.
- **Si no baja, se dice y no se fuerza.** Un x1,18 de primavera está cerca de lo
  óptimo y puede que no haya nada que afinar. Si la medida sale plana, el valor
  del frente pasa a ser el ahorro de búsquedas, **se escribe así**, y no se
  inventa un número para que parezca que aportó.
- **Vuelve a bajar tras un rehorneo.** En la misma corrida, en la estación
  siguiente al cambio de rejilla: el rodeo sube al caducar la memoria y **vuelve
  a bajar** en unos recorridos, en vez de quedarse clavado en la ruta vieja.
- **Ahorra búsquedas de verdad.** Búsquedas de camino completas por jornada
  simulada, con los mismos trayectos andados: tiene que bajar, contado por la
  sonda. Es la mitad del frente que se pidió —«en vez de buscarse de cero»— y se
  mide aparte del rodeo.
- **Ninguna ruta sobrevive a su rejilla**, con una prueba que falle antes de la
  regla.
- **La misma semilla, la misma partida** (SPECS.md §3.3): la memoria de rutas es
  estado de la simulación, no del fotograma. Comprobado con `FirmaDiaria`.

#### 2. La noche se salta

Cuando nadie está trabajando, el reloj corre a todo lo que dé. **El que
vivaquea cuenta como dormido**: si no, un solo cazador a 3 km bloquearía la
aceleración todas las noches, que es lo contrario de lo pedido.

Criterios:

- **La jornada cuesta menos reloj.** Segundos de reloj por jornada simulada,
  antes y después, **en la misma máquina y en la misma sesión** —un tirón no se
  compara entre equipos—, con la misma semilla y el mismo número de jornadas.
  Tiene que bajar, y la cifra se escribe en ESTADO.md §2.
- **La partida no cambia.** La firma diaria (`FirmaDiaria`) de una corrida con
  la noche acelerada es **idéntica** a la de la misma semilla sin acelerar, a lo
  largo de 60 jornadas por lo menos. Acelerar es correr el paso fijo más
  deprisa, no dar menos pasos: `SettlementSim.PASO_FIJO` no se toca, y
  `Engine.time_scale` tampoco (SPECS.md §3.1).
- **La noche no atropella una decisión.** Mientras haya un `Moment` con opciones
  el reloj está parado (`Moment.is_decision()`); la aceleración lo respeta, con
  prueba.
- **Un cazador fuera no bloquea la noche**, con prueba: banda dormida y una
  persona vivaqueando a varios kilómetros, y la noche se acelera igual.

#### 3. La temperatura, visible

*Mecanismo: [SISTEMAS.md](SISTEMAS.md) §19. Lo que se ve:
[INTERFAZ.md](INTERFAZ.md) §4.*

Grados en pantalla, sacados de estación, hora, altitud y el paleoclima que ya
está calculado al nivel del mar (`RegionEras`). Aquí entra **sólo la magnitud y
su lectura**; el vestido como necesidad es tanda 2, porque se mide en inviernos.

Criterios:

- **Una pregunta, un sitio.** «¿Cuántos grados hace aquí y ahora?» se contesta
  desde un solo sitio (invariante 3 de SPECS.md §7), y hay una prueba de
  entradas fijas a grados conocidos.
- **La altitud pesa lo que pesa en la atmósfera.** El gradiente vertical es el
  físico, del orden de 0,65 °C por 100 m —**no** es una cifra de balanceo—, y una
  prueba lo comprueba entre la cueva y el roquedo con su diferencia de cota real.
- **El invierno y el verano no se parecen.** Mediodía de verano y noche de
  invierno en la boca de la cueva: la diferencia existe, se mide, y queda
  escrita.
- **Se lee en la barra superior**, en grados, y persona a persona se ve quién va
  vestido y con cuánto desgaste (`SettlementSim.VESTIDO_WEAR_PER_DAY`).
  Comprobado con captura **con ventana**: en `--headless` la imagen sale nula.

#### 4. Rendimiento estable

No es un frente aparte que se haga al final: es la condición que los otros tres
tienen que cumplir mientras se hacen.

Criterios:

- **El fotograma malo no empeora.** Con el cepo que ya existe (F3, `PicoProbe`,
  `TironAnualProbe`), el peor fotograma y el tirón de la simulación no empeoran
  respecto de lo que ESTADO.md §2 tenga escrito al abrir la tanda, medido con la
  misma sonda y en la misma máquina.
- **La memoria de rutas no crece sin tope.** Entradas guardadas ≤ destinos
  conocidos, con prueba: una memoria por trayecto y por estación crecería todo el
  año sin que nada se quejase.
- **La suite sigue verde y no adelgaza.** El suelo es **el total que dé la suite
  al abrir la tanda**, anotado antes de tocar nada, no una cifra de este
  documento: verde **y** sin que baje el total. Medido el 2026-09-12 al escribir
  la spec: **925 pruebas, 6 912 comprobaciones, TODO OK**. Y la razón de mirar
  las dos cosas: una prueba que revienta antes de su primer `assert` pasa, no
  falla, así que el verde solo no dice nada.

---

**Plan técnico.** (2026-09-12, `/plan-tarea`, `history-of-man-11`.) Las tareas
cuelgan de [ROADMAP.md](ROADMAP.md) «En curso», bloque «Tanda 1».

> **Lo que se cayó del plan al implementarlo (2026-09-12).** El plan es lo que
> se creía antes de tocar el código; esto es lo que el código contestó. El
> detalle de cada cosa está en su tarea de ROADMAP y las cifras en ESTADO.md
> §2.
>
> 1. **«La clave es el destino, no el trayecto» — NO.** Es lo que pedía el
>    frente 1 y está medido que no funciona: multiplica por 135 los pasos que
>    el terreno corta con camino trazado (17 → 2 295). Con la clave por par,
>    quien reutiliza la vereda está a setenta metros del primer hito; con la
>    clave por destino puede estar a kilómetros, y el enganche se convierte en
>    una recta larguísima que ninguna cata razonable cubre. **La clave sigue
>    siendo el par**, y lo que se queda de la idea son las dos catas.
> 2. **«Mejorar con el uso es acortar la cuerda» — retirado.** Afinar consiste
>    en fabricar tramos rectos nuevos, que es justo lo que el punto 1 acaba de
>    demostrar que es caro de comprobar. El frente 1 entrega memoria sellada,
>    dos extremos catados y **el 39 % de las búsquedas ahorradas**, no una
>    vereda que converge.
> 3. **«`duerme_la_banda()`: todos en `DURMIENDO`» — demasiado estricto.** El
>    usuario lo probó en el juego: la noche seguía yendo lenta porque la banda
>    no se acuesta a la vez. Es `nadie_trabaja()`, que es lo que la spec decía
>    desde el principio. 90 s → 62 s por cuatro jornadas, en vez de 71.
> 4. **«`RegionEras` no calcula paleoclima» — confirmado, y peor.** No sólo no
>    existe la base: el Magdaleniense abarca la deglaciación entera, así que un
>    desfase fijo tampoco serviría. El frente 3 se para y vuelve a `/spec`.
> 5. **«M2, el rodeo, ~12 min» — no procede.** `RodeoProbe` no simula jornadas
>    de marcha: mide el rodeo del planificador, no lo que la banda aprende
>    andando. El plan dio por hecho que sí sin mirarlo.
> 6. **Y el error de método que costó más que todo lo anterior:** las primeras
>    medidas se tomaron **sin fijar la semilla**, y eran ruido. Ver
>    ARQUITECTURA.md §5.1, donde queda la regla.

**El suelo, medido hoy antes de tocar nada:** `RunTests` da **932 pruebas,
6 920 comprobaciones, TODO OK**. Ésa es la cifra que no puede bajar, no las
925/6 912 que anotó la spec: entre una y otra entraron las pruebas del taller y
del cuelgue. La copia viva está en [ESTADO.md](ESTADO.md) §3.

### Dos premisas de la spec que el código no sostiene

Se dicen antes del plan porque una de las dos cambia una tarea entera.

1. **`RegionEras` no calcula ningún paleoclima.** La spec de este frente y
   [SISTEMAS.md](SISTEMAS.md) §19 dicen que la temperatura sale «del paleoclima,
   que ya está calculado para el nivel del mar (`RegionEras`)». Comprobado:
   `scripts/datos/RegionEras.gd` tiene `sea_levels`, `masks`, `index_for` y
   `mask_texture`, y **nada más** — son máscaras de área emergida por cota del
   mar, no clima. En todo el repositorio no hay ni un grado de temperatura
   ambiente. O sea que la base al nivel del mar **no existe y hay que traerla de
   algún sitio**, y como no se inventan números, de dónde viene es una decisión
   que no es del plan. Va en la pregunta.
2. **El vestido no es de nadie: es de la banda.** `Toolkit` guarda
   `pieces: Array[Tool]` sin dueño, y `SettlementSim.vestido_coverage()` es
   `count(VESTIDO)` partido por la población. [INTERFAZ.md](INTERFAZ.md) §4 pide
   ver «persona a persona quién va vestido y con cuánto desgaste», y eso hoy no
   se puede contestar: repartir el utillaje por persona es un cambio de modelo,
   y además es lo que la tanda 2 va a necesitar para «el vestido como
   necesidad». **En esta tanda la barra enseña la cobertura de la banda y el
   desgaste de la pieza peor**, que sí existen; el reparto por persona se queda
   para el frente 7, con su spec.

### Frente 1 — los caminos que se aprenden

**Lo que hay.** La memoria de rutas **ya existe y no está donde dice la spec**:
vive en `SettlementSim._route_cache` / `_route_order` (LRU con tope
`ROUTE_CACHE_LIMIT`) y la maneja `Marcha._remember_route` / `_retarget` /
`forget_routes`. La clave es `Marcha._lane_key`, que es **el par origen-destino**
en cubos de `SettlementSim.LANE_CELL` (48 m), o sea memoria por **trayecto**.
Y hay una pieza que la spec no menciona y que decide el diseño: los viajes que
tocan el abrigo —«la mayoría», dice el comentario— **no pasan por la memoria**:
salen del árbol de Dijkstra `Marcha._arbol_desde_casa` vía
`Wayfinder.camino_por_el_arbol`, exactos y sin buscar.

**Consecuencia, y hay que decirla antes de empezar:** lo que el frente 1 puede
mejorar es **sólo el resto**, los viajes que no tocan el abrigo. El grueso del
tránsito ya es óptimo por construcción. Esto refuerza el aviso que la propia
spec trae —«si la medida sale plana, se escribe así y no se fuerza un número»—.

**Decisiones de arquitectura** (las que la spec obliga, no más):

- **La memoria pasa a `BandKnowledge`**, que es donde la spec la quiere y donde
  ya vive lo que la banda sabe. `SettlementSim._route_cache` y `_route_order`
  desaparecen; `Marcha` pregunta a `sim.knowledge`. Esto es un cambio de sitio
  de estado de partida: lo recorre `Instantanea` por reflexión, así que **la
  firma diaria cambia de forma** y la comparación de determinismo del frente 2
  se hace **después** de esta tarea, no a caballo de ella.
- **La clave es el destino, no el trayecto.** Una vereda es «el camino a D», y
  quien va a D **se engancha a ella** por el hito más cercano al que llegue en
  línea limpia (`Wayfinder.linea_limpia`), en vez de tener su propia copia desde
  su propio cubo. Esto arregla de paso la costura que `Marcha._lane_key`
  documenta —dos destinos distintos en el mismo cubo prestándose el camino— sin
  caer en lo que ya se midió que no sale a cuenta: afinar la clave **del origen**
  hundía el reuso y subía los atascos de 3 a 243.
- **Mejorar con el uso es acortar la cuerda, no volver a buscar.** En cada
  recorrido se intenta un número corto y fijo de atajos sobre la ruta guardada:
  si del hito *i* se ve el *i+2* en línea limpia, se tira el de en medio. No
  cuesta ni un nodo de búsqueda, converge en unos pocos recorridos —que es
  justo lo que la spec pide— y no puede empeorar la ruta, porque sólo quita
  hitos por los que ya se pasaba.
- **El sello es un dato, no un aviso.** Cada entrada guarda el
  `built_with_caudal` y el `built_with_encharque` de la rejilla que la trazó, y
  se descarta al leerla si no coinciden con los de la rejilla de hoy.
  `Marcha.forget_routes()` se queda —también levanta `parajes.revisar_el_mapa`—
  pero deja de ser la única garantía: la regla «ninguna ruta sobrevive a su
  rejilla» pasa a ser comprobable con una prueba de segundos, que hoy no lo es.
- **El tope sale solo.** Con la clave por destino, las entradas son como mucho
  los destinos conocidos, que es el criterio del frente 4. El tope LRU se queda
  como red.

**Qué contrato de SPECS.md aplica.** §4.6 (`scripts/banda/` guarda lo que la
banda sabe), §3.3 (la memoria es estado de la simulación: el azar de los
atajos, si lo hubiera, saldría del `_rng` — el diseño de arriba **no usa
azar**), y §4.3, que no se toca: quién puede pasar lo sigue diciendo
`Navgrid.paso_entre` y lo que cuesta un metro, `Traversal.pace_fraction`.

### Frente 2 — la noche se salta

**Lo que hay.** `SettlementSim._process` acumula el `delta` real en `_pendiente`
y da pasos de `PASO_FIJO` hasta `PASOS_POR_CUADRO`. Dentro de `_advance`, el
tick de la gente se parte en `steps := ceil(time_scale)` trozos, así que **el
tiempo de juego por trozo no depende de `time_scale`**.

**La decisión que ordena el frente, y sale de leer el bucle:** acelerar **no**
es subir `time_scale`. Subirlo cambia cuánta hora de juego avanza cada
`_advance`, y con ella cambian el instante en que salta `hour_passed`, el
tamaño del trozo de fauna que entrega `_fauna_pendiente` cada `PASOS_DE_FAUNA`,
y por tanto la partida. La firma no sería idéntica, y la spec la exige.

Acelerar es **dar más pasos por fotograma, del mismo tamaño**: se multiplica lo
que se mete en `_pendiente` y se sube el tope de pasos por cuadro, dejando
`PASO_FIJO` y `time_scale` como están. Con eso la sucesión de llamadas a
`_advance` es **la misma que sin acelerar**, sólo que repartida en menos
fotogramas, y la firma es idéntica **por construcción** y no por suerte. Que
esto valga depende de que nada de la simulación dependa del fotograma, y está
comprobado: `Marcha.nuevo_cuadro()` es un `pass`, y `_path_nodes_this_frame` y
`_stranded_this_frame` se ponen a cero **dentro** de `_advance`, no por cuadro.
Es, además, literalmente lo que la spec pedía: «correr el paso fijo más deprisa,
no dar menos pasos».

- **Quién bloquea la noche.** Una pregunta, un sitio:
  `SettlementSim.duerme_la_banda()`. Es cierta cuando todas las personas están
  en `Inhabitant.State.DURMIENDO`. El que vivaquea entra solo, porque el vivac
  también acaba en `DURMIENDO` —`SettlementSim` lo pone así en las tres ramas de
  dormir fuera—, que es lo que el criterio pedía sin tener que añadir nada. El
  que **anda** de vuelta a casa de noche no duerme y frena la aceleración, y eso
  es lo correcto: se le está simulando la marcha.
- **La decisión para el reloj ya está respetada** sin tocar nada: `_process`
  sale antes de acumular si `time_scale <= 0.0`, y la interfaz lo pone a cero al
  levantar un `Moment` con opciones. Se le pone prueba igualmente, porque es un
  criterio de aceptación y hoy nadie lo comprueba.
- **El tope, y es lo que lo enlaza con el frente 4.** Un cuadro con cuarenta
  pasos es un tirón. El tope de pasos de noche es una cifra de rendimiento y se
  fija **midiendo con `PicoProbe`**, no a ojo.

**Qué contrato aplica.** SPECS.md §3.1 entero: `PASO_FIJO` no se toca,
`Engine.time_scale` tampoco, y la partida no depende de los fps —que es
exactamente lo que este diseño preserva—. §3.3 para la firma.

### Frente 3 — la temperatura, visible

**Lo que hay:** nada. `Inhabitant.cold` es un 0–100 abstracto, `Weather` da
tipo de día y factores, `Temporada` da cota de nieve, caudal y encharcamiento.
No hay grados en ninguna parte.

- **Una clase nueva, `Termometro`, en `scripts/mundo/`**, con una sola función
  pública: los grados de una estación, una hora y una cota. Es el «un solo
  sitio» del invariante 3, y va en `mundo/` porque es una magnitud del sitio y
  del calendario, no de la banda ni del utillaje. No se mete en `Temporada`
  —que es el estado de la estación en curso— para que la pregunta se pueda
  hacer de cualquier cota y hora, que es lo que van a necesitar el hogar, el
  vivac y la ropa.
- **El gradiente vertical es 0,65 °C por 100 m y es físico**, no de balanceo:
  va con su comentario diciendo que no se toca para cuadrar una partida.
- **La base al nivel del mar sale del clima cantábrico de hoy menos la anomalía
  magdaleniense** (decidido el 2026-09-12 al preguntar). No se inventa ninguna
  de las dos: las medias mensuales de la costa cantábrica y el desfase frío del
  Magdaleniense van **con su fuente citada en [CREDITOS.md](CREDITOS.md)**, y si
  una de las dos no se encuentra con cita, la tarea para y se dice — no se
  rellena a ojo. La oscilación diaria es la forma, no la cifra: amplitud
  estacional sobre esa base.
- **Lo que se ve** (INTERFAZ.md §4): grados en la barra superior, y la cobertura
  de vestido de la banda con el desgaste de la pieza peor —no por persona, ver
  la premisa 2—. La comprobación es una captura **con ventana**: en
  `--headless`, `get_texture().get_image()` devuelve null.

### Frente 4 — rendimiento estable

No es una tarea al final: es la puerta por la que pasan las otras tres. Lo que
hace falta para que sea comprobable:

- **Una línea base en ESTA máquina, antes de tocar nada.** El cepo mide reloj de
  pared y las cifras de SPECS.md §6.1 son de otra corrida: sin una medida propia
  del día de hoy no hay con qué comparar. `PicoProbe` con sus valores por
  defecto son ~80 s.
- **El re-medido, sólo después del frente 2**, que es el único que toca el
  reparto de trabajo por fotograma.
- **El tope de la memoria**, con prueba: entradas ≤ destinos conocidos.
- **La suite en verde y sin adelgazar**, contra las 932/6 920 de hoy.

### Riesgos técnicos, nombrados

- **La memoria de rutas puede no aportar nada medible al rodeo.** Lo dice la
  propia spec y el código lo refuerza: los viajes del abrigo ya salen del árbol
  de Dijkstra y son óptimos. Si el rodeo sale plano, el valor del frente es el
  ahorro de búsquedas y **se escribe así**.
- **Engancharse a la vereda cuesta algo.** Buscar el hito de enganche es una
  cata de línea limpia por hito; si se deja sin tope, sale más caro que la
  búsqueda que ahorra. Va con tope fijo de hitos catados.
- **Mover la memoria a `BandKnowledge` cambia la forma de la instantánea**, o
  sea las firmas de antes y las de después no se comparan entre sí. Por eso el
  cotejo de determinismo del frente 2 va **después** del frente 1 y no en
  paralelo.
- **La noche acelerada puede fabricar el tirón que el frente 4 prohíbe.** Es el
  riesgo real de esta tanda, y por eso el tope de pasos se fija midiendo.
- **Deuda que se hereda y no se toca aquí:** la costura del origen en la memoria
  de rutas —dos personas de cubos distintos compartiendo destino se engancharán
  a la misma vereda, que es lo que se quiere, pero el tramo de enganche no está
  medido— y las tres capas de física declaradas y sin usar (SPECS.md §5).

### Ficheros que se tocan

`scripts/banda/BandKnowledge.gd`, `scripts/sim/Marcha.gd`,
`scripts/sim/SettlementSim.gd`, `scripts/mundo/Termometro.gd` (nuevo),
`scripts/ui/BarraSuperior.gd`, `scripts/tests/RodeoProbe.gd`,
`scripts/tests/PicoProbe.gd`, y pruebas nuevas en `scripts/tests/`.
Documentación: SISTEMAS.md §18 y §19, INTERFAZ.md §4, ESTADO.md §2 y §3,
SPECS.md §3.1 y §4.6, ROADMAP.md.

---

### Tanda 2 — lo que sólo se mide con el año corriendo

Nada de esta tanda se da por hecho antes de que los dos 🔴 estén cerrados.

#### 5. Expedición fuera del mapa

*Mecanismo: [SISTEMAS.md](SISTEMAS.md) §4, capas regional y exterior.*

Las dos capas que faltan se construyen **juntas y en ese orden**: la regional
pone la niebla, y la exterior pone a alguien al final del camino. El propósito
es **encontrar gente con la que tratar**, no sólo terreno.

Criterios:

- **El jugador no ve los 862 de golpe.** Al empezar la partida `PanelSitios`
  lista los emplazamientos descubiertos y **son un puñado, no 862**; el número
  exacto se fija al implementar y se escribe.
- **La expedición descubre, y se cuenta.** Tras una expedición regional, el
  número de `Site` con ficha revelada (`Site.describe_for_player`) sube; cuánto
  sube por expedición queda medido.
- **Y cuesta.** Jornadas-persona y raciones consumidas por la expedición,
  contadas en la sonda: salir del abrigo no se vuelve el mismo día, y esas
  jornadas **no se recolectan**. Una expedición que vuelve sin llegar cuesta
  igual, con prueba.
- **Hay alguien al final.** Algunos `Site` llevan marca de ocupados por otro
  grupo, y alcanzar uno deja **contacto**: estado que sobrevive a la expedición y
  que el trueque puede usar. Prueba de que el contacto sigue ahí una estación
  después.

#### 6. Trueque de verdad

*Mecanismo: [SISTEMAS.md](SISTEMAS.md) §5, primer peldaño.*

`Intercambio` ya existe: ofrece `FRUTO_SECO` 6,0, pide `SILEX` 3,0, acierta el
55 % fijo, se intenta solo una vez por estación y **el jugador no decide nada ni
se entera**. Pasa a decidir las cuatro cosas: con quién, qué se ofrece y cuánto,
qué se pide, y si se va.

Criterios:

- **No ocurre solo.** En un año simulado sin que el jugador decida nada,
  intercambios consumados = **0**.
- **La contraparte recuerda.** Dos corridas con la misma semilla, una siendo
  generoso y otra regateando, dan **tasas de éxito distintas** —el 55 % fijo
  deja de ser fijo— y la diferencia queda medida. El patrón es el `trato` de
  `ElLobo`, que ya funciona así.
- **Desprenderse duele.** Ofrecer algo que no sobra en invierno se nota en la
  despensa de las jornadas siguientes, medido. Hoy está clavado en fruto seco
  porque es justo lo que sobra.
- **Ir cuesta jornadas.** Las del que va no se recolectan, y se ven en la
  contabilidad por oficio del año.
- **Se puede pedir sílex, concha o gente**, y las tres llegan: una prueba por
  cada una. La concha es el hito «la concha de lejos», que hoy no tiene de dónde
  venir.

#### 7. El vestido como necesidad, y el frío que cierra sitios

*Mecanismo: [SISTEMAS.md](SISTEMAS.md) §19, piezas 2 y 3.*

El vestido existe como pieza y quita el 60 % del frío
(`SettlementSim.VESTIDO_COLD_MITIGATION`); lo que falta es la **necesidad** que
lo justifique, y que sin ropa buena no se pueda ir a ciertos sitios.

Criterios:

- **El frío mata alguna vez.** Dos corridas con la misma semilla y dos
  inviernos: una en la que la banda hace ropa y otra en la que no. En la que no,
  **alguien enferma o muere de frío**; en la que sí, menos o ninguno. Si en dos
  inviernos nadie enferma de frío, la necesidad no existe y el frente no está
  hecho. `Relevo.revisar_frio` ya sabe aplicarlo.
- **El frío cierra el roquedo.** Sin ropa buena, una salida al roquedo en
  invierno se **rechaza**, con un motivo que el panel dice. La peletería es una
  puerta —como la azagaya lo es para la caza mayor—, no un porcentaje.
- **Y dormir al raso en invierno tiene consecuencia**, distinta de dormir al
  raso en verano: medido en `Inhabitant.cold` con la misma semilla.

#### 8. Decisiones repartidas por el año

Vienen de cuatro sitios: las que ya existen con apuesta de verdad, **una fija
por estación**, las que salten del estado sin calendario, y el reparto como
decisión continua.

Criterios:

- **Al menos cuatro al año que no se pueden evitar**: una decisión fija por
  estación, contada en un año simulado. Las que dispare el estado van encima,
  sin suelo ni tope —así se decidió al escribir la spec: el calendario no se
  infla para llegar a un número—.
- **Cada una cuesta.** Un `Moment` con opciones cuenta **sólo** si la opción que
  no se eligió cambia una cifra de la partida —despensa, jornadas o riesgo—, y
  la sonda apunta cuál y cuánto. Un momento cuya elección da igual no se cuenta
  aunque tenga dos botones.
- **La berrea deja de ser gratis.** Hoy es binaria y no cuesta nada elegir:
  volcarse tiene que significar que ese mes **no se recolecta ni se hace leña**,
  y se ve en las raciones recolectadas de ese mes.
- **Y el lobo y el trueque se ven al decidir.** `ElLobo` ya descuenta la tajada
  de la despensa y ya ingresa carne y piel al matarlo: lo que falta no es la
  consecuencia, es que **esté escrita en la opción** antes de elegir.

---

### El cierre de la fase: tres condiciones, no una

`Partida.evaluar_victoria` cierra hoy con una sola condición —un año vivo y la
cueva pintada, `SettlementSim.CUEVA_PINTADA_MINIMO`—. La primera fase pasa a
pedir las tres:

1. **La cueva pintada** (la que ya está).
2. **Una expedición mandada fuera del mapa.**
3. **Puntos nuevos descubiertos en el mapa regional.**

Las dos nuevas son exactamente las que obligan a construir la capa regional, y
por eso están aquí y no en §8 como hitos internos.

Criterios:

- **Una partida llega a las tres**, y el desenlace se levanta sólo cuando están
  las tres: prueba de que con dos no se cierra.
- **Y tarda del orden de dos años.** Entre año y medio y tres años simulados,
  que es la lectura de «no de medio ni de seis» de la intención —no una medida—.
  Si sale de esa banda, lo que se ajusta es el contenido de los dos años, no el
  criterio.
- **La caza vuelve a medirse.** El 0,27 raciones por cazador y día de ESTADO.md
  §2 es de antes de abrir las puertas del asta y de la punta lítica, y **nadie lo
  ha vuelto a medir**. Se mide un año con `BandaProbe`, la cifra nueva se escribe
  en ESTADO.md §2, y el umbral de «la caza es un oficio viable» se decide **con
  el dato delante** —así se resolvió al escribir la spec, en vez de fijar un
  número a ciegas—. Para leerlo: un recolector da 14,29 raciones y alimenta a
  siete, así que el consumo es del orden de 2 raciones por persona y día. Si la
  cifra no se mueve de 0,27, eso es un hallazgo para `/depurar`, no una tarea de
  esta spec.

---

### Fuera de alcance

- **Alargar la época porque es la que está hecha.** La trampa de §11, descartada
  explícitamente. Ningún sistema entra si sólo vale aquí.
- **Quitarle el coste de material al árbol de técnicas**
  (`TechTree.LEARNING_COST`). Era el arreglo barato de la azagaya y rompe la
  regla que el propio jugador pidió. Y además se midió que **el material no
  frenaba nada**: lo que frena son las jornadas.
- **Bajar las jornadas de la talla laminar.** Taparía el 🔴 del taller.
- **La senda que se abre al pisarla.** Buena mecánica y reutilizable, pero no
  ahorra búsquedas, que es media petición; y ya no hay un rodeo roto que
  explicar.
- **Banda vecina jugable o rival con IA.** El contacto sí; el otro asentamiento
  simulado, no (SISTEMAS.md §4).
- **La agregación estacional y la sepultura** (§10, punto 7). La primera pide más
  de una banda simulada, que está fuera de alcance a propósito.
- **Las plazas de abrigo** (§10, punto 4). Siguen sin decidirse, y no se deciden
  aquí.
- **Guardado y carga.** FASE A3, sin empezar (SPECS.md §8): dos años de partida
  no se pueden guardar a mitad, y eso se acepta.
- **La causa en el panel de técnicas.** Ya está hecha (INTERFAZ.md §4). Se nombra
  para que no se rehaga.
- **Ficheros nuevos en `docs/`.** Esta spec vive en los permanentes que le tocan.

---

### La intención, tal como salió de las preguntas

> **Intención (2026-09-12).** Sale de `/epoca 1`. Es lo que había antes de la
> spec de arriba, y se conserva porque dice **por qué** cada decisión es la que
> es. Si choca con la spec, gana la spec.

**Qué se quiere.** Que la primera fase del Paleolítico **dure dos años de
partida y se juegue**, en vez de durar lo que tarde el jugador en ver que no
pasa nada. Dos años no salen de añadir contenido: salen de que la caza
funcione, de que haya decisiones repartidas por el año, y de que las noches no
se miren pasar. En concreto, siete frentes:

1. **La banda aprende los caminos.** La ruta a cada paraje se guarda y se afina
   cada vez que se recorre, hasta converger —«cosa de un par de estaciones como
   mucho»—, y se reutiliza en vez de buscarse de cero.
2. **La noche se salta.** Cuando nadie está trabajando, el reloj corre a todo
   lo que dé.
3. **Expedición fuera del mapa**, con el propósito de **encontrar gente con la
   que tratar**, no sólo terreno.
4. **Trueque de verdad**: con quién, qué se ofrece, qué se pide, y si se va.
5. **La temperatura, visible**, y el vestido convertido en necesidad.
6. **Más decisiones a lo largo del año**, y que las que ya existen cuesten algo.
7. **Rendimiento estable** mientras se hace todo lo anterior.

**Lo que se decidió al preguntar.**

- **Los fallos van por `/depurar`, no por aquí.** *(¿Cómo partimos fallos y
  diseño?)* La azagaya que no se fabrica, las técnicas que no se desbloquean y
  el rodeo del río son fallos con causa localizada; salen por su camino. Esta
  intención se queda con lo que es diseño. Razón: no se diseña encima de una
  caza rota. **Los tres cerrados el 2026-09-12**; ver ROADMAP «En curso». Del
  tercero salió algo que este documento daba por otra cosa: el rodeo no era del
  río sino del recargo por riesgo del trazado —ver [ESTADO.md](ESTADO.md) §2—.
- **Sólo entra lo que sirve a las once épocas.** *(La trampa de §11 es alargar
  esta época. ¿Cómo la esquivamos?)* Exploración regional, trueque con
  contraparte, temperatura, decisiones y caminos que se aprenden son
  infraestructura reutilizable —senda, calzada, carretera; trueque, ruta,
  mercado—. **Queda fuera todo contenido que sólo valga en el Paleolítico.** Es
  el mismo criterio que §11 ya aplica a la exploración regional: no es excusa
  para quedarse, es la pieza que abre paso.
- **El camino mejora porque la banda aprende el valle**, no porque la senda se
  abra de tanto pisarla. *(¿Por qué mejora con el tiempo?)* Lo dijo el jugador
  al describirlo: al principio «no saben llegar de otra manera». La ruta se
  guarda por paraje y se reintenta mejor cada recorrido hasta converger. Encaja
  con `BandKnowledge`, que ya existe, y da el segundo ahorro pedido: no buscar
  de cero.
- **La noche se acelera cuando nadie trabaja**, no cuando todos duermen
  literalmente. *(¿Y el que está fuera?)* El que vivaquea cuenta como dormido.
  Si no, un solo cazador a 3 km bloquearía la aceleración todas las noches, que
  es lo contrario de lo pedido.
- **El asta de desmogue se puede buscar.** *(¿Por dónde se rompe el bucle de la
  azagaya?)* El ciervo desmoga de febrero a abril y `Tajo._gathering_yields` ya lo produce,
  pero `ASTA` no figura en `Parajes.EXTRAS_BY_ACTIVITY`, así que **ningún paraje
  la anuncia y el jugador no puede ir a por ella**. Además el tendón ha de poder
  salir de la caza menor. Las dos cosas juntas abren el bucle sin tocar el peaje
  de material del árbol, y son históricamente correctas: la cuerna de desmogue
  es la única materia dura animal que no exige matar.

  > **Al arreglarlo salió peor de lo escrito aquí (2026-09-12, `/depurar`).**
  > El desmogadero **ya era** un nombre de paraje —`Parajes.MATERIA_PRIMA_POOL`
  > le reserva cuatro papeletas de quince— y ninguna tabla de rendimiento de
  > materia prima daba asta. O sea que no es que no se pudiera ir a por ella:
  > **se podía ir a un desmogadero y volver sin nada**. Hecho: el asta entra en
  > los extras de recolección y de materia prima, y `Tajo.ASTA_DE_DESMOGUE` es
  > la única cifra, que usan el recolector, el cantero y la materia prima sin
  > especialidad. Y el tendón ya salía de la caza menor: lo que lo cerraba era
  > que `SettlementSim.SPECIALITY_TOOL` exigía azagaya para cazar menor
  > mientras `Fauna` decía que al corzo se le entra con lanza de mano. Gana
  > `Fauna`.
- **Y la banda empieza con azagayas que no sabe fabricar.** Lo señaló el jugador
  y el código lo confirma: `SettlementSim.UTILLAJE_INICIAL` metía `Tool.Kind.AZAGAYA` en
  el utillaje inicial, mientras `Tool.tech_of` exige `Tech.AZAGAYA` para hacer
  una. [ESTADO.md](ESTADO.md) §2 ya lo había medido —«acabaron con dos azagayas
  de un utillaje que ni siquiera sabían diseñar»— y se quedó sin arreglar.

  > **Arreglado (2026-09-12, `/depurar`).** En su lugar van dos **puntas
  > líticas**: es lo histórico —la lanza de mano precede a la punta de asta
  > enmangada—, no piden técnica ni herramienta para hacerse, y `Fauna` ya deja
  > cobrar corzo y rebeco con ellas, así que la caza menor sigue viva desde el
  > primer día. El utillaje inicial es ahora una lista,
  > `SettlementSim.UTILLAJE_INICIAL`, y hay una prueba que exige que nada de
  > ella pida técnica.
- **La expedición sirve para encontrar gente.** *(¿Cuál es su propósito?)*
  Revela `Site` del mapa regional —hoy se ven los 862 desde el minuto uno— y
  algunos llevan marca de ocupados por otro grupo. Alcanzar uno abre el
  contacto, y el contacto es lo que convierte el trueque automático de hoy en
  una relación con una banda concreta.
- **El trueque decide las cuatro cosas**: con quién (y eso tiene memoria, como
  el `trato` del lobo), qué se ofrece y cuánto, qué se pide —sílex, concha,
  gente— y si se va, porque esas jornadas no se recolectan.
- **Las decisiones vienen de los cuatro sitios**: las que ya existen con apuesta
  de verdad, una fija por estación, las que saltan del estado sin calendario, y
  el reparto como decisión continua. La berrea de hoy es binaria y **no cuesta
  nada elegir**, así que no es una decisión: volcarse tiene que significar que
  ese mes no se recolecta ni se hace leña.
- **El frío decide adónde se puede ir.** Temperatura en grados visible, el
  vestido como necesidad que hoy falta (§4), y sin ropa buena no se sube al
  roquedo en invierno ni se duerme al raso.
- **La fase cierra con tres condiciones, no con una.** *(¿Qué cierra los dos
  años?)* Haber **pintado la cueva**, haber **mandado una expedición fuera del
  mapa** y haber **descubierto más puntos del mapa regional**.

> **Corregido (2026-09-12).** §8 listaba «el primer trazo en la pared» como un
> hito interno más, y `Moment.Kind.VICTORIA` cierra hoy con «un año vivo y con
> la cueva pintada» —una sola condición—. El cierre de la primera fase pasa a
> pedir las tres, y las dos nuevas son exactamente las que obligan a construir
> la capa regional de [SISTEMAS.md](SISTEMAS.md) §4.

**Fuera a propósito.**

- **La trampa de §11 —alargar la época porque es la que está hecha— se descartó
  explícitamente.** Ningún sistema entra si sólo vale aquí.
- **Los fallos**: azagaya, panel de técnicas y el rodeo del río van por
  `/depurar`. Los tres cerrados el 2026-09-12.
- **Quitarle el coste de material al árbol de técnicas.** Era el arreglo barato
  de la azagaya, y rompe la regla que el propio jugador pidió —«cada material
  abre su parte de las jornadas», `TechTree.LEARNING_COST`—.
- **La senda que se abre al pisarla.** Buena mecánica y reutilizable, pero no
  explica el rodeo ni ahorra búsquedas, que es lo que se pidió. Y se descartó
  por la razón buena: el rodeo no lo explicaba **ninguna** mecánica de caminos,
  porque no era un problema de caminos. Ver [SISTEMAS.md](SISTEMAS.md) §18.
- **Banda vecina jugable o rival con IA.** El contacto sí; el otro asentamiento
  simulado, no. Sigue fuera de alcance como dice [SISTEMAS.md](SISTEMAS.md) §4.

**Con qué choca.**

- **La ruta memorizada choca con la rejilla estacional.** `Navgrid` se rehorna
  **una vez por estación** (`Navgrid.from_terrain`, `HornoDeRejillas`), así que
  el vado que no existía en primavera sí existe en verano. Si la ruta aprendida
  se guarda sin invalidarla al rehornear, el síntoma que motivó la petición
  —seguir yendo al oeste cuando el río ya se vadea— **pasa de ser un fallo
  pasajero a ser permanente**. Toda memoria de ruta tiene que caducar con la
  rejilla con la que se trazó (`Navgrid.built_with_caudal`).

  > **Las dos mitades de esto salieron falsas (2026-09-12).** El rodeo al oeste
  > no era una ruta rancia sino el recargo por riesgo sin tope, y las rutas que
  > `Marcha` ya guarda **sí** caducan al rehornear (`Marcha.forget_routes`). O
  > sea que no hay un fallo debajo que justifique el frente, y la regla de
  > caducidad no hay que introducirla: hay que **no perderla**. Ver la spec de
  > arriba, frente 1, y [SISTEMAS.md](SISTEMAS.md) §18.
- **`ASTA` no está en `Parajes.EXTRAS_BY_ACTIVITY`** aunque
  `Tajo._gathering_yields` la produce en invierno. El propio fichero dice la
  regla que incumple: «lo que se puede traer de un sitio tiene que salir en la
  ficha del sitio», en el comentario de `EXTRAS_BY_ACTIVITY`.
- **El utillaje inicial contradice el árbol**: `SettlementSim.UTILLAJE_INICIAL`
  frente a `Tool.tech_of`.
- **El lobo ya hace lo que se pedía.** `ElLobo._preguntar_se_queda` **ya**
  descuenta despensa por la tajada (`_eat_from_store(2.0)`) y **ya** ingresa
  carne y piel al matarlo. Lo que falta no es la consecuencia: es que se **vea**
  al decidir. Lo mismo con el trueque: `Intercambio.gd` existe y funciona solo,
  sin que el jugador se entere.
- **Hay un 🔴 abierto en [ROADMAP.md](ROADMAP.md)**, el cuelgue de la hambruna
  total, asignado a otra sesión. **Mientras exista no se puede medir un año
  completo con reparto pobre**, y esta intención se mide en años.

> **Actualizado (2026-09-12), después de que `/depurar` cerrara el nudo de la
> azagaya.** Los choques de arriba ya están resueltos y se dejan escritos para
> que no se vuelvan a investigar. Se citan **por nombre y no por línea**: las
> referencias de este documento se movieron solas en cuanto `/depurar` editó
> esos ficheros, y una línea equivocada engaña más que ninguna.
>
> - `ASTA` figura en `Parajes.SEASONAL_EXTRAS` como invernal —eso ya estaba— y
>   ahora también en `Parajes.EXTRAS_BY_ACTIVITY`, en recolección **y** en
>   materia prima. Lo segundo porque el desmogadero ya era un nombre de paraje
>   (`Parajes.MATERIA_PRIMA_POOL`) y no entregaba nada.
> - El utillaje inicial es `SettlementSim.UTILLAJE_INICIAL` y lleva dos puntas
>   líticas en vez de dos azagayas, con prueba de que nada de la lista pide
>   técnica.
> - La caza menor pide `Tool.Kind.PUNTA` en `SettlementSim.SPECIALITY_TOOL`, no
>   azagaya, que es lo que cerraba el bucle del tendón.
>
> **Y una de las decisiones de arriba partía de una causa equivocada.** Se
> escribió que las técnicas se paraban por falta de material. Medido con
> `ArbolPasoProbe`, **ninguna** lo estaba: todas esperaban **jornadas**. La
> causa invisible no era el material, era **el oficio que nadie practica**.
> Romper el bucle del asta seguía haciendo falta y sigue siendo correcto, pero
> no era lo que cerraba la rama.
>
> Eso abrió un 🔴 nuevo que **bloquea esta intención más que el cuelgue de la
> hambruna**: «el taller se para solo hacia la jornada 31» (ROADMAP.md). Con él,
> ninguna técnica de manufactura pasada del núcleo llega en un año — y «los dos
> años se juegan» se mide contra eso.
>
> **Las cifras de las dos medidas están en [ESTADO.md](ESTADO.md) §2 y sólo
> ahí**, con su tabla día a día: es la copia que se toca si cambian. Llegaron a
> estar repetidas en tres documentos a la vez, que es la manera segura de que
> dentro de un mes dos digan cosas distintas.

**Qué habría que medir.**

- **Los dos años se juegan**: una partida llega al cierre triple —cueva pintada,
  expedición fuera, puntos regionales nuevos— y tarda del orden de dos años de
  simulación, no de medio ni de seis.
- **El camino converge**: rodeo medio a un paraje, medido al empezar y dos
  estaciones después. Tiene que bajar, y tiene que **volver a bajar** tras un
  rehorneo de rejilla, en vez de quedarse clavado en la ruta vieja.
- **La noche cuesta**: segundos de reloj por jornada simulada, antes y después.
  Es la mitad de «rendimiento estable» que se mide barata.
- **La caza deja de dar 0,27.** [ESTADO.md](ESTADO.md) §2 tiene la cifra de
  partida, en raciones por cazador y día. Con el asta buscable y el tendón de
  caza menor tiene que subir, y hay que decir cuánto.
- **Las decisiones se cuentan**: cuántos `Moment` con opciones salen en un año,
  y en cuántos el jugador podía haber elegido al revés sin que diera igual. Un
  momento cuya elección no cambia nada no cuenta.
- **El frío mata a alguien alguna vez.** Si el vestido es necesidad y nadie
  enferma de frío en dos inviernos, la necesidad no existe.

---


## 11. La trampa

**Alargarla porque es la que está hecha.** Es la época mejor construida del
proyecto, y la exploración regional del punto 1 **no es una excusa para quedarse
más tiempo aquí**: es infraestructura que sirve exactamente igual a las diez
épocas siguientes. Esta ficha la trata como la pieza que abre paso, no como
contenido nuevo del Paleolítico.

---

## 12. Fidelidad

`ATESTIGUADO` con margen: Altamira, El Castillo (la secuencia de ocupación más
larga de Europa y el arte parietal datado más antiguo del continente),
La Pasiega, El Pendo, Covalejos, El Mirón —con el enterramiento de la Dama
Roja— y La Garma, con suelo de ocupación sellado. El propulsor, los arpones de
asta, las agujas con ojo y el trabajo de piel están documentados en el
Magdaleniense cantábrico.

El **ciclo estacional de decisiones** del §3 es `INFERIDO`: la estacionalidad de
salmón y berrea es real y los yacimientos muestran ocupación estacional, pero el
calendario concreto de juego es una construcción.
