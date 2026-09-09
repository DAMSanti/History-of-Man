# Época 5 — Edad del Bronce: el linaje y la red

~1800–800 a.C. `Site.Era.METALES`. Primera época con un oficio puro —el
artesano, que no produce comida y aun así come— y primera que ata el valle a
una red de intercambio que no controla.

**Punto de partida.** Cubeta con fuelle, primer metal trabajado, ruta de
estaño ya abierta (hito de cierre del Calcolítico).

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| Horno mejorado (~1200 °C) | cubeta con fuelle | — (obra) | Bronce de verdad, no cobre con suerte | ATESTIGUADO |
| Molde bivalvo | horno mejorado | `METALURGO` | La forma se repite: hacha de talón en serie | ATESTIGUADO |
| Telar de pesas | lana de los ovicaprinos (época 3) | `ARTESANO` (nuevo) | Tela sin salir del poblado | PLAUSIBLE para el detalle, ATESTIGUADO el peso de telar como hallazgo tipo |
| Rueda de alfarero | cerámica neolítica | `ARTESANO` | Cerámica en cantidad y a medida | ATESTIGUADO como tecnología general de la época |
| El depósito escondido | bronce en cantidad | — (decisión, no técnica) | Metal enterrado a propósito: primera riqueza guardada fuera de casa | ATESTIGUADO (Cofresnedo, Matienzo) |

Segundo peldaño de la escalera térmica: el horno mejorado. El salto real no
es de temperatura sola —cien grados más que la cubeta— sino de **qué llega
a fundirse de verdad**: la aleación exige las dos materias primas a la vez,
cobre y estaño, y el estaño sigue sin estar en Cantabria.

---

## 2. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| Horno mejorado | interno | obra construida | — |
| El molde bivalvo | interno | primera pieza repetida desde molde | — |
| El telar de pesas | interno | técnica/obra nueva | — |
| La rueda de alfarero | interno | técnica nueva | — |
| El depósito escondido | interno | primer alijo de metal enterrado sin consumir | posible `Feature` de depósito, hoy sin valor propio en `Site.Feature` |
| El artesano | social | primer `ARTESANO` sostenido sin tarea de subsistencia asignada | — |
| La ruta del estaño | social | continuidad de `Intercambio` abierto en el cierre anterior | — |
| El ajuar desigual | social | dos entierros del mismo asentamiento con diferencia de bienes medible | — |
| El poblado en alto | social | primer asentamiento fundado priorizando `Site.Kind.ALTURA` sobre `VALLE` | — |
| **El ocre da metal** | **cierre** | el mismo `Materia.Kind.OCRE` que se recoge desde la época 1 se identifica y funde como mineral de hierro | — |

**Este es el mejor hito del juego y ya está escrito, sin que haya que
inventarlo**: `SLICE_PALEOLITICO.md` §4, en la fila del ocre, dice
literalmente "el mismo mineral que 30.000 años después se funde en hierro".
El hito no es fundirlo bien —eso es la época siguiente—, es **verlo**: que
el jugador conecte un material que lleva usando treinta mil años de partida
con lo que se convierte. Es también la prueba de que la fidelidad histórica
de este proyecto no es decorado: el dato estaba desde la primera ficha de
`Materia.Kind`.

---

## 3. Oficios y profesiones

| `Job` nuevo | Notas |
|---|---|
| `ARTESANO` | Primer oficio puro: no produce nada de `Subsistence.Activity` y aun así come. En `Profession.CATALOGUE` su `activity` es `-1`, igual que `HOGAR`, pero a diferencia del hogar sí exige que el resto de la banda genere el excedente que lo sostiene — es el primer punto en que el reparto de comida (`Reparto.gd`) tiene que tolerar bocas que no trabajan el campo ni el monte |

`METALURGO`, que en la época 4 era embrionario, aquí se consolida como
especialidad de pleno derecho de `MANUFACTURA` o pasa a `Job` propio si el
volumen de producción de bronce lo justifica al implementar.

---

## 4. Mecánicas nuevas

1. **El oficio que no produce comida.** Hasta ahora todo `Job` con
   `activity >= -1` en `Profession.CATALOGUE` o no producía nada (`HOGAR`,
   `OCIOSO`) o producía subsistencia directa. `ARTESANO` es el primero que
   no produce subsistencia y **tampoco es un cuidado** como el hogar: pide
   que el sistema de reparto entienda que alimentar a un artesano es una
   inversión, no un gasto sin retorno.
2. **La riqueza que se esconde en vez de usarse.** El depósito escondido es
   el primer caso de un material que se retira del ciclo de consumo a
   propósito — antecede a la moneda y al mercado (época 7) como forma de
   guardar valor.
3. **La desigualdad medible entre dos entierros del mismo sitio.** Pide que
   `Chronicle`/el registro de fallecidos lleve algo parecido a un ajuar, que
   hoy no existe.

---

## 5. La trampa

Que el metal sustituya a la piedra al día siguiente. EPOCAS.md es
explícito: la piedra pulimentada sigue siendo la inmensa mayoría de las
herramientas durante siglos, y el bronce es caro, escaso y en buena medida
prestigio. Si el reparto de materiales del juego pone bronce como material
corriente en cuanto está disponible, se ha perdido lo que el bronce
significaba — coherente con "el objeto que no sirve" de la época anterior.

---

## 6. Fidelidad

`ATESTIGUADO` el material —hachas de talón, cuevas sepulcrales, túmulos,
arte esquemático, depósitos en Cofresnedo—; `PLAUSIBLE` el detalle de la
organización social (el ajuar desigual como prueba de jerarquía es
interpretación razonable, no hecho cerrado).
