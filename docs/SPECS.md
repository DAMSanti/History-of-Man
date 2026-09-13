# SPECS — el contrato técnico

Qué existe hoy en *History of Man*, con qué contrato, y qué no se puede romper
sin romper otra cosa. Es la referencia para tomar decisiones consistentes: si
vas a escribir código nuevo, esto es lo que ya está decidido.

Motor **Godot 4.5.1** · **GDScript** · **Forward+** · `config/name="History of Man"`

**Este documento no es el único, y no repite lo que dicen los otros.** Si algo
está aquí y también allí, allí manda:

| Pregunta | Documento |
|---|---|
| Cómo se escribe código aquí, cómo se trocea una clase, cómo se mide | [ARQUITECTURA.md](ARQUITECTURA.md) |
| Qué se va a construir y en qué orden | [ROADMAP.md](ROADMAP.md) |
| Qué hace hoy el juego y qué le falta, con cifras medidas | [ESTADO.md](ESTADO.md) |
| Las once épocas y sus hitos | [EPOCAS.md](EPOCAS.md) · [SISTEMAS.md](SISTEMAS.md) |
| Cómo trabajan varios agentes a la vez sin pisarse | [AGENTES.md](AGENTES.md) |

> **Nota de historia.** La versión anterior de este documento describía un
> prototipo de *city builder* —`Chunk`, `Architecto`, `RawMaterial`,
> `BlockData`, `TimeManager` como autoload, «no hay suite de pruebas»— que
> **ya no existe**: se retiró entero (ARQUITECTURA.md §8) y el documento se
> quedó atrás sin que nadie lo tocara. Lo que sigue está contrastado contra
> `scripts/` el 2026-09-12, con la suite en verde —el total de ese día está en
> [ESTADO.md](ESTADO.md) §3, que es donde vive esa cifra—. Si vuelve a haber
> discrepancia, gana el código y este documento está pendiente de arreglar.

---

## Dónde mirar

| Si buscas… | Ve a |
|---|---|
| Las dos escalas, su malla y su resolución | §2.1 |
| **Por qué no hay autoloads y dónde vive el estado global** | **§2.2** |
| Quién cablea con quién | §2.3 |
| El paso fijo, y por qué la partida no depende de los fps | §3.1 |
| **Qué señal usar: `hour_passed`, `day_passed` o `paso_cerrado`** | **§3.2** |
| El determinismo y de dónde sale el azar | §3.3 |
| La trampa de `scripts/datos/` y los `.res` | §4.1 |
| **Quién contesta «¿se puede pasar?» y «¿cuánto cuesta andar?»** | **§4.3** |
| `SettlementSim` como fachada y las reglas del troceado | §4.4 |
| La ración, y qué limita la despensa | §4.5 |
| Las capas de física, y cuáles no se usan | §5 |
| Rendimiento medido, y el aviso del contador roto | §6.1 |
| Cómo se comprueba que dos corridas son la misma partida | §6.2 |
| La suite, y por qué se mira el total de comprobaciones | §6.3 |
| **Lo que rompe el juego sin dar un error de compilación** | **§7** |

Cómo se escribe código está en [ARQUITECTURA.md](ARQUITECTURA.md), no aquí.

---

## 1. Qué es

Una simulación de una banda paleolítica en la Cantabria del Magdaleniense sobre
relieve real. No se construye una ciudad: se lleva a quince personas a través de
un año. El jugador no da órdenes de tarea — reparte prioridades y cada mañana la
banda se organiza sola con lo que puede hacer ese día.

---

## 2. Arquitectura

### 2.1. Dos escalas, un solo conjunto de datos

| | Capa regional | Capa local |
|---|---|---|
| Escena | `scenes/region_map.tscn` (`RegionMap.gd`) | `scenes/demo_main.tscn` (`DemoMain.gd`) |
| Qué es | Cantabria entera, tablero de decisión | La simulación: la banda vive aquí |
| Escala de mundo | 1 unidad = **100 m** | 1 unidad = **1 m** |
| Extensión | 199 × 171 km | 4 096 m de lado (`Expedition.local_size_m`) |
| Malla | 1025² vértices, exageración vertical ×2,5 | 513² vértices → **8 m por vértice** |
| Reloj | estaciones | días y horas |

La escala regional no es cosmética: a 1 unidad = 1 m, Cantabria daría un mundo
de 171 000 unidades, con problemas de precisión de coma flotante y un plano
lejano imposible.

**No hay streaming de chunks y no lo va a haber.** Un mapa local de 4 km cabe en
una malla única; la antigua fase de chunking está cancelada, no aplazada.

### 2.2. Estado global: no hay autoloads

`project.godot` tiene la sección `[autoload]` **vacía, y es deliberado**. Lo que
tiene que sobrevivir a un cambio de escena va en `static var` de un script, que
queda cargado igual y no obliga a tocar `project.godot`:

| Clase | Qué guarda | Contrato |
|---|---|---|
| `Expedition` (`region/`) | El traspaso regional → local: qué `Site`, qué relieve, qué recuadro, qué cota del mar, qué época | Lo escribe el mapa regional al fundar y lo lee `DemoMain._ready`. `is_active()` decide si la capa local arranca de una partida o de sus valores de demo |
| `GameState` (`region/`) | La partida: emplazamiento de arranque, población inicial, estación, qué se lleva la banda | Constantes de diseño (`HOME_LAT`, `START_POPULATION := 15`) más el estado que cruza escenas |
| `UISkin.era` (`ui/`) | La era que lleva puesta la interfaz | Se viste con `UISkin.vestir(era)`; los colores son `static var` y no `const` justamente porque cambian con la era |

**Regla: no se añaden autoloads.** Si algo parece necesitar ser global, se
pregunta primero si de verdad lo necesita; si lo necesita, va como estática con
su comentario de por qué.

### 2.3. El cableado

`DemoMain.gd` es **el único sitio** donde se conectan unos subsistemas con
otros: monta terreno, campo de recursos, fauna, vegetación, `SettlementSim` y
`GameUI`, y los enlaza. No se cablean entre sí por su cuenta.

---

## 3. Los relojes, y el contrato que de verdad importa

### 3.1. Paso fijo

`SettlementSim` avanza en **pasos de tamaño fijo** (`PASO_FIJO := 1.0/30.0`),
con tope de `PASOS_POR_CUADRO := 8` por fotograma. Lo que sobra no se tira: se
queda en `_pendiente` y se hace en el fotograma siguiente.

**Consecuencia, y es un contrato duro: la partida no depende de los fps.** Una
máquina lenta va más despacio, no juega otra partida. Esto se rompe con una
facilidad sorprendente, y por eso existe el instrumental del §6.2.

`time_scale` es una variable de `SettlementSim`, **no** `Engine.time_scale`:
congelar el motor congelaría también la interfaz y la cámara.

**Y la noche se salta dando MÁS PASOS, no pasos más largos** (2026-09-12).
Cuando `SettlementSim.nadie_trabaja()` —nadie en `TRABAJANDO`, `BUSCANDO` ni
`RECONOCIENDO`— se siguen dando pasos de `PASO_FIJO` hasta gastar
`MS_DE_NOCHE_POR_CUADRO` (8 ms) del cuadro.

Esto **no rompe el contrato de arriba, y la distinción es la clave del diseño**:
subir `time_scale` cambiaría cuánta hora de juego avanza cada paso, y con ella
el instante en que salta `hour_passed` y el trozo de fauna que entrega
`_fauna_pendiente` — sería otra partida. Dando más pasos del mismo tamaño, la
sucesión de `_advance` es **idéntica** a la de una corrida sin acelerar; lo
único que cambia es en cuántos fotogramas se reparte. Comprobado con `Cotejo`.

Que eso valga depende de que **nada de la simulación dependa del fotograma**, y
está comprobado: `Marcha.nuevo_cuadro()` es un `pass`, y `_path_nodes_this_frame`
y `_stranded_this_frame` se ponen a cero dentro de `_advance`. Si alguien mete
estado por cuadro, rompe esto sin dar un error.

Se apaga con `NOCHE=0` **para medir**, no para jugar: la corrida que demuestra
que la partida no cambia necesita la pareja con y sin. Y el interruptor está en
`Instantanea.FUERA`, porque es ritmo de reloj y no partida.

**Y la semilla se fija sola cuando esto no es una partida sino una medida.** Lo
lanzado con `--script` arranca con `SettlementSim.SEMILLA_DE_SONDA`, no con el
reloj: ninguna sonda la fijaba por su cuenta y comparar dos corridas era
comparar dos partidas distintas. Ver ARQUITECTURA.md §5.1.

### 3.2. Las tres señales, y cuál usar

| Señal | Cuándo se emite | Para qué |
|---|---|---|
| `hour_passed(day, hour)` | **dentro** del paso, a horas de juego | Todo lo que tenga que ocurrir a una hora concreta. Lo que va «cada N fotogramas» cambia de sitio al cambiar los fps, y eso ya apuntó la misma cueva a dos horas distintas |
| `day_passed(day)` | **dentro** del paso, al cerrar la jornada y **antes** del tick de la gente | Cierre de contabilidad diaria |
| `paso_cerrado(day)` | al terminar el paso **entero** | El único límite limpio de la partida. **Una instantánea se toma aquí**: tomada en `day_passed` es media partida a medio paso |

Además: `season_changed(season, year)`, `storage_full(units_lost)`,
`moment_raised(moment)`.

### 3.3. Determinismo

`SettlementSim` tiene **un** `RandomNumberGenerator` (`_rng`), sembrado desde
`game_seed`. **La misma semilla tiene que dar la misma partida**, año entero.
No es un deseo: está medido, y hay herramienta para comprobarlo (§6.2).

Quien necesite azar lo pide al `_rng` de la simulación. Un `randf()` global, un
`Time.get_ticks_msec()` o un contador de fotogramas dentro de la lógica de
partida rompen esto sin dar ningún error.

---

## 4. Módulos y contratos

Una clase por fichero, y el fichero se llama como la clase. Las carpetas son
contratos, no cajones:

### 4.1. `scripts/datos/` — lo que se serializa

`Site`, `SiteSet`, `HeightmapData`, `RegionBoundary`, `RegionEras`,
`TerrainGenerationCache`, `TerrainSurroundCache`, `TerrainTextureSet`,
`TerrainTextureArrays`, `PropLibrary`.

**Contrato: un `.res` binario lleva escrita la ruta del `.gd` de cada objeto que
contiene.** Mover el fichero rompe el dato, y la ruta no se parchea a mano. Si
hay que moverlos se usa `tools/MigrarEsquema.gd`, y el orden importa; el
procedimiento exacto y lo que costó equivocarse están en ARQUITECTURA.md §6.

`Site` es el objeto puente entre las dos escalas. Sus atributos **no se escriben
a mano**: se derivan del relieve real (`SiteDeriver`). `Site.Era` tiene cinco
valores y **las once épocas de `EPOCAS.md` se reparten sobre esos cinco**: no
hace falta tocar el `enum` para añadir una época.

### 4.2. `scripts/region/` — la capa regional

`RegionMap`, `SiteDeriver`, `DEMImporter` (teselas Terrarium de AWS),
`IGNImporter` (MDT05 LiDAR, el fino), `OSMWays`, `Expedition`, `GameState`.

Contrato de importación: el relieve **se descarga una vez y se hornea**; a
partir de ahí se lee de `data/dem/local/`. La primera fundación de un
emplazamiento paga la descarga, las siguientes no.

### 4.3. `scripts/mundo/` — relieve, agua y por dónde se pasa

`TerrainGenerator` (procedural y real), `MallaDelTerreno`, `TerrainSurround`,
`TerrainInpainter`, `TerrainLayers`, `TerrainMaterialManager`,
`ProceduralTextureGenerator` (hoy **sólo el agua**), `Erosion`, `Hydrography`,
`Temporada`, `Navgrid`, `Traversal`, `Wayfinder`, `HornoDeRejillas`.

**Contrato único de tránsito, y es el que más ha costado.** Hubo seis capas
contestando distinto a la misma pregunta, y el resultado fueron 41 atascos por
partida y 5 741 pasos sobre terreno cortado. Hoy:

- **Si se puede pasar de una celda a otra** lo dice `Navgrid.paso_entre`, y
  nadie más. En marcha, la única pregunta es `Marcha.agua_deja_pasar`.
- **Lo que cuesta andar un metro** lo dice `Traversal.pace_fraction`, y nadie
  más. Hubo dos modelos, y un comentario jurando que era uno.
- **Cuántos metros hay de casa a una celda** lo dice `Wayfinder.metros_desde`:
  un Dijkstra desde el abrigo —que es siempre el mismo origen—, rehecho al
  cambiar la rejilla, o sea una vez por estación. **No se pregunta con un A\*
  por candidato**: eso fueron 79 búsquedas en un fotograma de 2 541 ms.
- **Y son los metros del camino que SE ANDA**, no los del más corto que
  existiría. Uno solo, no dos: el mismo Dijkstra da el árbol —por coste— y los
  metros acumulados sobre él. Hubo dos, y con ellos la regla del rodeo admitía
  un sitio midiendo un camino y la persona andaba otro; medido, 88 sitios en
  verano admitidos y luego andados por encima del tope que los admitió.
- **El miedo no encarece un metro más que el rodeo que se anda.**
  `Navgrid.RIESGO_MAXIMO` **es** `Marcha.RODEO_QUE_SE_ANDA`, no una copia: si
  esquivar lo peligroso no puede multiplicar el coste de una celda más que eso,
  tampoco puede provocar un rodeo mayor. El tope es al recargo por riesgo, no
  al tiempo: lo que se tarda en subir una cuesta sigue entero.
- **Nadie da un paso sin camino debajo.** Quedarse sin ruta no es salir derecho
  hacia el destino.

`HornoDeRejillas` amasa las rejillas de la estación siguiente en trozos, **aun
con el reloj parado**, con presupuesto por cuadro. Un presupuesto más fino que
el grano que sabes cortar no es un presupuesto: corta a mitad de fila.

### 4.4. `scripts/sim/` — la simulación

`SettlementSim` es el objeto central y es una **fachada**: los temas cerrados
viven en su propia clase, construida con `Clase.new(self)`, y el simulador deja
pasamanos para no reescribir las llamadas de fuera.

Subsistemas hoy: `Ascent`, `Barbecho`, `Caceria`, `CampProjects`, `Contacto`,
`Cronista`, `Cumbres`, `Desechos`, `Despensa`, `ElLobo`, `Expedicion`, `Hogar`,
`Intercambio`, `Marcha`, `Nasas`, `Partida`, `Percances`, `Pinturas`,
`Reconocimiento`, `Relevo`, `Reparto`, `Tajo`, `Taller`, `Tanteo`, `Trampas`.

> **`Expedicion` y `Contacto` necesitan la comarca regional**, que es un dato
> horneado que la simulación local no carga por su cuenta. Se la pasa
> `DemoMain` justo después de `setup`, que es donde §2.3 dice que se cablea.
> **Y repartir quién vive dónde consume tiradas del `_rng`**, así que desde el
> 2026-09-12 todas las partidas se desplazan respecto de las anteriores: una
> firma o una cifra medida antes de esa fecha no se compara con una de después.

Y alrededor: `Exploration`, `Fauna`, `Fishing`, `Huella`, `Hunt`, `Hunting`,
`Paraje`, `Parajes`, `Poblaciones`, `Querencia`, `ResourceField`,
`ResourceMapper`, `Subsistence`, `Weather`, `WildlifeHerds`.

**Contrato del troceado** — la receta completa, con sus siete reglas y lo que
costó saltárselas, está en ARQUITECTURA.md §3. Lo que no es negociable:

- Las constantes se piden **por la clase** (`SettlementSim.MIN_HEARTH`), nunca
  por la instancia: por la instancia se pierde el tipo y deja de compilar.
- Al sacar una clase hay que **redirigir lo que llamaba desde fuera, variables
  incluidas**. GDScript no avisa en compilación. Se comprueba con
  `tools/LlamadasHuerfanas.gd`, que tiene que decir `llamadas huerfanas: 0`.

### 4.5. `scripts/economia/` — materiales, utillaje, técnica

`Materia`, `Storehouse`, `Toolkit`, `Tool`, `Trap`, `Nasa`, `TechTree`.

**Contrato de unidad, y es el más fácil de romper: una unidad significa una sola
cosa en todo el juego.** La ración es `Materia.KCAL_RACION` — media jornada de
una persona, `KCAL_DIA * 0.5` con `KCAL_DIA := 2500`. Hubo doce materiales cuya
«ración» valía entre 0,06 y 1,36 raciones: veintitrés veces de diferencia entre
dos cosas con el mismo nombre.

**Lo que limita la despensa es en qué se guarda**, no un número:
`Storehouse.capacidad_de_comida` es el volumen a granel (`A_GRANEL`) más lo que
quepa en los cestos (`POR_CESTO`) y odres (`POR_ODRE`) que existan, recalculado
al cerrar cada jornada porque los cestos se rompen. Un tope en raciones no es
una mecánica: es un número, y nada en el mundo impide seguir amontonando.

`TechTree`: las técnicas **se aprenden practicando**, no investigando. El
prerrequisito manda, y es lo que hoy deja la caza mayor fuera de un año de
partida (`AZAGAYA` ← `HOJA` ← `NUCLEO` ← `LASCA`). Eso es un hallazgo medido,
no un fallo por arreglar a ciegas.

### 4.6. `scripts/banda/` — las personas

`Inhabitant`, `Profession`, `BandKnowledge`, `Vereda`, `Chronicle`, `Diario`,
`Tale`, `Moment`, `Mishap`.

- `Profession.can_do()` es **la única puerta** de quién puede hacer qué. Ningún
  oficio de época posterior necesita un campo nuevo en `Inhabitant`: el
  `enum Job` crece, el resto del sistema no.
- La pericia crece practicando y **se transmite de noche**.
- **Los caminos que la banda sabe son de la banda**, no del simulador:
  `BandKnowledge.veredas`, cada uno una `Vereda` sellada con el caudal y el
  encharcamiento de la rejilla que lo trazó, y descartado al leerlo si el sello
  no cuadra. Estuvo en `SettlementSim._route_cache` hasta el 2026-09-12.
  Ver SISTEMAS.md §18.
- `Moment` es el contrato de «la partida deja de ser gestión y te mira»: se
  levanta desde dentro de un paso y la interfaz pone `time_scale` a cero ahí
  mismo. El bucle del §3.1 corta ahí por eso.
- **Y cada opción declara lo que cuesta** (desde el 2026-09-12): `"cuesta"`, en
  despensa, jornadas y riesgo, construida con `Moment.opcion`.
  `Moment.la_eleccion_importa()` dice si elegir cambia alguna cifra. Un momento
  con dos botones que cuestan lo mismo **no cuenta como decisión**, aunque pare
  el reloj. Quien levante un momento con opciones nuevo tiene que rellenarlo, o
  la sonda del año no lo contará.
- **Las sondas contestan por `BarraSuperior.contestar_todo(elige)`**, que
  contesta las decisiones y **cierra los avisos**. Un aviso sin cerrar tapa la
  cola entera: hasta el 2026-09-13 cinco sondas sólo contestaban decisiones, se
  quedaban paradas ante el aviso inicial de la partida y jugaban el año sin
  contestar ninguna.
- **La primera opción es la que no compromete a nada**, cuando la hay. Las
  sondas contestan los momentos eligiendo la opción 0 —`TironAnualProbe`—, y
  si ésa fuera la que gasta, medir «un año sin decidir nada» haría gastos solo.

### 4.7. `scripts/vista/` y `scripts/ui/`

Dibujo y ventanas. `GameUI` es fachada igual que `SettlementSim`, con sus
paneles sacados (`PanelAlmacen`, `PanelCenso`, `PanelObras`, `PanelOficios`,
`PanelRastros`, `PanelSitios`, `PanelTecnicas`, `PanelTrabajos`,
`PanelCronica`, `BarraSuperior`).

**La vista no decide nada de la partida.** Lee el estado y lo dibuja. Un
contador propio en la vista es un segundo modelo de algo que ya está simulado, y
tarde o temprano dice otra cosa.

### 4.8. `scripts/tools/` — herramientas, no juego

Horneado, ingesta, atlas, y el instrumental de medida (`Cronometro`,
`Instantanea`, `FirmaDiaria`, `CosteIndireccion`, `LlamadasHuerfanas`,
`MigrarEsquema`).

**El juego no depende de `tools/` para su lógica**, y ninguna de estas
herramientas promete que un fichero de hoy sirva mañana.

**La excepción es `Cronometro`, y hay que conocerla.** Sus marcas
(`tramo_raiz`, `tramo`, `cierra`) están repartidas por unos veinte scripts del
juego —`SettlementSim`, `Marcha`, `Wayfinder`, `WildlifeHerds`, la vista
entera—, porque medir un tirón desde fuera no dice quién lo causó. Sólo cuenta
mientras el panel de F3 está encendido. **Contrato: una marca que se abre se
cierra**, también por los caminos de salida temprana; un `tramo` sin su
`cierra` desplaza todo lo que venga detrás. Y lo que no está marcado se
atribuye a EL MOTOR (§6.1), así que una marca que falta se lee como un tirón
del motor que no existe.

---

## 5. Capas de física

`project.godot` nombra cuatro: `terrain` (1), `props` (2), `resources` (3),
`banda` (4).

**Estado real: sólo se asigna la 1**, en `MallaDelTerreno` (la colisión del
terreno). Las otras tres están declaradas y sin usar. Es deuda conocida: o se
usan al añadir colisión, o se retiran de `project.godot`. Mientras tanto, no se
asume que un `CollisionShape3D` creado por código tenga capa — hoy no la tiene.

---

## 6. Requisitos no funcionales

### 6.1. Rendimiento

El objetivo no es un número de fps: es **que no haya tirones, y sobre todo que
no crezcan con los días**. La media está bien, y ése es justo el problema — una
media no encuentra un tirón.

Lo medido y en pie hoy: **a velocidad de juego (×5), un año de 180 jornadas va
a 39,1 ms de fotograma medio, con 150 tirones de más de 100 ms en 109 968
cuadros y ninguno grave** — medido con `TironAnualProbe`, semilla 123, con el
cepo puesto, que cuesta un 20 %. Sobre las noventa primeras jornadas, contra la
línea base: de 19,9 a 24,4 fps medios por jornada, y de 1 787 tirones a 114.

Y todo eso **sin que cambie la partida**: las firmas del año salen idénticas y
el año termina con la misma gente y las mismas técnicas.

> **Dos avisos que valen más que las cifras**, y están al principio de
> [archivo/LO_MISMO_MAS_DEPRISA.md](archivo/LO_MISMO_MAS_DEPRISA.md):
>
> **Todo recuento de tirones anterior al arreglo del contador es basura.** El
> panel de F3 y la sonda leían la misma bandeja de picos y **la vaciaba quien
> leyera primero**, así que el segundo contaba de menos: el cepo empujaba 92
> picos y la sonda contaba 3. Lo destapó el usuario, que veía tirones cada
> 0,2 s en su F3 mientras la sonda informaba de ocho en todo el año. Si una
> cifra de tirones no dice que es posterior a ese arreglo, no se usa.
>
> **Y la velocidad importa: ×20 no es velocidad de juego.** La partida llega
> como mucho a ×5, y a ×5 el reparto del coste es otro. Una medida a ×20 no
> describe la partida que se juega.

Instrumento: `Cronometro` más el panel de **F3** (`PerformanceOverlay`), que
caza el fotograma malo y le pregunta qué hizo de más. Lo que no está marcado se
atribuye a **EL MOTOR**, con nodos, objetos y llamadas de dibujo al lado; no
existe un «SIN EXPLICAR».

**Cuidado al comparar corridas:** el cepo mide reloj de pared. Dos corridas con
la máquina en estado distinto no se comparan, y una sonda de número fijo de
fotogramas avanza menos horas de juego si la máquina va cargada.

### 6.2. Determinismo: cómo se comprueba

No es una promesa, es un procedimiento:

- `Instantanea` recorre el estado **por reflexión** desde pocas raíces y saca la
  partida entera a algo comparable. No hay un serializador por módulo que haya
  que mantener a mano cada vez que alguien añade un campo.
- `FirmaDiaria` da tres piezas por jornada: la **firma** (SHA-256 de la
  instantánea, sin tolerancias — una millonésima de hambre ya la cambia), el
  **resumen** en claro, y el **detalle** por `Clase.campo`.
- `Cotejo` compara dos corridas y dice en qué jornada se separan y qué campo no
  cuadra. Sale con 0 si son la misma partida.

```
godot --headless --path . --script res://scripts/tests/Cotejo.gd -- firmas A.txt B.txt
```

### 6.3. Pruebas

```
godot --headless --path . --script res://scripts/tests/RunTests.gd
```

**Todas en verde, siempre**, y el total de comprobaciones no baja del que diera
al empezar. El total medido está en [ESTADO.md](ESTADO.md) §3 y sólo ahí. Una
prueba comprueba **una regla del juego**, no una línea de código.

Las **sondas** (`scripts/tests/*Probe.gd`) son otra cosa y no se mezclan: no
pasan ni fallan, **miden**. El balanceo se ajusta midiendo.

**No se mira sólo el número de pruebas.** Una prueba que revienta antes de su
primer `assert` no falla: pasa. Lo que la delata es el total de comprobaciones.

### 6.4. Persistencia

**No existe**, y conviene no confundirla con lo que sí hay. `Instantanea` es un
instrumento de medida, no un guardado: no sobrevive a un cambio de esquema y no
lo pretende. El guardado de partida es la FASE A3 del ROADMAP.

### 6.5. Datos

`data/dem/`, `models/` y `textures/terrain/` **no se versionan**: son cientos de
MB que se reconstruyen con las herramientas de `scripts/tools/`. La tabla de qué
rehace cada cosa está en ARQUITECTURA.md §7. Sí se versionan `data/sites/*.res`,
`data/boundaries/*.res` y los `.json` de origen.

### 6.6. Plataforma

Windows/desktop sobre el editor Godot 4.5.1. No hay `export_presets.cfg` ni
build de exportación configurada.

---

## 7. Invariantes

Lo que rompe el juego sin dar un solo error de compilación:

1. **Una unidad, un significado.** §4.5.
2. **La misma semilla, la misma partida.** §3.3.
3. **Una pregunta, un sitio que la contesta.** Si «¿se puede pasar?» o «¿cuánto
   cuesta andar un metro?» se responden desde dos sitios, tarde o temprano
   responden distinto. §4.3.
4. **Lo que pasa a horas de juego va en `hour_passed`**, no cada N fotogramas.
5. **Cifras de balanceo, con nombre y con su porqué.** Si la cifra viene de una
   medida, va la medida; si viene de una decisión, se dice que es una decisión.
6. **No se deja código muerto** ni propiedades apuntando a donde ya no está.
7. **Compilar no es funcionar.** GDScript no avisa de asignar una propiedad que
   no existe: `sim.wildlife = herds` tuvo la fauna desconectada de la caza
   durante meses sin que se notara.

---

## 8. Fuera de alcance

- Multijugador.
- Streaming de chunks (cancelado, no aplazado).
- Guardado/carga persistente (FASE A3, todavía no).
- Build de exportación.
- Autoloads nuevos (§2.2).
