shader_type sky;
// El cielo del valle: nubes que pasan, estrellas que giran, y el sol y la luna
// donde de verdad están.
//
// Frente 16 de EPOCA_01 §10.1, tanda 3, ampliado por el usuario el 2026-09-13
// con «rotación de cielo, sol, luna, estrellas». Antes había un
// `ProceduralSkyMaterial`: un degradado de cenit a horizonte y nada más.
//
// **Nada de esto decide dónde están los astros.** Las direcciones del sol y de
// la luna las calcula `SolarPosition` —latitud, día del año y hora solar, las
// mismas que orientan las luces— y entran por uniforme. Una segunda cuenta del
// cielo aquí sería una segunda respuesta a la misma pregunta: el sol de la
// sombra y el sol pintado se separarían al primer cambio.
//
// Las NUBES van con el reloj de pared (`TIME`) y las ESTRELLAS con el ángulo
// horario del juego. Es deliberado: la nube es vista y no cambia una cifra
// —SPECS §4.7—, pero que las estrellas giren con la noche es parte de la hora
// que el jugador lee.

uniform vec3 color_cenit : source_color = vec3(0.30, 0.50, 0.85);
uniform vec3 color_horizonte : source_color = vec3(0.65, 0.75, 0.90);
uniform vec3 color_suelo : source_color = vec3(0.25, 0.20, 0.15);

// Cuánto cubren las nubes, de 0 -limpio- a 1 -tapado-. Lo pone el tiempo que
// hace: ver `WorldEnvironmentSetup.NUBOSIDAD`.
uniform float nubes : hint_range(0.0, 1.0) = 0.45;
uniform float viento : hint_range(0.0, 0.2) = 0.012;
uniform float luz_de_la_nube : hint_range(0.0, 1.0) = 1.0;

// De 0 -de día- a 1 -noche cerrada-. Decide si se ven las estrellas.
uniform float noche : hint_range(0.0, 1.0) = 0.0;
// El eje sobre el que gira el cielo: el polo celeste, a la altura de la latitud
// y mirando al norte. Y cuánto lleva girado, en radianes -el ángulo horario-.
uniform vec3 polo_celeste = vec3(0.0, 0.7, -0.7);
uniform float angulo_horario = 0.0;

// Dónde están, y cuánto lucen. `luna_iluminada` es la fracción de disco que da
// la fase: en luna nueva no se pinta.
uniform vec3 hacia_el_sol = vec3(0.0, 1.0, 0.0);
uniform vec3 hacia_la_luna = vec3(0.0, -1.0, 0.0);
uniform float luna_iluminada : hint_range(0.0, 1.0) = 0.0;


// Ruido de valor en tres octavas: la forma barata de una nube. Ni textura que
// cargar ni ruido que hornear.
float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 dentro = fract(p);
	dentro = dentro * dentro * (3.0 - 2.0 * dentro);
	float a = fract(sin(dot(celda, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(celda + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(celda + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(celda + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, dentro.x), mix(c, d, dentro.x), dentro.y);
}

float nubosidad(vec2 p) {
	return ruido(p) * 0.55 + ruido(p * 2.3) * 0.28 + ruido(p * 5.1) * 0.17;
}

// Gira un vector alrededor de un eje. Rodrigues, que es lo que hace falta para
// que las estrellas den la vuelta al polo y no a la vertical: en Cantabria el
// polo está a 43 grados, no en el cenit.
vec3 gira(vec3 v, vec3 eje, float angulo) {
	float c = cos(angulo);
	float s = sin(angulo);
	return v * c + cross(eje, v) * s + eje * dot(eje, v) * (1.0 - c);
}

// Un campo de estrellas fijo: celdas sobre la dirección, y en cada una, si le
// toca, un punto con su brillo. Al mirar con la dirección YA GIRADA, el campo
// se queda quieto respecto del polo y es el cielo el que pasa.
float estrellas(vec3 dir) {
	vec3 p = dir * 60.0;
	vec3 celda = floor(p);
	vec3 dentro = fract(p);
	float sorteo = fract(sin(dot(celda, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	// Una de cada catorce celdas tiene estrella. Con una de cada veinticinco
	// —lo primero que probé— se contaban tres en toda la pantalla: medido
	// mirando la captura, que para eso está.
	if (sorteo > 0.07) {
		return 0.0;
	}
	vec3 donde = vec3(
		fract(sorteo * 31.7), fract(sorteo * 57.3), fract(sorteo * 91.1));
	float lejos = length(dentro - donde);
	float punto = 1.0 - smoothstep(0.0, 0.16, lejos);
	// Y no todas alumbran igual, que es lo que hace que se lean como estrellas
	// y no como una retícula.
	return punto * mix(0.45, 1.30, fract(sorteo * 137.0));
}


void sky() {
	float altura = EYEDIR.y;
	float hacia_arriba = clamp(altura, 0.0, 1.0);
	vec3 color = mix(color_horizonte, color_cenit, pow(hacia_arriba, 0.45));
	color = mix(color_suelo, color, smoothstep(-0.06, 0.02, altura));

	// LAS ESTRELLAS, debajo de las nubes y sólo de noche.
	if (noche > 0.01 && altura > -0.02) {
		vec3 eje = normalize(polo_celeste);
		vec3 fijo = gira(EYEDIR, eje, -angulo_horario);
		float brillo = estrellas(fijo) * noche;
		// Al ras del horizonte se pierden, como se pierden de verdad.
		brillo *= smoothstep(-0.02, 0.10, altura);
		color += vec3(0.85, 0.88, 1.0) * brillo;
	}

	// EL SOL Y LA LUNA, en la dirección que dice `SolarPosition`.
	float al_sol = dot(EYEDIR, normalize(hacia_el_sol));
	float disco_sol = smoothstep(0.9993, 0.9997, al_sol);
	float halo = pow(clamp(al_sol, 0.0, 1.0), 220.0) * 0.35;
	color += vec3(1.0, 0.94, 0.80) * (disco_sol + halo);

	if (luna_iluminada > 0.01) {
		float a_la_luna = dot(EYEDIR, normalize(hacia_la_luna));
		float disco_luna = smoothstep(0.9990, 0.9995, a_la_luna);
		float resplandor = pow(clamp(a_la_luna, 0.0, 1.0), 900.0) * 0.20;
		color += vec3(0.90, 0.92, 1.0) * (disco_luna + resplandor) * luna_iluminada;
	}

	// LAS NUBES, encima de todo: tapan estrellas y luna, que es lo que hacen.
	if (altura > 0.005 && nubes > 0.001) {
		vec2 plano = EYEDIR.xz / max(altura, 0.06);
		plano += vec2(TIME * viento, TIME * viento * 0.6);
		float densa = nubosidad(plano * 0.55);
		float borde = mix(0.85, 0.28, nubes);
		float mancha = smoothstep(borde, borde + 0.16, densa);
		mancha *= smoothstep(0.0, 0.12, altura);
		vec3 tinta = mix(color_horizonte, vec3(1.0), 0.55) * luz_de_la_nube;
		color = mix(color, tinta, mancha * 0.9);
	}

	COLOR = color;
}
