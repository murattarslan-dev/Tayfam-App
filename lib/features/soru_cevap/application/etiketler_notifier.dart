import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/metin/turkce.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';

/// Bir tayfanın soru etiketleri (`GET /v1/tayfas/{tayfa_id}/tags`; ada göre
/// sıralı, en çok 200): soru listesindeki etiket süzgeci ve soru formundaki
/// öneriler. Yalnızca bellektedir (ADR-0006).
class EtiketlerNotifier extends AsyncNotifier<List<Tag>> {
  EtiketlerNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<List<Tag>> build() {
    ref.watch(oturumDurumuProvider);
    return ref.watch(soruCevapDeposuProvider).etiketler(tayfaId);
  }
}

/// Bir tayfanın etiketleri. Okunamazsa süzgeç ve öneriler gösterilmez;
/// otomatik yeniden denenmez.
final etiketlerProvider = AsyncNotifierProvider.autoDispose
    .family<EtiketlerNotifier, List<Tag>, String>(
      EtiketlerNotifier.new,
      name: 'etiketlerProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Soru formunda gösterilen en çok etiket önerisi.
const int etiketOnerisiEnCok = 8;

/// Soru formundaki etiket önerileri: tayfanın etiketlerinden ([tumu])
/// soruya eklenmemiş olanlar; [yazilan] boş değilse adında onu (Türkçe
/// büyük-küçük harf farkı gözetmeden) geçirenler. En çok
/// [etiketOnerisiEnCok] tane, sunucunun sırasıyla (ada göre).
List<String> etiketOnerileri(
  List<Tag> tumu,
  String yazilan,
  List<String> ekli,
) {
  final aranan = turkceKucukHarf(yazilan.trim());
  final ekliler = {for (final e in ekli) turkceKucukHarf(e)};
  final oneriler = <String>[];
  for (final etiket in tumu) {
    final ad = turkceKucukHarf(etiket.name);
    if (ekliler.contains(ad)) continue;
    if (aranan.isNotEmpty && !ad.contains(aranan)) continue;
    oneriler.add(etiket.name);
    if (oneriler.length == etiketOnerisiEnCok) break;
  }
  return oneriler;
}
