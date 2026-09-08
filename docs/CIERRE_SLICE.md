# Cierre de la slice — dejar el Paleolítico jugable

Ata los flecos de la primera época para que deje de ser una demo de sistemas
sueltos y pase a ser una slice **jugable y balanceable**. No abre alcance
nuevo: cierra contradicciones y huecos de lo que ya existe.

Ver [SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) para el diseño de la época,
[ROADMAP.md](ROADMAP.md) para el plan general, [REVAMP_GRAFICO.md](REVAMP_GRAFICO.md)
para el plan visual y [SPECS.md](SPECS.md) para el contrato técnico.

**Nota de método.** Varios de los "flecos" reportados ya estaban resueltos en
el código y no se tocan aquí: el reparto de recolección/exploración entre
miembros de la banda (`SettlementSim._best_known_spot`, dispersión de 55 m,
tope duro por paraje), los estados `YENDO→BUSCANDO→TRABAJANDO→VOLVIENDO` con
su mapeo de animación correcto, y que caza y pesca ya dependen de tecnología y
herramienta disponible (`Hunting.gd`, `Fishing.gd`). Este documento cubre lo
que de verdad falta o está mal.

---

## 0. Orden propuesto, y por qué

1. **Sombras negras** — bug de percepción barato de acotar, y hace falta verlo
   arreglado para evaluar a ojo todo lo demás.
2. **Solape en tránsito** — otro bug de percepción, independiente del resto.
3. **Fuego y hogar** — el sistema nuevo más grande; desbloquea que "sin fuego"
   tenga consecuencia real, que alimenta el punto 7.
4. **Manufactura visible** — alto impacto de legibilidad, poco acoplado a lo
   demás.
5. **Pernocta de exploradores** — depende de que el jugador ya entienda las
   consecuencias por pantalla (punto 3 y 4) antes de que le pase un percance
   sin explicación.
6. **Fauna** — el bloque más caro en arte; va al final para no bloquear nada.
7. **Más juego, menos gestión** — transversal: sin ver qué hace la banda
   (puntos 3-4), pedir que el jugador decida "con nombre y cara" no tiene
   dónde apoyarse.

---

## 1. Sombras completamente negras

**Hipótesis a confirmar en juego, no a ciegas.** `SolarPosition.gd` calcula ya
el ángulo solar real por latitud/estación (máximo 70° en verano, 23° en
invierno en Cantabria), `WorldEnvironment.tscn` tiene `follow_time_of_day =
true`, y la partida arranca a las 6:00 — sol bajo desde el minuto uno. Sumado
a `fill_energy = 0.0` (luz de relleno de cielo desconectada del render por un
bug que el propio código admite no tener localizado) y sin SDFGI/SSIL, una
ladera a contraluz con sol bajo se queda solo con el ambiente del cielo.

`REVAMP_GRAFICO.md` midió esto y concluyó que las sombras estaban bien — pero
esa medida es de **antes** de `SolarPosition.gd`, con sol de mediodía fijo.
Nunca se ha vuelto a medir con sol real y bajo.

- No hace falta resolver el misterio de por qué `fill_energy` no toca el
  render — eso queda como deuda aparte.
- Sí hace falta que las sombras no se vean como agujeros negros en ningún
  momento jugable del día ni del año.

**Criterio de aceptación:** medir con `SombraProbe.gd`/`ReboteProbe.gd` (o el
que corresponda) en amanecer, atardecer e invierno, no solo a mediodía. La
razón sombra/luz debe quedar en rango fotográfico real (15-20 %) también en
esas condiciones, ajustando `fill_color`/`ambient_light_energy`/ángulo mínimo
de luz de relleno lo que haga falta — sin depender de arreglar `fill_energy`.

> **HECHO (6-sep-2026).** Tabla completa y explicación en REVAMP_GRAFICO §6.1.
> En corto: ninguna de las dos sondas servía —`LuzProbe` comparaba dos
> rectángulos a mano y el que hacía de sombra no lo estaba—, así que se midió
> con `SombraDiaProbe`, que fotografía la misma vista con el sol y sin él. Salía
> **5,8 %**, por debajo del 8 % que ya se lee como negro. `ambient_light_energy`
> «no hacía nada» porque con la fuente en el cielo su contribución vale 1 y el
> término de color queda fuera de la mezcla; bajándola a 0,5 la palanca existe.
> Queda en 17,5 % a mediodía de primavera y 18,1 % a mediodía de invierno. De
> paso, el color del cielo pasa a ir con la altura del sol y no con el reloj:
> el invierno salía con cielo de mediodía a las 16:30 sobre un valle a oscuras.

---

## 2. Banda: solape durante el desplazamiento

El reparto en el sitio de trabajo ya funciona. El problema está confirmado en
el **trayecto**: varias personas con destino distinto pero ruta A* compartida
se dibujan superpuestas mientras andan, no solo al llegar.

**Dirección de la solución:** aplicar al seguimiento de ruta el mismo patrón
que ya usa `_best_known_spot` para el sitio de trabajo — un desfase lateral
estable por persona (ángulo/offset derivado de `person.id`, no aleatorio cada
frame, para que no tiemble) mientras se sigue el mismo tramo de camino que
otro. Alternativa más barata si alcanza: pequeño jitter de fase/velocidad para
romper la fila exacta.

**Criterio de aceptación:** dos personas con mismo origen y destino se ven
como dos cuerpos claramente separados durante todo el trayecto, no solo un
instante al llegar al sitio de trabajo.

> **HECHO (6-sep-2026).** `SettlementSim.LANE_SPREAD` (carril lateral de 2,5 m,
> estable por `id` y desvanecido al llegar, o nadie tocaría nunca su destino) más
> `LANE_PACE` (±6 % de paso). Hacen falta los dos: el reparto áureo garantiza que
> dos personas no lleven el MISMO carril, no que no se rocen, y con quince en la
> banda los dos carriles más juntos quedan a menos de un palmo. Medido con
> `CarrilProbe` sobre parejas en tránsito de una partida real —las dos andando y
> las dos a más de 30 m de su destino—:
>
> | | el 1 % más junto | el 5 % | por debajo de un cuerpo |
> |---|---|---|---|
> | sin carril | 0,15 m | 0,63 m | 4,01 % |
> | sólo carril | 0,95 m | 4,38 m | 0,50 % |
> | **carril + paso** | **1,44 m** | **5,72 m** | **0,19 %** |
>
> Lo que queda son cruces —dos personas que se cruzan yendo a sitios
> contrarios—, que no son el fallo que se venía a arreglar.

---

## 3. Fuego y hogar

### 3.1 La contradicción, resuelta

Hoy `TechTree.Tech.FUEGO` se investiga en 20 jornadas, pero
`SLICE_PALEOLITICO.md` dice que la banda ya sabe hacer fuego desde el
principio (`ATESTIGUADO`) y que empezar "descubriendo el fuego" es un tópico
de género y es falso.

**Decisión:** el fuego es saber inicial, no investigación. Se quita
`Tech.FUEGO` del árbol tecnológico. Lo que sigue haciendo falta —y ya
existe— es **construir** el hogar (`CampProjects.Kind.HOGAR`): la banda llega
a un abrigo nuevo sin hogar delimitado y lo levanta, como ya hace hoy.

**Consecuencia a resolver:** dos tecnologías dependen hoy de `Tech.FUEGO` como
prerrequisito — `Tech.PIRAGUA` (`needs: [FUEGO, NUCLEO]`) y `Tech.ARTE`
(`needs: [FUEGO, HOJA]`). Al quitar `Tech.FUEGO`, esas dependencias pasan a
ser **"hogar construido"** (un hecho del campamento, no una tecnología que se
investiga), porque piragua y arte parietal siguen necesitando fuego de
verdad, solo que ya no hay que "descubrirlo".

### 3.2 El hogar como instalación real, con estados

Hoy `_tend_camp` es una línea de log cosmética ("manteniendo el fuego") sin
leña consumida ni estado real. Pasa a tener:

- **Estados**: encendido (brasas vivas) / apagado. Consume `Materia.Kind.LENA`
  de la reserva a un ritmo — el número exacto se deja para balancear en
  playtest, no se fija aquí.
- **Reavivar** cuesta jornada de alguien de `Job.HOGAR`; si nadie lo cuida y se
  agota la leña, se apaga.
- **Consecuencias de apagado**: sin cocinar (se pierde el bono de digestión
  que ya describe `Tech.FUEGO` hoy), sin ahumado si hay `SECADERO`, y
  penalización de frío en invierno (a definir con el mismo criterio de
  balance que el resto: aquí se declara que debe doler, no cuánto).
- **Especialidades nuevas dentro de `Job.HOGAR`** (hoy no tiene ninguna,
  `Profession.SPECIALITIES` no lo lista): al menos **mantenimiento del
  fuego/yesquero** (reaviva, vigila el consumo) y **ahumado** (una vez hay
  `SECADERO`); evaluar si **cuidado** (niños/ancianos/enfermos, ya mencionado
  en la descripción del oficio) merece ser una tercera o queda implícito.

**Criterio de aceptación:** la banda arranca en un abrigo sin hogar, lo
levanta como primera prioridad (ya ocurre), el hogar puede apagarse de verdad
si falta leña o nadie lo cuida, y esa falta tiene consecuencia visible en
crónica/log — no silenciosa.

> **HECHO (6-sep-2026).** Con una corrección de premisa: **«lo levanta como
> primera prioridad» NO ocurría**. Poner una obra en cola sólo lo hacía el
> jugador desde el panel, así que la banda no levantaba el hogar jamás si nadie
> abría ese menú. Medido antes de arreglarlo: cuarenta y cinco jornadas con
> ciento ochenta y cinco unidades de leña guardadas y el abrigo todavía sin
> hogar, o sea la banda entera comiendo crudo. Ahora `_tend_camp` lo pone en
> cola solo si falta.
>
> Lo demás, tal como estaba pedido: `hearth_lit` con consumo diario de
> `Materia.Kind.LENA`, apagado por falta de leña **o** por falta de quien lo
> cuide, reavivar que cuesta jornada de `Job.HOGAR` y leña, y sin fuego no se
> cocina (`cooked` mira `hearth_lit`, no `camp_built`), no se ahuma y en
> invierno se descansa peor. Todos los números viven juntos en
> `SettlementSim`, bajo «Lo que cuesta tener fuego», y están **sin calibrar**.
>
> Reavivar exige además leña para el resto del día, no sólo para prender: sin
> esa condición la banda entraba en un bucle de encenderlo por la mañana y
> quedarse fría por la noche, quemando cada jornada la leña recién traída sin
> llegar a tener fuego nunca. Medido en `HogarProbe` con el almacén de leña
> vaciado a la fuerza.
>
> Especialidades de `Job.HOGAR`: **yesquero** (prende antes, estira la leña),
> **ahumado** (cura más, sólo con `SECADERO`) y **cuidado**. La tercera sí
> entra, y no como rótulo: acorta la convalecencia de `hurt_days`, que es lo
> que enlaza el hogar con los percances del §5. Una especialidad sin efecto
> mecánico habría sido una etiqueta.
>
> Y se ve sin abrir la crónica: la barra de arriba dice «sin hogar» mientras no
> esté levantado y «EL HOGAR ESTÁ APAGADO» cuando se apaga. Encendido no dice
> nada, que es lo normal y sería ruido.

---

## 4. Manufactura visible

`craft_progress` existe (`Inhabitant.gd`) pero no se expone en ningún sitio:
hoy es imposible saber en pantalla qué está tallando alguien ni cuánto le
falta.

**Solución:** icono + barra de progreso flotante sobre la cabeza de quien
fabrica, visible sin abrir ningún panel — leyendo `craft_progress` y la pieza
activa que ya decide `_next_piece`. Es, literalmente, el criterio que ya
tenía escrito `REVAMP_GRAFICO.md` en su fase G6 ("se sabe qué está haciendo
cada uno sin abrir un panel"), extendido de "qué anim toca" a "qué se está
fabricando y cuánto falta".

**Criterio de aceptación:** con solo mirar a un artesano trabajando se ve qué
pieza está haciendo y una estimación de cuánto le falta, sin clicar nada.

> **HECHO (6-sep-2026).** `CraftMarkers` + `CraftBadge`: chapa que mira a
> cámara sobre la cabeza, con el glifo de la pieza —los mismos del almacén y de
> los parajes— y una barra con lo que lleva hecho. Reutiliza el idioma de
> [ParajeMarkers] y [TrapMarkers] en vez de inventar otro, y se repinta sólo
> cuando el progreso da un paso del 2 %: un `SubViewport` por artesano y por
> fotograma sería carísimo para un dato que avanza despacio.
>
> La trampa que se llevó por delante el primer intento, y que queda con prueba
> propia: **el artesano nunca pasa por `TRABAJANDO`**. El taller no sale del
> abrigo, así que se queda en `OCIOSO` y `_craft` se llama desde ahí; mirar el
> estado para saber si alguien fabrica dejaba la chapa apagada siempre.

---

## 5. Pernocta de exploradores fuera del abrigo

Hoy quien pasa la noche fuera (expedición/ascensión) solo gasta comida de
mochila y recupera menos fatiga si no puede volver. No hay pieles ni troncos
de vivac.

**Solución:** expediciones y ascensiones que prevén pernoctar cargan, además
de comida, **pieles** (para una tienda pequeña) y **troncos** (para una
hoguera de vivac). Si al llegar la noche falta alguno de los tres, se
engancha al sistema de percances ya existente (`Mishap.gd`, mismo `enum Kind`
que cubre otros riesgos de expedición) en vez de solo penalizar la
recuperación de fatiga como hoy — dormir mal a la intemperie puede dejar una
herida, un retraso o un percance real, no solo cansancio.

Las cantidades (cuánta piel/tronco por noche/persona, probabilidad de
percance por carencia) se dejan como parámetros a ajustar en balanceo, no se
fijan en este documento.

**Criterio de aceptación:** una partida mal avituallada para pernoctar corre
un riesgo real y medible (aparece en la misma crónica que otros percances);
llevar lo necesario lo evita.

> **HECHO (6-sep-2026).** `_pack_bivouac` carga tienda y hoguera además de la
> comida; `_bivouac` cobra la noche una sola vez —se llama desde el tick
> nocturno, o sea sesenta veces por segundo— y `_check_mishaps` multiplica el
> riesgo por `VIVAC_RIESGO` elevado a las carencias. La piel NO se gasta: se
> lleva y vuelve al abrigo, que es lo que se hace con una tienda; lo que se
> pierde es la noche que no se llevó. La leña arde.
>
> Medido con `VivacProbe`, catorce jornadas con cuatro personas en expedición:
>
> | almacén | noches fuera | malas | percances |
> |---|---|---|---|
> | con piel y leña | 34 | 4 (12 %) | 4 |
> | vaciado a la fuerza | 21 | 21 (100 %) | **13** |
>
> Por noche pasada fuera, 0,12 percances contra 0,62: cinco veces. Y salen
> menos noches en la partida mal avituallada precisamente porque los percances
> les hacen dar media vuelta.
>
> De paso, un número que no era obvio: sin margen de noches la mitad de las
> noches se dormían sin fuego **aun con el almacén lleno**, porque la cuenta de
> días de expedición se redondeaba a la baja. De ahí `VIVAC_MARGEN_NOCHES`.

---

## 6. Fauna: locomoción real

Confirmado en código, no solo apreciación: jabalí, corzo y rebeco usan mallas
prestadas (cerdo, oveja respectivamente) de un pack que **solo hornea reposo y
salto**, sin ciclo de marcha — por eso no se ven mover las patas al andar
(`WildlifeHerds.MOVE_CLIP`, esas especies caen siempre en `"idle"`). El rumbo
(`heading`) sí se recalcula en código en cada movimiento, pero hay que
verificar en juego que el giro hacia la dirección de marcha se perciba
correctamente — puede haber un desajuste entre el heading calculado y la
orientación real del modelo baked.

**Alcance ampliado, según lo pedido:** además de arreglar el bug, conseguir
malla/impostor propio para las especies de caza mayor relevantes (ciervo,
cabra/rebeco al menos) en vez de heredar el esqueleto de caballo/oveja —
mismo tratamiento que ya se le dio a árboles y props del suelo.
`scripts/tools/FaunaAtlas.gd` ya existe como herramienta de horneado; es
ampliarla, no inventar el proceso.

**Criterio de aceptación:** cada especie de caza mayor anda con un ciclo de
marcha propio y visible, gira hacia donde se mueve de forma perceptible en
pantalla, y ciervo/cabra/rebeco dejan de compartir silueta con caballo/oveja.

> **HECHO (6-sep-2026), con dos cosas que declarar.**
>
> Lo primero fue comprobar la premisa en vez de creerla: `ClipProbe.gd` lista
> las animaciones que trae cada fichero, y confirma que `Pig.fbx` y `Sheep.fbx`
> sólo tienen `Idle` y `Jump` —también la versión de la web del autor, que se
> descargó para mirarlo—. El ciclo de marcha no estaba mal cableado: no existía.
>
> El pack «Ultimate Animated Animals» de Quaternius (CC0, mismo autor) sí trae
> ciervo, venado y toro con `Walk` y `Gallop`. Horneados con `FaunaAtlas`:
> ciervo→venado, corzo→ciervo pequeño, rebeco→ciervo pequeño gris,
> jabalí→toro oscuro. Las tallas se recalcularon con `FaunaTallaProbe` para que
> cada especie mida **en pantalla lo mismo que antes**: cambia la silueta y el
> paso, no el equilibrio visual del valle.
>
> **El giro tenía un fallo de verdad, y no era el que se sospechaba.** El rumbo
> se calculaba bien; lo que no cuadraba era la malla. `FaunaRumboProbe` pone a
> cada bicho un rumbo conocido y una bola donde debería quedarle la cabeza: el
> lobo del pack viene tumbado un cuarto de vuelta respecto a los demás, así que
> lobo, liebre y conejo —las tres usan esa malla— cruzaban el valle **andando de
> costado**. De ahí `WildlifeHerds.MODEL_YAW`.
>
> Lo que NO se ha podido cerrar, y queda escrito en CREDITOS y en `FaunaAtlas`:
> no hay bóvido de montaña ni suido con marcha en CC0 descargable por script, y
> **la cuerna del venado se pierde al hornear** —viene en una malla aparte
> colgada de un hueso, y el horneado a textura de vértice sólo se lleva una
> malla con pesos—. Un ciervo sin cuerna en plena berrea es una pérdida real.

---

## 7. Más juego, menos simulador de gestión

Cuatro líneas, las cuatro dentro de este goal, cada una apoyada en un sistema
que ya existe:

### 7.1 Decisiones con nombre y cara
Elegir quién va a la expedición de otoño o quién sube al pico debe presentarse
como elegir personas concretas —con edad, rasgos, relación con otras—, no
"asignar 2 trabajadores". El dato ya existe (`Inhabitant`); lo que falta es
que la UI de asignación lo muestre en vez de una cifra, para que perder a
alguien concreto en un percance (§5, `Mishap.gd`) pese de verdad.

### 7.2 Momentos de control directo
En instantes ya identificados por el propio sistema —la berrea, un encuentro
con otra banda, un percance de `Mishap.gd`— el juego ofrece una decisión
puntual en el momento (aceptar el riesgo de una caza mayor solitaria, elegir
cómo reaccionar a un lobo cerca del rebaño) en vez de que todo se resuelva por
planificación previa. No sustituye la gestión: la interrumpe en los puntos de
mayor tensión narrativa que la propia `SLICE_PALEOLITICO.md` ya señala.

### 7.3 Tensión visible del otoño
`SLICE_PALEOLITICO.md` ya dice que el otoño decide el invierno. Falta que se
**sienta**: una señal clara y permanente en pantalla de cuánto se lleva
acumulado de cara al invierno durante la berrea (no solo un número en un
panel de gestión que hay que ir a mirar), para que la decisión de dónde poner
el esfuerzo tenga urgencia real mientras se juega, no solo al revisar
estadísticas.

### 7.4 Descubrimiento como recompensa, no como dato
Encontrar un paraje nuevo o coronar un pico (`_reveal_from_summit`, que ya
revela una zona amplia del valle) debe notarse en el momento —cámara,
aviso, entrada de crónica destacada—, no ser solo un cambio silencioso en el
mapa de niebla de guerra que el jugador descubre después si se fija.

> **HECHO (6-sep-2026).** Las cuatro, y tres de ellas sobre una pieza nueva:
> `Moment` —un instante en que la partida deja de ser gestión y te mira—. Sin
> opciones es un hallazgo que se enseña; con opciones es una decisión, y
> entonces **para el reloj**. Sólo entonces: si cada paraje bautizado congelara
> la partida, en dos estaciones el jugador aprendería a cerrar la tarjeta sin
> leerla. Al reanudar se devuelve la velocidad que había, no una fija.
>
> - **7.1 Nombre y cara.** El panel de la cumbre ya no dice «el mejor la ve al
>   62 %» con un botón que manda a quien elija la máquina: lista a cada
>   candidato con su edad, su oficio y en qué destaca, cada uno con su «que
>   suba» (`climbers_for`, `order_ascent(peak, who)`), **y también a los que no
>   se atreven**, porque «me faltan manos» y «me falta pericia» son dos
>   problemas con dos remedios distintos. En el panel de oficios, exploración y
>   caza —los dos de los que se puede no volver— listan quién sale hoy por su
>   nombre.
> - **7.2 Control directo.** Berrea: al entrar el otoño, con la reserva delante,
>   volcarse o seguir igual. Percance: cuando queda margen —una torcedura, no
>   una caída, que ya obliga a volver— se decide si vuelve o aprieta los
>   dientes, y aguantar cuesta días de convalecencia. **El encuentro con otra
>   banda se queda fuera y no por olvido**: `SLICE_PALEOLITICO` excluye de la
>   slice que haya más de una banda, así que no hay tal encuentro que
>   interrumpir.
> - **7.3 Tensión del otoño.** Medidor fijo debajo del reloj: raciones
>   guardadas contra las que se comerán en invierno, con barra y tres colores
>   —se llega, va justo, no se llega—. En otoño el rótulo cambia a «BERREA» y
>   se pone en ocre. No se puede cerrar, que es el punto.
> - **7.4 Descubrimiento.** Coronar un pico y bautizar un paraje levantan su
>   momento, con botón de llevar la cámara al sitio.

---

## Fuera de alcance de este goal

- **Tinte de árboles con `terrain_tint`** — confirmado como bug real (`tint`/
  `brightness` del shader de impostor nunca se fijan en `Forest.gd`), pero
  queda como deuda documentada, no se toca aquí.
- **El bug de `fill_energy`** en sí mismo — solo se corrige su síntoma (§1).
- Todo lo que `SLICE_PALEOLITICO.md` ya excluye de la slice: comercio entre
  asentamientos, más de una banda, construcción de estructuras, épocas
  posteriores, enciclopedia.
