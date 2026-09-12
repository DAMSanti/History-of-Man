# History of Man — instrucciones del repositorio

Simulación de una banda paleolítica en la Cantabria del Magdaleniense sobre
relieve real. Godot 4.5.1, GDScript, Forward+.

## Antes de tocar nada: ¿hay alguien más?

**Este repositorio se trabaja con varios agentes a la vez.** Antes de la primera
edición:

1. Lee `.claude/agentes/pizarra.md` y **firma tu bloque** con lo que vas a tocar
   (y lo que puede que toques).
2. Si un fichero que necesitas ya lo declaró otro, **no lo edites**: háblale
   (`ListAgents` / `SendMessage`) y haz mientras tanto lo que no dependa de él.
3. Borra tu bloque al terminar.

**Godot es de uno en uno.** Cada proceso parsea todos los scripts al arrancar, y
las sondas miden reloj de pared: dos corridas a la vez no miden nada. Toma el
turno antes de arrancarlo y suéltalo siempre:

```bash
mkdir .claude/agentes/turno-godot 2>/dev/null \
  && echo "<agente> · <qué corro> · $(date +%H:%M)" > .claude/agentes/turno-godot/quien \
  || cat .claude/agentes/turno-godot/quien
# ...
rm -rf .claude/agentes/turno-godot
```

**Con el turno tomado, nadie edita un `.gd`** — ni el que lo tiene. Los `.md` sí.

El protocolo entero, incluidas las reglas de git: [docs/AGENTES.md](docs/AGENTES.md).

## El binario

Godot está en `E:\Godot\Godot_v4.5.1-stable_win64.exe`, **no** donde dice
`.vscode/settings.json`.

## Comprobar

```
godot --headless --path . --script res://scripts/tests/RunTests.gd
```

**887 pruebas, 6 163 comprobaciones**, en verde siempre. Mira las dos cosas: que
esté verde **y que el total de comprobaciones no baje**. Una prueba que revienta
antes de su primer `assert` no falla: pasa.

Si tocaste algo que salió de una fachada (`SettlementSim`, `GameUI`):

```
godot --headless --path . --script res://scripts/tools/LlamadasHuerfanas.gd
```

debe decir `llamadas huerfanas: 0`.

**Compilar no es funcionar.** GDScript no avisa de asignar una propiedad que no
existe. Antes de dar algo por hecho, corre el juego o el panel.

**Y mide barato.** Una corrida de un año a `time_scale = 5` **pasa de una hora
de reloj**; la suite entera tarda menos que una jornada simulada. Antes de
lanzar una sonda larga:

- **Una regla se comprueba con una prueba**, no con una partida.
- **Un estado lejano se construye, no se simula.** ¿Qué pasa en el año 3? Se
  escribe ese estado y se da un paso. Correr tres años para llegar cuesta horas
  y no comprueba nada más.
- **Si hace falta un año, que conteste TODAS las preguntas abiertas.** Diez
  preguntas no son diez corridas: son una corrida con diez contadores. Lo caro
  es arrancarla, no lo que mide.
- **Si va a costar más de unos minutos, dilo antes de gastarlo.** Dieciséis
  horas de sondas no es una decisión técnica.

El detalle está en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) §5.1.

**Las capturas de pantalla necesitan ventana**: con `--headless`,
`get_texture().get_image()` devuelve null.

## No malgastes contexto

Se hace buen trabajo **y** se gastan pocos tokens: no son objetivos opuestos,
casi siempre es el mismo gesto. Aquí es fácil tirarlos porque los documentos son
largos —`SISTEMAS.md` pasa de 700 líneas, `docs/archivo/` de 5 000— y `scripts/`
son 90 000 líneas de GDScript.

- **Todo documento largo abre con «Dónde mirar»**, una tabla de «si buscas X,
  ve a §N». **Ésa es la primera lectura**, no el documento:

  ```
  sed -n '1,40p' docs/SPECS.md      # la cabecera y el índice
  grep -n "^## [0-9]" docs/SPECS.md # los encabezados con su línea
  sed -n '99,110p' docs/SPECS.md    # y sólo la sección que te hacía falta
  ```

  Los tienen `SPECS`, `ARQUITECTURA`, `ESTADO`, `ROADMAP`, `SISTEMAS`,
  `EPOCAS`, `GRAFICOS` y `EPOCA_01`. Los demás caben de una lectura.
- **Busca antes de leer.** `grep -n` para localizar, y luego lee **el trozo**
  (`sed -n '120,180p'`, o `Read` con `offset`/`limit`). Abrir un fichero de
  ochocientas líneas para mirar una tabla es el desperdicio más común.
- **Ojo con `grep "^## "` en `ARQUITECTURA.md`**: devuelve también los
  comentarios `##` de los ejemplos de GDScript. Ahí, `grep -n "^## [0-9]"`.
- **Empieza por el índice del archivo** (`docs/archivo/README.md`) antes de
  abrir ninguno de los archivados: dice qué hay en cada uno y adónde fue su
  contenido vivo. Muchas veces con eso ya no hace falta abrirlo.
- **No releas lo que ya has leído** en esta conversación, ni vuelvas a
  comprobar algo que ya quedó establecido.
- **Filtra la salida de las herramientas.** La suite se mira con `tail -30`, no
  entera; una sonda, por las líneas que te interesan. Volcar mil líneas de log
  para leer una cifra las gasta todas.
- **No pegues ficheros en el chat.** Referencia `fichero.md:120` y cuenta lo que
  dice; el usuario puede abrirlo.
- **Una herramienta que ya te ha contestado no se repite.** Si `grep` te dio la
  línea, no leas el fichero «para confirmar».

Y al revés, para que no se lea como una excusa: **esto no autoriza a trabajar a
ciegas**. Leer el trozo que hace falta es barato; adivinar lo que pone y
equivocarse cuesta la conversación entera. Si hay que leer, se lee.

## Los comandos

```
/epoca      idea sobre una época  →  ficha de época + intención
/spec       intención o encargo   →  el qué y el por qué, medible
/plan-tarea spec                  →  plan, tareas, y las IMPLEMENTA y documenta
/tareas     retomar trabajo       →  implementa lo pendiente de ROADMAP «En curso»
/depurar    lo que no quedó bien  →  preguntas, y arreglo donde esté el fallo
```

`/plan-tarea` es el que llega hasta el código: planea, descompone, **te enseña
las tareas y te pregunta cómo atacarlas**, y entonces las implementa,
comprueba y documenta. `/tareas` es el mismo bucle suelto, para retomar lo que
quedó a medias.

Cada paso pilla cosas que el anterior no. No te saltes pasos aunque lo veas
claro, y **no parchees dentro de una tarea** lo que debería ir por `/depurar`.

**Nada se da por hecho hasta que está comprobado y documentado** en el
documento permanente que le toque — la tabla de abajo dice cuál.

## La documentación: dónde va cada cosa

**`docs/` tiene un conjunto FIJO de documentos.** No se crea uno nuevo por cada
trabajo: lo único específico son las once fichas de época. Si lo que vas a
escribir no cabe en ninguno de éstos, es que va en el que menos te apetece
abrir, no en uno nuevo.

**Esta tabla se usa dos veces en cada trabajo: para LEER antes de tocar código,
y para ACTUALIZAR después.** Las dos, no una.

| Si el trabajo va de… | Lee y actualiza |
|---|---|
| Técnicas, hitos, oficios o mecánicas **de una época concreta** | `docs/EPOCA_NN_*.md` |
| Un **sistema del juego**: caza, pesca, despensa, relato y pintura, desechos, el lobo, hitos, comercio, oficios, las tres escaleras | [docs/SISTEMAS.md](docs/SISTEMAS.md) |
| **Lo que se ve**: terreno, shader, texturas, personas, animaciones, niveles de gráficos, coste de GPU | [docs/GRAFICOS.md](docs/GRAFICOS.md) |
| **Ventanas y paneles**: interfaz, piel por era, legibilidad | [docs/INTERFAZ.md](docs/INTERFAZ.md) |
| Un **contrato técnico**: señales, estado global, determinismo, invariantes, capas de física | [docs/SPECS.md](docs/SPECS.md) |
| **Cómo se escribe código aquí**: troceado, estilo, cómo se mide, la trampa de `datos/` | [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) |
| Una **cifra medida de la partida**, o un hueco entre lo que el diseño pide y lo que hace el juego | [docs/ESTADO.md](docs/ESTADO.md) |
| El **reparto de épocas**, la regla del reloj, qué hito cierra cada una | [docs/EPOCAS.md](docs/EPOCAS.md) |
| **Tareas en curso** y qué falta por construir | [docs/ROADMAP.md](docs/ROADMAP.md) |
| De dónde sale un dato, un modelo o una textura | [docs/CREDITOS.md](docs/CREDITOS.md) |
| Trabajar **varios a la vez** | [docs/AGENTES.md](docs/AGENTES.md) |

Casi todo trabajo toca **dos**: el documento de su tema y `ROADMAP.md` para la
tarea. Uno que cambie una cifra medida toca `ESTADO.md` además.

[docs/archivo/](docs/archivo/README.md) es lo cerrado: **no se edita**, y se
lee cuando hace falta saber por qué algo quedó como quedó.

Si un documento choca con el código, **gana el código** y el documento está
pendiente de arreglar — dilo, no lo dejes pasar. Si una regla está escrita en
dos sitios y la queja se repite tras arreglarla, el fallo está en la copia que
no tocaste.

## Estilo, en una línea cada uno

- **GDScript tipado, siempre.** Parámetros, retornos y variables.
- **Nombres de dominio en español** (`Caceria`, `Despensa`, `pericia`); los del
  motor, como están.
- **Los comentarios explican POR QUÉ**, no qué. Si una cifra viene de una
  medida, va la medida; si viene de una decisión, se dice que es una decisión.
- **No se inventan números de balanceo.** Y no se ajusta una cifra contra una
  sola corrida: hay sondas no deterministas que dan 35,8 y 48,9 con el mismo
  código.
- **Una unidad significa una sola cosa** en todo el juego (`Materia.KCAL_RACION`).
- **Una pregunta, un sitio que la contesta.**
- **No se deja código muerto.** Si no lo llama nadie, se borra; git lo guarda.
- Una clase por fichero, y el fichero se llama como la clase.
