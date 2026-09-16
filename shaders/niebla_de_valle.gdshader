// La niebla de valle (GRAFICOS §7.4): nubes bajas con volumen en el fondo del valle.
//
// Se dibuja una caja con las caras de DENTRO (cull_front), para que se vea igual desde
// fuera y metida en ella, y se recorre el rayo de la camara dentro de la caja hasta lo
// que haya delante en el buffer de profundidad. En cada paso, la densidad: el perfil
// sobre el fondo del valle -horneado en `NieblaDeValle`, que es quien lo decide- por un
// ruido 3D que se mueve despacio.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D fondo_tex : filter_linear, repeat_disable;
uniform vec2 origen = vec2(0.0);
uniform float lado = 4096.0;
uniform float espesor = 60.0;
uniform float se_apaga = 120.0;
uniform vec3 caja_min = vec3(0.0);
uniform vec3 caja_max = vec3(1.0);
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color : source_color = vec3(0.80, 0.83, 0.86);
// Cuanto quita la niebla entera por metro. Con 0,004, 85 m de niebla -mirando desde la
// camara de gestion- dejan pasar un 71 %, y 300 m en horizontal un 30 %. Decision mirando
// capturas: con 0,006 y un tope de 0,82 el fondo del valle quedaba blanco (2026-09-16).
uniform float extincion = 0.004;
// Lo mas que tapa, por mucha niebla que se cruce: nunca tapa del todo.
uniform float tapa_como_mucho = 0.65;
uniform int pasos = 28;

// Ruido 3D de valor con la celda ACOTADA antes del hash: con coordenadas de miles de
// metros el hash sin acotar se queda sin decimales (ver `espuma_viva.gdshaderinc`).
float nv_hash(vec3 p) {
	p = mod(p, 289.0);
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float nv_ruido(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = nv_hash(i);
	float n100 = nv_hash(i + vec3(1.0, 0.0, 0.0));
	float n010 = nv_hash(i + vec3(0.0, 1.0, 0.0));
	float n110 = nv_hash(i + vec3(1.0, 1.0, 0.0));
	float n001 = nv_hash(i + vec3(0.0, 0.0, 1.0));
	float n101 = nv_hash(i + vec3(1.0, 0.0, 1.0));
	float n011 = nv_hash(i + vec3(0.0, 1.0, 1.0));
	float n111 = nv_hash(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

float densidad(vec3 p) {
	float fondo = texture(fondo_tex, (p.xz - origen) / lado).r;
	float sobre = p.y - fondo;
	float perfil = 1.0 - smoothstep(espesor, se_apaga, sobre);
	if (perfil <= 0.0) {
		return 0.0;
	}
	// Bancos de niebla que derivan: dos octavas grandes, y la de arriba mas rota.
	vec3 q = p * 0.006 + vec3(TIME * 0.01, 0.0, TIME * 0.006);
	float ruido = nv_ruido(q) * 0.65 + nv_ruido(q * 2.7 + 11.0) * 0.35;
	float rota = mix(0.9, 0.35, smoothstep(0.0, se_apaga, sobre));
	return perfil * smoothstep(0.25, 0.75, ruido + (1.0 - rota) * -0.3 + 0.2);
}

void fragment() {
	vec3 ojo = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);

	// Hasta donde mira: lo que hay delante en la escena.
	float bruto = texture(depth_texture, SCREEN_UV).r;
	vec4 vista = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, bruto, 1.0);
	vista.xyz /= vista.w;
	float hasta_la_escena = length(vista.xyz);

	// Donde entra y sale el rayo de la caja.
	vec3 inv = 1.0 / dir;
	vec3 t0 = (caja_min - ojo) * inv;
	vec3 t1 = (caja_max - ojo) * inv;
	vec3 tmin = min(t0, t1);
	vec3 tmax = max(t0, t1);
	float entra = max(max(max(tmin.x, tmin.y), tmin.z), 0.0);
	float sale = min(min(min(tmax.x, tmax.y), tmax.z), hasta_la_escena);
	if (sale <= entra || fuerza <= 0.0) {
		discard;
	}

	float paso = (sale - entra) / float(pasos);
	// Un desfase por pixel, para que los pasos no se lean como bandas.
	float desfase = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	float pasa = 1.0;
	for (int i = 0; i < pasos; i++) {
		vec3 p = ojo + dir * (entra + (float(i) + desfase) * paso);
		float d = densidad(p) * fuerza;
		if (d > 0.0) {
			pasa *= exp(-d * extincion * paso);
			if (pasa < 0.02) {
				break;
			}
		}
	}
	ALBEDO = color;
	ALPHA = min(1.0 - pasa, tapa_como_mucho);
}
