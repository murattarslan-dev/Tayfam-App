import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/soru_cevap/application/soru_notifier.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';

/// Cevapların sırası (sunucuyla aynı): faydalı oyu çoktan aza, eşitlikte
/// eskiden yeniye.
List<Answer> cevapSirala(Iterable<Answer> cevaplar) {
  final sirali = [...cevaplar];
  sirali.sort(_cevapSirasi);
  return sirali;
}

int _cevapSirasi(Answer a, Answer b) {
  final oy = b.voteCount.compareTo(a.voteCount);
  if (oy != 0) return oy;
  final zaman = a.createdAt.compareTo(b.createdAt);
  return zaman != 0 ? zaman : a.id.compareTo(b.id);
}

/// Bir sorunun cevapları (`GET …/questions/{question_id}/answers`, sayfalı;
/// ADR-0018 §4), faydalı oyuna göre sıralı.
///
/// Oy verilince cevap yerinde güncellenir, liste yeniden sıralanmaz
/// (dokunulan kart parmağın altından kaymasın); sıra yenilemede ve yeni
/// cevap eklenince sunucunun sırasına döner. Kendi cevabına oyu sunucu
/// reddeder (`own-answer-vote`); istemci yalnızca düğmeyi gizler.
class CevapListesiNotifier extends SayfaliListeNotifier<Answer> {
  CevapListesiNotifier(this.anahtar);

  /// Tayfa ve soru kimliği.
  final SoruAnahtari anahtar;

  final Set<String> _oylanan = {};

  @override
  Future<SayfaliListe<Answer>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(soruCevapDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Answer>> sayfaGetir(String? sayfaToken) =>
      ref
          .read(soruCevapDeposuProvider)
          .cevaplar(anahtar.tayfaId, anahtar.soruId, sayfaToken: sayfaToken);

  @override
  String kimlik(Answer oge) => oge.id;

  /// Yazılan [cevap]'ı ekler ve sırayı korur.
  void ekle(Answer cevap) => ogeleriDegistir(
    (ogeler) => cevapSirala([
      cevap,
      for (final c in ogeler)
        if (c.id != cevap.id) c,
    ]),
  );

  /// Değişen [cevap]'ı yerinde günceller.
  void guncelle(Answer cevap) => ogeleriDegistir(
    (ogeler) => [for (final c in ogeler) c.id == cevap.id ? cevap : c],
  );

  /// Silinen cevabı listeden çıkarır.
  void cikar(String cevapId) => ogeleriDegistir(
    (ogeler) => [
      for (final c in ogeler)
        if (c.id != cevapId) c,
    ],
  );

  /// [cevapId]'ye faydalı oyu verir ([oy] `true`) ya da geri alır. Aynı
  /// cevap için istek sürerken ikinci çağrı yok sayılır. Başarıda `null`,
  /// aksi halde gösterilecek hata.
  Future<Object?> oyla(String cevapId, {required bool oy}) async {
    if (!_oylanan.add(cevapId)) return null;
    try {
      final cevap = await ref
          .read(soruCevapDeposuProvider)
          .oyla(anahtar.tayfaId, cevapId, oy: oy);
      if (ref.mounted) guncelle(cevap);
      return null;
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return hata;
    } on Exception catch (hata) {
      return hata;
    } finally {
      _oylanan.remove(cevapId);
    }
  }

  /// [cevapId]'yi siler, listeden çıkarır ve sorunun cevap sayısını
  /// azaltır. Onay ekranda sorulur. Başarıda `null`, aksi halde hata.
  Future<Object?> sil(String cevapId) async {
    try {
      await ref
          .read(soruCevapDeposuProvider)
          .cevapSil(anahtar.tayfaId, cevapId);
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return hata;
    } on Exception catch (hata) {
      return hata;
    }
    if (!ref.mounted) return null;
    cikar(cevapId);
    final soru = soruProvider(anahtar);
    if (ref.read(soru.exists)) ref.read(soru.notifier).cevapSayisiniDegistir(-1);
    return null;
  }
}

/// Bir sorunun cevap listesi. Hata otomatik yeniden denenmez.
final cevapListesiProvider = AsyncNotifierProvider.autoDispose
    .family<CevapListesiNotifier, SayfaliListe<Answer>, SoruAnahtari>(
      CevapListesiNotifier.new,
      name: 'cevapListesiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Yazılan ya da düzenlenen [cevap]'ı açık cevap listesine yansıtır; yeni
/// cevapta ([yeni]) sorunun cevap sayısını artırır.
void cevabiYansit(
  Ref ref,
  SoruAnahtari anahtar,
  Answer cevap, {
  required bool yeni,
}) {
  final liste = cevapListesiProvider(anahtar);
  if (ref.read(liste.exists)) {
    final notifier = ref.read(liste.notifier);
    if (yeni) {
      notifier.ekle(cevap);
    } else {
      notifier.guncelle(cevap);
    }
  }
  if (!yeni) return;
  final soru = soruProvider(anahtar);
  if (ref.read(soru.exists)) ref.read(soru.notifier).cevapSayisiniDegistir(1);
}
