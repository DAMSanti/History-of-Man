// Genera los árboles del bosque con EZ-Tree y los vuelca a JSON para Godot.
//
// GRAFICOS §7.1. **Decisión del usuario del 2026-09-15**: no hay modelos CC0
// realistas hechos para juego de pino silvestre, abedul, roble y avellano, así que
// se generan con EZ-Tree (https://github.com/dgreenheck/ez-tree, MIT) y se guardan
// en el repositorio. Aquí sólo sale la GEOMETRÍA —ramas y hojas por separado, con
// posición, normal y UV—; los materiales y las texturas CC0 los pone
// `scripts/tools/ArbolesImport.gd`.
//
//   cd scripts/tools/arboles && npm install && node generar.mjs
//
// Deja `salida/<especie>_<variante>_lod<n>.json`. La carpeta lleva `.gdignore`:
// Godot no la importa.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// EZ-Tree carga sus texturas con el `TextureLoader` de three, que en Node pide un
// `document`. Las texturas no hacen falta aquí —van en Godot—, así que basta uno
// que no haga nada.
globalThis.document = {
  createElementNS: () => ({ addEventListener() {}, removeEventListener() {}, style: {} }),
};
const { Tree, TreePreset } = await import('@dgreenheck/ez-tree');

const SALIDA = path.join(path.dirname(fileURLToPath(import.meta.url)), 'salida');

// Cada especie: de qué preset parte, qué se le cambia para que se lea como su
// especie, a qué altura se escala en Godot y con qué semillas salen sus variantes.
//
// Las alturas son las del bosque de refugio del Magdaleniense que ya usaba el juego
// (`PropModels`): porte modesto, de tres a doce metros. Decisión de entonces.
const ESPECIES = {
  pino: {
    base: 'Pine Medium', alto_m: 10.0,
    // PINO SILVESTRE: fuste limpio y copa arriba. El preset echa ramas desde un
    // cuarto de la altura, que es un abeto.
    cambios: { branch: { start: { 1: 0.45 } }, leaves: { start: 0.2, size: 1.1 } },
    recto: true,
  },
  pino_joven: {
    base: 'Pine Small', alto_m: 4.5,
    cambios: { leaves: { count: 30, size: 0.9 } },
    recto: true,
  },
  abedul: {
    // Desde el ÁLAMO, que es el más parecido: fuste fino y copa estrecha. Más
    // ramitas y hoja algo más menuda, que el abedul cuelga.
    base: 'Aspen Medium', alto_m: 8.0,
    // El abedul: más grueso que el plantel de álamo del preset, que salía un palillo.
    cambios: { branch: { children: { 0: 18 }, radius: { 0: 1.2 } }, leaves: { count: 16, size: 1.6 } },
  },
  roble: {
    base: 'Oak Medium', alto_m: 11.0,
    cambios: { leaves: { size: 1.7 } },
  },
  avellano: {
    // Mata de varios pies: el preset de arbusto. Hoja grande y redonda.
    base: 'Bush 1', alto_m: 5.0,
    cambios: { leaves: { size: 1.6, count: 14 } },
  },
};

// CUÁNTAS VARIANTES por especie, y cuánto se desvía cada una de su preset.
//
// Seis y no tres, y **no sólo otra semilla**: petición del usuario del 2026-09-15,
// «que no sean todos iguales, genera variedad». Con la semilla sola cambia dónde
// sale cada rama, pero la silueta es la misma; con esto cambia la forma. Cada
// desviación sale de la semilla de la variante, así que el mismo árbol vuelve a
// salir igual. Las cifras son decisiones de aspecto, no medidas.
const VARIANTES = 6;
const DESVIO = {
  angulo: 0.14,      // ± en el ángulo de cada nivel de rama
  largo: 0.15,       // ± en el largo de cada nivel
  ramas: 0.2,        // ± en cuántas ramas salen del tronco
  retuerce: 0.06,    // + retorcimiento, hasta esto
  arranque: 0.06,    // ± en la altura donde empieza la copa
  hoja: 0.25,        // ± en cuánta hoja
  alto: 0.15,        // ± en la altura final
};

// Un azar pequeño y reproducible por semilla.
function azar(semilla) {
  let x = semilla * 9301 + 49297;
  return () => {
    x = (x * 9301 + 49297) % 233280;
    return x / 233280;
  };
}

function desviar(opciones, semilla) {
  const r = azar(semilla);
  const pm = (v) => 1 + (r() * 2 - 1) * v;
  const b = opciones.branch;
  for (const k of Object.keys(b.angle)) b.angle[k] = b.angle[k] * pm(DESVIO.angulo);
  for (const k of Object.keys(b.length)) b.length[k] = b.length[k] * pm(DESVIO.largo);
  b.children[0] = Math.max(1, Math.round(b.children[0] * pm(DESVIO.ramas)));
  // El TRONCO no se retuerce, sólo las ramas: con el tronco torcido los pinos salían
  // inclinados como a sotavento (captura del 2026-09-15).
  for (const k of Object.keys(b.gnarliness)) {
    if (k !== '0') b.gnarliness[k] = b.gnarliness[k] + r() * DESVIO.retuerce;
  }
  if (b.start[1] !== undefined) b.start[1] = Math.min(0.9, Math.max(0.0, b.start[1] + (r() * 2 - 1) * DESVIO.arranque));
  opciones.leaves.count = Math.max(1, Math.round(opciones.leaves.count * pm(DESVIO.hoja)));
  return pm(DESVIO.alto);
}

// Los tres niveles de detalle: cuánto se quedan secciones, segmentos y hojas, cuánto
// crece cada ramillete para que la copa no se aclare, y si la hoja es de una tarjeta
// o de dos cruzadas.
//
// **Mucho más ligeros que la primera versión** (2026-09-15). Aquélla daba de 10 000 a
// 24 000 triángulos en el nivel 0, y en el valle hay **un millón de árboles**: con el
// 3D a 160 m, el escalón Alto pintaba 541 millones de triángulos a 6 FPS. Aquí el nivel 0
// ronda los 4 000 y el 2, unos pocos cientos.
//
// En los lejanos se quitan además RAMAS y un nivel de ramificación: con sólo menos
// secciones, el nivel 2 seguía en 1 000–3 000 triángulos, casi todos de ramas —el pino
// echa 82 del tronco—. La copa la sostienen ramilletes más grandes.
const NIVELES = [
  { secciones: 0.55, segmentos: 0.6, hojas: 0.45, tamano: 1.35, cruzadas: true, ramas: 1.0, quita_nivel: 0 },
  { secciones: 0.3, segmentos: 0.45, hojas: 0.35, tamano: 2.2, cruzadas: false, ramas: 0.5, quita_nivel: 0 },
  { secciones: 0.18, segmentos: 0.3, hojas: 0.6, tamano: 3.6, cruzadas: false, ramas: 0.3, quita_nivel: 1 },
];

function mezclar(destino, cambios) {
  for (const [k, v] of Object.entries(cambios)) {
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      destino[k] = destino[k] ?? {};
      mezclar(destino[k], v);
    } else {
      destino[k] = v;
    }
  }
}

function volcar(geometria) {
  const r = (a) => Array.from(a, (x) => Math.round(x * 10000) / 10000);
  return {
    posicion: r(geometria.attributes.position.array),
    normal: r(geometria.attributes.normal.array),
    uv: r(geometria.attributes.uv.array),
    indice: geometria.index ? Array.from(geometria.index.array) : [],
  };
}

fs.mkdirSync(SALIDA, { recursive: true });
const resumen = [];
for (const [nombre, especie] of Object.entries(ESPECIES)) {
  for (let v = 0; v < VARIANTES; v++) {
    // La semilla de la variante: de la especie y el número, estable.
    const semilla = [...nombre].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 100000, 7) + v * 1009;
    for (let n = 0; n < NIVELES.length; n++) {
      const nivel = NIVELES[n];
      const opciones = structuredClone(TreePreset[especie.base]);
      mezclar(opciones, especie.cambios);
      // La misma desviación en los tres niveles: son el mismo árbol.
      const factor_alto = desviar(opciones, semilla);
      // LOS PINOS, DERECHOS. El preset tira de las ramas hacia abajo
      // (`force.strength` negativa) y con el ángulo desviado la copa entera se doblaba
      // hacia un lado (captura del 2026-09-15). Un pino silvestre crece hacia la luz.
      if (especie.recto) {
        opciones.branch.force.direction = { x: 0, y: 1, z: 0 };
        opciones.branch.force.strength = 0.004;
        opciones.branch.angle[1] = TreePreset[especie.base].branch.angle[1];
      }
      opciones.seed = semilla;
      for (const k of Object.keys(opciones.branch.sections)) {
        opciones.branch.sections[k] = Math.max(1, Math.round(opciones.branch.sections[k] * nivel.secciones));
        opciones.branch.segments[k] = Math.max(3, Math.round(opciones.branch.segments[k] * nivel.segmentos));
      }
      opciones.leaves.count = Math.max(1, Math.round(opciones.leaves.count * nivel.hojas));
      opciones.leaves.size = opciones.leaves.size * nivel.tamano;
      opciones.leaves.billboard = nivel.cruzadas ? 'double' : 'single';
      for (const k of Object.keys(opciones.branch.children)) {
        opciones.branch.children[k] = Math.max(1, Math.round(opciones.branch.children[k] * nivel.ramas));
      }
      opciones.branch.levels = Math.max(1, opciones.branch.levels - nivel.quita_nivel);

      const arbol = new Tree();
      arbol.options.copy(opciones);
      arbol.generate();
      const ramas = arbol.branchesMesh.geometry;
      const hojas = arbol.leavesMesh.geometry;
      ramas.computeBoundingBox();
      hojas.computeBoundingBox();
      const alto = Math.max(ramas.boundingBox.max.y, hojas.boundingBox.max.y);
      const datos = {
        especie: nombre, variante: v, nivel: n, base: especie.base, semilla,
        alto_generado: alto, alto_m: especie.alto_m * factor_alto,
        ramas: volcar(ramas), hojas: volcar(hojas),
      };
      const fichero = path.join(SALIDA, `${nombre}_${v}_lod${n}.json`);
      fs.writeFileSync(fichero, JSON.stringify(datos));
      const tris = (g) => (g.index ? g.index.count : g.attributes.position.count) / 3;
      resumen.push(`${nombre.padEnd(11)} v${v} lod${n}: ramas ${tris(ramas)} · hojas ${tris(hojas)} · alto ${alto.toFixed(1)}`);
    }
  }
}
console.log(resumen.join('\n'));
