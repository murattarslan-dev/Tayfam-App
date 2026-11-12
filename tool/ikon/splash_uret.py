#!/usr/bin/env python3
"""Açılış ekranı (splash) kaynaklarını Tayfam logosundan üretir (issue #100).

Tasarım: Design tuvalindeki "Splash açık" ve "Splash koyu" (açık temada
brand #5B2BE0 zemin ve L #FAF8FF; koyu temada ink #1B1036 zemin ve L
#A98BFF; ortada 120 dp logo, altta "tayfam" yazı logosu). Logonun yolları
ve renkleri `tool/ikon/ikon_uret.py`'den gelir. Yazı logo, uygulamaya
gömülü fonttan (`assets/fonts/BricolageGrotesque-Baslik750.ttf`, uygulamada
800 ağırlık yuvası) yollara çevrilir; uygulamadaki `LogoYazisi` ile aynı
font, aynı harf aralığı (−%4.5).

Üretilenler (çıktılar commit'lenir):

Android (`android/app/src/main/res/`):

- `values/splash_renkleri.xml`, `values-night/splash_renkleri.xml`: zemin
  ve L parçası rengi; koyu tema `-night` kaynaklarıyla seçilir.
- `drawable/splash_simge.xml`: Android 12+ SplashScreen ikonu (arka plansız
  ikon: 288 dp tuval, 192 dp çaplı dairenin içinde; logo 120 dp).
- `drawable/splash_logo.xml`: Android 12 öncesi açılış zemini için 120 dp
  logo.
- `drawable/splash_yazi.xml`: yazı logo (200×80 dp; Android 12+ marka
  görseli ve Android 12 öncesi zeminin alt kısmı).

iOS (`ios/Runner/Assets.xcassets/`):

- `LaunchImage.imageset`: 120 pt logo; açık ve koyu görünüm (L rengi).
- `LaunchYazi.imageset`: yazı logo (beyaz).
- `LaunchZemin.colorset`: açık ve koyu zemin.

Kullanım (yalnızca geliştirme):

    python3 -m venv /tmp/ikon && /tmp/ikon/bin/pip install cairosvg==2.9.1 \\
        pillow==12.0.0 fonttools==4.60.1 uharfbuzz==0.51.1
    /tmp/ikon/bin/python tool/ikon/splash_uret.py
"""

from __future__ import annotations

import io
import json
import math
import pathlib
import sys

import cairosvg
import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from ikon_uret import KUTU, RENKLER, YOLLAR, _sayi  # noqa: E402

KOK = pathlib.Path(__file__).resolve().parents[2]
RES = KOK / "android" / "app" / "src" / "main" / "res"
IOS = KOK / "ios" / "Runner" / "Assets.xcassets"
FONT = KOK / "assets" / "fonts" / "BricolageGrotesque-Baslik750.ttf"

UYARI = (
    "<!-- tool/ikon/splash_uret.py ile üretildi; elle düzenleme, betiği "
    "çalıştır. -->"
)

# --- Renkler (TayfamLogoRenkleri) -------------------------------------------

ZEMIN_ACIK = "#5B2BE0"  # brand
ZEMIN_KOYU = "#1B1036"  # ink
L_ACIK = "#FAF8FF"  # mor zeminde L
L_KOYU = "#A98BFF"  # koyu zeminde L (brand-dark)
YAZI = "#FFFFFF"

# --- Ölçüler -----------------------------------------------------------------

LOGO = 120  # dp; tasarımdaki svg 120×120 (TayfamSizes.logoSplash)
ISARET_ORTASI = (50, 53)  # işaretin sınır kutusunun ortası

# Android 12+ SplashScreen: arka plansız ikon 288 dp tuvalde, görünen kısım
# 192 dp çaplı daire.
SPLASH_TUVAL = 288
SPLASH_DAIRE_YARICAP = 96

YAZI_PUNTO = 34  # dp; tasarımdaki "tayfam" (TayfamSizes.acilisYaziPuntosu)
YAZI_HARF_ARALIGI = -0.045  # em; TayfamSizes.logoHarfAraligiOrani
MARKA_GORSELI = (200, 80)  # dp; Android 12+ marka görseli


def _logo_yollari_xml(l_rengi: str, girinti: str) -> str:
    dolgu = {
        "mango": "@color/ic_launcher_mango",
        "nar": "@color/ic_launcher_nar",
        "turkuaz": "@color/ic_launcher_turkuaz",
        "l": l_rengi,
    }
    return "\n".join(
        f'{girinti}<path\n'
        f'{girinti}    android:pathData="{d}"\n'
        f'{girinti}    android:fillColor="{dolgu[ad]}" />'
        for ad, d in YOLLAR.items()
    )


def renkler_xml(zemin: str, l_rengi: str, tema: str) -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Açılış ekranı renkleri ({tema}); lib/core/tema/tayfam_logo_renkleri.dart
     ile aynıdır. -->
<resources>
    <color name="splash_zemin">{zemin}</color>
    <color name="splash_l">{l_rengi}</color>
</resources>
"""


def splash_simge_xml() -> str:
    olcek = LOGO / KUTU
    kayma_x = SPLASH_TUVAL / 2 - ISARET_ORTASI[0] * olcek
    kayma_y = SPLASH_TUVAL / 2 - ISARET_ORTASI[1] * olcek
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Android 12+ SplashScreen ikonu (arka plansız): 288 dp tuval, logo
     {LOGO} dp, işaretin ortası tuvalin ortasında; 192 dp çaplı dairenin
     içinde kalır. L rengi temaya göre (@color/splash_l). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{SPLASH_TUVAL}dp"
    android:height="{SPLASH_TUVAL}dp"
    android:viewportWidth="{SPLASH_TUVAL}"
    android:viewportHeight="{SPLASH_TUVAL}">
    <group
        android:scaleX="{_sayi(olcek)}"
        android:scaleY="{_sayi(olcek)}"
        android:translateX="{_sayi(kayma_x)}"
        android:translateY="{_sayi(kayma_y)}">
{_logo_yollari_xml("@color/splash_l", "        ")}
    </group>
</vector>
"""


def splash_logo_xml() -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Android 12 öncesi açılış zemininin ortasındaki logo ({LOGO} dp). L
     rengi temaya göre (@color/splash_l). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{LOGO}dp"
    android:height="{LOGO}dp"
    android:viewportWidth="{KUTU}"
    android:viewportHeight="{KUTU}">
{_logo_yollari_xml("@color/splash_l", "    ")}
</vector>
"""


def yazi_yolu() -> tuple[str, float, float, float, float]:
    """"tayfam" yazısının yolu (punto {YAZI_PUNTO} dp; y aşağı) ve sınır
    kutusu (sol, üst, sağ, alt); taban çizgisi y = 0."""
    font = TTFont(FONT)
    birim = font["head"].unitsPerEm
    olcek = YAZI_PUNTO / birim
    metin = "tayfam"

    blob = hb.Blob.from_file_path(str(FONT))
    yuz = hb.Face(blob)
    hbfont = hb.Font(yuz)
    tampon = hb.Buffer()
    tampon.add_str(metin)
    tampon.guess_segment_properties()
    hb.shape(hbfont, tampon, {"kern": True, "liga": True})

    glifler = font.getGlyphSet()
    adlar = font.getGlyphOrder()
    pen = SVGPathPen(glifler, ntos=lambda x: _sayi(round(x, 3)))
    x = 0.0
    aralik = YAZI_HARF_ARALIGI * birim
    for bilgi, konum in zip(tampon.glyph_infos, tampon.glyph_positions):
        ad = adlar[bilgi.codepoint]
        tp = TransformPen(
            pen,
            (olcek, 0, 0, -olcek, (x + konum.x_offset) * olcek, -konum.y_offset * olcek),
        )
        glifler[ad].draw(tp)
        x += konum.x_advance + aralik
    d = pen.getCommands()

    # Sınır kutusu: yolu çizip ölçmek yerine cairosvg ile alfa kutusu.
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="200" '
        'viewBox="-100 -100 400 200">'
        f'<path d="{d}" fill="#000"/></svg>'
    )
    png = cairosvg.svg2png(bytestring=svg.encode(), output_width=4000, output_height=2000)
    kutu = Image.open(io.BytesIO(png)).getchannel("A").getbbox()
    assert kutu is not None
    sol, ust, sag, alt = (
        kutu[0] / 10 - 100,
        kutu[1] / 10 - 100,
        kutu[2] / 10 - 100,
        kutu[3] / 10 - 100,
    )
    return d, sol, ust, sag, alt


def splash_yazi_xml(d: str, sol: float, ust: float, sag: float, alt: float) -> str:
    gen, yuk = MARKA_GORSELI
    kayma_x = gen / 2 - (sol + sag) / 2
    kayma_y = yuk / 2 - (ust + alt) / 2
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- "tayfam" yazı logosu ({YAZI_PUNTO} dp, Bricolage Grotesque 750, harf
     aralığı −%4.5), {gen}×{yuk} dp kutunun ortasında; beyaz. Android 12+
     SplashScreen marka görseli ve Android 12 öncesi açılış zemininin alt
     kısmı. Yazı yollara çevrildi (font gömülmez). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{gen}dp"
    android:height="{yuk}dp"
    android:viewportWidth="{gen}"
    android:viewportHeight="{yuk}">
    <group
        android:translateX="{_sayi(round(kayma_x, 3))}"
        android:translateY="{_sayi(round(kayma_y, 3))}">
        <path
            android:pathData="{d}"
            android:fillColor="{YAZI}" />
    </group>
</vector>
"""


def launch_background_xml() -> str:
    gen, yuk = MARKA_GORSELI
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Android 12 öncesi açılış zemini: düz zemin (açıkta brand, koyuda ink),
     ortada logo, altta yazı logo (Design: Splash açık / koyu). Android 12+
     values-v31/styles.xml'deki SplashScreen özniteliklerini kullanır. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/splash_zemin" />
    <item
        android:width="{LOGO}dp"
        android:height="{LOGO}dp"
        android:gravity="center"
        android:drawable="@drawable/splash_logo" />
    <item
        android:width="{gen}dp"
        android:height="{yuk}dp"
        android:bottom="32dp"
        android:gravity="bottom|center_horizontal"
        android:drawable="@drawable/splash_yazi" />
</layer-list>
"""


def _yaz(yol: pathlib.Path, icerik: str | bytes) -> None:
    yol.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(icerik, bytes):
        yol.write_bytes(icerik)
    else:
        yol.write_text(icerik, encoding="utf-8")
    print(yol.relative_to(KOK))


def _png(svg: str, gen: int, yuk: int) -> bytes:
    return cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=gen, output_height=yuk)


def _logo_svg(l_rengi: str) -> str:
    yollar = "".join(
        f'<path d="{d}" fill="{l_rengi if ad == "l" else RENKLER[ad]}"/>'
        for ad, d in YOLLAR.items()
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {KUTU} {KUTU}">'
        f"{yollar}</svg>"
    )


def _yazi_svg(d: str, sol: float, ust: float, sag: float, alt: float) -> tuple[str, int, int]:
    gen = math.ceil(sag - sol)
    yuk = math.ceil(alt - ust)
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{_sayi(sol)} '
        f'{_sayi(ust)} {gen} {yuk}"><path d="{d}" fill="{YAZI}"/></svg>'
    )
    return svg, gen, yuk


def _imageset(ad: str, dosyalar: list[tuple[str, str | None, int]]) -> str:
    """dosyalar: (dosya adı, görünüm ('dark' ya da None), ölçek)."""
    gorseller = []
    for dosya, gorunum, olcek in dosyalar:
        g: dict[str, object] = {
            "idiom": "universal",
            "filename": dosya,
            "scale": f"{olcek}x",
        }
        if gorunum:
            g["appearances"] = [{"appearance": "luminosity", "value": gorunum}]
        gorseller.append(g)
    return json.dumps(
        {"images": gorseller, "info": {"version": 1, "author": "xcode"}},
        indent=2,
        ensure_ascii=False,
    ) + "\n"


def _renk(hexdeger: str) -> dict[str, object]:
    r, g, b = (int(hexdeger[i : i + 2], 16) for i in (1, 3, 5))
    return {
        "color-space": "srgb",
        "components": {
            "red": f"0x{r:02X}",
            "green": f"0x{g:02X}",
            "blue": f"0x{b:02X}",
            "alpha": "1.000",
        },
    }


def colorset() -> str:
    return json.dumps(
        {
            "colors": [
                {"idiom": "universal", "color": _renk(ZEMIN_ACIK)},
                {
                    "idiom": "universal",
                    "appearances": [{"appearance": "luminosity", "value": "dark"}],
                    "color": _renk(ZEMIN_KOYU),
                },
            ],
            "info": {"version": 1, "author": "xcode"},
        },
        indent=2,
    ) + "\n"


def main() -> None:
    _yaz(RES / "values" / "splash_renkleri.xml", renkler_xml(ZEMIN_ACIK, L_ACIK, "açık"))
    _yaz(
        RES / "values-night" / "splash_renkleri.xml",
        renkler_xml(ZEMIN_KOYU, L_KOYU, "koyu"),
    )
    _yaz(RES / "drawable" / "splash_simge.xml", splash_simge_xml())
    _yaz(RES / "drawable" / "splash_logo.xml", splash_logo_xml())
    yazi = yazi_yolu()
    _yaz(RES / "drawable" / "splash_yazi.xml", splash_yazi_xml(*yazi))
    _yaz(RES / "drawable" / "launch_background.xml", launch_background_xml())

    # iOS
    launch = IOS / "LaunchImage.imageset"
    for eski in launch.glob("*"):
        eski.unlink()
    dosyalar: list[tuple[str, str | None, int]] = []
    for gorunum, l_rengi, ek in [(None, L_ACIK, ""), ("dark", L_KOYU, "-koyu")]:
        for olcek in (1, 2, 3):
            ad = f"LaunchImage{ek}@{olcek}x.png"
            _yaz(launch / ad, _png(_logo_svg(l_rengi), LOGO * olcek, LOGO * olcek))
            dosyalar.append((ad, gorunum, olcek))
    _yaz(launch / "Contents.json", _imageset("LaunchImage", dosyalar))

    yazi_svg, gen, yuk = _yazi_svg(*yazi)
    yazi_klasoru = IOS / "LaunchYazi.imageset"
    yazi_dosyalari: list[tuple[str, str | None, int]] = []
    for olcek in (1, 2, 3):
        ad = f"LaunchYazi@{olcek}x.png"
        _yaz(yazi_klasoru / ad, _png(yazi_svg, gen * olcek, yuk * olcek))
        yazi_dosyalari.append((ad, None, olcek))
    _yaz(yazi_klasoru / "Contents.json", _imageset("LaunchYazi", yazi_dosyalari))
    print(f"LaunchYazi: {gen}×{yuk} pt")

    _yaz(IOS / "LaunchZemin.colorset" / "Contents.json", colorset())


if __name__ == "__main__":
    main()
