> **ARCHIVADO (2026-09-12).** Este documento ya no se edita. La documentación
> se reorganizó para que lo único específico fueran las fichas de época, y
> **terminada**: sus 17 tareas están hechas. Lo que quedó fuera sigue en **[ROADMAP.md](../ROADMAP.md)**.
>
> Se conserva entero porque guarda **lo que no cabe en un documento permanente**:
> qué se probó, qué salió, qué premisa se cayó a mitad y por qué se decidió lo
> que se decidió. Nada de lo que sigue se ha tocado — incluidas las cosas que
> hoy ya no son verdad, que se reconocen porque el documento permanente dice
> otra cosa y **gana el permanente**.

---

# Abrigo y trueque

Cierra el bloque "Tercero" de [ESTADO_DE_LA_SLICE.md](../ESTADO.md)
§5: lo que `SLICE_PALEOLITICO.md` pidió como necesidad del grupo y como
recurso del mapa, y que el código de hoy tiene a medio construir —las piezas
puestas, sin conectar.

De los cuatro puntos que listaba ese bloque, uno se cae de esta spec: **el
conchero visible ya está hecho**. `Desechos` apunta el litraje de cada
ración comida y `Conchero` lo pinta junto al abrigo —mancha, loma y cáscara
suelta— a partir de 400 litros, coloreado según de qué ha vivido la banda.
Está instanciado en la escena real, no en una prueba suelta. El propio
`ESTADO_DE_LA_SLICE.md` §4 ya lo da por bueno; su §5.9 lo repite como
pendiente por no haberse actualizado a la vez. Esta spec no vuelve sobre
ello — sólo dice que la entrada de §5.9 debería borrarse.

Quedan tres, y los tres comparten motivo: `SLICE_PALEOLITICO.md` §3
("Necesidades del grupo") y §4 ("Recursos") los exige explícitamente, y hoy
ninguno tiene consecuencia en la partida.

---

## 1. Vestido como necesidad de invierno

### Por qué

`Materia.Kind.PIEL`, la especialidad `PELETERIA` y la herramienta `AGUJA` ya
existen. La propia ficha de la técnica de la aguja lo dice con todas las
letras: *"ropa cosida y ajustada en vez de piel echada por encima. Es lo que
permite trabajar fuera en pleno invierno."* Es una promesa que el código no
cumple: `Inhabitant.cold` sólo responde al hogar (si está encendido) y a la
estación. Aprender la aguja, curtir pieles y tener a alguien en `PELETERIA`
no cambia nada en cómo pasa frío la banda. La necesidad que el diseño pide
—que vestirse sea distinto de no vestirse— no existe.

### Criterios de aceptación

1. Con `PIEL` curtida y alguien que ha practicado `PELETERIA`/`AGUJA`
   disponible, la banda puede producir vestido de invierno de verdad —no un
   número interno, sino un bien que se gasta o se queda corto si la banda
   crece, igual que ya pasa con el resto de utillaje. Medible: una sonda que
   deje a la banda fabricar durante N jornadas debe mostrar vestido
   acumulándose a un ritmo distinto de cero.
2. El frío medido en `Inhabitant.cold` a lo largo de un invierno debe subir
   de forma medible más despacio (o partir de un techo más bajo) en una
   banda con vestido suficiente que en una banda idéntica sin él. Una sonda
   al estilo de `TestRelevo`/`HogarProbe`, comparando ambos casos sobre el
   mismo número de jornadas de invierno, tiene que poder mostrar la
   diferencia.
3. Esa diferencia tiene que llegar hasta la consecuencia que ya existe: con
   `cold_sick_days` y la muerte por frío ya implementadas (`Relevo.gd`), una
   banda sin vestido en pleno invierno debe acumular enfermedad de frío de
   forma medible más rápido que una banda equivalente con vestido, sobre el
   mismo tramo de jornadas.
4. Por debajo de la temporada fría, o con vestido de sobra, no debe
   observarse penalización — el mecanismo no puede inventar una necesidad
   donde antes no la había; sólo conectar la que el diseño ya declaró.

Las cantidades exactas —litros de piel por prenda, cuánto reduce el vestido
la subida de `cold`, cuánto dura una prenda— se dejan para playtest, como el
resto del proyecto.

---

## 2. Plazas de abrigo por capacidad

### Por qué

La población ya no es una constante: nacimientos y muertes existen
(`Relevo.gd`, `Partida.gd`), así que una banda puede crecer de verdad de un
año a otro. Hoy nada limita cuánta gente cabe en un abrigo concreto:
`shelter_litres` mide volumen de ALMACÉN, no de gente, y no hay ninguna
consecuencia si la banda crece más allá de lo que el abrigo puede sostener.
El diseño lo pide sin rodeos: *"crecer más obliga a levantar paravientos o a
partir la banda"* (`ESTADO_DE_LA_SLICE.md` §5.8). Hoy no obliga a nada.

### Criterios de aceptación

1. Cada abrigo tiene una capacidad de gente definida y consultable, y esa
   capacidad sale de lo que hay construido, no de un número fijo de
   partida — el mismo principio que ya se aplicó a la capacidad de comida
   (`Storehouse.capacidad_de_comida`, que crece con cestos y odres en vez de
   con un tope inventado).
2. Superar esa capacidad tiene una consecuencia real y medible —peor
   descanso, más enfermedad, más percance— sin ser un muro que impida nacer
   o llegar. Se prueba con un año o varios de partida real —población que
   crece por `Relevo.evaluar_nacimiento`, no forzada a mano— donde cruzar el
   umbral se ve reflejado en alguna métrica ya existente (fatiga,
   `cold_sick_days`, percances) frente a una banda que se queda por debajo.
3. Levantar un paraviento (o partir la banda en más de un abrigo, si esa
   pieza llega a existir) sube la capacidad de forma medible y la
   penalización baja o desaparece dentro de las jornadas siguientes al
   terminar la obra.
4. Por debajo del umbral, cero efecto: una banda pequeña en un abrigo grande
   no debe mostrar ninguna penalización fantasma.

---

## 3. Sílex por intercambio

### Por qué

`Materia.Kind.SILEX` ya lleva su propia ficha diciendo que "no lo hay en
cualquier sitio: encontrarlo justifica el viaje", y `SLICE_PALEOLITICO.md`
§4 es más explícito todavía: el sílex bueno no existe en Cantabria y eso
**obliga al intercambio desde la primera época**. `SISTEMAS_COMPARTIDOS.md`
§5 ya diseña el primer peldaño de esa escalera —trueque de banda a banda,
sin institución de por medio— y lo señala como la semilla de todo el sistema
de comercio del juego.

**Decisión ya tomada sobre el alcance**: la veta local de sílex que hoy
genera `Parajes` (una de cada cinco parajes de materia prima) se queda tal
cual. Esta spec no la toca, ni la reduce, ni la retira. El intercambio se
añade como una fuente más, complementaria a lo que ya se puede tallar in
situ — no como su sustituto.

### Criterios de aceptación

1. Tiene que existir una vía para que la banda consiga sílex sin depender
   de encontrar o trabajar ninguna veta local: un contacto con una banda
   vecina que entrega sílex (u otro material del mismo peldaño, concha
   incluida, según `SISTEMAS_COMPARTIDOS.md` §5) a cambio de algo que la
   banda tiene. Medible: una sonda que fuerce o complete al menos un
   intercambio ve entrar sílex en el almacén en una partida donde no se ha
   descubierto ni trabajado ninguna veta.
2. El intercambio cuesta algo real — jornadas, un viaje, o material que se
   entrega a cambio— y queda registrado (crónica o equivalente) con lo que
   entra y lo que sale, no como dinero gratis.
3. El intercambio no tiene que salir siempre: `SISTEMAS_COMPARTIDOS.md` §5
   ya avisa de que "una banda vecina este año no tiene sílex de sobra" puede
   pasar. Repetir el intento varias veces en una sonda tiene que poder
   mostrar fallos, no sólo éxitos.
4. El primer intercambio logrado dispara el hito que ya está descrito y sin
   construir en `EPOCA_01_PALEOLITICO.md` §3 — "la concha de lejos", primer
   `Intercambio` recibido— y deja constancia en la crónica como un momento,
   no como un movimiento silencioso de inventario.

---

## Fuera de alcance

- **El conchero visible.** Ya construido (`Desechos` + `Conchero`); no se
  toca aquí. Queda pendiente, fuera de esta spec, corregir
  `ESTADO_DE_LA_SLICE.md` §5.9 para que no lo repita como tarea abierta.
- **La veta local de sílex.** No se reduce ni se retira: decisión tomada al
  encargar esta spec.
- **El resto de la escalera de comercio.** Ruta y depósito, mercado con
  moneda, mercado exterior (`SISTEMAS_COMPARTIDOS.md` §5, peldaños 2 a 4):
  son trabajo de épocas posteriores, no de esta spec.
- **La capa exterior de exploración como mecánica completa** —encuentro con
  otra banda, evitar/tratar/conflicto (`SISTEMAS_COMPARTIDOS.md` §4)—: esta
  spec sólo necesita que el trueque exista y entregue sílex; el resto de esa
  capa (visualizar el encuentro, IA de la banda vecina, opción de conflicto)
  queda fuera.
- **Cualquier instalación térmica nueva o cambio a la escalera térmica.** El
  Paleolítico se queda en el hogar abierto (`EPOCA_01_PALEOLITICO.md` §2);
  nada de esta spec lo cambia.
- **Números concretos de balanceo** — litros de piel por prenda, litros de
  abrigo por plaza, probabilidad exacta de que falte sílex del otro lado—:
  se dejan para playtest, como el resto del proyecto.
- **Partir la banda en más de un `Settlement`.** Si la consecuencia de
  superar las plazas de abrigo se resuelve sólo con paravientos, no hace
  falta construir una segunda banda jugable para cerrar esta spec; eso es
  alcance de la "agregación estacional" que `EPOCA_01_PALEOLITICO.md` §3 ya
  marca fuera de esta slice.

---

## Plan técnico

### 0. Sobre `docs/SPECS.md`

> **Resuelto (2026-09-12).** `SPECS.md` se reescribió entero contra el código y
> ya no describe aquel prototipo. Lo que sigue se deja como estaba porque
> documenta con qué se trabajó; el contrato vigente está ahora en `SPECS.md` §4.

`SPECS.md` §3 documentaba contratos de `RawMaterial`, `Chunk`, `Architecto`,
`BlockData`: la capa de *city builder* de una encarnación anterior del
proyecto, retirada según `ARQUITECTURA.md` §8 —confirmado, ninguno de esos
scripts existe en `scripts/`—. Nada de esa sección aplica a este plan. El
contrato real y vigente para los tres bloques de abajo es el que ya siguen
`Relevo.gd`, `Partida.gd`, `Percances.gd`, `Hogar.gd`, `Taller.gd` y
`Desechos.gd`: un `RefCounted` de "tema cerrado" colgado de `SettlementSim`
como `sim.xxx = Xxx.new(self)`, con su propio bloque de constantes de
balanceo y su punto de enganche explícito en el ciclo de jornada/estación.
Los tres bloques de este plan siguen ese contrato, no el de `SPECS.md` §3.
Esto no es una desviación que haga falta declarar caso a caso: es simplemente
qué contrato es el vigente hoy en `scripts/sim` y `scripts/economia`.

Comprobado en código, no asumido de la documentación:
`Tool.gd`, `CampProjects.gd`, `Toolkit.gd`, `Storehouse.gd`, `TechTree.gd`,
`Chronicle.gd` y `SettlementSim.gd` (`SPECIALITY_MAKES`, `tool_natural_demand`,
`camp_built`, el bloque nocturno de `_tick_person` con `HEARTH_COLD_RISE`).

---

### 1. Vestido como necesidad de invierno

**Módulos afectados**

- `scripts/economia/Tool.gd` — nuevo valor en `enum Kind` (nombre a fijar en
  `/tareas`; "VESTIDO" o "PRENDA" son las dos opciones obvias). Entra en
  `KIND_NAMES`, `WEAR_PER_DAY`, `default_stuff()` (→ `Stuff.PIEL`, mismo que
  ya usa `Kind.ODRE`), `recipe()` (→ `{Materia.Kind.PIEL: n}`),
  `needs_tool()` (→ `Kind.AGUJA`: se cose, no se raspa como el odre) y
  `tech_of()` (→ `TechTree.Tech.AGUJA` — la misma tecnología que ya desbloquea
  la aguja y cuya propia ficha dice *"ropa cosida y ajustada... permite
  trabajar fuera en pleno invierno"*; no hace falta una tecnología nueva).
- `scripts/sim/SettlementSim.gd` — añadir el nuevo `Tool.Kind` a
  `SPECIALITY_MAKES[Profession.Speciality.PELETERIA]` (hoy sólo lista
  `Tool.Kind.ODRE`, pese a que la descripción de la especialidad en
  `Profession.gd` ya dice *"Piel: ropa, odres, cobijo"*) y una entrada nueva
  en `Taller.tool_natural_demand()`, con la demanda ligada a `population()`
  en vez de a una cifra fija como el `2` del odre — el objetivo natural es
  una prenda por persona, no un número de taller.
- `scripts/sim/SettlementSim.gd`, bloque nocturno de `_tick_person`
  (`HEARTH_COLD_RISE`/`HEARTH_COLD_RECOVERY`, hoy ~línea 1617-1628) — la
  cobertura de vestido de la banda (piezas en condición útil del nuevo
  `Tool.Kind` en `toolkit`, frente a `population()`) atenúa
  `HEARTH_COLD_RISE` por persona. Se suma al hogar, no lo sustituye: sin
  fuego y sin vestido sigue siendo lo peor; con las dos cosas debe doler
  menos que con ninguna.

**Decisiones de arquitectura**

- Vestido se modela como pieza de `Toolkit` —igual que `CESTO`/`ODRE`—, no
  como un nuevo `Materia.Kind` de almacén. Ya se desgasta, ya tiene receta y
  pericia del artesano, y "cobertura de stock frente a población" es
  exactamente el patrón que ya resuelve `CESTO` frente a la recolección.
- Cobertura agregada de la banda, no una prenda por persona con dueño. Nada
  en los criterios de aceptación exige saber QUIÉN lleva vestido puesto, y
  modelarlo por individuo sería un salto de complejidad que la spec no pide.

**Orden de dependencias**

Ninguno nuevo. `Tech.AGUJA`, `PIEL` curtida y `PELETERIA` ya existen y están
disponibles desde el arranque de la partida (Paleolítico).

**Riesgos técnicos conocidos**

- El desgaste de utillaje hoy se computa por JORNADA DE TRABAJO
  (`WEAR_PER_DAY`, se gasta cuando la pieza se usa en una tarea). Un vestido
  no "se usa trabajando": se lleva puesto siempre, también en invierno
  cuando no se sale del abrigo. Si ese patrón no encaja, la alternativa es un
  desgaste por jornada de CALENDARIO en vez de por uso — la única pieza del
  `Toolkit` que se gastaría por tiempo llevado puesto y no por trabajo. Se
  decide en `/tareas`, no aquí.

---

### 2. Plazas de abrigo por capacidad

**Módulos afectados**

- `scripts/sim/CampProjects.gd` — nuevo `Kind.PARAVIENTO` en el `enum` y su
  entrada en `INFO` (`labor_days`, `materials`, `requires`), mismo patrón que
  `HOGAR`/`SECADERO`/`LAVADERO`.
- `scripts/sim/SettlementSim.gd` — nueva noción de capacidad de PLAZAS
  (constante base + bonus por cada `PARAVIENTO` presente en `camp_built`).
  No toca `shelter_litres`/`store.capacity_litres`: eso es volumen de
  ALMACÉN, esta spec es gente, son dos cosas distintas que hoy comparten
  vocabulario ("abrigo") por casualidad.
- `scripts/sim/SettlementSim.gd`, integración de la consecuencia — mismo
  bloque nocturno que ya trata `HEARTH_COLD_RISE`/`HEARTH_COLD_FATIGUE`
  (`_tick_person`/`_settle_at_home`): superar el aforo alimenta esos mismos
  contadores para quien duerme esa noche en el abrigo, no crea un tercero.

**Decisiones de arquitectura**

- La capacidad sale de lo construido (`camp_built`), no de un número fijo de
  partida — mismo principio que ya aplicó `Storehouse.capacidad_de_comida`
  a la comida (cestos/odres en vez de un tope inventado, ver
  `ESTADO_DE_LA_SLICE.md` §5.11). Este plan repite un patrón ya validado en
  el propio código, no inventa uno nuevo.
- La penalización por superar el aforo NO es un muro duro — no impide nacer
  ni expulsa a nadie —: es una degradación medible, reutilizando `cold` y
  `fatigue`, que ya tienen en `Relevo.gd` el patrón exacto de "sube con la
  exposición, cura por debajo de un umbral, mata a partir de cierta
  acumulación". Superpoblación entra como una fuente más de esos mismos
  contadores, no como un cuarto camino de muerte paralelo a hambre, frío,
  vejez y percance.

**Orden de dependencias**

- Depende de que la población varíe de verdad: `Relevo.gd`/`Partida.gd`
  (nacimientos, muertes) ya están en el árbol de trabajo, sin comitear
  todavía (`scripts/sim/Relevo.gd`, `scripts/sim/Partida.gd`, `??` en
  `git status`). Cualquier tarea de este bloque parte de ese código, no de
  la versión de `ESTADO_DE_LA_SLICE.md` que daba la población por constante.
- Independiente de los bloques 1 y 3: se puede trabajar en cualquier orden
  respecto a ellos.

**Riesgos técnicos conocidos**

- Comprobar el criterio de aceptación exige población creciendo de forma
  orgánica (un parto por año bueno), no forzada a mano: eso pide partidas de
  varios años (180+ jornadas) para ver el umbral superado con naturalidad.
  Antes de escribir una sonda nueva desde cero, comprobar si la
  infraestructura de sondas de año largo que ya existe en el repo
  (`AnoProbe.gd` y similares) sirve de base, en vez de duplicarla.

---

### 3. Sílex por intercambio

**Módulos afectados**

- Nuevo `scripts/sim/Intercambio.gd`, `RefCounted`, mismo patrón de fachada
  que `Relevo`/`Partida`/`Hogar`/`Percances`: `sim.intercambio =
  Intercambio.new(self)`. `SISTEMAS_COMPARTIDOS.md` §5 ya da la forma:
  "qué se ofrece, qué se pide, cuánto tarda el viaje, y si el otro extremo es
  fiable o puede fallar".
- `scripts/banda/Chronicle.gd` — nuevo valor en `enum Kind`. Ninguna
  categoría actual (`TIERRA`, `HALLAZGO`, `TALLER`, `PENURIA`, `OBRA`,
  `GENTE`) encaja con "trato con banda vecina": `HALLAZGO` es territorio
  propio, no gente de fuera.
- `scripts/sim/SettlementSim.gd` — engancha `Intercambio` al ciclo de
  jornada/estación, igual que el resto de subsistemas (p.ej.
  `relevo.evaluar_nacimiento()` se llama desde `_advance_local_season`). El
  punto de enganche exacto —por jornada, por estación, o por evento— se
  decide en `/tareas`.

**Decisiones de arquitectura**

- **No se construye la capa exterior de exploración completa**
  (`SISTEMAS_COMPARTIDOS.md` §4: encuentro visualizado en el mapa, IA de
  banda vecina, elegir evitar/tratar/conflicto). `Intercambio` no necesita
  "ver" a la banda vecina para funcionar — es el objeto ligero que el propio
  `SISTEMAS_COMPARTIDOS.md` §5 ya describe. Construir la capa exterior
  completa sería diseñar muy por encima de lo que esta spec pide.
- **No se construye el sistema genérico `Hito`/`Hitos`.** Está bosquejado en
  `SISTEMAS_COMPARTIDOS.md` §2 pero no tiene una sola línea de código
  todavía (comprobado: no existe `Hito.gd` ni `Hitos.gd` en el repo). El
  criterio de aceptación de la spec —que el primer intercambio no sea "un
  movimiento silencioso de inventario"— se satisface con una entrada de
  crónica de peso alto, igual que ya hace `Taller.gd` con "la primera pieza
  de sílex de la banda" (peso 2). Cuando el proyecto construya `Hito`/`Hitos`
  de verdad —hace falta para el resto de hitos del Paleolítico, no sólo para
  éste—, "la concha de lejos" se da de alta en ese catálogo entonces, no
  como parte de esta tarea.

**Orden de dependencias**

- Ninguno respecto a los bloques 1 y 2.
- Lo que la banda entrega a cambio sale de `Storehouse`/`Materia` ya
  existentes (materia prima o comida que sobra); no depende de ningún
  sistema nuevo aparte del propio `Intercambio`.

**Riesgos técnicos conocidos**

- Es la única pieza de las tres que introduce un concepto sin ningún soporte
  de datos hoy —no hay ningún `Site`/entidad que represente a la banda
  vecina—. Modelarla como un generador aleatorio sin mundo detrás es
  aceptable para esta spec (coherente con no construir la capa exterior
  completa), pero es deuda declarada: cuando `SISTEMAS_COMPARTIDOS.md` §4 se
  construya de verdad, `Intercambio` tendrá que engancharse a un `Site` real
  en vez de a un número aleatorio. Eso es trabajo futuro, no de esta tarea.

---

## Tareas

Dos nombres que el plan dejaba abiertos, fijados aquí: el `Tool.Kind` nuevo
se llama **`VESTIDO`** (consistente con el título de la spec y con el estilo
de una palabra por `Kind`), y la categoría nueva de `Chronicle.Kind` se llama
**`TRUEQUE`**.

### Bloque 1 — Vestido como necesidad de invierno

- [x] **1.1.** Añadir `Tool.Kind.VESTIDO` en `scripts/economia/Tool.gd`:
  entrada en el `enum`, `KIND_NAMES`, `default_stuff()` → `Stuff.PIEL`,
  `recipe()` → `{Materia.Kind.PIEL: n}` (cantidad a fijar al implementar),
  `needs_tool()` → `Kind.AGUJA`, `tech_of()` → `TechTree.Tech.AGUJA`. NO se
  añade todavía a `WEAR_PER_DAY` — ver 1.3. Verificable: ampliar
  `TestToolkit.gd` con un caso que fabrica un `VESTIDO` de `Stuff.PIEL` y
  comprueba `display_name()`, `needs_tool()` y `tech_of()`.

  > **HECHO (2026-09-12).** `Tool.Kind.VESTIDO` de `Stuff.PIEL`
  > (`recipe()` → 1,5 de piel, más que el odre porque es una prenda entera),
  > `needs_tool()` → `AGUJA` (se cose, no se raspa) y `tech_of()` →
  > `Tech.AGUJA` (la misma que ya desbloquea la aguja). Test nuevo en
  > `TestToolkit.gd`. Suite completa: 881 pruebas, 6153 comprobaciones, todo
  > en verde (`Utillaje` pasó de 33 a 34 pruebas).
- [x] **1.2.** Añadir `Tool.Kind.VESTIDO` a
  `SettlementSim.SPECIALITY_MAKES[Profession.Speciality.PELETERIA]` y una
  entrada en `Taller.tool_natural_demand()` con demanda = `population()`
  (una prenda por persona). Verificable: ampliar `TallerProbe.gd` (o
  equivalente) para comprobar que con alguien en `PELETERIA` y `PIEL` en el
  almacén se fabrican piezas de `VESTIDO` a lo largo de varias jornadas.

  > **HECHO (2026-09-12).** `VESTIDO` añadido a `SPECIALITY_MAKES[PELETERIA]`
  > y a `tool_natural_demand()` con `sim.people.size()`. La demanda,
  > `_next_piece` y `_craft` ya eran genéricos sobre `Tool.Kind`
  > (recetas/prerequisito/tecnología vía `Tool.recipe`/`needs_tool`/`tech_of`)
  > así que no hizo falta tocar `Taller.gd` más que esa línea. Verificado con
  > un test nuevo en `TestToolkit.gd` en vez de `TallerProbe.gd` —éste último
  > es un script de diagnóstico por texto sin aserciones, no una prueba
  > automática— que monta un `SettlementSim` desnudo, un peletero con aguja
  > en el taller y piel en el almacén, y comprueba que `_craft` acaba
  > produciendo un `VESTIDO`. Sorpresa real al escribirlo: `sim.techs` es
  > `null` en un `SettlementSim.new()` sin `setup()`, y mi primer intento
  > escribía `sim.techs.known[...] = true` — reventaba con "Invalid access...
  > on a base object of type 'Nil'" y el fallo se tragaba en silencio (el
  > test contaba como "pasado" sin haber corrido ninguna comprobación:
  > 154 comprobaciones antes y después de añadirlo). `Taller.knows_tool` ya
  > trata `sim.techs == null` como "se sabe hacer todo", así que sobraba esa
  > línea. Con eso quitado: 882 pruebas, 6154 comprobaciones, todo en verde.
- [x] **1.3.** Enganchar el desgaste de `VESTIDO`: una vez por jornada de
  CALENDARIO (no por tarea de trabajo, a diferencia del resto del utillaje —
  ver el riesgo ya señalado en el plan), en el mismo punto donde se procesa
  el bloque nocturno de `_tick_person`. Fijar aquí la constante de desgaste
  diario. Verificable: prueba unitaria que corre varias jornadas sin reponer
  `VESTIDO` y comprueba que `toolkit.count`/condición baja con el tiempo.

  > **HECHO (2026-09-12).** Cambio de sitio respecto a lo previsto: en vez de
  > `_tick_person` (que corre por fracciones de hora y no tiene una noción
  > limpia de "un día"), el desgaste se engancha en `_end_of_day()`, que ya
  > es el punto donde el resto de cosas "por jornada de calendario" ocurren
  > (`store.age(1)`, `desechos.nuevo_dia()`). Nuevo `Toolkit.wear_all(kind,
  > amount)` —distinto de `use()`, que sólo gasta LA PEOR pieza: aquí
  > envejecen TODAS, porque todo el que tiene un vestido lo lleva puesto a
  > la vez, no de uno en uno—. Constante `SettlementSim.VESTIDO_WEAR_PER_DAY
  > = 0.6`, que con la durabilidad de la piel (80 usos) da algo más de dos
  > estaciones por prenda. Dos tests nuevos en `TestToolkit.gd`: que
  > `wear_all` envejece TODAS las piezas por igual, y que sin reponer, el
  > vestido se agota solo con los días. Suite: 883 pruebas, 6157
  > comprobaciones, todo en verde.
- [x] **1.4.** Calcular la cobertura de vestido de la banda (piezas de
  `VESTIDO` en condición útil frente a `population()`) y usarla para atenuar
  `HEARTH_COLD_RISE` en el bloque nocturno de `_tick_person`, sumándose al
  efecto del hogar sin sustituirlo. Verificable: ampliar `TestRelevo.gd` con
  un caso que compara `person.cold` tras el mismo número de horas de
  invierno sin hogar, con cobertura de vestido 0 frente a cobertura 1.

  > **HECHO (2026-09-12).** Nueva `SettlementSim.vestido_coverage()` (piezas
  > de `VESTIDO` sin agotar entre `population()`, saturada a 1) y constante
  > `VESTIDO_COLD_MITIGATION = 0.6`: con cobertura completa, `HEARTH_COLD_RISE`
  > se multiplica por 0,4 en vez de por 0 — a propósito, para que "sin fuego
  > y sin vestido" siga siendo la peor combinación de las cuatro, tal como
  > pedía el plan. Test en `TestRelevo.gd` comparando `person.cold` tras la
  > misma noche de invierno sin hogar, con y sin un vestido por persona.

- [x] **1.5.** Confirmar que la atenuación llega hasta `cold_sick_days` y la
  muerte por frío ya implementadas en `Relevo.revisar_frio()`. Verificable:
  ampliar `TestRelevo.gd` (o `HogarProbe.gd`) con un tramo de varias
  jornadas de invierno intenso comparando una banda con vestido suficiente
  contra una equivalente sin él, mostrando `cold_sick_days` divergiendo.

  > **HECHO (2026-09-12).** Diez noches de invierno sin hogar, comparando dos
  > `SettlementSim` gemelos —uno con un `VESTIDO` por persona, otro sin
  > ninguno— llamando `_tick_routine` + `relevo.revisar_frio()` jornada a
  > jornada. La banda sin vestido acumula al menos tantos `cold_sick_days`
  > como la que lo lleva, y de hecho enferma en ese tramo; la que lo lleva,
  > con la cobertura elegida (0,6), aguanta mejor. Mismo test en
  > `TestRelevo.gd`.

- [x] **1.6.** Confirmar el criterio negativo: fuera de invierno, o con
  cobertura de vestido completa, no aparece penalización distinta de la
  actual. Verificable: caso de prueba dedicado en el mismo fichero que 1.4,
  con la estación puesta a verano y cobertura 0 — `cold` no debe subir por
  falta de vestido fuera de temporada fría.

  > **HECHO (2026-09-12).** Dos casos en `TestRelevo.gd`: en verano, con
  > vestido completo, `cold` se queda en 0 igual que sin él —la cueva sola
  > ya abriga fuera de invierno, con vestido no cambia nada—; y en invierno,
  > con cobertura completa pero sin hogar, `cold` sigue subiendo algo por
  > encima de 0 (no desaparece del todo, que es el punto de 1.4). Suite
  > completa tras 1.4-1.6: 887 pruebas, 6163 comprobaciones, todo en verde.

### Bloque 2 — Plazas de abrigo por capacidad

- [x] **2.1.** Añadir `CampProjects.Kind.PARAVIENTO` en
  `scripts/sim/CampProjects.gd`, con su entrada en `INFO`
  (`labor_days`, `materials`, `requires: -1`), mismo patrón que `HOGAR` /
  `SECADERO` / `LAVADERO`. Verificable: ampliar `TestCampProjects.gd` con el
  caso estándar que ya cubre las otras obras (nombre, coste, sin
  dependencia).

  > **HECHO (2026-09-12).** `PARAVIENTO`: 2 jornadas, `PIEL: 4.0` +
  > `LENA: 3.0`, sin dependencia (es un cierre, no una fuente de calor, igual
  > que el lavadero). La prueba genérica `test_cada_proyecto_tiene_receta_y_
  > jornadas` ya lo cubrió sola al iterar `CampProjects.all()`; añadido
  > además un caso dedicado a `requires == -1`, mismo patrón que el del
  > hogar. Suite: 888 pruebas, 6167 comprobaciones, todo en verde.
- [x] **2.2.** Definir en `SettlementSim.gd` la capacidad de plazas del
  abrigo (constante base + bonus por cada `PARAVIENTO` presente en
  `camp_built`) y exponerla como función consultable. Verificable: prueba
  unitaria que activa 0/1/2 `PARAVIENTO` en `camp_built` a mano y comprueba
  el valor devuelto en cada caso.

  > **HECHO (2026-09-12).** Cambio de premisa respecto a "0/1/2": `camp_built`
  > es un `Dictionary[Kind, bool]` -como ya lo es para `HOGAR`/`SECADERO`/
  > `LAVADERO`-, así que sólo puede haber UN paraviento construido, nunca
  > dos. La spec no exige más de uno (la vía de "partir la banda" para
  > cuando uno no baste ya queda fuera de alcance), así que
  > `plazas_abrigo()` es `PLAZAS_ABRIGO_BASE` (18) más
  > `PLAZAS_ABRIGO_POR_PARAVIENTO` (8) si `camp_built` lo tiene, y no un
  > contador. Documentado el porqué en el propio comentario de la constante
  > para que no se lea como un olvido. Test 0/1 en `TestCampProjects.gd`.
  > Suite: 889 pruebas, 6168 comprobaciones, todo en verde.
- [x] **2.3.** Enganchar la consecuencia de superar el aforo en el mismo
  bloque nocturno que ya trata `HEARTH_COLD_RISE`/`HEARTH_COLD_FATIGUE`:
  cuando `population()` supera la capacidad de plazas, quien duerme esa
  noche en el abrigo acumula `cold`/`fatigue` extra. Verificable: ampliar
  `TestRelevo.gd` con población forzada a mano por encima y por debajo del
  umbral, aislando el efecto de la mecánica en sí (sin depender todavía de
  que la población haya crecido de forma orgánica).

  > **HECHO (2026-09-12).** Nuevas constantes `ABARROTADO_FATIGUE_RISE` y
  > `ABARROTADO_COLD_RISE` (1,5 cada una, más suaves que las del hogar
  > apagado): se suman a `fatigue`/`cold` cuando `population() >
  > plazas_abrigo()`, FUERA del `if` de hogar/estación —apretujarse molesta
  > todo el año, no sólo en invierno sin fuego—, y por encima de lo que ya
  > toque por esas otras causas, nunca en su lugar. Test en `TestRelevo.gd`
  > que aísla el efecto poniendo hogar encendido y verano (ambos ya
  > neutralizan `HEARTH_COLD_RISE`), de forma que cualquier subida de `cold`
  > sólo puede venir de la superpoblación.

- [x] **2.4.** Confirmar el criterio negativo: por debajo del umbral, cero
  efecto — ninguna penalización fantasma en una banda pequeña con un abrigo
  grande. Verificable: caso de prueba dedicado junto a 2.3.

  > **HECHO (2026-09-12).** Mismo montaje que 2.3 pero sin la gente de más:
  > `cold` se queda exactamente en 0. Suite tras 2.3-2.4: 891 pruebas, 6172
  > comprobaciones, todo en verde.
- [x] **2.5.** Sonda de varios años sobre partida real —población que crece
  por `Relevo.evaluar_nacimiento()`, no forzada— que muestra el aforo
  superado con naturalidad y la métrica elegida (fatiga, `cold_sick_days` o
  percances) empeorando frente a una partida equivalente que construye un
  `PARAVIENTO` a tiempo. Partir de la infraestructura de `AnoProbe.gd` en
  vez de escribir una sonda de año largo desde cero. Es el criterio de
  aceptación real de la spec (punto 2 de §2), y el que de verdad cierra este
  bloque.

  > **HECHO (2026-09-12).** Cambio deliberado de método, acordado con el
  > usuario tras pedir permiso: la sonda con escena 3D real al estilo
  > `AnoProbe.gd` se estimó en horas de reloj para cubrir varios años de
  > partida, y no se lanzó. En su lugar, dos tests en `TestRelevo.gd` que
  > conducen el ciclo ANUAL directamente —`cumplir_anyos`/`revisar_vejez`/
  > `evaluar_nacimiento`, sin escena ni jornada a jornada—, forzando "año
  > bueno" (reserva de sobra, sin racha de hambre) para que los nacimientos
  > salgan solos, sin fijar población a mano. Dos bandas con la misma
  > semilla en `create_band` y en `sim._rng` crecen parto a parto de forma
  > IDÉNTICA; la única diferencia entre ellas es si tienen `PARAVIENTO`
  > construido. Con diez años buenos ambas superan las 15 personas y el
  > aforo base de 18; con la misma población, la que no levantó paraviento
  > acumula más frío agregado en la misma noche de invierno. Coste real:
  > segundos, no horas — la parte cara de la sonda de escena era el terreno
  > y el pathfinding, no la mecánica de población en sí. Suite completa:
  > 898 pruebas, 6836 comprobaciones, todo en verde.

**Documento completo.** Las 17 tareas de los tres bloques están hechas y
verificadas. 898 pruebas, 6836 comprobaciones, todo en verde.

### Bloque 3 — Sílex por intercambio

- [x] **3.1.** Añadir `Chronicle.Kind.TRUEQUE` en
  `scripts/banda/Chronicle.gd`, con su entrada en `KIND_NAMES`.
  Verificable: si existe una prueba de cobertura de `Chronicle` (todo
  `Kind` tiene nombre), que siga en verde; si no, basta con que compile.

  > **HECHO (2026-09-12).** No existía esa prueba de cobertura, así que se
  > añadió (`test_todos_los_tipos_tienen_nombre`, itera `Chronicle.Kind.
  > values()`). Suite: 892 pruebas, 6179 comprobaciones, todo en verde.
- [x] **3.2.** Crear `scripts/sim/Intercambio.gd` (`RefCounted`) con la
  forma mínima que describe `SISTEMAS_COMPARTIDOS.md` §5: qué se ofrece
  (material que la banda entrega), qué se pide (sílex u otro material del
  mismo peldaño), coste en jornadas, y probabilidad de que la banda vecina
  tenga de sobra ese año. Enganchar `sim.intercambio = Intercambio.new(self)`
  en `SettlementSim.gd`. Todavía sin llamar desde ningún ciclo. Verificable:
  prueba unitaria que crea la instancia y comprueba que un intento con la
  tirada forzada a éxito entrega el material pedido al `Storehouse`
  descontando lo ofrecido, y que un intento forzado a fallo no mueve nada.

  > **HECHO (2026-09-12).** `Intercambio.intentar()`: la banda ofrece
  > `FRUTO_SECO` (es lo único de lo que produce el doble de lo que puede
  > comer y guardar, `ESTADO_DE_LA_SLICE.md` §2) a cambio de `SILEX`, con
  > `PROBABILIDAD_EXITO = 0,55`. Cambio respecto al plan: sin forzar la
  > tirada a mano —no hay forma limpia de fijar `randf()` desde fuera—, se
  > repite el intento 300 veces (mismo patrón que ya usa `TestMishap` para
  > sus percances) y se comprueba que aparecen los dos desenlaces y que cada
  > uno mueve el almacén como toca. Nuevo `TestIntercambio.gd`, registrado en
  > `RunTests.gd`. Sorpresa de infraestructura: un `class_name` nuevo no lo
  > ve `RunTests.gd` hasta que Godot rehace `global_script_class_cache.cfg`
  > —hubo que abrir el editor una vez en headless
  > (`--headless --editor --quit-after 3`) antes de que la suite lo
  > reconociera—. Suite: 894 pruebas, 6655 comprobaciones, todo en verde.
- [x] **3.3.** Enganchar el intento de intercambio al ciclo de estación —un
  intento por estación, mismo patrón temporal que
  `relevo.evaluar_nacimiento()` en el giro de primavera, aplicado en el
  cambio de cada estación—. Verificable: sonda (`TruequeProbe.gd`) que corre
  varias estaciones y cuenta cuántos intentos se han disparado.

  > **HECHO (2026-09-12).** Llamada a `intercambio.intentar()` en
  > `_advance_local_season()`, fuera del `if PRIMAVERA` -a diferencia de
  > nacimientos y vejez, que son anuales, esto es una vez por CADA una de
  > las cuatro estaciones-. Cambio respecto al plan: en vez de una sonda que
  > simula jornadas reales (`TruequeProbe.gd`), un test que llama
  > `_advance_local_season()` directamente ocho veces y cuenta las entradas
  > de crónica `TRUEQUE` -más rápido y determinista, sin depender de cuántas
  > jornadas dura una estación-. `GameState.season`/`.year` son estáticas al
  > proceso, así que el test las restaura al salir para no filtrar estado a
  > las demás pruebas. Suite: 895 pruebas, 6656 comprobaciones, todo en
  > verde.
- [x] **3.4.** Registrar en la crónica cada intento, éxito o fracaso, con lo
  que entra y lo que sale (`Chronicle.Kind.TRUEQUE`). Verificable: en la
  misma sonda de 3.3, contar entradas de crónica de tipo `TRUEQUE` y
  comprobar que arroja tanto éxitos como fracasos en una muestra de varias
  estaciones.

  > **HECHO (2026-09-12).** Ya quedó implementado en 3.2 —`intentar()`
  > anota crónica en los dos caminos—; lo único que faltaba era la
  > aserción explícita de que el RECUENTO de entradas `TRUEQUE` coincide con
  > el número de intentos (éxitos + fallos), no sólo con los éxitos. Añadida
  > a `test_exito_y_fracaso_mueven_el_almacen_como_toca`. Suite: 895
  > pruebas, 6657 comprobaciones, todo en verde.
- [x] **3.5.** Confirmar el criterio central: en una partida donde no se ha
  descubierto ni trabajado ninguna veta local de sílex, tras varias
  estaciones con intercambio activo aparece `Materia.Kind.SILEX` en el
  almacén. Verificable: en `TruequeProbe.gd`, comprobar `store.amount
  (Materia.Kind.SILEX) > 0` sin que `Parajes` haya generado ni trabajado
  ningún paraje de tipo `SILEX` en esa corrida.

  > **HECHO (2026-09-12).** Test directo en `TestIntercambio.gd`: con
  > `sim.parajes.list` vacío desde el arranque (un `SettlementSim` a secas
  > no genera mapa), ocho cambios de estación bastan para que
  > `store.amount(SILEX) > 0`, con la lista de parajes siguiendo vacía al
  > final. Suite: 896 pruebas, 6659 comprobaciones, todo en verde.
- [x] **3.6.** Marcar el primer intercambio logrado con una entrada de
  crónica de peso alto —mismo patrón que "la primera pieza de sílex de la
  banda" en `Taller.gd`—, de forma que no sea indistinguible del resto de
  entradas de `TRUEQUE`. Verificable: en la misma sonda de 3.5, comprobar
  que la primera entrada de éxito lleva el peso alto y las siguientes no lo
  repiten.

  > **HECHO (2026-09-12).** Ya implementado en 3.2 (`logrado_alguna_vez`,
  > peso 2 la primera vez y peso 1 las siguientes). Ampliada
  > `test_exito_y_fracaso_mueven_el_almacen_como_toca` para comprobar el
  > peso de la ÚLTIMA entrada de crónica tras cada intento: 2 en el primer
  > éxito, 1 en los demás. Suite: 896 pruebas, 6831 comprobaciones, todo en
  > verde.

**Bloque 3 completo.** Con esto quedan hechas las tareas 1.1-1.6, 2.1-2.4 y
3.1-3.6. Sólo falta **2.5**, la sonda de varios años sobre partida real con
crecimiento orgánico — deliberadamente al final: es la única comprobación
"larga" (más de 45 días simulados) del documento.
