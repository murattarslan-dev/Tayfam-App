import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

/// Kendi hesap ayarların (ADR-0018 §2): referans kodu, katılım geçmişi
/// görünürlüğü ve avatar (ADR-0021) (`GET /v1/me/account`).
///
/// Yalnızca bellektedir (ADR-0006); oturum değişince sıfırlanır.
class HesapAyarlariNotifier extends AsyncNotifier<Account> {
  @override
  Future<Account> build() async {
    if (ref.watch(oturumDurumuProvider) != OturumDurumu.acik) {
      throw const OturumYok();
    }
    return ref.watch(profilDeposuProvider).hesap();
  }

  /// Katılım geçmişinin görünürlüğünü [gorunurluk] yapar. Başarıda `null`,
  /// aksi halde gösterilecek hata; hata olursa eski değer kalır.
  Future<Object?> gorunurlukDegistir(ActivityVisibility gorunurluk) => _islem(
    () => ref.read(profilDeposuProvider).gorunurlukDegistir(gorunurluk),
  );

  /// Yeni referans kodu üretir; eski kod ve linki hemen geçersiz olur.
  /// Onay ekranda sorulur. Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> koduYenile() => _islem(() async {
    final kod = await ref.read(profilDeposuProvider).yeniReferansKodu();
    final simdiki = state.value;
    if (simdiki == null) return ref.read(profilDeposuProvider).hesap();
    return Account(
      userId: simdiki.userId,
      displayName: simdiki.displayName,
      avatarUploadId: simdiki.avatarUploadId,
      referralCode: kod,
      activityVisibility: simdiki.activityVisibility,
    );
  });

  /// Hazır [uploadId] yüklemesini avatar yapar (`PUT /v1/me/avatar`;
  /// ADR-0021 §6). Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> avatarAyarla(String uploadId) => _islem(() async {
    final yeni = await ref.read(profilDeposuProvider).avatarAyarla(uploadId);
    return _avatarli(yeni);
  });

  /// Avatarı kaldırır (`DELETE /v1/me/avatar`). Başarıda `null`.
  Future<Object?> avatariKaldir() => _islem(() async {
    await ref.read(profilDeposuProvider).avatariKaldir();
    return _avatarli(null);
  });

  Future<Account> _avatarli(String? avatarUploadId) async {
    final simdiki = state.value;
    if (simdiki == null) return ref.read(profilDeposuProvider).hesap();
    return Account(
      userId: simdiki.userId,
      displayName: simdiki.displayName,
      avatarUploadId: avatarUploadId,
      referralCode: simdiki.referralCode,
      activityVisibility: simdiki.activityVisibility,
    );
  }

  Future<Object?> _islem(Future<Account> Function() islem) async {
    try {
      final hesap = await islem();
      if (ref.mounted) state = AsyncData(hesap);
      return null;
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return hata;
    } on Exception catch (hata) {
      return hata;
    }
  }
}

/// Profil sekmesindeki hesap ayarları. Hata otomatik yeniden denenmez.
final hesapAyarlariProvider =
    AsyncNotifierProvider.autoDispose<HesapAyarlariNotifier, Account>(
      HesapAyarlariNotifier.new,
      name: 'hesapAyarlariProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
