import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/islem.dart';
import 'package:tayfam/features/tayfa_yonetim/application/uyeler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/application/yetki.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';

/// Tayfa adının en az ve en çok uzunluğu (sözleşme: kırpıldıktan sonra
/// 3–50 karakter).
const int tayfaAdiEnAz = 3;
const int tayfaAdiEnCok = 50;

/// Tayfa açıklamasının en çok uzunluğu (sözleşme: 500).
const int tayfaAciklamasiEnCok = 500;

/// Tayfa bilgileri formunun hatası.
enum BilgiHatasi {
  /// Ad kırpıldıktan sonra 3–50 karakter değil.
  adUzunlugu,

  /// Açıklama 500 karakterden uzun.
  aciklamaUzunlugu,
}

/// Formdaki değerlerin [eski] tayfaya göre değişen alanları; değişiklik
/// yoksa `null`. Yalnızca değişen alanlar gönderilir (sözleşme:
/// `PATCH`'te gövdedeki alanlar değişir, en az bir alan gerekir).
///
/// [kapak] formdaki kapak yüklemesidir (`null`: kapak yok); verilmezse
/// kapak değişmez. Kaldırılan kapak `""` olarak gönderilir (sözleşme;
/// ADR-0021 §6).
TayfaUpdateRequest? bilgiDegisiklikleri(
  Tayfa eski, {
  required String ad,
  required String aciklama,
  required Set<EventType> ilgi,
  required JoinPolicy katilim,
  required bool uyeEtkinlikAcar,
  Object? kapak = _kapakAyni,
}) {
  final kapakDegisti =
      !identical(kapak, _kapakAyni) && kapak != eski.coverUploadId;
  final yeniAd = ad.trim();
  final yeniAciklama = aciklama.trim();
  final eskiIlgi = eski.interests.where(ilgiAlanlari.contains).toSet();
  final ilgiDegisti =
      eskiIlgi.length != ilgi.length || !eskiIlgi.containsAll(ilgi);
  final istek = TayfaUpdateRequest(
    coverUploadId: kapakDegisti ? (kapak as String?) ?? '' : null,
    name: yeniAd == eski.name ? null : yeniAd,
    description: yeniAciklama == eski.description ? null : yeniAciklama,
    interests: ilgiDegisti
        ? [
            for (final t in ilgiAlanlari)
              if (ilgi.contains(t)) t,
          ]
        : null,
    joinPolicy: katilim == eski.joinPolicy ? null : katilim,
    membersCanCreateEvents: uyeEtkinlikAcar == eski.membersCanCreateEvents
        ? null
        : uyeEtkinlikAcar,
  );
  return istek.toJson().isEmpty ? null : istek;
}

const Object _kapakAyni = Object();

/// Formdaki ad ve açıklamanın hatası; geçerliyse `null`.
BilgiHatasi? bilgiHatasi({required String ad, required String aciklama}) {
  final uzunluk = ad.trim().runes.length;
  if (uzunluk < tayfaAdiEnAz || uzunluk > tayfaAdiEnCok) {
    return BilgiHatasi.adUzunlugu;
  }
  if (aciklama.trim().runes.length > tayfaAciklamasiEnCok) {
    return BilgiHatasi.aciklamaUzunlugu;
  }
  return null;
}

/// Tayfa ayarları işlemleri (yönetici; ADR-0018 §1): bilgiler, modüller,
/// tayfa kodu ve silme. Durum, bir işlemin sürüp sürmediğidir (düğmeler
/// bu sırada kapalıdır).
///
/// Başarıdan sonra tayfanın görünümü sunucudan yeniden okunur; ekranlar
/// değeri oradan gösterir. Yetkiyi sunucu verir (kesin kural 5).
class TayfaAyarlariNotifier extends Notifier<bool> {
  TayfaAyarlariNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  bool build() {
    ref.watch(oturumDurumuProvider);
    return false;
  }

  /// Bilgileri günceller (`PATCH`). Ad değiştiyse tayfa listesi de
  /// yenilenir.
  Future<Object?> bilgileriKaydet(TayfaUpdateRequest istek) => _islem(() async {
    await ref.read(yonetimDeposuProvider).bilgileriGuncelle(tayfaId, istek);
    if (istek.name != null && ref.mounted) {
      unawaited(ref.read(tayfalarimProvider.notifier).yenile());
    }
  });

  /// [modul]'ü açar ya da kapatır.
  Future<Object?> modulAyarla(Module modul, {required bool acik}) => _islem(
    () =>
        ref.read(yonetimDeposuProvider).modulAyarla(tayfaId, modul, acik: acik),
  );

  /// Katılım kodunu yeniler; eski kod hemen geçersiz olur.
  Future<Object?> koduYenile() =>
      _islem(() => ref.read(yonetimDeposuProvider).koduYenile(tayfaId));

  /// Tayfayı 72 saat sonra silinmek üzere işaretler.
  Future<Object?> silmeIste() =>
      _islem(() => ref.read(yonetimDeposuProvider).silmeIste(tayfaId));

  /// Bekleyen silmeyi iptal eder.
  Future<Object?> silmeyiIptalEt() =>
      _islem(() => ref.read(yonetimDeposuProvider).silmeyiIptalEt(tayfaId));

  Future<Object?> _islem(Future<void> Function() islem) async {
    if (state) return null;
    state = true;
    final hata = await yonetimIslemi(ref, () async {
      await islem();
      await gorunumuYenile(ref, tayfaId);
    });
    if (ref.mounted) state = false;
    return hata;
  }
}

/// Bir tayfanın ayar işlemleri; `true` iken bir işlem sürüyor.
final tayfaAyarlariProvider = NotifierProvider.autoDispose
    .family<TayfaAyarlariNotifier, bool, String>(
      TayfaAyarlariNotifier.new,
      name: 'tayfaAyarlariProvider',
    );

/// Kullanıcının bu tayfa için bildirim tercihi: sessizde mi
/// (`GET /v1/notification-preferences`; ADR-0018 §1). Sessize alma
/// bildirim listesinden gizlemez; anlık bildirim gönderiminde kullanılır
/// (sözleşme).
class TayfaSessizNotifier extends AsyncNotifier<bool> {
  TayfaSessizNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<bool> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(yonetimDeposuProvider);
    final tercihler = await depo.bildirimTercihleri();
    return tayfaSessizde(tercihler, tayfaId, ref.read(saatProvider)());
  }

  /// [sessiz] `true` ise tayfayı süresiz sessize alır, değilse varsayılana
  /// döndürür.
  Future<Object?> ayarla({required bool sessiz}) =>
      yonetimIslemi(ref, () async {
        final depo = ref.read(yonetimDeposuProvider);
        if (sessiz) {
          await depo.sessizeAl(tayfaId);
        } else {
          await depo.sessizdenCikar(tayfaId);
        }
        if (ref.mounted) state = AsyncData(sessiz);
      });
}

/// Bir tayfanın bildirimleri sessizde mi.
final tayfaSessizProvider = AsyncNotifierProvider.autoDispose
    .family<TayfaSessizNotifier, bool, String>(
      TayfaSessizNotifier.new,
      name: 'tayfaSessizProvider',
      retry: yenidenDenemeYok,
    );
