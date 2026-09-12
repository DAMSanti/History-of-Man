# Los gráficos

Cómo se dibuja este juego, qué cuesta y en qué se gasta el presupuesto de
fotograma. **Sólo lo visual**: nada de aquí cambia una mecánica.

Las decisiones que ordenan todo lo demás, tomadas antes de nada: **escala humana
real (1,70 m)**, **realismo legible** —material escaneado, contraste ajustado a
distancia de gestión— y **objetivo Alto = GTX 1070 a 1080p/60**, con Ultra por
encima y Bajo por debajo.

> Este documento absorbió el 2026-09-12 lo vivo del antiguo `REVAMP_GRAFICO.md`.
> El plan por fases con su historial, sus commits y sus tres correcciones de
> medida está en [archivo/REVAMP_GRAFICO.md](archivo/REVAMP_GRAFICO.md); lo que
> quede pendiente vive en [ROADMAP.md](ROADMAP.md).

---

## Dónde mirar

| Si buscas… | Ve a |
|---|---|
| **Por qué lo primero no es añadir texturas**, y el presupuesto de fotograma | **§1** |
| Hasta dónde llega el DEM y dónde empieza la invención | §2 |
| Cómo se baja el coste del shader sin perder capas | §3 |
| El catálogo de texturas, su origen CC0 y por qué 2K y no 4K | §4 |
| Cuerpos, escala real, ropa por época y LOD | §5 |
| **Los ~35 clips, y por qué son la partida más cara** | **§6** |
| Los cuatro niveles de gráficos, y por qué SDFGI está fuera de todos | §7 |
| **Las tres veces que la medida estaba mal antes que el juego** | **§8** |
| Qué queda fuera a propósito | §9 |

Lo que falta por hacer está en [ROADMAP.md](ROADMAP.md) «En curso» → Los gráficos.

---

## 1. La cifra que manda

```
A 1080p/60 el fotograma entero son 16,6 ms.
El terreno solo costaba 25.
```

De ahí sale todo el orden de trabajo, y es contraintuitivo:

> **El primer trabajo de un revamp gráfico aquí no es añadir texturas. Es que el
> terreno deje de costar 25 ms.** Meter ORM y ocho capas encima de la
> arquitectura vieja habría bajado el juego de 28 FPS a menos de 15.

Medido con `scripts/tests/GpuProfile.gd`: de 28,7 ms de GPU, **18,6 eran el
shader del terreno** y la geometría costaba 0,3. No era la malla: era el
muestreo.

### Presupuesto de fotograma (Alto, 1070 @ 1080p)

| Partida | ms |
|---|---|
| Terreno opaco | 6,0 |
| Vegetación y props (MultiMesh) | 3,0 |
| Personajes | 2,0 |
| Sombras direccionales | 2,5 |
| Entorno y post (niebla, SSAO, tonemap) | 2,0 |
| UI y resto | 1,0 |
| **Total** | **16,5** |

**Nada entra en el juego sin caber en su casilla.**

---

## 2. Hasta dónde llega el dato

Importa saberlo, porque marca dónde la textura empieza a afirmar más de lo que
la geometría sostiene:

| Capa | Origen | Paso del dato | Paso de la malla |
|---|---|---|---|
| Regional | terrarium zoom 10 | 111 m | 100 m |
| **Local (normal)** | **IGN MDT05, LiDAR** | **5 m** | 4 m |
| Local (reserva) | terrarium zoom 13 | 13,9 m | 4 m |

`use_ign_elevation` viene a `true`, así que en Cantabria lo que se juega es
**MDT05 del IGN a 5 m**; el terrarium sólo entra fuera de España o si el servicio
no responde.

> **Corrección al ROADMAP.** Decía que «el DEM tiene una muestra cada 14 m; por
> debajo de esa escala todo lo que se ve es invención». Con dato a 5 m y
> vértices a 4 m la interpolación es casi 1:1. **El relieve es real hasta los
> 5 m**, y el hueco donde hay que inventar es sólo el tramo de **1 a 5 m** — que
> es estrecho, y se rellena con parallax y geometría dispersa, **no con ruido**.

---

## 3. El terreno: arquitectura antes que arte

El truco central es que **más capas y más mapas no tienen por qué costar más
muestreos**, porque el coste no lo fija cuántas capas existen sino cuántas están
activas en un píxel. Con blending por altura y pendiente, en cualquier píxel hay
como mucho **dos** capas con peso real.

| | Antes | Con la reforma |
|---|---|---|
| Ladera (2 capas activas, biplanar) | 24 muestreos | **12** |
| Valle llano (2 capas, un plano) | 24 | **6** |
| Mapas por capa | 2 | **3** (albedo, normal, ORM) |

**Más información PBR por la mitad de coste.** Ése es el argumento entero.

Las cuatro piezas:

1. **`Texture2DArray` en vez de un sampler por capa.** Ocho capas pasan a ser
   tres arrays en vez de 24 uniforms, y añadir una capa deja de tocar el shader.
2. **Biplanar en vez de triplanar.** El triplanar mezcla los tres planos
   siempre; el biplanar descarta el de menor peso. Un tercio menos de muestreos
   y la diferencia no se ve en terreno natural.
3. **Camino de un solo plano en terreno llano.** Si `abs(normal.y) > 0.98` —la
   mayor parte de un valle— basta el plano Y, y la rama es coherente por warp.
4. **Salto de capas por peso.** `weight_cutoff` existe pero sólo recorta la
   contribución; tiene que **evitar el muestreo**.

Y la compresión: VRAM Compressed con mipmaps —BC7 para albedo y ORM, BC5 para
normal—. Las texturas eran `ImageTexture` sin comprimir, o sea puro ancho de
banda.

**Sobre el addon Terrain3D: no migrar.** Es bueno, pero la malla de aquí no es un
clipmap: sale de `HeightmapData` del DEM real, con máscara de región, ríos por
vértice y un contorno propio (`TerrainSurround`). El shader propio ya tiene
resueltas las partes específicas del proyecto; lo que le falta es arquitectura
de muestreo, que es mucho menos trabajo que la migración.

---

## 4. Las texturas

Ocho capas, derivadas de los biomas que pide la primera época:

| Capa | Qué es | Por qué está |
|---|---|---|
| Pradera / estepa | herbazal frío | El Magdaleniense cantábrico es **estepa fría**, no el prado verde de hoy |
| Suelo de bosque | hojarasca y humus | Bosque de refugio en los valles |
| Roquedo calizo | caliza gris, karst | Cantabria es caliza. Nada de granito |
| Pedrera / canchal | derrubio de ladera | La transición roquedo→suelo |
| Cantos de río | cuarcita rodada | **La materia prima del juego.** Tiene que leerse desde la cámara |
| Arena de playa | | Marisqueo y costa |
| Limo de marisma | fango de estuario | Estuario, y el sitio del conchero |
| Nieve | | Alta cota |

**Origen: CC0, y scriptable.** [ambientCG](https://ambientcg.com/) expone una API
JSON pública y [Poly Haven](https://polyhaven.com/textures) cubre los huecos.
Megascans ya no es gratis desde 2025, así que queda como recurso de pago puntual
si alguna capa no aparece en CC0 — el limo de marisma es la que más papeletas
tiene.

**Ingesta reproducible** (`tools/TerrainTextureIngest.gd`): llama a la API,
descarga, **empaqueta en un solo RGBA** (AO→R, rugosidad→G, metálico→B,
**altura→A**), reescala y escribe en `textures/terrain/`. Lo que se versiona es
el script y el `.import`, no dos gigas de PNG. El canal de altura no es relleno:
BC7 trae alfa sin coste extra y alimenta el parallax que tapa el hueco de escala
del §2.

**Resolución: 2K, y no más.** A la distancia mínima de cámara (~30 m) 1920 px
cubren unos 30 m de suelo, o sea 64 px/m; una textura 2K con tesela de 4 m da
512 px/m. **Ir a 4K es VRAM tirada para un detalle que no cabe en pantalla.**
Ocho capas × 3 mapas × 2K comprimido ≈ 130 MB de VRAM con mipmaps.

**Anti-repetición:** `macro_influence` ya existe; la rotación estocástica de
tesela en Alto y Ultra es lo que rompe la cuadrícula de verdad.

---

## 5. Las personas

**Escala real, 1,70 m.** La legibilidad que daba la cápsula de 3,2 m tiene que
darla el tope de zoom cercano y la silueta a distancia.

**Cuerpo base: MPFB2** (sucesor de MakeHuman). Código GPLv3, pero **los assets y
lo que generas son CC0**. Encaja exacto con lo que el código ya modela: seis
cuerpos base —mujer/hombre × niño/adulto/anciano, que son `Inhabitant.Sex` ×
`Inhabitant.Age`— con **topología compartida**, así que una prenda vale para
todos.

**Rig:** Rigify → glTF → esqueleto humanoide de Godot, con retargeting por
`SkeletonProfileHumanoid`.

**Ropa por época: geometría, no textura.** Slots de cabeza, torso, piernas, pies
y accesorio en mano. Para la primera época basta **un set**: piel cosida,
capucha, calzado de piel y adornos de concha y hueso, todo atestiguado en el
Magdaleniense cantábrico.

**LOD:** LOD0 ~6k triángulos hasta media distancia, LOD1 ~2k, LOD2 silueta.

**Veinticinco personas con `Skeleton3D` y `AnimationTree` es asumible.** La
técnica de multitudes —animación horneada a textura de vértices sobre
`MultiMesh`— resuelve cientos de personajes, y por eso queda **anotada para
épocas tardías, no construida ahora**: hacerla hoy sería pagar complejidad por un
problema que no se tiene.

---

## 6. Las animaciones: el catálogo sale del código

**La máquina de estados ya está escrita.** `Inhabitant.State` dice en qué
situación está cada persona y `Profession.Speciality` qué está haciendo. La
animación se engancha ahí y no hay que inventar nada.

**Locomoción y estado — 15 clips.** Dormir, ir, buscar, trabajar, volver
cargado, comer, ocioso, reconocer; más vadear (`Traversal`), trepar (`Ascent`),
cojear y herido (`Mishap`) y cargar con la cría. Casi todo genérico, y se
resuelve retargeteando de Mixamo. **Aviso: Adobe lo describe como no mantenido,
así que hay que bajar de una vez todo lo que se vaya a usar.**

**Trabajo — 20 clips, y éstos hay que animarlos a mano.** Ninguna biblioteca
genérica tiene «tallar cuarcita». Uno por `Profession.Speciality`, bucles de 2 a
4 segundos:

| Oficio | Clips |
|---|---|
| Manufactura | talla (percusión sentado), asta (ranurar con buril), peletería (raspar en bastidor), cordelería (trenzar) |
| Caza | montar lazo agachado, acecho y lanzamiento, atlatl (cargar y lanzar) |
| Ribera | marisqueo agachado con cesto, arponeo desde la orilla, remar |
| Recolección | coger de mata, hacer y cargar el haz de leña, recoger cantos |
| Exploración | marcha con carga, trepar |
| Hogar | avivar el fuego, cocinar, cargar el crío, enseñar |

**~35 clips, y es la partida más cara del revamp entero**: más que las texturas y
los modelos juntos. Es también donde esto puede morir a medias, dejando personas
realistas en pose T — por eso se entrega **por oficios completos**, caza entera y
luego ribera entera, no treinta y cinco clips a medias.

Y un `BoneAttachment3D` en la mano para el apero: sin eso, arponear y forrajear
se leen igual.

---

## 7. Niveles de gráficos

| | Bajo | Medio | **Alto** (1070@60) | Ultra |
|---|---|---|---|---|
| Capas de terreno | 2 | 3 | 4 | 4 |
| Muestreo | 1 plano | biplanar | biplanar | triplanar |
| Normales de terreno | no | sí | sí | sí |
| ORM | constantes | rugosidad | completo | completo |
| Resolución de textura | 1K | 1K | 2K | 2K |
| Sombras | 2 splits / 2048 | 3 / 2048 | 4 / 4096 suave | 4 / 4096 suave alto |
| SDFGI | no | no | no | **no** |
| SSAO / SSIL | no | SSAO | SSAO | SSAO + SSIL |
| Niebla volumétrica | no | no | sí | sí |
| Instancias de vegetación | 25 % | 50 % | 100 % | 100 %, más lejos |
| Personajes en LOD0 | 20 m | 40 m | 80 m | 120 m |
| Escalado 3D | FSR2 0,6 | FSR2 0,77 | 1,0 | 1,0 |
| Anisotropía | 2 | 4 | 8 | 16 |

El escalado con FSR2 en Bajo es lo que hará que esto corra en una integrada. Sin
él no hay tier bajo que valga.

### SDFGI: medido, y fuera de todos los niveles

No es una opinión de rendimiento, es una medida (`ReboteProbe.gd`, sitio 56,
misma vista y luz de mediodía):

| | GPU | VRAM |
|---|---|---|
| apagado | 27,4 ms | 876 MB |
| celda 0,2 m | +2,9 | |
| celda 1,5 m | +4,2 | |
| celda 4,0 m | +5,9 | **1369 MB** |

Y lo que compra, medido con `LuzProbe.gd` —la razón entre una zona en sombra y
otra al sol—: **17,1 % apagado y 16,8 % encendido.** O sea nada, o un pelo peor.
**No entra ni en Ultra.**

---

## 8. La lección de método, que vale más que cualquier cifra de aquí

Esta parte del proyecto se equivocó **dos veces seguidas** sobre lo mismo, y las
dos veces el fallo fue del instrumento, no del juego. Está escrito porque es el
error que más fácil se repite.

**Primer intento.** La queja era «las laderas en sombra salen casi negras». Se
montaron cinco hipótesis —`ssao_intensity`, `ambient_light_energy`,
`tonemap_white`, `WeatherView` pisando el entorno, y falta de luz de rebote— y
**las cinco eran falsas**. Al medir los píxeles en vez de mirarlos, la razón
sombra/sol daba 18,5 %, que es el rango de una foto de campo a pleno sol. La
conclusión fue: las sombras están bien, lo que engaña es el valor absoluto.

**Segundo intento: eso también era falso, y el error era del método.**
`LuzProbe` compara dos **rectángulos fijos** de una captura, uno haciendo de
sombra y otro de sol. El que hacía de sombra **no lo estaba**: era terreno al sol
de albedo oscuro. Y con rectángulos a mano hay un problema de fondo — a otra hora
la sombra está en otro sitio, así que la medida no se puede repetir a lo largo
del día. `SombraDiaProbe.gd` mide sin depender del encuadre: fotografía la misma
vista **con el sol y sin él**, y compara.

**Y una tercera, de higiene:** durante buena parte de una sesión hubo **otra
instancia de Godot con el juego abierto**, así que la carga de fondo variaba
entre ejecuciones. Eso invalidó todas las medidas tomadas comparando tandas
distintas, y explica una línea base de 48 ms con las de al lado en 23 que se
achacó al reloj de la GPU.

Las tres reglas que salen de ahí:

1. **Medir los píxeles, no mirarlos.** El ojo se adapta y miente por contraste.
2. **Una medida que depende del encuadre no es una medida**, porque no se puede
   repetir.
3. **Una sola instancia de Godot.** Es la misma regla del turno de
   [AGENTES.md](AGENTES.md) §3, y aquí costó una sesión entera de cifras
   inservibles.

---

## 9. Fuera de alcance

Edificios y cabañas, agua avanzada, clima visible y ciclo día/noche. Cada uno es
su propio trabajo, **y meterlos aquí es exactamente cómo un revamp se convierte
en un proyecto que no termina**.
