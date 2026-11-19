import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir etkinliğin bir ölçüm bileşeni: bileşen uçlarındaki
/// `{component_key}` ile (bir etkinlikte birden çok ölçüm olabilir:
/// yürüyüşte `distance` ve `elevation_gain`).
typedef OlcumKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Sözleşmedeki ondalık basamak sınırı (`EventMeasure.decimals`: 0–3).
const int olcumBasamakEnCok = 3;

/// Formdaki değerin anahtarı ([olcumAlani]).
const String _degerAnahtari = 'value';

/// [olcum]'un ondalık basamağı (sözleşmenin 0–3 aralığına çekilir).
int olcumBasamagi(EventMeasure olcum) =>
    olcum.decimals.clamp(0, olcumBasamakEnCok);

/// Ölçüm değerinin formdaki alanı: birim, sınırlar ve ondalık basamak
/// ölçümün kendisinden (sunucu tanımdan okur). Basamağı 0 olan ölçüm tam
/// sayıdır. Doğrulama tek alan çizicinin kurallarıyla yapılır
/// ([alanHatalari]); son söz sunucunundur.
CatalogField olcumAlani(EventMeasure olcum) {
  final basamak = olcumBasamagi(olcum);
  return CatalogField(
    key: _degerAnahtari,
    kind: basamak == 0 ? 'integer' : 'decimal',
    required_: true,
    labels: const {},
    min: olcum.min,
    max: olcum.max,
    decimals: basamak == 0 ? null : basamak,
    unit: olcum.unit,
  );
}

/// [deger]'in [basamak]'a yuvarlanmış sade yazımı, Türkçe ondalık
/// ayracıyla (`12.4` → `12,4`; `12.0` → `12`).
String olcumSayisi(AppLocalizations m, double deger, int basamak) {
  if (!deger.isFinite) return '';
  final yuvarlak = double.parse(
    deger.toStringAsFixed(basamak.clamp(0, olcumBasamakEnCok)),
  );
  return sayiMetni(yuvarlak).replaceAll('.', m.katalog_ondalik_ayraci);
}

/// [deger]'in birimiyle gösterilen hali (`12,4 km`); birim tanınmıyorsa
/// yalnızca sayı.
String olcumDegeriMetni(AppLocalizations m, EventMeasure olcum, double deger) {
  final sayi = olcumSayisi(m, deger, olcumBasamagi(olcum));
  final birim = katalogBirimAdi(m, olcum.unit);
  return birim == null ? sayi : m.katalog_birimli_deger(sayi, birim);
}

/// Formdaki değerin hata metni (sınırlar Türkçe ondalık ayracıyla).
String olcumHataMetni(AppLocalizations m, EventMeasure olcum, AlanHatasi hata) {
  final basamak = olcumBasamagi(olcum);
  return switch (hata) {
    AlanHatasi.aralik => m.katalog_alan_aralik(
      olcumSayisi(m, olcum.min, basamak),
      olcumSayisi(m, olcum.max, basamak),
    ),
    AlanHatasi.basamak => m.katalog_alan_basamak(basamak),
    AlanHatasi.zorunlu => m.katalog_alan_zorunlu,
    _ => m.katalog_alan_sayi,
  };
}

/// Formdaki [metin]'den gönderilecek değer; geçersizse hata. Virgül de
/// nokta da ondalık ayracı kabul edilir.
({double? deger, AlanHatasi? hata}) olcumGirdisiniOku(
  EventMeasure olcum,
  String metin,
) {
  final alan = olcumAlani(olcum);
  final degerler = {_degerAnahtari: metin};
  final hata = alanHatalari([alan], degerler)[_degerAnahtari];
  if (hata != null) return (deger: null, hata: hata);
  final sayi = alanGovdesi([alan], degerler)[_degerAnahtari];
  if (sayi is! num) return (deger: null, hata: AlanHatasi.zorunlu);
  return (deger: sayi.toDouble(), hata: null);
}

/// Düzeltmede formun ilk metni: kayıtlı değer, Türkçe ondalık ayracıyla.
String olcumGirdisi(AppLocalizations m, EventMeasure olcum, double? deger) =>
    deger == null ? '' : olcumSayisi(m, deger, olcumBasamagi(olcum));

/// [kullaniciId]'nin kişisel değeri; yoksa `null`.
EventMeasureEntry? olcumKaydi(EventMeasure olcum, String? kullaniciId) {
  if (kullaniciId == null) return null;
  for (final kayit in olcum.entries) {
    if (kayit.userId == kullaniciId) return kayit;
  }
  return null;
}

/// Çağıran [kayit]'ı değiştirebilir mi: yazabiliyorsa
/// (`caller_can_edit`) ve değeri organizatör giriyorsa herkesinkini, kişi
/// kendisi giriyorsa yalnızca kendisininkini. Kolaylıktır; yetki
/// sunucudadır (kesin kural 5).
bool olcumKaydiDegisebilir(
  EventMeasure olcum,
  EventMeasureEntry kayit,
  String? ben,
) =>
    olcum.callerCanEdit &&
    (olcum.enteredBy == EventMeasureEnteredBy.organizer ||
        (ben != null && kayit.userId == ben));

/// Ölçümün yeniden okunmasını gerektiren hatalar: ölçümün durumu
/// etkinlikle, katılımla ya da tür tanımıyla değişmiş.
const Set<ProblemType> _bayatOlcumHatalari = {
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.measurementNotStarted,
  ProblemType.measurementScope,
  ProblemType.notAttended,
};

/// Ölçüm bileşeninin değerleri (`GET …/components/{component_key}/measure`;
/// Tayfam-Api #245), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır
/// (ADR-0024 §5): bileşen değişince ve katılım durumun değişince REST'ten
/// yeniden okunur (`caller_can_edit` doğrulanmış katılıma bağlı olabilir).
///
/// Değerler yalnızca bellekte tutulur ve loglanmaz (ADR-0006). Hassas
/// ölçümde sunucu yalnızca kişinin kendi değerini döndürür. Yazan her uç
/// ölçümün güncel halini döner; durum onunla değişir. Yetki sunucudadır;
/// istemci yalnızca düğmeleri sadeleştirir (kesin kural 5).
class OlcumNotifier extends AsyncNotifier<EventMeasure> {
  OlcumNotifier(this.kimlik);

  final OlcumKimligi kimlik;

  @override
  Future<EventMeasure> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(
      etkinlikDetayProvider(etkinlik).select(
        (d) => (d.value?.callerAttendance, d.value?.status),
      ),
    );
    return ref
        .read(etkinlikDeposuProvider)
        .olcum(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Toplamı [deger] yapar (önerilen değeri onaylamak da budur).
  Future<Object?> toplamiYaz(double deger) => _yaz(
    (d) => d.olcumToplamiYaz(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      deger,
    ),
  );

  /// Toplamı kaldırır.
  Future<Object?> toplamiKaldir() => _yaz(
    (d) => d.olcumToplaminiKaldir(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
    ),
  );

  /// [kullaniciId]'nin kişisel değerini [deger] yapar.
  Future<Object?> degeriYaz(String kullaniciId, double deger) => _yaz(
    (d) => d.olcumDegeriYaz(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      kullaniciId,
      deger,
    ),
  );

  /// [kullaniciId]'nin kişisel değerini kaldırır.
  Future<Object?> degeriKaldir(String kullaniciId) => _yaz(
    (d) => d.olcumDegeriniKaldir(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      kullaniciId,
    ),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Ölçüm bayatlamışsa (donmuş, iptal, katılım değişmiş)
  /// yeniden okunur.
  Future<Object?> _yaz(
    Future<EventMeasure> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final olcum = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(olcum);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatOlcumHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir ölçüm bileşeninin durumu. Hata otomatik yeniden denenmez.
final olcumProvider = AsyncNotifierProvider.autoDispose
    .family<OlcumNotifier, EventMeasure, OlcumKimligi>(
      OlcumNotifier.new,
      name: 'olcumProvider',
      retry: yenidenDenemeYok,
    );
