"""Bricolage Grotesque değişken fontundan statik örnekler üretir (ADR-0004).

Kaynak: github.com/google/fonts, ofl/bricolagegrotesque/
"BricolageGrotesque[opsz,wdth,wght].ttf" (SIL OFL 1.1, ayrılmış font adı
yok). Değişken dosyanın varsayılan örneği wght 800 / opsz 96'dır; Flutter
`fontWeight`'i `wght` eksenine kendiliğinden bağlamadığı için statik
örnekler kullanılır: her ağırlık pubspec'te kendi `weight` değeriyle
kaydedilir ve Material'ın tüm metin stilleri doğru dosyayı seçer.

Kullanım (fonttools gerekir: pip install fonttools):
    python3 -I tool/font/bricolage_ornekle.py <değişken.ttf> assets/fonts
"""

import pathlib
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

AILE = "Bricolage Grotesque"

# (dosya adı eki, wght, opsz, OS/2 usWeightClass)
# opsz: metin boyutları (13–22 px) için 16; büyük başlık (28 px) için 28.
# 750 (büyük başlık, ADR-0004 §4) Flutter'da 100'ün katı olmayan bir ağırlık
# olarak kaydedilemediği için pubspec'te 800 yuvasına kaydedilir.
ORNEKLER = [
    ("Regular", 400, 16, 400),
    ("SemiBold", 600, 16, 600),
    ("Bold", 700, 16, 700),
    ("Baslik750", 750, 28, 800),
]


def adlari_yaz(font: TTFont, ek: str, agirlik_sinifi: int) -> None:
    ad = font["name"]
    tam = f"{AILE} {ek}"
    ps = f"BricolageGrotesque-{ek}"
    for kimlik in (16, 17, 21, 22, 25):
        ad.removeNames(nameID=kimlik)
    ad.setName(AILE, 1, 3, 1, 0x409)
    ad.setName("Regular", 2, 3, 1, 0x409)
    ad.setName(tam, 4, 3, 1, 0x409)
    ad.setName(ps, 6, 3, 1, 0x409)
    ad.setName(f"{ps};tayfam-ornek", 3, 3, 1, 0x409)
    font["OS/2"].usWeightClass = agirlik_sinifi


def main() -> None:
    kaynak = pathlib.Path(sys.argv[1])
    hedef = pathlib.Path(sys.argv[2])
    hedef.mkdir(parents=True, exist_ok=True)
    for ek, wght, opsz, sinif in ORNEKLER:
        font = TTFont(kaynak)
        statik = instancer.instantiateVariableFont(
            font, {"wght": wght, "wdth": 100, "opsz": opsz}
        )
        adlari_yaz(statik, ek, sinif)
        cikti = hedef / f"BricolageGrotesque-{ek}.ttf"
        statik.save(cikti)
        print(cikti, cikti.stat().st_size)


if __name__ == "__main__":
    main()
