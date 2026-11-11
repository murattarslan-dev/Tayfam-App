#!/usr/bin/env python3
"""Android başlatıcı ikonunu Tayfam monogramından üretir (issue #32).

Kaynak: tanıtım sitesindeki `app-icon.svg` (brand zemin, turkuaz gövdeli
monogram, köşe yarıçapı 112/512 ≈ %22). Monogramın yolları ve renkleri
aşağıdaki sabitlerdedir; `lib/core/bilesenler/tayfam_monogram.dart`
(MonogramBoyaci) aynı yolları çizer, renkler `lib/core/tema/tayfam_colors.dart`
token'larıyla aynıdır. Renk eşliğini
`test/core/bilesenler/android_ikonu_test.dart` denetler.

Üretilenler (`android/app/src/main/res/` altında; çıktılar commit'lenir):

- `values/ic_launcher_renkleri.xml`: ikon renkleri (brand, turkuaz, mango,
  nar).
- `drawable/ic_launcher_foreground.xml`: uyarlanabilir ikonun ön planı
  (VectorDrawable, 108 dp tuval).
- `mipmap-anydpi-v26/ic_launcher.xml`: uyarlanabilir ikon (Android 8+);
  arka plan brand rengi.
- `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`: Android 7 ve öncesi için
  `app-icon.svg` görünümünde PNG'ler (48–192 px).

Kullanım (yalnızca geliştirme; uygulamaya bağımlılık eklemez):

    python3 -m venv /tmp/ikon && /tmp/ikon/bin/pip install cairosvg==2.9.1
    /tmp/ikon/bin/python tool/ikon/ikon_uret.py

Betik repo kökünden ya da herhangi bir dizinden çalıştırılabilir.
"""

from __future__ import annotations

import pathlib

import cairosvg

KOK = pathlib.Path(__file__).resolve().parents[2]
RES = KOK / "android" / "app" / "src" / "main" / "res"

# --- Monogram (tanıtım sitesi icon.svg / app-icon.svg; değiştirilmez) -------

KUTU = 64  # viewBox kenarı
KALINLIK = 10
GOVDE = "M31 8c-1 14-3 26-1 36 2 9 10 13 18 7"
CIZGI = "M14 27c10 0 22-2 34-6"
NOKTA = (52, 13, 4.5)  # cx, cy, r

# --- Renkler (Notion: Marka; TayfamColors: markaYuzey, teal, mango, nar) ----

BRAND = "#5B2BE0"
TURKUAZ = "#00C2A8"
MANGO = "#FFB000"
NAR = "#FF3D68"

# --- app-icon.svg yerleşimi -----------------------------------------------

IKON = 512
IKON_KOSE = 112  # ≈ %22 (Standartlar: uygulama ikonu yarıçapı)
IKON_OLCEK = 5.6  # monogram 64 → 358.4 px: ikonun %70'i

# --- Uyarlanabilir ikon (Android 8+) ---------------------------------------
#
# Tuval 108 dp; başlatıcı ortadaki 72 dp'yi maskeyle gösterir, 66 dp çaplı
# daire her maskede görünür (güvenli bölge). Monogram, app-icon.svg'deki
# gibi görünen alanın %70'ini kaplar: 72 × 0.7 = 50.4 dp → ölçek 0.7875.
# Monogramın merkezden en uzak noktası (nokta dış kenarı) ≈ 32.1 birim →
# 25.3 dp; güvenli bölge yarıçapı 33 dp'nin içinde kalır.

TUVAL = 108
GORUNEN = 72
GUVENLI_YARICAP = 33
ADAPTIF_OLCEK = GORUNEN * (IKON_OLCEK * KUTU / IKON) / KUTU
ADAPTIF_KAYMA = TUVAL / 2 - KUTU / 2 * ADAPTIF_OLCEK

YOGUNLUKLAR = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

UYARI = (
    "<!-- tool/ikon/ikon_uret.py ile üretildi; elle düzenleme, betiği "
    "çalıştır. -->"
)


def _sayi(x: float) -> str:
    return f"{x:.4f}".rstrip("0").rstrip(".")


def _daire_yolu(cx: float, cy: float, r: float) -> str:
    """VectorDrawable'da <circle> olmadığı için iki yaylı yol."""
    return (
        f"M{_sayi(cx - r)},{_sayi(cy)}"
        f"a{_sayi(r)},{_sayi(r)} 0 1,0 {_sayi(2 * r)},0"
        f"a{_sayi(r)},{_sayi(r)} 0 1,0 {_sayi(-2 * r)},0"
    )


def _monogram_svg(govde: str) -> str:
    cx, cy, r = NOKTA
    return (
        f'<path d="{GOVDE}" fill="none" stroke="{govde}" '
        f'stroke-width="{KALINLIK}" stroke-linecap="round"/>'
        f'<path d="{CIZGI}" fill="none" stroke="{MANGO}" '
        f'stroke-width="{KALINLIK}" stroke-linecap="round"/>'
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{NAR}"/>'
    )


def app_icon_svg() -> str:
    """Tanıtım sitesindeki app-icon.svg ile aynı çizim."""
    yarim = IKON // 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {IKON} {IKON}">'
        f'<rect width="{IKON}" height="{IKON}" rx="{IKON_KOSE}" fill="{BRAND}"/>'
        f'<g transform="translate({yarim} {yarim}) scale({IKON_OLCEK}) '
        f'translate(-{KUTU // 2} -{KUTU // 2})">'
        f"{_monogram_svg(TURKUAZ)}</g></svg>"
    )


def renkler_xml() -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Renkler lib/core/tema/tayfam_colors.dart token'larıyla aynıdır
     (markaYuzey, teal, mango, nar); test/core/bilesenler/android_ikonu_test.dart
     denetler. -->
<resources>
    <color name="ic_launcher_background">{BRAND}</color>
    <color name="ic_launcher_govde">{TURKUAZ}</color>
    <color name="ic_launcher_cizgi">{MANGO}</color>
    <color name="ic_launcher_nokta">{NAR}</color>
</resources>
"""


def on_plan_xml() -> str:
    cx, cy, r = NOKTA
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<!-- Uyarlanabilir ikonun ön planı: tanıtım sitesindeki app-icon.svg'nin
     monogramı (viewBox 64), 108 dp tuvalin ortasında, görünen 72 dp'nin
     %70'i. Güvenli bölge (66 dp çap) dışına taşmaz. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{TUVAL}dp"
    android:height="{TUVAL}dp"
    android:viewportWidth="{TUVAL}"
    android:viewportHeight="{TUVAL}">
    <group
        android:scaleX="{_sayi(ADAPTIF_OLCEK)}"
        android:scaleY="{_sayi(ADAPTIF_OLCEK)}"
        android:translateX="{_sayi(ADAPTIF_KAYMA)}"
        android:translateY="{_sayi(ADAPTIF_KAYMA)}">
        <path
            android:pathData="{GOVDE}"
            android:strokeColor="@color/ic_launcher_govde"
            android:strokeWidth="{KALINLIK}"
            android:strokeLineCap="round" />
        <path
            android:pathData="{CIZGI}"
            android:strokeColor="@color/ic_launcher_cizgi"
            android:strokeWidth="{KALINLIK}"
            android:strokeLineCap="round" />
        <path
            android:pathData="{_daire_yolu(cx, cy, r)}"
            android:fillColor="@color/ic_launcher_nokta" />
    </group>
</vector>
"""


def uyarlanabilir_xml() -> str:
    return f"""<?xml version="1.0" encoding="utf-8"?>
{UYARI}
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
"""


def _guvenli_bolge_denetle() -> None:
    """Monogramın en uzak noktası güvenli bölgenin içinde mi."""
    import math

    merkez = KUTU / 2
    cx, cy, r = NOKTA
    noktalar = [
        math.hypot(cx - merkez, cy - merkez) + r,
        # Yolların uç ve kontrol noktaları (Bezier eğrisi kontrol
        # noktalarının dışbükey zarfındadır) + yarım kalem kalınlığı.
        *(
            math.hypot(x - merkez, y - merkez) + KALINLIK / 2
            for x, y in [(31, 8), (30, 22), (28, 34), (30, 44), (32, 53),
                         (40, 57), (48, 51), (14, 27), (24, 27), (36, 25),
                         (48, 21)]
        ),
    ]
    en_uzak = max(noktalar) * ADAPTIF_OLCEK
    if en_uzak > GUVENLI_YARICAP:
        raise SystemExit(
            f"Monogram güvenli bölgeyi aşıyor: {en_uzak:.1f} dp > "
            f"{GUVENLI_YARICAP} dp"
        )


def _yaz(yol: pathlib.Path, icerik: str) -> None:
    yol.parent.mkdir(parents=True, exist_ok=True)
    yol.write_text(icerik, encoding="utf-8")
    print(yol.relative_to(KOK))


def main() -> None:
    _guvenli_bolge_denetle()
    _yaz(RES / "values" / "ic_launcher_renkleri.xml", renkler_xml())
    _yaz(RES / "drawable" / "ic_launcher_foreground.xml", on_plan_xml())
    _yaz(RES / "mipmap-anydpi-v26" / "ic_launcher.xml", uyarlanabilir_xml())
    svg = app_icon_svg().encode("utf-8")
    for yogunluk, boyut in YOGUNLUKLAR.items():
        hedef = RES / f"mipmap-{yogunluk}" / "ic_launcher.png"
        cairosvg.svg2png(
            bytestring=svg,
            write_to=str(hedef),
            output_width=boyut,
            output_height=boyut,
        )
        print(hedef.relative_to(KOK))


if __name__ == "__main__":
    main()
