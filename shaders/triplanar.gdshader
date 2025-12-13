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

// Muestrea una textura usando tri-planar mapping
vec4 triplanar_texture(sampler2D tex, vec3 pos, vec3 weights) {
	vec4 x_sample = texture(tex, pos.zy * texture_scale);
	vec4 y_sample = texture(tex, pos.xz * texture_scale);
	vec4 z_sample = texture(tex, pos.xy * texture_scale);
	return x_sample * weights.x + y_sample * weights.y + z_sample * weights.z;
}

// Muestrea un normal map usando tri-planar mapping
vec3 triplanar_normal(sampler2D tex, vec3 pos, vec3 weights) {
	vec3 x_normal = texture(tex, pos.zy * texture_scale).rgb * 2.0 - 1.0;
	vec3 y_normal = texture(tex, pos.xz * texture_scale).rgb * 2.0 - 1.0;
	vec3 z_normal = texture(tex, pos.xy * texture_scale).rgb * 2.0 - 1.0;
	
	// Reorientar normales para cada eje
	x_normal = vec3(x_normal.xy + world_normal.zy, abs(x_normal.z) * world_normal.x);
	y_normal = vec3(y_normal.xy + world_normal.xz, abs(y_normal.z) * world_normal.y);
	z_normal = vec3(z_normal.xy + world_normal.xy, abs(z_normal.z) * world_normal.z);
	
	return normalize(
		x_normal.zyx * weights.x +
		y_normal.xzy * weights.y +
		z_normal.xyz * weights.z
	);
}

void fragment() {
	vec3 triplanar_weights = get_triplanar_weights(world_normal, triplanar_sharpness);
	
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
	
	// Muestrear texturas con tri-planar
	vec4 sand_color = triplanar_texture(texture_sand, world_position, triplanar_weights);
	vec4 grass_color = triplanar_texture(texture_grass, world_position, triplanar_weights);
	vec4 rock_color = triplanar_texture(texture_rock, world_position, triplanar_weights);
	vec4 snow_color = triplanar_texture(texture_snow, world_position, triplanar_weights);
	
	// Combinar colores
	vec3 final_color = sand_color.rgb * sand_weight +
					   grass_color.rgb * grass_weight +
					   rock_color.rgb * rock_weight +
					   snow_color.rgb * snow_weight;
	
	// Muestrear y combinar normal maps
	vec3 sand_normal = triplanar_normal(normal_sand, world_position, triplanar_weights);
	vec3 grass_normal = triplanar_normal(normal_grass, world_position, triplanar_weights);
	vec3 rock_normal = triplanar_normal(normal_rock, world_position, triplanar_weights);
	vec3 snow_normal = triplanar_normal(normal_snow, world_position, triplanar_weights);
	
	vec3 final_normal = normalize(
		sand_normal * sand_weight +
		grass_normal * grass_weight +
		rock_normal * rock_weight +
		snow_normal * snow_weight
	);
	
	// Calcular roughness combinado
	float final_roughness = roughness_sand * sand_weight +
							roughness_grass * grass_weight +
							roughness_rock * rock_weight +
							roughness_snow * snow_weight;
	
	// Salidas del shader
	ALBEDO = final_color;
	NORMAL_MAP = final_normal * 0.5 + 0.5;
	ROUGHNESS = final_roughness;
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
