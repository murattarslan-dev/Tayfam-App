"""dahili_yukle.py testleri: yerel sahte Play API sunucusuna karşı.

Gerçek ağ yoktur; sunucu 127.0.0.1'de rastgele bir portta çalışır.
Çalıştırma: python3 -m unittest discover -s tool/play
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dahili_yukle  # noqa: E402

PAKET = "com.murattarslan.tayfam"
TOKEN = "sahte-token-gizli"
EDIT = "edit-1"
KOK = f"/androidpublisher/v3/applications/{PAKET}/edits"


class SahtePlay:
    """İstekleri kaydeder; belirli bir adımda hata döndürebilir."""

    def __init__(self, hata_adimi: str | None = None, surum_kodu: int = 105):
        self.hata_adimi = hata_adimi
        self.surum_kodu = surum_kodu
        self.istekler: list[dict] = []

    def adim(self, yontem: str, yol: str) -> str:
        if yontem == "POST" and yol == KOK:
            return "insert"
        if yontem == "POST" and yol == f"/upload{KOK}/{EDIT}/bundles?uploadType=media":
            return "upload"
        if yontem == "PUT" and yol.startswith(f"{KOK}/{EDIT}/tracks/"):
            self.kanal = yol.rsplit("/", 1)[1]
            return "track"
        if yontem == "POST" and yol == f"{KOK}/{EDIT}:commit":
            return "commit"
        if yontem == "DELETE" and yol == f"{KOK}/{EDIT}":
            return "delete"
        return "bilinmeyen"

    def isleyici(self):
        sahte = self

        class Isleyici(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def _isle(self):
                uzunluk = int(self.headers.get("Content-Length") or 0)
                govde = self.rfile.read(uzunluk) if uzunluk else b""
                adim = sahte.adim(self.command, self.path)
                sahte.istekler.append(
                    {
                        "adim": adim,
                        "yetki": self.headers.get("Authorization"),
                        "tur": self.headers.get("Content-Type"),
                        "govde": govde,
                    }
                )
                if adim == sahte.hata_adimi or adim == "bilinmeyen":
                    yanit = {
                        "error": {
                            "code": 403,
                            "message": "gizli ayrıntı " + TOKEN,
                            "status": "PERMISSION_DENIED",
                            "errors": [{"reason": "permissionDenied"}],
                        }
                    }
                    self._gonder(403, yanit)
                    return
                yanitlar = {
                    "insert": {"id": EDIT, "expiryTimeSeconds": "1"},
                    "upload": {"versionCode": sahte.surum_kodu, "sha1": "x"},
                    "track": {"track": "internal"},
                    "commit": {"id": EDIT},
                    "delete": None,
                }
                self._gonder(200 if adim != "delete" else 204, yanitlar[adim])

            def _gonder(self, kod, veri):
                govde = b"" if veri is None else json.dumps(veri).encode()
                self.send_response(kod)
                if govde:
                    self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(govde)))
                self.end_headers()
                self.wfile.write(govde)

            do_POST = do_PUT = do_DELETE = _isle

        return Isleyici


class DahiliYukleTesti(unittest.TestCase):
    def calistir(
        self, sahte: SahtePlay, *, durum="completed", notu="feat: x", kanal=None
    ):
        sunucu = ThreadingHTTPServer(("127.0.0.1", 0), sahte.isleyici())
        is_parcacigi = threading.Thread(target=sunucu.serve_forever, daemon=True)
        is_parcacigi.start()
        self.addCleanup(sunucu.server_close)
        self.addCleanup(sunucu.shutdown)
        with tempfile.NamedTemporaryFile(suffix=".aab", delete=False) as aab:
            aab.write(b"PK\x03\x04sahte-aab")
        self.addCleanup(os.unlink, aab.name)
        ortam = {
            "PLAY_API_KOK": f"http://127.0.0.1:{sunucu.server_port}",
            "PLAY_ERISIM_TOKENI": TOKEN,
            "PLAY_SURUM_NOTU": notu,
        }
        cikti = io.StringIO()
        eski = {k: os.environ.get(k) for k in ortam}
        os.environ.update(ortam)
        try:
            with contextlib.redirect_stdout(cikti):
                kod = dahili_yukle.main(
                    [
                        "--paket",
                        PAKET,
                        "--aab",
                        aab.name,
                        "--surum-kodu",
                        "105",
                        "--durum",
                        durum,
                    ]
                    + ([] if kanal is None else ["--kanal", kanal])
                )
        finally:
            for k, v in eski.items():
                if v is None:
                    os.environ.pop(k, None)
                else:
                    os.environ[k] = v
        return kod, cikti.getvalue()

    def test_basarili_yukleme_sirasi(self):
        sahte = SahtePlay()
        kod, cikti = self.calistir(sahte, notu="feat: yeni\nözellik (#1)")
        self.assertEqual(kod, 0, cikti)
        self.assertEqual(
            [i["adim"] for i in sahte.istekler],
            ["insert", "upload", "track", "commit"],
        )
        for istek in sahte.istekler:
            self.assertEqual(istek["yetki"], "Bearer " + TOKEN)
        yukleme = sahte.istekler[1]
        self.assertEqual(yukleme["tur"], "application/octet-stream")
        self.assertEqual(yukleme["govde"], b"PK\x03\x04sahte-aab")
        kanal = json.loads(sahte.istekler[2]["govde"].decode("utf-8"))
        self.assertEqual(
            kanal,
            {
                "track": "internal",
                "releases": [
                    {
                        "versionCodes": ["105"],
                        "status": "completed",
                        "releaseNotes": [
                            {"language": "tr-TR", "text": "feat: yeni\nözellik (#1)"}
                        ],
                    }
                ],
            },
        )
        self.assertNotIn(TOKEN, cikti)
        self.assertNotIn(EDIT, cikti)

    def test_kapali_test_kanali(self):
        sahte = SahtePlay()
        kod, cikti = self.calistir(sahte, kanal="alpha")
        self.assertEqual(kod, 0, cikti)
        self.assertEqual(sahte.kanal, "alpha")
        kanal = json.loads(sahte.istekler[2]["govde"].decode("utf-8"))
        self.assertEqual(kanal["track"], "alpha")

    def test_gecersiz_kanal(self):
        sahte = SahtePlay()
        kod, cikti = self.calistir(sahte, kanal="../internal")
        self.assertEqual(kod, 2)
        self.assertEqual(sahte.istekler, [])

    def test_taslak_durumu(self):
        sahte = SahtePlay()
        kod, _ = self.calistir(sahte, durum="draft", notu="")
        self.assertEqual(kod, 0)
        kanal = json.loads(sahte.istekler[2]["govde"].decode("utf-8"))
        self.assertEqual(kanal["releases"][0]["status"], "draft")
        self.assertNotIn("releaseNotes", kanal["releases"][0])

    def test_hatada_edit_silinir(self):
        for adim in ("upload", "track", "commit"):
            with self.subTest(adim=adim):
                sahte = SahtePlay(hata_adimi=adim)
                kod, cikti = self.calistir(sahte)
                self.assertEqual(kod, 1)
                adimlar = [i["adim"] for i in sahte.istekler]
                self.assertEqual(adimlar[-1], "delete")
                self.assertEqual(adimlar.count("delete"), 1)
                self.assertIn("HTTP 403 (permissionDenied)", cikti)
                # Yanıt gövdesi (message) ve token log'a girmez.
                self.assertNotIn("gizli ayrıntı", cikti)
                self.assertNotIn(TOKEN, cikti)

    def test_insert_hatasinda_silinecek_edit_yok(self):
        sahte = SahtePlay(hata_adimi="insert")
        kod, _ = self.calistir(sahte)
        self.assertEqual(kod, 1)
        self.assertEqual([i["adim"] for i in sahte.istekler], ["insert"])

    def test_beklenmeyen_surum_kodunda_onaylanmaz(self):
        sahte = SahtePlay(surum_kodu=7)
        kod, _ = self.calistir(sahte)
        self.assertEqual(kod, 1)
        self.assertEqual(
            [i["adim"] for i in sahte.istekler], ["insert", "upload", "delete"]
        )

    def test_gecersiz_durum_reddedilir(self):
        sahte = SahtePlay()
        kod, _ = self.calistir(sahte, durum="inProgress")
        self.assertEqual(kod, 2)
        self.assertEqual(sahte.istekler, [])


class YardimciTesti(unittest.TestCase):
    def test_surum_notu_500_karakter(self):
        notu = dahili_yukle.surum_notu("a" * 600)
        self.assertEqual(len(notu), 500)
        self.assertTrue(notu.endswith("…"))

    def test_surum_notu_satirlari_korur(self):
        ham = "# açıklama\n\n• Yeni:  demo tayfalar\n• Düzeltme\x07: bildirim\n"
        self.assertEqual(
            dahili_yukle.surum_notu(ham), "• Yeni: demo tayfalar\n• Düzeltme : bildirim"
        )

    def test_surum_notu_bos(self):
        self.assertEqual(dahili_yukle.surum_notu("# yalnızca açıklama\n\n"), "")

    def test_kok_yalnizca_google_ya_da_yerel(self):
        for kok, gecerli in (
            ("", True),
            ("https://androidpublisher.googleapis.com/", True),
            ("http://127.0.0.1:8080", True),
            ("https://ornek.com", False),
            ("http://127.0.0.1.ornek.com", False),
        ):
            with self.subTest(kok=kok):
                os.environ["PLAY_API_KOK"] = kok
                try:
                    if gecerli:
                        dahili_yukle.api_koku()
                    else:
                        with self.assertRaises(dahili_yukle.PlayHatasi):
                            dahili_yukle.api_koku()
                finally:
                    os.environ.pop("PLAY_API_KOK", None)

    def test_hata_nedeni(self):
        self.assertEqual(dahili_yukle.hata_nedeni(b"<html>"), "bilinmiyor")
        self.assertEqual(
            dahili_yukle.hata_nedeni(b'{"error":{"status":"NOT_FOUND"}}'),
            "NOT_FOUND",
        )


if __name__ == "__main__":
    unittest.main()
