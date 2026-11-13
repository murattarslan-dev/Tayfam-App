#!/usr/bin/env python3
"""Play test kanalına .aab yükler (issue #95, ADR-0018 §10 Notlar).

Play Developer API v3 ile tek bir "edit" içinde:

  1. edits.insert
  2. edits.bundles.upload   (uploadType=media, application/octet-stream)
  3. edits.tracks.update    (--kanal; varsayılan "internal", tek sürüm)
  4. edits.commit

Herhangi bir adım başarısız olursa (iptal sinyali dahil) açılan edit
edits.delete ile silinir; yarım bir edit Play'de kalmaz.

Yalnızca Python standart kütüphanesi kullanılır (yeni bağımlılık yok).

Girdiler:
  --paket, --aab, --surum-kodu, --durum, --kanal   komut satırı
                       (--kanal: Play kanal adı; kapalı test varsayılanı "alpha")
  PLAY_ERISIM_TOKENI   ortam değişkeni; androidpublisher kapsamlı OAuth
                       erişim token'ı (Workload Identity Federation ile,
                       google-github-actions/auth). Komut satırına konmaz.
  PLAY_SURUM_NOTU      ortam değişkeni; tr-TR sürüm notu (isteğe bağlı, çok satırlı).
  PLAY_API_KOK         yalnızca testler içindir; varsayılan Google'ın
                       adresi. Token başka bir yere gitmesin diye yalnızca
                       Google adresi ya da yerel (127.0.0.1/localhost)
                       sahte sunucu kabul edilir.

Log'a yalnızca adım adı, HTTP durum kodu ve Google hata "reason"ı yazılır.
Erişim token'ı, edit kimliği ve yanıt gövdeleri yazılmaz.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import sys
import urllib.error
import urllib.parse
import urllib.request

VARSAYILAN_KOK = "https://androidpublisher.googleapis.com"
DAHILI_KANAL = "internal"
KANAL_DESENI = re.compile(r"^[a-z0-9][a-z0-9:_-]{0,63}$")
SURUM_NOTU_DILI = "tr-TR"
# Play bir dil için en fazla 500 karakter kabul eder.
SURUM_NOTU_SINIRI = 500
DURUMLAR = ("completed", "draft")
PAKET_DESENI = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$")
YEREL_KOK_DESENI = re.compile(r"^http://(127\.0\.0\.1|localhost)(:[0-9]{1,5})?$")

JSON_ZAMAN_ASIMI = 60
YUKLEME_ZAMAN_ASIMI = 900


class PlayHatasi(Exception):
    """Bir API adımı başarısız oldu; mesajda gizli bilgi yoktur."""


class Iptal(Exception):
    """İş akışı iptal edildi (SIGTERM/SIGINT)."""


def _iptal_et(signum, _frame):
    raise Iptal(f"sinyal {signum}")


def api_koku() -> str:
    kok = os.environ.get("PLAY_API_KOK", "").strip() or VARSAYILAN_KOK
    kok = kok.rstrip("/")
    if kok != VARSAYILAN_KOK and not YEREL_KOK_DESENI.match(kok):
        raise PlayHatasi(
            "PLAY_API_KOK yalnızca Google adresi ya da yerel test sunucusu olabilir."
        )
    return kok


def hata_nedeni(govde: bytes) -> str:
    """Google hata gövdesinden yalnızca makine okunur nedeni çıkarır."""
    try:
        hata = json.loads(govde.decode("utf-8")).get("error", {})
    except (ValueError, UnicodeDecodeError, AttributeError):
        return "bilinmiyor"
    if not isinstance(hata, dict):
        return "bilinmiyor"
    nedenler = hata.get("errors")
    if isinstance(nedenler, list) and nedenler and isinstance(nedenler[0], dict):
        neden = nedenler[0].get("reason")
        if isinstance(neden, str) and neden:
            return neden
    durum = hata.get("status")
    if isinstance(durum, str) and durum:
        return durum
    return "bilinmiyor"


def surum_notu(ham: str) -> str:
    """Satır yapısını korur (madde işaretli notlar için), her satırdaki
    kontrol karakterlerini ve fazla boşlukları atar, boş satırları ve `#`
    ile başlayan açıklama satırlarını çıkarır, 500 karakterle sınırlar."""
    satirlar = []
    for satir in ham.splitlines():
        satir = re.sub(r"[\x00-\x1f\x7f]+", " ", satir)
        satir = re.sub(r"\s+", " ", satir).strip()
        if satir and not satir.startswith("#"):
            satirlar.append(satir)
    temiz = "\n".join(satirlar)
    if len(temiz) > SURUM_NOTU_SINIRI:
        temiz = temiz[: SURUM_NOTU_SINIRI - 1].rstrip() + "…"
    return temiz


class PlayIstemcisi:
    def __init__(self, kok: str, token: str, paket: str):
        self._kok = kok
        self._token = token
        self._paket = urllib.parse.quote(paket, safe=".")

    def _istek(
        self,
        adim: str,
        yontem: str,
        yol: str,
        *,
        govde=None,
        icerik_turu: str | None = None,
        uzunluk: int | None = None,
        zaman_asimi: int = JSON_ZAMAN_ASIMI,
    ) -> dict:
        istek = urllib.request.Request(self._kok + yol, data=govde, method=yontem)
        # Yönlendirmede başka adrese taşınmasın.
        istek.add_unredirected_header("Authorization", "Bearer " + self._token)
        istek.add_header("Accept", "application/json")
        if icerik_turu:
            istek.add_header("Content-Type", icerik_turu)
        if uzunluk is not None:
            istek.add_header("Content-Length", str(uzunluk))
        try:
            with urllib.request.urlopen(istek, timeout=zaman_asimi) as yanit:
                durum = yanit.status
                veri = yanit.read()
        except urllib.error.HTTPError as hata:
            neden = hata_nedeni(hata.read())
            print(f"{adim}: HTTP {hata.code} ({neden})", flush=True)
            raise PlayHatasi(f"{adim} başarısız: HTTP {hata.code} ({neden})") from None
        except urllib.error.URLError as hata:
            tur = type(hata.reason).__name__
            print(f"{adim}: bağlantı hatası ({tur})", flush=True)
            raise PlayHatasi(f"{adim} başarısız: bağlantı hatası ({tur})") from None
        print(f"{adim}: HTTP {durum}", flush=True)
        if not veri:
            return {}
        try:
            sonuc = json.loads(veri.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise PlayHatasi(f"{adim}: yanıt JSON değil") from None
        return sonuc if isinstance(sonuc, dict) else {}

    def _edit_yolu(self, edit: str, ek: str = "") -> str:
        return (
            f"/androidpublisher/v3/applications/{self._paket}/edits/"
            f"{urllib.parse.quote(edit, safe='')}{ek}"
        )

    def edit_ac(self) -> str:
        sonuc = self._istek(
            "edits.insert",
            "POST",
            f"/androidpublisher/v3/applications/{self._paket}/edits",
            govde=b"{}",
            icerik_turu="application/json",
        )
        edit = sonuc.get("id")
        if not isinstance(edit, str) or not edit:
            raise PlayHatasi("edits.insert: yanıtta edit kimliği yok")
        return edit

    def paket_yukle(self, edit: str, aab: str) -> int:
        boyut = os.path.getsize(aab)
        with open(aab, "rb") as dosya:
            sonuc = self._istek(
                "edits.bundles.upload",
                "POST",
                "/upload" + self._edit_yolu(edit, "/bundles?uploadType=media"),
                govde=dosya,
                icerik_turu="application/octet-stream",
                uzunluk=boyut,
                zaman_asimi=YUKLEME_ZAMAN_ASIMI,
            )
        kod = sonuc.get("versionCode")
        try:
            return int(kod)
        except (TypeError, ValueError):
            raise PlayHatasi("edits.bundles.upload: yanıtta versionCode yok") from None

    def kanali_guncelle(
        self, edit: str, kanal: str, surum_kodu: int, durum: str, notu: str
    ):
        surum: dict = {"versionCodes": [str(surum_kodu)], "status": durum}
        if notu:
            surum["releaseNotes"] = [{"language": SURUM_NOTU_DILI, "text": notu}]
        govde = json.dumps(
            {"track": kanal, "releases": [surum]}, ensure_ascii=False
        ).encode("utf-8")
        self._istek(
            "edits.tracks.update",
            "PUT",
            self._edit_yolu(edit, f"/tracks/{urllib.parse.quote(kanal, safe='')}"),
            govde=govde,
            icerik_turu="application/json; charset=utf-8",
        )

    def edit_onayla(self, edit: str):
        self._istek("edits.commit", "POST", self._edit_yolu(edit, ":commit"))

    def edit_sil(self, edit: str):
        self._istek("edits.delete", "DELETE", self._edit_yolu(edit))


def yukle(
    istemci: PlayIstemcisi,
    aab: str,
    surum_kodu: int,
    durum: str,
    notu: str,
    kanal: str = DAHILI_KANAL,
) -> None:
    edit = istemci.edit_ac()
    onaylandi = False
    try:
        yuklenen = istemci.paket_yukle(edit, aab)
        if yuklenen != surum_kodu:
            raise PlayHatasi(
                f"Yüklenen paketin versionCode'u {yuklenen}, beklenen {surum_kodu}."
            )
        istemci.kanali_guncelle(edit, kanal, surum_kodu, durum, notu)
        istemci.edit_onayla(edit)
        onaylandi = True
    finally:
        if not onaylandi:
            # Asıl hatayı gölgelemeden yarım edit'i silmeyi dene.
            try:
                istemci.edit_sil(edit)
            except (PlayHatasi, Iptal):
                print("edits.delete: edit silinemedi; Play süresi dolunca atar.")


def main(argv: list[str] | None = None) -> int:
    ayr = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ayr.add_argument("--paket", required=True)
    ayr.add_argument("--aab", required=True)
    ayr.add_argument("--surum-kodu", required=True, type=int)
    ayr.add_argument("--durum", default="completed")
    ayr.add_argument("--kanal", default=DAHILI_KANAL)
    args = ayr.parse_args(argv)

    if not PAKET_DESENI.match(args.paket):
        print("::error::Paket adı geçersiz.")
        return 2
    if args.durum not in DURUMLAR:
        print(f"::error::Sürüm durumu {'/'.join(DURUMLAR)} olmalı.")
        return 2
    if not KANAL_DESENI.match(args.kanal):
        print("::error::Kanal adı geçersiz.")
        return 2
    if args.surum_kodu <= 0:
        print("::error::versionCode pozitif olmalı.")
        return 2
    if not os.path.isfile(args.aab) or os.path.getsize(args.aab) == 0:
        print("::error::.aab dosyası yok ya da boş.")
        return 2
    token = os.environ.get("PLAY_ERISIM_TOKENI", "")
    if not token:
        print("::error::PLAY_ERISIM_TOKENI yok.")
        return 2

    signal.signal(signal.SIGTERM, _iptal_et)
    signal.signal(signal.SIGINT, _iptal_et)
    try:
        istemci = PlayIstemcisi(api_koku(), token, args.paket)
        yukle(
            istemci,
            args.aab,
            args.surum_kodu,
            args.durum,
            surum_notu(os.environ.get("PLAY_SURUM_NOTU", "")),
            args.kanal,
        )
    except (PlayHatasi, Iptal) as hata:
        print(f"::error title=Play yüklemesi::{hata}")
        return 1
    print(
        f"versionCode {args.surum_kodu} '{args.kanal}' kanalına yüklendi "
        f"(durum: {args.durum})."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
