# History of Man

Simulación de una banda paleolítica en la Cantabria del Magdaleniense, sobre
relieve real. Godot 4.5.1, Forward+.

No se construye una ciudad: se lleva a quince personas a través de un año.
Salen a recoger, a pescar y a cazar, aprenden técnicas, se hacen herramientas
que se rompen, y el otoño decide si sobreviven al invierno.

## Cómo se juega

Dos capas. En la **regional** se ve Cantabria entera —869 emplazamientos
derivados del MDT real y cruzados con el registro arqueológico— y se elige
dónde fundar. En la **local** se juegan 4 km de valle alrededor del abrigo
elegido.

El jugador no da órdenes de tarea: reparte prioridades en la tabla de trabajos
y cada mañana la banda se organiza sola con lo que puede hacer ese día.

## Arrancar

Abrir el proyecto en Godot 4.5.1 y darle a play. La escena principal es
`scenes/region_map.tscn`.

La primera vez que se funda un emplazamiento se descarga su relieve del IGN
(MDT05, LiDAR) y se hornea; a partir de ahí se lee de `data/dem/local/`.

## Las pruebas

```
godot --headless --path . --script res://scripts/tests/RunTests.gd
```

887 pruebas, 6 163 comprobaciones. Tienen que estar todas en verde.

Aparte están las **sondas** (`scripts/tests/*Probe.gd`), que no pasan ni
fallan: miden. El balanceo de este proyecto se ajusta midiendo.

```
DIAS=40 godot --path . --script res://scripts/tests/JornadaCazadorProbe.gd
```

## Datos

`data/dem/`, `models/` y `textures/terrain/` no se versionan: son cientos de MB
que se reconstruyen solos con las herramientas de `scripts/tools/`. La tabla de
qué rehace cada cosa está en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) §7.

Fuentes: MDT del IGN/CNIG, teselas Terrarium de AWS, OpenStreetMap, y modelos
CC0 de Poly Haven y Quaternius. El detalle está en
[docs/CREDITOS.md](docs/CREDITOS.md).

La letra manuscrita de la interfaz es **Caveat**, con licencia SIL OFL 1.1
(`fonts/Caveat-OFL.txt`). Ésa sí se versiona: son 400 kB y sin ella la interfaz
del Paleolítico sale con la tipografía de serie.

## Documentación

`docs/` tiene un **conjunto fijo** de documentos. No se crea uno nuevo por cada
trabajo: lo único específico son las once fichas de época.

| | |
|---|---|
| [docs/SPECS.md](docs/SPECS.md) | **el contrato técnico: qué existe y qué no se puede romper** |
| [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) | **cómo está montado y cómo se escribe código aquí** |
| [docs/ESTADO.md](docs/ESTADO.md) | **qué hace hoy, qué falta para que sea jugable, medido** |
| [docs/ROADMAP.md](docs/ROADMAP.md) | por dónde va, qué falta, y las tareas en curso |
| [docs/SISTEMAS.md](docs/SISTEMAS.md) | los sistemas del juego: la caza, la pesca, la despensa, el relato, los hitos, el comercio |
| [docs/EPOCAS.md](docs/EPOCAS.md) | las once épocas y el hito que cierra cada una |
| [docs/EPOCA_01…11_*.md](docs/EPOCA_01_PALEOLITICO.md) | una ficha por época — **lo único específico** |
| [docs/GRAFICOS.md](docs/GRAFICOS.md) | cómo se dibuja, qué cuesta y el presupuesto de fotograma |
| [docs/INTERFAZ.md](docs/INTERFAZ.md) | la piel de la interfaz y cómo cambia con las eras |
| [docs/AGENTES.md](docs/AGENTES.md) | cómo trabajan varios agentes a la vez sin pisarse |
| [docs/CREDITOS.md](docs/CREDITOS.md) | de dónde sale cada dato y cada modelo |
| [docs/archivo/](docs/archivo/README.md) | lo cerrado: specs terminadas y diseño descartado. **No se edita** |

La tabla de qué documento se lee y se actualiza para cada clase de trabajo está
en [CLAUDE.md](CLAUDE.md).
