"""Dodatne ikone koje igra treba, a nisu bile u originalnom dizajn-paketu.

Isti stil kao ikone/kontrole: monokromatska silueta 16x16, svijetla varijanta
#efe6cf i tamna #3a2a1c, plus @3x verzija skalirana nearest-neighbor.

Pokreni:  python dodatne_ikone.py
"""
import os
from PIL import Image

D = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(D, "..", "..", "assets", "ikone", "kontrole"))

SVIJETLA = (0xef, 0xe6, 0xcf, 255)
TAMNA = (0x3a, 0x2a, 0x1c, 255)


def rotiraj(tocke):
    """90 stupnjeva u smjeru kazaljke na 16x16 mrezi."""
    return [(15 - y, x) for (x, y) in tocke]


# Dijagonalna strelica prema gornjem lijevom kutu: kukasta glava u kutu plus
# deblji dijagonalni drzak prema sredini. Rotacija daje preostala tri kuta.
KRAK = [
    (2, 2), (3, 2), (4, 2), (5, 2),
    (2, 3), (2, 4), (2, 5),
    (3, 3), (4, 3),
    (4, 4), (5, 4),
    (5, 5), (6, 5),
    (6, 6), (7, 6),
]


def sirenje():
    tocke = set()
    trenutna = KRAK
    for _ in range(4):
        tocke.update(trenutna)
        trenutna = rotiraj(trenutna)
    return tocke


def spremi(ime, tocke, boja):
    slika = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    piksel = slika.load()
    for (x, y) in tocke:
        piksel[x, y] = boja
    slika.save(os.path.join(OUT, ime + ".png"))
    slika.resize((48, 48), Image.NEAREST).save(os.path.join(OUT, ime + "@3x.png"))
    return slika


if __name__ == "__main__":
    tocke = sirenje()
    spremi("sirenje_svijetla", tocke, SVIJETLA)
    spremi("sirenje_tamna", tocke, TAMNA)
    print("napisano u", OUT)
