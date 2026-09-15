shader_type spatial;
// El árbol lejano de los escalones Medio, Alto y Ultra: un impostor de VARIAS VISTAS.
// GRAFICOS §7.1.
//
// De cada árbol hay 64 fotos desde la semiesfera de arriba (`ArbolImpostores`). Este
// shader levanta un cuadrado mirando a la cámara, calcula desde dónde se mira EN EL
// MARCO DEL ÁRBOL —así respeta el giro de cada pie— y mezcla las cuatro fotos más
// cercanas. Con eso, al orbitar el árbol cambia de silueta y desde arriba se ve la
// copa, que es lo que la spec pide para que «no se note que son billboards».
//
// **La cuenta hemi-octaédrica es la de `ImpostorVistas.gd`**: si se toca allí, aquí.
render_mode cull_disabled, world_vertex_coords, diffuse_burley;

// LAS SEIS VARIANTES DE LA ESPECIE en un array de texturas, una capa por variante:
// cada pie elige la suya con el dato de instancia (`INSTANCE_CUSTOM.r`). Así el
// impostor es del mismo árbol que el 3D y el relevo no cambia de forma, con un solo
// material por especie en vez de seis.
uniform sampler2DArray color_vistas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2DArray normal_vistas : filter_linear_mipmap, repeat_disable;
uniform int vistas = 8;
// Medio lado del cuadrado de foto, y a qué altura está su centro, en metros del
// árbol a escala 1, por variante. Salen del horneado.
uniform float radios[6];
uniform float centros[6];
// Medio ancho y medio alto del árbol, en metros a escala 1, por variante: el cuadrado se
// ajusta a lo que ocupa el árbol visto desde esa elevación y no a todo el cuadro de la
// foto, que es del lado de su dimensión mayor. Un pino de 20 m por 8 pagaba un cuadrado
// de 21 × 21 casi vacío, y con el recorte alfa cada píxel vacío se paga igual.
uniform float anchos[6];
uniform float altos[6];

// EL RELEVO CON EL 3D: el complemento exacto del corte de `arbol_3d`. El impostor se
// esconde si su pie está a menos de `oculto_hasta` de la cámara y se ve si está más
// lejos. `Forest` pone `oculto_hasta` = el radio del 3D **o menos, si los bloques de
// cerca todavía no están montados**: así, si la cámara corre más que el montaje, se ve
// el impostor y no un hueco.
uniform float oculto_hasta = 40.0;
uniform vec3 ojo = vec3(0.0);
// Y al fondo del valle, el impostor se va.
uniform float far_end = 4000.0;

// HASTA DÓNDE SE MEZCLAN LAS CUATRO VISTAS; más lejos se lee la más cercana, una foto
// de color y una de normal. Con el recorte alfa cada capa de cuadrados solapados paga
// su píxel entero, y las ocho lecturas de antes costaban 14,5 ms de GPU en la vista de
// medida contra 1,9 del bosque Mínimo (`GpuProfile ARBOLES=1`, 2026-09-15). La mezcla
// es lo que evita que la silueta salte al orbitar, y eso sólo se ve de cerca. Lo pone
// `Forest` por escalón.
uniform float mezcla_hasta = 150.0;

uniform vec3 tint : source_color = vec3(1.0);
// Hoja y corteza, cada una con su tinte: qué es hoja lo guarda el horneado en el alfa
// del atlas de normales. Así el tinte de otoño no tiñe también el tronco.
uniform vec3 tint_corteza : source_color = vec3(1.0);
// La sombra que la copa se hace a sí misma, que la foto horneada —sin luz— no tiene: sin
// esto el impostor salía más claro que el 3D a su lado, de ×1,15 a ×1,45 en luminancia,
// y más amarillo, b* +5 a +10: la sombra de dentro de la copa la ilumina el cielo, que es
// azul. Por canal y en lineal, y SÓLO EN LA HOJA: sobre la corteza, en invierno —cuando
// no queda otra cosa— los caducos lejanos salían lila. La pone `Forest` por especie,
// medida con `ArbolColorProbe`.
uniform vec3 luz = vec3(1.0);
uniform float hoja : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_dir;
varying vec2 v_cuadro;
varying float v_distancia;
varying mat3 v_giro;
varying float v_capa;
varying flat float v_mezcla;

vec2 codificar(vec3 d) {
	d = normalize(vec3(d.x, max(d.y, 0.0), d.z));
	float suma = abs(d.x) + abs(d.y) + abs(d.z);
	vec2 p = d.xz / max(suma, 0.0001);
	return vec2(p.x + p.y, p.x - p.y);
}

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	float escala = length(MODEL_MATRIX[0].xyz);
	int variante = clamp(int(INSTANCE_CUSTOM.r * 255.0 + 0.5), 0, 5);
	v_capa = float(variante);
	float radio = radios[variante];
	vec3 centro = base + vec3(0.0, centros[variante] * escala, 0.0);
	vec3 al_ojo = CAMERA_POSITION_WORLD - centro;
	// La distancia del relevo, DESDE EL PIE y a la cámara de verdad, como en `arbol_3d`:
	// si no, el corte de uno y el del otro no caerían en el mismo sitio.
	v_distancia = distance(ojo, base);
	vec3 mira = al_ojo / max(length(al_ojo), 0.0001);
	vec3 derecha = cross(vec3(0.0, 1.0, 0.0), mira);
	derecha = length(derecha) < 0.001 ? vec3(1.0, 0.0, 0.0) : normalize(derecha);
	vec3 arriba = normalize(cross(mira, derecha));
	// El giro del pie, sin la escala: para pasar la mirada y la normal a su marco.
	v_giro = mat3(normalize(MODEL_MATRIX[0].xyz), normalize(MODEL_MATRIX[1].xyz),
		normalize(MODEL_MATRIX[2].xyz));
	v_dir = transpose(v_giro) * mira;
	// Lo que ocupa el árbol en pantalla: de ancho, su copa; de alto, su altura mirado de
	// lado y su copa mirado desde arriba. Nunca más que el cuadro de la foto.
	float sube = clamp(v_dir.y, 0.0, 1.0);
	vec2 medio = vec2(min(anchos[variante], radio),
		min(altos[variante] * sqrt(1.0 - sube * sube) + anchos[variante] * sube, radio));
	// La esquina del cuadrado, SACADA DE LA UV: con `world_vertex_coords` el vértice
	// llega ya pasado al mundo —girado y escalado por la instancia— y no sirve.
	vec2 local = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	v_cuadro = local * medio / radio;
	VERTEX = centro + (derecha * local.x * medio.x + arriba * local.y * medio.y) * escala;
	// Dentro de lo montado o más allá del fondo, plegado a su pie: sin fragmentos.
	if (v_distancia < oculto_hasta || v_distancia > far_end) {
		VERTEX = base;
	}
	NORMAL = mira;
	// Por árbol y no por píxel: el cuadrado entero va por un camino o por el otro.
	v_mezcla = length(al_ojo) < mezcla_hasta ? 1.0 : 0.0;
}

void fragment() {
	float n = float(vistas);
	vec2 celda = (codificar(v_dir) * 0.5 + 0.5) * n - 0.5;
	vec2 c0 = clamp(floor(celda), vec2(0.0), vec2(n - 1.0));
	vec2 c1 = clamp(c0 + 1.0, vec2(0.0), vec2(n - 1.0));
	vec2 f = clamp(celda - c0, vec2(0.0), vec2(1.0));
	// Dentro de la foto: y hacia abajo en la imagen.
	vec2 en_foto = vec2(v_cuadro.x, -v_cuadro.y) * 0.5 + 0.5;
	en_foto = clamp(en_foto, vec2(0.002), vec2(0.998));
	vec2 cerca = clamp(floor(celda + 0.5), vec2(0.0), vec2(n - 1.0));
	vec4 color;
	if (v_mezcla > 0.5) {
		vec4 a = texture(color_vistas, vec3((c0 + en_foto) / n, v_capa));
		vec4 b = texture(color_vistas, vec3((vec2(c1.x, c0.y) + en_foto) / n, v_capa));
		vec4 c = texture(color_vistas, vec3((vec2(c0.x, c1.y) + en_foto) / n, v_capa));
		vec4 d = texture(color_vistas, vec3((c1 + en_foto) / n, v_capa));
		color = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	} else {
		color = texture(color_vistas, vec3((cerca + en_foto) / n, v_capa));
	}
	// Lo transparente se tira ANTES de leer la normal: es la mayor parte del cuadrado.
	if (color.a < 0.5) {
		discard;
	}
	vec4 muestra;
	if (v_mezcla > 0.5) {
		vec4 na = texture(normal_vistas, vec3((c0 + en_foto) / n, v_capa));
		vec4 nb = texture(normal_vistas, vec3((vec2(c1.x, c0.y) + en_foto) / n, v_capa));
		vec4 nc = texture(normal_vistas, vec3((vec2(c0.x, c1.y) + en_foto) / n, v_capa));
		vec4 nd = texture(normal_vistas, vec3((c1 + en_foto) / n, v_capa));
		muestra = mix(mix(na, nb, f.x), mix(nc, nd, f.x), f.y);
	} else {
		muestra = texture(normal_vistas, vec3((cerca + en_foto) / n, v_capa));
	}
	vec3 normal_arbol = normalize(muestra.rgb * 2.0 - 1.0);
	float es_hoja = muestra.a;
	vec3 normal_mundo = v_giro * normal_arbol;

	// La hoja que queda en la estación: la hoja se aclara hacia rama sin hoja.
	float quita = es_hoja * (1.0 - hoja);
	// Desaturada como en `arbol_3d`, para que el mismo tinte dé el mismo color.
	vec3 gris = mix(vec3(dot(color.rgb, vec3(0.2126, 0.7152, 0.0722))), color.rgb, 0.3);
	ALBEDO = gris * mix(tint_corteza, tint * luz, es_hoja);
	ALPHA = color.a * (1.0 - quita * 0.85);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);
}
