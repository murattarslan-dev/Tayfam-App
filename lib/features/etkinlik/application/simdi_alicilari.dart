import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/zaman/takvim_gunu.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/simdi_baslat.dart';

/// Şimdi bildirimi alıcılarının üst sınırı (sözleşme: `now_recipient_ids`
/// en çok 30; App ADR-0032 §4).
const int simdiAliciEnCok = 30;

/// [arkadas] [bugun] (Europe/Istanbul takvim günü) "Boşum" demiş mi:
/// rozetin günü bugünse.
bool bugunBos(Friend arkadas, DateTime bugun) =>
    rozetGunu(arkadas, bugun) == bugun;

/// Arkadaş seçicinin sırası (App ADR-0032 §4): önce bugün "Boşum" demiş
/// arkadaşlar, sonra sunucunun sırası (arkadaşlık puanı; Tayfam-Api
/// ADR-0030 §12). Her grubun içinde sunucu sırası korunur. Kabul edilmiş
/// arkadaş olmayan, kimliği UUID biçiminde olmayan (sunucu girdisi),
/// [haric]'te olan ve yinelenen kişiler (sayfalar arasında aynı kişi iki
/// kez gelebilir; sözleşme) alınmaz.
List<Friend> simdiArkadasSirasi(
  Iterable<Friend> arkadaslar,
  DateTime bugun, {
  Set<String> haric = const {},
}) {
  final bos = <Friend>[];
  final diger = <Friend>[];
  final gorulen = <String>{};
  for (final a in arkadaslar) {
    if (a.state != FriendState.friends ||
        !uuidBicimindeMi(a.userId) ||
        haric.contains(a.userId) ||
        !gorulen.add(a.userId)) {
      continue;
    }
    (bugunBos(a, bugun) ? bos : diger).add(a);
  }
  return [...bos, ...diger];
}

/// Önceden dolu seçim: [simdiArkadasSirasi]'nın ilk [simdiAliciEnCok]
/// kişisi. "Şimdi bildirimlerini kapatmış" arkadaşları istemci tahmin
/// etmez; sunucu onları sessizce düşürür (ADR-0032 §4).
List<String> simdiOnSecimi(
  Iterable<Friend> arkadaslar,
  DateTime bugun, {
  Set<String> haric = const {},
}) => List.unmodifiable(
  simdiArkadasSirasi(
    arkadaslar,
    bugun,
    haric: haric,
  ).take(simdiAliciEnCok).map((a) => a.userId),
);

/// Şimdi bildiriminin alıcı seçimi.
@immutable
final class SimdiAlicilari {
  const SimdiAlicilari({this.secili = const [], this.duzenlendi = false});

  /// Seçili arkadaşların kimlikleri, sırasıyla. Yalnızca bellektedir.
  final List<String> secili;

  /// Kullanıcı seçimi değiştirdi mi; değiştirdiyse liste yeniden
  /// yüklendiğinde ön seçim üstüne yazılmaz.
  final bool duzenlendi;
}

/// Tayfasız (anlık) şimdi etkinliğinde bildirim gidecek arkadaşlar (App
/// ADR-0032 §4; Tayfam-Api ADR-0038 §4).
///
/// Liste önceden dolu gelir ([simdiOnSecimi]); kullanıcı düzenler, en çok
/// [simdiAliciEnCok] kişi. "Boşum"dan gelen davetli (`invitee_user_ids`)
/// alıcılarda olmaz (sözleşme: iki liste kesişmez). Tayfa içinde alıcı
/// yoktur (bildirim tayfa üyelerine gider); durum hep boştur ve arkadaş
/// listesi istenmez.
class SimdiAlicilariNotifier extends Notifier<SimdiAlicilari> {
  SimdiAlicilariNotifier(this.anahtar);

  final SimdiAnahtari anahtar;

  Set<String> get _haric => {?anahtar.davetli};

  DateTime get _bugun => istanbulBugunu(ref.read(etkinlikSaatiProvider)());

  @override
  SimdiAlicilari build() {
    if (anahtar.tayfaId != null) return const SimdiAlicilari();
    ref.listen(arkadaslarProvider, (_, durum) {
      final liste = durum.value;
      if (liste == null || state.duzenlendi) return;
      state = SimdiAlicilari(
        secili: simdiOnSecimi(liste.ogeler, _bugun, haric: _haric),
      );
    });
    final liste = ref.read(arkadaslarProvider).value;
    if (liste == null) return const SimdiAlicilari();
    return SimdiAlicilari(
      secili: simdiOnSecimi(liste.ogeler, _bugun, haric: _haric),
    );
  }

  /// [kullaniciId]'yi seçer ya da seçimden çıkarır; sınır dolunca yeni
  /// kişi eklenmez.
  void degistir(String kullaniciId) {
    if (anahtar.tayfaId != null ||
        !uuidBicimindeMi(kullaniciId) ||
        _haric.contains(kullaniciId)) {
      return;
    }
    final secili = [...state.secili];
    if (!secili.remove(kullaniciId)) {
      if (secili.length >= simdiAliciEnCok) return;
      secili.add(kullaniciId);
    }
    state = SimdiAlicilari(secili: List.unmodifiable(secili), duzenlendi: true);
  }

  /// Seçimi boşaltır (kimseye bildirim gitmez).
  void temizle() {
    state = const SimdiAlicilari(duzenlendi: true);
  }
}

/// Şimdi ekranının alıcı seçimi; ekran kapanınca bırakılır.
final simdiAlicilariProvider = NotifierProvider.autoDispose
    .family<SimdiAlicilariNotifier, SimdiAlicilari, SimdiAnahtari>(
      SimdiAlicilariNotifier.new,
      name: 'simdiAlicilariProvider',
    );
