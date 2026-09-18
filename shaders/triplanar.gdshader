shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Tri-planar terrain shader con blending por altura y pendiente
// Evita el estiramiento de texturas en pendientes pronunciadas

// Ocho capas de material en tres arrays, en el orden de TerrainLayers.Layer:
//   0 pradera · 1 bosque · 2 roquedo · 3 canchal
//   4 cantos  · 5 arena  · 6 limo    · 7 nieve
//
// Antes eran ocho samplers sueltos para cuatro materiales -albedo y normal-, y
// anadir una capa significaba tocar el shader. Con arrays, anadir capas cuesta
// VRAM y no codigo, y sobre todo no cuesta MUESTREOS: se muestrean siempre las
// DOS capas de mas peso, sean ocho o veinte.
#define LAYERS 9

group_uniforms textures;
uniform sampler2DArray terrain_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray terrain_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// R oclusion · G rugosidad · B metalico · A altura
uniform sampler2DArray terrain_orm : filter_linear_mipmap_anisotropic, repeat_enable;

group_uniforms texture_settings;
// Lado de la tesela de cada capa, en METROS de mundo. Antes habia una sola
// escala para las cuatro, que es lo que hacia imposible que un canto rodado y
// una mata de hierba tuviesen su tamano real a la vez.
uniform float layer_tile_m[LAYERS];
// CUANTO RELIEVE TIENE CADA CAPA. Multiplica el mapa de normales, la cuesta de la altura y
// el desplazamiento: un canchal tiene bulto de canto y un limo de marisma no tiene ninguno,
// y hasta el 2026-09-18 iban todas con la misma fuerza. Ver [TerrainLayers.reliefs_in_order].
uniform float layer_relieve[LAYERS];

// Graduacion de color por capa. Ver TerrainLayers.CATALOGUE para el porque de
// cada numero: en corto, la fotogrametria de la biblioteca esta hecha en un
// prado ingles de junio y esto es una estepa fria de hace quince mil anos, y
// ese material no existe en CC0. La textura pone la estructura y el color se
// gradua.
uniform vec3 layer_tint[LAYERS];
// Cuanto se conserva del color original: 1 tal cual, 0 gris.
uniform float layer_saturation[LAYERS];
uniform float blend_sharpness : hint_range(0.1, 10.0) = 2.0;
uniform float triplanar_sharpness : hint_range(0.1, 10.0) = 3.0;

group_uniforms height_settings;
uniform float grass_max_height : hint_range(0.0, 1.0) = 0.5;
uniform float rock_min_height : hint_range(0.0, 1.0) = 0.4;
uniform float rock_max_height : hint_range(0.0, 1.0) = 0.75;
uniform float snow_min_height : hint_range(0.0, 1.0) = 0.7;
uniform float sand_max_height : hint_range(0.0, 1.0) = 0.2;
uniform float max_world_height : hint_range(1.0, 500.0) = 50.0;
// Desde qué cota se cuentan las bandas, en unidades de mundo. Cero en el valle,
// y el MAR DE LA ÉPOCA en el mapa regional: con el mar a -120 m, todo lo que
// asoma entre -120 y 0 normalizaba por debajo de cero, se recortaba y caía
// entero en la banda de orilla —arena y limo—. Era la costa marrón que vio el
// usuario el 2026-09-14.
uniform float cota_base = 0.0;

group_uniforms slope_settings;
// DESDE QUE INCLINACION HAY DERRUBIO Y DESDE CUAL PARED, en `1 - |normal.y|`, que va de 0
// —llano— a 1 —pared vertical—. En grados: el angulo es `acos(1 - valor)`.
//
// **Rehechos el 2026-09-18.** Estaban escritos como un umbral y un margen —`slope_threshold`
// y `slope_blend`— con la pared en `umbral + margen*2,5`, y el material ponia el umbral en
// 0,15: el canchal empezaba **casi en llano** —a 30 grados ya era medio canchal— y la pared
// necesitaba 0,65 de pendiente para asomar, con lo que el derrubio se comia la roca. El
// usuario: «hay muchos sitios que deberian ser piedra caliza y sin embargo son rocal».
//
// Ahora son cuatro numeros con su angulo, y la decision del usuario fue **pared desde
// 55-60 grados**:
//   canchal   0,18 (35°) → 0,43 (55°)
//   pared     0,43 (55°) → 0,70 (73°)
// LA HUMEDAD DEL VALLE, la que siembra los arboles. La pone `TerrainMaterialManager`; sin
// ella el bosque se reparte como antes, por curvatura y ruido.
uniform bool use_humedad = false;
uniform sampler2D humedad_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec2 humedad_extent = vec2(1.0, 1.0);
uniform vec2 humedad_origen = vec2(0.0, 0.0);

uniform float canchal_desde : hint_range(0.0, 1.0) = 0.18;
uniform float canchal_hasta : hint_range(0.0, 1.0) = 0.43;
uniform float pared_desde : hint_range(0.0, 1.0) = 0.43;
uniform float pared_hasta : hint_range(0.0, 1.0) = 0.70;

group_uniforms material_properties;
// La rugosidad ya no es una constante por material: viene en el canal verde del
// ORM, o sea que cambia DENTRO de la textura. Una piedra mojada en la sombra de
// una grieta y la misma piedra al sol no tienen el mismo acabado, y con una
// constante por capa eso no se puede decir.
uniform bool use_orm = true;

group_uniforms relieve;
// EL RELIEVE DE LA TEXTURA (parallax con oclusion), con la altura sacada del color.
//
// Hasta el 2026-09-16 no habia ninguno. GRAFICOS §4 decia que el canal A del ORM
// -«altura→A»- «alimenta el parallax», y NO LO ALIMENTABA: se muestreaba, se
// guardaba en `surface_height` y nadie lo miraba. Lo unico que daba relieve era el
// mapa de normales, que no tapa nada porque no mueve nada. La primera version leyo
// ese canal; el usuario la vio y pidio que se hundiera lo oscuro del dibujo, asi que
// durante un dia la altura salio del brillo del color.
//
// **Desde el 2026-09-17 sale del alfa del ORM otra vez**, que es la altura de verdad
// (GRAFICOS §7.7, y el porque en `altura_de_la_capa`): con el brillo se hundia lo
// oscuro y no lo hundido, y en la caliza las dos cosas no se parecen en nada.
//
// 0 pasos = apagado, que es lo que se queda en Bajo y Medio.
uniform int relieve_pasos : hint_range(0, 32) = 0;
// Cuanto hunde, COMO PARTE DE LA TESELA y no en metros: la roca y la hierba no miden
// lo mismo -una tesela de roca son cuatro metros con piedras de medio metro, una de
// hierba es un palmo de briznas- y el relieve tiene que ir con lo que se dibuja.
// Estuvo en 6 cm fijos y sobre una tesela de 4 m no se veia nada (2026-09-16).
// «Levemente», dijo el usuario: lo claro sube un poco, no se hace un monte.
uniform float relieve_de_la_tesela : hint_range(0.0, 0.3) = 0.05;
// Cuanto brillo hace falta para ir de lo mas hondo a lo mas alto. Con 2,5 una
// diferencia de 0,2 de brillo sobre la media ya es media altura.
uniform float contraste_del_relieve : hint_range(0.5, 6.0) = 1.8;
// EL BULTO CON LUZ: cuanto inclina la normal la cuesta del brillo. Es lo que se ve
// desde la orbita de juego. El desplazamiento solo mueve unos pixeles a 30-80 m y
// el usuario, mirando la sonda, no noto nada -«no se nota nada», 2026-09-16-: lo
// que dice «esto tiene bulto» a esa distancia es que la cara al sol se aclare y la
// de la sombra se oscurezca.
// «Demasiada diferencia entre picos y valles» (usuario, 2026-09-16, con 7): a la
// mitad larga.
// **Bajado de 3 a 1,2 el 2026-09-18**, al pasar la cuesta a salir de la altura: el mapa de
// altura tiene mucho mas contraste que el brillo —desviacion tipica 0,22 contra 0,069 en la
// caliza— y con el numero de antes la piedra salia rayada.
uniform float fuerza_del_bulto : hint_range(0.0, 20.0) = 1.2;
// Cada cuantos texeles se mide la cuesta. Tiene que ir con el desenfoque: medir a
// tres texeles sobre una textura desenfocada a ocho es medir dentro de una mancha.
uniform float texeles_del_bulto : hint_range(1.0, 32.0) = 22.0;
// CUANTO SE DESENFOCA EL DIBUJO antes de leer la altura, en niveles de mipmap.
// «Cualquier minima mancha hace un bulto... detecta las piedras en la textura, no
// las manchas de las piedras» (usuario, 2026-09-16): con la textura a su tamaño
// cada mota y cada liquen de la roca salian como un grano. Tres niveles son ocho
// texeles por uno, y a esa escala las motas desaparecen y la piedra queda. Y cuatro y
// medio la dejan REDONDEADA: «deben ser bumps suavizados, como si fuesen las piedras
// del suelo» (usuario, 2026-09-16) —con tres la piedra salia con arista—.
uniform float desenfoque_de_la_piedra : hint_range(0.0, 6.0) = 4.5;
// Cuanto se oscurece el fondo de las juntas. Sin esto el parallax mueve el dibujo
// pero con sol no se lee hondo: lo que dice «aqui hay un hueco» es que el hueco
// este mas oscuro (captura del canchal, 2026-09-16).
uniform float hondura_de_las_juntas : hint_range(0.0, 1.0) = 0.12;
// Desde donde deja de calcularse. Tiene que pasar de la orbita con la que se juega
// -unos 80 m- o el relieve solo existe con la camara pegada al suelo, que es donde
// casi nunca se esta. Estuvo en 60 m (2026-09-16).
uniform float relieve_hasta_m = 160.0;
// Margen para retocar lo que traiga la textura sin volver a ingerirla.
uniform float roughness_scale : hint_range(0.2, 2.0) = 1.0;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.8;
// Rugosidad cuando el ORM esta apagado -tier bajo-. Muy mate a proposito:
// ninguna superficie natural de este mapa refleja de forma especular.
uniform float roughness_fallback : hint_range(0.0, 1.0) = 0.93;

// Reflectancia especular del terreno. Estaba clavada a 0.3 dentro del fragment
// y era la causa del brillo metalico: tierra, hierba y roca son dielectricos
// MUY mates, y con reflejo de cielo activado un 0.3 sobre una ladera de normal
// suave se lee como plastico o metal pulido.
uniform float terrain_specular : hint_range(0.0, 1.0) = 0.08;

group_uniforms variation;
// UV2.x trae la curvatura del terreno (0.5 = plano, >0.5 concavo) y UV2.y una
// variacion de parche. Se calculan por VERTICE, asi que aqui no cuestan nada.
uniform bool use_terrain_variation = true;
// Cuanto empuja la curvatura el reparto hierba/roca. Lo concavo acumula suelo
// y humedad; lo convexo se erosiona y deja la roca a la vista.
uniform float curvature_influence : hint_range(0.0, 1.5) = 0.75;
// Cuanto varia el reparto de una mancha a otra
uniform float macro_influence : hint_range(0.0, 1.5) = 0.65;

// Barrancos a roca. Un barranco es concavo Y con pendiente: el agua lo escarba
// y se lleva el suelo hasta dejar la roca. Sin esto la curvatura hace lo
// contrario -lo concavo acumula tierra- y los barrancos salian de hierba, que
// es justo lo que no son.
uniform float ravine_curvature : hint_range(0.0, 1.0) = 0.30;
uniform float ravine_slope : hint_range(0.0, 1.0) = 0.16;
uniform float ravine_strength : hint_range(0.0, 1.0) = 0.9;

group_uniforms overlay;
// Capa de informacion que se pinta sobre el terreno: recursos conocidos,
// territorio reconocido. Llega como UNA textura del tamano del recuadro, con
// el color en rgb y la intensidad en alfa.
//
// Va aqui y no como nodos en el mundo porque la version con un disco por celda
// eran mas de veinte mil llamadas de dibujado y se comia los frames enteros.
// Asi cuesta un muestreo, y ademas queda pegada al relieve en vez de flotando.
uniform bool use_overlay = false;
uniform sampler2D overlay_tex : filter_linear, repeat_disable;
uniform vec2 overlay_world_size = vec2(1.0, 1.0);

group_uniforms region;
// UV2.x trae la mascara de region jugable. Fuera de ella el terreno se apaga:
// sigue siendo contexto geografico util, pero deja claro que no es tablero.
uniform bool use_region_mask = false;
// La mascara llega como textura y no por UV2 para poder CAMBIARLA en caliente:
// el area jugable depende de la cota del mar, y rehacer la malla en cada
// cambio de epoca costaria casi veinte segundos.
uniform sampler2D region_mask_tex : hint_default_white, filter_linear, repeat_disable;
uniform vec2 region_world_size = vec2(1.0, 1.0);
uniform float outside_desaturation : hint_range(0.0, 1.0) = 0.85;
uniform float outside_dim : hint_range(0.0, 1.0) = 0.45;

group_uniforms rivers;
// El agua del cauce, encendida o apagada entera. Existe para medirla: con ella se
// alterna agua sí y no en la misma corrida (`AguaCaptura GPU=1`, GRAFICOS §7.3).
uniform bool use_rivers = true;
// El escalón del agua de la configuración: 0 Bajo, 1 Medio, 2 Alto, 3 Ultra. Cada uno
// incluye lo del de abajo (GRAFICOS §7.3). Lo pone `TerrainMaterialManager`.
uniform int nivel_de_agua : hint_range(0, 3) = 1;
// Pinta la espuma en rojo y nada más: para comprobar en captura dónde sale
// (`AguaCaptura MASCARA=1`). Nunca encendido en el juego.
uniform bool ver_espuma = false;
// Para buscar fallos: pinta en gris un termino del agua y nada mas. 1 la caida horneada,
// 2 la espuma viva, 3 la estela, 4 la espuma final, 5 la corriente, 6 el agua quieta, 7 la
// orilla horneada. Lo usa `AguaCaptura TERMINO=n`; nunca encendido en el juego.
uniform int ver_termino = 0;

// EL TIEMPO EN EL SUELO (GRAFICOS §7.4): lo mojado y la nieve cuajada de `ClimaEnPantalla`,
// y la cota de nieve de hoy en la MISMA fraccion del relieve que `snow_min_height`
// (`Temporada.cota_de_nieve`). Los pone `WeatherView`; con el clima apagado, a cero.
uniform float clima_mojado : hint_range(0.0, 1.0) = 0.0;
// CUANTA HOJARASCA hay en el suelo del bosque, de 0 a 1. Lo pone `WeatherView` con lo que
// dice `Temporada.hojarasca`: sube a lo largo del otoño y se va en invierno, con la misma
// transicion de doce dias que la cota de nieve. A cero, la novena capa no pinta nada.
uniform float hojarasca : hint_range(0.0, 1.0) = 0.0;
uniform float clima_nieve : hint_range(0.0, 1.0) = 0.0;
uniform float clima_cota_de_nieve = 2.0;
// Cuanto se hunde el lecho bajo la lamina, en unidades de mundo; lo pone la malla.
uniform float lecho_hondo = 0.0;
// Medio: cuanto deja ver el fondo el agua somera -la fraccion de lamina que cubre
// donde la lamina es mas fina- y cuanto se oscurece lo hondo. Decisiones mirando
// capturas contra las fotos del Nansa (CREDITOS).
uniform float somera_cubre : hint_range(0.0, 1.0) = 0.45;
uniform float honda_oscurece : hint_range(0.0, 1.0) = 0.45;
// Color y acabado del agua de los cauces. Llega por COLOR.a desde la malla:
// un plano de agua horizontal solo puede representar el tramo a nivel del mar,
// asi que el rio aguas arriba se pinta sobre el propio terreno.
uniform vec3 river_color : source_color = vec3(0.10, 0.22, 0.28);
uniform float river_roughness : hint_range(0.0, 1.0) = 0.06;
uniform float river_specular : hint_range(0.0, 1.0) = 0.5;
// Color del fondo, que se ve por la orilla donde la lamina es fina. Sin esto
// el rio es una cinta de color plano recortada sobre el terreno.
uniform vec3 river_shallow_color : source_color = vec3(0.24, 0.34, 0.30);
// Velocidad de la corriente, en metros por segundo del patron de ondas
uniform float water_flow_speed : hint_range(0.0, 6.0) = 1.4;
// Tamano de la onda, en metros
uniform sampler2D water_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
// Lado de la tesela de agua, en metros
uniform float water_tile_m : hint_range(1.0, 60.0) = 12.0;
uniform float water_normal_strength : hint_range(0.0, 2.0) = 0.6;
// Segunda capa, mas grande y mas lenta: da oleaje de fondo bajo el rizado
uniform float water_swell_tile_m : hint_range(4.0, 200.0) = 46.0;
// Espuma en los rapidos. Donde rompe llega horneado en UV.x, medido como CAIDA
// AGUAS ABAJO entre celdas de cauce (`AguaDelCauce`): ni la pendiente del terreno
// ni su normal, que en la margen de un cauce encajado siempre es empinada.
// Los umbrales de la caida, los de `AguaDelCauce`, que los pone `TerrainMaterialManager`.
uniform float caida_de_rapido = 0.08;
// La estela de espuma detras de las piedras del rapido, y la espuma viva: comunes con la
// lamina.
#include "res://shaders/espuma_viva.gdshaderinc"
#include "res://shaders/estela_de_piedras.gdshaderinc"
uniform float veces_para_romper = 5.0;
// La linea del agua de `AguaDelCauce`: por debajo, la mascara es ribera mojada y no se
// pinta agua. Pintando desde 0,005 la orilla se metia metros en tierra (2026-09-15).
uniform float linea_del_agua = 0.5;
uniform vec3 foam_color : source_color = vec3(0.82, 0.88, 0.90);
// Tamano de las manchas de espuma, en metros
uniform float foam_tile_m : hint_range(1.0, 40.0) = 8.0;
// Lo rapido que baja la espuma respecto al agua. Por encima de 1 porque la
// espuma va en la lamina superficial, que corre mas que la media de la seccion.
uniform float foam_drift : hint_range(0.0, 3.0) = 1.35;

group_uniforms antitiling;
// Romper la rejilla de la textura repetida.
//
// Una tesela de cuatro metros sobre una ladera de un kilometro se repite
// doscientas cincuenta veces, y el ojo lee esa regularidad como un enrejado
// muchisimo antes que como hierba. Comprobado con la vista de diagnostico: en
// la de capa dominante el enrejado NO esta, o sea que no lo produce el reparto
// de materiales sino la textura.
//
// Las dos palancas de aqui cuestan aritmetica y NINGUN muestreo extra, que es
// lo que las hace viables: el shader ya iba justo. La alternativa buena
// -teselado estocastico, muestrear dos veces con giro y mezclar- cuesta el
// doble de fetches y se queda para el tier alto si esto no basta.

// 1. Desplazar las coordenadas con ruido de onda larga. Deshace la ALINEACION
//    de la rejilla: las teselas dejan de estar en filas y columnas.
uniform float warp_amount : hint_range(0.0, 8.0) = 2.6;
uniform float warp_scale_m : hint_range(4.0, 200.0) = 38.0;

// 2. Y lo que de verdad la mata: muestrear LA MISMA capa a una escala mucho
//    mayor y usarla para modular el color.
//
//    El desplazamiento solo mueve la rejilla; el contenido sigue siendo el
//    mismo parche repitiendose, y el ojo lo pilla igual. Esto cambia el
//    CONTENIDO: la copia grande aporta manchas claras y oscuras sacadas de la
//    propia fotografia, no de un ruido, asi que se parecen a lo que la textura
//    ya tiene. Y como el factor no es entero, el patron combinado tarda ocho
//    veces mas en repetirse.
//
//    Cuesta UN muestreo, y de un solo plano porque es una senal de onda larga.
// --- Teselado estocástico ---------------------------------------------------
// Ver `hex_sample`. Es lo único que quita de verdad la cuadrícula de la textura
// repetida; el desplazamiento por ruido y la copia a escala grande la disimulan
// pero no la quitan, porque el patrón sigue estando ahí.
uniform bool use_hex_tiling = true;
// Cuánto gira cada parche. Uno es giro libre. Se baja sólo si el material tiene
// dirección -vetas, ladrillo-, y ninguno de los nuestros la tiene.
uniform float hex_rotation : hint_range(0.0, 1.0) = 1.0;
// La corrección de contraste de la mezcla. Por encima de 0,9 empieza a
// asomar la rejilla hexagonal; por debajo de 0,6 el material se lava.
uniform float hex_contrast : hint_range(0.51, 0.95) = 0.75;

uniform float macro_break : hint_range(0.0, 1.0) = 0.85;
uniform float macro_break_factor : hint_range(2.0, 20.0) = 7.7;

group_uniforms debug;
// Vista de diagnostico. 0 normal · 1 que capa manda en cada punto, como color
// plano · 2 albedo sin mezclar con nada, para mirar la teselacion sola.
//
// Existe porque «se ve una cuadricula» tiene al menos tres causas posibles -la
// textura que se repite, el reparto de capas, o la variacion de mancha- y
// mirando el terreno acabado no se distinguen. Pintando la capa dominante se
// distinguen en una captura.
uniform int debug_view : hint_range(0, 2) = 0;

group_uniforms performance;
// Los normal maps duplican el numero de muestreos. Desactivarlos es la palanca
// mas directa para ganar frames en mundos grandes.
uniform bool use_normal_maps = true;
// Por debajo de este peso un material o un plano no aporta nada visible y se
// salta su muestreo.
uniform float weight_cutoff : hint_range(0.0, 0.1) = 0.02;

// Corte de PLANO, aparte del de material y mucho mas agresivo.
//
// Son dos cosas distintas y por eso llevan dos numeros. Descartar un material
// se ve: es un color que desaparece de la mezcla. Descartar un plano no, porque
// el plano no aporta color propio sino la misma textura mirada desde otro eje,
// y su peso se reparte entre los que quedan (ver fragment). O sea que aqui se
// puede cortar donde alli no.
uniform float plane_cutoff : hint_range(0.0, 0.3) = 0.15;

varying vec3 world_position;
varying vec3 world_normal;
varying float vertex_height_normalized;

void vertex() {
	// Alto y Ultra: el lecho del rio se hunde bajo la lamina SOLO AL DIBUJAR, en
	// proporcion a lo entero de la lamina (`AguaDelCauce.LECHO_M`). Los mapas de alturas
	// no se tocan: la banda anda y vadea con los de siempre. Cero sin lamina encima.
	if (lecho_hondo > 0.0) {
		VERTEX.y -= lecho_hondo * smoothstep(linea_del_agua, 0.95, COLOR.a);
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vertex_height_normalized = clamp((world_position.y - cota_base)
		/ max(max_world_height - cota_base, 0.001), 0.0, 1.0);
}

// Calcula los pesos para tri-planar mapping
vec3 get_triplanar_weights(vec3 normal, float sharpness) {
	vec3 weights = abs(normal);
	weights = pow(weights, vec3(sharpness));
	weights = weights / (weights.x + weights.y + weights.z);
	return weights;
}

// --- Teselado estocástico (hex-tiling) -------------------------------------
//
// Lo que de verdad quita la cuadrícula. Es el «histogram-preserving blending»
// de Heitz y Neyret (HPG 2018) en la forma práctica de Mikkelsen (JCGT 2022):
// se parte el plano en una rejilla triangular, cada vértice coge un trozo
// DISTINTO de la textura -desplazado y girado por su propio azar- y se mezclan
// los tres que tocan cada píxel.
//
// La gracia no es mezclar, que eso es viejo y emborrona: es cómo se mezcla. Una
// media de tres muestras baja el contraste y apaga el material -tres piedras
// distintas promediadas dan gris-. Aquí los pesos se sesgan hacia la muestra
// dominante con una potencia alta y después se corrige la ganancia, así que el
// resultado conserva el histograma del original: sigue habiendo negros y
// blancos, no una papilla.
//
// Cuesta TRES muestreos en vez de uno, y por eso sólo lo lleva el albedo: es
// donde se ve la repetición. Un mapa de normales teselado se nota mucho menos
// porque el relieve fino se pierde con la distancia antes que el color.

// Rejilla triangular: los tres vértices que tocan este punto y su peso.
void hex_grid(out float w1, out float w2, out float w3,
		out ivec2 v1, out ivec2 v2, out ivec2 v3, vec2 st) {
	st *= 3.4641016;
	mat2 skew = mat2(vec2(1.0, 0.0), vec2(-0.57735027, 1.15470054));
	vec2 skewed = skew * st;

	ivec2 base = ivec2(floor(skewed));
	vec3 f = vec3(fract(skewed), 0.0);
	f.z = 1.0 - f.x - f.y;

	float pick = step(0.0, -f.z);
	float turn = 2.0 * pick - 1.0;

	w1 = -f.z * turn;
	w2 = pick - f.y * turn;
	w3 = pick - f.x * turn;

	v1 = base + ivec2(int(pick), int(pick));
	v2 = base + ivec2(int(pick), int(1.0 - pick));
	v3 = base + ivec2(int(1.0 - pick), int(pick));
}

vec2 hex_hash(vec2 p) {
	mat2 m = mat2(vec2(127.1, 269.5), vec2(311.7, 183.3));
	return fract(sin(m * p) * 43758.5453);
}

vec2 hex_centre(ivec2 vertex) {
	mat2 unskew = mat2(vec2(1.0, 0.0), vec2(0.5, 0.86602540));
	return (unskew * vec2(vertex)) / 3.4641016;
}

// Cada hexágono gira su trozo de textura un ángulo propio. Sin giro se ve que
// todos los parches son la misma imagen desplazada; con giro, no.
mat2 hex_turn(ivec2 idx, float amount) {
	float angle = abs(float(idx.x * idx.y)) + abs(float(idx.x + idx.y)) + PI;
	angle = mod(angle, 2.0 * PI);
	if (angle > PI) { angle -= 2.0 * PI; }
	angle *= amount;
	float cs = cos(angle);
	float sn = sin(angle);
	return mat2(vec2(cs, sn), vec2(-sn, cs));
}

// La corrección de ganancia que conserva el histograma. Sin ella la mezcla de
// tres muestras sale lavada justo en las costuras.
vec3 hex_gain(vec3 x, float r) {
	float k = log(1.0 - r) / log(0.5);
	vec3 up = 2.0 * step(vec3(0.5), x);
	vec3 down = 2.0 * (1.0 - up);
	vec3 out_v = 0.5 * up + 0.25 * down
		* pow(max(vec3(0.0), up + x * down), vec3(k));
	return out_v / max(out_v.x + out_v.y + out_v.z, 0.0001);
}

// Un muestreo de la capa `layer` con teselado estocástico.
vec4 hex_sample(sampler2DArray tex, float layer, vec2 st,
		vec2 ddx, vec2 ddy) {
	float w1, w2, w3;
	ivec2 v1, v2, v3;
	hex_grid(w1, w2, w3, v1, v2, v3, st);

	mat2 r1 = hex_turn(v1, hex_rotation);
	mat2 r2 = hex_turn(v2, hex_rotation);
	mat2 r3 = hex_turn(v3, hex_rotation);

	vec2 c1 = hex_centre(v1);
	vec2 c2 = hex_centre(v2);
	vec2 c3 = hex_centre(v3);

	// Cada muestra lleva SUS derivadas giradas: si se pasaran sin girar, el
	// nivel de mipmap sería el de otra orientación y saldrían costuras justo
	// donde se cruzan los parches.
	vec4 s1 = textureGrad(tex,
		vec3(r1 * (st - c1) + c1 + hex_hash(vec2(v1)), layer),
		r1 * ddx, r1 * ddy);
	vec4 s2 = textureGrad(tex,
		vec3(r2 * (st - c2) + c2 + hex_hash(vec2(v2)), layer),
		r2 * ddx, r2 * ddy);
	vec4 s3 = textureGrad(tex,
		vec3(r3 * (st - c3) + c3 + hex_hash(vec2(v3)), layer),
		r3 * ddx, r3 * ddy);

	// Los pesos se sesgan hacia la muestra dominante -la potencia alta es lo
	// que evita la papilla- y se ponderan por luminancia, para que un parche
	// oscuro no se coma a uno claro sólo por caer más cerca del centro.
	vec3 luma = vec3(dot(s1.rgb, vec3(0.299, 0.587, 0.114)),
		dot(s2.rgb, vec3(0.299, 0.587, 0.114)),
		dot(s3.rgb, vec3(0.299, 0.587, 0.114)));
	luma = mix(vec3(1.0), luma, 0.6);
	vec3 w = luma * pow(vec3(w1, w2, w3), vec3(7.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	w = hex_gain(w, hex_contrast);

	return w.x * s1 + w.y * s2 + w.z * s3;
}

// Muestrea una textura usando tri-planar mapping, saltando los planos que no
// aportan. En terreno de heightmap la normal apunta casi siempre hacia arriba,
// asi que dos de los tres planos suelen tener peso cero.
//
// Se usa textureGrad y no texture porque dentro de control de flujo divergente
// el LOD implicito queda indefinido: las derivadas hay que calcularlas fuera
// de las ramas o el mipmap sale mal justo en los bordes entre materiales.
vec4 triplanar_texture(sampler2DArray tex, float layer, float tile,
		vec3 pos, vec3 dpdx, vec3 dpdy, vec3 weights) {
	float s = 1.0 / max(tile, 0.01);
	vec4 result = vec4(0.0);
	// Los pesos llegan ya recortados a cero por `plane_cutoff`, asi que basta
	// comparar contra cero: el plano que no aporta ni se pide.
	if (weights.x > 0.0) {
		result += (use_hex_tiling
			? hex_sample(tex, layer, pos.zy * s, dpdx.zy * s, dpdy.zy * s)
			: textureGrad(tex, vec3(pos.zy * s, layer),
				dpdx.zy * s, dpdy.zy * s)) * weights.x;
	}
	if (weights.y > 0.0) {
		result += (use_hex_tiling
			? hex_sample(tex, layer, pos.xz * s, dpdx.xz * s, dpdy.xz * s)
			: textureGrad(tex, vec3(pos.xz * s, layer),
				dpdx.xz * s, dpdy.xz * s)) * weights.y;
	}
	if (weights.z > 0.0) {
		result += (use_hex_tiling
			? hex_sample(tex, layer, pos.xy * s, dpdx.xy * s, dpdy.xy * s)
			: textureGrad(tex, vec3(pos.xy * s, layer),
				dpdx.xy * s, dpdy.xy * s)) * weights.z;
	}
	return result;
}

// Igual que la anterior pero reorientando las normales de cada eje
vec3 triplanar_normal(sampler2DArray tex, float layer, float tile,
		vec3 pos, vec3 dpdx, vec3 dpdy, vec3 weights) {
	float s = 1.0 / max(tile, 0.01);
	vec3 result = vec3(0.0);
	if (weights.x > 0.0) {
		vec3 n = textureGrad(tex, vec3(pos.zy * s, layer),
			dpdx.zy * s, dpdy.zy * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.zy, abs(n.z) * world_normal.x);
		result += n.zyx * weights.x;
	}
	if (weights.y > 0.0) {
		vec3 n = textureGrad(tex, vec3(pos.xz * s, layer),
			dpdx.xz * s, dpdy.xz * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.xz, abs(n.z) * world_normal.y);
		result += n.xzy * weights.y;
	}
	if (weights.z > 0.0) {
		vec3 n = textureGrad(tex, vec3(pos.xy * s, layer),
			dpdx.xy * s, dpdy.xy * s).rgb * 2.0 - 1.0;
		n = vec3(n.xy + world_normal.xy, abs(n.z) * world_normal.z);
		result += n.xyz * weights.z;
	}
	return result;
}

// El ORM se muestrea por UN SOLO plano, el dominante, y no por los tres.
//
// No es un atajo sin criterio: oclusion y rugosidad son senales de baja
// frecuencia y de rango corto -no dibujan silueta, modulan luz-, asi que el
// error de proyectarlas por un solo eje en una ladera no se ve. Y el ahorro es
// grande, porque anadir el ORM en triplanar completo habria subido los
// muestreos por fragmento un cincuenta por ciento, que es justo lo que este
// shader no puede pagar.
// Muestreo por el plano dominante, para senales de onda larga que no dibujan
// silueta. Lo usan el ORM y la copia a escala grande del anti-teselado.
vec4 uniplanar(sampler2DArray tex, float layer, float tile, vec3 pos,
		vec3 dpdx, vec3 dpdy, vec3 weights) {
	float s = 1.0 / max(tile, 0.01);
	if (weights.y >= weights.x && weights.y >= weights.z) {
		return textureGrad(tex, vec3(pos.xz * s, layer), dpdx.xz * s, dpdy.xz * s);
	}
	if (weights.x >= weights.z) {
		return textureGrad(tex, vec3(pos.zy * s, layer), dpdx.zy * s, dpdy.zy * s);
	}
	return textureGrad(tex, vec3(pos.xy * s, layer), dpdx.xy * s, dpdy.xy * s);
}

// La copia a escala grande del albedo, tambien con teselado estocastico.
//
// Sin el, ESTA era la unica cuadricula que quedaba en el terreno, y la mas
// visible de todas: `macro_break` muestrea la misma capa a 7,7 veces su tesela
// -treinta metros para la pradera-, asi que las pajas secas que trae la foto de
// `Grass007` se convierten en trazos de casi un metro. Con teselado plano eso
// se repite cada treinta metros y sale como rayas paralelas por todo el prado.
// Se vio comparando las capturas de `AntiTeselaProbe`: con solo hex la vega
// sale limpia, y al añadir la escala grande vuelven las rayas.
vec4 uniplanar_albedo(float layer, float tile, vec3 pos, vec3 dpdx, vec3 dpdy,
		vec3 weights) {
	if (!use_hex_tiling) {
		return uniplanar(terrain_albedo, layer, tile, pos, dpdx, dpdy, weights);
	}
	float s = 1.0 / max(tile, 0.01);
	// El plano dominante, igual que `uniplanar`: a esta escala la diferencia
	// entre planos no se lee, y pedir los tres seria pagar nueve muestreos.
	if (weights.y >= weights.x && weights.y >= weights.z) {
		return hex_sample(terrain_albedo, layer, pos.xz * s,
			dpdx.xz * s, dpdy.xz * s);
	}
	if (weights.x >= weights.z) {
		return hex_sample(terrain_albedo, layer, pos.zy * s,
			dpdx.zy * s, dpdy.zy * s);
	}
	return hex_sample(terrain_albedo, layer, pos.xy * s,
		dpdx.xy * s, dpdy.xy * s);
}

vec4 uniplanar_orm(float layer, float tile, vec3 pos, vec3 dpdx, vec3 dpdy,
		vec3 weights) {
	return uniplanar(terrain_orm, layer, tile, pos, dpdx, dpdy, weights);
}

// La ALTURA de la capa en un punto, SACADA DEL DIBUJO: lo oscuro se hunde y lo
// claro sube.
//
// Peticion del usuario del 2026-09-16, despues de ver la primera version: «las
// partes oscuras de la textura se hundan, mientras las mas claras se eleven
// levemente». La primera leia el canal A del ORM, el mapa de altura empaquetado,
// y ese mapa no casa siempre con lo que se ve: una junta que en el color es negra
// podia estar a media altura. Con el brillo del color, lo que parece hondo ES hondo.
//
// Contra la MEDIA DE LA ZONA y no contra un gris fijo: una roca oscura entera no
// es un agujero, lo son sus juntas. La media sale de un mipmap alto, que es la
// textura promediada y cuesta una muestra.
//
// Una sola muestra por paso y sin tesela hexagonal: la marcha pregunta hasta
// veinticuatro veces por pixel y la tesela estocastica cuesta tres cada vez.
vec2 uv_de_la_capa(float tile, vec3 pos, vec3 weights) {
	float s = 1.0 / max(tile, 0.001);
	vec2 uv = pos.xz * s;
	if (weights.y < max(weights.x, weights.z)) {
		uv = weights.x >= weights.z ? pos.zy * s : pos.xy * s;
	}
	return uv;
}

const vec3 BRILLO = vec3(0.299, 0.587, 0.114);

// La cuesta de la ALTURA en la capa, en el plano dominante, lista para sumarla a la
// normal de `triplanar_normal`: cada plano mete las dos componentes en los mismos
// ejes de mundo que mete ahi las de su textura de normales.
//
// Diferencias finitas sobre la textura DESENFOCADA (`desenfoque_de_la_piedra`): dos
// muestras mas, y la cuesta es la de la piedra y no la de sus motas.
vec3 bulto_de_la_capa(float layer, float tile, vec3 pos, vec3 weights) {
	float s = 1.0 / max(tile, 0.001);
	float e = texeles_del_bulto / float(textureSize(terrain_orm, 0).x);
	vec2 uv;
	int plano;
	if (weights.y >= weights.x && weights.y >= weights.z) {
		uv = pos.xz * s;
		plano = 1;
	} else if (weights.x >= weights.z) {
		uv = pos.zy * s;
		plano = 0;
	} else {
		uv = pos.xy * s;
		plano = 2;
	}
	// DE LA ALTURA, COMO EL DESPLAZAMIENTO. Desde el 2026-09-17 el parallax mueve el dibujo
	// segun el mapa de altura, y esto seguia sombreandolo segun el BRILLO: dos fuentes que
	// se contradecian, y donde una decia hueco y la otra bulto salian manchas. El usuario
	// lo conto asi: «o no se esta aplicando el height map correcto o hay otra cosa
	// interfiriendo... parece que tiene lepra» (2026-09-18).
	float h = texture(terrain_orm, vec3(uv, layer), desenfoque_de_la_piedra).a;
	float hu = texture(terrain_orm, vec3(uv + vec2(e, 0.0), layer), desenfoque_de_la_piedra).a;
	float hv = texture(terrain_orm, vec3(uv + vec2(0.0, e), layer), desenfoque_de_la_piedra).a;
	// Normal de una cuesta: (-dh/du, -dh/dv). La escala va por texel, no por uv,
	// para que la fuerza no cambie con la resolucion de la textura.
	vec2 cuesta = -vec2(hu - h, hv - h) * fuerza_del_bulto * layer_relieve[int(layer)];
	if (plano == 1) {
		return vec3(cuesta.x, 0.0, cuesta.y);
	} else if (plano == 0) {
		return vec3(0.0, cuesta.y, cuesta.x);
	}
	return vec3(cuesta.x, cuesta.y, 0.0);
}

// LA ALTURA DE LA PIEDRA, del mapa de altura y no del dibujo.
//
// Viene en el ALFA del ORM, empaquetada desde el `Displacement` de ambientCG por
// `TerrainTextureIngest`. Estaba ahi desde el principio y no la miraba nadie: hasta el
// 2026-09-17 esto sacaba la altura del brillo del albedo, porque el dia que se hizo el
// parallax la de verdad no estaba enchufada y el usuario pidio «que se hunda lo oscuro del
// dibujo» (2026-09-16). Esa decision se retira con esta.
//
// **Y no era lo mismo**, medido capa por capa sobre las texturas de verdad: la correlacion
// entre brillo y altura es de **0,02 en el roquedo calizo** y 0,09 en la pradera. O sea que
// el relieve que se veia en la caliza no tenia NADA que ver con su relieve. De paso, el
// alfa trae relieve de sobra donde hace falta: desviacion tipica de 0,22 en el roquedo.
//
// El desenfoque sigue siendo el mismo ([desenfoque_de_la_piedra]): la altura tambien tiene
// motas, y lo que se quiere leer son las piedras, no sus granos.
float altura_de_la_capa(float layer, float tile, vec3 pos, vec3 weights) {
	float alto = texture(terrain_orm, vec3(uv_de_la_capa(tile, pos, weights), layer),
		desenfoque_de_la_piedra).a;
	// El contraste se queda como mando: un `Displacement` flojo se puede subir sin tocar
	// la textura. A 1 es la altura tal cual.
	return clamp(0.5 + (alto - 0.5) * contraste_del_relieve, 0.0, 1.0);
}

// Lo que hay que desplazar la textura para que se vea el relieve.
//
// Es parallax CON OCLUSION: se recorre el rayo de la vista por dentro de la capa
// hasta topar con la altura. Al topar, lo alto tapa lo bajo -una piedra esconde el
// canto de detras- y eso es lo que no puede dar un mapa de normales.
//
// Va en MUNDO y no en UV a proposito: aqui se textura desde la posicion de mundo
// con tres planos, asi que un desplazamiento en UV habria que hacerlo tres veces y
// no casaria en las mezclas. Proyectando la vista sobre la superficie sale uno solo
// que vale para el suelo y para la pared.
vec3 relieve_desplazado(float layer, float tile, vec3 pos, vec3 normal_mundo,
		vec3 hacia_el_ojo, vec3 weights, float fuerza, inout float altura) {
	vec3 vista = -hacia_el_ojo;
	vec3 tangente = vista - normal_mundo * dot(vista, normal_mundo);
	float largo = length(tangente);
	if (fuerza <= 0.0) {
		return vec3(0.0);
	}
	// Mirando de frente no hay nada que desplazar, pero la junta sigue siendo
	// honda: se devuelve la altura igual.
	if (largo < 0.001) {
		altura = altura_de_la_capa(layer, tile, pos, weights);
		return vec3(0.0);
	}
	// Cuanto mas rasante se mira, mas se desplaza: es el mismo triangulo de
	// siempre, la tangente partida por la componente que mira de frente.
	float de_frente = max(abs(dot(vista, normal_mundo)), 0.15);
	vec3 paso_total = tangente / de_frente * tile * relieve_de_la_tesela * fuerza
		* layer_relieve[int(layer)];
	float paso = 1.0 / float(relieve_pasos);
	float rayo = 0.0;
	float alto = altura_de_la_capa(layer, tile, pos, weights);
	float rayo_antes = 0.0;
	float alto_antes = alto;
	for (int i = 0; i < relieve_pasos; i++) {
		if (rayo >= 1.0 - alto) {
			break;
		}
		rayo_antes = rayo;
		alto_antes = alto;
		rayo += paso;
		alto = altura_de_la_capa(layer, tile, pos + paso_total * rayo, weights);
	}
	// SIN ESCALONES: el rayo se para en el primer paso que queda por debajo, y eso
	// dibuja la piedra en terrazas, una por paso. Se busca el cruce entre ese paso y
	// el anterior, en linea recta, que es lo que la deja lisa.
	float debajo = (1.0 - alto) - rayo;
	float encima = (1.0 - alto_antes) - rayo_antes;
	float donde = clamp(encima / max(encima - debajo, 0.0001), 0.0, 1.0);
	rayo = mix(rayo_antes, rayo, donde);
	altura = mix(alto_antes, alto, donde);
	return paso_total * rayo;
}

// Devuelve DOS canales de una vez. La version anterior llamaba tres veces a un
// ruido escalar para armar el desplazamiento, y eso -mas un tinte por ruido a
// dos escalas- costaba 3,3 ms medidos. Con dos canales por llamada y sin el
// tinte, el desplazamiento sale por una fraccion de eso.
vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

vec2 value_noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 a = hash22(cell);
	vec2 b = hash22(cell + vec2(1.0, 0.0));
	vec2 c = hash22(cell + vec2(0.0, 1.0));
	vec2 d = hash22(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Desatura hacia el gris de misma luminancia y despues tinta. En ese orden: al
// reves, el tinte se diluiria justo en las capas que mas hay que corregir.
vec3 grade(vec3 c, int layer) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(lum), c, layer_saturation[layer]) * layer_tint[layer];
}

// Un color por capa, para la vista de diagnostico
vec3 layer_color(int i) {
	if (i == 0) { return vec3(0.35, 0.70, 0.20); }  // pradera
	if (i == 1) { return vec3(0.08, 0.30, 0.10); }  // bosque
	if (i == 2) { return vec3(0.72, 0.72, 0.76); }  // roquedo
	if (i == 3) { return vec3(0.58, 0.46, 0.40); }  // canchal
	if (i == 4) { return vec3(0.90, 0.70, 0.30); }  // cantos
	if (i == 5) { return vec3(0.96, 0.88, 0.62); }  // arena
	if (i == 6) { return vec3(0.36, 0.26, 0.18); }  // limo
	return vec3(0.98, 0.98, 1.00);                  // nieve
}

void fragment() {
	vec3 triplanar_weights = get_triplanar_weights(world_normal, triplanar_sharpness);

	// Tirar los planos que no aportan y REPARTIR su peso entre los que quedan.
	//
	// El reparto es lo que permite que el corte sea agresivo. Sin el, el peso
	// descartado simplemente se pierde: la suma baja de 1 y el material se
	// oscurece, asi que el corte tenia que quedarse en 0.02 -un plano que
	// aporta un 2%- y a ese nivel casi no descarta nada. Medido en el sitio 56,
	// una ladera suave da pesos del orden de (0.05, 0.90, 0.05) y los TRES
	// planos pasaban el corte para aportar una veinteava parte cada uno.
	//
	// Con reparto, un plano al 15% se puede tirar entero y el color no cambia,
	// porque su peso se lo llevan los que sí se muestrean. El tope del rango es
	// 0.3 a proposito: los tres pesos suman 1, asi que por debajo de un tercio
	// siempre sobrevive al menos uno y la division nunca se queda sin nada.
	// El descarte se DESVANECE, no corta en seco. Con un `step` puro salian
	// manchas planas de borde duro por toda la ladera: al cruzar el umbral el
	// plano desaparecia de golpe, los pesos de los otros dos pegaban un salto
	// para repartirse el suyo, y el cambio de textura dibujaba la linea de
	// nivel del umbral en el monte.
	//
	// Asi el peso baja suave hasta cero en la mitad inferior del margen y solo
	// se salta el muestreo cuando ya vale cero exacto. Se sigue ahorrando en
	// todo lo que cae por debajo de la mitad del corte, que es la mayor parte,
	// y la transicion no se ve.
	triplanar_weights *= smoothstep(
		vec3(plane_cutoff * 0.5), vec3(plane_cutoff), triplanar_weights);
	triplanar_weights /= max(
		triplanar_weights.x + triplanar_weights.y + triplanar_weights.z, 0.0001);

	// Derivadas de la posicion de mundo, calculadas una sola vez y fuera de
	// cualquier rama. Las de cada plano salen de aqui con un swizzle.
	//
	// Se sacan de la posicion SIN deformar, a proposito: el desplazamiento de
	// abajo es de onda larga, asi que apenas cambia la derivada, y usar la
	// deformada solo serviria para que el nivel de mipmap diese bandazos.
	vec3 dpdx = dFdx(world_position);
	vec3 dpdy = dFdy(world_position);

	// Posicion con la que se TEXTURA, desplazada para que la rejilla de la
	// tesela deje de ser una rejilla. Dos ruidos a distinta escala y girados
	// entre si; con uno solo el desplazamiento tiene direccion y se lee como un
	// estirado.
	vec3 tex_position = world_position;
	if (warp_amount > 0.001) {
		vec2 offset = (value_noise2(world_position.xz / max(warp_scale_m, 1.0))
			- 0.5) * (warp_amount * 2.0);
		tex_position.xz += offset;
	}

	// Calcular pendiente (slope) - 1.0 = vertical, 0.0 = horizontal
	float slope = 1.0 - abs(world_normal.y);
	float height = vertex_height_normalized;

	// Curvatura y mancha, por VERTICE, asi que aqui no cuestan nada.
	// UV2.x trae la curvatura (0.5 plano, >0.5 concavo) y UV2.y la variacion.
	float curvature = 0.0;
	float patch = 0.0;
	if (use_terrain_variation) {
		curvature = UV2.x * 2.0 - 1.0;
		patch = (UV2.y - 0.5) * 2.0;
	}

	// El agua del cauce llega por COLOR.a. La orilla -donde el agua lame pero
	// no cubre- es donde se acumulan los CANTOS, y por eso es una capa de
	// material y ya no un tinte falso sobre la hierba.
	float river = clamp(COLOR.a, 0.0, 1.0);
	// La inclinacion de la CARA, no la de la normal suavizada: en una margen encajada
	// el triangulo que va del vertice de agua al de tierra es una pared, y la humedad
	// interpolada por el repartia cantos y agua talud arriba en DIENTES DE SIERRA
	// (capturas de Medio y Ultra, 2026-09-15). Ni los cantos ni el agua se quedan en una
	// pared. Aqui arriba y fuera de ramas: las derivadas dentro de un `if` no estan
	// garantizadas.
	vec3 normal_de_la_cara = normalize(cross(dFdy(world_position), dFdx(world_position)));
	float en_pared = smoothstep(0.15, 0.5, 1.0 - abs(normal_de_la_cara.y));
	float shore = smoothstep(0.02, 0.30, river)
		* (1.0 - smoothstep(0.35, 0.70, river)) * (1.0 - en_pared);

	// --- Reparto entre las ocho capas ------------------------------------
	//
	// Tres bandas de altura, y dentro de cada una un reparto por lo que
	// distingue de verdad a las dos capas que la comparten. La altura sola no
	// separa pasto de bosque ni arena de marisma: eso lo dicen la pendiente y
	// la curvatura.
	// El borde de la orilla se separa de cero a la fuerza. Con `bands_relative`
	// -que es lo que usa el mapa local- `sand_max_height` sale practicamente 0,
	// y un `smoothstep(0.0, 0.0, x)` tiene los dos bordes iguales, que en GLSL
	// es COMPORTAMIENTO INDEFINIDO. De ahi salia limo de marisma repartido por
	// media ladera.
	float shore_edge = max(sand_max_height, 0.004);
	float band_low = 1.0 - smoothstep(shore_edge * 0.5, shore_edge, height);
	float band_mid = smoothstep(shore_edge * 0.5, shore_edge, height)
		* smoothstep(grass_max_height + 0.1, grass_max_height - 0.1, height);
	float band_top = smoothstep(snow_min_height - 0.1, snow_min_height + 0.1, height);

	// Roca por pendiente, en DOS escalones. El suave es el manto de derrubio
	// que baja de la pared -el canchal- y el fuerte es la pared en si. Antes
	// habia un solo escalon y la transicion se pintaba como un degradado de
	// color; ahora es un material propio, que es lo que de verdad hay ahi.
	float scree_factor = smoothstep(canchal_desde, canchal_hasta, slope);
	float cliff_factor = smoothstep(pared_desde, pared_hasta, slope);

	// Un hondo suave acumula tierra, pero una vaguada marcada en ladera es un
	// barranco: cauce de temporal escarbado hasta la roca. Hacen falta las DOS
	// condiciones, porque solo con la concavidad tambien saldria de roca el
	// fondo llano de un valle.
	float ravine = smoothstep(ravine_curvature, 1.0, curvature)
		* smoothstep(ravine_slope - 0.06, ravine_slope + 0.10, slope)
		* ravine_strength;

	// DONDE HAY BOSQUE LO DICE LA HUMEDAD, la misma con la que se siembran los arboles
	// (`Forest`). Antes salia de la curvatura del terreno y un ruido macro propios: dos
	// criterios distintos para la misma pregunta, asi que **bajo un pinar el suelo podia
	// estar pintado de pradera**. Se vio al entrar la hojarasca de otoño, que cuelga de
	// esta capa y no aparecia (2026-09-18). Decision del usuario: manda la humedad.
	//
	// Con la pendiente, como los arboles: en una ladera empinada no hay bosque aunque
	// haya humedad, y ahi lo que hay es derrubio y peña.
	// Sin textura de humedad —una sonda, el editor— se cae a lo de antes.
	float wood;
	if (use_humedad) {
		vec2 uv_humedad = (world_position.xz - humedad_origen)
			/ max(humedad_extent, vec2(0.001));
		float humedo = texture(humedad_tex, uv_humedad).r;
		// Las bandas salen de las de `Forest.NICHOS`: por debajo de 0,34 no crece casi
		// ninguna especie y por encima de 0,55 crecen todas. El margen ancho es a
		// proposito: con un borde duro el bosque se recorta contra el prado, y lo que hace
		// un bosque de verdad es deshilacharse.
		wood = smoothstep(0.34, 0.55, humedo)
			* (1.0 - smoothstep(0.35, 0.55, slope));
	} else {
		float wood_raw = curvature * curvature_influence + patch * macro_influence;
		wood = smoothstep(-0.55, 0.55, wood_raw);
	}

	// La marisma se queda en lo hondo y lo LLANO: un limo no se sostiene en
	// pendiente. Sin la condicion de pendiente el fango trepaba por la ladera
	// de la ria.
	float marsh = smoothstep(0.05, 0.35, curvature)
		* (1.0 - smoothstep(0.04, 0.12, slope));

	float ground = 1.0 - max(scree_factor, ravine);

	float w[LAYERS];
	w[0] = band_mid * (1.0 - wood) * ground;              // pradera
	w[1] = band_mid * wood * ground;                      // bosque
	w[2] = max(cliff_factor, ravine);                     // roquedo
	w[3] = max(scree_factor - cliff_factor, 0.0);         // canchal
	w[4] = shore;                                         // cantos de rio
	w[5] = band_low * (1.0 - marsh) * ground;             // arena
	w[6] = band_low * marsh * ground;                     // limo
	w[7] = band_top * (1.0 - scree_factor * 0.5);         // nieve
	// LA HOJARASCA NO ES UN SITIO, ES UNA ESTACION (GRAFICOS §7.7). Las otras ocho se
	// reparten por altura, pendiente y orilla; ésta se lleva el suelo de bosque cuando cae
	// la hoja y se lo devuelve en invierno. Por eso sale de su peso y no de otro sitio: en
	// otoño el bosque ES hojarasca, no hojarasca ADEMAS de bosque.
	w[8] = w[1] * hojarasca;                              // hojarasca de otoño
	w[1] -= w[8];                                         // lo que deja de ser bosque

	// Recortar la cola y renormalizar. Es lo que permite quedarse con las dos
	// de mas peso sin que se vea el cambio: una capa que iba a entrar por un
	// dos por ciento llega a cero ANTES de cruzarse con otra, asi que cuando se
	// intercambian el segundo y el tercer puesto los dos valen ya cero y no hay
	// salto. Sin esto, quedarse con dos capas dibuja costuras donde la tercera
	// y la cuarta se adelantan.
	float total = 0.0;
	for (int i = 0; i < LAYERS; i++) {
		w[i] = max(w[i] - weight_cutoff, 0.0);
		total += w[i];
	}
	if (total <= 0.0) {
		// Todo por debajo del corte: se cae a pradera, que es el fondo del
		// valle y el material mas comun.
		w[0] = 1.0;
		total = 1.0;
	}

	// Las DOS de mas peso. Es lo que hace que ocho capas cuesten lo mismo que
	// dos: el bucle es aritmetica sobre ocho flotantes -barata y sin
	// divergencia- y los muestreos son siempre dos, no ocho.
	int i0 = 0;
	int i1 = 0;
	float w0 = -1.0;
	float w1 = -1.0;
	for (int i = 0; i < LAYERS; i++) {
		float wi = w[i];
		if (wi > w0) {
			i1 = i0; w1 = w0;
			i0 = i; w0 = wi;
		} else if (wi > w1) {
			i1 = i; w1 = wi;
		}
	}
	float pair = max(w0 + w1, 0.0001);
	w0 /= pair;
	w1 /= pair;

	// Endurecer la mezcla entre las dos. Se hace AQUI, sobre dos numeros, y no
	// con una potencia sobre los ocho pesos: son ocho `pow` por fragmento que
	// no hacen falta.
	float sharp = clamp((blend_sharpness - 1.0) * 0.5, 0.0, 1.0);
	w1 = mix(w1, w1 * w1 * (3.0 - 2.0 * w1), sharp);
	w0 = 1.0 - w1;

	float layer0 = float(i0);
	float layer1 = float(i1);
	float tile0 = layer_tile_m[i0];
	float tile1 = layer_tile_m[i1];

	// EL RELIEVE, antes de muestrear nada: desplaza la posicion con la que se
	// textura, asi que el color, la normal y el ORM salen ya del sitio correcto.
	// Se apaga con la distancia -de lejos no se distingue y es lo que cuesta- y
	// tambien donde el agua cubre, que ahi lo que manda es la lamina.
	float altura_del_relieve = 1.0;
	float hondo_del_relieve = 0.0;
	if (relieve_pasos > 0) {
		float cerca = 1.0 - smoothstep(relieve_hasta_m * 0.45, relieve_hasta_m,
			length(VERTEX));
		if (cerca > 0.01) {
			vec3 ojo = INV_VIEW_MATRIX[3].xyz;
			vec3 hacia_el_ojo = normalize(ojo - world_position);
			tex_position += relieve_desplazado(layer0, tile0, tex_position,
				world_normal, hacia_el_ojo, triplanar_weights, cerca, altura_del_relieve);
			hondo_del_relieve = cerca;
		}
	}

	vec3 final_color = grade(triplanar_texture(terrain_albedo, layer0, tile0,
		tex_position, dpdx, dpdy, triplanar_weights).rgb, i0) * w0;
	// El fondo de las juntas, mas oscuro. Va en el COLOR y no en la oclusion a
	// proposito: la oclusion de aqui solo toca la luz indirecta (ver abajo) y a
	// pleno sol no se veria.
	final_color *= mix(1.0, mix(1.0 - hondura_de_las_juntas, 1.0, altura_del_relieve),
		hondo_del_relieve);
	vec3 final_normal = vec3(0.0);
	if (use_normal_maps) {
		final_normal = triplanar_normal(terrain_normal, layer0, tile0,
			tex_position, dpdx, dpdy, triplanar_weights) * w0;
		// Y EL MAPA DE NORMALES TAMBIEN VA POR CAPA: inclinar mas sus componentes
		// horizontales es dar mas bulto sin tocar un solo muestreo, que era la via barata
		// que pidio el usuario -«¿no podemos darle relieve solo al canchal con normal map o
		// algo asi?», 2026-09-18-.
		final_normal.xz *= layer_relieve[int(layer0)];
		// Y el bulto que sale del dibujo, con la misma distancia que el relieve.
		if (hondo_del_relieve > 0.0) {
			final_normal += bulto_de_la_capa(layer0, tile0, tex_position,
				triplanar_weights) * w0 * hondo_del_relieve;
		}
	}

	float final_roughness = roughness_fallback;
	float occlusion = 1.0;
	float surface_height = 0.5;
	if (use_orm) {
		vec4 orm0 = uniplanar_orm(layer0, tile0, tex_position,
			dpdx, dpdy, triplanar_weights);
		final_roughness = orm0.g * w0;
		occlusion = orm0.r * w0;
		surface_height = orm0.a * w0;
	}

	// La segunda capa solo si aporta. Por debajo de un dos por ciento no se
	// distingue de no estar, y saltarsela ahorra la mitad de los muestreos en
	// todo lo que no es transicion, que es la mayor parte del mapa.
	if (w1 > 0.02) {
		final_color += grade(triplanar_texture(terrain_albedo, layer1, tile1,
			tex_position, dpdx, dpdy, triplanar_weights).rgb, i1) * w1;
		if (use_normal_maps) {
			final_normal += triplanar_normal(terrain_normal, layer1, tile1,
				tex_position, dpdx, dpdy, triplanar_weights) * w1;
		}
		if (use_orm) {
			vec4 orm1 = uniplanar_orm(layer1, tile1, tex_position,
				dpdx, dpdy, triplanar_weights);
			final_roughness += orm1.g * w1;
			occlusion += orm1.r * w1;
			surface_height += orm1.a * w1;
		}
	} else if (use_orm) {
		// Con una sola capa los pesos no suman 1 y todo saldria oscuro y liso
		float inv = 1.0 / max(w0, 0.0001);
		final_roughness *= inv;
		occlusion *= inv;
		surface_height *= inv;
	}

	if (use_orm) {
		final_roughness = clamp(final_roughness * roughness_scale, 0.04, 1.0);
	}

	// La copia a escala grande de la MISMA capa. Ver `macro_break`.
	//
	// Se mezcla como "overlay" y no multiplicando: multiplicar solo oscurece y
	// el terreno se apaga entero, mientras que overlay aclara donde la copia
	// grande es clara y oscurece donde es oscura, que es lo que hace que unas
	// manchas se lean mas secas y otras mas verdes sin cambiar el brillo medio.
	if (macro_break > 0.001) {
		vec3 wide = grade(uniplanar_albedo(layer0, tile0 * macro_break_factor,
			tex_position, dpdx, dpdy, triplanar_weights).rgb, i0);
		vec3 overlay = mix(2.0 * final_color * wide,
			1.0 - 2.0 * (1.0 - final_color) * (1.0 - wide),
			step(vec3(0.5), final_color));
		final_color = mix(final_color, overlay, macro_break);
	}

	// --- Agua ------------------------------------------------------------
	// El color de vertice trae la hidrografia entera: rg el sentido de la
	// corriente, b si el agua esta quieta, a la lamina. `river` ya se calculo
	// arriba, porque de el sale la orilla de cantos.
	float specular_out = terrain_specular;
	// El termino de depuracion, SIN LUZ: con la iluminacion encima no se distingue un
	// dibujo del termino de un brillo de la geometria. Ver `ver_termino`.
	float termino_sin_luz = -1.0;
	// Cuanto de este pixel es agua del rio: ahi no se moja ni cuaja. Lo pone el bloque del rio.
	float es_agua = 0.0;

	if (use_rivers && river > 0.005) {
		vec2 flow = COLOR.rg * 2.0 - 1.0;
		float still = COLOR.b;
		float flow_len = length(flow);
		// Sin direccion util -laguna, o celda suelta- se usa un eje fijo, que
		// con velocidad cero da agua quieta y no un patron desfilando
		vec2 dir = flow_len > 0.01 ? flow / flow_len : vec2(1.0, 0.0);

		float speed = water_flow_speed * (1.0 - still);

		// Flow map: la textura se arrastra en la direccion de la corriente y
		// se reinicia cada ciclo. Para que el salto no se vea, se muestrean
		// DOS fases desfasadas media vuelta y se cruzan segun avanza el ciclo:
		// mientras una se reinicia la otra esta en su punto mas estable.
		//
		// Esto sustituye a los senos analiticos que habia aqui. Aquello daba
		// galones y espinas de pescado, porque la direccion de la corriente se
		// interpola por fragmento y en la orilla, donde los vertices tienen
		// flujo cero, la fase pegaba bandazos de un pixel al siguiente.
		// PERIODO FIJO Y DESPLAZAMIENTO VARIABLE: la fase no puede ser `fract(TIME * speed)`.
		// `speed` se interpola y cambia de un pixel al siguiente -sobre todo junto al agua
		// quieta-, y con unos segundos de TIME dos pixeles vecinos dan la vuelta al ciclo en
		// sitios distintos: el dibujo se cortaba por lineas que siguen los triangulos de la
		// malla (captura de cerca, 2026-09-15). Todos giran a la vez y la velocidad solo dice
		// cuanto se desplaza el dibujo dentro del ciclo.
		float periodo = 4.0;
		float phase_a = fract(TIME / periodo);
		float phase_b = fract(TIME / periodo + 0.5);
		float cross_fade = abs(1.0 - 2.0 * phase_a);
		vec2 recorrido = flow * speed * periodo / max(water_tile_m, 1.0);

		vec2 base_uv = world_position.xz / max(water_tile_m, 1.0);
		vec3 n_a = texture(water_normal_tex, base_uv - recorrido * phase_a).rgb * 2.0 - 1.0;
		vec3 n_b = texture(water_normal_tex, base_uv - recorrido * phase_b + 0.37).rgb * 2.0 - 1.0;
		vec3 ripple = mix(n_a, n_b, cross_fade);

		// Oleaje de fondo: misma tesela mucho mas grande y mas lenta, para que
		// el rio no sea un patron unico repetido. El mismo ciclo, y un tercio del recorrido.
		vec2 swell_uv = world_position.xz / max(water_swell_tile_m, 1.0);
		vec2 recorrido_lento = flow * speed * 0.35 * periodo / max(water_swell_tile_m, 1.0);
		vec3 swell = mix(
			texture(water_normal_tex, swell_uv - recorrido_lento * phase_a).rgb,
			texture(water_normal_tex, swell_uv - recorrido_lento * phase_b + 0.53).rgb,
			cross_fade) * 2.0 - 1.0;

		vec3 water_normal = normalize(vec3(
			(ripple.xy + swell.xy * 0.7) * water_normal_strength, 1.0));

		// La lamina fina deja ver el fondo; el centro del cauce es mas hondo
		float depth = smoothstep(0.15, 0.85, river);
		vec3 water_color = mix(river_shallow_color, river_color, depth);

		// Rapidos: cuanto DESCIENDE el cauce en la direccion de la corriente. Viene
		// horneado en UV.x (`AguaDelCauce.rapido`). Se sacaba aqui de la normal
		// del terreno, y la normal no distingue un escalon del cauce de la ladera
		// de la margen: la espuma salia en vetas pegadas a la orilla (GRAFICOS §7.3).
		float rapids = smoothstep(caida_de_rapido, caida_de_rapido * veces_para_romper, UV.x)
			* (1.0 - still) * depth;

		// La espuma VIAJA. Antes era una funcion fija de la pendiente, o sea
		// una mancha blanca clavada en el sitio mientras el agua corria por
		// debajo, que es justo lo que no hace la espuma. Ahora son manchas que
		// bajan con la corriente, y algo mas rapido que ella porque van en la
		// lamina superficial.
		//
		// Dos capas a distinta escala y velocidad: una sola se lee como un
		// patron repetido desfilando.
		// Ya no es una textura arrastrada: ver `espuma_viva`.
		// EL RUIDO VIVO, SOLO DONDE SE USA. Calculado en todo pixel de rio, el agua de
		// Medio paso de 0,1-0,6 ms a 1,5-4,6 ms de GPU (AguaCaptura GPU=1, 2026-09-16), por
		// encima del tope de 1 ms: la espuma viva son tres ruidos de cuatro octavas.
		// Y en Alto y Ultra el terreno no pinta el agua -la pinta la lamina, ver
		// `lecho_hondo` abajo-: ahi la espuma no se calcula.
		bool pinta_el_agua = lecho_hondo <= 0.0 || ver_espuma || ver_termino > 0;
		float churn = 0.0;
		if (rapids > 0.0 && pinta_el_agua) {
			churn = espuma_viva(world_position.xz, flow, speed * foam_drift, foam_tile_m * 0.35, 1.0, 2);
		}

		// En el rapido fuerte la espuma cubre casi entero; en el suave solo
		// asoman las vetas. Por eso la turbulencia no multiplica sin mas: se
		// mezcla hacia 1 segun crece el rapido.
		// Vetas y no manta: medida la caida en el cauce, un torrente entero es rapido,
		// y mezclando hacia blanco segun crecia el rapido salia blanco de punta a punta
		// (AguaCaptura, 2026-09-15). Como en el Pas, agua oscura con la espuma rota
		// en manchas que crecen con la caida.
		float foam = rapids * smoothstep(0.55, 0.85, churn + rapids * 0.2);
		if (con_piedras) {
			// LA ESPUMA DETRAS DE LAS PIEDRAS, y el resto del rapido casi limpio: vuelta del
			// usuario del 2026-09-15 mirando el Pas. La estela se busca aguas ARRIBA: este
			// punto tiene espuma si hay una piedra a una, dos o tres celdas contra corriente.
			// Las piedras sólo están en los rápidos (`AguaDelCauce.RAPIDO_CON_PIEDRAS`): fuera
			// de donde el cauce cae, ni se buscan. Ver `churn`.
			float estela = 0.0;
			float cerca_de_piedras = smoothstep(caida_de_rapido * 0.25, caida_de_rapido * 0.6, UV.x);
			if (cerca_de_piedras > 0.0 && flow_len > 0.05 && pinta_el_agua) {
				estela = estela_viva(world_position.xz, dir, flow, speed * foam_drift, 2, churn)
					* smoothstep(0.05, 0.3, flow_len) * cerca_de_piedras;
			}
			// Donde la corriente se anula, `dir` salta a un eje fijo: sin apagarla ahi, la
			// estela y la espuma salian en triangulos sueltos junto a la orilla.
			float suelta = smoothstep(0.70, 0.86, churn) * 0.45;
			foam = max(estela, rapids * suelta);
		}
		water_color = mix(water_color, foam_color, foam * 0.75);

		// --- Medio: la orilla (GRAFICOS §7.3) ---
		// Lo hondo, mas oscuro; lo somero deja ver el fondo de cantos, que ya es la
		// capa CANTOS de la ribera; y una franja de espuma donde el agua lame la
		// tierra, horneada en UV.y (`AguaDelCauce.orilla`), que respira un poco.
		// EL AGUA EMPIEZA EN LA LINEA DEL AGUA, y se funde un poco a cada lado de ella.
		// EN UNA CARA EMPINADA, LA LINEA SUBE HACIA EL AGUA DE VERDAD. En una margen
		// encajada el vertice de tierra esta metros por encima del de agua, y la
		// humedad interpolada pintaba agua talud arriba en dientes de sierra, con una
		// mancha de espuma en cada punta (capturas de Medio, 2026-09-15). El agua no se
		// queda en una pared: ahi solo cuenta lo que es agua casi entera.
		float linea_aqui = mix(linea_del_agua, 0.9, en_pared);
		float agua = smoothstep(linea_aqui - 0.08, linea_aqui + 0.05, river);
		es_agua = agua;
		float cubre = agua;
		float espuma_de_orilla = 0.0;
		if (nivel_de_agua >= 1) {
			water_color = mix(water_color, river_color * 0.55,
				smoothstep(0.75, 1.0, river) * honda_oscurece);
			cubre = agua * mix(somera_cubre, 1.0, depth);
			// UNA BANDA FINA JUSTO POR DENTRO DE LA LINEA DEL AGUA. La orilla horneada
			// (UV.y) solo dice que la celda toca tierra, y va por celda de 5 m: repartida
			// por el triangulo, en un rio estrecho cubria casi todo el ancho. Donde cae la
			// linea dentro del triangulo lo sabe la mascara interpolada, y ahi va la
			// espuma. Y la textura, grande y cruzada consigo misma girada: a 4 m se leia
			// un dibujo de galones repetido.
			float orilla = step(0.01, UV.y) * agua
				* (1.0 - smoothstep(linea_aqui + 0.04, linea_aqui + 0.16, river));
			// La orilla LAME: espuma viva, casi quieta pero que se forma y se deshace
			// deprisa. Con la textura fija eran manchas constantes de forma irreal (queja
			// del usuario del 2026-09-15).
			if (orilla > 0.0 && pinta_el_agua) {
				float lamido = espuma_viva(world_position.xz, flow, 0.15, 1.2, 2.5, 2);
				espuma_de_orilla = orilla * smoothstep(0.52, 0.74, lamido) * 0.8;
			}
			water_color = mix(water_color, foam_color, espuma_de_orilla * 0.75);
			// La espuma no deja ver el fondo: donde la hay, el agua cubre.
			cubre = mix(cubre, agua, espuma_de_orilla);
			foam = max(foam, espuma_de_orilla);
		}
		if (ver_espuma) {
			water_color = vec3(foam, 0.0, 0.0);
			cubre = agua > 0.0 ? 1.0 : 0.0;
		}
		if (ver_termino > 0) {
			float t = ver_termino == 1 ? clamp(UV.x * 4.0, 0.0, 1.0)
				: ver_termino == 2 ? churn
				: ver_termino == 3 ? (con_piedras ? estela_de_piedras(world_position.xz, dir) : 0.0)
				: ver_termino == 4 ? foam
				: ver_termino == 5 ? flow_len
				: ver_termino == 6 ? still
				: clamp(UV.y, 0.0, 1.0);
			water_color = vec3(t);
			termino_sin_luz = agua > 0.0 ? t : -1.0;
			cubre = agua > 0.0 ? 1.0 : 0.0;
		}

		// Aqui habia un tinte que aclaraba el pasto de la ribera para fingir
		// grava. Ya no hace falta: la orilla es la capa CANTOS, con su
		// fotogrametria de canto rodado, y se reparte con las demas como
		// cualquier otro material.

		if (lecho_hondo > 0.0 && !ver_espuma) {
			// Alto y Ultra: el agua la dibuja la lamina. Aqui solo el lecho, mojado:
			// mas oscuro y algo verdoso bajo el agua, y liso de brillo.
			float mojado = agua;
			final_color = mix(final_color, final_color * vec3(0.52, 0.60, 0.56), mojado);
			final_roughness = mix(final_roughness, 0.4, mojado);
		} else {
			final_color = mix(final_color, water_color, cubre);
			// La espuma es aire y agua batidos: mucho mas mate que la lamina lisa
			final_roughness = mix(final_roughness,
				mix(river_roughness, 0.70, foam), agua);
			specular_out = mix(specular_out, river_specular, agua);
			final_normal = mix(final_normal, water_normal, agua);
		}
	}

	// EL TIEMPO EN EL SUELO. Mojado: mas oscuro, liso y con brillo. Nevado: blanco encima de
	// la cota de nieve y mas en lo tendido, la regla de `ClimaEnPantalla.cuaja` con la cota
	// en fraccion del relieve (el margen de 2 m de alli, aqui 0,01 del relieve).
	if (clima_mojado > 0.001 || clima_nieve > 0.001) {
		float seco = 1.0 - es_agua;
		float cuaja = clima_nieve * seco
			* smoothstep(clima_cota_de_nieve - 0.01, clima_cota_de_nieve + 0.01, height)
			* smoothstep(0.35, 0.75, world_normal.y);
		float moja = clima_mojado * seco * (1.0 - cuaja);
		final_color = mix(final_color, final_color * 0.58, moja);
		final_roughness = mix(final_roughness, 0.22, moja);
		specular_out = mix(specular_out, 0.65, moja);
		final_color = mix(final_color, vec3(0.93, 0.95, 0.98), cuaja);
		final_roughness = mix(final_roughness, 0.85, cuaja);
		final_normal = mix(final_normal, vec3(0.0, 0.0, 1.0), cuaja * 0.7);
	}

	// Fuera de la region jugable: desaturar y oscurecer
	if (use_region_mask) {
		vec2 mask_uv = world_position.xz / max(region_world_size, vec2(0.001));
		float outside = 1.0 - clamp(texture(region_mask_tex, mask_uv).r, 0.0, 1.0);
		// EL AGUA NO SE APAGA (2026-09-17). Lo de fuera del recuadro se desatura y se
		// oscurece a proposito -es fondo, no tablero-, pero eso se comia el azul del
		// cauce: el rio salia del recuadro y al entrar en las ocho casillas se volvia una
		// raya gris. El usuario lo conto como «los rios/rias se cortan cuando llegan a las
		// 8 casillas que rodean la casilla principal». El agua es lo unico que cruza esa
		// raya y tiene que verse igual a los dos lados.
		outside *= 1.0 - clamp(river * 1.4, 0.0, 1.0);
		if (outside > 0.001) {
			float grey = dot(final_color, vec3(0.299, 0.587, 0.114));
			final_color = mix(final_color, vec3(grey), outside * outside_desaturation);
			final_color *= mix(1.0, 1.0 - outside_dim, outside);
		}
	}

	// Overlay de informacion. Va al final, DESPUES del agua y de la mascara de
	// region: es una capa de lectura del jugador, no un material del mundo, y
	// tiene que verse igual sobre el rio que sobre la ladera.
	if (use_overlay) {
		vec2 overlay_uv = world_position.xz / max(overlay_world_size, vec2(0.001));
		if (overlay_uv.x >= 0.0 && overlay_uv.x <= 1.0
				&& overlay_uv.y >= 0.0 && overlay_uv.y <= 1.0) {
			vec4 layer = texture(overlay_tex, overlay_uv);
			// Se mezcla sin tapar del todo: hay que seguir viendo el relieve
			// que hay debajo, porque la informacion es DONDE, no QUE color
			final_color = mix(final_color, layer.rgb, layer.a * 0.62);
		}
	}

	// Salidas del shader
	if (debug_view == 1) {
		final_color = mix(layer_color(i0), layer_color(i1), w1);
	} else if (debug_view == 2) {
		final_normal = vec3(0.0, 0.0, 1.0);
	}

	ALBEDO = final_color;
	// La oclusion va a AO y NO multiplicando el albedo. Multiplicar el color
	// oscurece DOS veces lo que ya esta en sombra -la luz directa tambien
	// cae-, y el terreno se iba a negro en cuanto la ladera daba la espalda al
	// sol. Con AO_LIGHT_AFFECT a cero la oclusion solo toca la luz indirecta,
	// que es la unica que una grieta puede tapar.
	if (use_orm) {
		AO = mix(1.0, occlusion, ao_strength);
		AO_LIGHT_AFFECT = 0.0;
	}
	if (use_normal_maps && length(final_normal) > 0.001) {
		NORMAL_MAP = normalize(final_normal) * 0.5 + 0.5;
	}
	ROUGHNESS = final_roughness;
	METALLIC = 0.0;
	SPECULAR = specular_out;
	if (termino_sin_luz >= 0.0) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(termino_sin_luz);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
	}
}
