# Época 3 — Neolítico: la primera arquitectura

~5500–3000 a.C. `Site.Era.NEOLITICO`. Tercera en la cola de ROADMAP.md FASE D:
el primer peldaño térmico propio (cerámica) y la primera vez que se
construye en vez de ocupar. Es también donde el usuario pide, expresamente,
sentar la base de la agricultura como sistema.

**Punto de partida.** Todo el Mesolítico, más el primer grano ya guardado
(hito de cierre de la época 2). En Cantabria el Neolítico es **tardío y de
registro pobre**: llega tarde y convive mucho tiempo con la caza — el dato
más citado es el grano de cereal de El Mirón (~5300–4000 a.C.), entre los
más antiguos de la cornisa cantábrica, junto con las cabañas ganaderas de
Los Gitanos (Castro Urdiales). La región favoreció siempre más el pastoreo
que el cultivo, y eso debe notarse en cómo se reparte el trabajo, no sólo en
el texto.

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| Horno de fosa (~900 °C) | ninguno técnico, es obra de `CampProjects` | — | **Cerámica**: primer peldaño propio de la escalera térmica | ATESTIGUADO (cerámica en niveles neolíticos) |
| El recipiente que no se pudre | horno de fosa | `MANUFACTURA`/alfarería | Cocer cambia la dieta más que el arado | ATESTIGUADO |
| Hacha pulimentada | pule sobre `Tech.HOJA` | `MANUFACTURA` | Talar de verdad: hace el pasto | ATESTIGUADO |
| Ovicaprinos (domesticación) | ninguna, es adquisición de rebaño | `PASTOR` (nuevo) | Leche y lana: un animal que se come varias veces | ATESTIGUADO |
| Molino de vaivén | ninguno | `LABRIEGO` (nuevo) | El grano se muele sin salir del poblado | ATESTIGUADO |
| Siembra de cereal | el grano guardado del cierre anterior | `LABRIEGO` | Cultivo real de `Triticum`/`Hordeum`, documentado en El Mirón | ATESTIGUADO |

---

## 2. El sistema de agricultura, en concreto

Esto es lo que el objetivo de esta tanda pide sentar como base, no sólo
como ficha de época. Tres piezas nuevas, siguiendo el patrón de
`SISTEMAS_COMPARTIDOS.md` §1.3:

1. **`Subsistence.Activity.SIEMBRA` y `.PASTOREO`.** Dos actividades nuevas
   junto a las cinco que ya existen (`CAZA`, `MARISQUEO`, `PESCA`,
   `RECOLECCION`, `MATERIA_PRIMA`). No sustituyen a `RECOLECCION`: conviven,
   porque el registro cántabro dice que se sigue cazando y mariscando
   durante siglos.
2. **La parcela, no el `Paraje`.** Un `Paraje` de caza o recolección se
   encuentra y se agota; un campo se **planta**, con un ciclo fijo de
   siembra → espera de una estación entera → cosecha, y con rendimiento que
   depende de trabajo puesto (deshierbar, regar si toca) más que de suerte
   de terreno. Es una clase nueva, `Campo` o `Sementera`, con posición fija
   elegida por el jugador (o por `Reparto` si se automatiza), no descubierta
   por batida.
3. **El rebaño como inventario que se mueve solo.** Los ovicaprinos no son
   un `Materia.Kind` que se recoge: son una población propia, con
   reproducción y consumo de pasto, más cercana en forma a `WildlifeHerds`
   (que ya simula manadas) que a un recurso estático. La diferencia clave
   con la fauna salvaje es que el rebaño **pertenece** a la banda y se
   traslada con el pastoreo de altura (verano arriba, invierno abajo), que
   es el hito social de "la trashumancia corta que aún se ve" en Cantabria.

**Sobre la "mejora genética" que pide el objetivo de esta tanda**: en el
Neolítico no hay genética, hay **selección artificial a ojo** —se guarda
para criar al animal más manso, a la espiga que no se desgrana sola—, y así
debe leerse en el juego: no un árbol de "genética" adelantado a su tiempo,
sino que el rendimiento del rebaño y del campo mejora con **generaciones**
de cría dirigida, medido en el mismo sistema de saber tácito que ya usa
`TechTree` para el resto de técnicas (se mejora haciendo, aquí haciendo
cría). La genética de verdad —cruces controlados, razas fijadas
científicamente— no aparece hasta Robert Bakewell y la revolución agrícola
británica del XVIII, y en el juego encaja mejor como hito técnico de la
Edad Moderna o de El siglo corto (ver `EPOCA_10_EDAD_MODERNA.md` y
`EPOCA_12_SIGLO_CORTO.md`), no aquí. Meterla en el Neolítico sería el mismo
error que empezar la partida descubriendo el fuego: un tópico que además es
falso.

---

## 3. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| Horno de fosa | interno | obra de `CampProjects` construida | — |
| El recipiente que no se pudre | interno | primera pieza de cerámica cocida | — |
| El hacha pulimentada | interno | técnica nueva de `TechTree` | — |
| Ovicaprinos | interno | primer rebaño adquirido (por intercambio, `SISTEMAS_COMPARTIDOS.md` §5, o por domesticación local si se decide modelarla) | — |
| El molino de vaivén | interno | obra construida | — |
| La propiedad del rebaño | social | primer rebaño con dueño individual, no comunal | — |
| La tumba colectiva | social, previa al cierre | primeros ortostatos movidos, sin llegar aún al dolmen completo | — |
| El pastoreo de altura | social | rebaño trasladado entre dos `Site` por estación | — |
| La aldea | social | primer asentamiento fundado fuera de un abrigo natural (rompe la regla `Site.is_usable_in(NEOLITICO)`, que ya lo permite: `slope_deg < 15` y agua o costa cerca) | — |
| **El dolmen levantado** | **cierre** | convocar más brazos de los que tiene una familia: umbral de jornadas conjuntas de una obra de gran escala, no sólo material acumulado | `Feature.MEGALITO` |

---

## 4. Oficios y profesiones

Dos oficios nuevos, siguiendo el patrón de `Profession.Job` que crece sin
tocar el resto del sistema:

| `Job` nuevo | `min_age`/`max_age` orientativos | `mobile` | Notas |
|---|---|---|---|
| `LABRIEGO` | 10–70 | no | Siembra, deshierba, cosecha, muele. Convive con `RECOLECCION`, no la sustituye |
| `PASTOR` | 8–75 (el pastoreo lo puede llevar un crío, como hoy `RIBERA`) | sólo cuando trashuma | Cuida rebaño, lo traslada en la trashumancia de altura |

`RECOLECCION` no se retira: EPOCAS.md insiste en que la época debe poder
jugarse **sin** apostarlo todo al campo. `MANUFACTURA` gana la especialidad
de alfarería (cerámica) junto a las cuatro que ya tiene.

---

## 5. Mecánicas nuevas

1. El sistema de agricultura de §2, con sus tres piezas.
2. El sistema de rebaño doméstico, distinto de `WildlifeHerds`.
3. Primera obra de escala comunitaria real: el megalito exige coordinar más
   gente de la que rinde cualquier tarea individual, y es el primer caso en
   el juego de un coste que no es "más jornadas de una persona" sino "más
   personas a la vez".

---

## 6. La trampa

La "revolución neolítica" en una temporada. EPOCAS.md es tajante: en
Cantabria fue lentísima y mixta, se sigue cazando y mariscando durante
siglos, y la época debe permitir jugar sin apostarlo todo al campo,
castigando sólo si el invierno lo pide de verdad.

---

## 7. Fidelidad

`ATESTIGUADO` el megalitismo (Alto Asón, Peña Oviedo) y el grano de El
Mirón; `INFERIDO` el detalle del calendario agrícola concreto. `Site.Feature.MEGALITO`
ya existe en el código y no necesita cambios para recibir el hito de cierre.

Sources:
- [The spread of agriculture in northern Iberia: El Mirón cave](https://link.springer.com/article/10.1007/s00334-005-0078-7)
- [The first farmers in Cantabrian Spain](https://www.sciencedirect.com/science/article/abs/pii/S1040618214006740)
