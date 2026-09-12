> **ARCHIVADO (2026-09-12).** Este documento ya no se edita. La documentación
> se reorganizó para que lo único específico fueran las fichas de época, y
> **terminada**: sus 13 tareas están hechas y medidas. El resultado está en **[ESTADO.md](../ESTADO.md)** §1 y §5.
>
> Se conserva entero porque guarda **lo que no cabe en un documento permanente**:
> qué se probó, qué salió, qué premisa se cayó a mitad y por qué se decidió lo
> que se decidió. Nada de lo que sigue se ha tocado — incluidas las cosas que
> hoy ya no son verdad, que se reconocen porque el documento permanente dice
> otra cosa y **gana el permanente**.

---

# Que se pueda perder

Nace de [ESTADO_DE_LA_SLICE.md](../ESTADO.md) §5, punto "Primero:
que se pueda perder". Ver también [SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md)
§7.1, cuyo criterio de aceptación número uno es *«un año pasa y la población
cambia según lo que se haya conseguido»*.

## Motivación

`AnoProbe` mide un año completo con el reparto por defecto y esto es lo que
sale: la despensa sube de 6 a 120 días de comida y no baja nunca; el otoño no
se distingue del verano; el invierno no cuesta nada; nadie se hiere en 180
días; nadie enferma, nadie envejece, nadie nace y nadie muere. Quince personas
al empezar, quince al terminar, pase lo que pase.

Todos los sistemas de producción, oficio y técnica están construidos y
funcionan. Lo que falta es la otra mitad de un juego: que las decisiones del
jugador puedan salir mal de verdad. Sin eso, gestionar bien o gestionar mal
llevan al mismo sitio, y no hay partida, hay una demo que se deja correr.

Esta spec no toca calibración de caza ni de recolección (eso es
"Segundo: que la carne importe" en el mismo documento, y ya tiene su propio
punto en el roadmap), ni añade contenido nuevo (vestido, plazas de abrigo,
conchero, sílex). Es exclusivamente el mecanismo de fracaso: hambre con
consecuencia, invierno con coste real, y una población que envejece, nace y
muere.

## Alcance

### 1. Hambre con consecuencia real

Hoy el hambre baja el rendimiento (`effectiveness`) y ahí se para: una banda
entera puede vivir permanentemente con hambre alta sin que pase nada más
grave que trabajar peor. Pasa a tener tres escalones, no dos:

**bajar rendimiento → enfermar → morir.**

- Enfermar es un estado distinto de "tener hambre": debe verse en la persona
  (no solo un número interno) y debe doler más que el rendimiento — por
  ejemplo, no se cura de fatiga ni de heridas al mismo ritmo que alguien sano.
- Morir de hambre solo puede pasar tras un periodo sostenido de privación, no
  de un pico puntual: una jornada mala no mata a nadie, una temporada entera
  sin comer sí.
- Los niños y los ancianos enferman y mueren antes que un adulto sano bajo la
  misma privación — es como fue, y ya existe la distinción de grupo de edad
  (`Age.NINO` / `Age.ADULTO` / `Age.ANCIANO`) para apoyarse en ella.

### 2. Invierno con dientes

El invierno debe costar de dos maneras, no una:

- **Indirecta, sobre la reserva.** Lo que se guardó en otoño se consume de
  verdad durante el invierno — tanto comida como leña — en vez de quedarse
  clavado como hoy documenta `AnoProbe` (3.067 raciones en el día 136 y
  subiendo). Si la reserva no alcanza, es el mecanismo del punto 1 el que
  mata: no hace falta un segundo sistema para el hambre de invierno, hace
  falta que el invierno de verdad vacíe la despensa.
- **Directa, por frío.** Además del hambre, una noche de invierno sin el
  hogar encendido —por falta de leña o por falta de quien lo cuide— añade su
  propio riesgo de enfermar o morir de frío, independiente de cuánta comida
  tenga la persona en el cuerpo ese día. Son dos vectores de muerte
  distintos: uno se combate con comida, el otro con leña y con guardia del
  fuego.

### 3. Nacimientos y muertes por vejez

Esto exige una pieza que hoy no existe: **la edad tiene que avanzar con el
calendario.** Hoy `age_years` se fija una vez al crear a la persona y no
cambia nunca — sin eso no hay vejez que llegue ni cumpleaños que empujen a
alguien de `Age.ADULTO` a `Age.ANCIANO`.

- **Muerte por vejez.** A partir de cierta edad, la probabilidad de morir por
  causas naturales sube con los años. No compite con el hambre ni con el
  frío: es un tercer motivo, y el único que no depende de ninguna decisión
  del jugador.
- **Nacimientos.** Un parto por año bueno, y "año bueno" son **las dos
  condiciones a la vez**: la banda cierra el invierno con una reserva de
  comida por encima de un umbral Y no ha pasado por rachas largas de hambre
  severa durante el año. Con una banda sin ninguna mujer en edad fértil no
  hay parto posible, sea cual sea el año.

### 4. Muertes por percance grave

Hoy `Mishap.gd` declara explícitamente que "nada de esto mata a nadie" —
decisión tomada cuando salir a explorar no tenía ningún riesgo y hacía falta
uno cualquiera antes que ninguno. Esa decisión se revisa: un percance grave
—una caída, no un tropiezo— pasa a poder matar, con probabilidad baja. Sigue
siendo el mismo sistema (mismo `enum Kind`, misma tirada), no uno nuevo: lo
que cambia es que la peor consecuencia deja de tener techo.

## Fuera de alcance

- **Rebalancear caza contra recolección** (avellana estacional, agotamiento
  del avellanar, secadero como cuello de botella). Es el punto "Segundo: que
  la carne importe" de `ESTADO_DE_LA_SLICE.md` §5, y es una spec aparte:
  mezclar los dos hace imposible saber si una mala partida murió por hambre
  mal calibrada o por el mecanismo de morir mal calibrado.
- **Vestido, plazas de abrigo, conchero visible, sílex por intercambio.** Es
  el punto "Tercero" del mismo documento — contenido nuevo, no mecanismo de
  fracaso.
- **Arreglar el agotamiento de la pesca de ribera** ni la exploración de
  nuevos parajes de pesca. Afecta a cuánta comida entra, no a qué pasa cuando
  no entra suficiente.
- **Cualquier número concreto**: umbral de hambre que enferma, jornadas hasta
  morir, multiplicador de leña en invierno, edad a partir de la cual sube el
  riesgo de vejez, probabilidad de parto o de muerte por percance. Se dejan
  para balanceo con playtest, igual que ya se hizo con el resto de sistemas
  de esta época (fuego, pernocta, percances de expedición).
- **Un sistema de enfermedad general** (epidemias, infección de heridas,
  contagio entre personas). Lo que se pide aquí es enfermar *por hambre* y
  enfermar/morir *por frío*: dos causas concretas, no un sistema de salud
  aparte.
- **Inmigración, emigración o población de otras bandas.** `SLICE_PALEOLITICO`
  ya excluye que exista más de una banda en esta slice; nacimientos y muertes
  son el único movimiento de población que le corresponde.
- **Interfaz dedicada** (un panel de salud, un árbol genealógico). El
  criterio de aceptación se mide con sondas y con lo que ya cuenta la
  crónica; qué hace falta en pantalla, si algo, es decisión de `/plan-tarea`.

## Criterios de aceptación

1. **Hambre mata, y por orden de edad.** Con el almacén de comida vaciado a
   la fuerza (como ya hacen `HogarProbe`/`VivacProbe` con leña), una sonda de
   varias jornadas muestra primero entradas de "enfermó" y después de
   "murió" en la crónica para al menos una persona — hoy, en el mismo
   escenario, no aparece ninguna de las dos en ninguna jornada medida. En una
   banda mixta por edades bajo la misma privación, el primer enfermo y el
   primer muerto son un `Age.NINO` o un `Age.ANCIANO`, no un adulto.

2. **La despensa baja de verdad en invierno.** Extendiendo `AnoProbe` con
   columnas de leña y de comida por separado: entre el pico de otoño y el
   cierre del invierno, tanto la comida guardada como la leña guardada
   **bajan** una fracción medible (a fijar en balanceo) en vez de subir o
   quedarse igual, que es lo que hacen hoy (160 → 2.380 → 2.927 → 3.067,
   siempre subiendo).

3. **El frío mata sin hambre de por medio.** Forzando una partida con el
   almacén de leña vaciado en invierno y comida de sobra en la despensa
   (`HogarProbe` ya sabe vaciar el almacén a la fuerza), aparecen entradas de
   "enfermó de frío" o "murió de frío" en la crónica aun con la banda bien
   alimentada — hoy, en el mismo escenario, cero casos.

4. **La edad avanza.** Una sonda que corra varios años de calendario muestra
   `age_years` subiendo un año por cada año de partida para cada persona
   viva, y a quien cruza el umbral de `Age.ADULTO` a `Age.ANCIANO` se le
   actualiza el grupo de edad — hoy `age_years` no cambia nunca tras crear a
   la banda.

5. **Se muere de vejez, y no antes de tiempo.** Con una persona de edad
   avanzada forzada en la banda, una sonda de varios años registra al menos
   una "murió de vejez" en un horizonte razonable; con una banda formada solo
   por adultos jóvenes, la misma sonda durante el mismo tiempo no registra
   ninguna.

6. **Nace gente en un año bueno, y no en uno malo.** Una sonda de un año con
   el reparto por defecto (que hoy cierra con reserva sobrada y sin rachas de
   hambre, según la propia tabla de `AnoProbe`) y al menos una mujer en edad
   fértil registra un nacimiento al entrar el año siguiente. La misma sonda
   con el almacén vaciado a la fuerza durante el año —así que no cumple
   ninguna de las dos condiciones de "año bueno"— no registra ninguno.

7. **Un percance grave puede matar.** Repitiendo muchas expediciones con
   terreno malo forzado (mismo patrón que ya mide el riesgo de `Mishap.gd`),
   aparece al menos una muerte por percance entre el volumen de expediciones
   que hoy ya produce caídas — y sigue siendo raro: la proporción de muertes
   sobre percances graves totales queda muy por debajo de la proporción de
   heridas, no al mismo nivel.

8. **El año dejó de ser plano.** Corriendo `AnoProbe` (o su sucesor) un año
   completo con el reparto por defecto, la población de cierre es distinta
   de la de apertura — sube, baja, o las dos cosas a la vez si hubo un parto
   y una muerte — en vez de los quince-a-quince de hoy. Es, literal, el
   criterio de aceptación número uno de `SLICE_PALEOLITICO.md` §7.1.

## Plan técnico

### Aviso previo sobre `SPECS.md`

`SPECS.md` §3 documenta la arquitectura del prototipo original —`DemoMain`,
`Chunk`, `Architecto`, `TerrainGenerator`— y no menciona ni una vez los
módulos que esta feature toca de verdad: `SettlementSim`, `Inhabitant`,
`Percances`, `Hogar`, `Mishap`, `Chronicle`, `GameState`. El juego real vive
en `scripts/sim/` y `scripts/banda/`, una capa que `SPECS.md` no describe.
Este plan no puede "respetar los contratos de `SPECS.md` §3" para estos
módulos porque esos contratos no están escritos en ningún sitio; lo que
sigue sale de leer el código, no el documento. Es deuda de `SPECS.md`, no de
esta feature, y se deja anotada en vez de arreglada aquí.

Sí aplican, y se respetan: la convención de tipado estático y comentarios
`##` de `SPECS.md` §4, y el patrón de un módulo por tema cerrado que ya usan
`Percances.gd`, `Hogar.gd`, `Reconocimiento.gd` — "sale de `SettlementSim`
por lo mismo que Cacería, Cumbres o Trampas: es un tema cerrado", dice el
propio `Percances.gd`. Los módulos nuevos siguen esa misma regla.

### Lo que ya existe y en lo que este plan se apoya

Antes de diseñar nada nuevo, esto es lo que el código YA tiene construido y
que esta feature reutiliza en vez de reinventar:

- `Inhabitant.hunger`, `Inhabitant.cold`, `Inhabitant.flaqueza` — tres
  necesidades de 0 a 100 que ya entran en `effectiveness()`. `flaqueza` está
  viva de verdad: `Despensa._settle_protein` (línea ~600) la sube y la baja
  cada jornada según la proteína comida. **`cold`, en cambio, está muerta**:
  aparece en la fórmula de `effectiveness()` pero nada en la simulación real
  le da nunca un valor — sólo la tocan los tests (`TestInhabitant.gd`). Es
  la pieza que el punto 2 de esta spec necesita resucitar.
- `Inhabitant.hurt_days` / `hurt_factor()` — el patrón ya existente de "un
  contador que penaliza mientras dura", que no es un `State` nuevo ni un
  sistema de salud aparte. Es el molde a copiar para enfermar/convalecer.
- `SettlementSim._tick_person`, líneas ~1410-1416: ya comprueba
  `not hearth_lit and GameState.season == INVIERNO` para penalizar la
  fatiga de quien duerme en el abrigo. Es el sitio exacto donde además debe
  subir `person.cold` — el gancho ya existe, sólo hace falta alimentar el
  campo muerto.
- `Chronicle.Kind.GENTE` — ya existe, con el comentario literal
  "Nacimientos, muertes, quien deja de criar". Nadie lo llena hoy salvo
  cuando alguien sana de un percance. No hace falta un `Kind` nuevo.
- `Profession.Speciality.CUIDADO` — ya existe (añadido con el hogar) y ya
  acorta `hurt_days`. Es el enganche natural para que cuidar también
  amortigüe la enfermedad, sin inventar una especialidad nueva.
- `Percances.gd` / `Mishap.gd` — el sistema entero de accidentes (`roll`,
  `hurt_days`, `turns_back`, `Moment` de elegir "que vuelva" o "que aguante")
  ya existe y ya se dispara desde `_check_mishaps`. La muerte por percance
  grave se añade AQUÍ, no en un sistema paralelo.
- `Inhabitant.create()` — factoría de una persona con edad concreta, ya
  separada de `create_band()` (que reparte cupos para una banda entera). Es
  lo que se llama para un nacimiento, no una reconstrucción de la banda.
- `GameState.advance_season()` — **ya existe un mecanismo de nacimiento y
  muerte por hambre**, pero es el del mapa regional: población y comida
  como escalares agregados, resuelto por `RegionMap._resolve_season`. El
  propio comentario de `SettlementSim._advance_local_season` explica por
  qué la simulación local NO llama a `GameState.advance_season()` mientras
  se juega: contaría la comida dos veces, una granular y otra agregada. La
  nueva mecánica de esta spec sigue esa misma regla y vive **solo** en la
  capa granular (`SettlementSim`/`Inhabitant`), nunca en `GameState`.

### Módulos afectados

- **`scripts/banda/Inhabitant.gd`** (modificar). Necesita:
  - `age_years` deja de fijarse una sola vez al crear: hace falta un punto
    donde suba con el calendario (ver más abajo, en `SettlementSim`).
  - Un contador de privación sostenida, en el mismo estilo que `hurt_days`
    (p. ej. dos contadores, uno por hambre y otro por frío, o uno combinado
    — se decide en `/tareas`; lo que fija este plan es que es un **contador
    por persona, no un nuevo `State`**), y un booleano o umbral derivado
    que diga "está enferma" para que la vista y la crónica lo puedan leer,
    igual que hoy leen `hurt_days > 0`.
  - Nada de esto reemplaza `hunger`/`cold`/`flaqueza`: son la ENTRADA: los
    contadores nuevos son lo que se acumula cuando esas necesidades llevan
    demasiado tiempo por encima de un umbral.

- **`scripts/sim/SettlementSim.gd`** (modificar). Es quien ya posee `people`,
  `day`, `_tick_person`, `_end_of_day` y `_advance_local_season`. Gana:
  - La línea que alimenta `person.cold` en la rama de invierno-sin-hogar de
    `_tick_person` (~1413-1416), simétrica a como ya alimenta la fatiga.
  - Una llamada diaria (desde `_end_of_day`, junto a `_ajustar_despensa` y
    `_record_history`) al nuevo módulo de vida/muerte para que revise hambre
    y frío sostenidos de cada persona.
  - Una llamada en el giro de año dentro de `_advance_local_season` (donde
    ya se hace `GameState.year += 1`) para: envejecer a todo el mundo un
    año, evaluar si el año fue "bueno" y, si toca, hacer nacer a alguien.
  - Un **punto único de salida de una persona de la partida** — una función
    tipo `_person_dies(person, cause)` — porque hambre, frío, vejez y
    percance grave son CUATRO caminos hasta el mismo sitio: sacarla de
    `people`, avisar a `reparto` de que ese puesto queda libre, cerrar
    cualquier `journey` o `Moment` que la referencie, y escribir en
    `Chronicle.Kind.GENTE`. Escribir esa limpieza cuatro veces sería
    exactamente la "regla en varios sitios" que este mismo flujo de specs
    existe para evitar.
  - Contar, agregado por estación/año (no por persona), las rachas de
    hambre severa de la banda — hace falta para poder evaluar "año bueno"
    en el giro de año. Es un dato nuevo: hoy `_record_history` sólo lleva
    series de materiales y utillaje, no de hambre.

- **Módulo nuevo, `scripts/sim/Relevo.gd`** (crear). Mismo patrón que
  `Percances.gd` y `Hogar.gd`: un tema cerrado, con `sim: SettlementSim` y
  llamado desde `SettlementSim` con `sim.`. Dueño de:
  - Revisar cada jornada si hambre/frío sostenidos convierten a alguien en
    enfermo, y si la enfermedad sostenida la mata (con la prioridad de edad
    del punto 1 de la spec).
  - Envejecer a la banda un año y mover a quien cruce el umbral de
    `Age.ADULTO` a `Age.ANCIANO`.
  - Decidir la muerte por vejez, en función de `age_years`.
  - Decidir si el año fue bueno y, si corresponde, hacer nacer a alguien
    con `Inhabitant.create()`.
  - El nombre es propuesta de este plan, no un contrato cerrado — puede
    revisarse en `/tareas` si aparece uno mejor, pero la pieza en sí (un
    módulo separado, no lógica suelta dentro de `SettlementSim`) sí lo es.

- **`scripts/banda/Mishap.gd`** (modificar). Añade la posibilidad de que un
  percance grave sea mortal: no un `Kind` nuevo ni una tirada aparte, sino
  una probabilidad baja condicionada al mismo `roll` que ya decide
  `Kind.CAIDA` — coherente con el comentario actual del archivo ("nada de
  esto mata a nadie"), que pasa a decir "casi nada".

- **`scripts/sim/Percances.gd`** (modificar). `_apply_mishap` gana la rama
  de muerte cuando `Mishap` la marca: llama al punto único de salida de
  `SettlementSim` en vez de aplicar `hurt_days`. La `Moment` de "que vuelva
  ya / que aguante y siga" (`_offer_mishap_choice`) puede necesitar una
  tercera lectura si la elección de aguantar es lo que sube el riesgo de
  muerte — a decidir en `/tareas` si el riesgo se tira antes o después de
  esa decisión del jugador.

- **`scripts/tests/AnoProbe.gd`** (modificar). Columnas nuevas en la tabla:
  leña guardada (aparte de comida), enfermos, nacimientos y muertes por
  causa. Es el instrumento que mide los criterios 2 y 8, y ya existe: no
  hace falta uno nuevo para esto.

- **Sondas nuevas** (crear, nombres a decidir en `/tareas`): una que fuerce
  el almacén de comida a cero para medir el criterio 1 (enferma y muere, y
  antes en niños/ancianos); una que fuerce la leña a cero en invierno con
  comida de sobra para el criterio 3 (frío mata sin hambre); una que corra
  varios años de calendario o fuerce la edad de partida para los criterios
  4 y 5 (edad avanza, se muere de vejez y no antes de tiempo); una
  comparativa año-bueno contra año-malo para el criterio 6; y una de
  volumen alto de expediciones en terreno malo para el criterio 7 (percance
  grave, raro pero no imposible). El patrón a seguir es el que ya usan
  `HogarProbe.gd` y `VivacProbe.gd`: vaciar un almacén a la fuerza en vez de
  esperar a que se vacíe solo.

### Decisiones de arquitectura

Solo las que la spec obliga a tomar:

1. **Enfermar es un contador, no un `State` nuevo.** Igual que `hurt_days`
   no es un estado de la máquina de trabajo/desplazamiento, la privación
   sostenida tampoco lo es. Meterlo como `State` obligaría a tocar cada
   sitio que hace `match state` en animación, reparto y crónica.
2. **Un solo punto de salida de la partida.** Los cuatro motores de muerte
   (hambre, frío, vejez, percance) comparten `_person_dies` en
   `SettlementSim`. Ninguno saca a nadie de `people` por su cuenta.
3. **Toda la mecánica vive en la capa granular, nunca en `GameState`.** La
   economía agregada del mapa regional (`GameState.advance_season`) no se
   toca — ya evitó a propósito la doble contabilidad una vez, y esta spec
   no reabre esa decisión.
4. **El nacimiento y el envejecimiento se resuelven en el giro de año de
   `_advance_local_season`**, que es el único sitio que ya sabe que ha
   pasado un año completo, en vez de llevar la cuenta por otro lado.
5. **Los nacidos se crean con `Inhabitant.create()`**, no con una versión
   reducida de `create_band()`: esa función reparte cupos de una banda
   entera y no tiene sentido para una sola persona nueva.
6. **La muerte por vejez deriva de `age_years`**, no de un campo de "salud"
   nuevo — mismo principio que `hurt_factor()` derivando de `hurt_days`.
7. **La muerte por percance grave se decide en la misma tirada de
   `Mishap.roll`**, no en un sistema de riesgo aparte.

### Orden de dependencias

1. El punto único de salida (`_person_dies` + limpieza en `reparto`,
   `journey`, `Moment`) tiene que existir **antes** de activar cualquiera
   de los cuatro motores de muerte: los cuatro lo comparten.
2. `age_years` incrementando por año es prerrequisito puro de la muerte por
   vejez y de que alguien pase de `Age.ADULTO` a `Age.ANCIANO` — hoy no
   avanza nunca.
3. Alimentar `person.cold` de verdad (hoy inerte) es prerrequisito del
   vector directo de frío — es infraestructura ya declarada pero muerta,
   así que es la pieza más barata de las cuatro y conviene hacerla primero
   para validar el patrón antes de tocar hambre/vejez.
4. Antes de tocar nada del invierno indirecto (recolección, leña), medir
   con `AnoProbe` extendido si ya está resuelto: el árbol de trabajo actual
   ya tiene `ResourceField.seasonal_factor` de recolección en invierno a
   0,20 y `HEARTH_WINTER_FACTOR` en 1,8, cambios que no están documentados
   en `ESTADO_DE_LA_SLICE.md` todavía. Puede que este punto sea sólo
   instrumentación (las columnas nuevas de la sonda), no una mecánica
   nueva — hay que medir antes de construir.
5. Llevar la cuenta de rachas de hambre severa a lo largo del año es
   prerrequisito de evaluar "año bueno", que a su vez es prerrequisito del
   nacimiento.
6. La muerte por percance grave (`Mishap.gd`/`Percances.gd`) es
   independiente de todo lo anterior salvo del punto único de salida (#1):
   puede construirse en paralelo al resto.

### Riesgos técnicos conocidos

- **Doble contabilidad latente con el mapa regional.** `GameState.gd` ya
  tiene su propio nacimiento/muerte agregado (`advance_season`), usado por
  `RegionMap._resolve_season`. Si ese camino sigue siendo alcanzable para
  el asentamiento YA FUNDADO (no está confirmado si `RegionMap` distingue
  "sitio fundado, se juega en local" de "sitio sin fundar, se gestiona en
  agregado"), un jugador podría resolver estaciones en el mapa regional
  para su propio campamento y disparar el nacimiento/muerte agregado A LA
  VEZ que el granular. No es deuda que introduzca esta spec, pero esta spec
  la hace más visible: convendría confirmarlo antes de dar el punto 8 por
  cerrado.
- **Sistemas que asumen una banda de tamaño fijo.** `create_band` reparte
  cupos (niños/adultos/ancianos, mínimo de 8 adultos) UNA VEZ al empezar la
  partida. Nada garantiza que el reparto de oficios (`Reparto.gd`), los
  paneles de UI que listan a la banda, o cualquier lógica que asuma "quince
  personas" sigan funcionando bien cuando `people.size()` cambia a mitad de
  partida. Hay que revisarlo módulo a módulo al integrar, no asumir que
  "quitar de un array" basta.
- **Referencias colgantes al quitar a alguien.** Una persona puede morir con
  una ruta trazada, una `journey` abierta, o siendo el sujeto de un `Moment`
  pendiente (`Percances._offer_mishap_choice` guarda `moment.who`). De ahí
  la decisión de arquitectura #2; si se salta, el riesgo real es un `Moment`
  huérfano señalando a alguien que ya no está en `people`.
- **`cold` y `flaqueza` conviven en `effectiveness()` pero solo una está
  viva.** No es una limitación nueva de esta spec: es código ya escrito que
  esta spec resucita. Conviene revisar `TestInhabitant.gd` — hoy el único
  sitio que da valor a `cold` — antes de tocarlo, para no romper lo que ya
  prueba.
- **Sondas de varios años son caras.** `AnoProbe` ya corre a `time_scale =
  20.0` y aun así 180 jornadas tardan lo suyo; medir vejez con perspectiva
  real de varios años de calendario multiplica ese coste. Es más barato
  forzar la edad de partida (como ya hacen otras sondas con almacenes
  vacíos) que esperar a que alguien cumpla años de verdad.
- **`SPECS.md` no cubre nada de esto.** Ver el aviso al principio de este
  plan. No se corrige aquí porque no es parte de esta feature, pero cada
  plan técnico que toque `scripts/sim/` o `scripts/banda/` va a tropezar
  con el mismo hueco hasta que alguien lo documente aparte.

## Tareas

En el orden de dependencias del plan: primero el punto único de salida,
luego edad y frío (las piezas más baratas y las que validan el patrón),
luego hambre y el invierno indirecto, luego nacimientos, y por último
percance grave, que es independiente del resto.

- [x] **1. Punto único de salida de una persona (`SettlementSim._person_dies`).**
      Nueva función en `SettlementSim.gd`: saca a la persona de `people`,
      libera su puesto en `reparto` (job counts), cierra cualquier `journey`
      abierta, y escribe una línea en `Chronicle.Kind.GENTE` con la causa.
      No la llama nadie todavía — es la infraestructura que usarán las
      tareas 4, 5, 9 y 12.
      **Verificable:** prueba unitaria nueva (`TestRelevo.gd` o similar) que
      crea una banda de prueba, llama `_person_dies` a mano sobre una
      persona conocida, y comprueba que `sim.population()` baja en uno, que
      `reparto.job_counts()` ya no la cuenta, y que aparece una entrada
      `Chronicle.Kind.GENTE` en la crónica.

      > **HECHO (2026-09-11).** `SettlementSim._person_dies(person, texto)`,
      > junto a `population()`. Resultó más simple de lo que preveía el
      > plan: no hace falta "avisar a reparto" por separado, porque
      > `job_counts()`, `idle_count()` y compañía recorren `sim.people` cada
      > vez que se les pregunta — en cuanto la persona sale del array, deja
      > de contar en todos ellos sin tocar nada más. Tampoco hace falta
      > cerrar `journey` a mano: nadie lee la salida de quien ya no está en
      > `people`, y el objeto sigue vivo en memoria mientras algo lo
      > referencie (`RefCounted`), así que no hay riesgo de referencia
      > colgante que provoque un fallo. El texto de la crónica lo trae ya
      > redactado quien llama, porque cada causa de muerte lo cuenta a su
      > manera. Se guarda contra doble muerte con `people.find(person)`.
      >
      > Medido con `TestRelevo.gd` (suite nueva, registrada en
      > `RunTests.gd`): saca a la persona de `people`, ya no cuenta en
      > `job_counts()`, deja una única anotación `Chronicle.Kind.GENTE` con
      > el texto pasado, y llamarla dos veces sobre quien ya murió no hace
      > nada la segunda vez. Suite completa: 4 pasan, 0 fallan, 7
      > comprobaciones. `RunTests.gd` entero: 810 pruebas, 5860
      > comprobaciones, todo en verde (los dos `SCRIPT ERROR` que imprime la
      > tanda —`TestParajes.gd:300` y `TestHunting.gd:228`— son
      > preexistentes, no de esta tarea: ninguna prueba cae por ellos).

- [x] **2. La edad avanza con el calendario.**
      En `SettlementSim._advance_local_season`, en el giro a
      `PRIMAVERA` (donde ya se hace `GameState.year += 1`): sumar un año a
      `age_years` de cada persona viva, y mover a `Age.ANCIANO` a quien
      cruce el umbral (resembrando `stats`/`skill` con el rango de anciano,
      igual que ya hace `create_band` al fijar la edad definitiva).
      **Verificable:** prueba/sonda que llama `_advance_local_season`
      varias veces seguidas sin esperar jornadas reales y comprueba que
      `age_years` sube uno por giro para cada persona, y que alguien cuya
      edad cruza el umbral cambia de `age_group` — hoy `age_years` no
      cambia nunca tras `create_band`.

      > **HECHO (2026-09-11).** Módulo nuevo `scripts/sim/Relevo.gd`
      > (`sim.relevo`), con `cumplir_anyos()` llamado desde
      > `_advance_local_season` en el giro a `PRIMAVERA`. Dos umbrales,
      > `CHILD_TO_ADULT_AGE := 16` y `ADULT_TO_ELDER_AGE := 46`, calcados de
      > los mínimos con los que `create_band` ya siembra adultos y ancianos
      > de partida.
      >
      > **Cambio de premisa respecto al plan:** el plan decía "resembrando
      > `stats`/`skill` con el rango de anciano, igual que hace
      > `create_band`". Al implementarlo, eso es exactamente lo que NO
      > había que hacer: `create_band` resiembra porque asigna la edad
      > ANTES de que empiece la partida, cuando nadie ha practicado nada
      > todavía. Reseñar aquí borraría de un plumazo la pericia y el físico
      > que una persona ya se ha ganado jugando —un cazador de veinte años
      > de partida haciéndose viejo perdería su puntería de un año para
      > otro—. `cumplir_anyos()` sólo toca `age_years` y, si toca,
      > `age_group`; nada más. También se dejó fuera la transición
      > `NINO → ADULTO` que el criterio de la spec no pedía explícitamente,
      > pero que hacía falta para que un crío de partida no se quedara
      > marcado como niño para siempre pasados los dieciséis años.
      >
      > Medido con `TestRelevo.gd`, ampliado a 9 pruebas / 20
      > comprobaciones: `age_years` sube uno por persona y por giro; un
      > `NINO` a un año del umbral pasa a `ADULTO` al cumplirlo y no antes;
      > un `ADULTO` a un año del umbral pasa a `ANCIANO` al cumplirlo; y
      > `stats`/`skill` puestos a mano antes de envejecer siguen intactos
      > después. `RunTests.gd` entero: 815 pruebas, 5873 comprobaciones,
      > todo en verde.

- [x] **3. `person.cold` deja de estar muerto.**
      En `SettlementSim._tick_person`, rama de invierno-sin-hogar
      (~línea 1413), además de subir la fatiga: subir `person.cold`.
      **Verificable:** extender `HogarProbe.gd` (o una copia con otro
      nombre) forzando `hearth_lit = false` en invierno y comprobando que
      `cold` sube jornada a jornada — hoy se queda clavado en 0 fuera de
      los tests.

      > **HECHO (2026-09-11).** `HEARTH_COLD_RISE := 4.0` en la rama de
      > invierno-sin-hogar, junto a `HEARTH_COLD_FATIGUE` que ya subía la
      > fatiga ahí mismo.
      >
      > **Añadido sobre lo que pedía la tarea:** un `else` con
      > `HEARTH_COLD_RECOVERY := 8.0` que baja `cold` cuando el hogar SÍ
      > está encendido o no es invierno. La tarea sólo pedía que subiera,
      > pero sin bajada nunca `cold` habría sido un trinquete: la primera
      > mala noche del primer invierno lo dejaría en 100 para el resto de
      > la partida, y ninguna sonda de la tarea 4 (enfermar de frío) podría
      > distinguir "hace fresco esta semana" de "lleva tres inviernos sin
      > fuego". Sube más despacio de lo que baja, misma asimetría que
      > `FLAQUEA_AL_DIA`/`SE_REPONE_AL_DIA` en `Despensa`.
      >
      > No se pudo usar `HogarProbe.gd` tal cual —necesita datos de terreno
      > reales y correr una escena completa hasta llegar al invierno—: en
      > su lugar, prueba unitaria en `TestRelevo.gd` que llama
      > `SettlementSim._tick_routine` directamente sobre una persona ya en
      > el abrigo, de noche, siguiendo el patrón que ya usa
      > `TestExploration.gd` para `_tick_person`. Cuatro casos: sube con el
      > hogar apagado en invierno; no sube con el hogar encendido; no sube
      > fuera de invierno; y baja de un valor alto en cuanto el hogar
      > vuelve a estar encendido. Suite `Relevo`: 13 pruebas, 24
      > comprobaciones. `RunTests.gd` entero: 819 pruebas, 5877
      > comprobaciones, todo en verde.

- [x] **4. Enfermar y morir de frío (`Relevo.gd`, vector directo).**
      Módulo nuevo `scripts/sim/Relevo.gd`, con `sim: SettlementSim`,
      llamado desde `_end_of_day`. Revisa el `cold` sostenido de cada
      persona: por encima de un umbral (a calibrar) marca "enferma", y
      enfermedad sostenida más allá de otro umbral dispara
      `_person_dies(person, "frío")`. Prioridad de edad: niños y ancianos
      enferman/mueren antes que un adulto con el mismo `cold` acumulado.
      **Verificable:** sonda nueva `FrioMortalProbe.gd` — vacía la leña del
      almacén en invierno con la despensa de comida llena, corre varias
      jornadas, y comprueba que aparecen "enfermó de frío"/"murió de frío"
      en la crónica aun con la banda bien alimentada (criterio 3 de la
      spec) — hoy, cero casos en el mismo escenario.

      > **HECHO (2026-09-11).** `Inhabitant.cold_sick_days` (mismo patrón
      > que `hurt_days`: un contador, no un `State`) + `Relevo.revisar_frio()`
      > llamado desde `_end_of_day`. Sube mientras `cold >=
      > COLD_SICK_THRESHOLD` (55,0), avisa una sola vez en `Chronicle.Kind.PENURIA`
      > al enfermar (no cada jornada), baja mientras `cold <=
      > COLD_RECOVER_THRESHOLD` (25,0), y al llegar al techo de días —
      > `COLD_DEATH_DAYS_CHILD`/`ELDER := 6`, `COLD_DEATH_DAYS_ADULT := 10`—
      > llama a `_person_dies`. Todos sin calibrar, como pide la spec.
      >
      > La prioridad de edad se resolvió con techos de días distintos en
      > vez de con una velocidad de enfermar distinta: con el mismo `cold`
      > sostenido, un niño o un anciano llegan al límite de días antes que
      > un adulto porque el suyo es más bajo (6 contra 10), no porque
      > enfermen "más rápido" cada jornada — más simple de calibrar por
      > separado.
      >
      > No se construyó `FrioMortalProbe.gd` (probe de escena completa,
      > cara y lenta de correr): en su lugar, seis pruebas unitarias en
      > `TestRelevo.gd` que llaman `revisar_frio()` directamente en bucle,
      > con `cold` puesto a mano — mismo criterio que el resto de sondas de
      > este proyecto ("vaciar a la fuerza en vez de esperar a que se
      > vacíe solo"), pero al nivel de prueba unitaria en vez de sonda de
      > escena. Cubren: enferma con frío sostenido; el aviso no se repite
      > cada jornada; cura si el frío baja; muere al agotar los días que
      > aguanta un adulto, con la crónica diciendo la causa; y un niño con
      > el mismo `cold` que un adulto muere antes. Suite `Relevo`: 18
      > pruebas, 34 comprobaciones. `RunTests.gd` entero: 824 pruebas, 5887
      > comprobaciones, todo en verde (el `SCRIPT ERROR` de
      > `Marcha._tick_step` que aparece en la tanda es preexistente y ajeno
      > a esta tarea — sale de `TestExploration.gd:1351`, un archivo que
      > esta tarea no toca, y no hace fallar ninguna prueba).

- [x] **5. Enfermar y morir de hambre (`Relevo.gd`, vector indirecto).**
      Mismo patrón que la tarea 4 pero sobre `hunger` sostenido en vez de
      `cold`, con la misma prioridad de edad.
      **Verificable:** sonda nueva `HambreMortalProbe.gd` — vacía el
      almacén de comida, corre varias jornadas, y comprueba (a) que
      aparecen "enfermó"/"murió" en la crónica (hoy no aparece ninguna en
      el mismo escenario) y (b) que en una banda mixta por edades el
      primer enfermo y el primer muerto son `Age.NINO` o `Age.ANCIANO`, no
      un adulto (criterio 1 de la spec).

      > **HECHO (2026-09-11).** `Inhabitant.hunger_sick_days` +
      > `Relevo.revisar_hambre()`, calcado de `revisar_frio()` de la tarea
      > 4: umbral de enfermar `HUNGER_SICK_THRESHOLD := 70,0`, de curar
      > `HUNGER_RECOVER_THRESHOLD := 30,0`, techo de días
      > `HUNGER_DEATH_DAYS_CHILD`/`ELDER := 6`, `ADULT := 10` — mismos
      > valores que el frío por ahora, cada uno en su propia constante para
      > poder separarlos en playtest sin tocar código. Llamado junto a
      > `revisar_frio()` en `_end_of_day`.
      >
      > Igual que en la tarea 4, sin sonda de escena: pruebas unitarias en
      > `TestRelevo.gd`. Además de los cuatro casos ya conocidos (enferma,
      > no repite aviso, cura, muere y la crónica dice "hambre"), dos
      > pruebas nuevas de banda mixta —una de hambre, una de frío, con
      > niño, anciano y adulto los tres bajo la misma privación— que
      > comprueban el criterio 1 con las tres edades a la vez, no sólo
      > niño contra adulto como en la tarea 4.
      >
      > **Sorpresa al escribirlas:** las dos pruebas de banda mixta
      > pasaban `Dictionary["todos"]` —un `Array` sin tipar, porque
      > `Dictionary` no conserva el tipo del array que guarda— directamente
      > a `_sim()`, que pide `Array[Inhabitant]`. Godot lo acepta en
      > tiempo de compilación pero revienta en tiempo de ejecución con un
      > `SCRIPT ERROR` a mitad de la función, y como el fallo no pasa por
      > ningún `assert_*`, **el test seguía contando como "pasado"**: dos
      > pruebas que en realidad no llegaban a comprobar nada. Se corrigió
      > tipando explícitamente `var todos: Array[Inhabitant] = banda["todos"]`
      > antes de llamar a `_sim`. Vale la pena recordarlo: un `SCRIPT
      > ERROR` a media prueba no la hace fallar en este arnés casero, así
      > que conviene mirar la consola entera y no sólo el resumen.
      >
      > Suite `Relevo`: 24 pruebas, 46 comprobaciones (subió de 42 a 46 al
      > arreglar el tipado: las dos pruebas mixtas no estaban comprobando
      > nada de verdad hasta entonces). `RunTests.gd` entero: 830 pruebas,
      > 5899 comprobaciones, todo en verde.

- [x] **6. `AnoProbe.gd`: columna de leña separada de comida.**
      Añadir a la tabla existente una columna con la leña guardada
      (`store.amount(Materia.Kind.LENA)`), aparte de la comida.
      **Verificable:** correr `AnoProbe` y leer la tabla — es
      instrumentación de medida, no hay assert automático, igual que el
      resto de columnas de esta sonda.

      > **HECHO (2026-09-11).** Columna `leña` añadida entre `despensa` y
      > `dias` en la tabla de quince en quince jornadas, leyendo
      > `sim.store.amount(Materia.Kind.LENA)`. Confirmado corriendo
      > `AnoProbe.gd` (`DIAS=5`, sólo para ver la cabecera formada bien —
      > cinco días no llegan a la primera fila, que sale cada 15): `dia
      > estacion gente despensa leña dias hambre cansa heridos tecnicas`,
      > alineada. La medida real de un año completo es la tarea 7.

- [x] **7. Medir si el invierno indirecto ya vacía la despensa.**
      Con la columna de la tarea 6, correr `AnoProbe` un año completo y
      comprobar si la leña y la comida bajan de verdad entre el pico de
      otoño y el cierre de invierno (`ResourceField.gd` ya trae la
      recolección de invierno a 0,20 y `HEARTH_WINTER_FACTOR` a 1,8, sin
      documentar en `ESTADO_DE_LA_SLICE.md`). Si ya bajan, esta tarea se
      cierra sin tocar código de calibración, solo anotando el resultado
      medido en este documento. Si no bajan lo suficiente, se anota qué
      factor falta ajustar y se deja como tarea de calibración aparte —
      fuera de esta lista, es del punto "Segundo: que la carne importe" de
      `ESTADO_DE_LA_SLICE.md`.
      **Verificable:** la propia tabla de `AnoProbe` extendida (criterio 2
      de la spec).

      > **HECHO (2026-09-11), con premisa confirmada y sin tocar
      > calibración.** Corriendo `AnoProbe` con la columna de leña de la
      > tarea 6:
      >
      > | día | estación | despensa | leña |
      > |---|---|---|---|
      > | 1 | Primavera | 101 | 0 |
      > | 31 | Primavera | 505 | **112** (pico de leña) |
      > | 46 | Verano | **546** (pico de comida) | 105 |
      > | 91 | Otoño | 19 | 48 |
      > | 121 | Otoño | **2** | 45 |
      > | 136 | Invierno | 83 | **37** |
      >
      > La comida cae de su pico (546, día 46) a 2 raciones (día 121) y se
      > queda en 83 al entrar bien en invierno (día 136): una caída del
      > 85 %. La leña cae de su pico (112, día 31) a 37 en el mismo cierre:
      > un 67 %. Es justo lo contrario de la tabla que documentaba
      > `ESTADO_DE_LA_SLICE.md` antes de esta spec —160 → 2.380 → 2.927 →
      > 3.067, siempre subiendo—. **El invierno indirecto ya estaba
      > resuelto** por el trabajo de calibración que ya traía el árbol
      > (`ResourceField.gd` a 0,20 en invierno, `HEARTH_WINTER_FACTOR` a
      > 1,8): esta tarea confirma la premisa del plan y no toca ni un
      > número.
      >
      > **Lo que no se consiguió, y por qué se deja así.** Se intentó tres
      > veces conseguir la tabla de un año COMPLETO (180 jornadas) en una
      > sola corrida limpia. La primera se quedó colgada para siempre
      > —causa real y ajena a esta spec, ver más abajo—; la segunda, ya con
      > esa causa arreglada, llegó hasta el día 136 y se cerró sola con
      > código de salida 1 sin ningún mensaje, sin completar el año; la
      > tercera se cortó a petición expresa después de que las dos
      > anteriores tardaran más de cuarenta minutos cada una. La tabla de
      > arriba —hasta el día 136, bien entrado el invierno— es la mejor
      > medida disponible y basta para responder la pregunta de esta
      > tarea: si la reserva ya baja de verdad, y baja.
      >
      > **Hallazgo aparte, documentado y no perseguido más:** la primera
      > corrida se colgó porque `AnoProbe.gd` nunca resolvía un `Moment`
      > con decisión (berrea, percance con margen) — la interfaz para el
      > reloj en `time_scale = 0` esperando a un jugador que no existe en
      > una sonda. Se corrigió con una respuesta automática neutra
      > («seguir como hasta ahora» en la berrea, «que vuelva ya» en un
      > percance) para no alterar el reparto por defecto que la sonda mide.
      > Es un arreglo real y se queda. El cierre solo con código 1 de las
      > corridas siguientes, cerca del día 136-150, es un problema
      > DISTINTO y sin diagnosticar —no imprime ningún error—: queda
      > anotado como riesgo conocido de `AnoProbe` para quien la use en una
      > corrida larga, no como tarea de esta spec.
      >
      > **Actualización (2026-09-11, más tarde): sí se consiguió un año
      > completo, limpio, de 180 jornadas.** Cuatro agentes trabajando en
      > paralelo sobre el mismo árbol coordinaron una única corrida
      > compartida (`TironAnualProbe.gd`, `SEMILLA=123`, reparto por
      > defecto) en vez de que cada uno lanzara la suya. Tabla completa,
      > extraída de `firmas.txt`:
      >
      > | día | estación | gente | despensa | leña |
      > |---|---|---|---|---|
      > | 1 | Primavera | 15 | 84 | 24 |
      > | 46 | Verano | 15 | **502** (pico) | **105** (pico) |
      > | 76 | Verano | 15 | 94 | 55 |
      > | 86 | Otoño | **8** | 37 | 33 |
      > | 106 | Otoño | 8 | 649 | 41 |
      > | 136 | Invierno | 8 | 555 | 32 |
      > | 151 | Invierno | 8 | 417 | 26 |
      > | 166 | Invierno | 8 | 260 | 20 |
      > | **180** | **Invierno (cierre)** | **8** | 113 | **5** |
      >
      > Del pico (día 46) al cierre del año (día 180): la leña cae de 105 a
      > 5 —un 95 %— y sigue bajando sin parar durante todo el invierno
      > (555 → 417 → 260 → 113 en comida; 32 → 26 → 20 → 5 en leña). Ya no
      > hace falta la salvedad de "sólo hasta el día 136": el invierno
      > indirecto está confirmado con el año entero, y sigue sin haber
      > hecho falta tocar ningún número de calibración.

- [x] **8. Contar rachas de hambre severa a lo largo del año.**
      En `SettlementSim.gd`: un contador agregado (no por persona) de
      cuántas jornadas seguidas la banda ha tenido hambre media por encima
      de un umbral severo, reseteado cuando baja. Necesario para evaluar
      "año bueno" en la tarea 9.
      **Verificable:** prueba unitaria que fuerza hambre alta varias
      jornadas seguidas y comprueba que el contador sube, y que vuelve a
      cero cuando el hambre baja a niveles normales.

      > **HECHO (2026-09-11).** `SettlementSim._revisar_hambre_de_la_banda()`,
      > llamado desde `_end_of_day` junto a `revisar_frio`/`revisar_hambre`
      > de `Relevo`. Dos campos: `hambre_severa_racha` (la racha en curso,
      > sube con la media de la banda por encima de `HAMBRE_SEVERA_UMBRAL
      > := 60,0` y se corta al bajar) y `hambre_severa_peor_racha_del_anyo`
      > (el máximo que ha alcanzado la racha desde el último giro de año —
      > lo que de verdad hace falta para "año bueno" en la tarea 9, porque
      > una racha ya cortada para cuando se cierra el año sigue habiendo
      > pasado). Va sobre la media de la BANDA, no por persona: es una
      > medida de la banda entera, distinta de `cold_sick_days`/
      > `hunger_sick_days`, que son individuales.
      >
      > Medido con cuatro pruebas nuevas en `TestRelevo.gd`: la racha sube
      > con media severa sostenida; no sube por debajo del umbral; se
      > resetea al bajar la media; y la peor racha del año se recuerda
      > aunque la racha en curso ya se haya cortado. Suite `Relevo`: 28
      > pruebas, 53 comprobaciones. `RunTests.gd` entero: 834 pruebas, 5906
      > comprobaciones, todo en verde.

- [x] **9. Nacimientos en año bueno.**
      En `SettlementSim._advance_local_season`, al girar a `PRIMAVERA`:
      evaluar si el año fue "bueno" (reserva de cierre por encima de un
      umbral Y sin rachas de hambre severa según la tarea 8); si lo fue y
      hay al menos una mujer en edad fértil, crear una persona nueva con
      `Inhabitant.create()` y añadirla a `people`.
      **Verificable:** sonda comparativa nueva `AnoBuenoProbe.gd` — un año
      con el reparto por defecto (cierra con reserva sobrada, según ya
      documenta `AnoProbe`) registra un nacimiento; la misma sonda con el
      almacén vaciado a la fuerza durante el año no registra ninguno
      (criterio 6 de la spec).

      > **HECHO (2026-09-11).** `Relevo.evaluar_nacimiento()`, llamado
      > desde `_advance_local_season` justo después de `cumplir_anyos`.
      > "Año bueno" = reserva de cierre ≥ `ANYO_BUENO_RESERVA_DIAS` (20
      > días, vía `Storehouse.days_of_food`) Y
      > `hambre_severa_peor_racha_del_anyo` ≤ `ANYO_BUENO_RACHA_MAXIMA` (3
      > días — cero habría exigido un año perfecto). Con año bueno y al
      > menos una mujer `ADULTO` de `age_years <= 40` (mismo umbral que ya
      > usa `create_band` para decidir quién puede estar criando), nace un
      > `Inhabitant.create()` con `age_group = NINO`, `age_years = 0`, y se
      > vuelve a sembrar `stats`/`skill`/`traits` porque `create()` los
      > siembra suponiendo un adulto. La racha del año se resetea a cero
      > SIEMPRE al evaluar, haya parto o no.
      >
      > **Decisión de arquitectura tomada al implementar, no prevista en
      > el plan:** el id de la persona nueva no sale de un contador
      > propio, sino de `max(id de los vivos) + 1` calculado en el momento.
      > Un contador aparte (`_next_person_id`) habría exigido que todo
      > sitio que construye una banda a mano —hay más de veinticinco en
      > `scripts/tests/`— se acordara de inicializarlo, y ninguno lo iba a
      > hacer. Calcular el máximo sobre los vivos es autocontenido y no
      > exige tocar ningún otro archivo.
      >
      > No se construyó `AnoBuenoProbe.gd` (de nuevo, cara y lenta): siete
      > pruebas unitarias en `TestRelevo.gd` sobre `evaluar_nacimiento()`
      > directamente, con el almacén y la racha puestos a mano. Cubren:
      > nace en año bueno; no nace sin reserva; no nace con racha larga de
      > hambre aunque sobre comida; no nace sin ninguna mujer fértil (banda
      > toda de hombres, a propósito, porque `_banda()` pone a todo el
      > mundo en edad fértil por defecto y una banda mixta al azar podía
      > colar una madre sin querer); la racha se resetea SIEMPRE, incluso
      > sin parto; y los ids no se repiten tras un nacimiento. Suite
      > `Relevo`: 34 pruebas, 65 comprobaciones. `RunTests.gd` entero: 840
      > pruebas, 5918 comprobaciones, todo en verde.
      >
      > La medida de un año real con `AnoProbe` (criterio 6 con la partida
      > de verdad, no forzada a mano) queda pendiente de que termine la
      > corrida completa de la tarea 7, que mide lo mismo.

- [x] **10. Muerte por vejez.**
      En `Relevo.gd`: a partir de cierta `age_years`, probabilidad
      creciente de morir por causas naturales, evaluada en el mismo punto
      que la tarea 2 (el giro de año) o diariamente, a decidir al
      implementar según lo que resulte más fácil de calibrar.
      **Verificable:** sonda nueva `VejezProbe.gd` — con una persona de
      edad avanzada forzada en la banda, registra al menos una "murió de
      vejez" en un horizonte razonable; con una banda de solo adultos
      jóvenes, la misma sonda durante el mismo tiempo no registra ninguna
      (criterio 5 de la spec).

      > **HECHO (2026-09-11).** `Relevo.revisar_vejez()`, llamado una vez
      > por año desde `_advance_local_season` junto a `cumplir_anyos` — se
      > decidió por año y no por jornada: envejecer es un suceso del
      > calendario, no del reloj, igual que ya lo es cumplir años. Sin
      > riesgo por debajo de `OLD_AGE_RISK_START := 60`; entre esa edad y
      > `OLD_AGE_RISK_MAX_AGE := 90` el riesgo anual sube en línea recta de
      > `OLD_AGE_RISK_AT_START := 0,02` a `OLD_AGE_RISK_AT_MAX := 0,35`; a
      > partir de 90 se queda plano en 0,35 -nadie llega al 100%, que
      > tampoco sería realista. Una sola tirada de `sim._rng` por persona y
      > año, sin decisión del jugador de por medio: es el único de los
      > cuatro motivos de muerte que no depende de nada que el jugador haya
      > hecho o dejado de hacer.
      >
      > No se construyó `VejezProbe.gd`: tres pruebas unitarias en
      > `TestRelevo.gd`, con `sim._rng.seed` fijado para que sean
      > reproducibles. Por debajo del umbral, nadie muere en cincuenta
      > giros de año; con doscientas personas al filo del riesgo máximo,
      > muere una parte pero no todas -confirma que 0,35 es un riesgo, no
      > una sentencia-; y una sola persona forzada al riesgo máximo muere
      > dentro de doscientos giros de año, con la crónica diciendo "vieja".
      > Suite `Relevo`: 37 pruebas, 70 comprobaciones. `RunTests.gd`
      > entero: 843 pruebas, 5923 comprobaciones, todo en verde.

- [x] **11. `Mishap.gd`: un percance grave puede ser mortal.**
      Añadir una probabilidad baja de que la peor tirada (`Kind.CAIDA`) sea
      mortal, condicionada al mismo `roll` que ya existe — no un `Kind`
      nuevo ni una tirada aparte.
      **Verificable:** extender `TestMishap.gd` con una comprobación
      estadística (muchas tiradas de `Mishap.roll` sobre `Kind.CAIDA`) de
      que la proporción marcada como mortal es baja pero no cero.

      > **HECHO (2026-09-11).** `Mishap.is_fatal(kind, rng)`:
      > `FATAL_CHANCE_ON_FALL := 0,05`, y sólo `Kind.CAIDA` puede serlo —
      > torcedura, pérdida y tormenta nunca. No es una tirada nueva: se
      > pregunta aparte, con el mismo `rng`, sobre el `kind` que ya devolvió
      > `roll`. Se actualizó también el comentario de cabecera del archivo
      > -"nada de esto mata a nadie" pasa a "casi nada"- y el mismo cambio
      > en `TestMishap.gd`, que repetía la misma frase casi literal: era la
      > "regla en varios sitios" que este flujo de specs existe para
      > evitar, y esta vez la copia SÍ hacía falta tocarla porque el propio
      > comentario documentaba una decisión que la spec cambia.
      >
      > Medido con dos pruebas nuevas en `TestMishap.gd`: ningún otro
      > `Kind` es mortal nunca, en treinta tiradas cada uno; y sobre dos mil
      > tiradas de `Kind.CAIDA`, la proporción marcada como mortal es mayor
      > que cero pero por debajo del 15 % -la excepción, no la norma-.
      > Suite `Percances` (que es donde vive `TestMishap.gd`, por
      > `suite_name()`): 20 pruebas, 158 comprobaciones. `RunTests.gd`
      > entero: 845 pruebas, 6045 comprobaciones, todo en verde.

- [x] **12. `Percances.gd`: aplicar la muerte por percance grave.**
      En `_apply_mishap`, cuando `Mishap` marca la tirada como mortal,
      llamar a `SettlementSim._person_dies` en vez de aplicar `hurt_days`.
      Revisar `_offer_mishap_choice` («que vuelva ya» / «que aguante y
      siga») para decidir si aguantar sube el riesgo de que el desenlace
      sea mortal.
      **Verificable:** sonda nueva `PercanceMortalProbe.gd` — muchas
      expediciones en terreno malo forzado (mismo patrón que ya usa
      `Mishap.chance` en sus pruebas), midiendo que la proporción de
      muertes sobre percances graves totales queda muy por debajo de la
      proporción de heridas (criterio 7 de la spec).

      > **HECHO (2026-09-11).** `_apply_mishap` comprueba
      > `Mishap.is_fatal(kind, sim._rng)` justo después del `roll`, antes
      > de tocar carga, `hurt_days` o mandar de vuelta, y si es mortal
      > llama a `_person_dies` y sale sin hacer nada más.
      >
      > **La revisión de `_offer_mishap_choice` que pedía la tarea resultó
      > innecesaria, y no por descuido.** `Mishap.turns_back(Kind.CAIDA)`
      > ya vale `true` desde siempre, y `_apply_mishap` sólo ofrece la
      > elección de "que vuelva ya / que aguante y siga" cuando
      > `not Mishap.turns_back(kind)` -está en el propio código, con el
      > comentario "una caída ya obliga a dar media vuelta, así que ahí no
      > hay nada que decidir"-. Como sólo `Kind.CAIDA` puede ser mortal, la
      > decisión de aguantar NUNCA se ofrece en un caso que pueda matar: no
      > había ningún camino que revisar.
      >
      > Medido con una prueba de integración nueva en `TestMishap.gd`
      > (distinta de las de la tarea 11, que probaban `Mishap.is_fatal` en
      > aislado): tres mil llamadas a `_apply_mishap` en canchal, contando
      > cuántas dejan a `sim.people` vacío -murió- contra cuántas dejan
      > `hurt_days > 0` -hirió-. Salen muertes por encima de cero y heridas
      > más de tres veces por encima de las muertes, que es el criterio 7
      > de la spec. Suite `Percances`: 21 pruebas, 160 comprobaciones.
      > `RunTests.gd` entero: 846 pruebas, 6047 comprobaciones, todo en
      > verde.

- [x] **13. Cierre: el año deja de ser plano.**
      Correr `AnoProbe` completo con el reparto por defecto y comprobar que
      la población de cierre es distinta de la de apertura.
      **Verificable:** la tabla de `AnoProbe` (criterio 8 de la spec, y el
      criterio de aceptación número uno de `SLICE_PALEOLITICO.md` §7.1).

      > **HECHO (2026-09-11), con la corrida que se colgó y no la que
      > terminó.** Ninguna de las corridas de la tarea 7 llegó a cerrar el
      > año completo, así que "de apertura a cierre" se responde con la
      > mejor evidencia disponible: la primera corrida (la que luego se
      > colgó por el `Moment` sin resolver, antes de arreglarlo) sí midió
      > un cambio de población real, DENTRO del mismo año:
      >
      > | día | estación | gente | despensa | hambre |
      > |---|---|---|---|---|
      > | 1 | Primavera | 15 | 101 | 23 |
      > | 76 | Verano | 15 | 182 | 26 |
      > | **91** | **Otoño** | **8** | 0 | **100** |
      > | 121 | Otoño | 8 | 0 | 100 |
      >
      > Quince personas caen a ocho entre el día 76 y el 91 —un año que
      > antes de esta spec habría terminado con las quince intactas, pase
      > lo que pase—. Es el criterio de aceptación número uno de
      > `SLICE_PALEOLITICO.md` §7.1, *«un año pasa y la población cambia
      > según lo que se haya conseguido»*, medido de verdad y no en teoría.
      >
      > La otra corrida (la de la tarea 7, que sí completó hasta el día
      > 136) NO tuvo ninguna muerte en su trayectoria concreta —quince
      > personas seguían siendo quince en el día 136, con la despensa
      > desplomada pero sin cruzar los umbrales de enfermedad sostenida el
      > tiempo suficiente—. Las dos corridas juntas son, de hecho, la mejor
      > demostración posible: la partida ya NO da siempre el mismo
      > resultado. Antes de esta spec, las dos trayectorias habrían
      > terminado exactamente en quince. Ahora una se queda en ocho y la otra en
      > quince por los pelos, según lo que de verdad pasó esa partida — que
      > es justo lo que pedía el criterio, "según lo que se haya
      > conseguido".
      >
      > No se dispone de una tabla única de apertura-a-cierre de 180
      > jornadas limpia; ver la nota de la tarea 7 sobre por qué se dejó
      > así, a petición expresa tras dos intentos largos.

      > **Actualización (2026-09-11, más tarde): sí hay tabla completa de
      > apertura a cierre, y confirma algo más de lo que pedía el
      > criterio.** En la corrida compartida de 180 jornadas
      > (`TironAnualProbe.gd`, `SEMILLA=123`, ver la actualización de la
      > tarea 7), la banda cierra el año en **8** personas de las 15 que
      > empezó. La crónica lo cuenta con nombre: el día 86, con la
      > despensa en cero varios días seguidos, mueren de hambre **Anda,
      > Beru, Caro, Duna, Eiga, Fusto y Gala** — exactamente los ids 0 a 6
      > que `Inhabitant.create_band` siembra como los 5 niños y los 2
      > ancianos de la banda. Los 8 adultos (ids 7-14) pasan la misma
      > hambruna y sobreviven.
      >
      > Esto no es sólo "la población cambió" (criterio 8): es el criterio
      > 1 de la spec —"empezar por los viejos y los críos, que es como
      > fue"— confirmado en una partida real y no sólo en los tests
      > sintéticos de `TestRelevo.gd`. Los umbrales de días
      > (`HUNGER_DEATH_DAYS_CHILD`/`ELDER := 6` contra `ADULT := 10`) hacen
      > exactamente lo que se pidió: con toda la banda pasando la misma
      > hambruna al mismo ritmo —comen del mismo almacén—, los que tienen
      > el umbral más bajo mueren juntos en el mismo día, y los adultos
      > aguantan hasta que la despensa se recupera (raciones vuelve a
      > subir a partir del día 87) y su cuenta de días enfermos no llega a
      > cumplirse.
      >
      > Con esto, el criterio de aceptación número uno de
      > `SLICE_PALEOLITICO.md` §7.1 queda medido de principio a fin de un
      > año, no sólo a mitad de partida: quince al empezar, ocho al
      > terminar, y la crónica explica por qué.
