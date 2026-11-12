import 'dart:math';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/sohbet/data/kanal_deposu.dart';

import '../../core/realtime/sahte_soket.dart';
import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

const String kanalId1 = '11111111-1111-4111-8111-111111111111';
const String kanalId2 = '22222222-2222-4222-8222-222222222222';
const String mesajId1 = '33333333-3333-4333-8333-333333333331';
const String mesajId2 = '33333333-3333-4333-8333-333333333332';
const String mesajId3 = '33333333-3333-4333-8333-333333333333';
const String benimId = '44444444-4444-4444-8444-444444444441';
const String digerId = '44444444-4444-4444-8444-444444444442';

/// `Channel` JSON'u.
Map<String, Object?> kanalJson(
  String id, {
  String ad = 'genel',
  int okunmamis = 0,
  bool yonetim = false,
  bool arsiv = false,
  int yavas = 0,
}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'name': ad,
  'visibility': yonetim ? 'staff' : 'members',
  'slow_mode_seconds': yavas,
  'archived_at': arsiv ? '2026-11-10T10:00:00Z' : null,
  'created_at': '2026-11-01T10:00:00Z',
  'updated_at': '2026-11-01T10:00:00Z',
  'unread_count': okunmamis,
};

/// `ChannelMessage` JSON'u.
Map<String, Object?> mesajJson(
  String id, {
  String kanal = kanalId1,
  String? metin = 'merhaba',
  String? yazar = digerId,
  bool silindi = false,
  String zaman = '2026-11-11T10:00:00Z',
}) => {
  'id': id,
  'channel_id': kanal,
  'author_user_id': ?yazar,
  'body': silindi ? null : metin,
  'deleted': silindi,
  'created_at': zaman,
};

/// Gerçek zamanlı olay çerçevesindeki mesaj.
Map<String, Object?> olayMesaji(
  String id, {
  String kanal = kanalId1,
  String yazar = digerId,
  String zaman = '2026-11-11T11:00:00Z',
}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'channel_id': kanal,
  'author_user_id': yazar,
  'body': 'yeni',
  'created_at': zaman,
};

/// Sohbet testlerinin sahte ortamı: kanal uçları [tasima]'dan, WebSocket
/// [soketler]'den; zamanlayıcı elle çalışır.
final class SohbetOrtami {
  SohbetOrtami({
    List<Map<String, Object?>>? kanallar,
    List<Map<String, Object?>>? mesajlar,
    String rol = 'member',
    this.aktifTayfaVar = true,
  }) {
    tasima.yanitlar.addAll({
      'GET /v1/tayfas/{tayfa_id}/channels': (_) => {
        'channels': kanallar ?? [kanalJson(kanalId1)],
      },
      'GET /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages': (_) => {
        'messages': mesajlar ?? <Object?>[],
      },
      'PUT /v1/tayfas/{tayfa_id}/channels/{channel_id}/read': (_) => null,
      'GET /v1/tayfas': (_) => listeJson([etkinJson(ornekTayfaId, rol: rol)]),
      'GET /v1/tayfas/{tayfa_id}': (i) =>
          gorunumJson(i.yolParametreleri['tayfa_id']!, rol: rol),
    });
    realtime = RealtimeIstemcisi(
      adres: Uri.parse('wss://api.ornek.test/v1/realtime'),
      baglayici: (adres, basliklar) {
        final s = SahteSoket(adres, basliklar);
        soketler.add(s);
        return s;
      },
      tokenAl: () async => 'token',
      reddedildi: (_) async => 'token',
      oturumuKapat: () async {},
      zamanlayici: zaman.kur,
      rastgele: Random(1),
      gunluk: (_) {},
    );
  }

  /// `false` ise aktif tayfa yoktur.
  final bool aktifTayfaVar;

  final SahteTayfaTasima tasima = SahteTayfaTasima();
  final SahteZamanlayici zaman = SahteZamanlayici();
  final List<SahteSoket> soketler = [];
  late final RealtimeIstemcisi realtime;

  /// Bağlantıyı açar (`ready`).
  Future<SahteSoket> baglan() async {
    realtime.baslat();
    await pumpEventQueue();
    await soketler.last.ac();
    return soketler.last;
  }

  List<Override> get overridelar => [
    ...tayfaOverridelari(tasima: tasima),
    oturumDurumuProvider.overrideWith(
      () => SabitOturumDurumu(OturumDurumu.acik),
    ),
    aktifTayfaIdProvider.overrideWith(
      aktifTayfaVar ? SabitAktifTayfa.new : TayfasizAktifTayfa.new,
    ),
    kanalDeposuProvider.overrideWithValue(KanalDeposu(tasima)),
    realtimeIstemcisiProvider.overrideWithValue(realtime),
    zamanlayiciProvider.overrideWithValue(zaman.kur),
    profilOkuyucuProvider.overrideWithValue(
      (id) async => id == benimId
          ? const KullaniciAdi('Ben')
          : const KullaniciAdi('Ayşe'),
    ),
    kendiKimligiOkuyucuProvider.overrideWithValue(() async => benimId),
  ];
}

/// Aktif tayfası [ornekTayfaId] olan notifier.
class SabitAktifTayfa extends AktifTayfaIdNotifier {
  @override
  String? build() => ornekTayfaId;
}

/// Aktif tayfası olmayan notifier.
class TayfasizAktifTayfa extends AktifTayfaIdNotifier {
  @override
  String? build() => null;
}
