import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir etkinliğin bir hedef bileşeni: bileşen uçlarındaki
/// `{component_key}` ([anahtar]) ve tanımdaki bağlı ölçümün anahtarı
/// ([olcumAnahtari], `measure` parametresi). Bağlı ölçüm değişince canlı
/// olay ölçümün anahtarıyla gelir; hedef onunla da yeniden okunur.
typedef HedefKimligi = ({
  String tayfaId,
  String etkinlikId,
  String anahtar,
  String? olcumAnahtari,
});

/// Sözleşmedeki hedef üst sınırı (`EventGoalTargetRequest.target`).
const double hedefEnCok = 1000000000;

/// Yüzde hesabındaki kayan nokta payı ([hedefYuzdesi]).
const double _yuzdePayi = 1e-9;

/// Formdaki değerin anahtarı ([hedefAlani]).
const String _degerAnahtari = 'target';

/// [hedef]'in ondalık basamağı (sözleşmenin 0–3 aralığına çekilir).
int hedefBasamagi(EventGoal hedef) =>
    hedef.decimals.clamp(0, olcumBasamakEnCok);

/// [hedef]'in basamağındaki en küçük artı değer (`exclusiveMinimum: 0`;
/// sunucu değeri bu basamağa yuvarlar): 0 basamakta 1, 2 basamakta 0,01.
double hedefEnAz(EventGoal hedef) {
  final basamak = hedefBasamagi(hedef);
  return basamak == 0 ? 1 : double.parse('0.${'0' * (basamak - 1)}1');
}

/// Hedefin formdaki alanı: birim ve ondalık basamak bağlı ölçümden; değer
/// sıfırdan büyük olmalı. Doğrulama tek alan çizicinin kurallarıyla
/// yapılır ([alanHatalari]); ölçümün üst sınırını sunucu denetler.
CatalogField hedefAlani(EventGoal hedef) {
  final basamak = hedefBasamagi(hedef);
  return CatalogField(
    key: _degerAnahtari,
    kind: basamak == 0 ? 'integer' : 'decimal',
    required_: true,
    labels: const {},
    min: hedefEnAz(hedef),
    max: hedefEnCok,
    decimals: basamak == 0 ? null : basamak,
    unit: hedef.unit,
  );
}

/// [deger]'in birimiyle gösterilen hali (`100 km`); birim tanınmıyorsa
/// yalnızca sayı. Sayı Türkçe ondalık ayracıyla, basamağa yuvarlanır.
String hedefDegeriMetni(AppLocalizations m, EventGoal hedef, double deger) {
  final sayi = olcumSayisi(m, deger, hedefBasamagi(hedef));
  final birim = katalogBirimAdi(m, hedef.unit);
  return birim == null ? sayi : m.katalog_birimli_deger(sayi, birim);
}

/// İlerlemenin yüzdesi, aşağı yuvarlanmış (hedefe ulaşmadan %100
/// görünmesin); hedefi aşınca 100'ü geçebilir. Hedef ya da değer yoksa
/// `null`.
int? hedefYuzdesi(EventGoal hedef) {
  final hedefDeger = hedef.target;
  final mevcut = hedef.current;
  if (hedefDeger == null || mevcut == null || hedefDeger <= 0) return null;
  if (mevcut <= 0) return 0;
  final yuzde = mevcut * 100 / hedefDeger;
  if (!yuzde.isFinite) return null;
  // Kayan nokta artığı (35,999…) yüzdeyi bir eksik göstermesin.
  return (yuzde + _yuzdePayi).floor();
}

/// Çubuğun doluluk oranı (0–1); hedefe ulaşıldıysa tam dolu.
double hedefOrani(EventGoal hedef) {
  if (hedef.reached) return 1;
  final yuzde = hedefYuzdesi(hedef);
  if (yuzde == null) return 0;
  return (yuzde / 100).clamp(0.0, 1.0);
}

/// Formdaki [metin]'den gönderilecek hedef; geçersizse hata. Virgül de
/// nokta da ondalık ayracı kabul edilir.
({double? deger, AlanHatasi? hata}) hedefGirdisiniOku(
  EventGoal hedef,
  String metin,
) {
  final alan = hedefAlani(hedef);
  final degerler = {_degerAnahtari: metin};
  final hata = alanHatalari([alan], degerler)[_degerAnahtari];
  if (hata != null) return (deger: null, hata: hata);
  final sayi = alanGovdesi([alan], degerler)[_degerAnahtari];
  if (sayi is! num) return (deger: null, hata: AlanHatasi.zorunlu);
  return (deger: sayi.toDouble(), hata: null);
}

/// Hedefin yeniden okunmasını gerektiren hatalar: durumu etkinlikle ya da
/// tür tanımıyla değişmiş.
const Set<ProblemType> _bayatHedefHatalari = {
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
};

/// Hedef bileşeninin durumu (`GET …/components/{component_key}/goal`;
/// Tayfam-Api #246), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır
/// (ADR-0024 §5): hedef ya da bağlı ölçüm değişince ve etkinliğin durumu
/// değişince REST'ten yeniden okunur.
///
/// İlerleme sunucuda bağlı ölçümün kaydedilmiş değerinden hesaplanır;
/// hassas ölçümde değerleri göremeyene `progress_hidden` döner ve
/// ilerleme hiç gelmez. Yalnızca bellekte tutulur ve loglanmaz
/// (ADR-0006). Yetki sunucudadır; istemci düğmeleri sadeleştirir (kesin
/// kural 5).
class HedefNotifier extends AsyncNotifier<EventGoal> {
  HedefNotifier(this.kimlik);

  final HedefKimligi kimlik;

  @override
  Future<EventGoal> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    final olcumAnahtari = kimlik.olcumAnahtari;
    if (olcumAnahtari != null && olcumAnahtari != kimlik.anahtar) {
      bilesenDegisiminiIzle(ref, etkinlik, olcumAnahtari);
    }
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .hedef(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
  }

  /// Baştan okur ("Tekrar dene").
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu bölümde gösterilir.
    }
  }

  /// Etkinliğin hedefini [deger] yapar.
  Future<Object?> hedefiKoy(double deger) => _yaz(
    (d) => d.hedefiKoy(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      deger,
    ),
  );

  /// Etkinliğin hedefini kaldırır (tanımdaki varsayılan geri gelir).
  Future<Object?> hedefiKaldir() => _yaz(
    (d) => d.hedefiKaldir(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Hedef bayatlamışsa (donmuş, iptal, yetki değişmiş)
  /// yeniden okunur.
  Future<Object?> _yaz(
    Future<EventGoal> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final hedef = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(hedef);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatHedefHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir hedef bileşeninin durumu. Hata otomatik yeniden denenmez.
final hedefProvider = AsyncNotifierProvider.autoDispose
    .family<HedefNotifier, EventGoal, HedefKimligi>(
      HedefNotifier.new,
      name: 'hedefProvider',
      retry: yenidenDenemeYok,
    );
