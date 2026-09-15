# Roadmap — CityBuilder cántabro (Godot 4.5.1)

Del Paleolítico al siglo XIX sobre el relieve real de Cantabria.

Este documento se reescribió el **2026-09-02**, tras adoptar la arquitectura de
dos escalas, y se repasó contra el código el **2026-09-12**. Lo que sigue
refleja el estado real, no el deseado.

Ver [SPECS.md](SPECS.md) para el contrato técnico de cada módulo,
[ESTADO.md](ESTADO.md) para qué hace hoy el juego con
cifras medidas, y [AGENTES.md](AGENTES.md) si vais a ser más de uno trabajando
a la vez.

---

## Dónde mirar

| Si buscas… | Ve a |
|---|---|
| **Qué se está haciendo AHORA, y sus tareas** | **«En curso»** — es donde `/plan-tarea` cuelga la lista |
| Las diecisiete quejas del 2026-09-14 (costa, frontera, obras, agua, peces, nubes…) | «En curso» → Depurar del 2026-09-14 |
| **Cinco specs del 2026-09-14**: prioridades y cola del taller, campamentos y simulación fuera, exploración con rumbo, niebla regional, configuración | «En curso» → Cinco specs del 2026-09-14 |
| El segundo depurar del 2026-09-14 (visita, alfileres, pasarelas, campa) | «En curso» → Depurar del 2026-09-14 (segundo) |
| Los dos 🔴 que bloqueaban la tanda 2, y cómo se cerraron | «En curso» → La puerta de entrada |
| Las tareas de la tanda 1 del Paleolítico | «En curso» → Tanda 1 |
| Las tareas de la tanda 2 del Paleolítico (cerrada el 2026-09-13) | «En curso» → Tanda 2 |
| La tanda 3 del Paleolítico (cerrada el 2026-09-13) | «En curso» → Tanda 3 |
| La tanda 4 del Paleolítico (cerrada el 2026-09-13): cuevas, mapa regional, sepultura, trueque y relaciones | «En curso» → Tanda 4 |
| Qué está terminado | «Estado actual» → Completado |
| Qué está roto o a medias y molesta | «Estado actual» → Deuda pendiente, y FASE F |
| Por qué hay dos escalas y no hay chunking | «La decisión que ordena todo lo demás» |
| Cerrar el circuito de juego (exploración regional, guardado) | FASE A |
| Procesos, recetas y la escalera térmica | FASE B |
| El arte como motor y el saber que decae | FASE C |
| Las épocas | FASE D — el detalle, en [EPOCAS.md](EPOCAS.md) |
| Datos reales: agua, periodos, geología, trazabilidad | FASE E |
| Qué puede hundir el proyecto | «Riesgos» |

Lo que hace hoy el juego **medido** no está aquí: está en [ESTADO.md](ESTADO.md).

---

## La decisión que ordena todo lo demás

**Dos escalas sobre un solo conjunto de datos.**

| | Capa regional | Capa local |
|---|---|---|
| Qué es | Cantabria entera, tablero de gestión | El city builder |
| Extensión | 199 × 171 km | 4 × 4 km |
| Escala | 1 unidad = 100 m | 1 unidad = 1 m |
| Resolución del dato | 111 m/muestra (zoom 10) | 13,9 m/muestra (zoom 13) |
| Malla | 1993 × 1708 unidades, 1025² | 4096 unidades, 1025² (4 m/vértice) |
| Escena | `scenes/region_map.tscn` | `scenes/demo_main.tscn` |

Las une `Site`: un emplazamiento del mapa regional que, al fundarlo, descarga
su relieve fino y genera el mapa local. El traspaso va por `Expedition`.

**Consecuencia: no hay streaming de chunks.** Un mapa local de 4 km cabe en una
malla única a 28 FPS medidos, y el regional es una malla basta. La antigua
FASE 6 queda cancelada, no aplazada.

---

## Estado actual

### Completado

- **Importación de relieve real.** `DEMImporter` sobre teselas Terrarium de AWS
  (SRTM + NASADEM + EU-DEM + batimetría GEBCO). Sin clave de API y con licencia
  que permite uso derivado, al contrario que Google Maps.
- **Corrección de datos.** `despike()` sustituye artefactos por la mediana de
  sus vecinos: en Cantabria había una franja con +4416 m junto a −1783 m, cotas
  imposibles en la península. Tras corregir, el máximo queda en 2601,8 m, que es
  la cota real de los Picos de Europa.
- **Hidrografía deducida.** Relleno de depresiones (Planchon-Darboux) y
  acumulación de flujo D8. El umbral es área drenada real en km².
- **Frontera por época.** La región es Cantabria más la plataforma continental
  que esté emergida a esa cota del mar. Con el mar actual son 5304 km² —la
  frontera administrativa exacta, contrastada contra los 5321 km² reales—; con
  el mar a −120 m, 7316 km².
- **2067 emplazamientos** derivados del relieve, agrupados a 2 km en **862**
  con **2495 elementos reales adjuntos**. 173 atestiguados contra el registro
  arqueológico de OpenStreetMap.
- **Salto entre escalas.** Seleccionar, fundar, descargar el relieve fino
  (9 teselas, ~7 s) y entrar. `ESC` vuelve.
- **Caché de texturas de terreno** (antigua FASE 5.1). Se generaban 8 texturas
  píxel a píxel en cada `generate()`: 4 s que se pagaban una y otra vez.
- **Rendimiento.** De 4,2 a ~28 FPS con un mapa 12 veces mayor. Las causas eran
  texturas sin mipmaps y 24 muestreos por fragmento en el shader triplanar.
- **La capa de *city builder* retirada entera.** `Architecto`, `Chunk`,
  `BlockData`, `RawMaterial`, `buildings/`, `materials/` y las cabañas de
  prueba. No quedaba nada vivo de la encarnación anterior del proyecto.
- **La simulación de la banda**, que es el juego: quince personas con oficios,
  pericia que crece y se transmite, cacería por fases sobre fauna viva,
  trampas, nasas, meteorología, estaciones, árbol de técnicas por práctica,
  utillaje que se gasta, crónica, parajes con nombre. Todo medido, ver
  ESTADO.md.
- **Se puede perder**, y se puede ganar. Hambre, frío, vejez, nacimientos y
  muertes; y un objetivo doble —sobrevivir el año y dejar la cueva pintada—.
  Ver [archivo/QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md) y
  [archivo/QUE_FALTA_PARA_JUGARLO.md](archivo/QUE_FALTA_PARA_JUGARLO.md).
- **Suite de pruebas**, más las sondas de medida. El ROADMAP pidió una durante
  tres fases; ya está. El total en verde de hoy, en [ESTADO.md](ESTADO.md) §3.
- **Determinismo comprobable.** La misma semilla da la misma partida, año
  entero, y hay herramienta que lo verifica (`Instantanea`, `FirmaDiaria`,
  `Cotejo`).
- **Los tirones, fuera.** A velocidad de juego (×5), un año entero va a 39,1 ms
  de fotograma medio con **ningún tirón grave**, y las noventa primeras jornadas
  pasan de 1 787 tirones de más de 100 ms a 114 — sin que cambie una cifra de la
  partida. Ver [ESTADO.md](ESTADO.md) §5 y el aviso sobre el contador roto de
  [SPECS.md](SPECS.md) §6.1.

### Deuda pendiente

| | Estado |
|---|---|
| Entrada duplicada en `OrbitalCamera` (teclas físicas + acciones del `InputMap`) | sin unificar: el remapeo de teclas no funciona |
| Descarga de teselas bloqueante | congela la ventana unos segundos; no hay hilo |
| Ciclo día/noche (`WorldEnvironmentSetup.follow_time_of_day`) | apagado a propósito para trabajar con luz |
| Capas de física 2–4 (`props`, `resources`, `banda`) | declaradas en `project.godot` y sin asignar a nada |
| Ríos y lagos | deducidos del relieve, no de datos reales (FASE E1) |
| `SettlementSim` de vuelta en 4 119 líneas | el troceado funciona, pero toca otra pasada |

Lo que **se fue** de esta tabla, para no volver a buscarlo: `Inventory.gd` y
`GameUtils.gd` (borrados con el resto de la capa vieja), las señales duplicadas
de `TimeManager` (la clase ya no existe: no hay autoloads, ver SPECS.md §2.2),
y las bocas de cueva mirando arriba (`CaveMouth` ya las abre horizontalmente
contra la ladera).

---

## En curso

**Aquí viven las tareas que se están haciendo ahora.** Es el destino de
`/tareas`: desde el 2026-09-12 no se crea un documento por trabajo, así que la
lista de tareas de lo que esté abierto va aquí, con su cita de HECHO debajo
cuando se cierre. Lo que la tarea aprenda sobre el juego se funde en el
documento permanente que le toque —[SISTEMAS.md](SISTEMAS.md),
[ESTADO.md](ESTADO.md), la ficha de época— y de la tarea sólo queda la línea.

El contexto largo de los bloques que se cerraron antes de este cambio sigue
íntegro en [archivo/](archivo/); no se edita.

---

### ~~La pantalla de carga, y las dos cargas que sobran~~ — cerrado (2026-09-15)

Las diez tareas hechas y en verde: **1 483 pruebas y 8 142 comprobaciones** —del suelo
de 1 468 y 8 051—, `llamadas huerfanas: 0`. Lo aprendido fue a
[INTERFAZ.md](INTERFAZ.md) §9.6, [ESTADO.md](ESTADO.md) §2 (la tabla nueva del viaje) y
§3, [SPECS.md](SPECS.md) §2.2 y §3.1 y [ARQUITECTURA.md](ARQUITECTURA.md) §3.1 y §5.1.
Todas las cifras de la spec se cumplen. **Un criterio lo cambió el usuario**: esperando
a la red al preparar un valle, la barra se detiene y un brillo la recorre, en vez de «no
quieta más de 2 s». Quedan fuera, como decía la spec, los `SCRIPT ERROR` de los objetos
vivos al cambiar de escena (ESTADO §2).

Spec y **plan técnico** en [INTERFAZ.md](INTERFAZ.md) §9 (2026-09-15): barra con la
etapa escrita en el mapa de la banda, el mapa regional y al preparar un valle; la
ventana nunca congelada más de medio segundo; y que el segundo viaje al mapa regional
encuentre la malla hecha y que volver al mismo valle no vuelva a sembrar el bosque
(ESTADO §2).

- [x] **1. Medir hoy.** Cada camino, cuadro a cuadro, y cada trozo del montaje que
      pase de 100 ms, para saber qué trocear y con qué pesos. *Toca
      `scripts/tests/CargaProbe.gd` (nueva). Con ventana; `TransitoProbe` dos veces
      como línea base.* Media.
> **HECHO (2026-09-15).** `CargaProbe`, con ventana: **cada camino es un solo cuadro
> congelado** —nueva partida 28,5 s, fundar 26,3, ida al regional 27,3, retomar 19,3—.
> Lo que pesa, por montaje: el **regional**, composición de alturas 13,1-13,3 s, trocear
> la malla 7,6-7,9, vértices 1,7, máscara de eras 1,0, ruido 0,9; la **banda**, sembrar
> el bosque **14,0 s**, cargar el bosque de lejos 3,2-4,8, lo que la banda sabe al llegar
> 2,2 (sólo al fundar), recursos visibles 0,8-1,5, fauna y técnica 0,6, minimapa 0,5.
> Todo son bucles o cargas: nada es una sola llamada del motor de varios segundos, así
> que se puede trocear. **`TransitoProbe`, dos corridas, sin ventana: ida 29,2-30,4 s,
> vuelta 22,5-23,4 s**, peor que los 27,1 y 18,4 de ESTADO: desde entonces entró el
> bosque 3D. Los cronometrajes finos (`[MIDE]` en `Forest.setup` y
> `DemoMain._levantar_vegetacion`) son provisionales y se quitan en la tarea 4.
> Preparar un valle se mide en la tarea 6.
- [x] **2. La pantalla y el reparto.** *Toca `scripts/ui/PantallaDeCarga.gd`,
      `scripts/ui/Carga.gd` (nuevos), `scripts/tests/TestCarga.gd` (nueva). Prueba: la
      barra no retrocede, los pesos suman uno, sin pantalla `ceder` no espera, textos
      sin términos del motor; captura a 1080p y 720p.* Media.
> **HECHO (2026-09-15).** `Carga` (estática: abrir, etapas, avanzar, `ceder`, cerrar),
> `RepartoDeCarga` (la cuenta de la barra, pura, para probarla sin ventana; `Reparto`
> ya existía en `sim/`) y `PantallaDeCarga`. `TestCarga`, 7 pruebas: la barra avanza por
> peso, no retrocede, una carga encadenada se reparte lo que falta, y los textos del
> motor no pasan. `CargaCaptura` a 1920×1080 y 1280×720: en la primera, la etapa escrita
> en carbón no se leía y el marco salía más estrecho que su mínimo; ahora en hueso y
> con el tamaño a mano.
- [x] **3. El reloj parado mientras carga.** *Toca `scripts/sim/RelojDeLaPartida.gd`,
      `scripts/sim/SettlementSim.gd`. Prueba: con la pantalla abierta N cuadros, la hora
      y la jornada no se mueven.* Pequeña.
> **HECHO (2026-09-15).** Con la pantalla abierta, `RelojDeLaPartida._process` y
> `SettlementSim._process` vuelven en la primera línea: ni pasos, ni tiempo pendiente
> guardado, ni el horno de rejillas —que le quitaría cuatro milisegundos por cuadro a la
> carga—. Se comprobó sobre lo que acumulan (`_pendiente`), que es lo que haría andar la
> partida al cerrar la pantalla. `TestCarga`. Suite: **1 476 pruebas, 8 078
> comprobaciones**, `llamadas huerfanas: 0`.
- [x] **4. El mapa de la banda por etapas**, con el bosque sembrado por trozos y lo
      demás que la tarea 1 mida por encima de 500 ms; `montado`; los caminos que lo
      abren. *Toca `scripts/DemoMain.gd`, `scripts/vista/Forest.gd`,
      `scripts/ui/MenuPrincipal.gd`, `scripts/ui/MenuDelJuego.gd`,
      `scripts/region/RegionMap.gd` (sólo al salir). Prueba: la huella de la partida
      cargada con y sin pantalla es la misma.* Grande.
> **HECHO (2026-09-15), y tocó bastante más que lo declarado.** Con ventana
> (`CargaProbe`): **retomar, 0 cuadros de más de 500 ms** (el peor 366) y **fundar, 0**
> (el peor 454); la barra no retrocede, no se queda quieta más de 0,6 s, y a media barra
> ha pasado el 50-57 % del tiempo. **Y cargan antes**: retomar 14,0 s frente a 19,3,
> fundar 17,7 frente a 26,3 —las cargas de recursos van en otro hilo—. **La misma
> partida con pantalla y sin ella** (`CargaHuellaProbe`, misma huella byte a byte; y la
> misma que antes de trocear). Cuadro largo a cuadro largo, los culpables no fueron los
> previstos: el cambio de escena contaba en el primer cuadro (`ceder` cuenta ahora desde
> que empieza el cuadro); leer la partida antes de abrir la pantalla (se abre primero);
> la biblioteca de props, **431 MB de un `load`** (`Carga.cargar`, en hilo); el
> minimapa; la **rejilla de paso de la estación**, que se construía entera la primera
> vez que se preguntaba un camino (`HornoDeRejillas.hornear`); el Dijkstra desde casa;
> y el relieve desde caché. Lo de la simulación y el mundo recibe un `ceder` opcional,
> sin saber de pantallas (ARQUITECTURA §3.1). Tocados además: `Carga`, `RepartoDeCarga`
> (avance por tiempo), `ResourceProps`, `Minimapa`, `Campamento`, `Querencia`,
> `Marcha`, `Wayfinder`, `HornoDeRejillas`, `TerrainGenerator`, `MallaDelTerreno`,
> `TestBosque`, `TestParajes`, `GpuProfile`. Y `LlamadasHuerfanas` leía mal los ficheros
> en LF desde el suyo en CRLF: cinco huérfanas falsas, arreglado. Suite: **1 477
> pruebas, 8 092 comprobaciones**, `llamadas huerfanas: 0`.
- [x] **5. El mapa regional por etapas**, con la malla en frío en un hilo. *Toca
      `scripts/region/RegionMap.gd`, `scripts/mundo/MallaDelTerreno.gd`,
      `scripts/mundo/TerrainGenerator.gd`, `scripts/DemoMain.gd` (sólo al salir).* Grande.
> **HECHO (2026-09-15), sin hilo.** La malla en frío no necesitó hilo: sus 25 s eran
> bucles de GDScript —ruido, composición de alturas, vértices, índices, troceado— y bastó
> el `ceder` opcional por filas y por trozo (ARQUITECTURA §3.1). **Los cuatro caminos, con
> ventana (`CargaProbe`): nueva partida, fundar, ida al regional y retomar, 0 cuadros de
> más de 500 ms** (peores 418, 465, 383 y 388), la barra sin retroceder, quieta como mucho
> 1,1 s y a media barra con el 48-55 % del tiempo. **El regional carga en 19-20 s**
> frente a 27. Tres cosas que no estaban en el plan: la **frontera de la época** se trazaba
> dos veces al montar —una para tirarla— y cada una eran 720 ms (queda una, a trozos); la
> **primera carga de la escena** era un cuadro de 800 ms (`Carga.cambiar_de_escena` la
> lee en un hilo antes de cambiar); y **la barra del regional cambiaba de etapa por
> tiempo** y a media barra había pasado el 70 % —ahora el terreno dice cuándo empieza la
> malla (`TerrainGenerator.generando_la_malla`)—. Los pesos de las dos escenas, rehechos
> con lo medido con la pantalla puesta. Suite: **1 477 pruebas, 8 092 comprobaciones**,
> `llamadas huerfanas: 0`.
- [x] **6. Preparar un valle con progreso.** *Toca `scripts/region/PreparaValle.gd`,
      `scripts/region/DEMImporter.gd`, `scripts/ui/PanelCampamentos.gd`.* Media.
> **HECHO (2026-09-15), con un criterio cambiado por el usuario.** La receta de preparar
> un valle —MDT del IGN, vías y ríos de OSM, reconstruir el relieve, el relieve de
> alrededor, guardar— **va en un hilo** con la misma receta (`PreparaValle._hacer_el_valle`):
> es trabajo de datos sin nodos, y trocear cada algoritmo y cada descarga habría sido
> mucho más. `DEMImporter` no se tocó. Medido con red (`CargaProbe VALLE=1`, la Cueva de
> la Lastrilla, sitio 0, que queda preparada): **96 s y el cuadro más largo, 33 ms**. Pero
> **la barra se quedó quieta 41 s**: casi todo es esperar a la red —los ríos 43 s porque
> Overpass contestó con error y se reintentó, el relieve de alrededor otros 43—, y Overpass
> no manda nada hasta el final. Se probó a seguir acercando la barra al final sin llegar,
> y a la vista seguía quieta. **Decisión del usuario**: la barra se detiene cerca del
> final de su etapa, y un brillo que la recorre sin parar dice que no está colgado; el
> criterio de «quieta ≤ 2 s» se cambió en la spec para las esperas de red. Lo abren el
> mapa regional al fundar y la ficha de un campamento al migrar. **Y se perdió
> `TestCarga.gd`**: un parche que falló lo dejó vacío, y como era nuevo no estaba en git;
> se rehízo entero, con una prueba más.
- [x] **7. La caché de la malla regional.** *Toca `scripts/mundo/MallaDelTerreno.gd`,
      `scripts/region/RegionMap.gd`. Prueba: la clave no sale vacía con la copia, y
      cambia con el mar.* Pequeña.
> **HECHO (2026-09-15).** La caché se llama por el relieve de origen, el mar de la
> partida **y las lomas de la plataforma** (`RelieveDeLaPlataforma.huella`): retocar las
> lomas rehace la malla sola en vez de enseñar la vieja. Prueba en `TestNieblaRegional`.
> **La ida al regional con la malla en caché: 1,4-1,7 s** (`CargaProbe`, cuatro corridas),
> frente a los 19-20 de la tarea 5. Dos cosas más: **guardar la caché eran 724 ms de un
> cuadro** (106 MB) y va en un hilo; y **con la caché la barra mentía** —a media barra
> había pasado el 66-77 % de la carga—. Tenía dos causas: las etapas se declaraban con los
> pesos del frío y se volvían a declarar al ver la caché, y el rato que la pantalla está
> abierta antes de que la escena exista —leerla, guardar al salir, 160-1 120 ms— no era de
> ninguna etapa. Ahora se mira la caché antes de declarar (`MallaDelTerreno.ruta_de_la_cache`),
> ese rato cuenta en la primera etapa, y los pesos con caché salen de lo medido. Dos
> corridas: **0 cuadros de más de 500 ms en los cuatro caminos (peor, 416), mitad de
> barra al 62-63 % en la nueva partida, 49-50 % en la ida, 50-51 % al fundar y 45 % al
> retomar.** Suite: **1 481 pruebas, 8 133 comprobaciones**, `llamadas huerfanas: 0`.
- [x] **8. La siembra que no se repite.** *Toca `scripts/vista/Forest.gd`,
      `scripts/tests/TestBosque.gd`. Prueba: la vuelta da los mismos árboles; otra
      densidad vuelve a sembrar.* Media.
> **HECHO (2026-09-15).** `Forest._siembra_guardada`, con la huella de los mapas en
> crudo —no de su ruta—, el recuadro, las bocas, la densidad y `VERSION_DE_LA_SIEMBRA`,
> y `Forest.siembras` para contar. `TestBosque`: la vuelta no siembra y da los mismos
> árboles, otra densidad siembra con menos. Una cosa que no estaba en el plan: la etapa
> de sembrar pesa 9,6 s en la barra, y sin sembrar la barra se quedaba atrás; la etapa se
> da por hecha con lo que tardó (`Carga.dar_por_hecha_la_etapa`, prueba en `TestCarga`).
> Ocupa **35 MB**. Retomar el campamento, con ventana: **5,5 s frente a 15**.
- [x] **9. Medir todo.** `CargaProbe` en los caminos, dos corridas: cuadros ≤ 500 ms,
      barra sin retroceso ni quieta más de 2 s, mitad de barra entre el 35 y el 65 % del
      tiempo; `TransitoProbe` dos corridas: frío ≤ +10 %, segundo viaje sin malla,
      vuelta sin siembra; capturas. *Toca las dos sondas, y las que esperaban la cámara
      en vez de `montado` si hace falta.* Media.
> **HECHO (2026-09-15).** `CargaProbe`, dos corridas: **0 cuadros de más de 500 ms**
> (peor, 373), la barra sin retroceder, quieta como mucho 0,8 s, y a media barra con el
> 42-63 % del tiempo. `TransitoProbe`, ahora con la pantalla, esperando a `montado` y en
> frío el primer viaje (borra la malla regional y suelta la siembra), dos corridas con y
> dos sin pantalla la misma tarde: **ida en frío 20,2-20,3 s frente a 19,2-19,6 y vuelta
> 15,0-15,1 frente a 14,5-15,7, +3-5 %**; el segundo viaje, **1,3 s de ida con la malla en
> caché y 5,4 de vuelta sin sembrar** (antes 27 y 18 los dos). Tres sorpresas: la sonda
> medía una ida de 20 ms porque la escena de antes seguía diciendo `montado` mientras la
> nueva se leía en un hilo; en `_init` la carga en hilo no tiene bucle principal; y
> **al retomar, la mitad de la barra caía al 36 %** porque el peso del bosque de lejos
> era de antes de cargarlo en un hilo (2,6 s contra 3,6-3,9) —con el medido, 42-44 %—.
> Capturas a 1920×1080 y 1280×720 (`CargaCaptura`). Suite: **1 483 pruebas, 8 142
> comprobaciones**, `llamadas huerfanas: 0`.
- [x] **10. Documentar.** INTERFAZ §9 «Cómo quedó», ESTADO §2 (las cifras nuevas),
      SPECS §2.2 y §3.1 (la pantalla fuera de la escena, el reloj parado, `montado`),
      ARQUITECTURA §5.1 (a qué esperan las sondas).
> **HECHO (2026-09-15).** INTERFAZ §9.6 entera; ESTADO §2 con la tabla nueva del viaje
> sustituyendo a la de antes, y §3 con el total; SPECS §2.2 con la siembra guardada;
> ARQUITECTURA §5.1 con a qué espera una sonda que cambia de escena y cómo se mide un
> viaje en frío.

### ~~Depurar del 2026-09-15: el humo en cuesta, los tooltips de técnicas y el slider del 3D~~ — cerrado, con una medida pendiente

Tres quejas. **El humo** salía perpendicular a la hoguera en una ladera: el emisor
heredaba la inclinación del corro; ahora mira al cielo (EPOCA_01 §10.1, 24). **Los
tooltips de las técnicas** se cerraban al segundo: con la partida en marcha cambia el
porcentaje de una casilla y la ventana se sustituía entera; ahora lo que sólo cambia de
texto se escribe encima (INTERFAZ §8). **El slider** de la distancia de los árboles 3D,
de 10 m a sin límite, en caliente (INTERFAZ §8.7). Suite: **1 468 pruebas, 8 051
comprobaciones**, `llamadas huerfanas: 0`.

- [ ] **Medir «sin límite»** con `GpuProfile ARBOLES=1 ESCALON=1 RADIO=100000` y la
      máquina libre —la primera corrida coincidió con una partida abierta—, y poner la
      cifra en el aviso de la ventana (`VentanaDeConfiguracion.AVISO_SIN_LIMITE`).

### ~~La pared que se ve, y lo que otros pintaron antes~~ — cerrado (2026-09-15)

Las diez tareas hechas y en verde: **1 445 pruebas y 7 911 comprobaciones** —del
suelo de 1 419 y 7 848—, `llamadas huerfanas: 0`. Lo aprendido fue a
[SISTEMAS.md](SISTEMAS.md) §13 («Cómo quedó»), [GRAFICOS.md](GRAFICOS.md) §7.2,
[INTERFAZ.md](INTERFAZ.md) §4, [EPOCA_01](EPOCA_01_PALEOLITICO.md) §12,
[CREDITOS.md](CREDITOS.md) y [ESTADO.md](ESTADO.md) §2 y §3.

Spec y **plan técnico** en [SISTEMAS.md](SISTEMAS.md) §13 («Spec (2026-09-15)» y
«Plan técnico»), con lo visual en [GRAFICOS.md](GRAFICOS.md) §7.2.

- [x] **1. Los motivos.** Ciervo, cierva, caballo, uro, jabalí y bisonte; mano en
      negativo; puntos y signos (claviforme, tectiforme, escaleriforme), calcados
      en vectorial con su referencia. *Toca `scripts/datos/Motivos.gd` (nuevo),
      `docs/CREDITOS.md`, `scripts/tests/TestPared.gd` (nueva). Pruebas: todo
      relato pintable tiene motivo y ninguno cae en uno de relleno; cada motivo
      cita su referencia en CREDITOS.* Grande.
> **HECHO (2026-09-15).** Doce motivos en `scripts/datos/Motivos.gd`, **generado**
> por `scripts/tools/calcar_motivos.py`: baja la referencia de Commons, separa el
> pigmento, saca contornos con huecos y la silueta del cuerpo, y dibuja una hoja de
> prueba desde los polígonos. Casi todo sale de **calcos en dominio público de
> José-Manuel Benito** (Altamira, La Pasiega, Las Chimeneas, Hornos de la Peña) y
> uno de Obermaier; se vio cada hoja antes de darla por buena. **Tres sorpresas**:
> (1) **el uro no es cantábrico** —no hay en Commons un uro de la región con
> licencia libre— y sale de la Sala de los Toros de Lascaux, dicho en CREDITOS;
> (2) `PackedVector2Array([...])` **no es expresión constante** en GDScript: el
> primer `Motivos.gd` no compilaba y colgó la suite, así que los anillos van como
> listas planas con `Motivos.trazos_de`/`cuerpo_de`; (3) el hito de **la primera
> sepultura no es pintable** —no lleva tarea— aunque su comentario dice que sí:
> hueco anterior, apuntado y sin tocar aquí. El reparto de motivos es
> `Tale.motivo()`. `TestPared` (4 pruebas; la de las citas vista en rojo quitando la
> sección de CREDITOS). `RunTests` gana `SOLO=<suite>` para iterar. Suite: **1 423
> pruebas, 7 856 comprobaciones**.
- [x] **2. El arte de los que estuvieron antes.** Las diez cuevas, con sus paneles,
      cronologías y fuentes comprobadas. *Toca `scripts/datos/ArteDeLosDeAntes.gd`
      (nuevo), `docs/EPOCA_01_PALEOLITICO.md` §12, `docs/CREDITOS.md`,
      `TestPared.gd`. Pruebas: cada cueva del catálogo cae a menos de 150 m de un
      elemento de algún sitio, y ningún otro elemento se reconoce como cueva con
      arte.* Media.
> **HECHO (2026-09-15).** `scripts/datos/ArteDeLosDeAntes.gd`: las diez cuevas con
> sus paneles (una **muestra** de motivos en su proporción, no el inventario), texto
> y fuentes —*Science* 2012 (Pike y otros) para El Castillo y Altamira, *Science*
> 2018 (Hoffmann y otros) y su crítica para La Pasiega, la web del Ministerio y
> Wikipedia para el resto—, y la tabla en EPOCA_01 §12. **Dos sorpresas**: (1) **mi
> radio de 150 m confundía cuevas**: Las Monedas está a 112 m de La Pasiega y Las
> Chimeneas a 115 m de El Castillo, no a 300–400 m como escribí; como catálogo y
> mapas salen del mismo fichero de OpenStreetMap, se reconocen **al metro** (10 m).
> (2) La época cubre **todo el Magdaleniense** y la banda no tiene año fijo, así que
> los textos dan la cronología publicada sin decir «antes» o «después» de la banda,
> salvo lo claramente premagdaleniense. Se corrigió además una frase inventada sin
> querer («tapado por la calcita» en El Pendo). `TestPared`, 4 pruebas más.
- [x] **3. La pared.** Relieve por semilla, sitio y cueva; la medida del ajuste; y
      la colocación, **pintando encima de la más antigua de la banda cuando no
      queda sitio** (decisión del usuario). *Toca `scripts/sim/ParedDeLaCueva.gd` (nuevo), `TestPared.gd`,
      `scripts/tests/ParedProbe.gd` (nueva, sin escena). Pruebas: misma semilla,
      misma pared; nada encima de una figura documentada. Sonda: con veinte
      figuras, cada una ajusta mejor que el 90 % de los sitios al azar.* Grande.
> **HECHO (2026-09-15).** `scripts/sim/ParedDeLaCueva.gd`: relieve sembrado
> (abombamientos y grietas, con `Calculo.exponencial` y no `exp`, que no da el mismo
> bit en todos los hilos: lo cazó `TestCalculo`), convexidad y pendiente, ajuste
> —cuerpo sobre bulto, contorno sobre arista— y colocación en dos pasadas. **Medido
> con `ParedProbe`** (60 figuras en 3 paredes): la peor figura recalca mejor que el
> **99 % de los sitios libres**; colocar cuesta **53 ms de media**. Lo que salió
> distinto: (1) guardaba la figura con el tamaño de la tabla y no con el probado, y
> sus muestras caían encima de lo documentado; (2) la primera versión costaba
> **248 ms** por figura —las llamadas por muestra son lo caro en GDScript— y bajó a
> ~50 con el bucle en línea; (3) el listón de «recalca bien» estaba en la mediana y
> la spec dice el 90 %, y el percentil 90 de 64 muestras era ruidoso (ahora 200);
> (4) **la premisa «por construcción sale» se cayó**: con la pared llena, una figura
> quedaba al 88 % contra cualquier sitio porque se comparaba con huecos ya ocupados.
> **Decisión del usuario**: el criterio es contra los sitios libres; la spec lo dice.
> Y una **lectura mía, dicha para que se corrija**: con la pared llena se pinta encima
> de la más antigua sólo si recalca al menos igual que el mejor hueco libre. Cuatro
> pruebas más en `TestPared`. Suite: **1 431 pruebas, 7 868 comprobaciones**.
- [x] **4. Pintar con sitio.** La figura se coloca al terminar y queda en el
      relato con su cueva; lo pintado antes va a la cueva de la banda; mudarse no
      mueve las pinturas. *Toca `scripts/banda/Tale.gd`, `scripts/sim/Pinturas.gd`,
      `scripts/tests/TestRelato.gd`. Pruebas: cinco pintados, cinco figuras con
      sitio; tras `Traslado`, siguen en la cueva vieja; misma partida, mismos
      sitios.* Media.
> **HECHO (2026-09-15).** `Tale` gana `cueva` y `sitio`; `Pinturas._paint_wall` coloca
> la figura al terminar y la guarda en el relato; `Pinturas.pared_de(cueva)` monta la
> pared —lo documentado primero, lo pintado después, cada cosa en su sitio— y
> `Campamento` le pasa los elementos del sitio para reconocer las cuevas con arte. Lo
> pintado de antes, sin cueva, va a la de la banda, y `Traslado` lo fija **antes** de
> mudarse. La caché de paredes va fuera de la instantánea. Cuatro pruebas en
> `TestRelato`; una falló por el montaje —la cueva de la banda de las pruebas vale -1,
> el mismo valor que «sin cueva»— y se corrigió la prueba, no el código. Suite:
> **1 435 pruebas, 7 878 comprobaciones**, huérfanas 0.
- [x] **5. Pintar lo de antes.** La lista de lo pintable incluye lo anterior a la
      técnica, con su fecha, y se encarga desde la ventana de Técnicas. *Toca
      `Pinturas.gd`, `scripts/ui/PanelTecnicas.gd`, `TestRelato.gd`. Pruebas:
      relato del día 10, técnica el 50, se encarga el 51 y queda con la fecha del
      10; sin técnica no se encarga nada y la ventana dice por qué.* Media.
> **HECHO (2026-09-15).** `Pinturas.pintables()`: todo relato pintable sin pintar,
> antiguo incluido, por fecha. La ventana de Técnicas (bloque del hogar) lo lista con
> un botón «Pintar» **aunque no se sepa pintar**: apagado, y con el motivo en la
> ayuda. Antes el bloque entero se escondía sin la técnica. Tres pruebas en
> `TestRelato`: el relato del día 10 se encarga el 51 y queda con «Jornada 10»; la
> lista va por fecha sin lo pintado; la ventana dice por qué no.
- [x] **6. Lo que se lee al entrar.** La primera entrada en una cueva con arte
      cuenta su panel, una sola vez por campamento, sin tarea. *Toca `Pinturas.gd`,
      `TestRelato.gd`. Pruebas: una vez y no dos; el estado de la banda es el
      mismo salvo crónica y relatos.* Pequeña.
> **HECHO (2026-09-15).** `Pinturas.entrar_a_mirar(cueva)`: la primera vez que un
> campamento entra en una cueva con arte, su texto va a la crónica y a los relatos
> **sin tarea** —no pintable, no sube techos— y **sin parar la partida**, porque el
> texto ya está en la sala. `Pinturas.por_que_no_se_entra` sólo pide que esté
> explorada. Tres pruebas en `TestRelato`. Suite: **1 441 pruebas, 7 901
> comprobaciones**, huérfanas 0.
- [x] **7. La sala.** Capa con su propio mundo 3D, la pared con su relieve y la
      textura de roca, luz de lámpara y las figuras sobre el relieve. *Toca
      `scripts/vista/SalaDeLaCueva.gd` (nuevo), `shaders/pared_pintada.gdshader`
      (nuevo), `TestPared.gd`. Prueba: tantas figuras dibujadas como relatos
      pintados en esa cueva más las documentadas.* Grande.
> **HECHO (2026-09-15).** `SalaDeLaCueva` y `pared_pintada.gdshader`: capa con mundo
> propio, la malla del relieve con la caliza, la lámpara y las figuras pintadas en
> una textura en su sitio exacto. **Tres fallos que sólo salieron con ventana**, uno
> por captura: el `Control` sin tamaño bajo un `CanvasLayer` (sala invisible, texto
> en columna); los triángulos en sentido antihorario (pared negra, de espaldas); y
> las manos invisibles con un halo de 5 px, más la cámara demasiado lejos. Y **un
> sesgo que no era**: las figuras de dos capturas se amontonaban abajo porque las
> dos paredes eran la misma roca —misma semilla, sitio y cueva—; en 12 paredes los
> centros se reparten por todo el alto. De paso se vio que con el listón al 90 % se
> pintaba encima con la pared a medias, y **volvió a la mediana**. Prueba en
> `TestPared`: se dibujan tantas figuras como documentadas más pintadas.
- [x] **8. Entrar y salir.** Botón en la ficha de la cueva y en la del sitio
      regional, con motivo cuando no se puede; la partida sigue o se pausa como con
      cualquier ventana; la entrada vuelve al valle al salir. *Toca
      `scripts/ui/GameUI.gd`, `scripts/region/RegionMap.gd`,
      `scripts/tests/TestPared.gd`. Pruebas: sin explorar no se entra y se dice por
      qué; explorada sí.* Media.
> **HECHO (2026-09-15).** «Entrar a mirar la pared» en la ficha de toda cueva
> (apagado con el motivo sin explorar), y «Entrar en …» en la ficha del sitio del mapa
> regional por cada cueva explorada de su campamento (`Pinturas.cuevas_para_entrar`).
> La primera versión puso esa lista en `RegionMap`, que no tiene `class_name`: la
> prueba no compiló y colgó la suite. Tres pruebas en `TestPared`. Suite: **1 445
> pruebas, 7 911 comprobaciones**, huérfanas 0.
- [x] **9. Medir y ver.** Capturas de la pared de la banda con cinco pintadas y de
      Covalanas y El Castillo; entrada y salida ≤ 2 s; la sala frente al valle en
      Medio a 1080p, dos corridas. *Toca `scripts/tests/CuevaCaptura.gd` (nueva,
      con ventana). ~15 min.* Media.
> **HECHO (2026-09-15).** `CuevaCaptura`, dos corridas a 1920×1080: entrar **0,4–0,6 s**
> (1,5 s la primera vez de la partida, al descomprimir la roca y compilar el shader),
> salir **1–3 ms**, GPU de la sala **2,0–2,1 ms** frente a los 18,1 del valle en
> Medio. Con la sala abierta **se apaga el 3D de debajo**: tapaba la pantalla pero
> el valle seguía dibujándose. En las capturas se vio además que las cuernas de un
> ciervo a línea se metían en otra figura, porque sólo contaba el cuerpo como
> pisada: ahora cuenta también el contorno. La cámara arranca mirando lo pintado.
- [x] **10. Documentar.** SISTEMAS §13 «Cómo quedó», GRAFICOS §7.2 con el coste,
      EPOCA_01 §12 con la lista, CREDITOS, ESTADO §2 y §3 con la suite.
> **HECHO (2026-09-15).** Todo eso, e INTERFAZ §4 con los tres sitios nuevos.

### ~~El bosque: árboles 3D de cerca, impostores de lejos, sin aros~~ — cerrado (2026-09-15)

Las diez tareas hechas y en verde: **1 462 pruebas y 8 017 comprobaciones** —del
suelo de 1 445 y 7 911—. Lo aprendido fue a [GRAFICOS.md](GRAFICOS.md) §7 (la fila de
árboles) y §7.1 («Cómo quedó el color», los aros y huecos, «Lo que cuesta»),
[INTERFAZ.md](INTERFAZ.md) §8.7, [CREDITOS.md](CREDITOS.md) y [ESTADO.md](ESTADO.md)
§2 y §3. **Dos cifras de la spec quedaron fuera y el usuario las aceptó**: Medio cuesta
3,4-3,5 ms y no 3,0, y montar el mapa tarda 1,8-2,8 s más que en Mínimo. Queda como
deuda que las texturas de los árboles 3D están sin comprimir y sin mipmaps.

Spec y **plan técnico** en [GRAFICOS.md](GRAFICOS.md) §7.1, con el selector en
[INTERFAZ.md](INTERFAZ.md) §8.7. **Los árboles se generan con EZ-Tree** (decisión del
usuario al planear).

- [x] **1. Generar las cinco especies.** Presets afinados, tres variantes y tres
      niveles de detalle; importadas a Godot; licencia de las hojas resuelta.
      **Capturas por especie, y parada para que el usuario las vea.** *Toca
      `scripts/tools/arboles/` (nuevo), `scripts/tools/ArbolesImport.gd` (nuevo),
      `models/arboles/` (nuevo), `docs/CREDITOS.md`, `scripts/tests/ArbolesCaptura.gd`
      (nueva). Prueba: cada especie tiene sus tres niveles y el primero pasa de
      tantos triángulos.* Grande.
> **HECHO (2026-09-15), a la espera de que el usuario vea las capturas.** EZ-Tree corre
> en Node con un `document` de mentira (sus materiales piden uno para cargar texturas
> que aquí no hacen falta); `generar.mjs` saca **seis variantes por especie** —no
> tres: «que no sean todos iguales, genera variedad», dijo el usuario a mitad—, cada
> una desviada de su preset en ángulo, largo, ramas, retorcimiento, arranque de copa,
> hoja y altura, y tres niveles de detalle. `ArbolesImport.gd` las trae como
> `ArbolModelo` (30 recursos, 26 MB): **nivel 0 de 10 000 a 24 000 triángulos, nivel 2
> de 1 900 a 4 600**. Hojas y cortezas de ambientCG, CC0: **las hojas de EZ-Tree no
> declaran licencia y no se usan**. Tres cosas que salieron en las capturas: **una
> hoja por tarjeta daba copas ralas con hojas de un metro** —ahora cada tarjeta lleva
> el ramillete entero del atlas—; el tronco retorcido **inclinaba los pinos**, y la
> fuerza del preset doblaba su copa; y el abedul salía un palillo. El verde lima de
> roble y avellano es de la tarea 6. `TestBosque`: seis variantes, tres niveles que
> van a menos, alturas razonables y distintas. Suite: **1 446 pruebas, 7 912
> comprobaciones**.
- [x] **2. Las referencias de color.** Fotos por especie y estación, recortes de copa
      y corteza, color medio en CIELAB. *Toca `docs/GRAFICOS.md`, `docs/CREDITOS.md`,
      `scripts/tools/color_de_referencia.py` (nuevo).* Media.
> **HECHO (2026-09-15).** `scripts/tools/arboles/color_de_referencia.py` (y
> `candidatas.py`): once colores medios en CIELAB —copa en verano, copa en otoño de los
> caducos, corteza— de fotos de Commons con su licencia, recortando la zona útil y
> quitando cielo y sombra. En `models/arboles/color_de_referencia.json`. **Aviso**: las
> fotos tienen luces distintas —el roble de verano está en sombra y sale oscuro—, así
> que la referencia es aproximada; por eso el margen es ΔE ≤ 10.
- [x] **3. Los impostores de varias vistas.** Hornear las vistas y el shader que las
      elige. *Toca `scripts/tools/ArbolImpostores.gd`, `shaders/arbol_impostor_vistas.gdshader`
      (nuevos), `scripts/tests/TestBosque.gd`. Prueba de la elección de vista por
      dirección; sonda de silueta en ocho acimuts y desde arriba.* Grande.
> **HECHO (2026-09-15).** `ImpostorVistas` (la cuenta hemi-octaédrica, pura),
> `ArbolImpostores.gd` (hornea 64 vistas por árbol a 64 px, color y normal) y
> `arbol_impostor_vistas.gdshader`. **De las seis variantes y no de tres**: si el 3D es
> una variante y su impostor otra, al cruzar el relevo cambia de forma. Cada especie
> junta sus seis en un `Texture2DArray`, y cada pie elige la suya con el dato de
> instancia. Dos tropiezos: con `world_vertex_coords` el vértice llega ya en el mundo,
> así que la esquina del cuadrado sale de la UV; y el horneado se cortó una vez porque
> se cerró la ventana a mano —ahora retoma donde se quedó—. `TestBosque`: la vista va y
> vuelve, y las siluetas de lados opuestos no son la misma ni reflejada.
- [x] **4. El bosque por escalones.** Mínimo como hoy; Medio+ con 3D, impostor nuevo y
      relevo fundido. *Toca `scripts/vista/Forest.gd`, `TestBosque.gd`. Prueba: mismo
      censo y posiciones en los cuatro escalones.* Grande.
> **HECHO (2026-09-15), con tres premisas del plan caídas.** Mínimo sigue por su código;
> Medio, Alto y Ultra montan 3D de cerca e impostores de lejos. **(1) El radio del 3D**:
> con 160 m en Alto salían **541 millones de triángulos a 6 FPS** —el valle tiene
> **1 052 727 árboles**—; ahora es provisional 40 / 70 / 120 m hasta medir. **(2) Los
> modelos, mucho más ligeros**: el nivel 0 bajó de 10 000–24 000 a 5 000–9 000
> triángulos, y el 2 a 170–1 300 quitando ramas y un nivel de ramificación. **(3) Bloques
> de 32 m** para el 3D, no los 128 de las tarjetas: con radios de decenas de metros un
> bloque de 128 lo metía todo en el nivel 0. Con eso, **Medio pinta 4,8 M de triángulos**
> en el encuadre bajo y 5,9 M en el alto, frente a los 6,4 M de Mínimo en ese mismo
> encuadre. Y los niveles de detalle, **sin solaparse**: con holgura en los dos lados se
> pintaban dos a la vez. La sonda `BosqueCaptura` salió dos veces mal —a las 6:00 con
> niebla, y con la cámara pegada al suelo porque `min_distance` son pocos metros; lo vio
> el usuario, «se ve durante un segundo y después desaparece»—. `TestBosque`: el 3D
> reparte los mismos pies que la siembra, cada uno en la variante de su impostor; sin
> ventana, un MultiMesh no devuelve lo que se le escribe, así que se prueba el reparto.
- [x] **5. Sin huecos.** El impostor no se apaga antes de que su 3D esté montado.
      *Toca `Forest.gd`, `TestBosque.gd`.* Media.
> **HECHO (2026-09-15), y con él cambió el relevo.** El plan decía trama de puntos
> complementaria entre 3D e impostor; **en la captura se veía como un tamiz** sobre las
> copas, y era lo mismo que el shader del bosque Mínimo ya había descartado («se lee como
> que el bosque se disuelve»). Ahora **el relevo es un corte por árbol**: 3D si su pie
> está dentro del radio, impostor si fuera, medido a la cámara de verdad que `Forest`
> pasa a los materiales —en el pase de sombras la «cámara» es la luz—. Y **el impostor
> sólo se esconde dentro del radio ya montado** (`_poner_el_ojo`): si la cámara corre
> más que el montaje, se ve el impostor y no un hueco. Mínimo no tenía huecos —su
> impostor nunca se esconde—. `TestBosque`. Suite: **1 452 pruebas, 7 928
> comprobaciones**.
- [x] **6. El color.** Tintes por especie y estación en todos los escalones, contra
      las referencias. *Toca `Forest.gd`, `scripts/tests/ArbolColorProbe.gd` (nueva).
      Sonda: ΔE ≤ 10.* Media.
> **HECHO (2026-09-15), y bastante más grande de lo presupuestado.** `ArbolColorProbe`
> mide copa, otoño, corteza, invierno e impostor contra 3D, en Medio y en Mínimo (de
> lejos y de cerca): **todo ΔE ≤ 10, casi todo por debajo de 3**, repetido en una
> segunda corrida. Los tintes, en `Forest.COLOR_DE_ESPECIE`. Lo que no estaba en el plan
> —detalle en GRAFICOS §7.1, «Cómo quedó el color»—: dos fotos de referencia cambiadas
> (roble en sombra y luego de primavera; abedul de noviembre gris); la textura se
> desatura antes de teñir porque multiplicando pedía ×5 y salía magenta; el `BACKLIGHT`
> verde fijo de la hoja 3D, que era media queja del verde lima; **los 30 impostores
> rehorneados** con máscara de hoja; una luz por especie en el impostor, sólo en la
> hoja; el atlas de Mínimo normalizado por el brillo de su celda, que quemaba a neón;
> el color de rama de Mínimo medido en invierno contra la corteza; y un fallo que sólo
> vio la captura del valle: **el invierno de los caducos salía azul**. `TestBosque`,
> siete pruebas nuevas de la regla. Suite: **1 459 pruebas, 7 979 comprobaciones**.
- [x] **7. El selector.** «Árboles» en la configuración y en los niveles. *Toca
      `Configuracion.gd`, `VentanaDeConfiguracion.gd`, `TestConfiguracion.gd`,
      `ConfiguracionProbe.gd`, `ConfiguracionCaptura.gd`.* Media.
> **HECHO (2026-09-15).** Bajo → Mínimo, y cada otro nivel al escalón de su nombre; se
> aplica al montar el mapa y la ventana lo avisa. Una sorpresa: un fichero de
> configuración de antes habría abierto en Personalizado —el ajuste que falta tomaba
> el valor de Medio—; ahora toma el de su nivel guardado, con prueba.
> `ConfiguracionCaptura` no necesitó cambios. Detalle en INTERFAZ §8.7. **Ojo**: como
> Medio es el nivel por defecto, el juego abre ya con árboles 3D, y su coste está sin
> medir hasta la tarea 9. Suite: **1 461 pruebas, 7 997 comprobaciones**.
- [x] **8. Aros y huecos, medidos.** *Toca `scripts/tests/ArbolAroProbe.gd`,
      `scripts/tests/ArbolHuecoProbe.gd` (nuevas). En los cuatro escalones.* Media.
> **HECHO (2026-09-15): cero aros y cero huecos en Mínimo, Medio, Alto y Ultra**, y
> un fallo real encontrado y arreglado. Las dos sondas, con `SoloElBosque` común
> (sólo el bosque sobre negro). El criterio escrito se cambió al medir —detalle en
> GRAFICOS §7.1—: el aro contra una referencia de sólo impostores, y cuenta si falta
> al menos una copa; el hueco contra la misma pose asentada, comprobado rompiendo el
> bosque a propósito (`ROMPER=1`, huecos de 11 442 px). **El fallo**: los nodos de
> los bloques 3D y de las láminas de cerca de Mínimo estaban a cota cero, y Godot
> medía el rango de visibilidad desde ahí: a 38 m de órbita, el primer plano del 3D se
> apagaba entero (1 % de cobertura). `Forest.centro_de` los pone a la altura de sus
> árboles, y `TestBosque` lo fija. Tres trampas del instrumento en el camino: caducos
> pelados de primavera (se mide en verano), la textura del cuadro anterior tras
> `process_frame`, y un umbral de copa de 3 px en Mínimo que contaba ruido del
> horizonte. Suite: **1 462 pruebas, 8 017 comprobaciones**.
- [x] **9. Lo que cuesta.** GPU por escalón a 1080p (dos corridas), VRAM, montar el
      bosque, y fijar el radio del 3D de cada escalón. *Toca `GpuProfile.gd`,
      `Configuracion.gd` (los radios).* Media.
> **HECHO (2026-09-15), con dos cifras de la spec aceptadas por el usuario.**
> `GpuProfile ARBOLES=1`. **La primera medida dio 14,3 ms de bosque en Medio**, y no
> era el 3D sino el impostor de varias vistas: con recorte alfa, ocho lecturas de
> textura por píxel en cuadrados solapados. Bajó a **3,4-3,5 ms** leyendo el alfa antes
> que la normal, mezclando las cuatro vistas sólo de cerca (`Forest.MEZCLA_HASTA`) y
> ajustando el cuadrado al árbol. No llega a 3,0: **el usuario dio por buenos 3,8**.
> Los radios del 3D se quedan en 40 / 70 / 120 m, y siguen en `Forest.RADIO_3D`, no en
> `Configuracion`. **Montar el mapa tarda 1,8-2,8 s más que en Mínimo** —1,4 s de
> modelos, 0,84 de impostores—, y **el usuario lo aceptó** («me vale como está»). VRAM
> +145 MB. Queda como deuda que las texturas de los árboles están sin comprimir y sin
> mipmaps. Todas las cifras en GRAFICOS §7.1, «Lo que cuesta».
- [x] **10. Documentar.** GRAFICOS §7 y §7.1, INTERFAZ §8.7, CREDITOS, ESTADO §2 y §3.
> **HECHO (2026-09-15).** Cada tarea dejó lo suyo en su documento; al cerrar, la tabla de
> niveles de GRAFICOS §7 (fila de árboles y aviso de que la fila de GPU es de antes),
> las filas del plan técnico que el trabajo cambió (seis variantes, corte por árbol,
> máscara de hoja), ESTADO §2 y §3 con el total del día, y CREDITOS con las fotos de
> referencia.

### Lo que salió de depurar la noche del 2026-09-14 — pendiente de `/spec`

De catorce quejas, **nueve se arreglaron** (ver SISTEMAS §4, §16 y §20; INTERFAZ
§4; ARQUITECTURA §3; ESTADO §2). **Decisión del usuario**: lo que no es un fallo
sino funcionalidad nueva va por `/spec`. Queda esto:

- **La niebla del mapa regional, como nubes.** Decisión: primero medir lo que
  cuesta hoy y enseñar dos o tres aspectos con captura —ruido en capas animado
  frente a volumétrico de verdad— antes de elegir. GRAFICOS §3.
- **Enviar expedición desde la banda.** El botón de rumbo no hace nada desde el
  mapa de la banda; debería abrir el regional con direcciones posibles y la
  lista de quién va, **desactivado sin 3 pieles curtidas y comida**. Y cuantas
  más cumbres coronadas, más direcciones «vistas desde las cimas». Encaja con la
  decisión de hoy: la cumbre da pistas, la expedición descubre. SISTEMAS §4.
- **Filtro en la ventana de Parajes**, por tipo y por distancia. INTERFAZ.
- **Las pasarelas en Obras como las demás obras**: con botón «ver», su pestaña.
  INTERFAZ.
- **El tooltip de cada técnica aprendida, con su efecto EXACTO en el juego.**
  INTERFAZ, con SISTEMAS §2.

Y **una optimización ya medida**, que no se tocó por no meterla a medias en una
sesión de catorce quejas —ESTADO §2 tiene las cifras—:

- **El viaje al mapa regional: 27 s de ida y 18 s de vuelta, siempre.** Ida: la
  malla regional no encuentra caché nunca porque `RegionMap._setup_terrain`
  duplica el heightmap y la copia no tiene `resource_path`, que es de donde sale
  la clave (24,6 s). Vuelta: `_levantar_vegetacion` 13,8 s y
  `levantar_el_conocimiento` 2,3 s. Con `TransitoProbe` para comprobarlo.
- **Objetos de la escena anterior que siguen vivos** tras cambiar de mapa:
  `Campamentos` llama al `GameUI` liberado y `RelojDeLaPartida` escribe sobre
  una simulación liberada. `SCRIPT ERROR` en cada viaje.
- **Mirar la ropa con los tiempos nuevos**: el vestido pasó de 22 a 30 horas.

---

### Cinco specs del 2026-09-14 — escritas, pendientes de `/plan-tarea`

Escritas con `/spec` a partir de una petición del usuario, con las decisiones
sacadas a preguntas. **La primera —prioridades y cola del taller— se hizo el
2026-09-14**; las cuatro que quedan no tienen plan ni tareas todavía:

| Qué | Dónde está la spec |
|---|---|
| **Varios campamentos** —con plan y tareas desde el 2026-09-14, ver el bloque de abajo— | [SISTEMAS.md](SISTEMAS.md) §23; contrato en [SPECS.md](SPECS.md) §6.4; ventanas en [INTERFAZ.md](INTERFAZ.md) §4 |
| **Explorar hacia un rumbo** y **la niebla del mapa regional** —hechas el 2026-09-14, ver el bloque de abajo— | [SISTEMAS.md](SISTEMAS.md) §4; cómo se ve, [GRAFICOS.md](GRAFICOS.md) §3 |
| **Configuración** —hecha el 2026-09-14, ver el bloque de abajo— | [INTERFAZ.md](INTERFAZ.md) §8; los niveles, [GRAFICOS.md](GRAFICOS.md) §7 |

**Dependencias que salen de leerlas**, para quien las planee: la niebla del mapa
visitado y la del regional usan lo que descubre la exploración con rumbo, así
que ésta va antes o con ella; los campamentos guardan sus prioridades y su cola,
así que §22 no debe dar por hecho un solo campamento; y §23 es, con mucho, la más
grande —simular fuera de la escena lo que hoy vive dentro— y conviene medir el
coste de un campamento sin dibujar antes de construir nada encima.

### ~~Que lo que la banda aprende dure el año~~ — cerrado (2026-09-14)

Las seis tareas hechas y en verde: **1 407 pruebas y 7 824 comprobaciones** —del
suelo de 1 404 y 7 813—, `llamadas huerfanas: 0`. Lo aprendido fue a
[SISTEMAS.md](SISTEMAS.md) §18 y §20 y a [ESTADO.md](ESTADO.md) §2 y §3. **Y la
cifra honesta**: guardar las veredas de una estación a otra ahorra un **0,3 %** de
búsquedas, no más, porque el tope de 200 se satura en cuatro jornadas. El cambio
se hace porque lo aprendido no debe tirarse y porque la pasarela lo necesitaba, no
por rendimiento.

Spec y **plan técnico** en [SISTEMAS.md](SISTEMAS.md) §18 («Plan técnico: que lo
aprendido dure el año»). Sale de depurar las pasarelas el 2026-09-14.

- [x] **1. La prueba de que hoy se pierde.** Una vereda trazada con la rejilla de
      primavera, un ciclo de estaciones, y volver a primavera: hoy no está.
      *Toca `scripts/tests/TestVeredas.gd`. Prueba que falla antes del cambio.*
      Pequeña.
> **HECHO (2026-09-14).** Dos pruebas en `TestVeredas`: una vereda de primavera que espera a que vuelva su estación, y las de una estación que no echan a las de las otras. Las dos rojas antes del cambio.
- [x] **2. El olvido, sólo donde el sello no llega.** `forget_routes` deja de
      vaciar las veredas; quien cierra una celda a mano las tira. *Toca
      `scripts/sim/Marcha.gd`, `scripts/banda/BandKnowledge.gd`,
      `scripts/tests/TestVeredas.gd`. Pruebas: sobrevive al cambio de estación y a
      la pasarela; no sobrevive a cerrar una celda.* Media.
> **HECHO (2026-09-14).** `forget_routes` deja de vaciar las veredas; `Marcha._cerrar_y_olvidar` las tira al cerrar una celda a mano, que es el único cambio que el sello no ve. **Y una premisa del plan se cayó**: no bastaba con eso, porque `BandKnowledge.vereda` **borraba la caducada al leerla** —«para no dejarla ocupando sitio»—; ahora la deja dormida. La prueba vieja que exigía ese borrado se reescribió con la regla nueva, diciendo qué pedía antes.
- [x] **3. El tope, para cuatro rejillas.** Que las veredas de una estación no
      echen a las de las otras. *Toca `BandKnowledge.gd`, `TestVeredas.gd`.
      Prueba: con las cuatro estaciones llenas, ninguna se queda sin las suyas.*
      Media.
> **HECHO (2026-09-14).** El tope de 200 se cuenta **por rejilla** (`_orden_por_rejilla`, `_rejilla_de`, y `veredas_de(grid)` para poder contarlas). Prueba: un invierno entero de caminos no se lleva la vereda de primavera, y el invierno sí olvida las suyas más viejas.
- [x] **4. Que la pasarela vuelva a tener veredas que mirar.** *Toca
      `scripts/tests/TestPasarela.gd`. Prueba: tras volver la estación, el vado que
      se cierra sigue siendo el cruce elegido.* Pequeña.
> **HECHO (2026-09-14).** Prueba en `TestPasarela`: el vado que se cierra sigue siendo el cruce elegido después de rehacer la rejilla, porque la vereda ya no se borra.
- [x] **5. Medir lo que cambia.** `AtascoProbe` con la misma semilla antes y
      después: búsquedas completas por jornada, atascos y veredas recordadas.
      *~10 min las dos corridas.* Media.
> **HECHO (2026-09-14), y el resultado es que casi no cambia.** `VeredasProbe` (nueva) cruza estaciones a mano —primavera, invierno, primavera— porque la pregunta es de estaciones y no de jornadas; `OLVIDO=1` reproduce lo de antes en la misma sonda. Con `SEMILLA=42` y cuatro jornadas por tramo: al volver la primavera, **150,5 búsquedas por jornada guardando las veredas frente a 151,0 tirándolas (0,3 %)**, y 350 veredas guardadas frente a 200. **El tope de 200 se satura en cuatro jornadas**, así que de una estación a la otra sobrevive poco: el cambio es correcto, pero no es una mejora de rendimiento y así queda escrito.
- [x] **6. Documentar.** SISTEMAS §18 (y §20, que se apoyaba en ello), ESTADO §2
      con las cifras y §3 con la suite.
> **HECHO (2026-09-14).** SISTEMAS §18 («Cómo quedó», con la tabla medida y la deuda) y §20 —la regla del vado vuelve a tener veredas—, ESTADO §2 con las cifras y §3 con la suite.

### ~~La configuración: pantalla, gráficos y sonido~~ — cerrado (2026-09-14)

Las ocho tareas hechas y en verde: **1 397 pruebas y 7 798 comprobaciones** —del
suelo de 1 381 y 7 680—, `llamadas huerfanas: 0`. Lo aprendido fue a
[INTERFAZ.md](INTERFAZ.md) §8.6, [GRAFICOS.md](GRAFICOS.md) §1 y §7 (Medio es la
1070; lo que cuesta cada nivel), [SPECS.md](SPECS.md) §2.2 y
[ESTADO.md](ESTADO.md) §3. **Queda dicho**: la vegetación entra al montar el mapa,
no en caliente, y los tiempos son de la máquina de medida, no de una 1070.

Spec y **plan técnico** en [INTERFAZ.md](INTERFAZ.md) §8; los niveles, en
[GRAFICOS.md](GRAFICOS.md) §7.

- [x] **1. `Configuracion`.** Estado, niveles, guardar y cargar en su ruta.
      *Toca `scripts/vista/Configuracion.gd` (nuevo),
      `scripts/tests/TestConfiguracion.gd` (nueva), `RunTests.gd`. Pruebas: ida y
      vuelta de cada valor sobre el fichero, un nivel fija sus ajustes, tocar uno
      pone Personalizado.* Media.
> **HECHO (2026-09-14).** `scripts/vista/Configuracion.gd`: estado estático, `NIVELES` con las decisiones del usuario (Medio = lo de siempre, la 1070; Alto por encima; Ultra al máximo), `poner_nivel`/`poner_ajuste` —el nivel se deduce de los ajustes, y si no coincide ninguno, Personalizado—, y `ConfigFile` en `user://configuracion.cfg` con la ruta conmutable. `TestConfiguracion`: ida y vuelta de cada valor, una prueba por nivel, Ultra máximo y niveles crecientes.
- [x] **2. Aplicar la pantalla y el sonido.** Modo, tamaño, sincronización, tope,
      lista de resoluciones, buses de audio. *Toca `Configuracion.gd`,
      `TestConfiguracion.gd`.* Pequeña.
> **HECHO (2026-09-14).** `aplicar_pantalla` (modo, tamaño centrado en ventana, sincronización, tope), `resoluciones` —la nativa y las habituales que caben: Godot no enumera los modos del monitor— y `aplicar_sonido` sobre los buses Master, Musica y Efectos, que crea si faltan. Pruebas: resoluciones ordenadas y que caben, volúmenes en sus buses, tope en el motor.
- [x] **3. Medir lo que cuesta cada nivel y cada valor.** `GpuProfile` a 1080p
      con ventana: los cuatro niveles, y nubes y vegetación con sus valores
      candidatos, alternando en la misma corrida, dos corridas. *Toca
      `scripts/tests/GpuProfile.gd`. ~15 min.* Media.
> **HECHO (2026-09-14), después de la 4** —para medir un nivel hay que aplicarlo con el código del juego—. `GpuProfile NIVELES=1`, dos corridas, 1080p en ventana: **Bajo 7,8 ms, Medio 18,1, Alto 21,0–21,2, Ultra 37,7–39,9**. Nubes: de 0 a 32 pasos, menos de 1 ms, así que se quedan 0 / 12 / 20 / 32. Vegetación: el 25 % ahorra 2,3–2,5 ms y va en Bajo. **Sorpresa**: resembrar el bosque tarda ~10 s con el fotograma parado. Tablas en GRAFICOS §7.
- [x] **4. Aplicar los gráficos en caliente.** El grupo, `WorldEnvironmentSetup`,
      `Forest`, la escala de render. *Toca `Configuracion.gd`,
      `WorldEnvironmentSetup.gd`, `Forest.gd`. Sonda sobre el valle montado: cambiar
      el nivel cambia el entorno sin recargar. ~2 min.* Media.
> **HECHO (2026-09-14).** `Configuracion.aplicar_graficos`: el atlas y el suavizado de sombras en el servidor, la escala (FSR2 por debajo de 1) en la ventana raíz, y el grupo `configuracion_grafica` —`WorldEnvironmentSetup` (oclusión, niebla, sombras del sol y de la luna, pasos de nube) y `TerrainGenerator` (normales y ORM)—. **Cambio de plan**: la vegetación **no** va en caliente —~10 s de fotograma parado— y entra al montar el mapa (`Configuracion.AL_MONTAR_EL_MAPA`); `Forest.resembrar` queda para la sonda. Comprobado sobre el valle montado: Bajo, Ultra y Medio dejan el entorno como dicen sin recargar la escena.
- [x] **5. `VentanaDeConfiguracion`.** Pantalla, Gráficos y Sonido; la cuenta
      atrás. *Toca `scripts/ui/VentanaDeConfiguracion.gd` (nueva),
      `TestConfiguracion.gd`. Prueba de la cuenta atrás con el reloj a mano.*
      Grande.
> **HECHO (2026-09-14).** `scripts/ui/VentanaDeConfiguracion.gd` con las tres pestañas; cada cambio se aplica y se guarda al momento; modo y resolución con la barra de confirmación y la cuenta atrás, llevada por `avanzar(segundos)`; cerrar sin confirmar vuelve atrás. Pruebas: sin confirmar vuelve a los 10 s y queda guardado lo de antes; confirmando se queda; elegir nivel fija y tocar un ajuste personaliza.
- [x] **6. Los dos botones, y aplicar al abrir.** *Toca `MenuPrincipal.gd`,
      `MenuDelJuego.gd`, `TestConfiguracion.gd`, `scripts/tests/ConfiguracionProbe.gd`
      (nueva). Prueba: los dos menús abren la misma ventana. Sonda de dos procesos:
      se escribe, se arranca y se mira el motor. ~1 min.* Media.
> **HECHO (2026-09-14).** Botón **Configuración** en los dos menús, con `abrir_configuracion` en cada uno; `MenuPrincipal._ready` carga y aplica la configuración una vez por proceso. Prueba: los dos menús abren la misma ventana, control a control. `ConfiguracionProbe`, dos procesos: **TODO BIEN** —ventana 1280×720, sin sincronizar, tope 30, Bajo—.
- [x] **7. Que nada se salga.** Captura de la ventana a 1920×1080 y 1280×720.
      *~3 min.* Pequeña.
> **HECHO (2026-09-14).** `ConfiguracionCaptura`: las tres pestañas a 1920×1080 y 1280×720, nada se sale; capturas miradas, y de mirarlas salió ensanchar la columna de rótulos, que descuadraba el interruptor del ORM.
- [x] **8. Documentar.** INTERFAZ §8 y §7.5, GRAFICOS §7 con la tabla completa y
      el coste de cada nivel, SPECS §2.2, ESTADO con la suite.
> **HECHO (2026-09-14).** INTERFAZ §8.6, GRAFICOS §1 y §7 —«objetivo Alto = 1070» corregido a Medio, y la tabla de lo que se aplica con su coste—, SPECS §2.2, ESTADO §3 con **1 397 pruebas y 7 798 comprobaciones**, `llamadas huerfanas: 0`.

### ~~Explorar hacia un rumbo, y la niebla del mapa regional~~ — cerrado (2026-09-14)

Las catorce tareas hechas y en verde: **1 381 pruebas y 7 680 comprobaciones** —del
suelo de 1 352 y 7 590—, `llamadas huerfanas: 0`, `NieblaCaptura` sin nada que se
salga. Lo aprendido fue a [SISTEMAS.md](SISTEMAS.md) §4 («Cómo quedó», con la
deuda: la niebla del pasillo se levanta entera al volver, y tras cerrar el juego
no se manda desde el regional hasta entrar en el mapa de la banda),
[GRAFICOS.md](GRAFICOS.md) §3, [INTERFAZ.md](INTERFAZ.md) §4, [SPECS.md](SPECS.md)
§2.2, §3.1 y §4, EPOCA_01 y [ESTADO.md](ESTADO.md) §3. **Un aviso de balance**: con
el andar de siempre la ida avanza ~22 km por jornada, y las salidas largas llegan
casi siempre a la costa o al borde de la comarca.

Spec y **plan técnico** en [SISTEMAS.md](SISTEMAS.md) §4 («Spec (2026-09-14):
explorar hacia un rumbo…» y «Plan técnico: rumbo y niebla»); cómo se ve, en
[GRAFICOS.md](GRAFICOS.md) §3; cómo se elige, en [INTERFAZ.md](INTERFAZ.md) §4.

- [x] **1. `NieblaRegional`.** Rejilla sobre el relieve regional con las capas
      *vista* y *recorrida*, levantar rectángulo, círculo y pasillo por exceso,
      fracción levantada, datos. `GameState.niebla`. *Toca
      `scripts/region/NieblaRegional.gd` (nuevo), `GameState.gd`,
      `scripts/tests/TestNiebla.gd` (nueva), `RunTests.gd`. Pruebas de forma y de
      fracción.* Media.
> **HECHO (2026-09-14).** `scripts/region/NieblaRegional.gd` sobre la rejilla del relieve regional (1 792 × 1 280 celdas de 111 m, filas Mercator), un byte por celda con `VISTA` y `RECORRIDA`, levantar por exceso con una forma cualquiera (recuadro y círculo hechos), fracción, imagen L8 y guardado comprimido que se suma. `GameState.niebla`. **La prueba nueva es `TestNieblaRegional`**: `TestNiebla` ya existía —los alfileres de la niebla de antes— y lo pisé al escribirlo; se recuperó de git y el total lo confirma, 7 590 + 23.
- [x] **2. `Pasillo`.** Origen, rumbo y jornadas → el pasillo, con el largo y el
      ancho que se decidan, y `contiene`. *Toca `scripts/sim/Pasillo.gd` (nuevo),
      `TestNiebla.gd`. Pruebas: catálogo a mano a los dos lados, rumbos opuestos
      disjuntos.* Media.
> **HECHO (2026-09-14).** `scripts/sim/Pasillo.gd`: se anda por el rumbo a tramos de 250 m con `Viaje.andar_un_tramo` —la cuenta de tramo salió de `Viaje.camino` para que sea una sola— hasta gastar las horas de media salida; `contiene` y `levantar_en` preguntan la misma `distancia_m`. **Dos sorpresas**: el pasillo **cruzaba el mar** hasta el filo del relieve —ahora se para en la costa de la época—, y un punto justo en el borde caía en una celda sin levantar por 0,3 m de descuadre de cosenos —`NieblaRegional.HOLGURA_M`, 1 m—. **Y una cifra para mirar**: con el andar de siempre, cuatro jornadas de ida son ~100 km en llano (4,5 km/h × 11 h): las salidas largas acaban casi siempre en la costa o en el borde. Pruebas: catálogo a mano a los dos lados, rumbos opuestos, costa, montaña, y la niebla levantada = el pasillo.
- [x] **3. Levantar la niebla por la barrera.** Cola en `SettlementSim`, el reloj
      la junta y descubre los sitios de dentro; el recuadro del primer campamento
      al empezar, el de cada campamento al darse de alta y el del mapa visitado.
      *Toca `SettlementSim.gd`, `RelojDeLaPartida.gd`, `Campamentos.gd`,
      `GameState.gd`, `DemoMain.gd`, `TestNiebla.gd`, `TestReloj.gd`. Prueba: al
      empezar, la fracción es la del recuadro.* Media.
> **HECHO (2026-09-14).** `GameState.levantar_niebla(forma)` levanta un recuadro, un círculo o un pasillo **y descubre los sitios de dentro** —una regla: lo que se ve se descubre—. Dentro del paso va a `SettlementSim.niebla_por_levantar` (formas en diccionario, no funciones, para que la instantánea las recorra) y el reloj las levanta en la barrera tras lo descubierto. El recuadro se levanta en `GameState.begin`, en `Campamentos.alta` y al montar una visita. `TestNiebla` cambió de premisa y lo dice: al empezar ya no se conoce **una** cueva sino **los sitios de su recuadro**. Pruebas en `TestNieblaRegional`: al empezar, las celdas exactas del recuadro; la dirigida espera a la barrera; se descubre justo lo de dentro y nada queda bajo niebla.
- [x] **4. La expedición con rumbo y jornadas.** `mandar_a(quienes, rumbo,
      jornadas)`, coste con las jornadas, puerta por rumbo, y al volver el
      pasillo: sitios, contacto y niebla —vista y recorrida—. Fuera
      `destino_de_hoy` y los cuatro vecinos. *Toca `Expedicion.gd`,
      `TestExpedicion.gd`, `TestHerido.gd`, `TestGuardado.gd`. Pruebas: sólo y
      todos los del pasillo, contacto, en invierno sale.* Grande.
> **HECHO (2026-09-14), junto con la 5** —quitar la tarjeta y cambiar la salida son el mismo cambio—. `Expedicion` reescrita: `mandar_a(quienes, rumbo, jornadas)` y `mandar(cuantos, rumbo, jornadas)`, `puede_ir` público para la ficha, `pasillo_hacia` —el que enseñará la flecha—, el pasillo trazado **al salir** y guardado en la simulación, y al volver: los sitios de dentro contados, la niebla vista y recorrida por la barrera, y contacto con los ocupados; la primera, en el sitio más lejano del pasillo. Fuera `destino_de_hoy`, los cuatro vecinos, `sitios` y `JORNADAS_FUERA` (queda `JORNADAS_PROPUESTAS` = 12 para la ficha). La simulación sabe su sitio (`SettlementSim.sitio`, lo pone `Campamento`). `TestExpedicion` rehecha contra sitios reales: sólo y todos los del pasillo, rumbos opuestos, lo conocido no cuenta dos veces, contacto, el más lejano, jornadas elegidas y en invierno sale. **De paso salió una prueba frágil**: `TestIntercambio` dependía del año global que dejaba cambiado `TestDecisiones`; ahora fija su fecha.
- [x] **5. Sin tarjeta de primavera.** *Toca `SettlementSim.gd`,
      `TestDecisiones.gd`, `PanelProbe.gd`, `AnoProbe.gd`, `ExpedicionProbe.gd`,
      `docs/EPOCA_01_PALEOLITICO.md`. Prueba: la primavera no levanta decisión.*
      Pequeña.
> **HECHO (2026-09-14)**, con la 4. `_decision_de_la_estacion` ya no tiene primavera, `Moment.Kind.EXPEDICION` se quitó —nadie la levantaba—, y `TestDecisiones` prueba ahora que la primavera no pide nada y que al año salen **tres**; las pruebas de la cita y del cierre de jornada pasan a mirar la del verano. EPOCA_01 tachada con fecha. `AnoProbe` y `ExpedicionProbe` al día (esta última, hacia el rumbo de un sitio con gente).
- [x] **6. La cumbre ve fuera del recuadro.** `TerrainGenerator.world_to_geo` y
      el círculo de `ASCENT_SIGHT_RANGE`. *Toca `TerrainGenerator.gd`,
      `Cumbres.gd`, `TestNiebla.gd`. Prueba: una cumbre junto al borde levanta
      niebla fuera.* Pequeña.
> **HECHO (2026-09-14).** `TerrainGenerator.world_to_geo`, el inverso de `geo_to_world`, con la latitud por bisección en `HeightmapData.lat_for_v` —que usa también `NieblaRegional`, una sola copia—. `Cumbres._do_ascent` levanta un círculo de `ASCENT_SIGHT_RANGE` por la barrera. Pruebas: ida y vuelta mundo↔comarca (a 1,7 cm) y una cumbre a 96 m del borde este del sitio 56 levanta niebla a 1 km fuera del recuadro y no a 2,5 km.
- [x] **7. Guardar la niebla.** *Toca `Guardado.gd`, `TestGuardado.gd`. Prueba de
      ida y vuelta sobre la máscara, sumada al cargar.* Pequeña.
> **HECHO (2026-09-14).** En la cabecera de cada `sitio_<n>.sav`, comprimida con zstd, y `Guardado.preparar_la_escena` la **suma** como suma lo descubierto. Prueba de ida y vuelta con las dos capas y una niebla de sesión que no se pierde. **Un tropiezo**: un fallo de parseo en la prueba colgó la suite diez minutos sin salida —la lección de siempre: Godot con `timeout`—.
- [x] **8. La niebla que se ve en el regional.** Calima, trazo de costa, borde
      fundido; el agua y la frontera, debajo. *Toca `shaders/triplanar.gdshader`,
      `TerrainMaterialManager.gd`, `TerrainGenerator.gd`, `RegionMap.gd`.
      Captura.* Grande.
> **HECHO (2026-09-14).** En `triplanar.gdshader`, un bloque `fog` apagado en el valle: calima clara con el borde fundido en cinco muestras a 300 m, trazo de costa del mismo grueso en pantalla a cualquier pendiente (`fwidth` de la cota contra el mar de la época) y, bajo la niebla, la normal mirando al cielo para que la luz no dibuje laderas. El mar y la frontera, que son mallas aparte, con `shaders/bajo_la_niebla.gdshader`: el mar se tapa y la frontera se borra. `RegionMap._poner_la_niebla` hace la textura de `NieblaRegional` —que lleva su imagen L8 al día al levantar, para no recorrer 2,3 M de celdas por jornada— y la rehace si cambia con el mapa abierto. **Visto con `NieblaCaptura`** (ventana, 1080p): al empezar sólo el recuadro (1 482 celdas) y la costa intuida; tras un pasillo de 12 jornadas al este, 130,8 km de ida con 11 sitios. **Coste de GPU a 1920×1080, alternando en la misma corrida: −0,02 ms**, dentro del presupuesto de 1 ms.
- [x] **9. Bajo la niebla no se elige nada.** El regional y las listas sólo con lo
      descubierto, comprobado contra la máscara. *Toca `RegionMap.gd`,
      `PanelSitios.gd` si hace falta, `TestNiebla.gd`. Prueba.* Pequeña.
> **HECHO (2026-09-14).** Una pregunta, un sitio: `GameState.se_ve(site)` —descubierto y fuera de la niebla—, que usan el mapa regional (lista, alfileres y selección) y los destinos de la ficha de mover gente. **Y la compatibilidad que salió al pensarlo**: un guardado de antes de la niebla trae descubiertos sin niebla, y al abrirlo quedaban todos tapados; `Guardado.preparar_la_escena` levanta el recuadro de cada uno. Pruebas: descubierto bajo la niebla no se ve; el mapa y la ficha preguntan `se_ve`; un guardado sin niebla ve lo que conocía.
- [x] **10. Mandar desde el mapa regional.** Pinchar el rumbo desde un
      campamento, flecha con el pasillo, ficha de quién y cuántas jornadas con lo
      que cuesta. *Toca `RegionMap.gd`, `scripts/ui/FichaDeRumbo.gd` (nueva),
      `scripts/vista/FlechaDeRumbo.gd` (nueva). Prueba: la máscara de la flecha es
      la del pasillo.* Grande.
> **HECHO (2026-09-14).** Tecla **R** en el mapa regional: se apunta desde el campamento seleccionado —o el primero—, el clic da el rumbo (contra el plano de la cota del campamento, que el regional no tiene colisión) y se abren `scripts/ui/FichaDeRumbo.gd` —quién puede ir, jornadas de 4 a 24, lo que se llevan y por qué no se puede, sin contar nada por su cuenta— y `scripts/vista/FlechaDeRumbo.gd`, que dibuja **el mismo `Pasillo`** de la ficha: franja, eje y punta. **La prueba del criterio** (`TestNieblaRegional`): la niebla que levanta el pasillo de la flecha y la del pasillo que guarda la expedición mandada desde la ficha son **iguales celda a celda**; y la ficha dice «hacen falta» y «pieles» cuando toca.
- [x] **11. Mandar desde el borde del valle.** El mismo rumbo pinchando en el
      valle, la misma ficha. *Toca `DemoMain.gd`, `GameUI.gd`, `FichaDeRumbo.gd`,
      `FlechaDeRumbo.gd`.* Media.
> **HECHO (2026-09-14).** Botón **Rumbo** bajo el de la comarca, en el minimapa —la tecla R ya era la capa del minimapa, y la barra de abajo no cabe a 1280×720—; el clic en el valle da el rumbo desde la cueva, la misma `FichaDeRumbo`, y la flecha va de la cueva a la puerta del valle por la que saldrían (`FlechaDeRumbo.trazar_rumbo`), porque el pasillo no cabe en el valle. ESC la cierra. Visto en la captura de la tarea 13.
- [x] **12. La visita, en niebla.** Minimapa con sólo lo recorrido por
      expediciones, y las cuevas de dentro con alfiler. *Toca `Minimapa.gd`,
      `DemoMain.gd`. Sonda de escena.* Media.
> **HECHO (2026-09-14), con una prueba en vez de la sonda de escena prevista**: `Campamento.ver_lo_recorrido(niebla)` marca explorado en el conocimiento del mapa lo que cubre la capa recorrida y descubre las cuevas de dentro; `DemoMain._montar_la_visita` lo llama. La prueba monta el relieve del sitio 56 sin escena: visto donde pasó una expedición, y no donde no, aunque el mapa visitado tenga su vista entera.
- [x] **13. Capturas y coste.** Regional al empezar y tras una expedición, la
      ficha a 1920×1080 y 1280×720, y GPU a 1080p con niebla sí y no. *Sonda con
      ventana, ~8 min.* Media.
> **HECHO (2026-09-14).** `scripts/tests/NieblaCaptura.gd`, con ventana a 1080p: al empezar sólo el recuadro (1 482 celdas) y el trazo de costa; tras un pasillo de 12 jornadas al este, 130,8 km y 11 sitios; **GPU con niebla sí y no en la misma corrida: entre −0,02 y +0,24 ms en cinco corridas**, dentro de 1 ms; y la ficha de rumbo en el regional y en el valle, **nada se sale a 1920×1080 ni a 1280×720** y la flecha dibujada. Costó tres corridas más de las previstas: la ficha a una altura fija se salía por abajo a 1280×720, anclada al centro se iba por arriba, y la sonda medía con el escalado de contenido puesto —la receta de `PrioridadesCaptura`: abrir a cada resolución y desactivarlo cada vez—.
- [x] **14. Documentar.** SISTEMAS §4, EPOCA_01 (las decisiones del año),
      GRAFICOS §3, INTERFAZ §4, SPECS §2.2 y §4, ESTADO con el coste y la suite.
> **HECHO (2026-09-14).** SISTEMAS §4 («Cómo quedó: rumbo y niebla», con lo medido y la deuda), EPOCA_01 (la primavera tachada), GRAFICOS §3 (la niebla construida y su coste), INTERFAZ §4 («Lo construido: el rumbo de la expedición»), SPECS §2.2, §3.1 y §4 (`GameState.niebla`, la niebla por la barrera, lo que se cablea a la expedición), ESTADO §3 con **1 381 pruebas y 7 680 comprobaciones**, `llamadas huerfanas: 0`.

### ~~Varios campamentos, migrar, y la partida que no se mira~~ — cerrado (2026-09-14)

Las cuatro fases hechas y en verde: **1 352 pruebas y 7 590 comprobaciones**
—del suelo de 1 316 y 7 481—, `llamadas huerfanas: 0`, `MigracionProbe` y
`CampamentosCaptura` TODO BIEN. Lo aprendido fue a [SISTEMAS.md](SISTEMAS.md) §23
(«Cómo quedó», con la deuda: se sale sin andar hasta el borde, fundar bloquea el
fotograma, los campamentos vuelven al entrar en el mapa de la banda y no al abrir
el regional, y el regional no enseña la decisión pendiente), [SPECS.md](SPECS.md)
§3.1, §6.4 y §7, [INTERFAZ.md](INTERFAZ.md) §4 y [ESTADO.md](ESTADO.md) §2 y §3.
**Y un fallo ajeno**: la barra de botones de abajo se sale a 1280×720, para
`/depurar` con el de la barra superior.

Spec en [SISTEMAS.md](SISTEMAS.md) §23, con su **plan técnico** debajo; contrato
en [SPECS.md](SPECS.md) §6.4; ventanas en [INTERFAZ.md](INTERFAZ.md) §4 («Los
campamentos»). Cuatro fases, y **la primera es una puerta**: si un campamento
sin mirar no cabe, se para y se pregunta antes de construir nada encima.

**Fase 1 — ¿cabe?**

- [x] **1. La firma de antes.** Diez jornadas con `TironAnualProbe` y la semilla
      de sonda sobre el árbol de hoy, sin tocar un `.gd`, y el suelo de la suite.
      *Sonda, ~8 min.*
> **HECHO (2026-09-14), sin gastar la corrida.** Ya existía: la de `TironAnualProbe`, 10 jornadas, que se tomó al cerrar §22 sobre este mismo árbol —desde entonces sólo cambió un fichero de pruebas—. El suelo, el de aquel cierre: **1 316 pruebas y 7 481 comprobaciones**.
- [x] **2. `Campamento`: el mapa con gente, sin la vista.** Sacar de
      `DemoMain._start_settlement` el montaje de terreno, campo, fauna, cuevas y
      simulación a `scripts/sim/Campamento.gd`; `DemoMain` lo construye y lo mira.
      *Toca `scripts/sim/Campamento.gd` (nuevo), `scripts/DemoMain.gd`. Se
      comprueba con la suite y, en la corrida A de la tarea 6, con la firma de la
      tarea 1: tiene que ser la misma partida.* Grande.
> **HECHO (2026-09-14).** `scripts/sim/Campamento.gd` monta relieve, bocas, cuevas, simulación, comarca, conocimiento, cueva de casa, fauna y técnica, y elige los tajos; `DemoMain` le llama **en el mismo orden de antes** e intercala sus vistas, y guarda `terrain`, `sim`, `herds`… como referencias al campamento. Comprobado con `TironAnualProbe` 10 jornadas contra la tarea 1: **`Cotejo` da IGUALES las diez firmas**, sin un campo distinto —el orden de los objetos de la instantánea no se movió—. Suite 1 316 / 7 481 y `llamadas huerfanas: 0`. Doce sondas buscaban el terreno como hijo directo de la escena (`_first(demo, "TerrainGenerator")`) y pasaron a `demo.terrain`; en diez el ayudante quedó muerto y se borró. **Un error anterior a esto sale en la suite**: `TestTaller.test_la_partida_nueva_arranca_con_los_topes_puestos` llama a `setup` sin terreno y revienta en `SettlementSim.gd:1285` —no baja el total, así que ya pasaba antes—; queda apuntado.
- [x] **3. La partida que la escena todavía decide, al campamento.** Descubrir
      cuevas, contar técnicas y reelegir tajos al trasladarse. *Toca
      `Campamento.gd`, `DemoMain.gd`. Prueba: una cueva se descubre y se apunta
      en la crónica sin escena montada.* Media.
> **HECHO dentro de la 2 (2026-09-14).** Mudarlas fue parte de sacar el campamento, y la firma igual de la tarea 2 las cubre: descubrir cuevas cada hora (`revisar_hallazgos`), contar la técnica (`tell_technique`), reelegir tajos al trasladarse… **y una cuarta que el plan no había visto**: `_on_dia_para_el_paisaje` fijaba el **caudal del río** junto con la nieve y el color del pasto. El caudal decide qué se vadea, así que va al campamento (`_on_dia_para_el_rio`); la nieve, el color y el bosque se quedan en la vista. La prueba de «una cueva se descubre sin escena» va con las del reloj, que ya montan campamentos sin escena.
- [x] **4. `RelojDeLaPartida`: una sola fecha.** Pasos iguales a todos los
      campamentos, `time_scale` y pausa de todos, noche acelerada sólo si no
      trabaja nadie en ninguno, y estación y año girados una vez. *Toca
      `scripts/sim/RelojDeLaPartida.gd` (nuevo), `scripts/sim/SettlementSim.gd`,
      `scripts/tests/TestReloj.gd` (nuevo). Pruebas: la fecha es una tras 5
      jornadas; la noche con uno dormido y otro trabajando; la primavera llega
      una vez con dos campamentos.* Grande.
> **HECHO (2026-09-14).** `scripts/sim/RelojDeLaPartida.gd` da los pasos a todas las simulaciones dirigidas —mismo `PASO_FIJO`, mismo tope, misma noche con el mismo presupuesto—, una a una y en orden; `SettlementSim.dirigido` hace que una simulación deje de darlos en su `_process`, y `gira_la_estacion` que sólo la primera gire `GameState.season` y `year`. **La pausa no la lleva nadie aparte**: la interfaz y las decisiones siguen tocando la `time_scale` de UNA simulación, y el reloj adopta como de todas lo que cambie en cualquiera. Ocho pruebas en `TestReloj`. **Dos premisas caídas por el camino**: (1) la prueba de la noche daba pasos con alguien «trabajando» a la una de la madrugada, y esa persona se acostaba en el primer tick —lo que hace la banda—; se comprueba la decisión del reloj, no los pasos. (2) **Un campamento que se suma con la partida en pausa traía velocidad 1 y el reloj la habría adoptado, despausando a todos**; lo cazó diseñar la sonda, no una prueba, y ahora `dirigir` le da la velocidad de la partida, con su prueba. Suite **1 324 / 7 498** y `llamadas huerfanas: 0`. Sin reloj —una simulación sola— nada cambia: las dos marcas valen por defecto lo de siempre.
- [x] **5. `Campamentos`: vivos fuera de la escena.** El registro estático y los
      nodos colgados de la raíz; `DemoMain` mira uno y al volver al regional no
      destruye nada. *Toca `scripts/region/Campamentos.gd` (nuevo), `DemoMain.gd`,
      `RegionMap.gd`. Prueba: dos campamentos, se cambia de escena y los dos
      siguen avanzando.* Media.
> **HECHO en parte (2026-09-14).** `scripts/region/Campamentos.gd`: el registro estático y los nodos —campamentos y reloj— colgados de la raíz. **Comprobado en `CampamentosProbe`, no en una prueba**: en la suite no hay árbol (`Engine.get_main_loop()` es nulo mientras corre `RunTests`), y la prueba que lo intentó «pasaba» sin llegar a su primer `assert` —lo delató el total de comprobaciones, que no subió—. En la sonda, con dos y con tres campamentos, **todos siguen en el árbol y avanzando tras cambiar a una escena vacía**. **Lo que queda de la tarea para la 14**: que `DemoMain` mire un campamento ya montado en vez de montar el suyo como hijo, que es lo que hace falta para entrar en uno desde el regional.
- [x] **6. LA PUERTA: la sonda de cotejo y coste.** `CampamentosProbe`, tres
      corridas: **A**, un campamento mirado 10 jornadas —firma contra la tarea 1,
      cierra la 2, y coste con 1—; **B**, dos campamentos mirando el otro 10
      jornadas —firma del primero contra A, que es el criterio de «lo que no se
      mira es la misma partida», y coste con 2—; **C**, cuatro campamentos 3
      jornadas —coste con 4, RAM y lo que tarda montar uno—. *Toca
      `scripts/tests/CampamentosProbe.gd` (nuevo), `docs/ESTADO.md`. ~30 min.*
      **Se para y se enseñan las cifras.**

> **HECHO (2026-09-14). La partida es la misma; la CPU no cabe.** `scripts/tests/CampamentosProbe.gd` monta campamentos sin vista llevados por el reloj.
>
> **Firma**: con uno solo y con dos a la vez, **las diez firmas del sitio 56 salen IGUALES** a las del mismo campamento mirado con la escena (`TironAnualProbe`). Llegar ahí costó cuatro corridas, y cada una destapó algo: (1) la sonda no repartía el trabajo como `TironAnualProbe` (`assign_default_jobs`) ni tomaba la firma en `paso_cerrado` —el instrumento, y explica también el desvío que en §22 se atribuyó «al instrumento» sin saber por qué—; (2) **el reloj despausaba el arranque**: `setup` deja la simulación parada y el primer `dirigir` le ponía velocidad 1; (3) **la vista decidía partida**: `Cumbres._find_peaks` apunta en la crónica la primera vez que se llama, y quien lo llamaba era el alfiler de cima. Las tres arregladas donde estaban, y `dirigido`/`gira_la_estacion` fuera de la firma.
>
> **Coste** (ESTADO §2): memoria ~130 MB por campamento, que cabe; pero **a ×5 la máquina llega con uno (16,8 s por jornada) y no con dos (27,2 s, fotograma medio de 160 ms) ni con tres (55,1 s, 389 ms)**, sin dibujar. Montar sin caché, 17 s. **Son tres y no cuatro**: el sitio 9000 no tiene ficha en la comarca. **Y las cifras de reloj no son firmes al factor**: parte de las corridas se hicieron con el editor del usuario abierto. **Se para aquí, como se decidió.**
>
> **Y después, por decisión del usuario, se midió dónde se va el paso** (cepo, ESTADO §2): un campamento es una simulación entera y la simulación usa un núcleo —18 ms por paso el 56, ~32 el 14, y a ×5 hacen falta 30 pasos por segundo—. Se quitaron las dos cosas que sobraban sin tocar reglas —recordar si la casa está junto al agua (`Hogar._home_by_water`) y no pintar cuerpos donde no se mira (`SettlementSim.se_mira`)—: **el paso baja un 8 %, la firma sigue IGUAL, y dos campamentos siguen sin caber a ×5**. La hipótesis del agua era medio falsa: lo caro no era la pregunta por la casa sino la de cada persona, que no se puede recordar sin cambiar la regla. Suite 1 325 / 7 500, `llamadas huerfanas: 0`.
**Fase 1b — un hilo por campamento** (decisión del usuario tras la puerta; plan
en SISTEMAS §23, «Plan técnico: un hilo por campamento»)

- [x] **1b-1. La estación y el año, por campamento.** `sim.estacion` y `sim.anyo`
      en lugar de leer `GameState` dentro del paso (76 sitios); el reloj publica
      la del primero entre pasos. *Toca `SettlementSim.gd` y los ficheros de
      `sim/`, `banda/`, `economia/` que leen la estación; `RelojDeLaPartida.gd`;
      `TestReloj.gd`. Prueba de la estación con dos, y cotejo de un campamento
      10 jornadas contra la firma de la fase 1.* Grande y mecánica.
> **HECHO (2026-09-14), con un cambio de diseño que quita riesgo.** No se tocaron los 52 sitios de 10 pruebas que fijan `GameState.season`: **sólo una simulación DIRIGIDA lleva su copia** (`sim.estacion`/`sim.anyo` son propiedades que leen `_estacion` si está dirigida y la global si va suelta), así que las pruebas, las sondas y la escena de un mapa no cambian. El reloj copia la fecha al dirigir; el primer campamento sigue publicando la global **en el mismo instante del giro**, para que quien la lea dentro del paso vea lo de siempre. `Parajes` lee la de su campamento por una referencia (`fecha`); `Huella` y los dos ayudantes estáticos de nombres siguen con la global —sin carrera, porque sólo cambia en el giro del primero—, y se dice. Prueba nueva: **una dirigida y una suelta cruzan el cambio de estación con la misma firma**. Por el camino, un fallo mío que dejó la suite en rojo: la sustitución automática convirtió el `GameState.season` del propio getter en `estacion`, y un getter que se lee a sí mismo devuelve el valor de respaldo sin avisar —primavera siempre—. Cotejo de un campamento 10 jornadas: **el resumen, igual**; los tres campos del detalle eran esas mismas propiedades, que ahora no entran en la firma.
- [x] **1b-2. El presupuesto de caminos sin estático.** `Wayfinder.find` devuelve
      los nodos que ha mirado y `Marcha` los suma. *Toca `mundo/Wayfinder.gd`,
      `sim/Marcha.gd`. Suite y el mismo cotejo.* Pequeña.
> **HECHO (2026-09-14).** `Wayfinder.find` apunta sus nodos en un `Array` que le pasa quien la lanza, y `Marcha` suma ése. `last_nodes` se queda, **sólo para las sondas y las pruebas** que lo miran: ya no decide nada. Cubierto por el mismo cotejo.
- [x] **1b-3. Lo que el paso manda fuera, en cola.** Descubrir (`GameState.discover`),
      `last_report`, y lo que toque el árbol al nacer la fauna; el cepo no cuenta
      fuera del hilo principal. *Toca `Expedicion.gd`, `SettlementSim.gd`,
      `WildlifeHerds.gd`, `tools/Cronometro.gd`, `RelojDeLaPartida.gd`. Suite y
      cotejo.* Media.
> **HECHO en parte (2026-09-14).** Descubrir la comarca: una dirigida lo apunta en `sim.descubrimientos` —y lo cuenta al preguntar— y el reloj lo junta en `GameState` en la barrera, en orden de campamento; una suelta escribe al momento. `last_report` lo escribe sólo quien publica la fecha. El cepo no cuenta fuera del hilo principal. **Queda para la 1b-5**: la malla de la fauna al nacer (`_spawn` toca `instance_count` de un `MultiMesh`), que en serie no tiene carrera. Lo descubierto no entra en la firma —sólo estación y año de las estáticas—, así que la cola no la mueve. Cubierto por el mismo cotejo.
- [x] **1b-4. Las decisiones y la vista, en la barrera.** Las decisiones se
      encolan por campamento y se entregan entre pasos en orden; las señales de
      vista, diferidas. **Cambia el instrumento**: se toma de nuevo la firma de
      referencia de un campamento con contestación en la barrera. *Toca
      `BarraSuperior.gd`, `DemoMain.gd`, `CampamentosProbe.gd`,
      `RelojDeLaPartida.gd`. Sonda, ~10 min.* Media.
> **HECHO lo de las decisiones (2026-09-14).** `SettlementSim.raise_moment`: dentro del paso de un campamento dirigido se guarda (`momentos_pendientes`) y el reloj la entrega en la barrera, detrás de lo descubierto; fuera de un paso —el arranque, un clic— sale al momento. Dos pruebas. **Las señales de vista diferidas no se hicieron**: sólo importan cuando la escena mire un campamento dirigido, que es la tarea 14, o con hilos (1b-5). **La firma de referencia nueva, un campamento 10 jornadas con las decisiones en la barrera, sale IGUAL a la original** —y con ello quedan comprobados también la 1b-1 a la 1b-3 sin los getters en la firma—. Dicho con precisión: en esas diez jornadas no se levanta ninguna decisión dentro de un paso, así que esto prueba que no se rompió nada, no que contestar en la barrera dé siempre lo mismo; eso sólo se nota al cambiar de estación o al volver una expedición. Suite **1 328 / 7 508**, `llamadas huerfanas: 0`. **Se para aquí, como se decidió**: quedan la 1b-5 (hilos), la 1b-6 (carreras y ganancia) y la 1b-7.
- [x] **1b-5. El reloj en paralelo, con interruptor.** `WorkerThreadPool` por paso
      y barrera; en serie con `PARALELO=0`. *Toca `RelojDeLaPartida.gd`,
      `CampamentosProbe.gd`.* Media.
> **HECHO (2026-09-14), y la primera versión no valía.** `RelojDeLaPartida` da el paso de cada campamento en un hilo del `WorkerThreadPool` (`paralelo`, y `PARALELO=0` en la sonda), espera a todos, emite `pasos_cerrados` y cierra la barrera; el paso que cruza medianoche va en serie. **Primera corrida: basura** —46 000 errores de Godot en diez jornadas, alturas por defecto y ni una firma—, porque Godot no deja tocar un nodo del árbol desde otro hilo y el paso lo tocaba (`get_height_at` leía `global_position`; la simulación emitía señales). Era el riesgo escrito en el plan, y se aplicó la salida escrita: **los campamentos que no se miran salen del árbol** (`Campamentos.dejar_de_mirar`), el reloj les amasa el horno, el relieve lee su origen local fuera del árbol (`TerrainGenerator._origen`), el que se mira da su paso en el hilo principal, y el alfiler de una cueva se enciende diferido. Dos pruebas nuevas en `TestReloj`. Suite **1 334 / 7 519**.
- [x] **1b-6. Que no haya carreras, y lo que se gana.** Dos campamentos 10
      jornadas: en serie, y **dos veces** en paralelo; las tres firmas del primero
      iguales. Y el coste con 1, 2 y 3 en paralelo. *Toca `docs/ESTADO.md`. Tres
      corridas de ~15 min y una de ~5: ~50 min.*
> **HECHO (2026-09-14): sin carreras, bit a bit, y con ganancia.** La sonda firma ya **todos** los campamentos, en la barrera. Dos corridas en paralelo dieron firmas idénticas entre sí —no hay carreras—, y el campamento 1 igual en serie, en paralelo y contra la referencia; **pero el campamento 2 difería de la serie en la última cifra de un parte de atasco**. Se volcaron los partes: el campo `paso`, 0,697663867237661**4** contra …**7**. **La causa, medida en segundos: `exp` y `pow` de la librería no dan el mismo último bit en el hilo principal que en el pool** (15 % y 5 % de 60 000 valores), mientras que sumar, multiplicar, `floor`, `log`, `sqrt`, `sin` y `atan2` coinciden y los hilos del pool coinciden entre sí. **Decisión del usuario**: `exp` y `pow` propios (`mundo/Calculo.gd`) en los cinco sitios del paso —Tobler, la distancia de la presa, el vivac, el conchero y el lobo—, con su invariante comprobado en `TestCalculo`. Repetido: **dos campamentos, 10 jornadas, en serie y en paralelo, IGUALES los dos**. Coste en ESTADO §2. Por el camino: una prueba de `TestExploration` que fallaba según lo cargada que estuviera la máquina (la noche acelerada con la banda ociosa gasta 60 ms de reloj), anterior a esto, arreglada; y un error al cerrar la sonda (el reloj guardaba campamentos ya liberados), arreglado.
- [x] **1b-7. Documentar.** El contrato nuevo en SPECS §3 y su invariante en §7;
      SISTEMAS §23; ESTADO.

> **HECHO (2026-09-14).** SPECS §3.1 (los pasos en paralelo) y §7 (invariantes 8 —nada de `exp`/`pow` de la librería en el paso— y 9 —el paso de un campamento que no se mira no toca el árbol—); SISTEMAS §23; ESTADO §2 con el coste en paralelo; memoria de la trampa de la noche acelerada en las pruebas.
**Fase 2 — migrar**

- [x] **7. Cuánto se tarda.** Las jornadas de viaje entre dos sitios por
      distancia y relieve, con la regla que se decida. *Toca `Viaje.gd`. Prueba:
      dos destinos a distinta distancia tardan distinto.* Media.
> **HECHO (2026-09-14).** `Viaje.camino`: tramos de 250 m sobre el relieve regional (`data/dem/cantabria_region.res`) con el andar de Tobler de `Traversal.pace_fraction` y la carga, a 11 horas útiles por jornada. Prueba en `TestViaje` con el sitio más cercano y el más lejano **buscados, no escritos**: los tres con relieve horneado están a 2-3 km y caben en una jornada, que era la premisa rota de la primera versión de la prueba. Y el relieve alarga el viaje frente a la recta en llano.
- [x] **8. `Viaje`: salir y andar.** Quién sale, lo que carga (`Traslado._cargar`),
      la puerta del valle (`Expedicion.puerta_del_valle`), las raciones del
      origen por persona y jornada, y los percances del camino. *Toca
      `scripts/sim/Viaje.gd` (nuevo), `Campamentos.gd`, `scripts/tests/TestViaje.gd`
      (nuevo). Pruebas: raciones cobradas, llega con lo que cargó.* Grande.
> **HECHO (2026-09-14).** `Viaje.salir` cobra las raciones de todo el camino al salir, carga con `Traslado.cosas_en_orden_de_carga` y `SettlementSim.despedir` saca a cada uno. `Viaje.lo_que_cuesta` es la misma cuenta que se cobra —prueba de anunciado igual a cobrado—. Percances: **decisión del usuario, `Mishap.chance` con el suelo de cada jornada**, con su propio `_rng` sembrado por partida, jornada, destino e ids; **se llega herido, no se muere** (prueba construida con 60 jornadas de camino). Cambio de plan: **no se sale por `Expedicion.puerta_del_valle`** —la salida es inmediata—, queda como deuda.
- [x] **9. Llegar: fundar, reocupar o sumar.** *Toca `Viaje.gd`, `Campamentos.gd`,
      `Campamento.gd`. Tres pruebas; en la de reocupar, las obras y el almacén que
      se dejaron están.* Grande.
> **HECHO (2026-09-14).** `Campamentos.mandar` lleva los viajes, `_nueva_jornada` (colgada de `RelojDeLaPartida.jornada_cerrada`) los hace andar y `_llegar` suma, reocupa o funda; `SettlementSim.recibir` da ids nuevos de `relevo.id_libre()` y descarga en la despensa. Para fundar desde el juego, el montaje sin vista salió de `CampamentosProbe` a `Campamento.montar`. **Reocupar pone el campamento en la fecha de la partida** (`Campamentos.a_la_fecha`: jornada, hora y día de estación), que no estaba en el plan: sin eso giraría la estación en otra jornada. Y el valle de destino tiene que estar preparado al mandar —decisión del usuario—. Pruebas en `TestViaje`: sumar, reocupar con obras y almacén, reocupar en fecha, valle sin preparar. Fundar necesita relieve y árbol: lo mira la sonda de migración.
- [x] **10. El campamento vacío.** Queda abandonado, conserva su estado y no se
      simula. *Toca `Campamentos.gd`, `RelojDeLaPartida.gd`. Prueba: su jornada y
      su estado no cambian mientras está vacío.* Pequeña.
> **HECHO (2026-09-14).** El reloj ya no da pasos a quien no tiene gente; si todos van de viaje, `RelojDeLaPartida._andar_la_fecha_sola` lleva la fecha y gira la estación. Pruebas: jornada, hora y firma del vacío no cambian en 120 pasos, y la fecha sigue con todos de camino.
- [x] **11. Las decisiones de cualquier campamento.** Paran el reloj de todos y
      salen con el nombre del campamento; los avisos van a la crónica con él.
      *Toca `scripts/ui/BarraSuperior.gd`, `GameUI.gd`, `RelojDeLaPartida.gd`.
      Prueba.* Media.
> **HECHO (2026-09-14).** `Moment.desde` lo pone `raise_moment`; la tarjeta lleva el nombre si hay más de un campamento, y un aviso de uno que no se mira va a la crónica **del que se mira**, con el nombre delante —es la que el jugador lee—. `GameUI` escucha a los que hay y a los que se suman por `Campamentos.al_sumarse`. Parar a todos no hizo falta tocarlo: el reloj ya adopta la pausa de cualquier simulación. **Efecto a saber**: la firma cuenta las entradas de la crónica, así que la del campamento que se mira depende de los avisos de los otros —la crónica no la lee ninguna regla del juego—. Prueba en `TestReloj`.

**Fase 3 — guardar**

- [x] **12. Guardar y cargar con varios campamentos y viajes.** Un `sitio_<n>.sav`
      por campamento, y los viajes y la fecha en la cabecera; `Guardado.VERSION`
      sube y una partida de una banda se sigue abriendo. *Toca
      `scripts/region/Guardado.gd`, `Partidas.gd`, `TestGuardado.gd`. Prueba de
      ida y vuelta con dos campamentos y un grupo en camino.* Media-grande.
> **HECHO (2026-09-14).** `Guardado.VERSION` pasa a 2 y `VERSIONES_QUE_SE_LEEN` sigue abriendo la 1. `Guardado.guardar` guarda **la partida**: el campamento de la escena, los demás (`_guardar_los_demas`, cada uno con su relieve y su `orden` de paso) y `partida.sav` con la fecha del reloj y los viajes. `Guardado.retomar_los_demas` los monta sin mirar en el orden guardado y pone la fecha guardada al reloj. Los grupos de camino se guardan en una **instantánea de una simulación de paso** (`Viaje.a_datos`/`de_datos`): Instantanea recorre simulaciones y un grupo no está en ninguna. De paso salió que `Campamento.montar` **pisaba el traspaso de la escena** (`Expedition`): ahora lo devuelve como estaba y guarda el relieve en el campamento. Pruebas en `TestGuardado`: viaje con gente, herida, carga y azar; dos campamentos y un grupo con firma del otro igual; fichero de la versión 1. Montar desde disco necesita el árbol: lo mira la sonda de migración.

**Fase 4 — ventanas y visita**

- [x] **13. `PanelCampamentos`.** La lista —gente, jornada, alerta— con salto
      directo, y la ficha para migrar y mover gente que dice jornadas y raciones
      **antes** de confirmar, y son las que se cobran. *Toca
      `scripts/ui/PanelCampamentos.gd` (nuevo), `GameUI.gd`. Prueba de lo cobrado
      contra lo anunciado.* Grande.
> **HECHO (2026-09-14).** `scripts/ui/PanelCampamentos.gd` con su botón: la lista —gente y jornada o «abandonado», alerta de decisión pendiente o de hambre (`hambre_severa_racha`, la regla del juego), **Ir** y **Mover gente**, y los grupos de camino— y la ficha, que anuncia `Viaje.lo_que_cuesta` antes de **Mandar**. **Cambio de plan**: preparar el valle al mandar pedía la descarga del mapa regional, así que salió entera a `scripts/region/PreparaValle.gd`, que usan el mapa, la ficha y `RehacerSitio` —que ya no necesita levantar la escena regional—. `CampamentosCaptura` pulsa Mandar en la ventana montada: **jornadas y raciones cobradas = anunciadas** (1 jornada y 4 raciones de 56 a 14; la despensa baja 41 porque se llevan comida cargada).
- [x] **14. La visita con el reloj corriendo.** `RegionMap`, `Expedition.visita`
      y `DemoMain._montar_la_visita`. *Prueba: tras una visita, la fecha es la de
      todos.* Media.
> **HECHO (2026-09-14), y más grande que lo planeado**: sin esto nada de lo anterior se podía jugar. `DemoMain` **adopta** el campamento vivo del mapa en que entra en vez de montar otro, lo da de alta al empezar o retomar (y detrás `Guardado.retomar_los_demas`), y al irse guarda la partida y lo suelta (`_dejar_la_escena`) sin parar el reloj. Se entra desde el regional (`RegionMap._entrar_en_el_campamento`) o se salta desde la lista (`GameUI.ir_al_campamento`, `Campamentos.traspaso_de`). La visita, con campamentos vivos, la toma el reloj y copia su fecha. Una decisión con el jugador en el regional para la partida y sale al entrar (`Campamentos.sin_ver`). Otra partida o salir al menú sueltan los campamentos (`Campamentos.vaciar`). **`MigracionProbe`, escenas reales sin ventana: TODO BIEN en los 20 puntos y ni un error** —empezar, mandar, salir al regional, llegar y fundar en la fecha de todos, adoptar, saltar, visitar con el reloj corriendo, guardar, tirar y retomar los dos—. Fundar bloquea el fotograma: 16,6 s de relieve y 1,6 s de navegación medidos.
- [x] **15. Que nada se salga.** Captura de las ventanas nuevas a 1920×1080 y
      1280×720, con la receta de `PrioridadesCaptura` —ventana, y la interfaz
      montada a cada resolución—. *~3 min.* Pequeña.
> **HECHO (2026-09-14).** `CampamentosCaptura`: la lista y la ficha, **nada se sale** a 1920×1080 ni a 1280×720, capturas miradas —la ficha hace scroll a 1280×720—; salió y se corrigió «quedan 1 jornada». **Lo que se ve y no es de las ventanas**: la barra de botones de abajo ya se salía por la izquierda a 1280×720 y ahora lleva un botón más; va con el fallo de la barra superior, para `/depurar`.
- [x] **16. Documentar.** SISTEMAS §23, SPECS §2.2, §3.1 y §6.4 (el contrato que
      cambia), INTERFAZ §4 y §7.5, ESTADO con el coste y la suite.
> **HECHO (2026-09-14).** SISTEMAS §23 («Cómo quedó», con la deuda), SPECS §6.4 reescrito —dice qué decía antes—, INTERFAZ §4 («Lo construido: los campamentos») y §7.5, ESTADO §3 con **1 352 pruebas y 7 590 comprobaciones**, `llamadas huerfanas: 0`.

### ~~Priorizar materiales, presas y piezas, y la cola del taller~~ — cerrado (2026-09-14)

Las catorce tareas hechas y en verde: **1 316 pruebas y 7 481 comprobaciones**,
subiendo del suelo de 1 286 y 7 407, con `llamadas huerfanas: 0`. Lo aprendido
fue a [SISTEMAS.md](SISTEMAS.md) §22 («Cómo quedó»), [INTERFAZ.md](INTERFAZ.md)
§4, [SPECS.md](SPECS.md) §4.4 y §4.7, [ARQUITECTURA.md](ARQUITECTURA.md) §5.1 y
[ESTADO.md](ESTADO.md) §3. **Queda una sospecha sin medir** —si construir la
cola en cada consulta encarece el paso— y **un fallo ajeno a esta spec**: la
barra superior se sale de la pantalla al empequeñecer la ventana, para
`/depurar`.


Spec en [SISTEMAS.md](SISTEMAS.md) §22, con su **plan técnico** debajo; las
ventanas, en [INTERFAZ.md](INTERFAZ.md) §4 («Spec (2026-09-14)», los tres
primeros apartados: prioridades de material, de caza y la cola). Los campamentos
y el rumbo de esa misma spec **no son de este trabajo**.

- [x] **1. La firma de antes.** Diez jornadas con semilla fija sobre el árbol de
      hoy, guardadas a fichero. No toca ningún `.gd`: es la línea contra la que
      se comprueba «nada cambia sin tocar nada», y después de editar ya no se
      puede sacar. *Sonda, ~4 min.*
> **HECHO (2026-09-14).** Diez jornadas a `VEL=5` con `CEPO=0` y la semilla de sonda, con `TironAnualProbe FIRMAS=`. Tardó menos de lo presupuestado —los 4 min eran de sobra—. Se guardan fuera del repositorio, en el scratchpad de la sesión, y son la línea de la tarea 13. De paso quedó el suelo de la suite: **1 286 pruebas y 7 407 comprobaciones**.
- [x] **2. `Prioridades`, y dónde vive.** `scripts/sim/Prioridades.gd` nuevo
      —niveles de material, especie y pieza, todo normal por defecto— colgando de
      `SettlementSim.prioridades`, con la fachada que el jugador toca (cambiar un
      nivel de material reordena los sitios). *Toca: `scripts/sim/Prioridades.gd`,
      `scripts/sim/SettlementSim.gd`, `scripts/tests/TestPrioridades.gd`,
      `scripts/tests/RunTests.gd`. Prueba: por defecto normal, ida y vuelta, y
      que `LlamadasHuerfanas` siga en cero.*
> **HECHO (2026-09-14).** `scripts/sim/Prioridades.gd` con los tres niveles y `SettlementSim.prioridades`, más los tres pasamanos (`fijar_prioridad_material` reordena los parajes ahí mismo, que si no el clic no se notaría hasta el día siguiente). **Sólo se guarda lo que no es normal**, y `hay_algo_puesto()` es el interruptor por el que una partida sin tocar nada sigue el camino de antes. Sorpresa: un `class_name` nuevo no lo ve `--script` hasta reimportar el proyecto, y un fallo de parseo **cuelga** el SceneTree en vez de dar error —se destapó con `--check-only`, que es lo que hay que usar—.
- [x] **3. La presa.** `Caceria._pick_quarry`: fuera lo de nunca, gana el nivel
      más alto y dentro del nivel la cuenta de hoy. *Toca `scripts/sim/Caceria.gd`
      y `TestPrioridades.gd`. Prueba: uro en alta con ciervo más cerca y con más
      raciones; sin uro, el ciervo; ciervo en nunca y sólo ciervo, nada.*
> **HECHO (2026-09-14).** `Caceria._pick_quarry` lleva el nivel aparte de la puntuación, no multiplicándola: un uro en alta gana a un ciervo mejor puntuado, pero sin uro cerca se caza el ciervo. Prueba con la fauna puesta a mano. **La premisa del test estaba mal y el código no**: puse el uro a 120 m creyendo que ganaba el ciervo, y con 140 raciones contra 62 el uro gana hasta bien lejos —para que gane el ciervo tiene que estar diez veces más cerca—; las distancias del test salen ahora de esa cuenta.
- [x] **4. La carga.** `Tajo._fill_the_basket` por nivel, con lo de nunca fuera y
      descargando lo de nivel más bajo para hacer sitio. *Toca `scripts/sim/Tajo.gd`
      y `TestPrioridades.gd`. Prueba: avellana alta y baya normal sin sitio para
      las dos; y la baya en nunca.*
> **HECHO (2026-09-14).** `Tajo._por_prioridad` ordena el recorrido y `_soltar_lo_de_menos_nivel` hace sitio soltando lo de nivel inferior, que **vuelve al paraje** con `ResourceField.give_back_to_cell` (nueva). Sin prioridades puestas se devuelve la tabla tal cual: el camino de siempre, intacto. Otra premisa caída: la baya va la tercera de la tabla de forrajeo, así que sin tocar nada es de lo que menos entra —el test lo usa ahora al revés, poniéndola en alta—.
- [x] **5. El sitio.** El peso por nivel de lo sabido del paraje en
      `Tajo._rank_known_spots`. *Toca `scripts/sim/Tajo.gd` y `TestPrioridades.gd`.
      Prueba: dos parajes igual de lejos, sílex y cuarcita, con el sílex en alta y
      con los dos en normal.*
> **HECHO (2026-09-14).** `Tajo._peso_de_prioridad` multiplica la puntuación del paraje por `Σ abundancia × peso / Σ abundancia` sobre **lo que la banda sabe** que hay ahí; sin prioridades y en la caza devuelve 1. Prueba sobre parajes escritos a mano: el peso es la regla nueva, y el resto de la puntuación ya estaba probado.
- [x] **6. La cola del taller.** `Taller.encargos` y `Taller.cola()` como única
      lista, `_next_piece` pasando a leerla, y `_craft` cobrando el encargo por
      encima de la meta. *Toca `scripts/sim/Taller.gd` y
      `scripts/tests/TestColaDelTaller.gd` (nuevo, en `RunTests`). Pruebas: orden
      con encargo delante, entrada bloqueada que no para la cola, encargo sobre la
      meta, y el automático que sube, baja y se quita.*
> **HECHO (2026-09-14).** `Taller.cola(especialidad)` es ahora la única lista: encargos delante y automáticas detrás por nivel, cobertura y orden de `SPECIALITY_MAKES` —esta última clave, explícita, porque `sort_custom` no es estable y sin ella dos piezas con la misma cobertura romperían el determinismo (SPECS §3.3)—. `_next_piece` pasó de «la que más falte» a «la primera entrada sin motivo», que sin encargos y todo en normal da la misma pieza. Lo que antes se descartaba en silencio —falta el buril, falta el hueso— ahora es el `motivo` de la entrada y se ve. Once pruebas nuevas. Al escribirlas se cayó otra premisa mía: una azagaya pide buril, así que la prueba del encargo necesitaba herramientas previas en el abrigo —el código tenía razón—.
- [x] **7. A quién se manda al taller.** `Reparto._speciality_pressure`: un
      encargo hacedero pone la presión a cero y lo que está en nunca no cuenta.
      *Toca `scripts/sim/Reparto.gd` y `TestColaDelTaller.gd`. Prueba: con la meta
      cubierta y un encargo, la especialidad deja de estar «satisfecha».*
> **HECHO (2026-09-14).** `Reparto._speciality_pressure` devuelve 0 en cuanto hay un encargo hacedero de esa especialidad, y las piezas en nunca ya no cuentan para la peor cobertura (con todo apartado devuelve 1, «satisfecho»). Dos pruebas.
- [x] **8. Guardar y cargar.** Prioridades y encargos sobreviven al guardado, y
      un fichero de antes carga en normal y sin encargos. *Toca
      `scripts/tests/TestGuardado.gd` y, si hace falta, `scripts/region/Guardado.gd`.
      Prueba.*
> **HECHO (2026-09-14).** No hizo falta tocar `Guardado`: el recorrido por reflexión de `Instantanea` se lleva los tres diccionarios y la lista de encargos sin que nadie los declare. Dos pruebas en `TestGuardado`: ida y vuelta con prioridades y un encargo de tres azagayas, y un fichero de antes que carga en normal y sin encargos.
- [x] **9. El nivel en la ventana del almacén.** Una marca por fila, en lo que se
      recoge. *Toca `scripts/ui/PanelAlmacen.gd` y una prueba de panel montado:
      pulsar cambia el nivel de la simulación, y cambiarlo por código se ve sin
      cerrar.*
> **HECHO (2026-09-14).** Una marca por fila —normal → alta → baja → nunca— al lado de la meta, sólo en lo que se recoge: `Tajo.se_recoge` lo saca de las tablas de rendimiento y no de una lista escrita a mano. Atada con `ui._bind`, así que cambiar el nivel por código se ve sin cerrar la ventana.
- [x] **10. Las especies, en la rama de caza de Trabajos.** Las del valle, con su
      nivel, y apagadas con el motivo las que no se pueden cazar todavía. *Toca
      `scripts/ui/PanelTrabajos.gd` y `scripts/tests/TestPanelTrabajos.gd`.*
> **HECHO (2026-09-14).** Una fila por especie del catálogo con su nivel, y las que no se pueden cobrar hoy apagadas y con lo que falta (`Fauna.weapon_missing`), para poder priorizar el uro antes de saber hacer la azagaya.
- [x] **11. La ventana Taller.** `scripts/ui/PanelTaller.gd` nuevo, con su botón
      en la barra: la cola entera en orden, la fila de añadir encargo, y subir,
      bajar y quitar en cada fila. *Toca `scripts/ui/PanelTaller.gd`,
      `scripts/ui/GameUI.gd` y una prueba por botón, más la que compara entrada a
      entrada lo pintado con `Taller.cola()`.*
> **HECHO (2026-09-14).** `PanelTaller` nuevo con su botón en la barra: fila de encargo arriba, la cola entera con pieza, cuántas faltan, quién la hará y el motivo en rojo, y subir/bajar/quitar en cada fila. Y una línea de **apartadas** al pie que devuelve a normal lo que se quitó, porque quitar una automática la deja en nunca y si no sería irreversible. Al hacerlo saltó `LlamadasHuerfanas` con 5: mis nombres `cola` y `encargar` chocaban con los del horno y el Wayfinder —la herramienta casa por nombre—, así que pasaron a `cola_de_trabajo` y `encargar_pieza`. Vuelve a decir 0.
- [x] **12. Que nada se salga de la pantalla.** Captura con ventana de las tres a
      1920×1080 y a 1280×720, con la vara de `RegionCaptura`. *Sonda con ventana,
      ~3 min.*
> **HECHO (2026-09-14).** `scripts/tests/PrioridadesCaptura.gd`, que además de capturar **monta las ventanas y aprieta los botones**: es donde viven los criterios de INTERFAZ §4 que no caben en la suite (`TestCase` no tiene árbol y un `Button` sin árbol no se pulsa). Los diez pasan, incluida la comparación entrada a entrada de lo pintado contra `Taller.cola_de_trabajo()` con encargo, automáticas y una bloqueada. **Dos veces midió mal el instrumento antes de medir bien**: el proyecto arranca a pantalla completa, así que `window_set_size` no hacía nada y las ventanas se construían con el alto de 3651×2054 —de ahí «se salen»—; con `WINDOW_MODE_WINDOWED` primero y la interfaz montada de nuevo a cada resolución, nada se sale a 1920×1080 ni a 1280×720. **Hallazgo aparte, anterior a este trabajo**: la barra superior arrastra el ancho con el que se construyó y se sale (4 controles a 1920, 18 a 1280); no es de esta spec y queda para `/depurar`.
- [x] **13. La corrida que contesta lo que queda, en una sola pasada.** Treinta
      jornadas: las diez primeras sin tocar nada —firma contra la tarea 1 con
      `Cotejo`, ignorando los campos nuevos— y veinte con encargos y prioridades
      puestos, comparando la cola pintada con la pieza que termina cada artesano.
      *Sonda, ~12 min. Las comprobaciones de las tareas 1 y 6 se cierran aquí.*
> **HECHO a medias, y lo que salió es más útil que lo planeado (2026-09-14).**
>
> **«Nada cambia sin tocar nada»: comprobado.** Pero la primera comparación no valía: tomé la línea base con `TironAnualProbe` y la corrida nueva con `ColaVigilanteProbe`, y **dos instrumentos distintos son dos partidas distintas** —se separaban en la jornada 2 con la leña a 0 y 9 raciones de diferencia—. Repetida con el MISMO instrumento sobre el código nuevo, `Cotejo` dice **«en el resumen: nada»** las diez jornadas. Los 31 campos del detalle que sí difieren son los cuatro nuevos (`Prioridades.especies/materiales/piezas`, `Taller.encargos`) y **27 referencias a objetos renumeradas**: `Instantanea` codifica cada objeto como `[OBJETO, índice de registro]`, así que colgar un objeto más de `SettlementSim` desplaza el índice de todos los demás. Ningún valor de la partida cambia.
>
> **«Lo que se ve es lo que se hace»: comprobado, pero con una prueba y no con la sonda.** La corrida de 20 jornadas se frenó —la jornada 15 llevaba 190 s cuando las diez primeras iban a 45— y se cortó en vez de gastar 40 min más. El criterio se cerró con `test_lo_que_termina_el_artesano_es_la_cabeza_de_la_cola`: doce jornadas de taller tick a tick, comprobando en cada pieza terminada que era la primera entrada hacedera de la cola —con el progreso por persona, la materia prima gastándose y la cobertura subiendo por en medio, que es lo que podía descuadrarlo—. Cero descuadres, y el encargo cumplido desaparece.
>
> **Lo que queda sin medir, y se dice**: si construir la cola en cada consulta encarece el paso. Hay indicio —esa jornada 15— pero **no es medida**: la máquina tenía el editor del usuario abierto y cotejos corriendo a la vez, y el reloj de pared no se compara entre corridas con el equipo en distinto estado. Se mide con el cepo cuando se decida, y hasta entonces es sospecha, no cifra.
- [x] **14. Documentar.** Lo aprendido a SISTEMAS §22 y a INTERFAZ §4; SPECS §4.4
      y §4.7 si algún contrato cambia; ESTADO §3 si se mueve el total de la suite.

> **HECHO (2026-09-14).** SISTEMAS §22 con el plan, las decisiones del usuario y «Cómo quedó»; INTERFAZ §4 con las tres ventanas, la línea de apartadas y los dos avisos de captura; SPECS §4.4 (por qué `Prioridades` vive en `sim/` sin ser un subsistema con paso) y §4.7 (`PanelTaller`); ESTADO §3 con el total nuevo. Y en ARQUITECTURA §5.1, la lección de la firma: se coteja con el mismo instrumento, y añadir un objeto a la instantánea mueve los índices de todos.
### ~~Depurar del 2026-09-14 (segundo): la visita, los alfileres, las pasarelas y la campa~~ — cerrado

| Queja | Qué era | Dónde vive ahora |
|---|---|---|
| Al volver del mapa no salen los alfileres que tenía, sí los nuevos; «Viewport Texture must be set» | la caché estática de `Alfiler` entregaba texturas de un `SubViewport` ya liberado; la sonda de la primera vez contaba `visible` y cargaba con la caché vacía | [INTERFAZ.md](INTERFAZ.md) §4; `TestAlfiler` |
| Entrar en otro mapa trae a la banda y rompe la partida | cada mapa sin estado fundaba una banda | [SPECS.md](SPECS.md) §6.4; `TestGuardado`, `TestPartida`, `VisitaProbe` |
| La plataforma emergida es plana | la batimetría a 111 m sale lisa | [GRAFICOS.md](GRAFICOS.md) §3; `TestFrontera` |
| Las obras del hogar caen en el río | la campa era «ladera abajo», sin mirar el agua | [GRAFICOS.md](GRAFICOS.md) §4.1; `TestBocas` |
| Las nubes corren en pausa | iban con el reloj de pared, a propósito; el usuario cambió de idea | [GRAFICOS.md](GRAFICOS.md), el cielo |
| La noche no pasa rápido | 8 ms fijos por cuadro, y con ventana no se nota | [ESTADO.md](ESTADO.md) §2; `TestNoche`. **Abierto**: 3,2 s a x5 y 8 s a x1, no los 2 s pedidos |
| Las ventanas no se actualizan tras explorar | con el ratón encima no se repintaban, y las fichas sueltas no estaban en el repintado | [INTERFAZ.md](INTERFAZ.md) §4 |
| Clic en el minimapa | no existía | [INTERFAZ.md](INTERFAZ.md) §4; `TestMinimapa` |
| El paraviento, muy lejos | medido desde un borde de 7 m que no es el pozo: 12,5 m del centro | [GRAFICOS.md](GRAFICOS.md) §4.1 |
| La cima se queda explorando | el camino acaba una celda bajo la cumbre y al llegar se reconocía | [SISTEMAS.md](SISTEMAS.md) §4; `TestExploration` |
| Textura del conchero | era un tinte liso | [GRAFICOS.md](GRAFICOS.md) §4.1; `TestConchero` |
| No se levantan pasarelas; la N cierra el juego | sólo miraba rodeos con el agua de hoy, y la riada se la llevaba justo cuando servía; `NavOverlay` preguntaba por el permiso viejo | [SISTEMAS.md](SISTEMAS.md) §20; `TestPasarela` |

### ~~Depurar del 2026-09-14: diecisiete quejas de una partida de 167 jornadas~~ — cerrado

Lo que se arregló, qué era, y dónde está contado:

| Queja | Qué era | Dónde vive ahora |
|---|---|---|
| La costa a −120 m sale marrón | el shader recortaba a cero la cota bajo el mar de hoy: la plataforma entera caía en la banda de orilla | [GRAFICOS.md](GRAFICOS.md) §3 |
| La frontera al norte, recta | límites laterales en dos columnas fijas: 217 filas rectas | [EPOCA_01](EPOCA_01_PALEOLITICO.md), frente 18; `TestFrontera` |
| Más zoom, hasta el suelo | tope a unos 55 m de órbita y 14 m de suelo | [GRAFICOS.md](GRAFICOS.md) §4.1 |
| Las obras flotan | se apoyaban en el techo de su huella; ahora tendidas con la pendiente | [GRAFICOS.md](GRAFICOS.md) §4.1 |
| Pintar sale en cualquier cueva | el botón no miraba nada | [INTERFAZ.md](INTERFAZ.md) §4; `TestAbrigo` |
| El secadero, lejos del fuego | 2,9 m a un lado | [GRAFICOS.md](GRAFICOS.md) §4.1 |
| 1 277 de agua gastada junto al río | un odre lleno por salida aunque no se bebiera, el odre contado como bebido al salir, y el sorbo en casa mirando a la persona | [SISTEMAS.md](SISTEMAS.md) §17; `TestJornada` |
| El paraviento, encima del pozo | a 1,2 m del centro de la boca | [GRAFICOS.md](GRAFICOS.md) §4.1 |
| El filtro de alfileres se pierde al volver del mapa | vivía en el botón; y las cimas no se repintaban al retomar | [INTERFAZ.md](INTERFAZ.md) §4; `MarcadoresProbe` |
| Los peces desaparecen y no vuelven | barbecho al 90 % con el rebrote común: ~130 jornadas; y la ficha se callaba el pescado | [SISTEMAS.md](SISTEMAS.md) §12; `TestParajes` |
| Un aviso por paraje al coronar | la cola bautizaba de uno en uno, con tarjeta cada uno | [SISTEMAS.md](SISTEMAS.md) §4; `TestExploration` |
| Parajes «(2)», «(3)» | quince palabras de lugar | [SISTEMAS.md](SISTEMAS.md) §4; `TestParajes` |
| Nasas en «la veta de ocre» | `place_name` devolvía el primer paraje, no el más cercano | [INTERFAZ.md](INTERFAZ.md) §4; `TestParajes` |
| «Abrigo 5 de 15, la peor al 78 %» | eran vestidos; ahora lo dice, y el aforo al lado | [INTERFAZ.md](INTERFAZ.md) §4 |
| Nubes cuadriculadas | hash con seno sobre coordenadas que crecían sin tope | [GRAFICOS.md](GRAFICOS.md), el cielo; `NubesCaptura` |
| Vestidos sin agujas | **no era un fallo**: la regla ya existía; las agujas se gastan cosiendo | [SISTEMAS.md](SISTEMAS.md) §16; `TestTaller` |
| No hace lámparas | la demanda seguía siendo la de sólo pintar, y explorar también la pide | [SISTEMAS.md](SISTEMAS.md) §13; `TestRelato` |

**Queda abierto:** «ningún alfiler al volver» no se reprodujo, ni con la partida
del jugador (42 de 48 visibles); el botón «pintar» sigue sin pintar —la pintura
va por el relato—; y la pesca de un año con el remonte está sin medir (ESTADO §5).

---

### ~~El menú principal, las partidas guardadas y el modal de ESC~~ — cerrado (2026-09-14)

> Hecho entero. Lo que hay que saber vive ya en [INTERFAZ.md](INTERFAZ.md) §7
> —la spec, el plan y lo aprendido— y en [SPECS.md](SPECS.md) §6.4 —el contrato
> de persistencia—. Las tareas y sus citas de HECHO se quedan aquí abajo.

**Spec y plan técnico: [INTERFAZ.md](INTERFAZ.md) §7 y §7.6** (2026-09-13). Es
lo que [SPECS.md](SPECS.md) §6.4 dejó aplazado —«el guardado de partida se
desarrollará aparte»— más la pantalla que falta delante.

**Las tareas, en orden de implementación.** Lo que cuelga de qué está en §7.6;
aquí va lo que toca cada una y con qué se comprueba.

- [x] **1. `Partida`: la partida abierta y el catálogo.** Carpeta de trabajo
      (`user://partida_abierta`) a la que apunta `Guardado.carpeta` mientras se
      juega; ranuras en `user://partidas/<id>/` con su cabecera; nueva, guardar,
      cargar, lista, borrar y la marca de «hay cambios». `raiz` conmutable, que
      es lo que impide que una prueba pise las partidas del jugador.
      *Toca:* `scripts/region/Partida.gd` (nuevo).
      *Se comprueba con:* tarea 2.

      > **HECHO (2026-09-13).** La clase se llama **`Partidas`**, no `Partida`:
      > ese nombre ya era de `sim/Partida.gd` —el objetivo de la partida,
      > victoria y derrota— y Godot lo dijo con un «hides a global script
      > class». El plan decía `Partida`; se corrige aquí.
      >
      > **Dos carpetas conmutables, no una.** `Partidas.raiz` y
      > `Partidas.borrador`: si sólo se conmutara la raíz, una prueba que
      > llamara a `nueva()` vaciaría la carpeta de trabajo del jugador, que es
      > exactamente el fallo que costó una partida el 2026-09-13 por la otra
      > puerta.
- [x] **2. `TestPartida`.** Nueva deja el disco como estaba; guardar y cargar
      devuelve lo mismo; nombre repetido avisa; borrar borra; una partida de
      otra versión sale marcada y no carga; y la suite no escribe en
      `user://partidas`.
      *Toca:* `scripts/tests/TestPartida.gd` (nuevo), `scripts/tests/RunTests.gd`.

      > **HECHO (2026-09-13).** 14 pruebas, 45 comprobaciones; suite en verde,
      > **1 257 pruebas y 7 271 comprobaciones** (venía de 1 245 / 7 220).
      >
      > **Y una prueba tumbó una decisión del código el mismo día que se
      > escribió:** el identificador de ranura doblaba la eñe en ene, así que
      > «Cueva Peña» y «Cueva Pena» acababan en la misma carpeta. Ahora el
      > identificador sólo quita lo que un sistema de ficheros no admite.
- [x] **3. El menú principal, primera pantalla.** Tres botones y la piel del
      Paleolítico. Nueva partida → mapa regional con `GameState.begin`.
      *Toca:* `scripts/ui/MenuPrincipal.gd` y `scenes/menu_principal.tscn`
      (nuevos), `project.godot`.
      *Se comprueba con:* tarea 10 (captura) y la tarea 2 para «no hay
      simulación corriendo».
- [x] **4. La lista de partidas, una sola para las dos pantallas.** Nombre,
      valle, día y año, personas vivas y fecha real, leídos de cada cabecera; y
      borrar preguntando.
      *Toca:* `scripts/ui/ListaDePartidas.gd` (nuevo).
- [x] **5. El modal de ESC en el valle.** Sólo si no hay ventana abierta —la
      primera pulsación sigue cerrando lo que haya—, y **para el reloj**
      mientras está abierto.
      *Toca:* `scripts/ui/MenuDelJuego.gd` (nuevo), `scripts/DemoMain.gd`.
- [x] **6. Guardar y guardar como, desde el modal.** La primera vez pide nombre;
      después sobrescribe la suya; repetir un nombre existente pregunta. Guarda
      con la simulación viva y el reloj parado.
      *Toca:* `scripts/ui/MenuDelJuego.gd`, `scripts/region/Partida.gd`.
- [x] **7. El aviso de cambios sin guardar.** Marca encendida en `paso_cerrado`
      y al autoguardar un mapa, apagada al guardar; las dos salidas preguntan y
      cancelar no toca nada.
      *Toca:* `scripts/DemoMain.gd`, `scripts/ui/MenuDelJuego.gd`,
      `scripts/region/Partida.gd`.
- [x] **8. ESC en el mapa regional.** El mismo modal, y revisar el botón «volver
      con la banda» para que no se lea como «cargar partida»: es entrar en un
      mapa de ESTA partida.
      *Toca:* `scripts/region/RegionMap.gd`.

      > **HECHO (2026-09-14).** ESC abre el mismo modal en la comarca, medido con
      > `MenuCaptura SOLO=region`. Y el botón se llama ahora **«Entrar donde está
      > la banda (jornada N)»** con su aviso: era «Volver con la banda», y con un
      > menú que ya tiene «Cargar» eso se leía como abrir otra partida cuando es
      > entrar en un valle de la que se está jugando.
- [x] **9. `PartidaProbe`: dos procesos.** Guardar a media jornada, cerrar el
      proceso, cargar y cotejar **las mismas cinco firmas diarias** (criterio 5),
      y con dos valles visitados comprobar que el primero vuelve entero
      (criterio 6). Una sola pasada contesta los dos.
      *Toca:* `scripts/tests/PartidaProbe.gd` (nuevo).
- [x] **10. `MenuCaptura`: con ventana.** El menú, la lista y el modal abierto
      sobre el valle; y que con el modal abierto la jornada no avanza.
      *Toca:* `scripts/tests/MenuCaptura.gd` (nuevo).

      > **HECHO (2026-09-14), y con una sonda más de la que había en el plan.**
      > `MenuCaptura` mira el menú, la lista y el modal; lo que no cubría —y lo
      > dije al cerrar el bloque— era **el recorrido**: que pulsar «Nueva
      > partida» de verdad lleve a fundar en el valle. Eso es
      > **`NuevaPartidaProbe`**, pedida por el usuario, y pulsa el botón y la
      > tecla F por el mismo camino que el jugador.
      >
      > Medido en una pasada (unos dos minutos): arranca en `MenuPrincipal` **sin
      > simulación montada**; «Nueva partida» lleva al mapa regional con la
      > **carpeta de trabajo vacía —0 mapas—** y el emplazamiento de casa (56)
      > elegido; **no hay estado de ese mapa**, así que F funda en vez de
      > retomar, que es la prueba de que la partida empezó limpia; y el valle
      > monta con **jornada 1, 15 personas** y el guardado apuntando a la
      > partida abierta.
      >
      > Y de paso deja el **criterio 2 comprobado byte a byte**, que en la suite
      > sólo estaba a nivel de lista: las **6 partidas guardadas de la carpeta de
      > sondas quedan intactas** —hash de cada fichero antes y después—.
- [x] **11. Documentar.** INTERFAZ §7 con lo que se aprendió al hacerlo, y
      SPECS §6.4 con el contrato de la partida guardada.
      *Toca:* `docs/INTERFAZ.md`, `docs/SPECS.md`.

      > **HECHO las tareas 3 a 11 (2026-09-13/14).** El menú es la primera
      > pantalla (`scenes/menu_principal.tscn`, `run/main_scene`), la lista es
      > una sola clase para las dos pantallas, y el modal de ESC vive en
      > `MenuDelJuego` y lo montan tanto `DemoMain` como `RegionMap`.
      >
      > **Comprobado, y no sólo compilado:**
      >
      > - Suite en verde: **1 257 pruebas, 7 271 comprobaciones**; `llamadas
      >   huerfanas: 0`.
      > - `MenuCaptura`, con ventana: al arrancar hay menú y **no hay
      >   simulación montada**; con una ventana delante ESC la cierra y **no**
      >   abre el modal, y sin ventanas lo abre; con el modal abierto, **la
      >   jornada y la hora no se mueven en seis segundos de reloj a
      >   `time_scale = 5`** (jornada 1 → 1, hora 8,27 → 8,27). Y ESC abre el
      >   mismo modal en el mapa regional.
      > - `PartidaProbe`, dos procesos: guardada **a media jornada** (día 4, las
      >   13:00), cerrado el proceso, cargada, y **las cinco firmas diarias
      >   salen idénticas** —el criterio 5, que es el que hace que «se guarda
      >   todo» signifique algo—.
      >
      > **Lo que salió distinto del plan:** la clase tuvo que llamarse
      > `Partidas` (ver tarea 1), y hubo que hacer conmutables DOS carpetas y no
      > una. Nada más: el formato de los `.sav`, `Instantanea` y el autoguardado
      > al volver al mapa regional no se tocaron, que era lo que el plan decía
      > que no debía tocarse.

Qué entra: menú principal de tres botones (Nueva partida, Cargar, Salir) como
primera pantalla del juego; partidas guardadas **con nombre puesto por el
jugador, sin límite**, que guardan **la partida entera** —todos los mapas
visitados, la comarca, las relaciones, el valle en curso y la fecha—; y un modal
con ESC —dentro del valle y en el mapa regional— con seguir, guardar, guardar
como, cargar, salir al menú y salir del juego, que **para el reloj** y **avisa
si hay cambios sin guardar**.

Qué NO entra, y está escrito en la spec: opciones y controles en el menú,
«continuar» de un clic, autoguardado de la partida entera cada jornada,
capturas en la lista, y compatibilidad entre versiones.

Lo siguiente es `/plan-tarea` sobre esa spec.

### ~~Depurar del 2026-09-13 (tarde): el cuelgue, la despensa que se evaporaba y el abrigo que no se veía~~ — cerrado

Veinte quejas de una sola partida. Lo que se arregló, y dónde está contado:

| Queja | Qué era | Dónde vive ahora |
|---|---|---|
| Se cuelga en el día 350, «Navegacion…» sin parar | `Marcha._navgrid` encargaba las rejillas sin la versión de las pasarelas: con una levantada, `HornoDeRejillas.sirven` decía que no en CADA consulta y rehacía la rejilla entera (1 s) por cada camino pedido | `TestWayfinder` |
| 2 000 raciones de pescado seco en pocos días | `Storehouse.age` aplicaba la fracción podrida de la edad ENTERA sobre lo que quedaba cada día, y eso se acumula: pasada la mitad de vida se iba el 70 % en quince días | [SISTEMAS.md](SISTEMAS.md), la despensa |
| El hogar se apaga con leña y tardan días en prenderlo | quien llevaba el hogar se ponía con la obra en cola antes de mirar el fuego, y si a la obra le faltaba material se pasaba la jornada esperando | [SISTEMAS.md](SISTEMAS.md), el hogar |
| Siguen esquilmando la pesca | el descanso saltaba, pero los sitios conocidos y el de reserva entraban en la lista de tajos sin mirarlo | [SISTEMAS.md](SISTEMAS.md), el barbecho |
| Zoom cada vez más sensible, y no orbita el centro | el punto de órbita vivía a cota cero, bajo el monte | [GRAFICOS.md](GRAFICOS.md), la cámara |
| Hoguera medio enterrada; secadero, paraviento y lavadero invisibles | sólo el hogar tenía figura, y se apoyaba en la cota de su centro | [GRAFICOS.md](GRAFICOS.md), las obras del abrigo |
| Troncos donde sentarse | no existían | [GRAFICOS.md](GRAFICOS.md) y `CorroDelHogar` |
| «Alguien ha muerto» | la causa se quedaba en la crónica | [INTERFAZ.md](INTERFAZ.md), la tarjeta de la muerte |
| Técnicas frenadas sin marcar | sólo iba en rojo la parada por material | [INTERFAZ.md](INTERFAZ.md) §4 |
| Se comen la grasa; nadie curte pieles | la grasa era comida y el curtido la necesitaba | [SISTEMAS.md](SISTEMAS.md), el taller |
| ¿En qué se gasta la piel cruda? | tiendas, expedición y paraviento la gastaban sin curtir | [SISTEMAS.md](SISTEMAS.md), el taller |
| Las técnicas tardan muchísimo | jornadas nuevas, decididas por el usuario | [EPOCA_01](EPOCA_01_PALEOLITICO.md) §5 |
| Marcadores de cueva distintos, y sin filtro | el alfiler vivía dentro de `ParajeMarkers` | [INTERFAZ.md](INTERFAZ.md) y [GRAFICOS.md](GRAFICOS.md) |
| Cueva explorada: sigue el botón | no se guardaba quién entró ni qué eligió | [INTERFAZ.md](INTERFAZ.md) §4 |
| El odre lleno cuenta también como vacío | tres sitios contaban vacíos por su cuenta y la capacidad sumaba los llenos | [SISTEMAS.md](SISTEMAS.md), la despensa |
| El almacén se llena de morralla | no había topes al empezar | [SISTEMAS.md](SISTEMAS.md), el almacén |

### ~~Tras la tanda 4: el trueque sólo en la ventana, y mudarse de cueva~~ — cerrado

> **Pedido por el usuario el 2026-09-13**, directamente y sin spec aparte: «mide
> los fotogramas, quita la tarjeta vieja de trueque, construye el traslado de
> campamento a una cueva descubierta; la banda viajará físicamente hasta allí y
> se asentarán, sólo si pueden llegar». Tres decisiones suyas del mismo día para
> el traslado: **se llevan lo que puedan cargar** y el resto se queda en la cueva
> vieja; **las obras se quedan** y hay que rehacerlas; **viajan todos juntos** y
> dejan de trabajar.

- [ ] **Medir el fotograma con las cuevas nuevas.** **Aparcado por el usuario**
      mientras probaba el juego. `FotogramaCuevasProbe.gd` queda escrita:
      mide con y sin cuevas en la misma corrida, alternando y con mediana. La
      primera pasada, con media y p95, salió dominada por tirones sueltos —el
      horno de rejillas al mover la cámara— y no servía para comparar.
- [x] **Quitar la tarjeta vieja de trueque.**

  > **HECHO (2026-09-13).** Fuera `proponer_el_trato`, `tratar` y su viaje de
  > cuatro jornadas, las probabilidades, `Moment.Kind.TRUEQUE` y la llamada de
  > cada estación. `Intercambio` queda con precios, la regla del 10 %, `cambiar`
  > e historial; el primer cambio sigue siendo un hito de la crónica. **Se va
  > también pedir gente a otra banda**, que sólo existía en la tarjeta. **Bajan
  > las comprobaciones de 7 645 a 7 029**: son las de la tarjeta —quince pruebas
  > de `TestIntercambio`, muchas con bucles, y dos de `TestDecisiones`—; no se
  > perdió ninguna de lo que sigue en el juego.
- [x] **El traslado de campamento.**

  > **HECHO (2026-09-13).** `sim/Traslado.gd`. La orden sale si la banda llega
  > andando —la rejilla de la marcha, sin la regla del rodeo— y no hay nadie de
  > expedición. Cada cual carga hasta su capacidad, la comida primero y lo demás
  > por su precio de trueque; lo que no cabe queda apuntado en la cueva vieja.
  > Toda la banda anda hasta la campa nueva sin trabajar y se asienta cuando
  > llegan todos: la casa, la cueva de la banda, el almacén con lo que traían,
  > las obras de ese sitio —ninguna si es nuevo—, y en la vista la hoguera y los
  > tajos. Volver a la cueva vieja devuelve sus obras y lo que se dejó. El botón
  > de la ventana del abrigo lo hace, o sale apagado con por qué.
  >
  > **Compilar no era funcionar**: las pruebas colocaban a la gente a mano, y
  > `TrasladoProbe`, en la escena real, pilló que **nadie llegaba andando** —la
  > banda se paraba a 51–52 m con el camino gastado, porque la campa de una cueva
  > cae en celda cerrada por la ladera— y se asentaba por la red de seguridad a
  > las 42 horas. Ahora cuenta como llegado quien agota el camino a menos de dos
  > celdas, y al asentarse se abre la puerta de la cueva nueva en la rejilla,
  > como la de casa. **Medido**: 15 personas, cueva a 448 m, **asentados en 0,4
  > horas de partida sin red de seguridad**, hoguera movida 441 m y tajos
  > rehechos. `TestTraslado`, nueve pruebas. Suite **1 216 pruebas, 7 031
  > comprobaciones**, huérfanas 0.
  >
  > **Lo que no hace**, dicho: lo que se deja en una cueva no se pudre ni se lo
  > lleva nadie; no hay plazas de cueva, así que cualquier cueva aloja a toda la
  > banda; y mudarse no mueve el territorio conocido ni los parajes, que son del
  > mapa.

---

### Los dos primeros años del Paleolítico

**Spec escrita (2026-09-12) en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, con los criterios de aceptación de cada frente. El mecanismo de lo que
cruza épocas, en **SISTEMAS.md §4, §5, §18 y §19**; lo que se ve, en
**INTERFAZ.md §4**; las cifras medidas, en **ESTADO.md §2** y sólo ahí.
Siguiente paso: `/plan-tarea`, que cuelga aquí la lista de tareas.

Que la primera fase dure dos años **y se juegue**: caminos que la banda aprende
y que caducan con la rejilla estacional, la noche acelerada cuando nadie
trabaja, expedición fuera del mapa para encontrar gente, trueque con
contraparte que recuerda, temperatura en grados y el vestido como necesidad, y
decisiones repartidas por el año que de verdad cuesten. Cierra con tres
condiciones: cueva pintada, expedición mandada fuera y puntos regionales
nuevos.

**Criterio que lo ordena:** sólo entra lo que sirva a las once épocas. Es la
trampa de la época 1 —EPOCA_01 §11, alargarla porque es la que está hecha— y se
descartó a propósito.

**Y va en dos tandas, partidas por lo que se puede medir**, no por lo que
importa más:

| | Qué entra | Se comprueba con |
|---|---|---|
| **Tanda 1** | Los caminos que se aprenden, la noche acelerada, la temperatura en grados visible, y el rendimiento que no empeora | Sondas de días o de una estación: `RodeoProbe`, `FirmaDiaria`, `Cronometro`, `PicoProbe` |
| **Tanda 2** | Expedición fuera del mapa, trueque con contraparte que recuerda, el vestido como necesidad, y las decisiones del año | Un año entero que llegue al final: `AnoProbe`, `BandaProbe` |

**Los dos 🔴 de aquí abajo entran en la spec**, decidido al escribirla:
ninguno es sólo un fallo —el taller que se para es el reparto automático
reasignando al artesano, que es diseño— y sin los dos cerrados **no se mide nada
de la tanda 2**. Ojo con el dueño: el cuelgue sigue asignado a
`history-of-man-0e` y no hay constancia de que esté empezado; quien lo coja, lo
dice en la pizarra primero.

**Depende de:**

- El 🔴 del cuelgue, de aquí abajo. Esto se mide en años, y mientras el
  cuelgue exista no se puede correr un año con reparto pobre. Está **dentro** de
  la spec, no fuera.
- Tres fallos que van por `/depurar` y que hay que cerrar **antes** de diseñar
  encima. **Los tres están hechos** (2026-09-12): la azagaya que no se
  fabricaba, el panel que no decía por qué una técnica estaba parada — ver
  INTERFAZ.md §4 y EPOCA_01 §10.1, donde queda anotado que la causa dominante no
  era el material sino las jornadas— y el rodeo del río, que **no era el río**:
  era el recargo por riesgo del trazado, que multiplicaba el tiempo sin tope y
  hacía que cuarenta metros de ladera costaran kilómetros de rodeo. Ver
  ESTADO.md §2 y SPECS.md §4.3.
- Y el 🔴 del taller, que salió de ese mismo `/depurar` y bloquea esto más
  que el cuelgue: sin taller no hay rama de manufactura, y sin manufactura los
  dos años no se sostienen. También **dentro** de la spec.

  **Los dos primeros, cerrados (2026-09-12, `/depurar`).** Lo que se arregló, y
  lo que se encontró que no estaba escrito en ninguna parte:

  - **El asta se puede buscar, y el desmogadero entrega.** No era sólo que
    `ASTA` faltara en `Parajes.EXTRAS_BY_ACTIVITY`: el desmogadero **ya era** un
    nombre de paraje y ninguna tabla de materia prima daba asta, así que se
    podía ir y volver vacío. `Tajo.ASTA_DE_DESMOGUE` es ahora la única cifra, y
    la usan el recolector, el cantero y la materia prima sin especialidad.
  - **La caza menor se hace con punta lítica**, no con azagaya. Era el bucle:
    sin tendón no se aprende la azagaya y sin caza menor no había tendón.
    `Fauna` ya decía que al corzo se le entra con lanza de mano y
    `SettlementSim.SPECIALITY_TOOL` decía lo contrario.
  - **La banda llega con dos puntas**, no con dos azagayas.
    `SettlementSim.UTILLAJE_INICIAL` es una lista y hay prueba de que nada de
    ella pide técnica.
  - **El panel dice la causa.** `TechTree.freno` / `TechTree.causa` la deciden
    en un solo sitio; la casilla la escribe y la parada por material lleva
    filete de hematites. Ver INTERFAZ.md §4.
  - **Y la causa dominante no era el material sino las jornadas**: medido, 0,62
    jornadas de manufactura al día con el reparto por defecto. Ver ESTADO.md §2.

  - **El rodeo del río era el miedo, no el agua.** Cruzar un vado con el agua
    por la rodilla cuesta 20; subir un canchal, hasta 587, y de esas 587 sólo 58
    son el tiempo que se tarda. El trazado minimiza coste, así que rodeaba. Se
    le puso tope al recargo por riesgo, `Navgrid.RIESGO_MAXIMO`, que **es**
    `Marcha.RODEO_QUE_SE_ANDA` y no una copia. Medido: el rodeo de verano baja
    de x2,40 a x1,43 y los sitios que se admitían y se andaban por encima de su
    propio tope pasan de 88 a 1.
  - **Y la regla del rodeo juzgaba un camino distinto del que se anda.** Había
    dos Dijkstra —uno por coste para el viaje, otro por metros para la regla—;
    ahora es uno, y encima se ahorra. El segundo tapaba un síntoma cuya causa
    era el coste; con el coste arreglado no vuelve, comprobado.

  Los tres cerrados. Y salió uno nuevo, abajo.

---

### La puerta de entrada: los dos 🔴

**Spec y plan técnico en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, «La puerta de entrada». Lista colgada por `/plan-tarea` el 2026-09-12
por `history-of-man-b2`; el cuelgue estaba asignado a `history-of-man-0e`, que
ya no está viva y **no dejó nada en `scripts/` ni en el log** —comprobado, no
supuesto—, así que se coge de cero.

**Lo que cambia respecto de lo que decía este documento:** la hipótesis del
cuelgue —«recorrer `sim.people` mientras `_person_dies` lo modifica», con
`Relevo.gd` de sospechoso sin leer— **está descartada por lectura**: `Relevo`
ya recorre `sim.people.duplicate()` en las tres revisiones, y lo dice su
comentario de la línea 125. El diagnóstico empieza de cero.

**El taller, y es donde ya hay hipótesis medida a medias:**

- [x] **A1. Reproducir el taller parado sin simular 31 jornadas.** Prueba que
      construye el estado —almacén con piedra de sobra y sin fibra, asta ni
      hueso; un artesano en `MANUFACTURA`— y comprueba qué pieza elige
      `Taller._next_piece`, qué contesta `_workshop_short` y adónde le manda el
      recado. **Toca:** `scripts/tests/TestTaller.gd` (nuevo).
      **Verificable:** la prueba deja escrito el estado de hoy. Segundos.

      > **HECHO (2026-09-12).** `scripts/tests/TestTaller.gd`, cuatro pruebas,
      > segundos. **Y el diagnóstico sale distinto del que suponía el plan: el
      > taller no está roto, ha terminado su trabajo.** Construido el estado de
      > la jornada 31 —utillaje lítico cubierto, 3 054 de piedra en el almacén,
      > la cifra medida de la jornada 61— resulta que:
      >
      > - `Taller._next_piece(TALLA)` devuelve **−1**: no queda pieza que
      >   tallar, por mucha piedra que haya. La demanda natural de utillaje
      >   —`tool_natural_demand`: LASCA `gente/2`, RAEDERA 2, BURIL 2, PUNTA 2—
      >   es **fija y pequeña**, y una vez cubierta a `RESERVA_UTILLAJE` (1,3)
      >   no hay más que hacer.
      > - Y por eso `_speciality_can_work(TALLA)` da **false**, que es
      >   exactamente lo que `Reparto.apply_priorities` usa para mandar al
      >   artesano a su siguiente oficio —su comentario lo dice y es
      >   deliberado: «el artesano se va a su siguiente oficio en vez de
      >   quedarse el día entero delante de un banco vacío»—. De ahí la
      >   cuarcita: se va al canchal porque en el taller no hay nada que hacer.
      > - **No es falta de material.** Con 3 054 de piedra, `_workshop_short`
      >   dice que no falta nada: el recado a por materia prima no es la causa.
      > - Y **vuelve**: con el utillaje gastado, `_next_piece` vuelve a dar
      >   pieza. La caída de 2,00 a 0,3 jornadas/día no es una parada, es el
      >   paso del transitorio de equipar a la banda desde cero al **régimen
      >   permanente de reposición**.
      >
      > **Dos premisas del plan se caen con esto**, y están corregidas en
      > EPOCA_01 §10.1: A2 no procede —`_workshop_short` no es la causa— y A3
      > **ya estaba implementado**: `_next_piece` llama a `_can_pay_for` y
      > descarta la pieza sin material, con un comentario que dice justo lo que
      > el plan proponía añadir. Lo que queda no es un arreglo de código sino
      > una decisión de diseño, y está en el chat.
- [~] **A2. `_workshop_short` dice QUÉ falta, no sólo que falta.** Hoy sabe el
      material y devuelve `bool`: quien recibe ese `true` manda al canchal, y
      por eso entra cuarcita —de 96 a 3 054, ESTADO.md §2— mientras la
      manufactura se para. **Toca:** `scripts/sim/Taller.gd`,
      `scripts/sim/SettlementSim.gd` (~2378).
      **Verificable:** A1 en verde y `LlamadasHuerfanas` en 0. Segundos.
- [~] **A3. El artesano no hace lo que no puede hacer.** Que `_next_piece`
      descarte la pieza cuyo material no está, igual que ya descarta la que no
      se sabe hacer y la que nadie pide; y que salir a por material sea el
      último recurso, con destino al material que falta.
      **Toca:** `scripts/sim/Taller.gd`, `scripts/sim/SettlementSim.gd`.
      **Verificable:** prueba nueva en `TestTaller.gd`. Segundos.
- [~] **A4. Que la caída no vuelva, medido.** `ArbolPasoProbe` con el taller
      ocupado a mano a lo largo de 90 jornadas: las jornadas de manufactura por
      día no caen de 2,00, y la recolección no se resiente por competir por el
      mismo tajo. **Toca:** `scripts/tests/ArbolPasoProbe.gd` (añadir `MANU=n`).
      **Verificable:** su tabla jornada a jornada. **Corrida larga, ~45 min.**

      > **A2, A3 y A4 NO SE HACEN, decidido el 2026-09-12 con A1 en la mano.**
      > A1 demostró que no hay fallo que arreglar: A2 atacaba a
      > `_workshop_short`, que no es la causa; A3 **ya estaba implementado**
      > (`_next_piece` llama a `_can_pay_for`); y A4 medía si el arreglo había
      > funcionado, que ya no es la pregunta. El 🔴 se cierra **como hallazgo**:
      > el taller no se para, termina, y lo que queda —que el régimen de
      > reposición no dé para las 110 jornadas de la talla laminar— es
      > **balanceo**, va por `/spec` y no se decide aquí. Las cuatro opciones
      > que se barajaron (que el artesano practique sin demanda, subir
      > `tool_natural_demand`, bajar las jornadas de la laminar, o dejarlo)
      > quedan para esa spec. Ninguna cifra se inventó hoy.

**El cuelgue:**

- [x] **B1. Un vigía que se pueda leer mientras cuelga.** Godot no suelta la
      salida hasta salir, y por eso hubo «17 minutos sin una línea de log»: un
      fichero con `flush()` por fase dice dónde se quedó sin matarlo a ciegas.
      **Toca:** `scripts/tests/AnoProbe.gd`. **Verificable:** dos jornadas y el
      fichero tiene fases. Minutos.
- [x] **B2. Reproducirlo construyendo el estado, no simulándolo.** Despensa a
      cero, hambre al máximo en los quince, verano al filo del cambio a otoño, y
      dar pasos. **Toca:** `scripts/tests/TestCuelgue.gd` (nuevo).
      **Verificable:** cuelga, o no cuelga —y si no cuelga, la premisa se cae y
      se dice—. Minutos.
- [x] **B3. Decir cuál es el bucle.** No arreglar el primer sospechoso: nombrar
      el bucle con su fichero y su línea. Depende de B1 y B2.
- [x] **B4. Arreglarlo, con una prueba que falle antes.**
      **Toca:** donde caiga, más `scripts/tests/`.

      > **HECHO (2026-09-12), y B1–B3 con él.** `scripts/tests/CuelgueProbe.gd`
      > (nueva, con vigía), `SettlementSim.partida_terminada()`, tres pruebas en
      > `TestPartida.gd`, y el arreglo en `AnoProbe.gd`.
      >
      > **No era un bucle del juego: era el instrumento esperando a un muerto.**
      > `SettlementSim._process` abre con `if people.is_empty() or _terrain ==
      > null or time_scale <= 0.0: return`, así que con la banda extinta no
      > avanza nada y `day` se queda clavado. `AnoProbe` esperaba con
      > `while sim.day < primero + dias: await process_frame`, o sea **una
      > jornada que ya no iba a llegar nunca**: fotogramas vacíos a un núcleo
      > entero, y ni una línea de log porque no había nada que imprimir. De ahí
      > los «17 minutos sin escribir» y el tener que matarlo a mano.
      >
      > **Reproducido en 63 segundos, no en 45 minutos**, construyendo el
      > estado en vez de simularlo: verano a dos días del cruce, despensa a
      > cero, hambre 100 y `hunger_sick_days` a un día del umbral de
      > `Relevo`, para que los quince mueran la misma jornada. El vigía —a
      > fichero con `flush()`, porque Godot no suelta la salida hasta salir—
      > lo dejó escrito:
      >
      > ```
      > JORNADA 2 · Verano · vivos 0 · desenlace 2
      > CUELGUE CONFIRMADO · 4001 vueltas sin que avance el dia 2 ·
      >   vivos 0 · desenlace 2 · reloj x5.0
      > ```
      >
      > Nótese `reloj x5.0`: **no era el reloj parado por un `Moment` sin
      > contestar**, que era la otra sospecha razonable. Era la banda muerta.
      >
      > **Y se descarta del todo la hipótesis que traía el ROADMAP**: no hay
      > ningún bucle que recorra `sim.people` mientras `_person_dies` lo
      > modifica. `Relevo` ya recorría copias.
      >
      > El arreglo es `partida_terminada()` —la pregunta en un solo sitio,
      > invariante 3 de SPECS §7— y que quien espere jornadas la consulte. Una
      > corrida que antes había que matar ahora imprime en qué jornada terminó
      > la partida y hasta dónde miden sus tablas.
- [x] **B5. La corrida literal del criterio.** `SEMILLA=42 DIAS=95 BANDA=4,3,2`
      sobre `AnoProbe` **termina y escribe sus tablas**. No vale otra corrida:
      cambiarle el reparto para medir de paso otra cosa deja de reproducir lo
      que se quería reproducir. **Corrida larga, ~45 min.**

      > **HECHO (2026-09-12).** Terminó y escribió sus tablas, con
      > `desenlace: NINGUNO`. El criterio de aceptación del 🔴 queda cumplido.
- [x] **B6. ¿Es 4,3,2 viable, o es hambre garantizada?** La otra mitad de la
      pregunta, y **se lee de la misma pasada de B5** —hambre, muertes y
      despensa por estación, que `AnoProbe` ya saca—: no cuesta una corrida
      más. Si la respuesta es que no, es un hallazgo de balanceo y va a
      ESTADO.md §2.

      > **HECHO (2026-09-12): 4,3,2 es viable, y el parte del 🔴 ya no
      > describe el juego.** Los quince vivos las 95 jornadas, hambre media
      > clavada en 26 —el umbral de enfermedad es 70— y la despensa subiendo:
      >
      > | día | estación | gente | despensa | días de reserva | hambre |
      > |---|---|---|---|---|---|
      > | 1 | Primavera | 15 | 101 | 4,0 | 20 |
      > | 46 | Verano | 15 | 517 | 20,4 | 26 |
      > | **76** | **Verano** | **15** | **460** | **18,1** | **26** |
      > | 91 | Otoño | 15 | 556 | 21,9 | 26 |
      >
      > **Compárese el día 76 con el parte del 🔴**, que en esa misma jornada
      > medía «despensa = 0 y hambre media 100». Entre una medida y otra se
      > cerraron los tres fallos de `/depurar`, y el del rodeo del río es el
      > que lo explica: bajar el rodeo de verano de x2,40 a x1,43 es la mitad
      > del día que la banda se pasaba andando. **No era el reparto: era el
      > trazado.**
      >
      > Y con esto **se desbloquea «la pesca sin sitio conocido»** del bloque
      > del secadero, que estaba 🔒 esperando a este diagnóstico. La corrida
      > ya trae su medida: ver ESTADO.md §2.

**Presupuesto de máquina: ~1 h 30 de corridas largas**, A4 y B5 seguidas —Godot
es de uno en uno, AGENTES.md §3—. Todo lo demás son pruebas de segundos. La
contingencia es B2: si el estado construido no reproduce el cuelgue, hace falta
la corrida literal con el vigía para localizarlo, y eso son otros ~45 min.

**Al cerrar:** las cifras nuevas van a [ESTADO.md](ESTADO.md) §2 y el total de
la suite a §3, que son las únicas copias.

---


---

### ~~Tanda 2: expedición, trueque, el vestido y las decisiones del año~~ — cerrada

**CERRADA el 2026-09-13.** Todo lo estructural hecho y medido con dos años de
partida. Suite **1 076 pruebas y 7 161 comprobaciones**, desde 979/6 994. Lo
aprendido está en EPOCA_01 §10.1 («Cierre de la tanda 2»), SISTEMAS §4, §5, §18
y §19, SPECS §4.4 y §4.6, INTERFAZ §4 y ESTADO §2 y §5.

| | |
|---|---|
| La expedición | Sale, descubre **4 sitios** por vuelta y deja contacto; **la primera siempre encuentra gente** |
| El trueque | Con contraparte que recuerda y seis maneras de tratar; **tasa sin medir**, 0 intentos en la pasada |
| El vestido | Cierra las cumbres con frío; **en el invierno en casa no cambia nada**, aceptado como hallazgo |
| Las decisiones | **4 al año que cuestan**, una por estación |
| **Lo que queda abierto** | 🔴 **La banda muere de hambre en el segundo invierno** (ESTADO §5, punto 13), por `/depurar`. Hasta entonces ninguna cifra de año vale |

**Spec y plan técnico en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, tanda 2 y «Plan técnico de la tanda 2». Lista colgada por
`/plan-tarea` el 2026-09-12 por `history-of-man-11`.

**Suelo de la suite al abrir: 979 pruebas, 6 994 comprobaciones, TODO OK.**

**Tres premisas de la spec que el código no sostiene**, en el plan con detalle:
la **niebla regional ya está construida** (`GameState.discovered` +
`RegionMap`), `PanelSitios` **no lista emplazamientos regionales** —es el panel
local—, y `Site` es **un recurso horneado**, así que el contacto no puede vivir
ahí.

**La expedición** (frente 5) — nadie depende de nada, y todo depende de ella:

- [x] **E1. Medir la niebla que ya hay, antes de tocarla.** *(Decidido el
      2026-09-12: se mide y se corrige la documentación que dice lo contrario
      —SISTEMAS §4 y FASE A1—, en vez de reconstruir algo que funciona.)* Cuántos `Site`
      lista `RegionMap` al empezar la partida. Si ya son un puñado, el primer
      criterio del frente está cumplido y se escribe; si son 862, está roto y
      es otra tarea.
      **Toca:** `scripts/tests/TestNiebla.gd` (nuevo), ESTADO.md §2.
      **Verificable:** la prueba deja la cifra escrita. Segundos.

      > **HECHO (2026-09-12), y la premisa se confirma: estaba construida.**
      > `scripts/tests/TestNiebla.gd`, 4 pruebas. Al empezar la partida se
      > conoce **un** emplazamiento, la cueva. El criterio «no ver los 862 de
      > golpe» estaba cumplido de sobra.
      >
      > **Y lo que falta queda localizado:** nadie llama a
      > `GameState.discover` desde la partida, así que **la niebla no se
      > levanta nunca**. El mapa regional se queda en la cueva para siempre.
      > Eso es E3, y ahora se sabe que es lo único que falta de esta mitad.
      >
      > **Dos cifras de la documentación estaban mal**, y se corrigen en
      > SISTEMAS §4 y ESTADO §2: el conjunto horneado tiene **869**
      > emplazamientos y no 862 —los siete de más son los de prueba— y de ésos
      > sólo **72** son usables en el Paleolítico con el mar a −120 m. Los
      > «puntos regionales nuevos» que cierran la fase se miden contra 72.
- [x] **E2. `Contacto`: quién hay ahí fuera.** Subsistema nuevo: qué `Site`
      están ocupados —sorteado con el `_rng` al empezar— y con cuáles se ha
      tratado. **No va en `Site`**, que es dato horneado, ni en `GameState`,
      que es lo que cruza escenas: es estado de simulación y la instantánea
      tiene que recorrerlo.
      **Toca:** `scripts/sim/Contacto.gd` (nuevo), `scripts/sim/SettlementSim.gd`,
      `scripts/tests/TestContacto.gd` (nuevo).
      **Verificable:** pruebas —el sorteo sale del `_rng`; el contacto
      sobrevive a una estación; `LlamadasHuerfanas` en 0—. Segundos.

      > **HECHO (2026-09-12).** `scripts/sim/Contacto.gd` (nueva) y
      > `scripts/tests/TestContacto.gd`, 10 pruebas. Suite **993 pruebas,
      > 7 022 comprobaciones**. Guarda quién está ocupado —sorteado con el
      > `_rng`— y el `trato` con cada contraparte, con la forma del de
      > `ElLobo`, que es lo que la spec pedía para que el peldaño escale.
      >
      > **Y una guarda que salió de escribir la prueba, no del plan:** repartir
      > la comarca dos veces la cambiaba, porque el segundo sorteo usaba el
      > `_rng` ya avanzado —19 ocupados la primera vez, 12 la segunda—. O sea
      > que la gente que habías conocido dejaba de estar donde estaba. Ahora se
      > reparte **una sola vez** y la segunda llamada no hace nada.
      >
      > `OCUPADOS` (uno de cada cinco) y los topes del trato **son decisiones y
      > está dicho en el código**: no hay dato arqueológico de cuántos de los 72
      > emplazamientos del Magdaleniense estaban habitados a la vez.
- [x] **E3. `Expedicion`: la salida larga, y lo que cuesta.** Se manda gente,
      tarda jornadas, come de su propia cuenta de `Despensa`, y al volver
      descubre `Site` —es el único sitio que llama a `GameState.discover`—.
      Vuelva con algo o vuelva de vacío, las jornadas se han ido.
      **Toca:** `scripts/sim/Expedicion.gd` (nuevo), `scripts/sim/SettlementSim.gd`,
      `scripts/sim/Despensa.gd`, `scripts/tests/TestExpedicion.gd` (nuevo).
      **Verificable:** pruebas —descubre y sube la cuenta; consume raciones y
      jornadas; **la que vuelve sin llegar cuesta igual**—. Segundos.

      > **HECHO (2026-09-12).** `scripts/sim/Expedicion.gd` (nueva), 13 pruebas
      > en `TestExpedicion`. Se sale con 3 adultos como mínimo, 12 jornadas
      > fuera, y se llevan **las raciones de todo el viaje** antes de salir —en
      > la cuenta de siempre, `Materia.KCAL_RACION`: 3 × 12 × 2 = 72—. Al
      > volver se descubren el destino y sus vecinos más cercanos.
      >
      > **Tres cosas que no estaban en el plan:**
      >
      > - **Quien sale deja de existir en el mapa local.** No basta con que no
      >   trabaje: `SettlementSim._advance` no le da tick y `Reparto` no le
      >   asigna nada. Si no, «salir del valle» era seguir paseando por él.
      >   `Inhabitant.expedicion_hasta` es la marca.
      > - **La regla de qué comida aguanta un viaje estaba escrita dentro de
      >   `Despensa._provision`**, y la expedición la habría copiado. Ahora es
      >   `Despensa.LO_QUE_AGUANTA_EL_VIAJE` y la usan las dos.
      > - **Y compilaba sin funcionar.** Con las pruebas en verde, en el juego
      >   real nadie le pasaba la comarca a la expedición ni repartía quién
      >   vive dónde: salía, gastaba y volvía sin descubrir nada. El cableado
      >   va en `DemoMain`, que es donde SPECS §2.3 dice que se cablea, y lo
      >   comprueba `scripts/tests/ExpedicionProbe.gd` **en la escena de
      >   verdad**: comarca cargada, 16 emplazamientos con gente, salida con
      >   72 raciones, vuelta con 4 descubiertos y 36 jornadas-persona.
      >
      > Una prueba pasaba **sin comprobar nada**: «la que vuelve sin nada cuesta
      > igual» comparaba jornadas de dos expediciones, y cero contra cero
      > también son iguales. Ahora exige que las dos hayan salido.
      >
      > **Y lo que falta, dicho:** no hay botón. `Expedicion.mandar` es el
      > mecanismo; que el jugador pueda mandarla es una decisión y va con el
      > frente 8.
- [x] **E4. Alcanzar un sitio ocupado deja contacto.** Y el contacto sigue ahí
      una estación después, que es lo que el trueque va a usar.
      **Toca:** `scripts/sim/Expedicion.gd`, `scripts/sim/Contacto.gd`,
      `scripts/tests/TestContacto.gd`. **Verificable:** prueba. Segundos.

      > **HECHO (2026-09-12), y ya lo hacía E3:** `Expedicion._volver` llama a
      > `Contacto.conocerse` si el destino tiene gente. Lo que añade esta tarea
      > son las tres pruebas que lo cierran —dejar contacto donde hay gente,
      > **no** dejarlo donde no la hay, y que siga ahí **cuarenta y cinco
      > jornadas después**, literal—. La del sitio vacío se comprobó rompiendo
      > `Contacto.hay_gente_en` a propósito: se pone roja.
      >
      > Suite al cerrar el frente 5: **1 009 pruebas, 7 057 comprobaciones**,
      > desde 979/6 994. `LlamadasHuerfanas` sigue en las 2 de siempre.

**El trueque** (frente 6) — **depende entero de E2 y E4**:

- [x] **T1. El trueque deja de ocurrir solo.** Fuera la llamada automática por
      estación; pasa a ser un `Moment` con opciones. En un año sin que el
      jugador decida nada, intercambios consumados = 0.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/sim/SettlementSim.gd`
      (~3350), `scripts/tests/TestIntercambio.gd`.
      **Verificable:** prueba de que sin decisión no hay trato. Segundos.
- [x] **T2. La contraparte recuerda, y el 55 % fijo deja de ser fijo.** El
      `trato` por contraparte, con la forma del de `ElLobo`, sustituyendo a
      `PROBABILIDAD_EXITO`.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/sim/Contacto.gd`,
      `scripts/tests/TestIntercambio.gd`.
      **Verificable:** prueba —ser generoso sube la tasa, regatear la baja— .
      Segundos. **La confirmación en partida va en la pasada larga.**
- [x] **T3. Qué se ofrece, y que duela.** El fruto seco deja de estar clavado:
      la opción dice qué sale de la despensa, y sacarlo en invierno se nota.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/ui/`.
      **Verificable:** prueba sobre la despensa de las jornadas siguientes.
      Segundos.
- [x] **T4. Sílex, concha y gente, y las tres llegan.** Una prueba por cada
      una. **Antes de prometer nada hay que comprobar que `Materia.Kind.CONCHA`
      existe y que llegar gente tiene por dónde**; si no, se dice y se recorta.
      **Toca:** `scripts/sim/Intercambio.gd`, `scripts/economia/Materia.gd`,
      `scripts/tests/TestIntercambio.gd`. **Verificable:** tres pruebas. Segundos.

      > **T1–T4 HECHAS (2026-09-12), juntas porque viven en el mismo fichero.**
      > `Intercambio.gd` reescrito y `TestIntercambio.gd` también, 18 pruebas.
      > Suite **1 023 pruebas, 7 041 comprobaciones**.
      >
      > **Lo que hace ahora:** una vez por estación, si se conoce a alguien, se
      > **propone** con un `Moment` de kind `TRUEQUE` —nuevo—. La primera
      > opción es **no ir**: no decidir no puede costar nada, y las sondas
      > contestan con la primera opción, así que si fuera tratar, «sin decidir
      > nada, cero intercambios» haría tratos solo. Cada opción lleva **escrito
      > lo que cuesta**, que es media petición del frente 8. Ir saca a alguien
      > del mapa 4 jornadas —la misma marca que la expedición—, salga como
      > salga. La probabilidad sale del `trato` con esa gente y **se lee antes
      > de moverlo**, porque lo que recuerdan es lo de las veces anteriores.
      > Concha y gente llegan: la concha existía y la gente entra como en
      > `Relevo`, cuya regla del id libre sale a `Relevo.id_libre` porque ya la
      > preguntan dos.
      >
      > **Medido: 0,950 siendo generosos contra 0,080 regateando**, trescientos
      > intentos cada uno y misma semilla. **Y esa cifra exagera, dicho para
      > que no se lea mal**: en trescientos intentos seguidos el trato llega a
      > sus topes. En una partida se trata unas cuatro veces al año. La prueba
      > demuestra **la dirección**; la magnitud jugada la mide M1.
      >
      > **Una simplificación, dicha:** las cuatro decisiones de la spec darían
      > veintisiete combinaciones. Se ofrecen seis con sentido, siempre con la
      > contraparte de mejor trato. Si el juego pide elegir contraparte a mano,
      > se añade entonces.
      >
      > **El total bajó en 16 comprobaciones** respecto de la vuelta anterior
      > (7 057 → 7 041), y se dice: es exactamente `TestIntercambio`, de 652 a
      > 636, por reescribir una prueba cuyo comportamiento **se invierte a
      > propósito**. Dos de las pruebas viejas afirmaban «un intento por cada
      > estación» y «llega sílex al pasar estaciones», que es lo que la tanda
      > quita. Sigue por encima del suelo de la tanda (6 994).
      >
      > **Y dos pruebas pasaban en vacío, cazadas antes de cerrar:** en GDScript
      > **las lambdas capturan las variables locales por valor**, así que
      > `var propuestos := 0` con `propuestos += 1` dentro de la lambda contaba
      > sobre una copia. «Sin conocer a nadie no se propone nada» esperaba cero
      > y valía cero siempre, se propusiera o no. Ahora cuentan con un array y
      > llevan control positivo. Ver ARQUITECTURA §5.
      >
      > Las dos pruebas clave se comprobaron rompiendo el código: sin memoria de
      > la contraparte, generosos y regateando salen idénticos (0,573 y 0,573);
      > y si vuelve a tratar solo, en ocho estaciones trae 6 de sílex.

**El vestido** (frente 7) — no depende de nada, se puede hacer en paralelo:

- [x] **V1. El frío lo dicen los grados, no la estación.** Hoy `cold` sube sólo
      si es invierno **y** el hogar está apagado. Pasa a subir en función de
      `Termometro`, que es lo que hace que dormir al raso en enero no sea lo
      mismo que en julio —tercer criterio del frente— y de paso quita una regla
      del clima escrita fuera del termómetro.
      **Toca:** `scripts/sim/SettlementSim.gd` (~1786-1815),
      `scripts/tests/TestFrio.gd` (nuevo).
      **Verificable:** pruebas de estado construido —misma noche, dos
      estaciones, dos resultados—. Segundos. **Es el cambio con más riesgo de
      balance de la tanda.**
- [x] **V2. El frío cierra el roquedo.** Sin ropa buena, la salida al roquedo
      en invierno se rechaza, con motivo que el panel dice. Patrón:
      `TechTree.freno` / `TechTree.causa`.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/ui/`,
      `scripts/tests/TestFrio.gd`. **Verificable:** prueba de que se rechaza y
      de que el motivo llega. Segundos.

      > **V1 y V2 HECHAS (2026-09-12).** `SettlementSim.frio_por_hora` es la
      > única pregunta «¿cuánto enfría esta noche?» del juego, y la usan las
      > tres ramas de sueño —la cueva, el vivac y el que duerme donde le coge—.
      > `TestFrio`, 19 pruebas. Suite **1 042 pruebas, 7 087 comprobaciones**.
      >
      > **Premisa caída en V1: al raso no se cogía frío en NINGUNA estación.**
      > Dormir fuera sólo tocaba la fatiga. El tercer criterio del frente no
      > fallaba: no había nada que medir. Ahora sin hoguera se enfría por los
      > grados que haga, con hoguera se entra en calor.
      >
      > **La pendiente no se eligió:** está calibrada para que una madrugada de
      > invierno al nivel del mar dé exactamente el `HEARTH_COLD_RISE` de antes
      > (4,0/h), así que en ese punto el balance es el de siempre. Lo nuevo es
      > la altitud. **Comprobado en la escena real** con `FrioProbe`: una noche
      > sin fuego deja frío medio **0,00 en verano (13,0 °C en el abrigo) y
      > 30,52 en invierno (0,6 °C)**. Ese abrigo está a 135 m y enfría ~23 %
      > más que el «si es invierno» de antes: es el gradiente contando.
      >
      > **El umbral, 5 °C, es uno solo:** nació en la barra como
      > `GRADOS_QUE_MUERDEN`, una cifra de interfaz que sólo elegía un color, y
      > se mudó a `Termometro.GRADOS_DE_ABRIGO` en cuanto empezó a decidir la
      > partida.
      >
      > **Premisa caída en V2: el roquedo no existe como sitio en el código.**
      > Sólo aparece en dos comentarios. La salida a lo alto modelada es la
      > ascensión, y ahí va la puerta: `Cumbres.motivo_del_frio`, en los cuatro
      > caminos por los que se elige cumbre, junto a la de la cuerda. Sin
      > **un vestido por cada uno de la cordada** no se sube adonde de madrugada
      > se coge frío, y el motivo llega por `order_ascent`, que es lo que enseña
      > el panel. Una prueba recorre cinco cotas y cuatro estaciones y comprueba
      > que **la puerta se cierra exactamente donde la noche empieza a enfriar**.
      >
      > **Y es más fuerte de lo que pedía la spec, decidido así el 2026-09-12
      > con los números delante.** La spec decía «en invierno»; con la
      > madrugada como medida, sin abrigo se cierra: **en invierno, todo; en
      > primavera, por encima de 164 m; en otoño, de 580 m; en verano, de
      > 1 364 m**. Como la banda empieza en primavera sin ropa, **la primera
      > ascensión espera al verano o a que se cosan dos vestidos**, y las
      > ascensiones son las que revelan media comarca. Se ofreció mirar la media
      > del día —que abría la primavera hasta ~750 m— y se prefirió la versión
      > estricta, que hace la peletería urgente desde el primer día. **M1 dirá
      > si retrasa la fase de más.**
      >
      > Rompió una prueba de `TestExploration` que subía una cumbre sintética
      > de 300 m en primavera sin ropa. No se aflojó la puerta: se equipó a la
      > cordada en el montaje, porque esas pruebas van de subir y no de frío.

- [x] **V3. La cota de nieve sale del termómetro.** *(Añadida el 2026-09-12 a
      petición del usuario.)* Hoy `Temporada.COTA_DE_NIEVE` es **una fracción
      de la altura máxima del mapa local**, así que no depende del clima sino
      del mapa en que se esté: en un valle bajo pone la nieve bajísima y en los
      Picos altísima. Y es un segundo sistema describiendo el mismo frío que
      `Termometro`, sin hablarse. Pasa a ser la cota donde la media llega a
      0 °C: ~805 m en invierno, ~1 520 en primavera, ~1 930 en otoño, y por
      encima de los Picos en verano.
      **Toca:** `scripts/mundo/Temporada.gd`, `scripts/mundo/Termometro.gd`,
      `scripts/DemoMain.gd`, y lo que lea la cota —`TerrainGenerator.set_snow_line`,
      `Marcha` por `freno_por_nieve`—, `scripts/tests/`.
      **Verificable:** pruebas de la cota por estación y de que es absoluta,
      no fracción del mapa. Toca la vista y lo que cuesta andar, así que **va
      antes de M1** para que la pasada larga lo mida. Segundos.

      > **HECHO (2026-09-12), con la madrugada y no con la media.** La tarea
      > se planteó con la media a 0 °C y, al implementarla, salió que **en el
      > valle de partida no nevaría nunca**: el relieve va de 96 a 718 m y la
      > media de invierno hiela a ~805 m. Se preguntó con esa tabla delante y
      > se eligió la madrugada, que además es la misma hora que usa el frío de
      > la gente. `Termometro.cota_de_hielo` y `Temporada.fraccion_de`;
      > `COTA_DE_NIEVE` se borra. Suite **1 047 pruebas, 7 098 comprobaciones**.
      >
      > **Comprobado en la escena real** con `NieveProbe`: relieve 96–718 m;
      > **invierno 221 m, dentro del mapa**; primavera 933, otoño 1 349 y
      > verano 2 133, todas por encima de la cumbre. Antes la nieve de invierno
      > empezaba a 357 m.
      >
      > **Por qué la de antes era tan baja:** salía del Dryas reciente, que es
      > más frío que el 12 000 a.C. en que se fijó la época.
      >
      > **Dos pruebas de `TestSubsistence` montaban `Temporada` sin relieve** y
      > se pusieron rojas: sin relieve no se sabe dónde cae la nieve y no nieva.
      > Se les dio el del valle, y eso mismo destapó por qué había que
      > comprobarlo en la escena: el caso borra la nieve en silencio.
      >
      > **Y un efecto de balance que M1 va a notar:** el abrigo está a 135 m y
      > la nieve de invierno empieza a 221, así que **en invierno casi cualquier
      > salida cuesta arriba anda por nieve**, y `freno_por_nieve` frena la
      > marcha más que antes.

**Las decisiones** (frente 8) — depende de T1 para contar el trueque:

- [x] **D1. Un `Moment` declara lo que cuesta cada opción.** Hoy `options` es
      libre y **el criterio no se puede medir**: «cuenta sólo si la opción no
      elegida cambia una cifra» necesita que la cifra esté escrita.
      **Toca:** `scripts/banda/Moment.gd`, quien levante momentos,
      `scripts/tests/TestMoment.gd`. **Verificable:** prueba. Segundos.
- [x] **D2. Una decisión fija por estación.** Cuatro al año que no se pueden
      evitar. Las que dispare el estado van encima, **sin inflar el
      calendario** para llegar a un número.
      **Toca:** `scripts/sim/`, `scripts/tests/`. **Verificable:** prueba de
      que cada estación levanta la suya. Segundos.

      > **HECHO (2026-09-12). Las tres que no eran la berrea las eligió el
      > usuario** entre las que se le propusieron, y las tres salen de sistemas
      > que ya existían:
      >
      > | Estación | Decisión | Cuesta |
      > |---|---|---|
      > | Primavera | ¿se sale del valle? — `Expedicion.proponer_la_salida` | 36 jornadas y 72 raciones |
      > | Verano | ¿se sube ahora que no hiela? — `Cumbres.proponer_la_subida` | riesgo de la ascensión |
      > | Otoño | la berrea | 15 jornadas por cazador |
      > | Invierno | ¿cuánto fuego? — `Hogar.proponer_el_fuego` | la mitad de las noches sin fuego |
      >
      > Una prueba cuenta **las cuatro en un año**, y otra que la opción 0 de
      > todas no compromete a nada. Suite **1 071 pruebas, 7 148
      > comprobaciones**.
      >
      > **Tres cosas de las que conviene enterarse:**
      >
      > - **La de primavera es el botón que la expedición no tenía.** Hasta hoy
      >   `Expedicion.mandar` sólo se llamaba desde código.
      > - **La del fuego está hecha para costar en las dos direcciones.** El
      >   fuego de este juego es binario, así que si racionar sólo gastara
      >   menos, siempre convendría. Racionado es **una noche con fuego y otra
      >   sin él**: la mitad de leña, y la noche sin fuego se pasa el frío de V1
      >   entero. Ninguna cifra de calor inventada. La cueva pregunta ahora
      >   `Hogar.calienta_esta_noche()`, no `hearth_lit`.
      > - **La berrea estaba al revés** —«volcarse» era la opción 0— y por eso
      >   **seis sondas** la contestaban con la opción 1 como caso aparte:
      >   `TironAnualProbe`, `AnoProbe`, `ArbolPasoProbe`, `CuelgueProbe`,
      >   `DecisionProbe` y `RitmoProbe`. Se puso en orden y se quitó la
      >   excepción de todas, **porque si se hubiera dejado en una sola, esa
      >   sonda habría pasado a volcarse en la berrea sin avisar** —y `AnoProbe`
      >   es la de M1—.
      >
      > **Y un tropiezo con la herramienta:** llamar `proponer()` a los cuatro
      > métodos subió `LlamadasHuerfanas` de 2 a 10 —cruza nombres sin mirar el
      > receptor—. Se les dio nombre propio a cada uno y volvió a 2.
      >
      > **Y un hueco que destapó la prueba de humo de M1, antes de lanzarla:**
      > la partida empieza **ya dentro de la primavera**, y las decisiones de
      > estación saltan al *cambiar* de estación. Así que **la de primavera del
      > primer año no salía nunca**: la primera expedición esperaba al año 2 y el
      > primer año tenía tres decisiones, no cuatro. Ahora la de la estación en
      > curso sale también en `SettlementSim.iniciar_partida()`, desde un solo
      > sitio —`_decision_de_la_estacion`—, con prueba. Se arregló **antes** de
      > lanzar la pasada larga, que es la lección de ayer: con una medida en
      > vuelo no se toca el código.
- [x] **D3. La berrea deja de ser gratis.** Volcarse significa que ese mes no
      se recolecta ni se hace leña.
      **Toca:** donde viva la berrea, `scripts/tests/`. **Verificable:** prueba
      sobre las raciones de ese mes. Segundos.

      > **D1 y D3 HECHAS (2026-09-12)**, en `scripts/tests/TestDecisiones.gd`
      > —13 pruebas— y no en un `TestMoment` como decía el plan: son el mismo
      > frente. Suite **1 060 pruebas, 7 122 comprobaciones**.
      >
      > **D1.** Cada opción declara `"cuesta"` en las tres cifras de la spec
      > —despensa, jornadas, riesgo— con `Moment.opcion`, y
      > `Moment.la_eleccion_importa()` dice si al menos dos cuestan distinto.
      > Dos botones con el mismo coste **no cuentan como decisión**, con prueba.
      > El trueque y la berrea ya declaran lo suyo; la piel ofrecida no cuenta
      > en la despensa porque no se come.
      >
      > **D3, y con un fallo de verdad debajo.** Volcarse ponía la caza mayor a
      > **prioridad 3, que en este reparto es la menos urgente** —van de 1 a
      > 3—, así que quien tuviera recolección a 1 o 2 seguía recolectando y
      > volcarse casi no hacía nada. La opción prometía «se dejan de hacer otras
      > cosas: es la apuesta» y el código no lo cumplía. Ahora, durante
      > **un mes del juego** (`Subsistence.DAYS_PER_MONTH`, 15 jornadas, porque
      > la spec dice «ese mes»), la caza mayor a 1 y **la recolección entera
      > apagada** para quien va; al acabar, **cada uno recupera exactamente sus
      > prioridades de antes**. La tarjeta dice cuántas jornadas no se recogen.
      > Comprobado rompiéndolo: si no se apaga la recolección, caen tres pruebas.
      >
      > **Lo que falta del criterio, dicho:** «se ve en las raciones
      > recolectadas de ese mes» es cifra jugada, y la mide M1.

**El cierre de la fase:**

- [x] **C1. Las tres condiciones, no una.** `Partida.evaluar_victoria` pasa a
      pedir cueva pintada **más** expedición mandada **más** puntos regionales
      nuevos. Depende de E3.
      **Toca:** `scripts/sim/Partida.gd`, `scripts/tests/TestPartida.gd`.
      **Verificable:** prueba de que **con dos no se cierra**. Segundos.

      > **HECHO (2026-09-12).** `Partida.evaluar_victoria` pide cueva pintada
      > **y** `expedicion_mandada()` **y** `puntos_nuevos()`, y
      > `lo_que_falta_para_cerrar()` dice cuáles faltan. Suite **1 074 pruebas,
      > 7 154 comprobaciones**.
      >
      > La prueba vieja se llamaba «banda viva y cueva pintada gana», que es
      > literalmente la regla que esto sustituye, y **se reescribió en vez de
      > borrarse**. La nueva recorre las tres maneras de tener dos de tres y
      > comprueba que ninguna cierra, que es el criterio explícito. Y una más:
      > **mandar la expedición y que vuelva de vacío no basta** —cuenta para la
      > segunda condición y no para la tercera—.
      >
      > De paso se quitó un `capturados[0]` que reventaba si no salía la
      > tarjeta: una prueba que revienta antes de su assert no falla, pasa.

**Lo que se mide, y es donde está el dinero:**

- [x] **M1. La pasada larga, una sola, con seis contadores.** Dos años
      simulados con la noche acelerada, instrumentados para contestar de una
      vez: que el desenlace llega y **tarda entre año y medio y tres años**;
      que en el primer año sin decidir nada hay **0 intercambios**; **cuántas
      decisiones** de las que cuestan caen al año; **cuánto sube** la cuenta de
      `Site` descubiertos por expedición y qué cuesta; la tasa de éxito del
      trueque siendo generoso; y **la caza vuelta a medir**, que es el 0,27 de
      ESTADO.md §2 que nadie ha tocado desde que se abrieron las puertas del
      asta y la punta lítica.
      **Toca:** `scripts/tests/BandaProbe.gd` o sonda nueva, ESTADO.md §2.
      **Corrida larga: ~1 h 55.**

      > **PRIMERA PASADA PARADA a la jornada 46 (2026-09-13), y era la sonda.**
      > El vigía decía «expediciones 0» entrado el verano con un jugador que
      > manda la expedición en primavera. **No se había contestado ninguna
      > decisión.** La primera tarjeta de la partida —«Un abrigo, una banda»— es
      > un aviso sin opciones, y `AnoProbe` sólo contestaba tarjetas *con*
      > opciones: se quedaba parada delante, y todas las decisiones del año se
      > apilaban detrás sin enseñarse. **Cinco sondas de seis tenían el mismo
      > agujero** (Año, ArbolPaso, Cuelgue, Ritmo y FrioInvierno); sólo
      > `TironAnualProbe` cerraba los avisos. Así que toda cifra de esas sondas
      > que dependa de una decisión, **desde que existe el aviso inicial**, se
      > midió con las decisiones sin contestar. Arreglado **en un sitio y no en
      > seis**: `BarraSuperior.contestar_todo(elige)` contesta las decisiones y
      > cierra los avisos, y las seis sondas lo llaman.
      >
      > **Y un fallo de verdad que salió al mirar:** `Expedicion.mandar` sacaba
      > de la despensa lo que hubiera y *después* veía que no llegaba; la
      > expedición no salía y la comida desaparecía igual. Ahora mira antes de
      > sacar, con su comprobación en `TestExpedicion`.
      >
      > **Prueba de humo antes de relanzar**, 14 jornadas y 4 min 30: con el
      > jugador razonable la expedición sale la primera jornada (36
      > jornadas-persona) y vuelve con **4 sitios descubiertos**; a la fase ya
      > sólo le falta la cueva pintada. Suite: 1 075 pruebas, 7 156
      > comprobaciones. Relanzada con M2 delante.

      > **MEDIDA (2026-09-13), y los criterios NO se cumplen.** 1 h 52,
      > `SEMILLA=42 JUGADOR=razonable DIAS=360`. **La banda muere de hambre en la
      > jornada 359**, sin cerrar la fase (falta la cueva pintada). **4 decisiones
      > que cuestan cada año**, lo único que sale como pedía. **1 expedición** (4
      > sitios, 36 jornadas-persona): la del año 2 se decidió y no salió porque
      > la primavera empieza con la despensa a cero. **0 tratos** en dos años:
      > sólo el destino de la expedición deja contacto y 4 de cada 5 sitios están
      > vacíos. **Caza 1,88** por persona y día, no comparable a pelo con el 0,98.
      > La causa de fondo no es de esta tanda: la despensa sin cestos no pasa de
      > ~600 raciones y el invierno pide ~1 140. Cifras y lectura en ESTADO §2,
      > «Dos años con un jugador que decide». **Qué hacer con ello lo decide el
      > usuario.**
- [x] **M2. El frío, la pareja.** Dos corridas con la misma semilla, una
      haciendo ropa y otra no: en la que no, alguien enferma o muere de frío.
      **Toca:** sonda, ESTADO.md §2. **Corrida larga: ~56 min con un invierno,
      ~2 h 22 con los dos que pide la spec.**

      > **PRIMERA PASADA INVÁLIDA (2026-09-13), y se dice por qué.** Se construyó
      > «el último día de otoño» con `scripts/tests/FrioInviernoProbe.gd`, como
      > se decidió para no simular tres estaciones. Resultado: **la banda entera
      > muerta en 22 jornadas sin ropa y en 18 con ropa, y nadie enfermó de
      > frío.** Murieron de hambre.
      >
      > **Se construyó sólo el calendario.** La despensa era la del primer día de
      > primavera, y una banda llega al invierno con lo que ha recogido en tres
      > estaciones, no con lo que traía. Los muertos no enferman de frío, así que
      > el hambre tapó la pregunta entera. La regla de ARQUITECTURA §5.1 —«un
      > estado lejano se construye»— sigue en pie; lo que falló es construir
      > **la mitad** del estado.
      >
      > **Decidido por el usuario: llenar la despensa para aislar el frío.** Se
      > rellena cada día —tiene tope por cestos y odres, y parte se pudre—, y el
      > agua también, y la sonda dice de qué muere cada uno. Aplicado el
      > 2026-09-13, al parar M1 (ver arriba), y relanzada. Aviso de lectura: con el fuego encendido en la cueva puede salir
      > que nadie enferma ni con ropa ni sin ella, y eso sería un hallazgo, no un
      > fallo de la prueba.

      > **MEDIDA (2026-09-13): fue el hallazgo, no el fallo.** 15 min por brazo.
      > Con ropa y sin ella, **16 vivos, 0 enfermos, 0 muertos de frío y frío
      > medio 0,0**. En la cueva con el fuego encendido cada noche quita frío, y
      > el vestido sólo cuenta durmiendo sin fuego. **El criterio «sin ropa
      > alguien enferma» no se cumple en el invierno en casa**; el vestido manda
      > fuera del fuego (cumbres, vivac, fuego racionado). ESTADO §2, «El
      > invierno en la cueva». **Qué hacer con ello lo decide el usuario.**
- [x] **M3. Cerrar.** Suite verde y **≥ 6 994 comprobaciones**,
      `LlamadasHuerfanas` sin huérfanas nuevas, y lo aprendido a SISTEMAS §4,
      §5 y §19, INTERFAZ §4, SPECS §4.4 y ESTADO §2 y §3.

      > **HECHO (2026-09-13).** Tres decisiones del usuario con M1 y M2 delante:
      > el hambre del invierno va por `/depurar` y no se parchea aquí; la ropa se
      > acepta como hallazgo y se reescribe el criterio; y **la primera
      > expedición siempre encuentra gente** (`Contacto.poblar` desde
      > `Expedicion._volver`, con `test_la_primera_expedicion_siempre_encuentra_gente`
      > y la de «un sitio vacío» pasada a la segunda expedición). Suite **1 076
      > pruebas, 7 161 comprobaciones**; `LlamadasHuerfanas` en las 2 de siempre.
      > El trueque **no se ha vuelto a medir** con el cambio: una pasada de año
      > no vale mientras la banda no pase el segundo invierno.

**Presupuesto de máquina: ~2 h 51, decidido el 2026-09-12** — M1 entero, que
es el que cierra la fase y no se puede recortar, y M2 con **un solo invierno**:
si con uno ya enferma alguien, el segundo no añade nada. En
serie, Godot es de uno en uno. **Todo lo demás son pruebas de segundos**, y eso
es deliberado: catorce de las diecisiete tareas se comprueban sin simular nada.

**La medida se ha juntado a propósito**: M1 es **una sola corrida** que
contesta seis preguntas de cuatro frentes distintos. Por separado serían cinco
corridas y más de cinco horas.

**Orden acordado el 2026-09-12: el frente 5 primero (E1–E4) y se enseña antes
de seguir.** Es la mitad de la tanda y todo lo demás cuelga de ella; verla
funcionando antes de montar el trueque encima evita rehacer trabajo.

**Qué se puede repartir:** V1–V2 (el frío) no dependen de nada y tocan ficheros
distintos de E1–E4 y T1–T4; pueden ir en paralelo con otro agente. **T1–T4
dependen de E2 y E4**, y **dos medidas nunca a la vez.**
### ~~Tanda 4: las cuevas, el mapa regional, la sepultura y los otros~~ — cerrada

> **Cerrada el 2026-09-13.** Las veintidós tareas hechas. Lo que salió distinto
> de lo planeado, en corto: **la cueva costó veinte vueltas de captura** con el
> usuario mirando y acabó siendo un agujero en el propio terreno con un techo de
> roca, no un modelo; **la lámpara ya existía** como útil y se creó dos veces por
> un momento; **las máscaras de la frontera estaban horneadas contra otro
> relieve**; y la sonda de variedad pilló situaciones repetidas por las ramas. Lo
> pendiente: medir el fotograma con las cuevas nuevas, decidir si la tarjeta de
> trueque de siempre se retira ahora que está la ventana, el traslado de
> campamento sin construir, y los dos `/depurar` de siempre —las casillas del
> árbol de técnicas y los «sin camino»—.

**Spec escrita (2026-09-13) en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1 → Tanda 4**, frentes 18 a 27, cada uno con sus criterios. Sale de la lista
del usuario tras jugar la tanda 3.

En corto: el mapa regional sin sitio de prueba, con la frontera hasta la costa de
−120 m, la ficha de cada sitio descubierto y ventanas que caben; el hogar en
cuatro horas; el abrigo es el taller sin botón, y trasladarse sólo a cuevas
libres; una cueva que se ve y que nunca cae en el agua; **explorar una cueva**
con lámpara y grasa, dos o tres decisiones de un repertorio de treinta, riesgo
de verdad, y una de cada tres pintable; pintar sólo lo explorado; humo en los
fuegos; **el trueque como el almacén** con precios que mueve la relación; una
ventana de relaciones; y **la sepultura**.

**Ya arreglado el mismo día por `/depurar`, antes de la spec:** «F» en el mapa
regional funda de nuevo —ahora se entra al mapa y cada mapa guarda su estado—, la
suite borraba el guardado real del jugador, y la batida no practicaba
exploración.

**Depende de dos fallos por `/depurar`**: las casillas del árbol de técnicas que
no se rellenan, y los «sin camino» que no se reprodujeron.

**Coste de máquina:** pruebas de segundos, capturas con ventana, y una sonda de
variedad de cuevas que no juega jornadas. Nada pide un año.

**Plan técnico en EPOCA_01 §10.1**, «Plan técnico de la tanda 4», con tres
premisas que no se sostienen: las acciones del abrigo son de mentira, la frontera
se para por un tope de 60 km y no por el agua —y no queda herramienta para
hornearla—, y no hay ánimo ni cohesión en que pueda contar la sepultura. Lista
colgada por `/plan-tarea` el 2026-09-13 por `history-of-man-11`.

**Suelo de la suite al abrir: 1 167 pruebas, 7 372 comprobaciones.**

**Decidido por el usuario el 2026-09-13:** todas seguidas en este orden; la
sepultura se nota en **un duelo** que rinde menos y que la despedida acorta; y
«trasladar el campamento» se oculta en la cueva de la banda y queda apuntado como
no construido.

**Lo barato primero**

- [x] **H1. El hogar en cuatro horas.** **Toca:** `sim/CampProjects.gd`,
      `tests/TestCampProjects.gd`. Prueba, segundos.

  > **HECHO (2026-09-13).** `labor_hours: 4.0` en la entrada del hogar, y
  > `labor_days` la convierte con `SettlementSim.HORAS_UTILES` (11), así que las
  > demás obras siguen en jornadas. Dos cosas que no estaban en el plan: **el
  > hogar no lo acelera la pericia** —si no, el criterio de «cuatro sí, tres no»
  > sólo se cumplía para uno de rendimiento 1—, y **las ventanas lo escribían
  > «0 jornadas»** (`PanelTecnicas`, `CensoDeObras`), que ahora pasan por
  > `CampProjects.trabajo_texto`. Y un margen de coma flotante al comparar: 16
  > cuartos de hora sumados no dan 4/11 exactos. Tres pruebas nuevas en
  > `TestCampProjects` (cuatro horas sí y tres no a cachos de un cuarto; con
  > hambre también en cuatro; el texto). Suite **1170 pruebas, 7 377
  > comprobaciones**, huérfanas 0.
- [x] **A1. El abrigo es el taller.** Fuera «taller»; «trasladar» sólo en
      cuevas que no sean la de la banda. **Toca:** `ui/PanelSitios.gd`,
      `DemoMain.gd`, `tests/`. Prueba, segundos.

  > **HECHO (2026-09-13).** `PanelSitios._actions_for` pasa a estática y recibe
  > si la cueva es la de la banda; `DemoMain` se lo dice comparando con
  > `_cave_at(sim.home_position)`, que es la misma pregunta con la que
  > `_levantar_hogar` elige la cueva de casa. La rama «taller» de
  > `_on_cave_action` se fue. `TestAbrigo`, tres pruebas. **Sigue sin haber
  > traslado de campamento**: el botón existe en las cuevas libres y sólo
  > imprime una línea, como decía ESTADO §4 — la tanda no lo construye.
- [x] **R1. Fuera Torrelavega.** **Toca:** `region/RegionMap.gd`, `tests/`.
      Segundos.

  > **HECHO (2026-09-13).** Fuera `dev_sites`, `DEV_PLACES`, `_add_dev_sites`,
  > el color magenta y el trato aparte en la niebla. **Medido: no había ninguno
  > horneado** en `cantabria_sites.res` —869 sitios, ninguno con id de 9000
  > arriba—, así que el comentario de `TestNiebla` que atribuía a los de prueba
  > la diferencia con los 862 de los documentos era falso y se corrigió. Prueba
  > nueva en `TestNiebla`. Quedan en disco `data/dem/local/site_9000*.res`
  > (sin versionar) y `RunLocalTiming`/`DatoProbe` que los leen: son
  > herramientas de medida de carga, no el juego. De paso se quitó un
  > `field.free()` sobre un `RefCounted` en `TestParajes` que soltaba un
  > SCRIPT ERROR en cada pasada. Suite **1 174 pruebas, 7 385 comprobaciones**,
  > huérfanas 0.

**21 · La cueva**

- [x] **C1. Ninguna boca donde no se llega.** Validación al colocar, en un solo
      sitio, moviendo al punto válido más cercano; sonda por los nueve mapas.
      **Toca:** `DemoMain.gd`, `tests/CuevasProbe.gd` (nueva), `tests/`.
      **~5 min.**

  > **HECHO (2026-09-13).** `mundo/Bocas.gd` decide dónde se abre cada boca:
  > en seco y unida a casa, o al punto bueno más cercano en anillos de 10 m.
  >
  > **Dos premisas del plan se cayeron.** La primera: no podía ir en
  > `_place_site_features`, porque la entalladura se excava en el relieve
  > ANTES de generarlo y la rejilla sólo existe DESPUÉS; mover la boca ahí
  > dejaba el hueco en el sitio viejo (ya pasaba con `_nudge_out_of_water`,
  > que se ha borrado). Va dentro de `TerrainGenerator`, entre el relieve y la
  > excavación (`colocar_las_bocas`), con lo colocado guardado en la caché
  > (`carvings_colocadas`, versión 3) y las reglas en la clave
  > (`Bocas.REGLAS`) — sin eso, la segunda medida cargó las bocas de la
  > primera. La segunda: **no hay nueve mapas horneados, hay uno** —el 56—;
  > `site_9000` era Torrelavega y ya no es un sitio. Los demás se hornean al
  > entrar desde el mapa regional, con descarga del IGN, y pasan por la misma
  > colocación.
  >
  > **Medido con `CuevasProbe`**, que entra en cada mapa como el mapa
  > regional y pregunta a la rejilla DE LA PARTIDA: **9 bocas, 4 movidas**
  > (10, 20, 30 y 50 m) y **ninguna mal colocada**. La primera versión pedía
  > además que la celda de la boca se anduviera y movió 8 de 9, sacándolas de
  > la pared: una ladera de cuevas sale cerrada por pendiente. Se quitó; la
  > sonda sigue enseñando esa columna. Coste: la caché del terreno se rehace
  > una vez por sitio (14 s en el 56) y la rejilla de colocar son ~900 ms más
  > sólo cuando no hay caché. `TestBocas`, cuatro pruebas sobre `FakeTerrain`.
  > Suite **1 178 pruebas, 7 395 comprobaciones**, huérfanas 0.
  >
  > **Y dos reglas más, con el usuario viendo las capturas de C2:** la boca
  > sacada del agua va **hacia la orilla con pendiente** —entre los puntos
  > buenos hasta el doble de la distancia del primero, 40 m como poco, el de más
  > cuesta—, y pide seco **todo el corro que se excava**, no sólo el centro: la
  > Cueva del Fósil quedaba en la orilla con el río dentro del hueco. Con eso y
  > las entalladuras de C2, `CuevasProbe` da **9 bocas, 6 movidas (20 a 70 m),
  > ninguna mal colocada**. `TestBocas`, seis pruebas.
- [x] **C2. Una cueva en la pared.** **Toca:** `vista/CaveMouth.gd`.
      **Capturas, ~3 min.**

  > **HECHO (2026-09-13).** La cueva es **un agujero en el terreno** —una sima de
  > 2 m de boca y 50 m de hondo, con la rejilla del relieve recortada y un
  > embudo fino cosido en su sitio— **con un techo de roca en herradura** que la
  > cubre por la pendiente y los costados y deja libre la entrada. Detalle en
  > GRAFICOS.
  >
  > **No fueron tres minutos de capturas: fueron veinte vueltas con el usuario
  > mirando**, y tumbó cuatro modelos enteros por el camino (visera de caliza,
  > cámara abovedada, túnel con marco, cantos sueltos) antes de decir qué
  > quería. Lo que hay que saberse de aquí, porque cada uno costó una vuelta:
  > el parche del terreno necesita la normal y la tangente del campo de alturas;
  > una malla sin tangentes no puede llevar mapa de normales; las texturas del
  > terreno vienen comprimidas y hay que descomprimirlas para una `ImageTexture`;
  > y la caché de la malla necesita las reglas de la sima en su clave.
  >
  > `CuevaCaptura.gd` nueva, con cámara propia —la del juego no baja de ~100 m y
  > a esa distancia no se juzga un modelo de dos metros—. **Fotograma sin
  > medir**; el catálogo trae la Cueva del Fósil **dos veces** en el mismo sitio
  > («fosil» y «Fosil»), que es dato del conjunto y no se ha tocado. Y de paso:
  > **ningún recurso a menos de 30 m de una boca** (`ResourceProps`), que una
  > mata delante tapaba la entrada.

**22–23 · Explorar y pintar**

- [x] **E1. Explorar una cueva: la orden y el estado.** Persona del hogar,
      lámpara, grasa, una jornada; explorada y pintable (1 de 3, la de la banda
      siempre). **Toca:** `sim/` (nuevo), `sim/SettlementSim.gd`, `tests/`.
      Segundos.

  > **HECHO (2026-09-13).** `sim/Exploracion.gd`, colgado de la simulación.
  > `lo_que_falta()` contesta con una frase —lámpara, grasa, alguien del hogar—
  > y es lo que enseñará la orden; `mandar()` cobra la grasa y mete a alguien
  > dentro; la exploración se cierra al acabar el día, **antes del reparto de
  > práctica**, para que la jornada cuente como oficio de hogar. Lo pintable sale
  > de la semilla, una de cada tres, con azar propio que no toca el `_rng` de la
  > simulación (SPECS §7), y la cueva de la banda siempre.
  >
  > `TestExploracion`, ocho pruebas. Suite **1 188 pruebas, 7 437
  > comprobaciones**.
  >
  > **Corregido el mismo día, en P1**: se creó una lámpara como obra de
  > `CampProjects` porque EPOCA_01 §8 decía que faltaba, y **ya existía como
  > útil** (`Tool.Kind.LAMPARA`), el que pide la pintura. Dos respuestas a la
  > misma pregunta; se quitó la obra y la exploración pide el útil. Bajan tres
  > comprobaciones —las que la prueba de proyectos hacía sobre la obra
  > quitada—.
- [x] **E2. El repertorio: 30 situaciones o más, con ramas.** Datos, sin repetir
      en una cueva ni empezar igual dos seguidas. **Toca:** `sim/` (nuevo),
      `tests/`. Segundos.

  > **HECHO (2026-09-13).** `sim/Repertorio.gd`: **34 situaciones**, 26 que
  > pueden abrir una visita y 8 que sólo salen por la rama de otra, cada una
  > con sus opciones y lo que desatan (nada, hallazgo, susto, herida, peligro,
  > pared pintable). El oso del usuario va entero, rama por rama. `visita_de()`
  > sortea dos o tres por cueva con azar propio de la semilla y la cueva, sin
  > repetir y sin abrir como la cueva anterior. `TestRepertorio`, ocho pruebas.
  > Suite **1 196 pruebas, 7 576 comprobaciones**.
- [x] **E3. Las decisiones y lo que pasa.** `Moment` en cadena, heridas por
      `Percances`, muertes por `_person_dies`. **Toca:** el subsistema,
      `tests/`. Segundos.

  > **HECHO (2026-09-13).** Al entrar, `Exploracion` cita la primera situación
  > como un `Moment` nuevo, `Kind.CUEVA`, y cada opción, al elegirse, aplica lo
  > suyo y sigue por su rama o con la siguiente de la visita. Hallazgo deja ocre,
  > sílex o asta en el almacén; herida, tres días; peligro, en quintos: uno mata
  > —por `_person_dies`, el único camino de muerte—, dos hieren ocho días y dos
  > salen bien. **No se usó `Percances`**: aplica percances de marcha al aire
  > libre (dejar la carga, volverse), y aquí basta con los días de herida. Azar
  > propio de semilla, cueva, situación y opción. El aviso de cada opción dice el
  > aire que tiene, no el desenlace.
  >
  > Dos cosas que salieron al probar: morir el único de la banda cita además la
  > derrota, que no es de la visita; y la herramienta de huérfanas confundía
  > `elegir` con el de la barra superior, así que el método es `decidir`. Cinco
  > pruebas más en `TestExploracion`. Suite **1 201 pruebas, 7 587
  > comprobaciones**, huérfanas 0.
- [x] **E4. La sonda de variedad.** 50 cuevas, sin jugar jornadas.
      **Toca:** `tests/` (sonda nueva). **~2 min.**

  > **HECHO (2026-09-13).** `CuevasVariedadProbe.gd`, sin escena y en segundos,
  > eligiendo opciones con un azar fijo. **Cumple todo**: 50 cuevas, todas con
  > 2 o 3 situaciones, ninguna repite dentro, ninguna abre como la anterior,
  > **32 de las 34** situaciones del repertorio aparecen, **16 salen heridos y
  > 4 no salen**, y **35 de 90 cuevas son pintables**.
  >
  > **La primera pasada pilló un fallo de verdad**: dos cuevas repetían una
  > situación, porque una rama llevaba a otra que la visita ya tenía sorteada
  > para después. `Exploracion` lleva ahora lo visto en cada visita y se lo
  > salta. Y la sonda misma contaba mal los muertos —miraba si la banda quedaba
  > vacía, con dos personas— y daba cero. Lo pintable se probó con esta semilla
  > aquí y con otra en `TestExploracion`.
- [x] **E5. El botón de explorar hace lo que dice.** **Toca:** `DemoMain.gd`,
      `ui/PanelSitios.gd`. Prueba.

  > **HECHO (2026-09-13).** «Explorar el interior» llama a
  > `Exploracion.mandar`; ya no revela el entorno de golpe. Si no se puede, el
  > botón sale **apagado con lo que falta** en el aviso
  > (`PanelSitios.por_que_no`), y la ventana dice, si ya se exploró, si tiene
  > pared donde pintar. Cada `CaveMouth` lleva su `id` —el índice en el
  > catálogo— y la de casa se apunta como `cueva_de_la_banda`. El estado viaja
  > con la partida sin tocar nada: `Instantanea` recorre las propiedades de la
  > simulación, así que se quitaron los dos métodos de guardado que se habían
  > escrito para esto. Dos pruebas en `TestAbrigo`. **Sin ver en pantalla
  > todavía**: va en las capturas de R5. Suite **1 203 pruebas, 7 590
  > comprobaciones**, huérfanas 0.
- [x] **P1. Sólo se pinta lo explorado y pintable.** **Toca:** `sim/Pinturas.gd`,
      `tests/`. Segundos.

  > **HECHO (2026-09-13).** `Pinturas.painting_blocked_by` pide la cueva de la
  > banda explorada y con pared, y lo dice. Va **después** de la lámpara, el
  > ocre y la grasa, que es lo que se junta primero y lo que las pruebas viejas
  > de `TestRelato` ya comprobaban por su mensaje; su preparación da ahora la
  > cueva por explorada. Tres pruebas en `TestExploracion`. **Consecuencia en la
  > partida**: para cerrar el año con la cueva pintada hay que haberla
  > explorado antes. Suite **1 206 pruebas, 7 590 comprobaciones**.

**27 · La sepultura**

- [x] **S1. La despedida.** Tres opciones con coste al morir alguien. **Toca:**
      `sim/SettlementSim.gd`, `sim/` (nuevo), `tests/`. Segundos.
- [x] **S2. Lo que deja.** Crónica, relato, y lo que nota la banda (pendiente de
      decisión); el hito de la primera con ajuar. **Toca:** el subsistema,
      `tests/`. Segundos.

  > **HECHOS (2026-09-13), juntos.** `sim/Sepulturas.gd`, enganchado al único
  > camino de muerte (`_person_dies`), que ahora pregunta —salvo si era el último
  > de la banda: entonces es la derrota—. Tres despedidas: **dejarlo** (nada, 6
  > días de duelo), **cubrirlo** (4 de piedra, 4 días) y **enterrarlo con
  > ajuar** (4 de piedra, 1 de ocre y 2 conchas, 2 días). La tarjeta escribe el
  > coste y el duelo, y apaga lo que no se pueda pagar con lo que falta.
  >
  > **El duelo** es lo que decidió el usuario: toda la banda rinde un 15 % menos
  > esos días (`Inhabitant.duelo_dias`, dentro de `effectiveness`). **Las cifras
  > —días, 15 %, cantidades— son decisión, no medida**, que es lo que la spec
  > pedía decir. El «coste en jornadas» de la spec se paga así, en rendimiento
  > de la banda, y no como gente apartada del trabajo: no hay en el código un
  > sitio donde apartar a alguien un día sin tocar el reparto.
  >
  > Cada despedida se cuenta distinta en la crónica; las dos que dejan tumba la
  > apuntan con su sitio; y la **primera con ajuar es el hito**, contado como
  > relato `HITO` —el mismo camino que usa el lobo—, así que se puede pintar.
  > `TestSepulturas`, siete pruebas. Suite **1 213 pruebas, 7 610
  > comprobaciones**, huérfanas 0.
- [x] **S3. Se ve sobre el terreno.** **Toca:** `vista/` (nuevo), `DemoMain.gd`.
      **Captura, ~3 min.**

  > **HECHO (2026-09-13).** `vista/SepulturasView.gd`: un túmulo de nueve
  > piedras facetadas con la roca del terreno donde se cubrió a alguien, y el
  > mismo con una losa de ocre encima donde se le enterró con ajuar. Sólo lee
  > `Sepulturas.tumbas` y se rehace cuando hay una nueva, como las pasarelas.
  > Captura con `SepulturaCaptura.gd` (`user://sepultura.png`): se leen como
  > montones de piedra en la ladera, junto a la banda. **Tres capturas antes
  > de la buena por culpa de la sonda**: buscando seco a mano las ponía en el
  > río; la definitiva las pone en la campa de la boca.

**25–26 · El trueque y las relaciones**

- [x] **T1. Precios y la regla del 10 %.** **Toca:** `sim/Intercambio.gd`,
      `tests/TestIntercambio.gd`. Segundos.

  > **HECHO (2026-09-13).** `Intercambio` gana `PRECIO`, en puñados de fruto
  > seco: **fruto seco 1, sílex 2 y concha 3 salen de los tratos que ya
  > existían** (6 por 3 y 6 por 2); ocre, piel, asta, grasa, piedra y leña son
  > decisión, y lo que no está vale 1. La relación multiplica lo que da la banda
  > y divide lo que traen ellos (`factor_con`, 1 + trato / 200, entre 0,5 y 2),
  > así que el efecto se nota por los dos lados. `se_acepta` aplica el 10 % y
  > `cambiar` mueve el almacén exactamente, apunta el trato en `historial` —lo
  > leerá la ventana de relaciones— y lo cuenta como trato justo. Cuatro pruebas
  > en `TestIntercambio`; la primera versión de una tenía la cuenta mal hecha
  > —olvidaba que el factor actúa a los dos lados—. Suite **1 217 pruebas,
  > 7 621 comprobaciones**, huérfanas 0.
- [x] **T2. La ventana de trueque.** **Toca:** `ui/` (nuevo), `ui/GameUI.gd`,
      `tests/`. Prueba y **captura, ~3 min.**
- [x] **L1. La ventana de relaciones.** **Toca:** `ui/` (nuevo), `ui/GameUI.gd`,
      `tests/`. Prueba y **captura, ~3 min.**

  > **HECHAS (2026-09-13), juntas.** Dos botones nuevos en la barra de abajo,
  > «Trueque» y «Relaciones». `PanelTrueque`: lo de la banda a la izquierda y lo
  > que traen a la derecha, con − y + por material, lo que vale cada lado para
  > ellos y para nosotros, y «Cerrar el trato» apagado mientras no compense —con
  > cuánto se separan los dos lados—. `PanelRelaciones`: cada banda conocida por
  > el nombre de su sitio, el trato en palabras y los tratos hechos con el
  > último día. Las dos sólo leen y piden (SPECS §4.7). Capturas en
  > `TruequeCaptura.gd` (`user://trueque.png`, `user://relaciones.png`).
  >
  > Para que la ventana tuviera derecha, `Intercambio` gana `lo_que_traen` —por
  > semilla, sitio y estación, sílex, conchas, ocre y pieles, cantidades de
  > decisión— y `quedan_de`, que resta lo ya cambiado esa estación: si no, se
  > podía llevar lo mismo sin fin. `TestTruequeYRelaciones`, cuatro pruebas.
  > **Se quitó un filtro que me había inventado** —no ofrecer lo que se
  > pudre—: qué se da lo decide el jugador. **Queda por decidir** si la tarjeta
  > de trueque de siempre (`proponer_el_trato`) se retira ahora que está la
  > ventana; conviven. Suite **1 221 pruebas, 7 630 comprobaciones**.

**24 · El humo**

- [x] **F1. Humo en los fuegos.** **Toca:** `vista/HearthFire.gd`,
      `vista/Bonfire.gd`, `vista/BivouacFires.gd`. **Captura y fotograma antes y
      después, ~5 min.**

  > **HECHO (2026-09-13).** Sólo `Bonfire`: el hogar, las hogueras y los vivacs
  > son todos esa clase, así que una vez sirve para los tres. Un
  > `GPUParticles3D` de 18 bocanadas que viven 7 s, nacen oscuras y se aclaran y
  > ensanchan al subir, con una mancha redonda hecha en código; sale mientras
  > arde y deja de salir al apagarse. Captura en `HumoCaptura.gd`
  > (`user://humo.png`): se ve la columna desde lejos.
  >
  > **Fotograma, medido en la misma corrida** —con el humo saliendo y con el
  > humo parado, que entre corridas el reloj de pared no se compara—: **56,11
  > ms las dos veces, con 7 fuegos**. Sin diferencia medible. Ojo: ese
  > fotograma de 56 ms lo pone todo lo demás, no el humo.

**18 · El mapa regional**

- [x] **R2. La frontera hasta el agua.** Sin tope de distancia, con límites
      laterales, y la herramienta de horneado. **Toca:** `datos/RegionBoundary.gd`,
      `tools/` (nueva), `data/sites/cantabria_eras.res`, `tests/`.
      **Horneado ~2 min y captura.**

  > **HECHO (2026-09-13).** `RegionBoundary.build_playable_mask` pierde el tope
  > de 60 km y el ruido que modulaba el alcance: la inundación sigue mientras
  > haya fondo emergido, y los límites laterales —la costa de Cantabria— se
  > quedan. `tools/HornearEras.gd` nueva rehornea `cantabria_eras.res` en unos
  > 13 s (0, −60 y −120 m). `TestFrontera`: a −120 m, **ninguna celda de fondo
  > emergido pegada al territorio queda fuera** dentro de los límites laterales.
  >
  > **Y un fallo que no estaba en el plan**: las máscaras viejas eran de
  > **1792×1536** y el relieve regional de hoy es de **1792×1280**; estaban
  > horneadas contra otro relieve y se pintaban estiradas en vertical, que por sí
  > solo apartaba la línea de la costa. No se pudo medir el antes celda a celda
  > por eso mismo. La primera versión de la prueba estimaba los límites laterales
  > por su cuenta y falló por dos columnas; usa ahora el cálculo del constructor.
  > **La captura del mapa regional va con R5.** Suite **1 222 pruebas, 7 632
  > comprobaciones**, huérfanas 0.
- [x] **R3. La ficha del sitio descubierto.** **Toca:** `region/RegionMap.gd`,
      `tests/`. Segundos.
- [x] **R4. La banda y los mapas guardados.** **Toca:** `region/RegionMap.gd`,
      `region/Guardado.gd`, `tests/`. Segundos.

  > **HECHOS (2026-09-13), juntos.** El mapa regional no tiene simulación, así
  > que lo que sabe sale de **las cabeceras de los mapas guardados**:
  > `Guardado.guardar` apunta ahora el trato con cada banda, cuántas cuevas se
  > han explorado y cuántas tienen pared, si la cueva está pintada, y el año y la
  > estación; `Guardado.cabeceras()` las lee todas sin la foto.
  >
  > `RegionMap.ficha_del_sitio` —estática, sólo lee—: de un sitio descubierto,
  > si vive gente y el trato, los recursos que se ven desde fuera, y el estado de
  > sus cuevas; **de uno sin descubrir, nada, ni el nombre**. Va encima de los
  > datos del terreno que ya enseñaba. `RegionMap.panel_de_la_banda`, debajo del
  > botón de volver: cada mapa guardado con su jornada y su gente, dónde está la
  > banda y cómo volver. `TestMapaRegional`, cinco pruebas. **Un tropiezo**: el
  > mapa regional no tiene `class_name`, la prueba lo pedía por nombre, no
  > compilaba, y la suite se colgó —el aviso de siempre: `--check-only` antes—.
  > Suite **1 227 pruebas, 7 645 comprobaciones**, huérfanas 0.
- [x] **R5. Ventanas que caben.** **Toca:** `region/RegionMap.gd`. **Capturas a
      1920×1080 y 1280×720, ~5 min.**

  > **HECHO (2026-09-13).** `RegionCaptura.gd` no sólo captura: **recorre todos
  > los controles visibles y dice cuáles se salen de la pantalla**. Al empezar
  > se salía la ficha del sitio —1 505 px de alto— a las dos resoluciones. Ahora
  > va anclada a todo el alto del lado derecho con desplazamiento, 360 px de
  > ancho, y la letra de los paneles del mapa regional baja a 12: **0 controles
  > fuera a 1920×1080 y a 1280×720**, y ya no se pisan la cabecera con la
  > leyenda ni la ficha con el panel de la banda. La sonda tuvo que aprender
  > que lo de dentro de un panel con desplazamiento lo recorta el panel. En la
  > misma captura se ve **la línea amarilla siguiendo la plataforma emergida
  > hasta el agua** (R2). Queda el panel de rendimiento de F3 tapando la
  > leyenda, que es de depuración y se oculta con F3.

**Cierre**

- [x] **M. Cerrar.** Suite verde y ≥ 7 372 comprobaciones, huérfanas en 0, y lo
      aprendido a SISTEMAS §5 y §13, GRAFICOS, INTERFAZ §4, SPECS y ESTADO.

  > **HECHO (2026-09-13).** Suite **1 227 pruebas, 7 645 comprobaciones** —de
  > 1 167 y 7 372 al abrir—, sin un SCRIPT ERROR, huérfanas 0. Lo aprendido va
  > en cada cita de arriba y en SISTEMAS §5 y §13, GRAFICOS, INTERFAZ, SPECS
  > §4.3 y EPOCA_01.

**Presupuesto de máquina: ~40 min**, repartido en capturas —cueva, sepultura,
trueque, relaciones, humo, mapa regional a dos resoluciones— y dos sondas cortas
—colocación de cuevas por los nueve mapas y variedad de 50 cuevas—, más el
horneado de la frontera. **Nada pide correr jornadas largas.**

---

### ~~Tanda 3: quién va, la pasarela que se ve, el herido, el guardado y el cielo~~ — cerrada

**CERRADA el 2026-09-13.** Diecisiete tareas, todas hechas, más los dos
`/depurar` que la bloqueaban. Suite **1 145 pruebas y 7 332 comprobaciones**,
desde 1 076/7 161; `LlamadasHuerfanas` en **0** —las dos «de siempre» eran
falsas y se arregló el comprobador—. Lo aprendido está en SISTEMAS §3, §4, §16
y §20, GRAFICOS, INTERFAZ §4, SPECS §4.3, §4.5, §6.4 y §8, ESTADO §2, §3 y §5,
y EPOCA_01 §10.1.

| | |
|---|---|
| Las decisiones | Salen en una jornada sorteada del **segundo mes**, no el día 1: se decide habiendo vivido la estación |
| La expedición | **El jugador elige a quién manda**, se lleva tienda y hoguera, **sale y vuelve andando** por el borde del mapa y **despeja el minimapa por donde pasa** |
| La cumbre | El jugador elige la cordada, con el mínimo que ya tenía |
| El herido | Se queda en el abrigo hasta curarse, y vuelve solo a lo suyo |
| La pasarela | **Una obra en un cruce**, no un permiso sobre el mapa: la banda elige dónde, cuesta 40 de leña y 6 jornadas, **se ve** y **una riada se la lleva** |
| El taller | Practica sin encargo y **curte la piel cruda**; medido: **1,98 jornadas/día durante 90** y la talla laminar hacia la 51 |
| El guardado | **Existe** (FASE A3): automático al volver al mapa regional, y la partida cargada da **las mismas firmas** que la que no se guardó |
| El cielo | Nubes, **estrellas que giran con el polo**, sol y luna en su sitio. Y la cámara ya lo puede mirar |
| Las ventanas | «Trabajos» dice **quién no está**, Oficios enseña las jornadas del árbol, y el Shift del almacén está probado |

**Lo que NO quedó hecho, y por qué:** nada de la tanda. Lo que sigue abierto es
de antes —el 🔴 del hambre del segundo invierno, ESTADO §5 punto 13, que va por
`/depurar`— y los cinco fallos de la tabla de dependencias que no bloqueaban
ningún frente.

**Spec escrita (2026-09-13) en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1 → Tanda 3**, frentes 9 a 17, cada uno con sus criterios. Sale de la lista
del usuario tras jugar la tanda 2. Siguiente paso: `/plan-tarea`, que cuelga aquí
la lista de tareas.

En corto: las decisiones salen en el segundo mes de la estación; la
expedición lleva piel y leña de vivac, el jugador elige a quién manda y se les
ve salir por el borde del mapa; lo mismo, elegir quién sube, en la cumbre; el
herido se queda en la cueva; la pasarela es una obra con modelo en un cruce,
no un interruptor global, y la piragua sale de esta época; el taller practica
sin demanda, que cierra lo que A4 dejó abierto; la partida se guarda en disco
al volver al mapa regional, que es la FASE A3; hay cielo con nubes; y
«Trabajos», Almacén y Oficios se ponen al día.

**Depende de siete fallos que van por `/depurar`**, listados con su pista en la
spec: el % de técnicas que no sube en ribera, manufactura y hogar; la pasarela
en 82/70; «sim.hogar» en la crónica; los marcadores viejos del minimapa; el
raizal inalcanzable a 226 m; los 41 «sin camino» en 51 jornadas; y el barbecho
del 20 %, que existe y no se cumple. **Y no se toca código mientras M1 de la
tanda 2 esté midiendo.**

**Coste de máquina:** casi todo son pruebas de segundos y capturas con
ventana. La única corrida larga es la del taller, unos 45 minutos, la que A4 ya
tenía prevista.

**Plan técnico en EPOCA_01 §10.1**, «Plan técnico de la tanda 3», con tres
premisas que no se sostienen: el cielo ya existe y le faltan las nubes, el
Shift del almacén ya está, y el guardado parte de `Instantanea.volcar`. Lista
colgada por `/plan-tarea` el 2026-09-13 por `history-of-man-11`.

**Suelo de la suite al abrir: 1 076 pruebas, 7 161 comprobaciones.**

**Antes, por `/depurar`:** ~~el fallo 1 (la práctica que no cuenta) bloquea el
frente 14~~ **arreglado el 2026-09-13** —la cuenta se ha mudado a la simulación,
ver ESTADO §2—, y ~~el 2 (la pasarela en 82/70) bloquea el 13~~ **arreglado el
2026-09-13**: no era el material ni las jornadas, era que cuelga del núcleo
preparado y el cartel enseñaba «82 de 70». **Los dos frentes quedan
desbloqueados.**

**Decidido por el usuario el 2026-09-13:** primero los dos `/depurar` y después
la tanda entera en orden; el día de la decisión sale de la semilla, sin tocar el
`_rng`; la pasarela sirve para cauces de hasta **2 celdas (~16 m)** y cuesta
**40 de leña y 6 jornadas-persona**.

**9 · Las decisiones en el segundo mes**

- [x] **D1. El día de la decisión, sorteado en [16, 30].** Se sortea al entrar
      la estación y en `iniciar_partida`, y salta al cerrar esa jornada. Las
      tres pruebas de la spec, y `TestDecisiones` puesto al día.
      **Toca:** `sim/SettlementSim.gd`, `tests/TestDecisiones.gd`. Segundos.

      > **HECHO (2026-09-13).** `SettlementSim.dia_de_decidir` —estática, sin
      > estado— saca el día de la semilla, el año y la estación; `_citar_la_
      > decision` la cita al entrar la estación y en `iniciar_partida`, y el
      > cierre de la jornada pregunta con `_revisar_la_decision`. Seis pruebas
      > nuevas en `TestDecisiones`, incluida una que pasa por `_end_of_day` de
      > verdad y no por la regla a mano. Y una trampa evitada: si se entra en la
      > estación con el día ya pasado —una partida que arranca a mitad, o un
      > estado construido— se decide en cuanto se puede, en vez de perder la
      > decisión de esa estación. Suite: 1 090 pruebas, 7 193 comprobaciones.

**12 · El herido** (va antes que 10 y 11, que lo usan)

- [x] **H1. Tocado se queda en casa.** `Inhabitant.esta_tocado()`; `Reparto` le
      da sólo hogar; al curarse, su oficio y prioridades de antes, con **la
      misma receta que la berrea**, sacada a un sitio. Cuatro pruebas.
      **Toca:** `banda/Inhabitant.gd`, `sim/Reparto.gd`, `sim/SettlementSim.gd`,
      `tests/TestHerido.gd` (nuevo). Segundos.

      > **HECHO (2026-09-13), y por una vía más simple que la del plan.** El plan
      > decía reutilizar la receta de la berrea —guardar las prioridades y
      > devolverlas al curar—. No hace falta: basta con **no tocarlas** y filtrar
      > en el reparto, así que al curarse vuelve solo. La berrea sigue
      > guardándolas porque ella sí las cambia. Seis pruebas en `TestHerido`,
      > incluida la de que al sano sí se le deja salir —sin ese control, «no
      > sale» podría ser que no saliera nadie— y la de que no se le manda de
      > expedición. Suite: 1 096 pruebas, 7 209 comprobaciones. SISTEMAS §3.

**10 · La expedición**

- [x] **X1. El equipo.** Piel y leña con las constantes del vivac; la opción
      se bloquea diciendo qué falta; las pieles vuelven. `Moment` aprende la
      opción bloqueada. Una prueba por cada cosa que falta, y la del gasto.

      > **HECHO (2026-09-13).** `Expedicion.hace_falta_para` y `lo_que_falta`,
      > con las constantes del vivac y sin cifras nuevas: 3 personas y 12
      > jornadas piden **72 raciones, 3 pieles y 39 de leña**, y las pieles
      > vuelven. `Moment.opcion` admite `bloqueo`, la barra pinta el botón
      > apagado con lo que falta —no lo esconde: así se sabe a por qué ir— y
      > `elegir` sobre una opción bloqueada cae a la que no compromete, que es lo
      > que lo hace cierto también para las sondas. Suite: 1 100 pruebas, 7 220
      > comprobaciones.
      **Toca:** `sim/Expedicion.gd`, `banda/Moment.gd`, `ui/BarraSuperior.gd`,
      `tests/TestExpedicion.gd`. Segundos.
- [x] **X2. Elegir a quién se manda.** `Moment` aprende la elección de personas
      —candidatos, mínimo, marcados—, la barra la pinta, el coste se recalcula,
      con menos de 3 no se confirma, y `contestar_todo` marca a los primeros
      aptos. Sin niños ni tocados.
      **Toca:** `banda/Moment.gd`, `ui/BarraSuperior.gd`, `sim/Expedicion.gd`,
      `tests/TestExpedicion.gd`, `tests/TestDecisiones.gd`, `tests/AnoProbe.gd`.
      Segundos.

      > **HECHO (2026-09-13).** `Moment` aprende `candidatos`, `nombres`,
      > `minimo_elegidos`, `elegidos` y `marcar()`, y un `al_cambiar_la_eleccion`
      > que rehace las opciones: **el coste depende de cuántos van**. La barra
      > pinta una casilla por candidato y repinta la tarjeta al marcar —diferido,
      > que reconstruirla desde la señal de su propia casilla borra el nodo que
      > la emite—. `Expedicion.mandar_a` respeta la lista del jugador y vuelve a
      > comprobar que cada uno pueda ir. `contestar_todo` marca a los primeros
      > que puedan: sin eso una sonda no podría decir que sí nunca. **La parte
      > de interfaz no la cubre ninguna prueba**: se ve en la sonda de escena de
      > X3. Suite: 1 104 pruebas, 7 233 comprobaciones.
- [ ] **X3. Que se les vea irse y volver.** Salida por la celda del borde
      alcanzable más cercana al rumbo del destino; se ocultan al llegar,
      reaparecen el día que toca y vuelven andando, sin trabajar en todo el
      tramo. **Toca:** `sim/Expedicion.gd`, `sim/Marcha.gd`,
      `sim/SettlementSim.gd`, la vista de las personas, `tests/ExpedicionProbe.gd`.
      **Sonda en escena, ~5 min, y una captura con ventana.**

      > **HECHO (2026-09-13).** `Expedicion.puerta_del_valle` busca la celda del
      > borde **alcanzable** —`Marcha.alcanzable_desde_casa`, que nadie da un
      > paso sin camino debajo— que menos se desvía del rumbo del destino
      > regional. Salen andando hacia ella y, al llegar, se les saca de la vista
      > mandando su cuerpo bajo tierra: sin eso se quedaban plantados en el
      > borde doce jornadas, porque la simulación no los tocaba y la vista
      > seguía pintándolos donde los dejó. **Vuelven por la misma puerta** y
      > andan a casa solos. Medido en la escena: la puerta cae a **1 m del
      > borde** y a 2 115 m del abrigo, Haro los recorre en dos jornadas y
      > desaparece, y al volver los tres están en la puerta y no en la cueva.
      >
      > **Y despejan el minimapa por donde pasan** (pedido por el usuario ese
      > mismo día): la misma ojeada que hace cualquiera que anda, no un segundo
      > sistema. Medido: del **2,0 % al 6,2 %** de mapa conocido sólo con la
      > ida. Con prueba, y con su control —quien ya está fuera no descubre nada
      > del valle—.
      >
      > **Y un hallazgo de la partida**: con el equipo del vivac, al empezar no
      > hay ni pieles ni leña, así que **la primera expedición no puede salir
      > hasta que la banda tenga 3 pieles y 39 haces guardados**. La sonda tuvo
      > que abastecerse a mano para poder medir lo suyo.

**11 · La cumbre**

- [x] **C1. Elegir quién sube**, con la misma elección y
      `Cumbres.MIN_CLIMBING_PARTY` de mínimo. Prueba.
      **Toca:** `sim/Cumbres.gd`, `tests/TestDecisiones.gd`. Segundos.

      > **HECHO (2026-09-13).** `Cumbres.subir_con` pone en ascensión a **todos
      > los elegidos** —que es lo que `_ascension_party_size` cuenta, así que la
      > cordada elegida es la que permite atacar una cumbre dura— y abre paso el
      > que mejor trepa de ellos. El mínimo no es una cifra nueva: 1 en una
      > cumbre suave y `MIN_CLIMBING_PARTY` en una dura, que ya estaba. Los
      > tocados no salen en la lista. Suite: 1 106 pruebas, 7 238 comprobaciones.

**13 · La pasarela** (después del fallo 2)

- [x] **B1. La piragua sale del Paleolítico.** Prueba sobre el árbol.
      **Toca:** `economia/TechTree.gd`, `DemoMain.gd`, `ui/PopupHitoTecnico.gd`.
      Segundos.

      > **HECHO (2026-09-13).** Fuera del `enum`, del catálogo, de su coste y de
      > la rama de exploración, que se queda en la pasarela. EPOCA_02 decía «ya
      > en `TechTree.Tech.PIRAGUA`» y ahora dice que hay que añadirla: se
      > corrigió. El árbol pasa de 19 técnicas desbloqueables a **18**, y las dos
      > pruebas que la usaban de ejemplo —el arte pide hogar levantado— se
      > escribieron con el arte, que pide lo mismo.
- [ ] **B2. Un cruce, no el mapa.** `Navgrid.paso_entre` abre las celdas con
      pasarela en las cuatro estaciones; se borra `has_bridge` de
      `Hydrography.tope_de_vado`, del horno y de la simulación. Pruebas: con la
      técnica y sin obra sigue cerrado; con obra se abre ese y ningún otro.
      **Toca:** `mundo/Navgrid.gd`, `mundo/Hydrography.gd`,
      `mundo/HornoDeRejillas.gd`, `sim/Marcha.gd`, `sim/SettlementSim.gd`,
      `DemoMain.gd`, `tests/TestFording.gd`. Segundos.

      > **HECHO (2026-09-13).** `has_bridge` ya no existe. El parámetro que
      > viajaba por toda la capa de mundo pasa a llamarse `con_pasarela` y
      > significa **«hay una AQUÍ»**: la rejilla lo pregunta celda a celda con
      > `Navgrid._hay_pasarela`, y la regla de paso sigue en un solo sitio
      > —`Hydrography.can_cross`—. Las rejillas guardan las celdas con las que se
      > midieron y su versión: levantar o perder una pasarela las invalida.
      > Trampa evitada: el `Tajo` cacheaba con un sí/no de puente, y ahora
      > cachea con la versión, que es lo que de verdad cambia adónde se puede
      > ir. **Y una lección repetida**: las pruebas seguían llamando a la firma
      > vieja y la suite se quedó **colgada**, no en rojo —un fichero que no
      > compila no falla, no termina—.
- [ ] **B3. La banda elige dónde y la levanta.** `Pasarelas` (`sim/`): el cruce
      de sus veredas que más rodeo ahorra, hasta **2 celdas de ancho**, por
      **40 de leña y 6 jornadas-persona** (decididos por el usuario), y obra con jornadas y leña como
      `CampProjects`. Pruebas. **Toca:** `sim/Pasarelas.gd` (nuevo),
      `sim/SettlementSim.gd`, `tests/TestPasarela.gd` (nuevo). Segundos.

      > **HECHO (2026-09-13).** `Pasarelas.elegir_cruce` mira las veredas que la
      > banda sabe —SISTEMAS §18— y se queda con la que **más se desvía de la
      > línea recta entre sus extremos**: lo que rodea un camino en un valle con
      > río es el río. Donde esa recta corta el agua se cuentan las celdas
      > seguidas, y si pasan de dos no es cauce para dos troncos. **No se mide
      > rehaciendo la rejilla con la pasarela puesta**: sería hornear una rejilla
      > por candidato, 900 ms cada una, para contestar lo mismo. La levanta quien
      > ese día salió de exploración, a jornada por cabeza.
- [ ] **B4. La riada.** Al entrar la estación, si su rejilla cierra ese vado
      sin contar la pasarela, se pierde y se cuenta en la crónica. Sin crecida
      no se pierde nunca. Pruebas. **Toca:** `sim/Pasarelas.gd`,
      `tests/TestPasarela.gd`. Segundos.

      > **HECHO (2026-09-13).** Se pierde cuando el cauce de esa celda llega a
      > `Hydrography.FORD_IMPASSABLE` con el caudal de la estación que entra:
      > **sin sorteo y sin cifra nueva** —si el río viene tan alto que ya no se
      > vadea, viene lo bastante alto como para llevarse dos troncos—. Con el río
      > bajo aguanta todas las estaciones que haga falta, y eso también tiene
      > prueba: sin ella, «se la lleva la riada» sería «se cae sola».
- [x] **B5. Se ve sobre el terreno.** `PasarelaView` (`vista/`), que se quita
      con la riada. **Toca:** `vista/PasarelaView.gd` (nuevo), `DemoMain.gd`.
      **Una captura con ventana, ~3 min.**

      > **HECHO (2026-09-13), con dos vueltas.** La vista se repinta cuando
      > cambia `Pasarelas.version`, así que se quita sola con la riada. La
      > primera captura salió con **cero troncos**: la vista se refresca al
      > cerrar la jornada y la sonda tiene el reloj parado. La segunda la plantó
      > en mitad del cauce ancho —donde la banda no construiría— porque la sonda
      > buscaba «la primera celda mojada»; ahora busca **el paso más estrecho**,
      > puntuando cuánta agua hay alrededor. Y dos troncos de 28 cm desde la
      > distancia de gestión son dos rayas: lleva el tejido de ramas que dice su
      > propia ficha. `PasarelaCaptura` (nueva).

**14 · El taller** (después del fallo 1)

- [ ] **T1. Practica sin demanda, y curte la piel.** Las tres reglas, con
      pruebas sobre un taller construido. **Y el curtido sin pedido**, añadido
      por el usuario el 2026-09-13: hoy nadie curte piel si nadie ha pedido una
      prenda o un odre, y las pieles crudas se amontonan. **Toca:** `sim/Taller.gd`, `sim/Reparto.gd`,
      `tests/TestTaller.gd` (o la que ya lo cubra). Segundos.

      > **HECHO (2026-09-13).** `Taller.puede_practicar` abre la puerta del
      > reparto: con encargo o practicando. Sin encargo se talla para aprender
      > —gasta **1 unidad de la materia del oficio por jornada**, que es una
      > decisión, no una medida— y si no queda técnica de manufactura que
      > aprender, no se practica: no se gasta piedra por gastarla. **Y la piel
      > cruda se curte aunque nadie pida prendas**, que lo pidió el usuario al
      > verlo jugando: el curtido ya existía, pero a peletería sólo se mandaba a
      > alguien si había una pieza pedida que llevara piel. Ocho pruebas en
      > `TestTaller`. Suite: 1 126 pruebas, 7 284 comprobaciones.
- [x] **T2. La medida de A4.** `ArbolPasoProbe`, 90 jornadas, `MANU=2`: ≥ 2,00
      jornadas de manufactura al día, y en qué jornada llega la talla laminar o
      por qué no llega. **Corrida larga, ~45 min.** Toca ESTADO §2.

      > **CORTADA POR EL USUARIO (2026-09-13), y la cifra queda pendiente.** El
      > presupuesto de 45 min salió de lo que costó esta misma sonda en la tanda
      > anterior, con 60 jornadas; con 90 y la máquina venida de las pasadas
      > largas iba camino de **hora y media larga**. Se paró en la jornada 20 de
      > 90. Lo que alcanzó a medir: a la jornada 11, **18 jornadas de manufactura
      > con dos artesanos** —o sea las 2,00 al día que el criterio pide— y 88 de
      > piedra en el almacén. No basta para dar el criterio por cumplido: hace
      > falta ver si se sostiene cuando el utillaje se cubre, que es lo que
      > paraba al taller hacia la jornada 31. **El frente 14 queda medido sólo
      > por pruebas**, y esta cifra se retoma cuando haya máquina.

      > **MEDIDA ENTERA (2026-09-13), y el criterio se cumple.** Relanzada al
      > acabar lo demás: 90 jornadas, `MANU=2`, 1 h 40. **1,98 jornadas de
      > manufactura al día sostenidas las noventa** —el criterio pedía no bajar
      > de 2,00, y esto es el redondeo de la primera jornada— frente a la caída a
      > **0,3** que el 🔴 medía hacia la jornada 31. **La talla laminar se
      > aprende hacia la jornada 51**, con el núcleo por la 21–31. Lo que ahora
      > frena el árbol no es el taller: es el material animal —azagaya sin asta
      > ni tendón, aguja sin hueso— y el ocre y la grasa del arte parietal.
      > Cifras en ESTADO §2, «El taller ya no se para».

**15 · El guardado** (después de 10 y 13)

- [ ] **G1. Guardar y leer, sin pérdida.** `Guardado` (`region/`): cabecera y
      versión propias, la instantánea más el `GameState` que ella no guarda;
      una versión distinta se rechaza. Pruebas: misma firma al guardar y al
      cargar, y 5 jornadas iguales con la misma semilla; y una expedición a
      medias vuelve su día. **Toca:** `region/Guardado.gd` (nuevo),
      `tools/Instantanea.gd` si hace falta un gancho, `tests/TestGuardado.gd`
      (nuevo). Segundos.

      > **HECHO (2026-09-13).** `Guardado` (`region/`) con su cabecera y su
      > versión: dentro, la instantánea —que ya sabía recorrer y volcar la
      > partida entera, azar incluido— y lo que ella no guarda, que es lo que
      > cruza escenas: qué emplazamiento se juega, qué se ha descubierto de la
      > comarca, la era, la cota del mar y el recuadro local. **Un fichero de
      > otra versión se rechaza** en vez de cargarse a medias. Seis pruebas.
      > Trampa: el emplazamiento se guarda desde `Expedition.site` y no desde
      > `GameState.home`, que sólo lo pone `GameState.begin`; guardando el
      > segundo, una partida montada por sonda quedaba imposible de retomar.
- [x] **G2. Al volver al mapa se guarda, y se retoma.** `DemoMain` guarda,
      `RegionMap` ofrece retomar, y la escena arranca volcando. SPECS §6.4 y §8
      corregidos. **Toca:** `DemoMain.gd`, `region/RegionMap.gd`,
      `region/Expedition.gd`, docs/SPECS.md

      > **HECHO (2026-09-13).** Se guarda al volver al mapa regional, con el
      > reloj parado y desde fuera del paso. El mapa regional enseña **«Volver
      > con la banda (jornada N)»** sólo si hay algo que retomar, y
      > `Expedition.retomando` distingue retomar de fundar otra vez en el mismo
      > sitio: una partida retomada **no llama a `iniciar_partida`**, que
      > volvería a levantar el momento inicial y a citar la decisión de la
      > estación..
- [x] **G3. En dos procesos, y el mapa regional se entera.** `GuardadoProbe`
      con `MODO=guardar` y luego `MODO=cargar`, y en escena: tras una expedición
      el mapa enseña la cueva más los 4. **~5 min.**

      > **HECHO (2026-09-13), y el primer resultado era del instrumento.** Las
      > cinco jornadas salían distintas en tres de cinco, y dos corridas **del
      > mismo brazo** tampoco coincidían: la sonda tomaba la firma al salir del
      > bucle de espera, o sea en un punto cualquiera del paso, y en un mismo
      > fotograma corren varios pasos. Tomándola en `paso_cerrado` —«el único
      > límite limpio de la partida», SPECS §3.2— la hora es siempre 0,00 y
      > **las cinco jornadas salen idénticas**: la partida cargada es la misma
      > que la que no se guardó nunca. Lo de siempre: si las cifras no cuadran,
      > sospechar del instrumento antes que de lo medido.
      >
      > **Y el mapa regional se entera** porque `GameState.discovered` es lo que
      > filtra lo que enseña —medido en la tanda 2, `TestNiebla`— y ahora además
      > se guarda: `ExpedicionProbe` mide en la escena que una expedición lo
      > sube de 0 a 4.

**16 · El cielo**

- [x] **S0. Qué cielo hay hoy y por qué no se ve.** Capturas con ventana a
      cuatro horas desde la cámara de juego. **~3 min.** Si resulta que se ve y
      sólo le faltan nubes, S1 es sólo eso.

      > **HECHO (2026-09-13), y la respuesta eran dos cosas, ninguna «no hay
      > cielo».** Primera: **la cámara no lo mira**. `OrbitalCamera` clampa la
      > inclinación a [-89º, -10º], o sea que siempre mira hacia abajo, y en un
      > valle las laderas llenan el cuadro: a 300 m de distancia no entra ni una
      > franja. Segunda: **el cielo que hay es gris a propósito** —la escena
      > `WorldEnvironment.tscn` pone un cenit gris azulado y un horizonte gris,
      > que es la paleta de un día encapotado—, así que cuando entra en cuadro
      > no se lee como cielo. `CieloCaptura` (nueva) hace las cuatro horas.
- [x] **S1. Nubes, y el cielo con la hora.** Shader de cielo en
      `WorldEnvironmentSetup`; cuatro capturas, dos separadas unos segundos, y
      el fotograma medido antes y después en Alto. **Toca:**
      `vista/WorldEnvironmentSetup.gd`, `shaders/` (nuevo), docs/GRAFICOS.md.
      **~15 min.**

      > **HECHO EL CIELO (2026-09-13), y ampliado por el usuario a «rotación de
      > cielo, sol, luna, estrellas».** `shaders/cielo.gdshader` sustituye al
      > `ProceduralSkyMaterial`: degradado con la hora, **nubes que pasan**,
      > **estrellas que giran alrededor del polo celeste** —a la altura de la
      > latitud, no de la vertical: en Cantabria son 43º— y **el sol y la luna
      > donde de verdad están**. Las direcciones no las calcula el cielo: se las
      > da `WorldEnvironmentSetup` desde `SolarPosition`, que es quien ya orienta
      > las luces; una segunda cuenta separaría el sol de la sombra del sol
      > pintado. Las nubes van con el reloj de pared —son vista, SPECS §4.7— y
      > las estrellas con el ángulo horario del juego. Y el color: la paleta gris
      > de la escena es la de encapotado, así que se mezcla con un azul limpio
      > según lo que tapen las nubes, que salen del tiempo que hace.
      >
      > **Y las dos cosas que faltaban, hechas al soltar T2 la máquina.** El tope
      > de inclinación de la cámara sube de -10º a **-3º** (decisión del
      > usuario): ahora el cielo entra en cuadro de verdad, y la captura de
      > mediodía despejado lo enseña azul. **El fotograma no se nota**: `PicoProbe`
      > con `VEL=5 DIAS=2`, **40,6 ms de media con el cielo viejo y 40,5 con el
      > nuevo**, un tirón de más de 100 ms en cada corrida. Es un shader de
      > pantalla completa sin geometría: la diferencia es menor que el ruido
      > entre dos corridas. Para poder compararlo se dejó `CIELO=viejo`, un
      > interruptor **de medida** como `NOCHE=0` o `SEMILLA=`.

**17 · Las ventanas** (al final: pintan lo de 10, 11 y 12)

- [ ] **V1. «Trabajos»: quién está fuera.** Expedición, cumbre y heridos,
      aparte, con dónde y cuándo vuelven. Prueba sobre lo que pinta, y captura.
      **Toca:** `ui/PanelTrabajos.gd`, `tests/TestPanelTrabajos.gd` (nuevo).
      **~3 min** de captura.

      > **HECHO (2026-09-13).** Una sección «QUIÉN NO ESTÁ» con tres casos —de
      > camino al borde del valle, fuera del valle, descansando en el abrigo— y
      > la jornada en que vuelve o se cura. Quien está fuera **desaparece de la
      > rejilla**, que no se le puede dar trabajo hoy; el herido se queda, porque
      > lo que se le marque es lo que hará al curarse. La lista la calcula
      > `PanelTrabajos.ausentes`, que no pinta nada: así se comprueba con una
      > prueba y no con una captura —la vista lee, no decide—. Cuatro pruebas y
      > una captura con `PanelProbe`.
- [x] **V2. El Shift del almacén**, que ya existe: prueba de lo que hace y
      comprobarlo jugando. **Toca:** `tests/` (nueva prueba). Segundos.

      > **HECHO (2026-09-13).** Estaba, sin prueba y sin escribir en ninguna
      > parte. Se saca a `PanelAlmacen.paso_del_objetivo(con_shift)` —una función
      > sin teclado, porque `Input.is_key_pressed` no se puede preguntar en una
      > prueba sin pantalla— y se comprueba: 1 sin Shift, 10 con él. **Ojo con
      > la lectura**: en los pedidos de utillaje eso es «de 1 en 1 y de 10 en
      > 10», pero el tope de comida multiplica ese paso por diez, así que ahí va
      > de 10 en 10 y de 100 en 100. Es deliberado —un tope de comida en
      > raciones de una en una sería inmanejable— y ahora está escrito.
- [x] **V3. Oficios, al día.** Lista de textos revisados en la cita de HECHO, y
      las jornadas de cada oficio leídas del árbol, con prueba de que coinciden.
      **Toca:** `ui/PanelOficios.gd`, `tests/`. Segundos.

      > **HECHO (2026-09-13).** Cada oficio enseña ahora **«N jornadas
      > trabajadas · la siguiente, X, pide M»**, leído de `TechTree.days_in` —la
      > misma cifra que hace subir el árbol, no una copia— con su prueba.
      >
      > **Textos revisados, y los dos que decían algo que el juego no hace:**
      > el hogar decía «preparar pieles», y curtir es del taller —peletería,
      > SISTEMAS §16—: ahora dice «levantar las obras del abrigo», que sí lo
      > hace y no se decía. Y exploración no mencionaba lo que la tanda 3 le
      > añade: es quien levanta las pasarelas de los cruces. Los demás
      > —recolección, caza, ribera, manufactura y las diecisiete
      > especialidades— se leyeron uno a uno y describen lo que el juego hace.

**Cierre**

- [x] **M. Cerrar.** Suite verde y ≥ 7 161 comprobaciones, `LlamadasHuerfanas`
      **en 0** —las 2 «de siempre» eran falsas y se arreglaron el 2026-09-13:
      el comprobador llamaba huérfana a una función estática pedida por su
      clase—, y lo aprendido a SISTEMAS §4, §5 y §18, GRAFICOS,
      INTERFAZ §4, SPECS §4.3, §4.6, §6.4 y §8, y ESTADO §2 y §3.

**Presupuesto de máquina: ~1 h 20**, casi todo en T2 (45 min). Lo demás son
capturas y sondas cortas (S0 + S1 ~18 min, X3 ~5, G3 ~5, B5 y V1 ~3 cada una),
más las pasadas de la suite. **Ningún criterio pide correr un año.**

> **Lo que costó de verdad: ~3 h 15.** T2 se presupuestó en 45 min con lo que
> costó la misma sonda en la tanda anterior —60 jornadas— y con 90 se fue a
> **1 h 40**; se cortó a la jornada 20, el usuario decidió dejarla para el final,
> y se relanzó entera al acabar todo lo demás. El resto cuadró: las capturas y
> las sondas cortas, unos 40 min contando las repeticiones —la del cielo hubo
> que hacerla cuatro veces para encontrar un encuadre donde se viera—, y las
> pasadas de la suite, unos 55 min en total. **Ningún criterio pidió correr un
> año**, que era lo que se quería evitar.

**Qué puede ir a la vez:** 9, 12, 15-G1, 16 y 17-V2/V3 tocan ficheros
distintos y se pueden repartir, salvo que 9 y 12 comparten `SettlementSim`.
**Las medidas, nunca a la vez**: Godot es de uno en uno.

---

### ~~Tanda 1: los caminos, la noche, los grados y el rendimiento~~ — cerrada

**CERRADA el 2026-09-12.** Diez tareas de doce hechas; C3 y M2 retiradas con su
motivo medido. Suite **979 pruebas y 6 994 comprobaciones**, desde 932/6 920.

**Lo que la tanda entrega, en una línea cada uno:**

| | |
|---|---|
| Los caminos | Memoria de veredas **sellada con su rejilla** y comprobable, los dos extremos catados, y **39 % de búsquedas ahorradas** |
| La noche | Se salta cuando nadie trabaja: **31 % de reloj con ventana**, y las 60 jornadas con **la misma firma** |
| Los grados | `Termometro`, con sus dos fuentes citadas, y la barra leyéndolos |
| El rendimiento | El recuento de tirones no sube; el fotograma medio pasa de 38,5 a 41,0 ms |

**Y tres cosas que salieron al revés de lo planeado**, que es lo que de verdad
hay que llevarse:

1. **La spec pedía la vereda «por destino» y está medido que no sale** — 17
   pasos cortados con la clave por par contra 2 295 con la clave por destino. El
   motivo es geométrico y no se afina. C2 y ESTADO §2.
2. **«Todos duermen» no era la condición**: era «nadie trabaja», que es lo que
   la spec decía. Lo destapó el usuario probándolo en el juego, no una sonda.
3. **Dos errores de método propios costaron más que toda la implementación**:
   medir sin fijar la semilla y tocar el código con una medida en vuelo. Las dos
   reglas están en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1.

**Queda abierto y nombrado:** C3 (la vereda que mejora con el uso) espera a que
se sepa comprobar barato un tramo recto nuevo; el vestido persona a persona es
tanda 2; y el «peor fotograma» no es medible con una corrida.

**Spec y plan técnico en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md)
§10.1**, tanda 1 y «Plan técnico». Lista colgada por `/plan-tarea` el
2026-09-12 por `history-of-man-11`.

**El suelo de la suite, medido hoy antes de tocar nada: 932 pruebas, 6 920
comprobaciones, TODO OK.** No puede bajar de ahí. La copia viva de esa cifra es
[ESTADO.md](ESTADO.md) §3.

**Dos premisas de la spec que el código no sostiene**, y están escritas en el
plan: `RegionEras` **no** calcula ningún paleoclima —son máscaras de cota del
mar, y no hay un solo grado de temperatura en el repositorio—, y el vestido es
de la banda y no de cada persona, así que «quién va vestido» persona a persona
no se puede contestar en esta tanda.

**Los caminos** (frente 1):

- [x] **C1. La memoria de rutas se muda a `BandKnowledge` y se sella con su
      rejilla.** Hoy vive en `SettlementSim._route_cache` / `_route_order` y se
      tira por aviso (`Marcha.forget_routes`); pasa a `BandKnowledge` y cada
      entrada guarda el `built_with_caudal` y el `built_with_encharque` de la
      rejilla que la trazó, y se descarta al leerla si no coinciden.
      **Toca:** `scripts/banda/BandKnowledge.gd`, `scripts/sim/Marcha.gd`,
      `scripts/sim/SettlementSim.gd`, `scripts/tests/TestVeredas.gd` (nuevo).
      **Verificable:** prueba que falla antes de la regla —una ruta sellada con
      otra rejilla no se usa— y `LlamadasHuerfanas` en 0. Segundos.

      > **HECHO (2026-09-12).** `scripts/banda/Vereda.gd` (nueva),
      > `BandKnowledge.veredas` con `vereda` / `recordar_vereda` /
      > `olvidar_veredas` / `veredas_recordadas`, `Marcha` redirigida, y fuera
      > de `SettlementSim` los `_route_cache` / `_route_order` /
      > `ROUTE_CACHE_LIMIT`. `scripts/tests/TestVeredas.gd`, 11 pruebas.
      > **Suite: 943 pruebas, 6 936 comprobaciones, TODO OK** (desde 932/6 920).
      >
      > **La prueba del sello es de verdad, comprobado rompiéndolo:** con
      > `Vereda.sirve_en` devolviendo siempre `true` caen 4 comprobaciones en 3
      > pruebas. Antes de esto la regla no se podía comprobar de ninguna
      > manera: la sostenía una llamada a `forget_routes` y un aviso no se
      > comprueba, sólo se confía.
      >
      > Dos cosas que salieron por el camino y no estaban en el plan:
      >
      > - **Tres sondas leían la caché por dentro** —`CrecimientoProbe`,
      >   `ScoutProbe` y `TironAnualProbe` imprimían `sim._route_cache.size()`—
      >   y habrían reventado en marcha sin avisar en compilación. Pasan por
      >   `veredas_recordadas()`.
      > - **`LlamadasHuerfanas` dice 2, y no son de esta tarea ni son un
      >   fallo.** Son `TestPartida.gd:185-186` llamando a
      >   `BarraSuperior._risk_share`, que es `static`: pedir un miembro
      >   estático por la clase es lo correcto —SPECS.md §4.4 lo exige para las
      >   constantes— y la herramienta lo cuenta como si tuviera que ir por
      >   `ui.barra`. Es un falso positivo de la herramienta con los miembros
      >   estáticos, en un fichero sin versionar que dejó otra tanda. Va por
      >   `/depurar`, no se parchea aquí.
- [x] **C2. La clave es el destino, y a la vereda uno se engancha.** La clave
      deja de ser el par origen-destino en cubos de 48 m y pasa a ser el
      destino; quien va allí se engancha por el hito más cercano al que llegue
      en línea limpia, con tope fijo de hitos catados.
      **Toca:** `scripts/sim/Marcha.gd`, `scripts/mundo/Wayfinder.gd`,
      `scripts/tests/TestVeredas.gd`.
      **Verificable:** pruebas —dos orígenes distintos al mismo destino usan la
      misma vereda; el enganche no cruza terreno cortado; entradas guardadas ≤
      destinos conocidos, que es el criterio de tope del frente 4—. Segundos.

      > **HECHO (2026-09-12), y NO como lo pedía la spec: se midió y no sale.**
      >
      > Lo construido: `Vereda.clave_de`, `Vereda.enganchar` (se entra a la
      > vereda por el hito que menos anda en total, catado con
      > `Wayfinder.linea_limpia`, tope `CATAS_DE_ENGANCHE`) y `Vereda.remate`
      > (se sale por un tramo catado). `SettlementSim.LANE_CELL` pasa a ser
      > `Vereda.CELDA`; `Marcha._lane_key` y `Marcha._retarget` **se borran**,
      > no los llamaba ya nadie. Suite: **955 pruebas, 6 955 comprobaciones,
      > TODO OK**.
      >
      > **La clave NO es sólo el destino, y eso contradice la spec.** Se
      > implementó como pedía —«se guarda por destino», frente 1— y se midió
      > (`AtascoProbe`, `SEMILLA=42`, 8 jornadas, pasos que el terreno corta
      > teniendo camino trazado):
      >
      > | clave | cortados | atascos |
      > |---|---|---|
      > | sin memoria | 10 | 0 |
      > | par origen-destino | 17 | 1 |
      > | **par, con las dos catas** (lo que queda) | **33** | **0** |
      > | sólo el destino, remate sin catar | 803 | 3 |
      > | sólo el destino, las dos catas | 2 295 | 2 |
      >
      > El motivo es geométrico y no se arregla afinando: con el par, quien
      > reutiliza la vereda está a setenta metros como mucho del primer hito;
      > con la clave por destino puede estar a kilómetros, y el enganche pasa a
      > ser una recta larguísima que ninguna cata razonable cubre —lo que se
      > anda no es el eje, cada uno va por su carril—. Catar más fino y con el
      > ancho del carril llevó la sonda de 48 s a más de 10 min. Ver
      > [ESTADO.md](ESTADO.md) §2 y el porqué largo en `Vereda.clave_de`.
      >
      > **Lo que sí queda de aquello, y es la mejora real: los dos extremos se
      > catan.** Antes nadie miraba ni el tramo de la persona al primer hito ni
      > el del último hito al punto exacto. Cuesta 33 pasos cortados contra 17,
      > y deja 0 atascos contra 1 y menos proporción de caminos que no merecen
      > andarse, con más reuso.
      >
      > **Y una lección de instrumento que costó más que la tarea:** las
      > primeras medidas se tomaron **sin fijar la semilla**, y eran ruido —el
      > mismo código dio 2 200, 1 747, 303 y 219—. Se llegaron a escribir dos
      > conclusiones falsas en ESTADO.md y hubo que retirarlas. La regla está
      > ahora en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1.
- [~] **C3. La vereda se afina con el uso.** En cada recorrido, un número corto
      y fijo de intentos de atajo sobre la ruta guardada: si del hito *i* se ve
      el *i+2* en línea limpia, se tira el de en medio. Sin búsquedas y sin
      azar.
      **Toca:** `scripts/sim/Marcha.gd` o `scripts/banda/BandKnowledge.gd`,
      `scripts/tests/TestVeredas.gd`.
      **Verificable:** prueba —una ruta con un hito prescindible lo pierde en
      unos recorridos, y ninguna ruta se alarga nunca—. Segundos.

      > **NO SE HACE, y hace falta decir por qué con cuidado.** Se implementó
      > entero —`Vereda.afinar`, con la regla de que el atajo se cobra con la
      > vara del trazado (`Navgrid.cost_of`) y no con la regla de medir, más
      > seis pruebas— y se midió con `AtascoProbe`. **Pero se midió sin fijar
      > la semilla**, así que aquella medida no vale y la conclusión que se
      > sacó de ella —«el afinado empeora el andar»— **queda retirada**.
      >
      > Se retira la tarea igualmente, y por una razón que no depende de
      > aquella medida: **C2 demostró que el problema de las veredas está en
      > los tramos rectos que nadie comprueba**, y el afinado consiste
      > precisamente en fabricar tramos rectos nuevos borrando hitos. La cata
      > que haría falta para que fuera seguro es la misma que en C2 llevó la
      > sonda de 48 s a más de 10 min. Antes de reabrirlo hay que resolver eso,
      > y eso es otra tarea.
      >
      > El código se borró —no se deja código muerto— y con él sus seis
      > pruebas. Queda escrito aquí y en `Vereda.clave_de` para que no se
      > reintente a ciegas.
- [x] **C4. El contador de búsquedas.** Búsquedas completas de camino por
      jornada simulada, que es la mitad del frente que hoy no se mide.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/sim/Marcha.gd`,
      `scripts/tests/RodeoProbe.gd`.
      **Verificable:** prueba de que cuenta lo que dice. Segundos.

      > **HECHO (2026-09-12), y de paso contesta M2.** `Wayfinder.busquedas`,
      > contado **dentro de `find`** y no en quien llama: todo el que busca
      > pasa por ahí, y un contador que se puede rodear no cuenta nada.
      > `AtascoProbe` lo saca por jornada.
      >
      > **Y aquí está la cifra que justifica el frente 1** (`SEMILLA=42`, 8
      > jornadas, sitio 56):
      >
      > | | búsquedas completas por jornada | pasos cortados |
      > |---|---|---|
      > | sin memoria de veredas | **265,8** | 10 |
      > | con memoria de veredas | **161,1** | 33 |
      >
      > **Las veredas ahorran el 39 % de las búsquedas de camino.** Ésa es la
      > mitad del frente que la spec mandaba medir aparte —«en vez de buscarse
      > de cero»— y es lo que el frente entrega de verdad, porque la otra
      > mitad, el rodeo que baja con el uso, se quedó sin hacer (C3).
      >
      > **La salvedad, dicha:** apagar la memoria cambia los caminos y con
      > ellos la partida, así que las dos corridas no andan exactamente los
      > mismos trayectos aunque compartan semilla. La comparación es por
      > jornada y sobre el mismo arranque, no trayecto a trayecto.

**La noche** (frente 2):

- [x] **N1. `SettlementSim.duerme_la_banda()`.** Una pregunta, un sitio:
      cierta cuando todas las personas están en `DURMIENDO`. El que vivaquea
      entra solo, porque el vivac también acaba en `DURMIENDO`.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/tests/TestNoche.gd`
      (nuevo). **Verificable:** pruebas —banda dormida sí; uno andando de vuelta
      no; el vivaqueador a varios kilómetros no bloquea—. Segundos.

      > **HECHO (2026-09-12), y se llama `nadie_trabaja()`, no
      > `duerme_la_banda()`.** El cambio de nombre no es cosmético: la primera
      > versión usaba la lectura estricta —todos en `DURMIENDO`— y **el usuario
      > la probó en el juego y dijo que la noche seguía yendo lenta**. La banda
      > no se acuesta a la vez, así que el que volvía andando del monte
      > bloqueaba la aceleración durante esa hora larga: 71 s por cuatro
      > jornadas contra los 62 de ahora, sobre 90 sin acelerar.
      >
      > **Y la spec decía «cuando nadie está trabajando» desde el principio**
      > (frente 2): la lectura estricta era del plan. Hoy frenan sólo
      > `TRABAJANDO`, `BUSCANDO` y `RECONOCIENDO` —lo que el jugador puede
      > querer ver—; andar, comer y dormir no. El que vivaquea entra solo, que
      > era el criterio explícito.
      >
      > `scripts/tests/TestNoche.gd`, 11 pruebas. Una de ellas afirmaba lo
      > contrario y **se reescribió diciendo por qué**, en vez de borrarla.
- [x] **N2. La noche se salta dando más pasos, no pasos más largos.** Se
      multiplica lo que entra en `_pendiente` y se sube el tope de pasos por
      cuadro; `PASO_FIJO`, `time_scale` y `Engine.time_scale` no se tocan. Así
      la sucesión de `_advance` es la misma que sin acelerar y la firma es
      idéntica por construcción.
      **Toca:** `scripts/sim/SettlementSim.gd`, `scripts/tests/TestNoche.gd`.
      **Verificable:** pruebas —con `Moment` de decisión levantado el reloj
      sigue parado; con la banda despierta no se acelera; el número de pasos por
      hora de juego no cambia—. Segundos.

      > **HECHO (2026-09-12), tal como lo planteó el plan y funcionó.**
      > `MS_DE_NOCHE_POR_CUADRO`: cuando no hay nada que mirar se dan tantos
      > pasos **del mismo tamaño** como quepan en 8 ms de cuadro. `PASO_FIJO`,
      > `time_scale` y `Engine.time_scale` sin tocar, así que la sucesión de
      > `_advance` es la misma que sin acelerar y la firma sale igual **por
      > construcción**. Ahorro medido: **31 % del reloj** (90 s → 62 s por
      > cuatro jornadas). El barrido del presupuesto, en [ESTADO.md](ESTADO.md)
      > §2: el ahorro se agota en 8 ms.
      >
      > **Tres cosas que salieron por el camino:**
      >
      > - **El cierre de jornada corta el cuadro.** El peor fotograma de la
      >   partida es la contabilidad de medianoche (M1), y la medianoche cae
      >   dentro de la noche acelerada: sin ese corte, ese fotograma se comería
      >   además el presupuesto entero.
      > - **`noche_acelerada`, un interruptor, y hacía falta de verdad**: la
      >   corrida que demuestra que esto no cambia la partida necesita la
      >   pareja con y sin. Se pone con `NOCHE=0`, igual que `SEMILLA=`.
      > - **Y tuvo que entrar en `Instantanea.FUERA`.** El primer cotejo dio
      >   firmas distintas y el único campo que las separaba **era el propio
      >   interruptor**: todo lo demás, idéntico. Es ritmo de reloj, no partida.

**Los grados** (frente 3):

- [x] **G1. `Termometro`: cuántos grados hace aquí y ahora.** Clase nueva en
      `scripts/mundo/`, una sola función pública, de estación, hora y cota a
      grados. Gradiente vertical **0,65 °C por 100 m, físico y no de balanceo**.
      La base al nivel del mar es **el clima cantábrico de hoy menos la anomalía
      magdaleniense** (decidido el 2026-09-12), las dos **con fuente citada en**
      [CREDITOS.md](CREDITOS.md): `RegionEras` no la tiene y no se inventa. Si
      una de las dos no aparece con cita, la tarea para y se dice.
      **Toca:** `scripts/mundo/Termometro.gd` (nuevo),
      `scripts/tests/TestTermometro.gd` (nuevo).
      **Verificable:** pruebas de entradas fijas a grados conocidos; el
      gradiente entre la cueva y el roquedo con su diferencia de cota real;
      mediodía de verano contra noche de invierno. Segundos.

      > **PARADA (2026-09-12), y es lo que la propia decisión mandaba hacer.**
      > De los dos datos que hacían falta, **uno está y el otro no**:
      >
      > - **La base al nivel del mar, SÍ.** Normales de AEMET 1991–2020,
      >   Santander/aeropuerto, 3 m de cota: media anual 14,8 °C y las doce
      >   medias mensuales. Anotadas en [CREDITOS.md](CREDITOS.md) con su
      >   fuente y su salvedad, para que nadie las vuelva a buscar.
      > - **La anomalía del Magdaleniense, NO.** Lo único concreto que apareció
      >   —El Mirón, medias «no superiores a 5 °C» en el último nivel
      >   solutrense— está **tras muro de pago** y llegó por un resumen de
      >   búsqueda, no leyendo el artículo. Citarlo así sería dar por verificado
      >   algo que no lo está.
      >
      > **Y hay un problema de fondo que el plan no vio:** el Magdaleniense
      > cantábrico va de ~17 000 a ~11 700 a.C. y **abarca la deglaciación
      > entera** —de casi el Último Máximo Glacial al Dryas Reciente—. Un solo
      > desfase fijo no lo describe, así que la pregunta que hay que llevar de
      > vuelta a `/spec` no es sólo «¿de dónde sale el número?» sino «¿la
      > partida empieza en un clima y termina en otro, o se congela en uno?».
      > Eso es diseño de época y no se decide aquí.
      >
      > **G2 se queda con G1**: sin grados no hay grados que enseñar.

      > **DESBLOQUEADA Y HECHA (2026-09-12): el usuario fijó la época al FINAL
      > del Magdaleniense, hacia el 12 000 a.C.** Eso contesta la pregunta de
      > diseño que la paraba —la partida se congela en un clima, no recorre la
      > deglaciación— y además abre la puerta al dato: 12 000 a.C. son ~14 ka
      > cal BP, dentro del Bølling–Allerød, que está mucho mejor reconstruido
      > que el Último Máximo Glacial.
      >
      > `scripts/mundo/Termometro.gd` (nueva), con una sola pregunta pública.
      > Fuentes en [CREDITOS.md](CREDITOS.md): AEMET 1991–2020 para la base al
      > nivel del mar y **Tarroso et al. (2016), *Climate of the Past* 12,
      > 1137–1149**, abierto, para el desfase.
      >
      > **Y el hallazgo no es la cifra sino la forma: aquello no era «como hoy
      > pero más frío», era MÁS ESTACIONAL** — invierno −5 °C, verano −2 °C—.
      > Es lo que sostiene que el abrigo sea una puerta y no un porcentaje. Ver
      > [SISTEMAS.md](SISTEMAS.md) §19.
      >
      > G2: la barra lleva los grados y, al lado, **la peor pieza de abrigo y no
      > la media** —`Toolkit.peor_condicion`, nueva—, porque la media no se
      > mueve cuando una sola se está acabando. Sigue **sin ser persona a
      > persona**: `Toolkit` no tiene dueños, y eso es tanda 2. Ver
      > [INTERFAZ.md](INTERFAZ.md) §4.

- [x] **G2. Los grados en la barra superior**, y la cobertura de vestido de la
      banda con el desgaste de la pieza peor —no persona a persona, ver la
      premisa de arriba—.
      **Toca:** `scripts/ui/BarraSuperior.gd`, `scripts/ui/GameUI.gd`,
      `scripts/tests/TermometroCaptura.gd` (nuevo).
      **Verificable:** captura **con ventana** en cuatro momentos —mediodía de
      verano y noche de invierno, en la cueva y en el roquedo— con los cuatro
      números distintos y en el orden que les toca. Con `--headless` la imagen
      sale nula. Minutos.

**Lo que se mide** (frente 4, y las corridas de los otros tres):

- [x] **M1. La línea base del fotograma malo, en esta máquina y hoy.**
      `PicoProbe` con sus valores por defecto. Las cifras de SPECS.md §6.1 son
      de otra corrida y el cepo mide reloj de pared: sin medida propia no hay
      con qué comparar. Va **antes** de tocar nada.
      **Toca:** [ESTADO.md](ESTADO.md) §2. **Corrida, ~2 min.**

      > **HECHO (2026-09-12).** `PicoProbe` con `VEL=5 DIAS=4 LIMITE=100` y
      > **con ventana** —a x5, que es la velocidad a la que se juega; x6 era el
      > valor por defecto de la sonda y no describe la partida—. 2 329 cuadros
      > en 90 s: **medio 38,6 ms, peor 112,8 ms, 1 tirón de más de 100 ms**.
      >
      > **Y el hallazgo, que el plan no esperaba: el único fotograma malo de la
      > partida es el cierre de jornada, no el dibujo.** Cae el día 1 a las
      > 23:58, son 113 ms, y de ellos 97 son `simulacion (SettlementSim)` y 42
      > `cierre de jornada`; el motor entero pone 8. Eso cambia qué hay que
      > vigilar en M4: la noche acelerada mete más pasos por cuadro **y la
      > medianoche cae dentro de la noche**, así que el riesgo no es un tirón
      > nuevo repartido, es que ese tirón que ya existe se junte con los pasos
      > extra en el mismo fotograma.
      >
      > Apuntado de paso, y sin arreglar: la línea «SIN MARCAR» del informe de
      > la sonda sale en negativo porque suma tramos anidados. Las cuatro cifras
      > de arriba las da el cepo, no esa suma. Ver [ESTADO.md](ESTADO.md) §2.
- [~] **M2. El rodeo y las búsquedas, en una sola pasada.** `RodeoProbe` con
      ~30 jornadas y el rehorneo **forzado** a mitad, en vez de esperar dos
      estaciones reales: converger cuesta unos recorridos, no noventa días.
      Contesta de una vez el rodeo al empezar, el rodeo tras converger, las
      búsquedas por jornada antes y después, y que tras el rehorneo el rodeo
      **sube y vuelve a bajar**. Depende de C1–C4.
      **Toca:** `scripts/tests/RodeoProbe.gd`, [ESTADO.md](ESTADO.md) §2.
      **Corrida, ~12 min.**

      > **NO SE HACE COMO ESTABA PLANEADA, y se ahorran los 12 min.** Dos
      > razones, las dos descubiertas al llegar aquí:
      >
      > - **`RodeoProbe` no simula jornadas de marcha**: fuerza la rejilla de
      >   cada estación y traza los mismos trayectos sobre ella. Mide el rodeo
      >   del **planificador**, no el de lo que la banda ha aprendido andando,
      >   así que la memoria de veredas no le aparece por ningún lado. El plan
      >   dio por hecho que sí, sin mirarlo.
      > - **Y lo que iba a medir ya no existe**: «el rodeo baja con el uso y
      >   vuelve a bajar tras el rehorneo» era C3, que se retiró. Sin afinado,
      >   no hay nada que converja.
      >
      > Lo que sí quedaba por medir del frente —el ahorro de búsquedas— **está
      > medido en C4**, en una corrida de 50 segundos en vez de doce minutos.
      > El suelo de rodeo de ESTADO.md §2 (x1,18 primavera, x1,43 verano) sigue
      > siendo el bueno: nada de esta tanda lo ha tocado.
- [x] **M3. La noche: lo que ahorra y que no cambia la partida.** Dos pasadas de
      60 jornadas con la misma semilla —una sin acelerar, otra con la noche
      acelerada—, cada una escribiendo segundos de reloj por jornada **y** sus
      firmas; `Cotejo` decide. La pasada sin acelerar trae de regalo las
      búsquedas por jornada sobre 60 días reales. Depende de N1, N2 y de que C1
      esté cerrada: mudar la memoria a `BandKnowledge` cambia la forma de la
      instantánea, y firmas de antes y de después no se comparan.
      **Toca:** `scripts/tests/TironAnualProbe.gd` o sonda nueva,
      [ESTADO.md](ESTADO.md) §2. **Corrida, ~41 min — confirmadas las 60
      jornadas el 2026-09-12**: la ventana corta sólo probaría la ventana.

      > **HECHO (2026-09-12), a la SEGUNDA, y la primera vez fue culpa mía.**
      >
      > Resultado: **las 60 jornadas con la misma firma**, con y sin acelerar.
      > Y 18 min 51 s contra 24 min 21 s, un **22,6 % de reloj** —menos que el
      > 31 % con ventana, porque en `--headless` el fotograma pesa menos y la
      > firma de cada jornada se paga igual en las dos ramas—.
      >
      > **La primera pasada dijo que se separaban en la jornada 26, y era
      > mentira.** Se lanzó a las 18:38 y, mientras corría, se cambiaron tres
      > cosas de la propia noche: la condición de entrada (`duerme_la_banda` →
      > `nadie_trabaja`), el presupuesto por cuadro y el corte al cerrar la
      > jornada. Aquella corrida no comparaba dos configuraciones sino **dos
      > versiones del código**, y ninguna era la que quedó.
      >
      > Costó hora y media y cuatro corridas de diagnóstico descubrirlo —dos
      > gemelas idénticas, un barrido del horno de rejillas, y un instrumento
      > que contaba pasos, cuadros y estado del azar por jornada—. De ese
      > instrumento salió el dato que lo desmontaba: **`pasos` y `azar`
      > idénticos jornada a jornada; sólo cambiaban los cuadros**. La lección
      > está en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1: **con una medida en
      > vuelo, el código no se toca.**
- [x] **M4. El re-medido del fotograma malo.** `PicoProbe` otra vez, con la
      noche acelerada puesta y en la misma sesión que M1. El peor fotograma y el
      tirón de la simulación no empeoran respecto de M1. Es el que puede tumbar
      el tope de pasos de N2.
      **Toca:** [ESTADO.md](ESTADO.md) §2. **Corrida, ~2 min.**

      > **HECHO (2026-09-12), y el criterio NO se puede dar por cumplido tal
      > como está escrito.** Las dos ramas medidas en la misma sesión y con el
      > mismo código: sin noche 90 s / 38,5 ms medio / 1 tirón; con noche 62 s /
      > 41,0 ms medio / 1 tirón.
      >
      > **El recuento de tirones no empeora** —1 y 1—, y ésa es la mitad del
      > criterio que sí se sostiene. **El fotograma medio empeora**, de 38,5 a
      > 41,0 ms, que es el precio de meter más simulación en el mismo cuadro.
      >
      > **Y el «peor fotograma» resultó no ser medible con una corrida:** es
      > una muestra suelta y el cepo mide reloj de pared. En configuraciones
      > que ahorran lo mismo dio 117, 122, 124, 125,7, 138,8, 144,9 y 146,1 ms,
      > y el valor más alto salió con el presupuesto **más pequeño**. Queda
      > apuntado en [ESTADO.md](ESTADO.md) §2 como aviso para quien lo use: hace
      > falta una mediana de varias corridas, no una cifra.
- [x] **M5. Cerrar.** Suite verde y **≥ 6 920 comprobaciones**,
      `LlamadasHuerfanas` en 0, y lo aprendido a su documento permanente:
      [SISTEMAS.md](SISTEMAS.md) §18 y §19, [INTERFAZ.md](INTERFAZ.md) §4,
      [SPECS.md](SPECS.md) §3.1 y §4.6, [ESTADO.md](ESTADO.md) §2 y §3.

      > **HECHO (2026-09-12).** Suite **979 pruebas, 6 994 comprobaciones, TODO
      > OK**, sobre un suelo de 932/6 920 — sube 47 pruebas y 74
      > comprobaciones. `LlamadasHuerfanas` dice 2, **las mismas dos de siempre
      > y ninguna de esta tanda**: `TestPartida.gd:185-186` llamando a un
      > miembro `static` por su clase, que es un falso positivo de la
      > herramienta con los estáticos, en un fichero sin versionar de otra
      > tanda. Va por `/depurar`.
      >
      > Documentado en SISTEMAS §18 y §19, INTERFAZ §4, SPECS §3.1 y §4.6,
      > CREDITOS «Clima», ARQUITECTURA §5.1 y ESTADO §2 y §3.

**Presupuesto de máquina: ~57 min de corridas**, en serie —Godot es de uno en
uno, AGENTES.md §3—: M1 (2) + M2 (12) + M3 (41) + M4 (2). Todo lo demás son
pruebas de segundos. **Lo caro es M3**, y es el único que de verdad pide 60
jornadas: la firma idéntica en cinco jornadas no diría nada del mes.

> **Lo que costó de verdad: unas 3 h 20 de máquina, contra las 57 min
> presupuestadas.** M2 se ahorró entero (12 min) y M3 se pagó **dos veces** (43
> + 43), más hora y media de diagnóstico que no estaba en ningún plan. De ese
> sobrecoste, **casi todo es de dos errores de método míos y no de la tanda**:
> medir sin fijar la semilla, y tocar el código con una medida en vuelo. Las
> dos reglas están ahora en [ARQUITECTURA.md](ARQUITECTURA.md) §5.1, que es
> donde se miran antes de medir.

**Qué se puede repartir entre agentes:** C1–C4 y G1–G2 tocan ficheros distintos
—`Marcha`/`BandKnowledge` contra `Termometro`/`BarraSuperior`— y van en
paralelo. **N1 y N2 no**, porque tocan `SettlementSim.gd` igual que C1. Y **dos
medidas nunca a la vez.**

---

### ~~🔴 El taller se para solo hacia la jornada 31~~ — cerrado: no era un fallo

Encontrado el 2026-09-12 por `/depurar`, buscando por qué no llegaba la talla
laminar. **Sin arreglar**, y es lo que de verdad cierra la rama de manufactura:
la práctica corre a 2,00 jornadas/día treinta días y **se cae a 0,3**, mientras
la cuarcita del almacén pasa de 96 a 3 054. No falta material: la banda se va
al canchal y no vuelve al taller.

Con eso ninguna técnica de manufactura pasada del núcleo preparado llega en un
año. La cifra medida y por dónde empezar a mirar, en
[ESTADO.md](ESTADO.md) §2.

**No se bajaron las jornadas de la talla laminar** —era el arreglo que se
barajó— porque taparía esto: con el taller parándose, la cifra nueva tampoco se
alcanza.

**Las tareas están arriba**, en «La puerta de entrada: los dos 🔴» (A1–A4), y
con una hipótesis que el plan técnico explica: `Taller._workshop_short` sabe qué
material falta y lo tira al devolver un `bool`, así que el recado sale a por
piedra cuando lo que falta es fibra.

---

### ~~🔴 El cuelgue de la hambruna total~~ — cerrado (2026-09-12)

**Un bucle infinito de verdad, reproducible con semilla fija.** Es lo primero,
porque mientras exista **no se puede correr ninguna sonda de año completo** con
un reparto pobre, y eso bloquea medir la pesca, la subsistencia y el ritmo.

```
SEMILLA=42 DIAS=95 BANDA=4,3,2   sobre scripts/tests/AnoProbe.gd
```

Lo que se sabe, y de dónde sale (medido al escribir la spec del secadero,
detalle completo en [archivo/SECADERO_Y_RIO.md](archivo/SECADERO_Y_RIO.md),
«Riesgos técnicos conocidos»):

- Se cuelga en el cruce verano→otoño. **17 minutos sin escribir una línea de
  log** consumiendo un núcleo entero (3 101 s de CPU en 3 120 s de reloj). No es
  una caída: hay que matarlo a mano.
- El último punto de control impreso (día 76, verano) da **despensa = 0 y hambre
  media de la banda = 100**, el máximo, con los quince todavía vivos.
- `BandaProbe.gd` sin modificar, con otro reparto y otra semilla, no se ha
  colgado en 45 días.

**La hipótesis que había aquí está descartada, y por lectura.** Decía «un bucle
en el camino de muertes masivas simultáneas, por ejemplo recorrer `sim.people`
mientras `_person_dies()` lo modifica», con `Relevo.gd` de sospechoso **sin
leer**. Leído: `Relevo.revisar_vejez`, `revisar_frio` y `revisar_hambre` ya
recorren `sim.people.duplicate()`, y el comentario de `Relevo.gd:125` dice por
qué. Los demás bucles de salida variable de la simulación —`Reparto.set_job_count`,
`Inhabitant.create_band`— decrecen en cada vuelta. El diagnóstico empieza de
cero.

Lo que sigue en pie es la otra mitad: **no se descarta que el reparto 4,3,2 sea
insosteniblemente pobre bajo el código actual**, lo cual sería un hallazgo de
balanceo por sí solo.

**Las tareas están arriba**, en «La puerta de entrada: los dos 🔴» (B1–B6): es
la única copia, para que no haya dos listas del mismo trabajo.

> **Dueño:** era `history-of-man-0e`, que ya no está viva y **no dejó nada en
> `scripts/` ni en el log** —comprobado el 2026-09-12, no supuesto: una pizarra
> vacía puede ser «ya terminó» y aquí no lo era—. Lo lleva `history-of-man-b2`.

---

### El secadero y el río

De [ESTADO.md](ESTADO.md) §5, bloque «Segundo: que la carne importe». La spec
completa, con sus tres lecturas sucesivas del dato, está en
[archivo/SECADERO_Y_RIO.md](archivo/SECADERO_Y_RIO.md).

- [ ] **El otoño como pico de curado, no como ventana única.** El secadero cura
      más por jornada en otoño que en cualquier otra estación, con la misma
      gente. Sigue curando el resto del año: la caza de invierno también tiene
      que poder guardarse.
      **Verificable:** una sonda que fuerce carne y pescado frescos de sobra en
      las cuatro estaciones, con el mismo número en `Job.HOGAR`, mide más
      raciones curadas por jornada en otoño. Hoy `Hogar.DRY_PER_DAY` da
      exactamente 24 en las cuatro, sin excepción.

- [ ] **La pesca sin sitio conocido.** 🔓 **Desbloqueada el 2026-09-12**: el
      cuelgue está cerrado y la corrida de 95 jornadas llegó al final, así que
      hay tercera medida. Sigue en pie la contradicción de las dos primeras
      lecturas —a 45 jornadas parecía resuelto, a 90 la producción se hundía—, y
      la medida nueva la confirma: **de 41,45 a 5,60 raciones por pescador y
      día** de primavera a verano, con los mismos 90 jornadas-persona. Lo nuevo
      es que ahora se sabe que **no es falta de sitio**: el «sin sitio» baja del
      36,2 % al 2,1 % del día y el tiempo trabajando SUBE del 21,9 % al 37,2 %.
      Trabaja más y saca menos. Las cifras, en ESTADO.md §2.
      **Verificable:** una sonda de año completo, dos pescadores y sin
      exploradores, midiendo la pesca por persona y día estación a estación. Si
      colapsa, la sonda dice en cuál y cuánto, y se vuelve a `/spec`.

**Fuera de este bloque, decidido:** bajar las kcal del fruto seco (queda sólo un
número de balanceo), restringir el curado a otoño (se decidió en contra),
la curva de `ResourceField.regrow`, limpiar `ResourceField.deplete_at` (código
muerto), y tocar `Job.EXPLORACION`.

---

### Los gráficos

El diseño, el presupuesto de fotograma y lo ya medido están en
[GRAFICOS.md](GRAFICOS.md); el plan original fase a fase, en
[archivo/REVAMP_GRAFICO.md](archivo/REVAMP_GRAFICO.md). Hecho: medir (G0), el
calibrado de paleta (G3) y la ingesta PBR de las ocho capas (G2, a medias).

- [ ] **Terminar la reforma del shader.** Quedaba la palanca de la anisotropía
      (−4,5 ms medidos) sin aplicar, y el salto de capas por peso, que hoy
      recorta la contribución pero **no evita el muestreo**.
      **Verificable:** `GpuProfile.gd`, con el terreno dentro de su casilla de
      6,0 ms del presupuesto.

- [ ] **Lo que hay en el suelo.** Va **antes que la gente**, y no por gusto: el
      sistema ya existe —`ResourceProps` y `Forest` siembran con densidad por
      celda, rareza y balanceo de viento— y lo que falta es **la malla**, que
      hoy son esferas, cilindros y prismas de un color. Incluye la deuda que
      dejó G2: el roquedo tiene que tener **silueta propia, no sólo dibujo**.

- [ ] **Cuerpo y escala.** Seis bases MPFB2, rig, import, y fuera las cápsulas.
      **Verificable:** la banda son personas de 1,70 m y la cámara sigue siendo
      usable.

- [ ] **Locomoción**: los 15 clips de estado, atados a `Inhabitant.State`.
      **Verificable:** se distingue quien va, quien vuelve cargado y quien
      duerme.

- [ ] **Trabajo**: los 20 bucles de especialidad, con el apero en la mano.
      **Verificable: se sabe qué está haciendo cada uno sin abrir un panel** —
      es el criterio que justifica el revamp entero.
      ⚠️ Es **la partida más cara**, y donde esto puede morir a medias dejando
      personas realistas en pose T. Se entrega **por oficios completos**: caza
      entera, luego ribera entera.

- [ ] **Ropa paleolítica**: slots y el set del Magdaleniense.
      **Verificable:** cambiar de época cambia la ropa sin tocar el esqueleto.

- [x] **Panel de gráficos**: `GraphicsSettings`, interfaz y persistencia.
      **Verificable:** Alto da 60 FPS en la 1070; Bajo, 60 en una integrada.
> **HECHO de otra forma (2026-09-14)**: la ventana de configuración de INTERFAZ §8 —`Configuracion` y `VentanaDeConfiguracion`, no `GraphicsSettings`— con los niveles medidos en GRAFICOS §7. **El objetivo 1070 es ahora Medio**, decisión del usuario, y **no se ha medido en una 1070 ni en una integrada**: no hay ese equipo a mano.

---

### Lo mismo, más deprisa — casi cerrado

El bloque de rendimiento está hecho y medido: **la misma semilla da la misma
partida durante un año entero**, comprobado con cotejo de firmas, y los tirones
se han ido. Las cifras están en [ESTADO.md](ESTADO.md) §5; el relato completo,
en [archivo/LO_MISMO_MAS_DEPRISA.md](archivo/LO_MISMO_MAS_DEPRISA.md).

Lo que queda vivo:

- [ ] **`Instantanea.volcar`: de bytes a la partida** (tarea 15 del bloque). El
      sentido de vuelta está sin construir; sin él una instantánea se toma pero
      no se restaura.
      **Verificable:** en `TestInstantanea.gd`, tomar → volcar sobre una
      simulación nueva → volver a tomar da los mismos bytes; tras volcar, diez
      pasos en las dos simulaciones dan la misma firma; y un campo guardado que
      no existe en la clase da error.

- [ ] **El año de cierre**, cuando el usuario dé el bloque por cerrado. Está
      medido y a la espera de esa decisión, no de más trabajo.

- [ ] **Dos palancas que cambian la partida**, y las decide el usuario: no se
      tocan sin que lo diga.

---

## FASE A — Cerrar el circuito de juego

Lo que falta para que esto deje de ser dos visores y pase a ser un juego.

### A1. Enclave inicial y exploración — **hecho en la capa local**
- Se empieza con **un solo emplazamiento conocido** (`GameState.HOME_LAT/LON`,
  Cueva los Pendios) y el territorio se descubre saliendo: `Exploration`,
  `Reconocimiento`, `BandKnowledge` y los `Parajes` que se ganan un nombre.
- **La niebla regional está puesta** (corregido el 2026-09-12, midiendo):
  `GameState.discovered` arranca con sólo la cueva y `RegionMap` filtra por él.
  Este documento decía «hoy el mapa regional se ve entero» y no era cierto.
- **Lo que falta es QUIÉN la levanta**: nadie llama a `GameState.discover`
  desde la partida, así que la niebla no se abre nunca. Eso lo construye la
  expedición regional — ver «En curso» → Tanda 2, tarea E3.
- Criterio cumplido: al empezar se ve **uno**, no 862. Y de paso, los usables
  en el Paleolítico son **72**, no 862. Ver ESTADO.md §2.

### A2. El asentamiento existe — **hecho**
- `SettlementSim` es el asentamiento, con población concreta, oficios y rutina.
- La capacidad de carga no es «según la técnica disponible» en abstracto: es lo
  que da el territorio (`ResourceField`, `Subsistence`) y lo que cabe en la
  despensa (`Storehouse.capacidad_de_comida`).
- **Lo que falta**: salir al mapa regional y volver **no conserva el estado**.
  Eso es A3.

### ~~A3. Persistencia~~ — **hecha el 2026-09-13**
- Guardar y cargar de verdad: cerrar el juego y recuperar la partida.
- **`Instantanea` no es esto.** Es un instrumento de medida —comparar dos
  corridas, arrancar una sonda en la jornada N— y no promete que un fichero de
  hoy sirva mañana. Ver SPECS.md §6.4. Reutilizar su recorrido por reflexión es
  razonable; darla por guardado, no.
- Criterio: cerrar el juego y recuperar la partida.
- **HECHA el 2026-09-13** (tanda 3, frente 15): `Guardado` (`region/`), un
  fichero automático por partida, que se escribe al volver al mapa regional y se
  ofrece desde él —«Volver con la banda»—. Medido en dos procesos: guardar,
  cerrar, abrir y cargar da **las mismas cinco firmas diarias** que la partida
  que no se guardó. Ver SPECS §6.4 y ROADMAP «En curso» → Tanda 3, G1–G3.

---

## FASE B — El juego de verdad: procesos

Aquí está lo que distingue este proyecto de un city builder cualquiera.

### B1. `ProcessRecipe`
Entradas, herramientas, conocimiento, energía, jornadas, salidas y
**subproductos**. Los subproductos no son adorno: la escoria se acumula, la
ceniza abona y las conchas forman el conchero, que en Cantabria es el
yacimiento en sí.

### B2. La escalera térmica

> **Corrección.** Este apartado decía que «`RawMaterial` ya guarda punto de
> fusión e ignición, o sea que el árbol tecnológico ya está escrito: no hay que
> inventarlo, hay que leerlo». **Es falso**: `RawMaterial` se retiró con el resto
> de la capa de *city builder*. La secuencia de temperaturas de la tabla es
> correcta, pero **hay que escribirla de cero** cuando le toque, no leerla de un
> sitio que ya no existe. El sitio natural es `Materia.gd`, con dos campos
> opcionales (`melts_at`, `ignites_at`) sólo en los materiales que importan —ver
> [SISTEMAS.md](SISTEMAS.md) §1.1.

| Instalación | Máx. | Habilita |
|---|---|---|
| Hogar abierto | ~700 °C | Cocinar, calcinar conchas |
| Horno de fosa | ~900 °C | Cerámica |
| Cubeta con fuelle | ~1100 °C | Cobre (1085 °C) |
| Horno mejorado | ~1200 °C | Bronce |
| Cuba baja | ~1250 °C | Hierro **en estado sólido**: esponja, no colada |
| Ferrería hidráulica | ~1350 °C | Barras en cantidad |
| Alto horno | ~1550 °C | Fundir hierro (1538 °C) |

El salto de la esponja a la colada es una frontera tecnológica real, y es la
frontera de época entre la Baja Edad Media y la Moderna.

### B3. Primera cadena completa
Cuarcita de río → pico → marisqueo → conchero. Corta y cerrada. **Si esa cadena
no es satisfactoria, el resto es contenido sobre un juego que no funciona.**

---

## FASE C — El arte como motor

El saber tácito muere con quien lo tiene. Fijarlo en un soporte material lo
convierte en patrimonio del grupo: por eso el arte funciona como motor
tecnológico sin dejar de ser arte.

### C1. Estados de técnica
`DESCONOCIDA` → `TÁCITA` (decae con el relevo generacional) → `EXTERNALIZADA`
(permanente, pero atada al sitio donde está el soporte).

### C2. Externalización
No se puede pintar una caza que no se ha hecho: la obra tiene que ser **sobre**
algo ocurrido. Cuesta ocre, luz y jornadas.

### C3. Escalera de soportes
Parietal (inmóvil) → mobiliar (portátil) → cerámica (replicable) →
**escritura** → imprenta. El salto está en la escritura: antes hay que enseñar
mostrando, después basta con contar.

**Guardarraíl: no debe existir una puntuación de arte.** El recurso escaso
obliga a elegir *cuál* saber se hace permanente. Es una mecánica de
priorización sobre el árbol tecnológico, no una vía paralela que le compita.

---

## FASE D — Épocas

**Once** épocas con cultura material documentada en Cantabria, del Paleolítico
al siglo XIX. Cada una es **datos**: materiales, procesos y edificios
disponibles, más las técnicas que hay que externalizar para cerrarla.

Fueron doce hasta el 2026-09-12: el siglo corto (1900–1982) se retiró porque el
motor de jornadas y calorías no simula jornal ni capital, y está archivado en
[archivo/EPOCA_12_SIGLO_CORTO.md](archivo/EPOCA_12_SIGLO_CORTO.md). Con
él se fue el final circular de la partida —*el mapa se cierra sobre
`cantabria.json`*—, que **queda pendiente de decidir**: hoy la partida acaba en
el hito de cierre de El vapor, que es un cierre de época haciendo de final.

Están escritas una a una en [EPOCAS.md](EPOCAS.md), con el hito que cierra cada
una y la regla que decide qué merece ser época y qué no. El nivel de
implementación de cada una —catálogo de técnicas, condición de disparo de
cada hito, oficios nuevos, clases a escribir— está en `EPOCA_NN_NOMBRE.md`
junto a esa misma época, y lo que comparten las once vive en
[SISTEMAS.md](SISTEMAS.md): las tres escaleras
(térmica, soporte, alimento), el sistema de `Hito`, la exploración en tres
capas —local ya construida, regional pendiente en A1, exterior sin
empezar—, el comercio y los cuatro hitos que se sufren.

**El tiempo avanza por hitos, no por calendario.** El Paleolítico es el 99,4 %
del intervalo real; si el tiempo de juego fuese proporcional, la partida entera
sería tallar cuarcita. El calendario sigue corriendo dentro de una época para
estaciones y cosechas.

Hoy el filtro por época existe pero usa **abrigo y relieve**, no periodo
arqueológico: 86 emplazamientos ocupables en el Paleolítico porque tienen cueva,
que es la única vivienda de esa época.

---

## FASE E — Fidelidad y datos

### E1. Agua real
Ríos y lagos desde polígonos de OpenStreetMap. Lo actual los deduce del
relieve, que acierta el trazado del valle pero no la geometría. Arreglaría de
paso que `water_km` no se recalcule por época.

### E2. Periodos arqueológicos reales
Cruzar con el inventario del Gobierno de Cantabria. OSM solo trae periodo en
unas decenas de registros.

### E3. Geología
IGME MAGNA 1:50.000 para que los recursos líticos y minerales salgan del
sustrato real y no del ruido celular.

### E4. Trazabilidad visible
Cada material, proceso y edificio con su nivel de evidencia
(`ATESTIGUADO` / `INFERIDO` / `PLAUSIBLE`) y su fuente, expuestos en una
enciclopedia dentro del juego.

**«100 % históricamente fiable» no es alcanzable** —hay siglos de los que no
sabemos qué comía la gente— y perseguirlo es el mayor riesgo de que el proyecto
no termine nunca. Lo que sí se puede garantizar y defender es que ninguna
afirmación del juego esté sin etiqueta, y que la proporción de `PLAUSIBLE` esté
acotada.

---

## FASE F — Deuda e infraestructura

Sin orden fijo; se atiende cuando estorbe.

- Descarga de teselas en un hilo, con barra de progreso. Hoy congela la ventana.
- Dejar sólo el `InputMap` en `OrbitalCamera`: lee las teclas físicas **y** las
  acciones para el mismo eje, y eso anula el remapeo configurado en
  `project.godot`.
- Reactivar el ciclo día/noche (`WorldEnvironmentSetup.follow_time_of_day`), hoy
  desactivado a propósito para trabajar con luz.
- Decidir qué pasa con las capas de física 2–4 (`props`, `resources`, `banda`):
  están nombradas en `project.godot` y no se asigna ninguna. O se usan, o se
  retiran. Ver SPECS.md §5.
- Otra pasada de troceado a `SettlementSim`, que ha vuelto a 4 119 líneas. La
  receta y sus trampas, en ARQUITECTURA.md §3.
- Tirones de la capa local que crecen con los días: bajar su coste sin cambiar
  la partida, con la misma semilla dando la misma partida antes y después. Ver
  [archivo/LO_MISMO_MAS_DEPRISA.md](archivo/LO_MISMO_MAS_DEPRISA.md).

Cerrado y fuera de esta lista: la suite de pruebas, las bocas de
cueva contra la ladera (`CaveMouth`), e `Inventory.gd`/`GameUtils.gd`, que se
retiraron del repositorio con el resto de la capa vieja.

---

## Riesgos

**El alcance.** Cuarenta mil años, once épocas, procesos físicos, comercio y
fidelidad histórica sigue siendo más de lo que cabe en un proyecto personal.
Retirar el siglo corto fue el primer recorte real, no el último: EPOCAS.md §7
deja escrito el orden de los siguientes. La FASE B3 —una sola cadena completa y
corta— existe justamente para comprobar pronto si el núcleo divierte, antes de
construir contenido encima.

**El trabajo en paralelo.** Con varios agentes sobre el mismo árbol, lo que
rompe no es el código sino la medida: dos sondas a la vez no miden nada. El
protocolo está en [AGENTES.md](AGENTES.md) y no es opcional.

**El dato manda hasta donde llega.** El DEM tiene una muestra cada 14 m; por
debajo de esa escala todo lo que se ve es invención. Conviene recordarlo cada
vez que algo parezca poco detallado: la respuesta no es añadir ruido.
