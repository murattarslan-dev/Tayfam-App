import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/gunluk/gunluk_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_deposu.dart';

/// Katalogda tayfa sözlüğü kullanan bir ad alanı (`CatalogVocabulary`):
/// adını veren ilk alan ve onu kullanan türler (türler ad alanını
/// paylaşabilir).
typedef SozlukAdAlani = ({
  String adAlani,
  CatalogField alan,
  List<CatalogEventType> turler,
});

/// [katalog]'daki türlerin günlük alanlarında (`log` bileşeni, `fields`)
/// geçen sözlük ad alanları, katalog sırasıyla. Tanım girdidir: biçimi
/// geçersiz ad alanı atlanır.
List<SozlukAdAlani> sozlukAdAlanlari(Katalog katalog) {
  final sira = <String>[];
  final alanlar = <String, CatalogField>{};
  final turler = <String, List<CatalogEventType>>{};
  for (final tur in katalog.turler) {
    for (final bilesen in turBilesenleri(tur)) {
      if (bilesen.kind != 'log') continue;
      for (final alan in gunlukAlanlari(BilesenParametreleri(bilesen.params))) {
        final adAlani = alan.vocabulary?.namespace;
        if (adAlani == null || !katalogAnahtariMi(adAlani)) continue;
        if (!alanlar.containsKey(adAlani)) {
          sira.add(adAlani);
          alanlar[adAlani] = alan;
        }
        final liste = turler.putIfAbsent(adAlani, () => []);
        if (!liste.contains(tur)) liste.add(tur);
      }
    }
  }
  return [
    for (final a in sira)
      (
        adAlani: a,
        alan: alanlar[a]!,
        turler: List<CatalogEventType>.unmodifiable(turler[a]!),
      ),
  ];
}

/// Sözlük ekranındaki bir liste: tayfa, ad alanı, birleştirilmişler mi ve
/// arama metni.
typedef SozlukSorgusu = ({
  String tayfaId,
  String adAlani,
  bool birlesmis,
  String arama,
});

/// Sözlük ekranındaki liste (`GET …/vocabulary/{namespace}`); yalnızca
/// bellektedir (ADR-0006), ekran kapanınca bırakılır. Birleştirme ve geri
/// almadan sonra bütün sözlük listeleri yeniden okunur.
class SozlukListesiNotifier extends AsyncNotifier<TayfaVocabularyList> {
  SozlukListesiNotifier(this.sorgu);

  final SozlukSorgusu sorgu;

  @override
  Future<TayfaVocabularyList> build() => ref
      .read(sozlukDeposuProvider)
      .ara(
        sorgu.tayfaId,
        sorgu.adAlani,
        arama: sorgu.arama,
        birlesmis: sorgu.birlesmis,
      );
}

/// Sözlük listesi; hata otomatik yeniden denenmez.
final sozlukListesiProvider = AsyncNotifierProvider.autoDispose
    .family<SozlukListesiNotifier, TayfaVocabularyList, SozlukSorgusu>(
      SozlukListesiNotifier.new,
      name: 'sozlukListesiProvider',
      retry: yenidenDenemeYok,
    );
