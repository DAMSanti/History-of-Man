> **ARCHIVADO (2026-09-12).** Este documento ya no se edita. La documentación
> se reorganizó para que lo único específico fueran las fichas de época, y
> **terminada**: sus 10 tareas están hechas. El resultado está en **[ESTADO.md](../ESTADO.md)** §7.
>
> Se conserva entero porque guarda **lo que no cabe en un documento permanente**:
> qué se probó, qué salió, qué premisa se cayó a mitad y por qué se decidió lo
> que se decidió. Nada de lo que sigue se ha tocado — incluidas las cosas que
> hoy ya no son verdad, que se reconocen porque el documento permanente dice
> otra cosa y **gana el permanente**.

---

# Qué falta para jugarlo

Nace de [ESTADO_DE_LA_SLICE.md](../ESTADO.md) §7, "Qué falta para
poder jugarlo" — los cuatro puntos que bloquean que esto sea una partida y no
una demo de sistemas, salvo el quinto (la interfaz, que ya tiene su propio
documento en [INTERFAZ.md](../INTERFAZ.md)). Cubre: el objetivo de partida, que
la derrota se vea en pantalla, el ritmo de la estación y que la primera hora
enseñe sin tutorial.

## Motivación

[QUE_SE_PUEDA_PERDER.md](QUE_SE_PUEDA_PERDER.md) construyó el mecanismo de
fracaso — hambre, frío, vejez y percance que pueden matar de verdad — y está
casi cerrado (tareas 1-12 hechas; sólo quedan dos tareas de medida, no de
mecanismo). Pero un mecanismo de morir no es una partida si nada lo hace
visible ni existe nada que ganar. Hoy:

- No hay ningún objetivo: la partida no pide nada, y `ESTADO_DE_LA_SLICE.md`
  §7 lo dice explícito: *"sobrevivir un año, llegar a X personas, pintar la
  cueva: cualquiera vale, pero tiene que haber uno"*.
- El mecanismo de morir que ya existe no se ve. `QUE_SE_PUEDA_PERDER.md` lo
  deja dicho en su propio "Fuera de alcance": *"Interfaz dedicada... qué hace
  falta en pantalla, si algo, es decisión de `/plan-tarea`"* — pero antes de
  `/plan-tarea` hace falta decidir el qué, y es esta spec la que lo fija.
- Los 45 días por estación (`Subsistence.DAYS_PER_SEASON`) son mucho reloj a
  velocidad normal para lo que hoy ocurre en pantalla.
- La banda arranca con la tabla de trabajos en blanco y sin ninguna
  indicación — quince personas ociosas es la primera imagen del juego.

Sin objetivo ni derrota visible, jugar bien o jugar mal llevan al mismo sitio
en pantalla aunque el mecanismo de abajo ya distinga entre los dos. Esta spec
cierra esa distancia.

## Alcance

### 1. Objetivo de partida: sobrevivir el año Y pintar la cueva

El objetivo es doble, no una elección entre alternativas: la partida se gana
cuando, al cerrar el año (`Subsistence.DAYS_PER_SEASON` × 4 jornadas), la
banda sigue viva Y la pared del abrigo tiene pintado un mínimo de lo vivido
ese año — el número exacto de relatos pintados que cuenta como "la cueva está
pintada" se deja para balanceo con playtest, mismo criterio que ya usa
`QUE_SE_PUEDA_PERDER.md` para sus propios umbrales.

- Cumplir sólo una de las dos condiciones al cerrar el año no es victoria: la
  partida sigue, sin premio, camino del año siguiente.
- Pintar la cueva puede lograrse antes de que cierre el año; sobrevivir
  todavía hay que sostenerlo hasta el final.
- No hay elección de objetivo al empezar la partida: es el mismo objetivo
  doble siempre, en esta primera versión.

### 2. La derrota, visible en pantalla

El mecanismo ya existe (`QUE_SE_PUEDA_PERDER.md`); lo que falta es que se
note sin tener que abrir la crónica. Dos piezas, las dos:

- **Un indicador de riesgo permanente**, visible todo el año sin abrir ningún
  panel — no sólo en otoño, que es cuando ya existe el medidor de tensión de
  `CIERRE_SLICE.md` §7.3. Tiene que reflejar cuán cerca está la banda de
  desaparecer, no cuánta comida hay guardada, que ya lo cuenta el medidor de
  otoño.
- **Un cierre de partida** cuando la población llega a cero: un momento que
  lo diga con claridad, con la causa (mismo patrón que ya usa `Moment` en
  `CIERRE_SLICE.md` §7.2 para la berrea o un percance), no sólo una entrada
  más en `Chronicle.Kind.GENTE` que hay que ir a buscar.

### 3. Ritmo: llenar la estación de decisiones, no acortarla

`ESTADO_DE_LA_SLICE.md` §7 plantea la disyuntiva entre acelerar el año o
llenarlo de decisiones. Esta spec toma la segunda vía: los 45 días por
estación se quedan como están, y lo que se corrige es que una estación entera
pueda pasar sin que el jugador tenga nada que decidir.

`CIERRE_SLICE.md` §7 ya construyó varias piezas de esto — decisiones con
nombre y cara, momentos de control directo, tensión visible del otoño,
descubrimiento como recompensa — pero nadie ha medido si, juntas, sostienen
una estación entera sin huecos largos, ni si las cuatro estaciones están
igual de servidas o si el invierno (la de menos que hacer, según la propia
banda) se queda atrás. Esta spec pide medir eso y cerrar el hueco que
aparezca; no prescribe con qué decisión concreta se llena, eso es trabajo de
`/plan-tarea` y de balanceo.

### 4. La primera hora enseña sin tutorial

Al fundar el asentamiento, antes de que el jugador toque nada, tiene que
quedar claro sin salir de la partida: qué se persigue (el objetivo doble del
punto 1), que se puede perder (el punto 2), y cuál es la primera decisión
—repartir los oficios de la banda—. Un único momento inicial, no una
secuencia de pantallas de tutorial ni un modo aparte que se pueda saltar o
dejar a medias.

## Fuera de alcance

- **Rebalancear caza contra recolección** ni ningún otro número de
  producción. Es "Segundo: que la carne importe" de `ESTADO_DE_LA_SLICE.md`
  §5, spec aparte.
- **Contenido nuevo** (vestido, plazas de abrigo, conchero visible, sílex por
  intercambio). Es "Tercero" del mismo documento.
- **Terminar `QUE_SE_PUEDA_PERDER.md`.** Sus tareas 7 y 13 (medir si el
  invierno vacía la despensa, y confirmar que el año deja de ser plano) son
  de esa spec, no de ésta; esta spec depende de que el mecanismo de muerte
  funcione, no de que esté calibrado.
- **Cambiar `Subsistence.DAYS_PER_SEASON`** ni ningún otro número del
  calendario. La dirección elegida en el punto 3 es llenar la estación, no
  acortarla.
- **Elegir objetivo al empezar la partida**, o añadir "llegar a X población"
  como objetivo alternativo. El objetivo de esta primera versión es fijo y
  doble (punto 1); un menú de modos de partida es una feature aparte si hace
  falta más adelante.
- **Rediseñar la interfaz.** Ver [INTERFAZ.md](../INTERFAZ.md), documento
  aparte para el punto 5 de `ESTADO_DE_LA_SLICE.md` §7.
- **El riesgo de doble contabilidad con el mapa regional** que
  `QUE_SE_PUEDA_PERDER.md` ya deja anotado en sus riesgos técnicos. No lo
  reabre esta spec.
- **Números concretos**: cuántos relatos pintados cuentan como "la cueva está
  pintada", cómo se calcula el indicador de riesgo, cuántas jornadas sin
  decisión son demasiadas. Se dejan para balanceo con playtest, igual que el
  resto de umbrales de esta época.

## Criterios de aceptación

1. **La victoria existe y es doble.** Una sonda de un año completo con el
   reparto por defecto (la misma que ya usa `AnoProbe`, o su sucesora)
   registra una entrada de victoria en la crónica cuando, al cerrar el año,
   la población es mayor que cero Y el número de relatos pintados alcanza el
   umbral fijado — hoy, en el mismo escenario, no existe ninguna entrada
   equivalente pase lo que pase.
2. **Cumplir sólo una condición no gana ni termina la partida.** La misma
   sonda, forzando que se pinte lo suficiente pero vaciando el almacén para
   que la banda no llegue viva al cierre del año (o al revés, banda viva sin
   pinturas), no registra victoria, y la partida sigue corriendo hacia el año
   siguiente en vez de detenerse.
3. **La derrota tiene un cierre visible.** Forzando la muerte de la banda
   entera (mismo patrón que ya usan las sondas de `QUE_SE_PUEDA_PERDER.md`
   para vaciar almacenes), aparece un momento de cierre con la causa de la
   extinción — hoy, en el mismo escenario, sólo quedan entradas sueltas en
   `Chronicle.Kind.GENTE` que nadie destaca.
4. **El riesgo se ve todo el año, no sólo en otoño.** Leyendo o capturando el
   elemento de pantalla correspondiente en una jornada de invierno o de
   primavera con población baja forzada, su estado es distinto del que
   muestra la misma partida con población sana — hoy no existe ningún
   indicador de este tipo fuera de la ventana de otoño.
5. **Ninguna estación se queda muda.** Una sonda que recorre una estación
   completa (45 jornadas) con el reparto por defecto cuenta cuántas jornadas
   seguidas pasan sin que se ofrezca ningún momento o decisión activa al
   jugador; tras esta feature, ese tramo más largo queda por debajo del
   umbral fijado en las cuatro estaciones, invierno incluido — el primer paso
   es medir cuánto es hoy, que no está medido en ningún sitio.
6. **La primera hora enseña sin tutorial.** Una sonda que arranca una
   partida nueva comprueba que, en la primera jornada y antes de cualquier
   acción del jugador, se dispara un único momento que menciona el objetivo
   doble, la posibilidad de perder y la primera decisión a tomar — y que no
   existe ningún modo "tutorial" ni secuencia de pantallas aparte activándose
   en su lugar.

## Plan técnico

### Aviso previo sobre `SPECS.md`

Mismo aviso que ya deja `QUE_SE_PUEDA_PERDER.md`: `SPECS.md` §3 documenta el
prototipo original (`DemoMain`, `Chunk`, `Architecto`, `TerrainGenerator`) y no
menciona `scripts/sim/` ni `scripts/banda/`, que es donde vive todo lo que
este plan toca. Lo que sigue sale de leer el código — `SettlementSim.gd`,
`Moment.gd`, `Relevo.gd`, `Pinturas.gd`, `BarraSuperior.gd`, `DemoMain.gd` —,
no de `SPECS.md`. Sí aplican y se respetan la convención de tipado estático y
comentarios `##` de §4, y el patrón de "un módulo por tema cerrado" que ya
usan `Relevo.gd`, `Percances.gd`, `Hogar.gd`.

### Corrección sobre la propia spec

El punto 2 de esta spec da por hecho que el medidor de tensión de
`CIERRE_SLICE.md` §7.3 (`BarraSuperior._build_winter_gauge`) sólo se ve "en
otoño". Leyendo el código no es así: ese medidor está SIEMPRE en la barra de
arriba, todo el año — lo que cambia con la estación es sólo el rótulo
("De cara al invierno" → "BERREA · de cara al invierno" → "Invierno ·
reserva"). No cambia lo que pide la spec (sigue haciendo falta un indicador
nuevo, porque ese medidor mide reserva de comida, no riesgo de extinción de
la banda) ni ningún criterio de aceptación; se deja anotado aquí para que
quien lea el criterio 4 no se confunda con el porqué.

### Lo que ya existe y en lo que este plan se apoya

- **`Moment` / `SettlementSim.raise_moment` / `moment_raised`** — el canal ya
  construido para parar la partida y contar algo (`CIERRE_SLICE.md` §7.2).
  `GameUI`/`BarraSuperior` ya lo escuchan y ya saben pausar el reloj cuando
  el momento trae `options`, y devolverlo cuando se agota la cola
  (`_speed_before_moment`). Los tres momentos nuevos de este plan reutilizan
  el canal entero: no hace falta ni una ventana nueva ni un segundo aviso.
- **`SettlementSim._person_dies`** — el único punto de salida de una persona
  (`QUE_SE_PUEDA_PERDER.md`, tarea 1, ya hecha). Es el sitio exacto donde
  detectar que la banda se ha extinguido, porque ya es quien saca a la
  última persona de `people`.
- **`SettlementSim._advance_local_season`**, en el giro a `PRIMAVERA` — el
  único sitio que ya sabe que ha pasado un año completo (mismo punto que usa
  `Relevo.evaluar_nacimiento`). Es donde se evalúa la victoria.
- **`SettlementSim._process`, línea ~1112**: `if people.is_empty() or
  _terrain == null or time_scale <= 0.0: return`. Esta guarda ya existe —
  para no procesar una banda vacía — y **ya hace todo el trabajo de "parar
  la partida" que pide el punto 2 de la spec**: en cuanto `people` se vacía,
  ningún día vuelve a avanzar, sin tocar `time_scale` a mano.
- **`sim.paintings: Array[Tale]`** (`SettlementSim.gd`) — lo que ya hay
  pintado en la pared, mantenido por `Pinturas.queue_painting`. Es la medida
  directa de "la cueva está pintada"; no hace falta un contador aparte.
- **`Inhabitant.cold_sick_days` / `hunger_sick_days`** (`QUE_SE_PUEDA_PERDER.md`,
  tareas 4-5, ya hechas) — quién está enfermando de verdad, no sólo con hambre
  o frío puntuales. Es la métrica que este plan reutiliza para el indicador
  de riesgo permanente.
- **`BarraSuperior._build_band_gauge` / `_update_band_gauge`** — el patrón ya
  construido de una tira de `Muescas` con tricolor (verde/ocre/hematites)
  para un dato de la banda entera, visible siempre, actualizado con el reloj
  y no por fotograma. Es el molde del indicador nuevo, no algo que reinventar.
- **`DemoMain._levantar_interfaz`**, última línea antes de `_check_discoveries()`:
  `ui.barra.watch_moments(sim)`. Es el punto exacto a partir del cual un
  `raise_moment` SÍ llega a alguien.

### Módulos afectados

- **Módulo nuevo, `scripts/sim/Partida.gd`** (crear). Mismo patrón que
  `Relevo.gd`/`Percances.gd`: `var sim: SettlementSim`, `_init(settlement)`.
  Dueño de:
  - El umbral y la comprobación de "la cueva está pintada"
    (`sim.paintings.size() >= CUEVA_PINTADA_MINIMO`).
  - `evaluar_victoria()` — población > 0 Y cueva pintada, llamada desde
    `_advance_local_season` junto a `evaluar_nacimiento`. Si se cumple,
    marca `sim.desenlace = Desenlace.VICTORIA` y levanta el momento de
    victoria.
  - `declarar_derrota(causa: String)` — llamada desde `_person_dies` cuando
    `people` queda vacío. Marca `sim.desenlace = Desenlace.DERROTA` y levanta
    el momento de derrota con la causa de quien murió último.
  - `momento_inicial()` — construye (no dispara) el momento de apertura, con
    el objetivo doble, la posibilidad de perder y la primera decisión
    (repartir oficios). Lo dispara `SettlementSim.iniciar_partida()`.
  - Los nombres (`Desenlace`, `evaluar_victoria`, `declarar_derrota`,
    `momento_inicial`) son propuesta de este plan, no contrato cerrado —
    revisable en `/tareas`, igual que ya se dejó dicho en
    `QUE_SE_PUEDA_PERDER.md` para `Relevo`.

- **`scripts/sim/SettlementSim.gd`** (modificar):
  - `enum Desenlace { NINGUNO, VICTORIA, DERROTA }` y `var desenlace:
    Desenlace = Desenlace.NINGUNO`.
  - `const CUEVA_PINTADA_MINIMO := <valor provisional>` — sin calibrar, como
    el resto de umbrales de esta época.
  - `var partida: Partida`, instanciado en `setup()` junto al resto de
    módulos (`relevo = Relevo.new(self)`, etc.).
  - `_advance_local_season`: llamada a `partida.evaluar_victoria()` junto a
    `relevo.evaluar_nacimiento()`.
  - `_person_dies`: tras `people.remove_at(idx)`, si `people.is_empty()`,
    llamada a `partida.declarar_derrota(texto)`.
  - Nuevo método `iniciar_partida()`, que delega en
    `partida.momento_inicial()` y lo pasa a `raise_moment` — para que quien
    construye la escena decida CUÁNDO, sin que `Partida` necesite saber nada
    de `DemoMain`.

- **`scripts/banda/Moment.gd`** (modificar): tres valores nuevos en `Kind` —
  `INICIO`, `VICTORIA`, `DERROTA`. Sin opciones en los tres (`options`
  vacío): son hallazgos que se enseñan y no decisiones que tomar, igual que
  `HALLAZGO`/`CUMBRE`.

- **`scripts/ui/BarraSuperior.gd`** (modificar):
  - `_moment_tint`: color para los tres `Kind` nuevos — coherente con la
    paleta de `docs/INTERFAZ.md` §4 (verde de liquen para victoria, hematites
    para derrota, ocre para inicio, mismo criterio que ya usa berrea/relato).
  - Indicador nuevo en `_build_band_gauge`/`_update_band_gauge`: proporción
    de la banda con `cold_sick_days > 0` o `hunger_sick_days > 0`, como
    tercera tira de `Muescas` junto a hambre y cansancio, tricolor y visible
    todo el año — es el "indicador de riesgo permanente" del criterio 4.

- **`scripts/DemoMain.gd`** (modificar): en `_levantar_interfaz()`, justo
  después de `ui.barra.watch_moments(sim)`, llamada a `sim.iniciar_partida()`.
  Es el único punto de todo este plan donde el ORDEN de dos líneas ya
  existentes decide si una feature funciona o se pierde en silencio.

- **`scripts/tests/AnoProbe.gd`** (modificar): imprimir `sim.desenlace` al
  cierre de la sonda, junto a técnicas/utillaje/atascos — instrumentación,
  no lógica nueva.

- **Sonda nueva, `scripts/tests/RitmoProbe.gd`** (crear). Recorre una
  estación (o el año) con el reparto por defecto, escucha `moment_raised`, y
  mide cuántas jornadas seguidas pasan sin ningún momento, por estación. Es
  la que mide el punto 3 de la spec (ritmo) — instrumentación primero,
  igual que la tarea 7 de `QUE_SE_PUEDA_PERDER.md` midió antes de tocar
  calibración. No construye ninguna decisión nueva: eso, si el hueco medido
  lo pide, es trabajo de una tarea aparte una vez haya datos.

- **Pruebas nuevas, `scripts/tests/TestPartida.gd`** (crear), mismo patrón
  que `TestRelevo.gd`: banda de prueba con `paintings`/`people` puestos a
  mano, sin correr una escena completa, comprobando `evaluar_victoria()`,
  `declarar_derrota()` y el contenido de `momento_inicial()`.

### Decisiones de arquitectura

Sólo las que la spec obliga a tomar:

1. **Un enum de tres valores en `SettlementSim`, no una máquina de estados
   nueva.** Igual que `Relevo` no inventó un `State` para enfermar,
   `Partida` no inventa un sistema de fases de partida: `desenlace` es un
   campo, no un nodo ni un autoload.
2. **La derrota no para el reloj a mano: ya lo hace `_process`.** La guarda
   `people.is_empty()` (línea ~1112) es preexistente y ajena a esta spec —
   se reutiliza tal cual como el "cierre" que pide el punto 2, en vez de
   añadir un segundo mecanismo (`time_scale` forzado, botones deshabilitados)
   que haría dos sitios decidiendo si la partida sigue corriendo.
3. **El momento inicial no puede construirse dentro de `setup()`.**
   `sim.setup()` corre en `_levantar_simulacion`, antes de que
   `ui.barra.watch_moments(sim)` conecte la señal en `_levantar_interfaz`; un
   `raise_moment` ahí se perdería sin avisar a nadie. Por eso
   `iniciar_partida()` es un método aparte que `DemoMain` dispara
   explícitamente cuando el orden ya es seguro, en vez de un efecto
   secundario automático de `setup()`.
4. **El indicador de riesgo reutiliza `cold_sick_days`/`hunger_sick_days`**,
   no inventa una métrica de "salud de la banda" aparte — mismo principio
   que ya siguió `QUE_SE_PUEDA_PERDER.md` al derivar la muerte por vejez de
   `age_years` en vez de un campo de salud nuevo.
5. **"La cueva está pintada" se mide sobre `sim.paintings.size()`**, la
   lista que ya lleva la cuenta de lo pintado — no se inventa un segundo
   contador ni un concepto de "cueva completa" distinto del que ya existe.
6. **Victoria y derrota comparten el mismo canal que berrea y percance
   (`Moment`/`raise_moment`)**, no una ventana de "fin de partida" aparte —
   es la misma razón por la que `tell_tale` no abrió un segundo canal para
   los relatos: tener dos sitios donde la partida se para enseña a
   ignorar uno de los dos.

### Orden de dependencias

1. `Partida` + `SettlementSim.desenlace` + los tres `Kind` nuevos de
   `Moment` son la base: todo lo demás cuelga de que existan.
2. El gancho de derrota (`_person_dies` → `declarar_derrota`) no depende de
   nada más de este plan — `people`/`_person_dies` ya son estables desde
   `QUE_SE_PUEDA_PERDER.md`. Puede construirse primero para validar el
   patrón, igual que esa spec hizo con `person.cold` antes de tocar hambre.
3. El gancho de victoria (`_advance_local_season` → `evaluar_victoria`)
   necesita `CUEVA_PINTADA_MINIMO` fijado, aunque sea con un valor
   provisional sin calibrar.
4. El momento inicial es el más delicado de los tres, no por contenido sino
   por orden de arranque en `DemoMain` (decisión de arquitectura #3) —
   conviene construirlo y probarlo en escena real, no sólo con
   `TestPartida.gd`, precisamente porque el riesgo es de fontanería y no de
   lógica.
5. El indicador de riesgo en `BarraSuperior` es independiente de 1-4: sólo
   depende de `cold_sick_days`/`hunger_sick_days`, ya existentes.
6. `RitmoProbe` es independiente de todo lo anterior — es sólo medida.

### Riesgos técnicos conocidos

- **La pérdida silenciosa de señal ya descrita** (decisión #3): cualquier
  código futuro que llame `raise_moment` antes de que la interfaz esté
  montada tiene el mismo problema. No es nuevo de esta spec, pero esta spec
  es la primera que depende de disparar un momento en el arranque mismo de
  la partida, así que es donde el riesgo se vuelve real por primera vez.
- **Victoria repetida.** Si la banda sostiene el umbral de pintura y la
  reserva año tras año, `evaluar_victoria()` se volvería a cumplir cada
  primavera. Si debe sonar una vez o cada año es una decisión de balanceo/UX
  que esta spec no fija — se deja para `/tareas`, con un guard de una línea
  (`if desenlace == Desenlace.VICTORIA: return`) si se decide que sea una
  sola vez.
- **Sondas existentes y los `Kind` nuevos.** `AnoProbe.gd` conecta su propio
  `moment_raised` y sólo actúa sobre `moment.is_decision()`; como `INICIO`,
  `VICTORIA` y `DERROTA` no llevan `options`, la sonda los ignora sin
  cambios — confirmado leyendo `AnoProbe.gd`, no asumido.
- **`CUEVA_PINTADA_MINIMO` es un número inventado sin dato real detrás.**
  Ningún año medido hoy (`ESTADO_DE_LA_SLICE.md` §1) llega a tener más de un
  puñado de relatos pintados, así que el valor de partida es una suposición
  a corregir en cuanto haya una sonda de un año completo corriendo con este
  plan integrado.
- **`SPECS.md` sigue sin cubrir `scripts/sim/`/`scripts/banda/`.** Mismo
  aviso que ya deja `QUE_SE_PUEDA_PERDER.md`: no es deuda que introduzca
  este plan, pero se hereda.

## Tareas

En el orden de dependencias del plan: primero los tres `Kind` de `Moment`,
luego la infraestructura de `Partida`/`desenlace`, luego derrota y victoria
(las dos ganchos baratos que validan el patrón), luego el momento inicial
—el más delicado por orden de arranque, no por lógica—, luego el indicador
de riesgo y el color de los momentos nuevos, y por último la sonda de ritmo
y el cierre de medida con `AnoProbe`.

- [x] **1. Tres `Kind` nuevos en `Moment.gd`.** `INICIO`, `VICTORIA`,
      `DERROTA`, sin opciones — son hallazgos que se enseñan, no decisiones
      que tomar, igual que `HALLAZGO`/`CUMBRE`.
      **Verificable:** prueba unitaria nueva (`TestPartida.gd`) que
      construye un `Moment` de cada `Kind` nuevo y comprueba
      `is_decision() == false` en los tres, porque no llevan `options`.

      > **HECHO (2026-09-11).** Los tres valores añadidos al final del enum
      > `Moment.Kind`. Suite nueva `TestPartida.gd` (registrada en
      > `RunTests.gd`), con el mismo molde de `_banda()`/`_sim()` que ya usa
      > `TestRelevo.gd`. `RunTests.gd` entero: 847 pruebas, 6050
      > comprobaciones, todo en verde (los dos `SCRIPT ERROR` que imprime la
      > tanda —`TestParajes.gd:300` y `TestHunting.gd:228`— son
      > preexistentes, ajenos a esta tarea).

- [x] **2. `SettlementSim.desenlace` y el módulo `Partida.gd`.** Nuevo
      `enum Desenlace { NINGUNO, VICTORIA, DERROTA }` y
      `var desenlace: Desenlace = Desenlace.NINGUNO` en `SettlementSim.gd`,
      más `const CUEVA_PINTADA_MINIMO` (valor provisional, sin calibrar).
      Módulo nuevo `scripts/sim/Partida.gd` (mismo patrón que `Relevo.gd`:
      `var sim: SettlementSim`, `_init`), instanciado en `setup()` como
      `partida`. Sin lógica todavía dentro de `Partida` — sólo la
      infraestructura que usan las tareas 3-5.
      **Verificable:** extender `TestPartida.gd`: crear una banda de
      prueba, comprobar que `sim.partida` no es nulo y que
      `sim.desenlace == Desenlace.NINGUNO` al arrancar.

      > **HECHO (2026-09-11).** Con una corrección sobre el propio plan: no
      > se instancia en `setup()`. Todos los módulos hermanos
      > (`relevo`, `percances`, `pinturas`, `hogar`...) se crean como valor
      > por defecto del campo -`var relevo: Relevo = Relevo.new(self)`-, que
      > en GDScript corre al construirse el objeto, no dentro de `setup()`.
      > `partida` sigue el mismo patrón: `var partida: Partida =
      > Partida.new(self)`, junto a `relevo` en el archivo. `setup()` nunca
      > tocaba a `relevo` y no había motivo para que tocara a `partida`.
      > `CUEVA_PINTADA_MINIMO` provisional en 3. `RunTests.gd` entero: 848
      > pruebas, 6052 comprobaciones, todo en verde.

- [x] **3. Derrota: `Partida.declarar_derrota()` enganchada en
      `_person_dies`.** Cuando `people` queda vacío tras
      `people.remove_at(idx)`, `SettlementSim._person_dies` llama a
      `partida.declarar_derrota(texto)`: marca
      `sim.desenlace = Desenlace.DERROTA` y levanta el momento `DERROTA`
      con la causa de quien murió último. No hace falta tocar `time_scale`
      ni los botones de velocidad — `SettlementSim._process` ya corta la
      simulación en cuanto `people.is_empty()` (decisión de arquitectura
      #2 del plan).
      **Verificable:** extender `TestPartida.gd` — banda de una sola
      persona, forzar su muerte con `_person_dies`, comprobar que
      `sim.desenlace == Desenlace.DERROTA` y que el `Moment` capturado por
      `moment_raised` es de `Kind.DERROTA` y menciona la causa pasada. Es
      el criterio 3 de la spec, a nivel de prueba unitaria — sin sonda de
      escena completa, mismo criterio que ya usó `QUE_SE_PUEDA_PERDER.md`
      para frío/hambre.

      > **HECHO (2026-09-11).** `Partida.declarar_derrota(causa)` construye
      > el momento y lo lanza con `sim.raise_moment`; `_person_dies` la
      > llama justo después de anotar la crónica, sólo si `people.is_empty()`.
      > Guardada además contra doble derrota con
      > `if sim.desenlace != Desenlace.NINGUNO: return`, mismo estilo que
      > `_person_dies` se guarda con `people.find(person)`.
      >
      > **Sorpresa al escribir la prueba:** el primer intento capturaba el
      > `Moment` en una variable suelta reasignada dentro del lambda de
      > `moment_raised.connect(...)`, y salía siempre nula. Un lambda de
      > GDScript captura las locales de fuera **por valor**: reasignar la
      > variable capturada dentro del closure no se ve al salir de él.
      > `TestMishap.gd` ya esquiva esto acumulando en un array
      > (`caught.append(m)`) en vez de reasignar una variable; la prueba se
      > corrigió al mismo patrón. Vale la pena recordarlo para las tareas 4
      > y 5, que necesitan el mismo truco.
      >
      > Suite `Partida`: 4 pruebas, 10 comprobaciones. `RunTests.gd` entero:
      > 850 pruebas, 6057 comprobaciones, todo en verde.

- [x] **4. Victoria: `Partida.evaluar_victoria()` enganchada en
      `_advance_local_season`.** En el giro a `PRIMAVERA`, junto a
      `relevo.evaluar_nacimiento()`: si `population() > 0` Y
      `sim.paintings.size() >= CUEVA_PINTADA_MINIMO`, marca
      `sim.desenlace = Desenlace.VICTORIA` y levanta el momento `VICTORIA`.
      Cumplir sólo una de las dos condiciones no marca nada y la partida
      sigue.
      **Verificable:** extender `TestPartida.gd` con tres casos: banda viva
      con `paintings` por encima del umbral marca victoria (criterio 1);
      banda viva pero sin pinturas suficientes no marca nada y
      `desenlace` sigue en `NINGUNO` (criterio 2); banda con pinturas de
      sobra pero forzada a `people` vacío tampoco marca victoria — la
      llamada ni siquiera debería producirse porque `_person_dies` ya
      disparó `DERROTA` antes, pero se prueba igual para que quede
      constancia de que victoria y derrota son mutuamente excluyentes.

      > **HECHO (2026-09-11).** `Partida.cueva_pintada()` (mide
      > `sim.paintings.size()` contra `CUEVA_PINTADA_MINIMO`) y
      > `evaluar_victoria()`, guardada igual que `declarar_derrota` contra
      > repetirse (`if desenlace != NINGUNO: return`) — así que, tal y como
      > preveía el plan, la victoria no puede reabrirse tras una derrota ni
      > viceversa: son mutuamente excluyentes por construcción, no sólo por
      > coincidencia de que `_process` ya no llamaría a
      > `_advance_local_season` con la banda vacía.
      >
      > Tres pruebas nuevas en `TestPartida.gd`, con un ayudante
      > `_pinturas(cuantas)` que rellena `sim.paintings` con `Tale.new()` a
      > pelo -no hace falta un relato de verdad para contar cuántos hay-:
      > banda viva + cueva pintada gana; banda viva sin llegar al umbral no
      > gana; cueva pintada de sobra sin nadie vivo (`people` vacío a mano,
      > sin pasar por `_person_dies`) tampoco gana. Suite `Partida`: 7
      > pruebas, 15 comprobaciones. `RunTests.gd` entero: 853 pruebas, 6062
      > comprobaciones, todo en verde (el `SCRIPT ERROR` de
      > `Marcha._tick_step`/`TestExploration.gd:1351` que aparece en la
      > tanda es preexistente, ya documentado en la tarea 4 de
      > `QUE_SE_PUEDA_PERDER.md`).

- [x] **5. El momento inicial: `Partida.momento_inicial()` +
      `SettlementSim.iniciar_partida()` + el disparo desde `DemoMain`.**
      `momento_inicial()` construye el `Moment` de `Kind.INICIO` con el
      objetivo doble, la posibilidad de perder y la primera decisión
      (repartir oficios). `iniciar_partida()` en `SettlementSim` lo pasa a
      `raise_moment`. `DemoMain._levantar_interfaz()` llama a
      `sim.iniciar_partida()` justo después de `ui.barra.watch_moments(sim)`
      — nunca antes, porque un `raise_moment` sin nadie escuchando se
      pierde en silencio (decisión de arquitectura #3 del plan).
      **Verificable:** dos comprobaciones, no una sola. (a) Extender
      `TestPartida.gd`: `momento_inicial()` devuelve un `Moment` de
      `Kind.INICIO` cuyo texto contiene referencia al objetivo, a la
      posibilidad de perder y a repartir oficios. (b) Correr la escena real
      (`demo_main.tscn`, como hace `AnoProbe`) y comprobar que el momento
      SÍ llega a `GameUI` en la primera jornada — es la prueba que de
      verdad valida el orden de arranque, que es donde está el riesgo real
      de esta tarea, no en el contenido del texto.

      > **HECHO (2026-09-11).** `Partida.momento_inicial()` sólo construye;
      > `SettlementSim.iniciar_partida()` es quien llama a `raise_moment`, y
      > `DemoMain._levantar_interfaz()` la invoca justo después de
      > `ui.barra.watch_moments(sim)`, con un comentario en el sitio exacto
      > explicando por qué el orden importa.
      >
      > (a) Cuatro comprobaciones nuevas en `TestPartida.gd` sobre
      > `momento_inicial()` en aislado: `Kind.INICIO`, y que el texto
      > menciona "sobrevivir", "cueva pintada", "extingue"/"termina" y
      > "oficios".
      >
      > (b) Sonda nueva `scripts/tests/InicioProbe.gd`, mismo arranque de
      > escena que `AnoProbe.gd` (sitio 56), que lee `ui._moment_card`
      > -sin jugador de por medio, sin resolver nada- y comprueba que hay
      > una tarjeta con el titular exacto del momento inicial. Corrida con
      > ventana real (sin `--headless`), como piden las sondas de captura.
      >
      > **Dos sorpresas al correrla, las dos de fontanería y no de lógica —
      > justo el tipo de riesgo que esta tarea preveía.** Primera: `GameUI`
      > extiende `CanvasLayer`, no `Control` -el primer intento tipaba
      > `var ui: Control = demo.ui` y reventaba con "Trying to assign value
      > of type 'CanvasLayer' to a variable of type 'Control'" antes de
      > llegar a comprobar nada; se corrigió tipando `ui` como `GameUI`
      > directamente, ya que es una clase global. Segunda: ese primer
      > intento fallido no llegó a llamar `quit()`, así que la ventana se
      > quedó abierta de verdad -dos procesos de Godot huérfanos, uno de
      > esa corrida y otro de una reconstrucción de caché de una tarea
      > anterior-, cerrados a mano tras confirmar que no tenían ventana
      > visible en uso. Con el tipo corregido: `OK: el momento inicial
      > llega a la interfaz en la primera jornada, antes de cualquier
      > accion del jugador. dia=1`.
      >
      > `RunTests.gd` entero: 854 pruebas, 6067 comprobaciones, todo en
      > verde.

- [x] **6. Color de los tres momentos nuevos en `BarraSuperior._moment_tint`.**
      `INICIO` en ocre, `VICTORIA` en verde de liquen, `DERROTA` en
      hematites — misma paleta que ya usa `docs/INTERFAZ.md` §4 para
      acento/bien/alarma.
      **Verificable:** prueba unitaria que llama `_moment_tint` con un
      `Moment` de cada uno de los tres `Kind` nuevos y comprueba que
      devuelve el color esperado y que los tres son distintos entre sí.

      > **HECHO (2026-09-11).** Tres ramas nuevas en el `match` de
      > `_moment_tint`. `DERROTA` comparte `UISkin.ALARM` con `PERCANCE`
      > -misma familia de aviso, y es intencional, no un descuido-.
      > `BarraSuperior._init` acepta `ui: GameUI` nulo sin problema porque
      > `_moment_tint` no lo toca, así que la prueba lo instancia suelto
      > (`BarraSuperior.new(null)`) sin montar ninguna interfaz real. Suite
      > `Partida`: 9 pruebas, 24 comprobaciones. `RunTests.gd` entero: 855
      > pruebas, 6071 comprobaciones, todo en verde.

- [x] **7. Indicador de riesgo permanente en `BarraSuperior`.** Nueva tira
      de `Muescas` en `_build_band_gauge`/`_update_band_gauge`, junto a
      hambre y cansancio: proporción de la banda con `cold_sick_days > 0`
      o `hunger_sick_days > 0`, tricolor (verde/ocre/hematites) y visible
      todo el año, no sólo en otoño — es el indicador que pide el criterio
      4 de la spec, y no es el medidor de reserva de invierno de
      `CIERRE_SLICE.md` §7.3 (que ya es permanente pero mide comida, no
      enfermedad).
      **Verificable:** prueba unitaria que fuerza `cold_sick_days`/
      `hunger_sick_days` en varias personas de una banda de prueba, llama
      al cálculo del indicador directamente (sin construir la escena) y
      comprueba que el valor y el color cambian frente a la misma banda
      sana — mismo patrón que ya usa `TestRelevo.gd` para no depender de
      una escena completa.

      > **HECHO (2026-09-11).** Tercera tira de `Muescas` ("Riesgo") junto a
      > hambre y cansancio, alimentada por `BarraSuperior._risk_share`
      > -función `static`, separada a propósito de `_update_band_gauge` para
      > poder probarla sin montar ninguna interfaz-, coloreada con el mismo
      > `_paint_gauge` que ya usan hambre y cansancio (escalando la
      > proporción 0-1 a 0-100 para reutilizar sus mismos cortes de color).
      > Esos cortes -50 %/75 % de la banda enferma- son sin calibrar, como
      > todo lo demás de esta época: puede que sean demasiado altos para un
      > aviso que quiere ser temprano, y es playtest quien lo dirá.
      >
      > Prueba nueva en `TestPartida.gd`: banda sana da 0,0; banda con dos
      > de cuatro marcados (uno de frío, otro de hambre, para cubrir las dos
      > ramas del `or`) da 0,5. Suite `Partida`: 10 pruebas, 27
      > comprobaciones. `RunTests.gd` entero: 856 pruebas, 6074
      > comprobaciones, todo en verde.

- [x] **8. `AnoProbe.gd`: imprimir el desenlace al cierre.** Añadir a la
      salida final (junto a técnicas/utillaje/atascos/crónica) una línea
      con `sim.desenlace` y, si es `VICTORIA` o `DERROTA`, en qué jornada
      ocurrió.
      **Verificable:** correr `AnoProbe.gd` y leer la salida — es
      instrumentación de medida, no hay assert automático, igual que el
      resto de columnas de esta sonda.

      > **HECHO (2026-09-11).** Hacía falta un dato que no existía todavía:
      > `SettlementSim.desenlace_dia` (retrofit pequeño sobre las tareas 3 y
      > 4, con su propia comprobación añadida a las pruebas de esas dos
      > tareas), puesto a `sim.day` en el mismo momento que
      > `declarar_derrota`/`evaluar_victoria` fijan `desenlace`. `AnoProbe`
      > imprime `SettlementSim.Desenlace.keys()[sim.desenlace]` -mismo truco
      > de enum a texto que ya usan `CazaEscalonProbe`/`DespieceProbe`- y,
      > si no es `NINGUNO`, la jornada.
      >
      > Confirmado corriendo `AnoProbe.gd` con `DIAS=5` (ventana real, sin
      > `--headless`, como piden las sondas de captura): en cinco jornadas
      > nadie gana ni pierde, y la línea final dice `desenlace: NINGUNO`,
      > sin jornada — la medida real de un año completo, con victoria o
      > derrota de verdad, es la tarea 10.

- [x] **9. Sonda nueva `RitmoProbe.gd`: medir huecos sin decisión.**
      Recorre una estación (o el año) con el reparto por defecto,
      escucha `moment_raised`, y por cada estación calcula la racha más
      larga de jornadas seguidas sin ningún momento. Es medida, no
      construye ninguna decisión nueva — mismo criterio que la tarea 7 de
      `QUE_SE_PUEDA_PERDER.md` ("medir antes de calibrar").
      **Verificable:** correr `RitmoProbe.gd` y leer la tabla de huecos por
      estación — instrumentación, sin assert automático. Es la medida que
      pide el criterio 5 de la spec.

      > **HECHO (2026-09-11).** Mismo arranque de escena que `AnoProbe.gd`
      > (sitio 56), reparto por defecto, `time_scale = 20`. Cada jornada
      > cerrada se apunta si hubo o no algún `Moment` -de cualquier tipo,
      > no sólo de decisión-, y se lleva una racha que se corta al haber
      > momento o al cambiar de estación -un hueco no se le presta a la
      > estación siguiente-. Guarda además todos los tramos, no sólo el
      > peor, para poder ver si el hueco es uno solo o varios seguidos.
      >
      > Corrida de validación con `DIAS=45` (una sola estación, ventana
      > real): **cero momentos en cuarenta y cinco jornadas** con el
      > reparto por defecto — `Primavera 44 [44]`, un único hueco que cubre
      > casi toda la estación. No estaba calibrado que fuera a salir tan
      > extremo; es la primera confirmación real, con datos y no con
      > sospecha, de que el punto 3 de la spec tiene razón. La medida
      > formal de las cuatro estaciones (año completo) es la tarea 10.

- [x] **10. Cierre: correr `AnoProbe`/`RitmoProbe` con todo integrado y
      anotar el resultado.** Con las tareas 1-9 hechas, correr un año
      completo y comprobar de verdad los criterios 1, 2, 5 y 6 con datos
      reales de partida, no sólo con las pruebas unitarias de
      `TestPartida.gd`. Si `CUEVA_PINTADA_MINIMO` resulta inalcanzable o
      trivial con el reparto por defecto, se anota aquí el valor medido y
      se corrige la constante — no hace falta volver a `/plan-tarea` para
      eso, es el mismo tipo de ajuste sin calibrar que el resto de números
      de esta época. Si `RitmoProbe` encuentra huecos largos en alguna
      estación, se anota cuál y se deja como tarea de contenido aparte,
      fuera de esta lista — igual que hizo la tarea 7 de
      `QUE_SE_PUEDA_PERDER.md` con el invierno indirecto.
      **Verificable:** la propia tabla de `AnoProbe` extendida (tarea 8) y
      la de `RitmoProbe` (tarea 9), leídas juntas.

      > **HECHO (2026-09-11), con alcance recortado a propósito.** Cuatro
      > agentes coincidieron trabajando el mismo árbol el mismo día
      > (QUE_FALTA_PARA_JUGARLO, QUE_SE_PUEDA_PERDER, SECADERO_Y_RIO,
      > LO_MISMO_MAS_DEPRISA), y correr un año completo por separado para
      > cada uno —a la velocidad tope acordada, `time_scale = 5`, tras los
      > cambios de rendimiento del día— salía por más de una hora cada vez.
      > Se coordinó UNA corrida compartida (`TironAnualProbe.gd`, de
      > `history-of-man-0e`) con el reparto por defecto, y este cierre se
      > apoya en ella en vez de lanzar otra redundante.
      >
      > **Criterios 1, 2 y 6 — con dato real de un año completo.** Corrida
      > compartida, `SEMILLA=123`, `time_scale=5`, 180 jornadas, reparto por
      > defecto: `desenlace: NINGUNO (0 relatos pintados de 3 para ganar)`.
      > La banda cerró el año viva y no ganó, porque no pintó nada — es
      > exactamente el criterio 2 (sobrevivir solo no basta) confirmado con
      > partida real, no sólo con la prueba unitaria de la tarea 4. No hay
      > en esta corrida un caso positivo de victoria (población viva Y
      > cueva pintada a la vez): con el reparto por defecto, en un año,
      > nadie llegó a pintar nada. Eso es un dato de calibración, no de
      > mecanismo: **`CUEVA_PINTADA_MINIMO := 3` puede que sea alto, o puede
      > que el problema sea el mismo que ya documenta
      > `ESTADO_DE_LA_SLICE.md` §2 —la banda por defecto no llega a tener
      > sobrante para pintar—**, y separar las dos causas pide más de una
      > semilla, que aquí no había presupuesto para correr. Se deja
      > anotado, no se toca la constante a ciegas con un solo dato.
      >
      > **Criterio 5 — medido sólo en primavera, no las cuatro estaciones.**
      > La corrida compartida no llevaba instrumentación de huecos entre
      > `Moment` (mide tirones de fotograma, no cadencia de decisiones), así
      > que no sirve para este criterio. Lancé `RitmoProbe.gd` para el año
      > completo por mi cuenta y el usuario la paró a los pocos minutos:
      > con el tope de `time_scale=5` ya recién adoptado, una corrida de
      > 180 días son más de una hora, y ya había otras tres corriendo o
      > recién corridas el mismo día — exactamente el coste que este cierre
      > tenía que evitar, no añadir. Queda medido, de la tarea 9, sólo
      > **Primavera: cero momentos en cuarenta y cinco jornadas, un hueco
      > único de 44 días** con el reparto por defecto. Verano, Otoño e
      > Invierno quedan sin medir. No es una medida completa del criterio 5
      > y se deja dicho así, en vez de inflar una sola estación a "las
      > cuatro estaciones" — si hace falta la medida completa, es una
      > corrida aparte, corta si se limita a `DIAS=45` por estación en vez
      > de repetir el año entero, y con presupuesto explícito antes de
      > lanzarla.
      >
      > **Lo que se aprendió de fontanería en esta tarea, más allá de la
      > propia spec:** el bug de `on_pick` sin pasar por
      > `BarraSuperior.elegir()`/`seguir()` —que deja `time_scale` en cero
      > para siempre en cuanto aparece la primera decisión del año— estaba
      > en `AnoProbe.gd` desde antes de esta spec, y lo mismo lo encontró
      > por su cuenta `history-of-man-0e` en `TironAnualProbe.gd`. Lo
      > corregí en `AnoProbe.gd` y `RitmoProbe.gd` con el mismo patrón
      > (`momento_en_pantalla()` + `elegir()`, revisado cada fotograma, no
      > sólo al `raise`). De paso, a petición de `history-of-man-4b`, gané
      > en `AnoProbe.gd` una tabla "RIBERA POR ESTACIÓN" (raciones por
      > persona-pescador-día y `Paraje` distintos trabajados de verdad, vía
      > `sim._paraje_at` sobre quien está en `Job.RIBERA` y
      > `State.TRABAJANDO`) y soporte `BANDA=r,c,p` para forzar un reparto
      > concreto —mismo patrón que `BandaProbe.gd`—; el primer intento de
      > esa tabla muestreaba una vez al día en el cambio de jornada, que es
      > cuando nadie está `TRABAJANDO`, y daba cero parajes con miles de
      > raciones de pescado entrando. Corregido a muestreo por fotograma.
      > Ninguno de los dos arreglos lo pedía esta spec, pero los dos hacían
      > falta para que la corrida compartida —y la mía propia— dieran
      > algo más que un reloj colgado.
