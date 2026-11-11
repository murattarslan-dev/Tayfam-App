import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';

/// Kuyruğun anahtarı: tayfa ve açık/sonuçlanan sekmesi.
typedef KuyrukAnahtari = ({String tayfaId, bool acik});

/// Önizlemenin anahtarı: tayfa, içerik türü ve kimliği.
typedef HedefAnahtari = ({String tayfaId, ReportTargetType tur, String id});

/// Moderatörün kaldırabildiği içerik türleri (duyuru, soru, cevap, anket).
const Set<ReportTargetType> kaldirilabilirTurler = {
  ReportTargetType.announcement,
  ReportTargetType.question,
  ReportTargetType.answer,
  ReportTargetType.poll,
};

/// Geri alma ucu olan içerik türleri (duyuru, soru, cevap). Kanal mesajı
/// sözleşmede şikâyet edilemediği için kuyrukta görünmez.
const Set<ReportTargetType> geriAlinabilirTurler = {
  ReportTargetType.announcement,
  ReportTargetType.question,
  ReportTargetType.answer,
};

/// Önizlemesi okunabilen türler.
const Set<ReportTargetType> onizlenebilirTurler = {
  ReportTargetType.announcement,
  ReportTargetType.event,
  ReportTargetType.question,
  ReportTargetType.poll,
};

/// Şikâyet içerik hakkında mı (üye ve tayfa değil). `content_removed`
/// yalnızca bunlarda geçerlidir (sözleşme).
bool icerikMi(ReportTargetType tur) =>
    tur != ReportTargetType.user &&
    tur != ReportTargetType.tayfa &&
    tur != ReportTargetType.unknown;

/// Bir moderasyon işlemini çalıştırır. Başarıda `null`, aksi halde
/// gösterilecek hata. Oturum kapandıysa giriş ekranına dönülür. Hata
/// log'a yazılmaz.
Future<Object?> _islem(Ref ref, Future<void> Function() islem) async {
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

/// Hata otomatik yeniden denenmez; ekran "Tekrar dene" sunar.
Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Tayfanın moderasyon kuyruğu (`GET /v1/tayfas/{tayfa_id}/reports`;
/// ADR-0018 §8). Açık sekme önce öncelikli (`minor_involved`,
/// `child_safety`), sonra eskiden yeniye; sonuçlanan sekme son çözülen
/// önce. Şikâyet edenin kimliği ve tarafların yaşı sözleşmede yoktur.
///
/// Tayfaya bağlıdır: `family` + `autoDispose`; yalnızca bellektedir
/// (ADR-0006). Yetkiyi sunucu verir (kesin kural 5).
class ModerasyonKuyruguNotifier
    extends SayfaliListeNotifier<ModerationReport> {
  ModerasyonKuyruguNotifier(this.anahtar);

  /// Tayfa ve sekme.
  final KuyrukAnahtari anahtar;

  @override
  Future<SayfaliListe<ModerationReport>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(sikayetDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<ModerationReport>> sayfaGetir(String? sayfaToken) => ref
      .read(sikayetDeposuProvider)
      .kuyruk(anahtar.tayfaId, acik: anahtar.acik, sayfaToken: sayfaToken);

  @override
  String kimlik(ModerationReport oge) => oge.id;

  /// Şikâyeti [sonuc] ile sonuçlandırır; açık listeden çıkar ve
  /// sonuçlanan liste açıksa yenilenir.
  Future<Object?> sonuclandir(
    ModerationReport sikayet,
    ModerationReportResolution sonuc,
  ) => _islem(ref, () async {
    await ref
        .read(sikayetDeposuProvider)
        .sonuclandir(anahtar.tayfaId, sikayet.id, sonuc);
    _sonuclandi(sikayet.id);
  });

  /// Şikâyet edilen içeriği kaldırır, sonra şikâyeti "içerik kaldırıldı"
  /// diye sonuçlandırır. Kaldırma başarılı ama sonuçlandırma başarısızsa
  /// içerik kaldırılmış kalır; hata gösterilir ve tekrar sonuçlandırılabilir.
  Future<Object?> kaldirVeSonuclandir(ModerationReport sikayet) =>
      _islem(ref, () async {
        final depo = ref.read(sikayetDeposuProvider);
        await depo.icerigiKaldir(
          anahtar.tayfaId,
          sikayet.targetType,
          sikayet.targetId,
        );
        _onizlemeyiYenile(sikayet);
        await depo.sonuclandir(
          anahtar.tayfaId,
          sikayet.id,
          ModerationReportResolution.contentRemoved,
        );
        _sonuclandi(sikayet.id);
      });

  /// Moderasyonla gizlenen içeriği geri alır (duyuru, soru, cevap). Şikâyetin
  /// durumu değişmez.
  Future<Object?> geriAl(ModerationReport sikayet) => _islem(ref, () async {
    await ref
        .read(sikayetDeposuProvider)
        .geriAl(anahtar.tayfaId, sikayet.targetType, sikayet.targetId);
    _onizlemeyiYenile(sikayet);
  });

  void _onizlemeyiYenile(ModerationReport sikayet) {
    if (!ref.mounted) return;
    ref.invalidate(
      hedefOnizlemesiProvider((
        tayfaId: anahtar.tayfaId,
        tur: sikayet.targetType,
        id: sikayet.targetId,
      )),
    );
  }

  void _sonuclandi(String sikayetId) {
    if (!ref.mounted) return;
    if (anahtar.acik) {
      ogeleriDegistir(
        (ogeler) => [
          for (final s in ogeler)
            if (s.id != sikayetId) s,
        ],
      );
    }
    final sonuclanan = moderasyonKuyruguProvider((
      tayfaId: anahtar.tayfaId,
      acik: false,
    ));
    if (ref.read(sonuclanan.exists)) ref.invalidate(sonuclanan);
  }
}

/// Bir tayfanın açık ya da sonuçlanan şikâyetleri.
final moderasyonKuyruguProvider = AsyncNotifierProvider.autoDispose
    .family<
      ModerasyonKuyruguNotifier,
      SayfaliListe<ModerationReport>,
      KuyrukAnahtari
    >(
      ModerasyonKuyruguNotifier.new,
      name: 'moderasyonKuyruguProvider',
      retry: _yenidenDenemeYok,
    );

/// Kuyrukta şikâyet edilen içeriğin önizlemesi: başlık, ya da içerik artık
/// görünmüyorsa (`*-not-found`) [HedefOnizlemesi.gorunmuyor]. Önizlemesi
/// olmayan türde (cevap, av kaydı, üye, tayfa) `baslik` `null`'dır.
/// Yalnızca bellektedir.
class HedefOnizlemesiNotifier extends AsyncNotifier<HedefOnizlemesi> {
  HedefOnizlemesiNotifier(this.anahtar);

  final HedefAnahtari anahtar;

  @override
  Future<HedefOnizlemesi> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(sikayetDeposuProvider);
    if (!onizlenebilirTurler.contains(anahtar.tur)) {
      return (baslik: null, gorunmuyor: false);
    }
    try {
      final baslik = await depo.onizlemeBasligi(
        anahtar.tayfaId,
        anahtar.tur,
        anahtar.id,
      );
      return (baslik: baslik, gorunmuyor: false);
    } on ApiProblem catch (hata) {
      if (hata.status == 404) return (baslik: null, gorunmuyor: true);
      rethrow;
    }
  }
}

/// Bir içeriğin kuyruktaki önizlemesi.
final hedefOnizlemesiProvider = AsyncNotifierProvider.autoDispose
    .family<HedefOnizlemesiNotifier, HedefOnizlemesi, HedefAnahtari>(
      HedefOnizlemesiNotifier.new,
      name: 'hedefOnizlemesiProvider',
      retry: _yenidenDenemeYok,
    );
