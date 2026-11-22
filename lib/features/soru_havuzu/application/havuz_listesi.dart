import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';

/// Ana sayfadaki soru havuzu kartında gösterilen soru sayısı.
const int kartSoruSayisi = 3;

/// Bir soru havuzu listesinin anahtarı: tayfa ve ders/konu süzgeci
/// (`null`: süzgeç yok). Sayfa token'ı yalnızca aynı süzgeçle geçerli
/// olduğu için her süzgeç kendi listesini tutar.
typedef HavuzListesiAnahtari = ({String tayfaId, DersKonuSecimi? suzgec});

/// [tayfaId]'nin süzgeçsiz havuz listesi (yeniden eskiye); ana sayfa
/// kartı ve liste ekranı bu listeyi paylaşır.
HavuzListesiAnahtari anaHavuzListesi(String tayfaId) =>
    (tayfaId: tayfaId, suzgec: null);

/// Bir tayfanın soru havuzu (`GET …/questions?pool=question_pool`,
/// sayfalı; Tayfam-Api ADR-0040 §2). Ders ve konu süzgeci sunucuda
/// uygulanır. Tayfaya bağlıdır: `family` + `autoDispose`; oturum değişince
/// yeniden kurulur. Yalnızca bellektedir (ADR-0006).
class HavuzListesiNotifier extends SayfaliListeNotifier<Question> {
  HavuzListesiNotifier(this.anahtar);

  /// Tayfa ve süzgeç.
  final HavuzListesiAnahtari anahtar;

  @override
  Future<SayfaliListe<Question>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(soruCevapDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Question>> sayfaGetir(String? sayfaToken) {
    final suzgec = anahtar.suzgec;
    return ref
        .read(soruCevapDeposuProvider)
        .sorular(
          anahtar.tayfaId,
          havuz: QuestionPool.questionPool,
          dersAnahtari: suzgec?.ders,
          konuAnahtari: suzgec?.konu,
          sayfaToken: sayfaToken,
        );
  }

  @override
  String kimlik(Question oge) => oge.id;

  /// Yeni sorulan [soru]'yu listenin başına ekler.
  void ekle(Question soru) => ogeleriDegistir(
    (ogeler) => [
      soru,
      for (final s in ogeler)
        if (s.id != soru.id) s,
    ],
  );

  /// Değişen [soru] listede varsa yerinde günceller; ders/konu süzgece
  /// artık uymuyorsa çıkarır.
  void guncelle(Question soru) => ogeleriDegistir(
    (ogeler) => [
      for (final s in ogeler)
        if (s.id != soru.id)
          s
        else if (suzgeceUyar(anahtar.suzgec, soru))
          soru,
    ],
  );

  /// Silinen soruyu listeden çıkarır.
  void cikar(String soruId) => ogeleriDegistir(
    (ogeler) => [
      for (final s in ogeler)
        if (s.id != soruId) s,
    ],
  );
}

/// Bir soru havuzu listesi. Hata otomatik yeniden denenmez; ekranlar
/// "Tekrar dene" sunar, aşağı çekince yenilenir.
final havuzListesiProvider = AsyncNotifierProvider.autoDispose
    .family<HavuzListesiNotifier, SayfaliListe<Question>, HavuzListesiAnahtari>(
      HavuzListesiNotifier.new,
      name: 'havuzListesiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// [soru] [suzgec]'e uyuyor mu: süzgeç yoksa her soru; konu seçiliyse
/// ders ve konu, değilse yalnızca ders aynı olmalı.
bool suzgeceUyar(DersKonuSecimi? suzgec, Question soru) {
  if (suzgec == null) return true;
  if (soru.subjectKey != suzgec.ders) return false;
  final konu = suzgec.konu;
  return konu == null || soru.topicKey == konu;
}

/// Liste ekranının ders/konu süzgeci; ekran kapanınca bırakılır.
class HavuzSuzgeciNotifier extends Notifier<DersKonuSecimi?> {
  HavuzSuzgeciNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  DersKonuSecimi? build() => null;

  /// Süzgeci [secim] yapar (`null`: tümü).
  void ayarla(DersKonuSecimi? secim) => state = secim;
}

/// Bir tayfanın soru havuzu ekranındaki süzgeç.
final havuzSuzgeciProvider = NotifierProvider.autoDispose
    .family<HavuzSuzgeciNotifier, DersKonuSecimi?, String>(
      HavuzSuzgeciNotifier.new,
      name: 'havuzSuzgeciProvider',
    );

/// [tayfaId]'nin açık havuz listelerine [uygula]'yı uygular: süzgeçsiz
/// liste ve (süzgeç seçiliyse) ekrandaki süzgeçli liste. Var olmayan liste
/// kurulmaz.
void havuzListelerineUygula(
  Ref ref,
  String tayfaId,
  void Function(HavuzListesiNotifier liste) uygula,
) {
  final suzgec = havuzSuzgeciProvider(tayfaId);
  final secim = ref.read(suzgec.exists) ? ref.read(suzgec) : null;
  for (final anahtar in _acikAnahtarlar(tayfaId, secim)) {
    final liste = havuzListesiProvider(anahtar);
    if (ref.read(liste.exists)) uygula(ref.read(liste.notifier));
  }
}

/// [havuzListelerineUygula]'nın ekrandan (`WidgetRef`) çağrılan hali.
void havuzListelerineUygulaEkrandan(
  WidgetRef ref,
  String tayfaId,
  void Function(HavuzListesiNotifier liste) uygula,
) {
  final suzgec = havuzSuzgeciProvider(tayfaId);
  final secim = ref.read(suzgec.exists) ? ref.read(suzgec) : null;
  for (final anahtar in _acikAnahtarlar(tayfaId, secim)) {
    final liste = havuzListesiProvider(anahtar);
    if (ref.read(liste.exists)) uygula(ref.read(liste.notifier));
  }
}

Set<HavuzListesiAnahtari> _acikAnahtarlar(
  String tayfaId,
  DersKonuSecimi? secim,
) => {
  anaHavuzListesi(tayfaId),
  if (secim != null) (tayfaId: tayfaId, suzgec: secim),
};

/// Yeni sorulan [soru]'yu açık havuz listelerinin başına ekler (süzgece
/// uyuyorsa).
void havuzSorusunuEkle(Ref ref, Question soru) => havuzListelerineUygula(
  ref,
  soru.tayfaId,
  (liste) {
    if (suzgeceUyar(liste.anahtar.suzgec, soru)) liste.ekle(soru);
  },
);
