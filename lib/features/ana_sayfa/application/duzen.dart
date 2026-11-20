import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/ana_sayfa/data/ana_sayfa_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Düzenleme ekranındaki bir bileşen satırı: sunucudaki hali ([kaynak]),
/// ekrandaki açık/kapalı durumu ve ayarı.
@immutable
final class DuzenSatiri {
  const DuzenSatiri({required this.kaynak, required this.acik, this.ayar});

  /// Sunucunun gönderdiği bileşen (`GET …/home-widgets`).
  factory DuzenSatiri.sunucudan(HomeWidget bilesen) =>
      DuzenSatiri(kaynak: bilesen, acik: bilesen.enabled, ayar: bilesen.config);

  final HomeWidget kaynak;
  final bool acik;
  final HomeWidgetConfig? ayar;

  String get anahtar => kaynak.key;

  DuzenSatiri _ile({bool? acik, HomeWidgetConfig? ayar}) => DuzenSatiri(
    kaynak: kaynak,
    acik: acik ?? this.acik,
    ayar: ayar ?? this.ayar,
  );

  /// Bu sürümün bilmediği bir bileşenin, okurken düşen ayarı var mı:
  /// sözleşmedeki ayar nesnesi bileşenin kendi anahtarıyla adlanır, bu
  /// yüzden tanınmayan bileşenin ayarı boş bir nesne olarak okunur.
  /// Böyle bir ayar geri gönderilemez (silinirdi).
  bool get korunamayanAyarVar {
    final ayar = this.ayar;
    return ayar != null &&
        ayar.stats == null &&
        ayar.goal == null &&
        ayar.countdown == null &&
        ayar.champions == null &&
        ayar.logSummary == null;
  }

  @override
  bool operator ==(Object other) =>
      other is DuzenSatiri &&
      other.kaynak == kaynak &&
      other.acik == acik &&
      other.ayar == ayar;

  @override
  int get hashCode => Object.hash(kaynak, acik, ayar);
}

/// Ana sayfa düzeninin ekrandaki taslağı (App ADR-0024 §6): sıra, aç/kapa
/// ve ayarlar. Değişmezdir; her işlem yeni bir taslak döndürür. Kaydet
/// bütün listeyi tek istekle gönderir ([girdiler]); her bileşen tam bir
/// kez gider (sözleşme).
@immutable
final class DuzenTaslagi {
  DuzenTaslagi(Iterable<DuzenSatiri> satirlar)
    : satirlar = List.unmodifiable(satirlar);

  /// Sunucunun düzeninden taslak; aynı anahtarın tekrarı atlanır.
  factory DuzenTaslagi.sunucudan(HomeWidgetLayout duzen) {
    final gorulen = <String>{};
    return DuzenTaslagi([
      for (final b in duzen.widgets)
        if (gorulen.add(b.key)) DuzenSatiri.sunucudan(b),
    ]);
  }

  final List<DuzenSatiri> satirlar;

  /// Sürükle-bırak: [eski] sıradaki satır [yeni] sıraya taşınır; [yeni]
  /// satırın taşındıktan sonraki yeridir (`onReorderItem`).
  DuzenTaslagi tasi(int eski, int yeni) {
    if (eski < 0 || eski >= satirlar.length) return this;
    final hedef = yeni.clamp(0, satirlar.length - 1);
    if (hedef == eski) return this;
    final liste = [...satirlar];
    final satir = liste.removeAt(eski);
    liste.insert(hedef, satir);
    return DuzenTaslagi(liste);
  }

  /// [sira]'daki satırı bir yukarı taşır (erişilebilir alternatif).
  DuzenTaslagi yukari(int sira) => sira <= 0 ? this : tasi(sira, sira - 1);

  /// [sira]'daki satırı bir aşağı taşır (erişilebilir alternatif).
  DuzenTaslagi asagi(int sira) =>
      sira >= satirlar.length - 1 ? this : tasi(sira, sira + 1);

  /// [sira]'daki satırı açar ya da kapatır.
  DuzenTaslagi acKapa(int sira, {required bool acik}) =>
      _degistir(sira, (s) => s._ile(acik: acik));

  /// [sira]'daki satırın ayarını değiştirir; [ac] ise satırı da açar.
  DuzenTaslagi ayarla(int sira, HomeWidgetConfig ayar, {bool ac = false}) =>
      _degistir(sira, (s) => s._ile(ayar: ayar, acik: ac ? true : null));

  DuzenTaslagi _degistir(int sira, DuzenSatiri Function(DuzenSatiri) islem) {
    if (sira < 0 || sira >= satirlar.length) return this;
    final liste = [...satirlar];
    liste[sira] = islem(liste[sira]);
    return DuzenTaslagi(liste);
  }

  /// Sunucuya gidecek bütün liste, yeni sırasıyla.
  List<HomeWidgetInput> girdiler() => [
    for (final s in satirlar)
      HomeWidgetInput(key: s.anahtar, enabled: s.acik, config: s.ayar),
  ];

  /// Kaydedilebilir mi: tanınmayan bir bileşenin geri gönderilemeyen
  /// ayarı varsa hayır (uygulama güncellenmeli).
  bool get kaydedilebilir => !satirlar.any((s) => s.korunamayanAyarVar);

  @override
  bool operator ==(Object other) =>
      other is DuzenTaslagi && listEquals(other.satirlar, satirlar);

  @override
  int get hashCode => Object.hashAll(satirlar);
}

/// Bir tayfanın ana sayfa düzeninin tamamı (`GET …/home-widgets`; ayarlar
/// ekranı). Yalnızca bellektedir (ADR-0006) ve ekran kapanınca bırakılır.
class AnaSayfaDuzeniNotifier extends AsyncNotifier<HomeWidgetLayout> {
  AnaSayfaDuzeniNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<HomeWidgetLayout> build() =>
      ref.read(anaSayfaDeposuProvider).duzen(tayfaId);

  /// [taslak]'ı kaydeder (`PUT`); başarıda yeni düzen durum olur ve tayfa
  /// görünümü (ana sayfanın `home_widgets`'ı) yeniden okunur. Hata
  /// çağırana fırlatılır; taslak ekranda kalır.
  Future<void> kaydet(DuzenTaslagi taslak) async {
    final yeni = await ref
        .read(anaSayfaDeposuProvider)
        .kaydet(tayfaId, taslak.girdiler());
    if (!ref.mounted) return;
    state = AsyncData(yeni);
    final gorunum = tayfaGorunumuProvider(tayfaId);
    if (ref.exists(gorunum)) await ref.read(gorunum.notifier).yenile();
  }
}

/// Ana sayfa düzeni; hata otomatik yeniden denenmez.
final anaSayfaDuzeniProvider = AsyncNotifierProvider.autoDispose
    .family<AnaSayfaDuzeniNotifier, HomeWidgetLayout, String>(
      AnaSayfaDuzeniNotifier.new,
      name: 'anaSayfaDuzeniProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
