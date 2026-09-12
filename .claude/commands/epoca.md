---
description: Convierte una idea suelta sobre una época ("quiero que el Neolítico vaya de X") en documentación de época y en la intención de una spec. Primer paso del embudo epoca → spec → plan-tarea, que ya llega al código.
argument-hint: <época (número o nombre)> + lo que quieres que sea
---

El usuario te va a contar **cómo quiere que sea el juego** en una época
concreta. Tu trabajo en este paso NO es escribir código ni una spec formal: es
**sacarle los detalles con preguntas** y dejar dos cosas escritas —la ficha de
época actualizada y la intención de la que saldrá la spec—.

Lo que pide: $ARGUMENTS

---

## 1. Sitúate antes de preguntar nada

No preguntes lo que puedes leer. Antes de la primera pregunta:

1. **Identifica la época.** Son **once** (`EPOCA_01_PALEOLITICO.md` …
   `EPOCA_11_EL_VAPOR.md`). El siglo corto se retiró y está en
   `docs/archivo/`: si el usuario se refiere a él, dilo y pregunta si quiere
   recuperarlo, no lo des por vivo.
2. **Lee la ficha de esa época** (`docs/EPOCA_NN_*.md`) y su entrada en
   [docs/EPOCAS.md](../../docs/EPOCAS.md) §4 — el hito de cierre, y sobre todo
   **la trampa**, que es el error de diseño que esa época invita a cometer.
   Si lo que pide el usuario es exactamente la trampa, tienes que decírselo.
3. **Lee [docs/SISTEMAS.md](../../docs/SISTEMAS.md)**:
   las tres escaleras (térmica, soporte, alimento), el sistema de hitos, los
   oficios. Casi nada de lo que se pide para una época es nuevo de verdad —
   suele ser un peldaño de una escalera que ya existe.
4. **Mira qué hay ya en el código.** Media idea de época suele estar medio
   construida en `scripts/`: `TechTree`, `Materia`, `Profession`,
   `CampProjects`, `ResourceField`. Buscar antes de preguntar cambia las
   preguntas.
5. Si la época es la 1, lee además [docs/ESTADO.md](../../docs/ESTADO.md): es
   la única época construida, así que lo que pidas choca con una partida que ya
   existe y está medida. Su ficha lo lleva todo dentro — absorbió el antiguo
   `SLICE_PALEOLITICO.md`, que está en `docs/archivo/` por si hace falta el
   porqué de una decisión vieja.

---

## 2. Pregunta

Con **AskUserQuestion**, y con preguntas que cambien lo que se va a construir.
No preguntes por cortesía ni para confirmar lo que ya te ha dicho.

Ronda a ronda, no todo de golpe: haz dos o tres preguntas, escucha, y deja que
lo que conteste abra las siguientes. Es normal que hagan falta dos o tres
rondas; una sola suele significar que no has llegado al fondo.

Las que casi siempre hacen falta:

- **Qué cambia para el jugador.** Una época que no cambia dónde se vive, de qué
  se come, qué se fabrica o quién decide, no es una época: es decoración. ¿Cuál
  de las cuatro toca esto?
- **Qué decisión nueva pone delante.** Si el jugador hace lo mismo que antes
  con otros nombres, es contenido, no mecánica. ¿Qué tiene que elegir, y contra
  qué?
- **Qué se puede perder.** ¿Qué sale mal si lo hace mal? Sin eso no hay tensión.
- **De dónde sale el dato.** ¿Hay yacimiento cántabro, o es inferido? La ficha
  de época lleva nivel de evidencia y hay que poder ponerlo.
- **Qué NO quiere.** Es la pregunta que más ahorra. Ofrécele la trampa de la
  época como opción explícita de "esto fuera".
- **Hasta dónde llega esto.** Una época entera no cabe en una spec. ¿Es el hito
  de cierre, un peldaño de escalera, un oficio, una cadena de producción?

Cuando algo choque con lo que ya está escrito o construido, **dilo en la
pregunta**, con la cita. No lo resuelvas por tu cuenta ni lo dejes pasar: el
usuario decide si cambia la idea o cambia lo escrito.

---

## 3. Escribe, y escribe dos cosas

### 3.1. Actualiza la ficha de época

`docs/EPOCA_NN_*.md`. Esto es el "desarrollar la documentación": lo hablado
deja de ser una conversación y pasa a ser diseño. Mete lo decidido en la
sección que le toque —técnicas, hitos, oficios, mecánicas nuevas, la trampa—
en el estilo que ya tiene el fichero.

Si lo decidido **contradice** algo que ya decía la ficha, no lo borres en
silencio: corrígelo dejando dicho qué decía antes y por qué cambió. El repo lo
hace así en todas partes y es media razón de que se pueda confiar en él.

Si además toca a `EPOCAS.md` o a `docs/SISTEMAS.md` —un hito de cierre
distinto, un peldaño nuevo en una escalera—, actualízalos también. Una regla
escrita en dos sitios se queja siempre por la copia que no tocaste.

### 3.2. Escribe la intención donde le toque

**No crees un fichero nuevo.** `docs/` tiene un conjunto fijo de documentos y lo
único específico son las fichas de época. La intención se escribe **dentro del
documento permanente al que pertenezca**, como una sección con su cita de fecha:

| Si lo hablado va de… | Va a |
|---|---|
| Técnicas, hitos, oficios o mecánicas de **esa época** | la propia `docs/EPOCA_NN_*.md` (lo normal) |
| Un **sistema** que va a cruzar más épocas: caza, despensa, comercio, hitos, oficios, una de las tres escaleras | [docs/SISTEMAS.md](../../docs/SISTEMAS.md) |
| **Lo que se ve**: terreno, texturas, personas, animaciones | [docs/GRAFICOS.md](../../docs/GRAFICOS.md) |
| **Ventanas y paneles** | [docs/INTERFAZ.md](../../docs/INTERFAZ.md) |
| Un **contrato técnico** nuevo | [docs/SPECS.md](../../docs/SPECS.md) |

Lo habitual es que toque **dos**: la ficha de época y uno de sistemas o
gráficos. Actualiza los dos; una regla escrita en dos sitios se queja siempre
por la copia que no tocaste.

La sección que escribes lleva esto, y nada más —los criterios medibles y el
alcance los pone `/spec`—:

```markdown
> **Intención (fecha).** Sale de `/epoca <NN>`. Todavía no es una spec.

**Qué se quiere.** Lo pedido, ya limpio de ambigüedad.

**Lo que se decidió al preguntar.** Cada decisión con la pregunta que la
provocó. Incluidas las que cambiaron la idea de partida — sobre todo ésas.

**Fuera a propósito.** Y por qué. Con la trampa de la época marcada si se
descartó.

**Con qué choca.** Lo que ya está escrito o construido y no encaja, con la
cita. Vacío si nada.

**Qué habría que medir.** Cómo se sabría que funciona.
```

---

## 4. Deja el rastro en ROADMAP

**Antes de cerrar**, apunta el trabajo en [docs/ROADMAP.md](../../docs/ROADMAP.md),
sección «En curso», con una línea que diga de qué va y **en qué documento y
sección has dejado la intención**:

```markdown
### El otoño como estación que decide
Intención escrita (2026-09-12) en EPOCA_01_PALEOLITICO.md §3 y SISTEMAS.md §10.
Sin spec todavía — siguiente paso, `/spec`.
```

No es burocracia: es **lo único que permite retomarlo mañana o desde otra
sesión**. Sin esa línea, `/spec` tiene que salir a buscar por veintiún
documentos dónde dejaste la intención, y el usuario tiene que acordarse.

## 5. Cierra

Di **qué documentos has tocado** y pásale la pelota al usuario:

```
/spec <el documento y la sección donde has dejado la intención>
```

En la misma conversación `/spec` a secas basta —acabas de escribirlo y sabes
dónde está—, pero dile igualmente el puntero: la conversación puede cortarse
ahí.

De ahí sale `/plan-tarea`, que ya llega hasta el código: planea, descompone en
tareas —que viven en `ROADMAP.md` «En curso»—, las enseña, pregunta cómo
atacarlas, y las implementa y documenta.

**No escribas la spec formal ni el plan aquí**, aunque lo veas claro: el embudo
existe porque cada paso pilla cosas que el anterior no, y porque lo que se
decide bien aquí no hay que decidirlo con el código ya escrito.

---

**Y no malgastes contexto.** Los documentos de este repo son largos: busca con
`grep -n` y lee el trozo, no el fichero; filtra la salida de las sondas; no
pegues ficheros en el chat. Las reglas están en CLAUDE.md, «No malgastes
contexto» — y la contraria también: leer lo que hace falta es barato,
adivinarlo no.

---

## Si vais a ser varios

Antes de tocar un solo fichero, lee y firma en `.claude/agentes/pizarra.md`.
El protocolo entero está en [docs/AGENTES.md](../../docs/AGENTES.md). Este
comando sólo escribe `.md`, así que no necesita el turno de Godot — pero sí
necesita que nadie más esté reescribiendo la misma ficha de época.
