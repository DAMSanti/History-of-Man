# Las épocas y sus hitos

Once épocas con cultura material documentada en Cantabria, del Achelense a la
Edad Moderna, y **qué hito cierra cada una**. Es el contenido de la FASE D del
[ROADMAP.md](ROADMAP.md), que hasta hoy era una línea que decía «diez épocas»
sin decir cuáles.

Salen once y no diez porque el **Magdaleniense se separa** del Paleolítico
superior inicial: es la época que está construida
([SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md)) y no se juega igual que el
Auriñaciense —el arpón, el remonte del salmón y el arte parietal son un ciclo
anual distinto—. El resto de agrupaciones va al revés: Aziliense y Asturiense
caben en un Mesolítico, y Auriñaciense, Gravetiense y Solutrense caben en un
Paleolítico superior inicial.

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
- **Deja algo detrás en el mapa.** Un dolmen, un conchero, un castro, una
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
**capacidad demostrada**: el grupo ha hecho una vez la cosa que define la época
siguiente. Almacenar no es saber.

---

## 2. Las once, de un vistazo

`Era` es el valor de `Site.Era` con el que se juega esa época: define qué
emplazamientos son ocupables (`Site.is_usable_in`) y qué piel lleva la interfaz
(`UISkin.vestir`, ver [INTERFAZ.md](INTERFAZ.md)).

| # | Época | Intervalo | `Site.Era` | Mar | Dónde se vive | Hito de cierre |
|---|---|---|---|---|---|---|
| 1 | **Achelense** | ~350–120 ka | PALEOLITICO | −40 m | Terraza fluvial, boca de cueva | El núcleo preparado |
| 2 | **Musteriense** | ~120–40 ka | PALEOLITICO | −70 m | Cueva, ocupación corta y repetida | El primer trazo en la pared |
| 3 | **Paleolítico superior inicial** | ~40–17 ka | PALEOLITICO | −80 → −120 m | Cueva con vestíbulo, valle abrigado | El arpón de asta |
| 4 | **Magdaleniense** | ~17–11,7 ka | PALEOLITICO | −90 → −60 m | Abrigo con río y roquedo cerca | El bosque cierra el valle |
| 5 | **Mesolítico** | ~11,7–5,5 ka | MESOLITICO | −50 → −5 m | Conchero al aire libre, costa | El primer grano sembrado |
| 6 | **Neolítico** | ~5500–3000 a.C. | NEOLITICO | ~0 | Cabaña en ladera suave, puerto de montaña | El dolmen levantado |
| 7 | **Calcolítico y Bronce** | ~3000–800 a.C. | METALES | 0 | Poblado en alto, cueva sepulcral | La primera colada de bronce |
| 8 | **Hierro: los cántabros** | ~800–19 a.C. | METALES | 0 | Castro amurallado | La esponja de hierro forjada |
| 9 | **Roma** | 19 a.C.–s. V | HISTORICA | 0 | Ciudad, villa, puerto, mina | El agua mueve la rueda |
| 10 | **Edad Media** | s. V–XV | HISTORICA | 0 | Valle con concejo, villa con fuero | La escritura sale del monasterio |
| 11 | **Edad Moderna** | s. XVI–XVIII | HISTORICA | 0 | Villa portuaria, casona, fábrica | (final de la partida) |

Las cotas del mar son **INFERIDO**: salen de la curva eustática global, no de un
estudio de la plataforma cantábrica. Ya son datos vivos —`RegionEras` hornea una
máscara por cota y `Site.coast_km_by_era` guarda la distancia a la costa de cada
época—, así que un sitio costero de hoy queda a trece kilómetros del mar en el
Último Máximo Glacial sin que haya que escribir nada a mano.

---

## 3. Época por época

Cada ficha trae lo mismo: el suelo real cántabro (**ATESTIGUADO**, con
yacimiento), los hitos técnicos, los sociales, el de cierre, y **la trampa** —el
error de diseño que esa época invita a cometer—.

---

### 1. Achelense — la piedra grande

**El registro cántabro.** Bifaces de cuarcita en terrazas fluviales y en los
niveles basales de El Castillo (Puente Viesgo), que tiene la secuencia de
ocupación más larga de Europa. Poco y disperso: es la época peor documentada de
las once, y el juego debe decirlo.

| Hitos técnicos | |
|---|---|
| **Bifaz** | Una herramienta con forma buscada, no un filo aprovechado |
| **Percutor blando** | Asta en vez de canto: el filo deja de ser una casualidad |
| **Fuego mantenido** | No producido: recogido del rayo y alimentado. Perderlo es perderlo |

| Hitos sociales | |
|---|---|
| **El reparto de la pieza** | Se lleva al campamento en vez de comerla donde cayó |
| **El campamento base** | Un sitio al que volver, no un sitio donde se está |

**Cierre: el núcleo preparado.** Preparar el nódulo *antes* de extraer, para que
la lasca salga con la forma pensada. Ya está en `TechTree.Tech.NUCLEO`.

**La trampa.** Hacerla larga. Son 230.000 años de registro escasísimo y la
tentación es rellenarlos con contenido inventado. Debe ser la época **más corta
de jugar de las once**: media hora, un puñado de decisiones, y fuera.

---

### 2. Musteriense — los otros

**El registro cántabro.** El Castillo, Covalejos, Hornos de la Peña, Cueva Morín
y El Esquilleu (Liébana, ocupaciones de altura). Talla Levallois y discoide,
fuego habitual, caza de ciervo y bóvido. **ATESTIGUADO**.

| Hitos técnicos | |
|---|---|
| **Levallois** | Lascas repetibles: la herramienta se puede planificar |
| **Fuego producido** | Pirita y yesca. Deja de depender de la suerte |
| **Enmangue** | Resina y tendón. Una punta deja de ser una piedra en la mano |
| **Piel raspada** | Sin coser todavía: envuelve, no viste |

| Hitos sociales | |
|---|---|
| **El cuidado del herido** | Alguien que no produce sigue comiendo. Está en el registro europeo |
| **El sitio que se hereda** | Se vuelve a la misma cueva durante generaciones |

**Cierre: el primer trazo.** Una mano en negativo o un disco de ocre soplado en
la pared. En El Castillo hay un disco rojo datado en torno a 40.800 años, el arte
parietal más antiguo datado de Europa, justo en el filo de esta frontera. Es el
hito perfecto: **el saber empieza a salir de la cabeza y a fijarse en un
soporte**, que es exactamente el motor de la FASE C.

**La trampa.** Contar la sustitución como una derrota. El juego no debe premiar
ni castigar «ser neandertal»: la época se cierra con una capacidad, y quién la
tuvo es cosa de la enciclopedia, no del marcador.

---

### 3. Paleolítico superior inicial — el equipo completo

Auriñaciense, Gravetiense y Solutrense. Termina en el Último Máximo Glacial, con
Cantabria de refugio y el mar 120 m más abajo: la costa se va a más de diez
kilómetros y la plataforma emergida entra en juego.

**El registro cántabro.** El Castillo, El Pendo, Hornos de la Peña, Cueva Morín
(enterramientos gravetienses), Chufín (Riclones) y los niveles solutrenses de
Altamira. Puntas de aleta y pedúnculo, hojas de laurel, retoque plano.
**ATESTIGUADO**.

| Hitos técnicos | |
|---|---|
| **Talla laminar** | `Tech.HOJA`: metros de filo por kilo de sílex |
| **Azagaya de asta** | `Tech.AZAGAYA`, y con ella el propulsor |
| **Aguja con ojo** | `Tech.AGUJA`: ropa cosida, y con ella el invierno se puede ocupar |
| **Retoque a presión** | El límite de la talla lítica. Solutrense puro |
| **Lámpara de grasa** | Arenisca vaciada y mecha: **el fondo de la cueva es visitable** |

| Hitos sociales | |
|---|---|
| **La sepultura** | Un muerto con ajuar. El grupo gasta trabajo en quien ya no produce |
| **El adorno** | Concha perforada, diente colgado: se lleva puesta la pertenencia |
| **La concha de lejos** | Materia que no es de aquí: hay red de intercambio |
| **El refugio glacial** | Llega gente huyendo del hielo. La densidad sube y hay que repartir valle |

**Cierre: el arpón de asta.** El remonte del salmón deja de ser suerte y pasa a
ser cosecha. Es `Tech.ARPON`, que ya está en el árbol como cumbre de la pesca.

**La trampa.** Que el Último Máximo Glacial sea sólo un modificador de frío. Lo
que cambia de verdad es la **geografía**: kilómetros de plataforma emergida, la
costa lejísimos, y sitios que hoy están bajo el agua siendo los mejores del mapa.
Eso ya lo calcula `RegionEras`; hay que dejar que se note.

---

### 4. Magdaleniense — la época construida

Es la rebanada jugable de hoy. Aquí no hay que diseñar: hay que leer
[SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) y [CAZA_Y_PESCA.md](CAZA_Y_PESCA.md).

**El registro cántabro.** El techo de polícromos de Altamira, La Pasiega, Las
Monedas, Las Chimeneas, El Pendo, El Juyo (Camargo), Rascaño, El Mirón (Ramales,
con el enterramiento de la Dama Roja) y La Garma, que conserva un suelo de
ocupación sellado. Cantabria tiene aquí uno de los registros más densos del
mundo. **ATESTIGUADO**, y con margen de sobra.

| Hitos técnicos | |
|---|---|
| **El perro** | Ya implementado (`ElLobo.gd`). Empieza en el montón de basura, no en el cariño |
| **La bellota lavada** | Ya implementado: el tanino sale en el arroyo y la bellota se vuelve harina |
| **El secadero** | El remonte se convierte en despensa de invierno |
| **La pesquera** | Cierre de piedra en el cauce: `Tech.PESQUERA` |

| Hitos sociales | |
|---|---|
| **El relato junto al fuego** | Ya implementado (`Tale.gd`): lo que sabe uno pasa a saberlo el grupo |
| **La agregación estacional** | Varias bandas en el mismo sitio unas semanas al año |
| **El santuario** | Arte parietal donde no se va a vivir: el territorio se marca |

**Cierre: el bosque cierra el valle.** No es una técnica, y es a propósito. El
hielo se retira, el robledal sube y **el reno y el caballo se van del valle**: la
caza mayor de manada deja de existir. Es un hito que **le ocurre al jugador**, y
el único de los once que no se dispara con un acierto suyo. El grupo que dependía
de la berrea tiene que aprender a comer de la costa.

**La trampa.** Alargarla porque es la que está hecha. Es la época mejor
construida y la tentación será quedarse. El criterio del ROADMAP sigue mandando:
si la cadena corta no divierte, el contenido nuevo no lo arregla.

---

### 5. Mesolítico — la costa

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

### 6. Neolítico — la primera arquitectura

**El registro cántabro.** Cerámica y cabaña ganadera en cuevas como Los Gitanos
(Castro Urdiales) y en los niveles neolíticos de El Mirón; megalitismo en el Alto
Asón, en Peña Oviedo (Camaleño) y en los pasos de montaña. En Cantabria el
Neolítico es **tardío y de registro pobre**: llega tarde y convive mucho tiempo
con la caza. **ATESTIGUADO** el megalitismo, **INFERIDO** el detalle del
calendario agrícola. `Site.Feature.MEGALITO` ya lo contempla.

| Hitos técnicos | |
|---|---|
| **Horno de fosa** | ~900 °C. Primer peldaño de la escalera térmica: **cerámica** |
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

### 7. Calcolítico y Bronce — el metal y el linaje

**El registro cántabro.** Hachas de talón, cuevas sepulcrales, arte esquemático y
depósitos en Cofresnedo (Matienzo), y los ídolos grabados de Sejos (Campoo), con
armas representadas. **ATESTIGUADO** el material; **PLAUSIBLE** el detalle de la
organización social.

| Hitos técnicos | |
|---|---|
| **Cubeta con fuelle** | ~1100 °C: el cobre funde a 1085. La escalera térmica manda |
| **La aleación** | Estaño en el cobre: más duro y funde antes. **Y el estaño no es de aquí** |
| **El molde** | La forma deja de tallarse: se repite. Hacha de talón en serie |
| **El telar de pesas** | La lana se convierte en tela sin salir del poblado |
| **La rueda de alfarero** | Cerámica en cantidad y a medida |

| Hitos sociales | |
|---|---|
| **El artesano** | Alguien que no produce comida y aun así come: el primer oficio puro |
| **La ruta del estaño** | Depender de material lejano ata el valle a una red que no controla |
| **El ajuar desigual** | Dos tumbas del mismo sitio con contenidos incomparables |
| **El poblado en alto** | Se elige sitio por defendible. `Site.Kind.ALTURA` sube de valor |

**Cierre: la primera colada de bronce.** Una pieza salida de molde, con estaño
que no es del valle. Cierra técnica y comercio de una vez.

**La trampa.** Que el metal sustituya a la piedra al día siguiente. La piedra
pulimentada sigue siendo la inmensa mayoría de las herramientas durante siglos:
el bronce es caro, escaso y en buena medida **prestigio**. Si el juego lo reparte
como material corriente, se ha saltado lo que el bronce significaba.

---

### 8. Hierro — los cántabros

**El registro cántabro.** Castros de Las Rabas (Celada Marlantes), Monte Ornedo,
La Espina del Gallego y Cildá; las estelas discoideas gigantes de Barros y Zurita
—adscripción discutida, **PLAUSIBLE**—; y las fuentes grecolatinas, que traen los
nombres de los pueblos y muy poco más. `Site.Feature.CASTRO` ya existe.

| Hitos técnicos | |
|---|---|
| **Cuba baja** | ~1250 °C: hierro **en estado sólido**. Sale esponja, no colada |
| **La forja** | La esponja se limpia a martillo. Media jornada de golpes por kilo |
| **El molino circular** | Rotatorio: multiplica la harina por hora de trabajo |
| **La muralla y el foso** | La construcción defensiva como obra colectiva del año |
| **La salazón** | Sal y pescado: comida que viaja y que se vende |

| Hitos sociales | |
|---|---|
| **La comunidad castreña** | Se pertenece al castro. La unidad deja de ser la familia |
| **El guerrero** | Un oficio cuyo trabajo es la violencia, mantenido por los demás |
| **El pacto entre castros** | Hospitalidad y alianza: la política antes del Estado |
| **La frontera** | Hay un afuera, y el afuera tiene nombre |

**Cierre: la esponja forjada.** Una barra de hierro utilizable salida de la cuba
del valle. El salto de la esponja a la colada queda **para la época 11**, y esa
frontera cae sola de los datos que ya están en `Iron.tres`.

**La trampa.** El cántabro indomable. Es el tópico local por excelencia y el
juego debe resistirse: aquí hay agricultura, minería, comercio y jerarquía, no
una tribu heroica peleando contra el mundo. Las Guerras Cántabras se pierden, y
el juego no debe ofrecer ganarlas.

---

### 9. Roma — el Estado

**El registro cántabro.** Los campamentos de las Guerras Cántabras (29–19 a.C.)
en la línea de La Espina del Gallego, Cildá y El Cantón; Iuliobriga
(Retortillo); Portus Victoriae (Santander) y Flaviobriga (Castro Urdiales); la
calzada de Pisoraca a Portus Blendium, con el tramo empedrado de Bárcena de Pie
de Concha; minería de hierro en la zona de Cabárceno. **ATESTIGUADO**.
`Site.Feature.ROMANO` ya existe.

| Hitos técnicos | |
|---|---|
| **El arco y el mortero hidráulico** | Se construye alto y se construye mojado |
| **La teja y el ladrillo** | Barro cocido en serie: la casa cambia de forma |
| **La calzada** | El coste de mover mercancía se hunde. Cambia el mapa regional entero |
| **La galería de mina** | Se extrae bajo tierra, con desagüe y turnos |
| **El vidrio y la moneda** | Un valor que no se come y no se pudre |

| Hitos sociales | |
|---|---|
| **El impuesto** | El excedente ya no lo decide quien lo produce |
| **La ciudad** | Miles de personas que no producen alimento |
| **La esclavitud** | Trabajo como propiedad. Hay que nombrarlo, no adornarlo |
| **La ley escrita** | Y con ella el contrato, que dura más que quien lo firmó |
| **La lengua de fuera** | El latín entra por el mercado, no por la espada |

**Cierre: el agua mueve la rueda.** El molino hidráulico: la primera vez que algo
trabaja sin un músculo detrás. Es el hito que más cambia el tablero de trabajos,
porque libera jornadas de golpe.

**La trampa.** Jugar a ser Roma. Aquí se juega al **valle bajo Roma**: qué se
paga, qué se compra, qué oficio nuevo cabe. El Imperio es el clima, no el avatar.

---

### 10. Edad Media — el valle, el fuero y la ferrería

Mil años; conviene partirla en dos por dentro aunque cuente como una época.

**El registro cántabro.** Santo Toribio de Liébana y los *Comentarios al
Apocalipsis* del Beato (776), Santa María de Lebeña (925), el cartulario de Santa
María del Puerto (Santoña, 1084) y la Colegiata de Santillana; después los fueros
de las Cuatro Villas de la Costa entre finales del XII y principios del XIII, la
Hermandad de las Marismas (1296), las ferrerías de agua, las torres de los bandos
y la caza de ballena, que está en los escudos de Castro Urdiales y San Vicente de
la Barquera. **ATESTIGUADO**. `Feature.CULTO`, `Feature.DEFENSIVO` y
`Feature.INDUSTRIA` ya existen.

| Hitos técnicos | |
|---|---|
| **Vertedera y collerón** | Se ara tierra pesada y el tiro deja de ahogarse |
| **Rotación y barbecho** | Ya hay `Barbecho.gd`: aquí es donde deja de ser una prueba |
| **Ferrería hidráulica** | ~1350 °C con barquín de agua: barras en cantidad |
| **La nao y la atalaya** | La ballena se ve desde tierra, se sale a por ella, se despieza en la villa |
| **El pergamino y el escritorio** | Copiar es carísimo, y por eso se copia lo que importa |

| Hitos sociales | |
|---|---|
| **El concejo abierto** | El valle decide en junta. La institución más cántabra de todas |
| **El fuero** | La villa negocia su ley: hay un derecho que no es el del señor |
| **La parroquia** | La unidad que cuenta a la gente antes de que exista el censo |
| **La peste** | 1348: menos brazos, más tierra por cabeza. Cambia el precio del trabajo |
| **Los bandos** | La violencia entre linajes como estado normal del siglo XV |

**Cierre: la escritura sale del monasterio.** Un documento que no es litúrgico
—un cartulario, un fuero, una cuenta—. Es el peldaño alto de la escalera de
soportes de la FASE C: **antes hay que enseñar mostrando, después basta con
contar**, y el saber deja de estar atado al sitio donde está el soporte.

**La trampa.** Que la Edad Media sea un menú de edificios. Lo que la distingue es
que aparecen **instituciones**: concejo, fuero, parroquia, hermandad. Si eso no
es jugable, la época es un castillo con textura de piedra.

---

### 11. Edad Moderna — el fin de la partida

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

**Sin cierre.** Es la última. El juego termina cuando el valle está enganchado a
una economía que ya no cabe en el mapa: la partida acaba **por integración**, no
por victoria.

**La trampa.** Seguir hasta la industria y el ferrocarril. El siglo XIX pide otro
juego —capital, fábrica, sindicato— y meterlo aquí es abrir un frente que no se
cierra. La Edad Moderna es el final, y conviene que se note desde el principio.

---

## 4. Las tres escaleras que cruzan todas las épocas

**Ninguna es contenido nuevo**: las tres están ya escritas en el proyecto, y son
el esqueleto que impide que las once épocas sean once listas sueltas.

### La escalera térmica

`RawMaterial` guarda punto de fusión e ignición, o sea que el árbol tecnológico
ya está escrito y sólo hay que leerlo (ROADMAP B2). Casi un peldaño por época:

hogar ~700 °C (1–5) → horno de fosa ~900 (6) → cubeta con fuelle ~1100 (7) →
horno mejorado ~1200 (7) → cuba baja ~1250 (8) → ferrería hidráulica ~1350 (10) →
alto horno ~1550 (11).

### La escalera del soporte

De la FASE C. Es la que decide **qué saber sobrevive al relevo generacional**:

pared (2) → mobiliar (3–4) → canto pintado (5) → cerámica (6) → tablilla y marca
de propiedad (7–8) → escritura (9–10) → imprenta (11).

### La escalera del alimento

Y con ella, cuánta gente cabe en el mismo sitio:

recolección y caza (1–4) → marisqueo y costa (5) → siembra y rebaño (6) →
excedente almacenable (7–8) → mercado y compra (9) → rotación y molino (10) →
maíz y comercio de ultramar (11).

---

## 5. Cómo se implementa

`Site.Era` se queda en cinco valores y **no hace falta tocarlo**: es lo que
gobierna qué emplazamientos son ocupables y qué piel lleva la interfaz. La época
concreta va aparte, porque son dos preguntas distintas —«qué cultura material
tengo» y «qué clase de sitio puedo habitar»—.

```gdscript
class_name Hito
extends Resource

@export var id: StringName             # "nucleo_preparado"
@export var epoca: int                 # índice de las once
@export var nombre: String
@export var descripcion: String
@export var cierra_epoca: bool = false # sólo uno por época
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

**Orden de trabajo, y el orden importa.** Se hacen primero la 5 y la 6
—Mesolítico y Neolítico— porque son las adyacentes a lo construido y porque la
cadena corta de la FASE B3 (cuarcita de río → pico → marisqueo → conchero) es
literalmente el Asturiense. Las once fichas de arriba son el destino; el camino
es de una en una hacia delante, sin saltar al bronce porque apetezca.

---

## 6. Lo que este documento no promete

**No hay línea recta.** Ninguna época «mejora» a la anterior: el Asturiense es un
ajuste excelente a un mundo nuevo, y el Neolítico cántabro llega tarde y a
regañadientes. El juego no debe tener una flecha de progreso dibujada.

**La proporción de PLAUSIBLE crece hacia atrás y hacia delante, por motivos
distintos.** En el Achelense porque casi no hay registro; en la Edad Media porque
hay tanto que elegir qué contar ya es una interpretación. Lo que se garantiza no
es acertar: es que **ninguna afirmación esté sin etiqueta** (FASE E4).

**Once épocas son más de lo que cabe.** Está dicho en los riesgos del ROADMAP y
se repite aquí: esto es el mapa del destino, no un compromiso de llegar. Si sólo
se hacen cinco, que sean cinco enteras.
