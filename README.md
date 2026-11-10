# Tayfam

Tayfam'ın Flutter mobil uygulaması (Android ve iOS): kulüplerin ve arkadaş
gruplarının etkinlik, duyuru, soru-cevap ve sohbet uygulaması.

Sunucu tarafı ayrı repodadır:
[murattarslan-dev/Tayfam-Api](https://github.com/murattarslan-dev/Tayfam-Api).
İstemcinin konuştuğu tek sözleşme oradaki `api/openapi/gateway.yaml`'dır.

> **Durum:** Mimari karar aşaması. Kararlar `docs/adr/` altına yazıldıkça
> kod eklenecek. İlk hedef platform Android.

- Kodlama kuralları ve iş akışı: [CLAUDE.md](CLAUDE.md)
- Kararlar: [docs/adr/](docs/adr/README.md)

## Lisans ve güvenlik

Kod [MIT](LICENSE) lisanslıdır. "Tayfam" adı ve logosu lisans kapsamında
değildir. Güvenlik açıklarını herkese açık issue yerine
[SECURITY.md](SECURITY.md)'deki yolla bildir.
