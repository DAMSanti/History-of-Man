---
description: Convierte una spec en plan técnico, lo descompone en tareas, te las enseña, te pregunta cómo atacarlas, y las implementa y documenta. Cierra el embudo epoca → spec → plan-tarea.
argument-hint: <ruta a la spec o nombre de la feature>
---

Vas a **llevar una spec desde el plan hasta el código documentado**. La spec
dice el qué y el por qué; a partir de aquí te encargas del resto:

```
plan técnico  →  lista de tareas  →  se la enseñas y preguntas  →  implementar
              →  comprobar  →  documentar en el permanente que toque
```

**No pares al terminar el plan.** Este comando existía antes cortado ahí, y el
resultado era que lo implementado se documentaba a mano o no se documentaba.

Spec de referencia: $ARGUMENTS

## Antes de planear

1. **Localiza la spec.** Desde el 2026-09-12 no vive en un fichero propio: está
   **dentro del documento permanente del que trata**, con una cita de fecha.
   Según de qué vaya, mira:

   | Tema | Documento |
   |---|---|
   | Una época concreta | `docs/EPOCA_NN_*.md` |
   | Un sistema del juego | [docs/SISTEMAS.md](../../docs/SISTEMAS.md) |
   | Terreno, texturas, personas, animaciones | [docs/GRAFICOS.md](../../docs/GRAFICOS.md) |
   | Ventanas y paneles | [docs/INTERFAZ.md](../../docs/INTERFAZ.md) |
   | Un contrato técnico | [docs/SPECS.md](../../docs/SPECS.md) |
   | Una cifra medida | [docs/ESTADO.md](../../docs/ESTADO.md) |

   **`docs/ROADMAP.md` «En curso» tiene la línea que dice en cuál está** — la
   dejan `/epoca` y `/spec`. Ése es el índice: míralo antes de ponerte a buscar
   por los veintiún documentos.

   Si el usuario invocó el comando a secas y sólo hay un bloque abierto, ése es.
   Si hay varios, **enséñaselos y pregúntale** — no elijas tú. Y si lo que
   encuentras es sólo una intención sin spec, dilo y sugiere `/spec` primero;
   no improvises la spec aquí.
2. Lee [docs/SPECS.md](../../docs/SPECS.md) completo: es el contrato técnico
   vigente —estado global sin autoloads (§2.2), el paso fijo y las tres señales
   (§3), los contratos por carpeta (§4), los invariantes (§7)—. El plan tiene
   que respetarlo, o **declarar explícitamente qué contrato cambia y por qué**.
3. Lee `docs/ROADMAP.md` para no pisar decisiones ya tomadas (la arquitectura
   de dos escalas, la cancelación del chunking, lo que cada fase ya cerró).
4. Busca en `scripts/` los módulos reales que la feature toca o de los que
   depende — comprueba los nombres de clases y señales **en el código**, no los
   asumas por lo que diga la documentación. Esto no es paranoia: `SPECS.md`
   entero describió durante meses un prototipo que ya no existía, con clases
   (`Chunk`, `Architecto`, `RawMaterial`, `TimeManager`) que se habían borrado.
   Se reescribió el 2026-09-12 contra el código, pero la lección se queda.
5. Mira los **invariantes** de `SPECS.md` §7 antes de diseñar nada. Son los que
   se rompen sin dar un error de compilación: una unidad con dos significados,
   una pregunta contestada desde dos sitios, algo que pasa cada N fotogramas en
   vez de a una hora de juego, o azar que no sale del `_rng` de la simulación.

## Al escribir el plan

Añádelo **en el mismo documento donde está la spec**, justo debajo, como
`**Plan técnico.**` — no crees un archivo nuevo, y no lo pongas en otro sitio
que la spec. Incluye:

- **Módulos afectados**: qué scripts se crean o modifican, y qué contrato de
  `SPECS.md` §3 les aplica (o qué contrato nuevo se añade, si es un módulo
  nuevo).
- **Decisiones de arquitectura**: solo las que la spec obliga a tomar — no
  diseñes por encima de lo que se pidió.
- **Orden de dependencias**: qué tiene que existir antes de qué (p.ej. si algo
  cuelga de una tecnología del árbol, o de un dato que hoy no se guarda en
  ningún sitio).
- **Riesgos técnicos conocidos**, si los hay — mismo tono que `SPECS.md` §3.11
  y el "Deuda pendiente" de `ROADMAP.md`: nombrar la deuda que se hereda o se
  introduce, no esconderla.

Si al planear descubres que la spec es ambigua o no encaja con el código
real, para y pregunta, o vuelve a `/spec` — no resuelvas la ambigüedad en
silencio dentro del plan; sería la misma "regla escrita en varios sitios" que
lo que este flujo intenta evitar.

Si al planear descubres que la spec es ambigua o no encaja con el código real,
**para y pregunta**, o vuelve a `/spec`. No resuelvas la ambigüedad en silencio
dentro del plan: sería la misma «regla escrita en varios sitios» que este flujo
intenta evitar.

---

## Descompón en tareas, y enséñaselas

Con el plan escrito, saca la lista de tareas **y ponla en
[docs/ROADMAP.md](../../docs/ROADMAP.md), sección «En curso»** — un bloque con
el nombre del trabajo, una línea diciendo en qué documento está la spec, y
debajo la checklist en el orden real de implementación.

Cada tarea tiene que ser:

- **Concreta**: un cambio en un fichero, o un conjunto pequeño y cohesionado —
  nunca «implementar el sistema X» de una tacada.
- **Verificable**: di con qué se comprueba. Una prueba de `scripts/tests/` si es
  una regla del juego; una sonda si es una cifra de balanceo.
- **Declarada**: di qué ficheros toca, que es lo que deja a otro agente
  repartirse el trabajo sin cruzarse contigo.

Y **enséñasela al usuario en el chat**, numerada, con lo que toca cada una y
cuánto crees que pesa. No le hagas abrir un fichero para ver qué le propones.

### Presupuesta lo que va a costar medir, y dilo

**Una corrida de un año a `time_scale = 5` pasa de una hora de reloj.** Esto no
es un detalle: en una tanda se planearon más de diez comprobaciones de un año y
una de tres —entre dieciséis y dieciocho horas de máquina—, y **la de tres años
acabó resolviéndose con una prueba de segundos**.

Antes de enseñar la lista, repasa tarea por tarea **con qué se comprueba cada
una**, y aplica las reglas de [docs/ARQUITECTURA.md](../../docs/ARQUITECTURA.md)
§5.1:

- **¿Es una regla?** Entonces es una prueba de `scripts/tests/`, no una sonda.
  Segundos.
- **¿Es un estado lejano** —la banda envejecida, la despensa vacía, el tajo
  esquilmado—? **Constrúyelo, no lo simules.** Se escribe el estado y se da un
  paso. Correr tres años para que alguien envejezca solo no comprueba nada más.
- **¿De verdad hace falta un año?** Sólo si lo que preguntas es interacción
  entre estaciones, deriva que crece con los días, o rendimiento sobre la
  partida real.

Y si **varias** tareas necesitan una corrida larga, **son una sola corrida con
varios contadores**, no una por tarea. Lo caro de un año es arrancarlo, no lo
que mide: instrumentarlo para sacar ocho cifras cuesta lo mismo que para sacar
una. Júntalas en la lista antes de proponerla, y dilo explícitamente: «las
tareas 3, 5 y 7 se miden en la misma pasada de año».

**Pon el total en el chat**, en minutos u horas, junto a la lista. Si pasa de
unos minutos, **es una decisión del usuario y va en la pregunta de abajo** — no
se gastan dieciséis horas de máquina sin que lo sepa antes de empezar.

Marca además cuáles se pueden hacer **a la vez** y cuáles no: dos tareas que
tocan ficheros distintos pueden ir en paralelo, pero **dos que midan, no** —
Godot es de uno en uno, ver [docs/AGENTES.md](../../docs/AGENTES.md) §3.

---

## Pregúntale cómo atacarlas

Con **AskUserQuestion**, y con la lista ya delante. Lo que hay que resolver es
**cómo**, no si:

- **Todas seguidas**, parando sólo si algo falla o si aparece una decisión que
  no es tuya. Es lo normal, y suele ser la respuesta.
- **Una a una**, enseñando el resultado entre cada una. Para lo que toca
  balanceo o algo que el usuario quiere ver antes de seguir.
- **Sólo algunas, o en otro orden.** Si él ve una dependencia que tú no viste,
  o quiere lo barato primero.
- **Parar aquí.** El plan y las tareas quedan escritos y no se toca código.

Si alguna tarea encierra una decisión de diseño —una cifra de balanceo, un
comportamiento con dos lecturas razonables—, **dilo en la pregunta**: es más
barato decidirlo ahora que después de implementarlo.

**Y si el presupuesto de medida pasa de unos minutos, pregúntalo aparte**, con
el número delante: cuánto cuesta la tanda larga, qué contesta, y qué alternativa
barata hay si la hay. «Confirmar la partida entera con un año» y «comprobar la
regla con una prueba de segundos» son dos respuestas distintas a la misma
pregunta, y elegir entre ellas no es tuyo.

---

## Y entonces impleméntalas

Cuando conteste, **ponte a ello**: invoca el skill `tareas`, que lleva el bucle
de implementación —firmar en la pizarra, implementar, comprobar las dos cosas,
marcar hecho con su cita, y llevar lo aprendido al documento permanente que le
toque—. Está escrito ahí y en un solo sitio a propósito.

**Lo que no es negociable, conteste lo que conteste:**

- Una tarea no está hecha hasta que está **comprobada** y **documentada en el
  documento del tema**, no sólo en la cita de HECHO del ROADMAP.
- Si la suite se pone en rojo, o el total de comprobaciones baja, **paras y lo
  dices**. No sigues con la tarea siguiente encima de algo roto.
- Si al implementar se cae una premisa del plan, **lo cuentas y corriges el
  plan**. El plan no es un contrato con el usuario: es lo que creías antes de
  tocar el código.

Al terminar, dile qué quedó hecho, qué se midió, qué salió distinto de lo
planeado y qué queda pendiente. Si te dejaste algo, dilo tú antes de que
pregunte.

---

**Y no malgastes contexto.** Los documentos de este repo son largos: busca con
`grep -n` y lee el trozo, no el fichero; filtra la salida de las sondas; no
pegues ficheros en el chat. Las reglas están en CLAUDE.md, «No malgastes
contexto» — y la contraria también: leer lo que hace falta es barato,
adivinarlo no.

---

## Si vais a ser varios

Lee y firma en `.claude/agentes/pizarra.md`, y **declara en el plan qué ficheros
va a tocar**: ese plan es lo que los demás agentes leerán para no cruzarse
contigo. Protocolo en [docs/AGENTES.md](../../docs/AGENTES.md).
