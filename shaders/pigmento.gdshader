shader_type canvas_item;
render_mode blend_mix, unshaded;

// Ocre y carbon pintados sobre piel, no texto de color.
//
// Un pigmento no cubre como la tinta de una impresora: se mete en el poro del
// soporte y SALTA donde la piel esta alta. Por eso el trazo se rompe por los
// bordes y tiene el tono manchado por dentro. Eso es lo que hace la diferencia
// entre «un texto naranja» y «algo pintado con ocre».
//
// Va sobre la cobertura del glifo, asi que sirve igual para una letra, una
// linea o un icono: lo unico que lee es el alfa que le llega.

// El grano del soporte, leido en pixeles de PANTALLA y no del glifo: asi el
// poro es continuo a lo largo de toda una linea de texto, como lo seria en una
// piel de verdad, y no se repite dentro de cada letra.
uniform sampler2D grano : filter_linear, repeat_enable;

// Lado de la textura de grano, en pixeles. Manda el tamano del poro.
uniform float lado = 160.0;

// Cuanto se come el poro el borde del trazo. Cero es tinta de impresora.
uniform float mordiente : hint_range(0.0, 1.0) = 0.55;

// Cuanta pintura llevaba el dedo. Sube la carga y el trazo vuelve a cerrarse:
// es la diferencia entre el ocre amasado con grasa y el carbon seco.
uniform float carga : hint_range(0.0, 1.0) = 0.12;

// Variacion de tono DENTRO del trazo. Es lo que impide que parezca un relleno.
uniform float veteado : hint_range(0.0, 1.0) = 0.35;


void fragment() {
	vec4 c = COLOR * texture(TEXTURE, UV);

	// Dos frecuencias: la gruesa es la veta de la piel y la fina el poro.
	vec2 p = FRAGCOORD.xy / lado;
	float poro = mix(
		texture(grano, p).r,
		texture(grano, p * 2.7 + vec2(0.31, 0.77)).r,
		0.45);

	// El borde se rompe y el centro no: donde la cobertura ya era baja, el
	// poro decide si hay pigmento; donde el trazo es macizo, no decide nada.
	float umbral = max(mordiente * (1.0 - poro) - carga, 0.0);
	float a = smoothstep(umbral, umbral + 0.30, c.a);
	a *= mix(1.0, 0.66 + 0.68 * poro, veteado);

	COLOR = vec4(c.rgb * mix(1.0, 0.80 + 0.42 * poro, veteado), a);
}
