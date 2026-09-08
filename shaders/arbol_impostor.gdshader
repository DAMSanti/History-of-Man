shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley;

// El árbol de lejos: un cuadrado con su foto, girado hacia quien mira.
//
// Es lo que permite tener el bosque ENTERO en pantalla, que es la condición de
// partida. Un pino de ocho metros con su malla son miles de triángulos, y un
// valle de dieciséis kilómetros cuadrados lleva decenas de miles de árboles: con
// geometría no se sostiene ni con niveles de detalle, porque el problema no es
// el detalle de uno sino la cantidad de todos.
//
// Con impostores cada árbol son DOS triángulos. Treinta mil árboles son sesenta
// mil triángulos —menos que un solo pino escaneado de Poly Haven, que trae
// diecisiete millones— y siguen estando todos, hasta el borde del mapa.
//
// La foto la hornea `scripts/tools/TreeAtlas.gd` del propio modelo que se usa
// de cerca, así que el impostor y la malla real son el mismo árbol y el relevo
// entre los dos no cambia de especie a medio camino.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int atlas_grid = 3;
// Qué celda del atlas es esta especie. Va por uniform y no por instancia
// porque hay un `MultiMesh` por especie: así el impostor sabe su celda sin
// gastar datos por instancia.
uniform int cell_index = 0;

// A qué distancia se releva la malla de verdad por el impostor, en metros.
//
// Es un corte DURO y el mismo para todo el bosque a la vez, a propósito: un
// desvanecido -por sorteo de árbol en árbol o por encogido- se ve desde lejos
// como una nube de arbolitos a medias delante de la cámara, que es peor que un
// simple salto. Con el corte único no hay mezcla posible: a un lado del radio
// está la malla entera, al otro el impostor entero, y el salto pasa de golpe
// para todo el bosque a la vez en vez de ir goteando árbol a árbol.
uniform float near_end = 150.0;

// Y hasta dónde llega. Muy lejos, porque el bosque tiene que verse hasta el
// borde del valle: es paisaje, no detalle.
uniform float far_end = 4000.0;


// Cuánto se inclina la lámina hacia atrás al mirarla desde arriba.
//
// Un impostor es vertical, así que con la cámara alta se ve de canto y el
// bosque se adelgaza. Inclinarlo un poco hacia el observador le devuelve
// superficie sin que a ras de suelo se note, que es el mismo problema que tenía
// la hierba y aquí sí se puede resolver girando, porque un árbol no se lee por
// su base sino por su copa.
// Ya no se inclina: se TUMBA DEL TODO y se enseña la copa. Ver `cell_top`.
// El número se queda para poder volver atrás, pero a cero.
uniform float lean_back : hint_range(0.0, 0.8) = 0.0;

// La celda del atlas con la copa vista desde arriba.
//
// Es la mitad del arreglo del bosque visto de pájaro. La otra mitad es tumbar
// la lámina: inclinarla un poco -que es lo que había- dibuja un remolino
// circular alrededor del centro de la pantalla, porque cada árbol se tumba
// hacia quien mira y los del centro se tumban más que los del borde. Y de paso
// hacía que un árbol apareciera o desapareciera con sólo cambiar el ángulo.
uniform int cell_top = 0;

// Entre qué alturas de cámara se pasa del perfil a la copa. Se mide como el
// seno del ángulo de la cámara sobre el árbol: 0 es a ras de suelo y 1 es
// justo encima.
uniform float top_from : hint_range(0.0, 1.0) = 0.62;
uniform float top_to : hint_range(0.0, 1.0) = 0.90;

// Cuánto se agranda la copa tumbada.
//
// Una copa de verdad mide tres o cuatro metros de ancho contra los ocho o
// veinte de alto del árbol, así que la lámina tumbada tapa mucho menos que la
// de perfil: puesta a tamaño real, desde arriba el bosque se convierte en una
// alfombra lisa en la que no se distingue un árbol. Se engorda hasta que las
// copas se solapan, que es como se ve un pinar desde un pájaro.
uniform float crown_gain : hint_range(1.0, 3.0) = 1.8;

// Cuánta luz atraviesa la copa.
//
// Una copa no tiene cara oscura: es un volumen de hojas y la luz la cruza. Sin
// esto, la tabla que queda de espaldas al sol se va a NEGRO y el árbol de cerca
// se ve partido en cuadrantes, uno de ellos completamente apagado.
//
// Y poco: `BACKLIGHT` SUMA luz sin mirar de dónde viene, así que con el sol
// alto y el ambiente subido, medio albedo de trasluz quema el bosque entero a
// blanco. Probado en 0,45 y el valle salía nevado.
uniform float leaf_wrap : hint_range(0.0, 1.0) = 0.10;

// Uno para el impostor de lejos -que se gira hacia la cámara- y cero para las
// tablas cruzadas de cerca, que están quietas.
//
// Es el mismo shader para los dos cuerpos del árbol a propósito: así no puede
// pasar que el de cerca y el de lejos se graden distinto y el relevo cambie de
// color a medio camino.
uniform float billboard : hint_range(0.0, 1.0) = 1.0;

// Uno invierte el desvanecido: en vez de aparecer con la distancia, desaparece.
// Lo usan las tablas de cerca, que son el relevo del impostor.
uniform float invert_fade : hint_range(0.0, 1.0) = 0.0;

// Cuánta hoja le queda al árbol, de 0 a 1.
//
// Uno es la copa llena y cero el árbol desnudo. NO es un tinte: baja el alfa de
// la copa, y como el recorte es a 0,35, lo primero que desaparece es el borde
// blando de la lámina -las hojas sueltas- y lo último la masa densa del centro,
// que es donde están las ramas. O sea que la copa se vacía DE FUERA HACIA
// DENTRO, que es como se cae la hoja.
//
// El pino no la usa: es perennifolio y se queda en uno todo el año. Quien
// decide qué especie la mueve es [Forest], no el shader.
uniform float hoja : hint_range(0.0, 1.0) = 1.0;

// De qué color es lo que queda cuando cae la hoja.
//
// Corteza mojada de abedul en invierno: ni negro ni blanco, un pardo grisáceo.
// El abedul tira a claro y por eso no se va a marrón oscuro.
uniform vec3 rama : source_color = vec3(0.42, 0.38, 0.34);

uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.2, 2.0) = 1.0;

varying vec2 v_local;
varying vec2 v_uv;
varying vec2 v_uv_top;
varying float v_flat;
varying float v_lit;


void vertex() {
	// El pie del árbol, ya en coordenadas de mundo.
	vec3 base = MODEL_MATRIX[3].xyz;
	// La lámina: ancho en x, alto en y, con el pie en cero. Viene ya con la
	// talla de esta instancia metida por su escala.
	vec3 card = VERTEX - base;

	vec3 to_eye = CAMERA_POSITION_WORLD - base;
	float reach = length(to_eye);
	vec2 flat_dir = to_eye.xz;
	float flat_len = max(length(flat_dir), 0.0001);
	flat_dir /= flat_len;

	// Se gira SÓLO alrededor del eje vertical. Un árbol no se tumba: si el
	// impostor siguiera a la cámara en los tres ejes, al mirar desde arriba el
	// bosque entero se echaría de espaldas y se vería el truco.
	// De lejos la lámina se gira hacia quien mira; de cerca se queda como la
	// puso la instancia, porque son tres cruzadas y girarlas las dejaría
	// solapadas en un solo plano.
	vec3 fixed_right = normalize((MODEL_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz
		+ vec3(0.0001, 0.0, 0.0));
	vec3 right = mix(fixed_right, vec3(flat_dir.y, 0.0, -flat_dir.x), billboard);
	vec3 up = vec3(0.0, 1.0, 0.0);

	// Y se inclina hacia atrás segun lo alta que esté la cámara, para no verse
	// de canto desde arriba.
	float above = clamp(to_eye.y / max(reach, 0.0001), 0.0, 1.0);
	vec3 toward = vec3(flat_dir.x, 0.0, flat_dir.y);
	float lean = above * lean_back * billboard;
	up = normalize(up * (1.0 - lean) + toward * lean);

	// TUMBARSE DEL TODO cuando se mira desde arriba, y enseñar la copa.
	//
	// Sólo el impostor: las tablas cruzadas de cerca se quedan como están, que
	// para eso son tres y no se ven de canto nunca.
	// `lying` y no `flat`: `flat` es palabra reservada de GLSL -es un
	// cualificador de interpolación- y usarla de nombre de variable hace que el
	// shader NO COMPILE. Godot entonces dibuja con el material blanco por
	// defecto, que es exactamente lo que se veía: un bosque de tablas blancas.
	float lying = smoothstep(top_from, top_to, above) * billboard;
	up = normalize(mix(up, toward, lying));

	// Y con la proporción de una copa, no la de un perfil: la instancia viene
	// escalada alta y estrecha, y tumbada así saldría una mancha alargada en
	// vez de una copa redonda.
	float wide = length(MODEL_MATRIX[0].xyz);
	float tall = max(length(MODEL_MATRIX[1].xyz), 0.001);
	float shape = mix(1.0, (wide / tall) * crown_gain, lying);

	// La `z` de la tabla cuenta cuando está cruzada: sin ella las tres caerían
	// en el mismo plano y el árbol de cerca sería una lámina.
	vec3 depth = normalize(cross(up, right));
	// Tumbada, la lámina se centra en el pie en vez de salir de él hacia
	// arriba: una copa vista de pájaro rodea al tronco, no cuelga de un lado.
	vec3 world = base + right * card.x
		+ up * (card.y * shape - tall * shape * 0.5 * lying)
		+ depth * card.z * (1.0 - billboard);
	v_flat = lying;

	// EL RELEVO ES UN CORTE, NO UN DESVANECIDO. Ni por sorteo de árbol en
	// árbol ni encogiendo la lámina: las dos formas de fundir el cambio dejan,
	// mientras dura la banda, una franja de bosque a medias -arbolitos sueltos
	// o copas encogidas- delante de la cámara, y eso se lee como que el bosque
	// se disuelve. Con un único radio, todo el bosque que lo cruza cambia de
	// cuerpo en el mismo fotograma: no hay banda que pueda notarse a medias.
	// EL IMPOSTOR NO SE ESCONDE NI SE ENCOGE NUNCA.
	//
	// Hacía las dos cosas y las dos se veían. Se apagaba dentro de `near_end`
	// para dejarle el sitio a la malla de verdad, y eso abría un CLARO alrededor
	// de la cámara —justo donde uno está mirando— cada vez que la malla no
	// estaba montada todavía. Y se encogía al acercarse a `far_end`, con lo que
	// el bosque del fondo se veía adelgazar según uno se alejaba.
	//
	// Ahora el impostor está siempre entero, de cero al borde del valle, y la
	// malla de verdad se dibuja ENCIMA dentro de su radio en vez de sustituirlo.
	// Un árbol de cerca es su impostor más su malla; no hay relevo que pueda
	// dejar un hueco.
	float far_side = step(near_end, reach);
	float alive = mix(1.0, 1.0 - far_side, invert_fade);
	world = base + (world - base) * alive;
	VERTEX = world;

	// La normal mira a la cámara pero muy inclinada hacia arriba: una copa es
	// un volumen, no una lámina, y con la normal plana el bosque parpadeaba
	// entre claro y oscuro al girar.
	NORMAL = normalize(up * 0.75 + toward * 0.25);

	// La celda del atlas de esta especie.
	float cells = float(atlas_grid);
	vec2 cell = vec2(mod(float(cell_index), cells),
		floor(float(cell_index) / cells));
	v_uv = (UV * 0.998 + 0.001 + cell) / cells;
	vec2 cell_up = vec2(mod(float(cell_top), cells),
		floor(float(cell_top) / cells));
	v_uv_top = (UV * 0.998 + 0.001 + cell_up) / cells;
	// La copa recibe más luz que el pie, que es lo que le da volumen a algo que
	// no lo tiene.
	v_lit = mix(0.72, 1.0, clamp(UV.y < 0.5 ? 1.0 : 0.35, 0.0, 1.0));
	// La UV de la lámina, sin desplazar a su celda: es la que dice qué parte
	// del árbol se está pintando. `v_uv` ya viene movida al atlas y no sirve.
	v_local = UV;
}


void fragment() {
	// Las dos fotos mezcladas: el perfil y la copa. Se muestrean las dos y se
	// funde en el fragmento, que es lo que hace que el paso de una a otra no
	// tenga costura.
	vec4 cut = mix(texture(atlas, v_uv), texture(atlas, v_uv_top), v_flat);

	// LA COPA es la mitad de arriba de la lámina de perfil -y la foto cenital
	// es copa entera-. El pie del árbol no pierde hoja porque no la tiene: es
	// tronco, y el tronco se queda en invierno.
	float copa = mix(smoothstep(0.62, 0.30, v_local.y), 1.0, v_flat);
	float desnudo = (1.0 - hoja) * copa;

	// Se cae la hoja: baja el alfa y el recorte va agujereando la copa desde el
	// borde. 0,42 y no menos porque por debajo de ahí no queda ni la rama.
	ALPHA = cut.a * mix(1.0, 0.42, desnudo);
	ALPHA_SCISSOR_THRESHOLD = 0.35;

	// Y lo que aguanta vira a corteza, que es lo que se ve de un abedul pelado.
	vec3 color = mix(cut.rgb * tint, rama, desnudo * 0.8);
	ALBEDO = color * brightness * v_lit;
	// La luz que cruza la copa. Ver `leaf_wrap`: sin esto la tabla que queda de
	// espaldas al sol se apaga del todo.
	BACKLIGHT = ALBEDO * leaf_wrap;
	ROUGHNESS = 0.92;
	SPECULAR = 0.05;
}
