> **ARCHIVADO (2026-09-12).** Este documento ya no se edita. La documentación
> se reorganizó para que lo único específico fueran las fichas de época, y
> **pendiente**: sus dos puntos y el cuelgue que los bloquea están en **[ROADMAP.md](../ROADMAP.md)**, sección «En curso».
>
> Se conserva entero porque guarda **lo que no cabe en un documento permanente**:
> qué se probó, qué salió, qué premisa se cayó a mitad y por qué se decidió lo
> que se decidió. Nada de lo que sigue se ha tocado — incluidas las cosas que
> hoy ya no son verdad, que se reconocen porque el documento permanente dice
> otra cosa y **gana el permanente**.

---

# El secadero y el río

Nace de [ESTADO_DE_LA_SLICE.md](../ESTADO.md) §5, bloque "Segundo:
que la carne importe", puntos 5 y 6. El punto 4 de ese mismo bloque —hacer la
avellana estacional y con agotamiento del avellanar— queda fuera: revisando el
código, las dos cosas ya están hechas (`Tajo._gathering_yields` solo da fruto
seco en otoño, y la propia ESTADO_DE_LA_SLICE §5.6 admite que "la recolección
está bien: baja hasta el 63 % en otoño y se recupera al 85 %"). Lo que queda de
ese punto es que la avellana da demasiada caloría por puñado frente a la caza,
y eso es un número de balanceo, no una mecánica: no encaja como criterio de
una spec.

## Motivación

`BandaProbe` mide un año con 4 recolectores, 3 cazadores y 2 pescadores: la
recolección da el 93 % de las raciones del año y la caza el 1 %. Parte de por
qué la caza no compensa ya tiene su propio punto en el roadmap (la cadena de
prerrequisitos de `AZAGAYA`, "ya se calibró" según la propia
ESTADO_DE_LA_SLICE); esta spec no la toca. Lo que sí toca son dos mecanismos
que hoy trabajan en contra de que la carne y el pescado lleguen al invierno:

**El secadero no distingue estaciones.** `Hogar._smoke_the_larder` ya es un
cuello de botella de verdad —24 raciones por jornada con un bastidor y quien lo
atienda, el mismo número todo el año—, pero no le importa si es otoño o
primavera. La berrea multiplica la caza ×1,70 y ya hay una decisión de jugador
en torno a ella (`Moment.Kind.BERREA`, CIERRE_SLICE §7.2), pero el secadero no
participa de esa temporada: cura exactamente lo mismo un día de otoño que un
día de primavera. La berrea decide cuánta carne entra; nada decide todavía
cuánta de esa carne se puede guardar.

**La pesca se agotaba y no había a dónde ir — hasta hace tres días.** Medido en
su momento con dos pescadores en un año: el tajo de ribera bajaba al 75 % en 8
jornadas, al 50 % en 15, al 25 % en 24 y al 1 % en 32, y se quedaba ahí el
resto del año con el resto del río al 93,9 % sin tocar. La razón era concreta:
`Tajo._rank_known_spots` solo ofrece a la banda celdas con
`familiarity_at(...) >= Tajo.SE_PUEDE_TRABAJAR` (0,35), y un pescador solo
aprendía lo que tenía alrededor de donde YA estaba pescando.

**Se intentó arreglar, y el resultado es a medias — no lo hizo esta spec.**
`Barbecho.gd` (commit `8fd75cd`, "la banda deja de pescar en un río muerto") y
`Tanteo.gd` (`aa5cc76`) se escribieron el 8 de septiembre para exactamente este
problema: un paraje por debajo del 20 % se deja en barbecho, y si a un oficio
no le queda ningún sitio conocido sin esquilmar, la cuadrilla sale a tantear el
margen del río en vez de quedarse quieta. Un bug de `Vector3` que medía altura
en vez de distancia (`e4aece7`, 10 de septiembre) tapaba parte del efecto.

Una primera medida (`BandaProbe`, mismo reparto, 45 jornadas —solo
primavera—) parecía confirmarlo: la ribera daba 36,30 raciones por persona y
día, el 67 % de lo que comía la banda. Pero una medida más larga (`AnoProbe`
con `BANDA=4,3,2`, 90 jornadas —primavera y verano completos—) lo desmiente:

| estación | raciones | jornadas-persona | por día | parajes |
|---|---|---|---|---|
| Primavera | 3.152 | 90 | 35,03 | 5 |
| Verano | 149 | 50 | **2,98** | 5 |

La producción cae un **91,5 %** de primavera a verano **sin que el número de
parajes trabajados cambie** — los mismos 5 sitios las dos estaciones. El
`seasonal_factor` de PESCA (1,85 en primavera, 1,15 en verano) explica como
mucho un -38 %, no un -91,5 %. Esto es el patrón "clavado en un sitio
agotado" que describe ESTADO_DE_LA_SLICE §5.6, no la solución: `Barbecho`
puede estar detectando bien que no queda sitio, pero `Tanteo` no está
consiguiendo que la banda se instale en uno nuevo de verdad — la sospecha,
sin confirmar, es que la cuadrilla pasa el tiempo tanteando (buscando) en vez
de trabajando, que es justo lo que medía `SinSitioProbe.gd` antes de
`e4aece7` (82-97 % del día en RECONOCIENDO, cero en TRABAJANDO). El punto 2
de esta spec parte de este hallazgo, no del optimismo de la primera medida.

## Alcance

### 1. El otoño como pico de curado, no como ventana única

El secadero pasa a curar más por jornada en otoño que en cualquier otra
estación, con la misma gente atendiéndolo. No se trata de que llegue más carne
fresca en otoño —eso ya lo hace la berrea— sino de que el propio proceso de
ahumado rinda más ese trimestre: es la estación en que se prepara la reserva
del invierno, y hoy nada en el secadero lo distingue de un día cualquiera de
mayo.

Sigue curando el resto del año — la caza de invierno por trasterminancia
(×1,35) también tiene que poder guardarse, aunque sea más despacio. No se
cierra ninguna estación; se hace notar cuál es la buena.

### 2. La pesca sin sitio conocido — alcance pendiente de diagnóstico

Esta parte de la spec ha cambiado de forma dos veces mientras se medía, y se
deja constancia de las tres lecturas en vez de borrar las anteriores, porque
cada una fue la mejor lectura del dato que había en su momento:

1. **Primera medida (45 jornadas, solo primavera):** parecía que
   `Barbecho`+`Tanteo` ya resolvían el problema — 36,30 raciones/persona/día,
   67 % de la comida de la banda.
2. **Segunda medida (90 jornadas, primavera+verano):** la producción se
   hundía un 91,5 % de una estación a la siguiente sin que el número de
   parajes trabajados cambiara — el patrón "clavado" que se creía resuelto.
3. **Tercera medida (misma corrida, extendida con rastreo de estados):**
   antes de poder ver SI los pescadores pasan el tiempo reconociendo en vez
   de trabajando —que habría confirmado o descartado la lectura 2—, **la
   simulación entró en un bucle infinito** justo en el cruce a otoño y hubo
   que matarla a mano. Ver "Riesgos técnicos conocidos" del plan técnico.

Con esto, el alcance real de este punto no se puede fijar todavía: puede ser
"ya funciona, hace falta una sonda de año completo que lo confirme sin
tropezar con el cuelgue", puede ser "el patrón clavado es real y hay que
arreglar `Tanteo`", o puede ser "el cuelgue es el problema de verdad y la
pesca es un síntoma menor al lado de eso". Antes de escribir más código para
este punto hace falta **diagnosticar el cuelgue** — no es opcional, porque
mientras exista no se puede correr ninguna medida de año completo con este
reparto para saber nada más.

## Fuera de alcance

- **Bajar el rendimiento calórico de la avellana o de cualquier fruto seco.**
  Es el punto 4 de ESTADO_DE_LA_SLICE §5, y tras revisar el código no queda
  nada de él salvo un número de balanceo (ver arriba). No es esta spec.
- **Restringir el curado a que solo pueda hacerse en otoño.** Se decidió
  explícitamente en contra: la caza de invierno también necesita poder
  conservarse, aunque sea menos que la de otoño.
- **La curva de reposición de `ResourceField.regrow`** (de 1 % a 50 % de
  carga en unas 275 jornadas si se le deja en paz). Es un hallazgo aparte de
  la propia ESTADO_DE_LA_SLICE §5.6, y es independiente de si hay alternativa
  o no: un sitio que tarda en recuperarse no es un problema si hay otro al que
  ir mientras tanto, que es justo lo que pide el punto 2 de esta spec.
- **Limpiar `ResourceField.deplete_at`** (código muerto, solo lo llaman dos
  pruebas). Es housekeeping aparte, no bloquea esta feature.
- **Tocar `Job.EXPLORACION` como oficio**, su interfaz o cómo se le asigna
  gente. Sigue existiendo exactamente igual; lo que cambia es que la pesca
  deja de depender EN EXCLUSIVA de que alguien lo tenga asignado.
- **Recalibrar la caza mayor** (la cadena de tecnologías hasta `AZAGAYA`). Ya
  tiene su propio punto en el roadmap y la propia ESTADO_DE_LA_SLICE dice que
  "ya se calibró".
- **Cualquier número concreto**: cuánto más cura el secadero en otoño, a
  partir de qué distancia o familiaridad se considera "alternativa" para la
  pesca. Se deja para balanceo con playtest, igual que el resto de números de
  esta época.

## Criterios de aceptación

1. **El secadero rinde más en otoño con la misma gente.** Una sonda que fuerce
   carne y pescado frescos de sobra en las cuatro estaciones, con el mismo
   número de personas en `Job.HOGAR` atendiendo el secadero, mide más
   raciones curadas por jornada en otoño que en cualquiera de las otras tres
   — hoy `Hogar.DRY_PER_DAY` da exactamente 24 en las cuatro, sin excepción.

2. **La diferencia llega a la despensa.** En una sonda de año completo (tipo
   `AnoProbe`/`BandaProbe`), la proporción de lo cazado y pescado en otoño que
   termina como `CARNE_SECA`/`PESCADO_SECO` es mayor que la misma proporción
   para lo cazado y pescado en cualquier otra estación.

3. **Antes que nada: una corrida con el reparto 4,3,2 completa un año sin
   colgarse.** Es el criterio que bloquea a todos los demás de este punto —
   ver "Riesgos técnicos conocidos" del plan técnico. Sin esto no hay sonda
   de año completo posible, y es lo primero que hay que resolver.

3b. **Con eso resuelto, una sonda de año completo (las cuatro estaciones)
   confirma que la pesca no se queda clavada en un sitio muerto.** Mismo
   reparto que ya documenta ESTADO_DE_LA_SLICE §5.6 —dos pescadores, sin
   exploradores—, midiendo la producción de pesca por persona y día
   estación a estación. La segunda medida de esta spec (90 jornadas) ya
   apunta a que esto puede FALLAR —91,5 % de caída de primavera a verano sin
   nuevos parajes—, así que este criterio no se da por supuesto: si en las
   cuatro estaciones se sostiene un rendimiento razonable, el punto se
   cierra; si colapsa, la sonda dice en cuál estación y cuánto, y hace falta
   volver a `/spec` para lo que encuentre.

4. **La misma sonda cuenta parajes de pesca distintos trabajados en el año**
   (no solo bautizados), para dejar constancia de que la banda se mueve de
   verdad y no vive todo el año de una única racha de suerte en el punto de
   partida.

5. **La sonda queda en el repositorio como prueba de regresión.** El
   mecanismo (`Barbecho`+`Tanteo`) es reciente y sigue recibiendo ajustes
   (los commits de "batidor" de estos últimos días); una sonda de año
   completo que se pueda volver a correr es lo que evita que un futuro ajuste
   de pathfinding rompa esto en silencio.

## Plan técnico

### Aviso previo sobre `SPECS.md`

> **Resuelto (2026-09-12).** `SPECS.md` se reescribió contra el código: §4.4 ya
> documenta `SettlementSim` como fachada y sus subsistemas, `Hogar` y `Tajo`
> incluidos. El aviso se deja por lo que cuenta de cómo se trabajó.

Igual que ya advierte [QUE_SE_PUEDA_PERDER.md](QUE_SE_PUEDA_PERDER.md), `SPECS.md`
§3 documenta la arquitectura del prototipo original (`DemoMain`, `Chunk`,
`Architecto`, `TerrainGenerator`) y no menciona `SettlementSim`, `Hogar`,
`Barbecho`, `Tanteo` ni `Tajo`, que es donde vive esta feature de verdad. Lo
que sí aplican y se respetan son las convenciones de `SPECS.md` §4 (tipado
estático, comentarios `##`) y el patrón ya establecido de un módulo por tema
cerrado —`Hogar.gd` para el fuego y el secadero, `Barbecho`/`Tanteo` para
"sin sitio conocido"—, que esta feature sigue sin inventar uno nuevo.

### Módulos afectados

- **`scripts/sim/SettlementSim.gd`** (modificar). Ya centraliza en un bloque
  ("Lo que cuesta tener fuego") los números del hogar y el secadero —
  `HEARTH_WINTER_FACTOR := 1.8`, `YESQUERO_BONUS := 1.8`,
  `AHUMADO_BONUS := 1.6`—. Gana una constante nueva junto a ellas para el
  pico de otoño del secadero (nombre a decidir en `/tareas`, p. ej.
  `SECADERO_OTONO_FACTOR`), siguiendo el mismo patrón: un número con su
  comentario `##` explicando el porqué histórico, sin lógica.

- **`scripts/sim/Hogar.gd`** (modificar). `_smoke_the_larder()`
  (línea ~414) ya calcula `supervision` a partir de `_hearth_hands()` y se
  la pasa a `_dry_meat(fraction, skill)`, que multiplica
  `DRY_PER_DAY * fraction * skill` para obtener `capacity`
  (línea ~368). El pico de otoño entra aquí: un factor por `GameState.season`
  que multiplique esa `capacity` (o el `skill` con el que se llama a
  `_dry_meat` desde `_smoke_the_larder`), con la misma forma que ya usa
  `ResourceField.seasonal_factor` — un `match` sobre `Subsistence.Season`
  con su comentario justificando el porqué, aunque esta vez no pueda
  reutilizarse `ResourceField.seasonal_factor` directamente porque está
  indexado por `Subsistence.Activity` y curar no es una de las cinco
  actividades del campo de recursos.

- **`scripts/tests/TestCampProjects.gd` / `TestDespensa.gd`** (modificar).
  Ya prueban `_smoke_the_larder`/`_dry_meat` con carne y pescado frescos
  forzados a mano (ver `TestCampProjects.gd:20-101`,
  `TestDespensa.gd:20-106`); ganan casos que fuercen `GameState.season` a
  las cuatro estaciones y comparen cuánto se cura en cada una — es la prueba
  unitaria del criterio de aceptación 1, más barata y más rápida que una
  sonda de escena completa.

- **Sonda nueva para el criterio 1** (crear, nombre a decidir en `/tareas`,
  p. ej. `SecaderoProbe.gd`), solo si las pruebas unitarias de arriba no
  bastan para ver el efecto en conjunto con `AHUMADO_BONUS` y con gente real
  del hogar. Mismo patrón que `CaceriaProbe.gd`: forzar carne/pescado frescos
  de sobra y gente en `Job.HOGAR`, y comparar `smoked_today` entre
  estaciones.

- **`scripts/tests/AnoProbe.gd` o `BandaProbe.gd`** (modificar). Para el
  criterio 2 (la proporción curada de otoño es mayor que la de cualquier
  otra estación) hace falta desglosar `_por_estacion` por material
  fresco-vs-curado y no solo por raciones totales, que es lo que hace hoy
  `BandaProbe._desglose`. Ampliar `_por_estacion` para separar
  `CARNE`/`PESCADO` de `CARNE_SECA`/`PESCADO_SECO` es una extensión directa
  de una estructura que ya existe, no una nueva.

- **Sonda nueva para el criterio 2, 3, 4 y 5** (crear, nombre a decidir en
  `/tareas`, p. ej. `RioAnoProbe.gd`). Mismo patrón que `BandaProbe.gd`
  —reutiliza literalmente `_arrancar()`/`_repartir()`— pero corriendo **un
  año completo** (`DIAS=360`, no 45) con el reparto `4,3,2` que ya usan las
  sondas del proyecto, desglosando por estación: raciones de ribera por
  persona y día, proporción curada, y cuántos `Paraje` de pesca distintos se
  han trabajado de verdad (contar cada vez que
  `sim.parajes.chosen_for(Subsistence.Activity.PESCA)` cambie de `id()`, o
  llevar un `Dictionary` como el que ya usaba el borrador descartado de esta
  misma investigación). Es la sonda que el criterio 5 pide dejar en el
  repositorio como prueba de regresión.

### Decisiones de arquitectura

Solo las que la spec obliga a tomar:

1. **El pico de otoño es un factor sobre la capacidad de curado, no una
   ventana que se abre y se cierra.** Se decidió explícitamente así con el
   usuario al escribir la spec: el secadero sigue funcionando las cuatro
   estaciones: cambia CUÁNTO cura, nunca SI cura.
2. **El factor vive junto a los demás números del fuego en
   `SettlementSim.gd`**, no en `Hogar.gd` ni en `ResourceField.gd` — sigue el
   patrón ya establecido (`HEARTH_WINTER_FACTOR`, `AHUMADO_BONUS`,
   `YESQUERO_BONUS` viven todos ahí) en vez de abrir un sitio nuevo para un
   solo número.
3. **El punto 2 de esta spec no toca código de simulación.** Es
   deliberado: `Barbecho`/`Tanteo` ya resuelven el problema medido, y
   escribir un mecanismo alternativo sería exactamente la "regla escrita en
   varios sitios" que este flujo de specs existe para evitar. El único
   entregable de ese punto es una sonda de medida.

### Orden de dependencias

1. El factor de temporada en `Hogar._dry_meat`/`_smoke_the_larder` (punto 1)
   es independiente del punto 2 — pueden construirse en cualquier orden o en
   paralelo.
2. Dentro del punto 1: la constante en `SettlementSim.gd` tiene que existir
   antes de que `Hogar.gd` la use, y las pruebas unitarias de
   `TestCampProjects.gd`/`TestDespensa.gd` son más baratas de escribir y de
   correr que la sonda de escena — conviene validar el factor con ellas
   antes de tocar `AnoProbe`/`BandaProbe` o construir una sonda nueva.
3. Dentro del punto 2: la sonda de año completo (`RioAnoProbe.gd` o el
   nombre que se decida) no depende de nada de esta spec — puede escribirse
   y correrse el primer día. Su resultado decide si el punto se cierra tal
   cual o si hace falta abrir una spec nueva para lo que encuentre.

### Riesgos técnicos conocidos

- **Un cuelgue confirmado, no solo sospechado, en el camino de la pesca sin
  sitio.** Hubo dos episodios al medir para esta spec, con el mismo reparto
  forzado (4,3,2) y el mismo emplazamiento (sitio 56):
  - Un borrador de sonda se cerró con código de salida 1 y sin ningún
    mensaje de error, en dos de tres ejecuciones, siempre entre los días 38
    y 41 —justo después de que `Barbecho.sin_sitio` empezara a dar positivo
    para pesca—.
  - `AnoProbe.gd` con `BANDA=4,3,2` y la instrumentación de esta spec (ver
    más abajo) **entró en un bucle infinito de verdad** en el cruce
    verano→otoño (día ~89 de 90): 17 minutos sin escribir una sola línea de
    log mientras el proceso consumía prácticamente un núcleo entero de CPU
    sin interrupción (3.101 s de CPU en 3.120 s de reloj) — no una caída,
    un cuelgue que hubo que matar a mano. Se perdieron las tablas finales de
    esa corrida (se imprimen solo al salir del bucle principal, que nunca
    llegó a completarse), así que **no hay todavía datos de estados
    (RECONOCIENDO vs TRABAJANDO) para verano ni para el cruce a otoño**.

  `BandaProbe.gd` sin modificar, con reparto distinto pero incluso distinta
  semilla, no se ha colgado en 45 días.

  **Reproducido después con semilla fija** (`SEMILLA=42 DIAS=95 BANDA=4,3,2`,
  con un vigilante que mide el log cada 15 s y mata el proceso a los 5
  minutos sin crecer): se cuelga otra vez, y esta vez hay un dato que
  reorienta la sospecha. El último checkpoint impreso antes del cuelgue (día
  76, Verano) muestra **despensa = 0 y hambre media de la banda = 100** —el
  máximo posible— con los 15 todavía vivos en ese instante. El proceso siguió
  corriendo unos 10 días más de calendario (visible por el contador de "año
  solar" del clima, que sigue avanzando) y se congeló del todo poco después,
  sin que ninguna tabla llegara a imprimirse.

  Con casi toda la banda en hambre máxima sostenida durante días, el sistema
  de enfermar/morir de hambre (`Relevo.gd`, de
  [QUE_SE_PUEDA_PERDER.md](QUE_SE_PUEDA_PERDER.md), terminado e integrado
  esta misma semana) tiene que estar disparándose sin parar en ese tramo.
  **La sospecha se traslada de `Barbecho`/`Tanteo` a la posibilidad de un
  bucle en el camino de muertes masivas simultáneas** —por ejemplo, recorrer
  `sim.people` mientras `_person_dies()` lo modifica a mitad de iteración—,
  aunque no se ha leído el código de `Relevo.gd` todavía para confirmarlo:
  es una hipótesis a partir del síntoma, no un diagnóstico. Tampoco se
  descarta que el reparto forzado 4,3,2 en sí sea insosteniblemente pobre en
  comida bajo el código actual —eso explicaría la hambruna, aparte de
  explicar o no el cuelgue—, lo cual sería en sí mismo un hallazgo de
  balanceo relevante para el roadmap general, no solo para esta spec.

  **Este hallazgo cambia la prioridad del punto 2**: antes de escribir la
  sonda de año completo definitiva, hace falta diagnosticar el cuelgue en
  sí —un bucle infinito de verdad es un bug de estabilidad, no un problema
  de calibración de subsistencia— y probablemente merece su propia spec o
  al menos su propia tarea de diagnóstico, posiblemente dentro del ámbito de
  `QUE_SE_PUEDA_PERDER.md` en vez de éste, antes de que el punto 2 de ésta se
  dé por verificable de ninguna manera.

  **Estado a 12-sep-2026: el bug queda fuera de esta spec, con dueño
  asignado.** La sesión que construyó `Relevo.gd` (`QUE_SE_PUEDA_PERDER.md`)
  ya cerró; el diagnóstico se entregó a la sesión que trabaja
  `LO_MISMO_MAS_DEPRISA.md` (rendimiento), a la espera de que se le encargue
  formalmente. **El punto 2 de esta spec queda bloqueado, no cancelado**:
  no se puede escribir ni correr la sonda de año completo del criterio 3
  mientras el juego se cuelgue en vez de dejar perder la partida bajo hambre
  severa. Retomar el punto 2 depende de que ese bug se arregle primero, en
  otra spec o tarea.
- **El mecanismo que resuelve el punto 2 es de esta misma semana y sigue en
  movimiento.** `Barbecho`/`Tanteo` (8-10 de septiembre) y los tres commits
  de "batidor" posteriores (hasta el 11) tocan la misma área de pathfinding
  de exploración/tanteo. Un ajuste futuro en esa área puede volver a romper
  lo que hoy funciona sin que nadie lo note si no queda una sonda corriendo
  con regularidad — de ahí el criterio de aceptación 5.
- **`_por_estacion` en `BandaProbe.gd` no distingue material fresco de
  curado hoy.** Extenderlo (para el criterio 2) es sencillo pero toca una
  sonda que ya usan otras medidas de referencia de este documento y de
  `ESTADO_DE_LA_SLICE.md`; conviene no romper su formato de salida actual al
  añadir columnas.
- **`SPECS.md` sigue sin cubrir `scripts/sim/`.** Ver el aviso al principio
  de este plan — no se corrige aquí, pero cualquier plan futuro que toque
  `Hogar.gd`/`SettlementSim.gd` va a tropezar con el mismo hueco.
