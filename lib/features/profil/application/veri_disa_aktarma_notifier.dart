import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/imzali_indirme.dart';
import 'package:tayfam/core/api/istek_kimligi.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/profil/application/yeniden_giris.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_bicimi.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_cozucu.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_deposu.dart';

/// Talepler ve bir sonraki talebin açılabileceği an.
@immutable
final class DisaAktarmaListesi {
  const DisaAktarmaListesi({required this.talepler, this.sonrakiTalep});

  /// Son 30 günün talepleri, yeniden eskiye.
  final List<DataExport> talepler;

  /// `next_request_at`; yoksa şimdi açılabilir (süren talep yine engeller).
  final DateTime? sonrakiTalep;

  /// Sırada ya da hazırlanmakta olan bir talep var mı.
  bool get suruyor => talepler.any(
    (t) =>
        t.status == DataExportStatus.pending ||
        t.status == DataExportStatus.processing,
  );
}

/// Süren talep varken listenin yoklanma aralığı. Hazır olunca
/// `data_export_ready` bildirimi de gelir (ADR-0022 §2).
const Duration disaAktarmaYoklamaAraligi = Duration(seconds: 15);

/// "Verilerimi indir" ekranının talep listesi (`GET /v1/me/data-exports`).
/// Süren talep varken [disaAktarmaYoklamaAraligi] aralıkla yeniden okunur;
/// ekran kapanınca yoklama durur.
class DisaAktarmaListesiNotifier extends AsyncNotifier<DisaAktarmaListesi> {
  Timer? _yoklama;

  @override
  Future<DisaAktarmaListesi> build() async {
    ref.onDispose(() => _yoklama?.cancel());
    final liste = await _oku(ref.watch(disaAktarmaDeposuProvider));
    _yoklamayiKur(liste);
    return liste;
  }

  /// Listeyi yeniden okur. Hata olursa eldeki liste kalır (yoksa hata
  /// gösterilir).
  Future<void> yenile() async {
    final depo = ref.read(disaAktarmaDeposuProvider);
    try {
      final liste = await _oku(depo);
      if (!ref.mounted) return;
      state = AsyncData(liste);
      _yoklamayiKur(liste);
    } on Exception catch (hata, iz) {
      if (!ref.mounted) return;
      final eldeki = state.value;
      if (eldeki == null) {
        state = AsyncError(hata, iz);
      } else {
        _yoklamayiKur(eldeki);
      }
    }
  }

  static Future<DisaAktarmaListesi> _oku(DisaAktarmaDeposu depo) async {
    final yanit = await depo.talepler();
    return DisaAktarmaListesi(
      talepler: yanit.dataExports,
      sonrakiTalep: yanit.nextRequestAt,
    );
  }

  void _yoklamayiKur(DisaAktarmaListesi liste) {
    _yoklama?.cancel();
    _yoklama = null;
    if (!liste.suruyor) return;
    _yoklama = ref.read(zamanlayiciProvider)(disaAktarmaYoklamaAraligi, () {
      if (ref.mounted) unawaited(yenile());
    });
  }
}

/// Ekranın talep listesi; ekran kapanınca bırakılır.
final disaAktarmaListesiProvider =
    AsyncNotifierProvider.autoDispose<
      DisaAktarmaListesiNotifier,
      DisaAktarmaListesi
    >(DisaAktarmaListesiNotifier.new, name: 'disaAktarmaListesiProvider');

/// Süren işlem.
enum DisaAktarmaIslemi {
  /// Talep açılıyor.
  talep,

  /// Yeniden giriş, indirme, çözme ya da paylaşım sürüyor.
  indirme,
}

/// Talep açma ve indirme eylemlerinin durumu.
@immutable
final class DisaAktarmaEylemDurumu {
  const DisaAktarmaEylemDurumu({this.islem, this.talepId, this.hata});

  /// Süren işlem; yoksa `null`.
  final DisaAktarmaIslemi? islem;

  /// İndirilen talebin kimliği ([DisaAktarmaIslemi.indirme] sürerken).
  final String? talepId;

  /// Son denemenin hatası; yoksa `null`.
  final Object? hata;

  bool get suruyor => islem != null;

  @override
  bool operator ==(Object other) =>
      other is DisaAktarmaEylemDurumu &&
      other.islem == islem &&
      other.talepId == talepId &&
      other.hata == hata;

  @override
  int get hashCode => Object.hash(islem, talepId, hata);
}

/// KVKK veri dışa aktarma eylemleri (ADR-0022; Tayfam-Api ADR-0021).
///
/// **Talep:** token önce yenilenir (toplama kullanıcının token'ıyla
/// sunucuda hemen başlar), sonra `POST /v1/me/data-exports`. Bağlantı ya da
/// süre hatasında aynı `client_request_id` korunur; tekrar denemede aynı
/// talep döner.
///
/// **İndirme:** `POST …/download` denenir; `reauthentication-required`
/// gelirse yeniden Google girişi yapılır ve bir kez daha denenir. Gelen
/// imzalı linkten dosya `ApiClient` dışında, token gönderilmeden indirilir
/// (boyut `size_bytes` ile denetlenir), biçimi doğrulanır, Signal
/// köprüsüyle bellekte çözülür ve zip sistem paylaşım sayfasıyla verilir.
/// Anahtar, link ve içerik yalnızca bellektedir; saklanmaz, log'lanmaz;
/// işten sonra anahtar ve içerik tamponları sıfırlanır.
class DisaAktarmaEylemNotifier extends Notifier<DisaAktarmaEylemDurumu> {
  /// Sonuçlanmamış talebin `client_request_id`'si.
  String? _istekKimligi;

  @override
  DisaAktarmaEylemDurumu build() => const DisaAktarmaEylemDurumu();

  /// Yeni talep açar. Bir işlem sürerken yok sayılır.
  Future<void> talepAc() async {
    if (state.suruyor) return;
    state = const DisaAktarmaEylemDurumu(islem: DisaAktarmaIslemi.talep);
    final oturum = ref.read(sessionStoreProvider);
    final depo = ref.read(disaAktarmaDeposuProvider);
    final durum = ref.read(oturumDurumuProvider.notifier);
    final kimlik = _istekKimligi ??= yeniIstekKimligi();
    try {
      await oturum.yenile();
      await depo.talepAc(kimlik);
      _istekKimligi = null;
      _bitir(const DisaAktarmaEylemDurumu());
      _listeyiYenile();
    } on ApiProblem catch (problem) {
      // Sunucu yanıt verdi: bir sonraki talep yeni bir iştir.
      _istekKimligi = null;
      _bitir(DisaAktarmaEylemDurumu(hata: problem));
      _listeyiYenile();
    } on OturumYok catch (hata) {
      durum.ayarla(OturumDurumu.girisYok);
      _bitir(DisaAktarmaEylemDurumu(hata: hata));
    } on Exception catch (hata) {
      _bitir(DisaAktarmaEylemDurumu(hata: hata));
    }
  }

  /// Hazır [talep]'i indirir, çözer ve paylaşır. [konum], iPad'de paylaşım
  /// menüsünün bağlanacağı düğmenin yeridir. Bir işlem sürerken yok
  /// sayılır; kullanıcı Google penceresini kapatırsa sessizce biter.
  Future<void> indir(DataExport talep, {Rect? konum}) async {
    if (state.suruyor) return;
    state = DisaAktarmaEylemDurumu(
      islem: DisaAktarmaIslemi.indirme,
      talepId: talep.id,
    );
    final depo = ref.read(disaAktarmaDeposuProvider);
    final yenidenGiris = ref.read(yenidenGirisProvider);
    final indirici = ref.read(imzaliIndiriciProvider);
    final cozucu = ref.read(disaAktarmaCozucuProvider);
    final paylasici = ref.read(zipPaylasiciProvider);
    final durum = ref.read(oturumDurumuProvider.notifier);
    try {
      if (kIsWeb) {
        throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.desteklenmiyor);
      }
      final bilgi = await _indirmeBilgisi(depo, yenidenGiris, talep.id);
      if (bilgi == null) {
        // Kullanıcı Google penceresini kapattı: hata gösterilmez.
        _bitir(const DisaAktarmaEylemDurumu());
        return;
      }
      final anahtar = DisaAktarmaBicimi.anahtar(bilgi.key);
      try {
        final zip = await _indirVeCoz(
          talep.id,
          bilgi,
          anahtar,
          indirici,
          cozucu,
        );
        try {
          await paylasici.paylas(
            zip,
            dosyaAdi: disaAktarmaDosyaAdi(talep),
            konum: konum,
          );
        } finally {
          zip.fillRange(0, zip.length, 0);
        }
      } finally {
        anahtar.fillRange(0, anahtar.length, 0);
      }
      _bitir(const DisaAktarmaEylemDurumu());
      _listeyiYenile();
    } on ApiProblem catch (problem) {
      _bitir(DisaAktarmaEylemDurumu(hata: problem));
      _listeyiYenile();
    } on OturumYok catch (hata) {
      durum.ayarla(OturumDurumu.girisYok);
      _bitir(DisaAktarmaEylemDurumu(hata: hata));
    } on Exception catch (hata) {
      _bitir(DisaAktarmaEylemDurumu(hata: hata));
    }
  }

  /// Link ve anahtar. Yeniden giriş gerekirse yapılır ve bir kez daha
  /// denenir; kullanıcı vazgeçerse `null`.
  static Future<DataExportDownload?> _indirmeBilgisi(
    DisaAktarmaDeposu depo,
    YenidenGiris yenidenGiris,
    String talepId,
  ) async {
    try {
      return await depo.indirmeBilgisi(talepId);
    } on ApiProblem catch (problem) {
      if (problem.type != ProblemType.reauthenticationRequired) rethrow;
    }
    if (!await yenidenGiris.yap()) return null;
    return depo.indirmeBilgisi(talepId);
  }

  static Future<Uint8List> _indirVeCoz(
    String talepId,
    DataExportDownload bilgi,
    Uint8List anahtar,
    ImzaliIndirici indirici,
    DisaAktarmaCozucu cozucu,
  ) async {
    final adres = Uri.tryParse(bilgi.url);
    if (bilgi.format != DataExportDownloadFormat.aes256GcmV1 ||
        adres == null) {
      throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.bicim);
    }
    final aad = DisaAktarmaBicimi.aad(talepId);
    final Uint8List dosya;
    try {
      dosya = await indirici.indir(
        adres,
        beklenenBoyut: bilgi.sizeBytes,
        enCok: DisaAktarmaBicimi.dosyaEnCok,
      );
    } on ImzaliIndirmeHatasi catch (hata) {
      throw DisaAktarmaHatasi(switch (hata.tur) {
        ImzaliIndirmeHataTuru.gecersizAdres ||
        ImzaliIndirmeHataTuru.boyut => DisaAktarmaHataTuru.bicim,
        ImzaliIndirmeHataTuru.baglanti ||
        ImzaliIndirmeHataTuru.zamanAsimi ||
        ImzaliIndirmeHataTuru.durum => DisaAktarmaHataTuru.indirilemedi,
      });
    }
    final parcalar = DisaAktarmaBicimi.ayristir(dosya);
    final zip = await cozucu.coz(
      anahtar: anahtar,
      nonce: parcalar.nonce,
      sifreliVeEtiket: parcalar.sifreliVeEtiket,
      aad: aad,
    );
    if (zip == null) {
      throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.cozulemedi);
    }
    if (!DisaAktarmaBicimi.zipMi(zip)) {
      zip.fillRange(0, zip.length, 0);
      throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.bicim);
    }
    return zip;
  }

  void _listeyiYenile() {
    if (ref.mounted) ref.invalidate(disaAktarmaListesiProvider);
  }

  void _bitir(DisaAktarmaEylemDurumu yeni) {
    if (ref.mounted) state = yeni;
  }
}

/// Paylaşılan zip'in adı: `tayfam-verilerim-YYYY-AA-GG.zip` (talebin
/// hazırlandığı gün, UTC). Ad içerik ya da kimlik taşımaz.
String disaAktarmaDosyaAdi(DataExport talep) {
  final gun = (talep.readyAt ?? talep.requestedAt).toUtc();
  String iki(int n) => n.toString().padLeft(2, '0');
  return 'tayfam-verilerim-${gun.year}-${iki(gun.month)}-${iki(gun.day)}.zip';
}

/// Ekranın eylemleri; ekran kapanınca bırakılır.
final disaAktarmaEylemProvider =
    NotifierProvider.autoDispose<
      DisaAktarmaEylemNotifier,
      DisaAktarmaEylemDurumu
    >(DisaAktarmaEylemNotifier.new, name: 'disaAktarmaEylemProvider');
