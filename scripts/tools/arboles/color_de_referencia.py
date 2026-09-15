"""El color de referencia de cada especie: copa y corteza, medido en fotos.

GRAFICOS §7.1, criterio de color: por especie y estación, el color medio de copa y de
tronco en el juego cae a ΔE ≤ 10 (CIELAB) del de sus fotos de referencia.

De cada foto de Wikimedia Commons se toma un recorte donde hay sobre todo hoja o
sobre todo corteza, se quita el cielo con una máscara, y se promedia en CIELAB. **Sólo
se guarda el número**, no la foto; la foto se cita en GRAFICOS y CREDITOS.

    python scripts/tools/arboles/color_de_referencia.py

Escribe `models/arboles/color_de_referencia.json` y lo imprime.
"""
import io
import json
import os
import re
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image
from skimage.color import rgb2lab

UA = {"User-Agent": "HistoryOfMan-color/1.0 (psalasviesgo@gmail.com)"}
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SALIDA = os.path.join(REPO, "models", "arboles", "color_de_referencia.json")

# Qué foto y qué recorte (fracciones de ancho y alto: x0, y0, x1, y1): en
# `candidatas.py`, elegidas mirando las candidatas de Commons el 2026-09-15.


def imagen(titulo):
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "titles": titulo, "prop": "imageinfo",
        "iiprop": "url|extmetadata", "iiurlwidth": 800, "format": "json"})
    d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30))
    p = list(d["query"]["pages"].values())[0]
    ii = p["imageinfo"][0]
    m = ii.get("extmetadata", {})
    limpio = lambda s: re.sub("<[^>]+>", "", s or "").strip()
    ficha = {"titulo": titulo, "pagina": ii.get("descriptionurl", ""),
             "licencia": limpio(m.get("LicenseShortName", {}).get("value")),
             "autor": limpio(m.get("Artist", {}).get("value"))[:80]}
    crudo = urllib.request.urlopen(urllib.request.Request(ii["thumburl"], headers=UA), timeout=60).read()
    return ficha, Image.open(io.BytesIO(crudo)).convert("RGB")


def media_lab(foto, recorte):
    w, h = foto.size
    x0, y0, x1, y1 = recorte
    rgb = np.asarray(foto.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))).astype(np.float32) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # FUERA EL CIELO: azul que manda y claro, o casi blanco. Y lo muy oscuro, que son
    # sombras y huecos, no el color de la hoja.
    brillo = rgb.mean(axis=2)
    cielo = ((b > r + 0.06) & (b > g) & (brillo > 0.45)) | (brillo > 0.93)
    oscuro = brillo < 0.06
    buenos = rgb[~(cielo | oscuro)]
    lab = rgb2lab(buenos.reshape(-1, 1, 3)).reshape(-1, 3)
    return [float(x) for x in lab.mean(axis=0)], float(len(buenos)) / float(rgb.shape[0] * rgb.shape[1])


def main():
    from candidatas import ELEGIDAS
    fuera = {}
    for clave, (titulo, recorte) in ELEGIDAS.items():
        ficha, foto = imagen(titulo)
        lab, fraccion = media_lab(foto, recorte)
        fuera[clave] = {"lab": lab, "fraccion_util": fraccion, "recorte": recorte} | ficha
        print("%-22s L %5.1f a %6.1f b %6.1f  (%.0f %% útil)  %s" % (clave, lab[0], lab[1], lab[2], fraccion * 100, ficha["licencia"]))
    json.dump(fuera, open(SALIDA, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
