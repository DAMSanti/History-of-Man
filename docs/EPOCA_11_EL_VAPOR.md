# Época 11 — El vapor: la fábrica y el ferrocarril

c. 1830–1900. `Site.Era.HISTORICA`. **La última época jugable**, desde que
el siglo corto se retiró (ver `archivo/EPOCA_12_SIGLO_CORTO.md` y
EPOCAS.md §2). Desde aquí el valle deja de ser un sistema cerrado: lo que se
produce, lo que vale y quién lo compra se decide fuera del mapa. Es también
donde cambia el método de esta documentación —de aquí en adelante la fuente
ya no es arqueológica, es de archivo y prensa.

> **Aviso de alcance.** Esta ficha se conserva con la misma advertencia que
> tumbó a la 12: el jornal y el capital de fuera **no se simulan** con el
> motor de jornadas y calorías que existe hoy, y EPOCAS.md §7 la señala como
> la siguiente candidata a caer si hay que recortar. Está escrita como
> destino, no como compromiso.

**Punto de partida.** Alto horno en marcha, provincia constituida (1778),
monte comunal ya en trance de privatizarse (cierre de la época anterior).

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| El coque | alto horno | `OBRERO`/`HERRERO` industrial | Suelta al alto horno del carbón vegetal: la industria deja de estar limitada por el bosque, techo desde el Neolítico | ATESTIGUADO |
| La máquina de vapor | ninguno técnico local | `MAQUINISTA` (nuevo) | La energía se desengancha del río y de la estación | ATESTIGUADO |
| El ferrocarril | la carretera (época 10) | `MAQUINISTA` | Alar–Santander (1857–1866): reordena el mapa regional entero | ATESTIGUADO |
| La mina a cielo abierto | galería de mina (época 7) | `MINERO` | Altera el paisaje a escala de mapa — y está en el DEM real que el juego ya carga | ATESTIGUADO (Cabárceno) |
| Conserva y salazón industrial | la salazón (época 6) escalada | `OBRERO` | El pescado deja de ser comida y pasa a ser producto | ATESTIGUADO (anchoa de Santoña, maestros italianos) |

El coque es el peldaño que cierra la escalera térmica clásica de
`SISTEMAS.md` §1.1: a partir de aquí el límite no es una
temperatura, es el dinero. Es la señal más limpia de que el juego cambia de
género.

---

## 2. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| El coque | interno | primera colada sin carbón vegetal | — |
| La máquina de vapor | interno | primera instalación con motor de vapor | — |
| El ferrocarril | interno | tramo construido conectando dos `Site` mayores | reordena rutas comerciales de `Intercambio` |
| La mina a cielo abierto | interno | primera extracción a cielo abierto sobre el DEM real | modifica terreno visible, no sólo un `Feature` |
| La conserva industrial | interno | primera producción en serie de conserva | — |
| El jornal | **social, cambio de unidad** | el trabajo se vende por horas a alguien; unidad económica de toda la época | — |
| La emigración masiva | social | flujo sostenido de población hacia América, con retorno de capital | — |
| La escuela y el cuartel | social | el Estado cuenta a cada persona por su nombre, por primera vez desde el censo romano | — |
| La huelga | social | primera acción colectiva de quien no tiene tierra ni herramienta | — |
| **El capital de fuera** | **cierre** | una fábrica que se levanta con dinero que no es del valle (Solvay en Barreda, 1908, capital belga) | `Feature.INDUSTRIA` |

---

## 3. Oficios y profesiones

| `Job` nuevo | Notas |
|---|---|
| `OBRERO` fabril, generalizado | El `OBRERO` de Real Fábrica de la época 10 deja de ser excepción y se vuelve la forma normal de trabajar para buena parte de la población |
| `MINERO` a cielo abierto | Evolución de escala del `MINERO` de galería romano |
| `MAQUINISTA` | Ferrocarril y vapor; primer oficio cuyo saber es mecánico y no artesanal ni agrícola |

`LABRIEGO` y `PASTOR` no desaparecen, pero compiten por primera vez con un
salario alternativo fuera del campo — la emigración y el jornal fabril
vacían mano de obra rural sin que el campo deje de existir.

---

## 4. Mecánicas nuevas

1. **La decisión que se toma fuera del mapa.** El sistema de `Intercambio`
   de `SISTEMAS.md` §5 necesita un cuarto peldaño: un mercado
   cuyo precio no lo fija nadie dentro de la partida — el jugador reacciona
   a un precio externo, no lo negocia.
2. **El paisaje que cambia a escala de mapa por una sola decisión.** La mina
   a cielo abierto es el primer caso en que una actividad económica altera
   el terreno visible del mapa regional, no sólo coloca un `Feature`
   puntual — y el proyecto ya tiene el DEM real para representarlo sin
   inventar geometría.
3. **El censo por nombre.** La escuela y el cuartel devuelven al Estado una
   capacidad que Roma tuvo y la Alta Edad Media perdió: contar a cada
   persona. Es un buen candidato para reconectar con el sistema de
   `Inhabitant` existente en vez de crear uno nuevo.

---

## 5. La trampa

Que se convierta en un *tycoon*. EPOCAS.md es explícito: el juego no es de
construir la fábrica, es de **qué le pasa al valle cuando la fábrica
llega** — quién deja el ganado, quién se va a América, qué monte se vende y
qué río se ensucia. Si el jugador acaba optimizando toneladas de mineral, se
ha perdido lo que hace distinto a este proyecto.

---

## 6. Fidelidad

`ATESTIGUADO`, y por primera vez de archivo y prensa, no arqueológico:
ferrocarril de Alar del Rey a Santander (1857–1866); minas de Cabárceno y
zinc de Reocín; Altos Hornos de Nueva Montaña (1899); emigración masiva a
América; explosión del *Cabo Machichaco* (1893). El cambio de fuente debe
distinguirse en la enciclopedia de FASE E4 cuando exista, y no mezclarse con
la etiqueta de una estela discoidea.
