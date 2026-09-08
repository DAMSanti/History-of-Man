# Dos mecánicas de época: el perro y el desamargado

Cómo implementar la domesticación del perro y el desamargado de la bellota,
encajadas en los sistemas que ya existen. Las dos son del Paleolítico superior
y las dos resuelven un problema real del juego, no sólo añaden contenido.

---

## 1. El perro

### Por qué encaja

La domesticación del lobo está atestiguada en Europa hacia **15 000 – 14 000
a.C.** (Bonn-Oberkassel, ~14 000 a.C., es el enterramiento de perro más antiguo
aceptado). Cae **dentro** del Magdaleniense cantábrico que juega la slice, así
que no hay que estirar nada.

Y resuelve el problema medido: **de quince cacerías levantadas sólo se cobran
cuatro**. El 73 % se pierde en el acecho — *«se enfrió el rastro»*, *«se fue de
vista»*. Eso es exactamente lo que un perro arregla: no mata la pieza, la
**encuentra y la para**.

### Qué toca en el código

Ya existe todo el andamiaje. `Fauna.SPECIES` tiene `"lobo"`, `TechTree` tiene
el mecanismo de aprender practicando, y `Caceria` tiene las fases donde el
perro actuaría.

**Una técnica nueva**, `Tech.PERRO`:

```gdscript
Tech.PERRO: {
    "name": "El lobo que se queda",
    "desc": "Un cachorro criado en el campamento en vez de espantado. "
        + "No caza por ti: corta el rastro que tú has perdido y para la "
        + "pieza hasta que llegas.",
    "needs": [Tech.OJEO],
    "practice": Subsistence.Activity.CAZA,
    "days": 120,
}
```

`needs: OJEO` porque el perro es una pieza de la batida organizada, no un
sustituto de ella. Y **120 jornadas de caza** —el doble que ninguna otra— por
lo que es: no se aprende, se cría.

**Tres efectos, en tres sitios que ya existen:**

| efecto | dónde | qué cambia |
|---|---|---|
| Corta el rastro perdido | `Caceria._stalk` | Al agotarse `ACECHO_HORAS`, con perro hay una tirada de recuperar el rastro en vez de terminar en «rastro frío» |
| Para la pieza | `Caceria._chase` | Sube `FUELLE_HORAS` efectivo: el perro la entretiene mientras llegas |
| Avisa de noche | `Percances._check_mishaps` | Baja el riesgo del vivac: un campamento con perro no lo sorprenden |

El primero es el importante: es el que ataca el 73 % de pérdida directamente.

**Y su coste, que es lo que lo hace una decisión:** el perro **come**. Una boca
más que no recolecta ni talla. En `Inhabitant.daily_food` o como término aparte
en la despensa: ~0,6 raciones/día, lo que come un crío. Con eso, tener perro es
rentable sólo si la banda caza de verdad — que es justo la decisión que se
quiere provocar.

### Cómo se ve

No hace falta modelo nuevo: `WildlifeHerds` ya dibuja `"lobo"` con la malla
`wolf`. Un perro es un lobo con otra tinta y anclado a la cuadrilla en vez de a
una querencia. `BandaCrowd` ya sabe dibujar un grupo que sigue a la gente.

### Criterio de aceptación

*Con perro, las cacerías perdidas en el acecho bajan del 73 % a menos del 50 %,
y la banda tiene una boca más que alimentar.* Medible con `CazaEscalonProbe`
añadiendo un escalón.

---

## 2. El desamargado de la bellota

### Por qué hace falta

Hoy `Materia.Kind.BELLOTA` está en el catálogo con 1 300 kcal y su propio
comentario dice *«necesita desamargado: agua, recipiente y tiempo»* — **y se
come directamente**. La bellota cruda tiene tanino: es astringente, sienta mal
y en cantidad es tóxica. Comérsela sin tratar no es una simplificación, es un
error.

Y resuelve otro problema medido: **la recolección de otoño es demasiado buena**
(32 de fruto seco y 22 de bellota por jornada perfecta). El desamargado pone un
**cuello de botella** donde ahora no hay ninguno: recoger bellota es fácil,
hacerla comestible cuesta.

### Cómo se hacía

Tres métodos atestiguados, todos lentos:

- **Agua corriente** — el saco en el arroyo, días. Barato en trabajo, caro en
  tiempo, y hay que tener el arroyo.
- **Lixiviación con ceniza** — más rápido, gasta ceniza del hogar.
- **Enterrarla** — meses, pero se guarda y se desamarga a la vez.

El primero es el que mejor encaja: **la banda ya tiene río y ya sabe dónde
está**.

### Qué toca en el código

**Un material nuevo**, `BELLOTA_DULCE`, y la bellota cruda deja de alimentar:

```gdscript
Kind.BELLOTA: {
    "name": "Bellota", "unit": "puñado", "kg": 0.6, "litros": 1.4,
    "dias": 300, "kcal": 0,          # <- cruda NO se come
    "desc": "Amarga de tanino. Hay que lavarla en el arroyo días antes "
        + "de que sea comida: cruda es astringente y en cantidad, tóxica.",
},
Kind.BELLOTA_DULCE: {
    "name": "Bellota lavada", "unit": "puñado", "kg": 0.55, "litros": 1.3,
    "dias": 300, "kcal": 1300,
    "desc": "Lavada en agua corriente hasta que suelta el tanino. "
        + "Harina de invierno: se guarda una estación entera.",
},
```

**Una obra del campamento**, que es donde va: `CampProjects` ya tiene `HOGAR` y
`SECADERO`, con su coste en materiales y jornadas.

```gdscript
Kind.LAVADERO: {
    "name": "Lavadero de bellota",
    "desc": "Un cesto lastrado en el remanso. La corriente hace el trabajo: "
        + "sólo hay que ponerla y volver a por ella.",
    "requires": -1,
    "materials": {Materia.Kind.FIBRA: 6.0, Materia.Kind.PIEDRA: 4.0},
    "days": 2.0,
}
```

**Y el proceso**, que va con el hogar porque es quien atiende lo que hay puesto
—igual que `Hogar._smoke_the_larder`—:

```gdscript
## La bellota puesta a lavar. La corriente trabaja sola: esto sólo mira si ya
## está. Ver [CampProjects.Kind.LAVADERO].
func _lavar_bellota() -> void:
```

Con **tres jornadas de remojo** y un tope por lavadero (lo que cabe en el
cesto), que es el cuello de botella: se puede recoger toda la bellota del
robledal y no poder tratarla.

### Lo que cambia en la partida

- El otoño deja de ser «recoge y ya»: hay que **decidir** cuánta bellota se
  pone a lavar y cuánta se queda amarga.
- Aparece una razón para tener el campamento **cerca del agua** que no es la
  pesca.
- La bellota pasa a ser lo que fue: **la harina del invierno**, comida de
  reserva que hay que preparar en otoño o no la tienes en enero.

### Criterio de aceptación

*La bellota recogida en otoño no es comestible hasta pasar tres jornadas en el
lavadero, y el lavadero tiene tope: en un otoño bueno sobra bellota sin
tratar.*

---

## 3. Por qué estas dos y no otras

Las dos comparten la misma virtud: **son históricas y además arreglan algo que
está medido**.

- El perro ataca el 73 % de cacerías perdidas en el acecho.
- El desamargado pone un cuello de botella en la recolección de otoño, que es
  la que desequilibra la despensa.

Añadir contenido que no arregla nada es lo que engorda un juego sin mejorarlo.
Ver [ESTADO_DE_LA_SLICE.md](ESTADO_DE_LA_SLICE.md) §5 para el resto de la
lista, por orden.
