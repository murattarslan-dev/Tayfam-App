# ADR-0003: Gezinme iskeleti ve yönlendirme

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0002](0002-modul-yapisi.md); Notion: Proje Planı §4 Kullanıcı Akışı, Tasarım Standartları

## Bağlam

Kullanıcı birden çok tayfaya üye olabilir; asıl kullanıcı (kulüp üyesi)
çoğunlukla tek bir tayfayı kullanır. Notion'daki kullanıcı akışına göre
onaylı üye uygulamayı açınca doğrudan tayfasının ana sayfasını görür; linksiz
gelen kullanıcı "Tayfa kodum var" ve "Tayfa oluştur" seçeneklerini görür.
Tayfa modülleri tayfadan tayfaya açık ya da kapalıdır (ADR-0002); birebir
mesajlar ve bildirimler tayfadan bağımsızdır.

## Karar

### Tayfa merkezli, dört sabit sekme

- **Üst çubuk:** Aktif tayfanın adı. Dokununca alttan tayfa değiştirme
  paneli açılır: tayfalarım, kodla katıl, tayfa oluştur.
- **Alt sekmeler (sabit, sırasıyla):**
  1. **Tayfa:** aktif tayfanın ana sayfası; yaklaşan etkinlikler, son
     duyurular. Açık modüller (duyuru, etkinlik, soru-cevap, anket) bu
     sekmenin içinde kart ve alt gezinme olarak yer alır.
  2. **Sohbet:** iki bölüm: aktif tayfanın kanalları ve tüm birebir mesajlar.
  3. **Bildirimler:** tüm tayfalar için tek liste.
  4. **Profil:** profil, arkadaşlar ve referans kodu, oturumlar, ayarlar.
- Sekmeler modüllere bağlı değildir; tayfa değişince iskelet değişmez,
  yalnızca Tayfa sekmesinin içeriği değişir.
- Sekmelerde ikon ve etiket birlikte kullanılır; okunmamış rozeti yalnızca
  Sohbet ve Bildirimler'de, sayı olarak ve ekran okuyucu etiketiyle.
- **Tayfası olmayan kullanıcı:** Tayfa sekmesi karşılama ekranını gösterir
  ("Tayfa kodum var", "Tayfa oluştur"); diğer sekmeler çalışır.
- **Geniş ekran (web, tablet):** Aynı dört öğe solda dikey gezinme çubuğu
  (navigation rail) olarak gösterilir. Kırılım noktası tema ADR'siyle
  belirlenir.

### Yönlendirme

- Yönlendirme için **`go_router`** kullanılır (Flutter ekibinin paketi).
- Dört sekme `StatefulShellRoute` ile kurulur; her sekme kendi geçmişini ve
  kaydırma durumunu korur. Geri tuşu önce sekmenin kendi geçmişinde geri
  gider.
- Tayfaya bağlı adresler tayfa kimliğini taşır (`/t/<tayfaId>/…`); web'de
  adres çubuğu ve paylaşılan linkler buna göre çalışır. Ayrıntılı adres
  tablosu derin link işiyle birlikte yazılır.
- Her yönlendirmede oturum durumu kontrol edilir (giriş yok → giriş; kayıt
  bekliyor → kayıt; yeniden onay → onay). Bu kontrol yetki değildir; yetki
  sunucudadır (CLAUDE.md, kesin kural 5).
- Adresteki tayfa kimliği girdi kabul edilir: kullanıcının üye olmadığı bir
  tayfaya gelen adres, sunucunun cevabına göre hata ya da katılım ekranına
  döner; istemci içerik varsaymaz.
- Davet ve referans linkleri bu yönlendiriciden geçer ve CLAUDE.md kesin
  kural 9'a uyar (davet token'ı fragment'ta, hiçbir yere yazılmaz).

## Gerekçe

- Notion'daki "onaylı üye doğrudan tayfa ana sayfasını görür" akışını tek
  dokunuşla karşılıyor.
- Sabit iskelet öngörülebilir; modüle bağlı sekme, kapalı modüllü tayfaya
  geçildiğinde kaybolurdu (ui-ux-pro-max: `bottom-nav-limit`,
  `back-behavior`, `nav-hierarchy`).
- `go_router` web adresleri, derin linkler ve sekme başına geçmiş için
  standart çözüm; ek durum yönetimi kütüphanesi gerektirmiyor (ADR-0001).

## Sonuçlar

- Bağımlılık: `go_router`.
- Tayfa geçişi aktif tayfa provider'ını değiştirir; tayfaya bağlı durum
  `autoDispose` ile bırakılır (ADR-0001).
- Keşfet ve herkese açık tayfa sayfası ayrı bir ürün kararı olarak
  konuşuluyor; iskelete nasıl gireceği o kararla bu ADR'ye eklenir.

## Değerlendirilen alternatifler

- **Genel bakış merkezli** (Tayfalar / Mesajlar / Bildirimler / Profil,
  tayfanın içinde ayrı sekmeler): çok tayfalı kullanıcı için düzenli, ama
  asıl kullanıcıya her açılışta fazladan dokunuş ve Notion akışıyla çelişki.
- **Modüllere bağlı sekmeler** (ayrı Etkinlikler sekmesi): kapalı modülde
  iskelet değişiyor.
- **Navigator 2.0'ı elle kullanmak:** daha çok kod, aynı sonuç.
