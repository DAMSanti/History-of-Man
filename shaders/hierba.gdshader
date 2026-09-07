shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_schlick_ggx;

// La alfombra de hierba. Cada brizna es un naipe de seis triángulos y aquí se
// decide todo: si sale, de qué talla, hacia dónde mira, cómo se inclina en la
// cuesta, de qué color y cuánto se mece.
//
// Va sobre una rejilla FIJA DEL MUNDO que sigue a la cámara, y llega hasta un
// radio y no más. Eso es lo que hace todo el mundo -Manor Lords lo enseña como
// dos ajustes, «densidad de hierba» y «distancia de hierba»- y aquí se llegó
// después de intentar evitarlo tres veces:
//
//   - sembrar el mapa entero: para tapar 16,8 km² a densidad de alfombra hacen
//     falta ocho millones de matas;
//   - anillos concéntricos: se veían los anillos;
//   - una rejilla de PANTALLA proyectada al suelo: la densidad salía perfecta
//     pero el reparto dependía de a dónde mirases, así que la hierba se cortaba
//     en recto al inclinar la cámara y las esquinas quedaban peladas.
//
// El error de fondo era creer que había que tapar más. No hay que tapar más:
// hay que hacer que el final NO SE VEA. Y eso se consigue con dos cosas, que
// son las que hacen los juegos que lo tienen bien:
//
//   1. LA BRIZNA SE TIÑE DEL COLOR DEL SUELO QUE PISA. Es lo que en Unreal se
//      hace con una Runtime Virtual Texture: el terreno deja su color en una
//      textura y la vegetación la lee. Aquí el color va horneado en
//      `terrain_tint`. Sin esto el borde canta aunque hagas el radio enorme,
//      porque pasas de mata amarilla a suelo pardo de golpe.
//   2. EN EL BORDE LA HIERBA SE ENCOGE, no desaparece. Se hunde en el suelo y
//      se funde con la textura, que ya es la misma pradera.

// El atlas de recortes: nueve plantas fotografiadas de nuestras propias matas.
// Lo hornea `scripts/tools/HierbaAtlas.gd`.
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
// Las mismas plantas vistas al ángulo al que se juega, para el quad TUMBADO. No
// vale la de perfil: una mata de perfil es un ochenta por ciento aire, y puesta
// en horizontal deja pasar el suelo entero.
uniform sampler2D atlas_top : source_color, filter_linear_mipmap, repeat_disable;
uniform int atlas_grid = 3;

// La altura del terreno en metros, tal cual la tiene el generador. Es lo que
// clava cada brizna al suelo sin que la CPU tenga que consultar nada.
uniform sampler2D terrain_height : filter_linear, repeat_disable;
// Dónde crece: uno donde hay hierba, cero en roca, agua y pendiente fuerte.
uniform sampler2D terrain_cover : filter_linear, repeat_disable;
// De qué color es el suelo en cada punto. La brizna se tiñe con esto, y ésa es
// la mitad de que el final de la alfombra no se vea.
uniform sampler2D terrain_tint : source_color, filter_linear, repeat_disable;
uniform vec2 terrain_origin = vec2(0.0);
uniform vec2 terrain_extent = vec2(4096.0);
// Medio texel: el mapa está muestreado en los VÉRTICES de la malla y una
// textura se lee en el centro de sus texeles.
uniform vec2 terrain_texel = vec2(0.0);
// Metros de mundo por texel del mapa de alturas, para sacar la pendiente.
uniform float terrain_step = 5.0;

// Hasta dónde llega la alfombra, en metros desde su centro, y en qué fracción
// del final se va encogiendo hasta desaparecer.
uniform float grass_radius = 90.0;
uniform float edge_fade : hint_range(0.05, 0.7) = 0.30;

// Píxeles de pantalla por radián: alto del viewport partido por dos veces la
// tangente del medio campo de visión. Lo refresca [GroundCover] cada fotograma.
//
// Con esto la brizna sabe CUÁNTO OCUPA EN PANTALLA, y ése es el único criterio
// honesto para apagarla. El anterior era la altura de la cámara en metros, y
// eso es siempre el número de alguien: habrá quien juegue pegado al suelo y
// quien juegue en modo gestión con la cámara arriba del todo, y un umbral en
// metros sólo está bien para uno de los dos. Los píxeles valen para todos, y
// además se ajustan solos si cambia la resolución o el campo de visión.
uniform float pixels_per_radian = 900.0;

// Por debajo de cuántos píxeles de alto una brizna deja de merecer la pena, y
// por debajo de cuántos desaparece del todo.
//
// Una mata que ocupa dos píxeles no se lee como hierba: se lee como ruido, y
// encima es la que peor se porta -parpadea al moverse, porque el recorte con
// alfa a ese tamaño entra y sale entre fotogramas-. Lo que cuenta el prado a esa
// escala es la textura del terreno.
// Estos dos números y el radio del disco compiten por matar la hierba, y el que
// gana tiene que ser EL RADIO: si gana el tamaño en píxeles, la alfombra se
// apaga antes de llegar a su borde y se desperdicia la mitad de las instancias.
//
// La cuenta, con un naipe de 0,46 m a 1080p y 60º: una brizna ocupa 430 /
// distancia píxeles. Con cuatro píxeles empezaba a encoger a los 107 m, antes
// de los 165 del disco. Con 2,6 aguanta hasta los 165 justos, que es donde el
// borde se hace cargo.
uniform float pixels_full : hint_range(1.0, 40.0) = 2.6;
uniform float pixels_gone : hint_range(0.2, 20.0) = 0.8;

// Separación de la rejilla en metros. Manda cuánto puede desviarse cada brizna
// de su punto sin que se abran claros.
uniform float spacing = 0.52;

// Talla del naipe en metros: ancho y alto. Es la talla REAL de una mata y no
// cambia con la distancia; lo que cuenta de lejos es la textura del terreno.
uniform vec2 card_size = vec2(0.52, 0.46);
uniform float size_jitter : hint_range(0.0, 0.9) = 0.40;

// Cuánto sigue la brizna a la PENDIENTE del terreno.
//
// El naipe tumbado la sigue entera -es una mancha de suelo, y horizontal sobre
// una ladera se clava en el monte por un lado y flota por el otro-. El de pie
// sólo en parte: una hierba en cuesta se inclina algo, pero no del todo, porque
// crece buscando la luz y no perpendicular al suelo.
uniform float slope_follow : hint_range(0.0, 1.0) = 0.35;

uniform float wind_strength : hint_range(0.0, 1.0) = 0.14;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.0;

// Por debajo de esta cobertura no sale nada.
uniform float cover_floor : hint_range(0.0, 1.0) = 0.12;

// Cuánto se aclara la brizna respecto al suelo del que toma el color. Algo por
// encima de uno, porque una hoja de pie recibe más luz que el suelo llano.
// Estaba en 1,18 y era un error: la brizna salía MÁS CLARA que el suelo del
// que toma el color, y encima el brillo de la forma la subía otro tanto -el
// atlas se hornea casi blanco, así que ese factor iba siempre al tope-. Entre
// las dos cosas, un cuarenta por ciento por encima del terreno. Por debajo de
// uno, que es lo que corresponde: un manto de hierba se hace sombra a sí mismo
// y es más oscuro que el suelo desnudo, no más claro.
uniform float tint_lift : hint_range(0.4, 2.0) = 0.88;
// Los dos extremos de la variación por brizna: hacia seco y hacia verde. Son
// DESVÍOS sobre el color del suelo, no colores absolutos, para que la mancha
// siga casando con el terreno se gradúe éste como se gradúe.
// Los desvíos van FLOJOS. Con los de antes -hasta un veintidós por ciento en un
// canal- la variación por brizna se comía el trabajo de haber medido el color
// del suelo: cada mata se iba por su lado y el conjunto ya no era del color del
// terreno. Lo que tiene que variar es el matiz, no el color.
uniform vec3 shift_dry : source_color = vec3(1.07, 1.01, 0.88);
uniform vec3 shift_green : source_color = vec3(0.93, 1.03, 0.88);
// Cuánto se oscurece el pie de la brizna. Es lo que la asienta en el suelo.
//
// Baja de 0,45 a 0,28 porque DOBLABA la oscuridad justo donde no hacía falta.
// Ésta es la sombra que la mata se hace a sí misma, y tiene sentido a pleno
// sol; en una ladera que ya está en sombra se suma a una zona sin luz y manda
// el pie de la hierba a negro. Con la luz de relleno puesta -ver
// `WorldEnvironmentSetup`- ya no hace falta tanta.
uniform float root_shade : hint_range(0.0, 1.0) = 0.28;

varying vec2 v_uv;
varying vec3 v_tint;
varying float v_up;
varying float v_flat;


// Ruido determinista a partir de una posición del mundo. Determinista importa:
// es lo que hace que la misma brizna en el mismo punto saque siempre los mismos
// números, y por tanto que la hierba no cambie al volver sobre tus pasos.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


vec2 terrain_uv(vec2 world_xz) {
	vec2 local = (world_xz - terrain_origin) / terrain_extent;
	return clamp(local, vec2(0.0), vec2(1.0)) * (1.0 - terrain_texel * 2.0)
		+ terrain_texel;
}


void vertex() {
	// El punto de la rejilla, ya en coordenadas del mundo: el nodo va
	// redondeado a la separación, así que estos puntos son siempre los mismos
	// por mucho que la cámara se mueva. De ahí que la hierba no repte.
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 card = VERTEX - base;
	float flatness = 1.0 - COLOR.r;

	float r1 = hash12(base.xz);
	float r2 = hash12(base.xz + vec2(37.7, 11.3));
	float r3 = hash12(base.xz + vec2(-19.1, 71.9));

	// Cada brizna se sale de la cuadrícula lo suyo, o se leería la rejilla.
	vec2 spot = base.xz + (vec2(r1, r2) - 0.5) * spacing * 1.6;

	vec2 uv = terrain_uv(spot);
	float cover = texture(terrain_cover, uv).r;
	float ground = texture(terrain_height, uv).r;

	// Vive si hay cobertura. El umbral lleva algo de azar para que el borde
	// entre pradera y roquedo salga deshilachado y no recortado con tijera.
	float r4 = hash12(base.xz + vec2(5.3, -47.1));
	float alive = step(max(cover_floor, r4 * 0.45), cover);

	// El borde de la alfombra: la brizna ENCOGE hasta hundirse en el suelo.
	//
	// Encoger y no desvanecer, y no es lo mismo. Ralear deja matas de talla
	// entera cada vez más separadas, y eso se lee como un prado pelándose. Al
	// encoger, la mata se mete en la textura del terreno -que ya es la misma
	// pradera y ya es del mismo color- y no hay borde que ver. Es lo que hacen
	// los sistemas de hierba que tienen esto bien resuelto.
	float from_centre = length(spot - NODE_POSITION_WORLD.xz);
	float edge = 1.0 - smoothstep(grass_radius * (1.0 - edge_fade),
		grass_radius, from_centre);
	// Al cuadrado: encogiendo linealmente, media corona se pasa con la hierba a
	// media altura y se lee como un aro de césped cortado. Al cuadrado baja
	// despacio al principio y se va deprisa al final.
	edge *= edge;

	// Y lo mismo por TAMAÑO EN PANTALLA: la brizna encoge cuando deja de ocupar
	// píxeles suficientes, mire desde donde mire la cámara.
	//
	// Esto sustituye al apagado por altura, y no es un refinamiento: es el
	// criterio correcto. Un umbral en metros supone una forma de jugar. Éste
	// vale para la cámara pegada al suelo, para la de modo gestión y para
	// cualquiera de las mil posiciones de en medio, porque lo que pregunta no es
	// «¿dónde está la cámara?» sino «¿se ve esta mata?».
	//
	// Y de paso arregla el borde del disco por su cuenta: al alejarte, las
	// briznas del fondo bajan del umbral antes que las de delante, así que la
	// alfombra se deshace de fuera hacia dentro en vez de acabar en un canto.
	float eye_reach = max(length(vec3(spot.x, ground, spot.y)
		- CAMERA_POSITION_WORLD), 0.01);
	float on_screen = card_size.y * pixels_per_radian / eye_reach;
	edge *= smoothstep(pixels_gone, pixels_full, on_screen);

	float grow = mix(1.0 - size_jitter, 1.0 + size_jitter * 0.6, r2);
	vec3 size = vec3(card_size.x, card_size.y, card_size.x) * grow * alive
		* edge;

	// Cada brizna mira a un lado. Los dos quads del naipe ya están cruzados,
	// así que con girar el conjunto basta para romper la repetición.
	float angle = r1 * 6.2831853;
	float sn = sin(angle);
	float cs = cos(angle);
	vec3 turned = vec3(card.x * cs - card.z * sn, card.y,
		card.x * sn + card.z * cs) * size;

	// El viento dobla la punta y deja el pie quieto, que es como se dobla una
	// hierba. Cuadrado para que la curva salga de caña y no de bisagra. Y sólo
	// al naipe de pie: el tumbado es una mancha de suelo y no se mece.
	//
	// Va ANTES de inclinar la brizna con la ladera, para que se doble respecto
	// a su propia caña: aplicado después, en una cuesta la empujaba contra el
	// monte y la metía dentro del terreno.
	float lean = card.y * card.y * (1.0 - flatness);
	float phase = TIME * wind_speed + spot.x * 0.22 + spot.y * 0.17;
	turned.xz += vec2(sin(phase), cos(phase * 0.73)) * wind_strength
		* lean * card_size.y;

	// Inclinada con la ladera. La normal del terreno sale del propio mapa de
	// alturas con dos lecturas más -hacia el este y hacia el sur-, que es tan
	// barato como se puede y sobra para esto.
	float east = texture(terrain_height,
		terrain_uv(spot + vec2(terrain_step, 0.0))).r;
	float south = texture(terrain_height,
		terrain_uv(spot + vec2(0.0, terrain_step))).r;
	vec3 ground_normal = normalize(vec3(
		ground - east, terrain_step, ground - south));
	vec3 lean_to = normalize(mix(vec3(0.0, 1.0, 0.0), ground_normal,
		mix(slope_follow, 1.0, flatness)));
	vec3 axis = cross(vec3(0.0, 1.0, 0.0), lean_to);
	float sine = length(axis);
	if (sine > 0.0001) {
		axis /= sine;
		float cosine = clamp(lean_to.y, -1.0, 1.0);
		turned = turned * cosine + cross(axis, turned) * sine
			+ axis * dot(axis, turned) * (1.0 - cosine);
	}

	// Tres centímetros hundida: apoyada justo en la cota, en cuanto el terreno
	// tiene un pliegue la brizna asoma flotando por debajo.
	VERTEX = vec3(spot.x, ground - 0.03, spot.y) + turned;

	// La normal es LA DEL SUELO, no la del cielo.
	//
	// Estaba apuntando hacia arriba, y ahí había medio problema del disco
	// visible: en una ladera en sombra el terreno sale oscuro y la hierba, con
	// la normal al cielo, salía a plena luz. Amarillo brillante sobre verde
	// oscuro, y el borde del radio cantando aunque el albedo casara. Una mata
	// de hierba recibe la luz que recibe el trozo de suelo donde está, así que
	// la normal tiene que ser la del terreno.
	//
	// No del todo, eso sí: se le deja algo de la cara del naipe para que las
	// matas no queden como una lámina plana y se distingan unas de otras.
	NORMAL = normalize(ground_normal * 0.82
		+ normalize(vec3(turned.x, 0.6, turned.z) + vec3(0.001)) * 0.18);

	// Celda del atlas. Cada una es una PLANTA DISTINTA -pasto, herbazal,
	// helecho, roseta-, no la misma girada: un prado no es un monocultivo.
	float cells = float(atlas_grid);
	float which = floor(r3 * cells * cells);
	vec2 cell_uv = vec2(mod(which, cells), floor(which / cells));
	// Un pelo de margen para que el mipmap no traiga hierba de la celda vecina.
	v_uv = (UV * 0.98 + 0.01 + cell_uv) / cells;

	// EL COLOR SALE DEL SUELO QUE PISA, no de una constante.
	//
	// Es la otra mitad de que el final de la alfombra no se vea, y es lo que
	// faltaba desde el principio: la hierba era pajiza y el suelo pardo oscuro,
	// así que el borde del radio se leía como una raya por mucho cuidado que se
	// pusiera en apagar la densidad. Tiñéndola con el color del terreno, la
	// brizna y el suelo son del mismo color POR CONSTRUCCIÓN y no hay salto que
	// disimular.
	//
	// Lo que varía por brizna es un DESVÍO -hacia seco o hacia verde- y no un
	// color absoluto, para que la mancha siga casando se gradúe el terreno como
	// se gradúe.
	vec3 soil = texture(terrain_tint, uv).rgb;
	float species = fract(which * 0.3819);
	v_tint = soil * tint_lift * mix(shift_dry, shift_green,
		clamp(r2 * r2 * 0.65 + species * 0.5, 0.0, 1.0))
		* mix(0.94, 1.06, fract(species * 7.3));

	// El quad tumbado viene marcado con el rojo del vértice a cero. No se le
	// aplica la sombra del pie: está a ras de suelo y quedaría negro justo en
	// la vista para la que existe.
	v_up = mix(0.9, clamp(card.y, 0.0, 1.0), COLOR.r);
	v_flat = flatness;
}


void fragment() {
	// Se leen los dos atlas y se mezcla, en vez de escoger con un `if`. Un
	// salto que no es uniforme dentro de un grupo de píxeles deja las derivadas
	// -y con ellas el mipmap- sin definir, y eso sale como una costura de ruido.
	vec4 cut = mix(texture(atlas, v_uv), texture(atlas_top, v_uv), v_flat);

	// Recorte duro en vez de transparencia: la hierba se ordena sola con el
	// buffer de profundidad y no hay que pagar mezcla ni ordenar nada.
	ALPHA = cut.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;

	// El atlas se hornea sin luz y bastante lavado, así que aporta la FORMA y
	// la variación dentro de la mata; el color lo pone el tinte, que viene del
	// suelo. Es lo que permite graduar el terreno y que la hierba lo siga sin
	// volver a hornear nada.
	// La forma modula POCO. Con un margen ancho, y sabiendo que el atlas se
	// hornea lavado -la luminancia del recorte ronda el 0,9-, este factor
	// trabajaba siempre cerca del tope y subía el color de toda la pradera.
	float shape = dot(cut.rgb, vec3(0.33));
	ALBEDO = v_tint * mix(0.92, 1.06, shape);
	ALBEDO *= mix(1.0 - root_shade, 1.0, smoothstep(0.0, 0.55, v_up));

	ROUGHNESS = 0.88;
	SPECULAR = 0.12;
}
