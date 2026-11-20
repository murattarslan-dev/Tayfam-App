import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ana sayfasının bir bileşeni (App ADR-0024 §6; Tayfam-Api
/// ADR-0027, ADR-0040): sunucunun `home_widgets` listesindeki bir anahtar
/// ve onun kartı.
///
/// Hangi bileşenin, hangi sırayla, hangi ayarla gösterileceğine sunucu
/// karar verir; istemci yalnızca kayıttaki bileşenleri çizer. Kayıtta
/// olmayan anahtar ana sayfada atlanır, düzenleme ekranında "Uygulamayı
/// güncelle" etiketiyle değiştirilemez olarak listelenir. "Sıradaki" kartı
/// bileşen değildir; ana sayfa onu her zaman en üstte gösterir.
///
/// Kayıt `shell/kayitlar.dart`'taki sabit listedir (`anaSayfaBilesenKaydi`;
/// ADR-0002 ile aynı ilke: çalışma zamanında dışarıdan kod yüklenmez).
/// Modül bileşenleri (kütüphane, garaj …) kendi paketlerinde bu arayüzü
/// uygular ve listeye kendi yorumlarının altına tek satırla eklenir.
abstract interface class AnaSayfaBileseni {
  /// Sözleşmedeki bileşen anahtarı (`HomeWidget.key`; ör. `stats`).
  String get anahtar;

  /// Düzenleme ekranındaki ikon; yanında her zaman [ad] yazılır.
  IconData get ikon;

  /// Bileşenin çeviri dosyasından gelen adı ("İstatistikler").
  String ad(BuildContext context);

  /// Düzenleme ekranındaki kısa açıklama.
  String aciklama(BuildContext context);

  /// Ana sayfadaki kart. [bilesen] sunucunun gönderdiği haliyle (ayarı
  /// dahil) girdidir. Gösterecek bir şey yoksa kart kendini boş (sıfır
  /// yükseklik) çizer.
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen);

  /// Ana sayfa aşağı çekilince kartın verisini yeniden okur; hata
  /// fırlatmaz (hata kartta gösterilir).
  Future<void> yenile(WidgetRef ref, String tayfaId);

  /// Bileşenin ayarı; ayar almayan bileşende `null`.
  BilesenAyari? get ayar;
}

/// Bir bileşenin ayar düzenleyicisi (sözleşme: `HomeWidgetConfig`).
@immutable
final class BilesenAyari {
  const BilesenAyari({required this.zorunlu, required this.duzenle});

  /// Bileşen ayarsız açılamaz (sözleşme: `goal`, `countdown`,
  /// `log_summary`).
  final bool zorunlu;

  /// Ayar formunu açar; kaydedilirse yeni ayarı, vazgeçilirse `null`
  /// döner. [mevcut] sunucudan gelen (ya da ekranda değiştirilmiş) ayardır.
  final Future<HomeWidgetConfig?> Function(
    BuildContext context,
    String tayfaId,
    HomeWidgetConfig? mevcut,
  )
  duzenle;
}

/// Ana sayfanın eski sabit bölümlerinden biri (`kind: section`;
/// Tayfam-Api ADR-0027 §3): kartı, sunucunun [modul] anahtarlı tayfa
/// modülünün ana sayfa bölümüdür ([TayfaModule.anaSayfaKarti]). Modül
/// kayıtlı değilse kart boştur.
@immutable
final class BolumBileseni implements AnaSayfaBileseni {
  const BolumBileseni(this.anahtar, {required this.modul, required this.ikon});

  @override
  final String anahtar;

  /// Bölümün bağlı olduğu tayfa modülü (`Module`; ör. `events`).
  final String modul;

  @override
  final IconData ikon;

  @override
  String ad(BuildContext context) {
    final m = AppLocalizations.of(context);
    return switch (anahtar) {
      'upcoming' => m.anasayfa_bolum_upcoming,
      'announcements' => m.anasayfa_bolum_announcements,
      'polls' => m.anasayfa_bolum_polls,
      'questions' => m.anasayfa_bolum_questions,
      _ => m.anasayfa_bolum_genel,
    };
  }

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).anasayfa_bolum_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      _BolumKarti(modul: modul, tayfaId: tayfaId);

  @override
  Future<void> yenile(WidgetRef ref, String tayfaId) async {
    final bulunan = _modulu(ref.read(tayfaModulleriProvider), modul);
    if (bulunan != null) await bulunan.anaSayfayiYenile(ref, tayfaId);
  }

  @override
  BilesenAyari? get ayar => null;
}

TayfaModule? _modulu(List<TayfaModule> kayit, String anahtar) {
  for (final m in kayit) {
    if (m.sunucuAnahtari == anahtar) return m;
  }
  return null;
}

class _BolumKarti extends ConsumerWidget {
  const _BolumKarti({required this.modul, required this.tayfaId});

  final String modul;
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bulunan = _modulu(ref.watch(tayfaModulleriProvider), modul);
    if (bulunan == null) return const SizedBox.shrink();
    return bulunan.anaSayfaKarti(context, tayfaId);
  }
}

/// Ana sayfanın eski sabit bölümleri, bugünkü sırasıyla (Tayfam-Api
/// `home.Widgets()`).
const List<AnaSayfaBileseni> anaSayfaBolumleri = [
  BolumBileseni('upcoming', modul: 'events', ikon: Icons.event_outlined),
  BolumBileseni(
    'announcements',
    modul: 'announcements',
    ikon: Icons.campaign_outlined,
  ),
  BolumBileseni('polls', modul: 'polls', ikon: Icons.poll_outlined),
  BolumBileseni('questions', modul: 'qa', ikon: Icons.forum_outlined),
];

/// [kayit]'ta [anahtar] anahtarlı bileşen; yoksa `null` (tanınmayan
/// bileşen).
AnaSayfaBileseni? anaSayfaBileseniBul(
  List<AnaSayfaBileseni> kayit,
  String anahtar,
) {
  for (final b in kayit) {
    if (b.anahtar == anahtar) return b;
  }
  return null;
}

/// Uygulamaya kayıtlı ana sayfa bileşenleri.
///
/// Liste `shell/kayitlar.dart`'ta tutulur ve uygulamanın kökünde bu
/// provider'a verilir. `core/` özellikleri import edemediği için
/// varsayılan değer yalnızca bölümlerdir ([anaSayfaBolumleri]); gösterim
/// ve modül bileşenleri kayıtla gelir.
final anaSayfaBilesenKaydiProvider = Provider<List<AnaSayfaBileseni>>(
  (ref) => anaSayfaBolumleri,
  name: 'anaSayfaBilesenKaydiProvider',
);
