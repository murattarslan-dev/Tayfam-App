import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/soru_cevap/application/cevap_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/application/soru_formu_notifier.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// [govde] boşluklar atıldıktan sonra 1–10000 karakter mi (sözleşme).
bool cevapGovdesiGecerli(String govde) {
  final uzunluk = govde.trim().runes.length;
  return uzunluk >= 1 && uzunluk <= soruCevapGovdesiEnCok;
}

/// Cevap formunun anahtarı: tayfa, soru ve düzenlenen cevap (yeni cevapta
/// `null`).
typedef CevapFormuAnahtari = ({
  String tayfaId,
  String soruId,
  Answer? duzenlenen,
});

/// Cevap yazma ve düzenleme formunun durumu (ADR-0018 §4).
@immutable
final class CevapFormuDurumu {
  const CevapFormuDurumu({
    required this.istekKimligi,
    this.govde = '',
    this.govdeHatali = false,
    this.gonderiliyor = false,
    this.hata,
    this.tamamlanan,
  });

  /// Form açılınca bir kez üretilen `client_request_id`.
  final String istekKimligi;

  final String govde;

  /// Gönderimde gövde geçersizdi.
  final bool govdeHatali;

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıda yazılan ya da düzenlenen cevap.
  final Answer? tamamlanan;

  CevapFormuDurumu _degistir({
    String? govde,
    bool? govdeHatali,
    bool gonderiliyor = false,
    Object? hata,
    Answer? tamamlanan,
  }) => CevapFormuDurumu(
    istekKimligi: istekKimligi,
    govde: govde ?? this.govde,
    govdeHatali: govdeHatali ?? this.govdeHatali,
    gonderiliyor: gonderiliyor,
    hata: hata,
    tamamlanan: tamamlanan,
  );
}

/// Cevap yazma (`POST …/answers`) ve düzenleme (`PATCH …/answers/{id}`)
/// formu. `client_request_id` form açılınca bir kez üretilir; tekrar
/// gönderimde aynı id gider ve ikinci cevap açılmaz. Bağlantı yoksa form
/// açık kalır, girilenler korunur. Başarıda sonuç cevap listesine ve
/// sorunun cevap sayısına yansır.
class CevapFormuNotifier extends Notifier<CevapFormuDurumu> {
  CevapFormuNotifier(this.anahtar);

  /// Tayfa, soru ve düzenlenen cevap.
  final CevapFormuAnahtari anahtar;

  @override
  CevapFormuDurumu build() => CevapFormuDurumu(
    istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
    govde: anahtar.duzenlenen?.body ?? '',
  );

  /// Gövdeyi günceller; geçerli olunca gövde hatası kalkar.
  void govdeAyarla(String govde) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      govde: govde,
      govdeHatali: state.govdeHatali && !cevapGovdesiGecerli(govde),
    );
  }

  /// Cevabı gönderir ya da değişikliği kaydeder. Sürerken ikinci çağrı yok
  /// sayılır; düzenlemede değişiklik yoksa istek gitmez.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.tamamlanan != null) return;
    if (!cevapGovdesiGecerli(mevcut.govde)) {
      state = mevcut._degistir(govdeHatali: true);
      return;
    }
    final govde = mevcut.govde.trim();
    final duzenlenen = anahtar.duzenlenen;
    if (duzenlenen != null && govde == duzenlenen.body) {
      state = mevcut._degistir(tamamlanan: duzenlenen);
      return;
    }
    state = mevcut._degistir(gonderiliyor: true);
    final depo = ref.read(soruCevapDeposuProvider);
    final Answer cevap;
    try {
      cevap = duzenlenen == null
          ? await depo.cevapla(
              anahtar.tayfaId,
              anahtar.soruId,
              AnswerCreateRequest(
                body: govde,
                clientRequestId: mevcut.istekKimligi,
              ),
            )
          : await depo.cevapDuzenle(
              anahtar.tayfaId,
              duzenlenen.id,
              AnswerUpdateRequest(body: govde),
            );
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut._degistir(hata: hata);
      return;
    }
    if (!ref.mounted) return;
    cevabiYansit(
      ref,
      (tayfaId: anahtar.tayfaId, soruId: anahtar.soruId),
      cevap,
      yeni: duzenlenen == null,
    );
    state = mevcut._degistir(tamamlanan: cevap);
  }
}

/// Cevap formunun notifier'ı; form kapanınca bırakılır.
final cevapFormuProvider = NotifierProvider.autoDispose
    .family<CevapFormuNotifier, CevapFormuDurumu, CevapFormuAnahtari>(
      CevapFormuNotifier.new,
      name: 'cevapFormuProvider',
    );
