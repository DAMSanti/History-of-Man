# Estado de la slice del Paleolítico

Qué hace hoy el juego, qué le falta para ser jugable y qué cambiaría. Todo lo
que se afirma aquí está medido con sondas del repositorio, y se dice con cuál.

Contrasta con [SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md), que es lo que el
proyecto dijo que iba a construir.

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

716 pruebas y 5 171 comprobaciones en verde.

---

## 4. Lo que el diseño pide y NO existe

Comprobado por búsqueda en todo el código: **cero coincidencias** para cada uno.

| pedido en SLICE_PALEOLITICO | estado |
|---|---|
| **El conchero crece** y modifica el terreno | **hecho** — `Desechos` + `Conchero` |
| **Vestido** como necesidad (piel curtida) | no existe |
| **Plazas de cueva** (cuánta gente cabe en el abrigo) | no existe |
| **Sílex importado / intercambio** | no existe |
| Población que cambia con el año | no existe: ni nacimientos, ni muertes, ni edad |
| Saber tácito que **decae** | sólo se transmite, no decae |

De éstos, el que más duele es **la población**. El criterio de aceptación
número 1 del documento es *«un año pasa y la población cambia según lo que se
haya conseguido»*. Hoy la población es una constante: 15 al empezar, 15 al
terminar, pase lo que pase. Sin eso no hay consecuencia y por tanto no hay
juego.

---

## 5. Qué haría, por orden

### Primero: que se pueda perder

Nada de lo demás importa hasta que exista un modo de fracasar.

1. **Hambre con consecuencia.** Hoy el hambre media llega al 40 % y no pasa
   nada. Debe: bajar el rendimiento (ya lo hace vía `effectiveness`), luego
   enfermar, y por fin matar. Empezar por los viejos y los críos, que es como
   fue.
2. **Invierno con dientes.** Que la recolección caiga a casi cero en invierno
   —hoy el factor estacional de recolección no lo hace lo bastante— y que el
   frío cueste leña y calorías. La reserva tiene que consumirse.
3. **Nacimientos y muertes.** Un parto por año bueno; muertes por hambre, por
   percance grave y por vejez. Es lo que convierte un año en una decisión.

### Segundo: que la carne importe

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

7. **Vestido.** Piel curtida como necesidad de invierno. Ya existen `PIEL`,
   `PELETERIA`, `AGUJA` y la técnica de coser: falta la necesidad que las
   justifique.
8. **Plazas de abrigo.** Cuánta gente cabe en la cueva; crecer más obliga a
   levantar paravientos o a partir la banda.
9. **El conchero.** El montón de conchas que crece y se ve. Es la prueba
   visible de que los subproductos son reales.
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
12. **El atasco «llegó y el estado no se enteró»**, 2–5 por partida. Es viejo y
    sigue ahí.
13. **20–30 % de salidas vuelven de vacío** en recolección. Puede ser correcto
    —cazar es no encontrar— pero está sin explicar.
14. **`_start_settlement` y compañía** ya están partidas; quedan funciones de
    82–97 líneas en `RegionMap`, que es el único fichero grande que no se ha
    mirado nunca.

---

## 6. Fidelidad histórica: qué cambiaría

Lo que hay está bien documentado y con fuentes. Tres cosas que retocaría:

**El arco no debería estar.** `TechTree.Tech.ARCO` está en el árbol y el propio
`SLICE_PALEOLITICO.md` lo pone en la lista de lo que la época **no** conoce
(*«Arco · cerámica · agricultura…»*). El arco es Mesolítico. Hoy es además el
peldaño que más sube la caza en la escalera. O se quita, o se marca
explícitamente como el salto que abre la época siguiente.

~~**La bellota necesita su proceso.**~~ **Hecho.** La bellota cruda pasa a 0 kcal
y aparece `BELLOTA_DULCE`; en medio, el `LAVADERO`, con tres jornadas de remojo
y un tope de 30 puñados que es el cuello de botella del otoño. Ver
[PERRO_Y_BELLOTA.md](PERRO_Y_BELLOTA.md) §2.

~~**Falta el perro.**~~ **Hecho, y no como técnica.** No es un peldaño del árbol:
es una relación con la manada que arranca en el montón de desechos —la hipótesis
comensal— y va por cinco decisiones hasta el perro o hasta la manada en contra.
Medido: perro en la jornada 161 eligiendo lo amable, manada hostil en la 12
eligiendo matar. Ver [PERRO_Y_BELLOTA.md](PERRO_Y_BELLOTA.md) §1.

---

## 7. Qué falta para poder jugarlo

En orden de lo que más bloquea:

1. **Un objetivo.** Hoy la partida no pide nada. Sobrevivir un año, llegar a X
   personas, pintar la cueva: cualquiera vale, pero tiene que haber uno.
2. **Un modo de perder** (§5.1).
3. **Que la primera hora enseñe.** La banda arranca con la tabla de trabajos en
   blanco y sin tutorial: el jugador ve quince personas ociosas y ninguna
   indicación. Es una decisión defendible —la primera decisión es suya— pero
   necesita al menos un momento inicial que lo diga.
4. **Ritmo.** 45 días por estación a velocidad normal es mucho reloj para lo
   que ocurre. O se acelera el año, o se llena de decisiones.
5. **La interfaz** (ver [INTERFAZ.md](INTERFAZ.md)).
