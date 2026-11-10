#!/usr/bin/env python3
"""tayfam.app tanıtım sitesi (site/) denetimi — ADR-0013 §3 ve §5.

Kullanım: python3 -I .github/site-denetimi/denetle.py [site-dizini]

Yalnızca standart kütüphane. HTML geçerliliği ayrıca html-validate ile
denetlenir (bkz. .github/workflows/ci.yml, `site` işi). Bu betiğin
denetledikleri:

1. JavaScript yok: <script> öğesi, on* olay öznitelikleri ve javascript:
   adresleri (HTML ve SVG dosyalarında).
2. Dış kaynak yalnızca Google Fonts: yüklenen kaynaklar (link, img, source,
   iframe, object, embed …) yalnızca site içinden ya da
   fonts.googleapis.com / fonts.gstatic.com'dan gelir.
3. İç bağlantılar: site içi her href/src bir dosyaya (ya da _redirects
   kaynağına) çıkar; #parça bağlantıları hedef sayfada bir id'ye çıkar.
4. _redirects: her satır "kaynak hedef [durum]" biçiminde, durum geçerli,
   site içi hedef var.
5. _headers: "/*" kuralında zorunlu güvenlik başlıkları ve değerleri.
6. .well-known: *.json ve apple-app-site-association geçerli JSON.

Bir sorun bulunursa hepsi listelenir ve çıkış kodu 1 olur.
"""

from __future__ import annotations

import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

IZINLI_DIS_KAYNAK = {"fonts.googleapis.com", "fonts.gstatic.com"}
# Kaynak yükleyen (sayfanın parçası olan) öğe/öznitelikler. <a href> gezinme
# bağlantısıdır, kaynak değildir; dış bağlantıya izin verilir.
KAYNAK_OZNITELIKLERI = {
    "link": ("href",),
    "img": ("src", "srcset"),
    "source": ("src", "srcset"),
    "video": ("src", "poster"),
    "audio": ("src",),
    "track": ("src",),
    "iframe": ("src",),
    "frame": ("src",),
    "embed": ("src",),
    "object": ("data",),
    "image": ("href", "xlink:href"),
    "use": ("href", "xlink:href"),
}
GEZINME_OZNITELIKLERI = {"a": ("href",), "area": ("href",)}
YONLENDIRME_DURUMLARI = {"200", "301", "302", "303", "307", "308"}

sorunlar: list[str] = []


def sorun(dosya: Path | str, mesaj: str) -> None:
    sorunlar.append(f"{dosya}: {mesaj}")


class Ayristirici(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.idler: set[str] = set()
        self.kaynaklar: list[tuple[int, str, str]] = []  # (satır, öğe, adres)
        self.gezinme: list[tuple[int, str]] = []
        self.betik: list[tuple[int, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        satir = self.getpos()[0]
        if tag == "script":
            self.betik.append((satir, "<script> öğesi"))
        for ad, deger in attrs:
            deger = deger or ""
            if ad.startswith("on"):
                self.betik.append((satir, f"olay özniteliği {ad}"))
            if re.match(r"^\s*javascript:", deger, re.IGNORECASE):
                self.betik.append((satir, f"javascript: adresi ({ad})"))
            if ad in ("id", "name") and deger:
                self.idler.add(deger)
        oz = dict(attrs)
        for ad in KAYNAK_OZNITELIKLERI.get(tag, ()):
            deger = oz.get(ad)
            if not deger:
                continue
            if ad == "srcset":
                for parca in deger.split(","):
                    adres = parca.strip().split(" ")[0]
                    if adres:
                        self.kaynaklar.append((satir, tag, adres))
            else:
                self.kaynaklar.append((satir, tag, deger))
        for ad in GEZINME_OZNITELIKLERI.get(tag, ()):
            deger = oz.get(ad)
            if deger is not None:
                self.gezinme.append((satir, deger))

    handle_startendtag = handle_starttag


def ayristir(dosya: Path) -> Ayristirici:
    a = Ayristirici()
    a.feed(dosya.read_text(encoding="utf-8"))
    a.close()
    return a


def redirects_kaynaklari(kok: Path) -> dict[str, str]:
    """_redirects dosyasını denetler; kaynak → hedef sözlüğü döner."""
    dosya = kok / "_redirects"
    sonuc: dict[str, str] = {}
    if not dosya.exists():
        return sonuc
    for no, satir in enumerate(dosya.read_text(encoding="utf-8").splitlines(), 1):
        satir = satir.strip()
        if not satir or satir.startswith("#"):
            continue
        parcalar = satir.split()
        if len(parcalar) not in (2, 3):
            sorun(f"{dosya}:{no}", "satır 'kaynak hedef [durum]' biçiminde değil")
            continue
        kaynak, hedef = parcalar[0], parcalar[1]
        if not kaynak.startswith("/"):
            sorun(f"{dosya}:{no}", f"kaynak '/' ile başlamalı: {kaynak}")
        if len(parcalar) == 3 and parcalar[2] not in YONLENDIRME_DURUMLARI:
            sorun(f"{dosya}:{no}", f"geçersiz durum kodu: {parcalar[2]}")
        hedef_url = urlsplit(hedef)
        if hedef_url.scheme and hedef_url.scheme != "https":
            sorun(f"{dosya}:{no}", f"dış hedef https olmalı: {hedef}")
        sonuc[kaynak.rstrip("/") or "/"] = hedef
    return sonuc


def site_yolunu_coz(kok: Path, yol: str) -> Path | None:
    """Cloudflare Pages'in sunacağı dosyayı bulur (yoksa None)."""
    yol = unquote(yol)
    if ".." in Path(yol).parts:
        return None
    aday = kok / yol.lstrip("/")
    adaylar = [aday / "index.html"] if yol.endswith("/") else [
        aday,
        aday / "index.html",
        aday.with_name(aday.name + ".html"),
    ]
    for a in adaylar:
        try:
            a.resolve().relative_to(kok.resolve())
        except ValueError:
            return None
        if a.is_file():
            return a
    return None


def html_denetle(kok: Path, dosya: Path, yonlendirmeler: dict[str, str],
                 idler: dict[Path, set[str]]) -> None:
    a = ayristir(dosya)
    for satir, ne in a.betik:
        sorun(f"{dosya}:{satir}", f"JavaScript yasak (ADR-0013 §3): {ne}")
    if dosya.suffix != ".html":
        return

    for satir, oge, adres in a.kaynaklar:
        u = urlsplit(adres)
        if u.scheme == "data":
            continue
        if u.scheme or adres.startswith("//"):
            if u.scheme != "https" or u.hostname not in IZINLI_DIS_KAYNAK:
                sorun(f"{dosya}:{satir}",
                      f"dış kaynak yalnızca Google Fonts olabilir (<{oge}>): {adres}")
            continue
        ic_baglanti(kok, dosya, satir, adres, yonlendirmeler, idler)

    for satir, adres in a.gezinme:
        u = urlsplit(adres)
        if u.scheme in ("http", "https", "mailto", "tel") or adres.startswith("//"):
            if u.scheme == "http":
                sorun(f"{dosya}:{satir}", f"bağlantı https olmalı: {adres}")
            continue
        if u.scheme:
            sorun(f"{dosya}:{satir}", f"desteklenmeyen bağlantı şeması: {adres}")
            continue
        ic_baglanti(kok, dosya, satir, adres, yonlendirmeler, idler)


def ic_baglanti(kok: Path, dosya: Path, satir: int, adres: str,
                yonlendirmeler: dict[str, str],
                idler: dict[Path, set[str]]) -> None:
    u = urlsplit(adres)
    if not u.path:
        hedef: Path | None = dosya
    else:
        if u.path.startswith("/"):
            mutlak = u.path
        else:
            goreli = dosya.parent.relative_to(kok).as_posix()
            mutlak = "/" + (f"{goreli}/" if goreli != "." else "") + u.path
        anahtar = mutlak.rstrip("/") or "/"
        if anahtar in yonlendirmeler:
            return
        hedef = site_yolunu_coz(kok, mutlak)
        if hedef is None:
            sorun(f"{dosya}:{satir}", f"iç bağlantının hedefi yok: {adres}")
            return
    parca = unquote(u.fragment)
    if parca and hedef.suffix == ".html":
        if hedef not in idler:
            idler[hedef] = ayristir(hedef).idler
        if parca not in idler[hedef]:
            sorun(f"{dosya}:{satir}", f"#{parca} hedef sayfada yok: {adres}")


def basliklari_oku(dosya: Path) -> dict[str, dict[str, str]]:
    kurallar: dict[str, dict[str, str]] = {}
    gecerli: dict[str, str] | None = None
    for no, satir in enumerate(dosya.read_text(encoding="utf-8").splitlines(), 1):
        if not satir.strip() or satir.lstrip().startswith("#"):
            continue
        if not satir[0].isspace():
            gecerli = kurallar.setdefault(satir.strip(), {})
            continue
        if gecerli is None or ":" not in satir:
            sorun(f"{dosya}:{no}", "başlık satırı bir yol kuralının altında değil")
            continue
        ad, deger = satir.strip().split(":", 1)
        gecerli[ad.strip().lower()] = deger.strip()
    return kurallar


def csp_ayristir(deger: str) -> dict[str, list[str]]:
    sonuc: dict[str, list[str]] = {}
    for yonerge in deger.split(";"):
        parcalar = yonerge.split()
        if parcalar:
            sonuc[parcalar[0].lower()] = parcalar[1:]
    return sonuc


def basliklari_denetle(kok: Path) -> None:
    dosya = kok / "_headers"
    if not dosya.is_file():
        sorun(dosya, "dosya yok (ADR-0013 §3)")
        return
    kurallar = basliklari_oku(dosya)
    b = kurallar.get("/*")
    if b is None:
        sorun(dosya, "bütün sayfaları kapsayan '/*' kuralı yok")
        return

    csp_degeri = b.get("content-security-policy")
    if not csp_degeri:
        sorun(dosya, "Content-Security-Policy yok")
    else:
        csp = csp_ayristir(csp_degeri)
        if csp.get("default-src") != ["'none'"]:
            sorun(dosya, "CSP default-src 'none' olmalı")
        if "script-src" in csp and csp["script-src"] != ["'none'"]:
            sorun(dosya, "CSP script-src verilecekse yalnızca 'none' olabilir (JavaScript yok)")
        if csp.get("frame-ancestors") != ["'none'"]:
            sorun(dosya, "CSP frame-ancestors 'none' olmalı")
        if csp.get("base-uri") != ["'none'"]:
            sorun(dosya, "CSP base-uri 'none' olmalı")
        if csp.get("form-action") != ["'none'"]:
            sorun(dosya, "CSP form-action 'none' olmalı")
        for yonerge, kaynaklar in csp.items():
            for k in kaynaklar:
                if k in ("*", "'unsafe-eval'", "http:", "https:") or k.startswith("http://"):
                    sorun(dosya, f"CSP {yonerge} çok geniş: {k}")
                if k.startswith("https://"):
                    host = urlsplit(k).hostname
                    if host not in IZINLI_DIS_KAYNAK:
                        sorun(dosya, f"CSP {yonerge} yalnızca Google Fonts'a izin verebilir: {k}")

    if b.get("x-content-type-options", "").lower() != "nosniff":
        sorun(dosya, "X-Content-Type-Options: nosniff olmalı")

    izinli_ref = {"no-referrer", "same-origin", "strict-origin",
                  "strict-origin-when-cross-origin"}
    if b.get("referrer-policy", "").lower() not in izinli_ref:
        sorun(dosya, f"Referrer-Policy şunlardan biri olmalı: {sorted(izinli_ref)}")

    pp = b.get("permissions-policy", "").replace(" ", "")
    for ozellik in ("camera", "microphone", "geolocation"):
        if f"{ozellik}=()" not in pp.split(","):
            sorun(dosya, f"Permissions-Policy {ozellik}=() içermeli")

    hsts = b.get("strict-transport-security", "")
    m = re.search(r"max-age=(\d+)", hsts)
    if not m or int(m.group(1)) < 31536000:
        sorun(dosya, "Strict-Transport-Security max-age en az 31536000 olmalı")


def well_known_denetle(kok: Path) -> None:
    dizin = kok / ".well-known"
    if not dizin.is_dir():
        return
    for dosya in sorted(dizin.rglob("*")):
        if dosya.is_file() and (dosya.suffix == ".json"
                                or dosya.name == "apple-app-site-association"):
            try:
                json.loads(dosya.read_text(encoding="utf-8"))
            except (ValueError, UnicodeDecodeError) as hata:
                sorun(dosya, f"geçerli JSON değil: {hata}")


def main() -> int:
    kok = Path(sys.argv[1] if len(sys.argv) > 1 else "site")
    if not kok.is_dir():
        print(f"{kok}: dizin yok", file=sys.stderr)
        return 1
    yonlendirmeler = redirects_kaynaklari(kok)
    for kaynak, hedef in yonlendirmeler.items():
        if hedef.startswith("/") and site_yolunu_coz(kok, urlsplit(hedef).path) is None:
            sorun(kok / "_redirects", f"{kaynak} → hedef yok: {hedef}")

    idler: dict[Path, set[str]] = {}
    dosyalar = sorted(p for p in kok.rglob("*")
                      if p.is_file() and p.suffix in (".html", ".htm", ".svg", ".xml"))
    for dosya in dosyalar:
        html_denetle(kok, dosya, yonlendirmeler, idler)
    for js in sorted(kok.rglob("*.js")) + sorted(kok.rglob("*.mjs")):
        sorun(js, "JavaScript dosyası yasak (ADR-0013 §3)")
    if (kok / "_worker.js").exists() or (kok / "functions").exists():
        sorun(kok, "Pages Functions / _worker.js yasak (statik site)")

    basliklari_denetle(kok)
    well_known_denetle(kok)

    if sorunlar:
        for s in sorunlar:
            print(f"::error::{s}")
        print(f"\n{len(sorunlar)} sorun bulundu.")
        return 1
    print(f"site denetimi geçti: {len(dosyalar)} HTML/SVG dosyası, "
          f"{len(yonlendirmeler)} yönlendirme.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
