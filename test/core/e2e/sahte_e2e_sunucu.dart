import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Sahte sunucuda bir E2E cihazı (Tayfam-Api ADR-0018 §1–3'ün kabası).
final class SahteCihaz {
  SahteCihaz({
    required this.id,
    required this.kullaniciId,
    required this.oturumId,
    required this.no,
    required this.kayitKimligi,
    required this.kimlik,
    required this.imzali,
    required this.sonCare,
  });

  final String id;
  final String kullaniciId;
  final String oturumId;
  final int no;
  final int kayitKimligi;
  String kimlik;
  Map<String, Object?> imzali;
  Map<String, Object?> sonCare;
  final List<Map<String, Object?>> ec = [];
  final List<Map<String, Object?>> kyber = [];
  final List<Map<String, Object?>> zarflar = [];
  bool eslesmis = false;

  Map<String, Object?> json() => {
    'id': id,
    'device_number': no,
    'registration_id': kayitKimligi,
    'identity_key': kimlik,
    'paired': eslesmis,
    'created_at': '2026-11-11T10:00:00Z',
  };

  Map<String, Object?> sayilar() => {
    'ec': ec.length,
    'kyber': kyber.length,
    'low': ec.length < 10 || kyber.length < 10,
  };
}

/// Sahte sunucuya giden bir istek.
typedef SahteE2eIstegi = ({
  String oturum,
  String method,
  String yol,
  Map<String, String> parametreler,
  Object? govde,
});

/// E2E uçlarını bellekte taklit eden sahte sunucu; gerçek ağ yok.
///
/// Her oturum ([istemci]) ayrı bir taşıma alır; cihaz oturuma bağlıdır.
/// Zarf kümesi denetimi, ön anahtarın bir kez verilmesi, zarf teslimi ve
/// onayı sunucunun davranışına göre yapılır.
final class SahteE2eSunucu {
  final Map<String, SahteCihaz> cihazlar = {};
  final Map<String, String> oturumKullanicisi = {};
  final List<SahteE2eIstegi> istekler = [];
  final List<Map<String, Object?>> anahtarOlaylari = [];
  final Map<String, Map<String, Object?>> gonderimler = {};

  /// Verilirse istek işlenmeden önce çağrılır; dönen istisna fırlatılır.
  Exception? Function(SahteE2eIstegi istek)? araya;

  int _sayac = 0;

  String _kimlik(int onek) {
    _sayac++;
    final s = _sayac.toRadixString(16).padLeft(12, '0');
    return '${onek.toRadixString(16).padLeft(8, '0')}-0000-4000-8000-$s';
  }

  /// [kullaniciId] için yeni bir oturumun taşıması.
  SahteE2eTasima istemci(String kullaniciId) {
    final oturum = _kimlik(0xa0);
    oturumKullanicisi[oturum] = kullaniciId;
    return SahteE2eTasima(this, oturum);
  }

  SahteCihaz? oturumCihazi(String oturum) {
    for (final c in cihazlar.values) {
      if (c.oturumId == oturum) return c;
    }
    return null;
  }

  List<SahteCihaz> kullaniciCihazlari(String kullaniciId) => [
    for (final c in cihazlar.values)
      if (c.kullaniciId == kullaniciId) c,
  ];

  /// [oturum]'un cihazını siler (oturum kapandı).
  void cihaziSil(String cihazId) {
    final c = cihazlar.remove(cihazId);
    if (c == null) return;
    _olay(c, 'device_removed');
  }

  void _olay(SahteCihaz c, String tur) => anahtarOlaylari.insert(0, {
    'id': _kimlik(0xe0),
    'user_id': c.kullaniciId,
    'device_id': c.id,
    'device_number': c.no,
    'type': tur,
    'created_at': '2026-11-11T10:0${anahtarOlaylari.length % 10}:00Z',
  });

  static ApiProblem _problem(ProblemType tur) =>
      ApiProblem(type: tur, status: 409);

  Object? isle(SahteE2eIstegi i) {
    istekler.add(i);
    final hata = araya?.call(i);
    if (hata != null) throw hata;
    final ben = oturumKullanicisi[i.oturum]!;
    final cihaz = oturumCihazi(i.oturum);
    final govde = i.govde is Map<String, Object?>
        ? i.govde! as Map<String, Object?>
        : const <String, Object?>{};
    switch ('${i.method} ${i.yol}') {
      case 'GET /v1/me/e2e/device':
        if (cihaz == null) {
          throw _problem(ProblemType.e2eDeviceNotRegistered);
        }
        return _durum(cihaz);
      case 'POST /v1/me/e2e/device':
        if (cihaz != null) {
          if (cihaz.kimlik == govde['identity_key']) {
            return {'device': cihaz.json(), 'prekey_counts': cihaz.sayilar()};
          }
          throw _problem(ProblemType.e2eDeviceAlreadyRegistered);
        }
        if (kullaniciCihazlari(ben).length >= 5) {
          throw _problem(ProblemType.e2eDeviceLimit);
        }
        final yeni = SahteCihaz(
          id: _kimlik(0xd0),
          kullaniciId: ben,
          oturumId: i.oturum,
          no: kullaniciCihazlari(ben).length + 1,
          kayitKimligi: govde['registration_id']! as int,
          kimlik: govde['identity_key']! as String,
          imzali: govde['signed_prekey']! as Map<String, Object?>,
          sonCare: govde['kyber_last_resort_prekey']! as Map<String, Object?>,
        );
        _ekle(yeni, govde);
        cihazlar[yeni.id] = yeni;
        _olay(yeni, 'device_added');
        return {'device': yeni.json(), 'prekey_counts': yeni.sayilar()};
      case 'DELETE /v1/me/e2e/device':
        if (cihaz != null) cihaziSil(cihaz.id);
        return null;
      case 'POST /v1/me/e2e/device/prekeys':
        if (cihaz == null) throw _problem(ProblemType.e2eDeviceNotRegistered);
        if (govde['signed_prekey'] case final Map<String, Object?> s) {
          cihaz.imzali = s;
        }
        if (govde['kyber_last_resort_prekey']
            case final Map<String, Object?> s) {
          cihaz.sonCare = s;
        }
        _ekle(cihaz, govde);
        return cihaz.sayilar();
      case 'GET /v1/me/e2e/envelopes':
        if (cihaz == null) throw _problem(ProblemType.e2eDeviceNotRegistered);
        return {'envelopes': List.of(cihaz.zarflar)};
      case 'POST /v1/me/e2e/envelopes/ack':
        final idler = (govde['envelope_ids']! as List<Object?>).toSet();
        cihaz?.zarflar.removeWhere((z) => idler.contains(z['id']));
        return null;
      case 'GET /v1/users/{user_id}/e2e/devices':
        final k = i.parametreler['user_id']!;
        return {
          'devices': [
            for (final c in kullaniciCihazlari(k)) _acikCihaz(c),
          ],
        };
      case 'GET /v1/users/{user_id}/e2e/key-events':
        final k = i.parametreler['user_id']!;
        return {
          'events': [
            for (final o in anahtarOlaylari)
              if (o['user_id'] == k) _olayJson(o),
          ],
        };
      case 'POST /v1/users/{user_id}/e2e/prekey-bundles':
        final k = i.parametreler['user_id']!;
        final istenen = (govde['device_ids'] as List<Object?>?)?.toSet();
        return {
          'bundles': [
            for (final c in kullaniciCihazlari(k))
              if (c.id != cihaz?.id && (istenen?.contains(c.id) ?? true))
                _paket(c),
          ],
        };
      case 'POST /v1/direct-messages':
        return _gonder(ben, cihaz, govde);
    }
    throw StateError('Beklenmeyen istek: ${i.method} ${i.yol}');
  }

  static Map<String, Object?> _acikCihaz(SahteCihaz c) =>
      Map.of(c.json())..remove('paired');

  static Map<String, Object?> _olayJson(Map<String, Object?> o) =>
      Map.of(o)..remove('user_id');

  void _ekle(SahteCihaz c, Map<String, Object?> govde) {
    for (final e in (govde['one_time_prekeys'] as List<Object?>?) ?? []) {
      c.ec.add(e! as Map<String, Object?>);
    }
    for (final e in (govde['kyber_prekeys'] as List<Object?>?) ?? []) {
      c.kyber.add(e! as Map<String, Object?>);
    }
  }

  Map<String, Object?> _durum(SahteCihaz c) => {
    'device': c.json(),
    'prekey_counts': c.sayilar(),
    'history_key_version': 0,
    'rotation_needed': false,
    'other_paired_device': false,
  };

  Map<String, Object?> _paket(SahteCihaz c) {
    final ec = c.ec.isEmpty ? null : c.ec.removeAt(0);
    final sonCare = c.kyber.isEmpty;
    final kyber = sonCare ? c.sonCare : c.kyber.removeAt(0);
    return {
      'device_id': c.id,
      'device_number': c.no,
      'registration_id': c.kayitKimligi,
      'identity_key': c.kimlik,
      'signed_prekey': c.imzali,
      'one_time_prekey': ?ec,
      'kyber_prekey': kyber,
      'kyber_last_resort': sonCare,
    };
  }

  Map<String, Object?> _gonder(
    String ben,
    SahteCihaz? cihaz,
    Map<String, Object?> govde,
  ) {
    if (cihaz == null) throw _problem(ProblemType.e2eDeviceNotRegistered);
    final alici = govde['recipient_user_id']! as String;
    final istek = govde['client_request_id']! as String;
    if (gonderimler[istek] case final onceki?) return onceki;
    final zarflar = [
      for (final z in govde['envelopes']! as List<Object?>)
        z! as Map<String, Object?>,
    ];
    final hedefler = {
      for (final c in kullaniciCihazlari(alici)) c.id: c,
      for (final c in kullaniciCihazlari(ben))
        if (c.id != cihaz.id) c.id: c,
    };
    if (kullaniciCihazlari(alici).isEmpty) {
      throw _problem(ProblemType.e2eRecipientUnavailable);
    }
    final gelen = {for (final z in zarflar) z['device_id']! as String: z};
    final eksik = hedefler.keys.where((id) => !gelen.containsKey(id));
    final fazla = gelen.keys.where((id) => !hedefler.containsKey(id));
    final eski = gelen.entries.where(
      (e) =>
          hedefler[e.key] != null &&
          hedefler[e.key]!.kayitKimligi != e.value['registration_id'],
    );
    if (eksik.isNotEmpty || fazla.isNotEmpty || eski.isNotEmpty) {
      throw _problem(ProblemType.e2eDevicesChanged);
    }
    final mesajId = _kimlik(0x4d);
    final konusma = _konusmaId(ben, alici);
    const zaman = '2026-11-11T12:00:00Z';
    for (final z in zarflar) {
      hedefler[z['device_id']]!.zarflar.add({
        'id': _kimlik(0x2a),
        'message_id': mesajId,
        'conversation_id': konusma,
        'sender_user_id': ben,
        'sender_device_id': cihaz.id,
        'sender_device_number': cihaz.no,
        'type': z['type'],
        'content': z['content'],
        'created_at': zaman,
      });
    }
    final sonuc = {
      'message': {
        'id': mesajId,
        'conversation_id': konusma,
        'sender_user_id': ben,
        'deleted': false,
        'encryption': 'e2e',
        'created_at': zaman,
      },
      'conversation': {
        'id': konusma,
        'other_user_id': alici,
        'status': 'active',
        'unread_count': 0,
        'last_message_at': zaman,
        'created_at': zaman,
      },
    };
    gonderimler[istek] = sonuc;
    return sonuc;
  }

  final Map<String, String> _konusmalar = {};

  String _konusmaId(String a, String b) {
    final anahtar = ([a, b]..sort()).join('|');
    return _konusmalar[anahtar] ??= _kimlik(0x3c);
  }
}

/// Bir oturumun sahte sunucuya taşıması.
final class SahteE2eTasima implements ApiTransport {
  SahteE2eTasima(this.sunucu, this.oturum);

  final SahteE2eSunucu sunucu;
  final String oturum;

  @override
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  }) async => sunucu.isle((
    oturum: oturum,
    method: method,
    yol: pathTemplate,
    parametreler: pathParams,
    govde: body,
  ));
}
