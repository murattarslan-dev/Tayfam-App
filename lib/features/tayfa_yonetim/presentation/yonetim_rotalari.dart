import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/ayarlar_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/bilgiler_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/davetler_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/katilim_istekleri_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/uyeler_ekrani.dart';

/// Tayfa yönetiminin rotaları (ADR-0018 §1). `/t/:tayfaId` rotasının
/// altına eklenir: `ayarlar`, `ayarlar/istekler`, `ayarlar/uyeler`,
/// `ayarlar/bilgiler`, `ayarlar/davetler`. [ekRotalar] başka paketlerin
/// `ayarlar/` altındaki ekranlarıdır (ör. moderasyon kuyruğu).
///
/// Ekranlara rol bakılmadan gidilebilir; içeriği ve işlemleri sunucu
/// yetkilendirir (kesin kural 5).
List<RouteBase> tayfaYonetimRotalari({List<RouteBase> ekRotalar = const []}) =>
    [
      GoRoute(
        path: Adresler.tayfaAyarlariYolu,
        builder: (context, state) =>
            TayfaAyarlariEkrani(tayfaId: _tayfaId(state)),
        routes: [
          GoRoute(
            path: AyarYollari.istekler,
            builder: (context, state) =>
                KatilimIstekleriEkrani(tayfaId: _tayfaId(state)),
          ),
          GoRoute(
            path: AyarYollari.uyeler,
            builder: (context, state) => UyelerEkrani(tayfaId: _tayfaId(state)),
          ),
          GoRoute(
            path: AyarYollari.bilgiler,
            builder: (context, state) =>
                TayfaBilgileriEkrani(tayfaId: _tayfaId(state)),
          ),
          GoRoute(
            path: AyarYollari.davetler,
            builder: (context, state) =>
                DavetlerEkrani(tayfaId: _tayfaId(state)),
          ),
          ...ekRotalar,
        ],
      ),
    ];

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi]!;
