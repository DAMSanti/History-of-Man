---
description: Implementa las tareas pendientes de ROADMAP «En curso», una a una, comprobando y documentando cada una en el documento permanente que le toque. Lo invoca /plan-tarea, y se llama suelto para retomar trabajo a medias.
argument-hint: <qué bloque de «En curso», o vacío para que te lo enseñe>
---

**El bucle de implementación.** Aquí vive, y en un solo sitio: lo invoca
`/plan-tarea` cuando acaba de planear, y se llama suelto para **retomar trabajo
a medias** — el tuyo de ayer, o el de otro agente que lo dejó abierto.

Qué implementar: $ARGUMENTS

---

## 1. Mira qué hay pendiente

Las tareas vivas están en [docs/ROADMAP.md](../../docs/ROADMAP.md), sección
**«En curso»**. Cada bloque dice de qué va y en qué documento está su spec.

- Si `$ARGUMENTS` nombra un bloque, ve a ése.
- Si viene vacío, **enséñale al usuario los bloques abiertos** con sus tareas
  pendientes y pregúntale por cuál empezar. No elijas tú un bloque entero.
- Si «En curso» está vacío, dilo y sugiere `/spec` o `/epoca`. No te inventes
  trabajo.

**Lee la spec y el plan antes de tocar nada.** Están en el documento permanente
que la línea del bloque señala. Una tarea implementada sin leer su spec es una
tarea implementada a ojo.

Y si el bloque es de otro agente, o su tarea lleva dueño puesto, **háblale
antes** (`ListAgents` / `SendMessage`).

---

## 2. El bucle, tarea a tarea

Para cada tarea, en orden, y sin saltarte pasos:

### 2.1. Firma

En `.claude/agentes/pizarra.md`: qué tarea coges y qué ficheros vas a tocar,
incluidos los que **puede** que toques. Lee antes lo que han firmado los demás
— si un fichero tuyo ya está declarado por otro, **no lo edites**: háblale, y
mientras tanto haz lo que no dependa de él. Protocolo completo en
[docs/AGENTES.md](../../docs/AGENTES.md).

### 2.2. Escribe primero la comprobación, y la MÁS BARATA que sirva

La prueba en `scripts/tests/` si es una regla del juego, la sonda si es una
cifra de balanceo. **Tiene que fallar —o medir lo viejo— antes del cambio.** Si
no consigues que falle, todavía no entiendes lo que vas a implementar.

**Y elige bien el instrumento, que es donde se van las horas.** Una corrida de
un año a `time_scale = 5` pasa de una hora de reloj; una prueba tarda segundos.
Las reglas completas están en
[docs/ARQUITECTURA.md](../../docs/ARQUITECTURA.md) §5.1, y en corto:

- **Una regla se comprueba con una prueba**, no con una partida.
- **Un estado lejano se construye, no se simula.** Si hay que ver qué pasa con
  la banda envejecida, se ponen las edades y se da un paso. Correr tres años
  para que envejezca sola cuesta horas y no comprueba nada más — pasó, y la
  comprobación acabó siendo una prueba de segundos.
- **Un año sólo si la pregunta es de año**: interacción entre estaciones, deriva
  que crece con los días, o rendimiento sobre la partida real.

**Si dos tareas necesitan una corrida larga, son UNA corrida con dos
contadores.** Lo caro es arrancar el año, no lo que mide. Antes de lanzar nada
largo, junta todas las preguntas abiertas del bloque —incluidas las de tareas
que vengan después— y métrelas en la misma pasada.

Y si la comprobación de esta tarea va a costar más de unos minutos y **no estaba
presupuestada en el plan**, dilo antes de lanzarla. No se gastan horas de
máquina por iniciativa propia.

### 2.3. Implementa

Respetando lo que ya está decidido: los invariantes de
[docs/SPECS.md](../../docs/SPECS.md) §7, el estilo de
[docs/ARQUITECTURA.md](../../docs/ARQUITECTURA.md) §4, y el porqué en los
comentarios — si una cifra sale de una medida, va la medida; si sale de una
decisión, se dice que es una decisión.

### 2.4. Comprueba, y comprueba las dos cosas

Con el **turno de Godot** tomado, y sin que nadie edite un `.gd` mientras corre:

```
godot --headless --path . --script res://scripts/tests/RunTests.gd
```

- Que esté **en verde**.
- Y que **el total de comprobaciones no haya bajado**. Una prueba que revienta
  antes de su primer `assert` no falla: pasa. Ese número es lo único que lo
  delata.

Si tocaste algo que salió de una fachada (`SettlementSim`, `GameUI`):

```
godot --headless --path . --script res://scripts/tools/LlamadasHuerfanas.gd
```

debe decir `llamadas huerfanas: 0`.

**Compilar no es funcionar.** Si el cambio toca algo que se ve, corre el juego o
el panel antes de darlo por hecho. Y si era una cifra de balanceo, **córrela dos
veces**: hay sondas no deterministas que dan 35,8 y 48,9 con el mismo código —
lo cual, si la sonda es de un año, son **dos horas**, y por eso cuenta en el
presupuesto.

> **Si se pone en rojo, paras y lo dices.** No sigues con la tarea siguiente
> encima de algo roto, y no la marcas hecha «pendiente de arreglar».

### 2.5. Márcala hecha, con lo que pasó de verdad

En `ROADMAP.md`, `- [x]`, y debajo:

```
> **HECHO (fecha).** Qué se hizo de verdad, con qué prueba o sonda se midió, y
> el resultado — incluidas las sorpresas y los cambios de premisa que
> aparecieron al implementar, no sólo el resultado limpio.
```

**No borres ni reescribas el texto original de la tarea.** El historial de qué
se pidió y qué pasó de verdad es parte del valor.

### 2.6. Y lleva lo aprendido al documento permanente

**Ésta es la mitad que se olvida**, y sin ella el conocimiento se queda en una
lista de tareas que nadie relee:

| Lo que has cambiado | Actualiza |
|---|---|
| Un mecanismo del juego: caza, pesca, despensa, relato, desechos, hitos, comercio, oficios | [docs/SISTEMAS.md](../../docs/SISTEMAS.md) |
| Algo propio de una época | `docs/EPOCA_NN_*.md` |
| Terreno, shader, texturas, personas, animaciones, niveles de gráficos | [docs/GRAFICOS.md](../../docs/GRAFICOS.md) |
| Ventanas, paneles, piel de la interfaz | [docs/INTERFAZ.md](../../docs/INTERFAZ.md) |
| Una señal, el estado global, un invariante, una capa de física | [docs/SPECS.md](../../docs/SPECS.md) |
| Una forma nueva de trocear, medir o comprobar | [docs/ARQUITECTURA.md](../../docs/ARQUITECTURA.md) |
| **Una cifra medida de la partida** | [docs/ESTADO.md](../../docs/ESTADO.md) |

Dos reglas al escribir ahí:

- **Si una cifra que el documento afirma ha dejado de ser cierta, cámbiala.** No
  vale dejar la vieja y poner la nueva sólo en la cita de HECHO.
- **Si contradice algo escrito, corrígelo diciendo qué decía antes y por qué
  cambió.** Este repositorio se puede creer justamente porque lo hace así.

**No crees un documento nuevo.** `docs/` tiene un conjunto fijo y lo único
específico son las fichas de época.

### 2.7. Suelta

Borra tu bloque de la pizarra —o actualízalo a la tarea siguiente— y suelta el
turno de Godot si lo tenías.

---

## 3. Al cerrar el bloque entero

Cuando no queden tareas:

1. **Quítalo de «En curso»**, dejando una línea de cierre con la fecha y adónde
   fue a parar lo aprendido.
2. Si el bloque fue largo y su relato tiene valor —qué se probó, qué falló, qué
   premisa se cayó a mitad—, ese relato va a `docs/archivo/` con su cabecera de
   archivado. El conjunto de `docs/` no crece.
3. **Cuéntaselo al usuario**: qué quedó hecho, qué se midió y con qué salió,
   qué resultó distinto de lo planeado, y qué queda pendiente. Si te dejaste
   algo, dilo tú antes de que pregunte.

---

**Y no malgastes contexto.** Los documentos de este repo son largos: busca con
`grep -n` y lee el trozo, no el fichero; filtra la salida de las sondas; no
pegues ficheros en el chat. Las reglas están en CLAUDE.md, «No malgastes
contexto» — y la contraria también: leer lo que hace falta es barato,
adivinarlo no.

---

## Lo que NO se hace aquí

- **No implementes varias tareas a la vez** salvo que el usuario lo haya dicho.
  Si no está claro por dónde empezar, pregunta.
- **No parchees dentro de una tarea lo que el usuario dice que no le gusta.**
  Eso es `/depurar`: preguntas detalladas primero, decidir si el fallo está en
  el código o en lo escrito después, y arreglarlo donde esté.
- **No lances una sonda larga porque sí.** La suite entera tarda menos que una
  jornada simulada. Si lo que quieres saber cabe en una prueba, va en una
  prueba; y si hace falta un año, que ese año conteste todo lo que haya
  pendiente, no una cosa sola.
- **No des una tarea por hecha sin comprobarla.** «Compila» no es «funciona»:
  GDScript no avisa de asignar una propiedad que no existe, y así estuvo la
  fauna meses desconectada de la caza.
