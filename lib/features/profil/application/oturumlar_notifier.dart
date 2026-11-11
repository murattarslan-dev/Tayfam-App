import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

/// Açık oturumların (cihazların) listesi (ADR-0018 §2): tek oturumu
/// kapatma ve "Diğer cihazlardan çık".
///
/// Bu cihazın oturumu (`current`) buradan kapatılmaz; kendi oturumunu
/// kapatmak çıkış yapmaktır (sözleşme: `/v1/auth/sign-out`). Liste yalnızca
/// bellektedir.
class OturumlarNotifier extends AsyncNotifier<List<DeviceSession>> {
  @override
  Future<List<DeviceSession>> build() async {
    if (ref.watch(oturumDurumuProvider) != OturumDurumu.acik) {
      throw const OturumYok();
    }
    return ref.watch(profilDeposuProvider).oturumlar();
  }

  /// [oturumId]'yi kapatır ve listeden çıkarır. Oturum zaten yoksa
  /// (`session-not-found`) yine listeden çıkarılır. Başarıda `null`, aksi
  /// halde gösterilecek hata.
  Future<Object?> kapat(String oturumId) => _islem(() async {
    try {
      await ref.read(profilDeposuProvider).oturumuKapat(oturumId);
    } on ApiProblem catch (problem) {
      if (problem.type != ProblemType.sessionNotFound) rethrow;
    }
    _listele((o) => o.sessionId != oturumId);
  });

  /// Bu cihaz dışındaki bütün oturumları kapatır; listede yalnızca bu
  /// cihaz kalır. Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> digerleriniKapat() => _islem(() async {
    await ref.read(profilDeposuProvider).digerOturumlariKapat();
    _listele((o) => o.current);
  });

  void _listele(bool Function(DeviceSession oturum) kalsin) {
    if (!ref.mounted) return;
    final liste = state.value;
    if (liste == null) return;
    state = AsyncData([
      for (final o in liste)
        if (kalsin(o)) o,
    ]);
  }

  Future<Object?> _islem(Future<void> Function() islem) async {
    try {
      await islem();
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

/// Oturumlar ekranının listesi; ekran kapanınca bırakılır. Hata otomatik
/// yeniden denenmez.
final oturumlarProvider =
    AsyncNotifierProvider.autoDispose<OturumlarNotifier, List<DeviceSession>>(
      OturumlarNotifier.new,
      name: 'oturumlarProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
