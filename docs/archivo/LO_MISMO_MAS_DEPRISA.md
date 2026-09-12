> **ARCHIVADO (2026-09-12).** Este documento ya no se edita. La documentación
> se reorganizó para que lo único específico fueran las fichas de época, y
> **casi terminada**: lo que queda vivo está en **[ROADMAP.md](../ROADMAP.md)**, sección «En curso». Ojo al aviso del contador de tirones que abre este documento.
>
> Se conserva entero porque guarda **lo que no cabe en un documento permanente**:
> qué se probó, qué salió, qué premisa se cayó a mitad y por qué se decidió lo
> que se decidió. Nada de lo que sigue se ha tocado — incluidas las cosas que
> hoy ya no son verdad, que se reconocen porque el documento permanente dice
> otra cosa y **gana el permanente**.

---

# Lo mismo, más deprisa

Depurar el rendimiento de la capa local **sin cambiar lo que pasa en la
partida**: bajar lo que cuesta calcular cada cosa, no lo que se calcula.

Nace de [ESTADO_DE_LA_SLICE.md](../ESTADO.md) §5, punto 12 —la
caza de tirones que bajó el peor fotograma de 2.541 ms a 143— y de la queja
que quedó abierta después: *«hay tirones de varios segundos y se hacen más
comunes según avanza la partida»*. Ver también
[QUE_SE_PUEDA_PERDER.md](QUE_SE_PUEDA_PERDER.md), cuyas medidas de balanceo
son las que este bloque se compromete a no mover.

> ## AVISO (2026-09-11): el contador de tirones mentía
>
> **Todas las cifras de «cuántos tirones» de este documento anteriores a esta
> nota están mal, y por mucho.** El panel de F3 y la sonda leían la MISMA
> bandeja de picos de [Cronometro] y **la vaciaba quien leía**, así que el
> primero que pasaba se los llevaba y el otro contaba de menos. Medido: el
> cepo empujaba **92 picos** en dos jornadas y la sonda contaba **3**.
>
> Lo descubrió el jugador mirando su F3 —«el panel mostraba tirones de más de
> 100 ms cada 0,2 s»— contra un informe mío que decía «8 tirones en todo el
> año». Y casi se tapa: mi primer arreglo fue apagar el panel durante las
> corridas, que es arreglarlo para la sonda y romperlo para quien mira.
>
> **Arreglado de verdad:** la bandeja la vacía el cepo al abrir cada
> fotograma, y la leen los dos. Comprobado: 89 empujados, 89 contados, con el
> panel vivo.
>
> **Qué queda en pie y qué no:**
>
> - **En pie:** las huellas —la partida no cambia, y eso no depende del
>   contador—, y los fotogramas por segundo y el peor fotograma de cada
>   jornada, que la sonda cronometra por su cuenta.
> - **Anulado:** todo recuento de tirones y todo «coste por llamada» sacado de
>   los picos antes del arreglo, porque salían de una muestra del 3 %. Las
>   comparaciones antes/después siguen siendo del mismo signo —los dos lados
>   usaban la misma muestra rota— pero sus porcentajes hay que rehacerlos.
>
> **Lo que de verdad se ha conseguido hasta ahora**, con la medida que no
> dependía del contador (fps y peor fotograma por jornada, línea base contra
> ahora):
>
> | jornada | línea base | con 21.1-21.4 |
> |---|---|---|
> | 77 | 0,4 fps · peor 5.665 ms | 2,5 fps · peor 760 ms |
> | 90 | 0,4 fps · peor 6.321 ms | 2,6 fps · peor 806 ms |
> | 136 | 1,4 fps · peor 1.957 ms | 2,4 fps · peor 831 ms |
> | 100 | 5,9 fps · peor 316 ms | 5,9 fps · peor 291 ms |
>
> Los días malos mejoran seis o siete veces; los buenos siguen igual. **Y la
> partida sigue a 300 ms por fotograma de media en esa zona del año**: el
> bloque no está ni cerca de terminado.

## Motivación

Todo lo que se ha medido de tirones hasta ahora cubre entre tres y doce
jornadas. La queja dice que la cosa **empeora con los días**, y nadie ha
mirado un año. `TironAnualProbe` existe para eso: corre las 180 jornadas,
vuelca el desglose de cada tirón grave en el momento en que ocurre y, al
final, suma todos los tirones del año por tramo.

La primera foto —un solo día— ya desmiente lo que se daría por hecho: el
«paso de simulación» se lleva el **86 %** del tiempo de los tirones (52 ms de
media por llamada, 92 llamadas) y la búsqueda de caminos, que fue la culpable
la vez anterior, sólo el **14 %**. Pero un día es el primer día, el de la
siembra de parajes y los primeros repartos, y no dice nada de lo que crece.
El orden de ataque tiene que salir del año medido, no de lo que se arregló la
última vez.

**Por qué «sin cambiar comportamiento» es la condición y no un deseo.** La
simulación va a paso fijo precisamente para que las cifras de balanceo no se
ajusten contra ruido: con el `delta` del fotograma, la misma semilla daba
entre 2,8 y 14,5 días de despensa. Una optimización que mueva el
comportamiento aunque sea un poco invalida en silencio todo lo calibrado hasta
hoy, y mezcla dos preguntas —¿cambió el número por el ajuste o por la
optimización?— que después ya no se pueden separar. Este bloque va en
cuarentena: sólo cambia el coste.

## Lo que hoy impide comprobarlo

El criterio central —misma semilla, misma partida, día a día— **hoy no se
cumple**, o no hay garantía de que se cumpla. Leyendo el código (aún sin
medir) salen estos sitios donde la partida depende de la máquina y no de la
semilla:

1. **La fauna anda por fotograma.** Las manadas piensan y se mueven en su
   propio `_process`, con el `delta` del fotograma, fuera del paso fijo: a
   velocidad ×20 y con fotogramas de 400 ms, un animal da saltos de ocho
   segundos de monte. Y la simulación la lee a cada rato —la cacería busca
   pieza y la espanta, el lobo mira la fauna, el censo la cuenta—, así que
   dónde está cada animal decide qué se caza. Es la fuente más gorda.
2. **El horno de rejillas de caminos por estación** amasa por milisegundos de
   reloj real, y la banda cambia a la rejilla de la estación nueva «en cuanto
   está lista». En la práctica acaba mucho antes del cambio de estación; pero
   ese «en la práctica» es justo lo que este bloque va a alterar.
3. **El repaso de la forma de los parajes** gasta como mucho dos milisegundos
   de reloj por vuelta. Cuántas formas se ponen al día depende de la máquina, y
   la forma decide dónde se trabaja. Es el caso más claro de la trampa de esta
   spec: **abaratar ese cálculo haría caber más formas por vuelta y cambiaría
   la partida sin tocar ninguna cifra.**
4. **Las charcas de la fauna** se eligen barajando con el azar global del
   motor, no con uno sembrado. Salen distintas en cada corrida, y con ellas
   por dónde andan las manadas.
5. **El cotejo de cuevas descubiertas** va cada 90 fotogramas, no cada tantos
   pasos de simulación, y escribe en la crónica. Con fotogramas más rápidos, la
   misma cueva se apunta a otra hora o en otro día.
6. **Un momento con decisión para el reloj a mitad de un fotograma.** Se
   lanza desde dentro de un paso; la interfaz pone la velocidad a cero ahí
   mismo, y los pasos que le quedaban a ese fotograma se dan igual, con tiempo
   cero —y cuántos quedaban depende del fotograma—. Y en las sondas hay algo
   sin explicar: la interfaz se engancha antes que la sonda, así que para el
   reloj primero, y la sonda contesta la decisión sin cerrar la tarjeta, que
   es lo único que devuelve la velocidad. Sobre el papel la sonda tendría que
   quedarse colgada en la primera decisión, y no se quedó.

**Una sospecha que no era:** se pensó que las sondas dejaban correr el reloj
mientras cargaban la escena. No: la partida arranca en pausa y la sonda pone
la velocidad después de repartir, así que el arranque sí es repetible.

El resto de lo que va por fotograma o por reloj —el refresco de paneles, las
chapas, las medidas de arranque— sólo pinta o sólo imprime, y no toca la
partida.

## Alcance

### 0. Que la misma semilla dé la misma partida

Es el paso previo, y el **único cambio de comportamiento** que admite el
bloque: declarado, hecho una sola vez y **antes** de medir la línea base.

- Todo lo que escribe en la partida se rige por el paso de simulación y por
  azar sembrado, nunca por el reloj real ni por el número de fotograma. Cubre
  las seis fuentes de arriba y cualquier otra que aparezca al hacerlo.
- Los presupuestos que hoy se miden en milisegundos pasan a no poder decidir
  nada de la partida: como mucho, cuánto trabajo se adelanta. Con una
  condición: **el tirón que cada presupuesto evitaba no puede volver** (una
  rejilla entera cuesta del orden de 900 ms; por eso se amasa a trozos).
- Si una prueba de la suite afirma justo la conducta que se quita, cambia con
  ella, y **sólo en este paso**. Después la suite queda congelada.

Las tablas de balanceo medidas antes de este paso se tomaron con estas
fuentes de ruido dentro. Después de él, la referencia es la línea base nueva,
no aquellas tablas.

### 1. La huella diaria

Lo que se compara día a día entre dos corridas. Como mínimo lo que pide la
queja —**despensa, técnicas, heridos**— y además lo que la delataría antes:
población y quién está viva, leña, parajes conocidos, cacerías, desenlace y la
crónica (número de entradas y su contenido).

- Se compara **a precisión completa**, no redondeado a lo que imprime una
  tabla. Una diferencia en la sexta cifra decimal hoy puede ser una persona de
  más dentro de cuarenta jornadas.
- Se compara con **igualdad exacta**, sin tolerancias: si la simulación es
  repetible, dos corridas iguales dan exactamente lo mismo, y cualquier
  tolerancia escondería justo lo que se busca.
- Se toma **en el paso en que se cierra la jornada**, no en el fotograma en
  que la sonda se entera: entre dos fotogramas pueden haber pasado varios
  pasos, y cuántos depende de la máquina.
- Puede tomarse en la misma corrida que las medidas de tiempo, siempre que se
  demuestre que medir no la cambia: el cepo de tirones sólo lee el reloj.

### 2. Arrancar en la jornada N

No hay guardado de partida, así que medir las jornadas 120 a 150 obliga hoy a
correr las 120 de antes: dos horas de reloj por cada medida. Por decisión de
este bloque, las sondas podrán **guardar la partida en una jornada y volver a
arrancar desde ahí**.

- Es una herramienta de medida, no el guardado del juego: sin interfaz, sin
  promesa de que un fichero de hoy sirva mañana, y fuera del alcance de la
  persistencia de la FASE A3 del roadmap.
- Sirve si, y sólo si, **arrancar en la jornada N da la misma huella que haber
  corrido desde la uno**, jornada a jornada. Una instantánea que se deja algo
  fuera es peor que no tener ninguna: mide otra partida creyendo que es la
  misma.

### 3. La línea base y el ranking

Con el paso 0 hecho, un año completo de `TironAnualProbe` con semilla fija,
**dos veces**. Las dos corridas sirven para dos cosas a la vez:

- demostrar que la partida se repite —huella idéntica las 180 jornadas—;
- saber **cuánto varían los tiempos de cada tramo entre dos corridas iguales**:
  la banda de ruido. Sin ella no se puede decir si otro tramo «ha empeorado»;
  un tramo que sube un 3 % entre dos corridas idénticas no ha empeorado.

La primera de las dos deja además instantáneas cada pocas jornadas: son los
puntos de arranque de todas las ventanas que vengan después.

El ranking es el orden de «SUMANDO TODOS LOS TIRONES DEL AÑO», con dos reglas
para leerlo:

- **Las filas de suma no son tramos.** «EL JUEGO», «EL MOTOR» y los tramos que
  contienen a otros —el `_process` entero de la simulación contiene el paso—
  suman lo de dentro. Entran en el ranking (el motor incluido, por decisión de
  este bloque), pero como pregunta: qué hay debajo.
- **Un tramo demasiado grueso se desglosa antes de optimizarlo.** El «paso de
  simulación» sólo tiene marcados dentro el cierre de jornada y el repaso de
  rezagados, o sea que casi todos sus 52 ms están sin explicar. Marcar más
  tramos dentro es instrumentación, no optimización, y tampoco puede cambiar
  la huella. Se hace antes de la línea base, para que el ranking salga ya
  desglosado.

Se apunta también, junto al ranking, lo que ya da la sonda sobre el
crecimiento: primer cuarto contra último cuarto del año, y la línea diaria de
nodos, salidas, crónica y memoria. Un tramo barato de media que crece con los
días puede importar más que uno caro y plano.

Y se apunta el estado de la suite ese mismo día: número de pruebas y de
comprobaciones, y los `SCRIPT ERROR` que imprime aunque pase. El pedido habla
de 716 pruebas y la última cifra anotada en `QUE_SE_PUEDA_PERDER` es 846; la
que cuenta es la del día de la línea base. Los `SCRIPT ERROR` también cuentan,
porque en este arnés una prueba que revienta a medias sigue saliendo como
pasada (`QUE_SE_PUEDA_PERDER`, tarea 5).

### 4. Una optimización cada vez, del más caro al más barato

- **Un tramo por cambio**, en el orden del ranking. Si al bajar uno el orden se
  reordena, el siguiente es el nuevo más caro: el ranking se vuelve a leer, no
  se congela el primer día.
- **Cada cambio se valida en una ventana corta** —del orden de 30 jornadas— que
  cubra los días en que ese tramo pesa según el año de la línea base (el día y
  la hora de sus tirones están en el volcado), **arrancando de la instantánea**
  más cercana por debajo. Misma semilla, misma ventana, antes y después.
- **Las tres pruebas, todas, no una impresión:**
  1. **Tiempo.** El tramo baja en **coste por llamada** (milisegundos entre
     llamadas) y en suma sobre los tirones. Hacen falta las dos cifras,
     porque la suma sobre tirones sólo cuenta los fotogramas que pasan del
     límite: si un cambio acorta los fotogramas, cruzan menos, y la suma baja
     también en tramos que nadie ha tocado; y al revés. El coste por llamada es
     lo que mueve el cambio; la suma es lo que nota quien juega. **Ningún otro
     tramo** sube su coste por llamada por encima de la banda de ruido.
  2. **La suite, tal cual.** Mismo número de pruebas y de comprobaciones que
     en la línea base, cero fallos, ningún `SCRIPT ERROR` nuevo, y ninguna
     prueba retocada para que pase.
  3. **La huella, idéntica** todas las jornadas de la ventana, y idéntica
     también a la del año de la línea base en esas mismas jornadas.
- **Lo que no puede cambiar**, además de las cifras de balanceo y los
  umbrales de decisión: el orden en que ocurren las cosas. Eso incluye, y es
  donde se va a tropezar:
  - **el orden de recorrido** de personas, animales y parajes;
  - **el número y el orden de las tiradas** de azar: una tirada de más o de
    menos desplaza todas las siguientes;
  - **los empates al ordenar**: otro algoritmo, o uno que no conserve el orden
    de los iguales, cambia quién va primero;
  - **los presupuestos que se cuentan en trabajo hecho**. El de caminos se
    cuenta en nodos abiertos por paso: un A\* que encuentra el mismo camino
    abriendo menos nodos deja más presupuesto a los siguientes de ese mismo
    paso, y eso ya cambia quién sale con camino. Es coste y comportamiento a
    la vez;
  - **las cachés** que devuelven algo calculado en otro momento del que se
    habría calculado sin ellas.
- Una optimización que no pasa la prueba 3 **se descarta o se rehace**, nunca se
  acepta porque la diferencia sea pequeña. Si la única forma de bajar un tramo
  cambia el comportamiento, se anota y queda fuera: pasa a ser una decisión de
  balanceo, con su propia spec.
- Que la partida vaya más deprisa cambia cuántos pasos de simulación caben en
  un fotograma y cuántos fotogramas hay por jornada. Eso no es un cambio de
  comportamiento —la secuencia de pasos es la misma—, y es exactamente lo que
  el paso 0 tiene que garantizar.

### 5. El motor y la vista

Entran en el ranking por decisión de este bloque. No aparecen en la huella —y
la huella tiene que seguir idéntica: si tocar la vista mueve la partida, eso
ya es un hallazgo—, pero **pueden cambiar la imagen**, que es lo único que
este bloque admite ver cambiado.

- Cada cambio de este tipo va con capturas de antes y después: misma cámara,
  mismo día, misma hora de juego y misma semilla. Se hacen con ventana, no sin
  ella, porque sin ventana no hay imagen.
- Se acepta o no **a criterio de quien dirige el proyecto**, a la vista de
  las capturas. No hay umbral numérico de «se parece lo suficiente».

### 6. El cierre

**No hay objetivo numérico.** Se va del tramo más caro al más barato y el
bloque se cierra cuando quien dirige el proyecto lo decida.

Lo que tiene que existir en ese momento:

- un segundo año completo, desde la jornada uno y con la misma semilla que la
  línea base, con la huella idéntica a la de la línea base las 180 jornadas;
- la suite en verde, en las mismas condiciones de la prueba 2;
- una tabla de línea base contra cierre, por tramo: suma sobre tirones, coste
  por llamada, porcentaje y llamadas; y del conjunto: tirones de más de 100 ms,
  tirones graves y primer cuarto contra último cuarto del año;
- este documento con una nota de **HECHO** por tramo, en el estilo del resto:
  qué costaba, qué se hizo, qué quedó y lo que se probó y no valió.

## Cómo se mide, para que dos medidas se puedan comparar

- **Siempre las mismas condiciones**: mismo emplazamiento (el 56), misma
  semilla, misma `VEL`, mismo `LIMITE`. La velocidad no es neutra: cuántos
  trozos se hace cada paso depende de ella, así que dos huellas sólo se
  comparan a la misma `VEL`.
- **Con ventana.** El motor está dentro del ranking, y sin ventana no se pinta:
  un ranking medido así se deja fuera justo uno de los tramos.
- **De una en una.** Dos sondas a la vez se estorban y falsean las cuentas, y
  un Godot que se queda vivo tras parar una sonda ralentiza la siguiente hasta
  cinco veces.

## Fuera de alcance

- **Cambiar cifras de balanceo, umbrales o el orden de nada**: es la premisa
  del bloque. Si optimizando se descubre un fallo de comportamiento —algo que
  se calcula y se tira cuando debería usarse, por ejemplo—, se anota y va a su
  propia spec; no se arregla aquí de paso, porque arreglarlo cambia la huella.
- **Un objetivo de fotogramas por segundo.** Ni los 60 de `SPECS.md` §5 ni
  otro: el cierre es una decisión, no una cifra.
- **El guardado del juego.** La instantánea del §2 es de las sondas; la
  persistencia de verdad sigue siendo la FASE A3.
- **El tiempo de carga**: generar el terreno, las texturas, la descarga de
  teselas. El cepo mide fotogramas de partida, no el arranque.
- **El mapa regional.** La sonda corre sobre la capa local.
- **Sustituir el cepo por un profiler.** Desglosar tramos sí entra (§3);
  cambiar de instrumento, no.
- **Atar el azar de la fauna a la semilla de la partida.** Hoy usa una semilla
  fija propia: es repetible, sólo que no cambia de una partida a otra. Eso es
  diseño, no repetibilidad, y no se toca aquí.
- **Volver a medir las tablas de balanceo de otras specs** después del paso 0.
  Pueden moverse, y está declarado; rehacerlas es trabajo de cada spec.

## Riesgos conocidos

- **Que el año no llegue al final.** Las corridas largas de `AnoProbe` se
  cerraron solas, con código 1 y sin mensaje, hacia la jornada 136–150, y
  nadie lo diagnosticó (`QUE_SE_PUEDA_PERDER`, tarea 7). Si `TironAnualProbe`
  hace lo mismo, no hay línea base del año. En ese caso **se para y se decide
  aparte**: el arreglo podría no ser inocuo para la huella.
- **Que el paso 0 no baste.** Puede haber más dependencias del reloj o del
  fotograma de las encontradas leyendo. La prueba de las dos corridas iguales
  es la que lo dice; la lista de arriba no sustituye a esa prueba.
- **Que la banda de ruido sea ancha.** Si dos corridas iguales difieren mucho
  en tiempos, sólo se podrán dar por buenas las mejoras grandes. Es
  información, no un fallo: se apunta y se trabaja con ella.

## Criterios de aceptación

1. **La partida se repite.** Tras el paso 0, dos años completos con la misma
   semilla y el mismo código dan la huella idéntica las 180 jornadas. Antes del
   paso 0 se mide lo mismo en una ventana corta, para saber de dónde se parte y
   en qué jornada se separan hoy dos corridas iguales.
2. **El paso 0 no devuelve los tirones que sus presupuestos evitaban.** Con
   `TironAnualProbe` en la misma ventana antes y después del paso 0, el coste
   por llamada y el peor fotograma del horno de rejillas y del repaso de
   formas no suben por encima de la banda de ruido. Lo que cueste llevar la
   fauna al paso fijo se mide y se apunta aparte: ése no tenía presupuesto,
   tenía una avería.
3. **La instantánea es fiel.** Arrancar de la instantánea de la jornada N da
   la huella idéntica a la de la corrida continua desde N hasta N+30, en al
   menos dos puntos del año —uno de ellos pasado un cambio de estación—.
4. **Cada optimización pasa las tres pruebas** del §4 —coste por llamada del
   tramo a la baja y ningún otro por encima del ruido, suite tal cual, huella
   idéntica en la ventana—, y queda anotada con sus cifras de antes y después.
5. **Cada cambio de motor o de vista** trae además sus capturas de antes y
   después, y está aceptado expresamente.
6. **Cierre.** El segundo año con la semilla de la línea base da la huella
   idéntica las 180 jornadas, la suite sigue como en la línea base, y existe la
   tabla comparativa del §6.

## Plan técnico

### Aviso previo sobre `SPECS.md`

Lo mismo que ya anotó [QUE_SE_PUEDA_PERDER.md](QUE_SE_PUEDA_PERDER.md): el §3
describe el prototipo original y no menciona ninguno de los módulos que este
bloque toca —`SettlementSim`, `WildlifeHerds`, `HornoDeRejillas`, `Parajes`,
`Cronometro`, las sondas—. Los contratos de abajo salen de leer el código.

Sí aplican y se respetan: el tipado estático y los comentarios `##` de §4. La
regla de §4 de nombrar los sistemas en inglés **no** se sigue, y no por
descuido: el código de `scripts/sim`, `scripts/mundo` y `scripts/tools` ya la
abandonó (`Cronometro`, `HornoDeRejillas`, `Marcha`), y lo nuevo sigue a sus
vecinos.

Dos contratos de `SPECS.md` que este plan toca de refilón, dichos en voz alta:

- §5 y §6 dan la persistencia por no implementada y fuera de alcance. Sigue
  siéndolo. La instantánea vive en `scripts/tools/`, junto al cepo, no la
  llama nada del juego y no promete formato estable: es instrumental, como
  `Cronometro`.
- §5 dice que no hay medición automatizada. Ya la hay —el cepo, las sondas—
  y este plan la amplía, pero no reescribe ese párrafo: la deuda de
  `SPECS.md` se queda anotada, no arreglada aquí.

### Lo que ya existe y en lo que se apoya

- **El paso fijo** (`SettlementSim._process`: `PASO_FIJO`, `PASOS_POR_CUADRO`,
  `_pendiente`). La secuencia de pasos no depende de la máquina; lo que
  depende es cuántos caben en un fotograma.
- **`SEMILLA`**, leída en `SettlementSim.setup` y puesta en `_rng`. Y `setup`
  deja `time_scale = 0.0`: la partida arranca en pausa, que es lo que hace
  repetible el arranque de las sondas.
- **`day_passed`**, que se emite DENTRO de `_advance`, justo después de
  `_end_of_day`. Es el punto de captura que no depende del fotograma. Hoy
  `TironAnualProbe` no lo usa: detecta el cambio de día mirando `sim.day` una
  vez por fotograma, y ése es el error de medida que ya describe la memoria de
  «medir el paso, no la intención».
- **`RandomNumberGenerator.state`**, expuesto por el motor. Meterlo en la
  huella delata cualquier tirada de más o de menos aunque no haya cambiado
  nada visible todavía.
- **El presupuesto de caminos** (`_path_nodes_this_frame`, `NODES_PER_FRAME`).
  Pese al nombre, se pone a cero en cada paso (`_advance`), no en cada
  fotograma: se cuenta en nodos y es repetible.
- **La fauna ya distingue la escala de la partida**: `_process` multiplica el
  `delta` por `sim.time_scale`. Y tiene su propio `_rng` sembrado con una
  constante (20260903): repetible, sólo que fuera de la semilla de la partida.
- **`Navgrid.amasar(terrain, filas, hasta_ms)`** sabe amasar sin reloj si no
  se le pasa `hasta_ms`, o sea terminar una rejilla de una vez.
- **La tarjeta de momento** (`BarraSuperior._show_next_moment`) es el único
  sitio que devuelve la velocidad tras una decisión, y lo hace al pulsar un
  botón: `on_pick` y luego `_show_next_moment`.
- **Todos los módulos de `scripts/sim` y `scripts/banda` son `RefCounted`**
  colgados de un solo `Node3D` (`SettlementSim`), salvo la fauna, que es otro
  `Node3D`. Los que piden `settlement` al construirse (`Caceria`, `Marcha`,
  `Reparto`…) existen uno por partida; los que van y vienen (`Inhabitant`,
  `Paraje`, `Hunt`, `Tale`, `Moment`) se construyen sin argumentos. Eso es lo
  que hace posible una instantánea genérica en vez de una por módulo.
- **El estado estático que importa** está en `GameState.season` y
  `GameState.year`. El resto de `GameState` y `Expedition` lo fija la sonda al
  arrancar, igual en todas las corridas.

### Módulos afectados

**Paso 0 — el único cambio de comportamiento**

- **`scripts/sim/WildlifeHerds.gd`** (modificar).
  - `_process` se parte en dos. `avanzar(delta)` hace lo que cambia la
    partida —`_think` y `_move` de cada animal— y lo llama la simulación en
    cada paso. `_process` se queda con lo que sólo pinta: `_hop_phase`, que ya
    va a la escala de la partida, y `_draw`.
  - **Sin simulación que la lleve, la fauna sigue andando sola** en `_process`,
    como hoy. Lo usan las sondas de fauna suelta y las dos pruebas de
    `TestFauna`, que miran `_hop_phase` y siguen valiendo tal cual.
  - `_find_waterholes` baraja con un generador propio sembrado con una
    constante, no con el azar global. Tampoco con `_rng`: meterle tiradas
    delante desplazaría todas las de las manadas que vienen detrás en `setup`.
- **`scripts/sim/SettlementSim.gd`** (modificar).
  - `_advance`, después de las personas, avanza la fauna con el mismo `delta`
    escalado del paso, a través de `caceria.wildlife`: la misma referencia
    que ya usa la cacería, sin un campo nuevo. El orden, personas primero y
    fauna después, es el que ya había, porque `DemoMain` añade la simulación
    antes que la fauna y su `_process` corría antes en cada fotograma.
  - El bucle de `_process` deja de dar pasos en cuanto la velocidad se pone a
    cero a mitad de fotograma: nada de pasos de tiempo cero.
  - Señal nueva `hour_passed(day, hour)`, emitida dentro de `_advance` cada
    vez que cambia la hora entera. La necesita el cotejo de cuevas.
- **`scripts/mundo/HornoDeRejillas.gd`** (modificar). `de(season)` devuelve
  **siempre la rejilla de esa estación, entera**: si el horno aún no la ha
  terminado, la termina ahí mismo, sin reloj. Desaparece «la más parecida»
  (`_caudales` y su bucle). `amasar()` sigue por reloj y cada fotograma, aun
  en pausa, pero ya sólo decide cuánto se adelanta, nunca qué rejilla usa la
  banda. El cambio de rejilla en `Marcha._navgrid` pasa a ocurrir en la
  primera consulta tras el cambio de estación, que cae siempre en el mismo
  paso.
  - `test_mientras_se_hornea_una_se_anda_con_otra` pide la rejilla del
    invierno sin terminar y comprueba que sale horneada. Sigue pasando: sale
    horneada porque se termina, no porque se preste otra. No hace falta
    tocarla.
- **`scripts/sim/Parajes.gd`** (modificar). `retocar_huellas` cambia los dos
  milisegundos por una cuenta fija de formas por vuelta, `POR_REPASO`.
  - El valor se fija midiendo cuántas caben hoy en dos milisegundos en esta
    máquina con `HuellaProbe`. Por lo anotado en el propio archivo (siete
    parajes, 15,5 ms), será una o dos.
  - Sólo afecta al barrido por franjas, que es el único que pasa `retocar`
    (`radio <= 0.0`) y el que corre tras cada cambio de rejilla.
- **`scripts/DemoMain.gd`** (modificar). `_check_discoveries` sale del bloque
  de cada 90 fotogramas y se engancha a `sim.hour_passed`. La niebla del
  minimapa sigue por fotograma, porque sólo pinta.
- **`scripts/ui/BarraSuperior.gd`** (modificar). Una vía pública para resolver
  una decisión —`on_pick` y después la tarjeta siguiente, que es la que
  devuelve la velocidad—, la que ya usa el botón. Las sondas la llaman en vez
  de llamar a `on_pick` a pelo. Una regla en un sitio: si la sonda resuelve
  por un camino distinto del jugador, mide otra partida.

**Instrumentos — ninguno cambia la partida**

- **`scripts/tools/Instantanea.gd`** (nuevo, `RefCounted`, estático, al lado de
  `Cronometro`). Recorre el estado de la partida y lo pasa a bytes y de
  vuelta.
  - **Raíces:** las variables de guion de `SettlementSim` y de `WildlifeHerds`;
    `GameState.season` y `GameState.year`; y el `discovered` de cada
    `CaveMouth`. Las cuevas son vista, pero la crónica depende de ellas: sin
    guardarlas, al restaurar se volverían a «descubrir» y la crónica saldría
    con entradas de más.
  - **Qué se recorre:** sólo variables de guion
    (`PROPERTY_USAGE_SCRIPT_VARIABLE`). Los objetos, por identidad, con tabla
    de ids para que dos referencias al mismo objeto sigan siendo el mismo
    objeto y los ciclos no revienten.
  - **Los `Node`, nunca por dentro:** son referencias externas por papel (la
    simulación, el terreno, la multitud, la fauna) y al restaurar se enchufan
    las de la escena nueva.
  - **Casos aparte:** los `RandomNumberGenerator` van por `seed` y `state`.
    Un `Callable` encontrado en el estado es un error y para la instantánea:
    al cierre de jornada no debería haber ninguno.
  - **Todo lo alcanzable se guarda y nada se reconstruye**, rejillas y cachés
    incluidas. Reconstruir abre la puerta a que lo reconstruido no sea igual.
  - **Al restaurar:** los módulos que ya existen se rellenan en su sitio y los
    objetos que van y vienen se crean de nuevo. Se informa de lo que no
    cuadra en cualquiera de los dos sentidos. Un campo guardado que el código
    ya no tiene invalida la instantánea. Un campo que el código tiene y la
    instantánea no se queda con su valor inicial y se avisa: es lo que pasa
    cuando una optimización añade una caché.
- **`scripts/tools/FirmaDiaria.gd`** (nuevo). Es la «huella diaria» de la spec.
  No se llama `Huella` porque ese nombre ya lo tienen la forma de un paraje
  (`Huella.gd`, `Paraje.huella`) y su sonda (`HuellaProbe`).
  - **Firma exacta:** SHA-256 (`HashingContext`) de los bytes de `Instantanea`,
    menos una lista de campos que son sólo coste, `SOLO_COSTE`: contadores de
    presupuesto, `grid_build_ms`, `_pendiente`, `time_scale`.
  - **Resumen legible, para saber qué se separó cuando la firma no cuadra:**
    población e ids, raciones, leña, técnicas, heridos, parajes, cacerías,
    entradas de crónica, desenlace y `_rng.state`.
  - Meter un campo en `SOLO_COSTE` es una decisión que se revisa en cada
    optimización, no un cajón de sastre.
- **`scripts/tests/TironAnualProbe.gd`** (modificar). Todo por entorno, como lo
  que ya tiene:
  - `FIRMAS=<fichero>`: una línea por jornada, escrita desde `day_passed`.
  - `INSTANTANEAS=<carpeta>` y `CADA=<n>`: una instantánea cada n jornadas,
    también desde `day_passed`.
  - `DESDE=<instantánea>`: restaura con la partida aún en pausa y no reparte
    oficios, porque el reparto ya viene en la instantánea.
  - `RESUMEN=<fichero>`: el ranking en CSV, con el coste por llamada y los dos
    cuartos del año.
  - Las decisiones se resuelven por la vía pública de `BarraSuperior`.
- **`scripts/tests/Cotejo.gd`** (nuevo, `SceneTree`). Dos modos.
  - `firmas`: dos ficheros de firmas. Dice la primera jornada en que se
    separan y qué campos del resumen difieren.
  - `tramos`: dos resúmenes CSV, y opcionalmente las dos corridas de la línea
    base. Dice cuánto se mueve cada tramo en coste por llamada contra la banda
    de ruido y señala los que la pasan.
  - Así el «no empeora ningún otro» sale de un programa, no de mirar dos
    listas.
- **Desglose del paso de simulación** (modificar `SettlementSim.gd` y lo que
  cuelgue de `_advance`): más tramos de `Cronometro`.
  - **Regla de grano:** se marcan los subsistemas que se llaman una vez por
    paso. Lo que va por persona (15 personas × 20 trozos × 8 pasos = 2.400
    llamadas por fotograma) se mide como un solo tramo alrededor del bucle, y
    dentro sólo lo que se sepa gordo. Un tramo por persona costaría él mismo
    varios milisegundos por fotograma.
  - **La fauna estrena su tramo** dentro del paso.

**Lo que no se toca:** `AnoProbe`, porque `TironAnualProbe` es la sonda
equivalente que pide la spec. Tampoco `RunTests.gd` ni ninguna prueba.

### Decisiones de arquitectura

Sólo las que la spec obliga a tomar:

1. **La partida sólo avanza en el paso.** Lo que cambia el estado —fauna
   incluida— va dentro de `_advance`; lo que pinta va por fotograma. Es la
   frontera que el paso fijo ya declaraba y que la fauna saltaba.
2. **Un presupuesto de reloj sólo puede decidir cuánto trabajo se adelanta,
   nunca qué ve la partida.** De ahí que el horno termine la rejilla que se le
   pide y que el repaso de formas cuente formas.
3. **La huella se toma en `day_passed`**, dentro del paso, nunca mirando
   `sim.day` desde el bucle de la sonda.
4. **Un solo recorrido del estado** sirve a la instantánea y a la firma. Si
   fueran dos, lo que la firma no mira podría ser justo lo que la instantánea
   se deja.
5. **Todo lo alcanzable se guarda; nada se reconstruye.**
6. **Una sola vía para resolver una decisión**, la del jugador. La usan el
   botón y las sondas.
7. **La instantánea es instrumental** (`scripts/tools/`), no el guardado de la
   FASE A3. Si algún día se escribe A3, podrá o no reutilizar el recorrido;
   este plan no lo decide.

### Orden de dependencias

1. **Comprobar el camino de la decisión en la sonda.** Una corrida hasta la
   primera berrea o el primer percance con margen, para saber qué pasa de
   verdad: sobre el papel se cuelga, y no se colgó. Va primero porque, si hay
   algo más devolviendo la velocidad, es otra fuente de divergencia que el
   paso 0 tiene que cubrir.
2. **`Instantanea` (sólo tomar) y `FirmaDiaria`**, y la escritura de firmas en
   la sonda. Hacen falta ANTES del paso 0: el criterio 1 pide medir de dónde se
   parte.
3. **`Cotejo`, modo `firmas`.** Con él, dos corridas de 10–15 jornadas sin
   tocar nada dicen en qué jornada se separan hoy.
4. **El paso 0**, fuente a fuente, en este orden:
   1. la vía única de decisión;
   2. la fauna al paso y las charcas sembradas;
   3. el horno;
   4. el repaso de formas;
   5. las cuevas;
   6. el tope de pasos de tiempo cero.

   Tras cada una se repiten las dos corridas cortas, para ver si la jornada en
   que se separan se aleja. Al final tienen que coincidir enteras.
5. **`Instantanea` (restaurar)**, que sólo tiene sentido con el paso 0 hecho:
   restaurar una partida que no se repite no se puede comprobar. Se valida con
   el criterio 3.
6. **El desglose del paso de simulación**, comprobando además que la firma
   sale igual con el cepo encendido que apagado.
7. **La línea base:** dos años, el primero dejando instantáneas, y el modo
   `tramos` de `Cotejo` para la banda de ruido. Se apunta el estado de la
   suite.
8. **El bucle de optimizaciones**, una a una.
9. **El año de cierre.**

### Riesgos técnicos conocidos

- **La fauna en el paso cuesta más.** Hoy piensa una vez por fotograma; en el
  paso, hasta ocho, o sea treinta veces por segundo de reloj. Puede salir de
  golpe como el tramo más caro del ranking. Es el precio de que la caza sea
  repetible y se apunta (criterio 2). Si resultara insoportable, la salida sin
  perder la repetibilidad es que la fauna avance cada k pasos con k veces el
  `delta`, con k fijo. Eso es una cifra que mueve el comportamiento, así que
  se decide dentro del paso 0, antes de la línea base, o no se decide.
- **Terminar una rejilla de golpe es un tirón de unos 900 ms**, y ahora puede
  darse: si la banda aprende barca o puente y la estación cambia antes de que
  el horno termine las otras tres, el cambio de estación la termina en el
  momento. En la práctica el horno necesita segundos de reloj y la estación
  dura cuarenta y cinco jornadas, así que debería ser raro; se vigila en el
  volcado de graves.
- **La instantánea genérica va a encontrar estado escondido.** Un `Callable`
  guardado, un nodo de vista con estado de partida (las cuevas son el que ya
  se sabe), una estática que no está en la lista. Leyendo no se ven todos: los
  caza el criterio 3, y por eso va antes de la línea base.
- **Una instantánea está atada al código que la hizo.** Si una optimización
  renombra o quita un campo, las instantáneas de la línea base dejan de
  servir. Hay que rehacerlas corriendo desde la jornada uno, que es justo el
  coste que se quería evitar. Que el código tenga un campo que la instantánea
  no trae se tolera, y es además una prueba: una caché que empieza vacía tiene
  que dar la misma huella que una llena.
- **La vista, al restaurar, no trae lo que lleva acumulado.** Los rastros y
  los montones de la vista se rehacen de la partida, pero lo que la vista
  guarde por su cuenta empieza de cero. En una ventana restaurada, los tramos
  de motor y vista pueden costar menos que en la corrida continua el mismo
  día. La prueba de fidelidad compara también nodos y llamadas de dibujo, no
  sólo la firma. Si no cuadran, los cambios de motor y vista se validan desde
  la jornada uno.
- **El cepo pesa.** Cada tramo son dos lecturas de reloj y dos accesos a
  diccionario. Con el grano del desglose acotado debería perderse en el ruido,
  y se comprueba igual que la firma: con el cepo encendido y apagado.
- **Queda sin explicar por qué la sonda no se colgaba** con la interfaz
  parando el reloj en cada decisión. Es el paso 1 del orden, y hasta que se
  sepa, la lista de fuentes de divergencia no está cerrada.
- **La salida con código 1 hacia la jornada 136–150** de las corridas largas
  sigue sin diagnosticar. Si alcanza a `TironAnualProbe`, para la línea base.

## Tareas

En el orden de dependencias del plan:

1. Averiguar qué pasa hoy con las decisiones en la sonda.
2. Los instrumentos para ver si dos corridas se separan, y en qué jornada lo
   hacen hoy.
3. El paso 0, fuente a fuente, midiendo tras cada una.
4. La restauración de la instantánea.
5. El desglose y la línea base.
6. El bucle de optimizaciones.
7. El año de cierre.

Todas las corridas de sonda van con ventana, de una en una, en el sitio 56,
con `SEMILLA` y `VEL` fijas y las mismas en cada pareja que se compara.

- [ ] **1. El camino de una decisión en la sonda, medido.**
      Sin cambiar nada del juego, correr `TironAnualProbe` hasta la primera
      decisión (la berrea al entrar el otoño, o antes un percance con
      margen). Instrumentar sólo la sonda para apuntar cuatro cosas:
      - `sim.time_scale` antes y después de su manejador;
      - si la tarjeta de la barra sigue abierta después;
      - cuántos pasos de simulación se dan con la velocidad a cero;
      - cuándo, y quién, devuelve la velocidad.

      **Verificable:** la salida de la sonda responde a la pregunta que el
      plan deja abierta —por qué no se colgaba—, y la respuesta queda
      anotada aquí. Si aparece otra fuente de divergencia, se añade a la
      lista de «Lo que hoy impide comprobarlo» antes de seguir.

      > **HECHO (2026-09-11).** Sonda nueva en vez de ensuciar
      > `TironAnualProbe`: `scripts/tests/DecisionProbe.gd`, sitio 56,
      > `SEMILLA=123`, `VEL=20`. Mide tres tiempos: las decisiones reales de la
      > primera jornada, contestadas como las contestan las sondas; una
      > decisión de prueba lanzada DENTRO de un paso (en `day_passed`) con la
      > tarjeta del arranque abierta; y la misma con las tarjetas cerradas.
      >
      > **Por qué no se colgaba.** El momento de arranque («Un abrigo, una
      > banda», `Partida.momento_inicial`) NO es una decisión: la barra lo
      > enseña sin parar el reloj, y en una sonda nadie pulsa su «Seguir».
      > Esa tarjeta se queda abierta la corrida entera, y
      > `BarraSuperior._on_moment` sólo enseña —y sólo para el reloj— cuando no
      > hay otra tarjeta abierta: todo lo que llega después se APILA en
      > `ui._moments` y no para nada. La sonda contesta llamando a `on_pick`
      > directamente. Medido:
      >
      > | | velocidad al llegar a la sonda | tras `on_pick` | tarjeta | en cola |
      > |---|---|---|---|---|
      > | al arrancar | 0 (pausa de `setup`) | — | abierta, «UN ABRIGO, UNA BANDA» | 0 |
      > | decisión con la del arranque abierta | 20 | 20 | abierta | 2 |
      > | decisión con las tarjetas cerradas | **0** | **0** | abierta, «PRUEBA» | 0 |
      >
      > En el tercer caso, 60 fotogramas después la velocidad seguía en 0:
      > **nadie la devuelve**, y una sonda que contestara así se quedaría
      > colgada. Es exactamente lo que pasó en la primera corrida larga de
      > `AnoProbe` (`QUE_SE_PUEDA_PERDER`, tarea 7), antes de que alguien
      > dejara la tarjeta del arranque abierta sin saberlo.
      >
      > **Pasos de tiempo cero:** en esta corrida la decisión cayó en el único
      > paso de su fotograma (sin ventana va a un paso por fotograma), así que
      > después no se dio ninguno. Que puedan darse sigue siendo cierto
      > leyendo el bucle de `_process`; cuántos, depende de cuántos pasos le
      > quedaran al fotograma. No es una fuente de divergencia EN LAS SONDAS
      > —ahí la barra no para el reloj nunca—, pero sí en una partida jugada.
      >
      > **Lo que cambia para la tarea 7**, que no estaba previsto: las sondas
      > no juegan como el jugador en DOS cosas, no en una. Contestan a pelo, y
      > además nunca cierran una tarjeta, así que `ui._moments` crece sin
      > parar durante toda la corrida (hallazgos, relatos, cumbres). La vía
      > única tiene que cubrir también los hallazgos: la sonda cierra cada
      > tarjeta como lo haría el jugador, y la del arranque la primera.

- [ ] **2. `Instantanea.tomar`: el estado de la partida a bytes.**
      Crear `scripts/tools/Instantanea.gd` sólo con el sentido de ida:
      - raíces: `SettlementSim`, `WildlifeHerds`, `GameState.season`/`year` y
        el `discovered` de las cuevas;
      - variables de guion, objetos por identidad con tabla de ids, los `Node`
        como referencia externa por papel, los `RandomNumberGenerator` por
        `seed` y `state`;
      - error si aparece un `Callable`.

      **Verificable:** suite nueva `TestInstantanea.gd`, registrada en
      `RunTests.gd`, sobre una simulación montada a mano como en
      `TestRelevo.gd`. Comprueba:
      - tomar dos veces el mismo estado da los mismos bytes;
      - cambiar un campo de una persona los cambia;
      - una tirada de `_rng` los cambia;
      - dos referencias al mismo objeto se guardan una vez;
      - un ciclo no revienta;
      - un `Callable` metido a propósito en el estado da error;
      - ningún `Node` se recorre por dentro.

      Y la suite entera sigue en verde.

      > **HECHO (2026-09-11).** `scripts/tools/Instantanea.gd`,
      > `Instantanea.tomar(sim, fauna, cuevas)`. Por reflexión, sólo variables
      > de guion (`PROPERTY_USAGE_SCRIPT_VARIABLE`). Un contenedor o una
      > referencia se codifica como un Array etiquetado. Como TODO Array de la
      > partida sale etiquetado, un Array en lo codificado nunca es un valor
      > suelto. Cada objeto se registra en la tabla ANTES de recorrerlo, que
      > es lo que corta los ciclos.
      >
      > Dos decisiones que no estaban en el plan:
      > - **Los campos de `FUERA` tampoco se guardan**, no sólo se quedan
      >   fuera de la firma (`_pendiente`, `time_scale`, los contadores de
      >   presupuesto del paso, `grid_build_ms`). Restaurar `_pendiente`
      >   metería en la partida restaurada un trozo de reloj real de otra
      >   máquina, y `time_scale` lo pone la sonda. Una sola lista para las
      >   dos cosas.
      > - **Un nodo sin papel o un objeto del motor no es un error, es un
      >   «ajeno»**: se guarda su clase, se cuenta en `ajenos` y al restaurar
      >   se dejará lo que haya. La fauna, por ejemplo, apunta a sus mallas.
      >   Tratarlos como error habría hecho imposible tomar la partida real.
      >   Sólo un `Callable`, `Signal` o `RID` es un error.
      >
      > `TestInstantanea.gd`, suite nueva registrada en `RunTests.gd`: 8
      > pruebas, 13 comprobaciones. Una simulación montada a mano se deja
      > tomar sin errores. Tomar dos veces da los mismos bytes. Una
      > millonésima de hambre en una persona los cambia, y una tirada de
      > `_rng` también. Una persona apuntada dos veces se guarda una. Un ciclo
      > de dos objetos (guion creado en la prueba) no revienta. Un `Callable`
      > metido en `limits` da un error que dice qué es y dónde está. Mover un
      > `Node3D` apuntado desde el estado no cambia los bytes y cuenta como
      > ajeno. Y los módulos apuntan a la simulación por su papel, no a una
      > copia.
      >
      > `RunTests.gd` entero: **864 pruebas, 6.089 comprobaciones, todo en
      > verde**. Los tres `SCRIPT ERROR` de la tanda son los preexistentes
      > —`Marcha._tick_step` desde Exploración, `TestParajes.gd:300` y
      > `TestHunting.gd:228`—, ninguno de esta suite.

- [ ] **3. `FirmaDiaria`: la huella de la spec.**
      Crear `scripts/tools/FirmaDiaria.gd`:
      - firma exacta: SHA-256 de los bytes de `Instantanea`, menos
        `SOLO_COSTE` (contadores de presupuesto, `grid_build_ms`,
        `_pendiente`, `time_scale`);
      - resumen legible: población e ids, raciones, leña, técnicas, heridos,
        parajes, cacerías, entradas de crónica, desenlace y `_rng.state`.

      **Verificable:** en `TestInstantanea.gd`:
      - la misma partida da la misma firma;
      - una tirada de más en `_rng` la cambia aunque el resumen, sin
        `_rng.state`, no haya cambiado;
      - tocar un campo de `SOLO_COSTE` no la cambia;
      - el resumen trae todos los campos pedidos.

      > **HECHO (2026-09-11).** `scripts/tools/FirmaDiaria.gd`,
      > `FirmaDiaria.de(sim, fauna, cuevas)`, con tres piezas:
      > - **firma:** el SHA-256 de `Instantanea.bytes()`;
      > - **resumen:** los once campos pedidos, con los números grandes y los
      >   decimales como texto para que JSON no les recorte cifras. El azar
      >   va como `_rng.state`;
      > - **detalle:** un hash corto por «Clase.campo», que es la pieza que no
      >   pedía la tarea. Sin él, dos firmas distintas sólo dicen «distintas»,
      >   y el resumen puede no enterarse todavía. Con él, `Cotejo` dice
      >   `Inhabitant.hunger` y se va derecho al código.
      >
      > `SOLO_COSTE` no existe con ese nombre: es `Instantanea.FUERA`, la misma
      > lista para no guardar y para no firmar (ver la nota de la tarea 2).
      > Se escribe como una línea de texto (`linea()` / `desde_linea()`).
      >
      > **Sorpresa:** la prueba de ida y vuelta falló a la primera.
      > `JSON.parse_string` devuelve los enteros como decimales, así que el
      > resumen leído de un fichero no era igual al tomado en memoria, y
      > `Cotejo` habría visto diferencias que no existen. Ahora `resumen_de`
      > devuelve el resumen ya pasado por JSON.
      >
      > Y otra que costó una tanda entera. Al arreglarlo se quedó sin cerrar
      > un paréntesis, `RunTests.gd` no llegó a compilar, y un guion de
      > `SceneTree` que no compila no llama nunca a `quit()`: Godot se quedó
      > esperando para siempre con un núcleo entero. Se vio porque la tanda
      > pasó de menos de diez minutos a no terminar.
      >
      > Seis pruebas nuevas en `TestInstantanea.gd`, que ahora además libera
      > sus simulaciones en `before_each`:
      > - la misma partida da la misma firma, de 64 cifras hexadecimales;
      > - una tirada de más cambia la firma aunque el resumen, quitando el
      >   azar, siga igual;
      > - tocar `grid_build_ms`, `_pendiente`, `_path_nodes_this_frame` o
      >   `time_scale` no la cambia;
      > - el resumen trae los once campos;
      > - una millonésima de hambre cambia `Inhabitant.hunger` en el detalle,
      >   y no `Inhabitant.fatigue` ni `sim.day`;
      > - la línea se lee de vuelta idéntica.
      >
      > `RunTests.gd` entero: **870 pruebas, 6.114 comprobaciones, todo en
      > verde**. El aviso de recursos vivos al salir, que ya estaba, baja de
      > 52 a 51.

- [ ] **4. `TironAnualProbe` escribe firmas desde `day_passed`.**
      Variable de entorno `FIRMAS=<fichero>`: una línea por jornada (jornada,
      firma, resumen), escrita en el manejador de `sim.day_passed` y no desde
      el bucle que mira `sim.day` una vez por fotograma.

      **Verificable:** una corrida de `DIAS=3` deja tres líneas, jornadas 2, 3
      y 4. Una segunda corrida con el cepo apagado (sin `LIMITE`) da las
      mismas firmas que con el cepo encendido, cotejado con la tarea 5. Si no
      las da, eso ya es un hallazgo.

      > **HECHO (2026-09-11).** `FIRMAS=<fichero>` en `TironAnualProbe`,
      > escrita desde `sim.day_passed` con la firma de `FirmaDiaria.de(sim,
      > herds, _caves)`. Y `CEPO=0`, que apaga el cepo.
      >
      > **Lo que no estaba en la tarea:** tomar la firma cuesta, unos 140 ms
      > por jornada (426 ms en tres), y se toma DENTRO del paso de
      > simulación. Sin más, esos 140 ms saldrían en el ranking como coste
      > del «paso de simulación». De ahí `Cronometro.aparta()`/`vuelve()`: lo
      > que tarda la sonda corre hacia delante el reloj de cada tramo abierto
      > y el del fotograma, y se suma aparte en `Cronometro.apartado_us`, que
      > la sonda descuenta también de sus propias cuentas de fotograma. Al
      > final lo dice: «lo que tardó la sonda en tomarlas, fuera de la cuenta:
      > 426 ms».
      >
      > Medido en el sitio 56, `SEMILLA=123`, `VEL=20`, `DIAS=3`, con
      > ventana. Las dos corridas dejan tres líneas, jornadas 2, 3 y 4. Y **con
      > el cepo y sin él NO dan la misma firma**: `Cotejo` las ve separadas
      > desde la primera, la jornada 2, con 168 raciones contra 84, 8
      > entradas de crónica contra 5, una cacería contra ninguna y 95 campos
      > del detalle distintos. No es el cepo: con el paso 0 sin hacer, dos
      > corridas cualesquiera se separan (tarea 6). Pero ya dice algo que la
      > spec daba por supuesto sin medirlo: hoy la misma semilla no da la
      > misma partida **ni durante un día**.
      >
      > Y una cosa que salió al leer el detalle: la fauna guardaba
      > `_hop_phase`, la fase del salto que se DIBUJA, que avanza por
      > fotograma y sólo mueve la malla. Habría hecho distintas dos partidas
      > iguales. Va a `Instantanea.FUERA`, que es para esto.

- [ ] **5. `Cotejo.gd`, modo `firmas`.**
      Crear `scripts/tests/Cotejo.gd` (`SceneTree`). Con dos ficheros de
      firmas dice cuántas jornadas coinciden, la primera en que se separan y
      qué campos del resumen difieren en ella.

      **Verificable:** con dos ficheros hechos a mano —idénticos, y uno con
      una línea alterada— dice «iguales» en el primer caso, y en el segundo
      la jornada y el campo exactos.

      > **HECHO (2026-09-11).** `scripts/tests/Cotejo.gd -- firmas A B`. Sale
      > con 0 si las jornadas en común son iguales, con 1 si no y con 2 si no
      > puede leer. Las jornadas que sólo tiene uno de los dos se cuentan
      > pero no hacen fallar, porque la prueba de fidelidad de la tarea 17
      > compara precisamente corridas de distinta longitud en lo que se
      > solapan.
      >
      > Medido con dos ficheros de tres jornadas hechos a mano:
      > - **idénticos:** «IGUALES: las 3 jornadas en común, de la 2 a la 4»,
      >   salida 0;
      > - **con la jornada 3 alterada** en firma, raciones, azar y un campo
      >   del detalle: «SE SEPARAN en la jornada 3: 1 iguales antes, 2
      >   distintas de 3», con `raciones` 100.5 → 99.25 y `azar` 77 → 78 en
      >   el resumen, y un solo campo del detalle, `Inhabitant.hunger`;
      >   salida 1.

- [ ] **6. De dónde se parte: dos corridas iguales, antes del paso 0.**
      Dos corridas de `TironAnualProbe` de 15 jornadas con la misma semilla y
      sin tocar código, cada una con su fichero de firmas.

      **Verificable:** la salida de `Cotejo` anotada aquí: en qué jornada se
      separan hoy y qué campo se separa primero. Es la primera mitad del
      criterio 1: el número contra el que se mide cada paso del 0.

      > **HECHO (2026-09-11).** Sitio 56, `SEMILLA=123`, `VEL=20`, 15
      > jornadas, con ventana, dos veces seguidas y sin tocar una línea entre
      > medias. Cada corrida tarda unos cuatro minutos, mucho menos de lo que
      > se temía, así que las parejas de 15 jornadas de las tareas 7 a 14 se
      > pueden hacer tal cual.
      >
      > **Se separan en la jornada 2, la primera que se firma: 0 iguales, 15
      > distintas de 15.** El primer día ya da 98,5 raciones contra 82,1, y
      > leña y azar distintos. 55 campos del detalle: la fauna entera
      > (`_animals`, `_prey`, `_predators`), las rutas y la caché de rutas,
      > el conocimiento del mapa, la despensa, las cacerías, el oficio
      > aprendido…
      >
      > Lo que no se esperaba, y cambia la tarea 10: entre los campos
      > distintos están **`Navgrid._fila`, `_columna`, `cost` y `vado`**. Es
      > el horno a medias: cuánto lleva amasado de las rejillas de las
      > estaciones que vienen, que va por reloj. Aunque la tarea 10 haga que
      > la banda sólo use rejillas ENTERAS, ese avance seguiría firmando
      > distinto en dos corridas iguales. Es coste, no partida, pero sólo
      > DESPUÉS de la tarea 10: antes, «la más parecida» dependía de él. Así
      > que la tarea 10 incluye sacar de la instantánea la cola del horno.

- [ ] **7. Paso 0.1 — una sola vía para resolver una decisión.**
      En `scripts/ui/BarraSuperior.gd`, un método público que haga lo que ya
      hace el botón: `on_pick` y luego `_show_next_moment`. El botón pasa a
      usarlo, y `TironAnualProbe` resuelve por ahí en vez de llamar a
      `on_pick` a pelo.

      **Verificable:**
      - la instrumentación de la tarea 1 muestra la velocidad devuelta dentro
        de la misma emisión y ningún paso con la velocidad a cero;
      - la suite entera en verde;
      - las dos corridas de 15 jornadas de la tarea 6, repetidas: la jornada
        en que se separan se anota, y no puede ser anterior a la de la tarea 6.

      > **HECHO (2026-09-11).** `BarraSuperior` gana `elegir(indice)`,
      > `seguir()` y `momento_en_pantalla()`: la tarjeta sabe qué momento
      > enseña (`_en_pantalla`) y los dos botones —elegir y «Seguir»— pasan
      > por ahí. `TironAnualProbe` ya no llama a `on_pick`: cierra la tarjeta
      > del arranque al empezar y contesta o cierra cada momento en cuanto
      > sale.
      >
      > Lleva una guarda que no pedía la tarea: si un `on_pick` levanta otro
      > momento, la señal vuelve a entrar con la tarjeta de fuera todavía
      > abierta, y sin guarda la sonda la contestaría dos veces. Se deja pasar
      > y el bucle de fuera la coge en la vuelta siguiente.
      >
      > Medido:
      > - **`DecisionProbe`, tercer tiempo, con las tarjetas cerradas:** la
      >   decisión llega con la velocidad a 0 (la barra para el reloj). Tras
      >   `barra.elegir(0)` la velocidad vuelve a 20 **en la misma emisión**, 0
      >   fotogramas parada, y al final queda la tarjeta cerrada y la cola
      >   vacía. Contestada a pelo, la misma decisión dejaba la velocidad en 0
      >   sesenta fotogramas después (tarea 1).
      > - **Dos corridas de 15 jornadas:** limpias, sin `SCRIPT ERROR`, con 15
      >   firmas cada una. **Se siguen separando en la jornada 2**, con 51 campos
      >   distintos del detalle contra los 55 de la tarea 6. No es anterior a la
      >   tarea 6, que es lo que se pedía. Tampoco podía ser posterior, porque
      >   la fauna, el horno y las charcas siguen yendo por el fotograma.
      >
      > La suite entera no se puede correr en este punto, y no por esta tarea:
      > las pruebas del paso 0 se escribieron por adelantado y llaman a
      > `avanzar`, `POR_REPASO` y `hour_passed`, que todavía no existen.
      > `RunTests.gd` no compilaría y se quedaría esperando para siempre (ya
      > pasó en la tarea 3). Se corre entera al terminar la tarea 13 y el
      > resultado vale para todas las del paso 0.

- [ ] **8. Paso 0.2 — la fauna al paso fijo.**
      En `scripts/sim/WildlifeHerds.gd`:
      - `avanzar(delta)` hace `_think` y `_move` de cada animal;
      - `_process` se queda con `_hop_phase` y `_draw`;
      - sin `sim`, `_process` sigue moviendo a los animales como hoy.

      En `SettlementSim._advance`, después del bucle de personas, se llama a
      `caceria.wildlife.avanzar(scaled)` si hay fauna. Nueva marca de
      `Cronometro`, «fauna (en el paso)».

      **Verificable:**
      - `TestFauna.gd` tal cual;
      - dos pruebas nuevas en `TestFauna.gd`: con `sim`, `_process` no mueve a
        ningún animal; `avanzar` sí, y lo mismo con el mismo `delta`
        partiendo del mismo estado;
      - la suite entera en verde;
      - las dos corridas de 15 jornadas: la jornada en que se separan se
        anota;
      - el coste de «fauna (en el paso)» se apunta con `TironAnualProbe` en
        esas mismas corridas: es la cifra aparte del criterio 2.

      > **HECHO (2026-09-11).** `WildlifeHerds.avanzar(delta)` hace `_think` y
      > `_move` de cada animal, y lo llama `SettlementSim._advance` después de
      > la gente, con el `delta` del paso, dentro del tramo nuevo «fauna (en
      > el paso)». `_process` se queda con `_hop_phase` y `_draw`. Sin partida
      > que la lleve, `_process` sigue moviéndola: las sondas de fauna suelta
      > y las dos pruebas de `TestFauna` valen tal cual.
      >
      > **Y con esto la partida ya casi se repite.** Dos corridas de 15
      > jornadas, misma semilla, ya no se diferencian en NADA de lo que se ve:
      > el resumen de la jornada 2 dice «nada: la diferencia todavía no ha
      > llegado a nada de lo que se ve» —mismas raciones, misma leña, mismo
      > azar, misma crónica— contra los 51 campos de la tarea 7. Quedan cuatro
      > campos del detalle, y ninguno es partida:
      > - `Navgrid._fila`, `Navgrid.cost` y `Navgrid.vado`: el horno a medias,
      >   que es la tarea 10;
      > - `sim._bodies`: los huecos de los cuerpos dibujados.
      >
      > **Lo que cuesta, que es la cifra aparte del criterio 2:** «fauna (en
      > el paso)» se lleva **21.304 ms, el 22 %** del tiempo de los tirones,
      > en 1.820 llamadas —11,7 ms por paso—, y los fotogramas por segundo de
      > la primera jornada bajan de 8,0 a **6,4**. Es el precio de que la caza
      > sea repetible: la fauna pensaba una vez por fotograma y ahora piensa
      > en cada paso, hasta ocho veces más. No se toca: si molesta, sale en el
      > ranking de la línea base y se optimiza como cualquier otro tramo, que
      > es justo para lo que está este bloque.

- [ ] **9. Paso 0.3 — las charcas, barajadas con semilla.**
      `WildlifeHerds._find_waterholes` baraja con un `RandomNumberGenerator`
      local sembrado con una constante, no con `shuffle()` global ni con
      `_rng`.

      **Verificable:**
      - si `TestFauna` tiene terreno falso que sirva, una prueba nueva: dos
        `setup` sobre el mismo terreno dan las mismas charcas en el mismo
        orden, y las tiradas de `_rng` después de `setup` son las mismas que
        si no hubiera charcas que barajar;
      - si no lo tiene, una sonda de dos corridas en el sitio 56 que imprime
        las charcas y salen iguales;
      - las dos corridas de 15 jornadas, repetidas y anotadas.

      > **HECHO (2026-09-11), con la premisa corregida.** `_find_waterholes`
      > baraja con un `RandomNumberGenerator` propio sembrado con
      > `CHARCAS_SEED`, en vez de `shuffle()`. No se usa `_rng` porque las
      > manadas se siembran con él justo después: meterle tiradas por delante
      > las habría movido a todas de sitio.
      >
      > **Pero las charcas NO salían distintas, y eso lo dice la medida de la
      > tarea 8**: entre los campos que separaban dos corridas no estaba
      > `fauna._waterholes`. El motivo: `shuffle()` usa el azar GLOBAL de
      > Godot, que arranca sembrado igual en cada ejecución mientras nadie
      > llame a `randomize()`. El único `randomize()` del proyecto está en
      > `BandaCrowd`, y es sobre su propio generador. O sea que salían iguales
      > **por casualidad**. El cambio se hace igual, porque esa casualidad se
      > rompe con una sola tirada global de más en cualquier rincón, y
      > entonces se movería la fauna entera sin que nadie relacionara una cosa
      > con la otra.
      >
      > **Y de camino, `sim._bodies` fuera de la firma.** Era el otro campo
      > que separaba las corridas de la tarea 8: el hueco de la malla que le
      > toca a cada persona, que reparte `BandaCrowd` con su `randomize()`.
      > Es variedad de cuerpos dibujados, no partida —sólo se usa para
      > colocar la malla—, así que va a `Instantanea.FUERA`.
      >
      > Medido con dos corridas de 15 jornadas: **5 de las 15 jornadas ya
      > coinciden enteras** (antes, ninguna), el resumen sigue sin ver
      > diferencia ninguna, y en el detalle quedan **cinco campos**: los
      > cuatro del horno a medias (`Navgrid._fila`, `_columna`, `cost`,
      > `vado`), que son la tarea 10, y `Parajes._por_retocar`, que es
      > exactamente el cursor del repaso de formas de la tarea 11.

- [ ] **10. Paso 0.4 — el horno termina la rejilla que se le pide.**
      En `scripts/mundo/HornoDeRejillas.gd`:
      - `de(season)`, si la rejilla de esa estación no está horneada, la
        termina ahí mismo con `Navgrid.amasar` sin `hasta_ms`, la saca de la
        cola y la devuelve;
      - se quitan «la más parecida» y `_caudales`;
      - `amasar()` no cambia.

      **Verificable:**
      - `TestWayfinder.gd` tal cual, incluida
        `test_mientras_se_hornea_una_se_anda_con_otra`;
      - una prueba nueva: tras `encargar` en verano, `de(INVIERNO)` devuelve
        la rejilla medida con el caudal del invierno —no otra— y
        `pendientes()` baja en uno;
      - con `TironAnualProbe`, en la misma ventana antes y después del
        cambio, el coste por llamada y el peor fotograma de «horno de
        rejillas» no suben (criterio 2);
      - las dos corridas de 15 jornadas, repetidas y anotadas.

      > **HECHO (2026-09-11).** `de(season)` devuelve siempre la rejilla de esa
      > estación: si está a medias, la termina ahí mismo con
      > `amasar(_terrain, tall)` —sin reloj— y la saca de la cola. Fuera «la
      > más parecida» y fuera `_caudales`, que sólo servía para elegirla.
      >
      > Y la otra mitad, que salió de la medida de la tarea 6: **la cola del
      > horno no se firma**. `Instantanea.FUERA` acepta ahora nombres con
      > clase —para no esconder de paso el campo de otra que se llame igual— y
      > lleva `HornoDeRejillas._rejillas` y `HornoDeRejillas._cola`. Cuánto
      > lleva amasado de las rejillas que aún no hacen falta va por reloj y,
      > desde este cambio, no decide nada: la que se usa está en `sim._grid`,
      > y ésa sí se firma.
      >
      > Medido con dos corridas de 15 jornadas: **queda UN campo distinto**,
      > `Parajes._por_retocar` —la tarea 11—, y la separación se va de la
      > jornada 2 a la 3. El resumen sigue sin ver ninguna diferencia.
      >
      > El criterio 2 para este tramo se comprueba con la línea base: «horno
      > de rejillas» no aparece en el ranking de los tirones de estas
      > corridas, ni antes ni después, porque amasar cuatro milisegundos por
      > fotograma no llega a fabricar un tirón de cien.

- [ ] **11. Paso 0.5 — el repaso de formas cuenta formas, no milisegundos.**
      Primero se mide con `HuellaProbe` cuántas formas caben hoy en
      `MS_POR_REPASO` (2 ms) en esta máquina. Con ese número,
      `Parajes.retocar_huellas` pasa a hacer exactamente `POR_REPASO` formas
      por llamada, además de las de los parajes recién nacidos, y
      `MS_POR_REPASO` desaparece.

      **Verificable:**
      - el número medido, anotado aquí;
      - `TestParajes.gd` tal cual;
      - una prueba nueva: con N parajes ya formados, una llamada retoca
        exactamente `POR_REPASO` y va dando la vuelta a la lista sin dejarse
        ninguno, sea cual sea lo que tarde cada uno;
      - con `TironAnualProbe` en una ventana que pase por un cambio de
        estación —que es cuando corre el barrido por franjas—, el tramo que lo
        contiene no sube en coste por llamada ni en peor fotograma
        (criterio 2);
      - las dos corridas, repetidas y anotadas.

      > **HECHO (2026-09-11).** Medido primero con `HuellaProbe` en el sitio
      > 56: seis repasos seguidos rehacen **1, 2, 1, 2, 2 y 2** formas en los
      > dos milisegundos de presupuesto —cada forma cuesta entre 1,5 y 1,9
      > ms—. De ahí `Parajes.POR_REPASO := 2`, que es lo que esta máquina
      > venía haciendo. `MS_POR_REPASO` desaparece y el bucle hace
      > `mini(POR_REPASO, list.size())` formas, tarde lo que tarde cada una.
      >
      > **Y con esto la partida se repite.** Dos corridas de 15 jornadas con
      > la misma semilla: **IGUALES, las 15 jornadas, de la 2 a la 16**. Era
      > el último campo que separaba dos corridas.
      >
      > El criterio 2 de este tramo se comprueba en la línea base: el repaso
      > de formas no aparece por su cuenta en el ranking de los tirones —va
      > dentro del «paso de simulación»—, y lo que se hacía por vuelta no ha
      > cambiado: dos formas entonces y dos ahora.

- [ ] **12. Paso 0.6 — `hour_passed`, y las cuevas colgadas de ella.**
      En `SettlementSim`, señal nueva `hour_passed(day, hour)`, emitida dentro
      de `_advance` cada vez que cambia la hora entera. En `DemoMain`,
      `_check_discoveries` sale del bloque de cada 90 fotogramas y se engancha
      a esa señal. La niebla del minimapa se queda donde está.

      **Verificable:**
      - una prueba nueva, en el estilo de las de `TestExploration.gd` que
        llaman a `sim._process` con `delta` pequeños: una jornada entera emite
        24 veces `hour_passed`, en orden, con el mismo resultado lo parta en
        muchos fotogramas o en pocos;
      - las dos corridas de 15 jornadas: las entradas de crónica de cuevas
        salen en la misma jornada y hora en las dos.

      > **HECHO (2026-09-11), medida junto con la tarea 13.** Señal
      > `hour_passed(day, hour)` en `SettlementSim`, emitida dentro de
      > `_advance` cuando cambia la hora entera —también en el cambio de día,
      > donde pasa de 23 a 0—. `DemoMain._check_discoveries` se cuelga de ella
      > y sale del bloque de cada 90 fotogramas, que se queda con la niebla
      > del minimapa y cambia de nombre de tramo.
      >
      > Probado con dos pruebas nuevas en `TestExploration.gd`: cuatro
      > segundos de reloj a x20 dan **16 horas**, de las 6:30 a las 22:30, y
      > salen **las mismas y en el mismo orden** partiendo el trabajo en
      > fotogramas de un paso o de ocho. Antes, el cotejo de cuevas caía donde
      > cayera el fotograma noventa.
      >
      > **Las dos corridas no podían demostrar esto y no lo demuestran:** en
      > estas 15 jornadas la banda no da con ninguna cueva, así que no hay
      > entrada de crónica que comparar. Se dice en vez de esconderlo: lo que
      > prueba la tarea son sus pruebas unitarias, y la pareja sólo confirma
      > que no rompe nada. Por eso las tareas 12 y 13 comparten una sola
      > pareja de corridas.

- [ ] **13. Paso 0.7 — ningún paso con el reloj parado.**
      En `SettlementSim._process`, el bucle de pasos comprueba la velocidad en
      cada vuelta y deja de dar pasos si se ha puesto a cero a mitad de
      fotograma.

      **Verificable:**
      - una prueba nueva: un manejador de `hour_passed` que pone la velocidad
        a cero hace que el fotograma no dé ni un paso más —se cuentan con la
        hora de juego, que no avanza—;
      - la suite entera en verde.

      > **HECHO (2026-09-11).** `while` de `_process` con `if time_scale <=
      > 0.0: break` al final de cada vuelta. Lo pendiente no se pierde: sigue
      > en `_pendiente` y se hace al reanudar.
      >
      > **La prueba no cuenta las horas, cuenta los pasos**, que es lo que
      > cambia: con el reloj a cero los pasos siguen dándose pero no mueven la
      > hora, así que mirar la hora no habría distinguido el antes del
      > después. Se cuentan con el propio cepo (`Cronometro._veces`), que ya
      > lleva la cuenta de «paso de simulacion» por fotograma: un fotograma
      > que pide ocho pasos, con la hora cambiando en el primero, da **1** paso
      > y no ocho.

- [ ] **14. Cierre del paso 0: dos corridas iguales enteras.**
      Las dos corridas de 15 jornadas, una vez más, con todo lo anterior
      hecho.

      **Verificable:** `Cotejo` dice «iguales» en las 15 jornadas. Si no, la
      jornada y el campo en que se separan señalan la fuente que falta, y se
      vuelve a la lista antes de seguir. Se anota además la suite: pruebas,
      comprobaciones y `SCRIPT ERROR`; es la suite que queda congelada.

      > **HECHO (2026-09-11). La partida se repite.** Dos corridas de 15
      > jornadas, sitio 56, `SEMILLA=123`, `VEL=20`, con ventana:
      > **IGUALES, las 15 jornadas, de la 2 a la 16.** Ya lo eran al cerrar la
      > tarea 11; esta pareja lo confirma con las tareas 12 y 13 dentro.
      >
      > El camino, jornada en que se separaban dos corridas iguales y campos
      > distintos en ella:
      >
      > | | se separan en | campos del detalle |
      > |---|---|---|
      > | antes del paso 0 (tarea 6) | jornada 2 | 55 |
      > | vía única de decisión (7) | jornada 2 | 51 |
      > | fauna al paso fijo (8) | jornada 2 | 4 |
      > | charcas sembradas + `_bodies` fuera (9) | jornada 2, con 5 jornadas iguales | 5 |
      > | el horno termina la que se pide (10) | jornada 3 | 1 |
      > | el repaso cuenta formas (11) | **nunca** | **0** |
      >
      > **La suite que queda congelada: 877 pruebas, 6.142 comprobaciones,
      > todo en verde.** Los `SCRIPT ERROR` de la tanda siguen siendo los tres
      > preexistentes —`Marcha._tick_step` desde Exploración,
      > `TestParajes.gd:300` y `TestHunting.gd:228`—. De las 877, siete son
      > del paso 0: tres de fauna, dos de exploración, una de parajes y una
      > del horno.

- [ ] **15. `Instantanea.volcar`: de bytes a la partida.**
      El sentido de vuelta:
      - los módulos que ya existen se rellenan en su sitio;
      - los objetos que van y vienen se crean con `new()`;
      - los `Node` se enchufan por papel;
      - se informa de lo que no cuadra en los dos sentidos. Campo guardado que
        el código no tiene: error. Campo del código que no viene: aviso, y se
        queda con su valor inicial.

      **Verificable:** en `TestInstantanea.gd`:
      - tomar, volcar sobre una simulación nueva y volver a tomar da los
        mismos bytes;
      - tras volcar, diez pasos en las dos simulaciones —la original y la
        restaurada— dan la misma firma;
      - un campo guardado que no existe en la clase da error.

- [ ] **16. `TironAnualProbe`: guardar y arrancar de una instantánea.**
      Variables de entorno:
      - `INSTANTANEAS=<carpeta>` y `CADA=<n>`: una instantánea cada n
        jornadas, desde `day_passed`;
      - `DESDE=<fichero>`: con la partida aún en pausa, restaura y no reparte
        oficios.

      **Verificable:** una corrida de 6 jornadas con `CADA=3` deja dos
      ficheros. Arrancar `DESDE` el primero pone la partida en la jornada que
      dice el fichero, sin mensajes de campos que no cuadran.

      > **HECHO (2026-09-11).** `INSTANTANEAS=`, `CADA=` y `DESDE=` en
      > `TironAnualProbe`. Con `DESDE` no se reparten oficios: el reparto viene
      > en la instantánea. Si algún campo no cuadra, la sonda lo dice y se
      > para.
      >
      > **Y no se toman en `day_passed`, sino al CERRARSE EL PASO**, con una
      > señal nueva, `SettlementSim.paso_cerrado`. Es el fallo que encontró la
      > tarea 17 y está contado ahí: `day_passed` se emite a mitad de
      > `_advance`, antes de que la gente y la fauna hagan lo suyo, así que una
      > foto tomada ahí es media partida a medio paso. La firma diaria se
      > mudó al mismo sitio, para que las dos miren el mismo instante.
      >
      > Medido con una corrida de 50 jornadas y `CADA=15`: deja las
      > instantáneas de las jornadas 16, 31 y 46, de unos **4,5 MB** cada una
      > —crecen unos 140 KB cada 15 jornadas—, y arrancar de cualquiera de
      > ellas pone la partida en su jornada sin un solo aviso.

- [ ] **17. La instantánea es fiel (criterio 3).**
      Una corrida continua de 90 jornadas con `FIRMAS` e `INSTANTANEAS` cada
      15. Luego dos arranques `DESDE`, de 30 jornadas cada uno: desde la
      jornada 15 y desde la 60, esta última ya pasado el cambio de estación
      de la jornada 46.

      **Verificable:**
      - `Cotejo` dice «iguales» en las jornadas solapadas de los dos
        arranques;
      - se apuntan además los nodos y las llamadas de dibujo de la línea
        diaria de la sonda, continua contra restaurada, el mismo día. Si no
        cuadran, queda escrito aquí que los cambios de motor y vista se
        validan desde la jornada uno.

      > **HECHO (2026-09-11), y costó tres intentos porque la instantánea
      > tenía DOS fallos que ninguna prueba unitaria podía ver.**
      >
      > Se hizo con una corrida continua de 50 jornadas y arranques de 15
      > desde la jornada 16 y desde la 46 —ésta, el cambio de estación—, más
      > una sonda nueva, `scripts/tests/InstantaneaProbe.gd`, que compara la
      > firma **justo después de restaurar**, sin dar un paso, contra la que
      > dejó la corrida continua. Esa sonda es la que hizo el diagnóstico
      > posible: cotejar dos corridas dice que se separan, pero una sola
      > diferencia se lo lleva todo por delante en una jornada y no señala
      > nada.
      >
      > **Primer intento: 44 campos distintos desde la primera jornada.** Y la
      > sonda decía «IGUALES» al restaurar. O sea: el estado entraba entero y
      > se torcía AL DAR EL PRIMER PASO. La causa era cuándo se tomaba la
      > foto: en `day_passed`, que se emite dentro de `_advance` justo después
      > de cerrar la jornada y **antes** de que la gente y la fauna hagan su
      > tick. Al arrancar de ahí, la corrida nueva empieza un paso entero
      > desde ese punto: se pierde la mitad del paso que faltaba. De ahí
      > `paso_cerrado` (tarea 16).
      >
      > **Segundo intento: cuatro campos, y todos de la fauna** —`_animals`,
      > `_prey`, `_predators`— más un estado de azar. El recorrido guardaba
      > las listas y los diccionarios **por valor**, y la partida se apoya en
      > que son referencias: `WildlifeHerds._spawn` mete el MISMO diccionario
      > de cada animal en `_animals` y en `_prey`. Restaurado por valor, salían
      > copias sueltas y mover un animal por una lista ya no se veía en la
      > otra. Ahora los contenedores van por identidad, en su propia tabla
      > (`Instantanea.contenedores`), buscados por cubos de `hash` y
      > `is_same`; el formato sube a la versión 2. Era el riesgo que el propio
      > plan anotó —«el sharing entre objetos dinámicos se pierde»— y se
      > cumplió.
      >
      > **Tercer intento: iguales desde la 16, pero la 46 seguía torcida** —una
      > entrada de crónica de más, un paraje de menos—. Al rehacer el horno se
      > metía la rejilla restaurada en la casilla de la estación de HOY, y si
      > la foto se toma justo al cambiar la estación, esa rejilla es todavía la
      > de la estación pasada: el horno restaurado creía tener ya la nueva y la
      > banda no cambiaba de caminos nunca, mientras la corrida continua sí.
      > Ahora se mete en la casilla que le toca por su caudal, que es distinto
      > en cada estación.
      >
      > **Resultado:** desde la jornada 16, **IGUALES las 15 jornadas**
      > (17-31); desde la 46, **IGUALES las 5** que solapan (47-51), y el log
      > de la restaurada enseña el cambio a «caminos de Verano» en su sitio.
      >
      > **PENDIENTE, y aparecido después (2026-09-11): la instantánea del día
      > 76 NO es fiel.** Al medir la tarea 21 con una ventana arrancada ahí,
      > se separa de la corrida continua en la primera jornada, la 77, y sólo
      > en la fauna (`_animals`, `_prey`, `_predators` y un estado de azar).
      > Lo que se sabe:
      >
      > - **No es el código de las optimizaciones**: la corrida continua del
      >   año con las tres puestas da la misma firma que la línea base, 180 de
      >   180. Continua contra continua, idénticas.
      > - **No es el restaurar**: `InstantaneaProbe` dice que la partida
      >   recién volcada de la jornada 76 es igual campo por campo.
      > - **No es aleatorio**: dos ventanas del 76 con el mismo código dan
      >   exactamente lo mismo entre ellas.
      > - **No pasa en las demás**: las del 16, 46 y 136 siguen cuadrando con
      >   la corrida continua.
      >
      > O sea que hay estado de la fauna que no está en la instantánea y que
      > sólo decide algo en esos días. Queda **abierto**. Mientras tanto, la
      > regla de medida: las ventanas valen para comparar antes/después desde
      > la MISMA instantánea —las dos partidas son la misma—, y la prueba de
      > «no cambia la partida» contra la línea base se hace en una ventana
      > comprobada o en el año entero.
      >
      > **Y el motor casi cuadra**, que es lo que pedía el segundo punto: mismos
      > nodos (2.105 y 2.107 en las mismas jornadas), dibujos dentro del 1 %
      > (830 contra 819; 1.114 contra 1.103) y un 3 % menos de RAM en la
      > restaurada, porque la vista no arrastra lo acumulado. Las ventanas
      > restauradas sirven también para medir motor y vista, con ese margen
      > sabido: una mejora de motor por debajo del 1 % no se puede dar por
      > buena en una ventana restaurada.

- [ ] **18. El desglose del paso de simulación.**
      Marcas nuevas de `Cronometro` dentro de `_advance`, con la regla de
      grano del plan:
      - cada subsistema que se llama una vez por paso, su tramo;
      - el bucle de personas, un tramo entero;
      - dentro de él, sólo lo que se sepa gordo, sin marcas por persona.

      **Verificable:**
      - una ventana de 15 jornadas con `TironAnualProbe` muestra los tramos
        nuevos, y lo que queda de «paso de simulación» sin explicar se anota
        (tiene que ser una fracción pequeña);
      - dos corridas, con cepo y sin él, dan la misma firma (`Cotejo`);
      - el fps medio de las dos se anota como coste del cepo.

      > **HECHO (2026-09-11), en dos pasadas.** Marcas nuevas dentro de
      > `_advance` y de `_tick_person`, por PIEZA y no por persona: el bucle de
      > gente entero, y dentro la rutina, la marcha, los cuerpos dibujados, el
      > cronista, el agua, el sitio en casa, el aprendizaje, el rastro y
      > atascos y la decisión de volver.
      >
      > **La primera pasada dejó un 36 % del bucle de gente sin explicar**, que
      > es justo el trozo sobre el que habría que optimizar a ciegas, así que
      > se marcaron cinco piezas más antes de la línea base. Con eso, de los
      > 45.750 ms del bucle quedan **5.138 sin explicar, un 11 %**. Desglose de
      > ocho jornadas, en ms:
      >
      > | | ms | por llamada |
      > |---|---|---|
      > | paso de simulacion | 61.378 | 48,1 |
      > | — gente (todos los ticks) | 45.750 | 35,9 |
      > | —— rutina | 14.026 | 0,0367 |
      > | —— aprender | 7.284 | 0,0190 |
      > | —— marcha | 6.862 | 0,0179 |
      > | —— cuerpos (vista) | 4.647 | 0,0121 |
      > | —— agua | 3.867 | 0,0101 |
      > | —— cronista | 1.588 | 0,0042 |
      > | —— sitio en casa | 1.355 | 0,0035 |
      > | —— decidir la vuelta | 988 | 0,0026 |
      > | — fauna (en el paso) | 15.255 | 12,0 |
      > | A* (Wayfinder.find) | 2.587 | 10,1 |
      >
      > **Medir no cambia la partida:** dos corridas de 15 jornadas, una con
      > cepo y otra con `CEPO=0`, dan **la misma firma las 15 jornadas**.
      >
      > **Lo que cuesta el cepo:** con cuatro marcas, los fps medios pasaban de
      > 6,9-7,9 a 6,0-7,0, un 12 %; con las nueve de la segunda pasada bajan a
      > 5,2-5,3, o sea cerca de un 25 %. Se anota porque es mucho: el ranking
      > se lee sabiendo que el cepo está dentro, y como está encendido igual en
      > el antes y en el después, no mueve ninguna comparación. Lo que sí
      > queda avisado es que las cifras de fps de este documento no son las de
      > la partida sin medir.

- [ ] **19. El ranking a fichero, y `Cotejo` modo `tramos`.**
      En `TironAnualProbe`, `RESUMEN=<fichero>` escribe el ranking en CSV:
      tramo, suma de ms, llamadas y ms por llamada, más los totales y los dos
      cuartos del año. En `Cotejo`, el modo `tramos`:
      - entrada: dos resúmenes y, opcionalmente, las dos corridas de la línea
        base;
      - salida: para cada tramo, cuánto se mueve en coste por llamada contra
        la banda de ruido, señalando los que la pasan.

      **Verificable:** con CSV hechos a mano —uno igual, uno con un tramo
      movido por encima de la banda— señala exactamente ese tramo y ningún
      otro.

      > **HECHO (2026-09-11).** `RESUMEN=<fichero>` en `TironAnualProbe`
      > —`tramo;ms;veces;ms_por_llamada` y los totales en líneas `#`— y
      > `Cotejo.gd -- tramos ANTES DESPUES [BASE1 BASE2]`.
      >
      > **Una cosa que hubo que arreglar de paso:** la fila de EL MOTOR lleva
      > pegados los nodos, los objetos y los dibujos DE ESE fotograma, así que
      > cada tirón inventaba un tramo distinto y el ranking del año lo contaba
      > en trocitos. Ahora se juntan todos bajo «· EL MOTOR (pintar, fisica)».
      >
      > Medido en dos mitades:
      > - **El CSV, con datos de verdad:** la corrida de 90 jornadas lo
      >   escribió con el ranking entero (17 tramos, de «paso de simulacion» a
      >   «cada 15: panel de banda + minimapa») y sus totales.
      > - **El cotejo, con CSV hechos a mano:** con una línea base donde el A\*
      >   varía un 1 % entre corridas y el horno un 5 %, un «después» que sube
      >   el A\* un 12,5 % y el horno un 1,6 % señala **sólo el A\***, deja el
      >   horno dentro de su ruido, marca «baja» el tramo que bajó y no juzga
      >   el que tiene cinco llamadas. Salida 1 cuando algo sube, 0 cuando no.

- [ ] **20. La línea base: dos años.**
      Dos corridas de 180 jornadas de `TironAnualProbe`, misma semilla, las
      dos con `FIRMAS` y `RESUMEN`, y la primera también con `INSTANTANEAS`
      cada 15.

      **Verificable:**
      - `Cotejo firmas` dice «iguales» las 180 jornadas (criterio 1);
      - `Cotejo tramos` sobre las dos da la banda de ruido por tramo;
      - el ranking, con el primer cuarto contra el último, se copia aquí
        como tabla.

      Si una corrida muere antes del final (el código 1 de hacia la jornada
      136–150), se para y se decide aparte, como dice la spec.

      > **HECHO (2026-09-11).** Dos años completos, sitio 56, `SEMILLA=123`,
      > `VEL=20`, con ventana. Unos 70 minutos cada uno. **Ninguna de las dos
      > murió**: el riesgo de la salida con código 1 hacia la jornada 136-150
      > no se ha vuelto a dar.
      >
      > **Criterio 1, cumplido: IGUALES las 180 jornadas.** La misma semilla da
      > la misma partida, año entero, con la firma completa.
      >
      > **El ranking del año** (corrida A; 6.449 tirones, 819 graves,
      > 3.629.836 ms en total):
      >
      > | tramo | ms | % | por llamada | llamadas |
      > |---|---|---|---|---|
      > | paso de simulacion | 3.491.379 | 96 % | 139,7 | 24.987 |
      > | — gente (todos los ticks) | 3.199.930 | 88 % | 128,1 | 24.987 |
      > | —— **gente: rutina** | **2.527.713** | **70 %** | 0,339 | 7.460.120 |
      > | — fauna (en el paso) | 283.793 | 8 % | 11,4 | 24.987 |
      > | gente: marcha | 156.910 | 4 % | 0,021 | 7.460.120 |
      > | gente: aprender | 144.096 | 4 % | 0,019 | 7.460.120 |
      > | A* (Wayfinder.find) | 140.659 | 4 % | 9,0 | 15.602 |
      > | gente: cuerpos (vista) | 96.742 | 3 % | 0,013 | 7.460.120 |
      > | · EL MOTOR (pintar, fisica) | 82.497 | 2 % | 12,8 | 6.449 |
      > | gente: agua | 82.431 | 2 % | 0,011 | 7.460.120 |
      > | fauna (manadas) | 47.549 | 1 % | 7,4 | 6.449 |
      > | cierre de jornada | 6.108 | 0,2 % | 34,7 | 176 |
      >
      > **Y empeora con los días, medido:** primer cuarto del año, 1.696
      > tirones a 217 ms de media; último cuarto, 1.514 tirones a **524 ms**.
      > Lo que crece es sobre todo `gente: rutina`: 0,037 ms por llamada en
      > las primeras ocho jornadas contra **0,339 en el año**, nueve veces.
      >
      > **La banda de ruido**, que es la otra mitad de esta tarea (`Cotejo
      > tramos` con las dos corridas): `gente: rutina` **±15,3 %**, paso de
      > simulación ±12,7 %, gente: marcha ±10,3 %, gente: aprender ±7,7 %,
      > fauna ±3,8 %, A* ±2,6 %, motor ±2 %. Es ancha para los tramos grandes
      > —los tirones se muestrean solos—, así que una mejora en la rutina
      > tendrá que pasar del 15 % para poder darse por buena.
      >
      > **La suite que queda congelada: 880 pruebas, 6.147 comprobaciones**,
      > todo en verde, con los tres `SCRIPT ERROR` preexistentes de siempre.
      >
      > Un tropiezo, anotado porque costó los dos cotejos: al meter el
      > desglose por estado de la tarea 21 mientras corría la segunda corrida,
      > una variable quedó inferida como `Variant` y este proyecto trata ese
      > aviso como error. Las corridas ya habían cargado y terminaron bien,
      > pero los cotejos del final no compilaron y hubo que repetirlos.

- [ ] **21. Las optimizaciones, un tramo cada vez.**
      No se pueden listar todavía: dependen del ranking de la tarea 20. Por
      cada tramo, en el orden del ranking y releyéndolo tras cada uno, se
      añade aquí una subtarea «21.k — (nombre del tramo)» con:
      - la ventana elegida y la instantánea de la que arranca;
      - el cambio hecho;
      - las tres pruebas del §4, cada una con su cifra: `Cotejo tramos`
        (el tramo baja en coste por llamada y ningún otro pasa la banda),
        `RunTests.gd` igual que en la tarea 14, y `Cotejo firmas` «iguales»
        contra la ventana y contra la línea base;
      - si es de motor o vista, las capturas de antes y después y quién lo
        aceptó.

      Una optimización que no pasa la prueba de la firma se anota igual, como
      descartada, con lo que se probó.

- [x] **21.1. La rejilla, una vez por recorrido y no una por cata.**

      > **HECHO (2026-09-11).**
      >
      > **Cómo se encontró.** El ranking del año dice que `gente: rutina` es el
      > 70 % de todo, pero no de qué. Desglosándola por el estado en que entra
      > cada persona —una marca más por tick, con el nombre sacado ANTES porque
      > la rutina cambia el estado— sale que en una ventana de invierno
      > **`rutina: reconociendo` cuesta 2,08 ms por tick contra 0,019 de
      > `trabajando`**: cien veces más. Y desglosando `_survey` por piezas,
      > **el 91 % de reconocer es sortear el siguiente tramo**, que además se
      > llama en tres de cada cuatro ticks, porque en cuanto un batidor se
      > queda sin ruta vuelve a sortear.
      >
      > Ahí dentro, `_least_known_around` prueba doce candidatos y por cada uno
      > pregunta si hay cauce de por medio; esa pregunta recorre la línea
      > catando cada tres metros. **Y cada cata llamaba a `Marcha._navgrid()`**
      > —que mira si el horno sirve, pide la rejilla de la estación y la
      > compara con la puesta— sólo para leerle el caudal. Un candidato de 260
      > m son 87 catas, o sea 87 veces la misma pregunta. El andador hacía lo
      > mismo y por partida doble: `_can_step_into` pedía la rejilla y luego
      > llamaba a `agua_deja_pasar`, que la volvía a pedir.
      >
      > **El cambio.** `Marcha.caudal_de_hoy()` y `agua_deja_pasar_con(punto,
      > caudal)`: se pregunta UNA vez por recorrido. No cambia nada, y por qué
      > no lo cambia está en el código: lo que `_navgrid()` hace de verdad
      > —montar la rejilla o cambiar a la de la estación nueva— ya lo hacía en
      > la primera cata; las otras ochenta y seis eran consultas sin efecto.
      >
      > **Las tres pruebas**, ventana de las jornadas 137-151 arrancada de la
      > instantánea de la 136, misma instrumentación antes y después:
      >
      > | tramo | antes (ms/llamada) | después | cambio | ruido |
      > |---|---|---|---|---|
      > | paso de simulacion | 251,08 | 153,33 | **−38,9 %** | 12,7 % |
      > | gente: rutina | 0,723 | 0,400 | −44,7 % | 15,3 % |
      > | rutina: reconociendo | 2,078 | 1,243 | −40,2 % | 2,0 % |
      > | reconociendo: siguiente tramo | 2,572 | 1,439 | −44,1 % | 2,0 % |
      > | rutina: ocioso (decide el dia) | 0,690 | 0,312 | −54,7 % | 2,0 % |
      > | gente: marcha | 0,0113 | 0,0100 | −11,6 % | 10,3 % |
      >
      > **Ningún tramo sube por encima de su ruido**: A* +1,0 % (ruido 2,6 %),
      > fauna en el paso +0,6 % (3,8 %), el resto por debajo del 2 %.
      >
      > **La suite, tal cual: 880 pruebas, 6.147 comprobaciones, todo en
      > verde.** Y **la huella idéntica las 15 jornadas**, tanto contra la
      > ventana de antes como contra la corrida del año de la línea base: la
      > partida es exactamente la misma.

- [x] **21.2. La cata del agua, una llamada en vez de ciento setenta y cuatro.**

      > **HECHO (2026-09-11).**
      >
      > **Qué quedaba.** Tras la 21.1, sortear el siguiente tramo sigue siendo
      > el tramo más caro: 1,44 ms por llamada. El A* explica sólo un cuarto
      > (13,6 ms × 3.853 llamadas = 52 s de los 207); el resto es el barrido de
      > doce candidatos, y **el 95 % de ese barrido son las catas del agua**:
      > por cada candidato se recorre la línea catando cada tres metros —87
      > puntos— y cada punto costaba DOS llamadas, la del vado y la del umbral.
      > La cuenta de dentro es un índice y una multiplicación: en GDScript la
      > llamada pesa más que la cuenta.
      >
      > **El cambio.** El recorrido entero lo hace ahora el terreno, que es
      > quien tiene el mapa: `TerrainGenerator.linea_sin_agua(desde, hasta,
      > cada, caudal, tope, estricto)`, **una llamada en vez de 174**, con el
      > mismo muestreo —los mismos puntos, los dos extremos incluidos— y el
      > mismo umbral.
      >
      > **Y la regla del vado no se ha copiado a dos sitios**, que era el
      > riesgo: `Hydrography.tope_de_vado(barca, puente)` dice hasta cuánto se
      > pasa y si la comparación es estricta, y `can_cross` pasa a salir de esa
      > misma función. Una regla, un sitio, dos maneras de preguntarla.
      >
      > **Las tres pruebas**, misma ventana (137-151) y misma instrumentación:
      >
      > | tramo | antes | después | cambio | ruido |
      > |---|---|---|---|---|
      > | paso de simulacion | 153,33 | 117,52 | **−23,4 %** | 12,7 % |
      > | gente: rutina | 0,400 | 0,282 | −29,4 % | 15,3 % |
      > | rutina: reconociendo | 1,243 | 0,937 | −24,6 % | 2,0 % |
      > | reconociendo: siguiente tramo | 1,439 | 1,024 | −28,9 % | 2,0 % |
      > | rutina: ocioso (decide el dia) | 0,312 | 0,174 | −44,3 % | 2,0 % |
      >
      > Ningún tramo sube por encima de su ruido (A* +0,5 %, fauna +0,9 %).
      > Suite: 880 pruebas, 6.147 comprobaciones, en verde. **Huella idéntica a
      > la línea base del año** las 15 jornadas, que es lo que había que
      > demostrar habiendo reescrito el muestreo: cata los mismos puntos.
      >
      > **Acumulado con la 21.1**: el paso de simulación pasa de 251,08 a
      > 117,52 ms por paso en esta ventana, **un 53 % menos**.

- [x] **21.3. Las anclas de los demás exploradores, una vez por barrido.**

      > **HECHO (2026-09-11), y es una mejora pequeña dicha como tal.**
      >
      > En el barrido de candidatos, la regla de «adonde ya va otro no se va»
      > recorría las quince personas **por cada uno de los doce candidatos**, y
      > los demás exploradores no se mueven mientras se barre. Las anclas se
      > sacan ahora una vez por barrido, en el mismo orden que `sim.people`,
      > que es el orden en que se sumaban —el orden importa: son sumas de
      > coma flotante—. De paso, el terreno se guarda en una variable local en
      > vez de pedírselo a la simulación en cada vuelta.
      >
      > **Lo que da:** `reconociendo: siguiente tramo` −4,6 % y `rutina:
      > reconociendo` −4,1 %, los dos por encima de su ruido del 2 %. Los
      > tramos padre se mueven +2,2 % y +3,0 %, dentro de bandas del 12,7 % y
      > el 13,5 %: a ese nivel es ruido, no efecto. **No se vende como más de
      > lo que es**: el bucle de personas costaba poco al lado de las catas de
      > agua que ya se habían quitado en la 21.2.
      >
      > Suite: 880 pruebas, 6.147 comprobaciones, en verde. Huella idéntica a
      > la línea base del año las 15 jornadas.
      >
      > **Acumulado con la 21.1 y la 21.2**: de 251,08 a 120,06 ms por paso en
      > esta ventana, **un 52 % menos**.

- [x] **21.4. El camino del árbol, recortado una vez y no una por candidato.**

      > **HECHO (2026-09-11). Es la gorda, y sale de la queja del jugador:**
      > «aún tenemos tirones de varios segundos por la mañana».
      >
      > **Cómo se encontró.** El log del año de cierre vuelca cada tirón grave
      > con su hora. Los 329 salen a todas horas —33 a las ocho, 32 a las
      > nueve, pero 30 a las seis de la tarde—, así que «por la mañana» no era
      > una hora: eran **días** concretos. En el peor, 7.255 ms del día 90,
      > `rutina: ocioso (decide el dia)` se lleva **6.894 ms del fotograma**,
      > el 95 %, en 900 llamadas. Decidir la jornada sale a 0,17 ms de media y
      > a 7,7 en los fotogramas malos.
      >
      > Desglosando por oficio: es `decide: tajo`, la gente normal. Y dentro,
      > `tajo: probar candidato` —o sea `Marcha._send_to`— se lleva el 92 %,
      > con 105.390 llamadas... **y sólo 116 búsquedas A\***. Se gastaba un
      > milisegundo por candidato ANTES de decidir que ni siquiera iba a
      > buscar. Marcando `_send_to` por dentro: **el 96,5 % es
      > `Wayfinder.camino_por_el_arbol`**.
      >
      > **Por qué costaba.** Sacar el camino del árbol de Dijkstra recorre el
      > hilo hasta la raíz y lo RECORTA con `_pull_string`, que es cuadrático
      > y pregunta si se ve una celda desde otra. Y ese recorte **no depende
      > del destino exacto** —el destino sólo sustituye el último punto—, sino
      > del árbol, la rejilla y la celda. La misma persona probando el mismo
      > candidato en cada tick lo rehacía entero cada vez.
      >
      > **El cambio.** `camino_por_el_arbol` acepta un diccionario de recortes
      > ya hechos; `Marcha` lo guarda y **lo vacía al rehacer el árbol**, que
      > es una vez por rejilla, o sea por estación. Y va a `Instantanea.FUERA`:
      > es caché de una función pura, así que empezar vacía tiene que dar la
      > misma partida —y eso lo comprueba la prueba de la huella, no un
      > razonamiento—.
      >
      > **Las tres pruebas**, ventana de tres jornadas desde la instantánea de
      > la 76 (otoño, con los peores tirones del año):
      >
      > | tramo | antes | después | cambio | ruido |
      > |---|---|---|---|---|
      > | **paso de simulacion** | 263,54 | **67,67** | **−74,3 %** | 12,7 % |
      > | gente (todos los ticks) | 251,43 | 55,46 | −77,9 % | 13,5 % |
      > | gente: rutina | 0,755 | 0,105 | −86,1 % | 15,3 % |
      > | rutina: ocioso (decide el dia) | 3,504 | 0,363 | −89,6 % | 2,0 % |
      > | tajo: probar candidato | 0,992 | 0,036 | −96,4 % | 2,0 % |
      > | send_to: camino por el arbol | 0,957 | **0,007** | **−99,3 %** | 2,0 % |
      >
      > Ningún tramo sube por encima de su ruido (fauna +0,7 %). Suite: 880
      > pruebas, 6.147 comprobaciones, en verde. **Huella idéntica** entre el
      > antes y el después de la misma instantánea, y también contra la línea
      > base del año en una ventana fiel (jornadas 137-138).

- [x] **21.5. La bandeja de picos, y el abanico de cada persona.**

      > **HECHO (2026-09-11). Lo primero no es una optimización: es que el
      > instrumento mentía.**
      >
      > El jugador lo vio en su F3 —«tirones de más de 100 ms cada 0,2 s»—
      > contra un informe mío que decía «8 tirones en todo el año». Medido:
      > **el cepo empujaba 92 picos en dos jornadas y la sonda contaba 3.** El
      > panel y la sonda leen la MISMA bandeja de [Cronometro] y **la vaciaba
      > quien leía**: el primero que pasaba se los llevaba.
      >
      > Mi primer arreglo fue apagar el panel durante las corridas. Estaba
      > mal y el jugador lo paró: apagar el panel es arreglarlo para la sonda
      > y romperlo para quien mira, y sin ese F3 esto no se habría visto.
      > **Arreglado de verdad:** la bandeja la vacía el cepo al abrir cada
      > fotograma y la leen los dos. `PerformanceOverlay` y `PicoProbe` dejan
      > de vaciarla. Comprobado con el panel vivo: **89 empujados, 89
      > contados**.
      >
      > **La primera medida fiable**, tres jornadas desde la instantánea del
      > día 76 (140 cuadros, media 268 ms, 133 de ellos por encima de 100 ms):
      >
      > | tramo | ms | % del paso | por llamada |
      > |---|---|---|---|
      > | paso de simulacion | 34.220 | — | 68,3 |
      > | — gente (todos los ticks) | 28.527 | 82 % | 54,6 |
      > | —— tajo: lista de candidatos | 6.416 | 19 % | 0,420 |
      > | —— tajo: probar candidato | 3.644 | 11 % | 0,035 |
      > | —— rutina: trabajando | 3.627 | 11 % | 0,065 |
      > | — fauna (en el paso) | 5.826 | 17 % | 11,63 |
      >
      > **Y la optimización de esta tarea:** de los 6.416 ms de montar la lista
      > de candidatos, sólo 1.395 estaban en lo marcado; los otros 5.021 eran
      > `Tajo._search_target`, que barre **36 puntos** —doce direcciones por
      > tres distancias— preguntándole al relieve altura, pendiente y vado en
      > cada uno. Y ese abanico **no cambia nunca**: sale del `id` de la
      > persona y del abrigo, y el relieve es el mismo toda la partida. Ahora
      > se guarda ya filtrado (`Tajo._abanico_de`), y se rehace sólo si
      > aparecen barca o puente o se muda el abrigo. Lo que sí cambia —lo que
      > promete el campo y lo que se conoce— se sigue preguntando siempre.
      >
      > | tramo | antes | después | cambio |
      > |---|---|---|---|
      > | tajo: lista de candidatos | 0,420 | 0,218 | **−48,1 %** |
      > | decide: tajo | 0,354 | 0,262 | −26,0 % |
      > | paso de simulacion | 68,30 | 61,72 | −9,6 % |
      > | media del fotograma | 268 ms | 250 ms | — |
      >
      > Suite: 880 pruebas, 6.147 comprobaciones, en verde. Huella idéntica las
      > tres jornadas.

- [x] **21.6. La velocidad de juego es x5, no x20. Y la correa a las
      decisiones.**

      > **HECHO (2026-09-11).** Quien dirige el proyecto avisó de algo que
      > invalidaba el orden entero: **«la velocidad x20 no es parte de la
      > partida, es una velocidad sólo para pruebas; la partida como máximo
      > llega a x5»**. Todas las mediciones anteriores estaban tomadas a x20.
      >
      > **Línea base a x5** (90 jornadas, semilla 123, con el cepo puesto, que
      > cuesta un 20 %): 43.635 cuadros, **media 50,7 ms, peor 324 ms**, 1.787
      > tirones de más de 100 ms —el 4 % de los fotogramas— y **cero graves**.
      > Nada de tirones de varios segundos: a la velocidad que se juega la
      > partida va a unos 20 fps. Y el reparto del paso (41,2 ms) **no es el
      > que decía x20**:
      >
      > | tramo | ms por paso | % del paso |
      > |---|---|---|
      > | rutina: ocioso (decide el día) | 17,8 | **43 %** |
      > | — tajo: probar candidato | 8,1 | 20 % |
      > | — tajo: lista de candidatos | 6,9 | 17 % |
      > | fauna (en el paso) | 11,3 | 28 % |
      > | gente: marcha | 4,1 | 10 % |
      > | A* (Wayfinder.find) | 3,4 | 8 % |
      >
      > A x20 decidir la jornada parecían 3,3 ms por paso; a la velocidad real
      > son 17,8, porque la decisión corre una vez por trozo y a x5 hay cinco.
      >
      > **Lo que NO funcionó, y se revirtió.** Supuse que el desperdicio era el
      > presupuesto de nodos: es por cuadro, a x5 caben cuarenta pasos en un
      > cuadro, agotado en el primero los otros treinta y nueve armarían la
      > lista de candidatos entera para tirarla. Puesta la guarda
      > (`marcha.presupuesto_agotado()` antes de armar la lista), medido:
      > `decide: tajo` se quedó en 0,536 ms por llamada contra 0,530 y 0,550 de
      > las dos corridas de referencia —dentro del ruido— y el paso subió a
      > 40,6 contra 39,2/39,5. **Cero ganancia, y la huella se separaba en la
      > jornada 78** porque saltarse la lista se salta el tanteo, y el tanteo
      > gasta una tirada de azar. Quitado: el presupuesto casi nunca se agota.
      >
      > **Lo que sí.** El desperdicio no era el coste de cada decisión sino
      > **cuántas**: 30.720 en cinco jornadas, casi todas recorriendo los siete
      > candidatos de la lista para no salir, y repitiéndolo veinticuatro
      > segundos de juego después con el mismo monte y los mismos tajos. Ahora
      > quien piensa la jornada y **no cambia nada** —sigue ocioso— no vuelve a
      > pensarla hasta seis minutos de juego más tarde
      > ([Inhabitant.repensar_tras], `ESPERA_PARA_REPENSAR = 0,1 h`). Quien sí
      > sale no espera nada, la espera se borra al empezar cada jornada, y de
      > noche no se cuenta desde ahora sino hasta la hora de salir: la primera
      > decisión de la mañana no se retrasa.
      >
      > | ventana de 5 jornadas desde el día 76 | antes (a / b) | después |
      > |---|---|---|
      > | media del fotograma | 60,5 / 62,0 ms | **46,6 ms** |
      > | tirones de más de 100 ms | 255 / 268 | **38** |
      > | peor fotograma | 252 / 259 ms | **192 ms** |
      > | cuadros en las mismas 5 jornadas | 2.121 / 2.083 | **2.568** |
      >
      > `decide: tajo` desaparece del top-10 del ranking.
      >
      > **En la ventana medida, la partida sale idéntica**: el cotejo dice que
      > el único campo distinto de esas cinco jornadas es
      > **`Inhabitant.repensar_tras`** —el contable de la propia
      > optimización— y que en el resumen no cambia nada. Posiciones, estados,
      > despensa, leña, crónica, parajes y hasta el estado del azar, bit a
      > bit iguales. Repetible (dos corridas idénticas) y suite en verde (880
      > pruebas, 6.147 comprobaciones).
      >
      > **CORRECCIÓN (mismo día): esa ventana no era representativa, y llegué
      > a escribir aquí «la partida es la misma, no parecida». Es falso.**
      > Cotejado el año entero desde la jornada 1 contra la línea base —con
      > este cambio y el de la ojeada, sin el de la fauna— **la partida se
      > separa en la jornada 2**: leña 20,85 → 24,00, raciones 83,80 → 83,59,
      > y el azar. La ventana estaba en el día 76, con la banda ya asentada y
      > sus tajos sabidos; en el juego temprano la gente pasa mucho más rato
      > ociosa, y ahí aplazar seis minutos una decisión sí mueve cuándo sale
      > alguien.
      >
      > Sigue sin tocarse una sola mecánica ni un umbral —la banda hace lo
      > mismo, un poco desplazado— y eso es lo que se autorizó para este
      > tramo. Pero la lección es de método: **una ventana corta prueba lo que
      > pasa en esa ventana y nada más.** Un cambio que sólo se mide donde
      > menos muerde parece gratis por construcción.
      >
      > El campo se queda dentro de la instantánea a propósito: que el cotejo
      > lo señale es más barato que perder fidelidad al restaurar.

- [x] **21.7. La fauna, de cuatro pasos en cuatro.**

      > **HECHO (2026-09-11).** Con las decisiones ya atadas, la fauna pasó a
      > ser el 30 % del paso: 11,2 ms fijos, seiscientos animales
      > preguntándole al relieve dificultad de paso y altura **en cada paso**.
      >
      > Andar es `posición += dirección · velocidad · delta`, y el hambre, la
      > sed y el reloj del susto suben todos multiplicados por `delta`: cuatro
      > pasos de `delta` y uno de `4·delta` dan lo mismo hasta el último
      > decimal. Lo caro era preguntar al relieve cuatro veces para avanzar
      > medio metro. Ahora se acumula (`_fauna_pendiente`) y se entrega entero
      > cada cuatro pasos (`PASOS_DE_FAUNA`): la fauna no anda menos, anda a
      > zancadas más largas. Va por pasos y no por reloj, así que sigue siendo
      > repetible.
      >
      > | ventana de 5 jornadas desde el día 76 | antes | después |
      > |---|---|---|
      > | media del fotograma | 46,6 ms | **41,4 ms** |
      > | tirones de más de 100 ms | 38 | **12** |
      > | peor fotograma | 192 ms | **165 ms** |
      >
      > `fauna (en el paso)` desaparece del ranking. **Lo que cambia de la
      > partida**, según el cotejo: las posiciones de los animales
      > (`fauna._animals`, `_predators`, `_prey`), el estado del azar y los dos
      > contadores nuevos. **En el resumen —gente, raciones, leña, crónica,
      > parajes, cacerías— no cambia nada en las cinco jornadas.** Suite en
      > verde.

- [x] **21.8. La ojeada, una por sitio y no una por paso.**

      > **HECHO (2026-09-11). La única de esta tanda que no cambia nada, y se
      > demuestra.**
      >
      > `BandKnowledge.see_from` barre las celdas a la redonda y **sube** la
      > claridad de cada una; nunca la baja, y marcar una boca de cueva ya
      > marcada tampoco hace nada. O sea que llamarla dos veces desde el mismo
      > punto y con el mismo alcance es, por construcción, un no-op caro. Y
      > quien trabaja está quieto: 6.760 de las 8.175 llamadas.
      >
      > Ahora cada persona recuerda desde dónde y con cuánto alcance dio la
      > última ojeada (`Inhabitant.ojeada_desde`) y no la repite. El alcance
      > entra en la llave porque lo mueve el tiempo que hace.
      >
      > La caché queda **fuera de la instantánea** a propósito —al revés que
      > `repensar_tras`—: perderla al restaurar sólo cuesta una ojeada de más,
      > que no toca un solo número.
      >
      > Peor fotograma 165 → **154 ms**, tirones 12 → 11, media igual.
      > **Huella idéntica las cinco jornadas** y suite en verde: es la prueba
      > de que la premisa de idempotencia era cierta.

      > **Lo que falta por comprobar de 21.6–21.8, y por qué no está.**
      >
      > - **El año entero con los tres cambios.** Hubo una corrida de 90
      >   jornadas (paso de simulación 41,2 → 16,2 ms por llamada), pero su
      >   primer cuarto está contaminado: quien dirige el proyecto abrió otro
      >   programa hacia la jornada 15, y el tramo que se disparó fue `· EL
      >   MOTOR`, no la simulación. Sus tirones y fps no valen; sus tramos
      >   por llamada y sus firmas, sí. La de control se cortó por tiempo en
      >   la jornada 16 con el equipo cargado. La de 180 jornadas se paró a
      >   propósito: **se hará una sola corrida compartida con los demás
      >   agentes que trabajan en este árbol**, salida en
      >   `d:/tmp/ano_compartido/`. Esa corrida prueba el código de todos
      >   juntos, así que si la huella se desvía no dirá de quién es el
      >   cambio.
      > - **Cuánto se desvía la partida en un año**, no en quince jornadas. A
      >   la jornada 2 la desviación es leña +15 % y raciones −0,2 %; hay que
      >   ver si se queda en eso o crece.
      >
      > **Encontrado de paso, sin tocar** —son umbrales, y este bloque no los
      > toca:
      >
      > - `NODES_PER_FRAME` vale **500** y su comentario dice que se subió a
      >   «tres mil». Además `_path_nodes_this_frame` se pone a cero **en cada
      >   paso**, no en cada fotograma: el bote es por paso, pese al nombre.
      >   Por eso la guarda de presupuesto de 21.6 no disparaba nunca.
      > - A x5 **cada paso tickea a la gente cinco veces** (`steps =
      >   ceil(time_scale)`), para que acelerar no deje atravesar obstáculos.
      >   Pero se trocea TODO el tick, no sólo el andar: rutina, aprendizaje,
      >   cronista, cuerpos. Es la palanca grande que queda —el 70 % del paso
      >   es `gente`— y cambiaría la partida más que las de esta tanda, así
      >   que es decisión de quien dirige, no mía.
      > - Los tirones que quedan son **el A\***: 12 llamadas a 71 ms son el
      >   74 % de los 11 fotogramas malos de la última ventana. Ya está bien
      >   escrito (arrays planos, montón binario, cerradas); bajarlo es otro
      >   algoritmo, no un retoque.

      > **EL AÑO, MEDIDO (2026-09-11, noche).** Una sola corrida compartida
      > con los otros agentes del árbol (QUE_SE_PUEDA_PERDER y
      > QUE_FALTA_PARA_JUGARLO), así que prueba el código de todos juntos:
      > `TironAnualProbe`, SEMILLA=123, VEL=5, 180 jornadas, reparto por
      > defecto, con el equipo sin otra carga salvo los primeros ~40 s (un
      > editor de otra sesión, dentro de la jornada 1). Salida en
      > `d:/tmp/ano_compartido/`.
      >
      > **Las jornadas 1–90, contra la línea base** (las únicas que tiene):
      >
      > | jornadas 1–90 | línea base | con 21.6–21.8 |
      > |---|---|---|
      > | fps medio por jornada | 19,9 | **24,2** |
      > | tirones de más de 100 ms | 1.787 | **187** (−90 %) |
      > | por cuartos | 63 / 88 / 877 / 759 | 15 / 11 / 100 / 61 |
      > | peor fotograma | 324 ms | 419 ms |
      >
      > El peor fotograma sube: es uno solo, y el recuento muestra que los
      > tirones no se han concentrado ahí sino que han desaparecido. Queda
      > anotado igualmente.
      >
      > **Las 180:** 103.436 cuadros, media 41,7 ms, 692 tirones (el 0,67 %),
      > **cero graves**. Pero el último cuarto (136–180) tiene 498 de ellos, y
      > para esas jornadas no hay línea base con la que comparar.
      >
      > **La partida.** Se separa de la línea base en la jornada 2, como ya se
      > sabía, y **a la jornada 90 cuenta la misma historia**: los mismos ocho
      > supervivientes (ids 7–14; los siete que faltan mueren de hambre la
      > jornada 86 en las dos), las mismas técnicas, raciones a cero en las
      > dos. Lo que cambia es de detalle: leña 20,4 → 27,2, parajes 10 → 11.
      > Es lo que se autorizó: la banda hace lo mismo, un poco desplazado.
      >
      > **El siguiente tramo** ya no es decidir ni la fauna:
      >
      > | tramo | ms | llamadas | por llamada |
      > |---|---|---|---|
      > | rutina: reconociendo | 57.490 | 40.007 | 1,44 |
      > | — reconociendo: siguiente tramo | 50.345 | 8.124 | **6,20** |
      > | A* (Wayfinder.find) | 51.359 | 2.707 | 19,0 |
      >
      > Sospecha, sin medir todavía: `Reconocimiento` pide el siguiente tramo
      > también cuando `route_step >= route.size()`, y con la ruta VACÍA eso
      > se cumple en cada tick. Tiene la forma exacta del reintento de 21.6.
      >
      > **Medido, y la sospecha era a medias falsa.** Partido el tramo según el
      > motivo, dos ventanas de 5 jornadas desde la instantánea del día 151
      > (idénticas entre sí; equipo al 16–20 % de carga):
      >
      > | motivo | llamadas | por llamada | % |
      > |---|---|---|---|
      > | ruta acabada, sin llegar al destino | 237 / 241 | 16,8 ms | 52 % |
      > | ruta acabada, llegó sin mirar | 384 / 396 | 5,0 ms | 25 % |
      > | sin ruta | 330 / 332 | 5,2 ms | 23 % |
      > | **llegó y miró la media hora** | **0** | — | 0 % |
      >
      > El siguiente tramo es **el 68 % del paso** en los fotogramas malos, y
      > la ruta vacía sólo la cuarta parte. Lo grande es otra cosa: **la regla
      > de pararse a mirar no se cumple nunca.** [MIRAR_EL_SITIO] pide media
      > hora por tramo —ocho tramos por batida—, pero la condición la
      > cortocircuita el `or route_step >= route.size()`: el andador sube
      > `route_step` al pisar el último hito ([Marcha.gd:152]), y en ese mismo
      > tick se sortea el siguiente. Y si la ruta acaba antes del destino, se
      > sortea igual, a 16,8 ms la vez.
      >
      > Esto ya no es sólo coste: arreglarlo cambia el ritmo de la
      > exploración —a lo que el propio código dice que debería ser—. Se deja
      > la decisión a quien dirige el proyecto.

- [x] **21.9. En cada tramo hay que pararse a mirar, y ahora se cumple.**

      > **HECHO (2026-09-11). Decidido por quien dirige el proyecto**, porque
      > cambia el ritmo de la exploración: a lo que el propio código dice que
      > debe ser.
      >
      > Tres cambios en `Reconocimiento._survey`, todos en la condición de
      > sortear el siguiente tramo:
      >
      > - **La ruta acabada ya no se salta la media hora.** El «o la ruta se
      >   acabó» se comía [MIRAR_EL_SITIO]; ahora hace falta haber llegado Y
      >   haber mirado.
      > - **Si el camino no llega del todo, se mira desde donde acaba.** Con el
      >   destino puesto, esperar habría sido peor que no esperar: el andador
      >   de [Marcha] vuelve a trazar hacia el destino en cada tick cuando la
      >   ruta está gastada y no se ha llegado. Así que el sitio se da por
      >   alcanzado donde se está.
      > - **Sin ruta, seis minutos quieto y se vuelve a probar**, con la misma
      >   espera de las decisiones (`SettlementSim.ESPERA_PARA_REPENSAR`: una
      >   regla, un sitio). Y quieto de verdad: `target` a la posición, por lo
      >   mismo.
      >
      > | ventana de 5 jornadas desde el día 151 | antes | después |
      > |---|---|---|
      > | tirones de más de 100 ms | 84 / 86 | **19 / 21** |
      > | peor fotograma | 413 / 301 ms | **220 / 234 ms** |
      > | media del fotograma | 46,9 / 47,5 ms | 44,4 / 44,3 ms |
      > | tramos sorteados en fotogramas malos | 951 / 969 | **35 / 39** |
      > | ms sorteando tramos | 7.634 / 8.120 | **1.432 / 1.670** |
      >
      > Repetible (las dos «después» idénticas), suite en verde (880 pruebas,
      > 6.147 comprobaciones), equipo al 14–16 % de carga durante las cuatro
      > ventanas. **La partida, a la jornada 156:** la misma gente, las mismas
      > técnicas, **los mismos 20 parajes**; raciones 377 → 383, leña 21,0 →
      > 24,7. Falta verlo en el año: se hará en la próxima corrida larga,
      > junto con lo siguiente, para no correr dos años.
      >
      > Lo que queda en los fotogramas malos vuelve a ser el A\*: unas 44
      > búsquedas a ~35 ms. Cada tramo todavía prueba hasta diecisiete
      > caminos; ahora se sortean veinticinco veces menos, pero cada sorteo
      > sigue costando lo mismo.

- [x] **21.10. El A\*: la sospecha era falsa, y el atajo que sí vale gana
      poco.**

      > **HECHO (2026-09-11).** Leyendo el código, el sospechoso era
      > `_pull_string`, el recorte de la escalera: cúbico en la longitud del
      > camino y creando un array por muestra. **Medido antes de tocarlo**
      > (una marca alrededor de `_rebuild`): rehacer y recortar son **12 ms
      > de 1.406, el 0,9 %**. Inocente. El A* se va en BUSCAR.
      >
      > Lo que se hizo: en el bucle de vecinos —del A* y de `metros_desde`,
      > que siguen la misma regla y tienen que seguirla igual— el caso sin
      > cauce se resuelve con dos lecturas locales, y sólo se llama a
      > `Navgrid.paso_entre` cuando alguna de las dos celdas lleva agua.
      > `paso_entre` no se toca y el resultado es el mismo celda a celda.
      >
      > | ventana de 5 jornadas desde el día 151 | antes (c / d / e) | después (f / g) |
      > |---|---|---|
      > | cuadros en las mismas 5 jornadas | 2.697 / 2.698 / 2.707 | **2.744 / 2.737** |
      > | media del fotograma | 44,4 / 44,3 / 44,2 ms | **43,6 / 43,7 ms** |
      > | tirones de más de 100 ms | 19 / 21 / 18 | **11 / 13** |
      > | A* por llamada, en fotogramas malos | 34,6 / 36,1 / 31,9 ms | 31,5 / 32,0 ms |
      >
      > **Huella idéntica** en las dos ventanas contra la de antes —no ha
      > cambiado un solo camino— y suite en verde. **Lo que no se consiguió,
      > dicho claro:** la búsqueda larga, la que hace los tirones que quedan,
      > cuesta lo mismo por llamada (dentro del ruido). La ganancia está en
      > el fotograma entero, pequeña y fuera de la franja de ruido en las
      > tres cifras. Bajar las búsquedas largas ya no es un atajo: es otro
      > algoritmo (jerárquico, o por portales), y los caminos dejarían de
      > salir idénticos.

      > **EL AÑO, OTRA VEZ (2026-09-12), con 21.9 y 21.10 dentro.** Misma
      > corrida compartida que la anterior —SEMILLA=123, VEL=5, 180 jornadas,
      > reparto por defecto— y esta vez **con vigilante**: si el log pasaba
      > cinco minutos sin escribir una línea, matarla y decir dónde. Hizo
      > falta porque otro agente tuvo un CUELGUE de verdad (17 minutos de
      > silencio con un núcleo al 100 %) y un cuelgue no da código de error,
      > sólo silencio. La corrida llegó entera: `colgada=0`.
      >
      > | el año | antes (21.6–21.8) | ahora (+21.9, 21.10) |
      > |---|---|---|
      > | cuadros | 103.436 | **109.968** |
      > | media del fotograma | 41,7 ms | **39,1 ms** |
      > | tirones de más de 100 ms | 692 | **150** (−78 %) |
      > | primer cuarto / último cuarto | 26 / 498 | **11 / 26** |
      > | graves (≥ 1 s) | 0 | 1 |
      >
      > **Y la partida cambia mucho menos de lo que temía: las firmas son
      > IDÉNTICAS hasta la jornada 137**, y se separan en la 138. Al cierre
      > del año: los mismos ocho supervivientes (ids 7–14), las mismas cinco
      > técnicas, 22 parajes contra 23, raciones 124,6 → 143,4, leña 4,9 →
      > 15,8. La ventana de cinco jornadas desde el día 151 hacía parecer que
      > 21.9 cambiaba la partida desde el primer día; el año dice que no —otra
      > vez la misma lección: la ventana prueba la ventana—.
      >
      > **El único fotograma grave del año: 1.074 ms, jornada 90 a las 16:00.
      > Era LA INTERFAZ.** Y lo resolvió quien dirige el proyecto, no la
      > sonda: «en ese momento justo abrí la pestaña de almacén del run».
      >
      > Vale la pena dejar escrito el camino equivocado, porque lo recorrí
      > entero. La jornada 90 es el cruce Verano→Otoño, y el cruce encaja con
      > el sitio donde a otro agente se le colgó su corrida, así que até las
      > dos cosas y culpé a `HornoDeRejillas.de()`, que espera dentro del
      > fotograma (`while not pedida.horneada(): pedida.amasar(...)`, y una
      > rejilla son ~900 ms). Los otros tres cruces del año ya lo
      > desmentían —día 45: 74 ms; día 135: 71 ms; día 180: 64 ms— y aun así
      > seguí con la sospecha, sólo que más fina. **Dos correcciones
      > seguidas, y la buena vino de fuera.** Una coincidencia en el tiempo
      > no es una causa, y el cepo no ve lo que hace quien mira la pantalla.
      >
      > Lo que deja: **abrir el panel de almacén congela la partida casi un
      > segundo.** Es coste puro de interfaz, no toca la simulación, y nadie
      > lo había medido porque las sondas no abren paneles.

- [ ] **22. El año de cierre.**
      Cuando quien dirige el proyecto dé el bloque por cerrado: 180 jornadas
      desde la jornada uno, con la semilla de la línea base, `FIRMAS` y
      `RESUMEN`.

      **Verificable:**
      - `Cotejo firmas` contra la primera corrida de la tarea 20 dice
        «iguales» las 180 jornadas;
      - `RunTests.gd` igual que en la tarea 14;
      - la tabla de línea base contra cierre del §6, por tramo y del
        conjunto, copiada aquí.

      > **MEDIDO (2026-09-11), con el bloque todavía abierto.** El año se ha
      > corrido para ver qué llevan puesto las tres optimizaciones; **dar el
      > bloque por cerrado es decisión de quien dirige el proyecto**, y quedan
      > tramos en el ranking. La casilla se deja sin marcar por eso.
      >
      > 180 jornadas desde la jornada uno, `SEMILLA=123`, `VEL=20`, con
      > ventana.
      >
      > **La partida es la misma: IGUALES las 180 jornadas** contra la corrida
      > A de la línea base. Es la prueba que importa: tres cambios en el camino
      > más caliente de la simulación y ni una cifra distinta en un año entero.
      >
      > **Del conjunto:**
      >
      > | | línea base | cierre |
      > |---|---|---|
      > | tirones de más de 100 ms | 6.449 | 6.477 |
      > | **tirones graves (≥ 1 s)** | **819** | **329** |
      > | primer cuarto, media por tirón | 217 ms | 220 ms |
      > | **último cuarto, media por tirón** | **524 ms** | **316 ms** |
      >
      > Los tirones de cien no bajan; **los graves caen un 60 %**, y el último
      > cuarto del año —lo que crecía con los días— baja un 40 %. Tiene
      > sentido: lo quitado es trabajo del batidor, que es quien fabricaba los
      > fotogramas de varios segundos.
      >
      > **Por tramo** (coste por llamada, con la banda de ruido de la línea
      > base):
      >
      > | tramo | base | cierre | cambio | ruido |
      > |---|---|---|---|---|
      > | paso de simulacion | 139,73 | 120,58 | −13,7 % | 12,7 % |
      > | gente (todos los ticks) | 128,06 | 108,88 | −15,0 % | 13,5 % |
      > | gente: rutina | 0,339 | 0,276 | −18,6 % | 15,3 % |
      > | · EL MOTOR (pintar, fisica) | 12,79 | 9,13 | −28,6 % | 2,0 % |
      > | fauna (en el paso) | 11,36 | 11,40 | +0,3 % | 3,8 % |
      > | A* (Wayfinder.find) | 9,02 | 9,05 | +0,4 % | 2,6 % |
      >
      > **Ningún tramo sube por encima de su ruido**, con una excepción que se
      > dice porque está en la tabla: «cada 90: niebla del minimapa» sube un
      > 2,4 % contra una banda de 2,2 %. Dos décimas por encima del ruido en un
      > tramo que nadie ha tocado: es ruido, no efecto.
      >
      > **Sobre el año el paso baja un 13,7 %, y en la ventana de invierno un
      > 52 %.** No se contradicen: la ventana es el peor trozo del año, donde
      > el batidor manda, y el año entero incluye tres cuartas partes en las
      > que reconocer pesa poco.
      >
      > La suite, en las mismas condiciones de la línea base: **880 pruebas,
      > 6.147 comprobaciones, todo en verde.**
      >
      > ---
      >
      > **SEGUNDO AÑO DE CIERRE (2026-09-11), ya con la 21.4**, que es la que
      > mató los tirones de la mañana:
      >
      > | | línea base | cierre 1 (21.1-21.3) | **cierre 2 (con 21.4)** |
      > |---|---|---|---|
      > | tirones de más de 100 ms | 6.449 | 6.477 | **8** |
      > | tirones graves (≥ 1 s) | 819 | 329 | **0** |
      > | último cuarto, tirones | 1.514 | 1.546 | **0** |
      > | último cuarto, media por tirón | 524 ms | 316 ms | **—** |
      >
      > **Ocho fotogramas de más de cien milisegundos en un año entero, y
      > ninguno de más de un segundo.** La queja que abrió este bloque —«hay
      > tirones de varios segundos y se hacen más comunes según avanza la
      > partida»— queda respondida con la medida: ni son de varios segundos ni
      > se hacen más comunes, porque ya no los hay.
      >
      > **Y la partida sigue siendo la misma: IGUALES las 180 jornadas** contra
      > la línea base.
      >
      > **Cómo NO leer la tabla de tramos de esta corrida.** Con ocho tirones,
      > el coste por llamada de cada tramo sale de una muestra de ocho
      > fotogramas —los ocho peores del año— contra los 6.449 de la línea
      > base. Por eso el cotejo marca «SUBE» en `gente: marcha` (+124 %) o
      > `gente: aprender` (+69 %): no han empeorado, es que ya sólo se les mide
      > en los pocos fotogramas raros que quedan. Lo comparable de esta corrida
      > es **cuántos tirones hay**, no cuánto cuesta cada tramo dentro de
      > ellos. Para eso están las ventanas de la tarea 21, con el mismo
      > muestreo a los dos lados.
