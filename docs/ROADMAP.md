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
| El cuelgue que bloquea las sondas de año completo | «En curso» → El cuelgue de la hambruna total |
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
- **Suite de pruebas.** 887 pruebas y 6 163 comprobaciones, más las sondas de
  medida. El ROADMAP pidió una durante tres fases; ya está.
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

### 🔴 El cuelgue de la hambruna total

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

**La hipótesis, dicha como hipótesis y no como diagnóstico:** un bucle en el
camino de muertes masivas simultáneas — por ejemplo recorrer `sim.people`
mientras `_person_dies()` lo modifica a mitad de iteración. `Relevo.gd` es el
sospechoso y **no se ha leído todavía**. Tampoco se descarta que el reparto
4,3,2 sea insosteniblemente pobre bajo el código actual, lo cual sería un
hallazgo de balanceo por sí solo.

- [ ] **Diagnosticar el cuelgue.** Reproducirlo, aislar el bucle y decir cuál
      es — no arreglar el primer sospechoso. **Verificable:** la corrida de
      arriba termina y escribe sus tablas.
- [ ] **Arreglarlo**, con una prueba en `scripts/tests/` que falle antes.
- [ ] **Decir si el reparto 4,3,2 es viable**, que es la otra mitad de la
      pregunta y no se contesta sola al arreglar el bucle.

> **Dueño:** asignado a la sesión que llevó el bloque de rendimiento
> (`history-of-man-0e`). Si lo coge otro, que lo diga en la pizarra primero.

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

- [ ] **La pesca sin sitio conocido.** 🔒 **Bloqueada por el cuelgue.** El
      alcance no se puede fijar hasta diagnosticarlo, y las tres lecturas del
      dato se contradicen entre sí a propósito: a 45 jornadas parecía resuelto,
      a 90 la producción se hundía un 91,5 % de una estación a la siguiente sin
      que cambiara el número de parajes trabajados, y la tercera medida no
      llegó a terminar.
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

- [ ] **Panel de gráficos**: `GraphicsSettings`, interfaz y persistencia.
      **Verificable:** Alto da 60 FPS en la 1070; Bajo, 60 en una integrada.

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
- **Lo que falta es la capa regional**: revelar `Site` del mapa de Cantabria por
  proximidad y por expedición. Hoy el mapa regional se ve entero.
- Criterio pendiente: el jugador no ve los 862 de golpe; los descubre.

### A2. El asentamiento existe — **hecho**
- `SettlementSim` es el asentamiento, con población concreta, oficios y rutina.
- La capacidad de carga no es «según la técnica disponible» en abstracto: es lo
  que da el territorio (`ResourceField`, `Subsistence`) y lo que cabe en la
  despensa (`Storehouse.capacidad_de_comida`).
- **Lo que falta**: salir al mapa regional y volver **no conserva el estado**.
  Eso es A3.

### A3. Persistencia — **sin empezar, y con una confusión que aclarar**
- Guardar y cargar de verdad: cerrar el juego y recuperar la partida.
- **`Instantanea` no es esto.** Es un instrumento de medida —comparar dos
  corridas, arrancar una sonda en la jornada N— y no promete que un fichero de
  hoy sirva mañana. Ver SPECS.md §6.4. Reutilizar su recorrido por reflexión es
  razonable; darla por guardado, no.
- Criterio: cerrar el juego y recuperar la partida.

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

Cerrado y fuera de esta lista: la suite de pruebas (887 pruebas), las bocas de
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
