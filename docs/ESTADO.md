# Estado de la slice del Paleolítico

Qué hace hoy el juego, qué le falta para ser jugable y qué cambiaría. Todo lo
que se afirma aquí está medido con sondas del repositorio, y se dice con cuál.

Contrasta con [archivo/SLICE_PALEOLITICO.md](archivo/SLICE_PALEOLITICO.md), que es lo que el
proyecto dijo que iba a construir.

---

## Dónde mirar

Todo lo que se afirma aquí está medido con una sonda del repositorio, y se dice
con cuál.

| Si buscas… | Ve a |
|---|---|
| **El estado de la partida en una página**, con el año medido | **§1** |
| Por qué un recolector alimenta a siete y un cazador no se alimenta ni a sí mismo | §2 |
| Por qué la caza mayor no llega en un año (la cadena de prerrequisitos) | §2, «Por qué la caza da 0,27» |
| **Qué sistemas están sólidos, y con qué sonda se comprobó** | **§3** |
| Qué pide el diseño y no existe | §4 |
| **Qué haría por orden**, con lo ya hecho tachado | **§5** |
| El agotamiento de la pesca y por qué la banda no se muda | §5, «Segundo» |
| Los atascos, los tirones y lo que costó quitarlos | §5, «Cuarto: depurar» |
| Qué cambiaría de fidelidad histórica (el arco, la bellota, el perro) | §6 |
| Qué falta para poder jugarlo | §7 |

Las tareas vivas no están aquí: están en [ROADMAP.md](ROADMAP.md) «En curso».

---

## 1. Resumen en una página

**Lo que está montado es mucho y es bueno.** Hay un valle de relieve real con
hidrografía derivada, una banda de quince personas con pericia que crece y se
transmite de noche, catorce oficios con sus especialidades, un árbol de veinte
técnicas que se aprenden practicando, cacería por fases —acecho, persecución,
lance, despiece, acarreo— sobre fauna que de verdad anda por el mapa, líneas de
trampas y de nasas, meteorología, estaciones con su efecto real, y una crónica
que lo cuenta.

**Y con todo eso, no se puede perder.** Un año completo con el reparto por
defecto, medido con `scripts/tests/AnoProbe.gd`:

| día | estación | gente | despensa | días de comida | heridos | técnicas |
|---|---|---|---|---|---|---|
| 1 | Primavera | 15 | 160 | 6,3 | 0 | 1 |
| 46 | Verano | 15 | 2 380 | 93,7 | 0 | 3 |
| 91 | Otoño | 15 | 2 927 | 115,2 | 0 | 3 |
| 136 | Invierno | 15 | 3 067 | **120,7** | 0 | 5 |

La despensa sube de 6 a 120 días de comida y no baja nunca. **El otoño no se
distingue del verano y el invierno no cuesta nada**, que es justo lo contrario
de lo que dice el documento de diseño: *«el otoño decide si sobrevives al
invierno»*.

Nadie se hiere en 180 días. Nadie nace, nadie muere, nadie envejece. Se
aprenden 5 técnicas de 20 en un año.

**El juego está construido. La partida no.**

> **Hecho (2026-09-11).** Ver [QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md).
> La tabla de arriba ya no describe la partida actual. Un año completo de
> 180 jornadas, misma banda de quince y reparto por defecto, corrido esta
> vez hasta el cierre (`TironAnualProbe.gd`, semilla 123):
>
> | día | estación | gente | despensa | leña |
> |---|---|---|---|---|
> | 1 | Primavera | 15 | 84 | 24 |
> | 46 | Verano | 15 | **502** (pico) | **105** (pico) |
> | 86 | Otoño | **8** | 37 | 33 |
> | 136 | Invierno | 8 | 555 | 32 |
> | **180** | **Invierno (cierre)** | **8** | 113 | **5** |
>
> El día 86, con la despensa en cero varios días seguidos, mueren de hambre
> Anda, Beru, Caro, Duna, Eiga, Fusto y Gala — los cinco niños y los dos
> ancianos de la banda, ids 0 a 6 de `Inhabitant.create_band`. Los ocho
> adultos pasan la misma hambruna y sobreviven. Del pico de verano al cierre
> del invierno la leña cae un 95 %. Quince al empezar, ocho al terminar, y
> la crónica dice por qué: **ya se puede perder.**

---

## 2. El hallazgo central: la caza está cerrada con llave

**Aviso sobre las cifras anteriores.** La versión previa de esta sección daba
una tabla de «lo que produjo la banda en 45 jornadas» que estaba mal:
`produced_days` es una **ventana rodante de 30 días** (`CONSUMO_DIAS`), y
`AnoProbe` la sumaba al final creyendo que era la partida entera y luego dividía
entre 180. Además el divisor contaba a quien tenía el oficio **al final**, no
las jornadas-persona trabajadas. Las dos sondas están arregladas —se apunta cada
jornada al cerrarse— y lo que sigue sale de la contabilidad nueva.

Un año entero, 4 recolectores · 3 cazadores · 2 pescadores y el resto repartido
entre hogar y taller (`BandaProbe`):

| oficio | jornadas-persona | raciones | % | por persona y día |
|---|---|---|---|---|
| **Recolección** | 716 | **10 232** | 93 % | **14,29** |
| Ribera | 358 | 639 | 6 % | 1,79 |
| **Caza** | 537 | **147** | 1 % | **0,27** |

Lo que entró, por material: fruto seco 6 306 raciones, raíz 2 066, bellota 741,
pescado 639, baya 399, grasa 236, miel 204, caracol 186, **carne 147**, huevo 68,
seta 27. Por estación: primavera 2 231, verano 3 656, **otoño 4 397, invierno
735**.

**Un recolector alimenta a siete personas; un cazador no se alimenta ni a sí
mismo.** Eso sigue siendo la partida.

### Por qué la caza da 0,27

No es calibración. Es una **cadena de prerrequisitos**:

```
Tech.AZAGAYA → needs Tech.HOJA → needs Tech.NUCLEO → needs Tech.LASCA
```

`AZAGAYA` se practica cazando (140 jornadas) pero cuelga de `HOJA`, que se
practica en **materia prima** (110 jornadas). En el año medido se aprendieron
Lazo, Cepo, Red de aves, Foso y Núcleo preparado: **nunca llegó la talla
laminar, así que nunca llegó la azagaya, así que no hubo caza mayor en todo el
año**. Los tres cazadores vivieron de trampas y acabaron con dos azagayas de un
utillaje que ni siquiera sabían diseñar.

Una banda con uno o dos en el taller no llega a la caza mayor en un año de
partida. Ése es el nudo, y está antes de cualquier número de rendimiento.

### Y el otro hallazgo: se tira más de lo que se come

La banda produjo **11 018 raciones y se comió 4 572**. La despensa se queda
clavada en 937 durante otoño e invierno temprano porque **no cabe más**: con el
tope por recipientes (ver §5.11), más de la mitad del trabajo de los recolectores
se pierde en la puerta. El mecanismo limita como debe; lo que está descalibrado
es la recolección, que produce el doble de lo que la banda puede comer *y*
guardar.

Los cestos son la mitad de esa cifra: **7,53 raciones/día sin taller, 14,29 con
seis cestos**. Es el multiplicador declarado de `Tool.Kind.CESTO`.

## 3. Lo que está construido y funciona

Para no perderlo de vista mientras se habla de lo que falta.

| sistema | estado | comprobado con |
|---|---|---|
| Relieve real (IGN 5 m) y region de Cantabria | sólido | `RejillaProbe`, `DatosProbe` |
| Hidrografía y vadeo | sólido | `TestHydrography`, `TestFording` |
| Trazado de caminos y marcha por carriles | sólido | `MarchaProbe`, `TestWayfinder` |
| Pericia que crece practicando y se transmite de noche | sólido | `TestTeaching` |
| Cacería por fases sobre fauna viva | sólido, mal calibrado | `CaceriaProbe`, `DespieceProbe` |
| Trampas y nasas que cobran solas | sólido | `TestFishing`, `CaceriaProbe` |
| Estaciones con efecto real | sólido | `TestSubsistence` |
| Meteorología | sólido | `TestWeather` |
| Árbol de técnicas por práctica | sólido | `ArbolProbe` |
| Utillaje que se gasta y se rompe | sólido | `TestToolkit` |
| Crónica y momentos | sólido | `TestChronicle`, `MomentoProbe` |
| Parajes con nombre y conocimiento del territorio | sólido | `TestParajes` |

887 pruebas y 6 163 comprobaciones en verde (2026-09-12).

---

## 4. Lo que el diseño pide y NO existe

Comprobado por búsqueda en todo el código: **cero coincidencias** para cada uno.

| pedido en SLICE_PALEOLITICO | estado |
|---|---|
| **El conchero crece** y modifica el terreno | **hecho** — `Desechos` + `Conchero` |
| **Vestido** como necesidad (piel curtida) | no existe |
| **Plazas de cueva** (cuánta gente cabe en el abrigo) | no existe |
| **Sílex importado / intercambio** | no existe |
| Población que cambia con el año | **hecho** — nacimientos, muertes por hambre/frío/vejez/percance, y la edad avanza. Ver [QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md) |
| Saber tácito que **decae** | sólo se transmite, no decae |

El criterio de aceptación número 1 del documento —*«un año pasa y la
población cambia según lo que se haya conseguido»*— ya no falla: medido en
§1, quince al empezar y ocho al terminar, con la crónica contando por qué.

---

## 5. Qué haría, por orden

### ~~Primero: que se pueda perder~~ Hecho

Ver [QUE_SE_PUEDA_PERDER.md](archivo/QUE_SE_PUEDA_PERDER.md) para la spec
completa, sus 13 tareas y sus criterios de aceptación medidos uno a uno.

~~1. **Hambre con consecuencia.**~~ **Hecho.** Enferma antes de morir
   (`Inhabitant.hunger_sick_days`), y muere si la privación sigue. Empieza
   por los viejos y los críos: en la corrida medida en §1, los cinco niños y
   los dos ancianos mueren de hambre el mismo día y los ocho adultos
   sobreviven a la misma hambruna, tal como pedía este punto.
~~2. **Invierno con dientes.**~~ **Hecho, y ya estaba medio resuelto.** La
   reserva se consume de verdad: leña y comida caen sin parar durante todo
   el invierno (ver la tabla de §1). La recolección de invierno y el coste
   de leña ya estaban calibrados en el árbol; lo que faltaba era medirlo, y
   además un vector de frío directo (`Inhabitant.cold`, antes declarado y
   nunca alimentado) que enferma y mata sin que medie el hambre.
~~3. **Nacimientos y muertes.**~~ **Hecho.** Un nacimiento si el año cierra
   con reserva sobrada y sin rachas largas de hambre severa, y una mujer en
   edad fértil. Muerte por vejez, sola, sin decisión del jugador. Y un
   percance grave (una caída) puede matar, pocas veces — `Mishap.gd` pasa de
   «nada de esto mata a nadie» a «casi nada».

### Segundo: que la carne importe

Ver [SECADERO_Y_RIO.md](archivo/SECADERO_Y_RIO.md) para la spec de los puntos 5
y 6. El punto 4 se revisó al escribirla y se dejó fuera: la estacionalidad y
el agotamiento del avellanar ya están en el código: lo único que queda de él
es un número de kcal por puñado, que es balanceo, no mecánica.

4. **Reequilibrar recolección contra caza.** No subiendo la caza —ya se
   calibró— sino **bajando la avellana**: menos kcal por puñado, o —mejor—
   haciéndola *estacional de verdad* (el fruto seco es de otoño, no de todo el
   año) y con agotamiento del avellanar. Que la despensa vegetal sea el suelo y
   no el techo.
5. **El otoño como pico.** La berrea ya multiplica ×1,70 la caza. Hace falta
   que además sea **la única ventana** en la que se puede acumular carne seca
   para el invierno, y que el secadero sea el cuello de botella.
6. **La pesca se agota en un mes y nadie se muda.** Medido con `ParajesProbe`,
   dos pescadores y un año: el tajo de ribera baja al 75 % en **8 jornadas**, al
   50 % en 15, al 25 % en 24 y al **1 % en 32**, y ahí se queda el resto del año
   —sube al 3 % y no pasa de ahí—. Eso explica por sí solo que la ribera dé 1,79
   raciones por persona y día en un año cuando en las diez primeras jornadas
   daba 13,26: no está mal calibrada, está **esquilmada**.

   Y lo que lo convierte en un callejón sin salida: **el resto del río está al
   93,9 %**. Hay dónde pescar; la banda no va. `_rank_known_spots` sólo ofrece
   celdas con familiaridad ≥ 0,35, o sea **sitios ya conocidos**, y en un año
   con nadie en exploración la banda descubre **4 parajes en total**. El
   agotamiento sin alternativas no es una decisión, es un tope disfrazado.

   La recolección, en cambio, está bien: baja hasta el 63 % en otoño y se
   recupera al 85 %. Es el único recurso que hace lo que tiene que hacer.

   Dos apuntes del mismo sitio:
   - **`ResourceField.deplete_at` no lo llama nadie del juego**, sólo dos
     pruebas. Lo que gasta de verdad es `take_from_cell`, proporcional a lo
     recogido. Es código muerto que además documenta un modelo que no está en
     uso.
   - **La curva de reposición no deja volver de casi cero.** A 1 % de carga
     crece un 0,18 % de la capacidad al día: de 1 % a 50 % son unas 275
     jornadas **si se le deja en paz**, y no se le deja.

### Tercero: lo que el diseño pidió y falta

Ver [ABRIGO_Y_TRUEQUE.md](archivo/ABRIGO_Y_TRUEQUE.md) para la spec de los
puntos 7, 8 y 10. El punto 9 se revisó al escribirla y se dejó fuera: el
conchero ya está hecho —ver §4 más arriba—, así que esta entrada quedaba
duplicada.

7. **Vestido.** Piel curtida como necesidad de invierno. Ya existen `PIEL`,
   `PELETERIA`, `AGUJA` y la técnica de coser: falta la necesidad que las
   justifique.
8. **Plazas de abrigo.** Cuánta gente cabe en la cueva; crecer más obliga a
   levantar paravientos o a partir la banda.
10. **Sílex por intercambio.** No hay sílex bueno en Cantabria: es la mecánica
    de comercio servida por la geología real, y está a medio camino —el
    material existe, el intercambio no—.

### Cuarto: depurar

11. ~~**`food_cap` arranca en 0 = sin tope.**~~ **Hecho, y de otra manera.** Un
    tope en raciones no es una mecánica: es un número, y nada en el mundo
    impedía a la banda seguir amontonando. Ahora lo que limita es **en qué se
    guarda** —`Storehouse.capacidad_de_comida`: a granel más lo que cabe en los
    cestos y odres que haya, recalculado al cerrar cada jornada porque los
    cestos se rompen—. La banda arranca sin cestos, con unos 30 días de
    capacidad, y ampliarla cuesta jornadas de cordelería. `food_cap` sigue
    existiendo en cero y pasa a ser sólo lo que pida el jugador.
12. ~~**El atasco «llegó y el estado no se enteró»**, 2–5 por partida.~~
    **Hecho, y con él todos los demás.** Medido con `AtascoProbe` en el sitio
    56, ocho jornadas: los atascos pasan de **41 a 6** —entre 0 y 6 según la
    semilla— y los pasos que el terreno corta con camino trazado, de **5.741
    a 18**, ninguno de ellos por agua. Nadie da ya un paso sin un camino
    debajo: ese contador está en cero. Y el peor fotograma baja de 950 ms a
    242.

    No era un fallo: eran seis capas contestando distinto a la misma
    pregunta.

    Lo que había, y está en el código con su porqué:

    - **El agua, cuatro respuestas.** `Navgrid` la medía sólo en el centro de
      la celda; el A\* sólo prohibía diagonales; el recorte de la escalera
      deshacía el rodeo del vado con una recta de sesgo; y el atajo de la
      recta corta ni miraba. Ahora una sola regla, `Navgrid.paso_entre`, y una
      sola pregunta, `Marcha.agua_deja_pasar`.
    - **`_send_to` dejaba la ruta vacía por cuatro motivos** y los cinco
      sitios que la llaman veían sólo el vacío. «No me ha dado tiempo a
      mirar» se leía como «no hay camino»: seis personas la jornada 1 con «no
      hay camino hasta ningún tajo» a 211 m de casa. Ahora `Marcha.Traza`.
    - **Sin camino no se anda.** `next_waypoint` cae al destino cuando la
      ruta está vacía, así que quedarse sin ruta era salir DERECHO hacia él,
      cruzara lo que cruzara: el 22,9 % de los fotogramas andando.
    - **La regla del rodeo, dos fórmulas** —`alcanzable_de_verdad` y
      `merece_el_camino`— encadenadas decidiendo sobre lo mismo.
    - **El coste de andar un metro, dos modelos**, y el comentario de la
      rejilla jurando que era uno. Ahora `Traversal.pace_fraction`.
    - **La estación, contada de dos maneras**: la rejilla con el caudal de
      destino y el andador con el del paisaje, que va interpolado; y la
      rejilla clasificando el suelo siempre en seco.
    - **El esquive de orilla sin tope**, que como mueve a la persona nunca
      dejaba saltar el replanteo: horas barriendo la ribera.
    - **La misma pregunta desde dos sitios.** «¿Merece la pena ir a este
      paraje?» se hacía desde el abrigo en una capa y desde la persona en la
      siguiente. Dos orígenes, dos respuestas, y la de la persona no se podía
      guardar —se mueve—, así que era una búsqueda entera por candidato y sin
      pasar por ningún presupuesto: treinta y dos A\* en el cuadro del
      reparto de la mañana.

    - **El repaso de rezagados era un barrido, no una cola.** Los sitios que
      se ganan un nombre salen de uno en uno —para que el jugador no vea
      siete chapas de golpe—, así que siempre hay cola. Pero la lista de los
      que esperaban se calculaba entera, se usaba para sacar uno y **se
      tiraba**; para encontrar a los demás había que volver a barrer las
      4.096 celdas del campo a cada hora de luz. Se troceó por oficios y
      franjas para que el tirón no se notara, que es esconder el coste, no
      quitarlo —y de paso metía hasta día y medio de espera antes de que a un
      sitio le tocara su casilla—.

      Ahora la cola se guarda ([Parajes.cola]) y sacar al siguiente no cuesta
      barrido ninguno. El campo se repasa **sólo cuando hay motivo**: cuando
      cambia por dónde se pasa —la estación, la barca— porque eso vuelve
      candidato a un sitio sin que nadie haya ido a mirarlo. Y lo que rebrota
      por encima del umbral se apunta donde se sabe, en el propio rebrote.

      Medido: el peor fotograma baja de 950 ms a **156**, los tirones de más
      de 100 ms de 24 a 12 en tres jornadas, y el repaso en sí de 852 ms a
      111. Y descubre **más**: 11 parajes en ocho jornadas con la cola vacía,
      frente a los 7-8 de antes.

    - **La pregunta cara que no lo era.** «¿Se llega de verdad desde casa?»
      —no «¿hay camino?», sino «¿sin dar la vuelta al valle?»— se contestaba
      con una búsqueda A\* **por pregunta**, y se hace por cada paraje
      candidato, cada vez que alguien decide su salida, y dentro de barridos.
      Encima de eso había tres parches: memoria por celda, un presupuesto por
      cuadro, y aplazar la respuesta. Y aun así se colaban: medido en el panel
      de F3, **79 búsquedas en un fotograma de 2.541 ms**.

      No hacía falta ninguna de las tres. **El origen es siempre el mismo —el
      abrigo—**, y para un origen fijo un solo Dijkstra da los metros exactos
      hasta cada celda del mapa por lo que costaba UNA de aquellas búsquedas.
      Se rehace al cambiar la rejilla, o sea una vez por estación. Ver
      [Wayfinder.metros_desde].

    - **El arranque del camino no lo comprobaba nadie.** Una ruta es una cadena
      de CENTROS de celda, y quien anda arranca donde esté —hasta 28 m en
      diagonal—. La recta de ahí al primer hito no está vetada por nadie, y
      eso vale para cualquier camino, no sólo para los guardados. Se amarra
      metiendo el centro de la celda propia como primer hito cuando esa recta
      no está limpia: ni descarta el camino ni busca otro.

    - **El horno se había puesto un presupuesto que no podía cumplir.** Cuatro
      milisegundos por cuadro, y el trozo más pequeño que sabía cortar era una
      FILA entera: entre nueve y diecisiete. Un presupuesto más fino que tu
      grano no es un presupuesto. Ahora corta a mitad de fila.

    Y **se quitaron los topes de distancia** de expedición y ascensión —un
    radio de 2.600 m con mínimo de plantilla, y otro de 2.200 para buscar
    cumbres—. No es así como se limita a quien duerme fuera: lo que lo limita
    es la comida que puede llevar encima, y de eso ya decide
    [Despensa._provision].

    Con todo junto: **un tirón cada 2,08 s** (era uno cada 0,7) y el peor
    fotograma en **143 ms** (eran 2.541). El A\* desaparece del desglose.

    - **Y el panel decía «SIN EXPLICAR»** para el 84 % de un tirón de 917 ms.
      Todos los `_process` del juego están marcados, así que lo que falta es
      siempre el motor. Ahora se llaman **EL JUEGO** y **EL MOTOR**, y el
      segundo lleva al lado los nodos, los objetos y las llamadas de dibujo
      del cuadro: un tirón que crece con los días se lee de un vistazo.

    Y con eso se encontraron los dos que **empeoraban solos con los días**:

    - **`TrailView` congelaba la jornada** al abrir el panel de rastros. La
      ventana de diez días —[Inhabitant.RASTRO_DIAS]— dejaba de deslizarse y
      pasaba a ser «todo lo posterior a cuando abriste el panel», con un
      repintado cuatro veces por segundo que creaba y tiraba una malla por
      salida. Cada jornada metía más y no salía ninguna.

    - **`_nearest_prey` recorría los ochocientos animales preguntándole a cada
      uno su dieta**, y preguntarla son dos diccionarios y un texto. Se
      mantiene la lista de presas igual que ya se mantenía la de carnívoros:
      misma respuesta, sin preguntar.

    Medido con `PicoProbe` sobre **doce jornadas**: los tirones de más de
    100 ms pasan de **177 a 31** —de uno cada 0,40 s a uno cada 2,28— y en el
    mismo tiempo de reloj caben un 42 % más de fotogramas.

    Queda **`Cumbres`**, que para elegir monte pregunta sólo si hay camino y
    no si merece andarse. Con los topes de distancia fuera puede elegir una
    cima al otro lado del valle; si eso molesta, la regla ya existe con el
    factor por parámetro en `Marcha.rodeo_aceptable`.

    Lo que queda de los tirones —medido sobre el año entero, no sobre doce
    jornadas— y la regla para quitarlos sin tocar la partida: ver
    [LO_MISMO_MAS_DEPRISA.md](archivo/LO_MISMO_MAS_DEPRISA.md). En marcha, con
    el paso 0 cerrado —la misma semilla da la misma partida, año entero— y
    tres optimizaciones dentro: los tirones graves del año pasan de **819 a
    329** sin que cambie una sola cifra de la partida.


---

## 6. Fidelidad histórica: qué cambiaría

Lo que hay está bien documentado y con fuentes. Tres cosas que retocaría:

**El arco no debería estar.** `TechTree.Tech.ARCO` está en el árbol y el propio
`archivo/SLICE_PALEOLITICO.md` lo pone en la lista de lo que la época **no** conoce
(*«Arco · cerámica · agricultura…»*). El arco es Mesolítico. Hoy es además el
peldaño que más sube la caza en la escalera. O se quita, o se marca
explícitamente como el salto que abre la época siguiente.

~~**La bellota necesita su proceso.**~~ **Hecho.** La bellota cruda pasa a 0 kcal
y aparece `BELLOTA_DULCE`; en medio, el `LAVADERO`, con tres jornadas de remojo
y un tope de 30 puñados que es el cuello de botella del otoño. Ver
[archivo/PERRO_Y_BELLOTA.md](archivo/PERRO_Y_BELLOTA.md) §2.

~~**Falta el perro.**~~ **Hecho, y no como técnica.** No es un peldaño del árbol:
es una relación con la manada que arranca en el montón de desechos —la hipótesis
comensal— y va por cinco decisiones hasta el perro o hasta la manada en contra.
Medido: perro en la jornada 161 eligiendo lo amable, manada hostil en la 12
eligiendo matar. Ver [archivo/PERRO_Y_BELLOTA.md](archivo/PERRO_Y_BELLOTA.md) §1.

---

## 7. Qué falta para poder jugarlo

Ver [QUE_FALTA_PARA_JUGARLO.md](archivo/QUE_FALTA_PARA_JUGARLO.md) para la spec
completa de los puntos 1-4, sus 10 tareas y sus criterios de aceptación
medidos uno a uno.

~~1. **Un objetivo.**~~ **Hecho.** El objetivo es doble y fijo: sobrevivir el
   año Y dejar la cueva pintada — no una elección entre alternativas. Medido
   en la corrida compartida de 180 jornadas con reparto por defecto
   (`TironAnualProbe.gd`, semilla 123): `desenlace: NINGUNO (0 relatos
   pintados de 3 para ganar)`. La banda cerró el año viva y no ganó, porque
   no pintó nada — confirma en partida real que sobrevivir solo no basta.
   Con un solo dato no se sabe si `CUEVA_PINTADA_MINIMO := 3` es alto o si
   el problema es el mismo de §2 —la banda por defecto no llega a tener
   sobrante para pintar—; queda anotado, sin tocar la constante a ciegas.
~~2. **Un modo de perder**~~ (§5.1). **Hecho, y ahora además visible.** Un
   indicador de riesgo permanente en la barra de arriba —proporción de la
   banda enferma de frío o de hambre, todo el año y no sólo en la ventana de
   otoño— y un momento de cierre con la causa cuando la banda se extingue,
   en vez de una entrada suelta en la crónica que hay que ir a buscar.
~~3. **Que la primera hora enseñe.**~~ **Hecho.** Un único momento al fundar
   el asentamiento dice el objetivo doble, que se puede perder, y la primera
   decisión —repartir los oficios de la banda—. Confirmado que llega de
   verdad a la interfaz en una escena real, antes de cualquier acción del
   jugador, no sólo en prueba unitaria.
4. **Ritmo.** Sigue sin resolver, pero ya no es una sospecha: medido con
   `RitmoProbe.gd`, la primavera con el reparto por defecto pasa **cero
   momentos en cuarenta y cinco jornadas** —un único hueco de 44 días sin
   nada que decidir—. Verano, otoño e invierno quedan sin medir: una corrida
   de un año a `time_scale = 5` cuesta más de una hora, y el día que tocaba
   medirlo había cuatro agentes con sondas distintas compitiendo por la
   misma máquina. La dirección elegida es llenar la estación de decisiones,
   no acortarla; construir esas decisiones es trabajo aparte, no de esta
   spec.
5. **La interfaz** (ver [INTERFAZ.md](INTERFAZ.md)).
