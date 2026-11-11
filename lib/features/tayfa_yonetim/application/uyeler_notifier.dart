import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/tayfa_yonetim/application/islem.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';

/// Üye listesinin anahtarı: tayfa ve banlılar mı.
typedef UyeListesiAnahtari = ({String tayfaId, bool banlilar});

/// Susturma süreleri (ADR-0018 §1: 1 saat, 1 gün, 7 gün).
const List<Duration> susturmaSureleri = [
  Duration(hours: 1),
  Duration(days: 1),
  Duration(days: 7),
];

/// Saat; testlerde sabit verilir.
final saatProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'saatProvider',
);

/// Bir tayfanın üyeleri (`GET /v1/tayfas/{tayfa_id}/members`, sayfalı;
/// sıra rol, sonra katılma zamanı) ya da banlananlar (`status=banned`).
///
/// Tayfaya bağlıdır: `family` + `autoDispose`; oturum değişince yeniden
/// kurulur. Yalnızca bellektedir (ADR-0006). İşlemlerin yetkisini sunucu
/// verir; hatası ekranda gösterilir (kesin kural 5).
class UyelerNotifier extends SayfaliListeNotifier<Membership> {
  UyelerNotifier(this.anahtar);

  /// Tayfa ve liste türü.
  final UyeListesiAnahtari anahtar;

  @override
  Future<SayfaliListe<Membership>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(yonetimDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Membership>> sayfaGetir(String? sayfaToken) => ref
      .read(yonetimDeposuProvider)
      .uyeler(
        anahtar.tayfaId,
        durum: anahtar.banlilar
            ? ListMembersStatus.banned
            : ListMembersStatus.active,
        sayfaToken: sayfaToken,
      );

  @override
  String kimlik(Membership oge) => oge.userId;

  /// [uyeId]'nin rolünü [rol] yapar.
  Future<Object?> rolDegistir(String uyeId, Role rol) => _islem(
    () => ref
        .read(yonetimDeposuProvider)
        .rolDegistir(anahtar.tayfaId, uyeId, rol),
  );

  /// [uyeId]'yi şimdiden [sure] sonrasına kadar susturur.
  Future<Object?> sustur(String uyeId, Duration sure) {
    final bitis = ref.read(saatProvider)().toUtc().add(sure);
    return _islem(
      () =>
          ref.read(yonetimDeposuProvider).sustur(anahtar.tayfaId, uyeId, bitis),
    );
  }

  /// [uyeId]'nin susturmasını hemen bitirir.
  Future<Object?> susturmayiKaldir(String uyeId) => _islem(
    () => ref
        .read(yonetimDeposuProvider)
        .susturmayiKaldir(anahtar.tayfaId, uyeId),
  );

  /// [uyeId]'yi tayfadan çıkarır; daha sonra tekrar katılabilir.
  Future<Object?> cikar(String uyeId) => yonetimIslemi(ref, () async {
    await ref.read(yonetimDeposuProvider).cikar(anahtar.tayfaId, uyeId);
    _listedenCikar(uyeId);
  });

  /// [uyeId]'yi banlar; kodla ya da davetle tekrar katılamaz.
  Future<Object?> banla(String uyeId) => yonetimIslemi(ref, () async {
    await ref.read(yonetimDeposuProvider).banla(anahtar.tayfaId, uyeId);
    _listedenCikar(uyeId);
    if (!ref.mounted) return;
    final banlilar = uyelerProvider((tayfaId: anahtar.tayfaId, banlilar: true));
    if (ref.read(banlilar.exists)) ref.invalidate(banlilar);
  });

  Future<Object?> _islem(Future<Membership> Function() islem) => yonetimIslemi(
    ref,
    () async {
      final uye = await islem();
      if (!ref.mounted) return;
      ogeleriDegistir(
        (ogeler) => [for (final u in ogeler) u.userId == uye.userId ? uye : u],
      );
    },
  );

  void _listedenCikar(String uyeId) {
    if (!ref.mounted) return;
    ogeleriDegistir(
      (ogeler) => [
        for (final u in ogeler)
          if (u.userId != uyeId) u,
      ],
    );
    // Üye sayısı değişti.
    unawaited(gorunumuYenile(ref, anahtar.tayfaId));
  }
}

/// Bir tayfanın üye listesi ya da banlananlar.
final uyelerProvider = AsyncNotifierProvider.autoDispose
    .family<UyelerNotifier, SayfaliListe<Membership>, UyeListesiAnahtari>(
      UyelerNotifier.new,
      name: 'uyelerProvider',
      retry: yenidenDenemeYok,
    );
