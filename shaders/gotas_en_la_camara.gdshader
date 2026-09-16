// El agua en la camara (GRAFICOS §7.4): gotas grandes y sueltas sobre la lente, cada una
// una lente pequeña que ve la escena del reves y nitida, con el borde oscuro y un brillo.
//
// Rehecho el 2026-09-16 con la imagen de referencia del usuario («el que tenemos es
// horroroso»): era un desenfoque gris con motas, que se leia como suciedad. Ahora el
// fondo queda casi limpio -algo desenfocado hacia los bordes- y el agua son las gotas.
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;

float gc_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Una capa de gotas en celdas de `celdas` por alto de pantalla. Devuelve cuanto es gota
// (0 a 1) y deja en `muestra` de donde ve la gota, y en `hacia_el_borde` lo cerca que
// esta el pixel del borde de la gota, de 0 en el centro a 1 en el borde.
float capa(vec2 p, float aspecto, float celdas, float hay, float semilla,
		out vec2 muestra, out float hacia_el_borde, out vec2 dentro) {
	vec2 g = p * celdas;
	vec2 celda = floor(g) + semilla;
	vec2 f = fract(g);
	muestra = vec2(0.0);
	hacia_el_borde = 1.0;
	dentro = vec2(0.0);
	if (gc_hash(celda) > hay) {
		return 0.0;
	}
	vec2 centro = 0.3 + 0.4 * vec2(gc_hash(celda + 1.3), gc_hash(celda + 7.1));
	// Una de cada tres, alargada y de lagrima: mas ancha abajo, donde se acumula el agua.
	float alargada = gc_hash(celda + 5.9) > 0.66 ? mix(1.3, 2.1, gc_hash(celda + 9.1)) : 1.0;
	// QUE QUEPA EN SU CELDA: una gota que se sale se corta en recto en el borde de la celda
	// (captura del 2026-09-16). Con el centro entre 0,3 y 0,7, 0,28 de alto como mucho.
	float radio = min(mix(0.12, 0.3, gc_hash(celda + 3.7)), 0.28 / alargada);
	vec2 d = f - centro;
	d.y /= alargada;
	d.x /= 1.0 + 0.3 * clamp(d.y / radio, -1.0, 1.0) * step(1.01, alargada);
	float r = length(d) / radio;
	float gota = 1.0 - smoothstep(0.9, 1.0, r);
	if (gota <= 0.0) {
		return 0.0;
	}
	// LA LENTE: ve un trozo mas grande de la escena, del reves, centrado en la gota.
	vec2 centro_en_pantalla = (floor(g) + centro) / celdas / vec2(aspecto, 1.0);
	muestra = centro_en_pantalla - (f - centro) / celdas / vec2(aspecto, 1.0) * 3.5;
	hacia_el_borde = r;
	dentro = d / radio;
	return gota;
}

void fragment() {
	float aspecto = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = SCREEN_UV * vec2(aspecto, 1.0);

	// El fondo, casi limpio: algo desenfocado hacia los bordes de la pantalla.
	float al_borde = smoothstep(0.25, 0.85, length((SCREEN_UV - 0.5) * vec2(aspecto, 1.0)));
	vec3 fondo = textureLod(pantalla, SCREEN_UV, 2.5 * al_borde * fuerza).rgb;

	// Dos capas: gotas grandes y pocas, y pequeñas algo mas numerosas.
	vec2 muestra_a; float borde_a; vec2 dentro_a;
	vec2 muestra_b; float borde_b; vec2 dentro_b;
	float a = capa(p, aspecto, 5.0, 0.42, 0.0, muestra_a, borde_a, dentro_a);
	float b = capa(p, aspecto, 11.0, 0.16, 57.0, muestra_b, borde_b, dentro_b);
	float gota = max(a, b);
	vec2 muestra = a >= b ? muestra_a : muestra_b;
	float borde = a >= b ? borde_a : borde_b;
	vec2 dentro = a >= b ? dentro_a : dentro_b;

	vec3 color = fondo;
	if (gota > 0.0) {
		vec3 lente = textureLod(pantalla, clamp(muestra, vec2(0.0), vec2(1.0)), 0.0).rgb;
		// Mas clara que el fondo, el borde oscuro y un brillo arriba a la izquierda.
		lente = lente * 1.08 + 0.04;
		lente *= mix(1.0, 0.45, smoothstep(0.55, 1.0, borde));
		float brillo = 1.0 - smoothstep(0.0, 0.28, length(dentro - vec2(-0.35, -0.45)));
		lente += vec3(0.55) * brillo;
		color = mix(fondo, lente, gota);
	}
	COLOR = vec4(color, fuerza);
}
