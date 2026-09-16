// Las nubes del mapa regional, CON VOLUMEN (GRAFICOS §3).
//
// Petición del usuario del 2026-09-16: «las nubes son un plano sobre el mapa regional,
// quiero que tengan volumen, altura». Lo de antes se pintaba en el propio relieve y por eso
// se leía pegado al suelo. Esto es una losa sobre la comarca —de `base` a `techo`— que se
// recorre paso a paso: las nubes se tapan entre ellas, se dan sombra y, al girar la cámara,
// se ven por delante del monte y no encima de él.
//
// Debajo sigue la calima lisa del relieve, que es la que garantiza que de lo no descubierto
// no se vea ni un río: estas nubes son el aspecto, no el tapado.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
// Lo visto de la comarca: 1 visto, 0 por descubrir. La misma textura que el relieve.
uniform sampler2D fog_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec2 fog_world_size = vec2(1.0, 1.0);
// El ruido de la nube, en tres dimensiones y sin costuras.
uniform sampler3D nube_tex : filter_linear, repeat_enable;
uniform float nube_m = 160.0;
uniform float viento = 0.0;
uniform vec3 caja_min = vec3(0.0);
uniform vec3 caja_max = vec3(1.0);
uniform vec3 color_al_sol : source_color = vec3(0.96, 0.96, 0.97);
uniform vec3 color_a_la_sombra : source_color = vec3(0.52, 0.54, 0.60);
uniform vec3 hacia_la_luz = vec3(-0.45, 0.72, -0.53);
// Cuánto quita de luz cada unidad de mundo de nube. **A la escala de la losa**: el paso de
// la marcha mide decenas de unidades, así que con 0,5 o 0,9 la primera muestra ya tapaba
// del todo y la nube salía como una sábana lisa (capturas del 2026-09-16).
uniform float espesor = 0.05;
uniform float umbral : hint_range(0.0, 1.0) = 0.33;
// La capa continua de debajo: por mucho claro que haya arriba, lo no descubierto queda
// tapado de nube y no de calima pelada (captura del 2026-09-16).
uniform float manto : hint_range(0.0, 1.0) = 0.07;
// **El usuario dijo que el coste no importa** (2026-09-16), así que la marcha es larga y la
// luz lleva tres catas.
uniform int pasos = 48;
uniform int pasos_de_luz = 3;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Cuánto se ha visto de la comarca en este punto: con las cinco muestras del relieve, para
// que el borde de la nube caiga donde el del mapa.
float nv_visto(vec2 xz) {
	vec2 uv = xz / max(fog_world_size, vec2(0.001));
	return clamp(texture(fog_tex, uv).r, 0.0, 1.0);
}

// La densidad de nube en un punto: el ruido, recortado por el umbral, por lo que queda por
// descubrir, y desvanecida arriba y abajo de la losa.
float nv_densidad(vec3 p) {
	float sin_ver = 1.0 - nv_visto(p.xz);
	if (sin_ver <= 0.01) {
		return 0.0;
	}
	float alto = (p.y - caja_min.y) / max(caja_max.y - caja_min.y, 0.001);
	// Base plana y cima redonda, como un cúmulo: entra deprisa por abajo y se deshace arriba.
	float perfil = smoothstep(0.0, 0.12, alto) * (1.0 - smoothstep(0.35, 1.0, alto));
	if (perfil <= 0.0) {
		return 0.0;
	}
	vec3 q = p / max(nube_m, 0.001) + vec3(viento * 0.02, 0.0, viento * 0.008);
	// LA FORMA, en grande: dónde hay banco y dónde claro. Sin esta escala se veía la tesela
	// del ruido en cuadrícula (captura del 2026-09-16).
	float forma = texture(nube_tex, q * 0.23 + vec3(11.0, 3.0, 7.0)).r;
	float densidad = max(forma - umbral, 0.0) / max(1.0 - umbral, 0.001) * perfil;
	// Y EL DETALLE, que come el borde de la nube: es lo que le quita cara de bola de humo.
	float detalle = texture(nube_tex, q * 3.1 + vec3(viento * 0.06, 0.0, 0.0)).r;
	densidad = max(densidad - (1.0 - detalle) * 0.45 * (1.0 - densidad), 0.0);
	// El manto de debajo, sólo en la mitad baja de la losa: los cúmulos crecen encima de él.
	float bajo = 1.0 - smoothstep(0.05, 0.45, alto);
	densidad = max(densidad, manto * bajo * perfil);
	return densidad * sin_ver;
}

void fragment() {
	vec3 ojo = INV_VIEW_MATRIX[3].xyz;
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);

	float bruto = texture(depth_texture, SCREEN_UV).r;
	vec4 vista = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, bruto, 1.0);
	vista.xyz /= vista.w;
	float hasta_la_escena = length(vista.xyz);

	vec3 inv = 1.0 / dir;
	vec3 t0 = (caja_min - ojo) * inv;
	vec3 t1 = (caja_max - ojo) * inv;
	vec3 tmin = min(t0, t1);
	vec3 tmax = max(t0, t1);
	float entra = max(max(max(tmin.x, tmin.y), tmin.z), 0.0);
	float sale = min(min(min(tmax.x, tmax.y), tmax.z), hasta_la_escena);
	if (sale <= entra) {
		discard;
	}

	float paso = (sale - entra) / float(pasos);
	float desfase = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 luz = normalize(hacia_la_luz);
	float pasa = 1.0;
	vec3 color = vec3(0.0);
	for (int i = 0; i < pasos; i++) {
		vec3 p = ojo + dir * (entra + (float(i) + desfase) * paso);
		float d = nv_densidad(p);
		if (d <= 0.0) {
			continue;
		}
		// LA SOMBRA PROPIA: cuánta nube hay entre este punto y la luz. Con varias catas, la
		// base de la nube se ve oscura y la cima encendida, que es lo que da el bulto.
		// Las catas van a distancias fijas de la LOSA —no del paso de la marcha, que cambia
		// con el ángulo—: así la sombra es la misma se mire desde donde se mire.
		float alto_de_la_losa = caja_max.y - caja_min.y;
		float tapa_la_luz = 0.0;
		for (int j = 1; j <= pasos_de_luz; j++) {
			float lejos = alto_de_la_losa * 0.12 * float(j) * float(j);
			tapa_la_luz += nv_densidad(p + luz * lejos) * lejos;
		}
		float iluminado = exp(-tapa_la_luz * espesor * 1.5);
		// Y algo de luz que rebota dentro de la nube: sin esto la sombra se va a negro.
		iluminado = max(iluminado, 0.08);
		vec3 aqui = mix(color_a_la_sombra, color_al_sol, iluminado);
		float se_queda = 1.0 - exp(-d * espesor * paso);
		color += aqui * se_queda * pasa;
		pasa *= 1.0 - se_queda;
		if (pasa < 0.02) {
			break;
		}
	}
	float tapa = 1.0 - pasa;
	if (tapa < 0.004) {
		discard;
	}
	ALBEDO = color / max(tapa, 0.001);
	ALPHA = tapa;
}
