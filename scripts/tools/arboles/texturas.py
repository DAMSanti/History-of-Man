"""Baja las texturas CC0 de ambientCG para los árboles y saca una hoja por especie.

GRAFICOS §7.1. Las hojas de EZ-Tree no declaran licencia, así que se usan atlas de
hojas de ambientCG (CC0): de cada atlas se recorta **una hoja** —la de más
superficie—, con su alfa, en un cuadrado. EZ-Tree pone la textura entera en cada
tarjeta de hoja, así que la tarjeta tiene que llevar una sola hoja.

    python scripts/tools/arboles/texturas.py

Deja `models/arboles/texturas/<especie>_hoja.png`, `<especie>_hoja_normal.png` y
`<especie>_corteza_{color,normal,rugosidad}.jpg`, y una hoja de prueba.
"""
import io
import json
import os
import urllib.request
import zipfile

import numpy as np
from PIL import Image
from scipy import ndimage

UA = {"User-Agent": "HistoryOfMan-arboles/1.0 (psalasviesgo@gmail.com)"}
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DESTINO = os.path.join(REPO, "models", "arboles", "texturas")

# Qué atlas de hoja y qué corteza lleva cada especie. Elegidas mirando las vistas
# previas de ambientCG el 2026-09-15, por la forma de la hoja y el color y el
# relieve de la corteza.
ESPECIES = {
    # El pino: un ramillete de conífera. No son acículas de dos en dos como las del
    # pino silvestre; es lo más parecido que hay en CC0, y a distancia de juego se
    # lee como conífera. Dicho en CREDITOS.
    "pino": {"hoja": "LeafSet019", "corteza": "Bark014"},
    "pino_joven": {"hoja": "LeafSet019", "corteza": "Bark014"},
    # Hoja triangular dentada, y la corteza más clara y lisa que hay.
    "abedul": {"hoja": "LeafSet004", "corteza": "Bark009"},
    # Hoja lobulada de roble, y corteza gris muy agrietada.
    "roble": {"hoja": "LeafSet016", "corteza": "Bark001"},
    # Hoja redonda y dentada, y corteza lisa.
    "avellano": {"hoja": "LeafSet024", "corteza": "Bark004"},
}

LADO_HOJA = 512


def bajar(asset, formato):
    cache = os.path.join(DESTINO, "..", "..", "..", "scripts", "tools", "arboles", "salida", "zip")
    os.makedirs(cache, exist_ok=True)
    local = os.path.join(cache, "%s_%s.zip" % (asset, formato))
    if not os.path.exists(local):
        url = "https://ambientcg.com/get?file=%s_%s.zip" % (asset, formato)
        open(local, "wb").write(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120).read())
    return zipfile.ZipFile(local)


def del_zip(z, sufijo):
    for n in z.namelist():
        if n.endswith(sufijo):
            return Image.open(io.BytesIO(z.read(n)))
    raise SystemExit("no está %s en %s" % (sufijo, z.filename))


def el_ramillete(asset):
    """El atlas entero, con su alfa: varias hojas en una tarjeta.

    Una hoja por tarjeta dejaba copas ralas con hojas de un metro (captura del
    2026-09-15): EZ-Tree pone la textura entera en cada tarjeta. Con el atlas —seis
    hojas— la copa se tupe con los mismos triángulos."""
    z = bajar(asset, "1K-PNG")
    color = del_zip(z, "_Color.png").convert("RGB")
    opacidad = del_zip(z, "_Opacity.png").convert("L")
    normal = del_zip(z, "_NormalGL.png").convert("RGB")
    ramillete = color.convert("RGBA")
    ramillete.putalpha(opacidad)
    return ramillete.resize((LADO_HOJA, LADO_HOJA), Image.LANCZOS),         normal.resize((LADO_HOJA, LADO_HOJA), Image.LANCZOS)


def una_hoja(asset):
    z = bajar(asset, "1K-PNG")
    color = del_zip(z, "_Color.png").convert("RGB")
    opacidad = np.array(del_zip(z, "_Opacity.png").convert("L"))
    normal = del_zip(z, "_NormalGL.png").convert("RGB")
    mascara = opacidad > 128
    etiquetas, n = ndimage.label(mascara)
    if n == 0:
        raise SystemExit("sin hojas en %s" % asset)
    areas = ndimage.sum(mascara, etiquetas, range(1, n + 1))
    mayor = int(np.argmax(areas)) + 1
    ys, xs = np.where(etiquetas == mayor)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    lado = max(x1 - x0, y1 - y0) + 8
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    caja = (cx - lado // 2, cy - lado // 2, cx - lado // 2 + lado, cy - lado // 2 + lado)
    alfa = Image.fromarray(np.where(etiquetas == mayor, opacidad, 0).astype(np.uint8))
    hoja = color.crop(caja).convert("RGBA")
    hoja.putalpha(alfa.crop(caja))
    return hoja.resize((LADO_HOJA, LADO_HOJA), Image.LANCZOS), \
        normal.crop(caja).resize((LADO_HOJA, LADO_HOJA), Image.LANCZOS)


def main():
    os.makedirs(DESTINO, exist_ok=True)
    fichas = {}
    hechas = {}
    for especie, fuente in ESPECIES.items():
        if fuente["hoja"] not in hechas:
            hechas[fuente["hoja"]] = el_ramillete(fuente["hoja"])
        hoja, normal = hechas[fuente["hoja"]]
        hoja.save(os.path.join(DESTINO, "%s_hoja.png" % especie))
        normal.save(os.path.join(DESTINO, "%s_hoja_normal.png" % especie))
        z = bajar(fuente["corteza"], "1K-JPG")
        for sufijo, nombre in [("_Color.jpg", "color"), ("_NormalGL.jpg", "normal"), ("_Roughness.jpg", "rugosidad")]:
            del_zip(z, sufijo).convert("RGB").save(os.path.join(DESTINO, "%s_corteza_%s.jpg" % (especie, nombre)), quality=92)
        fichas[especie] = {
            "hoja": "https://ambientcg.com/view?id=%s" % fuente["hoja"],
            "corteza": "https://ambientcg.com/view?id=%s" % fuente["corteza"],
            "licencia": "CC0 1.0",
        }
        print("%-11s hoja %s · corteza %s" % (especie, fuente["hoja"], fuente["corteza"]))
    json.dump(fichas, open(os.path.join(DESTINO, "fuentes.json"), "w", encoding="utf-8"), indent=1)
    prueba = Image.new("RGB", (LADO_HOJA * len(hechas), LADO_HOJA), (240, 240, 230))
    for i, (hoja, _) in enumerate(hechas.values()):
        prueba.paste(hoja, (i * LADO_HOJA, 0), hoja)
    prueba.save(os.path.join(DESTINO, "..", "..", "..", "scripts", "tools", "arboles", "salida", "hojas.png"))


if __name__ == "__main__":
    main()
