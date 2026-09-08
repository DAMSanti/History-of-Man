shader_type canvas_item;
render_mode blend_mix, unshaded;

// La piel tensada de una ventana.
//
// El fondo no es un color: es un material. Una piel raspada tiene poro y tiene
// veta, y lo que separa «un rectangulo marron» de «una piel» es que el tono se
// mueva por dentro. El grano llega como textura del poligono -ver
// [Pigmento.grano]- y aqui se convierte en relieve de curtido.

// Cuanto se nota la veta, de 0 a 1. Ver [PielDeEra.GRANO].
uniform float fuerza : hint_range(0.0, 1.0) = 0.55;

// El tono del valle del poro: la sombra del curtido, no negro.
uniform vec4 veta : source_color = vec4(0.35, 0.26, 0.18, 1.0);


void fragment() {
	float g = texture(TEXTURE, UV).r;
	vec3 base = COLOR.rgb;
	// El poro hunde hacia la veta y la cresta sube hacia la luz: lo mismo que
	// hace una piel raspada cuando le da la luz de lado.
	vec3 c = mix(base, mix(veta.rgb, base * 1.42, g), fuerza);
	COLOR = vec4(c, COLOR.a);
}
