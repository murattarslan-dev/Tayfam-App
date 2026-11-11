import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Bir etkinliğin bir cevaptaki katılımcılarının anahtarı.
typedef KatilimcilarAnahtari = ({
  String tayfaId,
  String etkinlikId,
  ListEventAttendeesStatus durum,
});

/// Bir etkinliğin bir cevaptaki katılımcıları, eskiden yeniye (bekleme
/// listesinde bekleme sırasıyla; ADR-0015 §3). Yalnızca bellektedir.
class KatilimcilarNotifier extends SayfaliListeNotifier<Attendee> {
  KatilimcilarNotifier(this.anahtar);

  final KatilimcilarAnahtari anahtar;

  @override
  Future<SayfaliListe<Attendee>> build() => ilkSayfayiOku();

  @override
  Future<Sayfa<Attendee>> sayfaGetir(String? sayfaToken) async {
    final yanit = await ref
        .read(etkinlikDeposuProvider)
        .katilimcilar(
          anahtar.tayfaId,
          anahtar.etkinlikId,
          anahtar.durum,
          token: sayfaToken,
        );
    return (ogeler: yanit.attendees, sonraki: yanit.nextPageToken);
  }

  @override
  String kimlik(Attendee oge) => oge.userId;
}

/// Katılımcılar listesi; detay ekranı kapanınca bırakılır.
final katilimcilarProvider = AsyncNotifierProvider.autoDispose
    .family<KatilimcilarNotifier, SayfaliListe<Attendee>, KatilimcilarAnahtari>(
      KatilimcilarNotifier.new,
      name: 'katilimcilarProvider',
      retry: yenidenDenemeYok,
    );

/// Hatalı okuma otomatik yeniden denenmez; kullanıcı "Tekrar dene"ye ya da
/// aşağı çekerek yeniler.
Duration? yenidenDenemeYok(int deneme, Object hata) => null;

/// Tayfanın etkinlik listesini (ana sayfa bölümü dahil) yeniden okutur
/// (oluşturma, düzenleme, iptal, katılım sonrası).
void etkinlikListeleriniYenile(Ref ref, String tayfaId) {
  ref.invalidate(etkinlikListesiProvider(tayfaId));
}
