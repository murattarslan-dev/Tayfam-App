# ADR-0014: Tayfalarım, aktif tayfa, kodla katılım ve tayfa oluşturma

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-10
- **Karar veren:** Murat Arslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), [ADR-0003](0003-gezinme-iskeleti.md), [ADR-0004](0004-tema-ve-bilesen-dili.md), [ADR-0005](0005-api-istemcisi.md), [ADR-0006](0006-onbellek-ve-cevrimdisi-kuyruk.md); Notion: Proje Planı §2, §4 (madde 2–5), §7

## Bağlam

Gezinme iskeleti (ADR-0003) aktif tayfayı, tayfa değiştirme panelini ve
karşılama ekranını ("Tayfa kodum var", "Tayfa oluştur") kurdu, ama veri
yok: aktif tayfa hiç dolmuyor, tayfa adı `null`. Sözleşmede ilgili uçlar:

| Uç | Ne yapar |
| --- | --- |
| `GET /v1/tayfas` | Etkin üyelikler ve bekleyen istekler (en yeniden eskiye, sayfalı) |
| `GET /v1/tayfas/{id}` | Tam görünüm |
| `POST /v1/tayfa-joins` | Kodla katılım; açık tayfada hemen etkin, onaylıda bekler |
| `POST /v1/tayfas` | Oluşturma (`client_request_id`; kullanıcı başına 24 saatte 1, IP başına saatte 1) |
| `DELETE /v1/tayfas/{id}/membership` | Ayrılma ya da bekleyen isteği geri çekme |

## Karar

### 1. Tayfalarım ve aktif tayfa

- `tayfalarimProvider` (`AsyncNotifier`, oturuma bağlı, `keepAlive`)
  `GET /v1/tayfas`'ın bütün sayfalarını okur. Uygulama ön plana dönünce ve
  katılım, oluşturma veya ayrılmadan sonra yenilenir.
- **Son kullanılan tayfa hatırlanır** (platform sahibi, 2026-11-10):
  - Yalnızca tayfa kimliği, kullanıcı ayarı olarak güvenli depoda tutulur
    (ADR-0006'nın "kullanıcı ayarları" istisnası; içerik değil).
  - Oturum kapanınca silinir.
  - Açılışta bu kimlik etkin üyelikler arasında yoksa (çıkarılma, ayrılma,
    tayfa silinmesi) sunucunun sırasındaki ilk etkin tayfa seçilir. Etkin
    tayfa yoksa karşılama ekranı açılır.
- Tayfa adı, rol ve modüller `tayfalarimProvider`'dan gelir. Tayfa ana
  sayfası açılınca `GET /v1/tayfas/{id}` ile tazelenir.
- Adresteki `/t/<id>` aktif tayfayla eşleşmezse ve kimlik etkin
  üyeliklerdeyse aktif tayfa adrese göre değişir. Değilse karşılamaya
  dönülür. Erişim kararını sunucu verir.

### 2. Bekleyen katılım istekleri

- Tayfa değiştirme panelinde **"Onay bekliyor"** etiketiyle listelenir.
  Dokununca isteği geri çekme onayı açılır
  (`DELETE /v1/tayfas/{id}/membership`).
- Etkin tayfası olmayan kullanıcıya karşılama ekranında bir bilgi kartı
  gösterilir: "Katılma isteğin onay bekliyor".
- Bekleyen tayfanın içeriği gösterilmez; yalnızca adı görünür.

### 3. Kodla katılım

- Karşılama ekranındaki ve paneldeki "Tayfa kodum var" alttan bir sayfa
  açar. Bu sayfada tek bir kod alanı vardır: büyük/küçük harf duyarsız,
  baştaki ve sondaki boşluklar atılır, en çok 32 karakter.
- Sonuç:
  - Etkin üyelik → tayfa aktif olur ve ana sayfası açılır.
  - Bekleyen üyelik → "İsteğin gönderildi" bilgisi; panelde bekleyen olarak
    görünür.
  - `invalid-join-code` → tek ve genel bir metin. Kod yanlış, yenilenmiş
    ya da banlı olunan tayfa birbirinden ayırt edilmez, çünkü sunucu da
    ayırt etmiyor.
  - Deneme sınırı hatası → bekleme metni.

### 4. Tayfa oluşturma: adım adım sihirbaz

Platform sahibi tek ekran yerine sihirbazı seçti (2026-11-10). Adımlar:

1. **Ad:** 3–50 karakter (boşluklar atıldıktan sonra).
2. **İlgi alanları:** 7 etkinlik türü, çoklu seçim, isteğe bağlı. Çipler
   etkinlik türü renkleriyle.
3. **Katılım ve açıklama:** onaylı (varsayılan) ya da açık. Her seçeneğin
   altında ne anlama geldiğini söyleyen bir cümle var. Açıklama isteğe
   bağlı, en çok 500 karakter.

Sihirbazın kuralları:

- Geri ve ileri gezinmede girilenler korunur.
- `client_request_id` sihirbaz açılınca bir kez üretilir. Aynı oluşturma
  tekrar gönderilirse aynı id kullanılır.
- `tayfa-create-limit` ve `rate-limited` → anlaşılır bekleme metni.
- Başarıda yeni tayfa aktif olur, ana sayfası açılır ve **davet kısayolu**
  gösterilir (madde 5). Bütün modüller açık başlar (sunucu).

### 5. Paylaşım

- Tayfa kodu sistem paylaşım menüsüyle paylaşılır. Yeni paket:
  **`share_plus`** (yayıncı fluttercommunity.dev, izin gerektirmez).
  Kod ayrıca panoya da kopyalanabilir.
- Kod yalnızca yöneticiye döner (`join_code`); paylaşım düğmesi yalnızca
  kod varsa görünür. Bu bir kolaylıktır, yetki kararı değildir (kesin
  kural 5).
- Paylaşım metni: tayfa adı, kod ve tayfam.app bağlantısı. Davet linki
  (`/davet#<token>`) derin link işiyle gelir.

### 6. Tayfa durumu

Ana sayfanın mor üst bölümünde sade bir bilgi şeridi gösterilir:

| Durum | Gösterilen |
| --- | --- |
| `warned` | Hareketsiz; 7 gün içinde etkinlik olmazsa arşivlenir |
| `archived` | Salt okunur |
| `suspended_at` dolu | Askıya alındı; sebep yok |
| `deletion_at` dolu | Silinme zamanı |

Düğmeler sunucunun hatalarına göre davranır; istemci durumdan yetki
çıkarmaz.

## Gerekçe

- Son tayfayı hatırlamak, birden çok tayfası olan kullanıcının her açılışta
  tayfa değiştirmesini önler. Saklanan tek şey bir kimliktir ve oturumla
  silinir.
- Bekleyen istekleri panelde göstermek, isteğin akıbetini kullanıcıya
  görünür kılar ve geri çekmeyi mümkün kılar.

## Sonuçlar

- Yeni paket: `share_plus` (kesin kural 8; PR'da gerekçe).
- Tayfa ana sayfasındaki etkinlik ve duyuru bölümleri kendi modül
  işleriyle gelir; bu iş üst bölümü ve tayfa verisini bağlar.
- Ayrılma, üye listesi ve yönetici ayarları ayrı işlerdir.

## Değerlendirilen alternatifler

- **Aktif tayfayı hatırlamamak:** diske hiçbir şey yazılmaz, ama her
  açılışta en son katılınan tayfa gelir.
- **Tek ekranlı oluşturma formu:** daha kısa; platform sahibi daha
  yönlendirici olan sihirbazı seçti.
- **Yalnızca panoya kopyalama:** paket gerektirmez, ama WhatsApp'a
  paylaşım bir adım uzar.

## Notlar

- **2026-11-10 (PR #31):** Tayfa listesi ilk kez okunurken kök ve
  karşılama adresinde açılış ekranı gösterilir (karşılama boş görünüp
  sonra tayfaya atlamasın diye). Üye olunmayan `/t/<id>` adresi karşılamaya
  döner; ADR-0003'teki "katılım ekranına döner" ifadesinin yerine budur.
  Kodla katılım ayrı bir rota değil, alttan açılan sayfadır. İlgi alanı
  çiplerinin tür başına rengi ve ikonu için ADR-0004 Notlar'a bakın.

