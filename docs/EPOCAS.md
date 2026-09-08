# Las épocas y sus hitos

Doce épocas con cultura material documentada en Cantabria, del Paleolítico al
siglo XX, y **qué hito cierra cada una**. Es el contenido de la FASE D del
[ROADMAP.md](ROADMAP.md), que hasta hoy era una línea que decía «diez épocas»
sin decir cuáles.

Diez llegan a la Edad Moderna, que era el final previsto, y **dos más llevan la
partida hasta 1982**. Esas dos se decidieron después y con el coste sobre la
mesa: el §4 lo deja escrito en su propia ficha, porque el motor que hay hoy
—prioridades de trabajo, jornadas y calorías— no simula jornal ni capital.

Con el Paleolítico entero contando como **una**. La primera versión de
este documento lo partía en cuatro —Achelense, Musteriense, Paleolítico superior
inicial y Magdaleniense— y eso estaba mal: ninguna de esas fronteras es una
frontera de juego, y el §3 explica por qué, porque el argumento destapa una
contradicción que ya estaba en el repositorio. Las dos épocas que salen en su
lugar son el **Calcolítico**, separado del Bronce, y la **Edad Media partida en
dos**, alta y baja. El §2 justifica las dos fronteras con la misma regla con la
que se cayeron las otras.

---

## 1. La regla del reloj

**El tiempo avanza por hitos, no por calendario.** El Paleolítico es el 99,4 %
del intervalo real; si el tiempo de juego fuese proporcional, la partida entera
sería tallar cuarcita. El calendario sigue corriendo *dentro* de una época, para
estaciones y cosechas, pero **no** hace avanzar de época.

Un **hito** tiene esta forma:

- **Se dispara con algo que el grupo hizo**, no con una fecha ni con un botón de
  investigar. La condición se lee del estado del juego.
- **No se puede perder.** Un saber tácito decae con el relevo generacional
  (FASE C); un hito, no. Por eso hay pocos.
- **Deja algo detrás en el mapa.** Un conchero, un dolmen, un castro, una
  ferrería. El `Site.Feature` construido es la prueba de que el hito ocurrió, y
  es lo que hace que una partida larga se lea como un paisaje.

Dos clases:

| | |
|---|---|
| **Hito interno** | Abre procesos, materiales o edificios dentro de la época |
| **Hito de cierre** | El único que pasa a la época siguiente. Hay uno por época |

**Lo que NO es un hito.** Acumular jornadas (eso es el árbol de técnicas de
`TechTree`), llegar a una población, ni sobrevivir N años. Los tres se llenan
solos y ninguno obliga a decidir nada.

**Guardarraíl.** El hito de cierre nunca es «tener X unidades de Y». Es una
**capacidad demostrada que ya no se puede deshacer**: una vez hecha, el mundo
anterior no vuelve. Almacenar no es saber.

**Y cuatro de los doce no los hace el jugador: le ocurren.** El bosque que cierra
el valle, la legión en el collado, el Estado que se va y el frente del norte en
1937. Son los cuatro momentos en que Cantabria deja de decidir su propia
historia, y el juego no debe ofrecer ganarlos.

---

## 2. Las doce, de un vistazo

`Era` es el valor de `Site.Era` con el que se juega esa época: define qué
emplazamientos son ocupables (`Site.is_usable_in`) y qué piel lleva la interfaz
(`UISkin.vestir`, ver [INTERFAZ.md](INTERFAZ.md)). Doce épocas sobre cinco
valores, y no hay que tocar el `enum`.

| # | Época | Intervalo | `Site.Era` | Mar | Dónde se vive | Hito de cierre |
|---|---|---|---|---|---|---|
| 1 | **Paleolítico** | hasta ~11,7 ka | PALEOLITICO | −120 → −60 m | Abrigo con río y roquedo cerca | El bosque cierra el valle |
| 2 | **Mesolítico** | ~11,7–5,5 ka | MESOLITICO | −50 → −5 m | Conchero al aire libre, costa | El primer grano sembrado |
| 3 | **Neolítico** | ~5500–3000 a.C. | NEOLITICO | ~0 | Cabaña en ladera suave, puerto de montaña | El dolmen levantado |
| 4 | **Calcolítico** | ~3000–1800 a.C. | METALES | 0 | Aldea con cueva sepulcral cerca | La aleación |
| 5 | **Edad del Bronce** | ~1800–800 a.C. | METALES | 0 | Poblado en alto | El ocre da metal |
| 6 | **Edad del Hierro** | ~800–19 a.C. | METALES | 0 | Castro amurallado | La legión en el collado |
| 7 | **Roma** | 19 a.C.–s. V | HISTORICA | 0 | Ciudad, villa, puerto, mina | El Estado se va |
| 8 | **Alta Edad Media** | s. V–XI | HISTORICA | 0 | Valle con concejo, monasterio | La escritura sale del monasterio |
| 9 | **Baja Edad Media** | s. XI–XV | HISTORICA | 0 | Villa con fuero y puerto | El barquín lo mueve el agua |
| 10 | **Edad Moderna** | s. XVI–XVIII | HISTORICA | 0 | Villa portuaria, casona, Real Fábrica | La tierra cambia de dueño |
| 11 | **El vapor** | c. 1830–1900 | HISTORICA | 0 | Barrio obrero, mina, cuenca del ferrocarril | El capital de fuera |
| 12 | **El siglo corto** | 1900–1982 | HISTORICA | 0 | Ciudad, polígono, pueblo que se vacía | (final de la partida) |

### Por qué estas dos fronteras y no otras

La regla es la del §3: una época nueva tiene que cambiar **al menos una** de
cuatro cosas —dónde se puede vivir, de qué se come, qué se puede fabricar, o
quién decide—. Las dos nuevas la cumplen:

| Frontera | Qué cambia |
|---|---|
| **Calcolítico ≠ Bronce** | *Qué se puede fabricar*: la cubeta con fuelle (~1100 °C) funde cobre, y no hace bronce. El bronce necesita estaño de fuera y un horno mejor (~1200 °C). Son dos peldaños térmicos y dos economías: una de piedra verde del monte, otra de red comercial a mil kilómetros |
| **Alta ≠ Baja Edad Media** | Las tres últimas a la vez: se pasa del valle con monasterio a la villa con fuero y puerto —`Site.Kind.COSTERO` cambia de valor de golpe—, de la ferrería de monte a la hidráulica (~1350 °C), y **la unidad deja de ser el valle y pasa a ser la villa**, que tiene ley propia y vecindad escrita |

Las dos últimas, las que llevan del XVIII al XX, pasan por la tercera y la
cuarta a la vez, y no por poco:

| Frontera | Qué cambia |
|---|---|
| **Moderna ≠ El vapor** | *Qué se fabrica*: el coque libera al alto horno del carbón vegetal, o sea del bosque, que había sido el techo de la industria desde el Neolítico; y la máquina de vapor desengancha la energía del río y de la estación. *Quién decide*: aparece el jornal, y con él un trabajo que se vende por horas |
| **El vapor ≠ El siglo corto** | *Quién decide*, otra vez y más fuerte: la decisión de qué se produce en el valle se toma fuera del valle, en un consejo de administración que no vive aquí. El resto —electricidad, hormigón, química— viene detrás |

**La cuarta regla, la social, también repasa las fronteras que ya estaban**, y
dos salen reforzadas: Hierro → Roma cambia la unidad del castro al Estado, y
Neolítico → Calcolítico es la única que se sostiene *sin* ella (va por la
tercera). Ninguna de las doce pasa sólo por la cuarta, y eso está bien: un
cambio social que no deja huella material tampoco deja `Feature` en el mapa.

Y las que descarté, por si prefieres cambiar el reparto:

- **Partir la Edad Moderna** (XVI–XVII / XVIII). Con la cuarta regla **es ahora
  la mejor de las descartadas**, por delante del Calcolítico: el jornal, la
  fábrica de cientos de personas y la provincia de 1778 sí cambian quién decide.
  Falla la tercera —el alto horno ya está en 1622—, así que entra sólo por lo
  social. **Si quieres cambiar una por otra, funde el Calcolítico en el Bronce y
  parte la Moderna en dos**: sigue habiendo doce y el reparto queda mejor
  documentado, porque el XVIII cántabro está escrito y el Calcolítico no.
- **Partir el Hierro** (primera / segunda Edad del Hierro). El registro cántabro
  de la primera es demasiado delgado para sostener una época jugable.
- **Partir el Mesolítico** (Aziliense / Asturiense). Falla las cuatro: mismo
  sitio, misma comida, mismo techo térmico y la misma unidad. Es la peor
  candidata, y con la regla social sigue siéndolo.

Las cotas del mar son **INFERIDO**: salen de la curva eustática global, no de un
estudio de la plataforma cantábrica. Ya son datos vivos —`RegionEras` hornea una
máscara por cota y `Site.coast_km_by_era` guarda la distancia a la costa de cada
época—, así que un sitio costero de hoy queda a trece kilómetros del mar en el
Último Máximo Glacial sin que haya que escribir nada a mano.

---

## 3. Por qué el Paleolítico es una sola época

Merecía discusión, así que aquí está el argumento entero y no la conclusión.

### Lo que tendría que cumplir para ser dos

Una frontera de época tiene que cambiar **al menos una** de estas cuatro cosas:

1. **Dónde se puede vivir** — o sea `Site.is_usable_in`, el valor de `Site.Era`.
2. **De qué se come** — la base de subsistencia, no su rendimiento.
3. **Qué se puede fabricar** — un peldaño de la escalera térmica o un material
   nuevo.
4. **Quién decide** — un cambio social lo bastante gordo como para justificar
   por sí solo una época.

La cuarta necesita una definición estrecha o se traga las otras tres, porque
casi todo es «social» si se mira de lejos. Vale cuando cambia **la unidad**: a
quién se pertenece, quién manda y quién posee. La banda, el poblado, el castro,
el Estado, el valle, la villa. Que haya más desigualdad, más gente o más
ceremonia dentro de la misma unidad **no cuenta**: eso es la misma sociedad
haciendo más de lo mismo.

El Magdaleniense **no cambia ninguna de las cuatro** respecto del Solutrense. Se
vive en cueva, se come ciervo y salmón, el techo sigue siendo el hogar abierto a
~700 °C, y la unidad sigue siendo la banda —la agregación estacional y el
santuario son cosas que la banda hace, no otra manera de organizarse—. Lo que
cambia es el **rendimiento**: más filo por kilo, menos jornadas por presa, mejor
conservación. Y eso ya tiene su sistema, que es `TechTree` —se mejora haciendo—
más la externalización de la FASE C. Está dicho literalmente en
[SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) §2: «la progresión de la primera
época es de rendimiento, no de repertorio».

Achelense y Musteriense fallan la prueba por el otro lado: sí cambian el
repertorio, pero **no se juegan**. La partida no empieza ahí, así que ponerlos
como épocas era reservar sitio para contenido que nadie va a jugar.

### El único argumento serio a favor de partirlo, y por qué tampoco basta

Dentro del Paleolítico ocurre **el cambio geográfico más brutal de la partida**:
el mar baja a −120 m en el Último Máximo Glacial y luego sube sesenta metros. La
costa se va a más de diez kilómetros y vuelve. Eso es más transformación de mapa
que la que hay entre el Bronce y el Hierro juntos.

Pero el nivel del mar **ya es un parámetro continuo** y no depende de `Site.Era`:
`RegionEras` hornea una máscara por cota y `SiteSet.available_in` ya recibe
`sea_level_m` aparte de la era. O sea que la geografía puede cambiar dentro de
una época sin que haya que declarar una época nueva. Se resuelve como **hito
interno con consecuencia de mapa**, que es más barato y se lee mejor.

### Dónde empieza la partida, que es la pregunta de verdad

Si el Paleolítico es una sola época, hay que decir en qué punto de sus doscientos
mil años arranca el jugador. Y la respuesta ya estaba escrita: **en el
Magdaleniense**. `SLICE_PALEOLITICO` §1 lo dice sin rodeos —«un grupo del
Paleolítico superior no es primitivo», «empezar la partida descubriendo el fuego
es un tópico de género, y además es falso»— y el enclave inicial, el año, la
berrea y el remonte del salmón están diseñados sobre eso.

Así que el Magdaleniense no es otra época: **es el punto de partida de la
primera**. Achelense y Musteriense no son contenido jugable sino la mochila con
la que llega la banda, y su sitio es la enciclopedia de la FASE E4.

### La contradicción que esto destapa, y que hay que resolver

Al juntarlo todo en una época salta un choque que llevaba tiempo en el
repositorio, entre dos documentos que se leen por separado:

| | Dice |
|---|---|
| `SLICE_PALEOLITICO.md` §1 | La banda **ya sabe** talla laminar, propulsor, azagaya, arpón y aguja |
| `TechTree.gd` | Esas cinco **se aprenden practicando**: el arpón, 850 jornadas de pesca |

Las dos no pueden ser verdad. **La recomendación es que gane `TechTree`**, por
tres razones: está implementado y medido, es el único sistema que le da al
Paleolítico progresión interna ahora que las cuatro fases se juntan en una, y
850 jornadas de pesca no son «descubrir el arpón» sino llegar a hacerlo bien,
que es exactamente la lectura correcta.

Lo que hay que corregir entonces es la lista de `SLICE_PALEOLITICO` §1: la banda
trae **fuego, talla sobre lasca, enmangue, curtido, cordelería, conservación y
el ciclo anual**, y el resto —núcleo, hoja, azagaya, propulsor, arpón— es la
escalera que se sube jugando. Que es, literalmente, la secuencia Musteriense →
Paleolítico superior → Magdaleniense convertida en juego en vez de en menú de
épocas.

**Esto no es cosmético y no se hace en este documento**: tocar §1 de la slice es
un cambio de diseño de la época que está construida, y va aparte.

---

## 4. Época por época

Cada ficha trae lo mismo: el suelo real cántabro (**ATESTIGUADO**, con
yacimiento), los hitos técnicos, los sociales, el de cierre, y **la trampa** —el
error de diseño que esa época invita a cometer—.

---

### 1. Paleolítico — el valle helado

**Se empieza aquí, y se empieza en el Magdaleniense.** Lo anterior es mochila:
la banda llega con doscientos mil años de acumulación encima.

**El registro cántabro.** Es el mejor del mundo y da de sobra: el techo de
polícromos de Altamira, El Castillo (con la secuencia de ocupación más larga de
Europa y un disco rojo datado en torno a 40.800 años, el arte parietal más
antiguo datado del continente), La Pasiega, Las Monedas, Las Chimeneas, El
Pendo, Hornos de la Peña, Covalejos, Cueva Morín, Chufín, El Juyo, Rascaño, El
Mirón —con el enterramiento de la Dama Roja— y La Garma, que conserva un suelo
de ocupación sellado. **ATESTIGUADO**, y con margen.

| Hitos técnicos | |
|---|---|
| **Núcleo preparado** | `Tech.NUCLEO`: la lasca sale con la forma pensada. El salto musteriense |
| **Talla laminar** | `Tech.HOJA`: metros de filo por kilo de sílex, en un valle que no tiene sílex |
| **Azagaya y propulsor** | `Tech.AZAGAYA`, `Tech.PROPULSOR`: matar a distancia sin perder gente |
| **Aguja con ojo** | `Tech.AGUJA`: ropa cosida, y con ella el invierno se puede ocupar |
| **Lámpara de grasa** | Arenisca vaciada y mecha: **el fondo de la cueva es visitable** |
| **El arpón de asta** | `Tech.ARPON`: el remonte del salmón deja de ser suerte y pasa a ser cosecha |
| **El perro** | Ya implementado (`ElLobo.gd`). Empieza en el montón de basura, no en el cariño |
| **La bellota lavada** | Ya implementado: el tanino sale en el arroyo y la bellota se vuelve harina |
| **El secadero y la pesquera** | La despensa de invierno, y el cauce cerrado con piedra |

| Hitos sociales | |
|---|---|
| **El relato junto al fuego** | Ya implementado (`Tale.gd`): lo que sabe uno pasa a saberlo el grupo |
| **El primer trazo en la pared** | Una mano en negativo, un disco soplado: el saber sale de la cabeza y se fija |
| **La sepultura** | Un muerto con ajuar. El grupo gasta trabajo en quien ya no produce |
| **La concha de lejos** | Materia que no es de aquí: hay red de intercambio, y el sílex la obliga |
| **La agregación estacional** | Varias bandas en el mismo sitio unas semanas al año |
| **El santuario** | Arte parietal donde no se va a vivir: el territorio se marca |

**Hito interno con consecuencia de mapa: el Máximo Glacial.** El mar baja a
−120 m, la plataforma emerge y aparecen decenas de emplazamientos que hoy están
bajo el agua; la costa se va a más de diez kilómetros y el marisqueo —la red de
seguridad del invierno— deja de estar a mano. Después el mar sube y esos sitios
se ahogan, con el grupo dentro si no se ha movido. No hace falta código nuevo:
`RegionEras` y `Site.coast_km_by_era` ya lo calculan.

**Cierre: el bosque cierra el valle.** El primero de los tres que le ocurren al
jugador. El hielo se retira, el robledal sube y **el reno y el caballo se van del
valle**: la caza mayor de manada deja de existir. El grupo que dependía de la
berrea tiene que aprender a comer de la costa.

**La trampa.** Alargarla porque es la que está hecha. Es la época mejor
construida y la tentación será quedarse. El criterio del ROADMAP sigue mandando:
si la cadena corta no divierte, el contenido nuevo no lo arregla.

---

### 2. Mesolítico — la costa

Aziliense y Asturiense. El mar sube deprisa, la plataforma se hunde y **la costa
se acerca cada década**: sitios de la época anterior desaparecen bajo el agua
dentro de la misma partida.

**El registro cántabro.** Arpones planos azilienses y cantos pintados en El Valle
y El Piélago; concheros y picos de cuarcita del Asturiense en la costa
occidental, y ocupaciones con enterramiento en conchero en las cuevas de El Perro
y La Fragua (Santoña). **ATESTIGUADO**.

| Hitos técnicos | |
|---|---|
| **El pico asturiense** | Canto de cuarcita apuntado para arrancar lapa. Es la cadena de la FASE B3 |
| **Microlitos** | Filos pequeños montados en serie sobre asta o madera |
| **El arco** | `Tech.ARCO`: bosque cerrado, pieza suelta, tiro corto |
| **La piragua** | `Tech.PIRAGUA`: el estuario deja de ser una pared |
| **El conchero** | Subproducto acumulado que acaba siendo el sitio mismo |

| Hitos sociales | |
|---|---|
| **El territorio pequeño** | Se deja de recorrer cien kilómetros: se explota una ría entera |
| **El muerto en la basura** | Se entierra en el conchero, dentro del campamento |
| **El vecino** | Con territorios pequeños hay linde, y con linde hay que tratar |

**Cierre: el primer grano sembrado.** Una sola siembra, sin excedente ni
graneros. Basta con que alguien haya guardado semilla en vez de comérsela: es la
decisión de gastar comida de hoy en comida de dentro de un año.

**La trampa.** Contarlo como decadencia —«ya no hay arte, ya no hay grandes
cacerías»—. El Asturiense es un ajuste eficientísimo a un ecosistema nuevo. Si el
juego lo pinta como caída, está contando mal lo que pasó.

---

### 3. Neolítico — la primera arquitectura

**El registro cántabro.** Cerámica y cabaña ganadera en cuevas como Los Gitanos
(Castro Urdiales) y en los niveles neolíticos de El Mirón; megalitismo en el Alto
Asón, en Peña Oviedo (Camaleño) y en los pasos de montaña. En Cantabria el
Neolítico es **tardío y de registro pobre**: llega tarde y convive mucho tiempo
con la caza. **ATESTIGUADO** el megalitismo, **INFERIDO** el detalle del
calendario agrícola. `Site.Feature.MEGALITO` ya lo contempla.

| Hitos técnicos | |
|---|---|
| **Horno de fosa** | ~900 °C. Primer peldaño propio de la escalera térmica: **cerámica** |
| **El recipiente que no se pudre** | La olla cambia la dieta más que el arado: se cuece |
| **El hacha pulimentada** | Se puede talar. Y talando se hace el pasto |
| **Ovicaprinos** | Leche y lana: un animal que se come varias veces |
| **El molino de vaivén** | El grano se muele. Y muele quien no sale del poblado |

| Hitos sociales | |
|---|---|
| **La propiedad del rebaño** | Lo primero que se puede acumular. Con ello, lo primero que se hereda |
| **La tumba colectiva** | El dolmen es un mojón: dice que esta tierra tiene dueños desde hace tiempo |
| **El pastoreo de altura** | Verano arriba, invierno abajo. La trashumancia corta que aún se ve |
| **La aldea** | Se vive donde está el campo, no donde está la cueva |

**Cierre: el dolmen levantado.** Mover ortostatos exige más brazos de los que
tiene una familia: **el hito no es la piedra, es haber podido convocar a la
gente**. Y deja un `Feature.MEGALITO` en el mapa regional para el resto de la
partida.

**La trampa.** La «revolución neolítica» en una temporada. En Cantabria fue
lentísima y mixta: se sigue cazando y mariscando durante siglos. La época debe
permitir jugar **sin** apostarlo todo al campo, y castigar sólo si el invierno lo
pide.

---

### 4. Calcolítico — la piedra que era metal

La época más corta y la de registro más flojo de las doce, y hay que jugarla
como tal: pocas decisiones, una sola idea.

**El registro cántabro.** Sigue el megalitismo, siguen las cuevas sepulcrales, y
aparecen las primeras piezas de cobre y algún vaso campaniforme. Los ídolos
grabados de Sejos (Campoo), con armas representadas, andan en esta frontera.
**ATESTIGUADO** el megalitismo y las cuevas; **PLAUSIBLE** casi todo lo demás.
Aquí la etiqueta de evidencia de la FASE E4 no es un adorno: es la mitad de la
ficha.

| Hitos técnicos | |
|---|---|
| **Cubeta con fuelle** | ~1100 °C: el cobre funde a 1085. Un peldaño térmico entero para un solo metal |
| **La piedra verde** | La malaquita del monte no es piedra: es mineral. Aprender a **verlo** es el hito |
| **El recocido** | Martillar cobre en frío lo agrieta. Hay que devolverlo al fuego entre golpe y golpe |
| **El punzón y la lezna** | Lo primero que se hace de metal no es un arma: es una herramienta de coser |
| **El campaniforme** | Un recipiente que se enseña, no que se usa |

| Hitos sociales | |
|---|---|
| **El buscador** | Alguien cuyo oficio es leer el color del monte. El primer prospector |
| **El objeto que no sirve** | Un puñal de cobre corta peor que uno de sílex, y aun así se quiere. Prestigio puro |
| **El secreto del oficio** | El primer saber que se guarda a propósito en vez de contarse |

**Cierre: la aleación.** Estaño en el cobre. Es el hito que más lejos lleva al
jugador sin moverlo del valle: **el estaño no está en Cantabria**, así que la
única manera de cerrar esta época es haber montado una ruta de intercambio que
llegue a donde sí lo hay.

**La trampa.** Inflarla. Es una época de transición con registro pobre y la
tentación de rellenarla con contenido inventado es la misma que tenía el
Achelense. Si hay que recortar el juego, **esta es la primera que se funde con
la siguiente**, y el documento se queda en nueve épocas sin perder nada
importante.

---

### 5. Edad del Bronce — el linaje y la red

**El registro cántabro.** Hachas de talón, cuevas sepulcrales, túmulos, arte
esquemático y depósitos en Cofresnedo (Matienzo). **ATESTIGUADO** el material;
**PLAUSIBLE** el detalle de la organización social.

| Hitos técnicos | |
|---|---|
| **Horno mejorado** | ~1200 °C: bronce de verdad, y no cobre con suerte |
| **El molde bivalvo** | La forma deja de tallarse: se repite. Hacha de talón en serie |
| **El telar de pesas** | La lana se convierte en tela sin salir del poblado |
| **La rueda de alfarero** | Cerámica en cantidad y a medida |
| **El depósito escondido** | Metal enterrado a propósito: la primera vez que se guarda riqueza fuera de casa |

| Hitos sociales | |
|---|---|
| **El artesano** | Alguien que no produce comida y aun así come: el primer oficio puro |
| **La ruta del estaño** | Depender de material lejano ata el valle a una red que no controla |
| **El ajuar desigual** | Dos tumbas del mismo sitio con contenidos incomparables |
| **El poblado en alto** | Se elige sitio por defendible. `Site.Kind.ALTURA` sube de valor |

**Cierre: el ocre da metal.** Que la piedra roja con la que se pinta desde hace
treinta mil años —el mismo `Materia.Kind.OCRE` que se recoge en la primera
época— sea mineral de hierro. Es el mejor hito del juego y no hay que
inventarlo: está escrito en `SLICE_PALEOLITICO` §4, en la fila del ocre, «el
mismo mineral que 30.000 años después se funde en hierro». Fundirlo bien es ya
la época siguiente; el hito es **verlo**.

**La trampa.** Que el metal sustituya a la piedra al día siguiente. La piedra
pulimentada sigue siendo la inmensa mayoría de las herramientas durante siglos:
el bronce es caro, escaso y en buena medida **prestigio**. Si el juego lo reparte
como material corriente, se ha saltado lo que el bronce significaba.

---

### 6. Edad del Hierro — los cántabros

**El registro cántabro.** Castros de Las Rabas (Celada Marlantes), Monte Ornedo,
La Espina del Gallego y Cildá; las estelas discoideas gigantes de Barros y Zurita
—adscripción discutida, **PLAUSIBLE**—; y las fuentes grecolatinas, que traen los
nombres de los pueblos y muy poco más. `Site.Feature.CASTRO` ya existe.

| Hitos técnicos | |
|---|---|
| **Cuba baja** | ~1250 °C: hierro **en estado sólido**. Sale esponja, no colada |
| **La forja** | La esponja se limpia a martillo. Media jornada de golpes por kilo |
| **El mineral de aquí** | Por primera vez el metal no viene de fuera. Se acabó depender de la ruta |
| **El molino circular** | Rotatorio: multiplica la harina por hora de trabajo |
| **La muralla y el foso** | La construcción defensiva como obra colectiva del año |
| **La salazón** | Sal y pescado: comida que viaja y que se vende |

| Hitos sociales | |
|---|---|
| **La comunidad castreña** | Se pertenece al castro. La unidad deja de ser la familia |
| **El guerrero** | Un oficio cuyo trabajo es la violencia, mantenido por los demás |
| **El pacto entre castros** | Hospitalidad y alianza: la política antes del Estado |
| **La frontera** | Hay un afuera, y el afuera tiene nombre |

**Cierre: la legión en el collado.** El segundo de los tres que le ocurren al
jugador. Las Guerras Cántabras (29–19 a.C.) se pierden, y **el juego no debe
ofrecer ganarlas**: lo que se decide es qué se conserva —el sitio, la gente, el
oficio— y qué se pierde. Un castro abandonado y un campamento romano encima son
dos `Feature` distintos en el mismo emplazamiento, y eso es exactamente lo que
hay en el registro.

**La trampa.** El cántabro indomable. Es el tópico local por excelencia y el
juego debe resistirse: aquí hay agricultura, minería, comercio y jerarquía, no
una tribu heroica peleando contra el mundo.

---

### 7. Roma — el Estado

**El registro cántabro.** Los campamentos de las Guerras Cántabras en la línea de
La Espina del Gallego, Cildá y El Cantón; Iuliobriga (Retortillo); Portus
Victoriae (Santander) y Flaviobriga (Castro Urdiales); la calzada de Pisoraca a
Portus Blendium, con el tramo empedrado de Bárcena de Pie de Concha; minería de
hierro en la zona de Cabárceno. **ATESTIGUADO**. `Site.Feature.ROMANO` ya existe.

| Hitos técnicos | |
|---|---|
| **El arco y el mortero hidráulico** | Se construye alto y se construye mojado |
| **La teja y el ladrillo** | Barro cocido en serie: la casa cambia de forma |
| **La calzada** | El coste de mover mercancía se hunde. Cambia el mapa regional entero |
| **La galería de mina** | Se extrae bajo tierra, con desagüe y turnos |
| **El agua mueve la rueda** | El molino hidráulico: por primera vez algo trabaja sin un músculo detrás |
| **El vidrio y la moneda** | Un valor que no se come y no se pudre |

| Hitos sociales | |
|---|---|
| **El impuesto** | El excedente ya no lo decide quien lo produce |
| **La ciudad** | Miles de personas que no producen alimento |
| **La esclavitud** | Trabajo como propiedad. Hay que nombrarlo, no adornarlo |
| **La ley escrita** | Y con ella el contrato, que dura más que quien lo firmó |
| **La lengua de fuera** | El latín entra por el mercado, no por la espada |

**Cierre: el Estado se va.** El tercero y último de los que le ocurren al
jugador. Deja de llegar la moneda, deja de repararse la calzada, la ciudad se
vacía y se vuelve a los altos. **Y lo interesante es qué sobrevive**: el molino
sigue moliendo, la teja sigue cociéndose, la vía sigue andándose. La época no
termina en ruina, termina en una lista de cosas que se conservan sin quien las
mantenía.

**La trampa.** Jugar a ser Roma. Aquí se juega al **valle bajo Roma**: qué se
paga, qué se compra, qué oficio nuevo cabe. El Imperio es el clima, no el avatar.

---

### 8. Alta Edad Media — el valle se gobierna solo

Del vacío tardoantiguo al monasterio con tierras. Es la época de menos gente y
más territorio por cabeza de toda la partida.

**El registro cántabro.** Santo Toribio de Liébana y los *Comentarios al
Apocalipsis* del Beato (776); Santa María de Lebeña (925); la presura y la
repoblación de los valles; el cartulario de Santa María del Puerto (Santoña,
1084). **ATESTIGUADO**. `Feature.CULTO` ya existe.

| Hitos técnicos | |
|---|---|
| **Arado de vertedera y collerón** | Se ara tierra pesada y el tiro deja de ahogarse |
| **Rotación y barbecho** | Ya hay `Barbecho.gd`: aquí es donde deja de ser una prueba |
| **Ferrería de monte** | Al viento de la ladera, sin agua. Poco hierro y muy caro |
| **El molino de cubo** | El de Roma, mantenido por el concejo en vez de por el Estado |
| **El escritorio** | Pergamino, tinta ferrogálica y meses de trabajo por libro |

| Hitos sociales | |
|---|---|
| **La presura** | Se ocupa tierra vacía y se es dueño por trabajarla. Lo más parecido a fundar |
| **El concejo abierto** | El valle decide en junta. La institución más cántabra de todas |
| **La parroquia** | La unidad que cuenta a la gente antes de que exista el censo |
| **El monasterio** | Un propietario que no se muere, y por eso acumula durante siglos |
| **La behetría** | Se elige señor, y se puede cambiar. Una rareza jurídica que aquí fue norma |

**Cierre: la escritura sale del monasterio.** Un documento que no es litúrgico
—un cartulario, una carta puebla, una cuenta—. Es el peldaño alto de la escalera
de soportes de la FASE C: **antes hay que enseñar mostrando, después basta con
contar**, y el saber deja de estar atado al sitio donde está el soporte. Con ese
documento se puede fundar una villa, que es la época siguiente.

**La trampa.** Contarla como siglos oscuros de relleno entre Roma y las
catedrales. Es donde se inventan las instituciones que gobiernan Cantabria
durante los siguientes mil años, y eso es más jugable que un castillo.

---

### 9. Baja Edad Media — la villa y el mar

**El registro cántabro.** Los fueros de las Cuatro Villas de la Costa entre
finales del XII y principios del XIII; la Hermandad de las Marismas (1296); la
Colegiata de Santillana; las ferrerías de agua; las torres de los bandos, y la
caza de ballena, que está en los escudos de Castro Urdiales y San Vicente de la
Barquera. **ATESTIGUADO**. `Feature.DEFENSIVO` y `Feature.INDUSTRIA` ya existen.

| Hitos técnicos | |
|---|---|
| **Ferrería hidráulica** | ~1350 °C con barquín movido por agua: barras en cantidad |
| **La nao y la atalaya** | La ballena se ve desde tierra, se sale a por ella, se despieza en la villa |
| **El astillero** | La madera del valle se convierte en barco, y el barco en flete |
| **La lonja y el peso** | Medida pública: se puede comerciar con quien no se conoce |
| **El puerto de rueda** | La lana de Castilla cruza Cantabria hacia Flandes |

| Hitos sociales | |
|---|---|
| **El fuero** | La villa negocia su ley: hay un derecho que no es el del señor |
| **La hermandad** | Villas que pactan entre sí por encima de sus señores |
| **La peste** | 1348: menos brazos, más tierra por cabeza. Cambia el precio del trabajo |
| **Los bandos** | La violencia entre linajes como estado normal del siglo XV |
| **El vecino y el forastero** | El fuero define quién es de la villa, y eso vale dinero |

**Cierre: el barquín lo mueve el agua.** La ferrería hidráulica es el penúltimo
peldaño térmico y el que hace posible el siguiente: sin barras en cantidad no
hay cañón, y sin cañón no hay Real Fábrica.

**La trampa.** Que sea un menú de edificios. Lo que distingue a esta época es que
aparecen **instituciones** —fuero, hermandad, lonja, bando— y que por primera vez
el valle depende de un mercado exterior. Si eso no es jugable, la época es un
castillo con textura de piedra.

---

### 10. Edad Moderna — la fábrica del rey

**El registro cántabro.** Las Reales Fábricas de artillería de Liérganes y La
Cavada, con altos hornos desde 1622; el astillero de Guarnizo; el Camino Real de
Reinosa a Santander a mediados del XVIII; la habilitación del puerto de Santander
para el comercio con América; el maíz, que entra en el XVII y rehace la dieta, la
casa y el calendario; la casona montañesa, y la emigración a Indias.
**ATESTIGUADO**.

| Hitos técnicos | |
|---|---|
| **Alto horno** | ~1550 °C: el hierro **funde**. Se cuela y se moldea. Fin de la escalera térmica |
| **El maíz** | Dos cosechas donde había una, y un grano que se seca en la solana |
| **El navío** | Guarnizo: madera del valle convertida en barco del Estado |
| **La carretera** | Reinosa–Santander: la harina de Castilla llega al puerto |
| **La imprenta** | El último soporte. El saber deja de tener original |

| Hitos sociales | |
|---|---|
| **La fábrica** | Cientos de personas cobrando un jornal por hora, no por cosecha |
| **La hidalguía universal** | Ser montañés como título. Curioso, y con consecuencias reales |
| **El indiano** | Se va gente y vuelve capital. El valle depende de otro continente |
| **La provincia** | Los Nueve Valles se dan gobierno común (1778): el mapa regional se cierra sobre sí mismo |

**Cierre: la tierra cambia de dueño.** Las desamortizaciones del XIX sacan a
subasta lo del monasterio y lo del común. Es el hito más social de los doce y
uno de los pocos que **quita** en vez de dar: el monte que el concejo llevaba
gestionando desde la Alta Edad Media —§8, la institución más cántabra de todas—
deja de ser del concejo. Sin ese cambio no hay obrero, porque quien tiene monte
comunal no necesita jornal.

**La trampa.** Que la Real Fábrica se juegue como un edificio más. Liérganes y
La Cavada son el Estado instalando industria pesada en un valle ganadero: comen
bosque a una velocidad que el monte no aguanta, y ese conflicto —carbón vegetal
contra pasto y contra leña— es la época entera. Se resuelve solo con la escalera
térmica y el bosque que ya están simulados.

---

### 11. El vapor — la fábrica y el ferrocarril

Aquí la partida cambia de naturaleza, y conviene decirlo en voz alta: **desde
esta época el valle deja de ser un sistema cerrado**. Lo que se produce, lo que
vale y quién lo compra se decide fuera del mapa.

**El registro cántabro.** El ferrocarril de Alar del Rey a Santander (1857–1866)
y con él la harina de Castilla hacia Cuba; las minas de Cabárceno y el zinc de
Reocín; los Altos Hornos de Nueva Montaña (1899); la emigración masiva a América
y las casas de indianos que volvieron con ella; la explosión del *Cabo
Machichaco* en el puerto (1893). **ATESTIGUADO**, y por primera vez la fuente no
es arqueológica sino de archivo y prensa, que es un cambio de método a tener en
cuenta en la enciclopedia de la FASE E4.

| Hitos técnicos | |
|---|---|
| **El coque** | El alto horno se suelta del carbón vegetal: **la industria deja de estar limitada por el bosque**, que era el techo desde el Neolítico |
| **La máquina de vapor** | La energía se desengancha del río y de la estación. El molino podía parar en agosto; esto no |
| **El ferrocarril** | Alar–Santander: Castilla y el puerto en una jornada. El mapa regional se reordena entero alrededor de la vía |
| **La mina a cielo abierto** | Cabárceno: el paisaje se altera a escala de mapa. Y esto **está en el DEM real** que el juego ya carga |
| **La conserva y la salazón industrial** | La anchoa de Santoña con maestros italianos: el pescado deja de ser comida y pasa a ser producto |

| Hitos sociales | |
|---|---|
| **El jornal** | El trabajo se vende por horas a alguien. Es el cambio de unidad de toda la época |
| **La emigración masiva** | El valle exporta gente y le vuelve capital. El indiano deja de ser una excepción |
| **La escuela y el cuartel** | El Estado llega a la aldea, y por primera vez cuenta a cada uno por su nombre |
| **La huelga** | La única herramienta del que no tiene tierra ni herramienta |

**Cierre: el capital de fuera.** Una fábrica que se levanta en el valle con
dinero que no es del valle —Solvay en Barreda, 1908, con capital belga—. La
decisión de qué se produce aquí deja de tomarse aquí, y eso es el siglo XX.

**La trampa.** Que se convierta en un *tycoon*. El juego no es de construir la
fábrica: es de **qué le pasa al valle cuando la fábrica llega**. Quién deja el
ganado, quién se va a América, qué monte se vende y qué río se ensucia. Si el
jugador acaba optimizando toneladas de mineral, se ha perdido lo que hacía
distinto a este proyecto.

---

### 12. El siglo corto — hasta el mapa de hoy

**El registro cántabro.** El Palacio de la Magdalena y el veraneo (1913); el
frente del norte y la caída de Santander (1937); el incendio de Santander
(1941); Sniace en Torrelavega (1941) y la química del Besaya; la emigración a
Europa de los sesenta; el turismo de costa; la reconversión industrial de los
ochenta, y el Estatuto de Autonomía (1981–82). **ATESTIGUADO**, con la misma
advertencia de método que la época anterior.

| Hitos técnicos | |
|---|---|
| **La electricidad** | La luz llega al valle. La jornada deja de acabarse con el sol, por primera vez desde la lámpara de grasa |
| **El hormigón** | Se construye en cualquier sitio y con material que no es del sitio |
| **El automóvil** | Y con él la carretera asfaltada: el pueblo de montaña deja de estar a un día de todo |
| **La química** | Solvay y Sniace. Producen bien y **el río paga la factura**: el Besaya es un dato del juego, no una moraleja |
| **El frigorífico** | Se acabó la conservación por humo, sal y estación. Cae la última mecánica que venía del Paleolítico |

| Hitos sociales | |
|---|---|
| **El veraneante** | La playa y el verde valen dinero sin que nadie los trabaje. El paisaje se vuelve producto |
| **La guerra** | 1937: el cuarto y último hito que le ocurre al jugador. No hay bando que jugar |
| **El éxodo rural** | El pueblo se vacía hacia Torrelavega, Santander y Europa. Emplazamientos ocupados desde el Neolítico se quedan sin nadie |
| **La reconversión** | Lo que trajo el jornal se lo lleva, y deja el edificio puesto |

**Final: el mapa se cierra.** Cantabria se constituye en comunidad autónoma y el
territorio de la partida pasa a coincidir **exactamente** con
`data/boundaries/cantabria.json`: los 5304 km² con los que arrancó el juego. La
partida termina cuando el mapa que has ido ocupando durante cuarenta mil años se
convierte en el mapa que se te dio a elegir en la primera pantalla. No hay
victoria; hay reconocimiento.

**La trampa.** Dos, y las dos fáciles de pisar. Una, contar la contaminación y
la reconversión como moraleja: son consecuencias medibles, y el juego mide.
Dos, seguir hasta hoy. De 1982 en adelante no hay distancia suficiente para
convertir nada en mecánica, y el registro deja de ser registro para ser opinión.

---

## 5. Las tres escaleras que cruzan todas las épocas

**Ninguna es contenido nuevo**: las tres están ya escritas en el proyecto, y son
el esqueleto que impide que las doce épocas sean doce listas sueltas. Además son
las que llevan la progresión *dentro* de una época, que es justo lo que hace
falta ahora que el Paleolítico es una sola.

### La escalera térmica

`RawMaterial` guarda punto de fusión e ignición, o sea que el árbol tecnológico
ya está escrito y sólo hay que leerlo (ROADMAP B2). **Un peldaño por época desde
el Neolítico**, que es lo que hace que las diez tengan ritmo:

hogar ~700 °C (1–2) → horno de fosa ~900 (3) → cubeta con fuelle ~1100 (4) →
horno mejorado ~1200 (5) → cuba baja ~1250 (6) → ferrería de monte (8) →
ferrería hidráulica ~1350 (9) → alto horno ~1550 (10) → **coque y vapor (11)**.

El último peldaño es distinto de los diez anteriores y por eso cierra la
escalera: con el coque **el límite deja de ser una temperatura y pasa a ser el
dinero**. Es la señal más limpia de que el juego ha cambiado de género, y de que
conviene que ahí queden sólo dos épocas y no seis.

### La escalera del soporte

De la FASE C. Es la que decide **qué saber sobrevive al relevo generacional**:

pared y mobiliar (1) → canto pintado (2) → cerámica (3) → molde y marca de
propiedad (4–5) → estela (6) → escritura (7) → cartulario y fuero (8–9) →
imprenta (10) → prensa y fotografía (11) → radio (12).

### La escalera del alimento

Y con ella, cuánta gente cabe en el mismo sitio:

recolección y caza (1) → marisqueo y costa (2) → siembra y rebaño (3) →
excedente almacenable (4–6) → mercado y compra (7) → rotación y molino (8) →
comercio de la villa (9) → maíz y ultramar (10) → mercado nacional por
ferrocarril (11) → frío, conserva y salario (12).

En la 12 se cierra el círculo entero: la comida deja de depender de la estación
y del sitio, que es la restricción sobre la que está construido todo el juego
desde la primera pantalla.

---

## 6. Cómo se implementa

`Site.Era` se queda en cinco valores y **no hace falta tocarlo**: es lo que
gobierna qué emplazamientos son ocupables y qué piel lleva la interfaz. La época
concreta va aparte, porque son dos preguntas distintas —«qué cultura material
tengo» y «qué clase de sitio puedo habitar»—. Con doce épocas sobre cinco
`Site.Era` la correspondencia es la de la tabla del §2 y no hace falta más.

```gdscript
class_name Hito
extends Resource

@export var id: StringName             # "la_aleacion"
@export var epoca: int                 # índice de las doce
@export var nombre: String
@export var descripcion: String
@export var cierra_epoca: bool = false # sólo uno por época
@export var lo_sufre: bool = false     # no lo hace el jugador: le ocurre
@export var evidencia: Site.Fidelity   # ATESTIGUADO / INFERIDO
@export var fuente: String             # yacimiento o referencia
@export var deja_en_el_mapa: Site.Feature = Site.Feature.OTRO
@export var abre_tecnicas: Array[int] = []
@export var abre_procesos: Array[StringName] = []
```

La condición de disparo **no va en el recurso**: va en código, porque cada una
mira una cosa distinta del estado —una técnica, una obra terminada, una colada,
un documento— y meterlas en un lenguajito de datos es la clase de generalización
que se paga durante años.

**Orden de trabajo, y el orden importa.**

1. **Resolver el choque del §3** entre `SLICE_PALEOLITICO` §1 y `TechTree`. Es
   barato, es un documento, y sin ello la primera época no tiene progresión
   interna definida.
2. **El Mesolítico**, porque la cadena corta de la FASE B3 (cuarcita de río →
   pico → marisqueo → conchero) es literalmente el Asturiense.
3. **El Neolítico**, que es el primer peldaño térmico propio y la primera vez
   que se construye en vez de ocupar.

De ahí en adelante, de una en una y hacia delante. Las doce fichas son el
destino, no el plan de la semana.

---

## 7. Lo que este documento no promete

**No hay línea recta.** Ninguna época «mejora» a la anterior: el Asturiense es un
ajuste excelente a un mundo nuevo, y el Neolítico cántabro llega tarde y a
regañadientes. El juego no debe tener una flecha de progreso dibujada.

**La proporción de PLAUSIBLE no es pareja.** El Calcolítico es la época con menos
suelo documentado de las doce y el Paleolítico la que más tiene; en la Edad Media
el problema es el contrario, que hay tanto que elegir qué contar ya es una
interpretación. Lo que se garantiza no es acertar: es que **ninguna afirmación
esté sin etiqueta** (FASE E4).

**El método cambia en la 11, y hay que decirlo.** Hasta la Edad Media todo lo que
afirma este documento se apoya en cultura material excavada; de la Edad Moderna
en adelante se apoya en archivo, y en el XX en prensa y memoria. No es peor
fuente, es **otra**, y la enciclopedia de la FASE E4 debería distinguirlas en vez
de meter una estela discoidea y una acta de la Solvay bajo la misma etiqueta de
ATESTIGUADO.

**Doce épocas son mucho más de lo que cabe.** Está dicho en los riesgos del
ROADMAP y se repite aquí: esto es el mapa del destino, no un compromiso de
llegar. Si hay que recortar, el orden es al revés del de escritura: **primero se
caen la 11 y la 12**, que son las que menos se apoyan en el motor que existe —el
jornal y el capital de fuera no se simulan con jornadas y calorías—, luego se
funde el Calcolítico con el Bronce, y luego se juntan las dos mitades de la Edad
Media. Con eso se vuelve a ocho sin perder nada estructural. Y si sólo se hacen
tres, que sean tres enteras.
