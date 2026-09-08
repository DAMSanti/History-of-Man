# Arquitectura y estilo

Cómo está montado *History of Man* y cómo se escribe código en él. Si algo de
aquí choca con lo que hay en el repositorio, gana este documento y el
repositorio está pendiente de arreglar.

---

## 1. Qué es esto

Una simulación de una banda paleolítica en la Cantabria del Magdaleniense,
sobre relieve real (MDT del IGN a 5 m, teselas Terrarium de AWS como reserva).
No es un juego de construir: no hay edificios, hay un abrigo que se equipa.

Hay **dos capas** y se pasa de una a la otra:

| capa | escena | qué es |
|---|---|---|
| regional | `scenes/region_map.tscn` | Cantabria entera. Se elige emplazamiento. |
| local | `scenes/demo_main.tscn` | 4 km de valle. Aquí vive la banda. |

El traspaso va por `Expedition` (qué sitio, qué relieve, qué era) y `GameState`
(qué se lleva la banda). Son las dos únicas piezas de estado global.

---

## 2. El mapa de carpetas

```
scripts/
  DemoMain.gd     el cableado de la capa local: monta todo y lo conecta
  datos/          clases que se SERIALIZAN en .res  (ver §6, tiene trampa)
  mundo/          relieve, agua, y por dónde se puede andar
  region/         la capa regional, los importadores de MDT y el estado global
  banda/          las personas y lo que saben
  sim/            la simulación del asentamiento y sus subsistemas
  economia/       materiales, utillaje, despensa y técnica
  vista/          lo que se dibuja en el mundo 3D
  ui/             las ventanas
  tests/          la suite y las sondas de medida  (ver §5)
  tools/          herramientas de línea de comandos: horneado e ingesta
```

Tamaños al día de hoy, para saber dónde duele:

| carpeta | ficheros | líneas |
|---|---|---|
| `tests/` | 105 | 21 165 |
| `sim/` | 28 | 14 701 |
| `vista/` | 23 | 7 196 |
| `ui/` | 11 | 6 460 |
| `mundo/` | 12 | 5 081 |
| `tools/` | 26 | 3 931 |
| `region/` | 7 | 2 936 |
| `banda/` | 7 | 2 170 |
| `economia/` | 7 | 1 897 |
| `datos/` | 10 | 1 350 |

**Una clase por fichero, y el fichero se llama como la clase.** Sin excepciones.

---

## 3. Cómo se descompone un sistema grande

`SettlementSim` es el objeto central y ha llegado a tener 9 276 líneas. Se
adelgaza sacando **temas cerrados** a su propia clase, siempre con el mismo
patrón:

```gdscript
class_name Caceria
extends RefCounted
## Qué es y por qué está separado.
var sim: SettlementSim

func _init(settlement: SettlementSim) -> void:
    sim = settlement
```

y en `SettlementSim`:

```gdscript
## La cacería: acecho, persecución, lance y despiece. Ver [Caceria].
var caceria: Caceria = Caceria.new(self)
```

Ya salieron así `Caceria`, `Cumbres`, `Despensa`, `Hogar`, `Marcha`, `Nasas`,
`Percances`, `Pinturas`, `Reconocimiento`, `Reparto`, `Tajo`, `Taller` y
`Trampas`; de `GameUI`, `BarraSuperior`, `PanelAlmacen`, `PanelRastros`,
`PanelSitios` y `PanelTrabajos`; de `TerrainGenerator`, `MallaDelTerreno`; y de
`DemoMain`, `Minimapa`.

`SettlementSim` ha pasado de **9 276 líneas a 3 100** por ese camino, `GameUI`
de **5 015 a 1 968**, `TerrainGenerator` de 1 715 a 1 182 y `DemoMain` de 2 007
a 1 485.

**Reglas del troceado:**

1. **Un tema cerrado, no una capa horizontal.** «La cacería» sí. «Todas las
   funciones que empiezan por `_get`» no.
2. **Bloque contiguo antes que funciones sueltas.** Un candidato de 850 líneas
   seguidas es mejor apuesta que uno de 960 repartido en once trozos, aunque
   sea más pequeño. Los trozos sueltos es donde se cuelan los errores.

   Si un sistema merece la pena pero está repartido, se **agrupa primero** en
   un commit que NO cambie una sola letra: se mueven los bloques y se comprueba
   que el texto de cada función es idéntico y que no ha desaparecido ninguna
   línea. Después, el corte es uno solo. Así salió la marcha: estaba en doce
   trozos, se juntó en un commit que sólo movía líneas, y el corte siguiente
   fue un único bloque de 820.
3. **El simulador se queda de fachada.** No se reescriben las llamadas de
   fuera: se dejan pasamanos.

   ```gdscript
   func apply_priorities() -> void:
       reparto.apply_priorities()
   ```

   `Reparto` tenía 156 llamadas externas y se resolvieron con 28 pasamanos.
4. **El coste de sacar un sistema NO es la velocidad.** Medido con
   `tools/CosteIndireccion.gd`: una función que lee ocho campos del simulador
   pasa de 249 a 453 ns cuando los pide por `sim.` — un 82 % más. Suena mucho y
   no lo es: quince personas por ocho pasos son 120 llamadas por fotograma,
   0,024 ms sobre 38,5. El **0,06 %**. Para costar un milisegundo harían falta
   unas 4 900 llamadas por fotograma y aquí no hay nada que se acerque.

   Lo que sí se paga es que **`sim.loquesea` deja de comprobarse en
   compilación**, y eso ya costó que la fauna no estuviera conectada a la caza
   y que la ventana del almacén reventara al abrirse. Por eso la regla 7 no es
   opcional: sustituye a la comprobación que se pierde.
5. **Las constantes se piden por la CLASE, no por la instancia.**
   `SettlementSim.MIN_HEARTH`, nunca `sim.MIN_HEARTH`: por la instancia se
   pierde el tipo y `var a := sim.MI_CONST if x else y` deja de compilar con
   *«Cannot infer the type»*.
6. **Al cortar un bloque se van constantes que usa el resto.** Después de
   cortar hay que comparar lo declarado en el fichero nuevo contra lo que
   sigue usándose en el viejo, y devolver lo compartido.
7. **Y hay que redirigir lo que llamaba desde fuera, VARIABLES INCLUIDAS.**
   Esto no da error de compilación: GDScript sólo se entera al ejecutar. Se
   comprueba con

   ```
   godot --headless --path . --script res://scripts/tools/LlamadasHuerfanas.gd
   ```

   que tiene que decir `llamadas huerfanas: 0`. Existe porque se colaron seis
   llamadas a `sim._report_spoilage` al sacar [Despensa] y **la suite seguía
   en verde**: cinco pruebas reventaban antes de su primera comprobación y se
   contaban como que pasaban. Se vio porque el total de comprobaciones bajó de
   5.171 a 5.164. **Ese número hay que mirarlo**: 716 pruebas «en verde» con
   siete comprobaciones menos no es verde.

---

## 4. Estilo de código

**GDScript tipado, siempre.** Parámetros, retornos y variables. `for person:
Inhabitant in people`, no `for person in people`.

**Nombres de dominio en español.** `Caceria`, `Paraje`, `Despensa`, `raciones`,
`pericia`. Los nombres del motor y de la API quedan como están (`_process`,
`Vector3`, `queue_redraw`). Una función se llama como la cosa que hace en el
juego, no como el patrón de código que usa.

**Los comentarios explican POR QUÉ, no qué.** Esto sobra:

```gdscript
# Suma uno al contador
total += 1
```

Esto es lo que hace falta:

```gdscript
## Estuvo en 2,4 y era una cifra sin medir. Un acecho es de un par de horas, y
## con 2,4 por hora la pieza levantaba la cabeza SIEMPRE: en la partida de
## prueba se llegó a tiro cuatro ticks en ciento veinte jornadas.
const NOTA_POR_HORA := 0.45
```

Un comentario bueno cuenta **qué se probó, qué salió y por qué está así**. Si
una cifra viene de una medida, va la medida. Si viene de una decisión de
diseño, se dice que es una decisión de diseño.

**No se inventan números de balanceo.** Toda cifra que decida si la banda come
va como constante con nombre, documentada y marcada *pendiente de playtest*. Lo
que se puede medir, se mide; lo que se decide, se dice que se ha decidido y por
qué. Ejemplos vivos: `HARVEST_SCALE`, `Caceria.ESCALA_DEL_RASTREO`,
`Hunting.RACIONES_POR_JORNADA_PERFECTA`.

**Una unidad significa una sola cosa en todo el juego.** La ración son
`Materia.KCAL_RACION` calorías, media jornada de una persona. Hubo doce
materiales cuya *unidad* se llamaba «ración» y valían entre 0,06 y 1,36
raciones: veintitrés veces de diferencia entre dos cosas del mismo nombre.

**Documentación de clase obligatoria.** Todo fichero abre con `##` diciendo qué
es y, si salió de otro sitio, de dónde salió y por qué.

---

## 5. Pruebas y sondas

Son dos cosas distintas y no se mezclan.

**`scripts/tests/Test*.gd`** — la suite. Se corre entera y tiene que estar en
verde siempre:

```
godot --headless --path . --script res://scripts/tests/RunTests.gd
```

Hoy: 716 pruebas, 5 171 comprobaciones. Una prueba comprueba una regla del
juego, no una línea de código, y su nombre lo dice:
`test_lo_que_gasta_el_almacen_es_lo_que_come_la_banda`.

**`scripts/tests/*Probe.gd`** — sondas de medida. No pasan ni fallan: **miden**
y escriben una tabla. Son la herramienta de trabajo del balanceo, y el
proyecto se ajusta midiendo, no a ojo. `JornadaCazadorProbe` fue quien dijo que
un cazador estaba el 0,8 % de su vida en estado de trabajo.

Tres cosas que cuestan tiempo si se olvidan:

- **Las capturas de pantalla necesitan ventana.** Con `--headless`,
  `get_texture().get_image()` devuelve null. Las capturas van a
  `%APPDATA%/Godot/app_userdata/History of Man/`.
- **Las medidas no se corren en paralelo** ni se solapan con edición de
  ficheros: cada proceso de Godot parsea todos los scripts al arrancar, y tocar
  un `.gd` a mitad de una tanda la rompe por dentro.
- **Hay sondas que NO son deterministas, y hay que saber cuales.** Las que
  corren un numero fijo de fotogramas -`MarchaProbe`- avanzan menos horas de
  juego si la maquina va cargada, porque la simulacion acumula tiempo real con
  tope (`PASOS_POR_CUADRO`). Dos corridas seguidas del mismo codigo dieron 35,8
  y 48,9 raciones. Antes de leer una diferencia como una regresion, hay que
  correr la sonda DOS VECES sobre el mismo codigo.
- **Compilar no es funcionar.** Antes de dar algo por hecho hay que correr el
  juego (`VistaProbe`) o el panel (`PanelProbe`). GDScript no avisa en
  compilación de asignar una propiedad que no existe: `sim.wildlife = herds`
  estuvo meses sin conectar la fauna a la caza, y la caza se resolvía por una
  tabla vieja sin que se notara.

---

## 6. La trampa de `scripts/datos/`

Un `.res` binario lleva escrita **la ruta del script** de cada objeto que
contiene. Mover el fichero `.gd` rompe el dato:

```
Attempt to open script 'res://scripts/Site.gd' resulted in error 'File not found'
```

Y la ruta no se puede parchear a mano: va con su longitud delante y detrás hay
una tabla de desplazamientos.

Por eso esas clases viven juntas en `scripts/datos/` y **no se mueven a la
ligera**. Si hay que moverlas, se usa `tools/MigrarEsquema.gd`, y el orden es
lo único que importa:

1. **cargar** todos los recursos (el script todavía en su sitio viejo),
2. **luego** `script.take_over_path(ruta_nueva)`,
3. **luego** guardar,
4. y por último mover los `.gd`.

Al revés, cada recurso se carga como un `Resource` pelado sin una sola
propiedad y se guarda ese vacío encima del bueno. Hecho al revés costó
dieciséis ficheros y 667 MB de relieve convertidos en ficheros de 330 bytes.
La herramienta comprueba el tamaño antes y después y se niega a guardar nada
que haya encogido.

---

## 7. Qué se versiona y qué se reconstruye

`data/dem/`, `models/` y `textures/terrain/` **no se versionan**: son cientos
de MB que se reconstruyen solos, cada capa con su herramienta.

| se pierde | se rehace con | ¿necesita red? |
|---|---|---|
| `data/dem/tiles/` | `region/DEMImporter` (AWS Terrain Tiles) | sí |
| `data/dem/cantabria_region.res` | `tools/RehacerRegion.gd` | no, si hay teselas |
| `data/dem/local/site_N*.res` | `tools/RehacerSitio.gd` (`SITIO=56`) | sí (IGN) |
| `data/sites/cantabria_sites.res` | `tools/BakeRegion.gd` | no |
| `models/props/props.res` | `tools/PropIngest.gd` (Poly Haven) | sí |
| `textures/terrain/` | `tools/TerrainTextureIngest.gd` (ambientCG) | sí |
| `models/people`, `models/animals` | `tools/BandaAtlas.gd`, `tools/FaunaAtlas.gd` | sí |

Lo que **sí** se versiona: `data/sites/*.res`, `data/boundaries/*.res` y los
`.json` de origen. Son pequeños y caros de derivar.

---

## 8. Lo que no se hace

- **No se deja código muerto.** Si algo no lo llama nadie, se borra; git lo
  guarda. Se fue así toda la capa de *city builder* que quedaba de la
  encarnación anterior del proyecto: `Architecto`, `Chunk`, `BlockData`,
  `RawMaterial`, `buildings/`, `materials/` y las cabañas de prueba.
- **No se deja una propiedad apuntando a donde ya no está.** Al sacar una
  clase hay que barrer los `sim.loquesea` que se quedaron atrás; no dan error
  hasta que corren, y a veces ni eso.
- **No se ajusta una cifra contra una sola corrida.** La varianza entre dos
  corridas del mismo escalón de caza llegó a ser mayor que la que hay entre el
  primer escalón y el último. Si la muestra son tres sucesos, no se toca nada.
- **No se toca un `.gd` mientras corre una medida.**
- **No se mira sólo el número de pruebas.** Una prueba que revienta antes de su
  primer `assert` no falla: pasa. Lo que la delata es el total de
  comprobaciones.
- **Cuidado con `endswith` sobre nombres de fichero.** Un guardia
  `if p.endswith("Despensa.gd"): continue` se salta también
  `TestDespensa.gd`, que es justo el fichero que había que arreglar.
