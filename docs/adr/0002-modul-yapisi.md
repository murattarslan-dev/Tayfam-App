# ADR-0002: Modül yapısı, klasör düzeni ve modül kayıtları

- **Durum:** Kabul edildi
- **Tarih:** 2026-11-09
- **Karar veren:** Murat Tarslan
- **İlgili:** [ADR-0001](0001-durum-yonetimi-riverpod.md), Tayfam-Api ADR-0003 (servis sınırları ve depguard)

## Bağlam

Sunucu sözleşmesinde iki ayrı kavram var:

- **Tayfa modülleri** (`Module`): `announcements`, `events`, `qa`, `polls`.
  Tayfa başına açılıp kapanır; kapalı modülün uçları `module-disabled`
  döner. Sohbet modül değildir, her tayfada vardır.
- **Etkinlik türleri** (`EventType`, tayfanın ilgi alanlarıyla aynı
  değerler): `convoy`, `camp`, `hike`, `fishing`, `gaming`, `sports`,
  `general`. Her türün kendi alanları ve aracı vardır (rota, malzeme listesi,
  yoklama, av günlüğü…).

Kodu birbirinden habersiz alt oturumlar yazacak; özellikler arasındaki
sınırlar baştan net ve otomatik denetlenebilir olmalı.

## Karar

### Tek paket, özellik klasörleri

Uygulama tek bir Flutter paketidir (Melos / çoklu paket yok):

```
lib/
  main.dart
  core/          ortak altyapı: oturum, API istemcisi, realtime, çevrimdışı
                 kuyruk, güvenli depo, tema, çeviri, ortak bileşenler
  shell/         uygulama kabuğu: ana gezinme, tayfa geçişi, derin linkler,
                 modül kayıtlarının toplandığı yer
  features/
    <özellik>/
      <özellik>.dart   özelliğin tek dışa açık dosyası
      data/            API çağrıları ve dönüştürme
      application/     Riverpod notifier'ları ve servisleri (ADR-0001)
      presentation/    ekranlar ve widget'lar
```

Başlangıç özellikleri: `tayfa`, `duyuru`, `etkinlik`, `soru_cevap`, `anket`,
`sohbet`, `bildirim`, `profil`, `hesap`. Klasör ve dosya adları ASCII,
`snake_case`.

### Import kuralları

1. `core/` hiçbir `features/` veya `shell/` dosyasını import edemez.
2. Bir özellik yalnızca `core/`'u ve başka bir özelliğin
   `<özellik>/<özellik>.dart` dosyasını import edebilir; başka bir özelliğin
   `data/`, `application/` veya `presentation/` klasörüne erişemez.
3. `shell/` özellikleri yalnızca dışa açık dosyalarından kullanır.
4. Döngüsel özellik bağımlılığı yasaktır; iki özelliğin ortak ihtiyacı
   `core/`'a taşınır.

Bu kurallar CI'da bir import kontrol betiğiyle zorlanır (Tayfam-Api'deki
depguard'ın karşılığı). Betik CI kurulumuyla birlikte eklenir; o zamana
kadar inceleme bu ADR'ye göre yapılır.

### Tayfa modül kaydı

- Her tayfa modülü (`announcements`, `events`, `qa`, `polls`) `core/`'daki
  `TayfaModule` arayüzünü uygular: sunucudaki modül anahtarı, rotaları, tayfa
  ana sayfası kartı ve gezinme girişi.
- Kayıt `shell/`'de, koddaki sabit bir listedir; çalışma zamanında dışarıdan
  modül yüklenmez.
- Bir modülün bir tayfada görünüp görünmeyeceğine **sunucudan gelen
  `modules` alanı** karar verir. İstemci kapalı modülü gizler, ama yetki
  sunucudadır (CLAUDE.md, kesin kural 5): `module-disabled` cevabı her
  zaman ele alınır.
- Sohbet ve tayfa yönetimi modül kaydına girmez; her tayfada sabittir.
- Sunucunun bilmediğimiz bir modül anahtarı göndermesi hata değildir; o
  anahtar yok sayılır.

### Etkinlik türü kaydı

- `features/etkinlik/turler/<tür>/` altında her tür, etkinlik
  özelliğindeki `EtkinlikTuru` arayüzünü uygular: `EventType` değeri, türe
  özel form alanları, detay ekranındaki araç bölümü ve ikon.
- Yeni bir tür eklemek etkinlik çekirdeğine dokunmayı gerektirmez; yalnızca
  türün klasörü ve kayıt listesine bir satır eklenir.
- Bilinmeyen tür, `general` gibi sade etkinlik olarak gösterilir.

### Testler

- Testler `test/` altında `lib/` ile aynı yapıyı izler
  (`test/features/<özellik>/…`); CI ileride yalnızca değişen özelliğin
  testlerini çalıştırabilir.

## Gerekçe

- Tek paket; tek `pubspec`, tek sürüm, hızlı CI ve tek kişilik projede düşük
  bakım yükü demek.
- Ayrı paketlerin ana kazancı olan derleyicinin zorladığı sınırlar, import
  kontrol betiğiyle büyük ölçüde sağlanıyor.
- Ayrı paketler mağaza güncellemesi ihtiyacını azaltmaz: hepsi tek
  uygulamada derlenir. Mağazasız değişiklik sunucu tarafı yapılandırmayla ve
  web sürümüyle yapılır; eski sürümleri devre dışı bırakmak için en düşük
  sürüm kontrolü Tayfam-Api'de iş olarak açıldı (issue #114).
- İki ayrı kayıt, sözleşmedeki iki ayrı kavramı (açılıp kapanan modül /
  etkinlik türü) birebir yansıtıyor.

## Sonuçlar

- Bir modül ileride başka bir uygulamada kullanılmak istenirse, sınırlar
  temiz olduğu için ayrı pakete taşınabilir; bu yeni bir ADR gerektirir.
- Import kontrol betiği CI'ın zorunlu kontrollerinden biri olur.
- `core/` büyüme eğilimindedir; yalnızca birden çok özelliğin gerçekten
  paylaştığı kod oraya girer.

## Değerlendirilen alternatifler

- **Melos ile özellik başına paket:** Sınırları derleyici zorlar, testler
  paket bazında koşar. Ama 15'ten fazla `pubspec`, sürüm uyumu ve daha yavaş
  CI; mağaza güncellemesinde bir kazancı yok.
- **Katman bazlı klasörler** (`lib/data`, `lib/ui` …): Özellikler arası
  sınır çizilemiyor; modül kaydına uymuyor.
- **Kod itme (Shorebird vb.) ile mağazasız güncelleme:** Uygulamaya dışarıdan
  kod indiren bir kanal açar; ele geçirilirse tüm kullanıcılara zararlı kod
  gider. Tedarik zinciri koruması kurulmadan değerlendirilmez (Tayfam-Api
  ADR-0011).
