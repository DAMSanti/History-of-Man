"""Calca los motivos de la pared a partir de sus referencias, y escribe Motivos.gd.

SISTEMAS §13, spec del 2026-09-15: «los motivos se dibujan a mano, calcados en
vectorial a partir de referencias publicadas». Esto es el calco, hecho de forma
que se pueda repetir y comprobar:

1. Se baja cada referencia de Wikimedia Commons (la ficha dice autor y licencia).
2. Se separa el PIGMENTO del fondo: el trazo negro o el ocre rojo de un calco
   limpio, o el pigmento oscuro sobre la roca en una foto.
3. Se sacan los contornos del pigmento CON SUS HUECOS —un contorno cerrado es un
   anillo—, y la silueta del CUERPO de la figura, rellenando el contorno: es lo
   que usa la pared para medir cuánto la recalca la roca.
4. Se simplifica y se normaliza: la figura cabe en un cuadrado de lado 1 centrado
   en el origen, con la y hacia abajo como en la imagen.
5. Se dibuja una hoja de prueba DESDE LOS POLÍGONOS, no desde la imagen, para ver
   lo que de verdad va a ir al juego.

No se inventa ninguna figura: si una referencia no está, el motivo no sale.

    python scripts/tools/calcar_motivos.py [carpeta_de_trabajo]
"""
import io
import json
import os
import re
import sys
import urllib.parse
import urllib.request

import cv2
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

UA = {"User-Agent": "HistoryOfMan-calcos/1.0 (psalasviesgo@gmail.com)"}
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SALIDA = os.path.join(REPO, "scripts", "datos", "Motivos.gd")

# Cada motivo: de qué fichero de Commons sale, qué recorte (en píxeles de la
# imagen a 900 px de ancho, o None para entera), cómo se separa el pigmento, su
# técnica y su color en la pared.
#
# `tinta`:
#   negro        trazo negro de un calco en blanco (José-Manuel Benito, Obermaier)
#   rojo         ocre rojo oscuro de un calco en blanco
#   negro_puro   sólo lo negro, dejando fuera el rojo del mismo calco
#   foto_oscuro  pigmento oscuro sobre roca clara, en una foto
MOTIVOS = [
    {"id": "bisonte", "nombre": "Bisonte", "fichero": "Altamira-3.png",
     "recorte": (0.797, 0.423, 0.934, 0.612), "tinta": "negro",
     "tecnica": "contorno", "color": "negro",
     "de": "bisonte del gran techo de Altamira"},
    {"id": "jabali", "nombre": "Jabalí", "fichero": "Altamira-3.png",
     "recorte": (0.152, 0.204, 0.276, 0.360), "tinta": "negro",
     "tecnica": "contorno", "color": "negro",
     "de": "jabalí del borde izquierdo del gran techo de Altamira"},
    {"id": "cierva", "nombre": "Cierva", "fichero": "La Pasiega-Galeria A-Cierva roja (panel 22).png",
     "recorte": None, "tinta": "rojo", "tecnica": "tinta_plana", "color": "rojo",
     "de": "cierva roja en tinta plana del panel 22 de La Pasiega"},
    {"id": "ciervo", "nombre": "Ciervo", "fichero": "Cueva de Chimeneas (ciervo).png",
     "recorte": None, "tinta": "negro", "tecnica": "contorno", "color": "negro",
     "de": "ciervo negro de Las Chimeneas"},
    {"id": "caballo", "nombre": "Caballo", "fichero": "Cueva de Hornos de la Peña (grabados).png",
     "recorte": (0.0, 0.09, 1.0, 0.60), "tinta": "negro", "tecnica": "contorno",
     "color": "negro", "de": "caballo grabado de Hornos de la Peña"},
    # EL URO ES EL ÚNICO QUE NO ES CANTÁBRICO. No se encontró en Commons un calco ni
    # una foto libre de un uro de las cuevas de la región (2026-09-15); en su
    # lugar, el de la Sala de los Toros de Lascaux, del mismo Magdaleniense. La foto
    # de 295 px (`LascauxStier.jpg`) salía como ruido; ésta es de 720.
    {"id": "uro", "nombre": "Uro", "fichero": "Lascaux painting.jpg",
     "recorte": (0.585, 0.10, 1.0, 0.60), "tinta": "foto_oscuro", "tecnica": "contorno",
     "color": "negro", "de": "uro de la Sala de los Toros de Lascaux (no hay uro cantábrico libre)"},
    {"id": "mano", "nombre": "Mano", "fichero": "La Pasiega-Galeria B-panel 54.png",
     "recorte": (0.30, 0.0, 1.0, 0.46), "tinta": "rojo", "tecnica": "mano_negativa",
     "color": "rojo", "de": "mano roja del panel 54 de La Pasiega"},
    {"id": "puntos", "nombre": "Serie de puntos", "fichero": "La Pasiega-Galeria A-panel 48.png",
     "recorte": None, "tinta": "rojo", "tecnica": "puntos", "color": "rojo",
     "de": "serie de puntos del panel 48 de La Pasiega"},
    {"id": "bastoncillos", "nombre": "Bastoncillos", "fichero": "La Pasiega-Galeria A-panel 37.png",
     "recorte": None, "tinta": "rojo", "tecnica": "signo", "color": "rojo",
     "de": "ideomorfos en bastoncillo del panel 37 de La Pasiega"},
    {"id": "claviforme", "nombre": "Claviformes", "fichero": "La Pasiega-Galeria B-panel 58.png",
     "recorte": (0.0, 0.12, 0.72, 1.0), "tinta": "rojo", "tecnica": "signo",
     "color": "rojo", "de": "claviformes del panel 58 de La Pasiega"},
    {"id": "tectiforme", "nombre": "Tectiforme", "fichero": "La Pasiega-Galeria A-Tectiformes.png",
     "recorte": (0.195, 0.10, 0.365, 0.50), "tinta": "rojo", "tecnica": "signo",
     "color": "rojo", "de": "tectiforme de la Galería A de La Pasiega"},
    {"id": "escaleriforme", "nombre": "Escaleriforme", "fichero": "La Pasiega-Galeria C-La Trampa.png",
     "recorte": None, "tinta": "negro_puro", "tecnica": "signo",
     "color": "negro", "de": "el marco en escalera de «La Trampa», panel 78 de La Pasiega"},
]

ANCHO = 900

# Lo que va en Motivos.gd además de los datos. Cada anillo se guarda como lista
# plana y no como PackedVector2Array: un array empaquetado NO es una expresión
# constante en GDScript, y con él el fichero no compilaba —y una suite que no
# compila se cuelga, no falla—.
AYUDAS_GD = '''##
## Cada anillo va como lista plana `[x0, y0, x1, y1...]` y no como
## `PackedVector2Array`: un array empaquetado no es una expresión constante en
## GDScript, y con él el fichero no compilaba. Se piden ya convertidos con
## [trazos_de] y [cuerpo_de].


## Los anillos convertidos, por figura. Se rellenan la primera vez que se piden.
## Con cerrojo: la pared los pide desde el hilo de cada campamento.
static var _trazos: Dictionary = {}
static var _cuerpos: Dictionary = {}
static var _cerrojo := Mutex.new()


## El pigmento de una figura: formas, cada una `[exterior, hueco...]`.
static func trazos_de(clave: String) -> Array:
	_cerrojo.lock()
	if not _trazos.has(clave):
		var formas: Array = []
		for forma: Array in (FIGURAS[clave] as Dictionary)["trazos"]:
			var anillos: Array[PackedVector2Array] = []
			for plano: Array in forma:
				anillos.append(anillo(plano))
			formas.append(anillos)
		_trazos[clave] = formas
	var hechos: Array = _trazos[clave]
	_cerrojo.unlock()
	return hechos


## La silueta rellena de una figura.
static func cuerpo_de(clave: String) -> Array[PackedVector2Array]:
	_cerrojo.lock()
	if not _cuerpos.has(clave):
		var anillos: Array[PackedVector2Array] = []
		for plano: Array in (FIGURAS[clave] as Dictionary)["cuerpo"]:
			anillos.append(anillo(plano))
		_cuerpos[clave] = anillos
	var hechos: Array[PackedVector2Array] = _cuerpos[clave]
	_cerrojo.unlock()
	return hechos


static func anillo(plano: Array) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	@warning_ignore("integer_division")
	puntos.resize(plano.size() / 2)
	for i in range(puntos.size()):
		puntos[i] = Vector2(float(plano[i * 2]), float(plano[i * 2 + 1]))
	return puntos

'''


def ficha_y_bytes(titulo, carpeta):
    local = os.path.join(carpeta, "calco_" + re.sub(r"[^a-z0-9]+", "_", titulo.lower()).strip("_") + ".png")
    ficha_local = local + ".json"
    if os.path.exists(local) and os.path.exists(ficha_local):
        return json.load(open(ficha_local, encoding="utf-8")), Image.open(local)
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "titles": "File:" + titulo, "prop": "imageinfo",
        "iiprop": "url|extmetadata|size", "iiurlwidth": ANCHO, "format": "json"})
    datos = json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30))
    pagina = list(datos["query"]["pages"].values())[0]
    if "imageinfo" not in pagina:
        raise SystemExit("No está en Commons: %s. El motivo no sale." % titulo)
    info = pagina["imageinfo"][0]
    meta = info.get("extmetadata", {})
    limpio = lambda s: re.sub("<[^>]+>", "", s or "").strip()
    ficha = {
        "titulo": titulo,
        "pagina": info.get("descriptionurl", ""),
        "licencia": limpio(meta.get("LicenseShortName", {}).get("value")),
        "autor": limpio(meta.get("Artist", {}).get("value")),
    }
    crudo = urllib.request.urlopen(urllib.request.Request(
        info.get("thumburl") or info["url"], headers=UA), timeout=60).read()
    imagen = Image.open(io.BytesIO(crudo)).convert("RGBA")
    fondo = Image.new("RGBA", imagen.size, "white")
    fondo.alpha_composite(imagen)
    fondo.convert("RGB").save(local)
    json.dump(ficha, open(ficha_local, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    return ficha, Image.open(local)


def pigmento(rgb, tinta):
    r, g, b = [rgb[:, :, i].astype(np.int32) for i in range(3)]
    maximo = np.maximum(np.maximum(r, g), b)
    if tinta == "negro":
        return maximo < 100
    if tinta == "negro_puro":
        return (maximo < 80) & ((r - g) < 30)
    if tinta == "rojo":
        # Ocre oscuro de los calcos de La Pasiega: rojo que manda sobre verde y
        # azul, y oscuro. Deja fuera el blanco y el gris del antialias.
        return (r - g > 40) & (r - b > 40) & (maximo < 200)
    if tinta == "foto_oscuro":
        gris = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
        suave = cv2.GaussianBlur(gris, (0, 0), 25)
        r_, g_, b_ = rgb[:, :, 0].astype(np.int32), rgb[:, :, 1].astype(np.int32), rgb[:, :, 2].astype(np.int32)
        # Negro de carbón y no el pardo del caballo de al lado: oscuro, y sin que
        # el rojo mande.
        return (gris.astype(np.int32) < suave.astype(np.int32) - 25) & (gris < 85) & ((r_ - b_) < 45)
    raise ValueError(tinta)


def limpiar(mascara):
    """Quita el polvo y lo que se cuela por el borde del recorte."""
    etiquetas, n = ndimage.label(mascara)
    if n == 0:
        return mascara
    areas = ndimage.sum(mascara, etiquetas, range(1, n + 1))
    mayor = areas.max()
    alto, ancho = mascara.shape
    quedan = np.zeros_like(mascara)
    for i in range(n):
        area = areas[i]
        if area < max(12, mayor * 0.004):
            continue
        ys, xs = np.where(etiquetas == i + 1)
        toca = ys.min() == 0 or xs.min() == 0 or ys.max() == alto - 1 or xs.max() == ancho - 1
        if toca and area < mayor * 0.35:
            continue
        quedan |= etiquetas == i + 1
    return quedan


def cuerpo_de(mascara, tecnica):
    """La silueta de la figura: el contorno rellenado. Para signos y puntos, el
    propio pigmento un poco engordado."""
    lado = max(mascara.shape)
    if tecnica in ("puntos", "signo"):
        k = max(3, lado // 60)
        return cv2.dilate(mascara.astype(np.uint8), np.ones((k, k), np.uint8)) > 0
    k = max(5, lado // 22)
    cerrado = cv2.morphologyEx(mascara.astype(np.uint8), cv2.MORPH_CLOSE,
                               cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (k, k)))
    lleno = ndimage.binary_fill_holes(cerrado)
    # UN CONTORNO ABIERTO NO SE RELLENA CERRÁNDOLO: el caballo de Hornos de la Peña
    # y el ciervo de Las Chimeneas tienen el vientre y las patas sin cerrar, y el
    # relleno se quedaba en la raya. Se le suma la envolvente cóncava del pigmento,
    # que abraza la figura sin tapar los huecos grandes entre patas.
    ys, xs = np.where(mascara)
    if len(xs) > 8:
        from shapely import MultiPoint, concave_hull
        envolvente = concave_hull(MultiPoint(np.column_stack([xs, ys])), ratio=0.18)
        if envolvente.geom_type == "Polygon":
            capa = np.zeros(mascara.shape, np.uint8)
            cv2.fillPoly(capa, [np.array(envolvente.exterior.coords, np.int32)], 1)
            lleno = lleno | (capa > 0)
    etiquetas, n = ndimage.label(lleno)
    if n > 1:
        areas = ndimage.sum(lleno, etiquetas, range(1, n + 1))
        lleno = etiquetas == (int(np.argmax(areas)) + 1)
    return lleno


def poligonos(mascara, epsilon):
    """Contornos con jerarquía: cada forma es [exterior, hueco, hueco...]."""
    contornos, jerarquia = cv2.findContours(mascara.astype(np.uint8), cv2.RETR_CCOMP,
                                            cv2.CHAIN_APPROX_NONE)
    formas = []
    if jerarquia is None:
        return formas
    jerarquia = jerarquia[0]
    for i, c in enumerate(contornos):
        if jerarquia[i][3] != -1:
            continue
        forma = [cv2.approxPolyDP(c, epsilon, True).reshape(-1, 2)]
        hijo = jerarquia[i][2]
        while hijo != -1:
            hueco = cv2.approxPolyDP(contornos[hijo], epsilon, True).reshape(-1, 2)
            if len(hueco) >= 3 and cv2.contourArea(contornos[hijo]) > 6:
                forma.append(hueco)
            hijo = jerarquia[hijo][0]
        if len(forma[0]) >= 3:
            formas.append(forma)
    return formas


def calcar(motivo, carpeta):
    ficha, imagen = ficha_y_bytes(motivo["fichero"], carpeta)
    rgb = np.array(imagen.convert("RGB"))
    alto, ancho = rgb.shape[:2]
    if motivo["recorte"]:
        x0, y0, x1, y1 = motivo["recorte"]
        rgb = rgb[int(y0 * alto):int(y1 * alto), int(x0 * ancho):int(x1 * ancho)]
    tinta = limpiar(pigmento(rgb, motivo["tinta"]))
    ys, xs = np.where(tinta)
    if len(xs) == 0:
        raise SystemExit("Sin pigmento en %s" % motivo["id"])
    cuerpo = cuerpo_de(tinta, motivo["tecnica"])
    ys2, xs2 = np.where(cuerpo | tinta)
    x0, x1, y0, y1 = xs2.min(), xs2.max(), ys2.min(), ys2.max()
    lado = float(max(x1 - x0, y1 - y0))
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    eps = max(0.6, lado * 0.0035)
    normaliza = lambda p: [((float(x) - cx) / lado, (float(y) - cy) / lado) for x, y in p]
    trazos = [[normaliza(anillo) for anillo in forma] for forma in poligonos(tinta, eps)]
    silueta = [normaliza(forma[0]) for forma in poligonos(cuerpo, eps * 1.5)]
    return {"motivo": motivo, "ficha": ficha, "trazos": trazos, "cuerpo": silueta,
            "aspecto": float(x1 - x0) / max(float(y1 - y0), 1.0)}


def hoja(calcos, destino):
    celda = 300
    columnas = 4
    filas = (len(calcos) + columnas - 1) // columnas
    img = Image.new("RGB", (celda * columnas, (celda + 24) * filas), (236, 226, 204))
    dib = ImageDraw.Draw(img)
    for i, c in enumerate(calcos):
        ox = (i % columnas) * celda + celda // 2
        oy = (i // columnas) * (celda + 24) + celda // 2
        escala = celda * 0.86
        for anillo in c["cuerpo"]:
            dib.polygon([(ox + x * escala, oy + y * escala) for x, y in anillo], fill=(214, 200, 172))
        color = (120, 22, 16) if c["motivo"]["color"] == "rojo" else (30, 24, 22)
        capa = Image.new("L", img.size, 0)
        dc = ImageDraw.Draw(capa)
        for forma in c["trazos"]:
            dc.polygon([(ox + x * escala, oy + y * escala) for x, y in forma[0]], fill=255)
            for hueco in forma[1:]:
                dc.polygon([(ox + x * escala, oy + y * escala) for x, y in hueco], fill=0)
        img.paste(color, mask=capa)
        puntos = sum(len(a) for f in c["trazos"] for a in f)
        dib.text((ox - celda // 2 + 6, oy + celda // 2 - 4), "%s · %d pt" % (c["motivo"]["id"], puntos), fill=(0, 0, 160))
    img.save(destino)


def gd(calcos):
    fuera = []
    fuera.append("class_name Motivos")
    fuera.append("extends RefCounted")
    fuera.append("## Las figuras que se pintan en la pared, calcadas de referencias publicadas.")
    fuera.append("##")
    fuera.append("## **No se edita a mano**: lo escribe `scripts/tools/calcar_motivos.py`, que baja")
    fuera.append("## cada referencia de Wikimedia Commons, separa el pigmento, saca sus contornos")
    fuera.append("## con los huecos y la silueta del cuerpo, y los normaliza. Las referencias, con")
    fuera.append("## autor y licencia, están en `docs/CREDITOS.md`. SISTEMAS §13.")
    fuera.append("##")
    fuera.append("## **Constantes en código y no un recurso**: la pared se calcula dentro del paso")
    fuera.append("## de los campamentos fuera del árbol (SPECS §3.1), y cargar recursos desde ahí")
    fuera.append("## no es seguro.")
    fuera.append("##")
    fuera.append("## Coordenadas de la figura: cabe en un cuadrado de lado 1 centrado en el origen,")
    fuera.append("## con la y hacia abajo. `trazos` es el pigmento, forma a forma, y cada forma es")
    fuera.append("## `[exterior, hueco, hueco...]` —un contorno cerrado es un anillo—. `cuerpo` es")
    fuera.append("## la silueta rellena, que es lo que la pared compara con su relieve.")
    fuera.append(AYUDAS_GD)
    fuera.append("const FIGURAS := {")
    for c in calcos:
        m = c["motivo"]
        fuera.append('\t"%s": {' % m["id"])
        fuera.append('\t\t"nombre": "%s", "tecnica": "%s", "color": "%s",' % (m["nombre"], m["tecnica"], m["color"]))
        fuera.append('\t\t"de": "%s",' % m["de"])
        fuera.append('\t\t"referencia": "%s",' % c["ficha"]["pagina"])
        fuera.append('\t\t"aspecto": %.3f,' % c["aspecto"])
        fuera.append("\t\t\"trazos\": [")
        for forma in c["trazos"]:
            anillos = ", ".join("[%s]" % ", ".join("%.4f, %.4f" % p for p in anillo) for anillo in forma)
            fuera.append("\t\t\t[%s]," % anillos)
        fuera.append("\t\t],")
        fuera.append("\t\t\"cuerpo\": [")
        for anillo in c["cuerpo"]:
            fuera.append("\t\t\t[%s]," % ", ".join("%.4f, %.4f" % p for p in anillo))
        fuera.append("\t\t],")
        fuera.append("\t},")
    fuera.append("}")
    fuera.append("")
    return "\n".join(fuera)


def main():
    carpeta = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, ".calcos")
    os.makedirs(carpeta, exist_ok=True)
    calcos = []
    for motivo in MOTIVOS:
        c = calcar(motivo, carpeta)
        calcos.append(c)
        print("%-14s %3d formas  %4d puntos  %s | %s" % (
            motivo["id"], len(c["trazos"]), sum(len(a) for f in c["trazos"] for a in f),
            c["ficha"]["licencia"], c["ficha"]["autor"][:40]))
    hoja(calcos, os.path.join(carpeta, "hoja_de_motivos.png"))
    open(SALIDA, "w", encoding="utf-8", newline="\n").write(gd(calcos))
    json.dump([c["ficha"] | {"id": c["motivo"]["id"], "de": c["motivo"]["de"]} for c in calcos],
              open(os.path.join(carpeta, "fichas.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("escrito", SALIDA)


if __name__ == "__main__":
    main()
