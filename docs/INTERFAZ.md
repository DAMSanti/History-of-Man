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

**El panel de técnicas no dice por qué una técnica está parada.** Es la queja
literal del jugador —«hay varias técnicas que no se desbloquean, no sé por
qué»— y tiene tres causas distintas que hoy se ven igual: falta el
prerrequisito, faltan jornadas del oficio, o **falta material**, que es la que
nadie adivina porque `TechTree._ir_pagando` **detiene el progreso** cuando la
despensa no da para seguir practicando. Decir «parada: faltan 6 de asta» vale
para las veinte técnicas del árbol, no sólo para la azagaya. Va por `/depurar`
junto con el resto de los fallos, pero la decisión de diseño —el panel dice la
causa, no sólo el porcentaje— se anota aquí.

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
> - **Sólo la de material lleva marca**, un doble filete de hematites. Parada es
>   la que no sube aunque se practique; la de las jornadas va despacio, y
>   marcarlas todas sería no marcar ninguna. Son dos decisiones distintas: traer
>   asta, o poner gente en el taller.

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
