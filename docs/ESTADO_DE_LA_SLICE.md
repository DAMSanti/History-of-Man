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

## 2. El hallazgo central: la banda vive de la avellana

Lo que produjo la banda en 45 jornadas (`AnoProbe`, reparto por defecto):

| material | raciones | aguanta |
|---|---|---|
| **Fruto seco** | **2 080** | 360 días |
| Raíz | 681 | 60 días |
| Huevo | 143 | 14 días |
| Baya | 141 | 8 días |
| Caracol | 115 | 3 días |
| **Carne** | **13** | 4 días |
| **Pescado / marisco** | **0** | — |

La banda come 1 125 raciones en ese periodo. **La recolección sola trae el
triple de lo que hace falta**, y casi todo es avellana, que aguanta un año.

La caza aporta el **0,4 %**. Y no es un detalle de balance: es que el sistema
más elaborado de todo el código —la cacería por fases, con su fauna viva, sus
alcances de arma y su despiece— es irrelevante para la supervivencia. El propio
docstring de `Hunting.gd` dice *«una banda cantábrica del Magdaleniense vivía de
la carne, no de la avellana»*. El juego hace exactamente lo contrario.

Medido por persona y día (`JornadaCazadorProbe`, `CazaEscalonProbe`,
`RendimientoProbe`):

| oficio | raciones por persona y día |
|---|---|
| Recolección | ~15 |
| Caza mayor (40 jornadas, pericia crecida) | ~1,5 |
| Lo que come una persona | 2,0 |

**Un recolector alimenta a siete personas; un cazador no se alimenta ni a sí
mismo.** Esa es la partida hoy.

### Por qué pasa

Tres causas, y sólo la tercera es un error:

1. **La avellana es demasiado buena.** 1 700 kcal por puñado de 0,55 kg y 360
   días de vida. Es la mejor relación caloría/riesgo/conservación del catálogo
   y no tiene contrapartida.
2. **La recolección no falla casi nunca.** Es «la mitad callada de la dieta»
   por diseño, pero sin variabilidad no hay decisión: siempre es la respuesta
   correcta.
3. **La cacería paga el desplome de la cadena y la recolección no.** Las dos
   multiplican seis factores que dan ~0,04, pero la recolección lo compensa con
   `HARVEST_SCALE = 26` y la caza tuvo que esperar a
   `Caceria.ESCALA_DEL_RASTREO`. Aun con ella, un cazador está el **5,9 % de su
   existencia** en estado de trabajo: el resto duerme (49 %) y anda (32 %).

---

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
| **El conchero crece** y modifica el terreno | no existe |
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
6. **Pesca y marisqueo, que hoy dan cero.** En 45 jornadas con el reparto por
   defecto no entró ni un pescado. Hay que averiguar por qué antes de tocar
   nada: puede ser que el tajo de ribera quede lejos, o que el oficio no se
   asigne, o que `food_is_capped` lo cierre.

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

11. **`food_cap` arranca en 0 = sin tope.** El jugador tiene que descubrir el
    control para que la banda deje de acumular. Debería arrancar en algo
    razonable (30 días) y ser una decisión, no un descubrimiento.
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

**La bellota necesita su proceso.** Está en el catálogo con 1 300 kcal y su
comentario dice «necesita desamargado: agua, recipiente y tiempo», pero se come
directamente. El desamargado de la bellota es trabajo real y sin él la bellota
es tóxica: es una receta esperando a existir.

**Falta el perro.** El lobo está en la fauna sólo como competidor. La
domesticación del perro está atestiguada en el Paleolítico superior europeo
(~15.000 a.C.) y es exactamente el tipo de cambio que transforma la caza. Sería
la mejor técnica «de época» que se puede añadir sin salirse del Magdaleniense.

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
