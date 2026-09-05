# Revamp gráfico

Plan para pasar de cuatro texturas procedurales y quince cápsulas a terreno PBR
y una banda de personas a la que se le ve lo que están haciendo.

Ver [ROADMAP.md](ROADMAP.md) para el plan general y [SPECS.md](SPECS.md) para el
contrato técnico. Este documento cubre **sólo lo visual**; no cambia ninguna
mecánica.

Decisiones tomadas antes de escribirlo: **escala humana real (1,70 m)**,
**realismo legible** (material escaneado, contraste ajustado a distancia de
gestión), y **objetivo Alto = GTX 1070 a 1080p/60**, con Ultra por encima y Bajo
por debajo.

---

## 1. De dónde se parte, y por qué eso manda

| | Hoy |
|---|---|
| Texturas de terreno | 4, pintadas **píxel a píxel desde GDScript** (`ProceduralTextureGenerator.gd`) |
| Mapas por textura | albedo + normal. **Sin rugosidad, sin AO, sin altura** |
| Rugosidad | una constante por capa en el shader |
| Muestreo | triplanar: 4 capas × 3 planos × 2 mapas = **24 muestreos** peor caso |
| Compresión | ninguna: `ImageTexture` en RAM |
| Personas | `CapsuleMesh` de 3,2 m con `StandardMaterial3D` (`SettlementSim.gd:325`) |
| Animación | **ninguna**. Cero `.glb`, cero `Skeleton3D`, cero `AnimationPlayer` |
| Coste medido | ~25 ms de GPU sólo el terreno (`scripts/tests/GpuProfile.gd`) |

Ese último número es el que ordena todo el plan. A 1080p/60 el frame entero son
**16,6 ms**, y hoy el terreno solo se come 25. Es decir:

> **El primer trabajo del revamp no es añadir texturas. Es que el terreno deje
> de costar 25 ms.** Si se meten ORM y ocho capas encima de la arquitectura
> actual, el juego pasa de 28 FPS a menos de 15.

### Hasta dónde llega el dato (y una corrección al ROADMAP)

El ROADMAP avisa de que *«el DEM tiene una muestra cada 14 m; por debajo de esa
escala todo lo que se ve es invención»*. **Ese número está desfasado** y conviene
arreglarlo, porque cambia lo que hay que hacer:

| Capa | Origen | Paso del dato | Paso de la malla |
|---|---|---|---|
| Regional | terrarium zoom 10 | 111 m | 100 m |
| **Local (normal)** | **IGN MDT05, LiDAR** (`IGNImporter`) | **5 m** | 4 m |
| Local (reserva) | terrarium zoom 13 | 13,9 m | 4 m |

`use_ign_elevation` viene a `true` (`RegionMap.gd:35`), así que en Cantabria lo
que se juega es **MDT05 del IGN a 5 m**; el terrarium de 13,9 m sólo entra fuera
de España o si el servicio no responde. Con dato a 5 m y vértices a 4 m la
interpolación es casi 1:1, no «3 de cada 4 vértices» como todavía dice el
comentario de `TerrainGenerator.gd:68` —escrito para la ruta vieja—.

**Consecuencia para el revamp:** el relieve es real hasta los 5 m, y el hueco
donde la textura fotogramétrica va a afirmar más de lo que la geometría sostiene
es sólo el tramo de **1 a 5 m**. Es estrecho, y se rellena con parallax y con
geometría dispersa (§8), no con ruido.

### Medido (G0, 5-sep-2026)

`scripts/tests/GpuProfile.gd` sobre el sitio 56, GTX 1070, 1920×1080, cámara de
juego. **30,8 ms por fotograma: 0,4 de CPU de render y 28,7 de GPU.** El render
por CPU no existe como problema; esto es GPU de cabo a rabo.

| Se apaga | Total | GPU | Ahorro |
|---|---|---|---|
| — (todo encendido) | 30,8 | 28,7 | — |
| **el terreno jugable entero** | 11,9 | 9,8 | **18,9** |
| **el shader del terreno** (malla intacta) | 12,2 | 10,1 | **18,6** |
| TAA | 23,5 | 21,2 | 7,5 |
| Mapas de normales | 26,8 | 25,0 | 3,7 |
| Sombras | 27,6 | 25,3 | 3,4 |
| Corte de capa al 12 % | 30,0 | 27,8 | 0,9 |
| Contorno | 30,0 | 27,8 | 0,9 |
| Escala 3D al 50 % | 18,8 | 16,5 | 12,2 |

Tres conclusiones, y las tres mueven el plan:

**1. La geometría no cuesta nada; el shader lo es todo.** Quitar la malla ahorra
18,9 ms y dejarla con material trivial ahorra 18,6: la diferencia son 0,3 ms. O
sea que 3,4 millones de triángulos son gratis y el coste está **entero** en el
fragmento. Es la premisa del §2, ahora con número: **18,6 ms, el 60 % del
fotograma, es el triplanar**.

**2. `weight_cutoff` no hace lo que parece.** Subirlo de 0,02 a 0,12 ahorra
0,9 ms, porque recorta la contribución pero **no evita el muestreo**.
Confirmación directa del punto 2.4.

**3. TAA cuesta 7,5 ms, el 24 % del fotograma.** Encendido en
`project.godot:81` con MSAA apagado, o sea corriendo solo. Es la palanca más
barata que hay hoy y no tiene nada que ver con el revamp.

### Presupuesto de frame propuesto (Alto, 1070 @ 1080p)

| Partida | ms |
|---|---|
| Terreno opaco | 6,0 |
| Vegetación y props (MultiMesh) | 3,0 |
| Personajes | 2,0 |
| Sombras direccionales | 2,5 |
| Entorno y post (niebla, SSAO, tonemap) | 2,0 |
| UI y resto | 1,0 |
| **Total** | **16,5** |

Nada entra en el juego sin caber en su casilla.

---

## 2. Terreno: arquitectura antes que arte

El truco central es que **más capas y más mapas no tienen por qué costar más
muestreos**, porque el coste no lo fija cuántas capas existen sino cuántas están
activas en un píxel dado. Con blending por altura y pendiente, en cualquier
píxel hay como mucho **dos** capas con peso real.

Cuatro cambios, en este orden:

**2.1 `Texture2DArray` en vez de un sampler por capa.** Ocho capas pasan a ser
tres arrays —albedo, normal, ORM— en vez de 24 uniforms. Añadir una capa nueva
deja de tocar el shader.

**2.2 Biplanar en vez de triplanar.** El triplanar mezcla los tres planos
siempre; el biplanar descarta el de menor peso. Un tercio menos de muestreos, y
la diferencia no se ve en terreno natural.

**2.3 Camino de un solo plano en terreno llano.** Si `abs(normal.y) > 0.98` —la
mayor parte de un valle— basta el plano Y. La rama es coherente por warp, así
que sale casi gratis.

**2.4 Salto de capas por peso.** `weight_cutoff` ya existe en el shader, pero
sólo recorta la contribución; hay que hacer que **evite el muestreo**.

Cuentas, peor caso y caso típico:

| | Hoy | Con la reforma |
|---|---|---|
| Ladera (2 capas activas, biplanar) | 24 | 2 × 2 × 3 = **12** |
| Valle llano (2 capas, un plano) | 24 | 2 × 1 × 3 = **6** |
| Mapas por capa | 2 | **3** (albedo, normal, ORM) |

**Más información PBR por la mitad de coste.** Ese es el argumento entero.

**2.5 Compresión.** Hoy las texturas son `ImageTexture` sin comprimir: puro
ancho de banda, y probablemente buena parte de los 25 ms. Importar como VRAM
Compressed —BC7 para albedo y ORM, BC5 para normal— con mipmaps.

### ¿Y el addon Terrain3D?

Existe y es bueno, pero la malla de aquí no es un clipmap: sale de
`HeightmapData` del DEM real, con máscara de región, ríos por vértice y un
contorno propio (`TerrainSurround.gd`). Migrar significaría rehacer todo eso.
**Recomendación: no migrar.** El shader propio ya tiene resueltas las partes
específicas del proyecto; lo que le falta es arquitectura de muestreo, que es
mucho menos trabajo que la migración.

---

## 3. Las texturas: catálogo y origen

Ocho capas, derivadas de los biomas que pide
[SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) §8:

| Capa | Qué es | Por qué está |
|---|---|---|
| Pradera / estepa | herbazal frío | El Magdaleniense cantábrico es **estepa fría**, no el prado verde de hoy |
| Suelo de bosque | hojarasca y humus | Bosque de refugio en los valles |
| Roquedo calizo | caliza gris, karst | Cantabria es caliza. Nada de granito |
| Pedrera / canchal | derrubio de ladera | La transición roquedo→suelo, hoy pintada como degradado |
| Cantos de río | cuarcita rodada | **La materia prima del juego.** Tiene que leerse desde la cámara |
| Arena de playa | | Marisqueo y costa |
| Limo de marisma | fango de estuario | Estuario, y el sitio del conchero |
| Nieve | | Alta cota |

**Origen.** Base **CC0**, que además es scriptable:
[ambientCG](https://ambientcg.com/) expone una API JSON pública —verificada:
`Ground103`–`Ground110`, `Gravel043`, `ScatteredLeaves009` y `Rock020`…`Rock064`
son fotogrametría real y descargables sin cuenta— y
[Poly Haven](https://polyhaven.com/textures/ground-terrain) cubre los huecos.
Megascans **ya no es gratis** desde 2025, así que queda como recurso de pago
puntual en [Fab](https://www.fab.com/sellers/Quixel%20Megascans) si alguna capa
concreta no aparece en CC0. El limo de marisma es la que más papeletas tiene.

**Ingesta reproducible.** Un script que llama a la API, descarga, **empaqueta en
un solo RGBA** (AO→R, Rugosidad→G, Metálico→B, **Altura→A**), reescala y escribe
en `textures/terrain/`. Así lo que se versiona es el script y el `.import`, no
dos gigas de PNG.

El canal de altura no es relleno: BC7 trae alfa sin coste extra, y es lo que
alimenta el parallax que tapa el hueco de escala del §8. Hoy ni se descarga.

**Resolución: 2K, y no más.** A la distancia mínima de cámara (~30 m, con
`ground_clearance = 12`) 1920 px cubren unos 30 m de suelo: **64 px/m**. Una
textura 2K con tesela de 4 m da 512 px/m. Ir a 4K es VRAM tirada para un detalle
que no cabe en pantalla. Ocho capas × 3 mapas × 2K comprimido ≈ **130 MB de
VRAM** con mipmaps, que en 8 GB no es nada.

**Anti-repetición.** `macro_influence` ya existe; añadir rotación estocástica de
tesela en Alto y Ultra, que es lo que rompe la cuadrícula de verdad.

---

## 4. Personas: cuerpo, ropa y escala

**Escala real, 1,70 m.** Toca revisar `_make_body()`, el `ground_clearance` de la
cámara y el recorte de zoom, porque la legibilidad que hoy da la cápsula de
3,2 m tendrá que darla el tope de zoom cercano y una silueta a distancia.

**Cuerpo base: [MPFB2](https://static.makehumancommunity.org/mpfb.html)**
—sucesor de MakeHuman, addon de Blender—. Código GPLv3, pero **los assets y lo
que generas son CC0**, sin restricción comercial. Encaja exacto con lo que el
código ya modela: seis cuerpos base —mujer/hombre × niño/adulto/anciano, que son
`Inhabitant.Sex` × `Inhabitant.Age`— con **topología compartida**, así que una
prenda vale para todos.

**Rig:** Rigify → export glTF → esqueleto humanoide de Godot. Godot 4 trae
retargeting por `SkeletonProfileHumanoid`, que es lo que permite reutilizar
animación externa sin rehacerla.

**Ropa por época: geometría, no textura.** Slots de cabeza, torso, piernas, pies
y accesorio en mano. Para la slice sólo hace falta **un set**: piel cosida,
capucha, calzado de piel y adornos de concha y hueso, todo atestiguado en el
Magdaleniense cantábrico. Las otras nueve épocas son datos del mismo sistema y
**no entran en este plan**.

**Dibujado.** Veinticinco personas con `Skeleton3D` y `AnimationTree` es
perfectamente asumible. La técnica de multitudes —animación horneada a textura
de vértices sobre `MultiMesh`— resuelve cientos de personajes, y por eso queda
**anotada para épocas tardías, no construida ahora**. Hacerla hoy sería pagar
complejidad por un problema que no se tiene.

**LOD:** LOD0 ~6k triángulos hasta media distancia, LOD1 ~2k, LOD2 silueta.
Godot genera los LODs al importar el glTF.

---

## 5. Animaciones: el catálogo sale del código, no de la imaginación

Esto es lo bueno: **la máquina de estados ya está escrita**. `Inhabitant.State`
dice en qué situación está cada persona y `Profession.Speciality` qué está
haciendo. La animación se engancha ahí y no hay que inventar nada.

### Locomoción y estado — 15 clips

De `Inhabitant.State`: dormir, ir, buscar (andar mirando), trabajar, volver
cargado, comer, ocioso, reconocer. Más lo que aportan otros módulos: vadear
(`Traversal.gd`), trepar (`Ascent.gd`), cojear y herido (`Mishap.gd`), y cargar
con la cría (`nursing`).

Casi todo esto es genérico y se resuelve **retargeteando de
[Mixamo](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html)**, que sigue
siendo gratis y sin royalties para uso comercial dentro de un juego. Aviso: la
propia Adobe lo describe como no mantenido, así que **hay que bajar de una vez
todo lo que se vaya a usar**, no cuando haga falta.

### Trabajo — 20 clips, y estos hay que animarlos a mano

Ninguna biblioteca genérica tiene «tallar cuarcita». Uno por especialidad de
`Profession.Speciality`, bucles de 2 a 4 segundos:

| Oficio | Clips |
|---|---|
| Manufactura | talla (percusión sentado), asta (ranurar con buril), peletería (raspar en bastidor), cordelería (trenzar) |
| Caza | montar lazo agachado, acecho y lanzamiento, atlatl (cargar y lanzar) |
| Ribera | marisqueo agachado con cesto, arponeo desde la orilla, remar *(pendiente de embarcación)* |
| Recolección | coger de mata, hacer y cargar el haz de leña, recoger cantos |
| Exploración | marcha con carga, trepar |
| Hogar | avivar el fuego, cocinar, cargar el crío, enseñar |

**~35 clips en total** para la primera época. Es un número acotado y medible, y
es **la partida más cara del revamp entero**: más que las texturas y los modelos
juntos.

`AnimationTree` por persona: máquina de estados arriba, `BlendSpace1D` de
locomoción dentro del estado de marcha, y el trabajo como sub-máquina indexada
por especialidad. Y un `BoneAttachment3D` en la mano para el apero —el arpón, el
atlatl, el cesto—: sin eso, arponear y forrajear se leen igual.

---

## 6. Niveles de gráficos

Autoload `GraphicsSettings` con cuatro preajustes y ajuste fino por eje, más
panel en la UI y persistencia.

| | Bajo | Medio | **Alto** (1070@60) | Ultra |
|---|---|---|---|---|
| Capas de terreno | 2 | 3 | 4 | 4 |
| Muestreo | 1 plano | biplanar | biplanar | triplanar |
| Normales de terreno | no | sí | sí | sí |
| ORM | constantes | rugosidad | completo | completo |
| Resolución de textura | 1K | 1K | 2K | 2K |
| Sombras | 2 splits / 2048 | 3 / 2048 | 4 / 4096 suave | 4 / 4096 suave alto |
| SDFGI | no | no | no | sí |
| SSAO / SSIL | no | SSAO | SSAO | SSAO + SSIL |
| Niebla volumétrica | no | no | sí | sí |
| Instancias de vegetación | 25 % | 50 % | 100 % | 100 %, más lejos |
| Personajes en LOD0 | 20 m | 40 m | 80 m | 120 m |
| Escalado 3D | FSR2 0,6 | FSR2 0,77 | 1,0 | 1,0 |
| Anisotropía | 2 | 4 | 8 | 16 |

Dos avisos honestos:

- **SDFGI: medido, y fuera de todos los tiers (5-sep-2026).** Con
  `scripts/tests/ReboteProbe.gd`, sitio 56, misma vista y luz de mediodía:

  | | GPU | VRAM |
  |---|---|---|
  | apagado | 27,4 ms | 876 MB |
  | celda 0,2 m (lo que había) | +2,9 | |
  | celda 1,5 m | +4,2 | |
  | celda 4,0 m | +5,9 | **1369 MB** |

  Y lo que compra, medido con `scripts/tools/LuzProbe.gd`, que da la razón entre
  una zona en sombra y otra al sol: **17,1 % apagado y 16,8 % encendido**. O sea
  nada, o un pelo peor. No entra ni en Ultra.

  El camino hasta ahí fue un error mío que conviene dejar escrito: di por hecho
  que las laderas en sombra salían «casi negras» y monté cinco hipótesis
  —`ssao_intensity`, `ambient_light_energy`, `tonemap_white`, WeatherView pisando
  el entorno, y falta de luz de rebote—. Las cinco falsas. Cuando por fin medí
  los píxeles en vez de mirarlos, la razón sombra/sol daba **18,5 %**, que es
  justo el rango de una foto de campo a pleno sol (15-20 %). **Las sombras
  estaban bien.** Lo que engañaba es el valor absoluto: 0,043 es muy oscuro, y
  contra un 0,23 al lado el ojo se adapta a lo claro y lee lo oscuro como negro.
  Una fotografía real se comporta igual.
- El escalado con FSR2 en Bajo es lo que hará que esto corra en una integrada.
  Sin él no hay tier bajo que valga.

---

## 7. Fases, con criterio de aceptación

**G0 · Medir. — HECHO (5-sep-2026).** No hizo falta ampliar `GpuProfile.gd`:
ya medía todo lo que hacía falta y sólo había que ejecutarlo. Resultados y
conclusiones en §1. *Criterio cumplido: 18,6 ms de los 28,7 de GPU son el
shader del terreno, y la geometría cuesta 0,3.*

**G1 · Reforma del shader — en curso.** Se está haciendo palanca a palanca,
midiendo cada una. Coste del shader del terreno:

| Palanca | ms | Estado |
|---|---|---|
| — (original) | 18,6 | |
| **A ·** texturas a BC7 | 15,5 | aplicada (`862eaa7`) |
| **C ·** descarte de planos con reparto de peso | **13,0** | aplicada (`5a634fd`) |
| **B ·** sin anisotropía | *8,5* | **no** aplicada, ver abajo |

*Criterio: el terreno se ve igual que hoy y cuesta ≤10 ms.*

Dos correcciones a lo que este documento decía antes:

- **El §2.4 proponía algo que ya existía.** El salto por material y por plano
  estaban implementados; se escribió habiendo leído los uniforms y no el cuerpo
  del fragmento. Lo que faltaba no era saltar, sino **poder saltar
  agresivamente sin oscurecer**, y eso lo resuelve repartir el peso del plano
  descartado entre los que quedan.
- **El corte tiene que ser suave.** Con `step` salían manchas planas de borde
  duro por toda la ladera: el umbral se dibujaba en el monte como una curva de
  nivel. Con `smoothstep` desaparece y casi no cuesta.

Y una advertencia sobre la palanca B: **está medida contra un espantapájaros.**
La anisotropía vale 4,5 ms y hoy no compra nada porque las texturas son ruido
procedural de baja frecuencia a 512²; no hay detalle fino que conservar. Con
fotogrametría sí lo habrá. Se decide después de G2, y su sitio es el panel de
tiers.

**Sobre medir.** Comparar entre ejecuciones no vale para deltas de 1 a 3 ms: hay
más de dos milisegundos de deriva entre tandas —una llegó a dar 48 ms de línea
base con las de al lado en 23—. `scripts/tests/CorteProbe.gd` alterna los
valores dentro de una misma ejecución, da varias vueltas e informa del mínimo;
así la repetibilidad es de ±0,1 ms.

**G2 · Ingesta PBR.** Script de descarga y empaquetado (ORM + altura); las ocho
capas dentro, y el sembrado de cantos y bloques en `MultiMesh` sobre roquedo y
barras de río. *Criterio: a 100 m se distingue roquedo de pedrera de cantos de
río, y el roquedo tiene silueta propia, no sólo dibujo.*

**G3 · Calibrado.** Bandas de altura y pendiente para ocho capas, y paleta de
estepa fría. *Criterio: el valle no parece un prado cántabro de hoy.*
~~El A/B de `detail_amplitude`~~ — hecho el 5-sep-2026, ver §8.

**G4 · Cuerpo y escala.** Seis bases MPFB2, rig, import, fuera las cápsulas.
*Criterio: la banda son personas de 1,70 m y la cámara sigue siendo usable.*

**G5 · Locomoción.** Los 15 clips de estado, atados a `Inhabitant.State`.
*Criterio: se distingue quien va, quien vuelve cargado y quien duerme.*

**G6 · Trabajo.** Los 20 loops de especialidad, con el apero en la mano.
*Criterio: **se sabe qué está haciendo cada uno sin abrir un panel**. Este es el
criterio que justifica el revamp entero.*

**G7 · Ropa paleolítica.** Sistema de slots y el set del Magdaleniense.
*Criterio: cambiar de época cambia la ropa sin tocar el esqueleto.*

**G8 · Panel de gráficos.** `GraphicsSettings`, UI y persistencia.
*Criterio: Alto da 60 FPS en la 1070; Bajo da 60 en una integrada.*

### Fuera de este plan

Vegetación nueva, edificios y cabañas, agua avanzada, clima visible y ciclo
día/noche. Cada uno es su propio trabajo, y meterlos aquí es exactamente cómo un
revamp se convierte en un proyecto que no termina.

---

## 8. Riesgos

**Los 35 clips.** Es la partida cara, y donde esto puede morir a medias dejando
personas realistas en pose T. Mitigación: G5 va antes que G6, y G6 se entrega
**por oficios completos** —caza entera, luego ribera entera—, de forma que
cortar por cualquier punto deje algo coherente.

**El hueco de 1 a 5 m.** Con el MDT05 del IGN el relieve es real hasta los 5 m
(§1), pero una textura de fotogrametría lleva pistas de escala hasta el tamaño
de su tesela: un bloque de caliza en el albedo *mide* algo, y por debajo de 5 m
la silueta no lo respalda. Hoy no se nota porque las texturas procedurales son
ruido de bajo contraste y no afirman nada; con material escaneado, sí.

Dos mitigaciones, y **ninguna es ruido**:

- **Parallax occlusion** desde el mapa de altura del set PBR —que hoy ni se
  descarga, porque sólo se usan albedo y normal—. Cubre de 0 a 1 m, en el
  shader, y es barato. Entra con G1.
- **Cantos y bloques dispersos en `MultiMesh`** sobre la banda de roquedo y las
  barras de río. Cubre de 1 a 5 m con silueta y sombra reales, que es lo que el
  shader no puede fingir. El patrón ya está escrito en `ResourceProps.gd`.

**`detail_amplitude`: resuelto (5-sep-2026).** Medido con
`scripts/tests/DetalleProbe.gd` sobre el sitio 56:

| Amplitud | Altura RMS / máx | Casillas que pasan a pared | Ritmo de marcha |
|---|---|---|---|
| 1,5 (la que había) | 0,64 m / 2,37 m | 24 de 9216 (0,3 %) | 100,4 % |
| 3,0 | 1,28 m / 4,73 m | 54 (0,6 %) | 101,3 % |

O sea: **era un problema de vista, no de juego.** A la simulación no le afecta
—la perturbación máxima de pendiente es 0,27 contra un límite de escalada de
1,2—, pero en pantalla el monte se cubre de bultos redondos que se comen las
crestas y las vaguadas del LiDAR.

La causa es que el parámetro es **anterior al dato**: los `.uid` fechan
`DEMImporter` a las 17:33 del 2-sep y `IGNImporter` a las 23:24 del mismo día, y
el comentario que justifica el detalle está escrito contra los 13,9 m del
terrarium. Seis horas después llegó el MDT05 y nadie volvió a mirarlo. Y
`_safe_detail_frequency()` fuerza el ruido a ser más **grueso** que la malla, así
que nunca pudo añadir detalle fino: en el terrarium rompía la lisura de la
interpolación —un defecto real allí— y sobre LiDAR sólo degrada.

Arreglado en `_effective_detail_amplitude()`: la amplitud sale de la razón entre
el paso del dato y el de la malla, así que se apaga sola donde el dato ya sabe
la verdad y sigue entrando entera donde no.

```
IGN MDT05        5,00 / 4,97 =  1,01  ->  amplitud 0,009
terrarium z13   13,91 / 4,97 =  2,80  ->  amplitud 1,500
terrarium z10  111,00 / 4,97 = 22,33  ->  amplitud 1,500
```

`detail_amplitude` pasa a ser el **techo** —cuánto se añade como mucho— y el dato
decide cuánto de eso hace falta.

**Peso del repositorio.** 24 texturas fuente. Fuera de git: se versiona el
script de ingesta, no el PNG.

**Mixamo sin mantenimiento.** Bajar hoy todo lo que se vaya a usar.

---

## Fuentes

- [ambientCG](https://ambientcg.com/) — materiales PBR CC0, con API pública
- [Poly Haven · Ground & Terrain](https://polyhaven.com/textures/ground-terrain) — texturas CC0
- [Quixel Megascans en Fab](https://www.fab.com/sellers/Quixel%20Megascans) — de pago desde 2025
- [MPFB2](https://static.makehumancommunity.org/mpfb.html) · [licencia](https://github.com/makehumancommunity/mpfb2/blob/master/LICENSE.md) — generador de humanos, salida CC0
- [Mixamo FAQ](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) — animación gratuita, sin royalties, no redistribuible en crudo
- [AnimatedMultimeshInstance3D](https://github.com/shadecoredev/AnimatedMultimeshInstance3D) — multitudes en Godot, para más adelante
