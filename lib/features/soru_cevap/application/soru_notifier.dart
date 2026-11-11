import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';

/// Tek bir sorunun anahtarı: tayfa ve soru kimliği.
typedef SoruAnahtari = ({String tayfaId, String soruId});

/// Tek bir soru (ADR-0018 §4): detay ekranı ve silme.
///
/// Soru tayfanın süzgeçsiz listesinde varsa oradan gösterilir; yoksa
/// (derin link, aramadan gelinen, ilk sayfada olmayan soru) sunucudan
/// okunur. Düzenleme ve silme yazar ile yönetim içindir; düğmeler buna göre
/// sadeleşir, ama kararı sunucu verir (kesin kural 5).
class SoruNotifier extends AsyncNotifier<Question> {
  SoruNotifier(this.anahtar);

  /// Tayfa ve soru kimliği.
  final SoruAnahtari anahtar;

  @override
  Future<Question> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(soruCevapDeposuProvider);
    final liste = soruListesiProvider(anaSoruListesi(anahtar.tayfaId));
    if (ref.read(liste.exists)) {
      for (final s in ref.read(liste).value?.ogeler ?? const <Question>[]) {
        if (s.id == anahtar.soruId) return s;
      }
    }
    return depo.soru(anahtar.tayfaId, anahtar.soruId);
  }

  /// Soruyu sunucudan yeniden okur (aşağı çekince) ve açık listelere
  /// yansıtır. Okunamazsa eldeki soru kalır. Başarıda `null`, aksi halde
  /// hata.
  Future<Object?> yenile() async {
    try {
      final soru = await ref
          .read(soruCevapDeposuProvider)
          .soru(anahtar.tayfaId, anahtar.soruId);
      if (!ref.mounted) return null;
      state = AsyncData(soru);
      acikSoruListelerineUygula(ref, anahtar.tayfaId, (l) => l.guncelle(soru));
      return null;
    } on Exception catch (hata) {
      return hata;
    }
  }

  /// Gösterilen soruyu [soru] yapar (düzenleme sonrası).
  void yansit(Question soru) => state = AsyncData(soru);

  /// Cevap sayısını [fark] kadar değiştirir (cevap yazılınca ya da
  /// silinince) ve açık listelere yansıtır.
  void cevapSayisiniDegistir(int fark) {
    final soru = state.value;
    if (soru == null) return;
    final yeni = cevapSayisiDegismis(soru, fark);
    state = AsyncData(yeni);
    acikSoruListelerineUygula(ref, anahtar.tayfaId, (l) => l.guncelle(yeni));
  }

  /// Soruyu siler ve açık listelerden çıkarır. Onay ekranda sorulur.
  /// Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> sil() async {
    final (:tayfaId, :soruId) = anahtar;
    try {
      await ref.read(soruCevapDeposuProvider).soruSil(tayfaId, soruId);
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return hata;
    } on Exception catch (hata) {
      return hata;
    }
    if (ref.mounted) {
      acikSoruListelerineUygula(ref, tayfaId, (l) => l.cikar(soruId));
    }
    return null;
  }
}

/// Tek bir soru. Hata otomatik yeniden denenmez.
final soruProvider = AsyncNotifierProvider.autoDispose
    .family<SoruNotifier, Question, SoruAnahtari>(
      SoruNotifier.new,
      name: 'soruProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// [soru]'nun cevap sayısı [fark] kadar değişmiş kopyası (en az 0).
Question cevapSayisiDegismis(Question soru, int fark) {
  final sayi = soru.answerCount + fark;
  return Question(
    id: soru.id,
    tayfaId: soru.tayfaId,
    authorUserId: soru.authorUserId,
    title: soru.title,
    body: soru.body,
    tags: soru.tags,
    answerCount: sayi < 0 ? 0 : sayi,
    createdAt: soru.createdAt,
    updatedAt: soru.updatedAt,
  );
}

/// Yeni sorulan [soru]'yu süzgeçsiz listenin başına ekler.
void soruyuEkle(Ref ref, String tayfaId, Question soru) {
  final liste = soruListesiProvider(anaSoruListesi(tayfaId));
  if (ref.read(liste.exists)) ref.read(liste.notifier).ekle(soru);
}

/// Düzenlenen [soru]'yu açık listelere ve detaya yansıtır.
void soruyuYansit(Ref ref, String tayfaId, Question soru) {
  acikSoruListelerineUygula(ref, tayfaId, (l) => l.guncelle(soru));
  final tek = soruProvider((tayfaId: tayfaId, soruId: soru.id));
  if (ref.read(tek.exists)) ref.read(tek.notifier).yansit(soru);
}
