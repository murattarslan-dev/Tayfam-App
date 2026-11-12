#!/usr/bin/env python3
"""Uygulama ikonlarını Tayfam logosundan ("Dörtlü") üretir (issue #98).

Kaynak: `assets/marka/logo/` altındaki SVG'ler (Notion: Marka → Logo;
2026-11-12). Logonun yolları ve renkleri aşağıdaki sabitlerdedir;
`lib/core/bilesenler/tayfam_logo.dart` (LogoYollari, LogoBoyaci) aynı
yolları çizer, renkler `lib/core/tema/tayfam_logo_renkleri.dart` ile
aynıdır. Eşliği `test/core/bilesenler/android_ikonu_test.dart` ve
`test/core/bilesenler/ios_ikonu_test.dart` denetler.

Üretilenler (çıktılar commit'lenir):

Android (`android/app/src/main/res/`):

- `values/ic_launcher_renkleri.xml`: ikon renkleri (brand zemin, mango,
  nar, turkuaz, mor zemindeki L #FAF8FF).
- `drawable/ic_launcher_foreground.xml`: uyarlanabilir ikonun ön katmanı
  (VectorDrawable, 108 dp tuval; `tayfam-android-foreground.svg`).
- `drawable/ic_launcher_monochrome.xml`: Android 13+ temalı ikon katmanı;
  tek renk logo, ön katmanla aynı yerleşim (başlatıcı yalnızca alfayı
  kullanır).
- `mipmap-anydpi-v26/ic_launcher.xml`: uyarlanabilir ikon (Android 8+);
  arka plan düz brand.
- `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`: Android 7 ve öncesi için
  `tayfam-app-icon.svg` görünümünde, köşeleri %22 yuvarlatılmış PNG'ler
  (48–192 px; Standartlar: uygulama ikonu yarıçapı).
- `drawable/ic_bildirim.xml`: push bildiriminin durum çubuğu simgesi
  (istemci ADR-0019 §4); tek renk (beyaz) logo, 24 dp. Android bu simgenin
  yalnızca alfa kanalını kullanır.

iOS (`ios/Runner/Assets.xcassets/AppIcon.appiconset/`):

- `Contents.json`'daki her boyut için `tayfam-app-icon.svg` görünümünde,
  alfa kanalı olmayan PNG (App Store alfalı ikonu reddeder; köşeyi sistem
  maskeler).

Kullanım (yalnızca geliştirme; uygulamaya bağımlılık eklemez):

    python3 -m venv /tmp/ikon && /tmp/ikon/bin/pip install cairosvg==2.9.1 pillow==12.0.0
    /tmp/ikon/bin/python tool/ikon/ikon_uret.py

Betik repo kökünden ya da herhangi bir dizinden çalıştırılabilir.
"""

from __future__ import annotations

import io
import json
import math
import pathlib

import cairosvg
from PIL import Image

KOK = pathlib.Path(__file__).resolve().parents[2]
RES = KOK / "android" / "app" / "src" / "main" / "res"
IOS_IKON = KOK / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

# --- Logo (assets/marka/logo/*.svg; değiştirilmez) --------------------------

KUTU = 100  # viewBox kenarı

# Sıra SVG'lerdeki gibi: sol üst, sağ üst, sağ alt, L.
YOLLAR = {
    "mango": "M16 14 H32 Q40 14 40 22 V26 Q40 32 34 32 H14 Q8 32 8 26 V22 "
    "Q8 14 16 14 Z",
    "nar": "M60 14 H84 Q92 14 92 22 V26 Q92 32 86 32 H58 Q52 32 52 26 V22 "
    "Q52 14 60 14 Z",
    "turkuaz": "M60 44 H84 Q92 44 92 52 V56 Q92 64 84 64 H64 Q52 64 52 52 "
    "Q52 44 60 44 Z",
    "l": "M18 44 H30 Q40 44 40 54 V64 Q40 76 52 76 H84 Q92 76 92 84 "
    "Q92 92 84 92 H18 Q8 92 8 82 V54 Q8 44 18 44 Z",
}

# --- Renkler (Notion: Marka; TayfamLogoRenkleri) ---------------------------

BRAND = "#5B2BE0"
RENKLER = {
    "mango": "#FFB000",
    "nar": "#FF3D68",
    "turkuaz": "#00C2A8",
    "l": "#FAF8FF",  # mor zeminde L parçası
}

# --- Yerleşim ----------------------------------------------------------------
#
# Uygulama ikonu (tayfam-app-icon.svg): 100 birimlik ikonda logo
# translate(20 20) scale(0.6), yani işaret ikon genişliğinin %60'ı.
# Uyarlanabilir ikon (tayfam-android-foreground.svg): 108 dp tuvalde
# scale(0.6); başlatıcı ortadaki 72 dp'yi gösterir, işaret yine görünen
# alanın ~%60'ıdır. Tasarım dosyası viewBox'ı ortalar (translate 24 24);
# işaretin kendisi ise y'de 14–92 arasındadır (orta 53), bu yüzden köşeleri
# 66 dp çaplı güvenli bölgeyi ~1 dp aşıyordu (33.9 dp). Burada işaretin
# kendi ortası tuvalin ortasına konur (translateY 22.2): en uzak nokta
# ~32.7 dp, işaret görsel olarak da ortalı. Boyut değişmez.

IKON_KAYMA = 20
IKON_OLCEK = 0.6
IKON_KOSE_ORANI = 0.22  # Standartlar: uygulama ikonu yarıçapı %22

TUVAL = 108
ADAPTIF_OLCEK = 0.6
ISARET_ORTASI = (50, 53)  # işaretin sınır kutusunun ortası (8–92, 14–92)
ADAPTIF_KAYMA_X = TUVAL / 2 - ISARET_ORTASI[0] * ADAPTIF_OLCEK  # 24
ADAPTIF_KAYMA_Y = TUVAL / 2 - ISARET_ORTASI[1] * ADAPTIF_OLCEK  # 22.2
GUVENLI_YARICAP = 33

YOGUNLUKLAR = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

UYARI = (
    "<!-- tool/ikon/ikon_uret.py ile üretildi; elle düzenleme, betiği "
    "çalıştır. -->"
)


def _sayi(x: float) -> str:
    return f"{x:.4f}".rstrip("0").rstrip(".")


def app_icon_svg(kose: float = 0) -> str:
    """tayfam-app-icon.svg ile aynı çizim; [kose] zemin köşe yarıçapı."""
    yollar = "".join(
        f'<path d="{d}" fill="{RENKLER[ad]}"/>' for ad, d in YOLLAR.items()
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {KUTU} {KUTU}">'
        f'<rect width="{KUTU}" height="{KUTU}" rx="{_sayi(kose)}" '
        f'fill="{BRAND}"/>'
        f'<g transform="translate({IKON_KAYMA} {IKON_KAYMA}) '
        f'scale({IKON_OLCEK})">{yollar}</g></svg>'
    )


def renkler_xml() -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Renkler lib/core/tema/tayfam_logo_renkleri.dart ile aynıdır;
     test/core/bilesenler/android_ikonu_test.dart denetler. -->
<resources>
    <color name="ic_launcher_background">{BRAND}</color>
    <color name="ic_launcher_mango">{RENKLER["mango"]}</color>
    <color name="ic_launcher_nar">{RENKLER["nar"]}</color>
    <color name="ic_launcher_turkuaz">{RENKLER["turkuaz"]}</color>
    <color name="ic_launcher_l">{RENKLER["l"]}</color>
</resources>
"""


def _yollar_xml(dolgu: dict[str, str], girinti: str) -> str:
    return "\n".join(
        f'{girinti}<path\n'
        f'{girinti}    android:pathData="{d}"\n'
        f'{girinti}    android:fillColor="{dolgu[ad]}" />'
        for ad, d in YOLLAR.items()
    )


def _katman_xml(aciklama: str, dolgu: dict[str, str]) -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- {aciklama} -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{TUVAL}dp"
    android:height="{TUVAL}dp"
    android:viewportWidth="{TUVAL}"
    android:viewportHeight="{TUVAL}">
    <group
        android:scaleX="{_sayi(ADAPTIF_OLCEK)}"
        android:scaleY="{_sayi(ADAPTIF_OLCEK)}"
        android:translateX="{_sayi(ADAPTIF_KAYMA_X)}"
        android:translateY="{_sayi(ADAPTIF_KAYMA_Y)}">
{_yollar_xml(dolgu, "        ")}
    </group>
</vector>
"""


def on_katman_xml() -> str:
    return _katman_xml(
        "Uyarlanabilir ikonun ön katmanı (tayfam-android-foreground.svg):\n"
        "     logo (viewBox 100) 108 dp tuvalde scale(0.6), işaretin ortası\n"
        "     tuvalin ortasında (66 dp güvenli bölge); L parçası mor zemin\n"
        "     için #FAF8FF. Arka plan düz brand.",
        {ad: f"@color/ic_launcher_{ad}" for ad in YOLLAR},
    )


def tek_renk_katman_xml() -> str:
    return _katman_xml(
        "Android 13+ temalı ikon (monochrome) katmanı: tek renk logo, ön\n"
        "     katmanla aynı yerleşim. Başlatıcı yalnızca alfayı kullanır.",
        {ad: "#FFFFFFFF" for ad in YOLLAR},
    )


def uyarlanabilir_xml() -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
"""


def bildirim_ikonu_xml() -> str:
    """Durum çubuğu simgesi: tek renk logo, 24 dp (viewBox 100)."""
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Push bildiriminin simgesi (istemci ADR-0019 §4): tek renk logo
     (tayfam-tek-renk.svg). Android yalnızca alfa kanalını kullanır; rengi
     manifestteki default_notification_color verir. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="{KUTU}"
    android:viewportHeight="{KUTU}">
{_yollar_xml({ad: "#FFFFFFFF" for ad in YOLLAR}, "    ")}
</vector>
"""


def _yol_noktalari(d: str, adim: int = 24) -> list[tuple[float, float]]:
    """Yol üzerindeki noktalar (M/H/V/Q/Z; Q eğrileri örneklenir)."""
    import re

    parcalar = re.findall(r"[A-Za-z]|-?\d+(?:\.\d+)?", d)
    noktalar: list[tuple[float, float]] = []
    x = y = 0.0
    i = 0
    komut = ""

    def sayi() -> float:
        nonlocal i
        i += 1
        return float(parcalar[i - 1])

    while i < len(parcalar):
        if parcalar[i].isalpha():
            komut = parcalar[i]
            i += 1
        if komut == "M":
            x, y = sayi(), sayi()
            komut = "L"
        elif komut == "L":
            x, y = sayi(), sayi()
        elif komut == "H":
            x = sayi()
        elif komut == "V":
            y = sayi()
        elif komut == "Q":
            kx, ky, sx, sy = sayi(), sayi(), sayi(), sayi()
            for k in range(1, adim + 1):
                t = k / adim
                noktalar.append(
                    (
                        (1 - t) ** 2 * x + 2 * (1 - t) * t * kx + t * t * sx,
                        (1 - t) ** 2 * y + 2 * (1 - t) * t * ky + t * t * sy,
                    )
                )
            x, y = sx, sy
        elif komut == "Z":
            komut = ""
            continue
        else:
            raise SystemExit(f"Desteklenmeyen yol komutu: {komut}")
        noktalar.append((x, y))
    return noktalar


def guvenli_bolge_mesafesi() -> float:
    """Ön katmanda logonun merkezden en uzak noktası (dp)."""
    merkez = TUVAL / 2
    return max(
        math.hypot(
            ADAPTIF_KAYMA_X + px * ADAPTIF_OLCEK - merkez,
            ADAPTIF_KAYMA_Y + py * ADAPTIF_OLCEK - merkez,
        )
        for d in YOLLAR.values()
        for px, py in _yol_noktalari(d)
    )


def _yaz(yol: pathlib.Path, icerik: str) -> None:
    yol.parent.mkdir(parents=True, exist_ok=True)
    yol.write_text(icerik, encoding="utf-8")
    print(yol.relative_to(KOK))


def _png(svg: str, boyut: int, alfasiz: bool) -> bytes:
    ham = cairosvg.svg2png(
        bytestring=svg.encode("utf-8"), output_width=boyut, output_height=boyut
    )
    if not alfasiz:
        return ham
    resim = Image.open(io.BytesIO(ham)).convert("RGB")
    cikti = io.BytesIO()
    resim.save(cikti, format="PNG", optimize=True)
    return cikti.getvalue()


def ios_ikonlari() -> None:
    icerik = json.loads((IOS_IKON / "Contents.json").read_text(encoding="utf-8"))
    svg = app_icon_svg()
    for gorsel in icerik["images"]:
        en = float(gorsel["size"].split("x")[0])
        olcek = int(gorsel["scale"].rstrip("x"))
        boyut = round(en * olcek)
        hedef = IOS_IKON / gorsel["filename"]
        hedef.write_bytes(_png(svg, boyut, alfasiz=True))
        print(hedef.relative_to(KOK))


def main() -> None:
    mesafe = guvenli_bolge_mesafesi()
    if mesafe > GUVENLI_YARICAP:
        raise SystemExit(
            f"Logo güvenli bölgeyi aşıyor: {mesafe:.2f} dp > {GUVENLI_YARICAP} dp"
        )
    print(f"Güvenli bölge: en uzak nokta {mesafe:.2f} dp (sınır {GUVENLI_YARICAP})")
    _yaz(RES / "values" / "ic_launcher_renkleri.xml", renkler_xml())
    _yaz(RES / "drawable" / "ic_launcher_foreground.xml", on_katman_xml())
    _yaz(RES / "drawable" / "ic_launcher_monochrome.xml", tek_renk_katman_xml())
    _yaz(RES / "mipmap-anydpi-v26" / "ic_launcher.xml", uyarlanabilir_xml())
    _yaz(RES / "drawable" / "ic_bildirim.xml", bildirim_ikonu_xml())
    yuvarlak = app_icon_svg(kose=KUTU * IKON_KOSE_ORANI)
    for yogunluk, boyut in YOGUNLUKLAR.items():
        hedef = RES / f"mipmap-{yogunluk}" / "ic_launcher.png"
        hedef.write_bytes(_png(yuvarlak, boyut, alfasiz=False))
        print(hedef.relative_to(KOK))
    ios_ikonlari()


if __name__ == "__main__":
    main()
