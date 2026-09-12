# Época 7 — Roma: el Estado

19 a.C.–s. V. `Site.Era.HISTORICA`. La época en la que "quién decide" pasa,
por primera vez, a alguien que no vive en el valle. Se juega **el valle bajo
Roma**, no Roma: el Imperio es el clima, no el avatar.

**Punto de partida.** El castro que sobrevivió al cierre anterior —o el que
no, con el campamento romano encima del mismo emplazamiento— y lo que se
haya logrado evacuar durante el asedio (`EPOCA_06_EDAD_DEL_HIERRO.md` §2).

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| Arco y mortero hidráulico | ninguno del árbol local: llega con el Estado | `ARTESANO`/nuevo oficio de construcción | Construir alto y construir mojado | ATESTIGUADO |
| Teja y ladrillo | horno de fosa mejorado a escala de alfar | `ARTESANO` | Barro cocido en serie: la casa cambia de forma | ATESTIGUADO |
| La calzada | ninguno técnico, es obra de Estado | — | El coste de mover mercancía se hunde; reordena el mapa regional entero | ATESTIGUADO (Pisoraca–Portus Blendium, tramo de Bárcena de Pie de Concha) |
| Galería de mina | cuba baja (época 6) | `MINERO` (nuevo) | Extracción bajo tierra, con desagüe y turnos | ATESTIGUADO (Cabárceno) |
| El agua mueve la rueda | ninguno técnico | — (obra) | Molino hidráulico: primera vez que algo trabaja sin músculo detrás | ATESTIGUADO |
| Vidrio y moneda | comercio consolidado | `MERCADER` (nuevo) | Un valor que no se come y no se pudre | ATESTIGUADO |

No hay peldaño nuevo de la escalera térmica: el foco de la época es
**infraestructura y organización**, no metalurgia. El molino hidráulico es
el precedente directo del que sobrevive al Estado que se va (§2) y del que
usará el concejo en la Alta Edad Media.

---

## 2. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| El impuesto | social | primer tributo cobrado al `Settlement` por una autoridad externa | — |
| La ciudad | social | primer asentamiento con población que no produce alimento propio en su mayoría | `Feature.ROMANO` |
| La esclavitud | social, "hay que nombrarlo, no adornarlo" | trabajo modelado como propiedad, no como `Job` elegible — ver §4 | — |
| La ley escrita | social | primer documento con fuerza vinculante más allá de quien lo firmó | — |
| La lengua de fuera | social | adopción de préstamos por el mercado, no impuesta | — |
| **El Estado se va** | **cierre, se sufre** | cuenta de años desde el fin del hito de cierre de la época 6, con margen mayor que el asedio porque es un declive, no un asalto | Retirada de mantenimiento sobre `Feature.ROMANO`, sin borrarlo |

**Lo interesante es qué sobrevive, y el juego debe medirlo, no narrarlo.**
Siguiendo el patrón de `SISTEMAS.md` §6: al disparar el hito,
cada obra construida durante la época comprueba si dependía del Estado para
seguir funcionando. El molino sigue moliendo (no depende de nadie más que
del agua), la calzada sigue andándose (se degrada con el tiempo, no
desaparece de golpe), pero el impuesto deja de cobrarse y el mercado de
moneda deja de tener con qué comprar. Es la especificación concreta de la
frase de EPOCAS.md: "la época no termina en ruina, termina en una lista de
cosas que se conservan sin quien las mantenía".

---

## 3. Oficios y profesiones

| `Job` nuevo | Notas |
|---|---|
| `FUNCIONARIO` | Cobra el impuesto, lleva el censo. Desaparece limpio con el hito de cierre: sin Estado no hay a quién servir |
| `MERCADER` | Primer oficio ligado a un mercado de moneda fijo, no a trueque directo |
| `MINERO` | Trabajo de galería, distinto de `PROSPECTOR` (que busca) y de `HERRERO` (que transforma) |
| `GUERRERO` cántabro (heredado de la época 6) | Se disuelve o se recicla como auxiliar romano, según decisión del jugador o del estado de la banda al cierre anterior — no hay tercera vía neutral, y no debería haberla |

**La esclavitud no es un `Job`.** EPOCAS.md pide nombrarla, no adornarla:
modelarla como una opción elegible dentro de `Profession.Job` la
normalizaría como una carrera más. La forma correcta es un estatuto sobre
`Inhabitant` (una propiedad de estado, no de oficio) que condiciona qué
`Job` puede ejercer y quién decide su trabajo, y que el juego debe mostrar
como lo que es sin que sea jugable como aspiración.

---

## 4. Mecánicas nuevas

1. **El hito que se sufre por declive, no por evento súbito.** A diferencia
   de la legión en el collado (una secuencia de semanas), el Estado se va
   es un proceso de años: el patrón de `Hitos.revisar()` necesita distinguir
   "condición que se cumple en un instante" de "condición que se cumple
   gradualmente y hay que ir degradando servicios mientras dura".
2. **El estatuto de trabajo no elegible.** Primera vez que `Inhabitant`
   necesita un campo de condición social independiente del `Job` asignado.
3. **El mercado de moneda**, como capa por encima del `Intercambio` de
   trueque directo (`SISTEMAS.md` §5): mismo sistema, con un
   `Materia.Kind` de moneda que no se consume ni caduca.

---

## 5. La trampa

Jugar a ser Roma. Se juega el valle bajo Roma, no el Imperio: qué se paga,
qué se compra, qué oficio nuevo cabe. Si la interfaz empieza a mostrar
legiones que el jugador mueve, se ha cambiado de juego.

---

## 6. Fidelidad

`ATESTIGUADO`: campamentos de las Guerras Cántabras (La Espina del Gallego,
Cildá, El Cantón); Iuliobriga (Retortillo); Portus Victoriae (Santander);
Flaviobriga (Castro Urdiales); la calzada de Pisoraca a Portus Blendium;
minería de hierro en Cabárceno. `Site.Feature.ROMANO` ya existe en el
código y no necesita cambios de esquema para esta ficha.
