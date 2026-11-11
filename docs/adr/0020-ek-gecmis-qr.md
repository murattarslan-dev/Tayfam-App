# ADR-0020 eki (taslak): Geçmiş arşivi, eşleştirme ve yenileme

> Bu dosya ADR-0020'nin (E2E istemci ADR'si; E2 iskeleti oluşturur) bir
> bölümünün taslağıdır. Mimari oturumu birleştirirken içeriği ADR-0020'ye
> "## Geçmiş arşivi, eşleştirme ve yenileme" başlığıyla taşır ve bu dosyayı
> siler. Kaynaklar: e2e ortak tasarımı (platform sahibi kararları
> 2026-11-11 18:4x ve 19:00), araştırma raporu §2–§3, Tayfam-Api ADR-0018
> §4–§6, sözleşme 8ef8245.

## Geçmiş arşivi, eşleştirme ve yenileme

### 1. Geçmiş anahtarı

- Sürüm başına `Random.secure()` ile 32 bayt. Güvenli depoda
  `e2e.gecmis.<sürüm>` kayıtları; bütün sürümler tutulur (eski arşiv
  kayıtları kendi sürümleriyle okunur). Çıkışta ve hesap silmede E2E
  deposunun tamamıyla silinir.
- **İlk cihaz** (`device.paired == false`, `other_paired_device == false`):
  anahtar önce aday sürümle (`history_key_version + 1`) depoya yazılır,
  sonra `POST /v1/me/e2e/history-key`. Sunucu kesin olarak reddederse aday
  silinir; cevap kaybolursa (bağlantı) aday korunur, çünkü sunucu kabul
  etmiş olabilir. Sunucu başka sürüm dönerse anahtar o sürüme taşınır.
  Önceki sürüm > 0 ise kullanıcıya bir kez "eski şifreli mesajlar bu
  cihazda okunamaz" bilgisi gösterilir. `e2e-paired-device-exists` → QR.

### 2. Arşiv kaydı biçimi

```
k       = HKDF-SHA256(geçmişAnahtarı, tuz = ∅, bilgi = "tayfam/arsiv/v1", 32)
içerik  = 0x01 ‖ nonce(12, Random.secure) ‖ AES-256-GCM-SIV(k, nonce, düz, aad)
aad     = "tayfam/arsiv/v1" ‖ user_id(16) ‖ message_id(16) ‖ key_version(u16 BE)
düz     = dolgu160(UTF-8 JSON {v:1, gonderen, created_at, t:"metin", govde})
dolgu160: veri ‖ 0x80 ‖ 0x00…, uzunluk 160'ın katı (ISO/IEC 7816-4)
```

- HKDF ve AES-256-GCM-SIV Signal motorunun (libsignal) yapı taşlarıdır;
  istemcide yalnızca biçim vardır (kesin kural 4). GCM-SIV nonce'un
  yanlış kullanımına dayanıklıdır; rastgele 96 bit nonce güvenlidir.
- AAD kaydı kullanıcıya, mesaja ve sürüme bağlar: sunucu bir kaydı başka
  mesajın, kullanıcının ya da sürümün yerine koyamaz.
- Türetilen anahtar yalnızca bellekte, sürüm başına bir kez türetilir.

### 3. Arşive yazma ve okuma

- **Yazma:** E2'nin gönderilen/çözülen mesaj kancası (`CozulmusMesajAkisi`)
  dinlenir; yalnızca eşleştirilmiş cihaz yazar. Mesajlar bellekte sıraya
  girer, aynı olay döngüsü turunda gelenler birleşir ve en çok 50'lik
  gruplarla `POST /v1/me/e2e/archive` yapılır (sıra en çok 500; fazlasında
  en eskiler düşer). `e2e-history-key-stale` → paylaşımlar çekilir, durum
  tazelenir, grup yeni sürümle bir kez daha şifrelenir. `e2e-not-paired` →
  sıra boşaltılır. Bağlantı ve geçici sunucu hatası → grup sıranın başına
  döner; sonraki mesajda, yeniden bağlanmada ya da paylaşım olayında
  tekrar denenir. Diske hiçbir şey yazılmaz (ADR-0006).
- **Okuma:** konuşma açılınca `GET …/conversations/{id}/archive` (100'lük
  sayfa) bellekte çözülür ve `message_id` ile birebir konuşma notifier'ına
  verilir (`konusmaArsiviProvider(konusmaId)`, `autoDispose`). Anahtarı bu
  cihazda olmayan sürüm, başka konuşmanın ya da doğrulanamayan kayıt
  "okunamayan" sayılır; varsa konuşmada "Eski mesajların bu cihazda
  okunamıyor" satırı gösterilir. Eşleştirilmemiş cihaz istek atmaz.

### 4. QR eşleştirme

- **QR içeriği:** `tayfam-esle:v1:<link_request_id>:<device_id>:<kimlik>:<kod>`
  - `link_request_id`, `device_id`: yeni cihazın eşleştirme isteği ve
    sunucudaki cihaz kimliği (UUID).
  - `kimlik`: yeni cihazın Signal kimlik açık anahtarı (33 bayt, 0x05
    önekli), dolgusuz base64url.
  - `kod`: `Random.secure()` ile 16 bayt doğrulama kodu, dolgusuz
    base64url. Sunucuya hiç gitmez.
  - Ayrıştırma katıdır: önek ve sürüm, tam dört alan, UUID biçimi,
    yalnızca base64url karakterleri, uzunluklar, en çok 256 karakter.
- **Eşleştirilmiş cihaz** (Profil → "Cihaz bağla"): QR okutulur →
  ayrıştırılır → kendi QR'ı reddedilir → `GET /v1/users/{kendi}/e2e/devices`
  listesindeki o cihazın kimlik anahtarı QR'dakiyle sabit zamanlı
  karşılaştırılır; aynı değilse hiçbir şey şifrelenmez. Signal oturumu
  da yalnızca bu kimlikle kurulur (`KendiCihazOturumu.sifrele(…,
  beklenenKimlik)`; ön anahtar paketindeki kimlik farklıysa reddedilir).
  Cevap düz metni `dolgu160(JSON {kod, link_request_id, anahtarlar:
  [{surum, anahtar}]})` kullanıcının kendi cihazları arasındaki Signal
  oturumuyla şifrelenir; paket `tür(1) ‖ Signal şifreli metni` (en çok
  16 KiB) `POST …/link-requests/{id}/answer` ile güncel sürüm numarasıyla
  gider. `e2e-history-key-stale` → paylaşım çekilip bir kez tekrar.
- **Yeni cihaz** (Profil → "Bu cihazı bağla"): `POST /v1/me/e2e/link-requests`
  → QR ve 10 dakikalık geri sayım; süre dolunca "Yeni kod al". Cevap
  WebSocket `e2e.link_answered` ile ya da 5 saniyelik yoklamayla
  (`GET …/{id}`) beklenir → Signal ile çözülür → `link_request_id` ve
  doğrulama kodu (sabit zamanlı) denetlenir → bütün sürümler depoya
  yazılır → `POST …/complete`. Kod tutmazsa hiçbir anahtar yazılmaz.
  `e2e-history-key-stale` → kendiliğinden yeni istek.
- **QR çizimi:** `qr` paketi + `CustomPainter`; tema ne olursa olsun açık
  zemin (açık temanın kart token'ı) üzerinde koyu modüller, 4 modül sessiz
  bölge, hata düzeltme M.

### 5. Geçmiş anahtarının yenilenmesi

- `rotation_needed` olan eşleştirilmiş cihaz yeni 32 baytı aday sürümle
  (`history_key_version + 1`) depoya yazar ve `POST …/history-key/rotate`
  çağırır. Hangi cihazların eşleştirilmiş olduğu yalnızca sunucuda
  bilindiği için ilk deneme boş paylaşım kümesiyle yapılır;
  `e2e-devices-changed` cevabındaki `missing_device_ids` için kendi cihaz
  oturumuyla paylaşım (`dolgu160(JSON {anahtarlar: [{surum, anahtar}]})`)
  hazırlanır, `stale_device_ids` çıkarılır; en çok 3 tekrar.
- `e2e-history-key-stale` (başka cihaz önce yeniledi): aday silinir,
  paylaşımlar çekilir, vazgeçilir. Sonucu bilinmeyen istekte aday silinmez.
- **Paylaşım alma:** WebSocket `e2e.history_key_shared`, yeniden bağlanma
  ve açılışta `GET …/history-key-shares` → çöz → yalnızca paylaşımın
  sürümündeki anahtar depoya yazılır → `…/ack` (100'lük gruplar).
  Çözülemeyen ya da bozuk paylaşım (kalıcı hata) da onaylanır; ağ
  hatasında hiçbiri onaylanmaz. Anahtar depoya yazılmadan onaylanmaz.

### 6. Tek cihaz uyarıları (araştırma §3.11)

- Çıkış onayında `paired && !other_paired_device` ise ek uyarı: eski
  birebir mesajlar kalıcı olarak okunamaz; önce başka cihaz bağlanabilir.
  Uyarı gerekmiyorsa çıkış önceki gibi sorusuz.
- İlk E2E açılışında bir kez bilgi kartı (gösterildiği E2E deposunda
  `e2e.bilgi.tek_cihaz` ile tutulur; çıkışta silindiği için yeni girişte
  yeniden gösterilir).
- Yeni girişte eski arşiv için "Eski mesajların bu cihazda okunamıyor"
  satırı; cihaz QR ile eşleşebiliyorsa "Bu cihazı diğer telefonunla bağla".

### 7. Paketler ve izin

| Paket | Sürüm | Yayıncı / lisans | Bakım | İzin | Platform |
|---|---|---|---|---|---|
| `qr` | 4.0.1 (tam sabit) | kevmoo.com (doğrulanmış), BSD-3 | Etkin (4.0.1: 2026-11) | Yok; saf Dart | Hepsi |
| `mobile_scanner` | 7.5.0 (tam sabit) | steenbakker.dev (doğrulanmış), BSD-3 | Etkin, sık sürüm (7.5.0: 2026-11-01) | Android `CAMERA` (+ ML Kit'ten `ACCESS_NETWORK_STATE`); iOS `NSCameraUsageDescription` | Android (CameraX + ML Kit), iOS (AVFoundation/Vision) |

- **ML Kit gömülü sürüm** (`dev.steenbakker.mobile_scanner.useUnbundled=false`,
  varsayılan; `android/gradle.properties`'te açıkça yazılı): model APK'nın
  içinde (+3–10 MB); Play Hizmetleri olmayan cihazlarda (Huawei) çalışır.
- **Kamera izni** yalnızca "Cihaz bağla" ekranı açılınca istenir; görüntü
  saklanmaz ve gönderilmez. Reddedilirse açıklama; iOS'ta "Ayarları aç"
  (`app-settings:`), Android'de `url_launcher` uygulama ayarlarını
  açamadığı için yol metinle anlatılır ve "Tekrar tara" sunulur.
  `android.hardware.camera` zorunlu değil.
- CI APK izin denetimi: `INTERNET`, konum ikilisi, `CAMERA`,
  `ACCESS_NETWORK_STATE`.

### Sapmalar ve açık konular

- **Tayfam-Api ADR-0018 §5 sapması:** ADR "yeni cihazın bu iş için
  ürettiği açık anahtar" der; istemci cihazın Signal kimlik anahtarını ve
  kendi cihazlar arası Signal oturumunu (PQXDH) kullanır (araştırma §2
  seçenek A; platform sahibi 2026-11-11). Sunucu değişmez; ADR-0018
  metnine not düşülmeli. Kendi bağlamamıza ya da HPKE'li bir sürüme
  geçilirse (seçenek B) QR biçimi `v2` olur.
- `ACCESS_NETWORK_STATE`: ML Kit'in `datatransport` bileşeni getirir.
  Kaldırılması ML Kit'in kendi gönderim kodunda `SecurityException`
  riskine yol açtığı için bırakıldı. ML Kit'in Google'a anonim kullanım
  ölçümü göndermesi platform sahibine sorulacak (gerekirse ZXing tabanlı
  tarayıcıya geçiş).
- Yenilemede boş kümeyle ilk deneme bir fazla istek demektir; sözleşme
  eşleştirilmiş cihaz listesini vermediği için bilinçli seçim.
