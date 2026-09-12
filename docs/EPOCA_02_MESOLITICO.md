# Época 2 — Mesolítico: la costa

Aziliense y Asturiense, ~11.700–5.500 a.C. `Site.Era.MESOLITICO`. Primera de
las once que faltan por construir, y la que ROADMAP.md FASE D pone la
siguiente en la cola, porque la cadena corta de FASE B3 —cuarcita de río →
pico → marisqueo → conchero— es literalmente el Asturiense convertido en
juego.

**Punto de partida.** Todo lo del Paleolítico: fuego, talla, azagaya,
propulsor, arpón, aguja, arte parietal como saber ya sea `TÁCITO` o
`EXTERNALIZADO` según cómo haya terminado la partida anterior. Lo que se
pierde no es técnica, es **presa**: el reno y el caballo se van del valle
(cierre de la época 1), así que la caza mayor de manada deja de sostener a
la banda y el centro de gravedad se mueve al mar, que sube deprisa.

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| Pico asturiense | (ninguno, es cadena B3) | `RECOLECCION`/cantera | Arrancar lapa en la rasa | ATESTIGUADO (costa occidental) |
| Microlitos | `Tech.HOJA` | `MANUFACTURA` | Filos pequeños en serie sobre asta/madera | ATESTIGUADO |
| Arco | ya en `TechTree.Tech.ARCO`, hereda de `PROPULSOR` | `CAZA` | Precisión y tiro repetido; caza de acecho individual | ATESTIGUADO (Aziliense) |
| Piragua | ya en `TechTree.Tech.PIRAGUA`, hereda de `NUCLEO` | `EXPLORACION` | Cruzar estuario, pesca en aguas profundas | INFERIDO para esta región concreta |
| Conchero como obra | nueva, no existe | — | Subproducto acumulado que es, a la vez, el yacimiento | ATESTIGUADO |

**El arco y la piragua ya están en `TechTree.CATALOGUE`** — el árbol técnico
del Paleolítico ya se adelantó a esta época, cosa que EPOCAS.md no señala y
que conviene decirlo aquí: si una banda del Paleolítico llega a dominarlos
antes del cierre de época, el Mesolítico no tiene que reenseñarlos, sólo dar
continuidad. Lo nuevo real de esta época es el **pico asturiense** y los
**microlitos**, que hoy no tienen entrada en `TechTree`.

**El techo térmico no cambia.** Sigue siendo el hogar abierto a ~700 °C: el
Mesolítico no toca la escalera térmica de `SISTEMAS.md` §1.1, y
por eso EPOCAS.md lo señala como el peor candidato para partirse en dos —no
cambia ni dónde se vive, ni qué se fabrica del todo, ni quién decide—.

---

## 2. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| El pico asturiense | interno | nueva técnica en `TechTree` (o proceso de `ProcessRecipe` si no compensa un `Tech` completo) | — |
| Microlitos | interno | técnica nueva, `needs: [Tech.HOJA]` | — |
| El arco | interno | ya alcanzable con el árbol actual | — |
| La piragua | interno | ya alcanzable con el árbol actual | — |
| El conchero | interno | acumulación de subproducto de marisqueo sobre el mismo `Paraje`, ver §5 | `Feature` nuevo o marca sobre `ABRIGO`/`OTRO` |
| El territorio pequeño | social, sin gatillo mecánico propio | se lee del patrón de exploración: radio de batida menor que en la época 1 | — |
| El muerto en la basura | interno | entierro dentro del conchero, mismo requisito que "la sepultura" de la época 1 pero en otro lugar | — |
| El vecino | social | primer contacto sostenido con otro grupo por la capa exterior de exploración (`SISTEMAS.md` §4) | — |
| **El primer grano sembrado** | **cierre** | una sola siembra: alguien guarda semilla en vez de comérsela. No pide excedente ni granero, sólo la decisión de gastar comida de hoy en la de dentro de un año | — |

**El hito de cierre es deliberadamente barato.** EPOCAS.md lo dice: "sin
excedente ni graneros". En código es una bandera, no un sistema de
agricultura completo — el sistema de agricultura de verdad (parcela,
`SIEMBRA` como `Subsistence.Activity`, cosecha) es del Neolítico, época 3.
Aquí basta con que exista `Materia.Kind` de semilla guardable y una decisión
del jugador (o de la IA de reparto) de no consumirla.

---

## 3. Oficios y profesiones

Ningún `Job` nuevo. Cambios dentro de los que ya existen:

- `RIBERA` gana peso relativo frente a `CAZA`: con el reno y el caballo
  fuera del valle, buena parte de la banda que antes cazaba pasa a
  marisquear o pescar. No hace falta una especialidad nueva —`MARISQUEO`,
  `ORILLA` y `ALTURA` ya cubren el abanico—, sólo que el reparto de tareas
  (`Reparto.gd`) refleje que hay menos trabajo de `CAZA_MAYOR` disponible
  porque `WildlifeHerds` ya no trae manada.
- `MANUFACTURA` gana trabajo de microlito, que es la misma actividad
  (`MATERIA_PRIMA`) con otra técnica, no una especialidad nueva.
- `EXPLORACION` gana sentido nuevo con la piragua: cruzar el estuario abre
  territorio que antes era frontera, así que la especialidad `EXPEDICION`
  debería poder alcanzar la otra orilla si la banda ya sabe hacer piragua.

---

## 4. Mecánicas nuevas

1. **El conchero como obra viva.** No es sólo un vertido de concha: crece,
   se lee en el paisaje y acaba siendo el emplazamiento en sí —"en
   Cantabria el conchero es el yacimiento", dice EPOCAS.md—. Necesita que
   el subproducto de marisqueo (FASE B1, `ProcessRecipe`) se acumule sobre
   una posición fija en vez de perderse, y que `TerrainGenerator` sepa
   dibujar el volumen que resulta.
2. **La costa que se acerca cada década.** El mar sube deprisa en esta
   época —al revés que en el Paleolítico, donde bajaba—, y eso ya está
   soportado por `RegionEras`/`Site.coast_km_by_era`: no hace falta código
   nuevo, pero sí que el jugador lo note, porque sitios de la época anterior
   pueden quedar bajo el agua dentro de la misma partida.
3. **El primer paso de la escalera del alimento** (`SISTEMAS.md`
   §1.3): "marisqueo y costa" como base de subsistencia dominante, no ya
   accesoria como en el Paleolítico.

---

## 5. Qué construir en código

- `scripts/sim/Concheros.gd` (nombre tentativo), con el mismo patrón que
  `Barbecho.gd`: revisa tras cada jornada, acumula subproducto de
  `MARISQUEO` en la posición del `Paraje` de marisqueo activo.
- Dos entradas nuevas en `TechTree.CATALOGUE` (pico, microlitos) y su
  `BRANCHES` correspondiente; ninguna rama nueva, van a las que ya existen.
- Un valor de semilla guardable en `Materia.Kind` si no se quiere esperar al
  Neolítico para tenerlo (el hito de cierre lo necesita antes que el sistema
  de siembra completo).

---

## 6. La trampa

Contarlo como decadencia. EPOCAS.md es explícito: "ya no hay arte, ya no hay
grandes cacerías" es la lectura equivocada. El Asturiense es un ajuste
eficientísimo a un ecosistema nuevo, y la interfaz —textos, tono de los
paneles— no debe presentarlo como una banda venida a menos.

---

## 7. Fidelidad

`ATESTIGUADO`: arpones planos azilienses y cantos pintados en El Valle y El
Piélago; concheros y picos de cuarcita del Asturiense en la costa
occidental; enterramientos en conchero en El Perro y La Fragua (Santoña).
