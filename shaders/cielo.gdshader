shader_type sky;
// Las nubes volumétricas se calculan a MEDIA resolución y se mezclan después:
// ver `nubes_volumen`. Es lo que las deja caber en el presupuesto de GPU.
render_mode use_half_res_pass;
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
// Las NUBES y las ESTRELLAS van con el reloj del juego: las estrellas con el ángulo
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
// Cuánto ha corrido ya el viento, en unidades del ruido. Lo cuenta
// `WorldEnvironmentSetup._mover_las_nubes` con el reloj de la PARTIDA: en pausa
// no cambia y las nubes se quedan quietas. Desde el 2026-09-14; antes era `TIME`.
uniform float viento_recorrido = 0.0;
uniform float luz_de_la_nube : hint_range(0.0, 1.0) = 1.0;
// Pasos de la marcha por la capa de nubes. Cero apaga el volumen y deja las
// nubes planas —las baratas—, que es lo que usa el nivel bajo de gráficos.
uniform int pasos_de_nube : hint_range(0, 32) = 12;

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


// LAS NUBES ERAN CUADRADOS, «parecen de Minecraft» (usuario, 2026-09-14). Dos
// causas, y las dos se quitan aquí:
//
//  1. El azar de cada celda salía de `fract(sin(x) * 43758)`. Con `x` grande el
//     seno pierde los decimales en coma flotante y celdas enteras dan el mismo
//     número: bloques. Y `x` crecía sin tope, con el reloj —el viento
//     sumaba el tiempo a la coordenada— y con `1/altura` al mirar al horizonte.
//     El hash de ahora no usa seno —el `hash13` de Dave Hoskins—, y sin seno
//     la coordenada no pierde precisión hasta pasar del millón.
//  2. Una sola capa plana de ruido de rejilla cortada con un borde estrecho: la
//     rejilla se leía en el contorno. Ahora es un volumen de ruido 3D con
//     octavas giradas, así que ningún eje manda.
float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float ruido3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
			mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

// Octavas giradas entre sí: cada una en otra orientación, para que las aristas
// de la rejilla de una no coincidan con las de la siguiente.
const mat3 GIRO = mat3(vec3(0.00, 0.80, 0.60), vec3(-0.80, 0.36, -0.48),
	vec3(-0.60, -0.48, 0.64));

float fbm3(vec3 p, int octavas) {
	float suma = 0.0;
	float peso = 0.5;
	float total = 0.0;
	for (int o = 0; o < octavas; o++) {
		suma += ruido3(p) * peso;
		total += peso;
		p = GIRO * p * 2.03;
		peso *= 0.5;
	}
	return suma / total;
}

// Lo que ha corrido el viento, en las dos direcciones del plano.
vec3 viento_corrido() {
	return vec3(viento_recorrido, 0.0, viento_recorrido * 0.6);
}

// La capa de nubes, en metros sobre el valle. Es vista y no clima: la cota la
// decide lo que se ve bien desde la cámara de gestión, no una medida.
const float NUBE_BASE = 1400.0;
const float NUBE_TOPE = 2600.0;
// Hasta dónde se marcha por la capa, en metros. Más allá, al ras del horizonte,
// la nube es una franja de pocos píxeles y no merece pasos.
const float NUBE_ALCANCE = 38000.0;
// Cuánto oscurece un metro de nube. Decisión de aspecto, mirada en la captura.
const float NUBE_EXTINCION = 0.0022;

// Cuánta nube hay en un punto, de 0 a 1.
float densidad(vec3 p) {
	vec3 q = p / 2600.0 + viento_corrido();
	float alto = clamp((p.y - NUBE_BASE) / (NUBE_TOPE - NUBE_BASE), 0.0, 1.0);
	// Base plana y copa redondeada, que es la silueta de un cúmulo.
	float perfil = smoothstep(0.0, 0.12, alto) * smoothstep(1.0, 0.45, alto);
	float forma = fbm3(q, 4);
	float umbral = mix(0.72, 0.36, nubes);
	float d = smoothstep(umbral, umbral + 0.22, forma) * perfil;
	if (d <= 0.001) {
		return 0.0;
	}
	// El borde se deshilacha con una octava fina: es lo que quita el contorno de
	// pompa lisa.
	d -= (1.0 - fbm3(q * 5.0, 2)) * 0.35 * (1.0 - d);
	return clamp(d, 0.0, 1.0);
}

// Marcha por la capa y devuelve el color de la nube en `rgb` y cuánto tapa en `a`.
vec4 nubes_volumen(vec3 dir, vec3 sol, float semilla) {
	if (dir.y < 0.01 || nubes < 0.001 || pasos_de_nube <= 0) {
		return vec4(0.0);
	}
	float t0 = NUBE_BASE / dir.y;
	if (t0 > NUBE_ALCANCE) {
		return vec4(0.0);
	}
	float t1 = min(NUBE_TOPE / dir.y, NUBE_ALCANCE);
	float paso = (t1 - t0) / float(pasos_de_nube);
	// Un desfase por dirección rompe las bandas de la marcha sin parpadear: es
	// fijo para cada píxel del cielo, no cambia con el tiempo.
	float t = t0 + paso * semilla;
	vec3 luz = mix(color_horizonte, vec3(1.0), 0.6) * luz_de_la_nube;
	vec3 sombra = color_horizonte * 0.45 * luz_de_la_nube;
	float paso_luz = (NUBE_TOPE - NUBE_BASE) * 0.35;
	vec3 hacia_luz = normalize(vec3(sol.x, max(sol.y, 0.15), sol.z));
	vec3 acumulado = vec3(0.0);
	float pasa = 1.0;
	for (int i = 0; i < pasos_de_nube; i++) {
		vec3 p = dir * t;
		float d = densidad(p);
		if (d > 0.01) {
			// UNA muestra hacia la luz: cuánta nube tiene encima entre ella y el
			// sol. Es lo que le da cara iluminada y panza oscura.
			float tapada = densidad(p + hacia_luz * paso_luz);
			vec3 tono = mix(sombra, luz, exp(-tapada * 2.2));
			float a = 1.0 - exp(-d * paso * NUBE_EXTINCION);
			acumulado += pasa * a * tono;
			pasa *= 1.0 - a;
			if (pasa < 0.03) {
				break;
			}
		}
		t += paso;
	}
	float tapa = 1.0 - pasa;
	// Al ras del horizonte se funden con la calima, como las de antes.
	tapa *= smoothstep(0.01, 0.10, dir.y);
	return vec4(acumulado / max(1.0 - pasa, 0.001), tapa);
}

// Las nubes planas: para el reflejo del cielo —`AT_CUBEMAP_PASS`, que ilumina
// la escena y no se ve directamente— y para el nivel bajo. Con el mismo ruido
// sin seno, así que tampoco salen a cuadros.
float nubosidad_plana(vec3 dir) {
	vec2 plano = dir.xz / max(dir.y, 0.06);
	vec3 q = vec3(plano * 0.55, 0.0) + viento_corrido() * 0.05;
	return fbm3(q, 3);
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


// El cielo sin nubes volumétricas: degradado, estrellas, sol y luna. Aparte de
// `sky()` porque ahí dentro no se puede salir antes con `return`, y la pasada a
// media resolución no tiene que pintar nada de esto.
vec3 cielo_de_fondo(vec3 dir) {
	float altura = dir.y;
	float hacia_arriba = clamp(altura, 0.0, 1.0);
	vec3 color = mix(color_horizonte, color_cenit, pow(hacia_arriba, 0.45));
	color = mix(color_suelo, color, smoothstep(-0.06, 0.02, altura));

	// LAS ESTRELLAS, debajo de las nubes y sólo de noche.
	if (noche > 0.01 && altura > -0.02) {
		vec3 eje = normalize(polo_celeste);
		vec3 fijo = gira(dir, eje, -angulo_horario);
		float brillo = estrellas(fijo) * noche;
		// Al ras del horizonte se pierden, como se pierden de verdad.
		brillo *= smoothstep(-0.02, 0.10, altura);
		color += vec3(0.85, 0.88, 1.0) * brillo;
	}

	// EL SOL Y LA LUNA, en la dirección que dice `SolarPosition`.
	float al_sol = dot(dir, normalize(hacia_el_sol));
	float disco_sol = smoothstep(0.9993, 0.9997, al_sol);
	float halo = pow(clamp(al_sol, 0.0, 1.0), 220.0) * 0.35;
	color += vec3(1.0, 0.94, 0.80) * (disco_sol + halo);

	if (luna_iluminada > 0.01) {
		float a_la_luna = dot(dir, normalize(hacia_la_luna));
		float disco_luna = smoothstep(0.9990, 0.9995, a_la_luna);
		float resplandor = pow(clamp(a_la_luna, 0.0, 1.0), 900.0) * 0.20;
		color += vec3(0.90, 0.92, 1.0) * (disco_luna + resplandor) * luna_iluminada;
	}
	return color;
}


void sky() {
	if (AT_HALF_RES_PASS) {
		// La pasada a media resolución sólo hace las nubes.
		vec4 nube = vec4(0.0);
		if (pasos_de_nube > 0) {
			nube = nubes_volumen(EYEDIR, normalize(hacia_el_sol),
				hash13(EYEDIR * 997.0));
		}
		COLOR = nube.rgb;
		ALPHA = nube.a;
	} else {
		vec3 color = cielo_de_fondo(EYEDIR);
		// LAS NUBES, encima de todo: tapan estrellas y luna, que es lo que
		// hacen. Volumen a media resolución en la vista; planas en el reflejo
		// y con el volumen apagado.
		if (EYEDIR.y > 0.005 && nubes > 0.001) {
			if (pasos_de_nube > 0 && !AT_CUBEMAP_PASS) {
				color = mix(color, HALF_RES_COLOR.rgb, clamp(HALF_RES_COLOR.a, 0.0, 1.0));
			} else {
				float densa = nubosidad_plana(EYEDIR);
				float borde = mix(0.72, 0.36, nubes);
				float mancha = smoothstep(borde, borde + 0.22, densa);
				mancha *= smoothstep(0.0, 0.12, EYEDIR.y);
				vec3 tinta = mix(color_horizonte, vec3(1.0), 0.55) * luz_de_la_nube;
				color = mix(color, tinta, mancha * 0.9);
			}
		}
		COLOR = color;
	}
}
