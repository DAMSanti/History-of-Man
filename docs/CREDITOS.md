# Créditos de los assets

Lo genera `scripts/tools/PropIngest.gd` a partir de los
catálogos, así que no se queda desfasado respecto a lo que de
verdad se usa. No se edita a mano.

## Texturas del terreno

[ambientCG](https://ambientcg.com), CC0.

- Pradera — `Grass007`
- Suelo de bosque — `Ground037`
- Roquedo calizo — `Rock030`
- Canchal — `Rocks006`
- Cantos de río — `Gravel041`
- Arena — `Ground095A`
- Limo de marisma — `Ground026`
- Nieve — `Snow010A`

## Modelos del suelo

- Canto rodado — [Poly Haven](https://polyhaven.com/a/rock_07), CC0.
- Nódulo de ocre — [Poly Haven](https://polyhaven.com/a/rock_09), CC0.
- Bloque de ladera — [Poly Haven](https://polyhaven.com/a/boulder_01), CC0.
- Rama caída — [Poly Haven](https://polyhaven.com/a/dry_branches_medium_01), CC0.
- Helecho — [Poly Haven](https://polyhaven.com/a/fern_02), CC0.
- Mata de fruto — [Poly Haven](https://polyhaven.com/a/nettle_plant), CC0.
- Pasto de claro — [Poly Haven](https://polyhaven.com/a/grass_medium_01), CC0.
- Arbusto de baya — [Poly Haven](https://polyhaven.com/a/shrub_02), CC0.
- Mata de raíz — [Poly Haven](https://polyhaven.com/a/dandelion_01), CC0.
- Tocón — [Poly Haven](https://polyhaven.com/a/tree_stump_01), CC0.
- Conífera joven — [Poly Haven](https://polyhaven.com/a/pine_sapling_small), CC0.
- Herbazal — [Poly Haven](https://polyhaven.com/a/grass_medium_02), CC0.
- Peña — [Poly Haven](https://polyhaven.com/a/namaqualand_boulder_02), CC0.
- Peña partida — [Poly Haven](https://polyhaven.com/a/namaqualand_boulder_03), CC0.
- Peña baja — [Poly Haven](https://polyhaven.com/a/namaqualand_boulder_05), CC0.
- Pino de refugio — [Poly Haven](https://polyhaven.com/a/fir_sapling_medium), CC0.
- Pino joven — [Poly Haven](https://polyhaven.com/a/fir_sapling), CC0.
- Abedul — [Poly Haven](https://polyhaven.com/a/tree_small_02), CC0.
- Tronco caído — [Poly Haven](https://polyhaven.com/a/dead_tree_trunk), CC0.
- Tronco partido — [Poly Haven](https://polyhaven.com/a/dead_tree_trunk_02), CC0.
- Cuerna — «Deer horn» de alban (https://sketchfab.com/alban), CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/). https://sketchfab.com/3d-models/deer-horn-dd102097d1da44acbf586ffcc73c15d0
- Concha — «Seashell Fossil» de NaRoCreations (https://sketchfab.com/NaRoCreations), CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/). https://sketchfab.com/3d-models/seashell-fossil-bc4b85625dd045608b498c41f8b5c1a7
- Concha menuda — «Seashell» de yaocheng (https://sketchfab.com/yaocheng), CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/). https://sketchfab.com/3d-models/seashell-9b59afbf4a694e8cb6daa0e0235cff86
- Corteza de yesca — [Poly Haven](https://polyhaven.com/a/bark_debris_01), CC0.

## Personas

«Animated Human» de [Quaternius](https://quaternius.com) ([OpenGameArt](https://opengameart.org/content/animated-human-low-poly)), CC0. `scripts/tools/BandaAtlas.gd` hornea sus siete animaciones -reposo, andar, correr, salto, golpe, trabajo, muerte- a textura de vértice para dibujar la banda entera en un solo `MultiMesh`; ver ese fichero para el porqué.

## Fauna

Lobo, caballo, vaca, cerdo, oveja, águila y pájaro pequeño de [Quaternius](https://quaternius.com) — [Animal Pack Vol.2](https://opengameart.org/content/animated-animales-low-poly), [Farm Animals](https://opengameart.org/content/lowpoly-animated-farm-animal-pack)—, CC0. Ciervo, venado y toro del [Ultimate Animated Animal Pack](https://quaternius.com/packs/ultimateanimatedanimals.html) del mismo autor, CC0. Pato de [Gobkit](https://gobkit.com), CC0. `scripts/tools/FaunaAtlas.gd` los hornea igual que a la banda.

`WildlifeHerds.gd` reparte once mallas entre las doce especies de [Fauna]. La caza mayor ya no anda prestada de caballo ni de oveja —esas dos mallas de granja sólo traen reposo y salto, y por eso jabalí, corzo y rebeco cruzaban el valle con las patas quietas—, pero tres cosas siguen faltando y conviene tenerlas escritas:

- **Cabra montés y rebeco.** No hay bóvido de montaña CC0 descargable por script. El rebeco lleva la malla del corzo con otra talla y otro tinte: anda bien, pero comparte silueta con él.
- **Jabalí.** Tampoco hay suido con ciclo de marcha. Lleva la del toro, que es lo más parecido que anda: cuerpo bajo y macizo con la cabeza pesada delante.
- **La cuerna del venado.** El `Stag.fbx` trae las astas en una malla aparte, colgada de un hueso, y el horneado a textura de vértice sólo se lleva una malla con pesos. Se hornea el cuerpo; las astas se pierden, que en la época de la berrea se nota.

## Clima

- **Temperatura actual al nivel del mar, costa cantábrica** — Valores
  climatológicos normales de **AEMET, periodo 1991–2020**, observatorio de
  **Santander / aeropuerto** (Camargo, **3 m** de cota, que es lo que lo hace
  servir de base a nivel del mar). Media anual **14,8 °C**; medias mensuales,
  de enero a diciembre: 10,0 · 9,9 · 11,6 · 12,9 · 15,6 · 18,1 · 20,1 · 20,8 ·
  18,9 · 16,5 · 12,8 · 10,8. Consultado el 2026-09-12.
  <https://www.aemet.es/es/serviciosclimaticos/datosclimatologicos/valoresclimatologicos?l=1111&k=can>

  > La tabla de AEMET se sirve por JavaScript y no se puede leer de la página
  > directamente; estas cifras se tomaron de la ficha de Santander de la
  > Wikipedia en español, que cita esa misma fuente y periodo. **Quien las use
  > para algo que dependa del decimal, que las contraste contra el CSV de
  > AEMET** (`ecv_normales_1991-2020.zip`, datos abiertos).

- **Desfase térmico del final del Magdaleniense** — Tarroso, P., Carrión, J.,
  Dorado-Valiño, M., Queiroz, P., Santos, L., Valdeolmillos-Rodríguez, A.,
  Célio Alves, P., Brito, J. C., y Cheddadi, R. (2016): «Spatial climate
  dynamics in the Iberian Peninsula since 15 000 yr BP», *Climate of the Past*
  **12**, 1137–1149, <https://doi.org/10.5194/cp-12-1137-2016>. Acceso abierto,
  CC-BY. Reconstruye por polen la mínima de enero y la máxima de julio en
  mallas de mil años entre los 15 ka y los 3 ka.

  Se usa su **grupo C1**, que es «northern and western Iberia... includes part
  of the north-Iberian mountain ranges but also low altitudinal coastal areas»
  —o sea, ésta—. Sobre el tramo de 15 a 3 ka, C1 va de **−5,5 a 0,2 °C** de
  mínima de enero y de **21,7 a 24,2 °C** de máxima de julio, y el texto cifra
  el calentamiento medio de enero en **~5,5 °C** sobre esos 15 000 años,
  añadiendo que en julio «variations showed a smaller amplitude». A ~14 ka cal
  BP —los **12 000 a.C.** del final del Magdaleniense, decidido por el usuario
  el 2026-09-12— toca el extremo frío: **−5 °C en invierno y −2 °C en verano**.

  > **Dos salvedades, y conviene leerlas antes de afinar nada con esto.**
  > Primera: el trabajo reconstruye **mínima de enero y máxima de julio**, y
  > aquí el desfase se aplica a **medias mensuales**, que no es exactamente la
  > misma magnitud. Segunda: los −5 y −2 se **leen del extremo frío de los
  > rangos publicados y de la tendencia que el texto cifra**, no de las mallas
  > NetCDF del suplemento, que sí darían el valor puntual a 14 ka en este punto
  > del mapa. Quien necesite precisión, ahí están:
  > <https://doi.org/10.5194/cp-12-1137-2016-supplement>.

  **Descartada**: una reconstrucción por arvicolinos en El Mirón (*Quaternary
  Science Reviews*, 2023) que da medias «no superiores a 5 °C» para el último
  nivel solutrense. Está tras muro de pago —la cifra llegó por un resumen de
  búsqueda, no leyendo el texto— y además el Solutrense es **anterior** al
  Magdaleniense.

## Árboles del bosque en 3D (GRAFICOS §7.1)

**Generados**, no descargados: no hay modelos CC0 realistas hechos para juego de pino
silvestre, abedul, roble y avellano, y el usuario decidió generarlos (2026-09-15).

- **Geometría** — [EZ-Tree](https://github.com/dgreenheck/ez-tree), de Daniel
  Greenheck, **licencia MIT**. Se usa como herramienta (`scripts/tools/arboles/generar.mjs`)
  y lo que se guarda en `models/arboles/` es su salida, con presets afinados por
  especie y seis variantes cada una.
- **Hojas** — atlas de [ambientCG](https://ambientcg.com), **CC0**:
  [LeafSet019](https://ambientcg.com/view?id=LeafSet019) (pino; es un ramillete de
  conífera, no acículas de pino silvestre),
  [LeafSet004](https://ambientcg.com/view?id=LeafSet004) (abedul),
  [LeafSet016](https://ambientcg.com/view?id=LeafSet016) (roble) y
  [LeafSet024](https://ambientcg.com/view?id=LeafSet024) (avellano). **Las texturas de
  hoja que trae EZ-Tree no declaran licencia, y por eso no se usan.**
- **Cortezas** — ambientCG, **CC0**: [Bark014](https://ambientcg.com/view?id=Bark014)
  (pino), [Bark009](https://ambientcg.com/view?id=Bark009) (abedul),
  [Bark001](https://ambientcg.com/view?id=Bark001) (roble) y
  [Bark004](https://ambientcg.com/view?id=Bark004) (avellano).
- **Color de referencia** — de cada foto **sólo se guarda el color medio** en CIELAB
  (`models/arboles/color_de_referencia.json`, con título, página, licencia y autor de
  cada una); la foto no está en el repositorio. Todas de Wikimedia Commons:

  | Qué | Foto | Autor | Licencia |
  |---|---|---|---|
  | Pino, copa | [Pinus sylvestris Scots Pine at Stansted Mountfitchet 3](https://commons.wikimedia.org/wiki/File:Pinus_sylvestris_Scots_Pine_at_Stansted_Mountfitchet,_Essex,_England_3.jpg) | Acabashi | CC BY-SA 4.0 |
  | Pino, corteza | [Pinus sylvestris bark 2012-05-18](https://commons.wikimedia.org/wiki/File:Pinus_sylvestris_bark_2012-05-18.jpg) | Rudolf Schäfer | CC BY-SA 2.0 |
  | Abedul, copa en verano | [Efremov - 2025 - Betula pendula crown](https://commons.wikimedia.org/wiki/File:Efremov_-_2025_-_Betula_pendula_crown.jpg) | Юрий Д.К. | CC BY 4.0 |
  | Abedul, copa en otoño | [Betula pendula (fall colors)](https://commons.wikimedia.org/wiki/File:Betula_pendula_(fall_colors).jpg) | Le.Loup.Gris | CC BY-SA 3.0 |
  | Abedul, corteza | [Betula pendula bark TK 2023-04-16 1](https://commons.wikimedia.org/wiki/File:Betula_pendula_bark_TK_2023-04-16_1.jpg) | T. Kebert | CC BY-SA 4.0 |
  | Roble, copa en verano | [Pferdekopfeiche, Ivenack, NW view](https://commons.wikimedia.org/wiki/File:Pferdekopfeiche,_Ivenack,_NW_view.jpg) (el robledal del fondo) | Radomianin | CC BY-SA 4.0 |
  | Roble, copa en otoño | [Autumn English Oak (Quercus robur) leaves](https://commons.wikimedia.org/wiki/File:Autumn_English_Oak_(Quercus_robur)_leaves_(26092351292).jpg) | AnemoneProjectors | CC BY-SA 2.0 |
  | Roble, corteza | [Oak tree Quercus robur bark at High Beach](https://commons.wikimedia.org/wiki/File:Oak_tree_Quercus_robur_bark_at_High_Beach,_Essex,_England.jpg) | Acabashi | CC BY-SA 4.0 |
  | Avellano, copa en verano | [Corylus avellana shrub](https://commons.wikimedia.org/wiki/File:Corylus_avellana_shrub.jpg) | MPF | CC BY-SA 3.0 |
  | Avellano, copa en otoño | [20171114Corylus avellana2](https://commons.wikimedia.org/wiki/File:20171114Corylus_avellana2.jpg) | AnRo0002 | CC0 |
  | Avellano, corteza | [Corylus avellana bark](https://commons.wikimedia.org/wiki/File:Corylus_avellana_bark.jpg) | MurielBendel | CC BY-SA 4.0 |

## Arte parietal: los motivos de la pared

Las figuras que se pintan en la pared de la cueva (SISTEMAS §13) son **calcos**:
`scripts/tools/calcar_motivos.py` baja cada referencia de Wikimedia Commons, separa
el pigmento, saca sus contornos y la silueta del cuerpo, y escribe
`scripts/datos/Motivos.gd`. Ninguna figura se ha dibujado de memoria. Los calcos
limpios de **José-Manuel Benito Álvarez** (usuario Locutus Borg), publicados en
dominio público, son la mayor parte; el de la mano es de **Hugo Obermaier**
(muerto en 1946). Las pinturas en sí son prehistóricas y no tienen autor con
derechos.

| Motivo | Qué es | Referencia | Licencia |
|---|---|---|---|
| Bisonte | Bisonte del gran techo de Altamira | <https://commons.wikimedia.org/wiki/File:Altamira-3.png> | Dominio público (J.-M. Benito) |
| Jabalí | Jabalí del borde izquierdo del mismo techo | <https://commons.wikimedia.org/wiki/File:Altamira-3.png> | Dominio público (J.-M. Benito) |
| Cierva | Cierva roja en tinta plana, panel 22, La Pasiega | <https://commons.wikimedia.org/wiki/File:La_Pasiega-Galeria_A-Cierva_roja_(panel_22).png> | Dominio público (J.-M. Benito) |
| Ciervo | Ciervo negro de Las Chimeneas | <https://commons.wikimedia.org/wiki/File:Cueva_de_Chimeneas_(ciervo).png> | Dominio público (J.-M. Benito) |
| Caballo | Caballo grabado de Hornos de la Peña | <https://commons.wikimedia.org/wiki/File:Cueva_de_Hornos_de_la_Pe%C3%B1a_(grabados).png> | Dominio público (J.-M. Benito) |
| Uro | Uro de la Sala de los Toros, **Lascaux** | <https://commons.wikimedia.org/wiki/File:Lascaux_painting.jpg> | Dominio público |
| Mano | Mano roja del panel 54, La Pasiega | <https://commons.wikimedia.org/wiki/File:La_Pasiega-Galeria_B-panel_54.png> | Dominio público (H. Obermaier) |
| Serie de puntos | Panel 48, La Pasiega | <https://commons.wikimedia.org/wiki/File:La_Pasiega-Galeria_A-panel_48.png> | Dominio público (J.-M. Benito) |
| Bastoncillos | Ideomorfos del panel 37, La Pasiega | <https://commons.wikimedia.org/wiki/File:La_Pasiega-Galeria_A-panel_37.png> | Dominio público (J.-M. Benito) |
| Claviformes | Panel 58, La Pasiega | <https://commons.wikimedia.org/wiki/File:La_Pasiega-Galeria_B-panel_58.png> | Dominio público (J.-M. Benito) |
| Tectiforme | Galería A, La Pasiega | <https://commons.wikimedia.org/wiki/File:La_Pasiega-Galeria_A-Tectiformes.png> | Dominio público (J.-M. Benito) |
| Escaleriforme | El marco en escalera de «La Trampa», panel 78, La Pasiega | <https://commons.wikimedia.org/wiki/File:La_Pasiega-Galeria_C-La_Trampa.png> | Dominio público (J.-M. Benito) |

**El uro es el único que no es cantábrico.** No se encontró en Commons, el
2026-09-15, ni un calco ni una foto libre de un uro de las cuevas de la región;
el de Lascaux es del mismo Magdaleniense. Si aparece uno cantábrico, se cambia la
línea de `calcar_motivos.py` y se vuelve a calcar.

## Lo que falta

- **Cuerna de desmogue** — Icono del Magdaleniense: azagayas y arpones salen de aquí. No existe en Poly Haven ni en ambientCG.
- **Concha de lapa o mejillón** — Ojo con la especie: `lambis_shell` de Poly Haven es una caracola tropical, nada que ver con el marisqueo cantábrico.
- **Seta** — Tampoco existe en CC0 scripteable.
- **Árbol adulto de verdad** — Los de Poly Haven son escaneos de cine -17 millones de triángulos el pino- y Godot se niega a generarles niveles de detalle: «mesh is too complex». Hace falta un árbol hecho para juego: unos miles de triángulos y la hoja en planos con alfa.
- **Hueso** — Ídem.
