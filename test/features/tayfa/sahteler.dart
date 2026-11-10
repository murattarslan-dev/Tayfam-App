import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';
import 'package:tayfam/features/tayfa/application/olusturma_notifier.dart';
import 'package:tayfam/features/tayfa/data/paylasim.dart';
import 'package:tayfam/features/tayfa/data/tayfa_deposu.dart';

/// Sahte istek kimliği (UUID v4 biçiminde).
const String sahteIstekKimligi = '7d0f3c2a-9b1e-4f6a-8c5d-2e4b6a8c0d1f';

/// Sahte tayfa kodu (sözleşme biçiminde; gerçek değil).
const String sahteKod = 'K7M2Q9XA';

/// Gönderilen bir istek.
final class TayfaIstegi {
  const TayfaIstegi(this.method, this.yol, this.yolParametreleri, this.sorgu,
      this.govde);

  final String method;
  final String yol;
  final Map<String, String> yolParametreleri;
  final Map<String, String> sorgu;
  final Object? govde;

  @override
  String toString() => '$method $yol';
}

/// İsteğe verilen yanıt: değer (JSON) döner ya da [Exception] fırlatılır.
typedef TayfaYaniti = Object? Function(TayfaIstegi istek);

/// Üretilmiş uç sınıflarının sahte taşıması. Yanıtı `"METHOD yol"`
/// anahtarına göre [yanitlar]'dan alır; gerçek ağ yoktur.
final class SahteTayfaTasima implements ApiTransport {
  SahteTayfaTasima([Map<String, TayfaYaniti>? yanitlar])
    : yanitlar = yanitlar ?? {};

  final Map<String, TayfaYaniti> yanitlar;
  final List<TayfaIstegi> istekler = [];

  /// Verilirse yanıt bu tamamlanana kadar bekletilir.
  Completer<void>? bekle;

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
    final istek = TayfaIstegi(method, pathTemplate, pathParams, query, body);
    istekler.add(istek);
    final b = bekle;
    if (b != null) await b.future;
    final yanit = yanitlar['$method $pathTemplate'];
    if (yanit == null) throw StateError('Beklenmeyen istek: $istek');
    final deger = yanit(istek);
    if (deger is Exception) throw deger;
    return deger;
  }

  /// [method] [yol]'a giden istekler.
  List<TayfaIstegi> giden(String method, String yol) => [
    for (final i in istekler)
      if (i.method == method && i.yol == yol) i,
  ];
}

/// Örnek tam tayfa (`Tayfa`) JSON'u.
Map<String, Object?> tayfaJson({
  required String id,
  String ad = 'Klasikçiler',
  int uyeSayisi = 12,
  String durum = 'active',
  String? kod,
  String? askida,
  String? silinme,
}) => {
  'id': id,
  'name': ad,
  'description': '',
  'interests': ['convoy'],
  'join_policy': 'approval',
  'modules': {
    'announcements': true,
    'events': true,
    'qa': true,
    'polls': true,
  },
  'status': durum,
  'suspended_at': ?askida,
  'deletion_at': ?silinme,
  'member_count': uyeSayisi,
  'members_can_create_events': false,
  'join_code': ?kod,
  'created_at': '2026-11-01T10:00:00Z',
  'updated_at': '2026-11-01T10:00:00Z',
};

/// Etkin üyelik satırı (`MyTayfa`) JSON'u.
Map<String, Object?> etkinJson(
  String id, {
  String ad = 'Klasikçiler',
  String rol = 'member',
  String? kod,
}) => {
  'tayfa_id': id,
  'name': ad,
  'role': rol,
  'status': 'active',
  'tayfa': tayfaJson(id: id, ad: ad, kod: kod),
};

/// Bekleyen istek satırı (`MyTayfa`) JSON'u: yalnızca kimlik ve ad.
Map<String, Object?> bekleyenJson(String id, {String ad = 'Kampçılar'}) => {
  'tayfa_id': id,
  'name': ad,
  'role': 'member',
  'status': 'pending',
};

/// `GET /v1/tayfas` yanıtı.
Map<String, Object?> listeJson(
  List<Map<String, Object?>> tayfalar, {
  String? sonraki,
}) => {'tayfas': tayfalar, 'next_page_token': ?sonraki};

/// `GET /v1/tayfas/{tayfa_id}` yanıtı.
Map<String, Object?> gorunumJson(
  String id, {
  String rol = 'member',
  String ad = 'Klasikçiler',
  int uyeSayisi = 12,
  String durum = 'active',
  String? kod,
  String? askida,
  String? silinme,
}) => {
  'tayfa': tayfaJson(
    id: id,
    ad: ad,
    uyeSayisi: uyeSayisi,
    durum: durum,
    kod: kod,
    askida: askida,
    silinme: silinme,
  ),
  'caller_role': rol,
};

/// `Membership` JSON'u.
Map<String, Object?> uyelikJson(String id, {String durum = 'active'}) => {
  'tayfa_id': id,
  'user_id': '00000000-0000-4000-8000-000000000001',
  'role': 'member',
  'status': durum,
};

/// Paylaşılan ve kopyalanan metinleri kaydeden sahte paylaşıcı.
final class SahtePaylasici implements Paylasici {
  final List<String> paylasilan = [];
  final List<String> kopyalanan = [];

  @override
  Future<void> paylas(String metin, {Rect? konum}) async {
    paylasilan.add(metin);
  }

  @override
  Future<void> kopyala(String metin) async {
    kopyalanan.add(metin);
  }
}

/// Tayfa özelliğinin sahte bağımlılıkları için override'lar. Yanıt
/// verilmezse `GET /v1/tayfas` boş, `GET /v1/tayfas/{tayfa_id}` istenen
/// kimlikle örnek bir tayfa döner.
List<Override> tayfaOverridelari({
  SahteTayfaTasima? tasima,
  SonTayfaDeposu? sonTayfa,
  Paylasici? paylasici,
}) {
  final t = tasima ?? SahteTayfaTasima();
  t.yanitlar
    ..putIfAbsent('GET /v1/tayfas', () => (_) => listeJson(const []))
    ..putIfAbsent(
      'GET /v1/tayfas/{tayfa_id}',
      () =>
          (i) => gorunumJson(i.yolParametreleri['tayfa_id']!),
    );
  return [
    tayfaDeposuProvider.overrideWithValue(TayfaDeposu(t)),
    sonTayfaDeposuProvider.overrideWithValue(
      sonTayfa ?? BellekSonTayfaDeposu(),
    ),
    paylasiciProvider.overrideWithValue(paylasici ?? SahtePaylasici()),
    istekKimligiUreticisiProvider.overrideWithValue(() => sahteIstekKimligi),
  ];
}

/// Örnek bir `Tayfa` modeli.
Tayfa ornekTayfa(String id, {String? kod}) =>
    Tayfa.fromJson(tayfaJson(id: id, kod: kod));
