// La estela de espuma detras de las piedras de un rapido (GRAFICOS §7.3). La incluyen el
// shader del terreno -Medio- y el de la lamina -Alto y Ultra-: una sola forma de pintarla.
// Va despues de `espuma_viva.gdshaderinc`, que usa `estela_viva`.
//
// `piedras_tex` lleva, por celda del terreno, la fuerza de la piedra que asoma en ella
// (`PiedrasDelRio`). Para un punto del agua se buscan las piedras de las celdas que
// quedan aguas ARRIBA -y a los dos lados- y cada una deja una cola que nace en la piedra,
// se abre corriente abajo y se apaga. Leida la textura a pelo, la espuma salia en
// cuadros del tamano de la celda (captura del 2026-09-15).

uniform sampler2D piedras_tex : filter_nearest, repeat_disable;
uniform bool con_piedras = false;
// El paso de la rejilla -tamano del terreno / (resolucion - 1)-, la resolucion y el origen
// del terreno. LA PIEDRA ESTA EN UN VERTICE de la rejilla, no en el centro de un texel: con
// el centro del texel la estela nacia media celda desplazada, y a lo largo del mapa mas
// (queja del usuario del 2026-09-15: «el wake no aparece donde estan las piedras»).
uniform float lado_de_celda = 5.0;
uniform float res_del_terreno = 825.0;
uniform vec2 origen_del_terreno = vec2(0.0);

float estela_de_piedras(vec2 punto, vec2 dir) {
	vec2 de_lado = vec2(-dir.y, dir.x);
	float estela = 0.0;
	// Hasta dos celdas aguas arriba: la cola se apaga a 2,2, y la tercera buscaba cuatro
	// lecturas de textura mas por pixel sin encontrar nunca nada.
	for (int k = 0; k <= 2; k++) {
		for (int l = -1; l <= 1; l++) {
			vec2 q = punto - dir * lado_de_celda * float(k) + de_lado * lado_de_celda * float(l);
			vec2 vertice = floor((q - origen_del_terreno) / lado_de_celda + 0.5);
			vec2 celda = vertice * lado_de_celda + origen_del_terreno;
			float fuerza = texture(piedras_tex, (vertice + 0.5) / max(res_del_terreno, 1.0)).r;
			if (fuerza <= 0.0) {
				continue;
			}
			vec2 rel = punto - celda;
			float abajo = dot(rel, dir);
			float al_lado = abs(dot(rel, de_lado));
			// Nace en la piedra, se abre un poco al bajar y se apaga a dos celdas, cada vez
			// mas debil. Mas larga y ancha, en la captura se leia como una cuna blanca de
			// bordes rectos; quien la rompe es la espuma viva, en el shader que la usa.
			float ancho = lado_de_celda * (0.14 + max(abajo, 0.0) / lado_de_celda * 0.10);
			float cola = (1.0 - smoothstep(ancho * 0.3, ancho, al_lado))
				* smoothstep(-lado_de_celda * 0.2, 0.0, abajo)
				* (1.0 - smoothstep(0.0, lado_de_celda * 2.2, abajo));
			estela = max(estela, cola * fuerza);
		}
	}
	return estela;
}


// La estela VIVA, de 0 a 1: la forma de `estela_de_piedras`, que se mece, rota por burbujas
// que viajan corriente abajo a `velocidad` y se forman y se deshacen deprisa.
//
// Queja del usuario del 2026-09-16: «la espuma del wake de las rocas no tiene movimiento,
// deberia cambiar de forma como si fuese espuma real». Era la cola fija con la espuma viva
// de todo el rapido por umbral, y sumandole la propia cola el umbral se pasaba casi siempre:
// salia una cuna blanca quieta.
//
// `burbujas_dadas`, si es 0 o mas, es la espuma viva que el shader ya tiene calculada, y
// no se calcula otra: en Medio, reusar la del rapido dejo el agua de cerca dentro del tope
// de 1 ms (AguaCaptura GPU=1, 2026-09-16). Las manchas salen mas grandes, que desde la
// camara de gestion no se nota.
float estela_viva(vec2 punto, vec2 dir, vec2 flow, float velocidad, int octavas, float burbujas_dadas) {
	// El vaiven: la cola se tuerce a un lado y al otro, unas decimas de celda.
	vec2 de_lado = vec2(-dir.y, dir.x);
	float vaiven = (ev_ruido(punto * 0.2 + vec2(TIME * 0.9, -TIME * 0.7)) - 0.5) * lado_de_celda * 0.35;
	float forma = estela_de_piedras(punto + de_lado * vaiven, dir);
	if (forma <= 0.0) {
		return 0.0;
	}
	// Burbujas de un metro que bajan con el agua y se renuevan cuatro veces mas deprisa
	// que la espuma del rapido. Pegado a la piedra la espuma es casi entera; en la cola
	// solo pasan las manchas mas fuertes, y se abren huecos que cambian.
	float burbujas = burbujas_dadas >= 0.0 ? burbujas_dadas
		: espuma_viva(punto, flow, velocidad, 0.9, 4.0, octavas);
	float mancha = forma * smoothstep(0.62 - forma * 0.35, 0.8 - forma * 0.3, burbujas);
	// Sin grano con poco detalle (Medio): ver `espuma_viva`.
	if (mancha <= 0.0 || octavas < 3) {
		return mancha;
	}
	// Y por dentro, GRANO de burbujas de palmo: sin el, la mancha era una lengua blanca
	// lisa, pintura y no espuma (secuencia de Ultra, 2026-09-16).
	float grano = espuma_viva(punto, flow, velocidad * 1.3, 0.25, 6.0, octavas);
	return mancha * mix(0.45, 1.0, smoothstep(0.35, 0.65, grano));
}

