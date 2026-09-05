shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Tri-planar terrain shader con blending por altura y pendiente
// Evita el estiramiento de texturas en pendientes pronunciadas

// Ocho capas de material en tres arrays, en el orden de TerrainLayers.Layer:
//   0 pradera · 1 bosque · 2 roquedo · 3 canchal
//   4 cantos  · 5 arena  · 6 limo    · 7 nieve
//
// Antes eran ocho samplers sueltos para cuatro materiales -albedo y normal-, y
// anadir una capa significaba tocar el shader. Con arrays, anadir capas cuesta
// VRAM y no codigo, y sobre todo no cuesta MUESTREOS: se muestrean siempre las
// DOS capas de mas peso, sean ocho o veinte.
#define LAYERS 8

group_uniforms textures;
uniform sampler2DArray terrain_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray terrain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// R oclusion · G rugosidad · B metalico · A altura
uniform sampler2DArray terrain_orm : filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms texture_settings;
// Lado de la tesela de cada capa, en METROS de mundo. Antes habia una sola
// escala para las cuatro, que es lo que hacia imposible que un canto rodado y
// una mata de hierba tuviesen su tamano real a la vez.
uniform float layer_tile_m[LAYERS];
uniform float blend_sharpness : hint_range(0.1, 10.0) = 2.0;
uniform float triplanar_sharpness : hint_range(0.1, 10.0) = 3.0;

group_uniforms height_settings;
uniform float grass_max_height : hint_range(0.0, 1.0) = 0.5;
uniform float rock_min_height : hint_range(0.0, 1.0) = 0.4;
uniform float rock_max_height : hint_range(0.0, 1.0) = 0.75;
uniform float snow_min_height : hint_range(0.0, 1.0) = 0.7;
uniform float sand_max_height : hint_range(0.0, 1.0) = 0.2;
uniform float max_world_height : hint_range(1.0, 500.0) = 50.0;

group_uniforms slope_settings;
uniform float slope_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float slope_blend : hint_range(0.01, 1.0) = 0.2;

group_uniforms material_properties;
// La rugosidad ya no es una constante por material: viene en el canal verde del
// ORM, o sea que cambia DENTRO de la textura. Una piedra mojada en la sombra de
// una grieta y la misma piedra al sol no tienen el mismo acabado, y con una
// constante por capa eso no se puede decir.
uniform bool use_orm = true;
// Margen para retocar lo que traiga la textura sin volver a ingerirla.
uniform float roughness_scale : hint_range(0.2, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.8;
// Rugosidad cuando el ORM esta apagado -tier bajo-. Muy mate a proposito:
// ninguna superficie natural de este mapa refleja de forma especular.
uniform float roughness_fallback : hint_range(0.0, 1.0) = 0.93;

// Reflectancia especular del terreno. Estaba clavada a 0.3 dentro del fragment
// y era la causa del brillo metalico: tierra, hierba y roca son dielectricos
// MUY mates, y con reflejo de cielo activado un 0.3 sobre una ladera de normal
// suave se lee como plastico o metal pulido.
uniform float terrain_specular : hint_range(0.0, 1.0) = 0.08;

group_uniforms variation;
// UV2.x trae la curvatura del terreno (0.5 = plano, >0.5 concavo) y UV2.y una
// variacion de parche. Se calculan por VERTICE, asi que aqui no cuestan nada.
uniform bool use_terrain_variation = true;
// Cuanto empuja la curvatura el reparto hierba/roca. Lo concavo acumula suelo
// y humedad; lo convexo se erosiona y deja la roca a la vista.
uniform float curvature_influence : hint_range(0.0, 1.5) = 0.75;
// Cuanto varia el reparto de una mancha a otra
uniform float macro_influence : hint_range(0.0, 1.5) = 0.65;

// Barrancos a roca. Un barranco es concavo Y con pendiente: el agua lo escarba
// y se lleva el suelo hasta dejar la roca. Sin esto la curvatura hace lo
// contrario -lo concavo acumula tierra- y los barrancos salian de hierba, que
// es justo lo que no son.
uniform float ravine_curvature : hint_range(0.0, 1.0) = 0.30;
uniform float ravine_slope : hint_range(0.0, 1.0) = 0.16;
uniform float ravine_strength : hint_range(0.0, 1.0) = 0.9;

group_uniforms overlay;
// Capa de informacion que se pinta sobre el terreno: recursos conocidos,
// territorio reconocido. Llega como UNA textura del tamano del recuadro, con
// el color en rgb y la intensidad en alfa.
//
// Va aqui y no como nodos en el mundo porque la version con un disco por celda
// eran mas de veinte mil llamadas de dibujado y se comia los frames enteros.
// Asi cuesta un muestreo, y ademas queda pegada al relieve en vez de flotando.
uniform bool use_overlay = false;
uniform sampler2D overlay_tex : filter_linear, repeat_disable;
uniform vec2 overlay_world_size = vec2(1.0, 1.0);

group_uniforms region;
// UV2.x trae la mascara de region jugable. Fuera de ella el terreno se apaga:
// sigue siendo contexto geografico util, pero deja claro que no es tablero.
uniform bool use_region_mask = false;
// La mascara llega como textura y no por UV2 para poder CAMBIARLA en caliente:
// el area jugable depende de la cota del mar, y rehacer la malla en cada
// cambio de epoca costaria casi veinte segundos.
uniform sampler2D region_mask_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec2 region_world_size = vec2(1.0, 1.0);
uniform float outside_desaturation : hint_range(0.0, 1.0) = 0.85;
uniform float outside_dim : hint_range(0.0, 1.0) = 0.45;

group_uniforms rivers;
// Color y acabado del agua de los cauces. Llega por COLOR.a desde la malla:
// un plano de agua horizontal solo puede representar el tramo a nivel del mar,
// asi que el rio aguas arriba se pinta sobre el propio terreno.
uniform vec3 river_color : source_color = vec3(0.10, 0.22, 0.28);
uniform float river_roughness : hint_range(0.0, 1.0) = 0.06;
uniform float river_specular : hint_range(0.0, 1.0) = 0.5;
// Color del fondo, que se ve por la orilla donde la lamina es fina. Sin esto
// el rio es una cinta de color plano recortada sobre el terreno.
uniform vec3 river_shallow_color : source_color = vec3(0.24, 0.34, 0.30);
// Velocidad de la corriente, en metros por segundo del patron de ondas
uniform float water_flow_speed : hint_range(0.0, 6.0) = 1.4;
// Tamano de la onda, en metros
uniform sampler2D water_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
// Lado de la tesela de agua, en metros
uniform float water_tile_m : hint_range(1.0, 60.0) = 12.0;
uniform float water_normal_strength : hint_range(0.0, 2.0) = 0.6;
// Segunda capa, mas grande y mas lenta: da oleaje de fondo bajo el rizado
uniform float water_swell_tile_m : hint_range(4.0, 200.0) = 46.0;
// Espuma en los rapidos. Se mide como CAIDA AGUAS ABAJO -cuanto desciende el
// cauce en la direccion de la corriente- y no como pendiente del terreno: la
// orilla de un cauce encajado siempre es empinada, asi que con la pendiente a
// secas salia una franja blanca continua pegada a la ribera, que es justo lo
// que no es la espuma.
uniform float foam_fall : hint_range(0.0, 1.0) = 0.06;
uniform vec3 foam_color : source_color = vec3(0.82, 0.88, 0.90);
uniform sampler2D water_foam_tex : filter_linear_mipmap, repeat_enable;
// Tamano de las manchas de espuma, en metros
uniform float foam_tile_m : hint_range(1.0, 40.0) = 8.0;
// Lo rapido que baja la espuma respecto al agua. Por encima de 1 porque la
// espuma va en la lamina superficial, que corre mas que la media de la seccion.
uniform float foam_drift : hint_range(0.0, 3.0) = 1.35;

group_uniforms antitiling;
// Romper la rejilla de la textura repetida.
//
// Una tesela de cuatro metros sobre una ladera de un kilometro se repite
// doscientas cincuenta veces, y el ojo lee esa regularidad como un enrejado
// muchisimo antes que como hierba. Comprobado con la vista de diagnostico: en
// la de capa dominante el enrejado NO esta, o sea que no lo produce el reparto
// de materiales sino la textura.
//
// Las dos palancas de aqui cuestan aritmetica y NINGUN muestreo extra, que es
// lo que las hace viables: el shader ya iba justo. La alternativa buena
// -teselado estocastico, muestrear dos veces con giro y mezclar- cuesta el
// doble de fetches y se queda para el tier alto si esto no basta.

// 1. Desplazar las coordenadas con ruido de onda larga. Deshace la ALINEACION
//    de la rejilla: las teselas dejan de estar en filas y columnas.
uniform float warp_amount : hint_range(0.0, 8.0) = 2.6;
uniform float warp_scale_m : hint_range(4.0, 200.0) = 38.0;

// 2. Y lo que de verdad la mata: muestrear LA MISMA capa a una escala mucho
//    mayor y usarla para modular el color.
//
//    El desplazamiento solo mueve la rejilla; el contenido sigue siendo el
//    mismo parche repitiendose, y el ojo lo pilla igual. Esto cambia el
//    CONTENIDO: la copia grande aporta manchas claras y oscuras sacadas de la
//    propia fotografia, no de un ruido, asi que se parecen a lo que la textura
//    ya tiene. Y como el factor no es entero, el patron combinado tarda ocho
//    veces mas en repetirse.
//
//    Cuesta UN muestreo, y de un solo plano porque es una senal de onda larga.
uniform float macro_break : hint_range(0.0, 1.0) = 0.85;
uniform float macro_break_factor : hint_range(2.0, 20.0) = 7.7;

group_uniforms debug;
// Vista de diagnostico. 0 normal · 1 que capa manda en cada punto, como color
// plano · 2 albedo sin mezclar con nada, para mirar la teselacion sola.
//
// Existe porque «se ve una cuadricula» tiene al menos tres causas posibles -la
// textura que se repite, el reparto de capas, o la variacion de mancha- y
// mirando el terreno acabado no se distinguen. Pintando la capa dominante se
// distinguen en una captura.
uniform int debug_view : hint_range(0, 2) = 0;

group_uniforms performance;
// Los normal maps duplican el numero de muestreos. Desactivarlos es la palanca
// mas directa para ganar frames en mundos grandes.
uniform bool use_normal_maps = true;
// Por debajo de este peso un material o un plano no aporta nada visible y se
// salta su muestreo.
uniform float weight_cutoff : hint_range(0.0, 0.1) = 0.02;

// Corte de PLANO, aparte del de material y mucho mas agresivo.
//
// Son dos cosas distintas y por eso llevan dos numeros. Descartar un material
// se ve: es un color que desaparece de la mezcla. Descartar un plano no, porque
// el plano no aporta color propio sino la misma textura mirada desde otro eje,
// y su peso se reparte entre los que quedan (ver fragment). O sea que aqui se
// puede cortar donde alli no.
uniform float plane_cutoff : hint_range(0.0, 0.3) = 0.15;

varying vec3 world_position;
varying vec3 world_normal;
varying float vertex_height_normalized;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vertex_height_normalized = clamp(world_position.y / max_world_height, 0.0, 1.0);
}

// Calcula los pesos para tri-planar mapping
vec3 get_triplanar_weights(vec3 normal, float sharpness) {
	vec3 weights = abs(normal);
	weights = pow(weights, vec3(sharpness));
	weights = weights / (weights.x + weights.y + weights.z);
	return weights;
}

// Muestrea una textura usando tri-planar mapping, saltando los planos que no
// aportan. En terreno de heightmap la normal apunta casi siempre hacia arriba,
// asi que dos de los tres planos suelen tener peso cero.
//
// Se usa textureGrad y no texture porque dentro de control de flujo divergente
// el LOD implicito queda indefinido: las derivadas hay que calcularlas fuera
// de las ramas o el mipmap sale mal justo en los bordes entre materiales.
vec4 triplanar_texture(sampler2DArray tex, float layer, float tile,
		vec3 pos, vec3 dpdx, vec3 dpdy, vec3 weights) {
	float s = 1.0 / max(tile, 0.01);
	vec4 result = vec4(0.0);
	// Los pesos llegan ya recortados a cero por `plane_cutoff`, asi que basta
	// comparar contra cero: el plano que no aporta ni se pide.
	if (weights.x > 0.0) {
		result += textureGrad(tex, vec3(pos.zy * s, layer),
			dpdx.zy * s, dpdy.zy * s) * weights.x;
	}
	if (weights.y > 0.0) {
		result += textureGrad(tex, vec3(pos.xz * s, layer),
			dpdx.xz * s, dpdy.xz * s) * weights.y;
	}
	if (weights.z > 0.0) {
		result += textureGrad(tex, vec3(pos.xy * s, layer),
			dpdx.xy * s, dpdy.xy * s) * weights.z;
	}
	return result;
}

// Igual que la anterior pero reorientando las normales de cada eje
vec3 triplanar_normal(sampler2DArray tex, float layer, float tile,
		vec3 pos, vec3 dpdx, vec3 dpdy, vec3 weights) {
	float s = 1.0 / max(tile, 0.01);
	vec3 result = vec3(0.0);
	if (weights.x > 0.0) {
		vec3 n = textureGrad(tex, vec3(pos.zy * s, layer),
			dpdx.zy * s, dpdy.zy * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.zy, abs(n.z) * world_normal.x);
		result += n.zyx * weights.x;
	}
	if (weights.y > 0.0) {
		vec3 n = textureGrad(tex, vec3(pos.xz * s, layer),
			dpdx.xz * s, dpdy.xz * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.xz, abs(n.z) * world_normal.y);
		result += n.xzy * weights.y;
	}
	if (weights.z > 0.0) {
		vec3 n = textureGrad(tex, vec3(pos.xy * s, layer),
			dpdx.xy * s, dpdy.xy * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.xy, abs(n.z) * world_normal.z);
		result += n.xyz * weights.z;
	}
	return result;
}

// El ORM se muestrea por UN SOLO plano, el dominante, y no por los tres.
//
// No es un atajo sin criterio: oclusion y rugosidad son senales de baja
// frecuencia y de rango corto -no dibujan silueta, modulan luz-, asi que el
// error de proyectarlas por un solo eje en una ladera no se ve. Y el ahorro es
// grande, porque anadir el ORM en triplanar completo habria subido los
// muestreos por fragmento un cincuenta por ciento, que es justo lo que este
// shader no puede pagar.
// Muestreo por el plano dominante, para senales de onda larga que no dibujan
// silueta. Lo usan el ORM y la copia a escala grande del anti-teselado.
vec4 uniplanar(sampler2DArray tex, float layer, float tile, vec3 pos,
		vec3 dpdx, vec3 dpdy, vec3 weights) {
	float s = 1.0 / max(tile, 0.01);
	if (weights.y >= weights.x && weights.y >= weights.z) {
		return textureGrad(tex, vec3(pos.xz * s, layer), dpdx.xz * s, dpdy.xz * s);
	}
	if (weights.x >= weights.z) {
		return textureGrad(tex, vec3(pos.zy * s, layer), dpdx.zy * s, dpdy.zy * s);
	}
	return textureGrad(tex, vec3(pos.xy * s, layer), dpdx.xy * s, dpdy.xy * s);
}

vec4 uniplanar_albedo(float layer, float tile, vec3 pos, vec3 dpdx, vec3 dpdy,
		vec3 weights) {
	return uniplanar(terrain_albedo, layer, tile, pos, dpdx, dpdy, weights);
}

vec4 uniplanar_orm(float layer, float tile, vec3 pos, vec3 dpdx, vec3 dpdy,
		vec3 weights) {
	return uniplanar(terrain_orm, layer, tile, pos, dpdx, dpdy, weights);
}

// Devuelve DOS canales de una vez. La version anterior llamaba tres veces a un
// ruido escalar para armar el desplazamiento, y eso -mas un tinte por ruido a
// dos escalas- costaba 3,3 ms medidos. Con dos canales por llamada y sin el
// tinte, el desplazamiento sale por una fraccion de eso.
vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

vec2 value_noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 a = hash22(cell);
	vec2 b = hash22(cell + vec2(1.0, 0.0));
	vec2 c = hash22(cell + vec2(0.0, 1.0));
	vec2 d = hash22(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Un color por capa, para la vista de diagnostico
vec3 layer_color(int i) {
	if (i == 0) { return vec3(0.35, 0.70, 0.20); }  // pradera
	if (i == 1) { return vec3(0.08, 0.30, 0.10); }  // bosque
	if (i == 2) { return vec3(0.72, 0.72, 0.76); }  // roquedo
	if (i == 3) { return vec3(0.58, 0.46, 0.40); }  // canchal
	if (i == 4) { return vec3(0.90, 0.70, 0.30); }  // cantos
	if (i == 5) { return vec3(0.96, 0.88, 0.62); }  // arena
	if (i == 6) { return vec3(0.36, 0.26, 0.18); }  // limo
	return vec3(0.98, 0.98, 1.00);                  // nieve
}

void fragment() {
	vec3 triplanar_weights = get_triplanar_weights(world_normal, triplanar_sharpness);

	// Tirar los planos que no aportan y REPARTIR su peso entre los que quedan.
	//
	// El reparto es lo que permite que el corte sea agresivo. Sin el, el peso
	// descartado simplemente se pierde: la suma baja de 1 y el material se
	// oscurece, asi que el corte tenia que quedarse en 0.02 -un plano que
	// aporta un 2%- y a ese nivel casi no descarta nada. Medido en el sitio 56,
	// una ladera suave da pesos del orden de (0.05, 0.90, 0.05) y los TRES
	// planos pasaban el corte para aportar una veinteava parte cada uno.
	//
	// Con reparto, un plano al 15% se puede tirar entero y el color no cambia,
	// porque su peso se lo llevan los que sí se muestrean. El tope del rango es
	// 0.3 a proposito: los tres pesos suman 1, asi que por debajo de un tercio
	// siempre sobrevive al menos uno y la division nunca se queda sin nada.
	// El descarte se DESVANECE, no corta en seco. Con un `step` puro salian
	// manchas planas de borde duro por toda la ladera: al cruzar el umbral el
	// plano desaparecia de golpe, los pesos de los otros dos pegaban un salto
	// para repartirse el suyo, y el cambio de textura dibujaba la linea de
	// nivel del umbral en el monte.
	//
	// Asi el peso baja suave hasta cero en la mitad inferior del margen y solo
	// se salta el muestreo cuando ya vale cero exacto. Se sigue ahorrando en
	// todo lo que cae por debajo de la mitad del corte, que es la mayor parte,
	// y la transicion no se ve.
	triplanar_weights *= smoothstep(
		vec3(plane_cutoff * 0.5), vec3(plane_cutoff), triplanar_weights);
	triplanar_weights /= max(
		triplanar_weights.x + triplanar_weights.y + triplanar_weights.z, 0.0001);

	// Derivadas de la posicion de mundo, calculadas una sola vez y fuera de
	// cualquier rama. Las de cada plano salen de aqui con un swizzle.
	//
	// Se sacan de la posicion SIN deformar, a proposito: el desplazamiento de
	// abajo es de onda larga, asi que apenas cambia la derivada, y usar la
	// deformada solo serviria para que el nivel de mipmap diese bandazos.
	vec3 dpdx = dFdx(world_position);
	vec3 dpdy = dFdy(world_position);

	// Posicion con la que se TEXTURA, desplazada para que la rejilla de la
	// tesela deje de ser una rejilla. Dos ruidos a distinta escala y girados
	// entre si; con uno solo el desplazamiento tiene direccion y se lee como un
	// estirado.
	vec3 tex_position = world_position;
	if (warp_amount > 0.001) {
		vec2 offset = (value_noise2(world_position.xz / max(warp_scale_m, 1.0))
			- 0.5) * (warp_amount * 2.0);
		tex_position.xz += offset;
	}

	// Calcular pendiente (slope) - 1.0 = vertical, 0.0 = horizontal
	float slope = 1.0 - abs(world_normal.y);
	float height = vertex_height_normalized;

	// Curvatura y mancha, por VERTICE, asi que aqui no cuestan nada.
	// UV2.x trae la curvatura (0.5 plano, >0.5 concavo) y UV2.y la variacion.
	float curvature = 0.0;
	float patch = 0.0;
	if (use_terrain_variation) {
		curvature = UV2.x * 2.0 - 1.0;
		patch = (UV2.y - 0.5) * 2.0;
	}

	// El agua del cauce llega por COLOR.a. La orilla -donde el agua lame pero
	// no cubre- es donde se acumulan los CANTOS, y por eso es una capa de
	// material y ya no un tinte falso sobre la hierba.
	float river = clamp(COLOR.a, 0.0, 1.0);
	float shore = smoothstep(0.02, 0.30, river)
		* (1.0 - smoothstep(0.35, 0.70, river));

	// --- Reparto entre las ocho capas ------------------------------------
	//
	// Tres bandas de altura, y dentro de cada una un reparto por lo que
	// distingue de verdad a las dos capas que la comparten. La altura sola no
	// separa pasto de bosque ni arena de marisma: eso lo dicen la pendiente y
	// la curvatura.
	// El borde de la orilla se separa de cero a la fuerza. Con `bands_relative`
	// -que es lo que usa el mapa local- `sand_max_height` sale practicamente 0,
	// y un `smoothstep(0.0, 0.0, x)` tiene los dos bordes iguales, que en GLSL
	// es COMPORTAMIENTO INDEFINIDO. De ahi salia limo de marisma repartido por
	// media ladera.
	float shore_edge = max(sand_max_height, 0.004);
	float band_low = 1.0 - smoothstep(shore_edge * 0.5, shore_edge, height);
	float band_mid = smoothstep(shore_edge * 0.5, shore_edge, height)
		* smoothstep(grass_max_height + 0.1, grass_max_height - 0.1, height);
	float band_top = smoothstep(snow_min_height - 0.1, snow_min_height + 0.1, height);

	// Roca por pendiente, en DOS escalones. El suave es el manto de derrubio
	// que baja de la pared -el canchal- y el fuerte es la pared en si. Antes
	// habia un solo escalon y la transicion se pintaba como un degradado de
	// color; ahora es un material propio, que es lo que de verdad hay ahi.
	float scree_factor = smoothstep(slope_threshold - slope_blend,
		slope_threshold + slope_blend, slope);
	float cliff_factor = smoothstep(slope_threshold + slope_blend * 0.5,
		slope_threshold + slope_blend * 2.5, slope);

	// Un hondo suave acumula tierra, pero una vaguada marcada en ladera es un
	// barranco: cauce de temporal escarbado hasta la roca. Hacen falta las DOS
	// condiciones, porque solo con la concavidad tambien saldria de roca el
	// fondo llano de un valle.
	float ravine = smoothstep(ravine_curvature, 1.0, curvature)
		* smoothstep(ravine_slope - 0.06, ravine_slope + 0.10, slope)
		* ravine_strength;

	// Lo concavo y humedo cria bosque; lo convexo y expuesto, pasto. La mancha
	// de UV2.y rompe la homogeneidad para que una ladera entera no salga de un
	// solo material.
	// El reparto pradera/bosque iba con un `clamp`, y un clamp SATURA: en casi
	// todo el mapa valia 0 o 1, asi que el paso de uno a otro era un escalon con
	// forma organica pero borde duro. Con `smoothstep` sobre un margen ancho la
	// mezcla ocupa una franja de verdad y el bosque se deshilacha en el prado,
	// que es lo que hace un bosque.
	float wood_raw = curvature * curvature_influence + patch * macro_influence;
	float wood = smoothstep(-0.55, 0.55, wood_raw);

	// La marisma se queda en lo hondo y lo LLANO: un limo no se sostiene en
	// pendiente. Sin la condicion de pendiente el fango trepaba por la ladera
	// de la ria.
	float marsh = smoothstep(0.05, 0.35, curvature)
		* (1.0 - smoothstep(0.04, 0.12, slope));

	float ground = 1.0 - max(scree_factor, ravine);

	float w[LAYERS];
	w[0] = band_mid * (1.0 - wood) * ground;              // pradera
	w[1] = band_mid * wood * ground;                      // bosque
	w[2] = max(cliff_factor, ravine);                     // roquedo
	w[3] = max(scree_factor - cliff_factor, 0.0);         // canchal
	w[4] = shore;                                         // cantos de rio
	w[5] = band_low * (1.0 - marsh) * ground;             // arena
	w[6] = band_low * marsh * ground;                     // limo
	w[7] = band_top * (1.0 - scree_factor * 0.5);         // nieve

	// Recortar la cola y renormalizar. Es lo que permite quedarse con las dos
	// de mas peso sin que se vea el cambio: una capa que iba a entrar por un
	// dos por ciento llega a cero ANTES de cruzarse con otra, asi que cuando se
	// intercambian el segundo y el tercer puesto los dos valen ya cero y no hay
	// salto. Sin esto, quedarse con dos capas dibuja costuras donde la tercera
	// y la cuarta se adelantan.
	float total = 0.0;
	for (int i = 0; i < LAYERS; i++) {
		w[i] = max(w[i] - weight_cutoff, 0.0);
		total += w[i];
	}
	if (total <= 0.0) {
		// Todo por debajo del corte: se cae a pradera, que es el fondo del
		// valle y el material mas comun.
		w[0] = 1.0;
		total = 1.0;
	}

	// Las DOS de mas peso. Es lo que hace que ocho capas cuesten lo mismo que
	// dos: el bucle es aritmetica sobre ocho flotantes -barata y sin
	// divergencia- y los muestreos son siempre dos, no ocho.
	int i0 = 0;
	int i1 = 0;
	float w0 = -1.0;
	float w1 = -1.0;
	for (int i = 0; i < LAYERS; i++) {
		float wi = w[i];
		if (wi > w0) {
			i1 = i0; w1 = w0;
			i0 = i; w0 = wi;
		} else if (wi > w1) {
			i1 = i; w1 = wi;
		}
	}
	float pair = max(w0 + w1, 0.0001);
	w0 /= pair;
	w1 /= pair;

	// Endurecer la mezcla entre las dos. Se hace AQUI, sobre dos numeros, y no
	// con una potencia sobre los ocho pesos: son ocho `pow` por fragmento que
	// no hacen falta.
	float sharp = clamp((blend_sharpness - 1.0) * 0.5, 0.0, 1.0);
	w1 = mix(w1, w1 * w1 * (3.0 - 2.0 * w1), sharp);
	w0 = 1.0 - w1;

	float layer0 = float(i0);
	float layer1 = float(i1);
	float tile0 = layer_tile_m[i0];
	float tile1 = layer_tile_m[i1];

	vec3 final_color = triplanar_texture(terrain_albedo, layer0, tile0,
		tex_position, dpdx, dpdy, triplanar_weights).rgb * w0;
	vec3 final_normal = vec3(0.0);
	if (use_normal_maps) {
		final_normal = triplanar_normal(terrain_normal, layer0, tile0,
			tex_position, dpdx, dpdy, triplanar_weights) * w0;
	}

	float final_roughness = roughness_fallback;
	float occlusion = 1.0;
	float surface_height = 0.5;
	if (use_orm) {
		vec4 orm0 = uniplanar_orm(layer0, tile0, tex_position,
			dpdx, dpdy, triplanar_weights);
		final_roughness = orm0.g * w0;
		occlusion = orm0.r * w0;
		surface_height = orm0.a * w0;
	}

	// La segunda capa solo si aporta. Por debajo de un dos por ciento no se
	// distingue de no estar, y saltarsela ahorra la mitad de los muestreos en
	// todo lo que no es transicion, que es la mayor parte del mapa.
	if (w1 > 0.02) {
		final_color += triplanar_texture(terrain_albedo, layer1, tile1,
			tex_position, dpdx, dpdy, triplanar_weights).rgb * w1;
		if (use_normal_maps) {
			final_normal += triplanar_normal(terrain_normal, layer1, tile1,
				tex_position, dpdx, dpdy, triplanar_weights) * w1;
		}
		if (use_orm) {
			vec4 orm1 = uniplanar_orm(layer1, tile1, tex_position,
				dpdx, dpdy, triplanar_weights);
			final_roughness += orm1.g * w1;
			occlusion += orm1.r * w1;
			surface_height += orm1.a * w1;
		}
	} else if (use_orm) {
		// Con una sola capa los pesos no suman 1 y todo saldria oscuro y liso
		float inv = 1.0 / max(w0, 0.0001);
		final_roughness *= inv;
		occlusion *= inv;
		surface_height *= inv;
	}

	if (use_orm) {
		final_roughness = clamp(final_roughness * roughness_scale, 0.04, 1.0);
	}

	// La copia a escala grande de la MISMA capa. Ver `macro_break`.
	//
	// Se mezcla como "overlay" y no multiplicando: multiplicar solo oscurece y
	// el terreno se apaga entero, mientras que overlay aclara donde la copia
	// grande es clara y oscurece donde es oscura, que es lo que hace que unas
	// manchas se lean mas secas y otras mas verdes sin cambiar el brillo medio.
	if (macro_break > 0.001) {
		vec3 wide = uniplanar_albedo(layer0, tile0 * macro_break_factor,
			tex_position, dpdx, dpdy, triplanar_weights).rgb;
		vec3 overlay = mix(2.0 * final_color * wide,
			1.0 - 2.0 * (1.0 - final_color) * (1.0 - wide),
			step(vec3(0.5), final_color));
		final_color = mix(final_color, overlay, macro_break);
	}

	// --- Agua ------------------------------------------------------------
	// El color de vertice trae la hidrografia entera: rg el sentido de la
	// corriente, b si el agua esta quieta, a la lamina. `river` ya se calculo
	// arriba, porque de el sale la orilla de cantos.
	float specular_out = terrain_specular;

	if (river > 0.005) {
		vec2 flow = COLOR.rg * 2.0 - 1.0;
		float still = COLOR.b;
		float flow_len = length(flow);
		// Sin direccion util -laguna, o celda suelta- se usa un eje fijo, que
		// con velocidad cero da agua quieta y no un patron desfilando
		vec2 dir = flow_len > 0.01 ? flow / flow_len : vec2(1.0, 0.0);

		float speed = water_flow_speed * (1.0 - still);

		// Flow map: la textura se arrastra en la direccion de la corriente y
		// se reinicia cada ciclo. Para que el salto no se vea, se muestrean
		// DOS fases desfasadas media vuelta y se cruzan segun avanza el ciclo:
		// mientras una se reinicia la otra esta en su punto mas estable.
		//
		// Esto sustituye a los senos analiticos que habia aqui. Aquello daba
		// galones y espinas de pescado, porque la direccion de la corriente se
		// interpola por fragmento y en la orilla, donde los vertices tienen
		// flujo cero, la fase pegaba bandazos de un pixel al siguiente.
		float cycle = TIME * speed / max(water_tile_m, 1.0);
		float phase_a = fract(cycle);
		float phase_b = fract(cycle + 0.5);
		float cross_fade = abs(1.0 - 2.0 * phase_a);

		vec2 base_uv = world_position.xz / max(water_tile_m, 1.0);
		vec3 n_a = texture(water_normal_tex, base_uv - dir * phase_a).rgb * 2.0 - 1.0;
		vec3 n_b = texture(water_normal_tex, base_uv - dir * phase_b).rgb * 2.0 - 1.0;
		vec3 ripple = mix(n_a, n_b, cross_fade);

		// Oleaje de fondo: misma tesela mucho mas grande y mas lenta, para que
		// el rio no sea un patron unico repetido
		float swell_cycle = TIME * speed * 0.35 / max(water_swell_tile_m, 1.0);
		vec2 swell_uv = world_position.xz / max(water_swell_tile_m, 1.0);
		vec3 swell = texture(water_normal_tex,
			swell_uv - dir * fract(swell_cycle)).rgb * 2.0 - 1.0;

		vec3 water_normal = normalize(vec3(
			(ripple.xy + swell.xy * 0.7) * water_normal_strength, 1.0));

		// La lamina fina deja ver el fondo; el centro del cauce es mas hondo
		float depth = smoothstep(0.15, 0.85, river);
		vec3 water_color = mix(river_shallow_color, river_color, depth);

		// Rapidos: cuanto DESCIENDE el cauce en la direccion de la corriente.
		// Se saca de la normal del terreno proyectada sobre el flujo, asi que
		// no cuesta ningun dato extra en la malla.
		float fall = -(world_normal.x * dir.x + world_normal.z * dir.y)
			/ max(abs(world_normal.y), 0.05);
		float rapids = smoothstep(foam_fall, foam_fall * 4.0, fall)
			* (1.0 - still) * depth;

		// La espuma VIAJA. Antes era una funcion fija de la pendiente, o sea
		// una mancha blanca clavada en el sitio mientras el agua corria por
		// debajo, que es justo lo que no hace la espuma. Ahora son manchas que
		// bajan con la corriente, y algo mas rapido que ella porque van en la
		// lamina superficial.
		//
		// Dos capas a distinta escala y velocidad: una sola se lee como un
		// patron repetido desfilando.
		vec2 foam_uv = world_position.xz / max(foam_tile_m, 1.0);
		float drift = TIME * speed * foam_drift / max(foam_tile_m, 1.0);
		float churn_a = texture(water_foam_tex, foam_uv - dir * fract(drift)).r;
		float churn_b = texture(water_foam_tex,
			foam_uv * 1.9 - dir * fract(drift * 1.7 + 0.37)).r;
		float churn = clamp(churn_a * 0.65 + churn_b * 0.55, 0.0, 1.0);

		// En el rapido fuerte la espuma cubre casi entero; en el suave solo
		// asoman las vetas. Por eso la turbulencia no multiplica sin mas: se
		// mezcla hacia 1 segun crece el rapido.
		float foam = rapids * mix(churn, 1.0, rapids * 0.55);
		water_color = mix(water_color, foam_color, foam * 0.80);

		// Aqui habia un tinte que aclaraba el pasto de la ribera para fingir
		// grava. Ya no hace falta: la orilla es la capa CANTOS, con su
		// fotogrametria de canto rodado, y se reparte con las demas como
		// cualquier otro material.

		final_color = mix(final_color, water_color, river);
		// La espuma es aire y agua batidos: mucho mas mate que la lamina lisa
		final_roughness = mix(final_roughness,
			mix(river_roughness, 0.70, foam), river);
		specular_out = mix(specular_out, river_specular, river);
		final_normal = mix(final_normal, water_normal, river);
	}

	// Fuera de la region jugable: desaturar y oscurecer
	if (use_region_mask) {
		vec2 mask_uv = world_position.xz / max(region_world_size, vec2(0.001));
		float outside = 1.0 - clamp(texture(region_mask_tex, mask_uv).r, 0.0, 1.0);
		if (outside > 0.001) {
			float grey = dot(final_color, vec3(0.299, 0.587, 0.114));
			final_color = mix(final_color, vec3(grey), outside * outside_desaturation);
			final_color *= mix(1.0, 1.0 - outside_dim, outside);
		}
	}

	// Overlay de informacion. Va al final, DESPUES del agua y de la mascara de
	// region: es una capa de lectura del jugador, no un material del mundo, y
	// tiene que verse igual sobre el rio que sobre la ladera.
	if (use_overlay) {
		vec2 overlay_uv = world_position.xz / max(overlay_world_size, vec2(0.001));
		if (overlay_uv.x >= 0.0 && overlay_uv.x <= 1.0
				&& overlay_uv.y >= 0.0 && overlay_uv.y <= 1.0) {
			vec4 layer = texture(overlay_tex, overlay_uv);
			// Se mezcla sin tapar del todo: hay que seguir viendo el relieve
			// que hay debajo, porque la informacion es DONDE, no QUE color
			final_color = mix(final_color, layer.rgb, layer.a * 0.62);
		}
	}

	// Salidas del shader
	if (debug_view == 1) {
		final_color = mix(layer_color(i0), layer_color(i1), w1);
	} else if (debug_view == 2) {
		final_normal = vec3(0.0, 0.0, 1.0);
	}

	ALBEDO = final_color;
	// La oclusion va a AO y NO multiplicando el albedo. Multiplicar el color
	// oscurece DOS veces lo que ya esta en sombra -la luz directa tambien
	// cae-, y el terreno se iba a negro en cuanto la ladera daba la espalda al
	// sol. Con AO_LIGHT_AFFECT a cero la oclusion solo toca la luz indirecta,
	// que es la unica que una grieta puede tapar.
	if (use_orm) {
		AO = mix(1.0, occlusion, ao_strength);
		AO_LIGHT_AFFECT = 0.0;
	}
	if (use_normal_maps && length(final_normal) > 0.001) {
		NORMAL_MAP = normalize(final_normal) * 0.5 + 0.5;
	}
	ROUGHNESS = final_roughness;
	METALLIC = 0.0;
	SPECULAR = specular_out;
}
