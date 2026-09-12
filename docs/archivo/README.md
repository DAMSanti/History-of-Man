# El archivo

Documentos cerrados. **Aquí no se edita nada.**

El 2026-09-12 la documentación se reorganizó para que `docs/` tuviera un
conjunto fijo de documentos genéricos y **lo único específico fueran las fichas
de época**. Lo que seguía siendo verdad se fundió en los permanentes; lo que
está aquí es el relato de cómo se llegó a ello.

**Por qué no se borró.** Un documento permanente dice *qué* es verdad. Estos
dicen **qué se probó, qué salió, qué premisa se cayó a mitad y por qué se
decidió lo que se decidió** — y eso es la mitad del valor de este repositorio.
Media docena de las decisiones que hoy parecen obvias sólo se entienden leyendo
el intento que falló antes.

**Y cuando se contradigan: gana el permanente.** Hay cosas aquí que ya no son
verdad. Se reconocen porque el documento de `docs/` dice otra cosa.

---

## Qué hay, y dónde fue a parar

### Diseño y sistemas

| | Qué era | Dónde vive ahora |
|---|---|---|
| [SLICE_PALEOLITICO.md](SLICE_PALEOLITICO.md) | El diseño de la primera época: el techo de la época, el bucle del año, los recursos, el enclave | [EPOCA_01_PALEOLITICO.md](../EPOCA_01_PALEOLITICO.md), que lo absorbió entero |
| [CAZA_Y_PESCA.md](CAZA_Y_PESCA.md) | La despensa, la puerta del arma, las fases de la cacería, las nasas, el relato y la pared | [SISTEMAS.md](../SISTEMAS.md) §10–§13 |
| [PERRO_Y_BELLOTA.md](PERRO_Y_BELLOTA.md) | El lobo que acaba en perro o en enemigo, el desamargado de la bellota, el conchero | [SISTEMAS.md](../SISTEMAS.md) §14–§15 |
| [CIERRE_SLICE.md](CIERRE_SLICE.md) | El goal que dejó el Paleolítico jugable: hogar con estados, pernocta, locomoción de la fauna | Repartido entre [ESTADO.md](../ESTADO.md) y [SISTEMAS.md](../SISTEMAS.md) |
| [REVAMP_GRAFICO.md](REVAMP_GRAFICO.md) | El plan gráfico entero, fase a fase, con sus commits y sus tres correcciones de medida | [GRAFICOS.md](../GRAFICOS.md); lo pendiente, en [ROADMAP.md](../ROADMAP.md) |

### Specs cerradas

| | Estado | Dónde vive ahora |
|---|---|---|
| [QUE_SE_PUEDA_PERDER.md](QUE_SE_PUEDA_PERDER.md) | **13/13 hechas.** Hambre, frío, vejez, nacimientos y muertes | [ESTADO.md](../ESTADO.md) §1 y §5 |
| [QUE_FALTA_PARA_JUGARLO.md](QUE_FALTA_PARA_JUGARLO.md) | **10/10 hechas.** El objetivo doble, el modo de perder, la primera hora | [ESTADO.md](../ESTADO.md) §7 |
| [ABRIGO_Y_TRUEQUE.md](ABRIGO_Y_TRUEQUE.md) | **17/17 hechas.** Vestido, plazas de abrigo, sílex por intercambio | Lo que quedó fuera, en [ROADMAP.md](../ROADMAP.md) |
| [LO_MISMO_MAS_DEPRISA.md](LO_MISMO_MAS_DEPRISA.md) | **Casi cerrada.** Determinismo y rendimiento | Lo vivo, en [ROADMAP.md](../ROADMAP.md) «En curso» |
| [SECADERO_Y_RIO.md](SECADERO_Y_RIO.md) | **Pendiente.** El secadero de otoño y la pesca sin sitio | [ROADMAP.md](../ROADMAP.md) «En curso» |

### Diseño descartado

| | Por qué |
|---|---|
| [EPOCA_12_SIGLO_CORTO.md](EPOCA_12_SIGLO_CORTO.md) | Las once épocas eran doce. El siglo corto (1900–1982) salió porque el motor de jornadas y calorías no simula jornal ni capital. Se llevó consigo el final circular de la partida, que sigue pendiente de decidir |

---

## Dos avisos que hay que leer antes de citar nada de aquí

**El contador de tirones estaba roto**, y todo recuento anterior a su arreglo es
basura. El panel de F3 y la sonda leían la misma bandeja de picos y **la vaciaba
quien leyera primero**: el cepo empujaba 92 picos y la sonda contaba 3. Está al
principio de [LO_MISMO_MAS_DEPRISA.md](LO_MISMO_MAS_DEPRISA.md). Si una cifra de
tirones de estos documentos no dice que es posterior a ese arreglo, **no se
usa**.

**Y ×20 no es velocidad de juego.** La partida llega como mucho a ×5, y a ×5 el
reparto del coste es otro. Varias medidas de aquí se tomaron a ×20.
