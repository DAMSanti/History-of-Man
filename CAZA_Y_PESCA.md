# Caza, pesca y memoria de la banda

Cierra el hueco entre lo que la banda **hace** y lo que el jugador **ve**. Los
tres sistemas que dan de comer —la caza, la pesca y la despensa— funcionaban
como tablas de rendimiento: se ponía gente en un oficio, corrían las horas y
aparecían números en el almacén. Los ciervos que `WildlifeHerds` pinta cruzando
el valle no tenían nada que ver con la carne que llegaba.

No abre época nueva ni añade materiales: convierte en conducta lo que ya era
aritmética, y pone en pantalla lo que ya pasaba en silencio.

Ver [SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) para el diseño de la época,
[CIERRE_SLICE.md](CIERRE_SLICE.md) para el goal anterior y
[SPECS.md](SPECS.md) para el contrato técnico.

---

## 0. Lo que se pidió, y en qué orden se hizo

1. **Podredumbre y parte diario** — existía y no se veía. Lo más barato de
   cerrar y lo que hace falta para poder juzgar todo lo demás: sin saber qué se
   tira, cualquier cifra de producción engaña.
2. **Ahumado automático** — el secadero dejaba de ser un trabajo y pasa a ser
   lo que es, un bastidor sobre las brasas.
3. **La puerta del arma** — «no vamos a cazar un bisonte o un lobo con las
   manos vacías». Es un filtro, no una penalización, y hay que ponerlo antes de
   tocar la cacería para que ésta herede la regla en vez de repetirla.
4. **Las nasas** — la pesca deja de ser una escalera de un solo peldaño a la
   vez: se cala y ADEMÁS se pesca.
5. **La cacería visible** — acecho, persecución, lance, despiece y acarreo.
6. **Los relatos y la pared** — lo que se cuenta al volver, y la diferencia
   entre contarlo y pintarlo.

---

## 1. La despensa: lo que se pudre y lo que se salva

### 1.1 El parte de lo que se tira

`Storehouse.age` aplicaba la podredumbre desde siempre y **no se veía**. Desde
fuera, un montón que no crece porque nadie lo trae y uno que no crece porque se
pudre se leen exactamente igual, y no son lo mismo: el primero se arregla
mandando gente y el segundo, no.

Ahora se cuenta todos los días, con nombre y cantidad, **y con el motivo**:

> Se echó a perder 12,4 de pescado y 3,1 de carne. Sin secadero no hay forma de
> guardarlo.

Esa segunda frase es la mitad del parte. Un aviso que sólo dice cuánto se ha
perdido deja al jugador sin nada que hacer con el dato; lo que lo convierte en
una decisión es saber qué le falta. Y el peso en la crónica sale de la
cantidad: una merma normal es rutina y se olvida, perder la despensa no.

### 1.2 El ahumado, automático

**Petición literal:** «será automático siempre que se tenga hogar encendido y
ahumador y al menos un trabajador de hogar; no es un trabajo activo, pero sí se
necesita supervisar».

Y además es lo que es un secadero: un bastidor sobre las brasas. La carne se
cuelga por la mañana y el humo trabaja solo. Antes ocupaba la jornada entera de
quien lo atendía, con lo que tener secadero costaba una persona.

Las tres condiciones son las tres, y cada una falla distinto: sin bastidor no
hay dónde colgar, sin brasas no hay humo, y sin nadie al hogar el fuego se
aviva mal y la carne se ahúma de un lado. Esa tercera es la supervisión, y es
lo que hace que dejar el oficio de hogar vacío se pague en la despensa y no
sólo en el fuego.

Cuánto se cura sale de **cuántos** supervisan y de lo que saben, no de cuántas
horas le echan: el bastidor tiene el tamaño que tiene, y una segunda persona al
hogar es una segunda tanda colgada, no la misma vigilada el doble.

---

## 2. Con qué se le entra a cada pieza

**Petición literal:** «hay animales que no intentarán cazar si les falta lo
necesario... por ejemplo, no vamos a cazar un bisonte o un lobo con las manos
vacías».

Cada especie de `Fauna` declara ahora con qué se le puede entrar:

| | arma | por qué |
|---|---|---|
| Conejo, liebre, perdiz, ánade, urogallo | — | Lazo y palo. Es la comida del primer día |
| Corzo, rebeco | azagaya **o** punta | Una lanza de mano basta, y es muchísimo más vieja que la azagaya de asta |
| Lobo | azagaya | La única pieza MENOR que no admite lanza: a un lobo no se le espera a corta distancia |
| Ciervo, jabalí, caballo, uro | azagaya | A mil kilos no se le entra con un palo endurecido |

Tres decisiones que conviene dejar escritas:

- **Es un FILTRO, no una penalización.** Media pieza de uro sin azagaya no es
  media pieza: es una cuadrilla que vuelve corriendo. Lo que no se puede cobrar
  desaparece de la lista de lo que hay en ese sitio, con lo que la valoración
  del coto cae sola y la cuadrilla se va a donde sí puede cobrar algo.
- **Lo que no se caza tampoco cuesta.** `risk_at` mira la misma puerta: sin
  azagaya no se le entra al uro, así que tampoco se corre su riesgo. Antes una
  banda desarmada se llevaba las cornadas de una caza que no estaba haciendo.
- **La trampa se la salta, y ÉSA es su razón de ser.** Un foso coge un jabalí
  sin que nadie le tenga que entrar. Si el foso pidiera azagaya no serviría
  para nada.

Y se dice. Cerrar la puerta en silencio es la peor versión de sí misma: una
cuadrilla que vuelve de vacío de un cotarro lleno de ciervos se ve, desde
fuera, igual que una que fue a un sitio pelado. Ahora se anota una vez al día
—«Haro vio ciervo en el Raizal y lo dejó pasar: hace falta azagaya»— y el panel
de caza lo lleva debajo de cada rama.

---

## 3. La pesca: la nasa deja de ser un peldaño

`Fishing.Method.NASA` era una tabla de rendimiento al lado del arpón y del
sedal, o sea **una manera de plantarse en la orilla una jornada entera**. Una
nasa no es eso. Una nasa es un objeto que se queda en el río.

La consecuencia de tenerla en la escalera era doble y las dos estaban mal: una
banda con nasas y sin arpón se pasaba el día de pie en la orilla con una cesta,
y una con arpón no calaba ninguna.

Ahora hay dos listas. `Fishing.ACTIVAS` son las jornadas en el agua —mano,
pesquera, sedal, red, arpón— y la nasa está fuera. El pescador que sabe hacerlas
**revisa la línea por la mañana y luego pesca con lo mejor que tenga**, que es
la petición literal.

- La nasa **es** la pieza del utillaje (`Tool.Kind.NASA`, que el taller ya sabía
  trenzar). Al calarla sale del abrigo y se queda en el agua gastándose; el día
  que se pudre se pierde de verdad.
- **Cebo.** Una nasa sin cebar sigue cogiendo lo que se mete a refugiarse —una
  anguila se mete en cualquier agujero— pero mucho menos. Ponerlo a cero
  convertiría el cebo en un interruptor y la nasa en una pieza inútil el día
  que se acaban los caracoles.
- Lo que cobra se acumula **pesado por lo que valía cada día**, no resuelto
  mirando cómo está hoy: una nasa que estuvo cebada cuatro días y cuatro sin
  cebo no se paga entera a precio de mala ni entera a precio de buena.
- Y se ve en la orilla, con su cesto de mimbre medio hundido y ladeado hacia el
  cauce. Ver `NasaMarkers`.

---

## 4. La cacería, vista

**Petición literal:** «toda caza que no sea sorpresiva quiero que se reproduzca
en el juego, es decir quiero ver a los cazadores acechar, perseguir, cazar a su
presa».

La trampa se queda como estaba y no es un olvido: una trampa **es** lo
sorpresivo. Cae sola mientras la banda duerme y no hay acecho que mirar.

Las fases, y qué decide cada una:

1. **Rastreo.** La mayor parte del día. Se bate el monte y no se cobra nada,
   porque cazar es sobre todo no encontrar.
2. **Acecho.** Se anda hasta tenerla a noventa metros y desde ahí se acecha, a
   algo más de medio paso: nadie cruza dos kilómetros agachado. Cada rato hay
   riesgo de que la pieza levante la cabeza, y el riesgo sube al acercarse. El
   ojeo lo tapa: batir con un plan es literalmente que la pieza no sepa por
   dónde le viene.
3. **Persecución.** Ya ha arrancado. Se pierden muchas: lo que decide no es el
   fondo del cazador, es que el monte se la traga.
4. **Lance.** Una tirada. Llegar a tiro sin que te vean la mejora mucho —una
   pieza parada y de costado no es la misma pieza que una que ya corre— y la
   cuadrilla también.
5. **Despiece o acarreo**, según el tamaño. Ver §5.

Dos cosas que la cuadrilla hace y antes no:

- **Rodea UNA pieza, no cuatro.** Quien llega a un coto donde ya hay una batida
  en marcha se suma a ella. Sin esto, cuatro batidores acechaban cuatro ciervos
  cada uno por su lado, que no es una cuadrilla.
- **La caza menor NO se suma.** Se hace al acecho, solo o de a dos, y una
  cuadrilla no acecha mejor. `Hunting.CREW` ya lo decía y no llegaba a la
  conducta.

### 4.1 El tiempo no se ha inventado de cero

Lo que gobierna cuántas piezas cobra una jornada sigue siendo
`Hunting.pieces_per_day`, que está medido. Lo que hace la cacería visible es
**gastar esas horas donde se ven** —rastreando, acechando, corriendo— en vez de
hacerlas desaparecer en una multiplicación.

Si una jornada perfecta cobra `p` piezas, cada pieza cuesta `HORAS_UTILES / p`
horas de jornada perfecta; lo que la persona tenga de menos —destreza,
temporada floja, mal tiempo, ir sin cuadrilla— alarga ese rastreo en la misma
proporción en la que antes reducía el rendimiento.

---

## 5. ¿Se lleva la pieza a casa o se abre donde cae?

**Las dos cosas, según el tamaño**, y no es una comodidad de código: es el
efecto *schlepp*, de lo mejor documentado que hay en zooarqueología. En los
abrigos aparecen esqueletos casi completos de pieza pequeña y perfiles sesgados
a las partes buenas de la grande, porque lo pequeño se echa al hombro y lo
grande se abre donde cae y se acarrea por partes.

- Por debajo de veinte raciones —un corzo— la pieza se lleva entera.
- Por encima se abre en el sitio, y eso cuesta tiempo **y filo**. Sin lasca no
  es que se tarde más: es que no se pasa del cuero, y lo que se aprovecha de la
  piel y el tendón se cae.
- Lo que no cabe en una espalda **se queda en el monte**. Un uro son varios
  viajes, y hay tres jornadas para volver a por lo que quedó: después se pierde,
  y no sólo porque se pudra —hay lobos, y una res abierta se anuncia sola—.

Volver a por una espalda de ciervo rinde más que salir a por otra pieza, así
que el cazador que sale por la mañana va primero a lo que dejó abierto.

---

## 6. Lo que se cuenta al volver, y lo que se queda en la pared

**Petición literal:** «después de una caza mayor, cuando vuelvan al abrigo
contarán la historia y eso se transmitirá al jugador... cualquier
descubrimiento, adelanto tecnológico o hito quiero que se represente también
con una historia y nos dará la opción de pintarlo en la cueva».

La mitad de esto ya existía y no se veía: `_knowledge_transmission` acerca cada
noche a los que duermen en la cueva a lo que sabe el mejor de ellos, y eso **es**
contar la cacería junto al fuego. Lo que faltaba era enseñárselo al jugador y,
sobre todo, la diferencia entre contarlo y pintarlo.

- El relato se **arma donde pasa** —al cobrar la pieza, que es donde están los
  hechos: la especie, el sitio, si les vieron venir— y se **cuenta al llegar**,
  que es cuando hay quien lo oiga.
- Sólo la pieza mayor. «En el Paleolítico una gran caza no era algo diario»:
  contar cada conejo del lazo convertiría el relato en ruido.
- El **cómo** importa más que el qué, que es lo que lo hace un relato y no una
  entrada de almacén. No es lo mismo llegar a tiro sin que te vean que reventar
  el monte detrás de la pieza hasta acorralarla, y no se cuentan igual.

### 6.1 Pintar, y por qué cambia la partida

Contado, un relato dura lo que dure quien estuvo. Pintado, no. Eso no es una
metáfora: es lo que dice `TechTree.Tech.ARTE` con todas las letras —«fijar lo
que se sabe de los animales y transmitirlo a quien no estaba: es la primera
tecnología de la memoria»— y es exactamente lo que hace.

**Efecto:** cada relato pintado sube el techo de lo que se puede aprender de
oídas sobre esa tarea. La transmisión nocturna estaba topada en el 75 % de lo
que sabe el mejor presente, porque contar no es hacer; con la pared, ese techo
sube seis puntos por escena y se para en el 95 %. Nunca llega al 100 y no debe:
una parte de lo que sabe un cazador es la mano, y eso no se aprende mirando una
pared. Lo que la pared hace es que **no haya que empezar de cero cada vez que se
muere el que sabía**.

Una escena de caza mayor enseña a cazar pieza mayor, no a trenzar cordel. La
excepción es el relato de una técnica, que no tiene especialidad —se aprende a
hacer el arpón, no a hacerlo desde la orilla— y cubre el oficio entero.

**Qué cuesta:** saber pintar (`Tech.ARTE`, que ya pedía hogar levantado), ocre
para el pigmento, grasa para la lámpara, dos jornadas de alguien del hogar y
—lo nuevo— una **lámpara**: `Tool.Kind.LAMPARA`, un canto ahuecado con grasa y
una mecha. La lámpara de Lascaux es literalmente eso: arenisca vaciada a golpes
con un cuenco para la grasa. Es de las poquísimas piezas cuyo rendimiento sin
ella es **cero**: a oscuras no se pinta ni despacio ni deprisa.

El taller no hace lámparas antes de saber pintar. Nadie ahueca un canto para
tener luz dentro de la cueva antes de tener algo que hacer dentro de la cueva.

### 6.2 Lo que NO levanta relato, y por qué

El bautizo de un paraje. Un relato con opciones para el reloj —ver `Moment`— y
si cada sitio con nombre parara la partida a preguntar si se pinta, en dos
estaciones el jugador aprendería a cerrar la tarjeta sin leerla. Lo que se
pinta es lo que pasa pocas veces: una caza mayor, una cumbre, una técnica.

---

## 7. Medido

Todo lo de abajo sale de `scripts/tests/CaceriaProbe.gd`, sitio 56, ciento
veinte jornadas, quince personas —cuatro a la caza mayor, dos a la menor, dos
a la ribera, dos al hogar y el resto al taller y a la materia prima— con las
técnicas dadas y seis azagayas hechas.

### 7.1 La cacería, ya funcionando

| | |
|---|---|
| Cacerías levantadas | 85 |
| Cobradas | 54 (64 %) |
| Piezas | 19 caballos, 12 corzos, 16 perdices, 7 ciervos |
| Raciones por jornada-persona, caza mayor | 7,33 |
| Raciones por jornada-persona, caza menor | 5,35 |

Y **por qué se acaba cada una**, que es lo que permitió afinarla sin adivinar:

| | |
|---|---|
| Lance fallado | 257 |
| Cobrada | 54 |
| Acecho: se enfrió el rastro | 21 |
| Carrera: se fue de vista | 5 |
| Acecho: se fue de vista | 4 |
| Carrera: sin fuelle | 1 |

Doscientos cincuenta y siete lances fallados para cincuenta y cuatro piezas: se
falla cuatro de cada cinco veces que se tira, que es lo que dice `Hunting.gd`
desde mucho antes de esto —«cazar es fallar»— y ahora se cumple donde se ve en
vez de dentro de una multiplicación. Lo que sí se cobra es la mayoría de las
CACERÍAS, y también es lo suyo: una cuadrilla que ya tiene la pieza delante
insiste, y la unidad de cuenta de una jornada de caza es la cacería, no el
tiro.

**La cifra que hay que seguir mirando:** un recolector saca entre quince y
diecisiete raciones por jornada-persona en ese mismo sitio. La caza sigue por
debajo, aunque ya no de manera absurda —antes de todo esto la caza mayor daba
**0,09**, medido, y el propio `Hunting.gd` reconocía que eso contradecía el
encargo—. El equilibrio entre carne y avellana es una decisión de balanceo que
queda abierta; lo que se ha cerrado es que la caza sea una conducta y no una
tabla.

### 7.2 Cinco fallos que sólo salieron jugando

Ninguno se descubrió con las pruebas: los cinco aparecieron corriendo la
partida de verdad, con toda la máquina de fases funcionando y las setecientas
pruebas en verde. Quedan escritos porque comparten raíz —un número o una regla
puestos a ojo dentro de un sistema con reloj y con terreno— y volverá a pasar.

**1. El rastreo estaba dentro del acecho.** Hasta cumplir las horas de rastreo
no se podía llegar a tiro por muy encima que se estuviera de la pieza. En una
jornada de diez horas, un rastreo de siete no deja acecho: deja un cronómetro.

    acecho      441.119 ticks
    lance           185
    cobradas          3 piezas en cuatro meses

Puesto delante —primero se corta el rastro, luego se acecha— el acecho vuelve a
ser lo que es: corto.

**2. Se acechaba lo más cercano.** `quarry_near` devolvía la pieza más próxima,
y la pieza menuda es la más numerosa del valle: siempre hay un pato más cerca
que un ciervo. Resultado: once piezas cobradas y **las once ánades**, con una
cuadrilla de caza mayor. Ahora se puntúa lo que vale la pieza contra lo que
cuesta llegar a ella, y de golpe aparecen los caballos y los uros.

**3. El paso de acecho no ganaba terreno.** Un tercio del paso normal parecía
razonable hasta que se cruzó con que la pieza NO ESTÁ QUIETA: un ciervo pasta a
6,5 unidades por segundo y el cazador se le acercaba a menos de una unidad por
segundo neta. Los últimos noventa metros no se cerraban nunca y el acecho moría
por reloj. Con 0,55 gana terreno al doble de lo que la pieza deriva y sigue
leyéndose medio paso más lento que quien vuelve a casa.

**4. Los cazadores se metían en el río.** Éste no salió contando sino MIRANDO,
que es la única forma en que podía salir: `CaceriaVistaProbe` fotografió a un
cazador plantado en mitad del cauce, con su chapa encima, siguiendo a un ánade.

La cacería va en línea recta detrás del animal —una persecución no rodea el
canchal— y esa línea se salta la rejilla de navegación, que mide celdas de
cuarenta metros y da por transitable un río más estrecho que eso. Andando por
rutas de la rejilla da igual, porque se va de centro a centro y el trazado ya
rodea; derecho, no.

Ahora se tantea el suelo cada doce metros entre el cazador y su pieza: si hay
cauce de por medio se le pide camino a la rejilla —una vez, no en cada tick— y
la pieza que se echa al agua se da por perdida, que es lo que pasa. Y no se
levanta cacería contra nada que esté en el agua: del ánade se encarga la red de
aves en el bebedero.

**Y arregló la caza entera de propina.** Los cazadores se pasaban la partida
detrás de patos irrealizables:

| | antes | después |
|---|---|---|
| Cacerías levantadas | 170 | 85 |
| Cobradas | 46 (27 %) | 54 (64 %) |
| «Se enfrió el rastro» | 109 | 21 |
| Raciones por jornada-persona, caza mayor | 2,73 | 7,33 |

La mitad de las cacerías eran ánades que nunca se iban a cobrar, y cada una se
llevaba un rastreo entero.

Y dos que no eran de la caza:

**5. La ronda de nasas se comía la jornada del pescador.** `_creel_round` se
llama en cada tick, así que quien tenía una nasa sin cebo se pasaba el día
cebándola. La pesca de orilla cayó de 7,68 raciones por jornada-persona a 3,22;
con la ronda limitada a una al día vuelve a 7,74.

**6. Quien levantaba una nasa no la volvía a cebar.** También salió mirando: una
nasa en la orilla con el rótulo «sin cebo» encima y cuarenta caracoles en el
abrigo. Levantar y cebar eran dos visitas distintas, y con una nasa dando pieza
todos los días el pescador iba siempre a ésa mientras las demás se quedaban sin
cebo para siempre. Es una sola visita —se levanta el cesto, se saca el pez, se
le echa cebo y se cala otra vez—, que además es lo que se hace.

### 7.3 El secadero salva lo que la caza trae

La misma partida, con hogar y secadero levantados y dos personas al hogar,
contra la misma sin ellos:

| | sin secadero | con secadero |
|---|---|---|
| Raciones ahumadas en 120 jornadas | 0 | 278 |
| Raciones perdidas por podredumbre | 833 | 461 |

Que sigan perdiéndose cuatrocientas sesenta y una con el secadero puesto no es
un fallo del secadero: es que en esa partida **el hogar se apagó**, y sin brasas
no se ahúma. Es exactamente lo que el sistema tiene que decir, y ahora lo dice
—en el parte diario, con nombre y motivo— en vez de dejar que el jugador vea un
montón que no crece.

Ochocientas treinta y tres raciones tiradas en cuatro meses es lo que cuesta
cazar bien y no tener dónde guardarlo, y hasta ahora eso pasaba **en silencio**.
Es exactamente el agujero que el parte diario vino a tapar.

---

## Fuera de alcance

- **La caza por acoso a la vista del jugador con animación propia.** Los
  cazadores acechan, corren y rematan, pero lo hacen con el ciclo de marcha que
  ya tienen: no hay pose de agachado ni de lanzar. Se nota en el PASO —un
  tercio del normal al acechar— y no en la silueta.
- **El lobo como carroñero de lo que queda en el monte.** Lo que no se acarrea
  se pierde a los tres días y se cuenta que se ha perdido, pero no viene un lobo
  a llevárselo delante de nadie.
- **La composición de la escena pintada.** Una pared es un relato con fecha, no
  un dibujo distinto por especie.
