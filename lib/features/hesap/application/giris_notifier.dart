import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/data/apple_kimligi.dart';
import 'package:tayfam/features/hesap/data/giris_saglayicisi.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';
import 'package:tayfam/features/hesap/data/hesap_deposu.dart';

/// Giriş ekranının durumu.
@immutable
final class GirisDurumu {
  const GirisDurumu({this.suruyor = false, this.hata});

  /// Sağlayıcının penceresi açık ya da giriş isteği sürüyor.
  final bool suruyor;

  /// Son denemenin hatası (API, bağlantı ya da Google girişi hatası);
  /// yoksa `null`. Metni ekranda `hesapHatasiMetni` verir.
  final Object? hata;

  @override
  bool operator ==(Object other) =>
      other is GirisDurumu && other.suruyor == suruyor && other.hata == hata;

  @override
  int get hashCode => Object.hash(suruyor, hata);
}

/// "Google ile devam et" ve iOS'ta "Apple ile devam et" akışı (ADR-0012 §2,
/// ADR-0034 §5).
///
/// Sağlayıcıdan ID token alınır, `POST /v1/auth/sign-in`'e gönderilir ve
/// gelen oturum `SessionStore`'a verilir; ekranı oturum durumuna göre
/// yönlendirici değiştirir. ID token ve nonce saklanmaz, loglanmaz.
class GirisNotifier extends Notifier<GirisDurumu> {
  @override
  GirisDurumu build() => const GirisDurumu();

  /// Google ile girişi başlatır. Sürerken ikinci çağrı yok sayılır.
  Future<void> girisYap() => _yurut(GirisSaglayicisi.google);

  /// Apple ile girişi başlatır (iOS; ADR-0034 §5). Sürerken ikinci çağrı
  /// yok sayılır.
  Future<void> appleIleGirisYap() => _yurut(GirisSaglayicisi.apple);

  Future<void> _yurut(GirisSaglayicisi saglayici) async {
    if (state.suruyor) return;
    state = const GirisDurumu(suruyor: true);
    final google = ref.read(googleKimlikSaglayiciProvider);
    final apple = ref.read(appleKimlikSaglayiciProvider);
    final depo = ref.read(hesapDeposuProvider);
    final platform = ref.read(hesapPlatformuProvider);
    final oturum = ref.read(sessionStoreProvider);
    final googleAdi = ref.read(googleAdiProvider.notifier);
    final engel = ref.read(hesapEngeliProvider.notifier);
    final hafiza = ref.read(girisSaglayicisiHafizasiProvider);
    try {
      final Session yeni;
      final String? ad;
      switch (saglayici) {
        case GirisSaglayicisi.google:
          final kimlik = await google.girisYap();
          if (kimlik == null) {
            // Kullanıcı Google penceresini kapattı: hata gösterilmez.
            _bitir(const GirisDurumu());
            return;
          }
          yeni = await depo.girisYap(kimlik, platform: platform);
          ad = kimlik.ad;
        case GirisSaglayicisi.apple:
          final kimlik = await apple.girisYap();
          if (kimlik == null) {
            // Kullanıcı Apple penceresini kapattı: hata gösterilmez.
            _bitir(const GirisDurumu());
            return;
          }
          yeni = await depo.appleIleGirisYap(kimlik, platform: platform);
          ad = kimlik.ad;
      }
      // Kayıt formunun ön dolgusu; Apple adı yalnızca ilk yetkilendirmede
      // verir.
      googleAdi.ayarla(ad);
      await hafiza.yaz(saglayici);
      await oturum.oturumAc(yeni);
      _bitir(const GirisDurumu());
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.accountSanctioned) {
        engel.ayarla(HesapEngeli.kisitlandi);
        _bitir(const GirisDurumu());
        return;
      }
      _bitir(GirisDurumu(hata: problem));
    } on Exception catch (hata) {
      _bitir(GirisDurumu(hata: hata));
    }
  }

  void _bitir(GirisDurumu durum) {
    if (ref.mounted) state = durum;
  }
}

/// Giriş ekranının notifier'ı; ekran kapanınca bırakılır.
final girisProvider = NotifierProvider.autoDispose<GirisNotifier, GirisDurumu>(
  GirisNotifier.new,
  name: 'girisProvider',
);
