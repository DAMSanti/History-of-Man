# Vertical slice — Paleolítico superior

Diseño de la primera época, para saber qué hace falta construir antes de
seguir. Cantabria, Magdaleniense (~17.000–12.000 a.C.).

Ver [ROADMAP.md](ROADMAP.md) para el plan general y [SPECS.md](SPECS.md) para
el contrato técnico.

---

## 1. No se empieza de cero

Un grupo del Paleolítico superior **no es primitivo**. Lleva cientos de miles
de años de acumulación técnica y sabe perfectamente cómo cubrir sus
necesidades. Empezar la partida «descubriendo el fuego» es un tópico de género,
y además es falso.

### Lo que el grupo ya sabe hacer

| | |
|---|---|
| **Fuego** | Producirlo y mantenerlo |
| **Talla lítica** | Cuarcita local; láminas, raspadores, buriles |
| **Enmangue** | Astiles con resina y tendón |
| **Propulsor** | Atlatl — arma característica del Magdaleniense |
| **Asta y hueso** | Azagayas, arpones, agujas con ojo |
| **Piel** | Raspado y curtido; ropa cosida |
| **Cordelería** | Cuerda, cestería, trampas |
| **Conservación** | Secado y ahumado |
| **Abrigo** | Ocupar cueva, levantar paravientos |
| **Ciclo anual** | Cuándo sube el salmón, cuándo es la berrea |

### Lo que NO sabe, y marca el techo de la época

Arco · cerámica · agricultura · ganadería · metal · rueda · molienda intensiva.

Ese techo es lo que define la época. No hay que escribirlo como lista de
bloqueos: sale solo de qué procesos existen y de la temperatura alcanzable
(un hogar abierto no pasa de ~700 °C).

---

## 2. Qué significa «investigar» entonces

No es descubrir lo básico, es **afinarlo**. La progresión de la primera época
es de rendimiento, no de repertorio:

- Más filo por kilo de cuarcita
- Menos jornadas por presa abatida
- Menos pérdida de alimento almacenado
- Más alcance de expedición
- Más gente en el mismo abrigo

Y el mecanismo ya está diseñado: **se mejora haciendo** (saber tácito, que
decae con el relevo generacional) y **se fija externalizando** (arte parietal,
permanente). No hay árbol de investigación con botones: hay cosas que haces
mucho y cosas que decides hacer permanentes.

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

**La tensión central de la época:** el otoño decide si sobrevives al invierno,
y el marisqueo es la red de seguridad — fiable pero de bajo rendimiento, y te
obliga a estar en la costa. Es lo que documentan los yacimientos: el ciervo
domina, la cabra aparece en zonas de roquedo, y el molusco es recurso de
temporada mala.

---

## 4. Necesidades y recursos

### Necesidades del grupo
`Alimento` · `Calor` (leña) · `Abrigo` (plazas de cueva) · `Materia prima` ·
`Vestido` (piel curtida)

### Recursos, y de qué atributo del mapa salen

| Recurso | Sale de | Notas |
|---|---|---|
| Ciervo, caballo | valle y bosque | La caza mayor, base de todo |
| Cabra, rebeco | `prominence` alta, pendiente | Poco rendimiento, zonas malas |
| Salmón | `water_km` bajo | Estacional, primavera |
| Molusco | `coast_km` bajo | Todo el año, bajo rendimiento |
| **Cuarcita** | cauces (`river_mask`) | Cantos rodados. **La materia prima real de Cantabria** |
| **Sílex** | **no existe aquí** | Importado. Obliga al intercambio desde la primera época |
| Ocre (hematites) | afloramientos | Pigmento — y el mismo mineral que 30.000 años después se funde en hierro |
| Leña, madera | bosque | Cuello de botella del fuego |
| Asta, hueso, piel | subproducto de la caza | Nada se tira |

Que el sílex bueno no exista en Cantabria no es un obstáculo: **es la mecánica
de comercio, servida por la geología real**. Y la cuarcita está donde dice la
acumulación de flujo D8 que ya está calculada.

---

## 5. El enclave inicial

De acuerdo en no dar a elegir sobre el mapa. Dos razones: el jugador todavía no
sabe leer los atributos, y explorar un mapa que aún no conoce no es una
decisión, es una lotería.

**Propuesta:** arrancar en **un abrigo fijo**, sin elección. La primera decisión
real llega con la primera expedición.

Criterios del sitio de arranque:
- Abrigo real (`has_shelter`), con cavidad de tamaño razonable
- Cauce a menos de 1 km — agua y cuarcita
- Ni costero ni de alta montaña: que la costa y el roquedo sean **descubrimientos**
- Modesto: los yacimientos célebres deben ser hallazgos, no el punto de partida

### Problema detectado

Los emplazamientos ocupables en el Paleolítico están dominados por nombres tipo
«Torca» y «Sima» —simas verticales de catálogo espeleológico, no abrigos
habitables— y **Altamira y El Castillo no aparecen**: al agrupar a 2 km, el
primario se elige por fidelidad y luego por puntuación, pero los atestiguados
tienen puntuación 0, así que gana uno arbitrario.

Hay que arreglarlo antes de elegir enclave inicial:
1. Preferir `yacimiento` sobre `cueva` al elegir el primario del grupo
2. Penalizar los nombres de sima o torca como sitio de habitación
3. Idealmente, cruzar con el inventario arqueológico del Gobierno de Cantabria

---

## 6. Exploración

- Al empezar se ve **el propio emplazamiento y poco más**
- Las expediciones cuestan jornadas y víveres, y tienen alcance limitado
- Revelan emplazamientos, recursos y otros grupos
- El alcance mejora con la técnica (conservación de alimento = más autonomía)

Encaja con el registro: los grupos cantábricos tenían movilidad logística
estacional, no vagaban al azar.

---

## 7. Qué hay que construir

En orden, y con criterio de aceptación.

1. **Banda y necesidades.** Población, consumo, estación. *Un año pasa y la
   población cambia según lo que se haya conseguido.*
2. **Recursos en el mapa local.** Sustituir hierro/carbón/piedra por los de la
   tabla de arriba, situados por atributos reales. *Se ve dónde hay cuarcita, y
   está en los cauces.*
3. **Tres procesos.** Talla, caza, marisqueo. Con `ProcessRecipe` de verdad:
   entradas, herramientas, jornadas, subproductos. *La cadena canto → pico →
   marisqueo → conchero funciona de principio a fin.*
4. **El conchero crece.** El residuo se acumula y modifica el terreno. *Es la
   prueba de que los subproductos son reales y no adorno.*
5. **Ciclo anual con estaciones** que cambian disponibilidad. *El otoño se
   siente distinto del invierno.*
6. **Expedición y descubrimiento.** *Encontrar el segundo emplazamiento se
   siente como un hallazgo.*
7. **Saber tácito que decae** y externalización que lo fija. *Perder una
   técnica por no haberla pintado duele.*

### Fuera de la slice

Comercio entre asentamientos · más de una banda · construcción de estructuras ·
todas las épocas posteriores · enciclopedia.

---

## 8. La vista detallada

Aparte de lo anterior, y necesario para que nada de esto se entienda en
pantalla:

- **Texturas por bioma real**, no las cuatro procedurales de ahora: pradera,
  bosque, roquedo, pedrera, arena, marisma
- **Delimitación visible de zonas** de recurso — dónde se puede mariscar, dónde
  hay cantos, qué alcanza una expedición
- **Vegetación por altitud y humedad**, con especies de la época: en el
  Magdaleniense esto era estepa fría con bosque de refugio en los valles, no
  el prado y el eucalipto de hoy
- **Bocas de cueva orientadas** contra la ladera, no medias esferas mirando
  arriba

---

## 9. Nota de fidelidad

La lista de conocimiento inicial es `ATESTIGUADO`: propulsor, arpones de asta,
agujas con ojo y trabajo de piel están documentados en el Magdaleniense
cantábrico. El **ciclo estacional** que propone este documento es `INFERIDO`:
la estacionalidad de salmón y berrea es real y los yacimientos muestran
ocupación estacional, pero el calendario concreto de decisiones es una
construcción de juego.
