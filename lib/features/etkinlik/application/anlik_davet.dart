import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';

/// Anlık tayfada "Arkadaş davet et" sayfasının durumu (ADR-0026).
@immutable
final class AnlikDavetDurumu {
  const AnlikDavetDurumu({
    this.secili = const [],
    this.gonderiliyor = false,
    this.hata,
    this.gonderilen,
  });

  /// Seçili arkadaşların kimlikleri, seçim sırasıyla. Yalnızca bellektedir.
  final List<String> secili;

  final bool gonderiliyor;

  /// İlk başarısız davetin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Bütün davetler gittiyse davet edilen kişi sayısı; sayfa kapanır.
  final int? gonderilen;
}

/// Anlık tayfada organizatörün arkadaşlarını doğrudan davet etmesi:
/// seçilen her kişi için `POST /v1/tayfas/{tayfa_id}/invitations`
/// (mevcut uç; davet edilenin arkadaş olması ve günlük 10 doğrudan davet
/// sınırı sunucudadır, Tayfam-Api ADR-0032 §4).
///
/// Davetler sırayla gönderilir. Biri başarısız olursa diğerleri yine
/// denenir; başarılı olanlar sayılır, ilk hata gösterilir. Başarıyla davet
/// edilenler seçimden çıkar; böylece tekrar denemede yalnızca kalanlar
/// gider.
class AnlikDavetNotifier extends Notifier<AnlikDavetDurumu> {
  AnlikDavetNotifier(this.tayfaId);

  final String tayfaId;

  @override
  AnlikDavetDurumu build() => const AnlikDavetDurumu();

  /// [kullaniciId]'yi seçer ya da seçimden çıkarır; en çok
  /// [anlikDavetliEnCok] kişi.
  void degistir(String kullaniciId) {
    if (state.gonderiliyor || !uuidBicimindeMi(kullaniciId)) return;
    final secili = [...state.secili];
    if (!secili.remove(kullaniciId)) {
      if (secili.length >= anlikDavetliEnCok) return;
      secili.add(kullaniciId);
    }
    state = AnlikDavetDurumu(secili: List.unmodifiable(secili));
  }

  /// Seçilenleri davet eder. Sürerken ya da seçim boşken bir şey yapmaz.
  Future<void> gonder() async {
    final mevcut = state;
    if (mevcut.gonderiliyor || mevcut.secili.isEmpty) return;
    state = AnlikDavetDurumu(secili: mevcut.secili, gonderiliyor: true);
    final depo = ref.read(arkadasDeposuProvider);
    final kalan = <String>[];
    var gonderilen = 0;
    Object? ilkHata;
    for (final kullaniciId in mevcut.secili) {
      try {
        await depo.tayfayaDavetEt(tayfaId, kullaniciId);
        gonderilen++;
      } on OturumYok {
        if (!ref.mounted) return;
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
        return;
      } on Exception catch (hata) {
        ilkHata ??= hata;
        kalan.add(kullaniciId);
      }
      if (!ref.mounted) return;
    }
    // Hata varsa sayfa açık kalır ve hata gösterilir; başarıyla davet
    // edilenler seçimden çıkmıştır.
    state = AnlikDavetDurumu(
      secili: List.unmodifiable(kalan),
      hata: ilkHata,
      gonderilen: ilkHata == null ? gonderilen : null,
    );
  }
}

/// "Arkadaş davet et" sayfasının notifier'ı; sayfa kapanınca bırakılır.
final anlikDavetProvider = NotifierProvider.autoDispose
    .family<AnlikDavetNotifier, AnlikDavetDurumu, String>(
      AnlikDavetNotifier.new,
      name: 'anlikDavetProvider',
    );
