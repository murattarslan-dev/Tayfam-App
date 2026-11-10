// Kural kataloğu ve bulgu modeli.
//
// Her kural, dayandığı karar maddesiyle (ADR veya CLAUDE.md) birlikte
// tanımlanır; çıktıdaki her bulgu bu dayanağı gösterir.

/// Bir bulgunun önemi. [hata] CI'ı kırar, [uyari] yalnızca raporlanır.
enum Seviye { hata, uyari }

/// Bir kuralın adı, dayanağı ve kısa açıklaması.
final class KuralTanimi {
  const KuralTanimi({
    required this.ad,
    required this.dayanak,
    required this.aciklama,
    this.seviye = Seviye.hata,
  });

  /// İstisna yorumunda da kullanılan kısa ad (ör. `sabit-renk`).
  final String ad;

  /// Kuralın dayandığı karar maddesi.
  final String dayanak;

  /// Kuralın ne denetlediği.
  final String aciklama;

  /// Bu kuralın bulgularının seviyesi.
  final Seviye seviye;
}

/// Bir kural ihlali.
final class Bulgu {
  const Bulgu({
    required this.kural,
    required this.yol,
    required this.satir,
    required this.mesaj,
    this.sutun = 1,
  });

  final KuralTanimi kural;

  /// Repo köküne göre dosya yolu (`/` ayraçlı).
  final String yol;

  /// 1'den başlayan satır.
  final int satir;

  /// 1'den başlayan sütun.
  final int sutun;

  final String mesaj;

  Seviye get seviye => kural.seviye;

  /// Tek satırlık, insan için özet.
  String get ozet =>
      '$yol:$satir:$sutun: [${kural.ad}] $mesaj (Dayanak: ${kural.dayanak})';
}

/// Kural kataloğu.
abstract final class Kurallar {
  static const importSiniri = KuralTanimi(
    ad: 'import-siniri',
    dayanak: 'ADR-0002 "Import kuralları" 1–3; CLAUDE.md "Klasör yapısı"',
    aciklama:
        'core/ shell/ ve features/ import etmez; bir özellik başka bir '
        "özelliğin yalnızca <özellik>.dart'ını import eder; özellikler "
        "shell/'i ve kök dosyaları import etmez.",
  );

  static const importDongusu = KuralTanimi(
    ad: 'import-dongusu',
    dayanak: 'ADR-0002 "Import kuralları" 4',
    aciklama: 'Özellikler arasında döngüsel bağımlılık yoktur.',
  );

  static const ozellikDisaAcikDosya = KuralTanimi(
    ad: 'ozellik-disa-acik-dosya',
    dayanak: 'ADR-0002 "Tek paket, özellik klasörleri"',
    aciklama: "Her lib/features/<özellik>/ klasöründe <özellik>.dart vardır.",
  );

  static const dosyaAdi = KuralTanimi(
    ad: 'dosya-adi',
    dayanak: 'ADR-0002 "Tek paket, özellik klasörleri"',
    aciklama: 'lib/ altındaki klasör ve dosya adları ASCII snake_case.',
  );

  static const apiTekIstemci = KuralTanimi(
    ad: 'api-tek-istemci',
    dayanak: 'ADR-0005 §2; ADR-0007; CLAUDE.md kesin kural 1',
    aciklama:
        "HTTP yalnızca lib/core/api/'de (package:http, HttpClient), "
        "WebSocket yalnızca lib/core/realtime/'da kurulur.",
  );

  static const elleUc = KuralTanimi(
    ad: 'elle-uc',
    dayanak: 'CLAUDE.md kesin kural 1; ADR-0005 §1',
    aciklama:
        'API yolu (/v1/…) yalnızca üretilmiş kodda (lib/core/api/gen/) '
        "ve realtime bağlantısında (lib/core/realtime/) yazılır.",
  );

  static const elleModel = KuralTanimi(
    ad: 'elle-model',
    dayanak: 'ADR-0005 §1',
    aciklama:
        'fromJson/toJson yalnızca üretilmiş modellerde tanımlanır; '
        "JSON çözme/kodlama yalnızca lib/core/'da yapılır.",
  );

  static const sabitRenk = KuralTanimi(
    ad: 'sabit-renk',
    dayanak: 'ADR-0004 §3; CLAUDE.md "Kodlama kuralları" (Tema)',
    aciklama:
        "lib/core/tema/ dışında Color(0x…), Color.from…, Colors.* yok; "
        'renkler TayfamColors token\'larından gelir.',
  );

  static const sabitBosluk = KuralTanimi(
    ad: 'sabit-bosluk',
    dayanak: 'ADR-0004 §3; CLAUDE.md "Kodlama kuralları" (Tema)',
    aciklama:
        "lib/core/tema/ dışında EdgeInsets, boşluk SizedBox'ı ve "
        'spacing argümanlarında sayı yok; TayfamSpacing kullanılır.',
  );

  static const sabitYaricap = KuralTanimi(
    ad: 'sabit-yaricap',
    dayanak: 'ADR-0004 §3; CLAUDE.md "Kodlama kuralları" (Tema)',
    aciklama:
        "lib/core/tema/ dışında Radius.circular / BorderRadius.circular "
        'içinde sayı yok; TayfamRadii kullanılır.',
  );

  static const sabitMetin = KuralTanimi(
    ad: 'sabit-metin',
    dayanak: 'ADR-0008 "Denetim"; CLAUDE.md "API ile konuşma" (Arayüz metinleri)',
    aciklama:
        "Text('…'), tooltip: '…', semanticLabel: '…' gibi sabit kullanıcı "
        'metni yok; metin lib/l10n/app_tr.arb\'den gelir.',
  );

  static const harfDonusumu = KuralTanimi(
    ad: 'harf-donusumu',
    dayanak: 'ADR-0008 "Türkçe metin işleme"',
    aciklama:
        "lib/core/metin/ dışında toUpperCase/toLowerCase yok; "
        'arama ve tekillik için turkceKucukHarf() kullanılır.',
  );

  static const logCiktisi = KuralTanimi(
    ad: 'log-ciktisi',
    dayanak: 'CLAUDE.md kesin kural 3; ADR-0001 kural 6; ADR-0005 §2',
    aciklama:
        'print/debugPrint/stdout/stderr yok; dart:developer yalnızca '
        "lib/core/'daki günlük altyapısında; go_router debugLogDiagnostics "
        'açılmaz (tam adres loglar).',
  );

  static const diskeYazma = KuralTanimi(
    ad: 'diske-yazma',
    dayanak: 'ADR-0006; CLAUDE.md kesin kural 2; ADR-0011',
    aciklama:
        'SharedPreferences, path_provider, yerel veritabanı, File/Directory '
        've tarayıcı deposu kullanılmaz; kalıcı veri yalnızca güvenli depoda.',
  );

  static const googleFonts = KuralTanimi(
    ad: 'google-fonts',
    dayanak: 'ADR-0004 §1',
    aciklama: 'google_fonts paketi kullanılmaz; font uygulamaya gömülüdür.',
  );

  static const guvensizRastgele = KuralTanimi(
    ad: 'guvensiz-rastgele',
    dayanak: 'CLAUDE.md kesin kural 4',
    aciklama: 'Rastgele değer yalnızca Random.secure() ile üretilir.',
  );

  static const riverpodApi = KuralTanimi(
    ad: 'riverpod-api',
    dayanak: 'ADR-0001 kural 1',
    aciklama:
        'StateNotifier, StateNotifierProvider, ChangeNotifierProvider, '
        'StateProvider ve legacy.dart kullanılmaz.',
  );

  static const kodUretimi = KuralTanimi(
    ad: 'kod-uretimi',
    dayanak: 'ADR-0001 kural 2; ADR-0005 §1',
    aciklama:
        'riverpod_generator, freezed, json_serializable, build_runner ve '
        '.g.dart / .freezed.dart part dosyaları kullanılmaz.',
  );

  static const yasakPaket = KuralTanimi(
    ad: 'yasak-paket',
    dayanak: 'ADR-0001; ADR-0005 §2; ADR-0008; CLAUDE.md kesin kural 8',
    aciklama:
        'ADR\'lerde reddedilen paketler (get_it, bloc, provider, dio, '
        'easy_localization) pubspec.yaml\'a girmez.',
  );

  static const arbAciklama = KuralTanimi(
    ad: 'arb-aciklama',
    dayanak: 'ADR-0008 "Çeviri altyapısı"',
    aciklama: 'Kaynak ARB\'deki her anahtarın @anahtar.description\'ı vardır.',
  );

  static const arbAnahtarAdi = KuralTanimi(
    ad: 'arb-anahtar-adi',
    dayanak: 'ADR-0008 "Çeviri altyapısı"',
    aciklama: 'ARB anahtarları snake_case\'tir.',
  );

  static const arbKullanilmayan = KuralTanimi(
    ad: 'arb-kullanilmayan',
    dayanak: 'ADR-0008 "Denetim"',
    aciklama: "ARB'de olup kodda kullanılmayan anahtar (uyarı).",
    seviye: Seviye.uyari,
  );

  static const istisnaBicimi = KuralTanimi(
    ad: 'istisna-bicimi',
    dayanak: 'tool/kurallar (istisna biçimi)',
    aciklama:
        'İstisna yorumu "// kural-istisnası: <kural> — <gerekçe>" '
        'biçimindedir; kural adı bilinir ve gerekçe boş değildir.',
  );

  static const istisnaKullanilmayan = KuralTanimi(
    ad: 'istisna-kullanilmayan',
    dayanak: 'tool/kurallar (istisna biçimi)',
    aciklama: 'Hiçbir bulguyu kapatmayan istisna yorumu (uyarı).',
    seviye: Seviye.uyari,
  );

  /// Bütün kurallar, çıktıdaki sırayla.
  static const List<KuralTanimi> hepsi = [
    importSiniri,
    importDongusu,
    ozellikDisaAcikDosya,
    dosyaAdi,
    apiTekIstemci,
    elleUc,
    elleModel,
    sabitRenk,
    sabitBosluk,
    sabitYaricap,
    sabitMetin,
    harfDonusumu,
    logCiktisi,
    diskeYazma,
    googleFonts,
    guvensizRastgele,
    riverpodApi,
    kodUretimi,
    yasakPaket,
    arbAciklama,
    arbAnahtarAdi,
    arbKullanilmayan,
    istisnaBicimi,
    istisnaKullanilmayan,
  ];

  /// [ad]'lı kural; yoksa `null`.
  static KuralTanimi? bul(String ad) {
    for (final kural in hepsi) {
      if (kural.ad == ad) {
        return kural;
      }
    }
    return null;
  }
}
