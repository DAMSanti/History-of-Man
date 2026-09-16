// La espuma del rio, VIVA (GRAFICOS §7.3). La incluyen el terreno -Bajo y Medio- y la
// lamina -Alto y Ultra-.
//
// Vuelta del usuario del 2026-09-15 mirando las capturas: «la espuma no se comporta como
// espuma, realmente se crea y se desvanece; aqui solo va desplazandose» y «es MUY
// regular, son largas tiras blancas». Era una textura procedural arrastrada por la
// corriente: su dibujo se repetia en tiras y nunca cambiaba. Aqui:
//
// - un ruido de varias octavas hecho en el shader, sin tesela que se repita;
// - arrastrado en dos fases que se cruzan, para que el reinicio del arrastre no se vea;
// - y un segundo campo que NO viaja y cambia despacio con el tiempo, que sube y baja el
//   umbral: donde sube, la espuma se forma; donde baja, se deshace.

// EL HASH CON LA CELDA ACOTADA. El rio esta a miles de metros del origen, y en la cuarta
// octava la celda pasa de diez mil: `fract(p * 456.21)` con p asi ya no tiene cifras
// decimales en float de 32 bits, y el hash devolvia unos pocos valores repetidos en rejilla.
// Salia en facetas triangulares con la corriente parada y sin luz (vista de terminos de
// `AguaCaptura`, 2026-09-15). Con la celda modulo 289 el patron se repite cada 289 celdas
// -cientos de metros-, que no se ve, y el hash trabaja con numeros pequenos.
float ev_hash(vec2 p) {
	vec3 p3 = fract(vec3(mod(p, 289.0).xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ev_ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(ev_hash(i), ev_hash(i + vec2(1.0, 0.0)), u.x),
		mix(ev_hash(i + vec2(0.0, 1.0)), ev_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float ev_fbm(vec2 p, int octavas) {
	float suma = 0.0;
	float peso = 0.5;
	float total = 0.0;
	mat2 giro = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int o = 0; o < octavas; o++) {
		suma += peso * ev_ruido(p);
		total += peso;
		p = giro * p;
		peso *= 0.5;
	}
	return suma / total;
}

// De 0 a 1: cuanta espuma hay en `punto` -en unidades de mundo- con la corriente `dir`,
// que va a `velocidad` unidades por segundo, con manchas de `escala` unidades, y que se
// renueva a `renueva` (1 lo normal; mas, antes).
//
// `octavas`, el detalle: 4 en la lamina -Alto y Ultra-, 2 en el terreno -Bajo y Medio-.
// Con cuatro en Medio el agua costaba 1-2,3 ms de GPU en los rapidos, por encima del tope
// de 1 ms (AguaCaptura GPU=1, 2026-09-16); lo fino de las octavas altas casi no se ve
// desde la camara de gestion.
float espuma_viva(vec2 punto, vec2 dir, float velocidad, float escala, float renueva, int octavas) {
	// SIN GIRAR EL MUNDO: la primera version giraba las coordenadas absolutas -mil y pico
	// metros- segun la corriente, que cambia de un triangulo al siguiente, y el dibujo
	// saltaba metros en cada arista: facetas triangulares duras en la captura de cerca.
	// Aqui la corriente solo desplaza, y el desplazamiento esta acotado por la fase.
	//
	// Y PERIODO FIJO: con `fract(TIME * velocidad)`, la velocidad interpolada hacia que dos
	// pixeles vecinos reiniciaran el ciclo en sitios distintos, y la espuma se cortaba en
	// triangulos. Todos giran a la vez; la velocidad solo dice cuanto se mueve.
	//
	// Y RECORRIDO CORTO: por ciclo el dibujo se mueve menos de un tercio de su tamano. La
	// corriente llega por vertice, y cualquier cambio entre vertices -aun suavizada, ver
	// `AguaDelCauce.corriente_suave`- cambia el ritmo del desplazamiento en cada arista:
	// con dos manchas de recorrido la espuma se cortaba en facetas. La sensacion de que el
	// agua corre la da la espuma que se renueva, no la que viaja lejos.
	vec2 p = punto / max(escala, 0.001);
	float periodo = 1.2;
	float fase_a = fract(TIME / periodo);
	float fase_b = fract(TIME / periodo + 0.5);
	float cruce = abs(1.0 - 2.0 * fase_a);
	vec2 recorrido = dir * velocidad * 0.5 * periodo / max(escala, 0.001);
	float a = ev_fbm(p - recorrido * fase_a + vec2(0.0, 17.0), octavas);
	float b = ev_fbm(p - recorrido * fase_b + vec2(31.0, 0.0), octavas);
	float arrastrada = mix(a, b, cruce);
	// El campo que la forma y la deshace es grande: una octava menos.
	float vida = ev_fbm(p * 0.5 + vec2(TIME * 0.13, -TIME * 0.09) * renueva + 7.3, max(octavas - 1, 1));
	return clamp(arrastrada + (vida - 0.5) * 1.1, 0.0, 1.0);
}
