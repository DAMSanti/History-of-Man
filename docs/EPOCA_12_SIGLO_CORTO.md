# Época 12 — El siglo corto: hasta el mapa de hoy

1900–1982. `Site.Era.HISTORICA`. No hay cierre de progreso: hay un final de
partida. El territorio jugado se cierra exactamente sobre
`data/boundaries/cantabria.json`, los 5304 km² con los que arrancó el juego
en la primera pantalla.

**Punto de partida.** Capital exterior ya instalado (cierre de la época
anterior), jornal como forma normal de trabajo, emigración a América en
marcha.

---

## 1. Desarrollos tecnológicos

| Técnica/proceso | Prerrequisito | Oficio | Qué habilita | Evidencia |
|---|---|---|---|---|
| La electricidad | máquina de vapor (época 11) | `TECNICO` (nuevo) | La jornada deja de acabarse con el sol, por primera vez desde la lámpara de grasa del Paleolítico | ATESTIGUADO |
| El hormigón | ninguno técnico local | `OBRERO` construcción | Se construye en cualquier sitio, con material que no es del sitio — rompe la regla de fidelidad geológica que sostiene el resto del juego, y a propósito | ATESTIGUADO |
| El automóvil | la carretera (época 10) | `MAQUINISTA`/`TECNICO` | Con la carretera asfaltada, el pueblo de montaña deja de estar a un día de todo | ATESTIGUADO |
| La química | el ferrocarril y el capital exterior (época 11) | `QUIMICO` (nuevo) | Solvay y Sniace producen bien y el río paga la factura: el Besaya es un dato del juego, no una moraleja | ATESTIGUADO |
| El frigorífico | ninguno técnico local | — (obra doméstica) | Cae la última mecánica que venía del Paleolítico: la conservación por humo, sal y estación | ATESTIGUADO |
| La genética aplicada | la cría dirigida (época 10) | `TECNICO` agrónomo | Selección científica de razas y variedades, ya no a ojo: es donde "mejora genética" se vuelve ciencia de verdad, tras dos siglos de selección artificial documentada desde Bakewell | ATESTIGUADO como fenómeno de mediados de siglo XX (inseminación artificial, semilla mejorada) |

**El frigorífico es el hito técnico más silencioso y más importante de la
lista**: cierra un sistema que lleva activo desde `SLICE_PALEOLITICO.md`
—secado y ahumado, luego el secadero, luego la salazón, luego la conserva
industrial— y que, del Paleolítico al siglo XX, es la única mecánica que
sobrevive sin interrupción a las doce épocas hasta este punto exacto.

---

## 2. Hitos

| Hito | Tipo | Condición de disparo | Deja en el mapa |
|---|---|---|---|
| La electricidad | interno | primera instalación conectada | — |
| El hormigón | interno | primera construcción con material importado, no local | — |
| El automóvil | interno | primera carretera asfaltada transitada | — |
| La química | interno | primera planta química en marcha (Solvay 1908, Sniace 1941) | `Feature.INDUSTRIA` |
| El frigorífico | interno | primera instalación de frío, sustituye conservación tradicional | apaga la necesidad de secadero/ahumado como mecánica central |
| La genética aplicada | interno | primera mejora de rebaño o cultivo por selección científica, no sólo por cría dirigida a ojo | — |
| El veraneante | social | primer sitio cuyo valor económico es el paisaje, no lo que produce | nueva clase de uso de `Site`, no contemplada hoy en `Site.Kind` |
| **La guerra** | **se sufre, y es distinto de los otros tres** | 1937, fecha fija, no condición de estado — es el único de los cuatro hitos sufridos que no depende de nada que haya hecho la partida | destrucción/abandono puntual sobre `Feature` existentes, sin `Feature` nuevo |
| El éxodo rural | social | emplazamientos ocupados desde el Neolítico se quedan sin nadie | vaciado de `Settlement`, no borrado del `Site` |
| La reconversión | social | lo que trajo el jornal se lo lleva, y deja el edificio puesto | `Feature.INDUSTRIA` persiste sin actividad |
| **El mapa se cierra** (final, no hito de cierre de época) | — | Cantabria se constituye en comunidad autónoma (1981–82); el territorio jugado coincide exactamente con `data/boundaries/cantabria.json` | — |

**"La guerra" es el único de los cuatro hitos que se sufren con fecha fija
en vez de condición de estado.** Los otros tres —el bosque, la legión, el
Estado que se va— dependen de dónde está la partida cuando se cumplen; 1937
no depende de nada que la banda haya hecho o dejado de hacer, y el patrón de
`Hitos` de `SISTEMAS_COMPARTIDOS.md` §6 debe distinguir explícitamente los
hitos por condición de estado de este único hito por calendario absoluto.

**No hay victoria; hay reconocimiento.** El final de partida no es un
puntaje: es que el mapa que se ha ido ocupando durante cuarenta mil años se
convierte en el mapa que se dio a elegir en la primera pantalla.

---

## 3. Oficios y profesiones

| `Job` nuevo | Notas |
|---|---|
| `TECNICO` | Electricidad, automóvil, agronomía. Oficio de formación, no de linaje ni de aprendizaje por práctica pura |
| `QUIMICO` | Fábrica de proceso, no de manufactura: Solvay y Sniace |

El éxodo rural vacía `LABRIEGO` y `PASTOR` de buena parte del mapa, sin que
el `Job` deje de existir: es el primer caso en que un oficio sigue siendo
jugable pero deja de tener gente disponible en la mayoría de emplazamientos.

---

## 4. Mecánicas nuevas

1. **`Site` valorado por paisaje, no por producción.** El veraneante pide un
   uso de `Site` que hoy `Site.Kind` no contempla: un emplazamiento puede
   valer por lo que se ve desde él o por su playa, no por sus recursos.
2. **El hito por fecha de calendario, no por condición de estado**, único
   caso en las doce épocas, y por eso merece su propio camino en `Hitos`.
3. **El cierre de la escalera del alimento** (`SISTEMAS_COMPARTIDOS.md`
   §1.3): frío, conserva y salario. La comida deja de depender de la
   estación y del sitio, la restricción sobre la que está construido el
   juego entero desde la primera pantalla — y el frigorífico es el
   mecanismo concreto que lo cierra.
4. **La genética como ciencia**, distinta de la cría dirigida de la época
   10: aquí sí hay selección con criterio explícito y trazable, no sólo
   intuición de criador.

---

## 5. La trampa

Dos, y las dos fáciles de pisar. Contar la contaminación y la reconversión
como moraleja —son consecuencias medibles, y el juego mide, no predica—.
Y seguir jugando después de 1982: de ahí en adelante no hay distancia
histórica suficiente para convertir nada en mecánica, y el registro deja de
ser registro para ser opinión.

---

## 6. Fidelidad

`ATESTIGUADO`, con la misma advertencia de método que la época anterior
—archivo, prensa y memoria, no excavación—: Palacio de la Magdalena y
veraneo (1913); frente del norte y caída de Santander (1937); incendio de
Santander (1941); Sniace en Torrelavega (1941) y química del Besaya;
emigración a Europa de los sesenta; turismo de costa; reconversión
industrial de los ochenta; Estatuto de Autonomía (1981–82).
