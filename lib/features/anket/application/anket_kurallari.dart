import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Gizli ankette seçenek sayılarının gösterilmesi için gereken en az oy
/// veren sayısı (ADR-0018 §5, kesin kural 7). Az oyda sayım, kimin neye oy
/// verdiğini açığa çıkarabilir.
const int anketSonucEsigi = 5;

/// [anket]'in seçenek sayıları ve yüzdeleri gösterilebilir mi.
///
/// Açık ankette her zaman. Gizli (`anonymous`) ankette yalnızca oy veren
/// sayısı [anketSonucEsigi]'nin altında değilse; altındaysa yalnızca
/// toplam gösterilir. Sayılardan türeyen hiçbir şey (çubuk, yüzde, önde
/// olan seçenek, ekran okuyucu metni) de gösterilmez.
bool secenekSayilariGorunur(Poll anket) =>
    !anket.anonymous || anket.voterCount >= anketSonucEsigi;

/// [anket]'te bir seçeneğe kimlerin oy verdiği gösterilebilir mi.
///
/// Gizli ankette hiçbir zaman, hiç kimseye (yöneticiler dahil): oy
/// verenler ucu çağrılmaz (ADR-0018 §5, kesin kural 7).
bool oyVerenlerGorunur(Poll anket) => !anket.anonymous;

/// [anket] kapandı mı: sunucu kapandı dediyse ya da planlanan kapanma
/// zamanı [simdi] itibarıyla geçtiyse. Kapanmış ankette oy alınmaz.
bool anketKapali(Poll anket, DateTime simdi) {
  if (anket.closed) return true;
  final kapanis = anket.closesAt;
  return kapanis != null && !kapanis.isAfter(simdi);
}

/// Kullanıcı bu ankete oy verdi mi (`own_option_ids` yalnızca çağıranın
/// kendi oyudur).
bool oyVerdi(Poll anket) => anket.ownOptionIds.isNotEmpty;

/// Seçenekler, sunucunun verdiği sırayla (`position`).
List<PollOption> siraliSecenekler(Poll anket) =>
    [...anket.options]..sort((a, b) {
      final sira = a.position.compareTo(b.position);
      return sira != 0 ? sira : a.id.compareTo(b.id);
    });

/// En çok oyu alan seçenek(ler)in kimlikleri. Hiç oy yoksa ya da sayılar
/// gösterilemiyorsa ([secenekSayilariGorunur]) boştur.
Set<String> ondekiSecenekler(Poll anket) {
  if (!secenekSayilariGorunur(anket)) return const <String>{};
  var enCok = 0;
  for (final s in anket.options) {
    if (s.voteCount > enCok) enCok = s.voteCount;
  }
  if (enCok == 0) return const <String>{};
  return {
    for (final s in anket.options)
      if (s.voteCount == enCok) s.id,
  };
}

/// Anketlerin saati; testlerde sabit bir saat verilir.
final anketSaatiProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'anketSaatiProvider',
);
