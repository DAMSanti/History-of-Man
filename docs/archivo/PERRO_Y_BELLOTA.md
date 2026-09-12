> **ARCHIVADO (2026-09-12).** Este documento ya no se edita. La documentación
> se reorganizó para que lo único específico fueran las fichas de época, y
> lo vivo está en **[SISTEMAS.md](../SISTEMAS.md) §14–§15** (los desechos y el lobo, y la bellota).
>
> Se conserva entero porque guarda **lo que no cabe en un documento permanente**:
> qué se probó, qué salió, qué premisa se cayó a mitad y por qué se decidió lo
> que se decidió. Nada de lo que sigue se ha tocado — incluidas las cosas que
> hoy ya no son verdad, que se reconocen porque el documento permanente dice
> otra cosa y **gana el permanente**.

---

# El perro y la bellota

Dos mecánicas del Paleolítico superior, **ya implementadas**. Este documento
decía cómo iban a hacerse; ahora dice cómo se hicieron y en qué se desvió lo
construido de lo diseñado, que es la parte que sirve.

Las dos comparten una virtud: son históricas **y además arreglan algo que está
medido**. Añadir contenido que no arregla nada es lo que engorda un juego sin
mejorarlo.

---

## 1. El perro

`scripts/sim/ElLobo.gd` · pruebas en `TestLobo.gd` · medido con `PerroProbe.gd`

### Lo que cambió respecto al diseño

El diseño decía **una técnica del árbol**, `Tech.PERRO`, con 120 jornadas de
práctica. Eso está mal por dos motivos y se descartó:

1. **Un lobo no se domestica investigando.** Una técnica se aprende acumulando
   jornadas; una relación se construye o se rompe, y se puede perder. Meterlo en
   el árbol lo habría convertido en otra casilla que se llena sola.
2. **El jugador pidió decisiones**, no un contador. «Una serie de tomas de
   decisión a lo largo de la partida que lo convierten en un amigo o en un
   enemigo temible.» Un peldaño del árbol no tiene dos finales.

Así que es un sistema propio con **cinco pasos**, cada uno un `Moment` con
opciones de verdad y el reloj parado hasta que se elige.

### Por dónde empieza: el montón de basura

La hipótesis que hoy tiene más apoyo no es la del cazador que sale a buscar un
cachorro: es la **comensal**. Los lobos menos miedosos se acercaron solos a los
desperdicios de los campamentos humanos, comieron mejor que los demás, criaron
más, y la selección hizo el resto. La domesticación no la empezó la gente: la
empezaron los lobos.

Por eso arranca en el **conchero** (§2). Sin montón no hay merodeo y sin merodeo
no hay camino, y eso encadena dos sistemas que si no serían dos adornos sueltos:
**la basura que la banda genera es lo que trae al animal que va a cambiarle la
caza**.

Atestiguado en Europa hacia **15 000 – 14 000 a.C.** (Bonn-Oberkassel, el
enterramiento de perro más antiguo aceptado), o sea **dentro** del Magdaleniense
que juega la slice. No hay que estirar nada.

### Los cinco pasos

| paso | qué pasa | qué se decide |
|---|---|---|
| **Merodean** | vienen al montón de noche | dejarlos comer · espantarlos · matar al que se acerque |
| **Uno se queda** | uno no huye cuando alguien sale | echarle una tajada · dejarlo estar · cobrárselo |
| **La lobera** | se da con la camada | coger un cachorro · dejarla en paz |
| **El cachorro** | 120 jornadas de cría, y come | — |
| **El perro** | caza con la cuadrilla | se pinta en la pared |

El `trato` va de −100 a +100. Lo suben las decisiones amables y, sobre todo,
**cada noche que vienen y no pasa nada**: la relación no la hacen los gestos, la
hace el tiempo.

### El otro final

Por debajo de −45, o con **dos lobos muertos**, la manada está en contra: el
riesgo de una noche fuera se multiplica por 1,9. Cada muerto cuesta **1,8 veces
el anterior**, y hace falta casi un año de partida por lobo para que se olvide.

No es un castigo por jugar mal —matar al lobo que te ronda la despensa es
razonable—: es la otra rama.

### Lo que cambia cuando llega

Ataca el problema **medido**: de quince cacerías levantadas sólo se cobran
cuatro, y el 73 % se pierde en el acecho.

| efecto | dónde | cuánto |
|---|---|---|
| Corta el rastro perdido | `Caceria._stalk` | 55 % de las veces |
| Para la pieza | `Caceria._chase` | ×1,60 de fuelle |
| Guarda el vivac | `Percances` | ×0,55 de riesgo |
| **Y come** | `ElLobo._dar_de_comer` | **0,6 raciones/día** |

Esas 0,6 son 108 raciones al año, y **la caza entera dio 147** en la corrida de
un año con 3 cazadores. Por eso es una decisión y no un regalo: sale a cuenta
sólo si la banda caza de verdad.

### Los dos fallos que encontró la sonda

Los dos son de los que no se ven leyendo el código, y por eso están escritos:

1. **El camino amable era imposible de andar.** Las dos decisiones previas a la
   camada sumaban 24 de trato y la camada pedía 55. Faltaban 31 que no salían de
   ninguna parte. Se arregló con `POR_NOCHE`.
2. **El camino del enemigo era inalcanzable.** Los momentos se preguntaban una
   sola vez, así que en toda la partida había **dos** ocasiones de matar un lobo,
   y con dos el trato se recuperaba antes de tocar fondo: 400 jornadas matando en
   cada decisión acababan con el trato a 100. Se arregló haciendo que los
   momentos **vuelvan** —un lobo no deja de venir porque le tires una piedra,
   deja de venir esa noche— y que cada muerto cueste más que el anterior.

### Medido

```
eligiendo siempre lo amable:   HAY PERRO en la jornada 161
   merodean 6 · uno se queda 24 · cachorro 41 · perro 161
eligiendo matar:               MANADA HOSTIL en la jornada 12
   y dos años y medio de partida para volver a cero
```

---

## 2. La bellota

`Materia.BELLOTA_DULCE` · `CampProjects.LAVADERO` · `Hogar._lavar_bellota`

### Por qué hacía falta

`Materia.Kind.BELLOTA` estaba en el catálogo con 1 300 kcal y su propio
comentario decía *«necesita desamargado: agua, recipiente y tiempo»* — **y se
comía directamente**. La bellota cruda tiene tanino: es astringente, sienta mal
y en cantidad es tóxica. Comérsela sin tratar no es una simplificación, es un
error.

### Cómo quedó

- **`BELLOTA` pasa a 0 kcal.** `Materia.is_food` es `kcal > 0`, así que sale
  sola de la despensa sin tocar nada más.
- **`BELLOTA_DULCE`**, 1 300 kcal y 300 días: la harina del invierno.
- **`CampProjects.Kind.LAVADERO`**: un cesto lastrado en el remanso. Dos
  jornadas, 6 de fibra y 4 de piedra. **No depende del hogar** —es agua
  corriente, no fuego—, así que es la primera obra que se puede levantar sin
  tener nada encendido.
- **Tres jornadas de remojo** y **30 puñados por lavadero**. Ese tope es el
  punto: en un otoño bueno sobra bellota sin tratar.

De los tres métodos atestiguados —agua corriente, lixiviación con ceniza,
enterrarla— se eligió el primero porque **la banda ya tiene río y ya sabe dónde
está**.

### Lo que cambia en la partida

- El otoño deja de ser «recoge y ya»: hay que decidir cuánta bellota se pone a
  lavar. Medido en un año: **712 puñados recogidos** = 24 cestadas de lavadero.
- Aparece una razón para tener el campamento cerca del agua que no es la pesca.
- La bellota pasa a ser lo que fue: comida de reserva que se prepara en otoño o
  no la tienes en enero.

---

## 3. Los desechos, que no estaban en el diseño

`scripts/sim/Desechos.gd` · `scripts/vista/Conchero.gd`

Esto no venía en este documento: lo pidió el jugador al ver la bellota. *«Supongo
que produzcan deshechos, casi como las conchas. Esos deshechos, al igual que los
concheros, cambiarán el paisaje (y las texturas).»*

Lo que se come deja lo que no se come, y eso **no desaparece**. Litros de residuo
por ración comida, material a material:

| material | litros por ración | por qué |
|---|---|---|
| Marisco | 2,40 | casi todo es concha |
| Caracol | 1,10 | concha más menuda |
| Bellota lavada | 0,45 | cascarilla y cúpula |
| Fruto seco | 0,40 | cáscara de avellana |
| Carne | 0,14 | hueso y asta que no se aprovechan |
| Pescado | 0,09 | espina |

El montón se ve a partir de **400 litros** —un año de marisqueo fuerte— y se
dibuja en tres capas que crecen juntas: un `Decal` que **tiñe el suelo**, una
loma baja que se desparrama (un conchero no es un cono) y la cáscara suelta en
`MultiMesh`. **El color sale de la dieta**: blanco de concha si la banda vivió
del marisco, pardo si vivió de la bellota.

A los cinco años, el montón dice de qué ha vivido la banda sin abrir una
ventana. Y es lo que trae a los lobos (§1).

Los concheros cantábricos —El Mazo, La Fragua, Santimamiñe— son montones de
metros de espesor hechos de una sola cosa: cáscara. Son la prueba de que la gente
estuvo comiendo ahí durante años, y a menudo lo único que queda.
