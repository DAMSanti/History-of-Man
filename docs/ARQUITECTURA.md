# Arquitectura y estilo

Cómo está montado *History of Man* y cómo se escribe código en él. Si algo de
aquí choca con lo que hay en el repositorio, gana este documento y el
repositorio está pendiente de arreglar.

---

## Dónde mirar

> **Aviso para buscar aquí:** `grep "^## "` devuelve también los comentarios
> `##` de los ejemplos de GDScript. Para los encabezados de verdad,
> `grep -n "^## [0-9]"`.

| Si buscas… | Ve a |
|---|---|
| Qué carpeta es para qué, y cuánto pesa cada una | §2 |
| **Cómo se saca un sistema de `SettlementSim`, y las siete trampas** | **§3** |
| Estilo: tipado, nombres, qué comentario sirve, cifras de balanceo | §4 |
| Pruebas y sondas, y en qué se diferencian | §5 |
| **Cuánto cuesta medir y cómo no pagarlo** | **§5.1** |
| Por qué `scripts/datos/` no se mueve a la ligera | §6 |
| Qué se versiona y con qué se rehace lo que no | §7 |
| Los errores que ya se cometieron y no se repiten | §8 |

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
| `tests/` | 143 | 30 090 |
| `sim/` | 38 | 21 034 |
| `ui/` | 22 | 8 560 |
| `vista/` | 26 | 8 185 |
| `mundo/` | 14 | 6 329 |
| `tools/` | 32 | 5 552 |
| `region/` | 7 | 2 929 |
| `banda/` | 8 | 2 552 |
| `economia/` | 7 | 2 214 |
| `datos/` | 10 | 1 340 |

(Medido el 2026-09-12. `tests/` es un tercio del repositorio y eso está bien:
es lo que sostiene que las cifras de la documentación se puedan comprobar.)

**Una clase por fichero, y el fichero se llama como la clase.** Sin excepciones.

---

## 3. Cómo se descompone un sistema grande

`SettlementSim` es el objeto central y llegó a tener 9 276 líneas. Se adelgaza
sacando **temas cerrados** a su propia clase, siempre con el mismo patrón:

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

Ya salieron así veintidós: `Ascent`, `Barbecho`, `Caceria`, `CampProjects`,
`Cronista`, `Cumbres`, `Desechos`, `Despensa`, `ElLobo`, `Hogar`, `Marcha`,
`Nasas`, `Partida`, `Percances`, `Pinturas`, `Reconocimiento`, `Relevo`,
`Reparto`, `Tajo`, `Taller`, `Tanteo` y `Trampas`. De `GameUI` salieron
`BarraSuperior`, `PanelAlmacen`, `PanelCenso`, `PanelCronica`, `PanelObras`,
`PanelOficios`, `PanelRastros`, `PanelSitios`, `PanelTecnicas` y
`PanelTrabajos`; de `TerrainGenerator`, `MallaDelTerreno`; y de `DemoMain`,
`Minimapa`.

`SettlementSim` bajó de **9 276 líneas a 3 100** por ese camino. Hoy está en
**4 119**, `GameUI` en 1 377, `TerrainGenerator` en 1 263 y `DemoMain` en 1 642.

**Que `SettlementSim` haya vuelto a subir mil líneas no es un fallo del método,
es el método funcionando**: se corta cuando estorba, no cuando se cruza un
número. Pero conviene mirarlo: si el siguiente tema cerrado ya se distingue
—y a este tamaño suele distinguirse—, toca cortar otra vez.

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

Tiene que salir en verde, y el total de comprobaciones no puede bajar del que
diera al empezar. El total medido vive en [ESTADO.md](ESTADO.md) §3 y sólo
ahí. Una prueba comprueba una regla del juego, no una línea de código, y su
nombre lo dice:
`test_lo_que_gasta_el_almacen_es_lo_que_come_la_banda`.

**`scripts/tests/*Probe.gd`** — sondas de medida. No pasan ni fallan: **miden**
y escriben una tabla. Son la herramienta de trabajo del balanceo, y el
proyecto se ajusta midiendo, no a ojo. `JornadaCazadorProbe` fue quien dijo que
un cazador estaba el 0,8 % de su vida en estado de trabajo.

### 5.1. Lo que cuesta medir, y cómo no pagarlo

> **Antes que nada: TODA MEDIDA COMPARATIVA LLEVA `SEMILLA=`.**
>
> `SettlementSim` siembra con el reloj si nadie le pasa una semilla
> (`SettlementSim.setup`, y su comentario avisa de esto), y **las
> sondas no la fijan por su cuenta**: ni `AtascoProbe`, ni `RodeoProbe`, ni
> `TironAnualProbe`. Así que dos corridas seguidas de la misma sonda con el
> mismo código son **dos partidas distintas**.
>
> Medido el 2026-09-12, y por eso está escrito aquí: `AtascoProbe` sin semilla,
> ocho jornadas, sin tocar una línea de código entre corridas, dio **2 200,
> 1 747, 303 y 219** pasos cortados. Con `SEMILLA=42` da **2 295 dos veces
> seguidas, exacto**. Sobre aquella primera tanda se llegaron a sacar dos
> conclusiones y a escribirlas en ESTADO.md; las dos eran ruido y hubo que
> retirarlas.
>
> El síntoma es fácil de reconocer: **si una cifra no cuadra con la de hace un
> momento y el código no ha cambiado, el roto es el instrumento**, no el juego.
> Y la primera pregunta que se le hace al instrumento es si fijó la semilla.

> **Y la segunda regla, que costó lo mismo el mismo día: MIENTRAS UNA MEDIDA
> ESTÁ EN VUELO, EL CÓDIGO NO SE TOCA.**
>
> Una corrida larga tarda media hora, y media hora da para seguir trabajando.
> El 2026-09-12 se lanzó una pareja de 60 jornadas para comprobar que acelerar
> la noche no cambiaba la partida y, mientras corría, se cambiaron tres cosas
> de esa misma noche: la condición de entrada, el presupuesto por cuadro y un
> corte nuevo al cerrar la jornada. **La corrida dio «divergen» y se tardó hora
> y media en entender que no comparaba dos configuraciones, sino dos versiones
> del código** — ninguna de ellas la que había al terminar.
>
> Con la versión final, la misma comprobación da idénticas.
>
> En corto: una sonda larga es una **foto del árbol de trabajo en el momento de
> lanzarla**. Si hay que tocar algo mientras corre, se toca sabiendo que el
> resultado no describirá lo que quede, y se vuelve a lanzar. Lo barato es
> repetir la corrida; lo caro es creerse la primera.

**Una corrida de un año a `time_scale = 5` pasa de una hora de reloj.** Esa
cifra decide cómo se comprueba todo lo demás, y olvidarla sale caro: en una
tanda se llegó a planear **más de diez comprobaciones de un año y una de tres**
— entre dieciséis y dieciocho horas de máquina—. **La de tres años acabó
resolviéndose con una prueba que tardó segundos.**

**Primero: ¿qué estás comprobando de verdad?** Casi siempre la respuesta barata
existe, y la cara es pereza disfrazada de rigor:

| Si lo que quieres saber es… | Se comprueba con | Cuesta |
|---|---|---|
| **Una regla**: «si pasa X, entonces Y» | una prueba de `scripts/tests/` | segundos |
| **Un estado lejano**: qué pasa en el año 3, con la banda envejecida | una prueba que **construye ese estado** y da un paso | segundos |
| **Una curva corta**: cuánto se agota un tajo, cuánto cura el secadero | una sonda de 8–45 jornadas | minutos |
| **Interacción entre estaciones**, deriva que crece con los días, rendimiento sobre la partida real | una sonda de año | **más de una hora** |

**La regla que sale de ahí: no simules para llegar a un estado — constrúyelo.**
Si la pregunta es «¿qué pasa cuando alguien cumple cuarenta años?», se pone la
edad a cuarenta y se da un paso. Correr tres años para que envejezca solo no
comprueba nada más y cuesta cinco horas. Lo mismo vale para una despensa vacía,
un utillaje roto o un paraje esquilmado: **son estados, y un estado se
escribe**.

`Instantanea` está para exactamente esto —arrancar en la jornada N sin correr
las anteriores—, y `Instantanea.volcar` es la mitad que falta para que sirva
(ver ROADMAP.md «En curso»).

**Segundo: si de verdad hace falta un año, que ese año conteste TODAS las
preguntas.** Una corrida larga es cara por arrancarla, no por lo que mide.
Instrumentarla para que saque ocho cifras en vez de una cuesta lo mismo. **Diez
preguntas no son diez corridas de un año: son una corrida con diez contadores.**

Antes de lanzar nada largo, junta la lista entera de lo que quieres saber de esa
partida — incluidas las preguntas de tareas que vengan después— y métela toda en
la misma pasada.

**Tercero: di lo que va a costar antes de gastarlo.** Si un plan implica más de
unos minutos de máquina, el número va en el plan y se pregunta. Dieciséis horas
de sondas no es una decisión técnica: es una decisión de quien dirige el
proyecto, y se toma antes, no cuando ya lleva ocho corriendo.

Y recuerda que **una cifra de una sola corrida no es una cifra** si la sonda no
es determinista: eso son dos corridas, no una. Cuenta las dos al presupuestar.

---

Tres cosas más que cuestan tiempo si se olvidan:

- **Las capturas de pantalla necesitan ventana.** Con `--headless`,
  `get_texture().get_image()` devuelve null. Las capturas van a
  `%APPDATA%/Godot/app_userdata/History of Man/`.
- **Las medidas no se corren en paralelo** ni se solapan con edición de
  ficheros: cada proceso de Godot parsea todos los scripts al arrancar, y tocar
  un `.gd` a mitad de una tanda la rompe por dentro. Si sois varios agentes,
  esto deja de ser un consejo y pasa a ser un turno: ver
  [AGENTES.md](AGENTES.md) §3.
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
- **Un cualificador automático no puede tocar lo que va entre comillas.** Al
  sacar `PanelOficios`, la regla que convierte `tech` en `ui.tech` reescribió
  también `entry["tech"]` y la ventana de técnicas dejó de encontrar su clave.
  No dio error de compilación: dio 43 filas donde había 46, y sólo se vio
  porque había un patrón contra el que comparar. El guardia tuvo el mismo
  problema al revés y ya lleva `_sin_cadenas`.
- **Cuidado con `endswith` sobre nombres de fichero.** Un guardia
  `if p.endswith("Despensa.gd"): continue` se salta también
  `TestDespensa.gd`, que es justo el fichero que había que arreglar.
