# La interfaz, y cómo cambia con las eras

Qué tiene hoy, qué le falta, y el diseño que propongo: **una interfaz hecha de
los materiales que la banda trabaja**, que cambia cuando cambia su cultura
material.

---

## 1. El problema

La piel de hoy (`UISkin`) ya no es el negro translúcido de serie de Godot —eso
se arregló— pero se ha quedado a medio camino: rectángulos redondeados marrón
oscuro, un ocre de acento y nada más. Es **funcional y anónima**. Podría ser la
interfaz de un gestor de tareas.

Lo que le falta no es color: es **materia**. Ahora mismo nada en pantalla dice
que esto va de gente que raspa pieles con una lasca de cuarcita.

---

## 2. La idea: la interfaz es un objeto de la época

La ventana no es un panel de cristal flotando sobre el mundo: es **una piel
tensada**, y lo que hay escrito en ella está **pintado con ocre y carbón**.

Eso da tres cosas gratis:

1. **Coherencia** — la paleta sale del catálogo de materiales que ya existe:
   ocre, hematites, carbón, hueso, sílex. No hay que inventar colores.
2. **Fidelidad** — son los pigmentos y soportes que la banda tiene. El ocre de
   los paneles es el mismo `Materia.Kind.OCRE` que se recoge.
3. **Y sobre todo: una razón para que evolucione.** La interfaz no cambia
   «porque toca una skin nueva cada era». Cambia porque **la banda aprende a
   hacer materiales nuevos**, y el soporte de su información cambia con ellos.

---

## 3. Las eras

`Site.Era` ya define las cinco. Cada una tiene su soporte, su pigmento y su
manera de contar.

| era | soporte | pigmento | acento | cómo se cuenta |
|---|---|---|---|---|
| **Paleolítico** | piel tensada, pared de cueva | ocre y carbón | ocre rojo | muescas en un hueso |
| **Mesolítico** | corteza, estera de junco | ocre, blanco de concha | verde de junco | muescas y conchas |
| **Neolítico** | barro cocido, lino tejido | almagre, engobe crema | terracota | fichas de barro |
| **Metales** | tablilla, bronce bruñido | tinta, verdín | bronce | signos grabados |
| **Histórica** | pergamino, tinta ferrogálica | sepia | rojo minio | número escrito |

La transición no tiene que ser un salto: **el soporte del que ya sabes hacer
sustituye al anterior**. Cuando la banda aprende cerámica, las fichas del
almacén dejan de ser muescas y pasan a ser cuencos.

---

## 4. El Paleolítico, en concreto

Lo que cambia respecto de hoy, elemento por elemento.

### La ventana

- **Fondo de piel curtida**, no color plano: un marrón cálido con **grano**
  —ruido fino, muy sutil— y variación de tono, como una piel raspada.
- **Sin esquinas redondeadas de widget.** Una piel tensada tiene el borde
  **irregular**: un contorno con leve dentado, no un radio de 6 px.
- **Doble filete**: uno exterior de carbón y otro interior de ocre, a un par de
  píxeles. Es como se enmarca una pintura parietal.

### Los rótulos

- **Cabeceras en versalitas**, con un **punto de ocre** delante en vez de un
  guion. Leído de lejos parece una marca hecha con el dedo.
- El texto secundario en **ceniza**, no en gris neutro.

### Las barras

Hambre y cansancio no son barras de progreso: son **una tira de muescas**. Diez
marcas talladas; se llenan de ocre según sube. Es exactamente cómo se contaba
—los bastones de muescas paleolíticos están atestiguados— y además se lee mejor
de un vistazo que un relleno continuo.

### Los botones

- Fondo de **hueso** (crema apagado) sobre la piel oscura, para que se vea que
  son otra cosa.
- Al pulsar, **se manchan de ocre** en vez de cambiar de tono.

### El acento y las alarmas

- Acento: **ocre**, el que ya hay.
- Alarma: **hematites**, un rojo más terroso y menos naranja que el actual.
- Bien: **verde de liquen**, apagado.

### Lo que arregló el depurar del 2026-09-13 (tarde)

**Lo que no sube por un REQUISITO va en rojo**, no sólo lo parado por material.
Son tres causas y ninguna se arregla con más jornadas: falta la técnica de
antes, falta una obra del abrigo, o falta material
(`TechTree.frena_un_requisito`). La que va lenta **no** se marca: se arregla
poniendo gente, y en rojo estaría medio árbol. Y el aviso emergente escribe **en
rojo lo que falta** —la técnica que aún no se tiene, la obra sin levantar, el
material—, para lo cual la casilla pinta su aviso en BBCode (`CasillaTecnica`,
`TechGraph.ROJO_DEL_AVISO`): el aviso de serie es texto plano y no admite color.

**La tarjeta de la muerte cuenta quién era.** Decía «Ha muerto Anda · La banda
tiene que decidir qué se hace con el cuerpo» y la causa se quedaba en la
crónica. Ahora dice cómo murió y dónde, qué edad tenía, de qué vivía, lo que
trajo al abrigo en su vida y quién trabajaba a su lado (`Sepulturas.relato`),
y debajo siguen las tres despedidas de siempre. Sale de lo que la partida ya
sabe de esa persona: una necrológica que dijera lo mismo de cualquiera sería
otra vez el mensaje robótico.

**La ficha de una cueva explorada no repite el botón**: enseña lo que hay dentro
y el testimonio en primera persona de quien entró, armado con lo que ELIGIÓ allí
(`Exploracion.descripcion` y `testimonio`, `Repertorio.TESTIMONIOS`). Dos
visitas con decisiones distintas cuentan cosas distintas.

**El filtro de alfileres**, debajo del minimapa (`FiltroDeMarcadores`): todos,
ninguno, o cualquier combinación de cuevas, cimas, pesca, caza, frutos y raíces,
leña y fibra y cantera. No se cierra al marcar, que es lo que permite combinar.

**Y la fila del odre cuenta los VACÍOS**, porque los llenos ya salen como Agua:
el mismo odre estaba en las dos filas. Ver [SISTEMAS.md](SISTEMAS.md) §17.

### Lo que arregló el depurar del 2026-09-14

**«Abrigo 5 de 15, la peor al 78 %» se leía como el aforo de la cueva.**
«Abrigo» es a la vez la ropa y la cueva. La barra dice ahora
`1 °C   8 vestidos para 15, el más gastado al 28 %   ·   cueva 15/18`: los
vestidos con su nombre, y al lado el aforo (`SettlementSim.plazas_abrigo`, 18 de
base y 8 más con paraviento), que era lo otro que el usuario quería ver. El
detalle, en el tooltip. Mirado en pantalla con `TermometroCaptura`: cabe con el
ancho reservado subido de 250 a 400 px.

**«Pintar la pared del fondo» sólo en una cueva explorada con pared pintable**
(`PanelSitios._actions_for`, cuarto argumento). Salía en todas. Y sigue siendo
lo que ya se sabía: el botón **no pinta**, escribe una línea en la consola —la
pintura de verdad va por el relato, ver [SISTEMAS.md](SISTEMAS.md) §13—.

**El filtro de alfileres se recuerda** (`GameState.marcadores_visibles`, y va en
el estado del mapa de [Guardado]). Al ir al mapa regional y volver, volvía con
todo puesto. Medido con `MarcadoresProbe` sobre una copia del guardado del
jugador (jornada 204) salieron además dos fallos más: los alfileres de paraje no
quedaban enlazados al filtro hasta tocar el botón —el minimapa lo cuelga antes de
que existan— y **las cimas no tenían alfiler al retomar** hasta el cierre de la
jornada siguiente. `DemoMain` repinta las cimas y aplica el filtro en cuanto la
partida está puesta.

> **Y lo que el usuario vio —ningún alfiler de los que tenía— sí era un fallo, y
> no lo vio la sonda** (corregido el mismo día, segundo `/depurar`). La caché de
> `Alfiler` es estática y cada textura sale de un `SubViewport` de la escena: al
> cambiar de escena el viewport muere, la textura sigue siendo un objeto válido,
> y los alfileres de lo ya horneado salían en blanco con «Viewport Texture must
> be set to use it» en la consola. Los parajes nuevos de un material sin hornear
> sí se veían, que es exactamente lo que contó. `MarcadoresProbe` contaba
> `visible` —y los alfileres en blanco son visibles— y con la copia del guardado
> cargaba en un proceso limpio, con la caché vacía: el instrumento no podía
> verlo. Ahora la caché guarda el viewport con la textura y lo mira. `TestAlfiler`.

**Las ventanas se rehacen solas, también con el ratón encima** (2026-09-14). Con
el ratón dentro no se repintaban —para no cerrar tooltips ni quitar un botón a
mitad de clic—, y justo tras pulsar algo el ratón sigue ahí: tras «Explorar el
interior» el botón seguía hasta cerrar y abrir. Ahora, con el ratón dentro, la
ventana se rehace aparte y **sólo se cambia si lo que dice ha cambiado**
(`GameUI._repintar_si_cambia` y `firma_de`).

> *Y un tooltip ya no se pierde porque cambie un texto* (`/depurar`, 2026-09-15). Lo de
> arriba lo daba por bueno —«un tooltip se pierde cuando hay algo nuevo que leer»—, y con
> la partida en marcha el porcentaje de una casilla del árbol de técnicas sube cada pocos
> segundos: el aviso se cerraba «al segundo», queja del usuario. Ahora, si la ventana
> rehecha tiene la **misma forma** —los mismos controles en el mismo orden, con el mismo
> color de letra, visibilidad y cursor—, los textos, avisos y botones apagados se
> escriben sobre los controles que ya están (`GameUI.copiar_encima`), y el que está bajo
> el ratón sigue vivo. Si cambia la forma —una fila más, una técnica que se domina y
> cambia de color—, se rehace como antes. `TestRepintado`.

Y las fichas sueltas —lugar, cima,
recurso, terreno, material, utensilio— apuntan cómo rehacerse con `recordar`:
antes no estaban en el repintado.

**Un clic en el minimapa lleva allí la cámara**, y arrastrando la sigue
(`Minimapa.punto_del_valle`).

**De visita en otro mapa**, la barra de velocidad y las teclas no ponen el reloj
en marcha: ver [SPECS.md](SPECS.md) §6.4.

**Las nasas se nombran por el paraje de agua** (`Parajes.place_name_en_el_agua`).
La ventana de técnicas ponía nasas en «la veta de ocre»: `place_name` devolvía el
**primer** paraje de la lista a menos de 320 m, no el más cercano. Ahora es el
más cercano para todo, y para lo que está en el río, el de pesca o marisqueo.

**Coronar una cima da UN aviso**, con cuántos parajes se han descubierto y los
cinco primeros por su nombre (`Cumbres.frase_de_lo_visto`). Salía una tarjeta por
paraje. Ver [SISTEMAS.md](SISTEMAS.md) §4.

### Spec (2026-09-14): priorizar, la cola del taller, los campamentos y el rumbo

Las ventanas que piden tres specs de sistemas del mismo día. **El mecanismo está
allí** —[SISTEMAS.md](SISTEMAS.md) §22, §23 y §4— y aquí sólo dónde se ve y cómo
se toca, para que no haya dos descripciones de la misma regla.

**Prioridades de material.** En la ventana del almacén, cada material que se
recoge lleva su nivel —alta, normal, baja, nunca— en su misma fila, al lado de
la meta: es donde el jugador ya mira qué tiene y cuánto quiere. Un clic cambia
el nivel; el nivel se lee sin abrir nada, con la marca de ocre de siempre para
lo alto y apagado para nunca.

**Prioridades de caza.** En la ventana de caza —o, si no la hay, en la de
trabajos, rama de caza—, una fila por especie que la banda conoce, con su nivel
y la misma marca. Las especies que no se pueden cazar con el utillaje de hoy se
ven igual, apagadas y con el motivo, para que se puedan dejar puestas antes de
tener el arma.

**La cola del taller.** Una ventana propia, **Taller**, con la cola entera en
orden: primero los encargos y luego lo automático, cada entrada con la pieza, la
cantidad que falta, quién la hará y, si no se puede hacer, **por qué**, en rojo
como en la ventana de técnicas. Encima, una fila para añadir un encargo —pieza y
cantidad—. Cada entrada se sube, se baja y se quita con botones en su fila; en
las automáticas, subir y bajar dice en su aviso emergente que cambia la
prioridad de esa pieza, y quitar, que la deja en nunca.

**Los campamentos.** Una lista de campamentos —nombre, gente, jornada, y una
alerta si hay decisión pendiente o hambre—, desde la que se salta a cualquiera.
Y en la ficha de un campamento, **migrar y mover gente**: se marcan las personas
como en la tarjeta de la expedición, se elige el destino entre los sitios
descubiertos, y la ventana dice antes de confirmar las jornadas de viaje y las
raciones que cuesta. Los grupos en camino se ven en la lista, con su destino y
las jornadas que les quedan.

**El rumbo de la expedición.** Se manda desde el mapa regional o desde el borde
del valle: se pincha la dirección, sale una flecha con el pasillo que se va a
recorrer para esas jornadas, y una ficha para elegir quién va y cuántas jornadas,
con lo que cuesta escrito antes de confirmar.

**Criterios de aceptación.**

- Cambiar un nivel en la ventana cambia **el mismo** nivel que usa la
  simulación, y cambiarlo por código se ve en la ventana sin cerrarla: prueba de
  ida y vuelta sobre las dos.
- La cola que pinta la ventana Taller es **la misma lista, en el mismo orden**,
  que la que usa el taller para elegir: prueba que las compara entrada a entrada
  con encargos, automáticas y una entrada bloqueada.
- Añadir, subir, bajar y quitar desde la ventana hacen lo que dice §22: una
  prueba por botón sobre la ventana montada.
- Migrar desde la ficha enseña jornadas y raciones **antes** de confirmar, y son
  las que luego se cobran: prueba.
- La flecha del rumbo cubre **el mismo pasillo** que luego descubre la
  expedición: prueba que compara las dos máscaras.
- Captura con ventana de cada una a 1920×1080 y a 1280×720: ningún control se
  sale de la pantalla (la vara de `RegionCaptura`).

**Fuera de alcance.** Arrastrar entradas de la cola con el ratón —se ordena con
botones—, y atajos de teclado para las prioridades.

#### Lo construido el 2026-09-14: las tres ventanas de las prioridades

De esta spec están hechas **las prioridades y la cola**; los campamentos y el
rumbo siguen pendientes. El mecanismo, en [SISTEMAS.md](SISTEMAS.md) §22.

| Dónde | Qué hay |
|---|---|
| **Almacén**, en la fila de cada material | La marca de nivel al lado de la meta. Un clic la pasa a la siguiente —normal → alta → baja → nunca—, en ocre lo alto y apagado lo bajo y lo apartado. Sólo en **lo que se recoge**: `Tajo.se_recoge` lo saca de las tablas de rendimiento, así que priorizar la carne seca —que no se recoge, se hace— no sale ni como opción |
| **Trabajos**, rama de caza | Una fila por especie del catálogo con su nivel. Las que no se pueden cobrar todavía salen apagadas y con lo que falta (`Fauna.weapon_missing`), y **se pueden dejar puestas igual**: priorizar el uro antes de saber hacer la azagaya es el caso que pedía la spec |
| **Taller**, ventana nueva con su botón | La cola entera en orden: encargos en ocre delante, automáticas detrás, cada una con la pieza, cuántas faltan, quién la hará y —si no se puede hacer— por qué, en rojo. Arriba, la fila de encargar; en cada fila, subir, bajar y quitar |

**Subir y bajar una entrada automática cambia el nivel de la pieza**, y quitarla
la deja en nunca: una sola palanca con dos puertas, no dos reglas. Por eso la
ventana lleva al pie una línea de **apartadas** con un botón que las devuelve a
normal — sin ella, quitar una entrada sería irreversible desde la única ventana
donde se quita. Es lo que la spec no decía y se decidió al construirla.

**Dónde se comprueba, y por qué no en la suite.** Estos criterios son de ventana
montada, y `TestCase` no tiene árbol de escena: un `Button` sin árbol no se
pulsa. Viven en **`scripts/tests/PrioridadesCaptura.gd`**, que monta [GameUI],
aprieta cada botón y mira qué cambió en la simulación —incluida la comparación
entrada a entrada de lo pintado contra `Taller.cola_de_trabajo()`— y de paso
captura a las dos resoluciones. Las reglas de debajo sí están en la suite
(`TestPrioridades`, `TestColaDelTaller`).

> **Dos avisos que costaron dos medidas malas**, y valen para cualquier captura
> futura:
>
> **El proyecto arranca a pantalla completa**, así que `window_set_size` no hace
> nada: hay que poner `WINDOW_MODE_WINDOWED` antes. Sin eso la ventana seguía
> midiendo 3651×2054 y lo que se medía era la pantalla del equipo.
>
> **El alto de una ventana se fija al crearla** (`GameUI._content_height`, 62 %
> del alto de la ventana con tope en 640), así que una interfaz montada a 4K y
> medida luego a 1280×720 «se sale» por algo que no le pasa a quien arranca en
> esa resolución. Se monta la interfaz **a cada resolución**.
>
> Y un hallazgo que **no es de esta spec**: la barra superior arrastra el ancho
> con el que se construyó y se sale de la pantalla al empequeñecer la ventana
> —4 controles a 1920×1080, 18 a 1280×720—. Viene de antes de este trabajo y
> queda para `/depurar`.

#### Lo construido el 2026-09-14: los campamentos

El mecanismo, en [SISTEMAS.md](SISTEMAS.md) §23. El rumbo de la expedición,
debajo.

| Dónde | Qué hay |
|---|---|
| **Campamentos**, ventana nueva con su botón en la barra de abajo (`PanelCampamentos`) | Una fila por campamento vivo: nombre —en ocre el que se mira—, gente y jornada o «abandonado», la alerta en rojo —**decisión pendiente** si la hay guardada, en cola, en pantalla o sin ver; **hambre** si `hambre_severa_racha` pasa de cero, la regla del juego y no un umbral de la ventana—, **Ir** y **Mover gente**. Debajo, los grupos de camino con su destino y las jornadas que les quedan |
| **Mover gente de…**, la ficha | Casillas con las personas, el destino entre lo descubierto y los campamentos vivos, y **antes de mandar** las jornadas y las raciones —o el motivo por el que no se puede, en rojo—, que son `Viaje.lo_que_cuesta`, la misma cuenta que cobra `Viaje.salir`. Si el valle de destino no está preparado, **Preparar el valle** lo descarga ahí mismo (`PreparaValle`, la receta que antes vivía dentro del mapa regional) y **Mandar** sigue apagado hasta que acabe |
| **Tarjeta de decisión** | Con más de un campamento, el titular lleva detrás el nombre del campamento que la levanta |
| **Crónica** del campamento que se mira | Los avisos sin decisión de los campamentos que no se miran, con su nombre delante. Una tarjeta es para lo que se tiene delante |

**Ir** cambia de mapa sin pasar por el regional: la escena guarda, suelta su
campamento —que sigue simulando— y adopta el otro. Una decisión que salta con el
jugador en el mapa regional, donde no hay tarjeta, **para la partida** y sale en
cuanto se entra en cualquier mapa (`Campamentos.sin_ver`).

Se comprueba con **`scripts/tests/CampamentosCaptura.gd`** (con ventana): lo que
la ficha escribe antes de mandar es lo que cobra el viaje, y a 1920×1080 y
1280×720 no se sale nada de las dos ventanas. **La barra de botones de abajo sí se
sale a 1280×720** —ya lo hacía, y ahora tiene un botón más—: va con el fallo de la
barra superior de arriba, para `/depurar`.

#### Lo construido el 2026-09-14: el rumbo de la expedición

El mecanismo, en [SISTEMAS.md](SISTEMAS.md) §4; cómo se ve la niebla, en
[GRAFICOS.md](GRAFICOS.md) §3.

| Dónde | Qué hay |
|---|---|
| **Mapa regional, tecla R** | Se apunta desde el campamento seleccionado, o el primero; el clic da el rumbo y abre la ficha, y cada clic siguiente lo cambia. La flecha dibuja **el pasillo mismo**: franja de su ancho, eje y punta donde se da la vuelta |
| **Valle, botón Rumbo** bajo el de la comarca en el minimapa | El clic en el valle da el rumbo desde la cueva; la flecha va de la cueva a la puerta del valle por la que saldrían, porque el pasillo no cabe. Aquí y no en la barra de abajo, que no cabe a 1280×720; y no con la R, que en el valle cambia la capa del minimapa. ESC cierra la ficha |
| **`FichaDeRumbo`**, la misma en los dos | Desde dónde y hacia dónde, los km de ida, quién puede ir (marcados los tres primeros), jornadas de 4 a 24, lo que se llevan —raciones y leña que no vuelven, pieles que sí— y, en rojo, por qué no se puede. No cuenta nada por su cuenta: todo sale de `Expedicion` |

#### La cueva por dentro, y pintar lo de antes (2026-09-15)

SISTEMAS §13. Tres sitios de la interfaz:

- **La ficha de una cueva** en el mapa de la banda trae siempre **«Entrar a mirar
  la pared»**: apagado y con el motivo mientras no está explorada, y activo en
  cuanto lo está, **sepa o no pintar la banda**. Abre la sala encima del mapa.
- **La ficha de un sitio** en el mapa regional pone debajo un botón **«Entrar en
  …»** por cada cueva explorada del campamento de ese sitio. Sin campamento vivo
  allí no hay botones: lo explorado es de cada campamento.
- **La ventana de Técnicas**, en el bloque del hogar, lista **lo vivido que se
  puede pintar**, del más viejo al más nuevo y con su jornada, con un botón
  «Pintar». Sale **también sin la técnica**, con el botón apagado y el motivo en
  la ayuda; antes el bloque entero se escondía.

#### Dos fallos más, de la noche del 2026-09-14

- **Territorio reventaba** con «Nonexistent function '_materials_of'». Lo rompí
  al depurar la tanda de la tarde; ver ARQUITECTURA §3, la herramienta de
  llamadas huérfanas, que ahora lo caza. La prueba de «cada botón abre su
  ventana» pulsaba Territorio y no lo vio porque, sin parajes conocidos, la
  ventana no llega a pedir los materiales.
- **La chapa del artesano a cero desde la cena hasta el día siguiente.** No era
  su progreso: `Taller.crafting_now` devuelve vacío fuera de horas de taller y
  `SettlementSim.doing_now` seguía hasta la última rama —«lo que llevas en el
  cesto»—, que para un artesano es siempre cero. Ahora el artesano que no talla
  no lleva chapa. `TestJornada`. **Queda**: el peletero que curte piel sin pieza
  encargada tampoco lleva chapa; antes llevaba la del cesto, que era peor.

#### Tres fallos de ventana, del 2026-09-14

Los vio el usuario jugando, y los tres estaban a la vista sin que ninguna prueba
los mirara:

- **La ventana «Taller» no abría.** El botón existía y `GameUI._toggle` no tenía
  su caso: las capturas de §22 la abrían llamando a `show_workshop()` por código.
  Ahora los botones de la barra son una constante (`GameUI.BOTONES_DE_LA_BARRA`) y
  **una prueba los pulsa todos** y exige que cada uno abra su ventana.
- **Las prioridades de caza no se veían.** Las filas de presas se pintaban dentro
  del selector de especialidades de antes de la rejilla de trabajos, al que ya no
  llamaba nadie. Ahora la ventana de Trabajos tiene sección **CAZA** —quién sale y
  a qué pieza se le va antes— y **EXPLORACIÓN** —quién sale—, que también se había
  perdido con aquel selector. Prueba: la ventana pinta una fila por especie.
- **Una línea que aparecía un segundo arriba de la ventana** al añadir un
  trabajador: al rehacerla, los hijos viejos seguían colgados hasta el final del
  fotograma —`queue_free` no los saca—, así que `_heading` creía que ya había algo
  y ponía su filete delante del primer rótulo; el repintado del segundo siguiente
  lo quitaba. `GameUI._clear` ahora los **saca** antes de liberarlos, y la prueba
  lo comprueba.

**Comprobado.** La prueba del criterio está en `TestNieblaRegional`: la niebla que
levanta el pasillo de la flecha y la del pasillo que se lleva la expedición
mandada desde la ficha, **iguales celda a celda**. Y `NieblaCaptura` abre la
ficha en el regional y en el valle a 1920×1080 y 1280×720: nada se sale y la
flecha está dibujada.

> **Un aviso para las capturas, que costó dos corridas**: la ficha se coloca con el
> tamaño de la pantalla al abrirse, y la sonda tiene que **abrirla a cada
> resolución y desactivar el escalado de contenido cada vez** —la misma receta que
> `PrioridadesCaptura`—. Anclada al centro colgando de una capa de lienzo se iba
> por arriba: el anclaje no ve el tamaño de la pantalla.
>
> Y se ve en la captura a 1280×720 del regional: **el panel de rendimiento (F3)
> tapa los botones de la ficha** si está abierto. No es de esta ventana.

### Dos cosas que hoy no se pueden leer

> **Spec (2026-09-12).** La mitad de la temperatura está especificada en
> [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md) §10.1, tanda 1, frente 3;
> la del panel de técnicas **ya está hecha** —ver el bloque de abajo— y se deja
> escrita para que no se rehaga.

**La temperatura no existe en pantalla.** Hay frío —`Inhabitant.cold`, que
enferma y mata— pero no hay grados en ninguna parte, y por eso el sistema de
ropa lleva desde que se construyó sin probarse: no se juega con lo que no se
lee. La magnitud y de dónde sale están en [SISTEMAS.md](SISTEMAS.md) §19; lo
que toca a este documento es que **la barra superior lleve grados** y que se
vea, persona a persona, quién va vestido y con qué desgaste
(`SettlementSim.VESTIDO_WEAR_PER_DAY`).

> **Hecho el 2026-09-12, con una salvedad que hay que saber.** La barra lleva
> los grados del abrigo —`Termometro`, SISTEMAS.md §19— y al lado cómo va de
> abrigo la banda. Van juntos a propósito: el frío sin el abrigo es un número
> con el que no se puede hacer nada, y el abrigo sin el frío es un inventario.
>
> **Se enseña la PEOR pieza, no la media** (`Toolkit.peor_condicion`, nueva). La
> media no se mueve cuando una sola se está acabando, y es ésa la que se va a
> romper: lo que hace falta es que dé tiempo a mandar coser. Se lee
> `1 °C   abrigo 8 de 15, la peor al 35 %`.
>
> **Y la captura sirvió para lo que sirve: el rótulo salía tapado.** En texto
> decía lo que tenía que decir; en pantalla caía **debajo de la barra de
> progreso del invierno** y no se leía. La tira de arriba va sobrada de sitio, y
> como el `ProgressBar` tiene mínimo propio y no encoge, lo que se come el hueco
> son las etiquetas. Se arregló poniendo los grados junto al reloj, a la
> izquierda, con ancho reservado. **Eso no se ve leyendo el código ni pasando
> una prueba** — es exactamente para lo que este apartado manda mirar la
> pantalla.
>
> Tres capturas, con ventana: `21 °C   sin abrigo` en ocre una tarde de verano,
> `1 °C   sin abrigo` en hematites una noche de invierno, y
> `1 °C   abrigo 8 de 15, la peor al 28 %` con abrigo puesto. La sonda es
> `scripts/tests/TermometroCaptura.gd`.
>
> **Dos capturas del par estación/hora y no cuatro con el roquedo**, porque la
> barra enseña los grados **del abrigo**: el par cueva/roquedo no depende de
> dónde mires y no se puede retratar. Esa mitad la cubre `TestTermometro`, que
> comprueba los 1,82 grados de los 280 m de desnivel.

> **Y NO es persona a persona, como pedía este apartado.** No se puede:
> `Toolkit` guarda `pieces: Array[Tool]` **sin dueño**, así que «quién va
> vestido» no tiene respuesta en el modelo de hoy. Repartir el utillaje por
> persona es un cambio de modelo y es lo que la tanda 2 va a necesitar para «el
> vestido como necesidad» — frente 7—. Hasta entonces, cobertura de banda.

**Y cómo se comprueba, porque una lectura sí se puede comprobar:** captura de la
barra con la misma partida en cuatro momentos —mediodía de verano y noche de
invierno, en la cueva y en el roquedo— y los cuatro números distintos y en el
orden que les toca. **La captura necesita ventana**: con `--headless`,
`get_texture().get_image()` devuelve null, así que esto no se comprueba desde una
sonda sin pantalla. Y el desgaste del vestido se ve **antes** de que la pieza se
rompa, que es lo que hace que el jugador mande coser a tiempo.

**Lo que pide la tanda 4 (spec, 2026-09-13)**, con criterios en
[EPOCA_01](EPOCA_01_PALEOLITICO.md) §10.1 → Tanda 4:

- **El mapa regional se juega**: sin sitio de prueba, la ficha de cada sitio
  descubierto con lo que se sabe, el estado de la banda y de los mapas guardados,
  y ventanas más pequeñas que **no salen de la pantalla a 1920×1080 ni a
  1280×720**.
- **La ventana del abrigo**: fuera el botón «usar como taller de talla»; y
  «trasladar el campamento aquí» sólo en cuevas no habitadas. **Hecho
  (2026-09-13)**: el taller es el abrigo donde vive la banda, sin botón, y la
  cueva propia no se ofrece como destino (`PanelSitios._actions_for`). **El
  traslado ya existe** (2026-09-13, `Traslado`): el botón muda a la banda, o
  sale apagado diciendo por qué —no se llega, hay gente de expedición—.
- **El trueque como el almacén**: la banda a la izquierda, los visitantes a la
  derecha, con precios que mueve la relación. **Hecho (2026-09-13)**:
  `PanelTrueque`, botón «Trueque» en la barra de abajo.
- **Una ventana de relaciones** con cada banda conocida y lo que se sabe de ella.
  **Hecho (2026-09-13)**: `PanelRelaciones`, botón «Relaciones».

**El minimapa ya no pinta los `work_sites`** (2026-09-13): eran un punto cian
por actividad, de antes de que los parajes tuvieran sus chapas, y el jugador los
veía como marcadores antiguos que no decían nada.

**«Trabajos» dice quién no está** (2026-09-13, tanda 3). Una sección aparte,
antes de la rejilla, con quien está **de camino al borde del valle**, **fuera
del valle** o **descansando en el abrigo**, y la jornada en que vuelve o se cura.
Quien está fuera no sale en la rejilla —no se le puede dar trabajo hoy—; el
herido sí, porque lo que se le marque es lo que hará al curarse. La lista la
calcula `PanelTrabajos.ausentes`, que no pinta: la ventana sólo la escribe.

**Y «Oficios» enseña las jornadas trabajadas de cada oficio**, con la técnica que
pagan y cuánto pide, leídas del árbol (`TechTree.days_in`). Es la misma cifra que
hace subir las técnicas, no una copia.

**El Shift del almacén**: un clic mueve los máximos de uno en uno y con Shift de
diez en diez (`PanelAlmacen.paso_del_objetivo`). El tope de comida multiplica ese
paso por diez —va de 10 en 10, y de 100 en 100 con Shift— porque en raciones el
paso de uno sería inmanejable.

**La tarjeta de una decisión puede preguntar a quién se manda** (2026-09-13,
tanda 3). Cuando la decisión mueve gente —la expedición de primavera, la cumbre
de verano—, la tarjeta enseña **una casilla por persona que puede ir**, con los
del mínimo ya marcados para que decir que sí sea un clic. Al marcar o desmarcar,
**la tarjeta se rehace entera**: lo que cuesta depende de cuántos van. Y si no
llegan al mínimo, o falta equipo, el botón de confirmar sale **apagado con lo
que falta escrito al lado** —no escondido: así se sabe a por qué ir—. Ver
`Moment.candidatos` y `BarraSuperior._build_moment_card`.

**El panel de técnicas no dice por qué una técnica está parada.** Es la queja
literal del jugador —«hay varias técnicas que no se desbloquean, no sé por
qué»— y tiene tres causas distintas que hoy se ven igual: falta el
prerrequisito, faltan jornadas del oficio, o **falta material**, que es la que
nadie adivina porque `TechTree._ir_pagando` **detiene el progreso** cuando la
despensa no da para seguir practicando. Decir «parada: faltan 6 de asta» vale
para las veinte técnicas del árbol, no sólo para la azagaya. Va por `/depurar`
junto con el resto de los fallos, pero la decisión de diseño —el panel dice la
causa, no sólo el porcentaje— se anota aquí.

> **Y las jornadas no pasan de las que la técnica pide (2026-09-13,
> `/depurar`).** El contador es del oficio y sigue subiendo mientras la técnica
> espera a la que va antes: el cartel de la pasarela decía «82 de 70 jornadas»
> —imposible de leer como otra cosa que «ya debería estar»— y la causa salía
> tres líneas más abajo. Ahora esa línea se corta en lo que pide y, cuando están
> hechas, dice en el mismo sitio qué falta: «70 de 70 jornadas, ya hechas;
> falta: tras núcleo preparado». Con prueba: `TestArbolVentana`.

> **Hecho (2026-09-12, `/depurar`), y la causa dominante no era la que se
> creía.** Medido con `ArbolPasoProbe`, **ninguna técnica estaba parada por
> material**: todas lo estaban por **jornadas**, con el núcleo preparado
> esperando gente en el taller día tras día. O sea que la causa invisible no era
> sólo el material: era el **oficio que nadie practica**, y un «82 %» que no se
> mueve tampoco lo dice. Las cifras, en [ESTADO.md](ESTADO.md) §2 —que es donde
> viven las medidas, y la única copia que hay que tocar si cambian—.
>
> Cómo quedó, y por qué así:
>
> - La causa la decide **un solo sitio**, `TechTree.freno` / `TechTree.causa`.
>   Antes la casilla y el aviso emergente la decidían cada uno por su cuenta, y
>   por eso la casilla decía «43 %» mientras el aviso decía «PARADA por falta de
>   asta».
> - **La casilla dice la causa**, no el porcentaje: «tras talla laminar»,
>   «faltan 43 de manufactura», «parada: falta 6 asta». Con las jornadas se
>   añade el tanto por ciento si cabe en la línea; la cifra que hace falta para
>   decidir es **la que queda**, porque dice a quién mover de oficio.
> - **Llevan marca las que no suben por un REQUISITO** —la técnica de antes, la
>   obra o el material—, un doble filete de hematites. Desde el 2026-09-13: era
>   sólo la de material, y el usuario pidió las tres. La de las jornadas va
>   despacio y no se marca: marcarlas todas sería no marcar ninguna. Son dos
>   decisiones distintas: conseguir lo que falta, o poner gente en el taller.

### Lo que pide la tanda 3 (spec, 2026-09-13)

Criterios en [EPOCA_01](EPOCA_01_PALEOLITICO.md) §10.1 → Tanda 3, frentes 10,
11 y 17.

- **«Trabajos» separa a los que están de los que no.** Hoy quien sale de
  expedición desaparece del mapa y la ventana no dice nada: el jugador no sabe
  quién se ha ido. Los que están fuera —expedición, cumbre— y los heridos van
  aparte, con dónde están y la jornada en que vuelven o se curan.
- **Elegir quién va, en la propia tarjeta.** La decisión de primavera y la de
  verano dejan marcar a las personas. El coste se recalcula con los elegidos, y
  con menos del mínimo no se puede confirmar.
- **Almacén: Shift+Click, de 10 en 10.** El click normal sigue yendo de 1 en 1.
- **Oficios, al día.** Sin textos que describan lo que el juego ya no hace, y
  con las jornadas acumuladas de cada oficio: la misma cifra que usa el árbol
  de técnicas, no una copia.
- **Los marcadores viejos del minimapa** se quitan. Van por `/depurar`, en la
  tabla de dependencias de la spec.

---

## 5. Cómo se implementa sin rehacer nada

`UISkin` se consume hoy en 145 sitios, casi todos como constantes de color
(`UISkin.OCHRE` ×37, `UISkin.INK_FAINT` ×26…). No hay que tocar ninguno.

**`PielDeEra`** es una clase nueva que devuelve la paleta y las cajas de estilo
de una era. `UISkin` deja de tener los colores escritos y **los pide a la piel
que esté puesta**, que arranca en la del Paleolítico:

```gdscript
UISkin.vestir(Site.Era.NEOLITICO)   # y toda la interfaz cambia
```

Las constantes pasan a `static var`, que en GDScript se leen igual desde fuera:
`UISkin.OCHRE` sigue funcionando en los 145 sitios.

La **textura de grano** se genera una vez, como ya hace
[ProceduralTextureGenerator] con las del terreno: no hay pipeline de arte y no
hace falta.

---

## 6. Orden de trabajo

1. `PielDeEra` con la paleta de las cinco eras y las cajas del Paleolítico.
2. `UISkin` delegando, sin tocar los 145 sitios que la consumen.
3. Grano procedural y borde irregular.
4. Las muescas de hambre y cansancio.
5. Las otras cuatro eras, cuando haya era que jugar.

Lo 1–3 es lo que cambia la impresión al abrir el juego; lo 4 es lo que la hace
memorable.

---

## 7. El menú principal, y el modal de ESC (spec, 2026-09-13)

> **Intención del usuario, literal:** «haz un menú principal, Nueva partida,
> cargar. Nueva partida empezará una limpia, cargar abrirá una lista de partidas
> guardadas. Dentro del juego dando a ESC sin tener ventanas abiertas, abre un
> modal con Salir, Cargar, Guardar…».

### 7.1. Qué problema cierra

Hoy el juego **no tiene principio ni salida**. Arranca cayendo directamente en
el mapa regional de Cantabria —`run/main_scene` es `region_map.tscn`—, así que
la primera pantalla de una partida nueva y la de una partida empezada son la
misma, y no hay forma de decir «quiero seguir la de ayer». Y no hay manera de
cerrar el juego desde dentro: se cierra la ventana.

Debajo hay una cosa a medio hacer, y está reconocida en [SPECS.md](SPECS.md)
§6.4: existe el **estado de los mapas** —un fichero por valle visitado,
automático al volver al mapa regional— pero **no existe la partida**. Nada junta
esos ficheros, nada les pone fecha ni nombre, y nada impide que la siguiente
sesión los siga usando como si fueran la misma historia. Aquello se escribió
diciendo que el guardado de partida vendría aparte; esto es ese aparte.

### 7.2. Lo que se pide

**El menú principal es la primera pantalla del juego**, con tres cosas y nada
más: **Nueva partida**, **Cargar** y **Salir del juego**. Lleva la piel de la
era del Paleolítico —la misma de §4—, porque es lo primero que se ve y es donde
la interfaz tiene que decir de qué va esto.

- **Nueva partida** lleva **directo al mapa regional**, como hoy, con una
  partida limpia: ningún valle visitado, nada descubierto de la comarca, y la
  semilla que toque. El nombre no se pide aquí: se pide **la primera vez que se
  guarda**.
- **Cargar** abre **la lista de partidas guardadas**, que también es la lista
  que se abre desde dentro del juego. Cada entrada dice, de un vistazo: el
  nombre que le puso el jugador, dónde está la banda, **el día y el año de la
  partida**, cuántas personas viven, y cuándo se guardó en el reloj de verdad.
  Desde la lista se puede **borrar** una partida, preguntando antes.
- **Salir del juego** cierra la aplicación.

**Dentro del juego, ESC abre un modal** —y sólo si no hay ventana abierta: la
primera pulsación sigue cerrando lo que tengas delante, que es lo que hace hoy—
con estas opciones:

| Opción | Qué hace |
|---|---|
| **Seguir jugando** | Cierra el modal. Va la primera porque es la salida que no rompe nada |
| **Guardar** | Guarda la partida en curso. La primera vez pide nombre; después, sobrescribe la suya |
| **Guardar como…** | Pide nombre siempre, y crea una entrada nueva |
| **Cargar** | La misma lista de partidas |
| **Salir al menú principal** | Deja la partida y vuelve al menú |
| **Salir del juego** | Cierra la aplicación |

**El modal para el reloj mientras está abierto**, como cualquier decisión del
juego (SPECS §4.6): un menú que se consulta con la simulación corriendo es una
forma de perder gente mientras lees.

**Y las dos salidas avisan si hay cambios sin guardar**: si la partida ha
avanzado desde el último guardado, salir pregunta —guardar, salir igualmente, o
volver— y no se sale sin contestar. Perder una partida por pulsar ESC dos veces
es exactamente el susto que este documento ya arregló una vez con el botón de la
comarca.

**Y «salir igualmente» tampoco la pierde** (decisión del usuario, 2026-09-13):
la partida se guarda sola en su ranura, y si nunca tuvo nombre, en una llamada
**«Sin título»**. Aparece en la lista de Cargar como una más. Es lo que permite
que el menú se quede en tres botones —sin «Continuar»— sin que salir sea una
trampa: lo que no se guarda a mano no desaparece, simplemente no tiene nombre.

**ESC hace lo mismo en el mapa regional**, que es la otra pantalla de una
partida en curso. Guardar desde allí guarda lo mismo.

### 7.3. Qué es «una partida guardada»

Decisión del usuario, y es la que da sentido a todo lo demás: **una partida
guarda la partida entera**, no el valle en el que estás.

Eso quiere decir, en contenido: **todos los mapas visitados** con su estado
—cada uno es hoy un fichero `sitio_<id>`—, **lo descubierto de la comarca**, las
**relaciones con los otros grupos**, la era, la cota del mar, cuál es el valle
que se estaba jugando, y la **fecha de la partida** (día y año). Cargar devuelve
al jugador al valle donde lo dejó, con los demás valles como estaban.

- **Sin límite de partidas**, y **el nombre lo escribe el jugador**. Si repite
  uno que ya existe, se avisa y se pregunta antes de sobrescribir.
- **Se puede guardar en cualquier momento**, a media jornada incluida. No hay
  «espera al final del día»: un botón que a veces no hace nada es peor que un
  guardado a media tarde.
- **El autoguardado por mapa se queda**, dentro de la partida abierta: sigue
  siendo lo que hace que salir al mapa regional y volver no pierda el valle. Lo
  que lo deja en disco para otro día es guardar.
- Una partida guardada **de otra versión del juego no se carga a medias**: se
  dice en la lista, se deja borrarla, y no se abre. Es la promesa que
  [SPECS.md](SPECS.md) §6.4 ya hace para el estado de los mapas.

### 7.4. Criterios de aceptación

Medibles, uno por punto. Los tres primeros piden sonda con ventana —hay que
mirar la pantalla—; los demás se comprueban sin abrir el juego.

1. **El juego arranca en el menú.** Al lanzar el ejecutable, la primera pantalla
   tiene los tres botones y **no hay simulación corriendo**: cero personas
   creadas y el reloj de la partida sin avanzar.
2. **Nueva partida deja el disco como estaba.** Empezar una partida nueva y
   jugar diez jornadas **no toca ningún fichero de partida guardada**: las que
   había siguen con el mismo contenido.
3. **ESC no se come el cierre de ventanas.** Con una ventana abierta, ESC la
   cierra y **no** abre el modal; con ninguna abierta, ESC abre el modal. Dos
   pulsaciones seguidas: cierra la ventana, abre el modal.
4. **El modal para el reloj.** Con el modal abierto, la jornada y la hora de la
   simulación no avanzan en diez segundos de reloj real.
5. **Guardar y cargar da la misma partida.** Guardar a media jornada, cerrar el
   proceso, abrir, cargar: **las mismas cinco firmas diarias** que la partida
   que no se cerró, con la misma vara que ya usa `GuardadoProbe` (SPECS §6.4).
   Es el criterio que hace que «se guarda todo» signifique algo.
6. **La partida entera viaja.** Guardar, cargar: el valle de la banda conserva
   su banda, su despensa y sus parajes; lo descubierto de la comarca es lo
   mismo. *(Cambiado el 2026-09-14: decía «visitar dos valles… el primero
   conserva su banda», y desde ese día la banda vive sólo en el primero y los
   demás se visitan sin estado. Ver SPECS §6.4.)*
7. **La lista dice lo que hace falta para elegir.** Cada entrada trae nombre,
   valle, día y año, personas vivas y fecha real, leídos del propio fichero —no
   de un índice aparte que pueda desincronizarse—.
8. **Nombres repetidos y borrado.** Guardar con un nombre existente pregunta
   antes de sobrescribir; borrar pregunta antes; y tras borrar, la entrada
   desaparece de la lista y el fichero, del disco.
9. **Un guardado de otra versión no revienta nada.** Con un fichero de versión
   distinta en la carpeta, la lista lo enseña marcado y no cargable, y el resto
   de la lista sigue funcionando.
10. **Sin guardar, se avisa — y no se pierde.** Con la partida avanzada desde el
    último guardado, «Salir al menú» y «Salir del juego» abren el aviso, y
    cancelar deja la partida exactamente donde estaba. Elegir «salir
    igualmente» **deja la partida en la lista**: en su ranura si ya tenía
    nombre, y en una llamada «Sin título» si no lo tenía.
11. **Las pruebas no tocan las partidas del jugador.** La suite y las sondas
    escriben en su propia carpeta, como ya obliga SPECS §6.4 para los mapas.

### 7.5. Fuera de alcance

- **Opciones y controles en el menú.** El usuario eligió dejar el menú en tres
  botones; la lista de teclas sigue dentro del juego, en su pestaña.
  *(Las opciones vuelven el 2026-09-14, a petición del usuario: ver §8. Los
  controles siguen fuera.)*
- **Continuar de un clic** (retomar la última sin pasar por la lista): se
  propuso y se dejó fuera.
- **Autoguardado de la partida entera cada jornada.** Se propuso y se dejó
  fuera: el autoguardado sigue siendo el de los mapas, dentro de la sesión.
- **Capturas de pantalla en la lista**, partidas en la nube, y varias bandas
  vivas a la vez en mapas distintos —eso último ya estaba aplazado en SPECS
  §6.4—.
  *(Varias bandas vivas a la vez: pedidas el 2026-09-14 y **hechas ese mismo
  día**, ver [SISTEMAS.md](SISTEMAS.md) §23 y la ventana de campamentos en §4.)*
- **Compatibilidad entre versiones del juego**: se rechaza avisando, no se
  migra.
- **Pedir la semilla al empezar.** Se propuso y se dejó fuera; la semilla se
  sigue fijando por entorno para medir (SPECS §7).

Y una restricción que no es de alcance sino de contrato, porque aquí es fácil
saltársela: **no hay autoloads nuevos** (SPECS §2.2). Lo que la partida abierta
necesita saber entre pantallas —qué valle, qué nombre, si hay cambios sin
guardar— tiene que vivir en los que ya existen.

### 7.6. Plan técnico

**Escrito el 2026-09-13 contra el código, no contra la documentación.** Lo que
sigue nombra clases que existen hoy: `Guardado` (`region/`), `GameState`,
`Expedition`, `RegionMap`, `DemoMain`, `GameUI.close_topmost`.

#### La pieza que ya estaba, y de la que cuelga todo

`Guardado.carpeta` es una `static var` —hoy vale `user://mapas`— y existe porque
la suite borró una vez la partida del jugador: las pruebas y las sondas apuntan
a otra ruta. **Ese mismo interruptor es el que convierte «los mapas» en «la
partida»**: si la carpeta de trabajo deja de ser una sola y pasa a ser la de la
partida abierta, el autoguardado por mapa sigue haciendo exactamente lo que hace
hoy, pero dentro de la partida que se está jugando. No hay que tocarlo.

#### Módulos afectados

| Módulo | Qué pasa | Contrato |
|---|---|---|
| `scripts/region/Partida.gd` | **Nuevo.** La partida abierta y el catálogo de guardadas | §4.2 (capa regional). Estático, **sin autoload** (§2.2), como `Guardado` y `GameState` |
| `scripts/ui/MenuPrincipal.gd` + `scenes/menu_principal.tscn` | **Nuevos.** La primera pantalla | §4.7: la interfaz no simula, lee y manda |
| `scripts/ui/ListaDePartidas.gd` | **Nuevo.** La lista, una sola, que usan el menú y el modal | §4.7 |
| `scripts/ui/MenuDelJuego.gd` | **Nuevo.** El modal de ESC, el mismo en las dos pantallas | §4.7 |
| `scripts/DemoMain.gd` | ESC abre el modal si no hay ventana; el reloj para mientras; guardar con la simulación viva; marcar la partida como avanzada | §2.3: sigue siendo el único sitio que cablea |
| `scripts/region/RegionMap.gd` | ESC abre el mismo modal; el botón «volver con la banda» pasa a ser lo que siempre fue —entrar en un mapa de ESTA partida—, no un «cargar» | §4.2 |
| `project.godot` | `run/main_scene` pasa a ser el menú | — |
| `scripts/tests/TestPartida.gd` + `RunTests.gd` | **Nuevo.** Las reglas de arriba, sin abrir ventana | §6.3 |
| `scripts/tests/MenuCaptura.gd` | **Nuevo.** Sonda con ventana: el menú y el modal se ven | §4.8 |
| `scripts/tests/PartidaProbe.gd` | **Nuevo.** Dos procesos: guardar a media jornada, cerrar, cargar, y cotejar firmas | §6.2 |

#### Decisión de arquitectura: carpeta de trabajo, y copia al guardar

Una partida guardada es **una carpeta** en `user://partidas/<id>/` con los mismos
ficheros `sitio_<n>.sav` que hoy, más una cabecera `partida.sav` (versión propia,
nombre, sitio en curso, jornada, año y estación, población y fecha real). Y la
partida que se está jugando vive en **una carpeta de trabajo**,
`user://partida_abierta/`, que es a la que apunta `Guardado.carpeta` mientras se
juega.

- **Guardar** = escribir el mapa en curso desde la simulación viva (el mismo
  `Guardado.guardar` de siempre) y **copiar la carpeta de trabajo** a la ranura,
  con su cabecera.
- **Cargar** = copiar la ranura a la carpeta de trabajo y entrar al mapa que la
  cabecera diga.
- **Nueva partida** = vaciar la carpeta de trabajo y `GameState.begin`, que ya
  es el reinicio completo (era, año, estación, población, descubierto).

Se descartó **autoguardar directo sobre la ranura**: sería el autoguardado de
partida que §7.5 deja fuera a propósito. Con carpeta de trabajo, «guardar» sigue
siendo un acto del jugador y el autoguardado por mapa sigue sosteniendo la
sesión, que es justo lo que se pidió.

**Cambios sin guardar** es una marca, no una comparación de ficheros: se enciende
en `paso_cerrado` (§3.2 — el único límite limpio de la partida) y al autoguardar
un mapa, y se apaga al guardar. Comparar carpetas byte a byte para contestar
«¿has jugado algo?» sería leer disco entero cada vez que se pulsa ESC.

#### Orden de dependencias

1. `Partida` antes que cualquier pantalla: el menú y el modal no son más que
   botones que la llaman.
2. La carpeta de trabajo antes que el menú: mientras `Guardado.carpeta` siga
   siendo `user://mapas`, «nueva partida» pisaría lo de la anterior —que es el
   fallo con el que nació `Guardado.carpeta`—.
3. El modal antes de tocar `RegionMap`: la misma clase se usa en las dos
   pantallas, y escribirlo dos veces sería la regla en dos sitios.
4. La lista, después de `Partida.lista()`: lee cabeceras de disco, no un índice
   aparte que pueda desincronizarse (criterio 7).

#### Riesgos técnicos conocidos

- **Guardar a media jornada.** `Instantanea` recorre el estado vivo y rechaza lo
  que no se puede serializar; el autoguardado de hoy se toma con el reloj parado
  y fuera del paso (`_return_to_region`). El modal **para el reloj antes de
  guardar**, con el mismo gesto: guardar a mitad de un `_advance` es media
  partida (§3.2). Lo que no se puede prometer es que el guardado caiga en
  `paso_cerrado`: cae entre fotogramas, que es donde cae hoy.
- **Copiar carpetas.** Si el juego se cierra a mitad de una copia, la ranura
  queda incompleta. Mitigación: se copia a un nombre temporal y se renombra al
  final; y la lista marca ilegible lo que no traiga cabecera en vez de reventar.
- **Deuda que se hereda:** `Guardado.VERSION` es la de un mapa; `Partida` trae la
  suya. Son dos versiones que pueden discrepar, y la de la partida manda: si el
  mapa de dentro es de otra versión, la partida no carga y se dice.
- **Deuda que se introduce:** el mapa regional deja de ser la primera pantalla,
  así que todo lo que hoy asume «al arrancar, `GameState.begin`» pasa a
  ejecutarse desde el menú. Si algo daba por hecho que existe una partida sólo
  por estar corriendo, sale aquí.

#### Lo que este plan NO toca

El formato de `sitio_<n>.sav`, el recorrido de `Instantanea`, y el autoguardado
al volver al mapa regional. Si el trabajo acaba tocando alguno, es que el plan
estaba mal y hay que decirlo.

### 7.7. Lo que se aprendió al construirlo (2026-09-14)

**Hecho entero.** Las once tareas del bloque están cerradas en el ROADMAP con
lo que midió cada una. Lo que conviene saber si se vuelve aquí:

- **La clase se llama `Partidas`, no `Partida`.** Ese nombre ya era de
  `sim/Partida.gd` —el objetivo de la partida: victoria, derrota y el momento
  que abre todo— y Godot lo canta con un «hides a global script class». El plan
  (§7.6) decía `Partida`; manda el código.
- **Dos carpetas conmutables, no una.** Además de `Partidas.raiz` hizo falta
  `Partidas.borrador`: una prueba que llame a `nueva()` con la carpeta de
  trabajo del jugador puesta **le vacía la partida abierta**, que es el mismo
  accidente que costó una partida el 2026-09-13 por la otra puerta. Hay una
  prueba que comprueba que ninguna de las dos es la del jugador.
- **Una prueba tumbó una decisión el día que se escribió.** El identificador de
  ranura doblaba la eñe en ene, así que «Cueva Peña» y «Cueva Pena» acababan en
  la misma carpeta; ahora sólo se quita lo que un sistema de ficheros no admite.
- **ESC son dos pulsaciones, y es a propósito**: la primera cierra la ventana
  que tengas delante, la segunda abre el menú. Con una sola, salir del juego
  quedaría a un ESC de distancia de mirar el almacén.
- **Guardar a media jornada funciona** y está medido: `PartidaProbe` guarda el
  día 4 a las 13:00, cierra el proceso, carga y da las mismas cinco firmas
  diarias. Lo que lo hace posible es que el modal **pare el reloj antes de
  guardar**: la instantánea se toma entre fotogramas, no a mitad de un paso.
- **El recorrido entero se comprueba solo** (`NuevaPartidaProbe`, con ventana):
  menú → «Nueva partida» → mapa regional → F → valle, pulsando el botón y la
  tecla como los pulsa el jugador. Lo que delata que la partida empezó limpia no
  es un contador: es que **F funda en vez de retomar**, porque `RegionMap` entra
  en el mapa si tiene estado guardado. Y la misma pasada huella las partidas
  guardadas antes y después, que es el criterio 2 —«nueva partida deja el disco
  como estaba»— comprobado byte a byte y no sólo por el número de la lista.
- **El botón del mapa regional se llama «Entrar donde está la banda»**, no
  «Volver con la banda»: con un menú que ya tiene «Cargar», había que separar
  *abrir otra partida* de *entrar en un valle de ésta*.
- **Lo que no se tocó**, como el plan pedía: el formato de `sitio_<n>.sav`, el
  recorrido de `Instantanea`, y el autoguardado al volver al mapa regional. Ese
  autoguardado ahora escribe dentro de la carpeta de la partida abierta sin
  saberlo, porque lo único que cambió es adónde apunta `Guardado.carpeta`.

---

## 8. La configuración (spec, 2026-09-14)

> **Spec**, de `/spec`. Petición del usuario: «quiero, en el menú principal y en
> el menú ESC, una opción de Configuración, con volumen —aunque ahora no sirva
> para nada— y configuración de gráficos con las opciones que tengamos, y una
> selección de resolución además de pantalla completa, ventana y ventana
> maximizada».

### 8.1. Qué problema cierra

No hay dónde tocar nada de la pantalla. La resolución y el modo de ventana los
pone el sistema al abrir, los ajustes de gráficos son números del código —la
niebla volumétrica, el SSAO, los pasos de las nubes—, y los cuatro niveles de
[GRAFICOS.md](GRAFICOS.md) §7 están diseñados y medidos en parte pero **no hay
forma de elegirlos**. Y el que juega en un equipo más flojo no tiene más salida
que aguantar los fotogramas. §7.5 dejó las opciones fuera del menú a propósito;
esto las trae, y lo dice ahí.

### 8.2. Lo que se pide

Un botón **Configuración** en el menú principal y en el modal de ESC, que abre
**la misma ventana** en los dos, con tres partes:

1. **Pantalla.**
   - **Resolución**: las del monitor en el que está la ventana, de la nativa
     hacia abajo, más las habituales que quepan en él.
   - **Modo**: pantalla completa, ventana y ventana maximizada.
   - **Sincronización vertical**: sí o no.
   - **Tope de fotogramas**: sin tope, 30, 60, 120 y 144.
   - **Cambiar resolución o modo pide confirmación**: se aplica, y una cuenta
     atrás de **10 segundos** vuelve a lo de antes si no se confirma.
2. **Gráficos.**
   - **Nivel**: Bajo, Medio, Alto y Ultra, que fijan los ajustes según la tabla
     de GRAFICOS §7.
   - **Debajo, cada ajuste suelto que exista en el juego**: sombras, SSAO,
     niebla volumétrica, nubes volumétricas, escala de render y densidad de
     vegetación. Tocar cualquiera pone el nivel en **Personalizado**.
   - Se aplican **en caliente**, sin reiniciar ni salir de la partida.
3. **Sonido.** Tres barras —**general, música y efectos**— aunque hoy no
   suene nada: el volumen existe y se guarda, y cuando haya sonido ya tiene
   dónde ir.

**Se recuerda entre sesiones**: se guarda en disco al cambiar y se aplica al
abrir el juego, antes de la primera pantalla. **No va dentro de la partida
guardada**: es del equipo, no de la historia.

### 8.3. Criterios de aceptación

- **Los dos menús abren la misma ventana**: prueba que monta las dos y compara
  los controles.
- **Lo que se elige es lo que queda**: cambiar resolución, modo, sincronización,
  tope, nivel, cada ajuste suelto y cada volumen, guardar, y leer lo guardado da
  lo mismo. Prueba sobre el fichero, en su propia carpeta —una prueba no toca
  nunca lo del jugador—.
- **Se aplica al abrir**: una sonda escribe una configuración, arranca el juego
  y comprueba el tamaño de la ventana, el modo, la sincronización y el tope de
  fotogramas del motor. Dos procesos.
- **La cuenta atrás**: sin confirmar, a los 10 s vuelve la resolución y el modo
  de antes; confirmando, se quedan. Prueba con el reloj de la ventana avanzado a
  mano.
- **Un nivel fija sus ajustes**: elegir cada uno de los cuatro deja cada ajuste
  en el valor de la tabla de GRAFICOS §7; tocar uno después pone Personalizado.
  Prueba, una por nivel.
- **En caliente**: con una partida abierta, cambiar el nivel cambia los ajustes
  del entorno de la escena sin recargarla. Prueba sobre la escena montada.
- **Cada nivel cuesta lo que dice**: el tiempo de GPU de cada nivel medido a
  1080p con `GpuProfile` y escrito en GRAFICOS §7, dos corridas por nivel.
- Captura con ventana de la ventana de configuración a 1920×1080 y a 1280×720:
  ningún control se sale.

### 8.4. Fuera de alcance

- **Sonido de verdad**: las barras existen; el sonido, no.
- **Controles y teclas** reasignables: la lista de teclas sigue donde está.
- **Idioma**, tamaño de letra y accesibilidad.
- **Ajustes que no existen hoy en el juego**: los que se añadan después entran
  en la lista cuando existan, no se inventan ahora para rellenarla.
- **Detectar el equipo** y proponer un nivel al empezar.

### 8.5. Plan técnico (2026-09-14)

**Lo que hay hoy en el código, que es lo que manda el plan.**

- **No hay configuración en ninguna parte.** El modo de ventana sale de
  `project.godot` (`window/size/mode=2`, maximizada, con `stretch=canvas_items` a
  1920×1080); la sincronización y el tope de fotogramas sólo los tocan las sondas.
- **Los ajustes de gráficos que existen y se pueden cambiar**:
  - `WorldEnvironmentSetup` (`vista/`, en `scenes/WorldEnvironment.tscn`, que
    montan el valle y el mapa regional): `ssao_enabled`, `ssil_enabled`,
    `volumetric_fog_enabled` y la direccional con `SHADOW_PARALLEL_4_SPLITS`;
  - las nubes, en `shaders/cielo.gdshader` (`pasos_de_nube`, 12; 0 las deja
    planas, «lo que usa el nivel bajo», dice el comentario);
  - la escala de render, en la ventana raíz (`scaling_3d_mode` y
    `scaling_3d_scale`, que `GpuProfile` ya prueba);
  - la vegetación, en `Forest.density`, que **entra al sembrar** el bosque: se
    comprobará si se puede rehacer en caliente.
- **Filas de la tabla de GRAFICOS §7 que no existen como ajuste**: capas y
  muestreo del terreno, resolución de textura, personajes en LOD0. La anisotropía
  es un ajuste del proyecto que sólo entra al arrancar. Las normales y el ORM del
  terreno sí existen en el shader (`use_normal_maps`, `use_orm`), pero no están
  en la lista de ajustes sueltos de la spec.
- **Godot no enumera los modos del monitor**: `DisplayServer.screen_get_size` da
  el nativo y nada más. La lista de resoluciones será la nativa más las habituales
  que quepan, que es lo que la spec pide igualmente.
- Los dos menús existen: `MenuPrincipal` (la escena principal) y `MenuDelJuego`
  (el modal de ESC, en el valle y en el regional).

**Módulos afectados.**

1. **`Configuracion` (`vista/`, nuevo)**: estado estático —como `GameState`, sin
   autoload (SPECS §2.2)— con pantalla, gráficos y volúmenes; los valores de cada
   nivel (**una sola tabla**: la de GRAFICOS §7 escrita en código, y la de la
   documentación la copia); guardar y cargar un `ConfigFile` en
   `user://configuracion.cfg`, con la ruta conmutable para pruebas y sondas —la
   regla del guardado—; y aplicar la pantalla (modo, tamaño, sincronización,
   tope) y los volúmenes a los buses de audio.
2. **Aplicar los gráficos en caliente**: `Configuracion` llama a un grupo de nodos
   (`configuracion_grafica`) y cada uno aplica lo suyo —`WorldEnvironmentSetup` el
   entorno, las sombras y las nubes; `Forest` la densidad o lo deja para la
   próxima siembra—; la escala de render la aplica ella en la ventana raíz.
3. **`VentanaDeConfiguracion` (`ui/`, nuevo)**: la misma ventana para los dos
   menús, con Pantalla, Gráficos y Sonido; la cuenta atrás de 10 s llevada por
   un reloj propio que la prueba avanza a mano.
4. **`MenuPrincipal` y `MenuDelJuego`**: el botón. `MenuPrincipal._ready` aplica
   la configuración guardada antes de pintar nada, una vez por proceso.
5. **`GpuProfile`**: un modo que mide los cuatro niveles y los valores candidatos
   de nubes y vegetación sobre la misma vista a 1080p.

**Decisiones del usuario (2026-09-14), al planear.**

- **Medio es el nivel de «1070 a 60 fps»**: el presupuesto de 16,6 ms a 1080p de
  GRAFICOS §1, que la tabla de §7 ponía en Alto. **Alto va por encima** y **Ultra
  no tiene límite**: cada ajuste al máximo que tenga. Bajo, por debajo de Medio.
- **La resolución sólo vale en ventana**: en pantalla completa y maximizada la
  lista sale apagada, con una nota —se usa la del monitor, y para renderizar a
  menos está la escala de render—.
- **Los mapas de normales y el ORM del terreno entran como dos ajustes más**:
  existen, se aplican en caliente y la tabla les da valor por nivel.
- **Los valores de nubes y vegetación los fijo con la medida delante** y quedan
  escritos con su coste, para cambiarlos si no convencen.
- **Todas las tareas seguidas.**

### 8.6. Lo construido (2026-09-14)

| Dónde | Qué hay |
|---|---|
| **Menú principal y menú de ESC**, botón **Configuración** | Abre `VentanaDeConfiguracion` encima del menú: **la misma ventana**, creada igual desde `MenuPrincipal.abrir_configuracion` y `MenuDelJuego.abrir_configuracion` |
| **Pantalla** | Modo —pantalla completa, ventana, ventana maximizada—; resolución, **apagada fuera de ventana** con una nota que manda a la escala de render; sincronización vertical; tope de fotogramas (sin tope, 30, 60, 120, 144). **Cambiar modo o resolución pide confirmación**: una barra dice «¿Se queda así?» con la cuenta atrás de 10 s y dos botones, y cerrar la ventana sin confirmar vuelve a lo de antes |
| **Gráficos** | Nivel —Bajo, Medio, Alto, Ultra, y Personalizado cuando no coincide ninguno, que no se puede elegir: se llega—, y debajo los ocho ajustes: sombras, oclusión ambiental, niebla volumétrica, nubes, escala de render, vegetación —con la nota de que entra al volver a un mapa—, normales y ORM del terreno. Los valores y lo que cuestan, en [GRAFICOS.md](GRAFICOS.md) §7 |
| **Sonido** | Tres barras —general, música y efectos— sobre tres buses de audio, con la nota de que todavía no suena nada |

**Se guarda al momento** en `user://configuracion.cfg` (`Configuracion`, `vista/`),
fuera de la partida, y **se aplica al abrir el juego** en `MenuPrincipal._ready`,
una vez por proceso. Las pruebas y las sondas usan su propia ruta
(`Configuracion.ruta`, o `CONFIGURACION=` en una sonda de dos procesos).

**Comprobado.**

- `TestConfiguracion`: ida y vuelta de cada valor sobre el fichero; cada nivel fija
  sus ajustes y tocar uno pone Personalizado; Ultra es el máximo de cada ajuste y
  ningún ajuste baja al subir de nivel; la cuenta atrás vuelve a lo de antes a los
  10 s y confirmando se queda —con el reloj de la ventana avanzado a mano—; **los
  dos menús abren la misma ventana**, control a control; los volúmenes llegan a
  sus buses y el tope al motor.
- `ConfiguracionProbe`, dos procesos: se escribe ventana a 1280×720, sin
  sincronizar, tope 30 y Bajo, y el juego abre así.
- `GpuProfile NIVELES=1`: cambiar el nivel con el valle montado cambia oclusión,
  niebla, sombras, normales, ORM y escala **sin recargar la escena**.
- `ConfiguracionCaptura`: las tres pestañas a 1920×1080 y 1280×720, nada se sale.

**Lo que no es como decía la spec, dicho**: la **densidad de vegetación no se
aplica en caliente** —resembrar para el fotograma unos 10 s, medido— y entra al
montar el próximo mapa, con aviso, que es lo que la spec pedía para una fila así.
Y la lista de resoluciones son **la nativa y las habituales que caben**: Godot no
enumera los modos del monitor.

**Orden de dependencias.** `Configuracion` antes que nada; la medida de coste
antes de fijar los valores de nubes y vegetación por nivel; lo que aplica en
caliente antes de la ventana; la ventana antes que los botones y las capturas.

**Riesgos técnicos.**

- **El tamaño de las sombras es un ajuste global del servidor de render**
  (`directional_shadow_atlas_set_size`), no de la luz: cambiarlo en caliente
  rehace el atlas, y hay que ver que no deja un fotograma negro.
- **La vegetación puede no aplicarse en caliente**: si rehacer la siembra cuesta
  segundos, la tabla lo dice y la ventana avisa en vez de fingir.
- **Las sondas que arrancan con la ventana maximizada** —las capturas— pueden
  heredar la configuración del jugador si leen la suya: tienen que apuntar a su
  propia ruta, igual que el guardado.

### 8.7. El selector de árboles (spec, 2026-09-15)

La spec del bosque está en [GRAFICOS.md](GRAFICOS.md) §7.1. Lo que toca a la
ventana de configuración:

- **Un ajuste más en la pestaña de gráficos, «Árboles»**, con **Mínimo, Medio,
  Alto y Ultra**. Mínimo es el bosque de hoy.
- **Cada nivel de gráficos elige su escalón**, y tocarlo suelto deja el nivel en
  Personalizado, como cualquier otro ajuste. Se recuerda entre sesiones.
- **Si no se aplica en caliente, la ventana lo avisa**, igual que la densidad de
  vegetación.

Criterios:

- Prueba: los cuatro niveles ponen su escalón de árboles, y cambiarlo a mano pasa
  a Personalizado.
- Prueba de dos procesos, como `ConfiguracionProbe`: se guarda un escalón, se
  cierra y el juego abre con él.
- `ConfiguracionCaptura`: la fila nueva cabe a 1920×1080 y a 1280×720.

> **Cómo quedó (2026-09-15).** «Árboles» va debajo de la densidad de vegetación, con
> Mínimo, Medio, Alto y Ultra, y la nota de debajo avisa de las dos: «La vegetación y
> los árboles cambian al volver a entrar en un mapa». **Cada nivel pone el escalón de
> su mismo nombre y Bajo el Mínimo** (`Configuracion.NIVELES`); así Medio, el nivel por
> defecto, abre con árboles 3D. Un fichero guardado antes de que existiera el ajuste
> toma el escalón de su nivel guardado —si no, quien jugaba en Bajo abriría en
> Personalizado con árboles de Medio—. Comprobado: `TestConfiguracion` (los cuatro
> niveles, el ajuste suelto a Personalizado, el fichero viejo), `ConfiguracionProbe`
> en dos procesos (Bajo con árboles Alto se guarda y se abre así) y
> `ConfiguracionCaptura` (nada se sale a 1920×1080 ni a 1280×720).

> **La distancia del 3D, en un slider (spec de `/depurar`, 2026-09-15).** Lo pidió el
> usuario: «un slider en la configuración de gráficos que sea el radio al que se dibujan
> los árboles 3D en lugar de los impostores, desde 10 m hasta infinito». Decidido a
> preguntas:
>
> - **Convive con el selector.** «Árboles» sigue eligiendo láminas (Mínimo) o 3D; el
>   slider, «Distancia de los árboles 3D», a qué distancia llega el 3D. **Cada nivel
>   pone la suya** —la de su escalón: Medio 40 m, Alto 70, Ultra 120— y moverlo deja la
>   configuración en Personalizado. Con «Árboles» en Mínimo el slider está apagado.
> - **De 10 m a sin límite.** El último punto es «sin límite»: todo árbol del mapa en
>   3D. **La ventana avisa** de que es para equipos muy potentes o capturas, con el
>   coste medido.
> - **En caliente**, si se puede sin congelar la pantalla: cambiar el radio no cambia
>   qué se siembra, sólo qué se monta.
>
> Criterios: prueba de que los niveles ponen su distancia y moverla personaliza; prueba
> de que sin límite el plan de bloques no pasa de los que tiene el mapa; la fila cabe a
> 1280×720 (`ConfiguracionCaptura`); y el coste de «sin límite» medido con
> `GpuProfile`.
>
> **Cómo quedó.** «Distancia de los árboles 3D» va debajo del selector y de su nota, con
> paradas de 10, 20, 30, 40, 50, 70, 100, 120, 150, 200, 300, 500 y 1 000 m y «sin
> límite» (`VentanaDeConfiguracion.DISTANCIAS_3D`), la cifra al lado, y **se aplica al
> soltar**: aplicar repinta la ventana, y hacerlo a mitad de arrastre borraba el slider
> bajo el ratón. Las distancias de cada nivel pasaron de `Forest.RADIO_3D` a
> `Configuracion.NIVELES` (`radio_3d`), que es donde viven los ajustes; «sin límite» es
> `Configuracion.RADIO_3D_SIN_LIMITE`, 100 km. **En caliente**: el bosque entra en el
> grupo de la configuración y, al cambiar la distancia, desmonta el 3D y lo vuelve a
> montar; el impostor tapa lo que falta mientras. Visto en el juego de verdad con
> `GpuProfile ARBOLES=1 EN_CALIENTE=1`: de 40 a 120 m, de 21 a 69 bloques, asentado en
> 271 ms. Con la distancia grande, **los niveles de detalle se siguen repartiendo sobre
> la distancia del escalón** (`Forest.DETALLE_HASTA`) —sobre 100 km todo el valle
> habría quedado en el nivel más detallado—, y **el plan de bloques no se sale del
> mapa**. `TestConfiguracion`, `TestBosque`, `ConfiguracionCaptura`.
>
> **Pendiente: el coste de «sin límite» no está medido.** La corrida coincidió con una
> partida abierta en la misma máquina y sus tiempos no valen; el aviso de la ventana
> dice que es para equipos muy potentes o capturas, sin cifra todavía. Se mide con
> `GpuProfile ARBOLES=1 ESCALON=1 RADIO=100000`, con la máquina libre.

---

## 9. La pantalla de carga (spec, 2026-09-15)

> **Encargo del usuario (2026-09-15):** «barra de carga al entrar al mapa de
> territorio, y al mapa regional. Básicamente en todos los sitios donde haya que
> cargar algo». Decidido a preguntas: barra con la etapa escrita, con la piel de la
> época; la ventana **nunca congelada más de medio segundo**; en el mapa de la banda, el
> mapa regional y la preparación de un valle nuevo; y **en el mismo trabajo, las dos
> causas ya localizadas de que las cargas tarden** (ESTADO §2).

### 9.1. Qué problema cierra

Las esperas del juego son largas y **mudas**. Medido con `TransitoProbe` (ESTADO §2):
ir al mapa regional cuesta **27,1 s** y volver al de la banda **18,4 s**, y montar el
mapa al empezar o cargar partida, 16-18 s. Todo ese tiempo la ventana está congelada:
no se pinta nada, el ratón no responde y Windows puede marcar el juego como «No
responde». Quien no sabe que carga cree que se ha colgado. Preparar un valle nuevo al
fundar o migrar descarga relieve durante segundos con sólo un aviso de texto encima
de una pantalla parada.

Y dos de esas esperas **no deberían existir la segunda vez**. La malla del mapa
regional se rehace entera en cada viaje (24,6 s de los 27,1) porque nunca encuentra la
caché que se guardó la vez anterior; y al volver al mapa de la banda se siembra otra
vez el bosque entero del mismo valle (11-13 s). El jugador que va y vuelve paga las dos
cada vez.

### 9.2. Lo que se pide

**La pantalla de carga**

1. **Una pantalla de carga** con la piel de la época (§2: la interfaz es un objeto de
   la época; en el Paleolítico, piel, ocre y carbón): **una barra** y **una línea que
   dice qué se está haciendo**, en el lenguaje del juego y no del motor —«Levantando el
   relieve», «Sembrando el bosque», «Despertando a la banda»—, no «cargando recursos».
2. Sale en:
   - **el mapa de la banda**: nueva partida, cargar partida, volver del mapa regional y
     llegar a otro valle al migrar;
   - **el mapa regional**: ir desde el mapa de la banda o desde el menú;
   - **preparar un valle nuevo**: la descarga y limpieza del relieve al fundar o
     migrar, que hoy es un aviso de texto.
3. **La ventana nunca se congela más de medio segundo** mientras carga: la barra se
   mueve, la ventana se puede mover y el sistema no la da por colgada.
4. **La barra dice la verdad**: no retrocede nunca, llega al final cuando se puede
   jugar —no antes ni con la pantalla quieta después—, y avanza en proporción al
   tiempo que de verdad cuesta cada etapa, no a partes iguales.
5. **La partida no avanza mientras carga**: ni la hora ni la simulación corren detrás
   de la pantalla, y lo que se carga es exactamente lo mismo que hoy.

**Las cargas más cortas**

6. **El segundo viaje al mapa regional no rehace la malla**: la encuentra hecha.
7. **Volver al mapa de la banda del mismo valle no vuelve a sembrar el bosque**, si no
   ha cambiado nada de lo que decide la siembra —el valle y la densidad de vegetación—.
   Si la densidad cambió en la configuración, se siembra de nuevo, como hoy.

### 9.3. Criterios de aceptación

**La pantalla**

- **Sale en los cuatro caminos al mapa de la banda, en los dos al regional y al
  preparar un valle**: una sonda recorre cada camino y comprueba que la pantalla de
  carga se ve (con ventana, captura) y que desaparece cuando el mapa está jugable.
- **Ningún cuadro de la carga pasa de 500 ms**, en ninguno de esos caminos, medido
  cuadro a cuadro con reloj de pared en el equipo de medida. **Cifra de la spec**: si
  alguna etapa no puede partirse por debajo —una llamada del motor que no se trocea—,
  se dice cuál y cuánto, con la medida, y se pregunta.
- **La barra no retrocede y no se queda quieta más de 2 s** en ningún camino: la sonda
  registra su valor en cada cuadro.
  > *Salvo esperando a la red al preparar un valle* (decisión del usuario, 2026-09-15):
  > ahí no hay nada hecho que contar —Overpass contesta entero al final, 43 s una vez—,
  > y la barra se detiene cerca del final de su etapa en vez de fingir avance. **La
  > pantalla se mueve siempre** con una señal de vida, un brillo que recorre la barra.
- **Cuando la barra está a medias, ha pasado entre el 35 % y el 65 % del tiempo de la
  carga**, en cada camino. **Cifra de la spec**, para que «avanza en proporción» sea
  comprobable.
- **Cada etapa tiene su texto**, y ninguno nombra clases, ficheros ni términos del
  motor. Prueba que recorre las etapas.
- **Cabe y se lee** a 1920×1080 y a 1280×720, captura.
- **Lo que se carga es lo de hoy**: la partida que resulta de cargar un guardado con
  pantalla de carga tiene la misma huella que sin ella, y la hora y la jornada al
  terminar de cargar son las de antes de empezar. Prueba.

**Lo que tarda**

- **Partir la carga en trozos no la alarga más de un 10 %** respecto a hoy en el viaje
  en frío, medido en los dos sentidos con `TransitoProbe`, dos corridas. **Cifra de la
  spec**: si pasa, se dice con la medida y se pregunta.
- **El segundo viaje al mapa regional no regenera la malla** —el registro de la sonda
  dice que la encontró— y **la ida baja al menos los 24,6 s que costaba**, medido en el
  mismo proceso: la caché que importa es la de la partida, y una sonda limpia no la
  ve (ARQUITECTURA §5.1).
- **Volver al mismo valle no siembra**: la siembra no se ejecuta en la vuelta —contador—
  y la vuelta baja lo que costaba sembrar, medido igual. Y **el bosque de la vuelta es el
  mismo**: mismos árboles, mismos sitios, prueba.
- **Cambiar la densidad y volver sí siembra**, y con la densidad nueva. Prueba.
- Las cifras nuevas de ida y vuelta se escriben en ESTADO §2, sustituyendo las de hoy.

### 9.4. Fuera de alcance

- **Otras cargas**: entrar en la sala de la cueva (0,4-0,6 s) y abrir ventanas no
  llevan pantalla. Lo que dure menos de un segundo no la necesita, y taparlo haría
  parpadear la pantalla.
- **Cancelar una carga** o volver atrás desde la pantalla.
- **Cargar en segundo plano mientras se juega**, precargar el mapa regional o
  cualquier otra carga anticipada. Las cargas siguen siendo cuando se piden.
- **Acelerar el viaje en frío** más allá de lo que den las dos cachés: la malla
  regional la primera vez y la siembra del primer montaje siguen costando lo que
  cuestan.
- **Consejos, datos de la época o arte** en la pantalla de carga: sólo barra y etapa.
- **Los objetos que quedan vivos al cambiar de escena** (`SCRIPT ERROR` en cada viaje,
  ESTADO §2): es otro fallo, con su propio arreglo, aunque se vea en los mismos viajes.
- **Música o sonido** durante la carga.

### 9.5. Plan técnico (2026-09-15)

**Módulos.**

| Qué | Dónde | Contrato |
|---|---|---|
| **La pantalla**: barra, etapa escrita, piel de la época; cuelga de la raíz del árbol para sobrevivir al cambio de escena | nuevo, `scripts/ui/PantallaDeCarga.gd` | vista (SPECS §4.7); estado fuera de escena como `Campamentos` (SPECS §2.2) |
| **El reparto**: etapas con peso medido, avance, y `ceder()` —esperar un cuadro cuando se agota el presupuesto del cuadro— | nuevo, `scripts/ui/Carga.gd` | vista; no toca la partida |
| **El mapa de la banda, montado por etapas** | `scripts/DemoMain.gd` (`_ready` → montaje asíncrono con `montado`) | cableado (SPECS §2.3) |
| **El bosque, sembrado por trozos** —y lo demás que la tarea 1 mida por encima de 500 ms— | `scripts/vista/Forest.gd` (`_sow`, `_levantar_lejos`), y lo que salga | vista |
| **El mapa regional, montado por etapas**, con la malla en frío fuera del hilo principal | `scripts/region/RegionMap.gd`, `scripts/mundo/MallaDelTerreno.gd`, `scripts/mundo/TerrainGenerator.gd` | región / mundo (SPECS §4.2, §4.3) |
| **Preparar un valle, con progreso**: la descarga deja de bloquear | `scripts/region/PreparaValle.gd`, `scripts/region/DEMImporter.gd`, `scripts/ui/PanelCampamentos.gd` | región |
| **Quién abre la pantalla**: todos los caminos que cambian de escena en el juego | `MenuPrincipal.gd`, `MenuDelJuego.gd`, `RegionMap.gd`, `DemoMain.gd` | vista |
| **El reloj parado mientras carga** | `scripts/sim/RelojDeLaPartida.gd`, `scripts/sim/SettlementSim.gd` (`_process`) | paso fijo (SPECS §3.1) |
| **La caché de la malla regional** | `MallaDelTerreno._cache_base_path`, `RegionMap._setup_terrain` | mundo |
| **La siembra que no se repite** | `Forest.gd` (caché estática por valle y densidad) | vista |
| **Las sondas**: cuadros, barra y caminos | nueva `scripts/tests/CargaProbe.gd`, `TransitoProbe.gd` | ARQUITECTURA §5.1 |

**Decisiones de arquitectura, sólo las que la spec obliga a tomar.**

1. **Sin pantalla abierta, el montaje es de un tirón, como hoy.** `Carga.ceder()` no espera nada si no hay pantalla. Así las más de cien sondas que cambian de escena y esperan cuadros fijos siguen montando igual, y **la huella con y sin pantalla es la prueba de que se carga lo mismo** (criterio de §9.3). Lo abren los caminos del juego, antes de `change_scene_to_file`.
2. **Una escena montada lo dice**: `montado` —propiedad y señal— al terminar la última etapa. Con pantalla, la pantalla se cierra ahí; las sondas de la tarea 9 esperan a eso y no a que exista la cámara.
3. **El presupuesto de cuadro es 250 ms**, la mitad del criterio, para dejar sitio a lo que el motor hace entre cuadros. Decisión; se ajusta con la medida.
4. **Los pesos de las etapas salen de medir** (tarea 1) y se escriben con su medida. La barra avanza por etapa y, dentro de las largas —sembrar, la malla, descargar—, por su propio contador.
5. **Lo que no se pueda trocear se saca del hilo principal**: la malla regional en frío (24,6 s, con `generate_lods` del motor dentro) se calcula en un `WorkerThreadPool` y sólo se cuelga del árbol en el principal. Lo que tampoco quepa así, se mide y se pregunta.
6. **Mientras la pantalla está abierta, el reloj no acumula tiempo**: el delta de esos cuadros se tira, no se guarda para ponerse al día al terminar (SPECS §3.1).
7. **La caché de la malla regional se llama por el relieve de origen y el mar de la partida**, no por la ruta de una copia: la copia lleva encima el relieve de la plataforma, que depende del mar (`RelieveDeLaPlataforma`).
8. **La siembra se guarda en una estática** con la huella de lo que la decide —relieve, recuadro, densidad, bocas y la versión de sus reglas—. Vive lo que vive el proceso: la vuelta la usa, abrir el juego otra vez no.

**Orden de dependencias.** Medir primero, que dice qué hay que trocear; la pantalla y el reparto antes que nadie los use; el reloj parado antes de repartir nada entre cuadros; el mapa de la banda y el regional después; las dos cachés son independientes; y las sondas al final, sobre todo montado.

**Riesgos técnicos.**

- **Montar la escena en varios cuadros deja ver el mundo a medias**, y cualquier `_process` que dé por hecho que todo existe puede fallar en esos cuadros. La pantalla tapa la vista; los `_process` del mapa se paran hasta `montado`.
- **Los objetos que quedan vivos al cambiar de escena** (ESTADO §2) pueden tocar la escena nueva a medio montar. Fuera de alcance, pero si se cruzan con esto, se dice.
- **Crear mallas en un hilo**: `ArrayMesh` y `ImporterMesh` fuera del árbol se pueden construir en otro hilo; colgar nodos, no. Si alguna llamada del motor no es segura en hilo, la malla en frío se queda en el principal y se mide cuánto congela.
- **La descarga depende de la red** (MDT del IGN): la medida del progreso de preparar un valle se hace con un sitio sin descargar, una vez.
- **Memoria de la siembra guardada**: un millón de árboles. Se mide y se dice.

### 9.6. Cómo quedó (2026-09-15)

**Lo que cuesta hoy, medido antes de tocar nada** (`CargaProbe`, con ventana): cada
camino es **un solo cuadro congelado** —nueva partida 28,5 s, fundar 26,3, ida al
regional 27,3, retomar 19,3—. En el regional pesan la composición de alturas
(13,1-13,3 s) y trocear la malla (7,6-7,9); en la banda, sembrar el bosque (14,0 s) y
cargar el bosque de lejos (3,2-4,8). Todo son bucles o cargas, ninguna llamada del motor
de varios segundos.

**La pantalla.** Una piel tensada en el centro de un fondo de piel en sombra, con el
título en ocre, la barra —una tira más oscura que se llena de ocre, como las casillas
del árbol de técnicas— y la etapa en hueso. La etapa iba en carbón, que es lo
secundario en el resto de la interfaz, y en la captura no se leía: aquí es lo único
que se lee mientras se espera. Cuelga de la raíz del árbol y se come el ratón. La
barra la lleva `RepartoDeCarga`: avanza por el peso medido de cada etapa, no retrocede,
y una carga encadenada —preparar un valle y montarlo— reparte lo que falta en vez de
empezar de cero. `Carga.ceder` gasta hasta **250 ms** de trabajo por cuadro (decisión:
la mitad del criterio) y, sin pantalla abierta, no espera nada.

**El mapa de la banda, por etapas** (tareas 3 y 4). Siete etapas con su peso medido
—levantar el relieve, dibujar los alrededores, despertar a la banda, poner a la vista lo
que da el valle, sembrar el bosque, plantar el bosque de lejos, encender el hogar— y
**ningún cuadro de más de 500 ms** al fundar ni al retomar (peores 454 y 366 ms,
`CargaProbe`), con la barra sin retroceder, sin quedarse quieta más de 0,6 s, y a media
barra con el 50-57 % del tiempo pasado. **Cargan antes que sin pantalla**: retomar 14,0
s frente a 19,3 y fundar 17,7 frente a 26,3, porque las cargas de recursos van a un hilo.
**La partida que sale es la misma** con pantalla y sin ella (`CargaHuellaProbe`). Mientras
carga, el reloj de la partida no anda y la escena está parada; al terminar dice
`montado`. Donde la barra no tiene contador propio avanza por el tiempo transcurrido
contra lo medido, sin pasar del 95 % de la etapa. Quien lee o copia una partida abre la
pantalla **antes** de leer: leída antes, el primer cuadro pasaba de medio segundo.

**El mapa regional, por etapas** (tarea 5). Cinco etapas —leer la costa y los montes,
modelar las alturas, tender la comarca, pintar la época, marcar los lugares— y, con ellas,
**los cuatro caminos sin un cuadro de más de 500 ms** (`CargaProbe`: nueva partida 418 ms
de peor cuadro, fundar 465, ida al regional 383, retomar 388), la barra sin retroceder, sin
quedarse quieta más de 1,1 s, y a media barra con el 48-55 % del tiempo pasado. El
regional carga ahora en 19-20 s; antes eran 27 con la ventana congelada. La generación del
relieve recibe el mismo `ceder` que la simulación, y dice cuándo pasa de las alturas a la
malla para que la barra cambie de etapa: cambiando por tiempo, a media barra había pasado
el 70 % de la carga. La frontera de la época se trazaba dos veces al montar y ahora una;
la escena se lee del disco en un hilo antes de cambiar a ella.

**Preparar un valle nuevo** (tarea 6). La receta entera va en un hilo y la pantalla
enseña por dónde va: descargar el relieve, quitar la obra moderna, trazar los ríos,
descargar el relieve de alrededor, guardar. Medido con red preparando la Cueva de la
Lastrilla: **96 s sin un cuadro de más de 33 ms**. Casi todo es esperar a la red, y ahí
**la barra se detiene** cerca del final de su etapa en vez de fingir avance —Overpass no
dice nada hasta que contesta entero, 43 s una vez—, mientras **un brillo recorre la barra
sin parar** para que se vea que no está colgado. Decisión del usuario; el criterio de
§9.3 lo recoge. Lo abre el mapa regional al fundar, y la carga del mapa que viene detrás
sigue en la misma barra; y la ficha de un campamento al migrar, con el reloj parado
mientras tanto.

**El segundo viaje al regional** (tarea 7). La malla del regional se hacía sobre una
copia del relieve —con las lomas de la plataforma encima— y una copia no tiene ruta, así
que su caché no se buscaba nunca. Ahora se llama por el relieve de origen, el mar de la
época y las lomas, y **la ida con la malla en caché tarda 1,4-1,7 s**. Con una carga tan
corta, lo que pasa antes de que la escena exista —leerla del disco, guardar la partida al
salir— ya es media carga, y cuenta en la primera etapa; sin contarlo, a media barra había
pasado hasta el 77 % del tiempo. Con caché, la barra usa sus propios pesos medidos: la
malla se lee en un cuadro y la barra salta al acabar de leer el relieve, que cae a media
carga (45-63 % en los cuatro caminos, dos corridas).

**Volver al mismo valle** (tarea 8). La siembra del bosque se guarda con una huella de
todo lo que la decide —el relieve, la humedad y los ríos tal cual, el recuadro, las
bocas, la densidad y la versión de las reglas— y la vuelta con la misma huella reutiliza
los árboles: son los mismos, en los mismos sitios, y otra densidad vuelve a sembrar
(`TestBosque`). Se guarda sólo la del último valle, 35 MB, y vive lo que el proceso.
Como la etapa de sembrar pesaba sus 9,6 s, la barra la da por hecha con lo que tardó
(`Carga.dar_por_hecha_la_etapa`); si no, se quedaba atrás y saltaba al final.

**Medido todo** (tarea 9, con ventana y sin ella, dos corridas de cada):

| Camino | En pie | Peor cuadro | Barra a medias con… |
|---|---|---|---|
| Nueva partida → regional (malla en caché) | 2,3-2,4 s | 339-342 ms | 62-63 % del tiempo |
| Fundar (el valle ya preparado) | 18,6-18,8 s | 370-373 ms | 54 % |
| Ida al regional (malla en caché) | 1,6 s | 345-346 ms | 47-48 % |
| Retomar el campamento (siembra guardada) | 5,5-5,6 s | 348-363 ms | 42-44 % |
| Preparar un valle, con red (tarea 6) | 96 s | 33 ms | — (esperas de red) |

Ningún cuadro de más de 500 ms, la barra sin retroceder y quieta como mucho 0,8 s. En
el viaje en frío (`TransitoProbe`, sin ventana), la pantalla alarga la carga un 3-5 %
frente a la misma carga de un tirón; el segundo viaje, 1,3 s de ida y 5,4 de vuelta
(ESTADO §2). **Al retomar, el peso del bosque de lejos se quedó corto**: era de antes de
cargar sus modelos en un hilo —2,6 s contra 3,6-3,9 medidos— y, sin sembrar delante, a
media barra había pasado sólo el 36 % del tiempo; con el peso medido, el 42-44 %. La
pantalla se lee a 1920×1080 y a 1280×720 (`CargaCaptura`). La huella de la partida con y
sin pantalla (`CargaHuellaProbe`) se midió en la tarea 4 y no se repitió: lo tocado
después no toca la partida.

**Lo que no se hizo.** Los `SCRIPT ERROR` de los objetos que quedan vivos al cambiar de
escena siguen igual (fuera de alcance, ESTADO §2). Queda en disco una caché vieja del
regional con el nombre de antes (`data/dem/cantabria_region_mesh_r1025.res`, 106 MB) que
ya no lee nadie; es un fichero ignorado por git y se puede borrar.

