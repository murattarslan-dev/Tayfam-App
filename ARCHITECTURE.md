# Mimari

Tayfam istemcisi tek bir Flutter kod tabanıdır ve yalnızca Android ve iOS'ta
yayınlanır. Web istemcisi yoktur: web derlemesi
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
  features/   tayfa · ana_sayfa · duyuru · etkinlik · soru_cevap · anket · sohbet · birebir · bildirim
              profil · hesap · arkadas · kesfet · kutuphane · soru_havuzu · materyal · garaj · rozet · istatistik …
  core/       ApiClient + üretilmiş uçlar · SessionStore · realtime · kuyruk · push · tema · çeviri
        │  HTTPS (REST, problem+json)  ·  WebSocket
        ▼
gateway ──gRPC──▶ identity · core · chat      (Tayfam-Api)
                                     └──FCM──▶ cihaz (push, içeriksiz; ADR-0019)
```

## Kararlar

Bütün kararlar ve güncel durumları [`docs/adr/README.md`](docs/adr/README.md)
listesindedir; bu dosyada ayrıca tekrarlanmaz (iki liste zamanla
birbirinden kopuyordu).

Güvenlik ilkesi ve kesin kurallar: [CLAUDE.md](CLAUDE.md).
