import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/duyuru/application/duyuru_notifier.dart';
import 'package:tayfam/features/duyuru/data/duyuru_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Duyuru başlığının en çok uzunluğu (sözleşme: boşluklar atıldıktan sonra
/// 1–120 karakter, tek satır).
const int duyuruBasligiEnCok = 120;

/// Duyuru gövdesinin en çok uzunluğu (sözleşme: `maxLength: 5000`).
const int duyuruGovdesiEnCok = 5000;

/// [baslik] boşluklar atıldıktan sonra 1–120 karakter ve tek satır mı.
bool duyuruBasligiGecerli(String baslik) {
  final kirpik = baslik.trim();
  final uzunluk = kirpik.runes.length;
  return uzunluk >= 1 &&
      uzunluk <= duyuruBasligiEnCok &&
      !kirpik.contains('\n') &&
      !kirpik.contains('\r');
}

/// [govde] en çok 5000 karakter mi (boşluklar atıldıktan sonra).
bool duyuruGovdesiGecerli(String govde) =>
    govde.trim().runes.length <= duyuruGovdesiEnCok;

/// Duyuru formunun anahtarı: tayfa ve düzenlenen duyuru (yeni duyuruda
/// `null`).
typedef DuyuruFormuAnahtari = ({String tayfaId, Announcement? duzenlenen});

/// Duyuru yazma ve düzenleme formunun durumu (ADR-0015 §2).
@immutable
final class DuyuruFormuDurumu {
  const DuyuruFormuDurumu({
    required this.istekKimligi,
    this.baslik = '',
    this.govde = '',
    this.baslikHatali = false,
    this.govdeHatali = false,
    this.sabitle = false,
    this.gonderiliyor = false,
    this.hata,
    this.tamamlanan,
    this.sabitlenemedi = false,
  });

  /// Form açılınca bir kez üretilen `client_request_id`; aynı duyuru
  /// tekrar gönderilirken aynı id kullanılır (ADR-0005, ADR-0015 §2).
  final String istekKimligi;

  final String baslik;

  final String govde;

  /// Gönderimde başlık geçersizdi.
  final bool baslikHatali;

  /// Gönderimde gövde geçersizdi.
  final bool govdeHatali;

  /// Yeni duyuru yayınlanınca sabitlensin ("Yayınlayınca sabitle";
  /// yalnızca moderatör ve yöneticiye gösterilir). Oluşturmanın ardından
  /// ayrı bir sabitleme çağrısı yapılır (sözleşmede oluşturma isteğinde
  /// `pinned` yok).
  final bool sabitle;

  /// İstek sürüyor.
  final bool gonderiliyor;

  /// Son gönderimin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıda yayınlanan ya da düzenlenen duyuru.
  final Announcement? tamamlanan;

  /// Duyuru yayınlandı ama istenen sabitleme başarısız oldu; duyuru
  /// sabitlenmemiş olarak [tamamlanan]'dadır.
  final bool sabitlenemedi;

  DuyuruFormuDurumu _degistir({
    String? baslik,
    String? govde,
    bool? baslikHatali,
    bool? govdeHatali,
    bool? sabitle,
    bool gonderiliyor = false,
    Object? hata,
    Announcement? tamamlanan,
    bool sabitlenemedi = false,
  }) => DuyuruFormuDurumu(
    istekKimligi: istekKimligi,
    baslik: baslik ?? this.baslik,
    govde: govde ?? this.govde,
    baslikHatali: baslikHatali ?? this.baslikHatali,
    govdeHatali: govdeHatali ?? this.govdeHatali,
    sabitle: sabitle ?? this.sabitle,
    gonderiliyor: gonderiliyor,
    hata: hata,
    tamamlanan: tamamlanan,
    sabitlenemedi: sabitlenemedi,
  );
}

/// Duyuru yazma (`POST …/announcements`) ve düzenleme (`PATCH …`) formu.
///
/// `client_request_id` form açılınca bir kez üretilir; gönderim tekrar
/// denenirse aynı id gider ve ikinci duyuru açılmaz. Duyuru çevrimdışı
/// kuyruğa girmez: bağlantı yoksa form açık kalır, girilenler korunur
/// (ADR-0006). Başarıda sonuç liste ve detaya yansır.
class DuyuruFormuNotifier extends Notifier<DuyuruFormuDurumu> {
  DuyuruFormuNotifier(this.anahtar);

  /// Tayfa ve düzenlenen duyuru.
  final DuyuruFormuAnahtari anahtar;

  @override
  DuyuruFormuDurumu build() {
    final duzenlenen = anahtar.duzenlenen;
    return DuyuruFormuDurumu(
      istekKimligi: ref.read(istekKimligiUreticisiProvider)(),
      baslik: duzenlenen?.title ?? '',
      govde: duzenlenen?.body ?? '',
    );
  }

  /// Başlığı günceller; geçerli olunca başlık hatası kalkar.
  void baslikAyarla(String baslik) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      baslik: baslik,
      baslikHatali: state.baslikHatali && !duyuruBasligiGecerli(baslik),
    );
  }

  /// Gövdeyi günceller; geçerli olunca gövde hatası kalkar.
  void govdeAyarla(String govde) {
    if (state.gonderiliyor) return;
    state = state._degistir(
      govde: govde,
      govdeHatali: state.govdeHatali && !duyuruGovdesiGecerli(govde),
    );
  }

  /// "Yayınlayınca sabitle" anahtarı. Düzenlemede yok sayılır; sabitleme
  /// orada duyurunun menüsündedir.
  void sabitlemeyiAyarla({required bool sabitle}) {
    if (state.gonderiliyor || anahtar.duzenlenen != null) return;
    state = state._degistir(sabitle: sabitle);
  }

  /// Duyuruyu yayınlar ya da değişiklikleri kaydeder. Sürerken ikinci
  /// çağrı yok sayılır. Düzenlemede yalnızca değişen alanlar gönderilir;
  /// değişiklik yoksa istek gitmez.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.tamamlanan != null) return;
    final baslikGecerli = duyuruBasligiGecerli(mevcut.baslik);
    final govdeGecerli = duyuruGovdesiGecerli(mevcut.govde);
    if (!baslikGecerli || !govdeGecerli) {
      state = mevcut._degistir(
        baslikHatali: !baslikGecerli,
        govdeHatali: !govdeGecerli,
      );
      return;
    }
    final baslik = mevcut.baslik.trim();
    final govde = mevcut.govde.trim();
    final duzenlenen = anahtar.duzenlenen;
    if (duzenlenen != null &&
        baslik == duzenlenen.title &&
        govde == duzenlenen.body) {
      state = mevcut._degistir(tamamlanan: duzenlenen);
      return;
    }
    state = mevcut._degistir(gonderiliyor: true);
    final depo = ref.read(duyuruDeposuProvider);
    final Announcement duyuru;
    try {
      duyuru = duzenlenen == null
          ? await depo.olustur(
              anahtar.tayfaId,
              AnnouncementCreateRequest(
                title: baslik,
                body: govde.isEmpty ? null : govde,
                clientRequestId: mevcut.istekKimligi,
              ),
            )
          : await depo.duzenle(
              anahtar.tayfaId,
              duzenlenen.id,
              AnnouncementUpdateRequest(
                title: baslik == duzenlenen.title ? null : baslik,
                body: govde == duzenlenen.body ? null : govde,
              ),
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
    duyuruyuYansit(ref, anahtar.tayfaId, duyuru);
    if (duzenlenen == null && mevcut.sabitle && !duyuru.pinned) {
      await _sabitle(mevcut, duyuru);
      return;
    }
    state = mevcut._degistir(tamamlanan: duyuru);
  }

  /// Yeni yayınlanan [duyuru]'yu sabitler (`PUT …/pin`). Duyuru zaten
  /// oluştu: sabitleme başarısız olsa da form tamamlanır ve
  /// [DuyuruFormuDurumu.sabitlenemedi] işaretlenir; tekrar gönderimde ikinci
  /// duyuru açılmaz. Yetkiyi sunucu verir (kesin kural 5).
  Future<void> _sabitle(DuyuruFormuDurumu mevcut, Announcement duyuru) async {
    final depo = ref.read(duyuruDeposuProvider);
    final Announcement sabit;
    try {
      sabit = await depo.sabitle(anahtar.tayfaId, duyuru.id, sabit: true);
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception {
      if (ref.mounted) {
        state = mevcut._degistir(tamamlanan: duyuru, sabitlenemedi: true);
      }
      return;
    }
    if (!ref.mounted) return;
    duyuruyuYansit(ref, anahtar.tayfaId, sabit);
    state = mevcut._degistir(tamamlanan: sabit);
  }
}

/// Duyuru formunun notifier'ı; form kapanınca bırakılır ve yeniden
/// açılınca yeni bir `client_request_id` üretilir.
final duyuruFormuProvider = NotifierProvider.autoDispose
    .family<DuyuruFormuNotifier, DuyuruFormuDurumu, DuyuruFormuAnahtari>(
      DuyuruFormuNotifier.new,
      name: 'duyuruFormuProvider',
    );
