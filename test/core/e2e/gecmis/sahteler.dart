import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Testlerdeki örnek kimlikler (gerçek değil).
const String kullaniciId = '00000000-0000-4000-8000-0000000000aa';
const String cihazA = '00000000-0000-4000-8000-00000000000a';
const String cihazB = '00000000-0000-4000-8000-00000000000b';
const String cihazC = '00000000-0000-4000-8000-00000000000c';
const String konusmaId = '00000000-0000-4000-8000-0000000000c1';
const String karsiKullanici = '00000000-0000-4000-8000-0000000000bb';
const String istekId = '00000000-0000-4000-8000-0000000000e1';

/// [n] ile başlayan 33 baytlık sahte kimlik açık anahtarı (0x05 önekli).
Uint8List kimlik(int n) =>
    Uint8List.fromList([0x05, for (var i = 0; i < 32; i++) (n + i) & 0xff]);

/// [n] ile doldurulmuş 32 baytlık sahte geçmiş anahtarı.
Uint8List anahtar(int n) => Uint8List.fromList(List.filled(32, n));

/// `i`. mesaj kimliği.
String mesajId(int i) =>
    '00000000-0000-4000-8000-${i.toRadixString(16).padLeft(12, '0')}';

/// `E2EDeviceState` (sahte).
E2eCihazBilgisi bilgi({
  String cihaz = cihazA,
  bool eslesmis = true,
  bool baska = false,
  int surum = 1,
  bool yenile = false,
  int kimlikNo = 1,
}) => E2eCihazBilgisi(
  kullaniciId: kullaniciId,
  durum: E2EDeviceState.fromJson({
    'device': {
      'id': cihaz,
      'device_number': 1,
      'registration_id': 7,
      'identity_key': base64.encode(kimlik(kimlikNo)),
      'paired': eslesmis,
      'created_at': '2026-11-11T10:00:00Z',
    },
    'prekey_counts': {'ec': 50, 'kyber': 20, 'low': false},
    'history_key_version': surum,
    'rotation_needed': yenile,
    'other_paired_device': baska,
  }),
);

/// Bellekteki E2E deposu.
final class BellekE2eDepo implements E2eDepoErisimi {
  final Map<String, Uint8List> kayitlar = {};

  @override
  Future<Uint8List?> oku(String anahtar) async => kayitlar[anahtar];

  @override
  Future<void> yaz(String anahtar, Uint8List deger) async =>
      kayitlar[anahtar] = Uint8List.fromList(deger);

  @override
  Future<void> sil(String anahtar) async => kayitlar.remove(anahtar);

  @override
  Future<Map<String, Uint8List>> onekliOku(String onek) async => {
    for (final e in kayitlar.entries)
      if (e.key.startsWith(onek)) e.key: e.value,
  };
}

/// Elle değiştirilen cihaz durumu kaynağı. [tazele] [sonraki]'ni (verilmişse)
/// yayınlar.
final class SahteKaynak implements E2eCihazDurumuKaynagi {
  SahteKaynak(this._guncel);

  E2eCihazBilgisi? _guncel;
  E2eCihazBilgisi? Function()? sonraki;
  int tazelemeSayisi = 0;
  final StreamController<E2eCihazBilgisi?> _akis = StreamController.broadcast(
    sync: true,
  );

  void yayinla(E2eCihazBilgisi? b) {
    _guncel = b;
    _akis.add(b);
  }

  @override
  E2eCihazBilgisi? get guncel => _guncel;

  @override
  Stream<E2eCihazBilgisi?> get degisiklikler => _akis.stream;

  @override
  Future<E2eCihazBilgisi?> tazele() async {
    tazelemeSayisi++;
    final s = sonraki;
    if (s != null) yayinla(s());
    return _guncel;
  }
}

/// Sahte kendi cihaz oturumu: "şifreli" = gönderen cihaz kimliği ‖ düz
/// (gerçek kripto değil). [kimlikler] sunucudaki paketlerin kimlik
/// anahtarlarıdır; `beklenenKimlik` tutmazsa [E2eKimlikUyusmazligi].
final class SahteKendiOturum implements KendiCihazOturumu {
  SahteKendiOturum(this.buCihaz, {Map<String, Uint8List>? kimlikler})
    : kimlikler = kimlikler ?? {};

  final String buCihaz;
  final Map<String, Uint8List> kimlikler;
  final List<String> sifrelenen = [];
  bool cozmeHatasi = false;

  @override
  Future<KendiCihazSifreli> sifrele(
    String cihazId,
    Uint8List duz, {
    Uint8List? beklenenKimlik,
  }) async {
    if (beklenenKimlik != null) {
      final k = kimlikler[cihazId];
      if (k == null || base64.encode(k) != base64.encode(beklenenKimlik)) {
        throw const E2eKimlikUyusmazligi();
      }
    }
    sifrelenen.add(cihazId);
    return KendiCihazSifreli(
      tur: SignalMesajTuru.onAnahtar,
      sifreli: Uint8List.fromList([
        ...utf8.encode('$buCihaz>$cihazId|'),
        ...duz,
      ]),
    );
  }

  @override
  Future<Uint8List> coz(String cihazId, int tur, Uint8List sifreli) async {
    if (cozmeHatasi) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }
    final onek = utf8.encode('$cihazId>$buCihaz|');
    if (sifreli.length < onek.length ||
        base64.encode(sifreli.sublist(0, onek.length)) != base64.encode(onek)) {
      throw const SignalHatasi(SignalHatasiTuru.gecersizMesaj);
    }
    return Uint8List.fromList(sifreli.sublist(onek.length));
  }
}

/// Kaydedilen istek.
final class SahteIstek {
  SahteIstek(this.yol, this.parametreler, this.govde);

  final String yol;
  final Map<String, String> parametreler;
  final Object? govde;

  Map<String, Object?> get json => govde! as Map<String, Object?>;
}

/// `"YÖNTEM yol"` → yanıt üreten sahte taşıma; yanıt `Exception` ise
/// fırlatılır. Gerçek ağ yok.
final class SahteTasima implements ApiTransport {
  SahteTasima([Map<String, Object? Function(SahteIstek)>? yanitlar])
    : yanitlar = yanitlar ?? {};

  final Map<String, Object? Function(SahteIstek)> yanitlar;
  final List<SahteIstek> istekler = [];

  @override
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  }) async {
    final istek = SahteIstek('$method $pathTemplate', {
      ...pathParams,
      ...query,
    }, body);
    istekler.add(istek);
    final yanit = yanitlar[istek.yol];
    if (yanit == null) throw StateError('Beklenmeyen istek: ${istek.yol}');
    final deger = yanit(istek);
    if (deger is Exception) throw deger;
    return deger;
  }

  /// [yol]'a giden istekler.
  List<SahteIstek> giden(String yol) => [
    for (final i in istekler)
      if (i.yol == yol) i,
  ];
}

/// Uç yolları.
const String arsivYaz = 'POST /v1/me/e2e/archive';
const String arsivOku =
    'GET /v1/direct-messages/conversations/{conversation_id}/archive';
const String anahtarAl = 'POST /v1/me/e2e/history-key';
const String yenileUc = 'POST /v1/me/e2e/history-key/rotate';
const String paylasimlarUc = 'GET /v1/me/e2e/history-key-shares';
const String paylasimOnay = 'POST /v1/me/e2e/history-key-shares/ack';
const String cihazlarUc = 'GET /v1/users/{user_id}/e2e/devices';
const String istekAc = 'POST /v1/me/e2e/link-requests';
const String istekOku = 'GET /v1/me/e2e/link-requests/{link_request_id}';
const String istekCevapla =
    'POST /v1/me/e2e/link-requests/{link_request_id}/answer';
const String istekTamamla =
    'POST /v1/me/e2e/link-requests/{link_request_id}/complete';

/// [tur] türünde problem.
ApiProblem problem(ProblemType tur, {E2eCihazFarki? fark}) =>
    ApiProblem(type: tur, status: 409, cihazFarki: fark);

/// `E2EDevice` JSON'u (complete cevabı).
Map<String, Object?> cihazJson(
  String id,
  Uint8List k, {
  bool eslesmis = true,
}) => {
  'id': id,
  'device_number': 2,
  'registration_id': 9,
  'identity_key': base64.encode(k),
  'paired': eslesmis,
  'created_at': '2026-11-11T10:00:00Z',
};
