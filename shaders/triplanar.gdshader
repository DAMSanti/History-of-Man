shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Tri-planar terrain shader con blending por altura y pendiente
// Evita el estiramiento de texturas en pendientes pronunciadas

group_uniforms textures;
uniform sampler2D texture_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_snow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms normal_maps;
uniform sampler2D normal_grass : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_rock : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_snow : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_sand : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms texture_settings;
uniform float texture_scale : hint_range(0.01, 10.0) = 0.25;
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
uniform float roughness_grass : hint_range(0.0, 1.0) = 0.9;
uniform float roughness_rock : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_snow : hint_range(0.0, 1.0) = 0.7;
uniform float roughness_sand : hint_range(0.0, 1.0) = 0.95;

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

group_uniforms performance;
// Los normal maps duplican el numero de muestreos. Desactivarlos es la palanca
// mas directa para ganar frames en mundos grandes.
uniform bool use_normal_maps = true;
// Por debajo de este peso un material o un plano no aporta nada visible y se
// salta su muestreo.
uniform float weight_cutoff : hint_range(0.0, 0.1) = 0.02;

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
vec4 triplanar_texture(sampler2D tex, vec3 pos, vec3 dpdx, vec3 dpdy, vec3 weights, float cutoff) {
	float s = texture_scale;
	vec4 result = vec4(0.0);
	if (weights.x > cutoff) {
		result += textureGrad(tex, pos.zy * s, dpdx.zy * s, dpdy.zy * s) * weights.x;
	}
	if (weights.y > cutoff) {
		result += textureGrad(tex, pos.xz * s, dpdx.xz * s, dpdy.xz * s) * weights.y;
	}
	if (weights.z > cutoff) {
		result += textureGrad(tex, pos.xy * s, dpdx.xy * s, dpdy.xy * s) * weights.z;
	}
	return result;
}

// Igual que la anterior pero reorientando las normales de cada eje
vec3 triplanar_normal(sampler2D tex, vec3 pos, vec3 dpdx, vec3 dpdy, vec3 weights, float cutoff) {
	float s = texture_scale;
	vec3 result = vec3(0.0);
	if (weights.x > cutoff) {
		vec3 n = textureGrad(tex, pos.zy * s, dpdx.zy * s, dpdy.zy * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.zy, abs(n.z) * world_normal.x);
		result += n.zyx * weights.x;
	}
	if (weights.y > cutoff) {
		vec3 n = textureGrad(tex, pos.xz * s, dpdx.xz * s, dpdy.xz * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.xz, abs(n.z) * world_normal.y);
		result += n.xzy * weights.y;
	}
	if (weights.z > cutoff) {
		vec3 n = textureGrad(tex, pos.xy * s, dpdx.xy * s, dpdy.xy * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.xy, abs(n.z) * world_normal.z);
		result += n.xyz * weights.z;
	}
	return result;
}

void fragment() {
	vec3 triplanar_weights = get_triplanar_weights(world_normal, triplanar_sharpness);

	// Derivadas de la posicion de mundo, calculadas una sola vez y fuera de
	// cualquier rama. Las de cada plano salen de aqui con un swizzle.
	vec3 dpdx = dFdx(world_position);
	vec3 dpdy = dFdy(world_position);

	// Calcular pendiente (slope) - 1.0 = vertical, 0.0 = horizontal
	float slope = 1.0 - abs(world_normal.y);

	// Calcular factor de roca por pendiente
	float slope_rock_factor = smoothstep(slope_threshold - slope_blend, slope_threshold + slope_blend, slope);

	// Calcular pesos de materiales por altura
	float height = vertex_height_normalized;

	float sand_weight = smoothstep(sand_max_height, sand_max_height * 0.5, height);
	float grass_weight = smoothstep(sand_max_height * 0.8, sand_max_height, height) *
						 smoothstep(grass_max_height + 0.1, grass_max_height - 0.1, height);
	float rock_weight = smoothstep(rock_min_height - 0.1, rock_min_height + 0.1, height) *
						smoothstep(rock_max_height + 0.1, rock_max_height - 0.1, height);
	float snow_weight = smoothstep(snow_min_height - 0.1, snow_min_height + 0.1, height);

	// Aplicar factor de pendiente (pendientes pronunciadas = más roca)
	grass_weight *= (1.0 - slope_rock_factor);
	sand_weight *= (1.0 - slope_rock_factor);
	snow_weight *= (1.0 - slope_rock_factor * 0.5); // Nieve resiste más en pendientes
	rock_weight = max(rock_weight, slope_rock_factor);

	// Curvatura y manchas. Sin esto una ladera entera sale del mismo color,
	// porque pendiente y altitud apenas cambian a lo largo de ella.
	if (use_terrain_variation) {
		float curvature = UV2.x * 2.0 - 1.0;   // -1 convexo, +1 concavo
		float patch = (UV2.y - 0.5) * 2.0;

		float soil = 1.0 + curvature * curvature_influence + patch * macro_influence;
		float bare = 1.0 - curvature * curvature_influence - patch * macro_influence;

		grass_weight *= max(soil, 0.05);
		sand_weight *= max(soil * 0.6 + 0.4, 0.05);
		rock_weight *= max(bare, 0.05);

		// Un hondo suave acumula tierra, pero una vaguada marcada en ladera es
		// un barranco: cauce de temporal, escarbado hasta la roca. Hacen falta
		// las DOS condiciones, porque solo con la concavidad tambien saldria
		// de roca el fondo llano de un valle.
		float ravine = smoothstep(ravine_curvature, 1.0, curvature)
			* smoothstep(ravine_slope - 0.06, ravine_slope + 0.10, slope)
			* ravine_strength;
		if (ravine > 0.001) {
			grass_weight *= 1.0 - ravine;
			sand_weight *= 1.0 - ravine;
			rock_weight = max(rock_weight, ravine);
		}
	}

	// Normalizar pesos
	float total_weight = sand_weight + grass_weight + rock_weight + snow_weight;
	if (total_weight > 0.0) {
		sand_weight /= total_weight;
		grass_weight /= total_weight;
		rock_weight /= total_weight;
		snow_weight /= total_weight;
	}

	// Aplicar sharpness al blend
	sand_weight = pow(sand_weight, blend_sharpness);
	grass_weight = pow(grass_weight, blend_sharpness);
	rock_weight = pow(rock_weight, blend_sharpness);
	snow_weight = pow(snow_weight, blend_sharpness);

	// Re-normalizar después de sharpness
	total_weight = sand_weight + grass_weight + rock_weight + snow_weight;
	if (total_weight > 0.0) {
		sand_weight /= total_weight;
		grass_weight /= total_weight;
		rock_weight /= total_weight;
		snow_weight /= total_weight;
	}

	// Muestrear solo los materiales con peso apreciable. Antes se muestreaban
	// los cuatro siempre: 24 fetches por fragmento aunque tres de ellos
	// acabasen multiplicados por cero.
	float cut = weight_cutoff;
	vec3 final_color = vec3(0.0);
	vec3 final_normal = vec3(0.0);

	if (sand_weight > cut) {
		final_color += triplanar_texture(texture_sand, world_position, dpdx, dpdy, triplanar_weights, cut).rgb * sand_weight;
		if (use_normal_maps) {
			final_normal += triplanar_normal(normal_sand, world_position, dpdx, dpdy, triplanar_weights, cut) * sand_weight;
		}
	}
	if (grass_weight > cut) {
		final_color += triplanar_texture(texture_grass, world_position, dpdx, dpdy, triplanar_weights, cut).rgb * grass_weight;
		if (use_normal_maps) {
			final_normal += triplanar_normal(normal_grass, world_position, dpdx, dpdy, triplanar_weights, cut) * grass_weight;
		}
	}
	if (rock_weight > cut) {
		final_color += triplanar_texture(texture_rock, world_position, dpdx, dpdy, triplanar_weights, cut).rgb * rock_weight;
		if (use_normal_maps) {
			final_normal += triplanar_normal(normal_rock, world_position, dpdx, dpdy, triplanar_weights, cut) * rock_weight;
		}
	}
	if (snow_weight > cut) {
		final_color += triplanar_texture(texture_snow, world_position, dpdx, dpdy, triplanar_weights, cut).rgb * snow_weight;
		if (use_normal_maps) {
			final_normal += triplanar_normal(normal_snow, world_position, dpdx, dpdy, triplanar_weights, cut) * snow_weight;
		}
	}

	// Calcular roughness combinado
	float final_roughness = roughness_sand * sand_weight +
							roughness_grass * grass_weight +
							roughness_rock * rock_weight +
							roughness_snow * snow_weight;

	// --- Agua ------------------------------------------------------------
	// El color de vertice trae la hidrografia entera: rg el sentido de la
	// corriente, b si el agua esta quieta, a la lamina.
	float river = clamp(COLOR.a, 0.0, 1.0);
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

		// Grava y canto rodado en la ribera, donde el agua lame pero no cubre.
		// Sin esto el pasto llega hasta la lamina como si el rio no arrastrase
		// nada, y una orilla de rio es piedra suelta, no cesped.
		float shore = smoothstep(0.02, 0.30, river) * (1.0 - smoothstep(0.35, 0.70, river));
		final_color = mix(final_color, final_color * 1.18 + vec3(0.06), shore * 0.7);
		final_roughness = mix(final_roughness, 0.95, shore * 0.7);

		final_color = mix(final_color, water_color, river);
		// La espuma es aire y agua batidos: mucho mas mate que la lamina lisa
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
	ALBEDO = final_color;
	if (use_normal_maps && length(final_normal) > 0.001) {
		NORMAL_MAP = normalize(final_normal) * 0.5 + 0.5;
	}
	ROUGHNESS = final_roughness;
	METALLIC = 0.0;
	SPECULAR = specular_out;
}
