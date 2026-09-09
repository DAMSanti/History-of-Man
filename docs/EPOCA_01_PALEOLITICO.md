# Época 1 — Paleolítico: el valle helado

Magdaleniense cantábrico, ~17.000–11.700 a.C. `Site.Era.PALEOLITICO`. Es la
única de las doce que ya está en construcción, así que esta ficha no repite
[SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) —que sigue siendo el diseño de
referencia— sino que la conecta con [SISTEMAS_COMPARTIDOS.md](SISTEMAS_COMPARTIDOS.md)
y dice, con el código delante, qué falta.

**Punto de partida.** Ninguno: es la primera época. La banda llega con
doscientos mil años de acumulación técnica encima —fuego, talla sobre lasca,
enmangue, curtido, cordelería, conservación, ciclo anual—, ver
`SLICE_PALEOLITICO.md` §1.

---

## 1. El choque que hay que resolver antes que nada

EPOCAS.md §3 ya lo destapa y ya lo falla: `SLICE_PALEOLITICO.md` §1 dice que
la banda **ya sabe** talla laminar, propulsor, azagaya, arpón y aguja;
`TechTree.gd` dice que esas cinco **se aprenden practicando** —el arpón,
850 jornadas de pesca—. Mirando el código de hoy, `TechTree.known` arranca
con un solo valor (`{Tech.LASCA: true}`), así que **el código ya vive la
versión que EPOCAS.md recomienda**: gana `TechTree`. Lo único que queda
pendiente es de redacción, no de motor — corregir la lista de
`SLICE_PALEOLITICO.md` §1 para que diga lo que el código ya hace: la banda
trae fuego, talla sobre lasca, enmangue, curtido, cordelería, conservación y
el ciclo anual, y el resto —núcleo, hoja, azagaya, propulsor, arpón, aguja—
es la escalera de `TechTree.CATALOGUE` que se sube jugando.

---

## 2. Desarrollos tecnológicos

Ya están en `TechTree.CATALOGUE` y `TechTree.BRANCHES`, con jornadas y coste
en material medidos, no inventados aquí. Resumen por oficio (el oficio sale
de la rama, `TechTree.job_of`):

| Oficio | Técnicas, en orden | Jornadas acumuladas hasta el final |
|---|---|---|
| `MANUFACTURA` | Lasca → Núcleo (45) → Hoja (110) → Aguja (190) | 345 |
| `CAZA` | Lazo (35) → Cepo (110) → Red de aves (190) → Foso (330) → Azagaya (140) → Ojeo (260) → Propulsor (420) → Arco (700) | hasta 2185 |
| `RIBERA` | Pesquera (60) → Nasa (180) → Anzuelo (320) → Red (560) → Arpón (850) | hasta 1970 |
| `EXPLORACION` | Pasarela (70) → Piragua (150, pide `Kind.HOGAR`) | 220 |
| `HOGAR` | Arte (200, pide `Kind.HOGAR`) | 200 |

**Lo que falta de instalación, no de técnica**: `CampProjects.Kind` sólo
tiene `HOGAR`, `SECADERO`, `LAVADERO`. Es la lista correcta para esta época
—no hace falta ninguna instalación térmica nueva, el hogar abierto a ~700 °C
es el techo de todo el Paleolítico— y no debe crecer hasta el Neolítico.

---

## 3. Hitos

Usando el formato de `Hito` de `SISTEMAS_COMPARTIDOS.md` §2:

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| Núcleo preparado | interno | `TechTree.has(Tech.NUCLEO)` | — |
| Talla laminar | interno | `TechTree.has(Tech.HOJA)` | — |
| Azagaya y propulsor | interno | `TechTree.has(Tech.PROPULSOR)` | — |
| Aguja con ojo | interno | `TechTree.has(Tech.AGUJA)` | — |
| Lámpara de grasa | interno | obra nueva de `CampProjects` (no existe hoy) | — |
| El arpón de asta | interno | `TechTree.has(Tech.ARPON)` | — |
| El relato junto al fuego | interno | ya implementado, `Tale.gd` | — |
| El primer trazo en la pared | interno | `TechTree.has(Tech.ARTE)` y primera obra pintada | `Feature.OTRO` (no hay `Feature` de arte parietal hoy; ver §5) |
| La sepultura | interno | no implementado: pide un `Inhabitant` fallecido y una decisión de gasto de trabajo en el entierro | — |
| La concha de lejos | interno | primer `Intercambio` recibido (§5 de `SISTEMAS_COMPARTIDOS.md`), aún sin construir | — |
| La agregación estacional | interno | no implementado: exige más de un `Settlement`, fuera de esta slice | — |
| El santuario | interno | arte parietal en un sitio que no es el de habitación | — |
| Máximo Glacial (interno, consecuencia de mapa) | interno | ya calculado: `RegionEras` + `Site.coast_km_by_era`, sin código nuevo | cambia disponibilidad, no `Feature` |
| **El bosque cierra el valle** | **cierre, se sufre** | cuenta de años/hitos desde el inicio de partida, ver `SISTEMAS_COMPARTIDOS.md` §6 | retirada de fauna de manada del `WildlifeHerds` local |

---

## 4. Oficios y profesiones

Sin cambios respecto a lo que hay: `Profession.Job` en su forma actual
—`CAZA`, `RIBERA`, `RECOLECCION`, `MANUFACTURA`, `EXPLORACION`, `HOGAR`,
`OCIOSO`— es exactamente el reparto de esta época y no necesita ningún valor
más. Es la única ficha de las doce donde esta sección no pide nada nuevo.

---

## 5. Mecánicas nuevas que faltan en esta época

No son "contenido de más adelante": son piezas de esta misma época que
`SLICE_PALEOLITICO.md` §7 ya pide y que siguen sin construirse, más una que
añade el objetivo de esta tanda de trabajo:

1. **Exploración regional** (`SISTEMAS_COMPARTIDOS.md` §4). Hoy `Reconocimiento`
   y `Exploration` sólo trabajan dentro del recuadro local de 4 km; el
   objetivo explícito de esta fase es que el mapa de Cantabria deje de
   mostrar los 862 emplazamientos desde el minuto uno (ROADMAP.md A1) y se
   revele por proximidad y por expedición larga desde el sitio fundado.
2. **El conchero crece** y modifica el terreno (`SLICE_PALEOLITICO.md` §7.4):
   el residuo de marisqueo es un subproducto real de `ProcessRecipe`
   (FASE B1), no un número en un almacén.
3. **Saber tácito que decae**, la otra mitad de FASE C1: hoy `TechTree.known`
   sólo sube, nunca baja con el relevo generacional.
4. **`Feature` de arte parietal.** `Site.Feature` no distingue "cueva con
   arte" de "abrigo natural cualquiera"; el primer trazo en la pared
   (§3) necesita un valor nuevo o una marca aparte, porque hoy no hay dónde
   anotar que un sitio concreto se volvió santuario.
5. **La sepultura** y **la agregación estacional** son los dos hitos
   sociales de la ficha que exigen algo que no existe todavía: la primera,
   una noción de "fallecido con ajuar" en `Inhabitant`/`Chronicle`; la
   segunda, más de una banda simulada a la vez, que `SLICE_PALEOLITICO.md`
   marca fuera de la slice a propósito.

---

## 6. La trampa

La misma que ya señala EPOCAS.md: alargarla porque es la que está hecha. Es
la época mejor construida del proyecto y **la exploración regional del
punto 1 no es una excusa para quedarse más tiempo aquí**: es infraestructura
que sirve exactamente igual a las once épocas siguientes, y es la razón por
la que este documento la trata como la pieza que abre paso, no como
contenido nuevo del Paleolítico.

---

## 7. Fidelidad

`ATESTIGUADO` con margen: Altamira, El Castillo (secuencia de ocupación más
larga de Europa, arte parietal datado más antiguo del continente),
La Pasiega, El Pendo, Covalejos, El Mirón (con el enterramiento de la Dama
Roja) y La Garma, con suelo de ocupación sellado. El ciclo estacional de
decisiones (berrea en otoño, remonte en primavera) es `INFERIDO`: la
estacionalidad es real, el calendario concreto de juego es construcción,
como ya advierte `SLICE_PALEOLITICO.md` §9.
