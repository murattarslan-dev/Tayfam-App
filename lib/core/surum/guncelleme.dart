import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/client_config_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/surum/surum.dart';
import 'package:tayfam/core/surum/uygulama_surumu.dart';

/// Açılıştaki sürüm denetimi (ADR-0012 §1.1).
abstract interface class SurumDenetleyici {
  /// Uygulamanın sürümü platformun `min_supported_version`'ının altındaysa
  /// `true`. Uç ulaşılamazsa, yanıt bozuksa ya da sürüm bilinmiyorsa
  /// `false`: açılış engellenmez.
  Future<bool> guncellemeGerekliMi();
}

/// `GET /v1/client-config` ile denetler.
final class ClientConfigSurumDenetleyici implements SurumDenetleyici {
  ClientConfigSurumDenetleyici({
    required this._api,
    required this._surum,
    required this._istemciAdi,
  });

  final ClientConfigApi _api;
  final String _surum;
  final String _istemciAdi;

  @override
  Future<bool> guncellemeGerekliMi() async {
    final surum = Surum.coz(_surum);
    if (surum == null) return false;
    final ClientConfig yapilandirma;
    try {
      yapilandirma = await _api.getClientConfig();
    } on ApiHatasi {
      return false;
    } on FormatException {
      return false;
    }
    final platform = switch (_istemciAdi) {
      'ios' => yapilandirma.platforms.ios,
      'web' => yapilandirma.platforms.web,
      _ => yapilandirma.platforms.android,
    };
    final enDusuk = Surum.coz(platform?.minSupportedVersion ?? '');
    if (enDusuk == null) return false;
    return surum < enDusuk;
  }
}

/// Uygulamanın sürüm denetleyicisi; testlerde sahtesiyle değiştirilir.
final surumDenetleyiciProvider = Provider<SurumDenetleyici>(
  (ref) => ClientConfigSurumDenetleyici(
    api: ClientConfigApi(ref.watch(httpTasimaProvider)),
    surum: uygulamaSurumu,
    istemciAdi: istemciAdi(web: kIsWeb, platform: defaultTargetPlatform),
  ),
  name: 'surumDenetleyiciProvider',
);

/// "Güncelleme gerekli" durumu (ADR-0012 §1.1).
///
/// İlk okunduğunda açılış denetimini başlatır; denetim bitene kadar ve uç
/// ulaşılamazsa `false` kalır. Herhangi bir istek `client-outdated` alırsa
/// da `true` olur. Bir kez `true` olunca uygulama süreci boyunca öyle kalır;
/// başka bir ekrana geçilemez.
class GuncellemeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final tasima = ref.watch(httpTasimaProvider);
    final abonelik = tasima.eskiSurumOlaylari.listen((_) => gerekli());
    ref.onDispose(abonelik.cancel);
    unawaited(_denetle());
    return false;
  }

  Future<void> _denetle() async {
    final denetleyici = ref.read(surumDenetleyiciProvider);
    final gerekiyor = await denetleyici.guncellemeGerekliMi();
    if (gerekiyor && ref.mounted) gerekli();
  }

  /// Güncelleme gerekli: yönlendirici "Güncelleme gerekli" ekranına geçer.
  void gerekli() => state = true;
}

/// Uygulama boyunca yaşayan güncelleme durumu (kalıcı).
final guncellemeProvider = NotifierProvider<GuncellemeNotifier, bool>(
  GuncellemeNotifier.new,
  name: 'guncellemeProvider',
);
