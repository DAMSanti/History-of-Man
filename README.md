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

716 pruebas, 5 171 comprobaciones. Tienen que estar todas en verde.

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

| | |
|---|---|
| [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) | **cómo está montado y cómo se escribe código aquí** |
| [docs/ESTADO_DE_LA_SLICE.md](docs/ESTADO_DE_LA_SLICE.md) | **qué hace hoy, qué falta para que sea jugable, medido** |
| [docs/INTERFAZ.md](docs/INTERFAZ.md) | la piel de la interfaz y cómo cambia con las eras |
| [docs/PERRO_Y_BELLOTA.md](docs/PERRO_Y_BELLOTA.md) | dos mecánicas de época, listas para implementar |
| [docs/SLICE_PALEOLITICO.md](docs/SLICE_PALEOLITICO.md) | qué tiene que demostrar la rebanada jugable |
| [docs/ROADMAP.md](docs/ROADMAP.md) | por dónde va y qué falta |
| [docs/EPOCAS.md](docs/EPOCAS.md) | las doce épocas y el hito que cierra cada una |
| [docs/CAZA_Y_PESCA.md](docs/CAZA_Y_PESCA.md) | el modelo de subsistencia, con sus medidas |
| [docs/REVAMP_GRAFICO.md](docs/REVAMP_GRAFICO.md) | el trabajo de imagen y su coste medido |
| [docs/CIERRE_SLICE.md](docs/CIERRE_SLICE.md) | el cierre de la rebanada |
| [docs/SPECS.md](docs/SPECS.md) | especificación de partida |
| [docs/CREDITOS.md](docs/CREDITOS.md) | de dónde sale cada dato y cada modelo |
