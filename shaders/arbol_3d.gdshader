shader_type spatial;
// El árbol de cerca de los escalones Medio, Alto y Ultra: la malla 3D generada con
// EZ-Tree, corteza u hoja. GRAFICOS §7.1.
//
// EL RELEVO ES UN CORTE POR ÁRBOL, no una trama. Cada árbol es 3D si su pie está a
// menos de `radio_3d` de la cámara, e impostor si está más lejos: uno u otro, nunca
// los dos ni ninguno, así que no queda anillo sin árbol —el «aro» de la queja—.
//
// Se probó antes una trama de puntos repartida entre los dos, y se veía como un tamiz
// sobre las copas (captura del 2026-09-15); era además lo que ya había descartado el
// shader del bosque Mínimo, «se lee como que el bosque se disuelve».
//
// La distancia es a `ojo`, la cámara de verdad, que pone `Forest` cada fotograma: en
// el pase de sombras la «cámara» es la luz, y con ella el corte caía en otro sitio.
render_mode cull_disabled, diffuse_burley;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform bool es_hoja = false;
uniform float recorte = 0.5;
uniform float radio_3d = 40.0;
uniform vec3 ojo = vec3(0.0);
// El color de la especie, medido contra fotos: ver `Forest.COLOR_DE_ESPECIE`. En la hoja
// cambia con la estación; en la corteza es fijo.
uniform vec3 tint : source_color = vec3(1.0);
// Cuánto color propio le queda a la textura antes del tinte, de 0 (sólo su luz) a 1.
// Las texturas de ambientCG son de otro verde: para llevarlas al de aquí multiplicando
// hacía falta ×5 en rojo y azul, y todo lo que no era hoja pura —una rama blanca en el
// impostor— salía magenta. Con la textura casi en gris el tinte ES el color de la especie
// y la textura pone la luz y el dibujo. Decisión, no medida; el color sí se mide.
const float SATURACION = 0.3;
// Cuánta hoja queda en la estación, de 0 a 1: los caducos pelados en invierno.
uniform float hoja : hint_range(0.0, 1.0) = 1.0;

varying float v_distancia;
varying vec3 v_mundo;

float azar(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	// En un MultiMesh, MODEL_MATRIX ya lleva la transformación de la instancia: su
	// columna 3 es el pie de ESTE árbol.
	v_distancia = distance(ojo, MODEL_MATRIX[3].xyz);
	v_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Fuera del radio, el árbol entero se pliega a su pie: sin área, sin fragmentos.
	if (v_distancia >= radio_3d) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	c.rgb = mix(vec3(dot(c.rgb, vec3(0.2126, 0.7152, 0.0722))), c.rgb, SATURACION);
	if (es_hoja) {
		// La hoja que ya no está, por racimos y no por píxeles sueltos.
		if (azar(floor(v_mundo * 1.5)) > hoja) {
			discard;
		}
		ALBEDO = c.rgb * tint;
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = recorte;
		// La luz que cruza la hoja es DEL COLOR DE LA HOJA. Era un verde fijo, 0,22 · 0,26 ·
		// 0,12, que se sumaba a cualquier tinte: la copa salía verde lima en todas las
		// especies, y el otoño no llegaba a amarillo. Como `leaf_wrap` en `arbol_impostor`.
		BACKLIGHT = ALBEDO * 0.3;
		ROUGHNESS = 0.85;
	} else {
		ALBEDO = c.rgb * tint;
		ROUGHNESS = 0.95;
	}
}
