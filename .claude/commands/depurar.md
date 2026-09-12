---
description: Algo no quedó como el usuario quería. Le preguntas hasta entender qué esperaba de verdad, decides si el fallo está en el código o en lo escrito, y lo arreglas donde esté.
argument-hint: <qué está mal, con tus palabras>
---

El usuario te va a decir que algo no quedó como quería. Puede ser un fallo, o
puede ser que lo implementado sea exactamente lo que pedía la documentación y
**la documentación esté mal**. Tu trabajo es averiguar cuál de las dos cosas es
antes de tocar nada.

La queja: $ARGUMENTS

> **La regla que gobierna este comando: no arregles la primera cosa que
> encuentres.** Este repositorio tiene un historial largo de síntomas que eran
> seis capas contestando distinto a la misma pregunta, y de cifras que estaban
> mal porque el instrumento estaba mal, no la partida. Arreglar el síntoma
> deja el fallo vivo y además esconde la pista.

---

## 1. Entiende el síntoma antes de buscarlo

Lee lo que dice el usuario y **búscalo en el código y en la documentación
antes de preguntar nada**. Las preguntas buenas salen de haber mirado:

- **¿Qué dice la documentación que debería pasar?** Busca en el documento del
  tema, que es el que lleva la spec si esto salió de una:

  | Si la queja va de… | Lee |
  |---|---|
  | Caza, pesca, despensa, relato, desechos, el lobo, hitos, comercio, oficios | [docs/SISTEMAS.md](../../docs/SISTEMAS.md) |
  | Algo propio de una época | `docs/EPOCA_NN_*.md` |
  | Terreno, texturas, personas, animaciones, rendimiento de GPU, niveles | [docs/GRAFICOS.md](../../docs/GRAFICOS.md) |
  | Ventanas, paneles, legibilidad, la piel por era | [docs/INTERFAZ.md](../../docs/INTERFAZ.md) |
  | Señales, determinismo, estado global, invariantes, capas de física | [docs/SPECS.md](../../docs/SPECS.md) |
  | Una cifra de la partida que no cuadra | [docs/ESTADO.md](../../docs/ESTADO.md) |
  | Cómo se mide o se trocea | [docs/ARQUITECTURA.md](../../docs/ARQUITECTURA.md) |

  Y si el trabajo está abierto, `docs/ROADMAP.md` «En curso». Lo cerrado hace
  tiempo está en `docs/archivo/` — ahí sale **por qué** quedó como quedó, que
  suele ser la mitad de la respuesta.
- ¿Qué hace el código de verdad?
- ¿Hay una prueba o una sonda que ya cubra esto? Si la hay y está en verde, o
  la prueba comprueba otra cosa, o el usuario esperaba otra cosa. Las dos
  posibilidades importan.

---

## 2. Pregunta hasta saber qué esperaba

Con **AskUserQuestion**, y en serio: este comando existe porque la explicación
de una línea nunca basta.

Lo que hay que sacar, siempre:

- **Qué esperabas ver, exactamente.** No "que funcione mejor": qué número, qué
  comportamiento, en qué momento de la partida. Si no se puede comprobar, no se
  puede arreglar.
- **Qué viste en su lugar.** Y dónde lo viste: el panel de F3, la crónica, una
  sonda, jugando.
- **Cuándo.** ¿Siempre, o en cierta estación, con cierto reparto, a partir de
  cierta jornada? Un fallo que sólo pasa en otoño no se busca igual.
- **¿Es esto lo que pedías, o has cambiado de idea?** Pregúntalo sin rodeos.
  Cambiar de idea es legítimo y cambia por completo qué hay que arreglar.

Y ofrece tu hipótesis como pregunta, con lo que has encontrado al mirar. Es la
forma más rápida de que el usuario te corrija pronto.

**Si las cifras del usuario no cuadran con las tuyas, sospecha de tu
instrumento antes que de su observación.** El F3 del usuario es la partida; tu
sonda es un aparato que puede estar roto.

---

## 3. Decide dónde está el fallo, y dilo

Tres casos, y hay que nombrar cuál es **antes** de tocar código:

| | Qué pasa | Qué se arregla |
|---|---|---|
| **A** | La documentación dice X, el código hace Y, el usuario quería X | El código |
| **B** | La documentación dice X, el código hace X, el usuario quería Y | **La documentación primero**, luego el código |
| **C** | La documentación no dice nada de esto | Se decide con el usuario qué debería decir, se escribe, y luego se implementa |

En el caso **B**, no cambies la documentación por tu cuenta: enséñale al
usuario qué dice hoy y confirma que quiere cambiarlo. Puede ser que la
documentación tenga razón y la idea nueva sea peor; el documento suele llevar
escrito el porqué de lo que dice, y ese porqué es la mitad del valor.

Y en cualquiera de los tres, **si el síntoma tiene pinta de ser una regla
escrita en varios sitios, búscalos todos antes de tocar uno**. La queja que se
repite después de arreglarla viene siempre de la copia que no tocaste.

---

## 4. Arregla

1. **Escribe primero la comprobación, y la más barata que sirva.** Una prueba en
   `scripts/tests/` si es una regla del juego; una sonda si es una cifra de
   balanceo. Tiene que fallar —o medir mal— **antes** del arreglo. Si no
   consigues que falle, todavía no entiendes el fallo.

   **Reproducir un fallo no es correr la partida entera hasta que aparezca.** Si
   el síntoma sale en el año 3, construye ese estado y da un paso: una corrida
   de un año pasa de una hora de reloj, y depurar a base de corridas largas se
   come el día. Ver [docs/ARQUITECTURA.md](../../docs/ARQUITECTURA.md) §5.1.

   La excepción legítima es un fallo que **sólo** aparece acumulando —una deriva,
   un cuelgue en el cruce de estaciones—. Ahí sí hace falta la corrida larga:
   dilo, presupuéstala, y que mida de una vez todo lo que quieras saber de ella.
2. **Arregla la causa, no el síntoma.**
3. **Deja el porqué en el código**, no el qué. Si la cifra viene de una medida,
   va la medida; si viene de una decisión, se dice que es una decisión. Y si el
   arreglo destapó algo que la documentación daba por cierto y no lo era,
   escríbelo.
4. **Actualiza lo escrito.** La spec de la que salió, si la hubo; `SPECS.md` si
   cambió un contrato; `docs/ESTADO.md` si cambió una cifra de las que
   afirma.

---

## 5. Comprueba, y comprueba las dos cosas

```
godot --headless --path . --script res://scripts/tests/RunTests.gd
```

- Que esté **en verde**.
- Y que el **total de comprobaciones no haya bajado**. Una prueba que revienta
  antes de su primer `assert` no falla: pasa. Ese número es lo único que lo
  delata.

Si tocaste código que salió de una fachada (`SettlementSim`, `GameUI`):

```
godot --headless --path . --script res://scripts/tools/LlamadasHuerfanas.gd
```

tiene que decir `llamadas huerfanas: 0`.

Y si era una cifra de balanceo, **córrela dos veces**. Hay sondas que no son
deterministas y dos corridas del mismo código pueden dar 35,8 y 48,9. Una
diferencia leída de una sola corrida no es una diferencia.

**Compilar no es funcionar.** Si el arreglo toca algo que se ve, corre el juego
o el panel (`VistaProbe`, `PanelProbe`) antes de darlo por hecho: GDScript no
avisa en compilación de asignar una propiedad que no existe.

---

## 6. Cuenta lo que pasó de verdad

Al usuario, y en el documento si lo hay. Incluidas las sorpresas: qué creías
que era, qué era, y qué apareció por el camino. Si te has dejado algo sin
arreglar, dilo tú antes de que lo pregunte.

---

**Y no malgastes contexto.** Los documentos de este repo son largos: busca con
`grep -n` y lee el trozo, no el fichero; filtra la salida de las sondas; no
pegues ficheros en el chat. Las reglas están en CLAUDE.md, «No malgastes
contexto» — y la contraria también: leer lo que hace falta es barato,
adivinarlo no.

---

## Si vais a ser varios

Lee y firma en `.claude/agentes/pizarra.md` antes de editar, y **toma el turno
de Godot** antes de correr la suite o una sonda — con el turno tomado, nadie
toca un `.gd`, tú incluido. Protocolo completo en
[docs/AGENTES.md](../../docs/AGENTES.md).

Depurar es justo el trabajo que más mide y más edita, así que es el que más
fácil pisa a otro. Declara también los ficheros que **puede** que toques.
