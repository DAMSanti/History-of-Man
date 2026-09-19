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
| **Cambia con la spec del 2026-09-15** ([SISTEMAS.md](SISTEMAS.md) §4) | El rumbo deja de ser libre: **ocho rumbos**, sólo los que tienen algo al alcance, iguales en los dos mapas. **El botón del valle lleva al regional** con la ficha abierta, y está **apagado** —con el motivo— sin tres pieles curtidas, raciones, leña o gente para la expedición más corta. Sin la R en el regional para un rumbo libre. Visto por el usuario el 2026-09-14: el botón «Rumbo» del valle no hacía nada visible |
| **`FichaDeRumbo`**, la misma en los dos | Desde dónde y hacia dónde, los km de ida, quién puede ir (marcados los tres primeros), jornadas de 4 a 24, lo que se llevan —raciones y leña que no vuelven, pieles que sí— y, en rojo, por qué no se puede. No cuenta nada por su cuenta: todo sale de `Expedicion` |

> **Construido el 2026-09-16: las dos filas de arriba de «Mapa regional» y «Valle» ya no
> valen.** Lo de hoy:
>
> | Dónde | Qué hay |
> |---|---|
> | **Mapa regional, tecla R** | Abre la ficha para el campamento seleccionado, o el primero. **No hay clic de rumbo**: el clic vuelve a ser elegir un sitio |
> | **Valle, botón «Rumbo»** bajo el de la comarca en el minimapa | **Apagado**, con el motivo en la ayuda, mientras no pueda salir la expedición más corta —tres personas y cuatro jornadas— o haya una fuera (`Expedicion.por_que_no_sale`). Al pulsarlo sale a la comarca con la pantalla de carga y el regional abre la ficha de ese campamento (`Expedition.ficha_de_rumbo_desde`) |
> | **`FichaDeRumbo`** | Arriba, **la rosa de los ocho rumbos**: apagados los que no tienen nada al alcance y marcado el elegido; de entrada, el primero que se ofrece. Sin ninguno, lo dice y no manda. Abierta desde el valle, **«Mandar y volver al valle»** y **«Mandar y quedarse»**; con la R, «Mandar» y se queda en el regional (decisión aceptada por el usuario) |
> | **`FlechaDeRumbo`** | El pasillo elegido como antes, y **tenue, el eje de los demás rumbos** que se ofrecen, hasta donde llegarían en 24 jornadas. En el valle ya no se dibuja |
> | **Los avistados** | Marcas pardas apagadas, aunque estén bajo la niebla; no se pinchan ni salen en listas (`RegionMap.sitios_que_se_dibujan`) |
>
> Comprobado con `TestExpedicion` (la ficha, sin ventana) y `RumboProbe` por el camino del
> juego: el botón apagado sin pieles y encendido con ellas, el regional con la ficha abierta
> viniendo del valle y los avistados dibujados sin poderse pinchar, y «Mandar y volver al
> valle» de vuelta en el valle con tres fuera. `NieblaCaptura` ya no captura la ficha en el
> valle.

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
> **«Sin límite» se quitó el 2026-09-15: rompía el motor** (`/depurar`). Medido con la
> máquina libre (`GpuProfile ARBOLES=1 ESCALON=1 RADIO=100000`), Godot dejó de crear
> los grupos de árboles 3D —«Element limit reached», más de 7 000 errores y 5,2 GB de
> RAM—: cada bloque de 32 m monta uno por especie, variante y nivel de detalle, y el mapa
> son 16 384 bloques. **El slider acaba en 1000 m** (`Configuracion.RADIO_3D_MAXIMO`),
> que monta, y **el aviso lleva la cifra**: el bosque pasa de 3 ms a 34-67 ms y el mapa
> tarda un minuto en montarse (GRAFICOS §7.1). Una configuración guardada con «sin
> límite» se lee como 1000 m (`TestConfiguracion`). Lo que pedía el usuario —el mapa
> entero en 3D— necesita agrupar los bloques lejanos, y va por `/spec` (ROADMAP).
> Decisión suya, con la medida delante.

### 8.8. El agua y el clima en la ventana (spec, 2026-09-15)

Lo que se ve, en [GRAFICOS.md](GRAFICOS.md) §7.3 y §7.4. Aquí, dónde van:

- **«Agua»**, un selector con **Bajo, Medio, Alto y Ultra**. Cada nivel general pone el
  suyo —el de su mismo nombre— y moverlo deja la configuración en Personalizado.
- **«Clima»**, un interruptor. **Encendido en Medio, Alto y Ultra; apagado en Bajo.**
  La ayuda dice que apagado el tiempo sigue haciendo lo que hace, sólo que no se ve.
- Los dos en la pestaña **Gráficos**, con los demás; si alguno se aplica al montar el
  mapa y no en caliente, lo dice su nota, como la vegetación y los árboles.

Criterios: prueba de que cada nivel pone su agua y su clima y de que moverlos
personaliza; un fichero de configuración de antes, sin estos ajustes, abre en su
nivel y no en Personalizado (como con los árboles); la pestaña cabe a 1280×720
(`ConfiguracionCaptura`).

> **«Agua», construido el 2026-09-16.** El selector va detrás de la distancia del 3D, con
> los cuatro niveles, y **se aplica en caliente**: cambiarlo con el valle abierto tarda lo
> mismo que montarlo con ese nivel. Lo comprueba `TestConfiguracion`. Lo que pone cada
> nivel, en GRAFICOS §7.3, «Cómo quedó». **«Clima» sigue pendiente**, con su spec en
> GRAFICOS §7.4.

> **«Clima», construido el 2026-09-16.** Casilla «Clima: lluvia, nieve y niebla» en
> Gráficos, antes de los mapas de normales, **en caliente**: apagada en Bajo y encendida en
> Medio, Alto y Ultra. Su ayuda dice que apagado el tiempo sigue haciendo lo que hace. Un
> fichero de antes abre en su nivel. `TestConfiguracion`. Lo que se ve, en GRAFICOS §7.4.

### 8.9. Jugabilidad: el aviso de paraje se puede apagar (spec, 2026-09-19)

#### Qué problema cierra

Cada vez que la banda termina de conocer un sitio y le pone nombre, sale una
tarjeta arriba: «Un sitio con nombre». Una está bien —encontrar algo tiene que
notarse, es la razón de ser de un `Moment` de hallazgo— pero **no salen de una
en una**. Medido: **11 parajes en ocho jornadas** con la cola de reconocimiento
vacía ([ESTADO.md](ESTADO.md) §5, «Cuarto: depurar»), o sea casi tarjeta y media por jornada,
y en una primavera de exploración van seguidas. La tarjeta tapa el valle, se
acumulan en cola y se aprende a cerrarlas sin leerlas, que es justo lo que
`Moment` dice que no debe pasar.

Ya se arregló una mitad del problema y esto es la otra. El 2026-09-14 el usuario
pidió «un solo mensaje diciendo se han descubierto X parajes» y coronar una
cumbre dejó de sacar una tarjeta por sitio: hoy bautiza de golpe y lo cuenta en
la tarjeta de la cumbre. **Lo que quedó fuera de aquel arreglo fue el otro
camino**, el de quien vuelve de batir el monte, que sigue sacando los parajes de
la cola a razón de unos pocos por vuelta y **uno a uno, cada uno con su
tarjeta**. La queja de ahora es sobre ése.

El arreglo no es callar el hallazgo: es **darle al jugador el interruptor**. A
quien juega su primera partida el aviso le enseña que la exploración produce
algo; a quien va por el tercer año le sobra. Eso no lo decide el diseño, lo
decide quien juega, y hoy la ventana de configuración no tiene dónde preguntarlo
porque sólo habla del equipo —pantalla, gráficos, controles y sonido— y esto es
del juego.

#### Lo que se pide

1. **Una quinta pestaña, «Jugabilidad»**, en la misma ventana de configuración
   que abren el menú principal y el modal de ESC. Nace con **un solo ajuste**: es
   el sitio donde irán los que vengan, no una pestaña que haya que rellenar.

2. **«Avisar de los parajes descubiertos», un interruptor.** Encendido, todo
   sigue como hoy. Apagado, **no sale la tarjeta de «Un sitio con nombre»** —ni
   la de este campamento ni la de ninguno—.

3. **Sólo calla la tarjeta.** El hallazgo se sigue apuntando en los otros dos
   canales, exactamente igual que hoy:
   - la **Crónica**, en Hallazgos, con su línea «La banda ya conoce bien un
     sitio y le ha puesto nombre: …»;
   - el **diario** de quien lo encontró.

   Y el paraje sigue apareciendo en el mapa del valle y en la ventana de
   Parajes, con su alfiler y su ficha. El ajuste cambia **cómo se entera** el
   jugador, no **qué sabe**: un hallazgo que se consulta en vez de anunciarse.

4. **La ayuda del control lo dice**, con esas palabras: que el paraje se sigue
   descubriendo y sigue en la Crónica y en el mapa, y que lo único que se apaga
   es el cartel. Sin esa frase el interruptor se lee como «no descubrir
   parajes», que es otra cosa y da miedo tocarlo.

5. **Encendido por defecto.** Se conserva el juego de hoy: el primer paraje
   sigue siendo un momento para quien no ha jugado nunca, y quien se canse lo
   apaga. Una partida nueva no cambia de comportamiento por esta spec.

6. **Se recuerda entre sesiones**, en el mismo fichero de configuración y con la
   misma regla que el resto de §8: es de quien juega, no de la partida, así que
   **no va dentro del guardado**. Una configuración escrita antes de que este
   ajuste existiera abre con el aviso **encendido**, sin quedarse en un estado
   raro —la misma regla que los árboles y el clima en §8.7 y §8.8—.

7. **Se aplica en caliente.** Apagarlo con una partida abierta deja de sacar
   tarjetas desde el siguiente paraje que se bautice, sin recargar el mapa ni
   salir al menú.

8. **Lo que ya estaba en cola, se va.** Si al apagarlo hay tarjetas de paraje
   esperando turno —la cola de momentos de `GameUI`—, desaparecen. Apagar el
   aviso y aun así tragarse seis carteles sería el mismo problema con un paso
   más.

#### Criterios de aceptación

- **El interruptor se guarda y vuelve.** Ponerlo en apagado, guardar, leer el
  fichero y abrirlo da apagado; lo mismo con encendido. Prueba sobre el fichero,
  **en su propia carpeta** —una prueba no toca nunca lo del jugador—.
- **Por defecto, encendido.** Una configuración recién creada, y también un
  fichero escrito sin esta clave, abren con el aviso encendido y con el nivel de
  gráficos que tuvieran: leer un fichero viejo **no** deja la configuración en
  Personalizado.
- **Apagado no sale la tarjeta.** Con el aviso apagado, bautizar un paraje
  —construido el estado, no simulado un año— no añade ningún momento de hallazgo
  de paraje a la cola de `GameUI`. Con el aviso encendido, el mismo estado añade
  exactamente uno por paraje. Una prueba, los dos casos.
- **Y los otros canales no se enteran.** En esa misma prueba, con el aviso
  apagado la Crónica gana su línea de Hallazgos y el diario de quien lo encontró
  su apunte, **igual que con el aviso encendido**: se comparan las dos corridas y
  la Crónica sale idéntica. Es el criterio que distingue «callar la tarjeta» de
  «callar el hallazgo», y sin él la implementación puede cortar por donde no es.
- **El resto de tarjetas sigue saliendo.** Con el aviso de parajes apagado, una
  cumbre, un percance, la berrea, un relato y una decisión levantan su tarjeta
  como siempre. Prueba, una por clase. Las decisiones **no se pueden apagar** ni
  por accidente: paran el reloj y piden respuesta.
- **La cumbre sigue contando los suyos.** Con el aviso apagado, la tarjeta de la
  cumbre sigue diciendo «Se han descubierto N parajes: …». Ese aviso es de la
  cumbre, no del paraje, y ya es uno solo. Prueba.
- **En caliente.** Con una partida montada, apagar el interruptor y bautizar un
  paraje acto seguido no saca tarjeta, sin recargar la escena. Prueba sobre la
  escena montada.
- **La cola se vacía.** Con tres tarjetas de paraje encoladas y una de percance
  detrás, apagar el interruptor deja la cola con la de percance y ninguna de
  paraje. Prueba.
- **Cabe.** Captura con ventana de la pestaña Jugabilidad a 1920×1080 y a
  1280×720 (`ConfiguracionCaptura`): ningún control se sale, y la ayuda del
  interruptor se lee entera en las dos.

#### Fuera de alcance

- **Un interruptor por cada clase de aviso** —cumbre, percance, berrea, relato,
  cueva—. Se apaga el que molesta, que es el de parajes. Si otro llega a
  molestar, entra entonces en esta misma pestaña, con su spec.
- **Apagar decisiones.** Una decisión para el reloj y pide una respuesta: sin
  ella la partida no avanza. No se ofrece.
- **Un estado intermedio**: ni «uno resumido al cierre de la jornada» ni «sólo
  los que estén a más de X metros». Lo primero es otro aviso que hay que
  diseñar; lo segundo pide un umbral que nadie ha medido, y aquí no se inventan
  números.
- **Cambiar cuántos parajes se bautizan**, o el ritmo al que salen de la cola
  (`Reconocimiento.DE_UNA_VUELTA`). Esta spec no toca la simulación: sólo si se
  cuenta o no.
- **Silenciar la Crónica o los diarios**, hoy o con otro ajuste. Son el sitio
  donde queda lo que se deja de anunciar; vaciarlos convertiría el interruptor en
  una pérdida de información.
- **Llevar a Jugabilidad ajustes que ya viven en otro sitio** —el filtro de
  parajes, el de marcadores, la velocidad del reloj—. La pestaña nace con uno.
- **Que el ajuste viaje en la partida guardada.** Es del jugador, como todo §8.

#### Plan técnico (2026-09-19)

**Dónde se calla la tarjeta, que es la decisión que manda.** En la **vista**, no en la
simulación: `BarraSuperior._on_moment`, que es quien recibe `moment_raised` y encola. Así el
criterio «sólo calla la tarjeta» no depende de acordarse de nada — la Crónica y el diario se
escriben en `Reconocimiento._contar_los_nuevos` **antes** de levantar el momento, y por ahí
no pasa el interruptor. Callarlo en la simulación —no levantar el `Moment`— habría dejado el
corte a un paso de los otros dos canales, y además metería `Configuracion` dentro de
`scripts/sim/`, que no la conoce (SPECS §4).

**Cómo se reconoce una tarjeta de paraje.** Por `Moment.Kind.HALLAZGO`, que **es** exactamente
eso: comprobado, `Moment.found()` se llama desde un único sitio —el bautizo de un paraje— y
los trece `Moment.new()` del juego fijan todos su `kind`. `summit()` sale de `found()` pero se
pone `CUMBRE`, así que la tarjeta de la cumbre —con su «se han descubierto N parajes»— no se
ve afectada. **Riesgo que se hereda**: `HALLAZGO` es el valor *por defecto* del enum, así que
un `Moment.new()` futuro que olvide su `kind` quedaría mudo sin que nadie lo note. Queda
dicho aquí y en el comentario del filtro.

**Módulos afectados.**

| Qué | Dónde | Contrato |
|---|---|---|
| El ajuste y su fichero | `scripts/vista/Configuracion.gd` | §8: es del jugador, no de la partida; **no** va en el guardado |
| La pestaña y el interruptor | `scripts/ui/VentanaDeConfiguracion.gd` | SPECS §4, `ui/` sólo lee y manda |
| El filtro y el vaciado de la cola | `scripts/ui/BarraSuperior.gd` | ídem |
| Pruebas | `scripts/tests/TestConfiguracion.gd`, `TestMomentos.gd` | |
| Captura | `scripts/tests/ConfiguracionCaptura.gd` | con ventana, 1920 y 1280 |

**Decisiones que la spec obliga a tomar.**

- **La ayuda es una línea visible, no un tooltip.** El criterio pide que se lea entera en una
  captura a dos resoluciones, y un tooltip no sale en una captura. `_casilla` hoy sólo pone
  `tooltip_text`; hace falta una variante que además escriba la frase debajo del interruptor.
- **Una sección propia en el fichero**, `[jugabilidad]`, al lado de `pantalla`, `graficos`,
  `teclas` y `sonido`. No entra en `AJUSTES` —esa lista es la de gráficos y la lee
  `_nivel_que_encaja()`—: meterlo ahí dejaría la configuración en «Personalizado» por apagar
  un aviso, que es justo lo que el criterio prohíbe.
- **El aplicar en caliente reutiliza `Configuracion.GRUPO`.** Es el grupo de «a quien le
  cambia la configuración», aunque se llame `configuracion_grafica`; la barra superior se
  apunta a él y vacía la cola en `aplicar_configuracion()`. **Se corrige el comentario del
  grupo**, no su nombre: renombrarlo es otro trabajo.
- **De la cola se van las que esperan turno, no la que está en pantalla.** Es lo que dice la
  spec, y además una tarjeta ya visible ya se ha leído.

**Orden de dependencias.** El ajuste primero —sin él no hay qué preguntar—, luego el filtro y
el vaciado, luego la pestaña, y la captura al final, que es lo único que necesita ventana.

#### Lo construido (2026-09-19)

Las seis tareas, y el plan aguantó entero salvo un detalle que se cuenta abajo.

- **El ajuste** es `Configuracion.aviso_de_parajes`, sección `[jugabilidad]` del mismo
  fichero, **encendido por defecto**. Fuera de `AJUSTES` a propósito: apagar un aviso no
  puede dejar la configuración en Personalizado, y una prueba lo fija con un fichero en
  Bajo al que se le quita la clave.
- **La tarjeta se calla en la vista**, `BarraSuperior._sale_la_tarjeta`, por
  `Moment.Kind.HALLAZGO`. La Crónica y el diario se escriben antes de levantar el momento,
  así que el criterio «sólo calla la tarjeta» **se cumple por construcción**: la prueba
  compara las dos corridas y la Crónica sale idéntica, con su línea y el nombre del sitio.
- **En caliente**, por el grupo de la configuración. **Aquí se cayó una premisa del plan**:
  el plan decía que la barra superior se apuntaría al grupo, y `BarraSuperior` es un
  `RefCounted` — no es un nodo y no tiene grupos. Se apunta `GameUI`, que sí está en el
  árbol, y le pasa el aviso a la barra.
- **La cola se vacía** de las que esperan turno. La que está en pantalla se queda: ya se ha
  leído.
- **La pestaña** nace con un interruptor y **la ayuda como línea visible** debajo, en letra
  menor. Decisión del usuario, y obligada por el criterio: un tooltip no sale en una
  captura, así que no se podría comprobar que quepa.

Medido con `ConfiguracionCaptura`: **«Jugabilidad: nada se sale»** a 1920×1080 y a
1280×720, y la ayuda entra entera en una línea en las dos. Suite: 1 744 pruebas, 9 451
comprobaciones, con cuatro nuevas en «Aviso de parajes» y dos en «Configuración».

**La deuda que se hereda, dicha**: `Moment.Kind.HALLAZGO` es el valor **por defecto** del
enum. Hoy los trece `Moment.new()` del juego fijan su `kind` —comprobado—, pero uno futuro
que lo olvide se quedaría mudo sin que nada falle. Está avisado en el comentario del filtro.

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
el viaje en frío (`TransitoProbe`, sin ventana), la pantalla alarga la carga un 0-7 %
frente a la misma carga de un tirón; el segundo viaje, 1,3 s de ida y 2,8 de vuelta
(ESTADO §2, corregido el mismo día: la primera medida de la vuelta, 5,4 s, era de una
sonda que no viajaba como el juego). **Al retomar, el peso del bosque de lejos se quedó corto**: era de antes de
cargar sus modelos en un hilo —2,6 s contra 3,6-3,9 medidos— y, sin sembrar delante, a
media barra había pasado sólo el 36 % del tiempo; con el peso medido, el 42-44 %. La
pantalla se lee a 1920×1080 y a 1280×720 (`CargaCaptura`). La huella de la partida con y
sin pantalla (`CargaHuellaProbe`) se midió en la tarea 4 y no se repitió: lo tocado
después no toca la partida.

**Lo que no se hizo.** Los `SCRIPT ERROR` de los objetos que quedaban vivos al cambiar de
escena (fuera de alcance, ESTADO §2) se miraron después, en `/depurar`: eran de la sonda,
no del juego. Queda en disco una caché vieja del
regional con el nombre de antes (`data/dem/cantabria_region_mesh_r1025.res`, 106 MB) que
ya no lee nadie; es un fichero ignorado por git y se puede borrar.

---

## 10. Buscar un paraje, ver una pasarela y saber qué da una técnica (spec, 2026-09-15)

> **Spec escrita con `/spec` el 2026-09-15**, a partir de tres quejas del `/depurar` de
> la noche del 2026-09-14 que no eran fallos sino cosas que faltaban (ROADMAP). Las
> decisiones las tomó el usuario con preguntas; están marcadas donde salen. El efecto
> del núcleo preparado y de la talla laminar es un cambio de la partida, no sólo de la
> ventana: su mecanismo está en [EPOCA_01_PALEOLITICO.md](EPOCA_01_PALEOLITICO.md) §7.

### 10.1. Qué problema cierra

Tres ventanas que responden a medias a la pregunta con la que se abren.

- **Parajes** es una lista ordenada por cercanía y nada más. Con decenas de parajes,
  «¿dónde hay caza a menos de un kilómetro?» obliga a leerla entera, y un paraje con
  varios oficios sólo enseña el icono del principal: el recodo donde también se saca
  raíz no se encuentra buscando raíz.
- **Obras** trata las pasarelas aparte, como un párrafo de texto encima de todo, sin
  el botón «ver» ni la ficha que tienen las trampas, las nasas y las obras del
  abrigo. Una pasarela armada no se puede ir a mirar desde la ventana, que es para lo
  que existe la ventana (§4, «Obras»).
- **El tooltip de una técnica** dice qué es, cuánto falta y de qué cuelga, pero no
  **qué cambia en el juego** al tenerla. El jugador elige hacia dónde practicar sin
  saber qué gana. Y al mirarlo apareció algo peor: **el núcleo preparado y la talla
  laminar no hacen nada** salvo abrir otras técnicas, aunque su descripción promete
  «menos desperdicio de sílex» y «más filo por kilo». La descripción mentía.

### 10.2. Lo que se pide

**Parajes: filtrar por oficio y por distancia.**

- **Cinco filtros de oficio** —caza, pesca, marisqueo, recolección y materia prima—
  que se encienden y se apagan, de uno en uno o varios. **Un paraje sale si allí se
  hace cualquiera de los oficios encendidos**, aunque no sea el que le da nombre e
  icono (decisión del usuario). Con todos apagados o todos encendidos, salen todos.
- **Tramos de distancia al campamento**: hasta 500 m, hasta 1 km, hasta 2 km, o todos
  (decisión del usuario). Uno a la vez.
- La lista **sigue ordenada por cercanía**, dice cuántos parajes enseña de cuántos
  conoce, y si el filtro deja la lista vacía lo dice con esas palabras, no con la
  ventana en blanco.
- **Se recuerdan mientras dura la partida** (decisión del usuario): cerrar y abrir la
  ventana los conserva; cargar otra partida o abrir el juego otra vez vuelve a «todo».
  No se guardan en disco.
- Los parajes que esta estación no se pueden trabajar siguen saliendo con su marco
  rojo: filtrarlos no es parte de esto.

**Obras: las pasarelas como las demás obras** (decisión del usuario).

- **Una fila «Pasarela de troncos»** en la lista, con cuántas hay y el botón «ver», en
  su familia como el resto.
- **«ver» abre la ficha de cada una** con ◀ ▶, «llevar la cámara» y «◀ todas las
  obras», igual que una trampa: dónde está —el nombre del paraje, como hoy—, cuánto
  mide y la jornada en que se remató.
- **La que se está armando sale también**, como una ficha más de la misma fila, con
  las jornadas puestas de las que pide y la leña que gastará al rematarla.
- **Si no hay ninguna, ni armada ni en marcha, la fila no sale** y queda la nota de
  por qué no se arma ninguna, la que hay hoy, con las mismas causas en el mismo orden.
- El párrafo aparte de hoy desaparece: una sola forma de enseñar una obra.

**El tooltip de cada técnica: su efecto, y lo que supone hoy para la banda.**

- **En todas las técnicas del árbol**, aprendidas o no (decisión del usuario): las que
  faltan dicen qué darán, que es lo que ayuda a decidir hacia dónde practicar.
- **El efecto, con la cifra que usa el juego.** Qué cambia —«la azagaya multiplica
  por 1,25 la caza menor y por 1,60 la mayor», «la nasa pesca sola, sin nadie en el río»— y qué abre:
  piezas que se pueden hacer, trampas que se pueden poner, maneras de pescar, otras
  técnicas. **Ninguna cifra se escribe a mano en el texto**: sale del mismo sitio del
  que la lee la partida, para que no puedan decir cosas distintas.
- **Lo de hoy, sólo en las aprendidas: el uso de ahora** (decisión del usuario). Lo
  que la partida ya sabe sin contadores nuevos: cuántos de la banda la usan hoy,
  cuántas piezas de lo que abre hay en el utillaje, cuántas trampas o nasas hay
  puestas. **Lo que no se pueda contar sin inventar, no sale**; no se promete «lo que
  ha ganado la banda desde que la aprendió».
- **La descripción no promete lo que la técnica no hace.** Si una descripción y el
  efecto no casan, se arregla la descripción o el efecto, no se deja.

**El núcleo preparado y la talla laminar, con efecto de verdad** (decisión del usuario,
con las cifras delante; son una decisión, no una medida):

- **Núcleo preparado: filos repetibles.** Lo que se talla en piedra —lasca, raedera,
  buril, punta— sale con **calidad no menor de 0,9**. Hoy es 0,7 + 0,6 × el
  rendimiento de quien talla, así que un novato saca piezas de vida corta; con el
  núcleo, el novato talla como alguien a media pericia y el experto sigue igual.
- **Talla laminar: la mitad de piedra.** Cada pieza tallada gasta **0,5 de piedra o de
  sílex en vez de 1**. Donde se nota es en el sílex, que no hay en el valle y llega por
  trueque (SISTEMAS §5). Leroi-Gourhan da unas diez veces más filo por kilo que la
  lasca; aquí se toma mucho menos para no romper la escalera.
- Su tooltip dice las dos cifras como cualquier otra técnica.

### 10.3. Criterios de aceptación

**Parajes**

- **El filtro de oficio mira todos los oficios del paraje**: con un paraje de caza que
  también tiene recolección, encender sólo recolección lo enseña. Prueba sobre lo que
  pinta la ventana, con parajes construidos.
- **Los tramos cortan donde dicen**: un paraje a 499 m sale en «hasta 500 m» y uno a
  501 no. Prueba.
- **Todo apagado es todo**, y **un filtro que no deja nada dice que no hay parajes que
  lo cumplan** y cuántos se conocen. Prueba.
- **Se conservan al cerrar y abrir la ventana, y vuelven a «todo» al cargar otra
  partida.** Prueba.
- **Cabe a 1280×720**: la fila de filtros no saca nada de la ventana, captura.

**Obras**

- **Con dos pasarelas armadas y una en marcha, la fila dice 3 y la ficha recorre las
  tres** con ◀ ▶, cada una con su sitio y su medida, y la de en marcha con sus
  jornadas. Prueba con pasarelas construidas, sin simular hasta que la banda las arme.
- **«llevar la cámara» lleva la cámara a la pasarela**, a su primera celda. Prueba.
- **Sin pasarelas, no hay fila y sí la nota**, con la misma causa que da hoy para cada
  estado —sin técnica, sin cruce, sin exploradores, sin leña—. Prueba por causa.
- **No queda el párrafo aparte.** Prueba de que no se escribe dos veces.

**El tooltip de las técnicas**

- **Las dieciocho técnicas tienen efecto escrito**: una prueba recorre el árbol y
  ninguna sale sin su línea de efecto.
- **Las cifras del tooltip son las del juego**: una prueba cambia la cifra de una
  técnica en el sitio del que la lee la partida y el tooltip cambia con ella. Al
  menos una técnica de cada oficio.
- **Lo de hoy cuenta lo que hay**: con tres azagayas en el utillaje y dos cazadores,
  el tooltip de la azagaya dice 3 y 2. Estado construido, prueba.
- **Las no aprendidas no dicen «lo de hoy»**, y sí su efecto. Prueba.
- **Se lee**: captura de un tooltip con efecto y lo de hoy, a 1280×720, sin salirse de
  la pantalla.

**El núcleo y la laminar**

- **Con el núcleo, ninguna pieza tallada sale por debajo de 0,9 de calidad** aunque la
  talle alguien con rendimiento 0,2; sin él, sale 0,82 como hoy. Prueba.
- **Con la laminar, tallar diez piezas gasta 5 de piedra, o 5 de sílex**; sin ella, 10.
  Prueba.
- **El resto de piezas no cambia**: el asta, la fibra y la piel gastan lo mismo con y
  sin las dos técnicas. Prueba.
- **La partida se mueve y se dice cuánto**: el cambio de gasto de piedra y sílex en
  un tramo de taller construido, antes y después, en ESTADO §2. No es un criterio de
  balance que cumplir, es una cifra que dejar escrita.

### 10.4. Fuera de alcance

- **Contar lo ganado por cada técnica** desde que se aprendió —piezas cazadas gracias
  al propulsor, pescado de la nasa—. Decisión del usuario: «lo de hoy» es el uso de
  ahora.
- **Filtrar por material**, por alcanzable hoy o por nombre, y **ordenar Parajes** de
  otra manera que por cercanía.
- **Guardar los filtros en disco** o en la configuración.
- **Cambiar qué hace cualquier otra técnica**, sus jornadas o su coste de aprendizaje:
  sólo el núcleo y la laminar ganan efecto. Si el tooltip destapa otra que no hace lo
  que dice, se apunta y va por `/depurar`.
- **Pinchar una pasarela en el mundo** para abrir su ficha: hoy no se pincha, y sigue
  sin pincharse.
- **Otras obras nuevas en Obras** y cualquier cambio a cómo se arma una pasarela
  (SISTEMAS §20).

### 10.5. Plan técnico (2026-09-16)

**Lo que hay hoy en el código, que es lo que manda el plan.**

- **Parajes** lo pinta `PanelSitios.show_places`: ordena `sim.parajes.list` por cercanía y
  saca una fila por paraje (`_place_row`). No hay filtros de ninguna clase. Cada `Paraje`
  ya sabe **todos** sus oficios (`Paraje.activities`, `Paraje.serves`), que es lo que el
  filtro necesita.
- **Obras** lo pinta `PanelObras`: las familias con su botón «ver» y una ficha con ◀ ▶ y
  «llevar la cámara» (`_ficha`, `_boton_volver`), **y las pasarelas aparte**, en
  `_pasarelas`, como párrafo, con su explicación de por qué no hay ninguna
  (`_por_que_no_hay_pasarela`). Los datos están en `Pasarelas.puentes` —las celdas de agua
  que salva cada una— y en `Pasarelas.obra` y `jornadas_puestas` para la que se arma.
- **El tooltip de una técnica** lo compone `TechGraph._tooltip`: nombre, descripción,
  jornadas del oficio, coste de aprendizaje y qué la frena. **No dice qué hace**.
  `PanelTecnicas._improvement_factor` ya lee un efecto de caza de `Hunting.MEJORAS`: ése es
  el patrón, leer la cifra de donde la lee la partida.
- **La calidad de una pieza** sale de `Tool.make`: `0.7 + pericia * 0.6`. **El gasto de
  materia** lo paga `Taller` con `Tool.recipe(kind)`, prefiriendo sílex a piedra cuando lo
  hay. Ni el núcleo ni la talla laminar tocan nada de esto.

**Módulos afectados.**

1. **`FiltroDeParajes` (`ui/`, nuevo)**: qué oficios están encendidos y qué tramo de
   distancia, y `pasa(paraje, casa)`. **Estático**, porque tiene que sobrevivir a cerrar la
   ventana pero no a cargar otra partida, que lo vacía; no se guarda en disco (decisión del
   usuario). Sin nodos: se prueba sin ventana.
2. **`PanelSitios`**: la fila de filtros —cinco oficios y cuatro tramos—, el recuento «de N
   que se conocen» y el aviso de lista vacía.
3. **`PanelObras`**: la familia «Pasarela de troncos» como una más, con su ficha; y fuera el
   párrafo aparte. La nota de por qué no hay ninguna se queda tal cual, sin tocar sus causas.
4. **`TechTree`**: `efecto(tech)` —qué cambia y qué abre, **leyendo las cifras de donde las
   lee la partida**— y `lo_de_hoy(tech, sim)` —el uso de ahora, sólo con lo que ya se puede
   contar—. `TechGraph._tooltip` las pinta. **Ninguna cifra se escribe a mano.**
5. **`Tool` y `Taller`**, que es lo único que cambia la partida: con el núcleo preparado, lo
   tallado en piedra sale con calidad no menor de 0,9; con la talla laminar, cada pieza de
   piedra o sílex gasta la mitad. Las dos preguntan por la técnica al `TechTree` de la
   simulación, que es quien sabe lo aprendido.
6. **`VentanasCaptura` (`tests/`, nueva)**: las dos capturas que la spec pide a 1280×720
   —Parajes con filtros y un tooltip con efecto y lo de hoy—.

**Decisiones que tomo, y se dicen.**

- **El filtro vive en la interfaz**, no en `Parajes`: es una preferencia de lectura, no
  estado de la partida, y por eso no entra en la instantánea ni en el guardado.
- **La calidad mínima del núcleo se aplica al fabricar** (`Tool.make` recibe si hay núcleo),
  no al usar la pieza: así una pieza tallada antes de aprenderlo sigue siendo lo que era.
- **La laminar abarata piedra y sílex, y nada más**: el asta, la fibra y la piel se pagan
  igual, como pide la spec.

**Orden de dependencias.** El filtro antes que la ventana que lo usa; el efecto de las
técnicas antes que «lo de hoy», que se apoya en la misma tabla; el núcleo y la laminar antes
de medir el gasto; y las capturas al final.

**Qué contrato cambia**: ninguno nuevo. El núcleo y la laminar cambian la partida —la
calidad y el gasto—, así que **las firmas de las sondas se desplazan una vez** y se dice.

**Riesgos técnicos.**

- **El efecto de una técnica sale de dieciocho sitios distintos** (caza, pesca, trampas,
  taller, obras). Si alguna no tiene una cifra que leer, el tooltip lo dirá con palabras y
  se apuntará como deuda, en vez de inventar un número.
- **Al escribir los efectos puede aparecer otra técnica que no hace lo que promete**: se
  apunta y va por `/depurar`, como dice la spec; aquí sólo cambian el núcleo y la laminar.
- **El gasto de piedra cae a la mitad con la laminar**: la piedra deja de ser un freno y el
  taller puede acelerar. Se mide el tramo y se escribe en ESTADO; no se reequilibra nada.

### 10.6. Cómo quedó (2026-09-16)

**Parajes.** Dos filas de botones debajo del encabezado: los cinco oficios, que se
encienden sueltos, y los cuatro tramos de distancia, de los que manda uno. El
encabezado pasa a «1 DE 13 PARAJES CONOCIDOS» en cuanto algo filtra, y con la lista
vacía lo dice con palabras —«ninguno de los 13 parajes conocidos pasa este filtro»—
en vez de quedarse en blanco. Quién sale y en qué orden lo decide
`FiltroDeParajes.filtrar`, no la ventana: por eso se comprueba sin montar ningún nodo
(`TestParajes`, nueve pruebas nuevas). El filtro **es estático y vive en la interfaz**
—no entra en la instantánea ni en el guardado— y se vacía solo al cambiar de partida,
que es lo que mira `FiltroDeParajes.para(sim)` comparando de quién era.

**Obras.** Las pasarelas son una familia más de la lista —«Pasarela de troncos», con
cuántas hay y su botón «ver»— y su ficha tiene ◀ ▶, «llevar la cámara» y el sitio, la
medida y la jornada en que se remató. La que se está armando sale como una ficha más,
con las jornadas puestas y la leña que gastará. El párrafo aparte desapareció; queda
una sola línea, la de por qué no se arma ninguna, y sólo cuando no hay ninguna. Para
poder decir la jornada hubo que **apuntarla**: `Pasarelas.rematadas`, una lista
paralela a `puentes`, porque cada entrada de `puentes` son las celdas que salva y eso
lo leen la rejilla, el andador y la vista. Que las dos listas no se descuadren al
llevarse una riada una pasarela es una prueba de `TestPasarela`.

**El tooltip de una técnica.** Debajo de la descripción va **qué da**, y en las
aprendidas, **qué supone hoy**. Ejemplos tal cual salen:

- Azagaya de asta: «Lo que se cobra en una jornada: multiplica por 1,25 la caza menor,
  y multiplica por 1,60 la caza mayor. Deja fabricar: azagaya. Y abre el paso a: ojeo,
  propulsor. Hoy: 3 azagaya en el utillaje.»
- Foso: «Trampa nueva, foso: cobra una pieza cada 9,0 jornadas y aguanta 70 puesta.
  Cae en ella: jabalí, ciervo, corzo.»
- Arpón de asta: «Abre arpón de asta: 105 de pescado por jornada, donde a mano se
  sacan 12.»
- Talla laminar: «Cada pieza de piedra o de sílex cuesta la mitad: una lasca pasa de
  1,0 a 0,5 de materia.»

**Ninguna de esas cifras está escrita en el texto**: `TechTree.efecto` las lee de
`Trap.INFO`, `Hunting.MEJORAS`, `Fishing.CATALOGUE`, `Tool.recipe` y las constantes de
`Pasarelas`, que es de donde las lee la partida, y `TechTree.lo_de_hoy` cuenta lo que
hay en el utillaje, en el río o en el valle. Las dieciocho técnicas dicen qué dan
—`TestTecnicas`, doce pruebas—, y las presas salen por su nombre (`Fauna.species_name`)
y no por la clave con que las apunta la tabla, que en la ficha se leía como una errata.

**El núcleo preparado y la talla laminar ya hacen algo**, que era la mitad de la queja:
calidad mínima 0,90 en lo tallado en piedra y media piedra o sílex por pieza. El
mecanismo y la cifra medida están en EPOCA_01 §7 y en ESTADO §2 —una tanda del utillaje
lítico de una banda de quince pasa de 14,0 a 7,0 de piedra—.

**Capturas** (`ParajesCaptura`, a 1280×720): `parajes.png` la lista entera,
`parajes_filtrados.png` la misma con pesca y marisqueo encendidos a menos de 500 m —uno
de trece— y `obras_pasarela.png` la ficha de una pasarela: «Armada en El pasto del picón.
Salva un paso de 40 m. Rematada la jornada 3. A 100 m del abrigo», con ◀ ▶, «llevar la
cámara» y «◀ todas las obras». Para capturarlas hay que **poner la ventana en modo ventana antes de pedir
la medida**: la partida arranca con lo que diga la configuración del jugador, y a
pantalla completa `window_set_size` se ignora sin decir nada.

**Lo que no se consiguió capturar: el aviso emergente.** `tecnica_tooltip.png` enseña
el árbol de caza, pero el globo no sale. Godot sólo lo abre con un ratón de verdad
posado encima: ni `Input.warp_mouse`, ni un `InputEventMouseMotion` metido por la cola,
ni traer la ventana al frente lo levantan —cuatro intentos el 2026-09-16, incluido el
de pasar el punto a coordenadas de ventana, que era un fallo de verdad y está
arreglado, porque el juego estira un lienzo de 1920×1080 sobre la ventana—. El texto
**sí** queda comprobado: `TestTecnicas` lo contrasta contra las tablas del juego, y la
sonda lo imprime entero en su salida. Queda como deuda de instrumentación, no de la
ventana.

**Corregido el 2026-09-16 (depurar): la ficha se queda.** El usuario pidió que lo que
dice una técnica se quedara abierto «hasta que el jugador quiera», y un aviso emergente
no puede: Godot lo cierra al mover el ratón. **Pinchar una casilla abre su ficha dentro
de la ventana, debajo del árbol** (`PanelTecnicas._ficha`), y se queda hasta que se
cierra con su aspa o se pincha otra. Lleva la descripción, **«EFECTO:»** delante de lo
que da —así lo pidió: «EFECTO: lo que haga exactamente»—, lo de hoy, qué la frena y, si
ya se sabe, el botón del vídeo del hito, que es lo que hacía antes el clic. El aviso
emergente sigue saliendo al pasar por encima, con el mismo «EFECTO:». Comprobado en
pantalla con `ParajesCaptura` (`tecnica_ficha.png`).


---

## 11. Las teclas, que se pueden cambiar (spec 2026-09-16, hecho 2026-09-17)

> **Spec escrita con `/spec` el 2026-09-16**, con las decisiones del usuario marcadas.

### Qué problema cierra

**Cambiar una tecla no sirve de nada.** La cámara mira a la vez las teclas W, A, S y D
fijas en el código y las acciones del mapa de entrada del proyecto: si se cambia la
acción, la W sigue moviendo. Y no es sólo la cámara: el zoom (Q/E), correr (Mayús), la
pausa (P y espacio), las capas de recursos (R) y el panel de rendimiento (F3) también
están fijos en el código. **Y no hay dónde cambiarlas**: la ventana «Controles» sólo
las enseña, con un texto escrito a mano.

### Lo que se pide

- **Toda tecla a la que responde el juego pasa por una acción**, también las que hoy
  están fijas. Una tecla no se mira en ningún otro sitio.
- **Una pestaña «Controles» en Configuración** (decisión del usuario): la lista de
  acciones con su tecla; se pincha una, se pulsa la nueva y queda puesta.
- **Si la tecla ya la usa otra acción, se dice** y se ofrece cambiarlas entre sí o
  cancelar. Nunca quedan dos acciones con la misma tecla sin que el jugador lo haya
  visto.
- **«Volver a las de siempre»**, que deja las del proyecto.
- **Se guardan en disco** con el resto de la configuración, y se leen al arrancar.
- **La ventana «Controles» del juego enseña las teclas que hay puestas**, no un texto
  fijo.

### Criterios de aceptación

- **Ninguna tecla fija.** Una comprobación que recorre los guiones del juego —fuera de
  las pruebas y de las herramientas— no encuentra ni una consulta de tecla concreta. Se
  corre con la suite.
- **Cambiar funciona**: con «avanzar» puesta en la I, la I mueve la cámara y la W no.
  Prueba.
- **Se guarda y se lee**: cambiar dos teclas, guardar, volver a leer: siguen cambiadas.
  Prueba, con la configuración de pruebas y no la del jugador.
- **Choque**: poner en «avanzar» la tecla de «pausa» avisa, y aceptar el cambio las
  intercambia. Prueba.
- **Volver a las de siempre** deja todas las del proyecto. Prueba.
- **La ventana «Controles» dice la verdad**: tras cambiar una tecla, enseña la nueva.
  Prueba de lo que pinta.
- **Se lee**: captura de la pestaña a 1280×720.

### Fuera de alcance

- **Los botones y la rueda del ratón.**
- **Mandos** de consola.
- **Varias teclas por acción**: una por acción.
- **Las teclas de las sondas y herramientas de desarrollo.**

**Plan técnico (2026-09-17).**

*La premisa se comprobó contra el código antes de planear, y aguanta*: el mapa de entrada
del proyecto tiene **cinco acciones** —`move_forward`, `move_backward`, `move_left`,
`move_right` y `rotate_camera`— y `OrbitalCamera._process` mira W, A, S y D **fijas** y
además esas cuatro acciones, sumando las dos. Todo lo demás son `match event.keycode` en
`DemoMain._tecla` y `RegionMap._unhandled_input`, más `Input.is_key_pressed` en la cámara y
en `PanelAlmacen`, y un `@export var toggle_key: Key = KEY_F3` en `PerformanceOverlay`.

**Y dos cosas que la spec no sabía, encontradas al mirar:**

- **F3 ya está pisada.** Es «velocidad ×5» en `DemoMain._tecla` y a la vez la tecla del
  panel de rendimiento. La ventana «Controles» las lista las dos como si nada.
- **La ventana «Controles» miente.** Enseña «B — modo construcción» y **no hay ninguna
  B** en el juego: `KEY_B` no aparece en `scripts/`. Es exactamente lo que la spec quiere
  cerrar pintando la ventana del catálogo en vez de a mano.

### Módulos

| Qué | Dónde | Contrato |
|---|---|---|
| El catálogo de acciones y el mapa de teclas | `scripts/vista/Teclas.gd` (nuevo) | Estado estático sin autoload, como [Configuracion] (SPECS §2.2) |
| Guardar y leer con el resto | `scripts/vista/Configuracion.gd` | Sección `[teclas]` del mismo `configuracion.cfg`, y la ruta de pruebas que ya tiene |
| Quien pregunta por una tecla | `OrbitalCamera`, `DemoMain`, `RegionMap`, `SalaDeLaCueva`, `PerformanceOverlay`, `PanelAlmacen` | SPECS §4.7: la vista lee y dibuja |
| La pestaña donde se cambian | `scripts/ui/VentanaDeConfiguracion.gd` | INTERFAZ §8 |
| La ventana que las enseña | `scripts/ui/GameUI.gd` | Se pinta del catálogo |

### Las tres decisiones que la spec obliga a tomar

**1. Las acciones llevan ÁMBITO, o el detector de choques miente.** Hoy la R es «cambiar
la capa del minimapa» en el valle y «abrir la ficha del sitio» en el regional, y el espacio
es «pausar» en uno y «resolver la estación» en el otro. Son pantallas distintas y nunca
coinciden, así que **no son un choque**. El catálogo lleva por acción un ámbito —`valle`,
`regional` o `siempre`— y dos acciones sólo chocan si comparten ámbito o si una es de
`siempre`. Sin esto, la ventana avisaría de conflictos falsos el primer día.

**2. Los números son una familia, no once filas.** El 1 al 5 manda a la banda a un oficio
en el valle y reparte la partida en el regional; el 0 limpia el reparto. Son **seis
acciones** (`numero_0`…`numero_5`) de ámbito `siempre`, y cada pantalla hace con ellas lo
suyo. Ponerlas por pantalla daría once filas que el jugador no sabría distinguir.

**3. El invariante que esto viene a cerrar es el tercero de SPECS §7**: «una pregunta, un
sitio que la contesta». Hoy «¿está pulsado avanzar?» se contesta desde dos sitios —la
tecla física y la acción— y por eso cambiar la acción no hace nada. Después se contesta
sólo desde `Teclas`/`InputMap`, y **una prueba de la suite recorre `scripts/` y falla si
alguien vuelve a preguntar por una tecla concreta** fuera de `Teclas.gd`.

### Lo que se hereda y no se arregla aquí

- **El ratón se queda fuera**, como dice la spec: `rotate_camera` seguirá siendo el botón
  derecho en el mapa del proyecto, y la rueda del zoom sigue leída en `_input`. Entran en
  el catálogo **sólo para enseñarse** en la ventana, sin poder cambiarse.
- **Una tecla por acción.** La pausa tiene hoy P **y** espacio; al catálogo va con una
  sola y la otra se pierde. Es lo que pide la spec («varias teclas por acción» está fuera
  de alcance), pero es una pérdida y se dice.
- **La N de la capa de navegación** es una herramienta de desarrollo —imprime por
  consola—: pasa a ser acción, para que la prueba de «ninguna tecla fija» no necesite
  excepciones, pero **no sale en la ventana del jugador**.

### Orden de dependencias

El catálogo (`Teclas`) antes que nada: todo lo demás le pregunta. Guardar y leer va justo
después, porque es lo que hace que un cambio sobreviva a cerrar el juego. Luego los
consumidores, uno por pantalla. La prueba de «ninguna tecla fija» va **al final de los
consumidores**, cuando puede pasar. Y la ventana de cambiar, y la que enseña, al final:
las dos se pintan del catálogo, así que no pueden existir antes que él.

### Cómo quedó (2026-09-17)

**Una sola puerta: `Teclas`** (`scripts/vista/Teclas.gd`). El catálogo —id, rótulo,
ámbito y tecla de siempre—, el `InputMap` que monta con lo que el jugador tenga puesto,
la regla del choque y el guardado. Estado estático como `Configuracion`, y en su mismo
fichero, sección `[teclas]`.

**Todo el juego pregunta por `Teclas.pulsada(...)` o `Teclas.es(evento, ...)`**, nunca
por `Input.is_action_pressed` a pelo. Parece un rodeo y no lo es: una sonda que arranca
`demo_main` sin pasar por el menú principal no ha leído la configuración, y sin nadie que
monte el `InputMap` la primera pregunta daba «request for nonexistent InputMap action».
Preguntando por aquí, la primera pregunta lo monta.

**Las acciones llevan ámbito** —`SIEMPRE`, `VALLE`, `REGIONAL`— y dos sólo chocan si
comparten pantalla. Sin eso, la ventana habría avisado el primer día de dos choques que
no lo son: la R es «la capa del minimapa» en el valle y «la ficha del sitio» en el
regional, y el espacio es «pausar» y «resolver la estación».

**La pestaña «Controles»**, cuarta de Configuración: la lista por ámbito, se pincha una
fila, se pulsa la tecla y queda puesta y guardada. Si choca, la pestaña entera pasa a un
aviso que **nombra las dos acciones** —«querías poner "X" en la tecla K, y esa tecla ya
es "Y"»— con «cambiarlas entre sí» y «dejarlo como estaba». Y «volver a las de siempre».
**ESC no se cambia** (decisión del usuario): su fila sale apagada, porque es la salida de
todas las ventanas, incluida ésta y su propio aviso.

**La ventana «Controles» del juego se pinta del catálogo.** Antes era una lista escrita a
mano, y por eso decía lo que le parecía.

### Tres cosas que aparecieron al implementarlo, y ninguna estaba en la spec

- **F3 hacía dos cosas**: «velocidad ×5» en `DemoMain` y abrir el panel de fotogramas.
  El panel se muda a **F4** (decisión del usuario, 2026-09-17), que las tres velocidades
  son un trío de teclas seguidas.
- **La ventana «Controles» anunciaba una «B — modo construcción» que no existe.** No hay
  ninguna B en el juego. Llevaba escrita a mano desde que la ventana se sacó del panel de
  la esquina.
- **El mapa de entrada del proyecto estaba muerto entero.** `move_forward`,
  `move_backward`, `move_left`, `move_right` y `rotate_camera`: las cuatro primeras
  porque la cámara sumaba la tecla física *y* la acción —de ahí que cambiarla no
  hiciera nada—, y `rotate_camera` porque el botón derecho se lee a mano en
  `OrbitalCamera._unhandled_input`. La sección `[input]` de `project.godot` queda vacía,
  con una nota que dice dónde viven ahora.

### Lo que se pierde, y se dice

**La P deja de pausar.** Pausaban la P y el espacio, y el catálogo lleva una tecla por
acción —«varias teclas por acción» está fuera de alcance en la spec—. Se queda el
espacio. Quien quiera la P la pone en dos clics, que es de lo que iba todo esto.

### Comprobado

`TestTeclas`, **24 pruebas y 250 comprobaciones**. Las que valen la pena nombrar:

- **«Ninguna tecla fija»**: recorre `scripts/` —fuera de `tests/` y `tools/`— y falla si
  alguien vuelve a escribir un `KEY_…` o un `is_key_pressed`. Es la que impide que esto
  se deshaga solo, porque deshacerlo no da ningún error de compilación.
- **La tecla física dispara su acción y sólo la suya**: con «avanzar» puesta en la I, el
  evento de la I es «avanzar» y el de la W ya no lo es.
- **El choque**: dos pantallas distintas comparten tecla sin avisar; lo de «en todas
  partes» choca con cualquiera; aceptar intercambia y cancelar no toca nada.
- **Preguntar sin haber leído la configuración no revienta.**

Y la vista: `ConfiguracionCaptura` recorre ahora **todas** las pestañas —la cuenta estaba
escrita a mano en tres y la nueva se habría quedado sin mirar— y saca además el aviso de
choque. **Nada se sale a 1920×1080 ni a 1280×720.**


---

## 12. El contorno del valle, sin congelar la ventana (spec 2026-09-16, hecho 2026-09-17)

> **Spec escrita con `/spec` el 2026-09-16**, de la deuda «la descarga del relieve
> congela la ventana unos segundos» (ROADMAP).

### Qué problema cierra

La deuda estaba escrita en grande y **ya es sólo un caso**. Preparar un valle nuevo va
en un hilo con su barra desde la pantalla de carga (§9). Lo que sigue congelando la
ventana es **rehacer el contorno de un valle que ya estaba preparado**: si el relieve de
alrededor quedó basto o sin ríos, se vuelve a descargar del IGN **en el hilo principal**,
con un aviso de «esto tarda» encima de una pantalla parada. Puede durar minutos.

### Lo que se pide

- **Esa descarga va fuera del hilo principal**, con la misma pantalla y la misma barra
  que preparar un valle, y la hidrografía que la acompaña también.
- **Si la red falla**, se queda con el contorno que había, lo dice, y la partida sigue.

### Criterios de aceptación

- **La ventana no se para**: durante el contorno rehecho, ningún cuadro pasa de 500 ms
  —el mismo tope que §9—. Sonda con red, presupuestada en el plan.
- **La barra avanza** y dice qué se está haciendo.
- **Sale el mismo contorno** que rehaciéndolo en el hilo principal: los datos son iguales
  byte a byte. Prueba con datos guardados, sin red.
- **Sin red no se cuelga**: con la descarga fallando, el valle se abre con el contorno
  viejo y un aviso. Prueba.

### Fuera de alcance

- **Hacer más rápida la descarga** o cambiar de dónde sale el relieve.
- **Los importadores de las herramientas** (`scripts/tools/`), que no son el juego.

**Plan técnico (2026-09-17).**

*Comprobado contra el código antes de planear, y la spec acierta de lleno.*
`PreparaValle.preparar` ya hace lo largo en un `Thread` —`_hacer_el_valle`— y bombea
cuadros mientras, pero **cuando el valle está en caché llama a
`_refresh_surround_if_coarse`, y ésa trabaja en el hilo principal**: dos
`await process_frame` de cortesía y luego `IGNImporter.import_area` para doce kilómetros
de lado y `OSMWays.fetch_water` a Overpass, los dos bloqueando. Las etapas medidas dicen
lo que cuesta: **43 s el relieve de alrededor**, y la ventana está parada todo ese rato.

### La forma del arreglo

La misma que ya funciona dos funciones más arriba, y no otra: **la receta de datos en un
hilo, los avisos por el buzón, y el hilo principal bombeando cuadros**. `PreparaValle` ya
tiene el buzón (`_avisar` guarda bajo `Mutex` y `_publicar` emite desde el principal,
porque una señal no se emite desde otro hilo), así que lo que falta es separar la receta
de la espera:

| Qué | Dónde |
|---|---|
| La receta, sin árbol ni señales: mirar, bajar, pintar el agua y guardar | `PreparaValle._rehacer_el_contorno(sitio, local)` (nuevo, del actual `_refresh_surround_if_coarse`) |
| La espera, que lanza el hilo y bombea cuadros con `al_cuadro` | `PreparaValle._poner_al_dia_el_contorno(arbol, sitio, local, al_cuadro)` |
| Quien lo pide | `preparar`, que ya recibe `al_cuadro` — **las dos puertas** (el mapa regional al fundar y la ficha de campamento al migrar) lo heredan sin tocarlas |

### La decisión que la spec obliga a tomar: dos costurones

«Sale el mismo contorno que rehaciéndolo en el hilo principal, **byte a byte**, con datos
guardados y **sin red**» no se puede comprobar si la receta llama al IGN y a Overpass por
su cuenta. Así que las dos llamadas salen a dos `Callable` con el de verdad por defecto:
`trae_el_relieve` y `trae_el_agua`. La prueba les pone un relieve de bote; el juego no se
entera. **Son los dos únicos sitios donde esta receta toca la red**, y tenerlos con nombre
vale por sí solo.

### Las etapas de la barra

La barra ya está abierta cuando esto pasa —la abre quien funda— con `ETAPAS`. El contorno
rehecho usa **la 4** («Descargando el relieve de alrededor», 43 s medidos) para el MDT y
para el agua, cambiando sólo el texto, y **la 5** para guardar. Así la barra nunca va
hacia atrás, que es lo que pasaría poniendo el agua en la 3.

### Riesgos y deuda que se nombra

- **Si el IGN falla, hoy se reintenta en cada entrada al valle.** El contorno sigue basto,
  así que la próxima vez se vuelve a pagar la espera. Con la descarga en un hilo la
  ventana ya no se congela, pero la espera sigue estando. Es una decisión del usuario.
- **`load` y `ResourceSaver.save` desde un hilo** ya se hacen en `_hacer_el_valle`, así
  que el terreno está pisado; lo que no se puede es tocar un nodo ni emitir una señal, y
  la receta no hace ninguna de las dos (invariante 9 de SPECS §7).
- **El recuadro jugable no se toca**: esto sólo reescribe `site_<id>_surround.res`.

### Cómo quedó (2026-09-17)

**El contorno rehecho va en un hilo**, como preparar un valle nuevo y con el mismo
aparato: `_rehacer_el_contorno` es la receta —mirar, bajar, pintarle el agua, guardar— y
`_poner_al_dia_el_contorno` la espera, que lanza el hilo y bombea cuadros con el
`al_cuadro` de la barra. Los avisos van por el buzón de `_avisar`, porque **una señal no
se emite desde otro hilo**. Las dos puertas —fundar desde el mapa regional y migrar desde
la ficha de un campamento— lo heredaron sin tocarlas: las dos llaman a `preparar`.

**Todo va dentro del hilo, incluida la comprobación de si hace falta.** Mirar el contorno
es leer un recurso de disco de varios megas, y leerlo en el principal sería justo el
tirón que se viene a quitar. Si no hay nada que hacer, el hilo termina en el primer
cuadro.

**Dos costurones, y son los dos únicos sitios donde esto toca la red**:
`trae_el_relieve` (el IGN) y `trae_el_agua` (Overpass), con el de verdad por defecto.
Existen porque la spec pedía comprobar el contorno **con datos guardados y sin red**, y
eso no se puede hacer si la receta llama a la red por su cuenta. De paso, tenerlos con
nombre dice de un vistazo dónde está el coste.

**Y `PreparaValle` ya no escribe en una ruta fija**: `carpeta_de_los_valles`, con la del
juego por defecto y otra para las pruebas y las sondas, por lo mismo que
`Guardado.carpeta` — una prueba no toca nunca los datos del jugador, y aquí lo que hay
son ficheros de veinte megas que cuesta minutos de red volver a hacer.

**Si el IGN no responde**, se queda el relieve que había y **se reintenta la próxima vez
que se entre al valle** (decisión del usuario del 2026-09-17): sigue basto, así que la
condición vuelve a dar verdad. Si la red va mal hoy y bien mañana, el contorno mejora
solo.

### Lo que la prueba destapó, y no era lo que se buscaba

El aviso de «el IGN no responde» **duraba un cuadro y no lo leía nadie**. El buzón guarda
UN texto y lo publica el hilo principal cuando puede: un aviso seguido de otro se pisa, y
el paso siguiente —guardar— tarda milisegundos. Escrito así, la spec decía «lo dice» y el
juego no decía nada. Ahora el fallo se guarda y sale **en el último cartel**, que es donde
la barra se queda parada un momento:

> Guardando el relieve de alrededor…
> (El IGN no ha respondido: se queda el que había.)

### Medido

`CargaProbe CONTORNO=1` (ventana 1920×1080, sitio 56, con red), estropeando a propósito el
contorno de un valle ya preparado —sobre una copia en la carpeta de las sondas—:

| caso | lo que rehace | tarda | cuadro más largo | de más de 500 ms |
|---|---|---|---|---|
| **seco** | sólo el agua (Overpass) | 43,5 s | **73 ms** | **0** |
| **basto** | el MDT del IGN, 25 s de descarga | 49,1 s | **40 ms** | **0** |

La barra no retrocede nunca y se queda quieta como mucho 2,1 s en el caso seco y 7,7 s en
el basto. **El criterio de la spec era que ningún cuadro pasara de 500 ms**, y el peor es
de 73.

Y una del instrumento, que costó una corrida entera: la sonda copia el valle preparado a
su carpeta, y **la copia salía «de una versión anterior»**, así que `preparar` rehacía el
valle entero —dos minutos de descarga— en vez de sólo el contorno. La sonda pone ahora el
sello a mano, que es lo honesto: está fabricando el escenario «este valle ya está
preparado».


---

## 13. La cámara sigue a la persona elegida (spec 2026-09-16, hecho 2026-09-17)

> **Spec escrita con `/spec` el 2026-09-16**, a partir de un encargo del usuario:
> «seleccionar un miembro de la banda centrará la cámara en él y además la cámara hará
> seguimiento». Las decisiones de abajo salieron a preguntas.

### Qué problema cierra

Hoy elegir a alguien —con un clic sobre su figura en el valle, o desde la lista de
trabajos— **abre su ficha y no mueve la cámara**. Si se eligió desde una lista, la
persona puede estar al otro lado del valle y no hay forma de verla sin buscarla a ojo; y
si se pinchó en el mundo, en cuanto echa a andar se sale del encuadre. La ficha dice qué
hace, pero no deja **mirarla hacerlo**, que es justo lo que pide la cámara lenta de
[GRAFICOS.md](GRAFICOS.md) §7.6.

### Lo que se pide

**Elegir a una persona la centra y la sigue.**

- Vale **igual desde el clic en el valle que desde cualquier lista** que abra su ficha
  (decisión del usuario).
- **Centrar es como «llevar la cámara»** de las demás fichas: el punto que se mira pasa a
  ser la persona, de una vez. Mientras se la sigue, ese punto **va con ella** cuadro a
  cuadro.
- **El zoom sólo se acerca si está lejos** (decisión del usuario): si la cámara está más
  lejos que la distancia a la que las fichas ya enseñan lo pinchado —80 m, GRAFICOS §4.1—,
  baja hasta ahí; si está más cerca, no se toca. Así elegir a alguien **no dispara por sí
  solo la cámara lenta**, que empieza por debajo de 60 m.
- **Se sigue lo que se ve** (decisión del usuario): la figura mientras anda y, en un viaje
  abreviado (GRAFICOS §7.6), la marca que recorre la vereda. La persona queda siempre en
  el centro de la pantalla, aunque la figura vaya con el retraso del tramo andado.
- **Girar y hacer zoom no sueltan**: se puede rodear a la persona y acercarse a ella
  mientras se la sigue.

**Qué suelta el seguimiento** (las cuatro, decisión del usuario):

- **Mover la cámara a mano**: las teclas de desplazamiento, arrastrar, o un clic en el
  minimapa.
- **Cerrar su ficha.**
- **Elegir otra cosa**: otra persona pasa a seguirse a ella; una cueva, un recurso, una
  cima, o el «llevar la cámara» de otra ficha lo suelta.
- **ESC**: suelta, y esa pulsación no abre el modal de §7.

Al soltar, la cámara **se queda donde está**: no vuelve a ningún sitio.

**Y lo que se sigue de lo anterior**, sin decisión nueva:

- Si la persona **deja el valle** —sale de expedición, se muda a otro campamento— o
  **muere**, el seguimiento se suelta y la cámara se queda donde estaba.
- Si se elige desde una lista a alguien que **no está en el valle**, se abre su ficha
  como hoy y la cámara no se mueve.
- **Con la partida en pausa** se sigue siguiendo; simplemente no se mueve nadie.
- Pasar al mapa regional suelta el seguimiento.

### Criterios de aceptación

- **Centra desde el clic y desde la lista**: tras elegirla, el punto de órbita está a
  **menos de 1 m en horizontal** de donde se dibuja la persona. Prueba, una por cada
  camino.
- **La sigue**: con la persona andando un trayecto corto (menos de 150 m, que se dibuja
  entero), dando pasos de simulación y de vista, en **cada cuadro** el punto de órbita
  está a menos de 1 m en horizontal de la figura. Prueba dando pasos, no esperando al
  reloj.
- **Sigue la marca en un viaje abreviado**: lo mismo, contra la marca, durante el tramo
  abreviado; y contra la figura en los tramos andados. Prueba. *Depende de §7.6 de
  GRAFICOS: si esa spec no está hecha, este criterio espera a ella.*
- **El zoom**: con la cámara a 150 m, elegir a alguien la deja a 80 m; a 30 m, la deja a
  30 m. Prueba.
- **Girar y hacer zoom no sueltan**: tras girar y tras una muesca de rueda, sigue a menos
  de 1 m. Prueba.
- **Cada cosa que suelta, suelta**: por separado, desplazamiento con tecla, arrastre,
  clic en el minimapa, cerrar la ficha, ESC, pinchar una cueva, un recurso, una cima y el
  «llevar la cámara» de otra ficha. Después de cada una, con la persona andando, **el
  punto de órbita no se mueve** en diez pasos. Prueba.
- **Otra persona cambia a quién se sigue**: tras elegir a una segunda, el punto va con la
  segunda y no con la primera. Prueba.
- **ESC no abre el modal** al soltar: tras esa pulsación el modal de §7 está cerrado; la
  siguiente, sin ventanas, lo abre. Prueba.
- **Quien se va, se suelta**: una persona que sale de expedición, se muda o muere deja de
  seguirse y la cámara se queda en el último punto. Prueba construyendo el estado, no
  jugándolo.
- **Nadie fuera del valle mueve la cámara**: elegir desde una lista a alguien ausente abre
  la ficha y deja el punto de órbita donde estaba. Prueba.

### Fuera de alcance

- **Una cámara en primera persona** o pegada a los ojos de la persona.
- **Deslizar la cámara** hasta la persona: centra de una vez, como el resto de «llevar la
  cámara». Si se quiere suave, va para todas las fichas a la vez y es otra spec.
- **Seguir a un animal, una obra o un grupo.**
- **Seguir a alguien en el mapa regional** o durante un viaje entre campamentos.
- **Una tecla propia** para soltar o volver a seguir: si hace falta, entra por §11.
- **Mantener el seguimiento al guardar y cargar** la partida.

**Plan técnico (2026-09-17).**

*Comprobado contra el código antes de planear.* Tres cosas que la spec da por hechas y lo
están, y una que no existe:

- **«Centrar es como llevar la cámara»**: esa receta ya vive en `PanelCenso._look_at_world`
  —`set_target` y, si la cámara estaba más lejos, `set_distance(distancia_para_mirar())`—
  y `OrbitalCamera.distancia_para_mirar()` ya devuelve los **80 m** que la spec pide. No
  hay número nuevo que inventar; hay que **sacar esa receta de `PanelCenso`** para que la
  use también el seguimiento, que es la misma pregunta contestada desde un solo sitio
  (invariante 3 de SPECS §7).
- **Una sola puerta para elegir persona**: todo pasa por `GameUI.show_person`, tanto el
  clic del valle (`DemoMain`) como las listas (`PanelTrabajos`, el censo). Engancharse ahí
  cubre los dos caminos de una vez.
- **Lo que se ve de alguien** ya lo sabe `Figuras` (GRAFICOS §7.6): la figura dibujada, o
  la marca cuando el viaje va abreviado y la figura está escondida. Falta una función que
  lo diga en una línea.
- **«Arrastrar» no existe.** La spec lista cuatro gestos que sueltan y uno de ellos es
  arrastrar la cámara: en el valle **no hay arrastre que la mueva** —el botón derecho
  orbita y la rueda hace zoom, y no hay paneo con ratón—. Lo que sí arrastra es **el
  minimapa**, que ya mueve el punto de órbita, y eso es lo que se suelta.

### Módulos

| Qué | Dónde | Contrato |
|---|---|---|
| A quién se sigue y qué punto se mira | `scripts/vista/Seguimiento.gd` (nuevo) | SPECS §4.7: la vista lee y dibuja, no decide |
| Lo que se ve de una persona: figura o marca | `Figuras.donde_se_ve` | Ya existente |
| Llevar la cámara a un punto, acercándose sólo si está lejos | `OrbitalCamera.mirar_a` (sale de `PanelCenso`) | Una pregunta, un sitio |
| Enganchar al elegir persona | `GameUI.show_person` | La puerta única |
| Mover la cámara cada cuadro y soltar con las teclas | `DemoMain` | — |
| Soltar al cerrar, al elegir otra cosa, con ESC y con el minimapa | `GameUI`, `PanelCenso`, `PanelObras`, `Minimapa`, `DemoMain` | — |

### Las decisiones que la spec obliga a tomar

**1. El seguimiento es un objeto de la escena, no una estática.** Va colgado de `GameUI`
—`ui.seguimiento`—, que es lo que ya tienen a mano los paneles que sueltan, y `DemoMain`
llega por `ui`. **No es `static`** aunque sería más cómodo de alcanzar: es estado de una
escena, y con estática habría que acordarse de soltarlo al pasar al mapa regional. Así se
muere con la escena, que es lo que la spec pide.

**2. Soltar con las teclas se avisa por señal, no preguntando.** `OrbitalCamera` emite
`movida_a_mano` cuando el jugador desplaza el punto de órbita, y **no** cuando gira o hace
zoom, que la spec dice expresamente que no sueltan. Preguntarle a `Teclas` desde
`DemoMain` cada cuadro daría lo mismo pero repartiría la regla en dos sitios.

**3. La cámara se mueve en `_process` de `DemoMain`, no dentro del paso de simulación.**
Es vista: sigue a lo que se dibuja, y lo que se dibuja lo pone `Figuras` en su propio
`_process`. Con la partida en pausa se sigue siguiendo, que es lo que la spec pide, y sale
gratis.

### Orden de dependencias

`Seguimiento` y `donde_se_ve` antes que nada. La receta de la cámara sale de `PanelCenso`
a la cámara **antes** de engancharla, para no escribirla dos veces. Los sueltos van
después, uno por sitio. La prueba de la marca abreviada necesita §7.6 de GRAFICOS, que ya
está hecho.

### Riesgos y deuda que se nombra

- **Los sitios que sueltan son seis**, y el que se olvide no da ningún error: se queda la
  cámara pegada a alguien cuando el jugador ya está mirando otra cosa. La prueba los
  recorre uno a uno, que es lo único que lo impide.
- **El seguimiento no se guarda** con la partida (fuera de alcance en la spec): al cargar,
  la cámara no sigue a nadie.
- **`PanelCenso._look_at_world` se queda como pasamanos** de la receta que se muda a la
  cámara: lo llaman las flechas del censo y las obras, y cambiar sus llamadas no aporta
  nada.

### Cómo quedó (2026-09-17)

**Elegir a alguien la centra y la sigue**, y se engancha en `GameUI.show_person`, que es
la puerta única: el clic en el valle, la lista de trabajos y el censo pasan todos por ahí.
A quien no está en el valle —de expedición, mudada— se le abre la ficha y la cámara no se
mueve. El zoom se acerca **sólo si estaba lejos**, con la receta que ya existía y que se
mudó de `PanelCenso` a `OrbitalCamera.mirar_a`, porque ahora la usan tres.

**Lo que se sigue es lo que se VE, no lo simulado.** `Figuras.donde_se_ve` contesta con la
figura dibujada o, cuando el viaje va abreviado y la figura está escondida, con la marca
(GRAFICOS §7.6). Seguir `person.position` dejaría a la figura fuera del centro justo en el
único rato en que las dos no coinciden.

**Y la sigue `Figuras` quien la manda mover**, no el `_process` de `DemoMain`: `Figuras`
emite `pintadas` al acabar de poner las figuras del cuadro y la cámara se mueve ahí.

**Lo que suelta**, y son seis: las teclas de desplazamiento, el minimapa, cerrar la ficha
—la cruz y ESC—, ESC a secas, elegir otra cosa, y el «llevar la cámara» de otra ficha.
**Girar y hacer zoom no sueltan**, y esa regla vive en la cámara: emite `movida_a_mano`
cuando el jugador desplaza la vista y **no** cuando gira o hace zoom. Al soltar, la cámara
se queda donde está.

### Lo que costó, que fue el orden del cuadro

La primera versión seguía desde `DemoMain._process` y **se quedaba a 54 metros de lo que
se veía** —medido en el valle, con ventana—. Son dos cosas, y las dos se aprenden aquí:

- **`DemoMain` es la raíz de la escena, así que su `_process` corre ANTES que el de sus
  hijos.** La cámara leía las figuras del cuadro anterior. Ahora la mueve la señal de
  `Figuras`, que es quien sabe cuándo están puestas.
- **La marca se dibujaba con un valor y se leía con otro.** `donde_se_ve` recalculaba la
  posición de la marca de `person.position` en vivo, y la simulación da su paso después:
  a ×1 eso son decenas de metros entre dos cuadros. Ahora la marca se guarda cuando se
  pone, y se lee guardada.

Con las dos, el desvío es **cero desde el primer cuadro dibujado**. Queda **un solo cuadro
con 6,4 m**: el de elegirla, porque la persona anda entre que se pincha y que se dibuja el
cuadro siguiente. Es un fotograma y no se ve.

### Comprobado

`TestSeguimiento`, **16 pruebas y 36 comprobaciones**: que lo que se ve es la figura o la
marca según la fase; que la cámara se acerca sólo si estaba lejos; que elegir centra,
sigue y cambia de persona; que quien no está en el valle no mueve la cámara; que soltar
deja el punto quieto aunque ella ande; y que quien se va del valle se suelta solo.

**Dos de los seis gestos no se pueden ejercitar en la suite** —ESC y el minimapa viven en
`DemoMain` y en `Minimapa`, que no se montan sin la escena—, así que de ésos se comprueba
que **el suelto sigue escrito**: si alguien reescribe uno de esos sitios y se lo deja, no
habría ningún error, sólo una cámara pegada a alguien que ya no se mira. Lo dice la prueba
por su nombre.

Y una corrida con ventana del valle, eligiendo a alguien y dejándola andar trescientos
cuadros: sigue, se acerca a 80 m y no se suelta sola.

### Lo que la spec pedía y no existe

«Arrastrar la cámara» es uno de los cuatro gestos que la spec dice que sueltan. **En el
valle no hay paneo con ratón**: el botón derecho orbita y la rueda hace zoom, y nada más.
Lo que sí se arrastra es el minimapa, que ya mueve el punto de órbita, y eso es lo que
suelta.


---

## 14. El modo Debug: todos los yacimientos del Paleolítico, sin niebla (spec y hecho, 2026-09-17)

> **Spec escrita con `/spec` el 2026-09-17**, a partir de un encargo del usuario: «una
> forma de depurar y ver todos los yacimientos del Paleolítico, quizá un botón en el menú
> principal "Debug" que me enseñe el mapa regional, sin niebla, y permitiéndome fundar en
> CUALQUIER yacimiento paleolítico, mostrándolos todos». Las decisiones de abajo salieron
> a preguntas.

### Qué problema cierra

**Para ver un valle hoy hay que jugarse la llegada.** Una partida empieza con la niebla
cubriendo el mapa regional y **un solo yacimiento a la vista**: los demás se descubren
explorando (SISTEMAS §4). Y **sólo se funda una vez**: elegir otro yacimiento después es
una visita sin banda (SISTEMAS §23). Así que comprobar cómo sale un valle concreto —su
relieve, su agua, dónde nacen los parajes, si la banda arranca— pide o jugar hasta
descubrirlo, o tocar a mano los datos de una sonda.

Con las tandas de la costa y los valles inventados (EPOCA_01 §10.2), los sitios que
merece la pena mirar uno a uno son decenas, y ninguno se puede elegir desde el juego.

### Lo que se pide

**Un botón «Debug» en el menú principal** que abre el mapa regional en un modo de
depuración:

- **Sólo en la versión de desarrollo** (decisión del usuario): sale al abrir el juego
  desde el proyecto y **no** en un ejecutable exportado para jugar.
- **Sin niebla**, y con **todos los yacimientos que el juego ofrece en el Paleolítico** a
  la vista (decisión del usuario): los habitables con el mar a −120 m y en esa época, que
  son los que un jugador acabaría viendo, incluidos los cuatro abrigos hipotéticos de la
  costa. **Los que el filtro de la época quita hoy siguen fuera**.
- **Se funda en cualquiera de ellos, y cada uno con una banda nueva** (decisión del
  usuario): elegir un yacimiento monta su valle con una banda recién llegada, como una
  partida nueva. Desde el valle se vuelve al mapa regional de depuración y se puede
  elegir otro, **tantas veces como se quiera**. No hay visitas: cada elección es una
  fundación.
- **Es una partida aparte y no se guarda nada** (decisión del usuario): entrar en Debug
  no lee ni pisa ninguna partida guardada, y lo que pase dentro no se escribe en disco.
  Al volver al menú principal, las partidas y la configuración están como estaban.
- **Se sabe que se está en Debug**: un rótulo visible en el mapa regional y en el valle,
  para no confundirlo con una partida.
- Un yacimiento **cuyo valle no está preparado** se prepara al fundar, como en una partida
  —descarga con su pantalla de carga—; **el mapa dice cuáles lo están y cuáles no**, para
  saber antes de pinchar si va a costar uno o dos minutos de red.

### Criterios de aceptación

- **El botón sólo en desarrollo**: con la marca de versión de desarrollo, el menú
  principal tiene «Debug»; sin ella, no lo tiene. Prueba de lo que pinta el menú, con las
  dos marcas.
- **Todos a la vista**: en el mapa regional de Debug, el número de yacimientos dibujados
  es **exactamente** el de los que el juego ofrece en el Paleolítico con el mar a −120 m,
  y **ninguno** queda bajo la niebla. Prueba.
- **Fundar en cualquiera**: para tres yacimientos escogidos —uno de interior, uno de los
  abrigos de la costa y el que esté más lejos de la cueva de arranque—, elegirlo en Debug
  monta su valle con una banda de la población inicial. Prueba de lo que queda preparado
  para la escena del valle, sin montarla.
- **Banda nueva cada vez**: fundar en A, volver, fundar en B deja en B una banda recién
  llegada —la misma población y el mismo día inicial que en A—, no la de A mudada. Prueba.
- **No toca nada guardado**: con una partida guardada y la configuración escritas antes,
  entrar en Debug, fundar dos veces y volver al menú deja **los mismos ficheros, byte a
  byte**. Prueba, con las carpetas de las pruebas y no las del jugador.
- **Salir de Debug deja el juego como estaba**: tras volver al menú, «Nueva partida»
  empieza con la niebla y un solo yacimiento a la vista, igual que sin haber pasado por
  Debug. Prueba.
- **Se sabe dónde se está**: el rótulo de Debug está en el mapa regional y en el valle, y
  no está en una partida normal. Prueba de lo que pinta.
- **Preparados y sin preparar se distinguen** en el mapa de Debug. Prueba de lo que pinta
  contra lo que hay en disco.

### Fuera de alcance

- **Las demás épocas**: el Debug es del Paleolítico. Elegir época es otra spec.
- **Los yacimientos que el filtro esconde** —bajo el mar de la época, fuera de la región
  jugable, sin nada paleolítico— (decisión del usuario).
- **Trucos dentro del valle**: dar recursos, adelantar el tiempo, saltar técnicas.
- **Guardar una partida de Debug**, o convertirla en una partida normal.
- **Cambiar las reglas de la partida normal**: la niebla, el descubrimiento y la regla de
  fundar una sola vez siguen como están fuera de Debug.

**Plan técnico (2026-09-17).**

*Comprobado contra el código antes de planear.* Lo que hay hoy, y lo que lo condiciona:

- **«Nueva partida» vacía el borrador del jugador.** `MenuPrincipal._nueva` llama a
  `Partidas.nueva()`, que hace `Campamentos.vaciar()`, **borra la carpeta
  `Partidas.borrador`** y apunta `Guardado.carpeta` a ella. Un Debug que reutilizara ese
  camino **tiraría la partida sin guardar que el jugador tuviera a medias**. Es la razón
  de la primera decisión de abajo.
- **Se escribe en disco sin pedirlo**: al salir de un valle, `DemoMain._dejar_la_escena`
  autoguarda el mapa en `Guardado.carpeta`; y el menú de ESC ofrece «Guardar», «Guardar
  como…» y «Guardar y salir».
- **Sin niebla es casi gratis**: `RegionMap.sitios_que_se_dibujan` ya enseña un
  yacimiento si está descubierto y `GameState.niebla` no lo tapa, y la capa de calima la
  pinta `_poner_la_niebla` desde `GameState.la_niebla()`.
- **Fundar una vez es una regla en `_found_settlement`**: si hay un campamento vivo en el
  sitio se entra en él; si el sitio es el de la banda guardada se retoma; y en cualquier
  otro caso, con banda o campamentos ya existentes, `Expedition.visita = true`.
- **Los campamentos siguen vivos al salir del valle** (SISTEMAS §23): colgados de la raíz
  del árbol y simulando. Volver al regional y fundar en otro dejaría el anterior andando.

### Las decisiones que la spec obliga a tomar

**1. Todo lo que el Debug toca de estado global se guarda al entrar y se devuelve al
salir, y la escritura va a una carpeta suya.** Una clase estática, `ModoDebug`
(`scripts/region/`), con `activo`, `entrar()` y `salir()` —estado global sin autoload,
como `GameState` (SPECS §2.2)—. Al entrar recuerda `Guardado.carpeta`,
`Partidas.borrador`, `Partidas.abierta` y lo que `GameState` lleva de la partida, y
**apunta las dos carpetas a `user://debug/`**, vaciada. Así **lo que se escriba sin
pedirlo** —el autoguardado de un valle— cae en la carpeta del Debug y no en la del
jugador. Es la misma receta que ya usan las pruebas («las pruebas no tocan los datos del
jugador»), y es más segura que perseguir cada sitio que guarda: el que se olvide escribe
igual, pero en otro sitio.

**2. Se arranca como una partida y luego se quita la niebla**, no al revés. Con
`GameState.started` a falso el mapa ya enseñaría todo, pero **media partida da por hecho
que hay casa, población y despensa** —`GameState.begin` las pone—. Así que en Debug se
llama a `begin` como siempre y después se descubre **todo lo que ofrece la época** y se
deja la niebla vacía. La capa de calima lleva **una sola rama** para no pintarse en Debug.

**3. «Banda nueva cada vez» es limpiar antes de cada fundación.** Antes de fundar,
`ModoDebug.nueva_fundacion(sitio)` vacía los campamentos vivos y la carpeta del Debug,
repone la población, la despensa y la fecha de arranque, y deja `Expedition.visita` a
falso. Después sigue la fundación de siempre, con su pantalla de carga y su preparación
del valle. **Una pregunta, un sitio**: `_found_settlement` sólo pregunta
`ModoDebug.activo` y le cede el arranque.

**4. El botón pregunta una marca que la prueba puede cambiar.**
`ModoDebug.hay_version_de_desarrollo`, que vale `OS.is_debug_build()` y que la prueba
pone a mano para pintar el menú con las dos.

**5. Lo que se ve.** El rótulo «DEBUG» lo pone `ModoDebug.rotulo(escena)` en el mapa
regional y en el valle —una sola función para los dos—. **Un yacimiento sin preparar se
dibuja con su color apagado**: el color del marcador ya dice qué clase de yacimiento es, y
cambiarlo por otro color perdería eso. Qué está preparado lo contesta
`PreparaValle` —el fichero existe y tiene su sello de versión—, que es quien lo sabe.
Y el menú de ESC, en Debug, **no ofrece guardar**: sólo seguir y volver al menú principal.

### Módulos

| Qué | Dónde |
|---|---|
| Entrar, salir, fundar de nuevo, rótulo y marca de desarrollo | `scripts/region/ModoDebug.gd` (nuevo) |
| El botón | `scripts/ui/MenuPrincipal.gd` |
| Sin guardar en el menú de ESC, y salir por `ModoDebug.salir` | `scripts/ui/MenuDelJuego.gd` |
| Sin niebla, todos, apagados los sin preparar, fundar siempre | `scripts/region/RegionMap.gd` |
| El rótulo en el valle | `scripts/DemoMain.gd` |
| Qué valle está preparado | `scripts/region/PreparaValle.gd` |

### Riesgos que se nombran

- **Si algo escribe en una ruta fija y no en `Guardado.carpeta`**, se salta la
  redirección. La prueba «no toca nada guardado» es la que lo caza: escribe ficheros del
  jugador de mentira, pasa por el Debug fundando dos veces, y compara byte a byte.
- **Fundar en un valle sin preparar descarga**, como siempre, y la sonda con ventana sólo
  funda en valles preparados para no depender de la red.
- **La configuración no se toca en Debug, pero se puede cambiar desde el menú de ESC**:
  eso sí se guarda, porque es del equipo y no de la partida (INTERFAZ §8). No es partida,
  así que no entra en «no se guarda nada».

### Cómo quedó (2026-09-17)

**Un botón «Debug» en el menú principal**, sólo cuando `OS.is_debug_build()` —al abrir el
juego desde el proyecto—. Lleva al mapa regional **sin niebla, sin calima y con los 76
yacimientos que ofrece el Paleolítico** con el mar a −120 m, cada uno con su marcador, y
con un rótulo rojo abajo: «DEBUG — no se guarda nada». Pinchar cualquiera funda **con una
banda nueva de 15**, en primavera del año uno; volver al regional deja elegir otro. Los
yacimientos cuyo valle no está en disco salen **con su color apagado**: fundar ahí
descarga. Y el menú de ESC no ofrece guardar ni cargar.

**Todo pasa por `ModoDebug`** (`scripts/region/`), estado global sin autoload como
`GameState`. Al entrar **aparta** las carpetas de partida y lo que `GameState` lleva, y
**apunta las carpetas a `user://debug/`**; al salir lo devuelve todo. Así lo que el juego
escribe sin pedirlo —el autoguardado al salir de un valle— cae en la carpeta del Debug.

### Lo que se encontró por el camino

- **«Nueva partida» vacía el borrador del jugador.** `Partidas.nueva` borra la carpeta de
  la partida a medias. Un Debug que reutilizara ese camino se habría llevado lo que el
  jugador no hubiera guardado, sin avisar. Por eso el Debug no lo llama y aparta las
  carpetas.
- **El mapa regional sólo pone marcador a lo atestiguado**, y la prueba de la suite no lo
  vio. Miraba el filtro de la niebla —que en Debug dejaba pasar los 76— y en la ventana
  **salían 63**: los inferidos y los hipotéticos no llevan marcador. Ahora
  `RegionMap.se_marca` es la pregunta, y en Debug dice que sí a todos.
- **Y eso vale también fuera de Debug, y es una cosa que mirar: los cuatro abrigos de la
  costa no tienen marcador en una partida.** Son hipotéticos, y por la misma regla no se
  dibujan aunque estén descubiertos. No se ha tocado —la spec dejaba las reglas de la
  partida como están—: va por `/depurar` si no es lo que se quería.

### Comprobado

`TestModoDebug`, **10 pruebas y 36 comprobaciones**. La que vale: con una partida guardada
y un borrador a medias escritos antes, **entrar, autoguardar como lo haría un valle, fundar
dos veces y salir deja los dos ficheros byte a byte**, y lo autoguardado en Debug no cae en
la carpeta del jugador. Las demás: todos a la vista y todos con marcador, fundar en un
sitio de interior, en un abrigo de la costa y en el más lejano, una banda nueva cada vez,
«Nueva partida» con niebla después, el botón con las dos marcas, el menú de ESC sin
guardar, el rótulo y «preparado» contra lo que hay en disco.

Y **una corrida con ventana**: menú → Debug → mapa regional (76 marcadores, sin niebla,
rótulo) → fundar en el sitio 56 (banda de 15, rótulo en el valle) → volver → fundar en el
33 (otra banda de 15) → salir al menú por ESC. Al acabar, el Debug apagado, las carpetas
de vuelta y el fichero de mentira «del jugador» intacto.

**Lo que no hace, y se dice**: «preparado» mira que el fichero del valle exista, no su
sello de versión —el sello está dentro de un recurso de veinte megas—. Un valle de una
versión anterior sale como preparado y se rehace al fundar, igual que en una partida.


> **Depurar del 2026-09-17 (la misma noche).** El modo Debug abría el mapa regional **sin
> ríos en la plataforma emergida** y preparaba los valles **sin el relleno de la época**.
> Las dos cosas salían de lo mismo: Debug no funda nada, y el mapa y el valle preguntaban
> «¿con qué mar?» a `GameState.home` y a `Expedition`, que en ese momento no lo saben.
> Ahora lo dice `RegionMap.mar_del_mapa()` —que cuenta con Debug— y se le pasa al preparar
> el valle. Medido: **22 414 celdas de cauce sobre la plataforma** donde antes no había
> ninguna (`tests/DebugCaptura.gd`). La regla está en GRAFICOS §3.

## 15. Depurar del 2026-09-17 (noche): el rótulo de la tecla y el aviso que se cerraba

Dos quejas del usuario, las dos de cosas que se leen en pantalla.

**El rótulo del panel de rendimiento decía F3 y el panel vive en F4.** Pasó porque la tecla
estaba **escrita** en el texto, y desde §11 las teclas son remapeables. Ahora el panel y el
cartel del mapa regional preguntan la tecla (`Teclas.nombre_de_la_tecla`), así que cambiarla
cambia lo que se lee. Las teclas que NO son acciones del catálogo —la F y la R del mapa
regional— siguen escritas, que para eso no son remapeables.

**El aviso de una técnica se abría y se cerraba solo.** Era el tooltip del motor: tiene
temporizador propio, se esconde al mover el ratón dentro del mismo control y se vuelve a
pedir después. `_make_custom_tooltip` sólo cambia lo que hay DENTRO del globo, no cuándo se
abre ni cuándo se cierra, así que la queja se repetía por más que se retocara.

La regla que pidió el usuario, literal, es **abierto siempre que el ratón esté encima**. Hoy
el globo es nuestro (`CasillaTecnica`): se abre al entrar el ratón, se cierra al salir y no
lo toca nada más —ni un temporizador, ni un redibujado—. Es uno solo para todas las
casillas, no se come el ratón (si lo capturase, taparía la casilla, la casilla se daría por
abandonada y el aviso se cerraría: justo lo que se venía a quitar) y se recorta contra los
bordes de la ventana. Dos pruebas en `TestTecnicas` lo fijan.


## 16. La resolución, también con la ventana maximizada (spec 2026-09-17)

> **Spec escrita con `/spec` el 2026-09-17.** Sale de una petición del usuario: «quiero
> hacer algo para poder cambiar la resolución en ventana maximizada». Las decisiones las
> tomó él con preguntas y están marcadas donde salen.

### Qué problema cierra

El juego se juega **maximizado**, y maximizado el selector de «Resolución» no hace nada: se
usa el tamaño del monitor. Fue una decisión explícita del 2026-09-14 —«la resolución sólo
vale en ventana»— porque eso es lo que Godot puede hacer con el tamaño de una ventana que
el gestor de ventanas manda. Y para dibujar a menos ya existe otra cosa, la **escala de
render** con FSR2, pero vive en la pestaña de Gráficos, se expresa en tanto por ciento y no
se llama resolución. Hay hasta una nota en la ventana que manda de un sitio al otro.

O sea: **lo que el usuario quiere ya se puede hacer, y aun así no lo encuentra**. Eso no es
un fallo del motor, es un fallo de la ventana: dos ajustes que hacen lo mismo para el
jugador —«que esto se vea más grande y vaya más suelto»— viven separados, con nombres
distintos y unidades distintas.

Y hay un motivo de fondo para arreglarlo ahora: el juego va **a 21-27 fps** en un valle con
bosque (medido en las capturas del 2026-09-17, GTX 1070 a 3651×2054). Bajar a cuánto se
dibuja es la palanca más grande que tiene el jugador, y hoy está escondida.

### Lo que se pide

- **Maximizado y a pantalla completa, el selector de «Resolución» manda sobre el dibujo**
  (decisión del usuario). Se elige a cuánto se dibuja el mundo y el resultado se estira a
  la pantalla; la ventana no se toca. En modo ventana sigue haciendo lo de siempre: cambiar
  el tamaño de la ventana.
- **Las opciones se leen en píxeles reales** (decisión del usuario): «1280 × 720», no
  «67 %». Se calculan sobre el tamaño real de la ventana, así que la lista dice a qué se
  está dibujando de verdad en ese monitor.
- **El escalado sigue siendo FSR2 por debajo del 100 %** (decisión del usuario), que es lo
  que ya usan los niveles de gráficos y lo que midió `GpuProfile`. No se añade un ajuste
  para elegir el filtro.
- **Un solo ajuste manda.** Elegir resolución de dibujo y escala de render son la misma
  cosa: lo que el jugador toque en un sitio tiene que verse reflejado en el otro, sin dos
  valores que se contradigan.
- **Se aplica en caliente y se guarda**, como el resto de la configuración.
- **La interfaz no se escala**: los paneles, el texto y los iconos siguen a la resolución de
  la ventana. Sólo se dibuja a menos el mundo 3D.

### Criterios de aceptación

- **Gana fotogramas, medido** (decisión del usuario sobre cómo darlo por hecho). Una sonda
  con ventana mide **ms de GPU y fps en el mismo sitio de un valle** con la ventana
  maximizada, a cada escalón de la lista, y la tabla va a `ESTADO.md`. El criterio es que
  cada escalón por debajo del tope **baje los ms de GPU de forma medible** (no dentro del
  ruido de la sonda) respecto al de encima.
- **Maximizado, elegir un escalón cambia lo que se dibuja**: la resolución interna del
  viewport 3D pasa a ser la elegida, comprobado con una prueba que lea el viewport, no a
  ojo.
- **La ventana no se mueve**: maximizado, elegir resolución no cambia el modo de ventana ni
  su tamaño. Prueba.
- **La interfaz se queda nítida**: el tamaño de la capa de interfaz no cambia al cambiar de
  escalón. Prueba.
- **Sobrevive**: se guarda y al abrir de nuevo el juego está lo elegido. Prueba con la
  carpeta de configuración de las pruebas, que no toca la del jugador.
- **Un solo valor**: no se puede dejar el juego con una resolución de dibujo elegida en
  Pantalla y una escala distinta en Gráficos. Prueba.

### Fuera de alcance

- **Cambiar el tamaño de la ventana desde maximizado.** Si el jugador quiere una ventana de
  1280 × 720, para eso está el modo ventana.
- **Elegir el filtro de escalado** (FSR2 frente a bilineal): se queda FSR2, decidido.
- **Escalar la interfaz.** Es otro trabajo y tiene su propio riesgo: el texto pequeño de los
  paneles es lo primero que se rompe.
- **Resolución por encima de la de la ventana** (supersampling): no se ofrece.
- **Tocar los niveles de gráficos** (Bajo/Medio/Alto/Ultra) ni lo que cada uno pone en la
  escala. Si el jugador elige a mano, manda lo que elija.
- **Las otras dos peticiones del mismo día** —los gráficos de la banda con su ropa y sus
  herramientas, y las mejoras de texturas del terreno—: son trabajos aparte, cada uno con
  su spec.

### Plan técnico (2026-09-17)

**Lo que ya existe, y es la mitad del trabajo.** El motor de esto está hecho:
`Configuracion.graficos["escala"]` guarda a cuánto se dibuja y `aplicar_graficos` lo
aplica al viewport raíz con FSR2 por debajo de 1. Lo que hay que hacer no es motor, es
**quitar la duplicidad**: hoy «a cuánto se dibuja» se contesta desde dos sitios con dos
unidades —la escala en Gráficos, en tanto por ciento, y el selector de Resolución en
Pantalla, en píxeles pero sólo en modo ventana—, y eso es justo el invariante 3 de
`SPECS.md` §7: *una pregunta, un sitio que la contesta*.

**Módulos afectados**

| Script | Qué cambia |
|---|---|
| `vista/Configuracion.gd` | La traducción entre resolución de dibujo y escala vive aquí, al lado de `resoluciones()` y de `aplicar_pantalla()`. Es el único sitio donde se convierte. |
| `ui/VentanaDeConfiguracion.gd` | El selector de «Resolución» de Pantalla pasa a mandar sobre el dibujo cuando la ventana no la dimensiona el jugador; sale de Gráficos la fila «Escala de render»; la nota que remitía de una a otra sobra. |
| `tests/TestConfiguracion.gd` | Las reglas nuevas: qué escala sale de qué resolución, que maximizado no se toca la ventana, que no quedan dos valores y que se guarda. |
| `tests/ResolucionProbe.gd` (nueva) | La medida con ventana: ms de GPU y fps por escalón. |
| `docs/INTERFAZ.md`, `docs/GRAFICOS.md`, `docs/ESTADO.md`, `docs/ROADMAP.md` | Lo aprendido y la tabla medida. |

Ninguno es un módulo nuevo del contrato de `SPECS.md` §4: `Configuracion` ya es el sitio
de los ajustes, y la ventana es sólo su cara.

**Decisiones de arquitectura** —las tres que la spec obliga a tomar, y ninguna más:

1. **El dato que manda es la escala**, no la resolución elegida. La resolución de dibujo
   depende del tamaño de la ventana, que cambia cuando el jugador mueve el juego a otro
   monitor; la escala no. Así que se guarda la escala —lo que ya se guardaba— y la lista
   se **deriva** de ella para enseñarla en píxeles.
2. **El selector de Pantalla hace dos cosas según el modo**, que es lo que pidió el
   usuario: en ventana cambia el tamaño de la ventana; maximizado y a pantalla completa
   cambia la escala de dibujo. La fila dice cuál de las dos está haciendo, para que nadie
   tenga que adivinarlo.
3. **La escala desaparece de Gráficos.** No se queda «también ahí»: dos controles sobre el
   mismo valor es el fallo que se viene a cerrar. Los niveles (Bajo/Medio/Alto/Ultra)
   siguen poniendo su escala al cambiar de nivel —Bajo la deja en 0,6— y elegir a mano
   sigue bajando el nivel a «personalizado», que es lo que ya hace `_nivel_que_encaja`.

**Orden de dependencias**: la traducción (1) antes que la ventana (2), y las dos antes de
medir (5): la sonda recorre los escalones que la ventana ofrezca.

**Riesgos que se nombran**

- **La resolución elegida no sale exacta.** Los escalones son escalas (0,5 · 0,6 · 0,77 ·
  0,9 · 1) y la ventana puede tener cualquier tamaño: 0,77 de 3651 px son 2811, no una
  cifra redonda. La lista enseñará **lo que de verdad se va a dibujar**, aunque no sea un
  número bonito. La alternativa —elegir píxeles redondos y deducir la escala— dejaría al
  jugador pidiendo 1280 y viendo 1284; peor.
- **Cambiar la escala en caliente rehace los búferes del render.** Da un tirón de un
  cuadro. Se acepta: es un ajuste que se toca una vez.
- **FSR2 a 0,5 sobre una ventana pequeña deja poca información**: por debajo de 1280 px de
  ancho efectivo la imagen se nota blanda. No se pone tope; se dice en la ventana.
- **Las sondas con ventana abren a la resolución del escritorio** —3651 × 2054 en esta
  máquina—, y el presupuesto de GPU está escrito a 1080p (GRAFICOS §7). La sonda fija el
  tamaño de ventana antes de medir, o las cifras no se pueden comparar con las de la tabla.

### Cómo quedó (2026-09-17)

**El selector de Pantalla hace dos cosas, y lo dice.** En modo ventana es «Tamaño de la
ventana» y cambia la ventana, con su cuenta atrás de confirmación, como siempre. Maximizada
y a pantalla completa —que es como se juega— es **«Resolución de dibujo»**: los mismos
cinco escalones de siempre (100 · 90 · 77 · 60 · 50 %) enseñados en píxeles de verdad
calculados sobre la ventana, y elegir uno cambia a cuánto se dibuja el mundo.

**Sin cuenta atrás**, a diferencia del tamaño: la confirmación existe para que una
resolución que el monitor no pueda dar no te deje sin ver nada, y dibujar a menos no puede
hacer eso. Se aplica y se guarda como cualquier otro ajuste de gráficos, y baja el nivel a
personalizado igual que los demás.

**Y la escala de render ya no está en Gráficos.** No se ha quedado «también ahí»: dos
controles sobre el mismo valor, con dos unidades, es la pregunta contestada desde dos
sitios que prohíbe SPECS §7. La lista de escalones vive ahora en `Configuracion`, que es
quien la aplica; la ventana sólo la enseña.

**Lo que gana, medido** (`ResolucionProbe`, ventana fijada a 1920 × 1080, valle del sitio
56, quieto en el mismo punto, 90 cuadros por escalón):

| Se dibuja a | Escala | GPU (ms) | fps |
|---|---|---|---|
| 1920 × 1080 | 100 % | 49,2 · 33,7 | 19,7 · 28,7 |
| 1728 × 972 | 90 % | 43,5 · 31,5 | 22,2 · 30,7 |
| 1478 × 832 | 77 % | 41,0 · 29,0 | 23,7 · 33,1 |
| 1152 × 648 | 60 % | 36,5 · 25,9 | 26,6 · 36,9 |
| 960 × 540 | 50 % | 33,5 · 23,1 | 28,9 · 41,3 |

**Van dos cifras por casilla porque son dos corridas del mismo código**, y es la lección
que el repositorio ya tenía escrita: los absolutos se mueven mucho entre corridas —49,2 y
33,7 ms para lo mismo— y una diferencia leída de una sola no es una diferencia. Lo que **sí**
se repite es la bajada: **−32 % y −31 % de GPU** del escalón más alto al más bajo, y cada
escalón por debajo del anterior en las dos. El criterio de la spec se cumple.

**Y dibujar a la mitad de lado no dobla los fotogramas**: de 19,7 a 28,9 en una corrida, de
28,7 a 41,3 en la otra. Es lo esperable y conviene decirlo, porque la mitad del coste de
este juego no depende de la resolución —geometría, draw calls, el bosque— y ésos no bajan
por dibujar más pequeño.

**La interfaz no se toca**: en las dos corridas y en los cinco escalones, la capa 2D se
queda a 1920 × 1080. Lo comprueba la propia sonda, columna «UI».
