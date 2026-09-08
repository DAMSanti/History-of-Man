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
