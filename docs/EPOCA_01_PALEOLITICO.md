# Época 1 — Paleolítico: el valle helado

Magdaleniense cantábrico, ~17.000–11.700 a.C. `Site.Era.PALEOLITICO`.

**Es la única de las once que está construida**, así que esta ficha no es sólo
diseño de destino como las otras diez: es el diseño **y** lo que falta de él,
con el código delante. Lo que hace hoy el juego, medido, está en
[ESTADO.md](ESTADO.md); lo que comparten todas las épocas, en
[SISTEMAS.md](SISTEMAS.md).

> Esta ficha absorbió el antiguo `archivo/SLICE_PALEOLITICO.md` el 2026-09-12, cuando
> la documentación se reorganizó para que lo único específico fueran las
> épocas. El original está en [archivo/SLICE_PALEOLITICO.md](archivo/SLICE_PALEOLITICO.md).

**Punto de partida.** Ninguno: es la primera época.

---

## Dónde mirar

| Si buscas… | Ve a |
|---|---|
| Qué sabe la banda al empezar y qué marca el techo de la época | §1 |
| Qué significa «investigar» aquí | §2 |
| **El año, estación a estación, y la tensión central de la época** | **§3** |
| Necesidades y de qué atributo del mapa sale cada recurso | §4 |
| Dónde empieza la partida y por qué ahí | §5 |
| Exploración, y qué limita el alcance de una expedición | §6 |
| **El árbol de técnicas por oficio, y el nudo de la azagaya** | **§7** |
| Los hitos y su condición de disparo | §8 |
| Qué falta por construir de esta época | §10 |
| La trampa: alargarla porque es la que está hecha | §11 |

Es la única época construida: lo que hace hoy, medido, está en
[ESTADO.md](ESTADO.md).

---

## 1. No se empieza de cero

Un grupo del Paleolítico superior **no es primitivo**. Lleva cientos de miles de
años de acumulación técnica y sabe perfectamente cómo cubrir sus necesidades.
Empezar la partida «descubriendo el fuego» es un tópico de género, y además es
falso.

**Lo que la banda trae puesto:** fuego, talla sobre lasca, enmangue, curtido,
cordelería, conservación por secado y ahumado, ocupar cueva y levantar
paravientos, y el ciclo anual —cuándo sube el salmón, cuándo es la berrea—.

**Lo que NO sabe, y marca el techo de la época:**

> Arco · cerámica · agricultura · ganadería · metal · rueda · molienda intensiva.

Ese techo no se escribe como lista de bloqueos: **sale solo** de qué procesos
existen y de la temperatura alcanzable. Un hogar abierto no pasa de ~700 °C, y
ésa es la barrera —ver la escalera térmica de [SISTEMAS.md](SISTEMAS.md) §1.1—.

> **Corregido (2026-09-12).** La versión anterior de este párrafo decía que la
> banda ya sabía **talla laminar, propulsor, azagaya, arpón y aguja**. Chocaba
> de frente con `TechTree.gd`, donde esas cinco se aprenden practicando —el
> arpón, 850 jornadas de pesca—. Ganó el código: `TechTree.known` arranca con
> un solo valor (`{Tech.LASCA: true}`), y el resto —núcleo, hoja, azagaya,
> propulsor, arpón, aguja— es la escalera que se sube jugando. El choque estuvo
> escrito y sin resolver desde que EPOCAS.md §3 lo destapó.

**El arco no debería estar.** `TechTree.Tech.ARCO` está en el árbol y es el
peldaño que más sube la caza, pero el arco es Mesolítico. O se quita, o se marca
explícitamente como el salto que abre la época siguiente. Sigue sin decidirse.

---

## 2. Qué significa «investigar» en esta época

No es descubrir lo básico: es **afinarlo**. La progresión de la primera época es
de rendimiento, no de repertorio:

- más filo por kilo de cuarcita,
- menos jornadas por presa abatida,
- menos pérdida de alimento almacenado,
- más alcance de expedición,
- más gente en el mismo abrigo.

Y el mecanismo ya está construido: **se mejora haciendo** (saber tácito) y **se
fija externalizando** (arte parietal, permanente). No hay árbol de investigación
con botones. Falta la otra mitad: que el saber tácito **decaiga** con el relevo
generacional — hoy `TechTree.known` sólo sube.

---

## 3. El bucle: el año

La unidad de juego es el **año**, no el tick. Y el año cantábrico del
Magdaleniense tiene una forma muy marcada:

| Estación | Qué ocurre | Decisión |
|---|---|---|
| **Primavera** | Sube el salmón por los ríos | ¿Se baja al río o se sigue en el abrigo? |
| **Verano** | Cabra y rebeco en roquedo; recolección | Expediciones lejos: materia prima, contacto |
| **Otoño** | **Berrea del ciervo.** La mejor caza del año | Todo el esfuerzo aquí. Es cuando se decide el invierno |
| **Invierno** | Ocupación del abrigo, consumo de reservas | Si el otoño falló, marisqueo y hambre |

**La tensión central de la época: el otoño decide si sobrevives al invierno**, y
el marisqueo es la red de seguridad —fiable, de bajo rendimiento, y te obliga a
estar en la costa—. Es lo que documentan los yacimientos: el ciervo domina, la
cabra aparece en roquedo, y el molusco es recurso de temporada mala.

**Y esto es lo que todavía no se cumple del todo**: la recolección produce el
doble de lo que la banda puede comer y guardar, así que el otoño no se distingue
lo bastante. Medido y explicado en [ESTADO.md](ESTADO.md) §2; lo que falta para
arreglarlo, en [ROADMAP.md](ROADMAP.md).

---

## 4. Necesidades y recursos

**Necesidades del grupo:** `Alimento` · `Calor` (leña) · `Abrigo` (plazas de
cueva) · `Materia prima` · `Vestido` (piel curtida).

De ésas, **plazas de cueva y vestido no existen todavía** como necesidad; las
otras tres sí. Ver `ROADMAP.md`.

| Recurso | Sale de | Notas |
|---|---|---|
| Ciervo, caballo | valle y bosque | La caza mayor, base de todo |
| Cabra, rebeco | `prominence` alta, pendiente | Poco rendimiento, zonas malas |
| Salmón | `water_km` bajo | Estacional, primavera |
| Molusco | `coast_km` bajo | Todo el año, bajo rendimiento |
| **Cuarcita** | cauces (`river_mask`) | Cantos rodados. **La materia prima real de Cantabria** |
| **Sílex** | **no existe aquí** | Importado. Obliga al intercambio desde la primera época |
| Ocre (hematites) | afloramientos | Pigmento — y el mismo mineral que 30 000 años después se funde en hierro |
| Leña, madera | bosque | Cuello de botella del fuego |
| Asta, hueso, piel | subproducto de la caza | Nada se tira |

Que el sílex bueno no exista en Cantabria no es un obstáculo: **es la mecánica
de comercio, servida por la geología real**. Está a medio camino — el material
existe (`Materia.Kind.SILEX`), el intercambio no.

El catálogo real vivo es `Materia.CATALOGUE`, con su peso y su volumen; la
abundancia repartida por el territorio, `ResourceField` y `ResourceMapper`.

---

## 5. El enclave inicial

No se da a elegir sobre el mapa, y por dos razones: el jugador todavía no sabe
leer los atributos, y explorar un mapa que aún no conoce no es una decisión, es
una lotería. **La primera decisión real llega con la primera expedición.**

Está resuelto y fijado en `GameState.HOME_LAT/LON`: **Cueva los Pendios**, valle
del Nansa. Elegido a propósito por anodino —agua a 300 m con cantos de cuarcita,
ladera suave, nueve cavidades, y el mar a 12,8 km, lo bastante lejos para que la
costa sea una expedición de verdad—. Tiene tres yacimientos con entrada
enciclopédica a menos de 5 km, así que la exploración temprana paga.

> **El problema de las torcas, resuelto.** Los emplazamientos ocupables del
> Paleolítico estaban dominados por «Torca» y «Sima» —pozos verticales de
> catálogo espeleológico, no abrigos habitables—. Hoy `Site.Feature` distingue
> `SIMA` de `ABRIGO` y sólo el segundo es habitable; una torca sigue valiendo
> como señal de karst, que es donde hay más cuevas sin descubrir.

---

## 6. Exploración

- Al empezar se ve **el propio emplazamiento y poco más**.
- Las expediciones cuestan jornadas y víveres.
- Revelan emplazamientos, recursos y otros grupos.
- El alcance no se limita con un radio: lo limita **la comida que se puede
  llevar encima**, y de eso decide `Despensa._provision`. Los topes de distancia
  se quitaron a propósito.

Encaja con el registro: los grupos cantábricos tenían movilidad logística
estacional, no vagaban al azar.

**Dentro del valle esto funciona** (`Reconocimiento`, `Exploration`,
`BandKnowledge`, `Parajes`). **Fuera no existe**: el mapa regional enseña los
862 emplazamientos desde el minuto uno. Es la FASE A1 del ROADMAP, y es
infraestructura que sirve igual a las diez épocas siguientes — ver §9.

---

## 7. Desarrollos tecnológicos

Ya están en `TechTree.CATALOGUE` y `TechTree.BRANCHES`, con jornadas y coste en
material medidos, no inventados aquí. Resumen por oficio (el oficio sale de la
rama, `TechTree.job_of`):

| Oficio | Técnicas, en orden | Jornadas acumuladas hasta el final |
|---|---|---|
| `MANUFACTURA` | Lasca → Núcleo (45) → Hoja (110) → Aguja (190) | 345 |
| `CAZA` | Lazo (35) → Cepo (110) → Red de aves (190) → Foso (330) → Azagaya (140) → Ojeo (260) → Propulsor (420) → Arco (700) | hasta 2185 |
| `RIBERA` | Pesquera (60) → Nasa (180) → Anzuelo (320) → Red (560) → Arpón (850) | hasta 1970 |
| `EXPLORACION` | Pasarela (70) → Piragua (150, pide `Kind.HOGAR`) | 220 |
| `HOGAR` | Arte (200, pide `Kind.HOGAR`) | 200 |

**El nudo de esta época, y está medido:** `AZAGAYA` cuelga de `HOJA`, que se
practica en materia prima. Una banda con uno o dos en el taller **no llega a la
caza mayor en un año de partida**, así que los cazadores viven de trampas. No es
calibración, es una cadena de prerrequisitos. Ver [ESTADO.md](ESTADO.md) §2.

**Lo que falta de instalación, no de técnica:** `CampProjects.Kind` tiene
`HOGAR`, `SECADERO`, `LAVADERO` y `PARAVIENTO`. Es la lista correcta para esta
época —el hogar abierto es el techo térmico de todo el Paleolítico— y **no debe
crecer hasta el Neolítico**. La única que falta es la lámpara de grasa (§8).

---

## 8. Hitos

Usando el formato de `Hito` de [SISTEMAS.md](SISTEMAS.md) §2:

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| Núcleo preparado | interno | `TechTree.has(Tech.NUCLEO)` | — |
| Talla laminar | interno | `TechTree.has(Tech.HOJA)` | — |
| Azagaya y propulsor | interno | `TechTree.has(Tech.PROPULSOR)` | — |
| Aguja con ojo | interno | `TechTree.has(Tech.AGUJA)` | — |
| Lámpara de grasa | interno | obra nueva de `CampProjects` (no existe hoy) | — |
| El arpón de asta | interno | `TechTree.has(Tech.ARPON)` | — |
| El relato junto al fuego | interno | **ya implementado**, `Tale.gd` | — |
| El primer trazo en la pared | interno | `TechTree.has(Tech.ARTE)` y primera obra pintada | `Feature.OTRO` (no hay `Feature` de arte parietal; ver §9) |
| La sepultura | interno | pide un `Inhabitant` fallecido y una decisión de gasto de trabajo en el entierro | — |
| La concha de lejos | interno | primer intercambio recibido (SISTEMAS.md §5), aún sin construir | — |
| La agregación estacional | interno | exige más de un asentamiento: fuera de alcance | — |
| El santuario | interno | arte parietal en un sitio que no es el de habitación | — |
| Máximo Glacial | interno, consecuencia de mapa | ya calculado: `RegionEras` + `Site.coast_km_by_era` | cambia disponibilidad, no `Feature` |
| **El bosque cierra el valle** | **cierre, se sufre** | cuenta de años/hitos desde el inicio, ver SISTEMAS.md §6 | retirada de fauna de manada del `WildlifeHerds` local |

---

## 9. Oficios

Sin cambios: `Profession.Job` en su forma actual —`CAZA`, `RIBERA`,
`RECOLECCION`, `MANUFACTURA`, `EXPLORACION`, `HOGAR`, `OCIOSO`— es exactamente
el reparto de esta época. **Es la única ficha de las once donde esta sección no
pide nada nuevo.**

---

## 10. Lo que falta de esta época

No es «contenido de más adelante»: son piezas de esta misma época que siguen sin
construirse. El estado medido de cada una está en [ESTADO.md](ESTADO.md) y el
orden en que se atacan, en [ROADMAP.md](ROADMAP.md).

1. **Exploración regional** (§6). El objetivo es que el mapa de Cantabria deje de
   mostrarlo todo desde el minuto uno.
2. **Saber tácito que decae** (§2), la otra mitad de la FASE C1.
3. **Vestido** como necesidad de invierno. Ya existen `PIEL`, `PELETERIA`,
   `AGUJA` y la técnica de coser: falta la necesidad que las justifique.
4. **Plazas de abrigo**: cuánta gente cabe en la cueva. Crecer más obliga a
   levantar paravientos o a partir la banda.
5. **Sílex por intercambio** (§4).
6. **`Feature` de arte parietal.** `Site.Feature` no distingue «cueva con arte»
   de «abrigo cualquiera», así que no hay dónde anotar que un sitio se volvió
   santuario.
7. **La sepultura** y **la agregación estacional**: la primera pide una noción de
   «fallecido con ajuar»; la segunda, más de una banda simulada a la vez, que
   está fuera de alcance a propósito.

---

## 11. La trampa

**Alargarla porque es la que está hecha.** Es la época mejor construida del
proyecto, y la exploración regional del punto 1 **no es una excusa para quedarse
más tiempo aquí**: es infraestructura que sirve exactamente igual a las diez
épocas siguientes. Esta ficha la trata como la pieza que abre paso, no como
contenido nuevo del Paleolítico.

---

## 12. Fidelidad

`ATESTIGUADO` con margen: Altamira, El Castillo (la secuencia de ocupación más
larga de Europa y el arte parietal datado más antiguo del continente),
La Pasiega, El Pendo, Covalejos, El Mirón —con el enterramiento de la Dama
Roja— y La Garma, con suelo de ocupación sellado. El propulsor, los arpones de
asta, las agujas con ojo y el trabajo de piel están documentados en el
Magdaleniense cantábrico.

El **ciclo estacional de decisiones** del §3 es `INFERIDO`: la estacionalidad de
salmón y berrea es real y los yacimientos muestran ocupación estacional, pero el
calendario concreto de juego es una construcción.
