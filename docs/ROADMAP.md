# Roadmap — CityBuilder cántabro (Godot 4.5.1)

Del Paleolítico al siglo XIX sobre el relieve real de Cantabria.

Este documento se reescribió el **2026-09-02**, tras adoptar la arquitectura de
dos escalas, y se repasó contra el código el **2026-09-12**. Lo que sigue
refleja el estado real, no el deseado.

Ver [SPECS.md](SPECS.md) para el contrato técnico de cada módulo,
[ESTADO.md](ESTADO.md) para qué hace hoy el juego con
cifras medidas, y [AGENTES.md](AGENTES.md) si vais a ser más de uno trabajando
a la vez.

---

## Dónde mirar

| Si buscas… | Ve a |
|---|---|
| **Qué se está haciendo AHORA, y sus tareas** | **«En curso»** — es donde `/plan-tarea` cuelga la lista |
| Los dos 🔴 que bloqueaban la tanda 2, y cómo se cerraron | «En curso» → La puerta de entrada |
| Las tareas de la tanda 1 del Paleolítico | «En curso» → Tanda 1 |
| Las tareas de la tanda 2 del Paleolítico (cerrada el 2026-09-13) | «En curso» → Tanda 2 |
| La tanda 3: quién va, pasarela, herido, guardado, cielo | «En curso» → Tanda 3 |
| Qué está terminado | «Estado actual» → Completado |
| Qué está roto o a medias y molesta | «Estado actual» → Deuda pendiente, y FASE F |
| Por qué hay dos escalas y no hay chunking | «La decisión que ordena todo lo demás» |
| Cerrar el circuito de juego (exploración regional, guardado) | FASE A |
| Procesos, recetas y la escalera térmica | FASE B |
| El arte como motor y el saber que decae | FASE C |
| Las épocas | FASE D — el detalle, en [EPOCAS.md](EPOCAS.md) |
| Datos reales: agua, periodos, geología, trazabilidad | FASE E |
| Qué puede hundir el proyecto | «Riesgos» |

Lo que hace hoy el juego **medido** no está aquí: está en [ESTADO.md](ESTADO.md).

---

## La decisión que ordena todo lo demás

**Dos escalas sobre un solo conjunto de datos.**

| | Capa regional | Capa local |
|---|---|---|
| Qué es | Cantabria entera, tablero de gestión | El city builder |
| Extensión | 199 × 171 km | 4 × 4 km |
| Escala | 1 unidad = 100 m | 1 unidad = 1 m |
| Resolución del dato | 111 m/muestra (zoom 10) | 13,9 m/muestra (zoom 13) |
| Malla | 1993 × 1708 unidades, 1025² | 4096 unidades, 1025² (4 m/vértice) |
| Escena | `scenes/region_map.tscn` | `scenes/demo_main.tscn` |

Las une `Site`: un emplazamiento del mapa regional que, al fundarlo, descarga
su relieve fino y genera el mapa local. El traspaso va por `Expedition`.

**Consecuencia: no hay streaming de chunks.** Un mapa local de 4 km cabe en una
malla única a 28 FPS medidos, y el regional es una malla basta. La antigua
FASE 6 queda cancelada, no aplazada.

---

## Estado actual

### Completado

- **Importación de relieve real.** `DEMImporter` sobre teselas Terrarium de AWS
  (SRTM + NASADEM + EU-DEM + batimetría GEBCO). Sin clave de API y con licencia
  que permite uso derivado, al contrario que Google Maps.
- **Corrección de datos.** `despike()` sustituye artefactos por la mediana de
  sus vecinos: en Cantabria había una franja con +4416 m junto a −1783 m, cotas
  imposibles en la península. Tras corregir, el máximo queda en 2601,8 m, que es
  la cota real de los Picos de Europa.
- **Hidrografía deducida.** Relleno de depresiones (Planchon-Darboux) y
  acumulación de flujo D8. El umbral es área drenada real en km².
- **Frontera por época.** La región es Cantabria más la plataforma continental
  que esté emergida a esa cota del mar. Con el mar actual son 5304 km² —la
  frontera administrativa exacta, contrastada contra los 5321 km² reales—; con
  el mar a −120 m, 7316 km².
- **2067 emplazamientos** derivados del relieve, agrupados a 2 km en **862**
  con **2495 elementos reales adjuntos**. 173 atestiguados contra el registro
  arqueológico de OpenStreetMap.
- **Salto entre escalas.** Seleccionar, fundar, descargar el relieve fino
  (9 teselas, ~7 s) y entrar. `ESC` vuelve.
- **Caché de texturas de terreno** (antigua FASE 5.1). Se generaban 8 texturas
  píxel a píxel en cada `generate()`: 4 s que se pagaban una y otra vez.
- **Rendimiento.** De 4,2 a ~28 FPS con un mapa 12 veces mayor. Las causas eran
  texturas sin mipmaps y 24 muestreos por fragmento en el shader triplanar.
- **La capa de *city builder* retirada entera.** `Architecto`, `Chunk`,
  `BlockData`, `RawMaterial`, `buildings/`, `materials/` y las cabañas de
  prueba. No quedaba nada vivo de la encarnación anterior del proyecto.
- **La simulación de la banda**, que es el juego: quince personas con oficios,
  pericia que crece y se transmite, cacería por fases sobre fauna viva,
  trampas, nasas, meteorología, estaciones, árbol de técnicas por práctica,
  utillaje que se gasta, crónica, parajes con nombre. Todo medido, ver
  ESTADO.md.
- **Se puede perder**, y se puede ganar. Hambre, frío, vejez, nacimientos y
  muertes; y un objetivo doble —sobrevivir el año y dejar la cueva pintada—.
  Ver [archivo/QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md) y
  [archivo/QUE_FALTA_PARA_JUGARLO.md](archivo/QUE_FALTA_PARA_JUGARLO.md).
- **Suite de pruebas**, más las sondas de medida. El ROADMAP pidió una durante
  tres fases; ya está. El total en verde de hoy, en [ESTADO.md](ESTADO.md) §3.
- **Determinismo comprobable.** La misma semilla da la misma partida, año
  entero, y hay herramienta que lo verifica (`Instantanea`, `FirmaDiaria`,
  `Cotejo`).
- **Los tirones, fuera.** A velocidad de juego (×5), un año entero va a 39,1 ms
  de fotograma medio con **ningún tirón grave**, y las noventa primeras jornadas
  pasan de 1 787 tirones de más de 100 ms a 114 — sin que cambie una cifra de la
  partida. Ver [ESTADO.md](ESTADO.md) §5 y el aviso sobre el contador roto de
  [SPECS.md](SPECS.md) §6.1.

### Deuda pendiente

| | Estado |
|---|---|
| Entrada duplicada en `OrbitalCamera` (teclas físicas + acciones del `InputMap`) | sin unificar: el remapeo de teclas no funciona |
| Descarga de teselas bloqueante | congela la ventana unos segundos; no hay hilo |
| Ciclo día/noche (`WorldEnvironmentSetup.follow_time_of_day`) | apagado a propósito para trabajar con luz |
| Capas de física 2–4 (`props`, `resources`, `banda`) | declaradas en `project.godot` y sin asignar a nada |
| Ríos y lagos | deducidos del relieve, no de datos reales (FASE E1) |
| `SettlementSim` de vuelta en 4 119 líneas | el troceado funciona, pero toca otra pasada |

Lo que **se fue** de esta tabla, para no volver a buscarlo: `Inventory.gd` y
`GameUtils.gd` (borrados con el resto de la capa vieja), las señales duplicadas
de `TimeManager` (la clase ya no existe: no hay autoloads, ver SPECS.md §2.2),
y las bocas de cueva mirando arriba (`CaveMouth` ya las abre horizontalmente
contra la ladera).

---

## En curso

**Aquí viven las tareas que se están haciendo ahora.** Es el destino de
`/tareas`: desde el 2026-09-12 no se crea un documento por trabajo, así que la
lista de tareas de lo que esté abierto va aquí, con su cita de HECHO debajo
cuando se cierre. Lo que la tarea aprenda sobre el juego se funde en el
documento permanente que le toque —[SISTEMAS.md](SISTEMAS.md),
[ESTADO.md](ESTADO.md), la ficha de época— y de la tarea sólo queda la línea.

El contexto largo de los bloques que se cerraron antes de este cambio sigue
íntegro en [archivo/](archivo/); no se edita.

---

### Los dos primeros años del Paleolítico

**Spec escrita (2026-09-12) en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, con los criterios de aceptación de cada frente. El mecanismo de lo que
cruza épocas, en **SISTEMAS.md §4, §5, §18 y §19**; lo que se ve, en
**INTERFAZ.md §4**; las cifras medidas, en **ESTADO.md §2** y sólo ahí.
Siguiente paso: `/plan-tarea`, que cuelga aquí la lista de tareas.

Que la primera fase dure dos años **y se juegue**: caminos que la banda aprende
y que caducan con la rejilla estacional, la noche acelerada cuando nadie
trabaja, expedición fuera del mapa para encontrar gente, trueque con
contraparte que recuerda, temperatura en grados y el vestido como necesidad, y
decisiones repartidas por el año que de verdad cuesten. Cierra con tres
condiciones: cueva pintada, expedición mandada fuera y puntos regionales
nuevos.

**Criterio que lo ordena:** sólo entra lo que sirva a las once épocas. Es la
trampa de la época 1 —EPOCA_01 §11, alargarla porque es la que está hecha— y se
descartó a propósito.

**Y va en dos tandas, partidas por lo que se puede medir**, no por lo que
importa más:

| | Qué entra | Se comprueba con |
|---|---|---|
| **Tanda 1** | Los caminos que se aprenden, la noche acelerada, la temperatura en grados visible, y el rendimiento que no empeora | Sondas de días o de una estación: `RodeoProbe`, `FirmaDiaria`, `Cronometro`, `PicoProbe` |
| **Tanda 2** | Expedición fuera del mapa, trueque con contraparte que recuerda, el vestido como necesidad, y las decisiones del año | Un año entero que llegue al final: `AnoProbe`, `BandaProbe` |

**Los dos 🔴 de aquí abajo entran en la spec**, decidido al escribirla:
ninguno es sólo un fallo —el taller que se para es el reparto automático
reasignando al artesano, que es diseño— y sin los dos cerrados **no se mide nada
de la tanda 2**. Ojo con el dueño: el cuelgue sigue asignado a
`history-of-man-0e` y no hay constancia de que esté empezado; quien lo coja, lo
dice en la pizarra primero.

**Depende de:**

- El 🔴 del cuelgue, de aquí abajo. Esto se mide en años, y mientras el
  cuelgue exista no se puede correr un año con reparto pobre. Está **dentro** de
  la spec, no fuera.
- Tres fallos que van por `/depurar` y que hay que cerrar **antes** de diseñar
  encima. **Los tres están hechos** (2026-09-12): la azagaya que no se
  fabricaba, el panel que no decía por qué una técnica estaba parada — ver
  INTERFAZ.md §4 y EPOCA_01 §10.1, donde queda anotado que la causa dominante no
  era el material sino las jornadas— y el rodeo del río, que **no era el río**:
  era el recargo por riesgo del trazado, que multiplicaba el tiempo sin tope y
  hacía que cuarenta metros de ladera costaran kilómetros de rodeo. Ver
  ESTADO.md §2 y SPECS.md §4.3.
- Y el 🔴 del taller, que salió de ese mismo `/depurar` y bloquea esto más
  que el cuelgue: sin taller no hay rama de manufactura, y sin manufactura los
  dos años no se sostienen. También **dentro** de la spec.

  **Los dos primeros, cerrados (2026-09-12, `/depurar`).** Lo que se arregló, y
  lo que se encontró que no estaba escrito en ninguna parte:

  - **El asta se puede buscar, y el desmogadero entrega.** No era sólo que
    `ASTA` faltara en `Parajes.EXTRAS_BY_ACTIVITY`: el desmogadero **ya era** un
    nombre de paraje y ninguna tabla de materia prima daba asta, así que se
    podía ir y volver vacío. `Tajo.ASTA_DE_DESMOGUE` es ahora la única cifra, y
    la usan el recolector, el cantero y la materia prima sin especialidad.
  - **La caza menor se hace con punta lítica**, no con azagaya. Era el bucle:
    sin tendón no se aprende la azagaya y sin caza menor no había tendón.
    `Fauna` ya decía que al corzo se le entra con lanza de mano y
    `SettlementSim.SPECIALITY_TOOL` decía lo contrario.
  - **La banda llega con dos puntas**, no con dos azagayas.
    `SettlementSim.UTILLAJE_INICIAL` es una lista y hay prueba de que nada de
    ella pide técnica.
  - **El panel dice la causa.** `TechTree.freno` / `TechTree.causa` la deciden
    en un solo sitio; la casilla la escribe y la parada por material lleva
    filete de hematites. Ver INTERFAZ.md §4.
  - **Y la causa dominante no era el material sino las jornadas**: medido, 0,62
    jornadas de manufactura al día con el reparto por defecto. Ver ESTADO.md §2.

  - **El rodeo del río era el miedo, no el agua.** Cruzar un vado con el agua
    por la rodilla cuesta 20; subir un canchal, hasta 587, y de esas 587 sólo 58
    son el tiempo que se tarda. El trazado minimiza coste, así que rodeaba. Se
    le puso tope al recargo por riesgo, `Navgrid.RIESGO_MAXIMO`, que **es**
    `Marcha.RODEO_QUE_SE_ANDA` y no una copia. Medido: el rodeo de verano baja
    de x2,40 a x1,43 y los sitios que se admitían y se andaban por encima de su
    propio tope pasan de 88 a 1.
  - **Y la regla del rodeo juzgaba un camino distinto del que se anda.** Había
    dos Dijkstra —uno por coste para el viaje, otro por metros para la regla—;
    ahora es uno, y encima se ahorra. El segundo tapaba un síntoma cuya causa
    era el coste; con el coste arreglado no vuelve, comprobado.

  Los tres cerrados. Y salió uno nuevo, abajo.

---

### La puerta de entrada: los dos 🔴

**Spec y plan técnico en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, «La puerta de entrada». Lista colgada por `/plan-tarea` el 2026-09-12
por `history-of-man-b2`; el cuelgue estaba asignado a `history-of-man-0e`, que
ya no está viva y **no dejó nada en `scripts/` ni en el log** —comprobado, no
supuesto—, así que se coge de cero.

**Lo que cambia respecto de lo que decía este documento:** la hipótesis del
cuelgue —«recorrer `sim.people` mientras `_person_dies` lo modifica», con
`Relevo.gd` de sospechoso sin leer— **está descartada por lectura**: `Relevo`
ya recorre `sim.people.duplicate()` en las tres revisiones, y lo dice su
comentario de la línea 125. El diagnóstico empieza de cero.

**El taller, y es donde ya hay hipótesis medida a medias:**

- [x] **A1. Reproducir el taller parado sin simular 31 jornadas.** Prueba que
      construye el estado —almacén con piedra de sobra y sin fibra, asta ni
      hueso; un artesano en `MANUFACTURA`— y comprueba qué pieza elige
      `Taller._next_piece`, qué contesta `_workshop_short` y adónde le manda el
      recado. **Toca:** `scripts/tests/TestTaller.gd` (nuevo).
      **Verificable:** la prueba deja escrito el estado de hoy. Segundos.

      > **HECHO (2026-09-12).** `scripts/tests/TestTaller.gd`, cuatro pruebas,
      > segundos. **Y el diagnóstico sale distinto del que suponía el plan: el
      > taller no está roto, ha terminado su trabajo.** Construido el estado de
      > la jornada 31 —utillaje lítico cubierto, 3 054 de piedra en el almacén,
      > la cifra medida de la jornada 61— resulta que:
      >
      > - `Taller._next_piece(TALLA)` devuelve **−1**: no queda pieza que
      >   tallar, por mucha piedra que haya. La demanda natural de utillaje
      >   —`tool_natural_demand`: LASCA `gente/2`, RAEDERA 2, BURIL 2, PUNTA 2—
      >   es **fija y pequeña**, y una vez cubierta a `RESERVA_UTILLAJE` (1,3)
      >   no hay más que hacer.
      > - Y por eso `_speciality_can_work(TALLA)` da **false**, que es
      >   exactamente lo que `Reparto.apply_priorities` usa para mandar al
      >   artesano a su siguiente oficio —su comentario lo dice y es
      >   deliberado: «el artesano se va a su siguiente oficio en vez de
      >   quedarse el día entero delante de un banco vacío»—. De ahí la
      >   cuarcita: se va al canchal porque en el taller no hay nada que hacer.
      > - **No es falta de material.** Con 3 054 de piedra, `_workshop_short`
      >   dice que no falta nada: el recado a por materia prima no es la causa.
      > - Y **vuelve**: con el utillaje gastado, `_next_piece` vuelve a dar
      >   pieza. La caída de 2,00 a 0,3 jornadas/día no es una parada, es el
      >   paso del transitorio de equipar a la banda desde cero al **régimen
      >   permanente de reposición**.
      >
      > **Dos premisas del plan se caen con esto**, y están corregidas en
      > EPOCA_01 §10.1: A2 no procede —`_workshop_short` no es la causa— y A3
      > **ya estaba implementado**: `_next_piece` llama a `_can_pay_for` y
      > descarta la pieza sin material, con un comentario que dice justo lo que
      > el plan proponía añadir. Lo que queda no es un arreglo de código sino
      > una decisión de diseño, y está en el chat.
- [~] **A2. `_workshop_short` dice QUÉ falta, no sólo que falta.** Hoy sabe el
      material y devuelve `bool`: quien recibe ese `true` manda al canchal, y
      por eso entra cuarcita —de 96 a 3 054, ESTADO.md §2— mientras la
      manufactura se para. **Toca:** `scripts/sim/Taller.gd`,
      `scripts/sim/SettlementSim.gd` (~2378).
      **Verificable:** A1 en verde y `LlamadasHuerfanas` en 0. Segundos.
- [~] **A3. El artesano no hace lo que no puede hacer.** Que `_next_piece`
      descarte la pieza cuyo material no está, igual que ya descarta la que no
      se sabe hacer y la que nadie pide; y que salir a por material sea el
      último recurso, con destino al material que falta.
      **Toca:** `scripts/sim/Taller.gd`, `scripts/sim/SettlementSim.gd`.
      **Verificable:** prueba nueva en `TestTaller.gd`. Segundos.
- [~] **A4. Que la caída no vuelva, medido.** `ArbolPasoProbe` con el taller
      ocupado a mano a lo largo de 90 jornadas: las jornadas de manufactura por
      día no caen de 2,00, y la recolección no se resiente por competir por el
      mismo tajo. **Toca:** `scripts/tests/ArbolPasoProbe.gd` (añadir `MANU=n`).
      **Verificable:** su tabla jornada a jornada. **Corrida larga, ~45 min.**

      > **A2, A3 y A4 NO SE HACEN, decidido el 2026-09-12 con A1 en la mano.**
      > A1 demostró que no hay fallo que arreglar: A2 atacaba a
      > `_workshop_short`, que no es la causa; A3 **ya estaba implementado**
      > (`_next_piece` llama a `_can_pay_for`); y A4 medía si el arreglo había
      > funcionado, que ya no es la pregunta. El 🔴 se cierra **como hallazgo**:
      > el taller no se para, termina, y lo que queda —que el régimen de
      > reposición no dé para las 110 jornadas de la talla laminar— es
      > **balanceo**, va por `/spec` y no se decide aquí. Las cuatro opciones
      > que se barajaron (que el artesano practique sin demanda, subir
      > `tool_natural_demand`, bajar las jornadas de la laminar, o dejarlo)
      > quedan para esa spec. Ninguna cifra se inventó hoy.

**El cuelgue:**

- [x] **B1. Un vigía que se pueda leer mientras cuelga.** Godot no suelta la
      salida hasta salir, y por eso hubo «17 minutos sin una línea de log»: un
      fichero con `flush()` por fase dice dónde se quedó sin matarlo a ciegas.
      **Toca:** `scripts/tests/AnoProbe.gd`. **Verificable:** dos jornadas y el
      fichero tiene fases. Minutos.
- [x] **B2. Reproducirlo construyendo el estado, no simulándolo.** Despensa a
      cero, hambre al máximo en los quince, verano al filo del cambio a otoño, y
      dar pasos. **Toca:** `scripts/tests/TestCuelgue.gd` (nuevo).
      **Verificable:** cuelga, o no cuelga —y si no cuelga, la premisa se cae y
      se dice—. Minutos.
- [x] **B3. Decir cuál es el bucle.** No arreglar el primer sospechoso: nombrar
      el bucle con su fichero y su línea. Depende de B1 y B2.
- [x] **B4. Arreglarlo, con una prueba que falle antes.**
      **Toca:** donde caiga, más `scripts/tests/`.

      > **HECHO (2026-09-12), y B1–B3 con él.** `scripts/tests/CuelgueProbe.gd`
      > (nueva, con vigía), `SettlementSim.partida_terminada()`, tres pruebas en
      > `TestPartida.gd`, y el arreglo en `AnoProbe.gd`.
      >
      > **No era un bucle del juego: era el instrumento esperando a un muerto.**
      > `SettlementSim._process` abre con `if people.is_empty() or _terrain ==
      > null or time_scale <= 0.0: return`, así que con la banda extinta no
      > avanza nada y `day` se queda clavado. `AnoProbe` esperaba con
      > `while sim.day < primero + dias: await process_frame`, o sea **una
      > jornada que ya no iba a llegar nunca**: fotogramas vacíos a un núcleo
      > entero, y ni una línea de log porque no había nada que imprimir. De ahí
      > los «17 minutos sin escribir» y el tener que matarlo a mano.
      >
      > **Reproducido en 63 segundos, no en 45 minutos**, construyendo el
      > estado en vez de simularlo: verano a dos días del cruce, despensa a
      > cero, hambre 100 y `hunger_sick_days` a un día del umbral de
      > `Relevo`, para que los quince mueran la misma jornada. El vigía —a
      > fichero con `flush()`, porque Godot no suelta la salida hasta salir—
      > lo dejó escrito:
      >
      > ```
      > JORNADA 2 · Verano · vivos 0 · desenlace 2
      > CUELGUE CONFIRMADO · 4001 vueltas sin que avance el dia 2 ·
      >   vivos 0 · desenlace 2 · reloj x5.0
      > ```
      >
      > Nótese `reloj x5.0`: **no era el reloj parado por un `Moment` sin
      > contestar**, que era la otra sospecha razonable. Era la banda muerta.
      >
      > **Y se descarta del todo la hipótesis que traía el ROADMAP**: no hay
      > ningún bucle que recorra `sim.people` mientras `_person_dies` lo
      > modifica. `Relevo` ya recorría copias.
      >
      > El arreglo es `partida_terminada()` —la pregunta en un solo sitio,
      > invariante 3 de SPECS §7— y que quien espere jornadas la consulte. Una
      > corrida que antes había que matar ahora imprime en qué jornada terminó
      > la partida y hasta dónde miden sus tablas.
- [x] **B5. La corrida literal del criterio.** `SEMILLA=42 DIAS=95 BANDA=4,3,2`
      sobre `AnoProbe` **termina y escribe sus tablas**. No vale otra corrida:
      cambiarle el reparto para medir de paso otra cosa deja de reproducir lo
      que se quería reproducir. **Corrida larga, ~45 min.**

      > **HECHO (2026-09-12).** Terminó y escribió sus tablas, con
      > `desenlace: NINGUNO`. El criterio de aceptación del 🔴 queda cumplido.
- [x] **B6. ¿Es 4,3,2 viable, o es hambre garantizada?** La otra mitad de la
      pregunta, y **se lee de la misma pasada de B5** —hambre, muertes y
      despensa por estación, que `AnoProbe` ya saca—: no cuesta una corrida
      más. Si la respuesta es que no, es un hallazgo de balanceo y va a
      ESTADO.md §2.

      > **HECHO (2026-09-12): 4,3,2 es viable, y el parte del 🔴 ya no
      > describe el juego.** Los quince vivos las 95 jornadas, hambre media
      > clavada en 26 —el umbral de enfermedad es 70— y la despensa subiendo:
      >
      > | día | estación | gente | despensa | días de reserva | hambre |
      > |---|---|---|---|---|---|
      > | 1 | Primavera | 15 | 101 | 4,0 | 20 |
      > | 46 | Verano | 15 | 517 | 20,4 | 26 |
      > | **76** | **Verano** | **15** | **460** | **18,1** | **26** |
      > | 91 | Otoño | 15 | 556 | 21,9 | 26 |
      >
      > **Compárese el día 76 con el parte del 🔴**, que en esa misma jornada
      > medía «despensa = 0 y hambre media 100». Entre una medida y otra se
      > cerraron los tres fallos de `/depurar`, y el del rodeo del río es el
      > que lo explica: bajar el rodeo de verano de x2,40 a x1,43 es la mitad
      > del día que la banda se pasaba andando. **No era el reparto: era el
      > trazado.**
      >
      > Y con esto **se desbloquea «la pesca sin sitio conocido»** del bloque
      > del secadero, que estaba 🔒 esperando a este diagnóstico. La corrida
      > ya trae su medida: ver ESTADO.md §2.

**Presupuesto de máquina: ~1 h 30 de corridas largas**, A4 y B5 seguidas —Godot
es de uno en uno, AGENTES.md §3—. Todo lo demás son pruebas de segundos. La
contingencia es B2: si el estado construido no reproduce el cuelgue, hace falta
la corrida literal con el vigía para localizarlo, y eso son otros ~45 min.

**Al cerrar:** las cifras nuevas van a [ESTADO.md](ESTADO.md) §2 y el total de
la suite a §3, que son las únicas copias.

---


---

### ~~Tanda 2: expedición, trueque, el vestido y las decisiones del año~~ — cerrada

**CERRADA el 2026-09-13.** Todo lo estructural hecho y medido con dos años de
partida. Suite **1 076 pruebas y 7 161 comprobaciones**, desde 979/6 994. Lo
aprendido está en EPOCA_01 §10.1 («Cierre de la tanda 2»), SISTEMAS §4, §5, §18
y §19, SPECS §4.4 y §4.6, INTERFAZ §4 y ESTADO §2 y §5.

| | |
|---|---|
| La expedición | Sale, descubre **4 sitios** por vuelta y deja contacto; **la primera siempre encuentra gente** |
| El trueque | Con contraparte que recuerda y seis maneras de tratar; **tasa sin medir**, 0 intentos en la pasada |
| El vestido | Cierra las cumbres con frío; **en el invierno en casa no cambia nada**, aceptado como hallazgo |
| Las decisiones | **4 al año que cuestan**, una por estación |
| **Lo que queda abierto** | 🔴 **La banda muere de hambre en el segundo invierno** (ESTADO §5, punto 13), por `/depurar`. Hasta entonces ninguna cifra de año vale |

**Spec y plan técnico en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, tanda 2 y «Plan técnico de la tanda 2». Lista colgada por
`/plan-tarea` el 2026-09-12 por `history-of-man-11`.

**Suelo de la suite al abrir: 979 pruebas, 6 994 comprobaciones, TODO OK.**

**Tres premisas de la spec que el código no sostiene**, en el plan con detalle:
la **niebla regional ya está construida** (`GameState.discovered` +
`RegionMap`), `PanelSitios` **no lista emplazamientos regionales** —es el panel
local—, y `Site` es **un recurso horneado**, así que el contacto no puede vivir
ahí.

**La expedición** (frente 5) — nadie depende de nada, y todo depende de ella:

- [x] **E1. Medir la niebla que ya hay, antes de tocarla.** *(Decidido el
      2026-09-12: se mide y se corrige la documentación que dice lo contrario
      —SISTEMAS §4 y FASE A1—, en vez de reconstruir algo que funciona.)* Cuántos `Site`
      lista `RegionMap` al empezar la partida. Si ya son un puñado, el primer
      criterio del frente está cumplido y se escribe; si son 862, está roto y
      es otra tarea.
      **Toca:** `scripts/tests/TestNiebla.gd` (nuevo), ESTADO.md §2.
      **Verificable:** la prueba deja la cifra escrita. Segundos.

      > **HECHO (2026-09-12), y la premisa se confirma: estaba construida.**
      > `scripts/tests/TestNiebla.gd`, 4 pruebas. Al empezar la partida se
      > conoce **un** emplazamiento, la cueva. El criterio «no ver los 862 de
      > golpe» estaba cumplido de sobra.
      >
      > **Y lo que falta queda localizado:** nadie llama a
      > `GameState.discover` desde la partida, así que **la niebla no se
      > levanta nunca**. El mapa regional se queda en la cueva para siempre.
      > Eso es E3, y ahora se sabe que es lo único que falta de esta mitad.
      >
      > **Dos cifras de la documentación estaban mal**, y se corrigen en
      > SISTEMAS §4 y ESTADO §2: el conjunto horneado tiene **869**
      > emplazamientos y no 862 —los siete de más son los de prueba— y de ésos
      > sólo **72** son usables en el Paleolítico con el mar a −120 m. Los
      > «puntos regionales nuevos» que cierran la fase se miden contra 72.
- [x] **E2. `Contacto`: quién hay ahí fuera.** Subsistema nuevo: qué `Site`
      están ocupados —sorteado con el `_rng` al empezar— y con cuáles se ha
      tratado. **No va en `Site`**, que es dato horneado, ni en `GameState`,
      que es lo que cruza escenas: es estado de simulación y la instantánea
      tiene que recorrerlo.
      **Toca:** `scripts/sim/Contacto.gd` (nuevo), `scripts/sim/SettlementSim.gd`,
      `scripts/tests/TestContacto.gd` (nuevo).
      **Verificable:** pruebas —el sorteo sale del `_rng`; el contacto
      sobrevive a una estación; `LlamadasHuerfanas` en 0—. Segundos.

      > **HECHO (2026-09-12).** `scripts/sim/Contacto.gd` (nueva) y
      > `scripts/tests/TestContacto.gd`, 10 pruebas. Suite **993 pruebas,
      > 7 022 comprobaciones**. Guarda quién está ocupado —sorteado con el
      > `_rng`— y el `trato` con cada contraparte, con la forma del de
      > `ElLobo`, que es lo que la spec pedía para que el peldaño escale.
      >
      > **Y una guarda que salió de escribir la prueba, no del plan:** repartir
      > la comarca dos veces la cambiaba, porque el segundo sorteo usaba el
      > `_rng` ya avanzado —19 ocupados la primera vez, 12 la segunda—. O sea
      > que la gente que habías conocido dejaba de estar donde estaba. Ahora se
      > reparte **una sola vez** y la segunda llamada no hace nada.
      >
      > `OCUPADOS` (uno de cada cinco) y los topes del trato **son decisiones y
      > está dicho en el código**: no hay dato arqueológico de cuántos de los 72
      > emplazamientos del Magdaleniense estaban habitados a la vez.
- [x] **E3. `Expedicion`: la salida larga, y lo que cuesta.** Se manda gente,
      tarda jornadas, come de su propia cuenta de `Despensa`, y al volver
      descubre `Site` —es el único sitio que llama a `GameState.discover`—.
      Vuelva con algo o vuelva de vacío, las jornadas se han ido.
      **Toca:** `scripts/sim/Expedicion.gd` (nuevo), `scripts/sim/SettlementSim.gd`,
      `scripts/sim/Despensa.gd`, `scripts/tests/TestExpedicion.gd` (nuevo).
      **Verificable:** pruebas —descubre y sube la cuenta; consume raciones y
      jornadas; **la que vuelve sin llegar cuesta igual**—. Segundos.

      > **HECHO (2026-09-12).** `scripts/sim/Expedicion.gd` (nueva), 13 pruebas
      > en `TestExpedicion`. Se sale con 3 adultos como mínimo, 12 jornadas
      > fuera, y se llevan **las raciones de todo el viaje** antes de salir —en
      > la cuenta de siempre, `Materia.KCAL_RACION`: 3 × 12 × 2 = 72—. Al
      > volver se descubren el destino y sus vecinos más cercanos.
      >
      > **Tres cosas que no estaban en el plan:**
      >
      > - **Quien sale deja de existir en el mapa local.** No basta con que no
      >   trabaje: `SettlementSim._advance` no le da tick y `Reparto` no le
      >   asigna nada. Si no, «salir del valle» era seguir paseando por él.
      >   `Inhabitant.expedicion_hasta` es la marca.
      > - **La regla de qué comida aguanta un viaje estaba escrita dentro de
      >   `Despensa._provision`**, y la expedición la habría copiado. Ahora es
      >   `Despensa.LO_QUE_AGUANTA_EL_VIAJE` y la usan las dos.
      > - **Y compilaba sin funcionar.** Con las pruebas en verde, en el juego
      >   real nadie le pasaba la comarca a la expedición ni repartía quién
      >   vive dónde: salía, gastaba y volvía sin descubrir nada. El cableado
      >   va en `DemoMain`, que es donde SPECS §2.3 dice que se cablea, y lo
      >   comprueba `scripts/tests/ExpedicionProbe.gd` **en la escena de
      >   verdad**: comarca cargada, 16 emplazamientos con gente, salida con
      >   72 raciones, vuelta con 4 descubiertos y 36 jornadas-persona.
      >
      > Una prueba pasaba **sin comprobar nada**: «la que vuelve sin nada cuesta
      > igual» comparaba jornadas de dos expediciones, y cero contra cero
      > también son iguales. Ahora exige que las dos hayan salido.
      >
      > **Y lo que falta, dicho:** no hay botón. `Expedicion.mandar` es el
      > mecanismo; que el jugador pueda mandarla es una decisión y va con el
      > frente 8.
- [x] **E4. Alcanzar un sitio ocupado deja contacto.** Y el contacto sigue ahí
      una estación después, que es lo que el trueque va a usar.
      **Toca:** `scripts/sim/Expedicion.gd`, `scripts/sim/Contacto.gd`,
      `scripts/tests/TestContacto.gd`. **Verificable:** prueba. Segundos.

      > **HECHO (2026-09-12), y ya lo hacía E3:** `Expedicion._volver` llama a
      > `Contacto.conocerse` si el destino tiene gente. Lo que añade esta tarea
      > son las tres pruebas que lo cierran —dejar contacto donde hay gente,
      > **no** dejarlo donde no la hay, y que siga ahí **cuarenta y cinco
      > jornadas después**, literal—. La del sitio vacío se comprobó rompiendo
      > `Contacto.hay_gente_en` a propósito: se pone roja.
      >
      > Suite al cerrar el frente 5: **1 009 pruebas, 7 057 comprobaciones**,
      > desde 979/6 994. `LlamadasHuerfanas` sigue en las 2 de siempre.

**El trueque** (frente 6) — **depende entero de E2 y E4**:

- [x] **T1. El trueque deja de ocurrir solo.** Fuera la llamada automática por
      estación; pasa a ser un `Moment` con opciones. En un año sin que el
      jugador decida nada, intercambios consumados = 0.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/sim/SettlementSim.gd`
      (~3350), `scripts/tests/TestIntercambio.gd`.
      **Verificable:** prueba de que sin decisión no hay trato. Segundos.
- [x] **T2. La contraparte recuerda, y el 55 % fijo deja de ser fijo.** El
      `trato` por contraparte, con la forma del de `ElLobo`, sustituyendo a
      `PROBABILIDAD_EXITO`.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/sim/Contacto.gd`,
      `scripts/tests/TestIntercambio.gd`.
      **Verificable:** prueba —ser generoso sube la tasa, regatear la baja— .
      Segundos. **La confirmación en partida va en la pasada larga.**
- [x] **T3. Qué se ofrece, y que duela.** El fruto seco deja de estar clavado:
      la opción dice qué sale de la despensa, y sacarlo en invierno se nota.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/ui/`.
      **Verificable:** prueba sobre la despensa de las jornadas siguientes.
      Segundos.
- [x] **T4. Sílex, concha y gente, y las tres llegan.** Una prueba por cada
      una. **Antes de prometer nada hay que comprobar que `Materia.Kind.CONCHA`
      existe y que llegar gente tiene por dónde**; si no, se dice y se recorta.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/economia/Materia.gd`,
      `scripts/tests/TestIntercambio.gd`. **Verificable:** tres pruebas. Segundos.

      > **T1–T4 HECHAS (2026-09-12), juntas porque viven en el mismo fichero.**
      > `Intercambio.gd` reescrito y `TestIntercambio.gd` también, 18 pruebas.
      > Suite **1 023 pruebas, 7 041 comprobaciones**.
      >
      > **Lo que hace ahora:** una vez por estación, si se conoce a alguien, se
      > **propone** con un `Moment` de kind `TRUEQUE` —nuevo—. La primera
      > opción es **no ir**: no decidir no puede costar nada, y las sondas
      > contestan con la primera opción, así que si fuera tratar, «sin decidir
      > nada, cero intercambios» haría tratos solo. Cada opción lleva **escrito
      > lo que cuesta**, que es media petición del frente 8. Ir saca a alguien
      > del mapa 4 jornadas —la misma marca que la expedición—, salga como
      > salga. La probabilidad sale del `trato` con esa gente y **se lee antes
      > de moverlo**, porque lo que recuerdan es lo de las veces anteriores.
      > Concha y gente llegan: la concha existía y la gente entra como en
      > `Relevo`, cuya regla del id libre sale a `Relevo.id_libre` porque ya la
      > preguntan dos.
      >
      > **Medido: 0,950 siendo generosos contra 0,080 regateando**, trescientos
      > intentos cada uno y misma semilla. **Y esa cifra exagera, dicho para
      > que no se lea mal**: en trescientos intentos seguidos el trato llega a
      > sus topes. En una partida se trata unas cuatro veces al año. La prueba
      > demuestra **la dirección**; la magnitud jugada la mide M1.
      >
      > **Una simplificación, dicha:** las cuatro decisiones de la spec darían
      > veintisiete combinaciones. Se ofrecen seis con sentido, siempre con la
      > contraparte de mejor trato. Si el juego pide elegir contraparte a mano,
      > se añade entonces.
      >
      > **El total bajó en 16 comprobaciones** respecto de la vuelta anterior
      > (7 057 → 7 041), y se dice: es exactamente `TestIntercambio`, de 652 a
      > 636, por reescribir una prueba cuyo comportamiento **se invierte a
      > propósito**. Dos de las pruebas viejas afirmaban «un intento por cada
      > estación» y «llega sílex al pasar estaciones», que es lo que la tanda
      > quita. Sigue por encima del suelo de la tanda (6 994).
      >
      > **Y dos pruebas pasaban en vacío, cazadas antes de cerrar:** en GDScript
      > **las lambdas capturan las variables locales por valor**, así que
      > `var propuestos := 0` con `propuestos += 1` dentro de la lambda contaba
      > sobre una copia. «Sin conocer a nadie no se propone nada» esperaba cero
      > y valía cero siempre, se propusiera o no. Ahora cuentan con un array y
      > llevan control positivo. Ver ARQUITECTURA §5.
      >
      > Las dos pruebas clave se comprobaron rompiendo el código: sin memoria de
      > la contraparte, generosos y regateando salen idénticos (0,573 y 0,573);
      > y si vuelve a tratar solo, en ocho estaciones trae 6 de sílex.

**El vestido** (frente 7) — no depende de nada, se puede hacer en paralelo:

- [x] **V1. El frío lo dicen los grados, no la estación.** Hoy `cold` sube sólo
      si es invierno **y** el hogar está apagado. Pasa a subir en función de
      `Termometro`, que es lo que hace que dormir al raso en enero no sea lo
      mismo que en julio —tercer criterio del frente— y de paso quita una regla
      del clima escrita fuera del termómetro.
      **Toca:** `scripts/sim/SettlementSim.gd` (~1786-1815),
      `scripts/tests/TestFrio.gd` (nuevo).
      **Verificable:** pruebas de estado construido —misma noche, dos
      estaciones, dos resultados—. Segundos. **Es el cambio con más riesgo de
      balance de la tanda.**
- [x] **V2. El frío cierra el roquedo.** Sin ropa buena, la salida al roquedo
      en invierno se rechaza, con motivo que el panel dice. Patrón:
      `TechTree.freno` / `TechTree.causa`.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/ui/`,
      `scripts/tests/TestFrio.gd`. **Verificable:** prueba de que se rechaza y
      de que el motivo llega. Segundos.

      > **V1 y V2 HECHAS (2026-09-12).** `SettlementSim.frio_por_hora` es la
      > única pregunta «¿cuánto enfría esta noche?» del juego, y la usan las
      > tres ramas de sueño —la cueva, el vivac y el que duerme donde le coge—.
      > `TestFrio`, 19 pruebas. Suite **1 042 pruebas, 7 087 comprobaciones**.
      >
      > **Premisa caída en V1: al raso no se cogía frío en NINGUNA estación.**
      > Dormir fuera sólo tocaba la fatiga. El tercer criterio del frente no
      > fallaba: no había nada que medir. Ahora sin hoguera se enfría por los
      > grados que haga, con hoguera se entra en calor.
      >
      > **La pendiente no se eligió:** está calibrada para que una madrugada de
      > invierno al nivel del mar dé exactamente el `HEARTH_COLD_RISE` de antes
      > (4,0/h), así que en ese punto el balance es el de siempre. Lo nuevo es
      > la altitud. **Comprobado en la escena real** con `FrioProbe`: una noche
      > sin fuego deja frío medio **0,00 en verano (13,0 °C en el abrigo) y
      > 30,52 en invierno (0,6 °C)**. Ese abrigo está a 135 m y enfría ~23 %
      > más que el «si es invierno» de antes: es el gradiente contando.
      >
      > **El umbral, 5 °C, es uno solo:** nació en la barra como
      > `GRADOS_QUE_MUERDEN`, una cifra de interfaz que sólo elegía un color, y
      > se mudó a `Termometro.GRADOS_DE_ABRIGO` en cuanto empezó a decidir la
      > partida.
      >
      > **Premisa caída en V2: el roquedo no existe como sitio en el código.**
      > Sólo aparece en dos comentarios. La salida a lo alto modelada es la
      > ascensión, y ahí va la puerta: `Cumbres.motivo_del_frio`, en los cuatro
      > caminos por los que se elige cumbre, junto a la de la cuerda. Sin
      > **un vestido por cada uno de la cordada** no se sube adonde de madrugada
      > se coge frío, y el motivo llega por `order_ascent`, que es lo que enseña
      > el panel. Una prueba recorre cinco cotas y cuatro estaciones y comprueba
      > que **la puerta se cierra exactamente donde la noche empieza a enfriar**.
      >
      > **Y es más fuerte de lo que pedía la spec, decidido así el 2026-09-12
      > con los números delante.** La spec decía «en invierno»; con la
      > madrugada como medida, sin abrigo se cierra: **en invierno, todo; en
      > primavera, por encima de 164 m; en otoño, de 580 m; en verano, de
      > 1 364 m**. Como la banda empieza en primavera sin ropa, **la primera
      > ascensión espera al verano o a que se cosan dos vestidos**, y las
      > ascensiones son las que revelan media comarca. Se ofreció mirar la media
      > del día —que abría la primavera hasta ~750 m— y se prefirió la versión
      > estricta, que hace la peletería urgente desde el primer día. **M1 dirá
      > si retrasa la fase de más.**
      >
      > Rompió una prueba de `TestExploration` que subía una cumbre sintética
      > de 300 m en primavera sin ropa. No se aflojó la puerta: se equipó a la
      > cordada en el montaje, porque esas pruebas van de subir y no de frío.

- [x] **V3. La cota de nieve sale del termómetro.** *(Añadida el 2026-09-12 a
      petición del usuario.)* Hoy `Temporada.COTA_DE_NIEVE` es **una fracción
      de la altura máxima del mapa local**, así que no depende del clima sino
      del mapa en que se esté: en un valle bajo pone la nieve bajísima y en los
      Picos altísima. Y es un segundo sistema describiendo el mismo frío que
      `Termometro`, sin hablarse. Pasa a ser la cota donde la media llega a
      0 °C: ~805 m en invierno, ~1 520 en primavera, ~1 930 en otoño, y por
      encima de los Picos en verano.
      **Toca:** `scripts/mundo/Temporada.gd`, `scripts/mundo/Termometro.gd`,
      `scripts/DemoMain.gd`, y lo que lea la cota —`TerrainGenerator.set_snow_line`,
      `Marcha` por `freno_por_nieve`—, `scripts/tests/`.
      **Verificable:** pruebas de la cota por estación y de que es absoluta,
      no fracción del mapa. Toca la vista y lo que cuesta andar, así que **va
      antes de M1** para que la pasada larga lo mida. Segundos.

      > **HECHO (2026-09-12), con la madrugada y no con la media.** La tarea
      > se planteó con la media a 0 °C y, al implementarla, salió que **en el
      > valle de partida no nevaría nunca**: el relieve va de 96 a 718 m y la
      > media de invierno hiela a ~805 m. Se preguntó con esa tabla delante y
      > se eligió la madrugada, que además es la misma hora que usa el frío de
      > la gente. `Termometro.cota_de_hielo` y `Temporada.fraccion_de`;
      > `COTA_DE_NIEVE` se borra. Suite **1 047 pruebas, 7 098 comprobaciones**.
      >
      > **Comprobado en la escena real** con `NieveProbe`: relieve 96–718 m;
      > **invierno 221 m, dentro del mapa**; primavera 933, otoño 1 349 y
      > verano 2 133, todas por encima de la cumbre. Antes la nieve de invierno
      > empezaba a 357 m.
      >
      > **Por qué la de antes era tan baja:** salía del Dryas reciente, que es
      > más frío que el 12 000 a.C. en que se fijó la época.
      >
      > **Dos pruebas de `TestSubsistence` montaban `Temporada` sin relieve** y
      > se pusieron rojas: sin relieve no se sabe dónde cae la nieve y no nieva.
      > Se les dio el del valle, y eso mismo destapó por qué había que
      > comprobarlo en la escena: el caso borra la nieve en silencio.
      >
      > **Y un efecto de balance que M1 va a notar:** el abrigo está a 135 m y
      > la nieve de invierno empieza a 221, así que **en invierno casi cualquier
      > salida cuesta arriba anda por nieve**, y `freno_por_nieve` frena la
      > marcha más que antes.

**Las decisiones** (frente 8) — depende de T1 para contar el trueque:

- [x] **D1. Un `Moment` declara lo que cuesta cada opción.** Hoy `options` es
      libre y **el criterio no se puede medir**: «cuenta sólo si la opción no
      elegida cambia una cifra» necesita que la cifra esté escrita.
      **Toca:** `scripts/banda/Moment.gd`, quien levante momentos,
      `scripts/tests/TestMoment.gd`. **Verificable:** prueba. Segundos.
- [x] **D2. Una decisión fija por estación.** Cuatro al año que no se pueden
      evitar. Las que dispare el estado van encima, **sin inflar el
      calendario** para llegar a un número.
      **Toca:** `scripts/sim/`, `scripts/tests/`. **Verificable:** prueba de
      que cada estación levanta la suya. Segundos.

      > **HECHO (2026-09-12). Las tres que no eran la berrea las eligió el
      > usuario** entre las que se le propusieron, y las tres salen de sistemas
      > que ya existían:
      >
      > | Estación | Decisión | Cuesta |
      > |---|---|---|
      > | Primavera | ¿se sale del valle? — `Expedicion.proponer_la_salida` | 36 jornadas y 72 raciones |
      > | Verano | ¿se sube ahora que no hiela? — `Cumbres.proponer_la_subida` | riesgo de la ascensión |
      > | Otoño | la berrea | 15 jornadas por cazador |
      > | Invierno | ¿cuánto fuego? — `Hogar.proponer_el_fuego` | la mitad de las noches sin fuego |
      >
      > Una prueba cuenta **las cuatro en un año**, y otra que la opción 0 de
      > todas no compromete a nada. Suite **1 071 pruebas, 7 148
      > comprobaciones**.
      >
      > **Tres cosas de las que conviene enterarse:**
      >
      > - **La de primavera es el botón que la expedición no tenía.** Hasta hoy
      >   `Expedicion.mandar` sólo se llamaba desde código.
      > - **La del fuego está hecha para costar en las dos direcciones.** El
      >   fuego de este juego es binario, así que si racionar sólo gastara
      >   menos, siempre convendría. Racionado es **una noche con fuego y otra
      >   sin él**: la mitad de leña, y la noche sin fuego se pasa el frío de V1
      >   entero. Ninguna cifra de calor inventada. La cueva pregunta ahora
      >   `Hogar.calienta_esta_noche()`, no `hearth_lit`.
      > - **La berrea estaba al revés** —«volcarse» era la opción 0— y por eso
      >   **seis sondas** la contestaban con la opción 1 como caso aparte:
      >   `TironAnualProbe`, `AnoProbe`, `ArbolPasoProbe`, `CuelgueProbe`,
      >   `DecisionProbe` y `RitmoProbe`. Se puso en orden y se quitó la
      >   excepción de todas, **porque si se hubiera dejado en una sola, esa
      >   sonda habría pasado a volcarse en la berrea sin avisar** —y `AnoProbe`
      >   es la de M1—.
      >
      > **Y un tropiezo con la herramienta:** llamar `proponer()` a los cuatro
      > métodos subió `LlamadasHuerfanas` de 2 a 10 —cruza nombres sin mirar el
      > receptor—. Se les dio nombre propio a cada uno y volvió a 2.
      >
      > **Y un hueco que destapó la prueba de humo de M1, antes de lanzarla:**
      > la partida empieza **ya dentro de la primavera**, y las decisiones de
      > estación saltan al *cambiar* de estación. Así que **la de primavera del
      > primer año no salía nunca**: la primera expedición esperaba al año 2 y el
      > primer año tenía tres decisiones, no cuatro. Ahora la de la estación en
      > curso sale también en `SettlementSim.iniciar_partida()`, desde un solo
      > sitio —`_decision_de_la_estacion`—, con prueba. Se arregló **antes** de
      > lanzar la pasada larga, que es la lección de ayer: con una medida en
      > vuelo no se toca el código.
- [x] **D3. La berrea deja de ser gratis.** Volcarse significa que ese mes no
      se recolecta ni se hace leña.
      **Toca:** donde viva la berrea, `scripts/tests/`. **Verificable:** prueba
      sobre las raciones de ese mes. Segundos.

      > **D1 y D3 HECHAS (2026-09-12)**, en `scripts/tests/TestDecisiones.gd`
      > —13 pruebas— y no en un `TestMoment` como decía el plan: son el mismo
      > frente. Suite **1 060 pruebas, 7 122 comprobaciones**.
      >
      > **D1.** Cada opción declara `"cuesta"` en las tres cifras de la spec
      > —despensa, jornadas, riesgo— con `Moment.opcion`, y
      > `Moment.la_eleccion_importa()` dice si al menos dos cuestan distinto.
      > Dos botones con el mismo coste **no cuentan como decisión**, con prueba.
      > El trueque y la berrea ya declaran lo suyo; la piel ofrecida no cuenta
      > en la despensa porque no se come.
      >
      > **D3, y con un fallo de verdad debajo.** Volcarse ponía la caza mayor a
      > **prioridad 3, que en este reparto es la menos urgente** —van de 1 a
      > 3—, así que quien tuviera recolección a 1 o 2 seguía recolectando y
      > volcarse casi no hacía nada. La opción prometía «se dejan de hacer otras
      > cosas: es la apuesta» y el código no lo cumplía. Ahora, durante
      > **un mes del juego** (`Subsistence.DAYS_PER_MONTH`, 15 jornadas, porque
      > la spec dice «ese mes»), la caza mayor a 1 y **la recolección entera
      > apagada** para quien va; al acabar, **cada uno recupera exactamente sus
      > prioridades de antes**. La tarjeta dice cuántas jornadas no se recogen.
      > Comprobado rompiéndolo: si no se apaga la recolección, caen tres pruebas.
      >
      > **Lo que falta del criterio, dicho:** «se ve en las raciones
      > recolectadas de ese mes» es cifra jugada, y la mide M1.

**El cierre de la fase:**

- [x] **C1. Las tres condiciones, no una.** `Partida.evaluar_victoria` pasa a
      pedir cueva pintada **más** expedición mandada **más** puntos regionales
      nuevos. Depende de E3.
      **Toca:** `scripts/sim/Partida.gd`, `scripts/tests/TestPartida.gd`.
      **Verificable:** prueba de que **con dos no se cierra**. Segundos.

      > **HECHO (2026-09-12).** `Partida.evaluar_victoria` pide cueva pintada
      > **y** `expedicion_mandada()` **y** `puntos_nuevos()`, y
      > `lo_que_falta_para_cerrar()` dice cuáles faltan. Suite **1 074 pruebas,
      > 7 154 comprobaciones**.
      >
      > La prueba vieja se llamaba «banda viva y cueva pintada gana», que es
      > literalmente la regla que esto sustituye, y **se reescribió en vez de
      > borrarse**. La nueva recorre las tres maneras de tener dos de tres y
      > comprueba que ninguna cierra, que es el criterio explícito. Y una más:
      > **mandar la expedición y que vuelva de vacío no basta** —cuenta para la
      > segunda condición y no para la tercera—.
      >
      > De paso se quitó un `capturados[0]` que reventaba si no salía la
      > tarjeta: una prueba que revienta antes de su assert no falla, pasa.

**Lo que se mide, y es donde está el dinero:**

- [x] **M1. La pasada larga, una sola, con seis contadores.** Dos años
      simulados con la noche acelerada, instrumentados para contestar de una
      vez: que el desenlace llega y **tarda entre año y medio y tres años**;
      que en el primer año sin decidir nada hay **0 intercambios**; **cuántas
      decisiones** de las que cuestan caen al año; **cuánto sube** la cuenta de
      `Site` descubiertos por expedición y qué cuesta; la tasa de éxito del
      trueque siendo generoso; y **la caza vuelta a medir**, que es el 0,27 de
      ESTADO.md §2 que nadie ha tocado desde que se abrieron las puertas del
      asta y la punta lítica.
      **Toca:** `scripts/tests/BandaProbe.gd` o sonda nueva, ESTADO.md §2.
      **Corrida larga: ~1 h 55.**

      > **PRIMERA PASADA PARADA a la jornada 46 (2026-09-13), y era la sonda.**
      > El vigía decía «expediciones 0» entrado el verano con un jugador que
      > manda la expedición en primavera. **No se había contestado ninguna
      > decisión.** La primera tarjeta de la partida —«Un abrigo, una banda»— es
      > un aviso sin opciones, y `AnoProbe` sólo contestaba tarjetas *con*
      > opciones: se quedaba parada delante, y todas las decisiones del año se
      > apilaban detrás sin enseñarse. **Cinco sondas de seis tenían el mismo
      > agujero** (Año, ArbolPaso, Cuelgue, Ritmo y FrioInvierno); sólo
      > `TironAnualProbe` cerraba los avisos. Así que toda cifra de esas sondas
      > que dependa de una decisión, **desde que existe el aviso inicial**, se
      > midió con las decisiones sin contestar. Arreglado **en un sitio y no en
      > seis**: `BarraSuperior.contestar_todo(elige)` contesta las decisiones y
      > cierra los avisos, y las seis sondas lo llaman.
      >
      > **Y un fallo de verdad que salió al mirar:** `Expedicion.mandar` sacaba
      > de la despensa lo que hubiera y *después* veía que no llegaba; la
      > expedición no salía y la comida desaparecía igual. Ahora mira antes de
      > sacar, con su comprobación en `TestExpedicion`.
      >
      > **Prueba de humo antes de relanzar**, 14 jornadas y 4 min 30: con el
      > jugador razonable la expedición sale la primera jornada (36
      > jornadas-persona) y vuelve con **4 sitios descubiertos**; a la fase ya
      > sólo le falta la cueva pintada. Suite: 1 075 pruebas, 7 156
      > comprobaciones. Relanzada con M2 delante.

      > **MEDIDA (2026-09-13), y los criterios NO se cumplen.** 1 h 52,
      > `SEMILLA=42 JUGADOR=razonable DIAS=360`. **La banda muere de hambre en la
      > jornada 359**, sin cerrar la fase (falta la cueva pintada). **4 decisiones
      > que cuestan cada año**, lo único que sale como pedía. **1 expedición** (4
      > sitios, 36 jornadas-persona): la del año 2 se decidió y no salió porque
      > la primavera empieza con la despensa a cero. **0 tratos** en dos años:
      > sólo el destino de la expedición deja contacto y 4 de cada 5 sitios están
      > vacíos. **Caza 1,88** por persona y día, no comparable a pelo con el 0,98.
      > La causa de fondo no es de esta tanda: la despensa sin cestos no pasa de
      > ~600 raciones y el invierno pide ~1 140. Cifras y lectura en ESTADO §2,
      > «Dos años con un jugador que decide». **Qué hacer con ello lo decide el
      > usuario.**
- [x] **M2. El frío, la pareja.** Dos corridas con la misma semilla, una
      haciendo ropa y otra no: en la que no, alguien enferma o muere de frío.
      **Toca:** sonda, ESTADO.md §2. **Corrida larga: ~56 min con un invierno,
      ~2 h 22 con los dos que pide la spec.**

      > **PRIMERA PASADA INVÁLIDA (2026-09-13), y se dice por qué.** Se construyó
      > «el último día de otoño» con `scripts/tests/FrioInviernoProbe.gd`, como
      > se decidió para no simular tres estaciones. Resultado: **la banda entera
      > muerta en 22 jornadas sin ropa y en 18 con ropa, y nadie enfermó de
      > frío.** Murieron de hambre.
      >
      > **Se construyó sólo el calendario.** La despensa era la del primer día de
      > primavera, y una banda llega al invierno con lo que ha recogido en tres
      > estaciones, no con lo que traía. Los muertos no enferman de frío, así que
      > el hambre tapó la pregunta entera. La regla de ARQUITECTURA §5.1 —«un
      > estado lejano se construye»— sigue en pie; lo que falló es construir
      > **la mitad** del estado.
      >
      > **Decidido por el usuario: llenar la despensa para aislar el frío.** Se
      > rellena cada día —tiene tope por cestos y odres, y parte se pudre—, y el
      > agua también, y la sonda dice de qué muere cada uno. Aplicado el
      > 2026-09-13, al parar M1 (ver arriba), y relanzada. Aviso de lectura: con el fuego encendido en la cueva puede salir
      > que nadie enferma ni con ropa ni sin ella, y eso sería un hallazgo, no un
      > fallo de la prueba.

      > **MEDIDA (2026-09-13): fue el hallazgo, no el fallo.** 15 min por brazo.
      > Con ropa y sin ella, **16 vivos, 0 enfermos, 0 muertos de frío y frío
      > medio 0,0**. En la cueva con el fuego encendido cada noche quita frío, y
      > el vestido sólo cuenta durmiendo sin fuego. **El criterio «sin ropa
      > alguien enferma» no se cumple en el invierno en casa**; el vestido manda
      > fuera del fuego (cumbres, vivac, fuego racionado). ESTADO §2, «El
      > invierno en la cueva». **Qué hacer con ello lo decide el usuario.**
- [x] **M3. Cerrar.** Suite verde y **≥ 6 994 comprobaciones**,
      `LlamadasHuerfanas` sin huérfanas nuevas, y lo aprendido a SISTEMAS §4,
      §5 y §19, INTERFAZ §4, SPECS §4.4 y ESTADO §2 y §3.

      > **HECHO (2026-09-13).** Tres decisiones del usuario con M1 y M2 delante:
      > el hambre del invierno va por `/depurar` y no se parchea aquí; la ropa se
      > acepta como hallazgo y se reescribe el criterio; y **la primera
      > expedición siempre encuentra gente** (`Contacto.poblar` desde
      > `Expedicion._volver`, con `test_la_primera_expedicion_siempre_encuentra_gente`
      > y la de «un sitio vacío» pasada a la segunda expedición). Suite **1 076
      > pruebas, 7 161 comprobaciones**; `LlamadasHuerfanas` en las 2 de siempre.
      > El trueque **no se ha vuelto a medir** con el cambio: una pasada de año
      > no vale mientras la banda no pase el segundo invierno.

**Presupuesto de máquina: ~2 h 51, decidido el 2026-09-12** — M1 entero, que
es el que cierra la fase y no se puede recortar, y M2 con **un solo invierno**:
si con uno ya enferma alguien, el segundo no añade nada. En
serie, Godot es de uno en uno. **Todo lo demás son pruebas de segundos**, y eso
es deliberado: catorce de las diecisiete tareas se comprueban sin simular nada.

**La medida se ha juntado a propósito**: M1 es **una sola corrida** que
contesta seis preguntas de cuatro frentes distintos. Por separado serían cinco
corridas y más de cinco horas.

**Orden acordado el 2026-09-12: el frente 5 primero (E1–E4) y se enseña antes
de seguir.** Es la mitad de la tanda y todo lo demás cuelga de ella; verla
funcionando antes de montar el trueque encima evita rehacer trabajo.

**Qué se puede repartir:** V1–V2 (el frío) no dependen de nada y tocan ficheros
distintos de E1–E4 y T1–T4; pueden ir en paralelo con otro agente. **T1–T4
dependen de E2 y E4**, y **dos medidas nunca a la vez.**
### Tanda 3: quién va, la pasarela que se ve, el herido, el guardado y el cielo

**Spec escrita (2026-09-13) en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1 → Tanda 3**, frentes 9 a 17, cada uno con sus criterios. Sale de la lista
del usuario tras jugar la tanda 2. Siguiente paso: `/plan-tarea`, que cuelga aquí
la lista de tareas.

En corto: las decisiones salen en el segundo mes de la estación; la
expedición lleva piel y leña de vivac, el jugador elige a quién manda y se les
ve salir por el borde del mapa; lo mismo, elegir quién sube, en la cumbre; el
herido se queda en la cueva; la pasarela es una obra con modelo en un cruce,
no un interruptor global, y la piragua sale de esta época; el taller practica
sin demanda, que cierra lo que A4 dejó abierto; la partida se guarda en disco
al volver al mapa regional, que es la FASE A3; hay cielo con nubes; y
«Trabajos», Almacén y Oficios se ponen al día.

**Depende de siete fallos que van por `/depurar`**, listados con su pista en la
spec: el % de técnicas que no sube en ribera, manufactura y hogar; la pasarela
en 82/70; «sim.hogar» en la crónica; los marcadores viejos del minimapa; el
raizal inalcanzable a 226 m; los 41 «sin camino» en 51 jornadas; y el barbecho
del 20 %, que existe y no se cumple. **Y no se toca código mientras M1 de la
tanda 2 esté midiendo.**

**Coste de máquina:** casi todo son pruebas de segundos y capturas con
ventana. La única corrida larga es la del taller, unos 45 minutos, la que A4 ya
tenía prevista.

---

### ~~Tanda 1: los caminos, la noche, los grados y el rendimiento~~ — cerrada

**CERRADA el 2026-09-12.** Diez tareas de doce hechas; C3 y M2 retiradas con su
motivo medido. Suite **979 pruebas y 6 994 comprobaciones**, desde 932/6 920.

**Lo que la tanda entrega, en una línea cada uno:**

| | |
|---|---|
| Los caminos | Memoria de veredas **sellada con su rejilla** y comprobable, los dos extremos catados, y **39 % de búsquedas ahorradas** |
| La noche | Se salta cuando nadie trabaja: **31 % de reloj con ventana**, y las 60 jornadas con **la misma firma** |
| Los grados | `Termometro`, con sus dos fuentes citadas, y la barra leyéndolos |
| El rendimiento | El recuento de tirones no sube; el fotograma medio pasa de 38,5 a 41,0 ms |

**Y tres cosas que salieron al revés de lo planeado**, que es lo que de verdad
hay que llevarse:

1. **La spec pedía la vereda «por destino» y está medido que no sale** — 17
   pasos cortados con la clave por par contra 2 295 con la clave por destino. El
   motivo es geométrico y no se afina. C2 y ESTADO §2.
2. **«Todos duermen» no era la condición**: era «nadie trabaja», que es lo que
   la spec decía. Lo destapó el usuario probándolo en el juego, no una sonda.
3. **Dos errores de método propios costaron más que toda la implementación**:
   medir sin fijar la semilla y tocar el código con una medida en vuelo. Las dos
   reglas están en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1.

**Queda abierto y nombrado:** C3 (la vereda que mejora con el uso) espera a que
se sepa comprobar barato un tramo recto nuevo; el vestido persona a persona es
tanda 2; y el «peor fotograma» no es medible con una corrida.

**Spec y plan técnico en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, tanda 1 y «Plan técnico». Lista colgada por `/plan-tarea` el
2026-09-12 por `history-of-man-11`.

**El suelo de la suite, medido hoy antes de tocar nada: 932 pruebas, 6 920
comprobaciones, TODO OK.** No puede bajar de ahí. La copia viva de esa cifra es
[ESTADO.md](ESTADO.md) §3.

**Dos premisas de la spec que el código no sostiene**, y están escritas en el
plan: `RegionEras` **no** calcula ningún paleoclima —son máscaras de cota del
mar, y no hay un solo grado de temperatura en el repositorio—, y el vestido es
de la banda y no de cada persona, así que «quién va vestido» persona a persona
no se puede contestar en esta tanda.

**Los caminos** (frente 1):

- [x] **C1. La memoria de rutas se muda a `BandKnowledge` y se sella con su
      rejilla.** Hoy vive en `SettlementSim._route_cache` / `_route_order` y se
      tira por aviso (`Marcha.forget_routes`); pasa a `BandKnowledge` y cada
      entrada guarda el `built_with_caudal` y el `built_with_encharque` de la
      rejilla que la trazó, y se descarta al leerla si no coinciden.
      **Toca:** `scripts/banda/BandKnowledge.gd`, `scripts/sim/Marcha.gd`,
      `scripts/sim/SettlementSim.gd`, `scripts/tests/TestVeredas.gd` (nuevo).
      **Verificable:** prueba que falla antes de la regla —una ruta sellada con
      otra rejilla no se usa— y `LlamadasHuerfanas` en 0. Segundos.

      > **HECHO (2026-09-12).** `scripts/banda/Vereda.gd` (nueva),
      > `BandKnowledge.veredas` con `vereda` / `recordar_vereda` /
      > `olvidar_veredas` / `veredas_recordadas`, `Marcha` redirigida, y fuera
      > de `SettlementSim` los `_route_cache` / `_route_order` /
      > `ROUTE_CACHE_LIMIT`. `scripts/tests/TestVeredas.gd`, 11 pruebas.
      > **Suite: 943 pruebas, 6 936 comprobaciones, TODO OK** (desde 932/6 920).
      >
      > **La prueba del sello es de verdad, comprobado rompiéndolo:** con
      > `Vereda.sirve_en` devolviendo siempre `true` caen 4 comprobaciones en 3
      > pruebas. Antes de esto la regla no se podía comprobar de ninguna
      > manera: la sostenía una llamada a `forget_routes` y un aviso no se
      > comprueba, sólo se confía.
      >
      > Dos cosas que salieron por el camino y no estaban en el plan:
      >
      > - **Tres sondas leían la caché por dentro** —`CrecimientoProbe`,
      >   `ScoutProbe` y `TironAnualProbe` imprimían `sim._route_cache.size()`—
      >   y habrían reventado en marcha sin avisar en compilación. Pasan por
      >   `veredas_recordadas()`.
      > - **`LlamadasHuerfanas` dice 2, y no son de esta tarea ni son un
      >   fallo.** Son `TestPartida.gd:185-186` llamando a
      >   `BarraSuperior._risk_share`, que es `static`: pedir un miembro
      >   estático por la clase es lo correcto —SPECS.md §4.4 lo exige para las
      >   constantes— y la herramienta lo cuenta como si tuviera que ir por
      >   `ui.barra`. Es un falso positivo de la herramienta con los miembros
      >   estáticos, en un fichero sin versionar que dejó otra tanda. Va por
      >   `/depurar`, no se parchea aquí.
- [x] **C2. La clave es el destino, y a la vereda uno se engancha.** La clave
      deja de ser el par origen-destino en cubos de 48 m y pasa a ser el
      destino; quien va allí se engancha por el hito más cercano al que llegue
      en línea limpia, con tope fijo de hitos catados.
      **Toca:** `scripts/sim/Marcha.gd`, `scripts/mundo/Wayfinder.gd`,
      `scripts/tests/TestVeredas.gd`.
      **Verificable:** pruebas —dos orígenes distintos al mismo destino usan la
      misma vereda; el enganche no cruza terreno cortado; entradas guardadas ≤
      destinos conocidos, que es el criterio de tope del frente 4—. Segundos.

      > **HECHO (2026-09-12), y NO como lo pedía la spec: se midió y no sale.**
      >
      > Lo construido: `Vereda.clave_de`, `Vereda.enganchar` (se entra a la
      > vereda por el hito que menos anda en total, catado con
      > `Wayfinder.linea_limpia`, tope `CATAS_DE_ENGANCHE`) y `Vereda.remate`
      > (se sale por un tramo catado). `SettlementSim.LANE_CELL` pasa a ser
      > `Vereda.CELDA`; `Marcha._lane_key` y `Marcha._retarget` **se borran**,
      > no los llamaba ya nadie. Suite: **955 pruebas, 6 955 comprobaciones,
      > TODO OK**.
      >
      > **La clave NO es sólo el destino, y eso contradice la spec.** Se
      > implementó como pedía —«se guarda por destino», frente 1— y se midió
      > (`AtascoProbe`, `SEMILLA=42`, 8 jornadas, pasos que el terreno corta
      > teniendo camino trazado):
      >
      > | clave | cortados | atascos |
      > |---|---|---|
      > | sin memoria | 10 | 0 |
      > | par origen-destino | 17 | 1 |
      > | **par, con las dos catas** (lo que queda) | **33** | **0** |
      > | sólo el destino, remate sin catar | 803 | 3 |
      > | sólo el destino, las dos catas | 2 295 | 2 |
      >
      > El motivo es geométrico y no se arregla afinando: con el par, quien
      > reutiliza la vereda está a setenta metros como mucho del primer hito;
      > con la clave por destino puede estar a kilómetros, y el enganche pasa a
      > ser una recta larguísima que ninguna cata razonable cubre —lo que se
      > anda no es el eje, cada uno va por su carril—. Catar más fino y con el
      > ancho del carril llevó la sonda de 48 s a más de 10 min. Ver
      > [ESTADO.md](ESTADO.md) §2 y el porqué largo en `Vereda.clave_de`.
      >
      > **Lo que sí queda de aquello, y es la mejora real: los dos extremos se
      > catan.** Antes nadie miraba ni el tramo de la persona al primer hito ni
      > el del último hito al punto exacto. Cuesta 33 pasos cortados contra 17,
      > y deja 0 atascos contra 1 y menos proporción de caminos que no merecen
      > andarse, con más reuso.
      >
      > **Y una lección de instrumento que costó más que la tarea:** las
      > primeras medidas se tomaron **sin fijar la semilla**, y eran ruido —el
      > mismo código dio 2 200, 1 747, 303 y 219—. Se llegaron a escribir dos
      > conclusiones falsas en ESTADO.md y hubo que retirarlas. La regla está
      > ahora en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1.
- [~] **C3. La vereda se afina con el uso.** En cada recorrido, un número corto
      y fijo de intentos de atajo sobre la ruta guardada: si del hito *i* se ve
      el *i+2* en línea limpia, se tira el de en medio. Sin búsquedas y sin
      azar.
      **Toca:** `scripts/sim/Marcha.gd` o `scripts/banda/BandKnowledge.gd`,
      `scripts/tests/TestVeredas.gd`.
      **Verificable:** prueba —una ruta con un hito prescindible lo pierde en
      unos recorridos, y ninguna ruta se alarga nunca—. Segundos.

      > **NO SE HACE, y hace falta decir por qué con cuidado.** Se implementó
      > entero —`Vereda.afinar`, con la regla de que el atajo se cobra con la
      > vara del trazado (`Navgrid.cost_of`) y no con la regla de medir, más
      > seis pruebas— y se midió con `AtascoProbe`. **Pero se midió sin fijar
      > la semilla**, así que aquella medida no vale y la conclusión que se
      > sacó de ella —«el afinado empeora el andar»— **queda retirada**.
      >
      > Se retira la tarea igualmente, y por una razón que no depende de
      > aquella medida: **C2 demostró que el problema de las veredas está en
      > los tramos rectos que nadie comprueba**, y el afinado consiste
      > precisamente en fabricar tramos rectos nuevos borrando hitos. La cata
      > que haría falta para que fuera seguro es la misma que en C2 llevó la
      > sonda de 48 s a más de 10 min. Antes de reabrirlo hay que resolver eso,
      > y eso es otra tarea.
      >
      > El código se borró —no se deja código muerto— y con él sus seis
      > pruebas. Queda escrito aquí y en `Vereda.clave_de` para que no se
      > reintente a ciegas.
- [x] **C4. El contador de búsquedas.** Búsquedas completas de camino por
      jornada simulada, que es la mitad del frente que hoy no se mide.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/sim/Marcha.gd`,
      `scripts/tests/RodeoProbe.gd`.
      **Verificable:** prueba de que cuenta lo que dice. Segundos.

      > **HECHO (2026-09-12), y de paso contesta M2.** `Wayfinder.busquedas`,
      > contado **dentro de `find`** y no en quien llama: todo el que busca
      > pasa por ahí, y un contador que se puede rodear no cuenta nada.
      > `AtascoProbe` lo saca por jornada.
      >
      > **Y aquí está la cifra que justifica el frente 1** (`SEMILLA=42`, 8
      > jornadas, sitio 56):
      >
      > | | búsquedas completas por jornada | pasos cortados |
      > |---|---|---|
      > | sin memoria de veredas | **265,8** | 10 |
      > | con memoria de veredas | **161,1** | 33 |
      >
      > **Las veredas ahorran el 39 % de las búsquedas de camino.** Ésa es la
      > mitad del frente que la spec mandaba medir aparte —«en vez de buscarse
      > de cero»— y es lo que el frente entrega de verdad, porque la otra
      > mitad, el rodeo que baja con el uso, se quedó sin hacer (C3).
      >
      > **La salvedad, dicha:** apagar la memoria cambia los caminos y con
      > ellos la partida, así que las dos corridas no andan exactamente los
      > mismos trayectos aunque compartan semilla. La comparación es por
      > jornada y sobre el mismo arranque, no trayecto a trayecto.

**La noche** (frente 2):

- [x] **N1. `SettlementSim.duerme_la_banda()`.** Una pregunta, un sitio:
      cierta cuando todas las personas están en `DURMIENDO`. El que vivaquea
      entra solo, porque el vivac también acaba en `DURMIENDO`.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/tests/TestNoche.gd`
      (nuevo). **Verificable:** pruebas —banda dormida sí; uno andando de vuelta
      no; el vivaqueador a varios kilómetros no bloquea—. Segundos.

      > **HECHO (2026-09-12), y se llama `nadie_trabaja()`, no
      > `duerme_la_banda()`.** El cambio de nombre no es cosmético: la primera
      > versión usaba la lectura estricta —todos en `DURMIENDO`— y **el usuario
      > la probó en el juego y dijo que la noche seguía yendo lenta**. La banda
      > no se acuesta a la vez, así que el que volvía andando del monte
      > bloqueaba la aceleración durante esa hora larga: 71 s por cuatro
      > jornadas contra los 62 de ahora, sobre 90 sin acelerar.
      >
      > **Y la spec decía «cuando nadie está trabajando» desde el principio**
      > (frente 2): la lectura estricta era del plan. Hoy frenan sólo
      > `TRABAJANDO`, `BUSCANDO` y `RECONOCIENDO` —lo que el jugador puede
      > querer ver—; andar, comer y dormir no. El que vivaquea entra solo, que
      > era el criterio explícito.
      >
      > `scripts/tests/TestNoche.gd`, 11 pruebas. Una de ellas afirmaba lo
      > contrario y **se reescribió diciendo por qué**, en vez de borrarla.
- [x] **N2. La noche se salta dando más pasos, no pasos más largos.** Se
      multiplica lo que entra en `_pendiente` y se sube el tope de pasos por
      cuadro; `PASO_FIJO`, `time_scale` y `Engine.time_scale` no se tocan. Así
      la sucesión de `_advance` es la misma que sin acelerar y la firma es
      idéntica por construcción.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/tests/TestNoche.gd`.
      **Verificable:** pruebas —con `Moment` de decisión levantado el reloj
      sigue parado; con la banda despierta no se acelera; el número de pasos por
      hora de juego no cambia—. Segundos.

      > **HECHO (2026-09-12), tal como lo planteó el plan y funcionó.**
      > `MS_DE_NOCHE_POR_CUADRO`: cuando no hay nada que mirar se dan tantos
      > pasos **del mismo tamaño** como quepan en 8 ms de cuadro. `PASO_FIJO`,
      > `time_scale` y `Engine.time_scale` sin tocar, así que la sucesión de
      > `_advance` es la misma que sin acelerar y la firma sale igual **por
      > construcción**. Ahorro medido: **31 % del reloj** (90 s → 62 s por
      > cuatro jornadas). El barrido del presupuesto, en [ESTADO.md](ESTADO.md)
      > §2: el ahorro se agota en 8 ms.
      >
      > **Tres cosas que salieron por el camino:**
      >
      > - **El cierre de jornada corta el cuadro.** El peor fotograma de la
      >   partida es la contabilidad de medianoche (M1), y la medianoche cae
      >   dentro de la noche acelerada: sin ese corte, ese fotograma se comería
      >   además el presupuesto entero.
      > - **`noche_acelerada`, un interruptor, y hacía falta de verdad**: la
      >   corrida que demuestra que esto no cambia la partida necesita la
      >   pareja con y sin. Se pone con `NOCHE=0`, igual que `SEMILLA=`.
      > - **Y tuvo que entrar en `Instantanea.FUERA`.** El primer cotejo dio
      >   firmas distintas y el único campo que las separaba **era el propio
      >   interruptor**: todo lo demás, idéntico. Es ritmo de reloj, no partida.

**Los grados** (frente 3):

- [x] **G1. `Termometro`: cuántos grados hace aquí y ahora.** Clase nueva en
      `scripts/mundo/`, una sola función pública, de estación, hora y cota a
      grados. Gradiente vertical **0,65 °C por 100 m, físico y no de balanceo**.
      La base al nivel del mar es **el clima cantábrico de hoy menos la anomalía
      magdaleniense** (decidido el 2026-09-12), las dos **con fuente citada en**
      [CREDITOS.md](CREDITOS.md): `RegionEras` no la tiene y no se inventa. Si
      una de las dos no aparece con cita, la tarea para y se dice.
      **Toca:** `scripts/mundo/Termometro.gd` (nuevo),
      `scripts/tests/TestTermometro.gd` (nuevo).
      **Verificable:** pruebas de entradas fijas a grados conocidos; el
      gradiente entre la cueva y el roquedo con su diferencia de cota real;
      mediodía de verano contra noche de invierno. Segundos.

      > **PARADA (2026-09-12), y es lo que la propia decisión mandaba hacer.**
      > De los dos datos que hacían falta, **uno está y el otro no**:
      >
      > - **La base al nivel del mar, SÍ.** Normales de AEMET 1991–2020,
      >   Santander/aeropuerto, 3 m de cota: media anual 14,8 °C y las doce
      >   medias mensuales. Anotadas en [CREDITOS.md](CREDITOS.md) con su
      >   fuente y su salvedad, para que nadie las vuelva a buscar.
      > - **La anomalía del Magdaleniense, NO.** Lo único concreto que apareció
      >   —El Mirón, medias «no superiores a 5 °C» en el último nivel
      >   solutrense— está **tras muro de pago** y llegó por un resumen de
      >   búsqueda, no leyendo el artículo. Citarlo así sería dar por verificado
      >   algo que no lo está.
      >
      > **Y hay un problema de fondo que el plan no vio:** el Magdaleniense
      > cantábrico va de ~17 000 a ~11 700 a.C. y **abarca la deglaciación
      > entera** —de casi el Último Máximo Glacial al Dryas Reciente—. Un solo
      > desfase fijo no lo describe, así que la pregunta que hay que llevar de
      > vuelta a `/spec` no es sólo «¿de dónde sale el número?» sino «¿la
      > partida empieza en un clima y termina en otro, o se congela en uno?».
      > Eso es diseño de época y no se decide aquí.
      >
      > **G2 se queda con G1**: sin grados no hay grados que enseñar.

      > **DESBLOQUEADA Y HECHA (2026-09-12): el usuario fijó la época al FINAL
      > del Magdaleniense, hacia el 12 000 a.C.** Eso contesta la pregunta de
      > diseño que la paraba —la partida se congela en un clima, no recorre la
      > deglaciación— y además abre la puerta al dato: 12 000 a.C. son ~14 ka
      > cal BP, dentro del Bølling–Allerød, que está mucho mejor reconstruido
      > que el Último Máximo Glacial.
      >
      > `scripts/mundo/Termometro.gd` (nueva), con una sola pregunta pública.
      > Fuentes en [CREDITOS.md](CREDITOS.md): AEMET 1991–2020 para la base al
      > nivel del mar y **Tarroso et al. (2016), *Climate of the Past* 12,
      > 1137–1149**, abierto, para el desfase.
      >
      > **Y el hallazgo no es la cifra sino la forma: aquello no era «como hoy
      > pero más frío», era MÁS ESTACIONAL** — invierno −5 °C, verano −2 °C—.
      > Es lo que sostiene que el abrigo sea una puerta y no un porcentaje. Ver
      > [SISTEMAS.md](SISTEMAS.md) §19.
      >
      > G2: la barra lleva los grados y, al lado, **la peor pieza de abrigo y no
      > la media** —`Toolkit.peor_condicion`, nueva—, porque la media no se
      > mueve cuando una sola se está acabando. Sigue **sin ser persona a
      > persona**: `Toolkit` no tiene dueños, y eso es tanda 2. Ver
      > [INTERFAZ.md](INTERFAZ.md) §4.

- [x] **G2. Los grados en la barra superior**, y la cobertura de vestido de la
      banda con el desgaste de la pieza peor —no persona a persona, ver la
      premisa de arriba—.
      **Toca:** `scripts/ui/BarraSuperior.gd`, `scripts/ui/GameUI.gd`,
      `scripts/tests/TermometroCaptura.gd` (nuevo).
      **Verificable:** captura **con ventana** en cuatro momentos —mediodía de
      verano y noche de invierno, en la cueva y en el roquedo— con los cuatro
      números distintos y en el orden que les toca. Con `--headless` la imagen
      sale nula. Minutos.

**Lo que se mide** (frente 4, y las corridas de los otros tres):

- [x] **M1. La línea base del fotograma malo, en esta máquina y hoy.**
      `PicoProbe` con sus valores por defecto. Las cifras de SPECS.md §6.1 son
      de otra corrida y el cepo mide reloj de pared: sin medida propia no hay
      con qué comparar. Va **antes** de tocar nada.
      **Toca:** [ESTADO.md](ESTADO.md) §2. **Corrida, ~2 min.**

      > **HECHO (2026-09-12).** `PicoProbe` con `VEL=5 DIAS=4 LIMITE=100` y
      > **con ventana** —a x5, que es la velocidad a la que se juega; x6 era el
      > valor por defecto de la sonda y no describe la partida—. 2 329 cuadros
      > en 90 s: **medio 38,6 ms, peor 112,8 ms, 1 tirón de más de 100 ms**.
      >
      > **Y el hallazgo, que el plan no esperaba: el único fotograma malo de la
      > partida es el cierre de jornada, no el dibujo.** Cae el día 1 a las
      > 23:58, son 113 ms, y de ellos 97 son `simulacion (SettlementSim)` y 42
      > `cierre de jornada`; el motor entero pone 8. Eso cambia qué hay que
      > vigilar en M4: la noche acelerada mete más pasos por cuadro **y la
      > medianoche cae dentro de la noche**, así que el riesgo no es un tirón
      > nuevo repartido, es que ese tirón que ya existe se junte con los pasos
      > extra en el mismo fotograma.
      >
      > Apuntado de paso, y sin arreglar: la línea «SIN MARCAR» del informe de
      > la sonda sale en negativo porque suma tramos anidados. Las cuatro cifras
      > de arriba las da el cepo, no esa suma. Ver [ESTADO.md](ESTADO.md) §2.
- [~] **M2. El rodeo y las búsquedas, en una sola pasada.** `RodeoProbe` con
      ~30 jornadas y el rehorneo **forzado** a mitad, en vez de esperar dos
      estaciones reales: converger cuesta unos recorridos, no noventa días.
      Contesta de una vez el rodeo al empezar, el rodeo tras converger, las
      búsquedas por jornada antes y después, y que tras el rehorneo el rodeo
      **sube y vuelve a bajar**. Depende de C1–C4.
      **Toca:** `scripts/tests/RodeoProbe.gd`, [ESTADO.md](ESTADO.md) §2.
      **Corrida, ~12 min.**

      > **NO SE HACE COMO ESTABA PLANEADA, y se ahorran los 12 min.** Dos
      > razones, las dos descubiertas al llegar aquí:
      >
      > - **`RodeoProbe` no simula jornadas de marcha**: fuerza la rejilla de
      >   cada estación y traza los mismos trayectos sobre ella. Mide el rodeo
      >   del **planificador**, no el de lo que la banda ha aprendido andando,
      >   así que la memoria de veredas no le aparece por ningún lado. El plan
      >   dio por hecho que sí, sin mirarlo.
      > - **Y lo que iba a medir ya no existe**: «el rodeo baja con el uso y
      >   vuelve a bajar tras el rehorneo» era C3, que se retiró. Sin afinado,
      >   no hay nada que converja.
      >
      > Lo que sí quedaba por medir del frente —el ahorro de búsquedas— **está
      > medido en C4**, en una corrida de 50 segundos en vez de doce minutos.
      > El suelo de rodeo de ESTADO.md §2 (x1,18 primavera, x1,43 verano) sigue
      > siendo el bueno: nada de esta tanda lo ha tocado.
- [x] **M3. La noche: lo que ahorra y que no cambia la partida.** Dos pasadas de
      60 jornadas con la misma semilla —una sin acelerar, otra con la noche
      acelerada—, cada una escribiendo segundos de reloj por jornada **y** sus
      firmas; `Cotejo` decide. La pasada sin acelerar trae de regalo las
      búsquedas por jornada sobre 60 días reales. Depende de N1, N2 y de que C1
      esté cerrada: mudar la memoria a `BandKnowledge` cambia la forma de la
      instantánea, y firmas de antes y de después no se comparan.
      **Toca:** `scripts/tests/TironAnualProbe.gd` o sonda nueva,
      [ESTADO.md](ESTADO.md) §2. **Corrida, ~41 min — confirmadas las 60
      jornadas el 2026-09-12**: la ventana corta sólo probaría la ventana.

      > **HECHO (2026-09-12), a la SEGUNDA, y la primera vez fue culpa mía.**
      >
      > Resultado: **las 60 jornadas con la misma firma**, con y sin acelerar.
      > Y 18 min 51 s contra 24 min 21 s, un **22,6 % de reloj** —menos que el
      > 31 % con ventana, porque en `--headless` el fotograma pesa menos y la
      > firma de cada jornada se paga igual en las dos ramas—.
      >
      > **La primera pasada dijo que se separaban en la jornada 26, y era
      > mentira.** Se lanzó a las 18:38 y, mientras corría, se cambiaron tres
      > cosas de la propia noche: la condición de entrada (`duerme_la_banda` →
      > `nadie_trabaja`), el presupuesto por cuadro y el corte al cerrar la
      > jornada. Aquella corrida no comparaba dos configuraciones sino **dos
      > versiones del código**, y ninguna era la que quedó.
      >
      > Costó hora y media y cuatro corridas de diagnóstico descubrirlo —dos
      > gemelas idénticas, un barrido del horno de rejillas, y un instrumento
      > que contaba pasos, cuadros y estado del azar por jornada—. De ese
      > instrumento salió el dato que lo desmontaba: **`pasos` y `azar`
      > idénticos jornada a jornada; sólo cambiaban los cuadros**. La lección
      > está en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1: **con una medida en
      > vuelo, el código no se toca.**
- [x] **M4. El re-medido del fotograma malo.** `PicoProbe` otra vez, con la
      noche acelerada puesta y en la misma sesión que M1. El peor fotograma y el
      tirón de la simulación no empeoran respecto de M1. Es el que puede tumbar
      el tope de pasos de N2.
      **Toca:** [ESTADO.md](ESTADO.md) §2. **Corrida, ~2 min.**

      > **HECHO (2026-09-12), y el criterio NO se puede dar por cumplido tal
      > como está escrito.** Las dos ramas medidas en la misma sesión y con el
      > mismo código: sin noche 90 s / 38,5 ms medio / 1 tirón; con noche 62 s /
      > 41,0 ms medio / 1 tirón.
      >
      > **El recuento de tirones no empeora** —1 y 1—, y ésa es la mitad del
      > criterio que sí se sostiene. **El fotograma medio empeora**, de 38,5 a
      > 41,0 ms, que es el precio de meter más simulación en el mismo cuadro.
      >
      > **Y el «peor fotograma» resultó no ser medible con una corrida:** es
      > una muestra suelta y el cepo mide reloj de pared. En configuraciones
      > que ahorran lo mismo dio 117, 122, 124, 125,7, 138,8, 144,9 y 146,1 ms,
      > y el valor más alto salió con el presupuesto **más pequeño**. Queda
      > apuntado en [ESTADO.md](ESTADO.md) §2 como aviso para quien lo use: hace
      > falta una mediana de varias corridas, no una cifra.
- [x] **M5. Cerrar.** Suite verde y **≥ 6 920 comprobaciones**,
      `LlamadasHuerfanas` en 0, y lo aprendido a su documento permanente:
      [SISTEMAS.md](SISTEMAS.md) §18 y §19, [INTERFAZ.md](INTERFAZ.md) §4,
      [SPECS.md](SPECS.md) §3.1 y §4.6, [ESTADO.md](ESTADO.md) §2 y §3.

      > **HECHO (2026-09-12).** Suite **979 pruebas, 6 994 comprobaciones, TODO
      > OK**, sobre un suelo de 932/6 920 — sube 47 pruebas y 74
      > comprobaciones. `LlamadasHuerfanas` dice 2, **las mismas dos de siempre
      > y ninguna de esta tanda**: `TestPartida.gd:185-186` llamando a un
      > miembro `static` por su clase, que es un falso positivo de la
      > herramienta con los estáticos, en un fichero sin versionar de otra
      > tanda. Va por `/depurar`.
      >
      > Documentado en SISTEMAS §18 y §19, INTERFAZ §4, SPECS §3.1 y §4.6,
      > CREDITOS «Clima», ARQUITECTURA §5.1 y ESTADO §2 y §3.

**Presupuesto de máquina: ~57 min de corridas**, en serie —Godot es de uno en
uno, AGENTES.md §3—: M1 (2) + M2 (12) + M3 (41) + M4 (2). Todo lo demás son
pruebas de segundos. **Lo caro es M3**, y es el único que de verdad pide 60
jornadas: la firma idéntica en cinco jornadas no diría nada del mes.

> **Lo que costó de verdad: unas 3 h 20 de máquina, contra las 57 min
> presupuestadas.** M2 se ahorró entero (12 min) y M3 se pagó **dos veces** (43
> + 43), más hora y media de diagnóstico que no estaba en ningún plan. De ese
> sobrecoste, **casi todo es de dos errores de método míos y no de la tanda**:
> medir sin fijar la semilla, y tocar el código con una medida en vuelo. Las
> dos reglas están ahora en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1, que es
> donde se miran antes de medir.

**Qué se puede repartir entre agentes:** C1–C4 y G1–G2 tocan ficheros distintos
—`Marcha`/`BandKnowledge` contra `Termometro`/`BarraSuperior`— y van en
paralelo. **N1 y N2 no**, porque tocan `SettlementSim.gd` igual que C1. Y **dos
medidas nunca a la vez.**

---

### ~~🔴 El taller se para solo hacia la jornada 31~~ — cerrado: no era un fallo

Encontrado el 2026-09-12 por `/depurar`, buscando por qué no llegaba la talla
laminar. **Sin arreglar**, y es lo que de verdad cierra la rama de manufactura:
la práctica corre a 2,00 jornadas/día treinta días y **se cae a 0,3**, mientras
la cuarcita del almacén pasa de 96 a 3 054. No falta material: la banda se va
al canchal y no vuelve al taller.

Con eso ninguna técnica de manufactura pasada del núcleo preparado llega en un
año. La cifra medida y por dónde empezar a mirar, en
[ESTADO.md](ESTADO.md) §2.

**No se bajaron las jornadas de la talla laminar** —era el arreglo que se
barajó— porque taparía esto: con el taller parándose, la cifra nueva tampoco se
alcanza.

**Las tareas están arriba**, en «La puerta de entrada: los dos 🔴» (A1–A4), y
con una hipótesis que el plan técnico explica: `Taller._workshop_short` sabe qué
material falta y lo tira al devolver un `bool`, así que el recado sale a por
piedra cuando lo que falta es fibra.

---

### ~~🔴 El cuelgue de la hambruna total~~ — cerrado (2026-09-12)

**Un bucle infinito de verdad, reproducible con semilla fija.** Es lo primero,
porque mientras exista **no se puede correr ninguna sonda de año completo** con
un reparto pobre, y eso bloquea medir la pesca, la subsistencia y el ritmo.

```
SEMILLA=42 DIAS=95 BANDA=4,3,2   sobre scripts/tests/AnoProbe.gd
```

Lo que se sabe, y de dónde sale (medido al escribir la spec del secadero,
detalle completo en [archivo/SECADERO_Y_RIO.md](archivo/SECADERO_Y_RIO.md),
«Riesgos técnicos conocidos»):

- Se cuelga en el cruce verano→otoño. **17 minutos sin escribir una línea de
  log** consumiendo un núcleo entero (3 101 s de CPU en 3 120 s de reloj). No es
  una caída: hay que matarlo a mano.
- El último punto de control impreso (día 76, verano) da **despensa = 0 y hambre
  media de la banda = 100**, el máximo, con los quince todavía vivos.
- `BandaProbe.gd` sin modificar, con otro reparto y otra semilla, no se ha
  colgado en 45 días.

**La hipótesis que había aquí está descartada, y por lectura.** Decía «un bucle
en el camino de muertes masivas simultáneas, por ejemplo recorrer `sim.people`
mientras `_person_dies()` lo modifica», con `Relevo.gd` de sospechoso **sin
leer**. Leído: `Relevo.revisar_vejez`, `revisar_frio` y `revisar_hambre` ya
recorren `sim.people.duplicate()`, y el comentario de `Relevo.gd:125` dice por
qué. Los demás bucles de salida variable de la simulación —`Reparto.set_job_count`,
`Inhabitant.create_band`— decrecen en cada vuelta. El diagnóstico empieza de
cero.

Lo que sigue en pie es la otra mitad: **no se descarta que el reparto 4,3,2 sea
insosteniblemente pobre bajo el código actual**, lo cual sería un hallazgo de
balanceo por sí solo.

**Las tareas están arriba**, en «La puerta de entrada: los dos 🔴» (B1–B6): es
la única copia, para que no haya dos listas del mismo trabajo.

> **Dueño:** era `history-of-man-0e`, que ya no está viva y **no dejó nada en
> `scripts/` ni en el log** —comprobado el 2026-09-12, no supuesto: una pizarra
> vacía puede ser «ya terminó» y aquí no lo era—. Lo lleva `history-of-man-b2`.

---

### El secadero y el río

De [ESTADO.md](ESTADO.md) §5, bloque «Segundo: que la carne importe». La spec
completa, con sus tres lecturas sucesivas del dato, está en
[archivo/SECADERO_Y_RIO.md](archivo/SECADERO_Y_RIO.md).

- [ ] **El otoño como pico de curado, no como ventana única.** El secadero cura
      más por jornada en otoño que en cualquier otra estación, con la misma
      gente. Sigue curando el resto del año: la caza de invierno también tiene
      que poder guardarse.
      **Verificable:** una sonda que fuerce carne y pescado frescos de sobra en
      las cuatro estaciones, con el mismo número en `Job.HOGAR`, mide más
      raciones curadas por jornada en otoño. Hoy `Hogar.DRY_PER_DAY` da
      exactamente 24 en las cuatro, sin excepción.

- [ ] **La pesca sin sitio conocido.** 🔓 **Desbloqueada el 2026-09-12**: el
      cuelgue está cerrado y la corrida de 95 jornadas llegó al final, así que
      hay tercera medida. Sigue en pie la contradicción de las dos primeras
      lecturas —a 45 jornadas parecía resuelto, a 90 la producción se hundía—, y
      la medida nueva la confirma: **de 41,45 a 5,60 raciones por pescador y
      día** de primavera a verano, con los mismos 90 jornadas-persona. Lo nuevo
      es que ahora se sabe que **no es falta de sitio**: el «sin sitio» baja del
      36,2 % al 2,1 % del día y el tiempo trabajando SUBE del 21,9 % al 37,2 %.
      Trabaja más y saca menos. Las cifras, en ESTADO.md §2.
      **Verificable:** una sonda de año completo, dos pescadores y sin
      exploradores, midiendo la pesca por persona y día estación a estación. Si
      colapsa, la sonda dice en cuál y cuánto, y se vuelve a `/spec`.

**Fuera de este bloque, decidido:** bajar las kcal del fruto seco (queda sólo un
número de balanceo), restringir el curado a otoño (se decidió en contra),
la curva de `ResourceField.regrow`, limpiar `ResourceField.deplete_at` (código
muerto), y tocar `Job.EXPLORACION`.

---

### Los gráficos

El diseño, el presupuesto de fotograma y lo ya medido están en
[GRAFICOS.md](GRAFICOS.md); el plan original fase a fase, en
[archivo/REVAMP_GRAFICO.md](archivo/REVAMP_GRAFICO.md). Hecho: medir (G0), el
calibrado de paleta (G3) y la ingesta PBR de las ocho capas (G2, a medias).

- [ ] **Terminar la reforma del shader.** Quedaba la palanca de la anisotropía
      (−4,5 ms medidos) sin aplicar, y el salto de capas por peso, que hoy
      recorta la contribución pero **no evita el muestreo**.
      **Verificable:** `GpuProfile.gd`, con el terreno dentro de su casilla de
      6,0 ms del presupuesto.

- [ ] **Lo que hay en el suelo.** Va **antes que la gente**, y no por gusto: el
      sistema ya existe —`ResourceProps` y `Forest` siembran con densidad por
      celda, rareza y balanceo de viento— y lo que falta es **la malla**, que
      hoy son esferas, cilindros y prismas de un color. Incluye la deuda que
      dejó G2: el roquedo tiene que tener **silueta propia, no sólo dibujo**.

- [ ] **Cuerpo y escala.** Seis bases MPFB2, rig, import, y fuera las cápsulas.
      **Verificable:** la banda son personas de 1,70 m y la cámara sigue siendo
      usable.

- [ ] **Locomoción**: los 15 clips de estado, atados a `Inhabitant.State`.
      **Verificable:** se distingue quien va, quien vuelve cargado y quien
      duerme.

- [ ] **Trabajo**: los 20 bucles de especialidad, con el apero en la mano.
      **Verificable: se sabe qué está haciendo cada uno sin abrir un panel** —
      es el criterio que justifica el revamp entero.
      ⚠️ Es **la partida más cara**, y donde esto puede morir a medias dejando
      personas realistas en pose T. Se entrega **por oficios completos**: caza
      entera, luego ribera entera.

- [ ] **Ropa paleolítica**: slots y el set del Magdaleniense.
      **Verificable:** cambiar de época cambia la ropa sin tocar el esqueleto.

- [ ] **Panel de gráficos**: `GraphicsSettings`, interfaz y persistencia.
      **Verificable:** Alto da 60 FPS en la 1070; Bajo, 60 en una integrada.

---

### Lo mismo, más deprisa — casi cerrado

El bloque de rendimiento está hecho y medido: **la misma semilla da la misma
partida durante un año entero**, comprobado con cotejo de firmas, y los tirones
se han ido. Las cifras están en [ESTADO.md](ESTADO.md) §5; el relato completo,
en [archivo/LO_MISMO_MAS_DEPRISA.md](archivo/LO_MISMO_MAS_DEPRISA.md).

Lo que queda vivo:

- [ ] **`Instantanea.volcar`: de bytes a la partida** (tarea 15 del bloque). El
      sentido de vuelta está sin construir; sin él una instantánea se toma pero
      no se restaura.
      **Verificable:** en `TestInstantanea.gd`, tomar → volcar sobre una
      simulación nueva → volver a tomar da los mismos bytes; tras volcar, diez
      pasos en las dos simulaciones dan la misma firma; y un campo guardado que
      no existe en la clase da error.

- [ ] **El año de cierre**, cuando el usuario dé el bloque por cerrado. Está
      medido y a la espera de esa decisión, no de más trabajo.

- [ ] **Dos palancas que cambian la partida**, y las decide el usuario: no se
      tocan sin que lo diga.

---

## FASE A — Cerrar el circuito de juego

Lo que falta para que esto deje de ser dos visores y pase a ser un juego.

### A1. Enclave inicial y exploración — **hecho en la capa local**
- Se empieza con **un solo emplazamiento conocido** (`GameState.HOME_LAT/LON`,
  Cueva los Pendios) y el territorio se descubre saliendo: `Exploration`,
  `Reconocimiento`, `BandKnowledge` y los `Parajes` que se ganan un nombre.
- **La niebla regional está puesta** (corregido el 2026-09-12, midiendo):
  `GameState.discovered` arranca con sólo la cueva y `RegionMap` filtra por él.
  Este documento decía «hoy el mapa regional se ve entero» y no era cierto.
- **Lo que falta es QUIÉN la levanta**: nadie llama a `GameState.discover`
  desde la partida, así que la niebla no se abre nunca. Eso lo construye la
  expedición regional — ver «En curso» → Tanda 2, tarea E3.
- Criterio cumplido: al empezar se ve **uno**, no 862. Y de paso, los usables
  en el Paleolítico son **72**, no 862. Ver ESTADO.md §2.

### A2. El asentamiento existe — **hecho**
- `SettlementSim` es el asentamiento, con población concreta, oficios y rutina.
- La capacidad de carga no es «según la técnica disponible» en abstracto: es lo
  que da el territorio (`ResourceField`, `Subsistence`) y lo que cabe en la
  despensa (`Storehouse.capacidad_de_comida`).
- **Lo que falta**: salir al mapa regional y volver **no conserva el estado**.
  Eso es A3.

### A3. Persistencia — **sin empezar, y con una confusión que aclarar**
- Guardar y cargar de verdad: cerrar el juego y recuperar la partida.
- **`Instantanea` no es esto.** Es un instrumento de medida —comparar dos
  corridas, arrancar una sonda en la jornada N— y no promete que un fichero de
  hoy sirva mañana. Ver SPECS.md §6.4. Reutilizar su recorrido por reflexión es
  razonable; darla por guardado, no.
- Criterio: cerrar el juego y recuperar la partida.
- **Tiene spec desde el 2026-09-13**: EPOCA_01 §10.1 → Tanda 3, frente 15. Se
  guarda solo al volver al mapa regional, y los criterios están allí.

---

## FASE B — El juego de verdad: procesos

Aquí está lo que distingue este proyecto de un city builder cualquiera.

### B1. `ProcessRecipe`
Entradas, herramientas, conocimiento, energía, jornadas, salidas y
**subproductos**. Los subproductos no son adorno: la escoria se acumula, la
ceniza abona y las conchas forman el conchero, que en Cantabria es el
yacimiento en sí.

### B2. La escalera térmica

> **Corrección.** Este apartado decía que «`RawMaterial` ya guarda punto de
> fusión e ignición, o sea que el árbol tecnológico ya está escrito: no hay que
> inventarlo, hay que leerlo». **Es falso**: `RawMaterial` se retiró con el resto
> de la capa de *city builder*. La secuencia de temperaturas de la tabla es
> correcta, pero **hay que escribirla de cero** cuando le toque, no leerla de un
> sitio que ya no existe. El sitio natural es `Materia.gd`, con dos campos
> opcionales (`melts_at`, `ignites_at`) sólo en los materiales que importan —ver
> [SISTEMAS.md](SISTEMAS.md) §1.1.

| Instalación | Máx. | Habilita |
|---|---|---|
| Hogar abierto | ~700 °C | Cocinar, calcinar conchas |
| Horno de fosa | ~900 °C | Cerámica |
| Cubeta con fuelle | ~1100 °C | Cobre (1085 °C) |
| Horno mejorado | ~1200 °C | Bronce |
| Cuba baja | ~1250 °C | Hierro **en estado sólido**: esponja, no colada |
| Ferrería hidráulica | ~1350 °C | Barras en cantidad |
| Alto horno | ~1550 °C | Fundir hierro (1538 °C) |

El salto de la esponja a la colada es una frontera tecnológica real, y es la
frontera de época entre la Baja Edad Media y la Moderna.

### B3. Primera cadena completa
Cuarcita de río → pico → marisqueo → conchero. Corta y cerrada. **Si esa cadena
no es satisfactoria, el resto es contenido sobre un juego que no funciona.**

---

## FASE C — El arte como motor

El saber tácito muere con quien lo tiene. Fijarlo en un soporte material lo
convierte en patrimonio del grupo: por eso el arte funciona como motor
tecnológico sin dejar de ser arte.

### C1. Estados de técnica
`DESCONOCIDA` → `TÁCITA` (decae con el relevo generacional) → `EXTERNALIZADA`
(permanente, pero atada al sitio donde está el soporte).

### C2. Externalización
No se puede pintar una caza que no se ha hecho: la obra tiene que ser **sobre**
algo ocurrido. Cuesta ocre, luz y jornadas.

### C3. Escalera de soportes
Parietal (inmóvil) → mobiliar (portátil) → cerámica (replicable) →
**escritura** → imprenta. El salto está en la escritura: antes hay que enseñar
mostrando, después basta con contar.

**Guardarraíl: no debe existir una puntuación de arte.** El recurso escaso
obliga a elegir *cuál* saber se hace permanente. Es una mecánica de
priorización sobre el árbol tecnológico, no una vía paralela que le compita.

---

## FASE D — Épocas

**Once** épocas con cultura material documentada en Cantabria, del Paleolítico
al siglo XIX. Cada una es **datos**: materiales, procesos y edificios
disponibles, más las técnicas que hay que externalizar para cerrarla.

Fueron doce hasta el 2026-09-12: el siglo corto (1900–1982) se retiró porque el
motor de jornadas y calorías no simula jornal ni capital, y está archivado en
[archivo/EPOCA_12_SIGLO_CORTO.md](archivo/EPOCA_12_SIGLO_CORTO.md). Con
él se fue el final circular de la partida —*el mapa se cierra sobre
`cantabria.json`*—, que **queda pendiente de decidir**: hoy la partida acaba en
el hito de cierre de El vapor, que es un cierre de época haciendo de final.

Están escritas una a una en [EPOCAS.md](EPOCAS.md), con el hito que cierra cada
una y la regla que decide qué merece ser época y qué no. El nivel de
implementación de cada una —catálogo de técnicas, condición de disparo de
cada hito, oficios nuevos, clases a escribir— está en `EPOCA_NN_NOMBRE.md`
junto a esa misma época, y lo que comparten las once vive en
[SISTEMAS.md](SISTEMAS.md): las tres escaleras
(térmica, soporte, alimento), el sistema de `Hito`, la exploración en tres
capas —local ya construida, regional pendiente en A1, exterior sin
empezar—, el comercio y los cuatro hitos que se sufren.

**El tiempo avanza por hitos, no por calendario.** El Paleolítico es el 99,4 %
del intervalo real; si el tiempo de juego fuese proporcional, la partida entera
sería tallar cuarcita. El calendario sigue corriendo dentro de una época para
estaciones y cosechas.

Hoy el filtro por época existe pero usa **abrigo y relieve**, no periodo
arqueológico: 86 emplazamientos ocupables en el Paleolítico porque tienen cueva,
que es la única vivienda de esa época.

---

## FASE E — Fidelidad y datos

### E1. Agua real
Ríos y lagos desde polígonos de OpenStreetMap. Lo actual los deduce del
relieve, que acierta el trazado del valle pero no la geometría. Arreglaría de
paso que `water_km` no se recalcule por época.

### E2. Periodos arqueológicos reales
Cruzar con el inventario del Gobierno de Cantabria. OSM solo trae periodo en
unas decenas de registros.

### E3. Geología
IGME MAGNA 1:50.000 para que los recursos líticos y minerales salgan del
sustrato real y no del ruido celular.

### E4. Trazabilidad visible
Cada material, proceso y edificio con su nivel de evidencia
(`ATESTIGUADO` / `INFERIDO` / `PLAUSIBLE`) y su fuente, expuestos en una
enciclopedia dentro del juego.

**«100 % históricamente fiable» no es alcanzable** —hay siglos de los que no
sabemos qué comía la gente— y perseguirlo es el mayor riesgo de que el proyecto
no termine nunca. Lo que sí se puede garantizar y defender es que ninguna
afirmación del juego esté sin etiqueta, y que la proporción de `PLAUSIBLE` esté
acotada.

---

## FASE F — Deuda e infraestructura

Sin orden fijo; se atiende cuando estorbe.

- Descarga de teselas en un hilo, con barra de progreso. Hoy congela la ventana.
- Dejar sólo el `InputMap` en `OrbitalCamera`: lee las teclas físicas **y** las
  acciones para el mismo eje, y eso anula el remapeo configurado en
  `project.godot`.
- Reactivar el ciclo día/noche (`WorldEnvironmentSetup.follow_time_of_day`), hoy
  desactivado a propósito para trabajar con luz.
- Decidir qué pasa con las capas de física 2–4 (`props`, `resources`, `banda`):
  están nombradas en `project.godot` y no se asigna ninguna. O se usan, o se
  retiran. Ver SPECS.md §5.
- Otra pasada de troceado a `SettlementSim`, que ha vuelto a 4 119 líneas. La
  receta y sus trampas, en ARQUITECTURA.md §3.
- Tirones de la capa local que crecen con los días: bajar su coste sin cambiar
  la partida, con la misma semilla dando la misma partida antes y después. Ver
  [archivo/LO_MISMO_MAS_DEPRISA.md](archivo/LO_MISMO_MAS_DEPRISA.md).

Cerrado y fuera de esta lista: la suite de pruebas, las bocas de
cueva contra la ladera (`CaveMouth`), e `Inventory.gd`/`GameUtils.gd`, que se
retiraron del repositorio con el resto de la capa vieja.

---

## Riesgos

**El alcance.** Cuarenta mil años, once épocas, procesos físicos, comercio y
fidelidad histórica sigue siendo más de lo que cabe en un proyecto personal.
Retirar el siglo corto fue el primer recorte real, no el último: EPOCAS.md §7
deja escrito el orden de los siguientes. La FASE B3 —una sola cadena completa y
corta— existe justamente para comprobar pronto si el núcleo divierte, antes de
construir contenido encima.

**El trabajo en paralelo.** Con varios agentes sobre el mismo árbol, lo que
rompe no es el código sino la medida: dos sondas a la vez no miden nada. El
protocolo está en [AGENTES.md](AGENTES.md) y no es opcional.

**El dato manda hasta donde llega.** El DEM tiene una muestra cada 14 m; por
debajo de esa escala todo lo que se ve es invención. Conviene recordarlo cada
vez que algo parezca poco detallado: la respuesta no es añadir ruido.
