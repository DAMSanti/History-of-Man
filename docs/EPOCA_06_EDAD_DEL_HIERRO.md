# Época 6 — Edad del Hierro: los cántabros

~800–19 a.C. `Site.Era.METALES`. La unidad deja de ser la familia extensa y
pasa a ser el castro — la primera vez en el juego que "quién decide" cambia
de verdad, y no sólo "de qué se vive".

**Punto de partida.** Bronce en circulación como material de prestigio, el
ocre ya identificado como mineral de hierro (cierre de la época anterior).

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| Cuba baja (~1250 °C) | horno mejorado | — (obra) | Hierro en estado sólido: esponja, no colada | ATESTIGUADO como proceso general de reducción directa |
| La forja | cuba baja | `HERRERO` (nuevo) | Limpiar la esponja a martillo; media jornada de golpes por kilo | ATESTIGUADO |
| El mineral de aquí | la piedra verde (época 4) reaplicada al hierro | `PROSPECTOR` | Por primera vez el metal no viene de fuera: se acaba la dependencia de la ruta | ATESTIGUADO (Cabárceno ya tenía mineral de hierro accesible) |
| Molino circular | molino de vaivén (época 3) | `LABRIEGO` | Rotatorio: multiplica la harina por hora de trabajo | ATESTIGUADO |
| Muralla y foso | ninguno técnico, es obra colectiva | — | Construcción defensiva del año | ATESTIGUADO (Las Rabas, Monte Ornedo) |
| La salazón | sal (recurso nuevo, sin `Materia.Kind` hoy) | `RIBERA`/nueva especialidad | Comida que viaja y se vende | PLAUSIBLE para el detalle cántabro concreto |

Tercer peldaño de la escalera térmica, y **el primero que rompe la
dependencia de intercambio** en vez de crearla: a diferencia del estaño del
Bronce, el mineral de hierro cántabro está en Cabárceno y no hay que
importarlo. Es un contrapunto de diseño útil frente a la época anterior.

---

## 2. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| Cuba baja | interno | obra construida | — |
| La forja | interno | primera pieza de hierro forjada desde esponja | — |
| El mineral de aquí | interno | primera colada con mineral de un `Site` propio, sin `Intercambio` | — |
| El molino circular | interno | obra/técnica nueva | — |
| La muralla y el foso | interno | obra colectiva de escala de asentamiento (mismo patrón de coste que el dolmen del Neolítico) | — |
| La salazón | interno | proceso nuevo de `ProcessRecipe` | — |
| La comunidad castreña | **social, y es el cambio de unidad** | primer `Settlement` cuya identidad ya no es la banda/familia sino el castro entero | `Feature.CASTRO` (ya existe) |
| El guerrero | social | primer `Job` de violencia sostenida por el resto | — |
| El pacto entre castros | social | primera relación formal entre dos `Settlement` (`SISTEMAS.md` §7, "el primer sitio donde hace falta código nuevo de verdad") | — |
| La frontera | social | primer límite reconocido con nombre frente a un `Settlement` vecino | — |
| **La legión en el collado** | **cierre, se sufre** | cuenta de años desde el inicio de la época, con margen; no es evitable | Un `Feature.ROMANO` (campamento) que puede convivir en el mismo emplazamiento que un `Feature.CASTRO` abandonado |

**El cierre no se gana, se afronta.** EPOCAS.md lo dice sin rodeos: las
Guerras Cántabras (29–19 a.C.) se pierden, y el juego no debe ofrecer
ganarlas. La investigación histórica confirma la forma concreta que debe
tener el hito en el juego: los castros de resistencia (Vellica, Aracillum)
cayeron por **cerco y hambre**, no por batalla campal — Roma quemó campos e
incendió cosechas antes de asaltar, y el invierno diezmó tanto a
defensores como a atacantes en el monte Vindio. Eso da la forma correcta al
"qué se decide" que EPOCAS.md deja abierto: no es "ganar o perder el
asedio", es **cuánto dura la resistencia y qué se evacúa antes de que
caiga** — población, saber externalizado, ganado — y ese margen sale
directamente del estado de la banda en el momento en que se dispara el
hito, no de una tirada aparte.

---

## 3. Oficios y profesiones

| `Job` nuevo | Notas |
|---|---|
| `HERRERO` | Sucesor directo de `METALURGO`: forja en vez de sólo fundir. Encaja como evolución de la especialidad de metalurgia más que como ruptura |
| `GUERRERO` | Primer oficio cuyo producto es la violencia y que el resto de la banda mantiene sin recibir bien material a cambio. Es el precedente directo de por qué, en Roma, ese mismo oficio puede reciclarse como auxiliar o disolverse — ver `EPOCA_07_ROMA.md` |

`PROSPECTOR` deja de buscar sobre todo cobre y estaño y pasa a centrarse en
mineral de hierro local, cerrando el ciclo que abrió con la piedra verde.

---

## 4. Mecánicas nuevas

1. **La relación entre dos `Settlement`.** El pacto entre castros es la
   primera vez que el juego necesita modelar una relación formal —alianza,
   hospitalidad— entre dos unidades de decisión, no sólo entre una banda y
   el territorio. Es infraestructura que sirve también para el "vecino" del
   Mesolítico en retrospectiva y para el comercio con otras tribus que pide
   el objetivo de esta tanda: un castro vecino es, mecánicamente, la primera
   forma jugable de "otra tribu".
2. **El asedio como hito que se sufre.** El patrón de "se sufre" definido en
   `SISTEMAS.md` §6 se concreta aquí por primera vez con una
   secuencia real (cerco → quema de campos → asalto o rendición), y ese
   mismo patrón —no el contenido romano en sí— es el que reutiliza el
   Estado que se va (época 7), que con el siglo corto retirado es ya el
   último de los tres hitos que se sufren.

---

## 5. La trampa

El cántabro indomable. Es el tópico local por excelencia, y EPOCAS.md pide
resistirlo: aquí hay agricultura, minería, comercio y jerarquía, no una
tribu heroica peleando contra el mundo. El diseño del cerco de §2 refuerza
esto — lo que se juega no es la heroicidad de resistir, es la gestión de qué
se salva antes de que la resistencia se acabe.

---

## 6. Fidelidad

`ATESTIGUADO`: castros de Las Rabas, Monte Ornedo, La Espina del Gallego y
Cildá; fuentes grecolatinas para el desenlace militar. `PLAUSIBLE` la
adscripción de las estelas discoideas de Barros y Zurita.

Sources:
- [Las Guerras Cántabras más allá de la leyenda](https://elretohistorico.com/guerras-cantabras-conquista-romana-hispania)
- [Las guerras cántabras (29-19 a.C.)](https://historiaeweb.com/2021/08/13/guerras-cantabras/)
- [Guerras cántabras — Wikipedia](https://es.wikipedia.org/wiki/Guerras_c%C3%A1ntabras)
