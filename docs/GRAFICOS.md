# Los gráficos

Cómo se dibuja este juego, qué cuesta y en qué se gasta el presupuesto de
fotograma. **Sólo lo visual**: nada de aquí cambia una mecánica.

Las decisiones que ordenan todo lo demás, tomadas antes de nada: **escala humana
real (1,70 m)**, **realismo legible** —material escaneado, contraste ajustado a
distancia de gestión— y **objetivo Medio = GTX 1070 a 1080p/60**, con Alto y
Ultra por encima y Bajo por debajo. *(Decía «Alto = 1070» hasta el 2026-09-14: al
planear la configuración, el usuario puso ese objetivo en Medio, dejó Alto por
encima y **Ultra sin límite**. Ver §7.)*

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
| La cámara, las obras del abrigo apoyadas en el suelo y los alfileres | §4.1 |
| Cuerpos, escala real, ropa por época y LOD | §5 |
| **Los ~35 clips, y por qué son la partida más cara** | **§6** |
| Los cuatro niveles de gráficos, y por qué SDFGI está fuera de todos | §7 |
| **El bosque: árboles 3D de cerca, impostores de lejos, sin aros** (spec) | §7.1 |
| La sala de la cueva y la pared pintada (spec en SISTEMAS §13) | §7.2 |
| **Las tres veces que la medida estaba mal antes que el juego** | **§8** |
| Qué queda fuera a propósito | §9 |

Lo que falta por hacer está en [ROADMAP.md](ROADMAP.md) «En curso» → Los gráficos.

> **Spec abierta (2026-09-13)**, en [EPOCA_01](EPOCA_01_PALEOLITICO.md) §10.1 →
> Tanda 4, con tres cosas que se ven:
>
> - **La cueva, como una cueva en la pared** y no un agujero negro con dos
>   piedras, visible a la distancia de gestión. Y ninguna boca de ningún mapa en
>   el agua o donde no se llega.
> - **Humo** en toda hoguera, hogar o fuego, que se va cuando el fuego se apaga.
> - **La sepultura sobre el terreno.**
>
> Ninguna puede empeorar el fotograma de forma medible.

> **La cueva, hecha (2026-09-13). Es un AGUJERO DEL TERRENO, no una pieza
> encima.** Lo dijo el usuario después de tumbar, una a una, una visera de
> caliza, una cámara abovedada y un túnel con marco de bloques: «el agujero será
> real, en el propio terreno, abierto, a una cueva; el terreno se abre y hace un
> agujero, y alrededor de ese agujero se pone el elemento de las piedras».
>
> Cómo está hecho, de dentro afuera:
>
> - **La sima.** El relieve tiene un punto cada ~5 m, así que un agujero de dos
>   metros no le cabe: sale cuadrado y del tamaño de la rejilla. Por eso
>   `MallaDelTerreno._construir_simas` **quita el ruedo de rejilla** alrededor de
>   cada boca y cose ahí un embudo circular fino con su pozo, con el material del
>   propio terreno. La boca mide **2 m** o algo más en las cuevas grandes
>   (`CaveMouth.hueco_de`), no es redonda —el radio se mueve con el ángulo, con
>   ruido fijo por posición— y el pozo **cae con perfil logarítmico**, como un
>   embudo de gravedad, hasta 50 m. La roca de dentro es la del mapa; la
>   oscuridad la cierra una capa negra que se vuelve opaca a los 6 m, para que la
>   boca no pase de suelo a negro de golpe.
> - **El techo de roca.** `CaveMouth` pone **una sola pieza en herradura**
>   —`_techo`— que cubre el agujero por el lado de la pendiente y por los
>   costados y deja **libre un vano de 110°** ladera abajo: la entrada. Vuela
>   sobre el hueco, cruza por encima en el fondo, sube en crestones, tiene
>   grueso —se ve el canto desde el vano— y se hunde en la tierra por fuera.
>   Lleva la capa de roquedo calizo del terreno (`Rock030`) por triplanar.
> - **Nada más.** Ni cantos sueltos, ni visera, ni cámara: el usuario tumbó las
>   tres cosas.
>
> **Tres trampas que costaron una captura cada una** y conviene no repetir: el
> parche del terreno necesita **la normal y la tangente del campo de alturas**,
> no las suyas geométricas —con las de la geometría el shader lo pintaba con otra
> luz y dejaba un cerco oscuro de veinte metros—; la malla de la roca **no lleva
> tangentes**, así que no puede llevar mapa de normales —lo pintaba negro—; y la
> caché del terreno guarda la malla ya recortada, así que **las reglas de la sima
> van en su clave** (`TerrainGenerator.SIMA_REGLAS`) o se carga la de antes.
> **Fotograma sin medir.**

> **El humo (2026-09-13)**: `Bonfire._build_humo`, partículas en la GPU que
> sólo salen mientras el fuego arde. Medido en `HumoCaptura`: el fotograma no
> cambia (56,11 ms con y sin humo, siete fuegos, en la misma corrida).

> **La sepultura sobre el terreno (2026-09-13)**: `SepulturasView`, un túmulo
> de piedras con la roca del mapa, y una losa de ocre encima si hubo ajuar.
> Captura en `SepulturaCaptura.gd`.

> **Y un claro de 25 m alrededor de cada boca de cueva** (2026-09-13,
> `/depurar`). El bosque se sembraba por ruido y sólo esquivaba el agua, así que
> plantaba pinos encima de la boca y de las obras de la campa. Ahora
> `Forest.en_un_claro` descarta todo punto a menos de `RADIO_DEL_CLARO` en
> planta de **cualquier** boca del mapa —la de la banda y las demás—, decidido
> por el usuario.

> **El cielo, hecho el 2026-09-13** (tanda 3, frente 16, ampliado por el
> usuario): `shaders/cielo.gdshader`. Un shader de cielo, sin geometría nueva ni
> texturas que cargar:
>
> - **Nubes** de ruido de valor en tres octavas, proyectadas sobre un plano alto
>   —se abren hacia el cenit y se apelotonan en el horizonte— y movidas por el
>   ~~reloj de pared: son vista, no partida, y acelerar la noche no las pone a
>   correr como en una película~~. **Desde el 2026-09-14, con el reloj del
>   juego**, decisión del usuario: «deben quedar paradas si el tiempo está parado;
>   a x5, cinco veces más rápido; a x1, velocidad normal», y también en la noche
>   acelerada. `WorldEnvironmentSetup._mover_las_nubes` pasa la hora de la
>   partida al uniforme `viento_recorrido`; a x1 corren como corrían con `TIME`.
>   En el mapa regional, que no tiene reloj, quietas.
> - **Estrellas** que giran alrededor del **polo celeste**, que está a la altura
>   de la latitud y mirando al norte. Giran con el **ángulo horario del juego**,
>   no con el reloj de pared: que el cielo haya girado es parte de la hora que el
>   jugador lee.
> - **Sol y luna** en la dirección que da `SolarPosition` —la misma que orienta
>   las luces—, con la fase de la luna decidiendo cuánto luce.
> - **Volumétricas desde el 2026-09-14.** Las planas «parecían de Minecraft»:
>   el azar salía de `fract(sin(x) * 43758)` y la coordenada crecía con el reloj
>   y con `1/altura`, así que el seno perdía decimales y celdas enteras daban el
>   mismo valor. Ahora son una marcha de 12 pasos por una capa de 1 400 a 2 600 m
>   con ruido 3D de octavas giradas y hash sin seno (`hash13`), una muestra hacia
>   el sol por paso —cara iluminada y panza oscura—, **a media resolución**
>   (`use_half_res_pass`). El viento no hace falta envolverlo: sin seno, el ruido no
>   pierde precisión hasta pasar del millón. El reflejo del cielo
>   (`AT_CUBEMAP_PASS`) y `pasos_de_nube = 0` usan las planas, con el mismo ruido.
>   **Coste medido con `NubesCaptura`, a 1920×1080 y alternando las dos en la
>   misma corrida: +0,31 y +0,33 ms de GPU** en dos corridas, dentro del tope de
>   1 ms que se acordó. A 3651×2054 fueron +2,77: escala con los píxeles.
> - **Cuánto tapan las nubes sale del tiempo que hace** (`NUBOSIDAD`), y con
>   ellas el color: la paleta de la escena es la de un día encapotado y se
>   mezcla con un azul limpio según lo despejado que esté.
>
> **Lo que se aprendió mirando las capturas**: el cielo ya existía —un
> `ProceduralSkyMaterial`— y el jugador decía que no había. Las dos razones:
> la cámara de gestión no lo mira (clampada a -10º) y el gris de la paleta no se
> lee como cielo. Lo primero se arregla subiendo el tope a -3º, decidido por el
> usuario.

> **Spec abierta (2026-09-13)**, en [EPOCA_01](EPOCA_01_PALEOLITICO.md) §10.1 →
> Tanda 3, con tres piezas que se ven:
>
> - **El cielo**, con nubes que se mueven y que cambia con la hora y la luz que
>   el juego ya lleva. Tiene que caber en el presupuesto de §1.
> - **La pasarela sobre el terreno**, visible a distancia de gestión y quitada
>   cuando la riada se la lleva.
> - **La expedición que se va andando** hasta el borde del mapa y vuelve por él.
>
> Ninguna cambia una mecánica. Las capturas necesitan ventana.

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

### Presupuesto de fotograma (Medio, 1070 @ 1080p)

*Era el de Alto hasta el 2026-09-14; ver §7.*

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

**En el mapa regional, las bandas de material cuentan desde el mar de la época**
(`cota_base` en `shaders/triplanar.gdshader`, que pone
`TerrainGenerator._apply_shader_height_setup`; 2026-09-14). El shader dividía la
cota por el techo y recortaba a cero lo negativo, así que con el mar a −120 m
**toda la plataforma emergida** —de −120 a 0— caía en la banda de orilla y salía
marrón. Ahora la playa es la franja de `RegionMap.shore_band_m` —**15 m**,
decisión del usuario: «playa fina y hierba»— sobre el agua, y por encima es
pradera y bosque como en tierra. En el valle `cota_base` es cero y nada cambia.
Visto con `RegionCaptura`.

**Y la plataforma tiene relieve** (`RelieveDeLaPlataforma`). La batimetría a 111 m
sale lisa, y con el mar a −120 m se veía una llanura sin un bulto.

> **Rehecho el 2026-09-14, con la queja repetida**: «en el mapa regional no se
> aprecia NADA de elevación en la plataforma emergida… quiero que tenga orografía
> como hoy la hay entre Santander y Torrelavega». La primera versión subía el fondo
> **saturando hacia la cota cero de hoy** —para no mover la costa actual—, así que
> las lomas se quedaban en 20-30 m sobre un mapa de 200 km: invisibles.
>
> Ahora **las alturas están medidas** en esa misma franja
> (43,33–43,48 N, 4,08–3,78 O; 28 637 celdas de tierra): p05 **3 m**, p25 **19**,
> p50 **48**, p75 **100**, p90 **159**, p99 **312**, máx **515**, y **22 m de
> desnivel por kilómetro** de mediana (86 en el décimo más quebrado). El ruido se
> mapea a esa escalera de percentiles, con onda de 2 km, así que la plataforma
> tiene la repartición de alturas de esa costa. Medido con la prueba: el mayor
> bulto sube **288 m** y más de mil celdas pasan de 100.
>
> **La costa no se mueve, por construcción**: sólo se sube lo que YA es tierra con
> **el mar de la época que se dibuja** —subir tierra la deja tierra—, y lo que está
> bajo el agua no se toca. Por eso el relieve depende del mar: `RegionMap` lo aplica
> con el de la partida —o con el de hoy si no hay partida, y entonces la plataforma
> sigue siendo fondo marino— y `HornearEras` hornea **cada época con el suyo**.
> Cambiar de época con la tecla E no rehace el relieve: es el de la época con la que
> se montó el mapa. Y **la orilla queda llana**: el relieve entra con una rampa de
> 600 m desde la costa, que es lo que deja sitio a la playa —decisión del usuario—.
>
> Visto en `PlataformaCaptura` (ventana, partida empezada y sin niebla).

Y deja escrita una trampa: `Resource.duplicate()` **no copia** `elevations`; la
copia y el recurso cacheado de `load()` compartían el array, y escribir en uno
escribía en el otro.

> **Spec (2026-09-14): la niebla del mapa regional.** El mecanismo —qué la
> levanta— está en [SISTEMAS.md](SISTEMAS.md) §4; aquí cómo se ve. Lo no
> descubierto se tapa con **una niebla opaca clara**, del color de una calima,
> no negra: se tiene que leer como «no se sabe», no como «no existe». Bajo ella
> **se intuye el perfil de la costa de la época** —un trazo tenue en el filo
> tierra-mar— para no perder la orientación, y **no se ven** sitios, ríos,
> frontera ni relieve. El borde entre lo visto y lo no visto se funde en unos
> cientos de metros, no corta a cuchillo.
>
> Criterios: al empezar la partida, en una captura del mapa regional con
> ventana, fuera del recuadro del primer campamento no hay píxel de sitio, río ni
> frontera, y el trazo de costa sí; tras una expedición, el pasillo recorrido se
> ve con su relieve. **Coste**: medido a 1080p en el mapa regional, alternando
> niebla sí y no en la misma corrida, **no más de 1 ms de GPU**. Fuera de alcance:
> nubes que se muevan en la niebla, y niebla en el valle más allá de la de su
> minimapa, que ya existe.

**Construida el 2026-09-14.** En `shaders/triplanar.gdshader`, un grupo `fog`
apagado en el valle: la textura de lo visto (`NieblaRegional`, una celda por celda
del relieve regional) mezcla hacia una calima clara `(0,80; 0,79; 0,74)`; el borde
se funde con cinco muestras a 300 m; el trazo de costa sale de la distancia de la
cota al mar de la época, con el grueso de `fwidth` de la cota para que mida lo
mismo en pantalla sea la ladera empinada o llana; y bajo la niebla la normal mira
al cielo y la oclusión se apaga, porque si no las laderas se leían a través. **El
mar y la frontera son mallas aparte** y no la leían: van con
`shaders/bajo_la_niebla.gdshader`, que tapa el mar y borra la frontera donde no se
ha visto. `RegionMap._poner_la_niebla` hace la textura y la rehace si la niebla
cambia con el mapa abierto; `NieblaRegional` lleva su imagen al día al levantar
para no recorrer 2,3 millones de celdas en cada jornada.

**Medido con `NieblaCaptura`** (ventana, 1920×1080): al empezar, sólo el recuadro
del primer campamento y el trazo de costa; tras un pasillo, su franja con relieve,
ríos y sitios. **GPU de render alternando niebla sí y no en la misma corrida,
mínimo de cuatro vueltas: +0,24, −0,02, +0,08, +0,11 y +0,06 ms** en cinco
corridas —ruido alrededor de cero—, dentro de 1 ms.

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

## 4.1. La cámara, y las obras del abrigo (2026-09-13)

**El punto de órbita va apoyado en el terreno** (`OrbitalCamera._apoyar_el_centro`).
Vivía a cota cero —nivel del mar— mientras el valle está a cientos de metros, y
eso rompía dos cosas a la vez: `orbit_distance` no era la distancia a lo que se
veía sino a un punto enterrado bajo el monte, así que **cada muesca de rueda
movía un 4,5 % de esa distancia enterrada** y de cerca eso es el encuadre
entero —«el zoom se vuelve más sensible cuanto más zoom haces»—; y la esfera de
giro tenía el centro bajo tierra, así que al orbitar el terreno se iba de la
pantalla en vez de girar sobre sí mismo. Apoyado, la distancia de órbita **es**
la distancia a lo que se mira, y se orbita el punto del centro de la pantalla.

**Y se baja hasta el suelo** (2026-09-14, «quiero poder hacer más zoom hasta
prácticamente estar sobre el terreno»). En el valle el tope pasa de unos 55 m de
órbita a **3,5 m** (`DemoMain.CAMARA_A_PIE_DE_TIERRA`), con el ojo como poco a
1,6 m del suelo —la altura de alguien de pie; eran 14— y el plano cercano a
0,1 m, que con la profundidad invertida de Godot 4.5 no arruina la precisión. La
muesca de abajo se ensancha a un 8 % para que el tramo nuevo no sean veinte
vueltas de rueda. Las ventanas que llevan la cámara a algo pinchado no bajan
hasta ahí: `OrbitalCamera.distancia_para_mirar`, 80 m como poco. El mapa
regional no cambia.

**Lo que la banda levanta, se ve** (`ObrasDelAbrigo`). Existía sólo la hoguera
(`HearthFire`); el secadero, el paraviento y el lavadero eran una casilla
marcada en un panel. Dónde va cada uno no es decoración: el secadero **junto a
la hoguera**, que es de donde saca el humo; el paraviento **en la boca de la
cueva**, que es el hueco que cierra; el lavadero **en el filo del agua**, que es
donde se remoja la bellota —y no en el punto de «orilla» que usa la banda para
llenar odres, que cuenta como orilla lo que tenga cauce a veinte metros—.

**Y cada cosa se apoya en su suelo, que en cuesta no es un punto.** Dos reglas,
y hacen falta las dos:

- `ObrasDelAbrigo.asentar` planta cada obra **tendida con la pendiente**: a la
  cota de su centro e inclinada con el plano que hace el terreno bajo su huella
  (`normal_del_suelo`, diferencias entre bordes opuestos). Es la tercera forma.
  Derecha y a la cota del centro se enterraba por arriba —la hoguera «medio
  metida en la tierra» del 2026-09-13—; apoyada en el techo de su huella dejó de
  enterrarse y **se puso a volar por abajo** —«los modelos están flotando; si hay
  pendiente, deben seguir la pendiente», 2026-09-14—. Inclinada, lo que sube por
  un lado baja por el otro. Vale para la hoguera, el secadero, el paraviento, el
  lavadero y cada leño del corro. `AbrigoProbe` imprime cada obra contra su suelo.
- `ObrasDelAbrigo.asiento_llano` busca **el rellano**: mira el desnivel de la
  huella en varios sitios alrededor y se queda con el menor. Lo usa la campa del
  abrigo (`sim.home_forecourt`), que es donde arde el hogar, se plantan los
  troncos y se junta la banda. Es lo que hace cualquiera antes de delimitar una
  fogata con piedras.

**Dónde va cada obra, desde el 2026-09-14** (petición del usuario, medido con
`AbrigoProbe` en el sitio 56):

| Obra | Dónde | Antes |
|---|---|---|
| Secadero | **a horcajadas del fuego**, las horquillas a `Bonfire.RING_RADIUS` + un palmo: 0,0 m | a 2,9 m a un lado |
| Paraviento | **a 3,5 m del centro del pozo**, mirando como la boca (el pozo mide 2–2,7 m de radio) | a 1,2 m del centro, encima del agujero; y luego a «5,5 m del borde», medido desde un borde de 7 m que no existe: 12,5 m del centro |
| Conchero | **a un lado de la boca, cuesta abajo**, 6 m más allá del filo (`DemoMain._sitio_del_conchero`): 7,8 m del borde | a 17 m del punto del emplazamiento, sin mirar la boca |

> **El paraviento se midió mal la primera vez, y fue el instrumento**:
> `CaveMouth.mouth_radius` vale 7 m fijos y no es el pozo —ése es `hueco_de`, de
> 2 a 2,7 m—; la sonda midió con él y dio por buenos 5,5 m que eran 12,5. El
> usuario lo vio a simple vista. Ahora se mide desde el centro, y `mouth_radius`
> dice en su comentario lo que es.

**La campa, en seco y allanada** (2026-09-14, «que las obras del hogar no se
puedan hacer en el río; si hace falta aplanar una zona contigua a las cuevas, se
hará»). La decide `Bocas.campa_de` al colocar las bocas, antes de excavar: ladera
abajo a 11,2 m, y si una explanada de 5 m ahí toca el agua, el punto seco más
cercano a ése hasta 24 m de la boca. `TerrainGenerator._apply_carvings` la allana
—plana en su 60 %, fundida hasta el borde— y `CaveMouth.forecourt_point` la usa.
`asiento_llano` tampoco elige ya un rellano mojado. `TestBocas`; sube
`Bocas.REGLAS` a 5, así que la malla cacheada del terreno se rehace.

**La loma del conchero va cosida al terreno** (`Conchero._malla_de_la_loma`):
una malla en anillos con cada vértice a la cota del suelo que tiene debajo más el
perfil del montón, y el borde cuatro centímetros enterrado. Era una media esfera
escalada, plana, y en la ladera volaba por el lado de abajo. Medido con el montón
en su máximo: loma entre −0,04 y +1,50 m sobre el suelo. Y se muda con la banda:
antes se quedaba en la primera cueva.

> Visto en la captura: con el montón al máximo (11 m de mancha) y la boca del
> sitio 56 dando al río, el borde de abajo del conchero llega cerca de la orilla.

**Y su textura dice de qué está hecho** (2026-09-14, «textura predominante del
material que lo forma: carne y huesos, cáscaras, conchas»): `Conchero.Familia`
—concha, cáscara, hueso— según `Desechos.dominante`, con una textura horneada en
CPU por familia —valvas en abanico, cascarilla menuda, astillas sobre tierra
oscura— proyectada desde el mundo sobre la loma. Era un tinte liso. `TestConchero`.

**Los troncos del corro** (`CorroDelHogar`) son cinco leños alrededor del fuego,
con dos sitios cada uno. La geometría vive en `sim/` y no en la vista porque la
preguntan dos: quien los planta y quien coloca a la gente en el abrigo. **No hay
clip de sentarse todavía** —ver §6, el catálogo de animaciones—, así que quien
coge sitio se pone en el tronco con la pose de reposo: se junta al fuego, no se
sienta. Cuando haya clip, sólo cambia `BandaCrowd.STATE_CLIP`.

**El alfiler es uno solo** (`Alfiler`). Estaba dentro de `ParajeMarkers`, y por
eso las bocas de cueva tenían marcador propio —un cono amarillo con un rótulo—
mientras parajes y cimas llevaban chapa con glifo. Ahora las tres piden el mismo
horneado y la cueva tiene su glifo (`MateriaIcon.Glyph.CUEVA`).

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

> **Esta tabla es el diseño de 2026-09-12, y la columna marcada 1070 es hoy
> Medio.** Lo que el juego aplica de verdad está en la tabla de debajo, «Los
> niveles que se eligen».

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

> **Spec (2026-09-14): los niveles se eligen.** Desde la ventana de
> configuración —[INTERFAZ.md](INTERFAZ.md) §8— el jugador elige uno de estos
> cuatro, o toca ajustes sueltos y queda en Personalizado. Dos cosas le pide eso
> a esta tabla, y son criterio:
>
> - **Que esté entera para lo que existe.** Faltan filas de lo que se añadió
>   después de escribirla —**nubes volumétricas**, sus pasos o apagadas, y la
>   **densidad de vegetación** donde hoy dice instancias—: cada una se añade con
>   su valor por nivel **medido**, no elegido a ojo.
> - **Que cada nivel diga lo que cuesta.** El tiempo de GPU de cada uno, a 1080p
>   y sobre la misma vista, con `GpuProfile`, dos corridas, escrito aquí debajo.
>   Hoy sólo Alto tiene presupuesto (§1).
>
> Una fila que no se pueda aplicar en caliente —que pida recargar la escena— se
> dice en la tabla: la configuración avisa de ella en vez de fingir que se
> aplicó.

El escalado con FSR2 en Bajo es lo que hará que esto corra en una integrada. Sin
él no hay tier bajo que valga.

### Los niveles que se eligen (construido el 2026-09-14)

Los aplica la ventana de configuración ([INTERFAZ.md](INTERFAZ.md) §8), y **la
tabla de verdad vive en el código**, en `Configuracion.NIVELES`: ésta la copia. Si
discreparan, gana el código.

**Decisiones del usuario (2026-09-14)**: **Medio es el de la 1070 a 60 fps**
—lo que el juego llevaba hasta ahora—, **Alto por encima**, **Ultra sin límite**
—cada ajuste a su máximo— y Bajo por debajo de Medio.

| Ajuste | Bajo | Medio | Alto | Ultra | ¿En caliente? |
|---|---|---|---|---|---|
| Sombras (cortes / atlas / suavizado) | 2 / 2048 / 2 | 4 / 4096 / 3 | 4 / 4096 / 4 | 4 / 8192 / 5 | sí |
| Oclusión ambiental | no | SSAO | SSAO | SSAO + SSIL | sí |
| Niebla volumétrica | no | sí | sí | sí | sí |
| Nubes volumétricas (pasos) | 0, planas | 12 | 20 | 32, el tope | sí |
| Escala de render | FSR2 0,6 | 1,0 | 1,0 | 1,0 | sí |
| Densidad de vegetación | 25 % | 100 % | 100 % | 100 % | **no: al montar el mapa** |
| Árboles (§7.1) | Mínimo, láminas | Medio, 3D de cerca | Alto | Ultra | **no: al montar el mapa** |
| Mapas de normales del terreno | no | sí | sí | sí | sí |
| ORM del terreno | no | sí | sí | sí | sí |
| **GPU a 1080p, dos corridas** | **7,8 ms** | **18,1 ms** | **21,0–21,2 ms** | **37,7–39,9 ms** | |

> **La fila de GPU es de antes de los árboles 3D** (2026-09-14), cuando todos los niveles
> pintaban el bosque de láminas. Lo que añade el bosque de cada escalón está medido
> aparte, como diferencia entre bosque encendido y apagado (§7.1, «Lo que cuesta»):
> en la vista de medida, Mínimo 1,9 ms, **Medio 3,4-3,5**, Alto 5,3-5,4 y Ultra 9,7.
> La fila entera no se ha vuelto a medir.

**Cómo se midió**: `GpuProfile` con `NIVELES=1`, el valle del sitio 56 con la
cámara de juego, a 1920×1080 en ventana, los cuatro niveles alternados dos veces
en la misma corrida y el mínimo; y la corrida entera dos veces. **En el equipo de
medida**, que no es una 1070: Medio no cabe en 16,6 ms en esta máquina, y eso no
dice nada de si cabe en la tarjeta del objetivo.

**Las nubes y la vegetación, con la medida delante**, sobre Medio:

| Nubes (pasos) | 0 | 6 | 12 | 20 | 32 |
|---|---|---|---|---|---|
| GPU | 18,09–18,13 | 18,30–18,35 | 18,25–18,55 | 18,46–18,71 | 18,67–18,84 |

| Vegetación | 25 % | 50 % | 100 % |
|---|---|---|---|
| GPU | 15,44–15,79 | 16,74–16,92 | 17,93–18,08 |
| Resembrar el bosque | 10,4–10,6 s | 10,2–10,3 s | 9,7–10,0 s |

Las nubes cuestan menos de un milisegundo de planas al tope, así que no son donde
se ahorra: cada nivel sube un escalón. La vegetación al 25 % ahorra 2,3–2,5 ms y
va en Bajo. **Y la vegetación no se aplica en caliente**: rehacer la siembra
para el fotograma unos diez segundos, así que la densidad entra al montar el
próximo mapa y la ventana lo dice (`Configuracion.AL_MONTAR_EL_MAPA`).

**Lo que de la tabla de diseño no es un ajuste**: capas de terreno, muestreo,
resolución de textura, personajes en LOD0 y anisotropía. Las cuatro primeras no
existen como interruptor, y la anisotropía es un ajuste del proyecto que sólo
entra al arrancar. La spec deja fuera los ajustes que no existen.

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

## 7.1. El bosque (spec, 2026-09-15)

**El problema, en tres quejas del usuario.** Todos los árboles son billboards o
tarjetas planas; **no tienen los colores que deberían para cada especie**; y hay
**«aros» entre los árboles y zonas en las que desaparecen**.

**Lo que hay hoy, comprobado en el código**, porque no es lo que dice su propio
comentario:

- **Lo que se monta de cerca son tres tarjetas cruzadas a 60°** con la foto del
  atlas, aunque la cabecera del bosque hable de «la malla de verdad con sus niveles
  de detalle».
  > *Decía «no hay ningún modelo de árbol en el repositorio», y era falso*
  > (corregido al planear, 2026-09-15). **Sí hay mallas**, en `models/props/props.res`,
  > y son las que fotografía `TreeAtlas`: planteles de abeto de Poly Haven para el
  > pino, y árboles genéricos —`island_tree_01`, `island_tree_02`, `tree_small_02`—
  > haciendo de roble, avellano y abedul, **que no son esas especies** (lo dice
  > `PropModels`). Medido: **de 157 000 a 1,3 millones de triángulos por árbol**, así
  > que no sirven de 3D de cerca, donde caben miles.
- De lejos, **un impostor de una foto**, con un **corte duro** a 350 m.
- La malla de cerca se monta **por bloques de 128 m, doce por fotograma**, y cada
  bloque se apaga con su propio margen de distancia.

De ahí salen, casi seguro, las dos cosas que se ven: **el aro** es el radio del
corte, donde un cuerpo se apaga y el otro se enciende sin coincidir; y **las zonas
que desaparecen** son bloques que la cámara ya ve y todavía no se han montado. Es
hipótesis: la spec pide medirlo, no darlo por hecho.

**Lo decidido, a preguntas del usuario:**

1. **Un selector nuevo, «Árboles», con cuatro escalones: Mínimo, Medio, Alto y
   Ultra.** **Mínimo es lo de hoy**, tal cual: son los gráficos mínimos. Cada nivel
   de gráficos elige su escalón, y el jugador puede tocarlo suelto como los demás
   ajustes (INTERFAZ §8.7).
2. **De cerca, árboles 3D de verdad**, con **modelos CC0 hechos para juego**, por
   especie, citados en CREDITOS.
3. **De lejos, impostores de varias vistas**, horneados del mismo modelo 3D: fotos
   desde muchos ángulos alrededor y desde arriba, con profundidad y normales, y se
   dibuja la del ángulo real de la cámara. **Que de lejos no se note que son
   billboards.**
4. **El color de cada especie se mide contra fotos de referencia**, por especie y
   estación.

#### Criterios de aceptación

**Mínimo es lo de hoy**

- Con el escalón Mínimo, una captura de la vista de medida de §7 es la de hoy: la
  diferencia media por píxel es del orden de la de dos capturas de hoy seguidas.
  `GpuProfile`: el mismo coste de GPU que hoy, **±0,3 ms**, que es la variación
  entre corridas medida en §7.
- **Los mismos árboles en los mismos sitios en los cuatro escalones**: el censo por
  especie y la posición de cada pie no cambian con el selector. Prueba.

**Sin aros ni huecos**

- **Quieto**: desde la cámara de juego, en las alturas y ángulos de
  `ArbolBordeProbe`, sobre un bosque seguido, **la cobertura de árbol por anillos de
  25 m de distancia a la cámara no tiene hueco en el relevo**: el anillo que
  contiene la distancia de relevo cae dentro del rango —mínimo a máximo— de los
  anillos que no la contienen. Sonda con ventana, en los cuatro escalones y
  **también en Mínimo**: el aro es un fallo de hoy y se arregla para todos.
- **Moviéndose**: en un barrido de 60 s de cámara a su velocidad máxima —paneo,
  órbita y zoom—, **ningún árbol desaparece y vuelve a aparecer**. Cero huecos,
  contados como grupos de píxeles que tenían árbol, dejan de tenerlo y lo recuperan
  en menos de 1 s, de más superficie que la copa de un árbol a esa distancia. En los
  cuatro escalones.

> **Cómo quedó (2026-09-15): cero aros y cero huecos en los cuatro escalones**, con
> `ArbolAroProbe` y `ArbolHuecoProbe` (con ventana, sobre el bloque más espeso del
> valle, en verano). Las dos pintan **sólo el bosque** sobre negro para contar árbol
> por píxel (`SoloElBosque`), y las dos cambiaron el criterio al medir, porque el
> escrito arriba no distinguía un aro del instrumento:
>
> - **El aro, contra una referencia.** En bruto, con la distancia del suelo detrás de
>   cada píxel, los anillos de cerca salían vacíos (0-18 %) —los árboles de cerca tapan
>   suelo más lejano— y el rango «mínimo a máximo» era tan ancho que ningún aro podía
>   caer fuera. Ahora cada pose se pinta también **sólo con impostores**, que cubren el
>   bosque sin relevo, y la cobertura de un anillo es qué parte de ese árbol sigue en el
>   de verdad; sin aro todos rondan el 100 %. Y como de cerca el impostor es una mancha
>   más gorda que la silueta 3D, cuenta como aro sólo si además **falta una mancha de al
>   menos una copa** (4 m, la más estrecha de los modelos) a la distancia del relevo.
> - **El hueco, contra la misma pose asentada.** Sesenta segundos de paneo con Mayús,
>   órbita y zoom, guardando pose y máscara tres veces por segundo; luego cada pose se
>   repite quieta con todo montado y se buscan manchas que faltaban en vivo. Comparar
>   cuadros seguidos habría contado el movimiento como huecos. Con `ROMPER=1` la sonda
>   esconde el 3D y cuenta huecos de 11 442 px: ve lo que tiene que ver.
> - Umbral de copa **nunca por debajo de la ventana de holgura** (49 px a 1/4): en
>   Mínimo una copa a 350 m son 3 px, y cuatro píxeles del perfil de una loma a
>   kilómetros contaban como hueco.
>
> **Y por el camino, un hueco de verdad.** El nodo de cada bloque 3D —y el de las
> láminas de cerca de Mínimo— estaba a cota cero, con los árboles subidos dentro del
> MultiMesh. Godot mide el rango de visibilidad desde el centro de la caja del nodo, así
> que un bloque del valle quedaba «lejos» por su altura y se apagaba entero antes del
> radio, con el impostor ya escondido: a 38 m de órbita y mirando bajo, el primer plano
> del 3D desaparecía (1 % de cobertura). A 4 m de órbita no se veía. Ahora el nodo va a
> la altura media de sus árboles (`Forest.centro_de`), con prueba en `TestBosque`.
> Dos tropiezos más del instrumento: la partida abre con los caducos pelados, y un
> abedul pelado en 3D contra su impostor medía «19 % de árbol» sin faltar nada —por eso
> en verano—; y la textura que se lee tras `process_frame` es la del cuadro anterior,
> con lo que cada máscara iba con la pose siguiente y los bordes de todos los árboles
> salían como huecos.

**De cerca, 3D**

- En Medio, Alto y Ultra, **todo árbol a menos de la distancia de relevo es un
  modelo 3D**, no una tarjeta. Prueba.
- **Una especie por modelo**: pino silvestre, abedul, roble y avellano, y el pino
  joven como un pino de menor porte. **Si no hay en CC0 un modelo de juego que
  sirva para alguna, se para y se pregunta**: ni se sustituye por otra especie en
  silencio ni se genera sin decirlo.
- Cada modelo **cita su origen y licencia en CREDITOS**. Prueba que cruza los
  modelos con CREDITOS.

**De lejos, que no se note**

- **Al orbitar, el árbol lejano cambia de silueta**: capturado un mismo árbol lejano
  desde ocho acimuts, las siluetas de vistas opuestas **no son la misma imagen
  reflejada ni la misma imagen**. Sonda.
- **Desde arriba se ve la copa**, no una foto de perfil aplanada: con la cámara
  por encima de 60° de inclinación, la silueta del impostor es la de la vista
  cenital. Sonda.
- **En el relevo no hay salto**: la diferencia de área de silueta y de color medio
  entre el último fotograma en 3D y el primero en impostor es **menor que la que hay
  hoy** entre la tarjeta cruzada y su impostor, medida con la misma sonda.
- **La luz casa**: al mover el sol del amanecer al mediodía, el lado iluminado del
  impostor es el mismo que el del modelo 3D a su lado. Sonda.

**El color de cada especie**

- **Por especie y estación, el color medio de copa y de tronco** —a la luz de
  mediodía de la vista de medida— cae a **ΔE ≤ 10** (CIELAB) del color medio de sus
  fotos de referencia. Diez es lo que separa «mismo color, se distingue» de
  «otro color»: **cifra de la spec, a confirmar con el usuario si al medir resulta
  demasiado estricta o demasiado floja**.
- **Las referencias se citan** —qué foto, de dónde, qué estación— en GRAFICOS o
  en CREDITOS. Y lo que distingue a cada especie de lejos tiene que verse: el tronco
  anaranjado en lo alto del pino silvestre, el blanco del abedul, el amarillo del
  abedular en otoño y los caducos pelados en invierno.
- Medido en los cuatro escalones: **Mínimo también mejora el color**, que es un
  fallo de hoy. Lo único que Mínimo conserva es la forma.

> **Cómo quedó el color (2026-09-15).** Con `ArbolColorProbe` —con ventana, un escalón
> por corrida—: el valle montado con la luz del juego a mediodía, sin niebla, y delante
> de la cámara un árbol suelto de cada especie contra un telón plano sin luz. **Todo
> dentro de ΔE ≤ 10, casi todo por debajo de 3**:
>
> | | copa verano | copa otoño | corteza | invierno | impostor contra 3D |
> |---|---|---|---|---|---|
> | Medio y más, 3D | 0,1–0,3 | 0,1–4,7 | 0,0 | — | 0,0–6,6 |
> | Mínimo, de lejos y de cerca | 0,7–2,9 | 1,4–2,5 | — | 0,6–0,8 (contra corteza) | — |
>
> El peor es el roble de otoño en 3D, 4,7: su tinte ya tiene el azul a cero. Medio,
> Alto y Ultra comparten modelos y tintes, así que se mide en Medio. Los números están
> en `Forest.COLOR_DE_ESPECIE`; salen de la sonda con CALIBRAR=1, que acerca cada tinte
> a su foto, y se verifican sin él.
>
> **Lo que se cayó por el camino**, que es casi todo lo que el plan daba por sentado:
>
> - **Dos referencias no valían.** El roble de verano era una copa vista desde abajo
>   en sombra (L 31,8: el robledal habría salido casi negro) y el siguiente candidato,
>   hoja tierna de primavera (a* −31, verde lima); quedó el robledal de Ivenack el 6 de
>   agosto, al sol. El abedul de otoño era de noviembre, medio pelado y gris (b* 14),
>   sin el amarillo que pide esta spec; quedó uno amarillo. `candidatas.py` dice por qué.
> - **Un tinte que multiplica no basta.** Las texturas de ambientCG son de otro verde:
>   medidas, las copas salían verde azulado (a* ≈ −25 contra −11 a −15 de las fotos), y
>   llevarlas al oliva pedía ×5 en rojo y azul. Todo lo que no era hoja pura salía
>   magenta. **La textura se desatura al 30 % antes de teñir**, en los tres shaders: la
>   textura pone la luz y el dibujo, y el tinte es el color de la especie.
> - **La hoja 3D llevaba un `BACKLIGHT` verde fijo** que se sumaba a cualquier tinte: era
>   la mitad del «verde lima» de la queja, y hacía que el calibrado rebotara sin
>   converger. Ahora es del color de la hoja.
> - **El impostor no sabe qué es hoja.** Separarla «por lo verde» fallaba con la aguja
>   del pino, oliva oscuro. El horneado guarda la máscara de hoja en el alfa del atlas
>   de normales —se rehornearon los 30 impostores, 3 minutos—, y hoja y corteza llevan
>   cada una su tinte.
> - **El impostor salía más claro y más amarillo que el 3D** (luminancia ×1,15 a ×1,45,
>   b* +5 a +10): la foto horneada no tiene la sombra que la copa se hace a sí misma,
>   que en el juego ilumina el cielo, azul. Lleva una luz por canal y por especie, sólo
>   en la hoja —sobre la corteza, los caducos lejanos salían lila en invierno—, y otra
>   para otoño.
> - **El atlas de Mínimo es muy oscuro** (la celda del pino, 0,12 de media en sRGB): su
>   tinte tenía que multiplicar ×30 y, en juego, las copas vistas desde arriba y las
>   láminas cruzadas de cerca se quemaban a verde neón. La lámina **se divide por el
>   brillo medio de su celda**, que `Forest` lee del atlas, con tope ×2,5. La sonda mide
>   también las láminas de cerca, que al principio no miraba.
> - **En Mínimo, el árbol pelado vira a su color de rama en la lámina entera**, con el
>   cuadrado de lo pelado (20 % en otoño, 90 % en enero), y ese color se mide en invierno
>   contra la foto de corteza. Con la mezcla vieja, sólo en la copa y lineal, un roble de
>   enero medía naranja y un abedul de octubre quedaba lavado de blanco.
> - **El invierno de los caducos salía azul.** Se sacaba del otoño con la forma del año,
>   que divide por el 0,42 de azul del otoño de `CADUCO`. Ahora el invierno es el tinte
>   de otoño tal cual —la hoja seca que queda— y lo que cambia es cuánta hoja. Lo vio
>   la primera captura del valle, no la sonda, que no medía el invierno: ahora sí.
> - **Dos trampas del instrumento.** `ShaderMaterial.duplicate()` perdía el tinte
>   puesto como `Vector3` en un uniforme `source_color` —el abedul de otoño medía verde
>   y con toda la hoja—; `Forest` lo pasa como `Color`. Y el fondo se movía entre la
>   foto sin árbol y la foto con él: en el pino fino de Mínimo pesaba más que el árbol
>   y la sonda medía cielo. De ahí el telón.

**Lo que cuesta**

- **Medio cabe en su casilla**: el bosque en Medio no cuesta más que los **3,0 ms**
  de «Vegetación y props» del presupuesto de §1, medido como la diferencia entre
  bosque encendido y apagado en la vista de medida, con `GpuProfile`, dos corridas.
  **En el equipo de medida**, que no es una 1070: si no cabe aquí, se dice con la
  cifra.
- **Alto y Ultra, medidos y escritos** en la tabla de §7, sin tope: Alto va por
  encima de Medio y Ultra no tiene límite (§7).
- **Montar el bosque no tarda más que hoy** en ningún escalón: hoy son 13,8 s en la
  vuelta al mapa de la banda (`TransitoProbe`, ESTADO §2). Lo que haya que hornear
  no se hornea al montar el mapa.
- La tabla de §7 dice en su fila de «Árboles» **si el escalón se aplica en
  caliente o al montar el mapa**, medido, igual que la densidad de vegetación.

> **Cómo quedó (2026-09-15).** `GpuProfile ARBOLES=1 ESCALON=n`, un escalón por
> proceso, 1920×1080, dos vueltas y el mínimo, **dos corridas** (dan lo mismo a ±0,2
> ms). «El bosque» es la GPU con el bosque encendido menos apagado; además de la vista
> de medida, los dos encuadres de juego de `BosqueCaptura`, porque la vista de medida
> mira desde 75 m de alto y desde ahí no hay ningún árbol 3D:
>
> | escalón | medida | juego alto | juego bajo | montar el mapa | VRAM |
> |---|---|---|---|---|---|
> | Mínimo | 1,9 ms | 2,5-2,6 ms | 3,2-3,3 ms | 16,2-16,3 s | 1 239 MB |
> | **Medio** | **3,4-3,5 ms** | 2,2-2,4 ms | 3,8-4,0 ms | 18,1-18,2 s | 1 384 MB |
> | Alto | 5,3-5,4 ms | 3,8-3,9 ms | 4,8 ms | 19,0 s | 1 384 MB |
> | Ultra | 9,7 ms | 6,4-6,8 ms | 9,5-9,8 ms | 18,2-18,9 s | 1 385 MB |
>
> - **Medio no cabe en 3,0 ms: 3,4-3,5.** El usuario lo dio por bueno —«3,8 ms en lugar
>   de 3 es aceptable»—.
> - **Lo caro no era el 3D, eran los impostores.** La primera medida dio 14,3 ms en
>   Medio con menos triángulos que Mínimo. Con el recorte alfa cada capa de cuadrados
>   solapados paga su píxel entero, y el impostor leía ocho texturas por píxel. Medido
>   por partes: sin las cuatro normales, 4,6 ms; opaco, 0,4. Tres cambios lo bajaron:
>   **el alfa se lee antes que la normal** y lo transparente se tira sin leerla (14,5 →
>   8,1); **las cuatro vistas sólo se mezclan de cerca** —`Forest.MEZCLA_HASTA`: 150 m
>   en Medio, 300 en Alto, siempre en Ultra—, más lejos se lee la vista más cercana
>   (8,1 → 3,8); y **el cuadrado se ajusta al árbol** visto desde esa elevación en vez
>   de ser del lado de su dimensión mayor (3,8 → 3,4). El color del impostor frente al
>   3D no se movió ni una décima, y aros y huecos siguen a cero.
> - **Los radios del 3D se quedan en 40 / 70 / 120 m**: el 3D sólo pesa en los encuadres
>   bajos, y ahí Medio cuesta 3,8-4,0 ms contra 3,2-3,3 de Mínimo.
> - **Montar el mapa tarda 1,8-2,8 s más que en Mínimo**, y la spec pedía que no tardara
>   más que hoy. Medido por partes en Medio: cargar los 30 modelos 1,4 s y montar los
>   impostores 0,84 s, frente a 0,28 s de todo el bosque lejano de Mínimo. **El usuario
>   lo dio por bueno** —«el punto de la spec es un poco limitante, me vale como está»—.
>   Se vio de paso por qué cargan tanto: ver la deuda de abajo.
> - **VRAM: +145 MB** en los tres escalones 3D, casi todo los impostores.
>
> **Deuda que queda a la vista.** Las texturas de hoja y corteza de los árboles 3D
> están importadas **sin comprimir y sin mipmaps** (`compress/mode=0`,
> `mipmaps/generate=false`): se decodifican en la CPU al cargar, y de lejos se leen a
> resolución completa. Y los modelos guardan también los mapas de normales y
> rugosidad de la corteza, que el shader del bosque no usa pero se cargan igual. Es
> casi seguro la mayor parte del 1,4 s; no se tocó porque el tiempo quedó aceptado.

#### Fuera de alcance

- **Dónde crece cada especie**: la siembra, las manchas de bosque y el reparto por
  ladera, humedad y altura quedan como están.
- **Especies nuevas.**
- **Viento**, árboles que se mueven, que se talan o que cambian con la partida.
- **Hierba, arbustos y props.**
- **La calidad de las sombras**, que es su propio ajuste.
- **Arreglar la vuelta de 13,8 s** de la vegetación: está pendiente aparte en
  ROADMAP. Esta spec sólo pide no empeorarla.

#### Plan técnico (2026-09-15)

**Decisión del usuario al planear**: no hay modelos CC0 realistas hechos para juego
de estas cuatro especies —Poly Haven no tiene abedul, roble ni avellano; lo CC0
gratuito es *low-poly* de dibujo; lo realista con LOD es de pago—, así que **los
árboles se generan con EZ-Tree y se guardan en el repositorio**. EZ-Tree
(<https://github.com/dgreenheck/ez-tree>) es un generador de código abierto: código
**MIT**, cortezas de **ambientCG en CC0**, ramas de verdad y hoja en tarjetas con
alfa. Sus texturas de hoja **no declaran licencia**: se confirman o se sustituyen.

**Lo que hay, comprobado en el código.**

- `Forest` monta **dos cuerpos**: de cerca, bloques de 128 m con **tres tarjetas
  cruzadas** por árbol, doce bloques por fotograma, hasta `near_distance` = 350 m;
  de lejos, impostores de **una foto** por especie (perfil y cenital) en teselas de
  512 m, con un **corte duro** en el mismo radio.
- Las fotos las hornea `TreeAtlas` de las mallas de Poly Haven de `props.res`, de
  157 000 a 1,3 millones de triángulos por árbol, y tres de ellas no son su especie.
- La densidad de vegetación va por niveles en `Configuracion.NIVELES` y **se aplica
  al montar el mapa**, no en caliente (resembrar cuesta ~10 s).

**Módulos.**

| Qué | Dónde | Contrato |
|---|---|---|
| **Generar los árboles**: cada especie con su preset afinado —pino en pisos con punta y corteza anaranjada arriba, abedul fino y blanco (desde el preset de álamo), roble ancho y tortuoso, avellano en mata (desde el de arbusto)—, tres variantes por especie y tres niveles de detalle, volcados a geometría —*quedaron seis variantes*, a petición del usuario— | nuevo, `scripts/tools/arboles/generar.mjs` (Node + `three` + `@dgreenheck/ez-tree`) | herramienta, fuera del juego (SPECS §4.8) |
| **Traer la geometría a Godot** como `ArrayMesh` con sus niveles de detalle, corteza y hoja en dos superficies | nuevo, `scripts/tools/ArbolesImport.gd` → `models/arboles/*.res` | §4.8 |
| **Hornear impostores de varias vistas**: de cada variante, fotos desde una semiesfera de direcciones (hemi-octaédrico), con color, alfa, normal y profundidad —*quedó color con alfa, y normal con qué es hoja en su alfa; sin profundidad*— | nuevo, `scripts/tools/ArbolImpostores.gd` (con ventana) → `models/arboles/impostores/<especie>_<variante>_{color,normal}.res` | §4.8 |
| **El impostor**: elige y mezcla las vistas según la cámara, relumbra con sus normales y se funde con el 3D | nuevo, `shaders/arbol_impostor_vistas.gdshader` | vista |
| **El bosque por escalones**: Mínimo, el código de hoy sin tocar su forma; Medio, Alto y Ultra, 3D de cerca y el impostor nuevo de lejos, con un **relevo fundido a trama** que se solapa en vez de un corte —*quedó un corte por árbol: ver la decisión 3*— | `scripts/vista/Forest.gd` | §4.7; la siembra no cambia |
| **El color por especie y estación**, medido contra fotos, para todos los escalones | tabla en `Forest.gd`, referencias en GRAFICOS y CREDITOS | vista |
| **El selector** | `scripts/vista/Configuracion.gd`, `scripts/ui/VentanaDeConfiguracion.gd` | INTERFAZ §8.7 |
| **Las sondas**: aros, huecos, color y coste | `ArbolAroProbe`, `ArbolHuecoProbe`, `ArbolColorProbe` (nuevas, con `SoloElBosque`), `GpuProfile` (`ARBOLES=1`) —*el tiempo de montar se midió en `GpuProfile`, no en `TransitoProbe`*— | §5.1 |

**Decisiones de arquitectura, sólo las que la spec obliga a tomar.**

1. **Mínimo no toca su forma**: tarjetas y foto única como hoy, por el mismo camino de
   código. Sólo cambia el color, que la spec pide también ahí.
2. **El radio del 3D no es 350 m en todos los escalones: sale de medir.** A 350 m hay
   del orden de veinte mil árboles alrededor de la cámara; con unos miles de
   triángulos cada uno no cabe en 3,0 ms. Medio tendrá **el radio que quepa en su
   casilla**, y Alto y Ultra más, medidos y escritos.
   > *Se quedaba corto*: el valle tiene **1 052 727 árboles**, y con 160 m el escalón
   > Alto pintaba 541 millones de triángulos a 6 FPS. Los radios de partida pasaron a
   > 40 / 70 / 120 m, los modelos a la mitad de triángulos, y los bloques del 3D a 32 m.
3. **El aro se quita con un corte por árbol**, no con trama ni afinando el radio: cada
   árbol es 3D si su pie está dentro del radio e impostor si está fuera, uno u otro.
   > *Decía «solapando, con trama entre dos distancias»* hasta la primera captura: la
   > trama se veía como un tamiz sobre las copas, y el shader de Mínimo ya lo había
   > descartado por lo mismo. El corte por árbol no deja banda, y como el impostor sale
   > del mismo modelo, el salto de cada árbol es pequeño.
4. **El hueco al moverse se quita con orden**: el impostor **sólo se esconde dentro del
   radio ya montado**, que `Forest` calcula del primer bloque pendiente.
5. **Todo lo que se hornea, se hornea antes**: generar, importar y hacer impostores
   son herramientas; montar el mapa sólo carga recursos, para no pasar de los 13,8 s
   de hoy.
   > *Se hornea antes, pero cargar cuesta*: 1,8-2,8 s más que Mínimo, aceptado por el
   > usuario. Ver «Lo que cuesta».
6. **Los mismos árboles en los mismos sitios**: la siembra no cambia; cada escalón
   dibuja el mismo censo.

**Orden de dependencias.** Los modelos antes que nada, y **se enseñan en capturas
por especie antes de seguir** —lo pidió el usuario—; los impostores de los modelos;
el color de las referencias antes de afinar tintes; `Forest` por escalones antes que
el selector; y las sondas al final, sobre todo montado.

**Riesgos técnicos.**

- **El abedul sale de un preset de álamo y el avellano de uno de arbusto**: habrá que
  afinar ramas y corteza hasta que se lean como su especie, y eso se juzga en capturas.
- **Las texturas de hoja de EZ-Tree no tienen licencia escrita**: si no se confirma,
  se sustituyen por hojas CC0 de ambientCG o se dibujan.
- **El nivel de detalle automático de Godot en un `MultiMesh`** se elige por instancia
  de nodo, no por árbol: con bloques de 128 m puede quedar grueso. Si no basta, un
  `MultiMesh` por nivel de detalle con sus rangos de visibilidad.
- **Los impostores de varias vistas pesan en memoria de vídeo**: tres variantes por
  cinco especies con cuatro mapas cada una. Se mide la VRAM y se dice.
  > *Medida*: +145 MB, con seis variantes y dos mapas cada una.
- **Medir los huecos en píxeles** pide comparar el fotograma en marcha con el mismo
  encuadre ya asentado: la sonda repite cada pose dos veces.

## 7.2. La sala de la cueva (spec, 2026-09-15)

La spec vive en **SISTEMAS §13** —«La pared que se ve»—, porque es un sistema. Lo
que toca a este documento, y hay que cumplir allí:

- **Una sala a la luz de la lámpara**, con la pared del fondo **modelada con su
  relieve** y la textura de la roca, porque las figuras se colocan donde el relieve
  las recalca y lo usan para recalcarse.
- **Cuesta como mucho lo que el valle en el mismo nivel** (18,1 ms en Medio en el
  equipo de medida), y **entrar y salir no pasa de 2 s**.
- Los motivos son **vectoriales calcados a mano**, con la paleta de ocre rojo,
  carbón y ocre amarillo, y se ven **sobre** el relieve de la roca, no pegados
  encima como una pegatina.

### Cómo quedó (2026-09-15)

`SalaDeLaCueva` (`scripts/vista/`) y `shaders/pared_pintada.gdshader`.

- **Una capa, no una escena**: un `Control` a pantalla completa con un
  `SubViewport` de **mundo propio**. Ni el sol ni la niebla del valle entran, y
  salir cuesta 1–3 ms. **Tamaño a mano y no con anclas**: colgada de un
  `CanvasLayer` un `Control` no tiene de quién tomar tamaño, y la primera captura
  salió con la sala invisible y el texto en columna.
- **La roca es la malla del relieve** de `ParedDeLaCueva`, curvada por los bordes
  como un nicho, con la caliza de la capa ROQUEDO del terreno **en dos muestras a
  escalas y giros distintos** —con una se leía como papel pintado—. Los triángulos
  van **en sentido horario**: al revés la pared quedaba de espaldas y la captura
  salía negra.
- **Las figuras se pintan en una textura** del tamaño de la pared (110 px por
  metro), rellenando los polígonos del calco por paridad, en el sitio exacto donde
  la simulación midió el ajuste. La **mano en negativo** es un halo soplado: la
  silueta emborronada menos la silueta.
- **El pigmento tiñe la caliza**, multiplicado sobre ella con un grano de poros, y
  la lámpara —un punto de luz cálido que parpadea con dos oscilaciones que no
  casan— hace que la figura se curve con el bulto.
- **Cámara**: arranca a 3,2 m de la pared —a 5,5 una mano no se leía—, mirando al
  centro de lo pintado, se acerca con la rueda y se desplaza arrastrando.
- **Con la sala abierta se apaga el 3D de la ventana de debajo**: la tapaba entera,
  pero el valle seguía dibujándose.

**Lo que cuesta**, `CuevaCaptura` a 1920×1080, dos corridas, en el equipo de medida:

| | Entrar | Salir | GPU por cuadro |
|---|---|---|---|
| Pared de la banda, 6 figuras | 549–632 ms | 1–2 ms | 2,02–2,06 ms |
| Covalanas, 8 figuras | 408–451 ms | 1 ms | 2,06–2,09 ms |
| El Castillo, 12 figuras | 599–616 ms | 1 ms | 2,09–2,11 ms |

**Cumple las dos cosas de la spec**: entrar por debajo de 2 s (la primera vez de la
partida, 1,5 s, porque se descomprime la roca y se compila el shader) y bastante
menos GPU que los 18,1 ms del valle en Medio.

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
