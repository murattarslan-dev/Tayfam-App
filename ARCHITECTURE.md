# Mimari

Tayfam istemcisi tek bir Flutter kod tabanıdır ve yalnızca Android ve iOS'ta
yayınlanır; ilk hedef platform Android. Web istemcisi yoktur: web derlemesi
yalnızca geliştirme sırasında uygulamayı hızlıca açmak içindir ve
yayınlanmaz. `tayfam.app` tanıtım sayfası ve davet/referans linklerinin
karşılama sayfasıdır (ADR-0011); kaynağı bu repodaki `site/` klasörüdür
(ADR-0013).

İstemci yalnızca Tayfam-Api'nin gateway'iyle konuşur (dev:
`https://api-dev.tayfam.app`). Sözleşme Tayfam-Api reposundaki
`api/openapi/gateway.yaml`'dır; gerçek zamanlı iletişim `GET /v1/realtime`
WebSocket'iyle yapılır.

```
Flutter uygulaması (Android / iOS)
  shell/      gezinme, tayfa geçişi, derin linkler, modül kayıtları
  features/   tayfa · duyuru · etkinlik · soru_cevap · anket · sohbet · bildirim · profil · hesap · hosgeldin
  core/       ApiClient + üretilmiş uçlar · SessionStore · realtime · kuyruk · tema · çeviri
        │  HTTPS (REST, problem+json)  ·  WebSocket
        ▼
gateway ──gRPC──▶ identity · core · chat      (Tayfam-Api)
```

## Kararlar

| ADR | Konu | Özet |
| --- | --- | --- |
| [0001](docs/adr/0001-durum-yonetimi-riverpod.md) | Durum ve DI | Riverpod 3, kod üretimi yok, tayfa kapsamı `family` + `autoDispose` |
| [0002](docs/adr/0002-modul-yapisi.md) | Modüller | Tek paket; `core/`, `shell/`, `features/`; iki kayıt (tayfa modülleri, etkinlik türleri) |
| [0003](docs/adr/0003-gezinme-iskeleti.md) | Gezinme | Tayfa merkezli, 4 sabit sekme, `go_router` |
| [0004](docs/adr/0004-tema-ve-bilesen-dili.md) | Tema | Token'lar, gömülü font, açık ve koyu tema, mor tayfa üst bölümü |
| [0005](docs/adr/0005-api-istemcisi.md) | API istemcisi | Repodaki üretici, tek `ApiClient`, tek uçuşlu token yenileme |
| [0006](docs/adr/0006-onbellek-ve-cevrimdisi-kuyruk.md) | Önbellek | Diske içerik yazılmaz; önbellek ve kuyruk bellekte |
| [0007](docs/adr/0007-websocket.md) | WebSocket | Tek bağlantı, aktif tayfa abonelikleri, WebSocket önce, REST yedek |
| [0008](docs/adr/0008-ceviri-ve-yerel-ayar.md) | Çeviri | `gen_l10n`, `tr_TR`, Türkçe harf yardımcısı |
| [0009](docs/adr/0009-test-ci-ve-ios.md) | Test ve CI | Birim/widget/golden testler, GitHub Actions CI, iOS için ileride macOS runner |
| [0010](docs/adr/0010-signal-kutuphanesi.md) | Signal | Resmi Rust çekirdeği (AGPL-3.0), anahtarlar güvenli depoda |
| [0011](docs/adr/0011-yalnizca-mobil.md) | Platform | Yalnızca Android ve iOS; web yalnızca geliştirme derlemesi |
| [0012](docs/adr/0012-giris-ve-kayit-akisi.md) | Giriş ve kayıt | Sürüm kontrolü, Google girişi, doğum tarihi teyidi, sürümlü hukuki metinler tayfam.app'te |
| [0013](docs/adr/0013-tanitim-sitesi.md) | Tanıtım sitesi | `site/` klasörü, JavaScript yok, main'den CI ile Cloudflare Pages'e |
| [0014](docs/adr/0014-tayfa-listesi-katilim-ve-olusturma.md) | Tayfa ve katılım | Son tayfa hatırlanır, bekleyenler panelde, kodla katılım, sihirbazla oluşturma, sistem paylaşımı |
| [0015](docs/adr/0015-etkinlik-ve-duyuru-modulleri.md) | Etkinlik ve duyuru | İki bölümlü ana sayfa, sihirbaz, OSM harita seçici, varış bildiriminde tek seferlik konum |
| [0016](docs/adr/0016-uygulama-degerlendirme-penceresi.md) | Değerlendirme | "Geliyorum" dediği ilk etkinlik bitince mağaza penceresi, cihazda bir kez |

Güvenlik ilkesi ve kesin kurallar: [CLAUDE.md](CLAUDE.md).
