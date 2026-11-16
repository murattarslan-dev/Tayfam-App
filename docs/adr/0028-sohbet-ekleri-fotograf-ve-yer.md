# ADR-0028: Sohbet ekleri — fotoğraf ve yer (istemci)

- **Durum:** Önerildi (platform sahibinin onayına; ürün kararları
  2026-11-15/16'da verildi)
- **Tarih:** 2026-11-16
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0004](0004-tema-ve-bilesen-dili.md),
  [ADR-0005](0005-api-istemcisi.md),
  [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md),
  [ADR-0007](0007-websocket.md), [ADR-0010](0010-signal-kutuphanesi.md),
  [ADR-0015](0015-etkinlik-ve-duyuru-modulleri.md) §4–§5,
  [ADR-0018](0018-faz1-kalan-moduller.md) §8–§9,
  [ADR-0020](0020-birebir-uctan-uca-sifreleme-istemci.md),
  [ADR-0021](0021-fotograf-yukleme-ve-goruntuleme.md); Tayfam-Api
  ADR-0031 (sözleşme 4cec101, PR #214), ADR-0008, ADR-0018; Notion "Faz 2
  (v2) — Medya ve Sosyal" §1, §7a, §9; tasarım
  [`docs/tasarim/28-sohbet-fotograf-yer/`](../tasarim/28-sohbet-fotograf-yer/README.md);
  issue #194

## Bağlam

Faz 2'de kanal ve birebir mesajlarda fotoğraf ve haritadan seçilmiş yer
gönderilebilir. Sunucu tarafı Tayfam-Api ADR-0031 ile birleşti:

- Kanal mesajı `kind` taşır (`text` / `photo` / `place`);
  `photo_upload_id` kanalın kitlesine görünen `chat_photo` yüklemesidir,
  `place` `{latitude, longitude, name?}`'dir. Alt yazı yoktur.
- Birebir mesajın türü sunucuda yoktur: metin, fotoğraf ya da yer zarfın
  içindedir. Sunucu yalnızca şifreli ekin dosya kimliğini
  (`attachment_upload_id`) bilir; ek `dm_attachment` amaçlı, tek `blob`
  (`application/octet-stream`, 1 B – 10 MiB) yüklemesidir ve sunucu onu
  hiç okumaz.
- Kanal mesajı şikâyet edilebilir (`target_type: channel_message`);
  birebir mesaj şikâyetinde kanıt fotoğrafı (`evidence_upload_id`,
  `report_evidence`) şikâyet edenin cihazından yüklenir.

Platform sahibinin kararları (issue #194, Notion §1 ve §9): birebir
fotoğrafı istemci temizlenmiş görüntüden CSPRNG anahtarıyla AES-256-GCM
ile (standart ya da resmi kütüphane; kendi kripto yok) şifreler, anahtar
ve özet Signal zarfının içinde gider, alıcı özeti doğrular, çözer ve
yalnızca bellekte gösterir; yer mevcut OSM seçicisiyle seçilir, "Bulunduğum
yer" düğmesi haritayı cihaz konumuna taşır ve konum izni yalnızca bu
düğmeye basınca istenir; kullanıcı noktayı görüp onaylamadan gönderilmez;
canlı konum yok; koordinat log'a girmez; yönetici ve moderatör başkasının
içeriğini şikâyet etmez, gizler.

## Karar

### 1. Kanal mesajı türleri

- `ChannelMessage.kind`'e göre çizilir: `text` metin balonu, `photo`
  `SohbetFotografi` (link `POST /v1/media/urls`'ten, mevcut
  `MedyaOnbellegi`; ADR-0021 §5), `place` `SohbetYerKarti`. `unknown`
  ya da beklenen alanı eksik/aralık dışı mesaj "Bu mesaj bu sürümde
  gösterilemiyor" metniyle gösterilir (sunucudan gelen veri girdidir).
- Yer değerleri istemcide de denetlenir: enlem −90..90, boylam
  −180..180, sonlu; ad 1–120 karakter, kontrol karakteri yok. Geçersizse
  gösterilmez.
- **Gönderim** çevrimdışı kuyruktan (ADR-0006) aynı `KanalMesajIsi` ile:
  iş türü (`metin`, `fotograf`, `yer`) taşır. Fotoğrafta iş önce
  hazırlanmış görüntüyü `chat_photo` olarak (tayfalı) yükler, sonra
  mesajı gönderir. Yükleme ve mesaj için ayrı, işle birlikte bir kez
  üretilen iki `client_request_id` vardır; her denemede aynısı gider
  (yükleme kimliği sunucuda `pending` yüklemeyi aynı linklerle döner,
  hazır yükleme bir kez alınır ve iş içinde bellekte tutulur). Mesaj
  WebSocket açıksa `send` çerçevesiyle (`kind`, `photo_upload_id`,
  `place`), değilse aynı kimlikle REST'ten gider (ADR-0007).
  `upload-not-found` / `upload-not-ready` / `upload-in-use` kalıcı
  hatadır; kullanıcı "Tekrar dene" ya da "Sil" seçer.
- Hazırlanmış görüntü (ve yerel önizlemesi) yalnızca bellektedir; iş
  bitince ya da silinince bırakılır. Gönderilen fotoğrafın baytları
  `MedyaOnbellegi.yerelEkle` ile önbelleğe konur (yeniden indirilmez).

### 2. Birebir ek: şifreleme biçimi

`lib/core/e2e/ek/` (hassas alan, ADR-0010):

```
anahtar = 32 bayt, Random.secure()            (her ek için yeni)
nonce   = 12 bayt, Random.secure()
aad     = "tayfam/ek/v1"
blob    = 0x01 ‖ nonce ‖ AES-256-GCM(anahtar, nonce, jpeg, aad) ‖ etiket(16)
özet    = SHA-256(blob)
```

- `jpeg`, ADR-0021'in hazırlama hattından geçmiş **tam** varyanttır
  (EXIF/GPS silinmiş, en uzun kenar 1600, `jpegTemizle` denetimi).
- AES-256-GCM şifreleme **libsignal'in** `Aes256GcmEncryption`'ıyla,
  çözme mevcut `Aes256GcmDecryption` köprüsüyle yapılır (Signal
  motoruna `aes256GcmSifrele` eklendi; ADR-0010'daki durumsuz Kotlin
  köprüsü). SHA-256 Dart ekibinin `crypto` paketiyle (zaten bağımlılık).
  İstemcide yalnızca biçim vardır (kesin kural 4).
- Özet şifreli blob üzerindedir (Signal'in ek modeli): alıcı indirdiğini
  **çözmeden önce** zarftaki özetle sabit zamanlı karşılaştırır; tutmazsa
  hiç çözmez. GCM etiketi ayrıca içeriği doğrular; etiket tutmazsa düz
  metin dışarı çıkmaz (köprüde tampon sıfırlanır).
- Sınır: blob 10 MiB'ı aşamaz (sözleşme); `1 + 12 + jpeg + 16` hesaplanır,
  aşarsa gönderilmez.

### 3. Birebir zarf içeriği (sürüm 1)

ADR-0020'deki `{v:1, t:"metin", govde}` biçimine iki tür eklenir (UTF-8
JSON, 160 bayt dolgu aynı):

```
{v:1, t:"foto", ek:{id, anahtar, ozet, boyut, en, boy}}
{v:1, t:"yer",  enlem, boylam, ad?}
```

- `id`: `attachment_upload_id` (UUID). `anahtar`, `ozet`: dolgusuz
  base64url (32 bayt). `boyut`: blob'un bayt sayısı (1–10 MiB; indirme
  tam bu boyutta beklenir). `en`, `boy`: görüntünün ölçüleri (1–1600;
  yer tutucunun oranı).
- Ayrıştırma katıdır: bilinmeyen `t`, eksik ya da aralık dışı alan →
  zarf "çözülemedi" sayılır (ADR-0020'deki satır). Mesajın
  `attachment_upload_id`'si zarftaki `id`'den farklıysa fotoğraf
  "doğrulanamadı" gösterilir.
- Zarfta önizleme (küçük resim) **yoktur**: zarf ve arşiv kaydı küçük
  kalır; alıcı tam görüntüyü indirene kadar kilitli yer tutucu görür.
- Geçmiş arşivi (ADR-0020 §2) aynı alanları taşır
  (`{v:1, gonderen, created_at, t, …}`); eşleştirilmiş yeni cihaz eki
  arşivdeki anahtarla açar. Arşiv kaydı 32 KiB sınırının çok altındadır.
- Eski sürüm istemci yeni türleri "Bir mesaj çözülemedi" olarak görür
  (dahili test sürümü; geriye uyum katmanı yok).

### 4. Birebir gönderim ve gösterim

- **Gönderim** (`BirebirMesajIsi`, kuyruk grubu aynı): fotoğrafta iş
  hazırlanmış görüntüyü bir kez şifreler (anahtar ve blob iş boyunca
  bellekte; her denemede aynı blob ve aynı yükleme kimliği), `dm_attachment`
  olarak yükler (`variants: [blob]`, tamamlama `{width: 0, height: 0}`),
  sonra zarfı `attachment_upload_id` ile gönderir (ADR-0020 gönderim
  adımları aynen; `e2e-devices-changed` tekrarında aynı ek).
  Gönderilen içerik belleğe ve yayın akışına (arşiv) girer; gönderenin
  kendi görüntüsü çözülmüş görüntü önbelleğine konur.
- **Gösterim:** `EkCozucu` → `POST /v1/media/urls` (yalnızca `full_url`,
  `application/octet-stream`) → imzalı linkten tam `boyut` bayt
  (`ImzaliIndirici`; token gönderilmez, yönlendirme izlenmez) → özet →
  çözme → görüntü denetimi (metadata'sız tek JPEG, en uzun kenar en çok
  1600, ölçüler zarftaki `en`/`boy` ile aynı; aksi halde bitmap'e hiç
  açılmaz) → en çok 1600 piksele sınırlı çözmeyle gösterim (devasa piksel
  ölçülü görüntüyle bellek tüketmeye karşı). Sonuç türleri: `hazir`, `baglanti` (tekrar
  denenebilir), `dogrulanamadi` (özet, etiket, boyut ya da kimlik
  tutmadı; tekrar denenmez), `gorulemez`.
- **Bellek:** çözülmüş görüntüler `EkOnbellegi`'nde (en çok 32 MiB, en
  eski kullanılan atılır) ve oturum değişince boşalır; Flutter'ın global
  görüntü önbelleği (çözülmüş bitmap'ler, `imageCache` ve canlı
  görüntüler) de oturum değişince temizlenir. Zarftaki ek kimliği mesajın
  `attachment_upload_id`'siyle tutmazsa ek indirilmez, çözülmez ve
  şikâyete kanıt olarak eklenmez. Anahtar, blob ve
  çözülmüş görüntü **diske yazılmaz**, log'a ve hata mesajına girmez;
  `toString`'ler içerik yazmaz. Tam ekran görüntüleyicide kaydet/paylaş
  yoktur.
- Web geliştirme derlemesi ve iOS (E2E yok, ADR-0020): ⊕ gösterilmez;
  yazma alanının yerinde mevcut "bu cihazda henüz açık değil" satırı.

### 5. Yer seçici ve "Bulunduğum yer"

- OSM seçicisi (`HaritaSeciciEkrani`, `OsmHarita`, `HaritaSecimi`) ve
  tek seferlik konum servisi (`KonumServisi`) etkinlikten
  `lib/core/harita/` ve `lib/core/konum/`'a taşındı: iki özellik
  (etkinlik, sohbet/birebir) aynı seçiciyi kullanır; özellikler birbirini
  import etmez (ADR-0002). Davranış etkinlikte aynıdır.
- Seçiciye isteğe bağlı "Bulunduğum yer" hap düğmesi eklendi; yalnızca
  sohbet açar (etkinlik seçicisinde ADR-0015 §4'teki "cihaz konumu
  istenmez" kuralı aynen geçerlidir). Düğmeye basınca izin
  ("uygulamayı kullanırken") istenir ve konum **bir kez** okunur
  (`tekSeferlikKonum`; konum akışı, arka plan ve son bilinen konum yok);
  harita oraya taşınır ve iğne bırakılır. Yaklaşık konum kabul edilir
  (yalnızca harita taşınır). Okunan konum seçicinin durumundan başka
  hiçbir yerde tutulmaz; kullanıcı onaylamazsa hiçbir yere gitmez.
- İzin reddi, kapalı servis ve okunamayan konum seçicide metinle
  gösterilir ("Ayarları aç" / "Konum ayarları"); seçici elle çalışmaya
  devam eder.
- Seçimden sonra "Yeri gönder" onay sayfası: etkileşimsiz harita, isteğe
  bağlı ad (arama sonucunun adı öneri; 1–120), "Gönder" / "Vazgeç".
  Gönderilen nokta kullanıcının gördüğü noktadır (Tayfam-Api ADR-0008:
  içerik).
- Koordinat ve yer adı log'a, hata mesajına, `toString`'e ve analitiğe
  girmez; yalnızca istek gövdesinde, bellekteki mesajda ve ekranda.
- Harita karoları (seçici, yer kartı, tam ekran harita) OpenStreetMap
  karo sunucusundan istenir; istek bakılan bölgeyi (karo koordinatı) OSM'ye
  bildirir. Bu, ADR-0015 §4'te etkinlik haritası için kabul edilen
  bedelin aynısıdır; disk önbelleği kapalıdır. Sohbette bir yer kartı
  ekranda göründüğünde karoları alıcının cihazı ister.
- Yeni platform izni yoktur: konum izinleri varış bildirimi için zaten
  manifestte (ADR-0015 §5); yalnızca isteme anı sohbette de var.

### 6. Şikâyet

- **Kanal mesajı:** başkasının silinmemiş mesajında "Şikâyet et"
  (`POST /v1/tayfas/{id}/reports`, `channel_message`); yönetici ve
  moderatöre bu satır gösterilmez, "Mesajı sil" (gizle) gösterilir.
  Arayüzdeki bu ayrım kolaylıktır; yetki sunucudadır (kesin kural 5).
- **Moderasyon kuyruğu:** `channel_message` etiketi; "İçeriği aç"
  `ModerationReport.channel_id` ile kanalı açar; "İçeriği kaldır" kanal
  mesajını moderatör olarak gizler (`DELETE …/messages/{id}`), "Geri al"
  `…/restoration`. `channel_id` yoksa (kanalı okuyamayan moderatör) bu
  iki eylem gösterilmez; sunucu zaten izin vermez.
- **Birebir fotoğraf:** şikâyet sayfası çözülmüş fotoğrafı önizlemede
  gösterir; gönderince fotoğraf ADR-0021 hattından yeniden hazırlanıp
  `report_evidence` (tayfasız, iki varyant) olarak yüklenir ve
  `evidence_upload_id` ile platforma gider. Yükleme kimliği form
  açıkken bir kez üretilir; hazır yükleme tekrar denemede yeniden
  yüklenmez. **Birebir yer:** `evidence_text` yerin adı ve
  koordinatıdır (ekranda gösterilir; kullanıcı bilerek paylaşır).

## Gerekçe

- Kanal fotoğrafı mevcut görüntü hattını ve bellek önbelleğini kullanır;
  yeni bir disk ya da ağ yolu açmaz.
- Şifrelemenin libsignal'den gelmesi yeni kripto paketi gerektirmez ve
  ADR-0010'un "Signal motoru simetrik yapı taşlarını verir" modeline
  uyar; çözme tarafı KVKK dışa aktarmasında zaten aynı köprüdedir.
- Özet şifreli blob üzerinde olduğu için sunucu ya da depo bozuk/
  değiştirilmiş veriyi çözdüremez; istemci yalnızca doğrulanmış baytı
  işler.
- Seçiciyi `core/`'a taşımak iki özelliğin birbirine bağlanmasını önler
  ve tek seçici (tek kural seti: OSM atfı, karo önbelleği kapalı) kalır.

## Sonuçlar

- Yeni paket yok. `crypto` (dart.dev) doğrudan bağımlılıktı; SHA-256
  için kullanılır.
- Kotlin köprüsüne `aes256GcmSifrele`; JVM birim testi.
- `SignalMotoru` arayüzü bir yöntem kazanır; `DesteklenmeyenSignalMotoru`
  `UnsupportedError` verir.
- `CozulmusBirebirMesaj.metin` yerine `icerik` (`MetinIcerigi`,
  `FotografIcerigi`, `YerIcerigi`); metin isteyen yerler `metin`
  yardımcısını kullanır.
- `MedyaLinki.onizleme` şifreli ekte `null`'dır.
- Testler: ek şifreleme/çözme (doğru anahtar, yanlış özet reddi, yanlış
  anahtar/etiket, boyut), zarf ve arşiv ayrıştırma (geçersiz alanlar),
  kuyruk işleri (aynı kimlikler), seçici ("Bulunduğum yer" yalnızca
  düğmede izin ister), ekranlar açık/koyu ve 2× yazıda.

## Değerlendirilen alternatifler

- **`cryptography` / `pointycastle` gibi Dart paketiyle AES-GCM:** yeni
  bağımlılık; libsignal köprüsü zaten var.
- **`javax.crypto` (`AES/GCM/NoPadding`):** standart, ama ikinci bir kripto
  yolu olurdu; libsignal ile tek yapı taşı seti tercih edildi.
- **Zarfta küçük önizleme:** alıcı hemen bulanık görüntü görürdü, ama her
  cihaz zarfı ve arşiv kaydı büyürdü; WebSocket zarf teslimi 64 KB
  çerçeveyle sınırlı. Sonraya bırakıldı (açık soru).
- **Yer seçicide açılışta cihaz konumu:** daha hızlı, ama izin
  istemeden önce kullanıcı eylemi şartını (karar) bozar.
- **Kanal fotoğrafını mesajdan ayrı, önceden yükleyip sonra göndermek
  (form gibi):** kuyruk dışı bir adım olurdu; tek iş olarak kuyrukta
  tutmak çevrimdışı davranışı ve "Tekrar dene"yi tek yerde toplar.
