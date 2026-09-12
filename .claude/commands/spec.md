---
description: Crea o actualiza la spec de una feature/fase — el "qué" y el "por qué", sin tecnología. Segundo paso del embudo, antes de que /plan-tarea llegue al código.
argument-hint: <nombre o descripción breve de la feature>
---

Vas a escribir la **spec** de una feature o subsistema para "History of Man".
Es un flujo ligero inspirado en Spec-Driven Development, adaptado a los
documentos que ya existen en `docs/`: no reemplaza
[docs/SPECS.md](../../docs/SPECS.md) (el contrato técnico permanente) ni
[docs/ROADMAP.md](../../docs/ROADMAP.md) (el plan por fases) — se apoya en los
dos.

El embudo entero:

```
/epoca      idea sobre una época  →  ficha de época + intención   (opcional)
/spec       intención o encargo   →  el qué y el por qué, medible   ← ESTÁS AQUÍ
/plan-tarea spec                  →  plan, tareas, y las IMPLEMENTA y documenta
/tareas     retomar trabajo       →  implementa lo pendiente de ROADMAP «En curso»
/depurar    lo que no quedó bien  →  preguntas, y arreglo donde esté el fallo
```

El paso siguiente llega hasta el código, así que **lo que dejes ambiguo aquí se
implementa ambiguo**. Un criterio de aceptación que no se puede medir es una
tarea que nadie sabrá dar por hecha.

Feature/fase a especificar: $ARGUMENTS

**Si lo que te pasan es un documento de intención** (lo escribe `/epoca`, lleva
una cita `> **Intención...**` arriba), no empieces de cero: ese fichero ya trae
las decisiones depuradas a preguntas. Tu trabajo es convertirlo en spec **en el
mismo fichero**, conservando las secciones de intención debajo. Lo que allí
está decidido no se vuelve a preguntar.

## Antes de escribir nada

1. Lee `docs/ROADMAP.md` y `docs/SPECS.md` para situar la feature dentro de la
   fase correspondiente y no chocar con contratos ya fijados (autoloads,
   convenciones §4, capas de física, la arquitectura de dos escalas).
2. Si la feature toca una época concreta, lee también el `EPOCA_NN_*.md`
   correspondiente y `docs/SISTEMAS.md`. Son **once** épocas: el
   siglo corto se retiró y vive en `docs/archivo/`.
   Si la feature es de una época y todavía no ha pasado por preguntas, para y
   sugiere `/epoca` — este paso no está pensado para sacarle al usuario cómo
   quiere que sea el juego, sólo para formalizarlo.
3. Si algo queda ambiguo — alcance, criterio de "terminado", qué se deja fuera
   a propósito — pregúntalo con AskUserQuestion antes de escribir. No lo dejes
   implícito ni lo decidas por tu cuenta: es exactamente el fallo que este
   paso existe para evitar.

## Al escribir la spec

Sigue el estilo ya establecido en el repo — mira `docs/archivo/CIERRE_SLICE.md` como
modelo de tono, no de estructura exacta:

- Español, prosa directa, sin relleno ni entusiasmo de marketing.
- El **qué y el por qué**, no el cómo técnico — nada de nombres de
  clases/scripts todavía; eso es trabajo de `/plan-tarea`.
- La motivación: qué problema real resuelve, qué contradicción cierra, o qué
  pide `ROADMAP.md`/`EPOCAS.md` que hoy no existe.
- Un apartado **"Fuera de alcance"** explícito — tan importante como lo que sí
  se pide.
- Cada punto con un **criterio de aceptación medible**: algo comprobable con
  una sonda o prueba, no una impresión. "Se siente mejor" no vale; "la
  despensa baja de X a Y en Z jornadas, medido con tal sonda" sí.

## Dónde guardarlo: en el permanente que le toque

**No crees un fichero nuevo.** `docs/` tiene un conjunto fijo de documentos y lo
único específico son las once fichas de época. Antes se creaba un
`docs/specs/<NOMBRE>.md` por trabajo; **eso se acabó el 2026-09-12** y las specs
viejas están en `docs/archivo/`, cerradas.

La spec se escribe **dentro del documento permanente del que trata**. Léelo
entero antes de escribir en él, y respeta su tono y su estructura:

| Si la feature va de… | Lee y actualiza |
|---|---|
| Técnicas, hitos, oficios o mecánicas **de una época concreta** | `docs/EPOCA_NN_*.md` |
| Un **sistema**: caza, pesca, despensa, relato y pintura, desechos, hitos, comercio, oficios, las tres escaleras | [docs/SISTEMAS.md](../../docs/SISTEMAS.md) |
| **Lo que se ve**: terreno, shader, texturas, personas, animaciones, niveles de gráficos | [docs/GRAFICOS.md](../../docs/GRAFICOS.md) |
| **Ventanas y paneles**: interfaz, piel por era, legibilidad | [docs/INTERFAZ.md](../../docs/INTERFAZ.md) |
| Un **contrato técnico**: señales, estado global, determinismo, invariantes | [docs/SPECS.md](../../docs/SPECS.md) |
| **Cómo se escribe código aquí** | [docs/ARQUITECTURA.md](../../docs/ARQUITECTURA.md) |
| Una **cifra medida** o un hueco entre lo que el diseño pide y lo que hace el juego | [docs/ESTADO.md](../../docs/ESTADO.md) |

**Casi siempre son dos.** Una feature de caza para el Mesolítico toca
`SISTEMAS.md` (el mecanismo) y `EPOCA_02_MESOLITICO.md` (qué cambia en esa
época). Actualiza los dos: una regla escrita en dos sitios se queja siempre por
la copia que no tocaste.

Si de verdad no encaja en ninguno, **dilo y pregunta** antes de crear nada. La
respuesta correcta casi nunca es un fichero nuevo.

**Y apunta el trabajo en `ROADMAP.md`, sección «En curso»**, con una línea que
diga de qué va y en qué documento está la spec. Es donde `/plan-tarea` va a
colgar después la lista de tareas.

No implementes nada de código en este paso: el siguiente, `/plan-tarea`, ya lo
hace —planea, descompone, pregunta cómo atacarlo, y lo implementa y documenta—.
Por eso **este paso es el último sitio barato para cambiar de idea**.

---

**Y no malgastes contexto.** Los documentos de este repo son largos: busca con
`grep -n` y lee el trozo, no el fichero; filtra la salida de las sondas; no
pegues ficheros en el chat. Las reglas están en CLAUDE.md, «No malgastes
contexto» — y la contraria también: leer lo que hace falta es barato,
adivinarlo no.

---

## Si vais a ser varios

Lee y firma en `.claude/agentes/pizarra.md` antes de editar nada. Protocolo en
[docs/AGENTES.md](../../docs/AGENTES.md). Este paso no arranca Godot, así que no
necesita turno.
