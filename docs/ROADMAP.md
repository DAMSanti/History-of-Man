# Roadmap — CityBuilder cántabro (Godot 4.5.1)

City builder del Paleolítico al siglo XX sobre el relieve real de Cantabria.

Este documento se reescribió el **2026-09-02**, tras adoptar la arquitectura de
dos escalas. La versión anterior planificaba un mundo único con streaming de
chunks; esa decisión quedó anulada y con ella varias fases enteras. Lo que
sigue refleja el estado real del código, no el deseado.

Ver [SPECS.md](SPECS.md) para el contrato técnico de cada módulo.

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
- **`BlockData`** implementado; los `.tres` de `buildings/` cargan tipados.
- **Colisión de edificios** en la capa `buildings`.
- **Caché de texturas de terreno** (antigua FASE 5.1). Se generaban 8 texturas
  píxel a píxel en cada `generate()`: 4 s que se pagaban una y otra vez.
- **Rendimiento.** De 4,2 a ~28 FPS con un mapa 12 veces mayor. Las causas eran
  texturas sin mipmaps y 24 muestreos por fragmento en el shader triplanar.

### Deuda pendiente

| | Estado |
|---|---|
| `scripts/Inventory.gd` | **0 bytes** |
| `scripts/GameUtils.gd` | **0 bytes** |
| Señales duplicadas en `TimeManager` (`cambio_de_estacion` / `season_changed`) | sin unificar |
| Entrada duplicada en `CameraController` (teclas físicas + acciones) | sin unificar |
| Descarga de teselas bloqueante | congela la ventana unos segundos |
| Ríos y lagos | deducidos del relieve, no de datos reales |

---

## FASE A — Cerrar el circuito de juego

Lo que falta para que esto deje de ser dos visores y pase a ser un juego.

### A1. Enclave inicial y exploración
- Empezar con **un solo emplazamiento conocido**; el resto del mapa, oculto.
- Revelar por proximidad y por expediciones.
- Criterio: el jugador no ve los 862 de golpe; los descubre.

### A2. El asentamiento existe
- Un `Settlement` con población, y que el mapa local muestre lo que hay
  construido en vez del demo de cabañas de prueba.
- Capacidad de carga del emplazamiento según la técnica disponible.
- Criterio: fundar, salir al mapa regional y volver conserva el estado.

### A3. Persistencia
- Guardar y cargar. `Chunk.serialize()` y `TimeManager.get_time_state()` ya
  existen y no los llama nadie.
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
`RawMaterial` ya guarda punto de fusión e ignición, o sea que **el árbol
tecnológico ya está escrito**: no hay que inventarlo, hay que leerlo.

| Instalación | Máx. | Habilita |
|---|---|---|
| Hogar abierto | ~700 °C | Cocinar, calcinar conchas |
| Horno de fosa | ~900 °C | Cerámica |
| Cubeta con fuelle | ~1100 °C | Cobre (1085 °C) |
| Horno mejorado | ~1200 °C | Bronce |
| Cuba baja | ~1250 °C | Hierro **en estado sólido**: esponja, no colada |
| Ferrería hidráulica | ~1350 °C | Barras en cantidad |
| Alto horno | ~1550 °C | Fundir hierro (1538 °C) |

El salto de la esponja a la colada es una frontera tecnológica real, y cae sola
con los datos que ya están en `Iron.tres`.

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

Épocas con cultura material documentada en Cantabria, del Paleolítico al siglo
XX. Cada una es **datos**: materiales, procesos y edificios disponibles,
más las técnicas que hay que externalizar para cerrarla.

Están escritas una a una en [EPOCAS.md](EPOCAS.md), con el hito que cierra cada
una y la regla que decide qué merece ser época y qué no.

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

- Descarga de teselas en un hilo, con barra de progreso.
- `Inventory.gd` y `GameUtils.gd`: implementar o retirar del repo.
- Unificar las señales duplicadas de `TimeManager`.
- Dejar solo el `InputMap` en `CameraController`, para que el remapeo funcione.
- Reactivar el ciclo día/noche (`follow_time_of_day`), hoy desactivado a
  propósito para trabajar con luz.
- Orientar las bocas de cueva contra la normal de la ladera. Hoy son medias
  esferas mirando arriba; una boca real se abre lateralmente.
- Suite de pruebas. No hay ninguna.

---

## Riesgos

**El alcance.** Cuarenta mil años, doce épocas, procesos físicos, comercio y
fidelidad histórica es más de lo que cabe en un proyecto personal. La FASE B3
—una sola cadena completa y corta— existe justamente para comprobar pronto si
el núcleo divierte, antes de construir contenido encima.

**El dato manda hasta donde llega.** El DEM tiene una muestra cada 14 m; por
debajo de esa escala todo lo que se ve es invención. Conviene recordarlo cada
vez que algo parezca poco detallado: la respuesta no es añadir ruido.
