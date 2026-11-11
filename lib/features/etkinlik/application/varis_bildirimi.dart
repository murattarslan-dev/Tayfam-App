import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/etkinlik/data/konum_servisi.dart';

/// Varış bildirimi penceresi başlangıçtan bu kadar önce açılır; bitişte
/// kapanır (sözleşme: `check-in-closed`, ADR-0015 §5). Yürüyüşte "Çıktım"
/// da aynı pencereyi kullanır.
const Duration varisPenceresiOncesi = Duration(minutes: 30);

/// Varış bildirimi penceresi açık mı: iptal edilmemiş, başlangıçtan 30
/// dakika önce ile bitiş arası. Kolaylıktır; karar sunucunundur.
bool varisPenceresiAcik(Event etkinlik, DateTime simdi) =>
    !iptalEdildi(etkinlik) &&
    !simdi.isBefore(etkinlik.startsAt.subtract(varisPenceresiOncesi)) &&
    simdi.isBefore(etkinlik.endsAt);

/// Katılımı doğrulanmış mı (`caller_attendance: attended`).
bool katilimDogrulandi(Event etkinlik) =>
    etkinlik.callerAttendance == AttendanceStatus.attended;

/// "Geldim" / "Katıldım" düğmesi görünür mü (ADR-0015 §5): pencere açık,
/// cevap "Geliyorum" ve katılım henüz doğrulanmamış.
///
/// Yürüyüşte katılım "Çıktım" ile doğrulanır; düğme yürüyüş aracındadır.
bool varisDugmesiGorunur(Event etkinlik, DateTime simdi) =>
    etkinlik.type != EventType.hike &&
    etkinlik.callerRsvp == RsvpStatus.going &&
    !katilimDogrulandi(etkinlik) &&
    varisPenceresiAcik(etkinlik, simdi);

/// Varış bildiriminde süren aşama.
enum VarisAsamasi {
  /// Konum izni isteniyor ya da konum okunuyor.
  konum,

  /// İstek gönderiliyor.
  gonderim,
}

/// Varış bildiriminin sonucu. Konum hiçbir sonuçta taşınmaz.
sealed class VarisSonucu {
  const VarisSonucu();
}

/// Katılım doğrulandı.
final class VarisBasarili extends VarisSonucu {
  const VarisBasarili();
}

/// Konum alınamadı: izin yok, yaklaşık konum, servis kapalı ya da okuma
/// hatası. İstek gönderilmedi.
final class VarisKonumEngeli extends VarisSonucu {
  const VarisKonumEngeli(this.neden);

  /// [KonumAlindi] dışındaki bir sonuç.
  final KonumSonucu neden;
}

/// Sunucu ya da bağlantı hatası; metni ortak eşlemeden gelir. Hata
/// metinleri uzaklık söylemez (`check-in-too-far`).
final class VarisHatasi extends VarisSonucu {
  const VarisHatasi(this.hata);

  final Object hata;
}

/// Varış bildirimi (ADR-0015 §5): `POST .../check-in`.
///
/// - Yüz yüze etkinlikte konum izni ve konum yalnızca [bildir] çağrılınca
///   istenir; konum tek seferlik okunur, yalnızca istek gövdesinde gider.
///   Durumda, sonuçta ve log'da konum yoktur; saklanmaz, önbelleğe alınmaz
///   (kesin kural 3).
/// - Çevrimiçi etkinlikte konum istenmez ("Katıldım").
///
/// Durum, süren aşamadır (yoksa `null`); aynı anda tek bildirim yapılır.
class VarisNotifier extends Notifier<VarisAsamasi?> {
  VarisNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  VarisAsamasi? build() => null;

  /// Varışı bildirir. Süren bildirim varken ya da etkinlik yokken `null`.
  Future<VarisSonucu?> bildir() async {
    final etkinlik = ref.read(etkinlikDetayProvider(anahtar)).value;
    if (state != null || etkinlik == null) return null;
    final yuzYuze = etkinlik.mode != EventMode.online;
    state = yuzYuze ? VarisAsamasi.konum : VarisAsamasi.gonderim;
    final depo = ref.read(etkinlikDeposuProvider);
    final (:tayfaId, :etkinlikId) = anahtar;
    try {
      final CheckIn yanit;
      if (yuzYuze) {
        final konum = await ref.read(konumServisiProvider).tekSeferlikKonum();
        if (!ref.mounted) return null;
        if (konum is! KonumAlindi) return VarisKonumEngeli(konum);
        state = VarisAsamasi.gonderim;
        yanit = await depo.varisBildir(tayfaId, etkinlikId, konum: konum.nokta);
      } else {
        yanit = await depo.varisBildir(tayfaId, etkinlikId);
      }
      if (!ref.mounted) return null;
      _katilimiGoster(yanit.attendance);
      return const VarisBasarili();
    } on OturumYok {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return null;
    } on Exception catch (hata) {
      return VarisHatasi(hata);
    } finally {
      if (ref.mounted) state = null;
    }
  }

  /// Konum engelinde ilgili sistem ayarlarını açar: servis kapalıysa konum
  /// ayarları, değilse uygulamanın izin ayarları.
  Future<bool> ayarlariAc(KonumSonucu neden) {
    final servis = ref.read(konumServisiProvider);
    return neden is KonumServisiKapali
        ? servis.konumAyarlariniAc()
        : servis.uygulamaAyarlariniAc();
  }

  void _katilimiGoster(AttendanceStatus katilim) {
    final detay = ref.read(etkinlikDetayProvider(anahtar).notifier);
    final etkinlik = ref.read(etkinlikDetayProvider(anahtar)).value;
    if (etkinlik != null) {
      detay.guncelle(etkinlikKopyasi(etkinlik, katilim: katilim));
    }
    ref.invalidate(katilimcilarProvider);
    unawaited(detay.sessizceYenile());
  }
}

/// Bir etkinliğin varış bildirimi; detay ekranı kapanınca bırakılır.
final varisProvider = NotifierProvider.autoDispose
    .family<VarisNotifier, VarisAsamasi?, EtkinlikAnahtari>(
      VarisNotifier.new,
      name: 'varisProvider',
    );
