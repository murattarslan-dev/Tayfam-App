import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';

/// Tayfa ana sayfasındaki "Son sorular" bölümünde gösterilen soru sayısı.
const int anaSayfaSoruSayisi = 2;

/// Arama metninin en çok uzunluğu (sözleşme: `q`, en çok 100 karakter).
const int soruAramasiEnCok = 100;

/// Arama kutusuna yazmayı bırakınca aramanın başlaması için beklenen süre;
/// her tuşta istek gitmez.
const Duration soruAramasiGecikmesi = Duration(milliseconds: 400);

/// Bir soru listesinin anahtarı: tayfa, arama metni (boşsa arama yok) ve
/// etiket süzgeci. Sayfa token'ı yalnızca aynı arama ve etiketle geçerli
/// olduğu için her süzgeç kendi listesini tutar.
typedef SoruListesiAnahtari = ({
  String tayfaId,
  String arama,
  String? etiketId,
});

/// [tayfaId]'nin süzgeçsiz soru listesinin anahtarı (yeniden eskiye); ana
/// sayfa bölümü ve detay ekranı bu listeyi paylaşır.
SoruListesiAnahtari anaSoruListesi(String tayfaId) =>
    (tayfaId: tayfaId, arama: '', etiketId: null);

/// Arama kutusuna yazılanı sunucuya gidecek biçime getirir: satır sonları
/// boşluk olur, baştaki ve sondaki boşluklar atılır, en çok 100 karakter
/// kalır (sözleşme: tek satır, en çok 100 karakter). Harf dönüşümü yapılmaz;
/// büyük-küçük harf duyarsızlığı sunucudadır (İ/ı doğru).
String soruAramasiniNormalle(String metin) {
  final tekSatir = metin.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  final harfler = tekSatir.runes;
  if (harfler.length <= soruAramasiEnCok) return tekSatir;
  return String.fromCharCodes(harfler.take(soruAramasiEnCok)).trim();
}

/// Bir tayfanın soruları (`GET /v1/tayfas/{tayfa_id}/questions`, sayfalı;
/// ADR-0018 §4). Arama ve etiket süzgeci sunucuda uygulanır. Tayfaya
/// bağlıdır: `family` + `autoDispose`; oturum değişince yeniden kurulur
/// (ADR-0001 kural 8). Yalnızca bellektedir (ADR-0006). Arama metni log'a
/// yazılmaz.
class SoruListesiNotifier extends SayfaliListeNotifier<Question> {
  SoruListesiNotifier(this.anahtar);

  /// Tayfa, arama ve etiket süzgeci.
  final SoruListesiAnahtari anahtar;

  @override
  Future<SayfaliListe<Question>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(soruCevapDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Question>> sayfaGetir(String? sayfaToken) {
    final depo = ref.read(soruCevapDeposuProvider);
    return depo.sorular(
      anahtar.tayfaId,
      arama: anahtar.arama,
      etiketId: anahtar.etiketId,
      sayfaToken: sayfaToken,
    );
  }

  @override
  String kimlik(Question oge) => oge.id;

  /// Yeni sorulan [soru]'yu listenin başına ekler (yeniden eskiye).
  void ekle(Question soru) => ogeleriDegistir(
    (ogeler) => [
      soru,
      for (final s in ogeler)
        if (s.id != soru.id) s,
    ],
  );

  /// Değişen [soru] listede varsa yerinde günceller.
  void guncelle(Question soru) => ogeleriDegistir(
    (ogeler) => [for (final s in ogeler) s.id == soru.id ? soru : s],
  );

  /// Silinen soruyu listeden çıkarır.
  void cikar(String soruId) => ogeleriDegistir(
    (ogeler) => [
      for (final s in ogeler)
        if (s.id != soruId) s,
    ],
  );
}

/// Bir soru listesi. Hata otomatik yeniden denenmez; ekranlar "Tekrar dene"
/// sunar, aşağı çekince yenilenir.
final soruListesiProvider = AsyncNotifierProvider.autoDispose
    .family<SoruListesiNotifier, SayfaliListe<Question>, SoruListesiAnahtari>(
      SoruListesiNotifier.new,
      name: 'soruListesiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Soru listesi ekranındaki süzgeç: arama metni ve seçili etiket.
@immutable
final class SoruSuzgeci {
  const SoruSuzgeci({this.arama = '', this.etiketId});

  /// Normallenmiş arama metni; boşsa arama yok.
  final String arama;

  /// Seçili etiketin kimliği; yoksa `null`.
  final String? etiketId;

  /// Arama ya da etiket seçili.
  bool get etkin => arama.isNotEmpty || etiketId != null;

  /// Bu süzgecin [tayfaId]'deki liste anahtarı.
  SoruListesiAnahtari anahtar(String tayfaId) =>
      (tayfaId: tayfaId, arama: arama, etiketId: etiketId);

  @override
  bool operator ==(Object other) =>
      other is SoruSuzgeci &&
      other.arama == arama &&
      other.etiketId == etiketId;

  @override
  int get hashCode => Object.hash(arama, etiketId);
}

/// Soru listesi ekranının süzgeci; ekran kapanınca bırakılır.
class SoruSuzgeciNotifier extends Notifier<SoruSuzgeci> {
  SoruSuzgeciNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  SoruSuzgeci build() => const SoruSuzgeci();

  /// Arama metnini ayarlar ([soruAramasiniNormalle]).
  void aramaAyarla(String metin) {
    final arama = soruAramasiniNormalle(metin);
    if (arama == state.arama) return;
    state = SoruSuzgeci(arama: arama, etiketId: state.etiketId);
  }

  /// [etiketId] seçiliyse kaldırır, değilse onu seçer (tek etiket).
  void etiketSec(String etiketId) {
    final yeni = state.etiketId == etiketId ? null : etiketId;
    state = SoruSuzgeci(arama: state.arama, etiketId: yeni);
  }
}

/// Bir tayfanın soru listesi ekranındaki süzgeç.
final soruSuzgeciProvider = NotifierProvider.autoDispose
    .family<SoruSuzgeciNotifier, SoruSuzgeci, String>(
      SoruSuzgeciNotifier.new,
      name: 'soruSuzgeciProvider',
    );

/// [tayfaId]'nin açık soru listelerine [uygula]'yı uygular: süzgeçsiz
/// liste ve (süzgeç etkinse) ekrandaki süzgeçli liste. Var olmayan liste
/// kurulmaz.
void acikSoruListelerineUygula(
  Ref ref,
  String tayfaId,
  void Function(SoruListesiNotifier liste) uygula,
) {
  final anahtarlar = {anaSoruListesi(tayfaId)};
  final suzgec = soruSuzgeciProvider(tayfaId);
  if (ref.read(suzgec.exists)) {
    anahtarlar.add(ref.read(suzgec).anahtar(tayfaId));
  }
  for (final anahtar in anahtarlar) {
    final liste = soruListesiProvider(anahtar);
    if (ref.read(liste.exists)) uygula(ref.read(liste.notifier));
  }
}
