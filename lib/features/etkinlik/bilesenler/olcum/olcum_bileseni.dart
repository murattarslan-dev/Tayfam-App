import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ölçüm bileşeni (`measure`; Tayfam-Api ADR-0025 §4, §5, ADR-0037 §2,
/// §3, #245; App ADR-0024 §3, ADR-0031 §2): birimli bir değer. Bir
/// etkinlikte birden çok ölçüm olabilir (yürüyüşte `distance` km ve
/// `elevation_gain` m); her biri tanımdaki `key`'iyle ayrı bölümdür.
///
/// - **Toplam** (`scope: total`): etkinlik başına tek değer; organizatör,
///   moderatör ve yönetici girer, düzeltir, kaldırır. Tanımda
///   `prefill_from` varsa etkinlik bitince planlanan değer **önerilen**
///   olarak gelir (`suggested`); yalnızca yazabilene "Önerilen: 12,4 km —
///   Onayla / Düzelt" gösterilir (ADR-0031 §2). Onaylanmamış öneri
///   istatistiğe girmez; başkasına gösterilmez.
/// - **Kişisel** (`scope: personal`): katılımcı başına değer.
///   `entered_by: self` ise katılımı doğrulanmış kişi kendi değerini,
///   `entered_by: organizer` ise organizatör ve atanmış hakem herkesinkini
///   girer. Hassas ölçümde (`sensitive`) herkes yalnızca kendi değerini
///   görür (sunucu başkasınınkini döndürmez).
///
/// Birim, sınırlar ve ondalık basamak ölçümün kendisinden okunur; birimin
/// adı çeviri dosyasındadır. Sayılar Türkçe ondalık ayracıyla gösterilir
/// ve girilir. Değer etkinlik başlamadan girilemez. Düğmeleri gizlemek
/// kolaylıktır; yetkiyi sunucu verir, hatası her durumda gösterilir
/// (kesin kural 5).
///
/// Değerler etkinlik oluşturulurken yazılmaz; sihirbazda form bölümü
/// yoktur.
final class OlcumBileseni extends KayitliBilesen {
  const OlcumBileseni() : super('measure');

  @override
  String ad(AppLocalizations m) => m.bilesen_measure_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return OlcumBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
      hassas: b.params.mantik('sensitive'),
    );
  }
}

/// Bir ölçüm işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef OlcumIslemi = Future<Object?> Function(OlcumNotifier olcum);

/// Ölçüm bileşeninin detaydaki bölümü: başlık ve toplam kartı ya da
/// kişisel değerler. Okunurken yer tutmaz; okunamazsa kısa hata ve
/// "Tekrar dene".
class OlcumBolumu extends ConsumerStatefulWidget {
  const OlcumBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
    this.hassas = false,
  });

  final OlcumKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  /// Tanımdaki `sensitive`: değerleri herkes yalnızca kendisininkini görür.
  final bool hassas;

  @override
  ConsumerState<OlcumBolumu> createState() => _OlcumBolumuState();
}

class _OlcumBolumuState extends ConsumerState<OlcumBolumu> {
  bool _mesgul = false;

  OlcumNotifier get _notifier =>
      ref.read(olcumProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir (bayat ölçüm
  /// ayrıca yeniden okunur). Aynı anda tek işlem yapılır.
  Future<void> _calistir(OlcumIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  /// Değer formunu açar. [kisi] verilirse o kişinin değeri, [kisiSec] ise
  /// kişi formda seçilir; ikisi de yoksa toplam yazılır.
  Future<void> _formuAc(
    EventMeasure olcum, {
    required String baslik,
    double? ilkDeger,
    String? kisi,
    bool kisiSec = false,
  }) => aracFormuAc<void>(
    context,
    (_) => OlcumFormu(
      olcum: olcum,
      baslik: baslik,
      ilkDeger: ilkDeger,
      kisiSecimi: kisiSec
          ? (
              tayfaId: widget.kimlik.tayfaId,
              etkinlikId: widget.kimlik.etkinlikId,
              durum: ListEventAttendeesStatus.going,
            )
          : null,
      gonder: (secilen, deger) {
        final hedef = kisi ?? secilen;
        return hedef == null
            ? _notifier.toplamiYaz(deger)
            : _notifier.degeriYaz(hedef, deger);
      },
    ),
  );

  Future<void> _kaldir(OlcumIslemi islem) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_measure_kaldir_onay,
      eylem: m.bilesen_measure_kaldir,
    );
    if (!onay || !mounted) return;
    await _calistir(islem);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_measure_ad,
    );
    final okunan = ref.watch(olcumProvider(widget.kimlik));
    final olcum = okunan.value;
    if (olcum == null) {
      if (!okunan.hasError) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baslik,
          HataSatiri.hatadan(okunan.error!),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: m.etkinlik_tekrar_dene,
              onPressed: () => unawaited(_notifier.yenile()),
            ),
          ),
        ],
      );
    }
    final etkinlik = widget.etkinlik;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final iptal = iptalEdildi(etkinlik);
    final baslamadi = !iptal && simdi.isBefore(etkinlik.startsAt);
    final bos = baslamadi ? m.bilesen_measure_baslamadi : m.bilesen_measure_yok;
    final icerik = switch (olcum.scope) {
      EventMeasureScope.total => _toplam(olcum, bos),
      EventMeasureScope.personal => _kisisel(olcum, bos, iptal, baslamadi),
      EventMeasureScope.unknown => <Widget>[
        AracBilgisi(metin: m.bilesen_measure_guncelle),
      ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [baslik, ...icerik],
    );
  }

  List<Widget> _toplam(EventMeasure olcum, String bos) {
    final m = AppLocalizations.of(context);
    final toplam = olcum.total;
    final onerilen = olcum.suggested;
    if (toplam == null && onerilen != null && olcum.callerCanEdit) {
      return [
        OnerilenOlcumKarti(
          metin: m.bilesen_measure_onerilen(
            olcumDegeriMetni(m, olcum, onerilen),
          ),
          onOnayla: _mesgul
              ? null
              : () => unawaited(_calistir((o) => o.toplamiYaz(onerilen))),
          onDuzelt: _mesgul
              ? null
              : () => unawaited(
                  _formuAc(
                    olcum,
                    baslik: m.bilesen_measure_duzelt,
                    ilkDeger: onerilen,
                  ),
                ),
        ),
      ];
    }
    return [
      OlcumKarti(
        metin: toplam == null ? bos : olcumDegeriMetni(m, olcum, toplam),
        dolu: toplam != null,
        eylemler: [
          if (olcum.callerCanEdit && toplam == null)
            CerceveliHapEylem(
              etiket: m.bilesen_measure_gir,
              ikon: Icons.add,
              onPressed: _mesgul
                  ? null
                  : () => unawaited(
                      _formuAc(olcum, baslik: m.bilesen_measure_gir),
                    ),
            ),
          if (olcum.callerCanEdit && toplam != null) ...[
            AracIkonDugmesi(
              ipucu: m.bilesen_measure_duzelt,
              ikon: Icons.edit_outlined,
              onPressed: _mesgul
                  ? null
                  : () => unawaited(
                      _formuAc(
                        olcum,
                        baslik: m.bilesen_measure_duzelt,
                        ilkDeger: toplam,
                      ),
                    ),
            ),
            AracIkonDugmesi(
              ipucu: m.bilesen_measure_kaldir,
              ikon: Icons.delete_outline,
              onPressed: _mesgul
                  ? null
                  : () => unawaited(_kaldir((o) => o.toplamiKaldir())),
            ),
          ],
        ],
      ),
    ];
  }

  List<Widget> _kisisel(
    EventMeasure olcum,
    String bos,
    bool iptal,
    bool baslamadi,
  ) {
    final m = AppLocalizations.of(context);
    final ben = ref.watch(kendiKimligimProvider).value;
    final etkinlik = widget.etkinlik;
    final kendisi = olcum.enteredBy == EventMeasureEnteredBy.self;
    final benimki = olcumKaydi(olcum, ben);
    final kendiDegeriniGirer =
        kendisi && olcum.callerCanEdit && ben != null && benimki == null;
    final herkesinkiniGirer =
        olcum.callerCanEdit &&
        olcum.enteredBy == EventMeasureEnteredBy.organizer;
    // Kendi değerini giren ölçümde, gelen ama katılımı doğrulanmamış kişiye
    // neden giremediği söylenir.
    final dogrulanmadi =
        kendisi &&
        !olcum.callerCanEdit &&
        !iptal &&
        !baslamadi &&
        etkinlik.callerRsvp == RsvpStatus.going &&
        !katilimDogrulandi(etkinlik);
    return [
      AracListesi(
        bos: bos,
        satirlar: [
          for (final kayit in olcum.entries)
            OlcumSatiri(
              key: ValueKey(kayit.userId),
              kullaniciId: kayit.userId,
              deger: olcumDegeriMetni(m, olcum, kayit.value),
              degisebilir: olcumKaydiDegisebilir(olcum, kayit, ben),
              mesgul: _mesgul,
              onDuzelt: () => unawaited(
                _formuAc(
                  olcum,
                  baslik: m.bilesen_measure_duzelt,
                  ilkDeger: kayit.value,
                  kisi: kayit.userId,
                ),
              ),
              onKaldir: () =>
                  unawaited(_kaldir((o) => o.degeriKaldir(kayit.userId))),
            ),
        ],
      ),
      if (kendiDegeriniGirer && ben != null) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracDugmesi(
          etiket: m.bilesen_measure_kendi_gir,
          ikon: Icons.add,
          onPressed: _mesgul
              ? null
              : () => unawaited(
                  _formuAc(
                    olcum,
                    baslik: m.bilesen_measure_kendi_gir,
                    kisi: ben,
                  ),
                ),
        ),
      ],
      if (herkesinkiniGirer) ...[
        const SizedBox(height: TayfamSpacing.s12),
        AracDugmesi(
          etiket: m.bilesen_measure_kisi_ekle,
          ikon: Icons.add,
          onPressed: _mesgul
              ? null
              : () => unawaited(
                  _formuAc(
                    olcum,
                    baslik: m.bilesen_measure_kisi_ekle,
                    kisiSec: true,
                  ),
                ),
        ),
      ],
      if (dogrulanmadi) ...[
        const SizedBox(height: TayfamSpacing.s8),
        AracBilgisi(metin: m.bilesen_measure_katilim_notu),
      ],
      if (widget.hassas) ...[
        const SizedBox(height: TayfamSpacing.s8),
        AracBilgisi(metin: m.bilesen_measure_hassas_notu),
      ],
    ];
  }
}

/// Toplam ölçümün kartı: değer (ya da boş metin) ve sağında eylemler; dar
/// ekranda ve büyük yazıda eylemler alt satıra iner.
class OlcumKarti extends StatelessWidget {
  const OlcumKarti({
    super.key,
    required this.metin,
    required this.dolu,
    this.eylemler = const [],
  });

  /// Değer ("12,4 km") ya da boş durum metni.
  final String metin;

  /// Değer var mı (yoksa [metin] ikincil biçimde gösterilir).
  final bool dolu;

  final List<Widget> eylemler;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return _Kart(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Süs: anlam yanındaki metindedir.
              ExcludeSemantics(
                child: Icon(
                  Icons.straighten_outlined,
                  size: TayfamSizes.ikon,
                  color: r.tintMarkaUstu,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Flexible(
                child: Text(
                  metin,
                  style: dolu
                      ? context.yazi.titleLarge
                      : context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
                ),
              ),
            ],
          ),
          if (eylemler.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: eylemler),
        ],
      ),
    );
  }
}

/// Önerilen değerin kartı (ADR-0031 §2): "Önerilen: 12,4 km", kısa
/// açıklama ve "Onayla" / "Düzelt". Yalnızca değeri yazabilene çizilir.
class OnerilenOlcumKarti extends StatelessWidget {
  const OnerilenOlcumKarti({
    super.key,
    required this.metin,
    required this.onOnayla,
    required this.onDuzelt,
  });

  final String metin;

  /// `null`: düğmeler geçici olarak kapalı (kayıt sürüyor).
  final VoidCallback? onOnayla;
  final VoidCallback? onDuzelt;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return _Kart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.straighten_outlined,
                  size: TayfamSizes.ikon,
                  color: r.tintMarkaUstu,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(child: Text(metin, style: context.yazi.titleMedium)),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s4),
          AracBilgisi(metin: m.bilesen_measure_onerilen_notu),
          const SizedBox(height: TayfamSpacing.s12),
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              CerceveliHapEylem(
                etiket: m.bilesen_measure_onayla,
                ikon: Icons.check,
                onPressed: onOnayla,
              ),
              CerceveliHapEylem(
                etiket: m.bilesen_measure_duzelt,
                ikon: Icons.edit_outlined,
                notr: true,
                onPressed: onDuzelt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bir kişinin kişisel değeri: adı (dokununca profili), değeri;
/// [degisebilir] ise "Düzelt" ve "Değeri kaldır".
class OlcumSatiri extends StatelessWidget {
  const OlcumSatiri({
    super.key,
    required this.kullaniciId,
    required this.deger,
    required this.degisebilir,
    required this.mesgul,
    required this.onDuzelt,
    required this.onKaldir,
  });

  final String kullaniciId;

  /// Birimiyle değer ("12,4 km").
  final String deger;

  final bool degisebilir;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onDuzelt;
  final VoidCallback onKaldir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TayfamSpacing.s8,
            children: [
              KisiyeDokun(
                kullaniciId: kullaniciId,
                child: KullaniciAdiMetni(
                  kullaniciId: kullaniciId,
                  style: context.yazi.bodyLarge,
                ),
              ),
              Text(deger, style: context.yazi.titleSmall),
            ],
          ),
        ),
        if (degisebilir) ...[
          AracIkonDugmesi(
            ipucu: m.bilesen_measure_duzelt,
            ikon: Icons.edit_outlined,
            onPressed: mesgul ? null : onDuzelt,
          ),
          AracIkonDugmesi(
            ipucu: m.bilesen_measure_kaldir,
            ikon: Icons.delete_outline,
            onPressed: mesgul ? null : onKaldir,
          ),
        ],
      ],
    );
  }
}

/// Ölçüm kartlarının zemini (rota kartıyla aynı: kart rengi, ince kenar).
class _Kart extends StatelessWidget {
  const _Kart({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: child,
      ),
    );
  }
}
