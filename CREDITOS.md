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
- Roble — [Poly Haven](https://polyhaven.com/a/island_tree_01), CC0.
- Avellano — [Poly Haven](https://polyhaven.com/a/island_tree_02), CC0.
- Brezal — [Poly Haven](https://polyhaven.com/a/shrub_01), CC0.
- Enebro — [Poly Haven](https://polyhaven.com/a/shrub_03), CC0.
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

## Lo que falta

- **Cuerna de desmogue** — Icono del Magdaleniense: azagayas y arpones salen de aquí. No existe en Poly Haven ni en ambientCG.
- **Concha de lapa o mejillón** — Ojo con la especie: `lambis_shell` de Poly Haven es una caracola tropical, nada que ver con el marisqueo cantábrico.
- **Seta** — Tampoco existe en CC0 scripteable.
- **Árbol adulto de verdad** — Los de Poly Haven son escaneos de cine -17 millones de triángulos el pino- y Godot se niega a generarles niveles de detalle: «mesh is too complex». Hace falta un árbol hecho para juego: unos miles de triángulos y la hoja en planos con alfa.
- **Hueso** — Ídem.
