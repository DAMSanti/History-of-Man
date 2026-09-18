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
| **El agua: ríos con rápidos y espuma, y el mar del valle** (spec) | §7.3 |
| **El clima en pantalla: lluvia, nieve que cuaja, niebla de valle** (spec) | §7.4 |
| **Las texturas del suelo, con su altura de verdad** (spec) | §7.7 |
| **La banda: cuerpos, oficios en las manos y ropa por era** (spec) | §5.1 |
| La niebla del mapa regional como nubes (spec) | §3 |
| El relieve de las texturas, que no existía (depurar del 2026-09-16) | §4 |
| **El día y la noche**: está encendido desde el 2026-09-07, y la spec de apagarlo era falsa | §7.5 |
| **Ver a la gente trabajar: viajes abreviados y cámara lenta** (spec) | §7.6 |
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
>
> **El fotograma, medido el 2026-09-15** con `FotogramaCuevasProbe` —las nueve cuevas
> del valle y sus 27 simas cosidas, con y sin ellas en la misma corrida, dos vueltas
> alternando, mediana de 400 cuadros—: **desde la cámara de arranque no cuestan nada**
> (49,4 ms con, 49,4-49,9 sin) y **a 30 m de la cueva de la banda, unos 2 ms** (52,1-52,2
> con, 50,1-50,2 sin). La sonda no fija la ventana a 1080p (abre más grande, §1), así que
> vale la diferencia y no el total. Estaba aparcada, y al retomarla **no arrancaba**:
> buscaba la cueva con `DemoMain._cave_at`, que ya no existe desde que las cuevas son
> del campamento (`Campamento.cueva_en`); `AbrigoProbe` y `TrasladoProbe` tenían lo mismo.

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

> **La escala de render ya no se elige aquí (2026-09-17, INTERFAZ §16).** Sigue siendo lo
> mismo por dentro —dibujar el mundo 3D a menos y reconstruir con FSR2, y los niveles
> siguen poniendo la suya: Bajo la deja en 0,6—, pero **se elige en Pantalla**, como
> «Resolución de dibujo» y en píxeles reales. Ya no hay fila «Escala de render» en
> Gráficos: dos controles sobre el mismo valor eran la pregunta contestada desde dos sitios
> que prohíbe SPECS §7.
>
> Lo que gana, medido con `ResolucionProbe` a 1080p en el valle del sitio 56: **−32 % y
> −31 % de GPU** del escalón más alto (100 %) al más bajo (50 %), en dos corridas. La tabla
> entera, en INTERFAZ §16.
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

> **Los ríos del mapa regional, hechos el 2026-09-16** (EPOCA_01 §10.2): el relieve
> regional se horneó sin cauces y el mapa no dibujaba ninguno. Ahora se hornean de OSM
> —1 599 tramos, 4 107 km— y se prolongan por la plataforma hasta la costa de la época
> (54 desembocaduras, 1 464 km). Se pintan con `Hydrography.apply` como en un valle,
> **exagerando el ancho ×4,5 con un mínimo de 0,8 celdas**: un vértice de la malla
> regional son 195 m, y por debajo de ese mínimo el cauce sale a trozos. El ancho crece
> aguas abajo (`AnchoDeLosRios`). **Y el relieve de la plataforma es ×1,6 el medido**
> —elección del usuario sobre capturas—, con el valle de cada río abierto en las lomas.
>
> Pintarlos costaba **23 s en cada montaje del mapa**, así que el relieve ya preparado
> —lomas, valles y ríos— se hornea en `data/dem/cantabria_region_mar…_hidro.res` (55 MB,
> no se versiona): con él, la sonda que monta el mapa y captura pasa de 110 s a 38 s.

> **Depurar del 2026-09-17: el mar de hoy, plano en los valles de la época, y la
> plataforma inventada.** Queja del usuario: «los mapas que hoy son costa, en el
> Paleolítico, cuando entro a ellos, la parte del mar es completamente plana… No te la
> inventes, busca orografía que cuadre con esos mapas, aunque sea de otro lugar, y
> sticheala para que no se note que está pegada. Los ríos deben continuar… ahora esos ríos
> desembocan en la nada».
>
> **Caso C: la documentación no decía nada.** El valle de un yacimiento real es el LiDAR
> del IGN, que se acaba en la orilla de hoy: el mar sale **a cota cero y plano**, y con el
> mar a −120 m ese llano queda en seco. La costa de la época (EPOCA_01 §10.2) sólo inventó
> valles para los cuatro abrigos hipotéticos. **Medido**: 16 de los 72 yacimientos reales
> del Paleolítico tienen mar de hoy dentro de su recuadro de 4 km (5, 19, 36, 38, 39, 41,
> 47, 49, 50, 51, 52, 54, 57, 60, 61 y 750). Y **el relieve de arriba, el de la
> plataforma en el mapa regional, está inventado**: es ruido ajustado a las alturas de la
> costa de Santander.
>
> **Lo que se decidió que debería pasar** (decisiones del usuario):
>
> 1. **Nada inventado.** La forma grande sale **del fondo marino real** —el relieve
>    regional trae batimetría de verdad: 3 414 cotas distintas bajo cero, hasta
>    −3 413 m— y el detalle fino **se presta de relieve real de otro sitio** de
>    Cantabria, cosido para que no se note la costura.
> 2. **En cada época, donde esa zona sea tierra**: por debajo de la orilla de hoy y por
>    encima del mar de la época.
> 3. **Los ríos que hoy mueren en la orilla siguen, bajando por el relieve nuevo**, hasta
>    el mar de la época o el borde del valle. Pueden no coincidir con el trazado del mapa
>    regional, y es a sabiendas.
> 4. **El mapa regional también**: su plataforma deja el ruido y usa la misma regla —fondo
>    real y detalle prestado—, para que los dos mapas cuenten lo mismo.
>
> **Esto retira dos decisiones escritas arriba**: el mapeo del ruido a los percentiles de
> la costa de Santander y la amplitud ×1,6 que el usuario eligió sobre capturas
> (2026-09-16). Aquellas capturas eran de relieve inventado; con relieve prestado se
> vuelve a elegir sobre capturas. Tareas en ROADMAP «En curso».

**Y la plataforma tiene relieve** (`RelieveDeLaPlataforma`). La batimetría a 111 m
sale lisa, y con el mar a −120 m se veía una llanura sin un bulto.

> **Rehecho el 2026-09-14, con la queja repetida**: «en el mapa regional no se
> aprecia NADA de elevación en la plataforma emergida… quiero que tenga orografía
> como hoy la hay entre Santander y Torrelavega». La primera versión subía el fondo
> **saturando hacia la cota cero de hoy** —para no mover la costa actual—, así que
> las lomas se quedaban en 20-30 m sobre un mapa de 200 km: invisibles.
>
> La primera versión medía las alturas de esa franja (43,33–43,48 N, 4,08–3,78 O;
> 28 637 celdas de tierra: p05 **3 m**, p25 **19**, p50 **48**, p75 **100**, p90 **159**,
> p99 **312**, máx **515**, y **22 m de desnivel por kilómetro** de mediana) y **mapeaba
> ruido a esa escalera de percentiles**. Tenía la repartición de alturas de la costa, pero
> era ruido. **Eso se retiró el 2026-09-17** —«no te la inventes»—: hoy el relieve es
> **detalle real prestado**, y las medidas de arriba se quedan como lo que se le pedía
> parecer.
>
> **El relieve depende del mar**: `RegionMap` lo aplica con el de la partida —o con el de
> hoy si no hay partida, y entonces la plataforma sigue siendo fondo marino— y
> `HornearEras` hornea **cada época con el suyo**. Cambiar de época con la tecla E no
> rehace el relieve: es el de la época con la que se montó el mapa.
>
> Visto en `PlataformaCaptura` (ventana, partida empezada y sin niebla).

### Cómo quedó: relieve prestado, rías y el mar de hoy rellenado (2026-09-17)

**De dónde sale cada cosa**, que es la regla entera en tres líneas:

| | Forma grande | Detalle fino |
|---|---|---|
| Plataforma del mapa regional (111 m) | batimetría real del propio mapa | trozos de tierra de la franja costera del mismo mapa (`RelievePrestado.de_la_comarca`) |
| Mar de hoy dentro de un valle real (5 m) | la plataforma regional en ese punto | trozos de **la tierra del propio valle** (`RellenoDelMarDeHoy`) |
| Valle de un abrigo de la costa (5 m) | la plataforma regional | la **sábana de tierra real** del IGN a 5 m (`RelievePrestado.de_la_tierra`) |

Nada de ruido en ninguna de las tres. El detalle de un trozo es lo que queda al quitarle
su forma grande —tres pasadas de emborronado—, y se cose por bloques con cuatro trozos
mezclados, dividiendo por la raíz de la suma de cuadrados de los pesos para que la costura
no baje el relieve: medido, **80,2 m de desviación típica en el centro de un bloque y
87,6 m en la costura**, o sea que la costura no se nota por ser más lisa.

**Las rías y los valles**, que es lo que el usuario pidió al ver las primeras capturas
(«x1, pero veo mucho terreno marrón; cuando esté en costa crea rías, y si no, soluciónalo
con valles»): el detalle prestado **baja además de subir**, así que una vaguada puede
quedar por debajo del mar. Si llega al mar, **se inunda: es una ría**. Si no llega, **no
es un lago bajo el nivel del mar** —el plano del agua lo pintaría de mar— sino el fondo de
un valle, y se levanta con una curva continua que le conserva la forma. La regla es una
sola función, `RelieveDeLaPlataforma.rias_y_valles`, y la usan **las dos escalas**.

Medido sobre las 273 325 celdas de plataforma del mapa regional: **4,8 % de tierra en la
franja de orilla** (la banda marrón; era **14,3 %** con la llanura costera y el recorte
que impedía que el mar entrase, y **7,8 %** con las rías pero sin lo de abajo) y **6,2 %
convertido en ría**. De referencia, la costa real de hoy da **8,1 %** de esa misma franja.

**Y los tres cortes que había que quitar** (la tarde del 2026-09-17, después de mirar el
valle del sitio 36 celda a celda). La plataforma sólo llevaba relieve **entre** el mar de
la época y la costa de hoy; en los bordes de esa franja el relieve entraba de golpe, y eso
dibujaba **rayas de escalones** por todo el mapa: medido, **saltos de hasta 49,5 m entre
celdas contiguas a 5 m**, cuando el LiDAR real de ese mismo valle no pasa de 21,6 m.

1. **Por abajo, el fondo sumergido también lleva detalle**, hasta 60 m bajo la lámina y
   desvaneciéndose ahí (`HONDO_DEL_DETALLE_M`). Así no hay frontera que cruzar en la
   isolínea del mar, que es justo donde se ve. Más abajo sigue siendo batimetría medida y
   nada más. Lo que se recorta es lo que **emergería**: medio metro bajo el agua, donde el
   recorte no se ve. *(El primer intento fue desvanecer el detalle por cota cerca del mar
   y **se comió el relieve**: la plataforma está casi toda a menos de 30 m de esa cota. El
   perfil de delante del Pas pasó de −152..+80 m a −120..−20.)*
2. **Por arriba, el valle del río también se desvanece** en la costa de hoy
   (`ORILLAS_M`, 30 m de cota), no sólo el detalle: el cauce llegaba excavado hasta 25 m y
   se cortaba en seco contra el dato crudo de tierra. Ésa era la raya larga que cruzaba el
   valle entero.
3. **La máscara del mar de hoy se come la orla de la orilla** (`CEJA_DEL_MAR_M`, 1,5 m):
   playa, marisma e intermareal, que el LiDAR da a unos decímetros y que con el mar de la
   época tampoco existían. Sin eso, el relleno quedaba a −25 m pegado a celdas que seguían
   a 0,4 m.

**Cómo quedó, medido en el valle del sitio 36** (360 401 celdas de mar de hoy, el 44,4 %
del recuadro), comparando el relleno con el LiDAR real del mismo valle:

| Salto entre celdas contiguas (5 m) | p50 | p90 | p99 | p999 | máximo |
|---|---|---|---|---|---|
| Tierra de hoy (LiDAR del IGN) | 1,18 | 3,29 | 5,49 | 10,33 | **21,6 m** |
| Relleno, al empezar | 0,93 | 2,30 | 3,95 | 29,40 | **49,5 m** |
| Relleno, al acabar | 0,83 | 2,20 | 3,67 | 5,36 | **17,0 m** |

O sea: **el relleno es más suave que el terreno real en todos los percentiles, y su peor
escalón está por debajo del peor escalón real**. Las celdas con salto de más de 12 m
pasaron de **423 a 22**.

**Lo que se retiró por el camino**, con su porqué:

- El mapeo del ruido a percentiles y la **amplitud ×1,6** que el usuario eligió sobre
  capturas el 2026-09-16: aquellas capturas eran de relieve inventado. Con relieve
  prestado eligió **×1**.
- La **llanura costera de 600 m** sin lomas (decisión del 2026-09-14). Con relieve real
  era buena parte del marrón: ahora son **200 m**, y sólo frenan las lomas —las vaguadas
  llegan hasta el agua, que es de donde salen las rías—.
- El recorte que subía la costa a un metro sobre el mar para que la costa no se moviera:
  dejaba **el 10,7 % de la plataforma pegada a esa cota**, un llano marrón. Ahora la costa
  sí se mueve, pero sólo hacia dentro y por rías.

**El mar de hoy de un valle real** (`RellenoDelMarDeHoy`) se rellena con la plataforma
regional de ese punto más el detalle prestado de la tierra del propio valle, **cosido en la
orilla**: en la orilla vale lo que valía el mar y llega a su cota a 250 m, sin escalón. Y
después, la misma regla de rías y valles. Dos cosas que costaron:

- **El valle guardado es uno para todas las épocas**, y el mar cambia de una a otra. Por
  eso el relleno lleva **su propio sello** (`relleno_mar`, `relleno_version`) y se
  **deshace** antes de rehacerse, con la máscara del mar de hoy guardada en el propio
  recuadro. Subir el sello del valle habría obligado a redescargar los 56 que no tienen
  mar.
- **El agua de OSM rebaja el terreno** del cauce para que la lámina sea horizontal
  (`Hydrography._settle_water_surface`). Si no se apuntan las cotas de antes, cada época
  hunde el cauce otra vez; se guardan (`cauce_celdas`, `cauce_cotas`) y se restauran.

**Y los ríos siguen.** Desde donde cada cauce de OSM toca la orilla de hoy, se baja por el
relleno hasta el mar de la época o el borde del valle: inundación por prioridad sobre el
relleno a un cuarto de resolución —20 m por casilla—, y el camino de vuelta desde la boca.
Como baja por el relieve nuevo, **puede no coincidir con el trazado del mapa regional**, y
es a sabiendas (decisión del usuario).

### Y una verdad sola: con qué mar se monta cada mapa (2026-09-17, por la noche)

Nada más probarlo, el usuario vio dos cosas que no cuadraban: «el mapa regional ha perdido
sus ríos en la plataforma emergida» y «los mapas de detalle están igual que antes». Y dio
él la pista que lo resolvió: «cuando entro en debug, el mapa regional no tiene ríos; pero
cargo un mapa, vuelvo y vuelve a tener ríos… ¿ya hay más de una verdad?».

**Había dos, y eran la misma pregunta contestada en dos sitios**: *¿con qué mar se monta
esto?*

- El **mapa regional** congela al montarse el relieve de la plataforma y los ríos que la
  cruzan —son la malla, y rehacerlos son veinte segundos—, pero preguntaba
  `GameState.home != null ? GameState.sea_level_m : 0.0`. El modo Debug **no funda nada**,
  así que caía en el 0: montaba el relieve con el mar de hoy y luego pintaba encima la
  costa glacial. Plataforma pelada y **sin un solo cauce**. Al cargar una partida sí había
  casa, y los ríos volvían. Hoy lo contesta `RegionMap.mar_del_mapa()` y nadie más.
- El **valle** se preparaba con `Expedition.sea_level_m`, que al fundar desde el mapa
  **todavía no está puesto** —se pone al entrar al valle, después—. Así que el relleno se
  hacía «para el mar de hoy», es decir, no se hacía… **y quedaba sellado como hecho**, con
  lo que no se reintentaba nunca. Medido en los valles guardados del jugador: el 60 con el
  sello puesto, mar 0 y 106 470 celdas a cota cero intactas. Hoy el mar se lo pasa quien
  manda preparar (`PreparaValle.mar_de_la_epoca`).

Medido después, con el modo Debug abierto en el Paleolítico: **255 287 celdas de plataforma
emergida y 22 414 con cauce pintado** (antes, ninguna). Lo enseña `tests/DebugCaptura.gd`.

La moraleja, que ya estaba escrita en CLAUDE.md y volvió a pasar: **una pregunta, un sitio
que la contesta**. Las dos quejas del usuario eran el mismo fallo visto desde dos mapas.

### ¿Son ríos de verdad? La auditoría del agua (2026-09-17)

El usuario lo pidió con todas las letras: «comprueba que todos los ríos que hayas metido,
tanto en mapa regional como en el mapa detalle, sean fieles a la realidad; que no hayas
convertido carreteras en ríos». La hace `tools/AuditarRios.gd`, sin red, sobre lo que hay
horneado y guardado.

**De dónde sale el agua, y qué se descarta.** La consulta de hidrografía y la de obra
humana son distintas y no se tocan: el agua pide `way["waterway"]` y `way["natural"=water]`,
y las vías —que se usan para **borrar** carreteras del relieve, no para pintarlas— piden
`way["highway"]` y `way["railway"]`. Además, la tabla de anchos de `OSMWays` da **ancho
cero** a lo artificial (canal, acequia, drenaje, presa, azud, compuerta, tubería), y un
cauce de ancho cero no se pinta. Lo comprueba `TestRelleno`, con una carretera colada a
propósito en la respuesta.

**Lo que dice el dato de hoy:**

| | Qué hay | Clases |
|---|---|---|
| Mapa regional, de OSM | **1 599 tramos, 4 107 km** | `river` 1 599, y nada más |
| Mapa regional, por la plataforma | 58 tramos, 1 490 km | **deducidos del relieve**, no son dato de OSM |
| Valle del sitio 36 | 15 cauces, 60,2 km | `stream` 13, `river` 2 |
| Valle del sitio 60 | 41 cauces, 73,2 km | `stream` 40, `river` 1 |

Los quince cauces con más kilómetros del mapa regional son ríos de verdad y con su nombre:
Pisuerga, Ebro, Carrión, Esla, Nela, **Deva**, Cea, **Saja**, **Pas**, Baia, Valdavia,
**Cares**, Urbel, **Nansa**, Oca. Los de la meseta salen porque el recuadro regional son
200 × 143 km y baja bastante al sur de la divisoria: están donde deben estar.

**Y dos cosas que la auditoría destapó en lo que acabábamos de hacer**, las dos en los ríos
que siguen por el relleno:

1. **Cada cauce bajaba solo hasta el mar**, sin unirse a nadie. El «Caño de la Portilla»
   —un caño de marisma de tres metros— recorría **12,7 km** él solo, y el Gandarilla salía
   **dos veces por el mismo sitio**, una por cada tramo en que OSM lo parte. Ahora **los
   afluentes confluyen**: el camino se para en cuanto pisa otro cauce ya trazado, y se
   trazan de mayor a menor para que el colector sea el río y no el arroyo que llegó antes.
   El caño quedó en 1,6 km.
2. **Los ríos remontaban.** El camino sale de una inundación por prioridad, que busca el
   paso más bajo pero **puede cruzar un collado**: el Deva subía 56 m y el Cabra 181,5 m.
   Ahora el tramo nuevo **abre su cauce** —como ya lo abre el mapa regional en la
   plataforma—, con pendiente mínima de 2,5 por mil y excavando a paso de celda, no por
   discos sueltos. Medido después: el sitio 36 se queda en **0,5 m** de remonte y el 60 en
   **0,7 m**, y eso comprobándolo sólo por encima del agua, que por debajo ya es estuario.

Lo único que sigue sin ser dato real es lo que nunca lo fue y está dicho desde el principio:
**la prolongación por la plataforma**, que es deducción sobre el relieve. Y el drenaje que
se deduce de la propia malla cuando Overpass no responde, que es la reserva de última hora
y sí podría seguir una cuneta —por eso la obra humana se borra del relieve **antes** de
calcularlo—.

### Y el agua que cruza la raya del recuadro (2026-09-17, jugando)

Queja del usuario: «los ríos/rías en los mapas costeros se cortan cuando llegan a las 8
casillas que rodean la casilla principal». **No era el dato**: el contorno trae su agua de
OSM y la pinta —medido, del 1,6 % al 4,4 % de sus celdas, y cruzando la raya—. Eran dos
cosas de cómo se ve:

1. **Las ocho casillas se desaturan y se oscurecen a propósito** —son fondo, no tablero— y
   eso **se comía el azul del cauce**: el río salía del recuadro y se volvía una raya gris.
   Ahora la desaturación de fuera **no se aplica donde hay agua** (`triplanar.gdshader`):
   el agua es lo único que cruza esa raya y tiene que verse igual a los dos lados.
2. **El mar se acababa en el borde del recuadro.** La lámina de `TerrainGenerator` mide
   exactamente `terrain_size`, así que en un valle de costa la ría llegaba a la raya y se
   quedaba sin agua. `TerrainSurround.montar_el_mar` le pone un **marco** de mar alrededor,
   con el mismo material —un plano grande por debajo se pelearía con el del valle por el
   mismo píxel, y el del valle es el que lleva las olas finas—.

Y de paso, una cosa que conviene saber: **un valle sin rellenar no tiene mar en el
Paleolítico**. El juego sólo pone lámina de agua si algo queda por debajo del nivel del
mar, y el mar de hoy sin rellenar está a cota cero: con el mar de la época a −120 m, el
valle sale entero en seco. Por eso el relleno no es un adorno.


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

> **Spec (2026-09-15): la niebla del mapa regional, como nubes.** Salió del `/depurar`
> de la noche del 2026-09-14. La calima de hoy se lee como una capa de pintura: lo
> que no se ha visto tiene que parecer **tapado por nubes**, no borrado.
>
> - **Sigue tapando lo mismo**: sitios, ríos, frontera y relieve bajo lo no visto, y
>   **se intuye el trazo de costa** de la época para no perder la orientación
>   (decisión del usuario). Los yacimientos **avistados** desde una cima se ven por
>   encima, apagados (SISTEMAS §4).
> - **Se mueven con el viento** (decisión del usuario), **con el reloj de la
>   partida**, como las nubes del cielo del valle: paradas si la partida está en
>   pausa, más deprisa a ×5. El reloj sigue corriendo con el regional abierto.
> - **El borde con lo visto se deshilacha** como el de una nube, no como un fundido
>   liso.
> - **Primero se mide y se enseña, luego se elige**: dos o tres aspectos —por
>   ejemplo, capas de ruido animado sobre la calima; nubes con altura y sombra
>   falsa; y una marcha volumétrica ligera—, cada uno con **captura del mismo
>   encuadre** y **su coste medido**, y el usuario elige uno antes de pulir nada.
>
> Criterios: la captura de partida recién empezada **sigue sin enseñar ni un píxel
> de sitio, río o frontera** fuera del recuadro, y sí el trazo de costa; entre dos
> capturas con la partida corriendo, las nubes **se han movido** y con la partida en
> pausa **no**; **coste no mayor de 1 ms de GPU** a 1080p, alternando nubes y calima
> de hoy en la misma corrida (decisión del usuario). Fuera de alcance: nubes en el
> mapa de la banda —eso es el clima, §7.4—, que la niebla vuelva con el tiempo, y
> cambiar qué la levanta.

**Plan técnico (2026-09-16).**

*Lo que hay hoy en el código.* La calima es un grupo `fog` de `triplanar.gdshader`: la
textura de lo visto (`NieblaRegional.imagen`) con un borde de cinco muestras, mezcla hacia
un color liso y pinta el trazo de costa con la cota del mar de la época. **El mar y la
frontera** son mallas con `bajo_la_niebla.gdshader`, que repite la misma lectura de la
textura. `RegionMap._poner_la_niebla` pone la textura. **Nada se mueve**. Las nubes del
cielo del valle sí avanzan con el reloj: `WorldEnvironmentSetup._mover_las_nubes` pasa las
horas de la partida a metros de viento (`VIENTO`, `VIENTO_A_RUIDO`). Con el regional
abierto, el reloj es `Campamentos.reloj` (`dia`, `hora`) y no hay simulación de escena.

*Módulos afectados.*

1. **El viento de la partida, en un sitio**: una función estática que da el recorrido del
   viento a partir de la jornada y la hora —la cuenta que hoy hace `_mover_las_nubes`—; la
   usan el cielo del valle y la niebla regional. `RegionMap` la lee de `Campamentos.reloj`
   cada cuadro y la pasa al shader; sin reloj, quieta.
2. **`shaders/nubes_de_la_niebla.gdshaderinc` (nuevo)**: lo que se pinta donde no se ha
   visto, **una sola vez** para el relieve (`triplanar.gdshader`) y para el mar y la
   frontera (`bajo_la_niebla.gdshader`), con un `estilo` para enseñar los aspectos:
   - **0, la calima de hoy**, para comparar;
   - **1, ruido animado**: capas de ruido que derivan con el viento sobre la calima, con
     claros y oscuros, y el borde deshilachado por el mismo ruido;
   - **2, nubes con altura y sombra falsa**: la misma nube desplazada por la vista —como si
     estuviera a cierta altura sobre el relieve—, con luz de un lado y su sombra oscura en
     el borde, sobre lo visto;
   - **3, marcha ligera**: pocos pasos por una capa de nube encima del relieve, con
     densidad de ruido 3D.
   El trazo de costa se queda encima de las tres, tenue.
3. **`NieblaCaptura`** saca, con el mismo encuadre de partida recién empezada, una captura
   por aspecto, otra del borde de cerca y **la GPU de cada uno contra la calima** en la
   misma corrida.
4. **Tras la elección**: se pule el elegido y **se quitan los otros** —no se deja código
   muerto—; y la sonda comprueba los criterios: fuera del recuadro, ni sitio ni río ni
   frontera, y sí costa; con la partida corriendo, dos capturas distintas; en pausa,
   iguales; y el coste.

*Decisiones.* Ninguna de diseño antes de que el usuario elija aspecto: la spec lo pide así.
El ruido 3D y 2D llevan la celda acotada antes del hash (la lección del agua, GRAFICOS §7.3).

*Orden.* El viento antes que nada que se mueva; el include con los tres estilos antes que la
sonda; la sonda y las capturas antes de preguntar; y el pulido, la limpieza y los criterios
después de la elección.

*Qué contrato cambia*: ninguno; es vista, y avanza con el reloj de la partida (SPECS §3.2).

*Riesgos.* **La marcha** puede pasar de 1 ms a 1080p: se mide y, si pasa, se dice al
enseñarla. **Tapar del todo**: las nubes tienen claros y sombras, pero donde no se ha visto
tienen que seguir sin dejar ver ni un río; se mira en la captura de partida recién
empezada. **Lo avistado** son marcas aparte, por encima: no debería cambiar, y se mira.

### Retirada: la niebla del mapa regional (2026-09-17)

> **Fuera, por decisión del usuario**: «quitamos la niebla en el mapa regional». Se retiran
> la calima del relieve, las nubes con volumen y el shader que las borraba del mar y de la
> frontera —`NubesDeLaNiebla`, `bajo_la_niebla.gdshader`, `nubes_con_volumen.gdshader` y el
> bloque `fog` de `triplanar.gdshader`—, y con ellas su sonda y su prueba de la losa.
>
> **Lo que NO se ha quitado es la exploración**: `NieblaRegional` sigue guardando qué ha
> visto la banda, y los yacimientos siguen apareciendo sólo cuando se descubren. Eso es
> conocimiento y lo usan las expediciones, los campamentos y el guardado; lo que se ha
> quitado es el velo que tapaba el mapa.
>
> Lo de abajo queda como estaba escrito, porque cuenta cómo se hizo y qué costó.

### Cómo quedó: la niebla como nubes (2026-09-16)

**Se le enseñaron tres aspectos al usuario**, con captura del mismo encuadre —de lejos y el
borde de cerca— y coste medido (`NieblaCaptura ESTILOS=1`): ruido animado sobre la calima
(+1,56 ms), nubes con altura y sombra falsa (+2,10) y una marcha ligera por capas (+2,71).
**Los tres pasaban el tope de 1 ms** con la pantalla llena de niebla. **Eligió el segundo.**

**Lo que quedó** (`shaders/nubes_de_la_niebla.gdshaderinc`, que incluyen el relieve y el mar
y la frontera, para que la niebla sea la misma en los tres):

- Las nubes se fingen a **900 m sobre el relieve**: mirando de lado se ven corridas
  respecto del suelo que tapan, que es lo que las despega del mapa.
- Cada bulto **se ilumina por el lado de la luz y hace sombra por el contrario**, con dos
  lecturas del ruido.
- **El borde con lo visto se deshilacha** con el mismo ruido, en vez de fundirse liso.
- **El trazo de costa va entero por encima**, que es lo que da la orientación.
- **Se mueven con el reloj de la partida** ([Viento], la misma cuenta que las nubes del
  cielo del valle): paradas en pausa, más deprisa a ×5. `RegionMap` se lo pasa al shader
  cada cuadro.
- El ruido va **en una textura sin costuras** de 512 hecha una vez, de 55 km de tesela, y no
  calculado por píxel: así cuesta lo que cuesta.

**Medido con `NieblaCaptura`**, 1920×1080, alternando nubes y calima en la misma corrida,
dos corridas: **+0,22 y +0,27 ms**, dentro del tope de 1 ms. La niebla entera contra no
tener niebla: +0,46 ms. **Los criterios**: en la partida recién empezada sólo se ve el
recuadro del primer campamento y el trazo de costa, y tras el pasillo su franja; con la
partida en pausa dos capturas seguidas son iguales (diferencia 0,0005) y con la hora corrida
no (0,037).

**Lo que salió al hacerlo.**

- **`absf` no existe en GLSL** —es de GDScript—, y **el tamaño de la nube iba en metros**
  cuando el shader trabaja en unidades del mundo, que en el regional son 111 m: salían nubes
  de dos mil kilómetros, o sea una mancha lisa.
- **Con teselas de 18 km** la nube se repetía once veces sobre la comarca y se leía como
  papel pintado: 55 km.
- **La sonda medía el viento a mano** y `RegionMap` lo reescribía con el del reloj cada
  cuadro, así que decía que las nubes no se movían. Ahora mueve el reloj, que es el camino
  de verdad.
- **El trazo de costa desapareció** bajo el bulto de la nube al principio: va con todo su
  peso por encima.

### Y con volumen de verdad (2026-09-16, misma tarde)

**El usuario lo vio y lo rechazó**: «las nubes son un plano sobre el mapa regional, quiero
que tengan volumen, altura». Tenía razón: por muy bien que se fingieran la altura y la
sombra, se pintaban EN el relieve y por eso se leían pegadas al suelo.

**Lo que hay ahora** (`NubesDeLaNiebla`, `shaders/nubes_con_volumen.gdshader`): **una losa
de aire sobre la comarca**, de 800 a 3 200 m sobre el mar de la época, que el shader
recorre en 48 pasos. La densidad sale de un ruido 3D sin costuras a dos escalas —la forma
del banco y el detalle que le come el borde—, por lo que queda por descubrir y por un
perfil de base plana y cima redonda. Cada muestra mira hacia la luz con tres catas, así
que **la base sale oscura y la cima encendida**: las nubes se tapan entre ellas y dan
sombra. Los montes altos asoman por encima de la capa, y por los claros se ve la calima y
el trazo de costa.

**Debajo se queda la calima lisa del relieve**, que es la que garantiza que de lo no
descubierto no se vea ni un río: las nubes son el aspecto, no el tapado. Por eso el dibujo
plano de nubes en el shader del terreno **se quitó entero** —el `nubes_de_la_niebla`
que duró unas horas— y `triplanar.gdshader` y `bajo_la_niebla.gdshader` vuelven a pintar
sólo calima.

**Medido**: **+4,4 y +5,6 ms** a 1080p con la pantalla llena de niebla, contra la calima,
en dos corridas. **Pasa del tope de 1 ms de la spec, y el usuario lo aceptó**: «no me
importa el coste» (2026-09-16). Sigue cumpliéndose lo demás: en pausa dos capturas seguidas
son iguales (0,0002) y con la hora corrida no (0,032).

**Lo que costó afinarlo**, todo con captura delante: con el ruido a 26 km se veía la tesela
en cuadrícula; con la extinción a escala equivocada —el paso de la marcha mide decenas de
unidades— la primera muestra ya tapaba del todo y la nube salía como una sábana; y con el
manto de fondo alto, el mapa entero quedaba blanco y liso. Quedó en 50 km de banco,
extinción 0,05 por unidad y un manto del 7 %.

**Deuda que queda, dicha.** Es una sola losa, así que no hay nubes a distintas alturas ni
nubes por debajo de la cámara cuando se baja mucho el zoom.

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
el script y el `.import`, no dos gigas de PNG. ~~El canal de altura no es relleno:
BC7 trae alfa sin coste extra y alimenta el parallax que tapa el hueco de escala
del §2.~~

> **Corregido el 2026-09-16: no había parallax.** El canal A se muestreaba, se
> guardaba en `surface_height` y no lo leía nadie; el único relieve era el mapa de
> normales. Lo destapó la queja del usuario —«las texturas no tienen height map, o no
> es suficiente; quiero relieve en las rocas y en las briznas»—. **Lo que hay ahora**
> no usa ese canal: ver «El relieve de las texturas», abajo.

### El relieve de las texturas (depurar del 2026-09-16)

Sólo en **Alto (12 pasos) y Ultra (24)**, decisión del usuario; en Personalizado, si
el agua está en Alto o más (`Configuracion.pasos_de_relieve`). Todo en
`triplanar.gdshader`, sobre la capa dominante. **Se ajustó mirando con el usuario**, que
seguía la ventana de la sonda, en seis vueltas; lo que queda, y por qué:

- **La altura sale del dibujo, desenfocado**: lo claro sube y lo oscuro se hunde
  —«las partes oscuras se hundan y las claras se eleven levemente»—, leído **cuatro
  niveles y medio de mipmap por debajo** (`desenfoque_de_la_piedra`). A su tamaño cada
  mota de liquen hacía un bulto —«detecta las piedras, no las manchas de las
  piedras»—, y con tres niveles la piedra salía con arista —«deben ser bumps
  suavizados, como las piedras del suelo»—. Se mide contra la media de una zona más
  ancha que una piedra, para que una roca oscura entera no sea un agujero.
- **Parallax con oclusión** (`relieve_desplazado`), en mundo y no en UV porque aquí se
  textura con tres planos, y **sin escalones**: el cruce se interpola entre los dos
  últimos pasos. La hondura es un 5 % de la tesela.
- **El bulto con luz** (`bulto_de_la_capa`): la cuesta de esa altura inclina la normal y
  la cara al sol se aclara. Es lo que se ve desde lejos —con sólo el desplazamiento el
  usuario «no notó nada»—. Fuerza 3, y las juntas un 12 % más oscuras: con 7 y 25 %
  había «demasiada diferencia entre picos y valles».

La primera versión leía el canal A del ORM; se cambió al color porque ese mapa no casa
siempre con lo que se ve. Se apaga a partir de 160 m de la cámara (con 60 no llegaba a
la órbita de juego).

**Lo que cuesta**, `ClimaCaptura SOLO=relieve`, 1920×1080, alternando 0/12/24 pasos en
la misma corrida y el mínimo de tres vueltas, con la versión final: **+0,6–0,7 ms en
Alto y +0,6–0,9 ms en Ultra** (28 y 80 m de órbita). **Una sola corrida limpia**: las
de en medio se tomaron con el usuario moviendo la ventana y dieron bases de 32 a 46 ms,
que se descartaron. Falta la segunda.

**Hasta dónde llega**: de cerca los cantos del canchal se separan unos de otros con su
luz; a 80 m se nota mucho menos, y es un límite del tamaño y no del efecto: una piedra
de medio metro ocupa ahí unos pocos píxeles.

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

> **AVISO (2026-09-18): esto es el plan que se escribió, no lo que se construyó.** Lo que
> hay hoy en el juego es **otra cosa**: un único modelo genérico (`Animated Human.fbx`) con
> **siete clips** —ocioso, andar, correr, saltar, golpear, trabajar, morir—, horneado a una
> **textura de vértices** y dibujado como un `MultiMesh` (`BandaAtlas`, `BandaCrowd`). La
> ropa son **cuatro materiales** —vestido/desnudo × piel clara/oscura—, no piezas de
> geometría. Es decir: se construyó justo la técnica de multitudes que esta sección decía
> dejar «anotada para épocas tardías, no construida ahora», y no se construyeron ni los
> seis cuerpos ni el rig ni los slots de ropa.
>
> Gana el código: lo de abajo se conserva porque sigue siendo el destino al que se quiere
> llegar —y porque explica por qué—, pero **no describe el juego de hoy**. La spec que cierra
> ese hueco es §5.1.
>
> **Al día 2026-09-18 esto está HECHO, y por otro camino.** La banda va con `Skeleton3D` de
> verdad —no con la técnica de multitudes que esta sección proponía dejar para después—, con
> cuerpos de 12 566 triángulos, 45 animaciones, ropa modular por era y el apero del oficio
> colgado del hueso de la mano. Lo que no hay es el rig propio ni los seis cuerpos: se usan
> tres packs CC0. Ver §5.1, «Cómo quedó».

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

## 5.1. La banda: cuerpos, oficios en las manos y ropa por era (spec 2026-09-18)

> **Spec escrita con `/spec` el 2026-09-18.** Sale de una petición del usuario: «modelos
> mejorados de los miembros de la banda, con animaciones para trabajar, sentarse, andar…
> también tendrá que tener posibilidad de equipar diferentes ropas por las diferentes eras y
> diferentes herramientas». Las decisiones las tomó él con preguntas y están marcadas donde
> salen.

### Qué problema cierra

**La banda es hoy veinticinco copias de la misma persona haciendo lo mismo.** Un modelo
genérico, siete clips y cuatro materiales. Un tallador sentado percutiendo una lasca, una
peletera raspando en bastidor y alguien avivando el fuego **se ven idénticos**: el mismo
bucle de «trabajar». Y como la animación va horneada en una textura de vértices, **no hay
huesos en tiempo real**: no hay dónde colgar una azagaya ni cómo cambiar una prenda.

Eso choca con lo que el juego ya sabe de sí mismo. `Inhabitant.State` dice en qué situación
está cada persona, `Profession.Speciality` qué está haciendo, el árbol de técnicas dice qué
sabe hacer y las once fichas de época dicen cómo iba vestida la gente. **La simulación tiene
la información y la vista no la enseña.**

Y hay un motivo de juego, no sólo de vista: el jugador reparte oficios y no puede comprobar
de un vistazo quién está en qué. Lo que se ve en pantalla debería contestar «¿quién está
tallando?» sin abrir un panel.

### Lo que se pide

- **Cuerpos mejores, de packs CC0 ya animados** (decisión del usuario). Nada de
  bibliotecas con licencia dudosa ni de assets que haya que comprar: el catálogo del juego
  es CC0 y se queda así. Si un pack no trae un clip, se resuelve con otro CC0 o se deja
  fuera y se dice.
- **Animaciones que distingan lo que se hace**: andar, sentarse, trabajar y las de los
  oficios que se ven. El catálogo sale de `Profession.Speciality`, que ya existe: no se
  inventa una lista nueva.
- **Herramienta en la mano, la del oficio que se está viendo** (decisión del usuario):
  lasca, buril, raspador, azagaya, arpón, cesto, haz de leña. El criterio es el de §6:
  **arponear y forrajear no pueden leerse igual**.
- **Ropa por era, con el sistema completo y un conjunto por cada una de las once**
  (decisión del usuario). Aviso dado y aceptado: son once conjuntos de prendas, y eso es la
  partida más cara con diferencia.
- **Y que el PC del usuario lo mueva** (decisión del usuario, literal: «lo necesario para
  conseguir lo que he pedido y que mi PC lo pueda mover»). Esto **decide la arquitectura**,
  y por eso la arquitectura no se fija aquí: se elige **con la medida delante** en el plan
  técnico. Hoy el valle va a 20-22 fps en una GTX 1070, así que el margen es estrecho y la
  decisión entre esqueletos en tiempo real, horneado o una mezcla de los dos es una cuestión
  de milisegundos medidos, no de gusto.

### Criterios de aceptación

- **Se distingue el oficio a la distancia de juego.** Sobre una captura del campamento con
  la banda trabajando, **cada especialidad visible se reconoce por su postura y su apero**
  sin leer ningún panel. Lo juzga el usuario sobre capturas, como se eligieron las texturas.
- **Cada especialidad tiene clip y apero, y se comprueba sin abrir el juego**: una prueba
  recorre `Profession.Speciality` y falla si alguna se queda sin animación asignada o sin
  objeto en la mano. Es la red contra el «treinta y cinco clips a medias» que §6 ya temía.
- **La ropa cambia con la era**: una prueba recorre las once eras y comprueba que cada una
  tiene su conjunto y que cambiar de era cambia las prendas de la persona.
- **Cabe en la máquina**: con la banda entera a la vista en el campamento, **la banda se
  queda por debajo de los 2,0 ms de GPU** que el presupuesto de §1 le da a «Personajes»,
  medido en dos corridas con `BandaProbe` y con la ventana fijada a 1080p. Si no cabe, se
  dice y se cambia la arquitectura, no el criterio.

  > **Este criterio decía «no subir más de un 15 %» y se cambió el 2026-09-18, al medir la
  > línea base.** La banda de hoy cuesta **0,15 y 0,21 ms de GPU** en dos corridas: el 15 %
  > de eso son 0,03 ms, **menos que el ruido entre corridas**. Un listón que no se puede
  > medir no es un listón. El presupuesto de §1 sí: da diez veces el margen que hace falta
  > y está escrito desde antes de este trabajo.
- **Nadie se queda en pose T**: una prueba comprueba que todo `Inhabitant.State` tiene clip.
- **Se entrega por oficios completos** (regla heredada de §6): caza entera, luego ribera
  entera. Nunca treinta y cinco clips a medias.

### Fuera de alcance

- **Multitudes de cientos de personas.** Veinticinco es la banda; lo demás es de épocas
  tardías y ya está anotado en §5.
- **Cara, pelo y expresión.** A la distancia a la que se juega no se ven, y abren un
  agujero sin fondo.
- **Física de tela y de pelo**: las prendas son geometría rígida cosida al cuerpo.
- **Cinemática inversa** para que los pies se posen en la pendiente: es el paso siguiente
  natural, y va aparte.
- **Que la herramienta de la mano sea la misma pieza del utillaje** que la simulación gasta
  y rompe (`Toolkit`): aquí se enseña un apero, no se lleva su contabilidad.
- **Animación facial, hablar, gestos de relación**: el juego no los pide todavía.

### Cómo quedó (2026-09-18)

> **Esta sección se reescribió entera.** La primera versión del trabajo montó la fontanería
> —una tabla de gestos, una pose de mano horneada, aperos de cubos y cilindros y una
> «prenda» que era la piel del propio cuerpo inflada y teñida— **sin tocar ni el modelo ni
> las animaciones**, que era el grueso de lo que se había pedido. El usuario lo dijo claro.
> Lo que sigue es el trabajo hecho.

**La banda ya no es un `MultiMesh` con la animación horneada: es una persona por nodo, con
su `Skeleton3D`.** Esa decisión la forzó la aritmética, no el gusto: con el cuerpo nuevo
—12 566 triángulos contra 1 578— y **ropa modular de verdad**, cada pieza de ropa habría
necesitado su propia textura de vértices, unos 25 MB por pieza y 60 por atuendo.

| | GPU | CPU | draw calls |
|---|---|---|---|
| Horneado en textura (antes) | 0,18 ms | 0,05 ms | 603 |
| Esqueletos con ropa (ahora) | 0,38 ms | 0,57 ms | 998 |

Medido con `scripts/tests/EsqueletosProbe.gd` en el valle 56 a 1080p en la 1070, con las dos
cosas en la misma escena y midiendo la diferencia. **El presupuesto de §1 para «Personajes»
son 2,0 ms**, así que se gasta la mitad y se compra todo lo demás.

#### De dónde sale todo

Tres packs **CC0 de Quaternius**, y lo importante es que **comparten esqueleto**: 65 huesos
con los mismos nombres en los tres, comprobado antes de tocar nada.

| Pack | Qué da |
|---|---|
| Universal Base Characters | 2 cuerpos con cara, ojos y cejas, y 8 peinados con barba |
| Modular Character Outfits | 20 piezas de ropa: torso, brazos, calzas, botas, capucha |
| Universal Animation Library | 45 animaciones |

Los dos primeros **sólo están en itch.io, que no deja descargar por script**: se intentó por
el flujo con cookies y token, por POST al fichero y por GET directo, y devuelve 404. El
espejo de poly.pizza sí deja, pero **les quita el esqueleto** —cero *skins*, cero
animaciones—, así que los bajó el usuario a mano. La biblioteca de animaciones sí se pudo,
desde OpenGameArt.

#### Las tres reglas del pack que no se adivinan

Están en [CatalogoDeCuerpos], y las tres se pagaron con capturas:

1. **La ropa trae su propia piel.** La pieza de brazos lleva dos materiales, el del atuendo
   y el de la carne. Así que el cuerpo desnudo **no se dibuja**: dejarlo puesto es lo que
   hacía que asomara por las costuras —«el cuerpo atraviesa la ropa»—.
2. **Pero el cuerpo es una sola malla con la cabeza dentro**, así que esconderlo deja a la
   persona **sin cabeza**. Se vio en captura. La cabeza se parte en frío con
   `scripts/tools/CabezaSuelta.gd`, quedándose con los triángulos que cuelgan de `Head` y
   `neck_01`: 2 912 de 12 566.
3. **Las animaciones vienen de otro fichero** y con sus pistas apuntando al esqueleto de su
   propio maniquí. Se re-enraizan a la persona. Y el export que vale es **el de Unreal**: el
   de Godot usa nombres de Rigify (`DEF-hips`) y los cuerpos usan los de Unreal (`pelvis`).

#### Los gestos: once posturas de trabajo donde había una

`ClipsDeLaBanda` reparte los ocho estados y las veinte especialidades entre los clips del
pack. No hay ninguno de tallar sílex —no existe en ningún pack libre— así que cada oficio usa
**el gesto real que más se le parece**, y lo que remata la lectura es el apero:

| Oficio | Gesto | En la mano |
|---|---|---|
| Talla, asta, peletería, cantera, ahumado | `Fixing_Kneeling` | percutor / buril / raspador |
| Forrajeo, leña | `PickUp_Table` | cesto / rollo de fibra |
| Trampas, caza menor, marisqueo | `Crouch_Idle` | — / azagaya / cesto |
| Caza mayor, orilla | `Sword_Attack` | azagaya / arpón |
| Yesquero | `Idle_Torch` | tea |
| Cordelería, cuidado | `Sitting_Idle`, `Sitting_Talking` | — |
| Batida | `Crouch_Fwd` | — |
| Altura | `Push` | arpón |

Y fuera del trabajo: se duerme sentado, se cena sentado y hablando, se bate la comarca al
trote y se prospecta agachado. **Sentarse, andar y trabajar, que era lo que se pidió.**

#### La ropa, y los aperos

`Vestuario` da un conjunto por era: qué piezas se ponen, de qué color y cuánto tapan. Son
cinco eras porque el código tiene cinco (`Site.Era`); las once de `docs/EPOCA_NN_*.md` son el
reparto del diseño. El pack libre trae dos atuendos —aldeano y montero— así que la era se
nota en las tres cosas a la vez, y el tinte hace más de lo que parece: acerca una lana
verdosa de fantasía a un cuero curtido sin gastar un triángulo.

Los aperos cuelgan de un `BoneAttachment3D` en `hand_r`. **Seis salen del «Fantasy Props
MegaKit»** (CC0, de OpenGameArt) y **dos hay que componerlos**: la azagaya y el arpón, que
ningún pack libre trae. El primer intento usó la «piedra de afilar» del pack como percutor y
resultó ser **una rueda de molino con su bancada**; se vio en captura y se cambió por una
primitiva.

#### Lo que se quedó por el camino

- **El horneado en textura de la banda**, con su `BandaAtlas`, su `Percha` y sus prendas
  infladas. `VertexAnimBaker` sigue vivo porque **la fauna sí lo usa**.
- **El modelo «Animated Human»**, que era lo que había, y sus cuatro materiales de piel.
- El arreglo del techo de 256 fotogramas del addon **se queda**: la fauna sigue con ese
  shader, y su bug era real. La sonda que lo cazaba (`TechoDeClips`) se fue con la banda:
  los horneados de la fauna no pasan de 132 fotogramas, así que ya no hay con qué
  reproducirlo.

#### Depurar del 2026-09-18: la banda hundida hasta la cintura

Al jugar, la gente salía **enterrada de medio cuerpo**. Medido con
`scripts/tests/PiesProbe.gd`, que pone una persona en `y = 0` y lee la cota de los huesos:
con el clip de estar de pie, **la planta caía a −0,83 m** y la pelvis a 8 mm del suelo. O
sea que el esqueleto estaba **aplastado**, no simplemente bajo.

**La causa no era el código de la vista: era el fichero de animaciones.** Comparando las dos
poses de reposo:

| | `root` | `pelvis` | `Head` | `ball_l` |
|---|---|---|---|---|
| Cuerpo (glTF) | 0,000 | **0,949** | **1,600** | 0,015 |
| Animaciones (FBX) | 0,000 | **0,0005** | **−0,0001** | −0,0011 |

El FBX trae **todos los huesos amontonados en el origen**. Es exactamente el fallo del que
avisa el propio pack en su léeme: *«The Unreal Engine models were exported in GLTF because of
a known scaling bug when importing rigged FBXs from Blender»*. Se leyó ese aviso al montar el
trabajo y se entendió como una advertencia sobre los **modelos**; era sobre cualquier FBX
riggeado, incluido el de animaciones.

**Las rotaciones del FBX sí valen** —no tienen unidades ni dependen del reposo, y por eso las
posturas se leían bien aunque el cuerpo estuviera aplastado—. Así que ahora
[CatalogoDeCuerpos] **se queda sólo con las pistas de rotación** y tira las de posición y
escala: las longitudes de hueso salen del esqueleto del cuerpo, que está sano. Es lo mismo
que hace el «rest fixer» de Godot al reorientar un rig.

**Y eso destapó la otra mitad.** Sin la traslación de la cadera, al doblar las piernas el
cuerpo no baja: ya no se hundía nadie, pero quien se agachaba o se arrodillaba quedaba
**flotando entre 36 y 46 cm**. Se arregla con una sola regla que vale para los dos casos:
[Cuerpo] mira cada cuadro dónde ha quedado el pie más bajo y **asienta el modelo** para que
apoye. Dos consultas de hueso por persona y cuadro.

El resultado, con los mismos diez clips:

| | planta antes | sólo rotaciones | asentado |
|---|---|---|---|
| De pie | −0,833 | +0,046 | **+0,015** |
| Andando | −0,865 | +0,011 | +0,018 |
| En cuclillas | −0,423 | +0,459 | +0,014 |
| Arrodillado | −0,527 | +0,363 | +0,032 |
| Sentado | −0,503 | +0,379 | +0,014 |

La planta en reposo está a 0,015 m —el hueso de la almohadilla va por encima de la suela—,
así que ésa es la diana, no el cero. Y la pelvis baja ya como debe: 0,85 m de pie, 0,44
en cuclillas, 0,52 arrodillado.

Coste tras el arreglo: **0,37 ms de GPU y 0,43 de CPU**, sin cambio apreciable.

#### Depurar del 2026-09-18: vestidos los que tienen vestido

La banda salía **abrigada siempre**, incluso el día 1 — que es justo cuando el utillaje
tiene cero vestidos y la barra superior pone «sin vestidos». La vista contradecía a la
partida en algo que el jugador ya podía leer en pantalla.

**La simulación no sabe quién lleva qué, y es a propósito.** Está escrito en tres sitios:
`SettlementSim.vestido_coverage` —«cobertura AGREGADA, no se sabe ni hace falta saber quién
lleva cuál»—, `Cumbres` —«el vestido es de la banda y no de nadie en concreto»— y
`Toolkit.wear_all` —«cada pieza se desgasta un poco cada jornada, la use quien la use»—. Lo
que hay es un número, `Tool.Kind.VESTIDO`.

Así que **elegir a quién se dibuja abrigado es una decisión de la vista**, y la tomó el
usuario: **primero los que salen del campamento**, porque el frío se pasa fuera y porque así
se lee de un vistazo quién va vestido al tajo. Si sobran, visten a los de dentro; si faltan,
van por orden de banda, que es estable —sin eso la ropa cambiaría de dueño cada cuadro y la
gente parpadearía—. El reparto vive en `Vestuario.quien_va_vestido` y lo calcula `Figuras`
**una vez por cuadro**, no una por persona.

Y salió gratis una coincidencia que no lo es: «estar fuera del campamento» es **la misma
lista de estados** con la que ya se decidía si se le ve el apero en la mano. Se renombró a
`ClipsDeLaBanda.FUERA_DEL_CAMPAMENTO` y contesta las dos preguntas desde un sitio.

Quien no tiene vestido va **con el cuerpo tal cual** (decisión del usuario). Cuesta un
`visible`, no rehacer nada, así que cambia en el mismo cuadro en que se cose o se rompe una
prenda. **Con un cuidado**: la malla del cuerpo entero trae la cabeza dentro, así que al
enseñarla hay que esconder la cabeza suelta o se dibujan las dos encima.

Y la banda desnuda es **más barata**: 785 llamadas de dibujo contra 991, y 0,29 ms de GPU
contra 0,37.

#### Lo que sigue sin estar

- **Los pies no se posan en la pendiente.** Estaba fuera de alcance en la spec y sigue fuera.
- **Sólo hay dos cuerpos**, hombre y mujer de proporción «superhéroe»: los otros cuatro van
  en la versión de pago del pack.
- **El atuendo es medieval teñido**, no una piel magdaleniense. A cuarenta píxeles se lee
  como cuero; de cerca es una túnica con cordones.

---

## 6. Las animaciones: el catálogo sale del código

> **AVISO (2026-09-18): ya no son siete clips genéricos, son 45.** De un pack CC0, con
> sentarse, agacharse, arrodillarse a trabajar, coger del suelo, empujar y sostener una tea.
> Ninguno es literalmente «tallar sílex» —eso no existe libre—, así que cada oficio usa el
> gesto que más se le parece y el apero acaba de separarlos: son **once posturas de trabajo
> distintas** donde había una. La tabla está en `ClipsDeLaBanda`. Ver §5.1.

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
| Agua (§7.3) | el río pintado en el terreno | orilla, piedras y estela | lámina transparente sobre el lecho | lámina con reflejos y salpicaduras | sí |
| Clima (§7.4) | apagado | encendido | encendido | encendido | sí |
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
> - **La distancia del 3D al máximo** (slider de INTERFAZ §8.7), `RADIO=1000`, una
>   corrida: el bosque **34 ms en el juego alto, 54 en el bajo y 67 en la medida**, con
>   32-54 millones de triángulos, y **57 s en montar el mapa**. **Y «sin límite» no se
>   puede**: con `RADIO=100000` Godot deja de crear los grupos de árboles
>   («Element limit reached», más de 7 000 errores y 5,2 GB de RAM). El 3D va por
>   bloques de 32 m con un grupo por especie, variante y nivel de detalle, y el mapa
>   entero son 16 384 bloques. El slider acaba en 1000 m desde el 2026-09-15; que quepa
>   el mapa entero —agrupar lejos en bloques mayores— va por `/spec` (ROADMAP).
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
  **Corregido el 2026-09-16: se veía el borde de la pared.** El tope estaba en el
  punto al que se mira —un metro antes del borde— y a 7,5 m con 55° de campo el
  encuadre se come 3,9 m más a cada lado. Ahora el límite sale de lo que **cabe en
  pantalla** (`SalaDeLaCueva.encuadre`): no se aleja más de lo que deja la pared llenar
  el alto —unos 4,6 m, la pared mide 4,8— y no se desplaza más allá de donde el borde
  entraría. Cinco pruebas en `TestPared`.
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

## 7.3. El agua (spec, 2026-09-15)

> **Spec escrita con `/spec` el 2026-09-15**, con las decisiones del usuario sacadas
> a preguntas. El ajuste en la ventana, en [INTERFAZ.md](INTERFAZ.md) §8.8.

### Qué problema cierra

El agua del valle es lo más pobre de lo que se ve. **Los ríos** son una cinta de
color pintada sobre el terreno con un movimiento de normales: el mismo aspecto en
un remanso que en una cascada, sin espuma, sin rápidos y sin fondo. **El mar y la
ría** son un plano liso semitransparente a la cota del mar, sin oleaje ni espuma de
orilla. En un juego que va de una banda que vive de la ribera —pesca, marisqueo,
agua, nasas, pasarelas—, el río se tiene que leer como río.

### Lo que se pide

- **Qué agua**: **los ríos del valle** y **el mar y la ría del valle** (decisión del
  usuario). El agua del mapa regional se queda como está.
- **Un selector «Agua» con cuatro niveles** en la configuración gráfica (decisión del
  usuario), y **cada nivel general pone el suyo**, como las sombras o los árboles;
  moverlo deja la configuración en Personalizado.

  > **Corregido al planear, el mismo día** (decisión del usuario): la primera
  > escalera ponía la corriente en Medio y la espuma de rápidos en Alto, pero **el río
  > de hoy ya tiene las dos** —la dirección del cauce sale de OSM, dos capas de ondas
  > bajan con el agua y la espuma sale donde el cauce desciende—, así que «Bajo como
  > hoy» y «Alto añade la espuma» se contradecían. La escalera sube desde lo de hoy:

  - **Bajo**: **el río de hoy, tal cual**: corriente por el cauce y espuma en los
    rápidos, pintados sobre el terreno.
  - **Medio**: lo de Bajo y **la orilla**: una franja de espuma donde el agua lame la
    tierra, el fondo de cantos que se ve en lo somero y el color según lo hondo.
  - **Alto**: lo de Medio y **una superficie de agua propia** sobre el cauce, **con
    transparencia y el lecho debajo**, y espuma más rica que **se acumula en los
    remansos**.
  - **Ultra**: **«que parezca agua de río real»** (petición del usuario): lo de Alto,
    con **salpicaduras** en los rápidos y **reflejos** del cielo y la orilla, todo al
    máximo.
- **El mar y la ría**, con **oleaje** y **espuma de orilla** —de rompiente en Alto y
  Ultra—. **En el Paleolítico no se ven en ningún valle preparado**: el mar está a
  −120 m, el relieve local no trae fondo marino y la cota más baja de los valles es
  10,8 m (sitio 0). **Se comprueban con un valle costero de prueba**, subiendo el mar
  en una sonda (decisión del usuario). Que haya yacimientos con costa en el
  Paleolítico —sobre la plataforma emergida— es otro trabajo, por `/spec` (ROADMAP).
- **Si se aplica en caliente o al montar el mapa se mide** y se escribe en la tabla de
  §7, como la vegetación y los árboles.

### Criterios de aceptación

- **Se da por bueno con fotos y con el visto bueno del usuario** (decisión suya), como
  el bosque: **fotos de referencia de ríos cantábricos** —Nansa, Deva, un rápido, un
  remanso y una orilla de ría—, con su licencia en [CREDITOS.md](CREDITOS.md), y
  **capturas del juego en el mismo encuadre** al lado, en Medio y en Ultra. Sin su
  visto bueno, Ultra no está hecho.
- **La espuma de rápido sale donde el cauce tiene pendiente o piedras, y no en un
  tramo llano**: con un cauce construido, llano y con un escalón, la espuma es cero en
  el llano y está en el escalón. Prueba sobre lo que decide la espuma.
- **La corriente va aguas abajo** en cada tramo: la dirección del flujo apunta hacia
  donde baja el cauce. Prueba sobre un cauce construido que gira.
- **La orilla tiene espuma y el centro del río no**, en Medio y más: captura con la
  máscara de espuma.
- **Cada nivel pone su agua** y moverla personaliza: prueba, como la de los árboles.
- **Coste: Medio no más de 1 ms de GPU** sobre Bajo, a 1080p, con un río en pantalla,
  alternando en la misma corrida (decisión del usuario). **Alto y Ultra, sin tope**
  —«haz el mejor río que puedas y si hace falta reducimos»—: se miden igual y se
  escriben en la tabla de §7.
- **No toca la partida**: dónde hay agua, qué se pesca y por dónde se cruza no cambian
  con el nivel. La firma de una partida es la misma en Bajo y en Ultra.

### Fuera de alcance

- **El agua del mapa regional.**
- **Simular el agua**: caudal que cambia, crecidas visibles, ríos que se desbordan con
  la lluvia, objetos que flotan.
- **Cambiar por dónde van los ríos** o su anchura: son datos del relieve (§2).
- **Sonido** del agua.
- **Cascadas verticales** con geometría propia: los rápidos son lo que el cauce da.
- **Yacimientos con costa en el Paleolítico** para ver el mar jugando: spec escrita el
  2026-09-16 en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md) §10.2.

### Plan técnico (2026-09-15)

**Lo que ya hay, leído en el código** —y que la spec suponía que no—: el río es
color de vértice sobre la malla del terreno (`MallaDelTerreno`: `rg` la corriente de
OSM, `b` agua quieta, `a` la lámina), pintado en `shaders/triplanar.gdshader` con dos
fases de normales que bajan con la corriente, color por hondura (`river_shallow_color`)
y espuma de rápido por **caída aguas abajo** calculada en el shader con la normal. El
mar es un `PlaneMesh` de 32×32 con un `StandardMaterial3D` a la cota del mar
(`TerrainGenerator._create_water`), y sólo se crea si el relieve baja de esa cota. El
entorno tiene `enable_ssr` apagado (`WorldEnvironmentSetup`).

**Módulos.**

| Qué | Dónde | Contrato |
|---|---|---|
| **El ajuste** «agua» 0-3, en `AJUSTES` y `NIVELES`, con el valor de su nivel para un fichero de antes | `scripts/vista/Configuracion.gd`, `scripts/ui/VentanaDeConfiguracion.gd` | vista; INTERFAZ §8 |
| **Lo que decide la espuma de rápido y la de orilla, en la CPU** y horneado en la malla, para que se pueda probar | `scripts/mundo/MallaDelTerreno.gd` (canal de vértice propio), nuevo `scripts/mundo/AguaDelCauce.gd` (funciones puras) | mundo, SPECS §4.3 |
| **Medio**: orilla, fondo de cantos y hondura | `shaders/triplanar.gdshader` (grupo `rivers`) | shader |
| **Alto**: la lámina propia sobre el cauce, transparente, y el lecho hundido **sólo al dibujar** | nuevo `shaders/agua_rio.gdshader`; la malla de la lámina en `MallaDelTerreno`; el hundido en el vértice de `triplanar.gdshader` | mundo / shader |
| **Ultra**: salpicaduras en los rápidos y reflejos | nuevo `scripts/vista/SalpicadurasDelRio.gd` (partículas en los puntos de más rápido cerca de la cámara); ~~SSR del entorno en Ultra~~ reflejos en el shader de la lámina —ver «Riesgos»— | vista |
| **El mar** con oleaje y espuma de orilla | nuevo `shaders/agua_mar.gdshader` en `TerrainGenerator._create_water` | mundo / shader |
| **Aplicar en caliente** lo que se pueda | `TerrainMaterialManager.aplicar_configuracion`, `TerrainGenerator.aplicar_configuracion`, `WorldEnvironmentSetup.aplicar_configuracion` | grupo `configuracion_grafica` |
| **Las sondas** | nueva `scripts/tests/AguaCaptura.gd` (encuadres de rápido, remanso y orilla elegidos por los datos, y la costa de prueba con `MAR=`), `GpuProfile.gd` modo `AGUA=1` | ARQUITECTURA §5.1 |
| **Las pruebas** | nueva `scripts/tests/TestAgua.gd` | — |

**Decisiones de arquitectura, sólo las que la spec obliga a tomar.**

1. **Lo que decide dónde hay espuma se calcula en la CPU y se hornea en la malla**, no
   en el shader: la spec pide probar que la espuma sale en el escalón y no en el llano,
   y la suite no ejecuta shaders (va sin ventana). `AguaDelCauce` da, por celda, cuánto
   rápido y cuánta orilla hay a partir de las alturas, la lámina y la corriente; la
   malla lo lleva en un canal de vértice y el shader sólo lo lee. **Una pregunta, un
   sitio**: la caída aguas abajo deja de calcularse en el shader.
2. **El lecho se hunde sólo al dibujar**: en el vértice del terreno, bajo la lámina, en
   proporción a lo hondo. **Los mapas de alturas no se tocan**: la banda anda, vadea y
   mide con los de siempre, y la firma no cambia con el nivel. Sin hundirlo, la lámina
   transparente de Alto no tendría nada debajo que enseñar: el relieve LiDAR es la
   superficie del agua, no el fondo.
3. **La caché de la malla cambia de versión** (`TerrainGenerationCache.CACHE_VERSION`):
   lleva un canal más. Se rehace una vez por valle y la del regional una vez.
4. **Cada nivel incluye al de abajo**, y en un solo shader por agua con interruptores,
   como `use_orm`: cambiar de nivel es cambiar uniformes y encender o apagar nodos, en
   caliente. Si algo no se puede en caliente, se mide y se dice en la tabla de §7.
5. **Las salpicaduras no llenan el río**: un número fijo de emisores en los puntos de más
   rápido cerca de la cámara, repartidos cada vez que la cámara cambia de bloque, como el
   3D del bosque.
6. **El mar se prueba subiendo el mar**: `AguaCaptura MAR=30` sobre el sitio 0, el valle
   preparado de cota más baja, pone parte del valle bajo el agua sin tocar la partida.

**Orden de dependencias.** Medir hoy y fijar encuadres primero, para comparar; el
ajuste antes que ningún nivel; lo que decide la espuma antes que Medio, que lo usa; la
lámina antes que Ultra, que la refleja; el mar aparte; las fotos de referencia en
cualquier momento; y el visto bueno del usuario al final, sobre capturas de todo.

**Riesgos técnicos.**

- **Lo que va por el fondo del río se verá hundido**: la gente al vadear y las nasas
  quedan a la cota de siempre, así que con el lecho hundido pueden flotar un palmo sobre
  él. Se mira en captura; si canta, se limita la hondura en los vados.
- **La lámina en celdas de 5 m**: la malla del terreno va a unos 5 m por vértice y los
  arroyos estrechos son dientes. La lámina hereda esa rejilla; alisarla es otro trabajo.
- ~~**SSR es del entorno entero**, no sólo del agua: en Ultra refleja también lo demás que
  sea liso. Se mide su coste aparte.~~ **Se cayó al implementar**: el SSR de Godot sólo
  refleja en materiales opacos y la lámina es transparente, así que no le llegaba. Los
  reflejos van dentro del shader de la lámina, recorriendo la pantalla con el buffer de
  profundidad, y sólo en Ultra; el entorno no se toca.
- **Transparencia y orden de dibujo**: la lámina es transparente sobre el terreno opaco y
  bajo las partículas del tiempo; lo que no se ordene bien se ve en captura.
- **«Que parezca real» no se puede probar**: se da por bueno con las fotos y con el visto
  bueno del usuario, y eso puede pedir varias vueltas.

### Cómo quedó (2026-09-16)

**Visto bueno del usuario el 2026-09-16**, tras tres vueltas al rápido y la orilla sobre
las capturas de `AguaCaptura` junto a las fotos del Pas (CREDITOS).

**Qué pone cada nivel.**

- **Bajo**: el río pintado en el terreno, con la espuma de rápido.
- **Medio**: además, la orilla —una banda fina de espuma por dentro de la línea del agua
  y fondo de cantos en lo somero—, **las piedras** de los rápidos (`PiedrasDelRio`, peñas
  de la biblioteca hundidas en el agua) y **la estela** detrás de cada una.
- **Alto**: el agua deja de pintarse en el terreno y la dibuja **una lámina
  transparente** propia (`agua_rio.gdshader`) sobre el lecho, que se hunde 0,8 m sólo al
  dibujar; el color sale del grosor de agua medido con el buffer de profundidad.
- **Ultra**: refracción, **reflejos recorriendo la pantalla** dentro del shader de la
  lámina —el SSR de Godot no llega a lo transparente— y **salpicaduras** en las piedras
  más cerca de la cámara (`SalpicadurasDelRio`, 12 emisores).
- **El mar** (`agua_mar.gdshader`): oleaje, color por hondura y espuma de orilla desde
  Medio, rompiente desde Alto y refracción en Ultra, probado con `MAR=30` en el sitio 0.

**Qué decide la espuma, y dónde.** `AguaDelCauce` hornea por vértice la caída aguas abajo
(el rápido), la orilla, las piedras y la corriente suavizada para dibujar; la partida no
lo usa. **La línea del agua es 0,5 de la lámina** (`LINEA_DEL_AGUA`): por debajo es ribera
mojada, no agua.

**La espuma es viva** (`espuma_viva.gdshaderinc`): ruido hecho en el shader, arrastrado en
dos fases que se cruzan y con un segundo campo que la forma y la deshace. **La estela**
(`estela_de_piedras.gdshaderinc`) nace en la piedra, se mece, se rompe en manchas que
bajan con el agua y, en la lámina, lleva grano de burbujas.

**Lo que salió al hacerlo, que es lo que más costó.**

- **Astillas triangulares en la espuma de cerca**: no eran la luz ni la corriente —se
  vio pintando el ruido sin luz y parado—, sino **el hash del ruido sin precisión**. El
  río está a miles de metros del origen y en la cuarta octava la celda pasa de diez mil:
  `fract(p * 456.21)` en 32 bits devolvía pocos valores en rejilla. La celda va módulo 289.
- **La orilla en dientes de sierra**, con una mancha de espuma en cada punta. Tres causas
  y tres arreglos: el agua y los cantos subían talud arriba por la humedad interpolada
  —en una cara empinada ya no—; la lámina trepaba al vértice de tierra —no sube más de
  25 cm sobre el agua de al lado, `AguaDelCauce.LAMINA_SUBE_M`, y la corta el talud—; y
  sobre todo **la malla del terreno se partía siempre por la misma diagonal**, que plegaba
  en picos el pie de un talud que corre en diagonal a la rejilla. Ahora cada cuadro se
  parte por la diagonal en que el relieve está más recto
  (`MallaDelTerreno.diagonal_principal`; sólo el dibujo, caché v10). Eso mejora el relieve
  de todo el mapa, no sólo el río. Montarlo sin caché cuesta unos 2 s más.
- **Una lámina plana a la cota del agua** se probó y se quitó: en la orilla tendida tocaba
  el lecho hundido por vértice en escalones de celda (visto en falso color).
- **El coste de la espuma viva**: calculada en todo píxel de río, Medio llegó a 1,5-4,6 ms.
  Ahora se calcula sólo donde hay rápido, piedra u orilla; el terreno no la calcula en Alto
  y Ultra, donde no la pinta; y Bajo y Medio usan dos octavas y la estela reutiliza el
  ruido del rápido.

**Lo que cuesta**, `AguaCaptura GPU=1` (el agua encendida y apagada en el mismo proceso,
sitio 56, 1920×1080):

| | rápido | remanso | orilla | arriba | rápido de cerca |
|---|---|---|---|---|---|
| Bajo | | | | | 0,86-1,16 |
| **Medio** | 0,58-0,60 | 0,17-0,38 | 0,48-0,64 | 0,63-0,69 | 1,30-1,38 |
| Ultra | 1,18 | 2,33 | 1,88 | 1,16 | 5,04 |

Medio, dos corridas; las cuatro primeras columnas, con el código de antes del último
recorte, que sólo toca la estela. **Medio cuesta 0,2-0,5 ms más que Bajo con el río
llenando la pantalla, dentro del tope de 1 ms sobre Bajo.** Ultra, una corrida y sin tope
(decisión del usuario).

**Deuda que queda, dicha.**

- **Bajo ya no es exactamente el río de antes**: la espuma viva se pinta en todos los
  niveles, y de cerca Bajo cuesta 0,86-1,16 ms de agua, que antes eran 0,37.
- **Los dientes de roca de los taludes** que quedan en el remanso son del relieve, no del
  agua.
- **Si la gente al vadear flota un palmo sobre el lecho hundido** en Alto y Ultra no se ha
  mirado en captura.
- **`AguaCaptura` se cierra con un fallo de Godot al salir** (se destruye con el render
  vivo); las capturas y las medidas salen antes y bien.
- **`ver_termino`** se queda como depuración del shader del terreno (1-7), y lo que pinta
  va sin luz, para no confundir un dibujo con un brillo.

---

## 7.4. El clima en pantalla (spec, 2026-09-15)

> **Spec escrita con `/spec` el 2026-09-15**, con las decisiones del usuario. El
> interruptor, en [INTERFAZ.md](INTERFAZ.md) §8.8. **Lo que el tiempo hace en la
> partida no cambia**: ya decide lo que cunde la jornada, lo que se anda y hasta dónde
> se ve (`Weather`); esto es cómo se ve.

### Qué problema cierra

El tiempo del juego existe —orbayu, lluvia, temporal, niebla, nieve— y decide cosas
importantes, pero **se ve poco**: gotas y copos en una caja que va con la cámara, y
una niebla de distancia que sube. **La niebla no se ve como niebla**, la nieve no
cuaja, el suelo no se moja y un temporal tiene la misma luz que un día nublado. El
jugador se entera del tiempo por el rótulo.

### Lo que se pide

**Sólo en el mapa de la banda** (decisión del usuario): el regional no tiene tiempo
que dibujar.

- **La lluvia, por intensidad.** Orbayu, lluvia y temporal **distintos**: cuántas
  gotas, qué tamaño y **cuánto las inclina el viento**. **El suelo y las rocas se
  mojan** —más oscuros y con brillo— mientras llueve, y **se secan poco a poco** al
  parar.
- **La nieve que cuaja.** Además de caer, **el terreno se blanquea** donde nieva,
  con la **cota de hielo** que ya calcula el termómetro (SISTEMAS §19), y **se quita
  poco a poco** al acabar.
- **La niebla de valle.** Nubes bajas **con volumen** que se quedan **en el fondo del
  valle y no en lo alto**; **bajan la visibilidad sin taparla**: se nota que hay
  niebla y se sigue viendo el valle. **Cuando la cámara se mete dentro, condensación
  en la cámara** —la imagen se empaña—, y se quita al salir (decisiones del usuario).
- **El nublado y el temporal en la luz.** El cielo **y la luz del sol** cambian con el
  tiempo: **luz plana** con nublado y orbayu, **más oscuro** con temporal. Hoy sólo
  cambian las nubes del cielo.
- **Un interruptor «Clima»** en la configuración gráfica (decisión del usuario):
  **apagado no se dibuja nada del tiempo** —ni partículas, ni niebla de valle, ni
  suelo mojado, ni nieve cuajada, ni la luz del temporal—; **encendido en todos los
  niveles salvo Bajo**. Apagado o encendido, **el tiempo sigue haciendo lo que hace**
  en la partida.

### Criterios de aceptación

- **Cada tiempo tiene su captura**, en el mismo encuadre de la banda: despejado,
  nublado, orbayu, lluvia, temporal, niebla y nieve, y nieve al día siguiente de
  parar.
- **Las tres lluvias se distinguen por cifras**: más partículas y más inclinación de
  orbayu a lluvia y de lluvia a temporal. Prueba sobre lo que se le pide a la vista.
- **El suelo se moja y se seca**: lo mojado sube mientras llueve y baja al parar, sin
  saltos. Prueba sobre el valor que lo lleva, con jornadas construidas.
- **La nieve cuaja donde hiela**: por encima de la cota de hielo sí y por debajo no,
  y se va poco a poco al acabar. Prueba con la cota construida.
- **La niebla de valle es más densa abajo que arriba**: a la cota del fondo del valle
  hay más que en la cumbre más alta del mapa. Prueba sobre lo que decide la densidad.
- **La condensación sale sólo con la cámara dentro de la niebla**: dentro sí, encima
  de la capa no, sin niebla no. Prueba.
- **Apagado no dibuja nada**: sin partículas, sin niebla de valle, sin mojado ni
  nieve. Prueba y captura.
- **No toca la partida**: la firma de una partida es la misma con el clima encendido
  y apagado. Prueba.
- **Coste, sin tope** (decisión del usuario): con el tiempo más caro en pantalla —
  temporal y niebla de valle—, a 1080p, clima sí y no en la misma corrida; se mide y
  se escribe en la tabla de §7.

### Fuera de alcance

- **El clima en el mapa regional.**
- **Cambiar qué hace el tiempo en la partida**, o cuándo sale cada uno.
- **Nieve sobre árboles, obras y personas**, charcos, barro y ríos que crecen.
- **Rayos, truenos y sonido.**
- **Niveles del clima**: es un interruptor.

### Plan técnico (2026-09-16)

**Lo que hay hoy en el código, que es lo que manda el plan.**

- `Weather` (`sim/`) decide el tiempo **por jornadas**: despejado, nublado, orbayu,
  lluvia, temporal, niebla y nieve, con `days_running`. La partida lo usa; nada de lo
  que sigue lo toca.
- `WeatherView` (`vista/`) pinta hoy: lluvia y nieve con `GPUParticles3D` en una caja de
  200 m que va con la cámara, **la misma lluvia para orbayu, lluvia y temporal** salvo
  la cantidad; una bruma de pantalla que cierra los bordes; y la niebla del entorno algo
  más densa. `DemoMain._sync_weather` le pasa el tiempo y también las nubes del cielo
  (`WorldEnvironmentSetup.nubes_por_el_tiempo`).
- **La luz** la lleva `WorldEnvironmentSetup`: `_place_sun` pone la energía del sol por
  la hora y `_update_ambient` la del ambiente. El tiempo no la toca.
- **La cota de hielo** es `Termometro.cota_de_hielo(estación)`, y `Temporada` ya la pasa
  al shader del terreno como `snow_min_height` —la nieve **de la estación**, en fracción
  del relieve (`Temporada.fraccion_de`)—.
- **El terreno** es `shaders/triplanar.gdshader` con sus capas; las peñas sueltas, los
  MultiMesh de `ResourceProps` y `PiedrasDelRio`.
- No hay interruptor «Clima» en `Configuracion`.

**Módulos afectados.**

1. **`Configuracion` y la ventana**: el ajuste `clima`, encendido en Medio, Alto y Ultra y
   apagado en Bajo, y la casilla en la pestaña Gráficos (INTERFAZ §8.8).
2. **`ClimaEnPantalla` (`vista/`, nuevo)**: **lo que se le pide a la vista**, sin nodos, para
   probarlo sin ventana. Una tabla por tiempo —partículas, tamaño e inclinación de la
   lluvia; si hay niebla de valle; energía del sol, opacidad de las sombras y ambiente— y
   **el suelo**: `mojado` y `nieve` de 0 a 1, que avanzan **por horas de juego**
   (`una_hora(tiempo)`) y se asientan al montar el mapa (`asentar(tiempo, días)`).
3. **`WeatherView`**: la lluvia y la nieve por la tabla, inclinadas por un viento que la
   vista elige; el suelo avanza con `SettlementSim.hour_passed` y se suaviza por cuadro;
   y **apagado no dibuja nada** (`aplicar_configuracion`, grupo de la configuración).
4. **El terreno y las peñas**: `triplanar.gdshader` gana `clima_mojado` —más oscuro y con
   brillo— y `clima_nieve` con `clima_cota_de_nieve` —blanco encima de la cota, más en lo
   llano—. La cota sale de **la misma cuenta de `Temporada`** pasada a altura del mundo, no
   de otra. Las peñas llevan un `material_overlay` (`clima_encima.gdshader`) que lee lo
   mismo.
5. **`NieblaDeValle` (`vista/`, nuevo)**: una caja sobre el valle con un shader que avanza
   por dentro (`niebla_de_valle.gdshader`), ruido 3D que se mueve con el reloj de la
   partida, y cortado por la profundidad. **El fondo del valle** se hornea al montar: por
   celda, la cota más baja en unos cientos de metros, suavizada; la densidad cae con la
   altura sobre ese fondo. La densidad **sólo decide en GDScript lo que la prueba mira**
   —fondo y perfil—, y el shader los recibe como textura y uniformes.
6. **La condensación**: una capa de pantalla que empaña —desenfoque y gotas finas— cuando
   la cámara está **dentro** de la niebla (`NieblaDeValle.dentro(punto)`), entrando y
   saliendo en un segundo.
7. **La luz del tiempo**: `WorldEnvironmentSetup.luz_por_el_tiempo(tiempo)` multiplica la
   energía del sol, la opacidad de las sombras y el ambiente que ya pone la hora, con
   transición. Apagado el clima, factores a uno.
8. **`ClimaCaptura` (`tests/`, nueva)**: los ocho encuadres de la spec y el coste.

**Decisiones que tomo, y se dicen.**

- **El suelo mojado y la nieve viven en la vista**, no en la partida: al cargar o entrar en
  un mapa se asientan por el tiempo que hace y los días que lleva (`asentar`). Guardarlos
  sería meter vista en la instantánea.
- **Ritmos del suelo** (se miran en captura): el orbayu moja hasta 0,6 en unas seis horas,
  la lluvia del todo en tres y el temporal en una; seca en unas dieciocho horas. La nieve
  cuaja en unas ocho horas y se va en unos dos días.
- **La niebla de valle, sólo con NIEBLA**, unos 60 m de espesor sobre el fondo que se
  apagan hacia los 120 m. **La bruma de los bordes se queda para la niebla**, más suave,
  porque la de valle ya quita visibilidad.
- **El viento de la lluvia** lo sortea la vista por jornada, con el día como semilla: no
  sale del `_rng` de la partida, que no debe consumirse para dibujar (SPECS §3.3).
- **Las peñas se mojan y se nievan; los árboles, obras y personas, no** (fuera de alcance).

**Orden de dependencias.** El interruptor y la tabla primero, porque todo lo lee; las
partículas y el suelo antes que el shader que los pinta; el fondo del valle antes que la
niebla y la condensación; la luz aparte; las capturas y el coste al final, con todo.

**Qué contrato cambia**: ninguno. Es vista (SPECS §4.7): lee `Weather` y la hora, no
escribe en la partida, y avanza con `hour_passed` (SPECS §3.2, invariante 4).

**Riesgos técnicos.**

- **La nieve cuajada y la de la estación usan la misma cota**: en invierno, lo alto ya sale
  blanco por `snow_min_height`, y la nevada tiene que notarse encima —cubre todas las capas
  y baja por las laderas tendidas—. Se mira en captura.
- **Una regla en dos sitios**: la cota y el perfil de la niebla se calculan en GDScript y se
  pintan en el shader; se pasan como uniformes y textura para que el shader no repita la
  cuenta.
- **La niebla que avanza por dentro** cuesta por píxel de pantalla que la cruza: con el valle
  lleno, varios ms. Sin tope, pero se mide y se escribe.
- **La cámara de gestión va alta**: dentro de la niebla sólo se entra acercándose. La
  captura de la condensación se hace metiendo la cámara.

### Cómo quedó (2026-09-16)

**Qué se ve con el clima encendido**, en el mapa de la banda:

- **La lluvia por intensidad** (`WeatherView` con la tabla de `ClimaEnPantalla`): orbayu
  3 000 gotas de 3 cm inclinadas 8°, lluvia 8 000 de 6 cm y 16°, temporal 16 000 de 8 cm y
  38°, soplando desde un viento que la vista elige por jornada. La gota va alineada a su
  caída en dos tiras cruzadas, en una caja de 140 m de lado a la altura de la cámara. El
  orbayu apenas se ve, que es lo que es.
- **El suelo mojado y la nieve que cuaja**: `ClimaEnPantalla` los lleva por horas de juego
  —el orbayu moja a 0,6 en seis horas, la lluvia del todo en tres, el temporal en una; seca
  en dieciocho; la nieve cuaja en ocho y se va en dos días— y `WeatherView` los pinta en el
  terreno (`clima_mojado`, `clima_nieve`, con la cota de `Temporada`) y encima de las peñas
  (`clima_encima.gdshader`). Nieva encima de la cota de hielo y en lo tendido, y no sobre el
  agua. No se guardan: al entrar en el mapa se asientan por el tiempo que hace.
- **La niebla de valle** (`NieblaDeValle`, `niebla_de_valle.gdshader`): una caja que se
  recorre en 28 pasos con un ruido 3D, entera hasta 60 m sobre el fondo del valle horneado y
  apagada a 120, con un tope del 65 %. Sólo con niebla; la bruma de los bordes baja con ella
  de 0,8 a 0,35.
- **El agua en la cámara**, al meterla en la niebla: gotas sueltas sobre la lente, cada una
  una lente que ve la escena del revés, con el borde oscuro y un brillo, sobre un fondo casi
  limpio (`gotas_en_la_camara.gdshader`).
- **La luz del tiempo** (`WorldEnvironmentSetup.luz_por_el_tiempo`): factores sobre el sol,
  las sombras y el ambiente —plana con nublado, orbayu y niebla; oscura con temporal—.
- **Apagado no dibuja nada** de lo anterior, y el suelo sigue contando horas.

**Lo que cuesta**, `ClimaCaptura`, 1080p, clima sí y no alternando en la misma corrida,
mínimo de tres vueltas, tres corridas: **temporal +0,13 a +0,17 ms, niebla de valle +1,48 a
+1,72 ms**. Sin tope (decisión del usuario).

**Lo que salió al hacerlo.**

- **La lluvia no se había visto nunca.** La caja de partículas iba a cota cero, bajo el
  relieve real; subida a la cámara, su caja de visibilidad quedaba por encima de lo que se
  mira y Godot descartaba la lluvia entera. La pista fue **el coste: cero con temporal**.
- **Con 400 m de lado se veían cuatro rayas**, y las gotas que pasaban pegadas a la cámara
  eran barras: caja de 140 m y gotas que se apagan a menos de 12 m.
- **La primera niebla tapaba el fondo del valle** en blanco: menos extinción y un tope.
- **El primer efecto de agua en la cámara** era un desenfoque gris con motas, y el usuario
  lo rechazó con una imagen de referencia («el que tenemos es horroroso»): se rehízo como
  gotas que hacen de lente. Pendiente de su visto bueno.
- **Las pruebas del clima heredaban el ajuste de otra suite** (Bajo, apagado): pasaban solas
  y fallaban en la suite entera. Ahora lo ponen ellas.

**Deuda que queda, dicha.**

- **La nieve de la estación y la del tiempo usan la misma cota**: en invierno lo alto ya es
  blanco, y la nevada se nota sobre todo bajando por lo tendido.
- **La lluvia se lee cerca de la cámara**: desde la altura de gestión son rayas sueltas, y
  el temporal se lee más por la luz que por el agua.
- **Lo mojado se ve poco** en la captura de gestión: más oscuro, y el brillo depende del sol,
  que con lluvia está bajo mínimos.

---

### Depurar del 2026-09-16: la lluvia con el zoom, y las gotas en el agua

**La lluvia desaparecía al mover la cámara** —«desaparece un momento, y después a veces
se reinicia, pero lejos, y saliendo sólo de un cuadrado»—. Dos causas:

- **Las gotas nacían en coordenadas de mundo** y la caja seguía a la cámara: al moverse,
  las que ya caían se quedaban atrás y las nuevas nacían en otro sitio. Ahora viajan
  con la caja (`local_coords`).
- **La caja medía 70 m siempre**, y desde lejos se veía entera: un cuadrado de lluvia en
  medio del valle. Ahora crece con la órbita —88 m a 80 m de órbita, 264 m a 240, tope de
  320—, con más gotas y algo más grandes para que en pantalla se lea igual, y su caja de
  visibilidad va con ella (si se queda corta, Godot descarta la lluvia entera).

Y las gotas pegadas al ojo se apagan ahora antes de 8 m y no de 3: salían como barras
blancas cruzando la pantalla. Comprobado con `ClimaCaptura SOLO=zoom` a tres zooms.

**Las gotas en el agua** (petición del usuario): anillos que nacen, crecen y se apagan,
en la lámina del río y en el mar (`gotas_en_el_agua.gdshaderinc`, común a los dos). Una
gota cada metro y medio, en dos capas de escala distinta para que no se lea la rejilla, y
la cresta del anillo clara: **sin ella no se veían** —la primera captura enseñaba unas
culebrillas que, comparando con la misma agua sin lluvia, resultaron ser la espuma de
orilla de siempre—. Lo que pica sale de la lluvia que cae ahora (`WeatherView.lluvia_vista`),
no de lo mojado del suelo: para de llover y los anillos se van en dos segundos.

---

## 7.5. El día y la noche: ya está encendido (2026-09-17)

> **Esta sección era una spec, y la spec partía de un dato falso.** Se escribió el
> 2026-09-16 diciendo «el sol está clavado a las 12:00, el ciclo se apagó a propósito»,
> y al ir a planearla el 2026-09-17 resultó que **el ciclo lleva encendido desde el
> 2026-09-07**. El usuario decidió entonces **dejar la luz exactamente como está** y
> quedarse con lo medido. Abajo está lo que dice el código y lo que dio la medida; la
> spec vieja no se conserva porque describía un juego que no existe.

### De dónde salió el error, que es lo que importa

`WorldEnvironmentSetup` tiene `@export var follow_time_of_day: bool = false` con un
comentario que decía «de momento va desactivado: el ciclo está implementado y funciona,
pero para trabajar en el terreno estorba tener medio mapa a oscuras». **Ese comentario
llevaba diez días siendo mentira**: `scenes/WorldEnvironment.tscn` pone
`follow_time_of_day = true`, y esa escena es la que instancian `demo_main` y
`region_map`. El `@export` es el valor de fábrica; el de la escena es el que corre.

La lección, que ya está en CLAUDE.md y aquí se cobró una spec entera: **un comentario
sobre el estado de una opción caduca en cuanto alguien toca la escena**, y nadie vuelve
a leerlo. El comentario quedó corregido el 2026-09-17.

### Lo que hace hoy, medido

`NocheLuzProbe` (ventana, 1080p, sitio 56, una noche con la luna alta y el hogar
encendido; `DIAS=1 FIJO=1 HORAS=6,9,12,15,18,21,23`), brillo medio de la pantalla:

| hora | pantalla | % del mediodía | altura del sol |
|---|---|---|---|
| 6:00 | 0,1558 | 72 % | 4,1° |
| 9:00 | 0,2024 | 93 % | 35,7° |
| 12:00 | 0,2171 | 100 % | 52,7° |
| 15:00 | 0,2041 | 94 % | 35,7° |
| 18:00 | 0,1662 | 77 % | 4,1° |
| 21:00 | 0,0957 | 44 % | −26,1° |
| 23:00 | 0,0839 | **39 %** | −38,9° |

O sea: **el sol sigue la hora de la partida** —de 52,7° a mediodía a −38,9° a las once
de la noche—, la luna se enciende de noche y se apaga de día, y **las hogueras alumbran**
(28,4 de energía y 85 m de alcance, con sombras).

**Y la noche se queda al 39 % del mediodía**, que es un día muy nublado y no una noche.
Se deja así a propósito: decisión del usuario del 2026-09-17. La cifra vive también en
[ESTADO.md](ESTADO.md) §2, que es donde se apuntan los huecos entre lo que se pretendía
y lo que hace el juego.

### Dos cosas que conviene saber si alguien vuelve aquí

- **El mapa regional se queda con luz fija por su cuenta**, sin interruptor ninguno:
  `_find_sim()` busca un `sim` en la escena actual y `RegionMap` no tiene, así que
  `_process` se va sin mover el sol. No es una decisión escrita en ningún sitio: es una
  consecuencia. Si algún día el regional necesita hora, hay que ponérsela a mano.
- **La noche dura 1,6 segundos de reloj.** `SettlementSim.NOCHE_HORAS_POR_SEGUNDO = 5.0`:
  en cuanto la banda se acuesta, ocho horas de juego pasan en un parpadeo. Lo único que
  se ve del ciclo, por tanto, es el atardecer y el amanecer — y ésos salen al 72-77 % del
  mediodía. Quien quiera «ver» la noche tiene ahí el número que tocar, no en la luz.

## 7.6. Ver a la gente trabajar: los viajes abreviados y la cámara lenta (spec 2026-09-16, hecho 2026-09-17)

> **Spec escrita con `/spec` el 2026-09-16**, a partir de una pregunta del usuario:
> «incluso a la velocidad normal todo se mueve extremadamente rápido; ¿se te ocurre
> alguna forma de que podamos ver a los personajillos trabajar a una velocidad normal,
> pero el juego siga funcionando igual? El problema creo que son los viajes». Se le dieron
> cuatro opciones y eligió la combinación de dos.

### Qué problema cierra

**Un día de juego son 120 s reales**, o sea una hora de juego son 5 s. La gente anda
4,5 km por hora de juego, que en pantalla son **900 m por segundo**: 720 veces lo real.
El usuario tenía razón con los viajes: para que una batida de dos kilómetros quepa en la
jornada, el trayecto dura en pantalla un par de segundos, y lo que se ve son muñecos
cruzando el valle como disparos.

**Verlos andar a paso humano con este reloj es imposible**: habría que hacer el juego
720 veces más lento. Lo que se pide es que **se lea**, separando lo que se ve de lo que se
simula, y **sin que la partida cambie**.

### Lo que se pide

**Los viajes largos, abreviados en la vista.**

- Un trayecto de **más de 150 m** no se dibuja andando entero. La persona se ve salir
  andando **los primeros 20 m** y llegar andando **los últimos 20 m**, a un paso que se
  pueda seguir con la vista; entre medias, **una marca pequeña con su color recorre la
  vereda** a la velocidad del juego (decisión del usuario), para saber por dónde va.
- **Es sólo vista**: la simulación hace el trayecto como hoy. Si el tramo de salida o de
  llegada retrasa la figura respecto a la persona simulada, el retraso tiene tope.
- Lo que la persona hace en el sitio —hoy la pose y los clips que haya— se reproduce **a
  su velocidad**, no a la del reloj del juego. El trabajo se verá tan bien como sean sus
  animaciones: los bucles de trabajo están pendientes (ROADMAP, «Los gráficos»).

**La cámara lenta al acercarse.**

- **Automática y gradual** (decisión del usuario): por debajo de **60 m** de distancia de
  cámara el tiempo va frenando, hasta ir **20 veces más despacio** en la distancia mínima.
  Al alejarse vuelve poco a poco.
- **Un letrero** en la barra de arriba dice que va a cámara lenta y cuánto.
- **Multiplica la velocidad que haya elegido el jugador** (×1, ×2, ×5) y no toca la
  pausa. **La noche acelerada no se frena**: de noche no hay trabajo que mirar.
- Frena **toda la partida a la vez**, todos los campamentos, porque el reloj es uno.
- **La partida da lo mismo con cámara lenta que sin ella**: se simulan los mismos pasos
  del mismo tamaño, sólo que menos por segundo real. Hoy la velocidad del juego cambia
  el tamaño del paso; la cámara lenta **no puede hacerlo así**. El contrato está en
  [SPECS.md](SPECS.md) §3.1.

### Criterios de aceptación

- **Nadie cruza la pantalla a toda velocidad.** A ×1 y sin cámara lenta, en una sonda de
  una jornada que apunte dónde se dibuja cada figura cada cuadro, **ninguna figura
  dibujada se mueve a más de 8 m por segundo real** salvo en trayectos de menos de 150 m.
- **La marca no se pierde.** Durante un trayecto abreviado la marca está siempre sobre la
  vereda que sigue la simulación y **a menos de 5 m de la posición simulada**.
- **La figura no llega tarde de más.** Cada tramo andado de salida o de llegada dura
  **como mucho 1,5 s reales**.
- **Los viajes abreviados no cambian la partida**: la misma semilla da la misma firma en
  diez jornadas con la función encendida y apagada. Prueba.
- **La cámara lenta frena lo que dice**: con la cámara en la distancia mínima, la partida
  avanza **1/20 de las horas de juego por segundo real** que sin ella, con un 5 % de margen;
  a 60 m o más, lo mismo que sin ella. Prueba.
- **La cámara lenta no cambia la partida**: los mismos pasos con y sin cámara lenta dan
  la misma firma. **Se comprueba dando pasos, no esperando al reloj**: diez jornadas a
  cámara lenta de verdad serían horas.
- **El letrero sale y se va**: aparece por debajo de 60 m y desaparece por encima.
  Prueba de lo que pinta la barra.

### Fuera de alcance

- **Cambiar la duración del día** o la velocidad de marcha de la simulación.
- **Animaciones nuevas** de andar o de trabajar: van por su bloque (ROADMAP, «Los
  gráficos»).
- **La cámara lenta en el mapa regional.**
- **Abreviar los viajes en el mapa regional** (las expediciones ya se dibujan como ruta).

**Plan técnico (2026-09-17).**

*Comprobado contra el código antes de planear.* Las cifras de la spec salen: un día son
`seconds_per_day = 120` s y `_advance` convierte con `scaled / seconds_per_day * 24.0`,
así que a ×1 una hora de juego son 5 s reales. La figura se dibuja en
`SettlementSim._pintar_a`, que pasa `person.position` tal cual a `BandaCrowd.update`
dentro del paso de simulación: **hoy no hay ninguna capa entre la posición simulada y la
dibujada**, y ahí es donde entra todo esto. El camino que sigue la persona está en
`Inhabitant.route` (`PackedVector3Array`) con `route_step`.

### Cómo se frena sin cambiar la partida

Es la pieza delicada, y la distinción ya está escrita en SPECS §3.1: `_advance(PASO_FIJO)`
multiplica por `time_scale` **dentro**, así que el tamaño del paso en horas de juego
depende de la velocidad. Bajar `time_scale` para ir a cámara lenta daría pasos más cortos
y **sería otra partida**.

Lo que se hace es lo contrario y es lo mismo que la noche al revés: **frenar el caudal de
pasos, no su tamaño**. Un `freno_de_la_vista` (1,0 = nada, 0,05 = veinte veces más
despacio) multiplica el `delta` que alimenta `_pendiente` en `SettlementSim._process` y en
`RelojDeLaPartida._process`. Se dan menos pasos por segundo real; la sucesión de
`_advance` es idéntica. **La noche no se frena**: su presupuesto sale del `delta` de
verdad, porque de noche no hay nada que mirar.

### Quién manda sobre quién

El freno **lo pone la vista y lo guarda la simulación**, no al revés: `SettlementSim` y
`RelojDeLaPartida` llevan un `freno_de_la_vista` que alguien de fuera escribe, igual que
ya pasa con `time_scale`. `DemoMain` lo calcula cada cuadro con la distancia de cámara.
Así no hay un `scripts/sim/` preguntándole nada a `scripts/vista/` (SPECS §4.7), y con
varios campamentos el reloj lo adopta como ya adopta la velocidad.

### Módulos

| Qué | Dónde | Contrato |
|---|---|---|
| La curva del freno y su rótulo | `scripts/vista/CamaraLenta.gd` (nuevo) | Funciones puras, sin estado: la prueba las llama sin escena |
| Dónde se dibuja cada figura, y la marca del viaje | `scripts/vista/Figuras.gd` (nuevo) | SPECS §4.7: la vista lee y dibuja, no decide |
| Guardar el freno y repartir menos pasos | `SettlementSim`, `RelojDeLaPartida` | SPECS §3.1, con el añadido de abajo |
| Ponerlo cada cuadro | `DemoMain` | — |
| El letrero | `BarraSuperior` | INTERFAZ |

### La figura y la marca, en concreto

`Figuras` recuerda por persona **dónde se la está dibujando** y la lleva hacia
`person.position` con dos reglas:

- **Si lo que queda de camino es corto** (menos de 150 m de ruta total), la figura va
  pegada a la persona, como hoy.
- **Si es largo**, la figura anda **los primeros y los últimos 20 m a paso legible** —como
  mucho 8 m por segundo real, y como mucho 1,5 s por tramo, que es el tope de retraso— y
  entre medias se esconde bajo tierra (el gesto que ya usa `_sacar_del_mapa`) mientras
  **una marca recorre la ruta** en la posición simulada.

El tope de retraso es lo que impide que la figura se descuelgue: si 1,5 s no bastan para
los 20 m, la figura salta a donde toque. **Es vista**: nadie lee la posición dibujada para
decidir nada.

### Riesgos que se nombran

- **El freno multiplica al `time_scale` del jugador**, así que a ×5 y muy cerca la partida
  va a ×0,25. Es lo que pide la spec, pero conviene saberlo: un día entero mirando de
  cerca son cuarenta minutos de reloj.
- **`Figuras` guarda estado por persona y por cuadro.** El invariante 3 de SPECS §7 dice
  que nada de la SIMULACIÓN puede depender del cuadro; esto es vista y no entra en la
  firma, y la prueba de firma con y sin lo comprueba.
- **La marca sale sin color propio**: hoy no hay ningún color por persona ni por oficio en
  el juego —el minimapa las pinta a todas del mismo amarillo—, así que «su color» no
  tiene a qué referirse todavía. Se decide con el usuario antes de implementarlo.

### Orden de dependencias

Las dos mitades son independientes y se pueden hacer en cualquier orden: la cámara lenta
toca el reloj, los viajes abreviados tocan el dibujo. La sonda de la jornada mide las dos
a la vez, así que va al final y se corre **una sola vez**.

### Cómo quedó (2026-09-17)

**La cámara lenta frena dando MENOS pasos.** `SettlementSim.freno_de_la_vista` multiplica
el reloj real que entra en `_pendiente`, en la simulación suelta y en
`RelojDeLaPartida`. Los pasos son los mismos y del mismo tamaño: sólo se reparten en más
fotogramas. La curva está en `CamaraLenta` —1 desde los 60 m, 1/20 en la distancia
mínima, con el cuadrado de lo que queda por acercarse porque el recorrido útil del zoom
está casi todo en los últimos metros— y `DemoMain` la pone cada cuadro. **La noche no se
frena**: de noche no hay a nadie mirando trabajar. El letrero vive en la barra de arriba
y lee el freno de la simulación, no la cámara.

**Los viajes largos se abrevian** (`Figuras`). Por encima de 150 m de ruta, la figura
anda los primeros doce metros del camino, se esconde, y reaparece a doce metros del final
para andarlos. Por el medio va **una marca cuadrada del color de su oficio** sobre la
posición simulada. Lo demás —viajes cortos, gente en el campamento— se dibuja donde está,
como siempre.

**Los doce metros son 8 m/s × 1,5 s, y salen de que la spec se contradecía.** Pedía
tramos de 20 m, figuras a 8 m/s como mucho y un retraso de 1,5 s como mucho: 20 m a 8 m/s
son 2,5 s. Los tres números no caben juntos, así que se conservan los dos medibles —el
paso y la duración— y el tramo sale de ellos.

**Y la primera paleta por oficio del juego** (decisión del usuario): no había ninguna, ni
por persona ni por oficio. Vive en `Figuras.COLOR_DEL_OFICIO` porque hoy es su único
consumidor.

### Lo que costó que la figura no diera saltos

La primera versión llevaba la figura **hacia la persona** y decidía si se la veía mirando
dónde estaba *la persona*: cerca del principio del camino, o cerca del final. Parece lo
mismo y no lo es, y la sonda lo dijo a la primera:

| | primera versión | lo que se pedía |
|---|---|---|
| la figura más rápida | **883 m/s** | 8 m/s |
| lo que se descolgaba | **64 m** | 12 m |

**A ×1 la simulación mueve a alguien de quince a sesenta metros por cuadro**, así que
«estar en los primeros doce metros del camino» es un estado por el que se pasa en un
fotograma —o que se salta entero—. La figura tiene ahora **fases y un avance propio a lo
largo de la ruta**, y mientras se la ve avanza `8 m/s × delta` y nada más: la garantía no
depende de cuánto corra la simulación entre cuadros.

Dos cosas más que aparecieron y ninguna era obvia:

- **El viaje volvía a empezar en cuanto terminaba.** Al llegar, la figura pasa a
  «pegada», y la pregunta «¿es otro viaje?» miraba justamente si estaba pegada: con la
  ruta todavía guardada, la respuesta era que sí, para siempre. En la prueba salían 321
  cuadros de salida donde tenía que haber 90. Ahora al llegar se tira la ruta.
- **Replanificar a otro sitio a mitad de camino teletransportaba la figura**: la ruta
  nueva empieza donde está la persona, que puede estar a un kilómetro. Medido: **3 374
  m/s**. Si el camino nuevo no empieza donde está la figura, ya no se la ve salir: se
  esconde y se va al medio del viaje.

### Depurar del 2026-09-17: se teletransportaban, y a veces eran una marca

Dos quejas del usuario jugando, las dos de esta sección:

**«Veo a los recolectores teletransportarse entre recolección y recolección.»** Sólo se
abrevian los viajes de más de 150 m; por debajo, la figura se pintaba **en la posición
simulada tal cual**, y a ×1 la simulación mueve a alguien de quince a sesenta metros por
cuadro. La cámara lenta frena eso al acercarse, pero el salto seguía ahí. Ahora, en viajes
cortos, la figura **persigue**: anda a 8 m/s y, si se descuelga más de 12 m, corre lo justo
para no pasar de ese retraso. Un salto de más de 60 m —reaparecer, volver de una
expedición, cargar— se pone sin disimulo: eso no es andar.

**«A veces se quedan representados por la marca y no por el modelo, por ejemplo por la
noche cenando.»** La marca sólo se pinta en mitad de un viaje abreviado, y de ahí se salía
mirando la ruta de la persona. Quien se quedaba parado con una ruta larga sin recorrer —el
reparto cambia, cae la noche— se quedaba **escondido para siempre**. Ahora lo que decide es
que la persona avance: diez minutos de juego sin moverse y la figura vuelve a verse entera.

**Se cuenta en horas de juego y no en segundos de reloj**, y eso importa: el reloj de pared
corre igual con la partida en pausa, y en pausa nadie se mueve. Contando reloj, pausar
sacaba a toda la banda de su viaje —lo dijo la prueba vieja de `TestSeguimiento` en cuanto
se tocó—.

### Medido

`VerTrabajarProbe` (ventana, 1280×720, valle del sitio 56, tres horas de juego a ×1, sin
cámara lenta, 250 cuadros con alguien de viaje en 238 de ellos):

| | medido | tope |
|---|---|---|
| la figura más rápida | **8,06 m/s** | 8,0 |
| el tramo andado más largo | **1,57 s** | 1,50 |
| el mayor salto de la marca | **652 m en un cuadro** | — |

Los 652 m de la marca **no son un fallo**: la marca va en la posición simulada y a ×1 una
persona recorre eso entre dos cuadros. Es lo que el usuario eligió al escribir la spec
—«una marca recorre la vereda **a la velocidad del juego**»—, y por eso la marca cruza el
valle como un trazo mientras la figura anda. La spec pedía además «la marca a menos de
5 m de la posición simulada»: **eso sólo se puede medir dentro del mismo cuadro**, y ahí
lo comprueba `TestVerTrabajar`; entre dos cuadros la persona ya se ha movido quince
metros, así que el criterio no se puede observar como estaba escrito.

Y dos cosas del instrumental, que costaron sus vueltas:

- **Un `MultiMesh` no devuelve lo que se le escribe sin ventana.** `--headless` no tiene
  dónde guardar las instancias y `get_instance_transform` contesta ceros, así que una
  prueba de la suite no puede mirar ahí. `Figuras.marcas_puestas` guarda la decisión
  aparte: la suite comprueba eso y la sonda comprueba que se dibujan.
- **La velocidad se mide sobre medio segundo, no sobre un cuadro.** Comparar lo que anda
  la figura en un cuadro con el `delta` que mide la sonda daba entre un 12 % y un 26 % de
  más —el `delta` de `Figuras` se toma en otro punto del fotograma—, y la figura salía a
  10,1 y a 9,0 m/s con el tope en 8. Lo que corría era la regla de medir.

**Y una que no es de este trabajo pero conviene saberla**: cualquier sonda que monte
`demo_main` con ventana y llame a `quit()` **revienta al cerrar** —«CrashHandlerException:
signal 11», después de imprimirlo todo—. `NocheLuzProbe`, que no tiene nada que ver con
esto, hace lo mismo. Es al apagar el servidor de render; la medida está entera.


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

> **El agua y el clima salieron de esta lista el 2026-09-15**: el usuario los pidió
> como trabajos propios, cada uno con su spec —§7.3 y §7.4—, que es justo lo que esta
> lista pedía de ellos. Siguen fuera los edificios y el ciclo día/noche.


## 7.7. Las texturas del suelo, con su altura de verdad (spec 2026-09-17)

> **Spec escrita con `/spec` el 2026-09-17.** Sale de una petición del usuario: «mejora de
> las texturas terrestres… quiero que encuentres texturas con heightmaps, PBR… para algunas
> zonas textura de pared de caliza con sus grietas y tal… en los rocales texturas de rocas
> con heightmaps de cada una de las rocas… para la hierba también… busca texturas de gran
> calidad». Las decisiones las tomó él con preguntas y están marcadas donde salen.

### Qué problema cierra

**Las texturas del terreno ya son PBR con altura, y la altura no se usa.** Se descargan de
ambientCG —CC0— con su `Displacement`, se empaquetan en el canal alfa del ORM y ahí se
quedan: el relieve que se ve sale del **brillo del color** (§3, «el relieve de las
texturas», 2026-09-16). Fue una decisión del usuario de aquel día —«que se hunda lo oscuro
del dibujo»— tomada cuando la altura de verdad no estaba enchufada a nada.

Eso tiene una consecuencia que hoy se ve en el juego: **se hunde lo que está oscuro, no lo
que está hundido**. Un liquen negro sobre una caliza lisa sale como un agujero, y una
grieta iluminada por el sol sale plana. Y hace que mejorar las texturas no sirva de mucho:
por buena que sea la piedra nueva, su relieve seguirá saliendo de las manchas del dibujo.

Y aparte está lo que el usuario pide de las texturas mismas: **la pared de caliza tiene que
tener grietas**, **el canchal tiene que leerse canto a canto** y no como una manta de
grava, y **la hierba tiene que ser hierba** y no una alfombra verde. Las ocho capas de hoy
son las primeras que se eligieron y nunca se han vuelto a mirar.

### Lo que se pide

- **El relieve sale de la altura descargada** (decisión del usuario): el parallax con
  oclusión lee el canal de altura del ORM, que ya está ahí, en vez de deducirla del brillo.
  **Esto retira la decisión del 2026-09-16**; se retira con su porqué escrito, porque aquel
  día la alternativa no existía.
- **Texturas nuevas para las capas que el usuario nombra**: la pared de caliza con sus
  grietas, el canchal con cantos que se lean uno a uno, y la hierba. De ambientCG y CC0,
  como las de ahora: mismo sitio, misma licencia, misma herramienta que las trae.
  **Elegidas el 2026-09-17 sobre las hojas de contacto** (`tools/CandidatasDeTextura.gd`,
  color y altura de cada candidata): caliza **Rock023** —estratos y grietas, y las grietas
  están en el mapa de altura—, canchal **Rocks002** —cantos que se leen uno a uno—, hierba
  **la de siempre** (Grass007: entre las candidatas no había mejora), suelo de bosque
  **Ground003** y, en otoño, la hojarasca **Ground041**.
- **Se quedan en 1K** (decisión del usuario). No se sube la resolución: el juego va a 20-28
  fps y usa 1 876 MB de VRAM, y cuadruplicar los píxeles de una capa no es lo que falta.
  Lo que falta es que la altura sea la de la piedra.
- **Los rocales son la capa de canchal** (decisión del usuario), no los modelos 3D de roca
  sueltos, que son otro trabajo.
- **Las elige el usuario sobre capturas** (decisión del usuario): del mismo sitio, a la
  altura a la que se juega, con la textura de ahora al lado de las candidatas.

### Criterios de aceptación

- **El hundido sigue a la altura y no al color.** Con una capa preparada a propósito donde
  el dibujo y la altura discrepan —una franja oscura y plana, y una grieta clara y honda—,
  el relieve hunde la grieta y deja la franja lisa. Se comprueba sobre captura, y es la
  única forma honrada de decir que el cambio hizo algo.
- **No cuesta más GPU que hoy**: mismos pasos de parallax, mismo número de muestras. Se
  mide con la sonda de GPU que ya existe, con el relieve encendido, antes y después, y la
  diferencia tiene que caber en el ruido de dos corridas —que en esta máquina es grande:
  49,2 y 33,7 ms para lo mismo (INTERFAZ §16)—.
- **La VRAM no sube**: se queda en 1K y se mide antes y después.
- **Las tres capas nuevas elegidas por el usuario** sobre capturas del mismo encuadre, y la
  elección queda escrita aquí con el nombre del asset, como está la de ahora.
- **Los créditos dicen de dónde sale cada una**: `CREDITOS.md` se regenera y nombra los
  assets nuevos.
- **La suite sigue en verde** y el total de comprobaciones no baja.

### Fuera de alcance

- **Subir de 1K**, decidido arriba.
- **Los modelos 3D de roca** —las peñas y bloques de Poly Haven repartidos por el valle—:
  otro trabajo, con su spec.
- **Desplazar la malla de verdad** (tessellation): el parallax mueve píxeles, no vértices, y
  cambiar eso es rehacer el terreno.
- ~~**Cambiar cuántas capas hay ni cómo se mezclan por altura y pendiente**~~. **Retirado
  el 2026-09-17, al elegir el usuario las texturas**: pidió que el suelo de bosque fuera uno
  normalmente y **hojarasca en otoño**, y eso no es cambiar una imagen sino **una capa que
  aparece con la estación**. Entra una novena capa —la hojarasca—, con su peso mandado por
  el otoño como la nieve cuaja con el frío, y **sube y baja progresivamente** (decisión del
  usuario). Lo que sigue fuera es tocar cómo se mezclan las otras ocho por altura y
  pendiente.
- **Texturas que no sean CC0.** Ni de pago ni con atribución obligatoria: el catálogo de
  hoy es CC0 y se queda así.
- **La hierba en 3D** (las briznas de `HierbaAtlas`): eso es vegetación, no textura de
  suelo.

### Plan técnico (2026-09-17)

**Dónde está el cambio, exactamente.** `altura_de_la_capa` en `shaders/triplanar.gdshader`
lee el brillo del albedo y devuelve una altura deducida de él; el parallax con oclusión
—`relieve_desplazado`— la llama tres veces por píxel. La altura de verdad está a un
muestreo de distancia: es el **canal alfa de `terrain_orm`**, que `TerrainTextureIngest` ya
empaqueta desde el `Displacement` de ambientCG. Todo lo demás del relieve —los pasos, la
hondura de las juntas, el bulto con luz, el desenfoque— se queda como está.

**Módulos afectados**

| Script | Qué cambia |
|---|---|
| `shaders/triplanar.gdshader` | `altura_de_la_capa` lee el alfa del ORM. `media_de_la_capa` deja de hacer falta para el relieve: un heightmap ya viene centrado, no hay que restarle su media. |
| `mundo/TerrainLayers.gd` | Los assets de las tres capas que cambian, con su `tile_m` si la textura nueva pide otro. Es el catálogo, y vive ahí y sólo ahí. |
| `tools/TerrainTextureIngest.gd` | Nada de fondo: ya descarga el `Displacement`. Se corre para traer las candidatas. |
| `tests/MapasProbe.gd` | Ya mira los mapas empaquetados; se le añade que diga si el alfa del ORM trae altura de verdad o está plano. |
| `tests/TexturasCaptura.gd` (nueva) | Las capturas para elegir, y la capa de prueba donde el dibujo y la altura discrepan. |
| `docs/GRAFICOS.md`, `docs/CREDITOS.md`, `docs/ESTADO.md`, `docs/ROADMAP.md` | Lo elegido, de dónde sale y lo que cuesta. |

**Decisiones de arquitectura** —dos, y las dos obligadas por la spec:

1. **La altura sale del ORM y de ningún otro sitio.** No se mezcla con el brillo ni se deja
   un mando para volver al brillo: sería la misma pregunta contestada desde dos sitios
   (`SPECS.md` §7, invariante 3). Lo que se retira queda escrito arriba con su fecha.
2. **Sin altura no hay relieve.** El ORM se apaga en el escalón Bajo (`graficos["orm"]`), y
   ahí el parallax ya está apagado (`relieve_pasos = 0` en Bajo y Medio). Así que no hace
   falta reserva: donde no hay ORM tampoco se pide relieve, y eso ya lo garantizan los
   niveles.

**Orden de dependencias**: la capa de prueba (2) antes que el cambio del shader (1), porque
es lo que demuestra que el cambio hizo algo. Las candidatas (3) después, porque hasta que
la altura no mande, una textura mejor no se distingue. Y la medida (5) al final, con todo
puesto.

**Riesgos que se nombran**

- **La descarga necesita red, y en `--headless` esta máquina no la tiene**: el módulo SSL
  de Godot no arranca ahí —visto el 2026-09-17 con el IGN y con Overpass, que sí responden
  con ventana—. La herramienta de texturas se corre **sin `--headless`**. Si aun así no
  hubiera red, la tanda se queda en enchufar la altura, que no necesita descargar nada.
- **Las candidatas pueden no existir con ese nombre.** El catálogo de ambientCG se nombra
  por id (`Rock030`, `Grass007`), y pedir uno que no existe falla en la descarga. Se prueba
  bajando, no adivinando.
- **El relieve puede salir peor al principio.** Con el brillo, lo oscuro se hundía y eso
  «se leía» aunque fuera mentira; con la altura real, una textura cuyo `Displacement` sea
  flojo puede quedar más plana que antes. Es justo lo que el usuario tiene que juzgar sobre
  capturas, y es la razón de que las candidatas vayan después del cambio.
- **El disco del usuario va justo** (2,1 GB libres el 2026-09-18): cada asset de ambientCG
  a 1K son unos 10 MB comprimidos y `textures/` ya pesa 56 MB. Se borra lo descargado que
  no se quede.

### Cómo quedó (2026-09-17)

**El relieve sale del mapa de altura.** `altura_de_la_capa` lee el alfa del ORM —donde
`TerrainTextureIngest` empaqueta el `Displacement` desde el principio— en vez de deducir la
altura del brillo del dibujo. Se retira así la decisión del 2026-09-16 («que se hunda lo
oscuro»), que se tomó cuando la altura de verdad no estaba enchufada a nada.

**Y no era lo mismo, medido** (`tools/AlturaDeLasTexturas.gd`, que se queda como
herramienta):

| capa | altura σ | brillo σ | correlación |
|---|---|---|---|
| Pradera | 0,114 | 0,055 | **0,09** |
| Suelo de bosque (el viejo, Ground037) | 0,053 | 0,104 | 0,18 |
| **Roquedo calizo** | **0,220** | 0,069 | **0,02** |
| Canchal | 0,107 | 0,136 | 0,60 |
| Cantos de río | 0,107 | 0,108 | 0,43 |
| Arena | 0,183 | 0,014 | 0,66 |
| Limo | 0,055 | 0,046 | 0,18 |
| Nieve | 0,135 | 0,010 | 0,39 |

O sea: el alfa **sí traía altura** —hasta 0,22 de desviación típica en la caliza, la mayor
de las ocho— y **no se parecía al brillo**: 0,02 de correlación en el roquedo. El relieve
que se veía en la caliza no tenía nada que ver con su relieve.

**Las texturas nuevas, elegidas por el usuario sobre hojas de contacto**
(`tools/CandidatasDeTextura.gd`, que baja candidatas y compone color + altura de cada una):

| capa | antes | ahora | por qué |
|---|---|---|---|
| Roquedo calizo | Rock030 | **Rock023** | caliza en estratos, y **las grietas están en el mapa de altura** |
| Canchal | Rocks006 | **Rocks002** | cantos que se leen uno a uno; el viejo era grava fina y su altura, ruido |
| Suelo de bosque | Ground037 | **Ground003** | el viejo tenía la altura más floja de las ocho (σ 0,053) |
| Pradera | Grass007 | **Grass007** | entre las candidatas no había mejora |
| Hojarasca (nueva) | — | **Ground041** | las hojas, dibujadas en el mapa de altura |

**La novena capa: la hojarasca de otoño.** No es un sitio del valle sino una estación del
suelo de bosque, así que su peso no sale de la altura ni de la pendiente: sale del propio
peso del bosque multiplicado por cuánto otoño hay (`Temporada.hojarasca`, con la misma
transición de doce días que la cota de nieve, decisión del usuario: «sube y baja con la
estación»). Con otoño a cero la capa no pinta nada.

**Lo que cuesta**: nueve capas de 1 024 px son **36 MB** de arrays, y la VRAM del juego se
queda en **1 847-1 848 MB** contra 1 843-1 876 con las ocho viejas. Cabe en el ruido.

### Lo que esto destapó, y que no es de aquí

**La hojarasca no se ve en el juego**, y la culpa no es suya: **el suelo de bosque casi no
se pinta donde hay árboles**. La máscara `wood` del shader sale de la curvatura del terreno
y un ruido macro —zonas cóncavas, manchas grandes—, mientras que los árboles los planta la
vista del bosque con su propia regla. Bajo un pinar, el suelo puede estar pintado de
pradera; y si no hay suelo de bosque, no hay hojas que caer sobre él.

El desajuste **ya existía** —la textura del suelo y los árboles llevan desde siempre sin
hablarse— y la capa nueva sólo lo ha hecho visible. Arreglarlo es otro trabajo: que la capa
de bosque siga a los árboles de verdad, o al revés. Queda escrito aquí y en ROADMAP para
que no se pierda.

### Depurar del 2026-09-18: la lepra, la caliza que no salía y el bosque que no coincidía

Tres quejas del usuario al jugar con lo de ayer, y las tres eran de código.

**«Parece que tiene lepra.»** Al enchufar el mapa de altura cambié **una sola mitad**: el
desplazamiento del parallax pasó a usar la altura, y el **bulto con luz** —que es lo que de
verdad se ve a la distancia de juego, según esta misma sección— se quedó sacando su cuesta
del **brillo del dibujo**. Dos fuentes contradiciéndose en el mismo píxel: donde una decía
hueco y la otra bulto salían manchas. Es el invariante 3 de SPECS §7 roto por mí en el
propio arreglo que lo invocaba. Ahora las dos leen el alfa del ORM.

Y la fuerza del bulto **baja de 3 a 1,2**: estaba calibrada contra el brillo, cuya
desviación típica es 0,069 en la caliza, y la altura tiene 0,22. Con el número viejo la
piedra salía rayada.

**«Hay muchos sitios que deberían ser piedra caliza y sin embargo son rocal.»** El reparto
roca/derrubio iba con un umbral y un margen —`slope_threshold`, `slope_blend`— y la pared se
calculaba en `umbral + margen × 2,5`. Con lo que el material ponía de verdad (umbral 0,15),
eso daba:

| | empezaba | llena |
|---|---|---|
| Canchal | slope −0,05 (**casi llano**) | 0,35 (49°) |
| Pared | 0,25 (41°) | 0,65 (70°) |

O sea que **a 30 grados ya había medio canchal** y el derrubio se comía la roca en toda la
ladera. Ahora son cuatro números con su ángulo escrito, y la decisión del usuario fue
**pared desde 55-60°**: canchal de 35° a 55°, pared de 55° a 73°.

**El suelo de bosque no coincidía con los árboles.** El shader pintaba bosque con la
curvatura del terreno y un ruido macro suyos; `Forest` siembra con el **mapa de humedad**, la
pendiente y la cota. Dos criterios para la misma pregunta, y por eso bajo un pinar el suelo
podía estar pintado de pradera —y la hojarasca de otoño, que cuelga de esa capa, no
aparecía—. Decisión del usuario: **manda la humedad**. El terreno la pasa al shader como
textura (`TerrainMaterialManager.set_humedad`) y el bosque sale de ella con las bandas de
`Forest.NICHOS` —0,34 a 0,55— por la pendiente. Visto en captura: el suelo de bosque cae
ahora bajo los árboles, y en otoño se cubre de hojarasca hasta donde llega el bosque.

**Y una trampa que costó tres intentos**: en las sondas no vale poner el uniforme de la
hojarasca a mano. `WeatherView` lo reescribe **cada cuadro** con lo que diga la temporada,
así que lo que hay que cambiar es la estación (`Temporada.asentar`), no el uniforme.


### Depurar del 2026-09-18 (segunda vuelta): el canchal de la comarca y los árboles que flotaban

**«En el mapa regional sólo hay parches de canchal… no puede haber canchales en la vista
regional.»** El mapa regional usa el mismo shader que el valle, así que heredaba sus dos
escalones de roca. Pero **el derrubio es un detalle de ladera**: a 111 m por muestra no se
distingue un canchal de una peña, y lo que salían eran manchas de canto suelto donde debería
haber caliza. Ahora `TerrainMaterialManager.pintar_como_comarca()` **iguala el escalón del
canchal al de la pared** —con lo que su peso, que es `scree − cliff`, sale cero en todas
partes— y baja el umbral de la roca al que tenía el derrubio, porque a esa escala las
pendientes se promedian y con el umbral del valle no asomaría peña casi en ningún sitio.
Decisión del usuario: «sin canchal: todo caliza».

**«No estás usando las texturas que escogí.»** Aquí el usuario no llevaba razón, y se
comprobó sobre el dato en vez de discutirlo: `tools/_Capas.gd` saca del `Texture2DArray`
guardado el albedo de cada capa y lo pinta con y sin el tinte del catálogo. La capa 2 es
**Rock023** —la caliza de estratos y grietas— y la 3 **Rocks002** —los cantos sueltos—, las
dos elegidas por él, y el tinte apenas las cambia. Lo que sí es cierto es que **en el mapa
regional no se leen**: la tesela mide de 3 a 6 m y la muestra 111 m, así que cada textura se
repite unas treinta veces por muestra y de lejos sólo se ve su color medio. Eso queda sin
tocar: es una vista de comarca, no de suelo.

**«Algunos árboles no están colocados en el suelo, flotan… aunque la mayoría están bien.»**
`Forest` tomaba la cota del **vértice de la celda**, sin interpolar, mientras la malla del
terreno sí interpola entre vértices. En llano las cuatro esquinas valen casi lo mismo —de ahí
que la mayoría estuvieran bien—, pero en ladera, entre dos vértices a 4,9 m hay metros de
diferencia. Ahora la cota se interpola entre los cuatro, que es lo que hace la malla.


### Depurar del 2026-09-18 (tercera vuelta): la caliza que no salía y el relieve por capa

**«Aún hay demasiado canchal con respecto a caliza.»** Medido antes de tocar nada, sobre el
relieve del valle del sitio 56 (807 302 celdas):

| umbrales | canchal | caliza | tierra |
|---|---|---|---|
| los de la mañana (canchal 35-55°, caliza 55-73°) | **2,4 %** | **0,2 %** | 97,4 % |
| caliza desde 45° | 1,9 % | 0,7 % | 97,4 % |
| caliza desde 40° | 3,6 % | 1,4 % | 95,0 % |

Y el reparto de pendientes del valle: mediana **22°**, p90 **36°**, p99 **51°**. O sea que
**el problema no era el exceso de canchal sino la ausencia de caliza**: con la peña pidiendo
55° en un valle cuya mediana son 22°, salía en el 0,2 % del suelo y el derrubio la superaba
doce veces. Decisión del usuario con esas cifras delante: **caliza desde 40° y el canchal
donde estaba**, que es lo que hace que la peña se coma parte del derrubio sin cambiar el
resto del valle.

**«El canchal apenas tiene relieve, debe tener MUCHO más relieve.»** No se podía: la fuerza
del relieve era **una sola para las nueve capas**. El usuario lo apuntó bien —«¿no podemos
darle relieve sólo al canchal con normal map o algo así?»— y eso es exactamente la vía
barata: el mapa de normales ya viene descargado por capa y sólo faltaba un multiplicador.

Ahora el catálogo lleva un `relieve` por capa que escala **las tres cosas que dan bulto**: el
mapa de normales, la cuesta de la altura y el desplazamiento del parallax. Canchal **×3**,
roquedo **×2**, el resto ×1. Un canto suelto tiene bulto de canto; un limo de marisma no
tiene ninguno.

**Lo que no salió**: las capturas para elegir esa fuerza. La sonda busca una ladera con la
pendiente del derrubio, y el punto de 46° del valle 56 cae **dentro de un cauce**: la cámara
acabó bajo el agua, a 9 fps. El número queda en `TerrainLayers.CATALOGUE`, una línea por
capa, para subirlo o bajarlo en cuanto se vea jugando.
