// Las gotas de lluvia picando el agua: anillos que nacen, crecen y se apagan.
//
// Petición del usuario del 2026-09-16: «cuando llueva que se vean ondas en el agua del
// río o del mar». Lo comparten la lámina del río y el mar, que es donde se ve el agua
// (GRAFICOS §7.3 y §7.4): una regla, un sitio.
//
// Es VISTA: no toca la partida, no moja el suelo —eso lo lleva `ClimaEnPantalla`— y sólo
// se calcula cuando de verdad está lloviendo.

// El azar de una celda, ACOTADO antes de multiplicar.
//
// La misma trampa que se comió la espuma del río: con coordenadas de miles de metros el
// hash pierde los decimales y el dibujo sale en facetas triangulares (GRAFICOS §7.3,
// 2026-09-16). Con `mod` antes del producto, el ruido es el mismo en el metro 3 y en el
// metro 30 000.
vec2 gea_hash(vec2 celda) {
	vec2 p = mod(celda, 289.0);
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// Una capa de gotas: una por celda, cayendo cada una a su hora.
//
// `x` e `y` son el tirón de la normal —hacia fuera del anillo, que es como empuja el
// agua— y `z` el chispazo del anillo, que es lo que se ve blanco.
vec3 gea_capa(vec2 pos, float tiempo, float semilla) {
	vec2 celda = floor(pos);
	vec3 total = vec3(0.0);
	// Las cuatro celdas de alrededor: una sola deja los anillos cortados en la
	// frontera de la rejilla, y eso se lee como una cuadrícula.
	for (int j = -1; j <= 0; j++) {
		for (int i = -1; i <= 0; i++) {
			vec2 vecina = celda + vec2(float(i), float(j));
			vec2 azar = gea_hash(vecina + semilla);
			// Dónde cae la gota dentro de su celda, y cuándo.
			vec2 centro = vecina + 0.15 + azar * 0.7;
			float fase = fract(tiempo * (0.7 + azar.y * 0.5) + azar.x);
			float radio = fase * 0.5;
			vec2 hacia = pos - centro;
			float lejos = length(hacia);
			// El anillo: la banda que va creciendo, y ANCHA. Con 26 medía dos
			// centímetros, y a treinta metros de cámara no se leía como un círculo
			// sino como una culebrilla (captura del 2026-09-16).
			float anillo = exp(-pow((lejos - radio) * 6.0, 2.0));
			// Y se apaga al crecer, que es lo que hace una onda de verdad.
			float vive = (1.0 - fase) * (1.0 - fase);
			float fuerza = anillo * vive;
			vec2 fuera = lejos > 0.0001 ? hacia / lejos : vec2(0.0);
			total.xy += fuera * fuerza;
			total.z += fuerza;
		}
	}
	return total;
}

// Las gotas en este punto del agua. `celda_m` es cada cuánto cae una.
vec3 gotas_en_el_agua(vec2 mundo_xz, float tiempo, float lluvia, float celda_m) {
	if (lluvia <= 0.01) {
		return vec3(0.0);
	}
	float lado = max(celda_m, 0.05);
	// DOS CAPAS a escalas distintas: con una sola, la rejilla de celdas se lee en
	// cuanto llueve fuerte, porque todas las gotas guardan la misma distancia mínima.
	vec3 fina = gea_capa(mundo_xz / lado, tiempo, 0.0);
	vec3 gorda = gea_capa(mundo_xz / (lado * 2.3), tiempo * 0.8, 37.0);
	vec3 juntas = fina + gorda * 0.8;
	// Con orbayu pican cuatro gotas y con temporal, todas.
	return juntas * lluvia;
}
