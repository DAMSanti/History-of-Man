# Época 9 — Baja Edad Media: la villa y el mar

s. XI–XV. `Site.Era.HISTORICA`. `Site.Kind.COSTERO` cambia de valor de
golpe, la ferrería pasa de monte a hidráulica, y **la unidad deja de ser el
valle y pasa a ser la villa**, que tiene ley propia y vecindad escrita.

**Punto de partida.** El documento no litúrgico del cierre anterior, que es
lo que permite fundar una villa con fuero.

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| Ferrería hidráulica (~1350 °C) | ferrería de monte + molino de cubo | `HERRERO` | Barras en cantidad, con barquín movido por agua | ATESTIGUADO |
| La nao y la atalaya | ninguno técnico local | `MARINERO`/`BALLENERO` (nuevo) | La ballena se ve desde tierra, se sale a por ella, se despieza en la villa | ATESTIGUADO (escudos de Castro Urdiales y San Vicente de la Barquera) |
| El astillero | madera del valle + ferrería | `ARTESANO` naval (nuevo) | La madera se convierte en barco, y el barco en flete | ATESTIGUADO |
| La lonja y el peso | mercado de moneda (época 7, recuperado) | `MERCADER` | Medida pública: comerciar con quien no se conoce | ATESTIGUADO |
| El puerto de rueda | la calzada romana, recuperada como ruta | `MERCADER` | La lana de Castilla cruza Cantabria hacia Flandes | ATESTIGUADO |

Penúltimo peldaño de la escalera térmica, y el que hace posible el
siguiente: sin barras de hierro en cantidad no hay cañón, y sin cañón no hay
Real Fábrica en la Edad Moderna.

---

## 2. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| Ferrería hidráulica | interno | obra construida | `Feature.INDUSTRIA` (ya existe) |
| La nao y la atalaya | interno | primera pieza de ballena despiezada tras avistamiento | — |
| El astillero | interno | primer barco botado | — |
| La lonja y el peso | interno | obra construida | — |
| El puerto de rueda | interno | primera ruta comercial de largo alcance activa (Castilla–Flandes) | — |
| El fuero | **social, y es el cambio de unidad** | primer documento de autogobierno de villa, heredero directo de "la escritura sale del monasterio" | `Feature.DEFENSIVO` si trae fortificación asociada |
| La hermandad | social | primer pacto formal entre dos villas, por encima de sus señores (paralelo directo al "pacto entre castros" de la Edad del Hierro) | — |
| La peste | social, se sufre a escala menor que un hito de cierre | mortandad puntual (1348) que sube la tierra disponible por cabeza y baja el precio del trabajo | — |
| Los bandos | social | violencia entre linajes como estado normal, no excepcional | — |
| El vecino y el forastero | social | el fuero empieza a discriminar quién es de la villa a efectos económicos | — |
| **El barquín lo mueve el agua** | **cierre** | la ferrería pasa de monte a hidráulica de forma sostenida, no como pieza suelta | `Feature.INDUSTRIA` |

---

## 3. Oficios y profesiones

| `Job` nuevo | Notas |
|---|---|
| `MARINERO`/`BALLENERO` | Oficio de mar abierto: es la maduración directa de la especialidad `ALTURA` de `Profession.Speciality`, marcada en el Paleolítico como "todavía no la hay" por falta de embarcación — aquí, con el astillero, deja de estar apagada |
| `ARTESANO` gremial | El `ARTESANO` puro de la Edad del Bronce se organiza en oficio con fuero propio: no es un `Job` distinto, es una capa de organización (el gremio) sobre el mismo oficio |

`MERCADER` pasa de mercado local de época romana a lonja con pesos
públicos: mismo `Job`, alcance mayor.

---

## 4. Mecánicas nuevas

1. **La villa como unidad de decisión**, sustituyendo al valle: es el
   segundo caso, tras el castro, de `SISTEMAS.md` §7 — y aquí sí
   hace falta relación entre unidades de verdad, porque la hermandad es un
   pacto explícito entre villas, con condiciones, no una alianza tácita.
2. **La especialidad `ALTURA` deja de estar apagada.** `Profession.needs_craft(Speciality.ALTURA)`
   ya lo prevé desde el Paleolítico: "sale en la tabla desde el principio a
   propósito, apagada, porque ver lo que aún no puedes hacer es la mitad de
   la gracia de un juego de progreso". Esta época es donde se enciende.
3. **La mortandad que cambia el precio del trabajo.** La peste es un
   choque de población que altera la relación tierra/mano de obra sin ser
   un hito de cierre — un tercer tipo de evento, entre "interno" y "se
   sufre", que vale la pena distinguir en `Hitos` si se repite en épocas
   posteriores.

---

## 5. La trampa

Que sea un menú de edificios. Lo que distingue a esta época son las
instituciones —fuero, hermandad, lonja, bando— y que por primera vez el
valle depende de un mercado exterior. Si eso no es jugable, la época es un
castillo con textura de piedra.

---

## 6. Fidelidad

`ATESTIGUADO`: fueros de las Cuatro Villas de la Costa (finales del XII,
principios del XIII); Hermandad de las Marismas (1296); Colegiata de
Santillana; ferrerías de agua; torres de los bandos; caza de ballena.
`Feature.DEFENSIVO` e `Feature.INDUSTRIA` ya existen en el código.
