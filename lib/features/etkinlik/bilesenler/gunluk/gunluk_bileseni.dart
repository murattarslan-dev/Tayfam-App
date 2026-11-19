import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/gunluk/gunluk_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/gunluk/kayit_formu.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart'
    show etkinlikZamani;
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart'
    show ozetAyraci;
import 'package:tayfam/l10n/app_localizations.dart';

/// Günlük bileşeni (`log`; Tayfam-Api ADR-0025 §4, ADR-0037 §3, #243; App
/// ADR-0024 §3): etkinlikte tutulan kayıtlar (av, kitap, kuş, zirve…).
/// Kaydın alanları bileşenin `fields` parametresindedir ve tek alan
/// çiziciyle ([KatalogAlanlari]) çizilir. Balıkçılığın Faz 1 av günlüğü
/// `catches` anahtarlı günlüktür.
///
/// - Kayıt eklemek için katılım doğrulanmış olmalıdır; düğme sunucunun
///   `caller_can_add`'ine göre görünür. Kendi kaydını yazma penceresinde,
///   moderatör ve yönetici herkesinkini her zaman çıkarır
///   (`caller_can_remove`).
/// - Konum gizliliği kayıt başınadır ve sunucunundur: bir kaydın yeri
///   yalnızca sunucu döndürdüyse gösterilir. Yer, kişinin haritada bilerek
///   işaretlediği noktadır (içerik); cihazın anlık konumu kullanılmaz,
///   saklanmaz, loglanmaz (kesin kural 3).
///
/// Kayıtlar etkinlik oluşturulurken yazılmaz; sihirbazda form bölümü
/// yoktur.
final class GunlukBileseni extends KayitliBilesen {
  const GunlukBileseni() : super('log');

  @override
  String ad(AppLocalizations m) => m.bilesen_log_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return GunlukBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      alanlar: gunlukAlanlari(b.params),
      etkinlik: etkinlik,
    );
  }
}

/// Günlük bileşeninin detaydaki bölümü: başlık ("Kayıt ekle"), kayıtlar
/// ve "Daha fazla göster". Okunurken yer tutmaz; okunamazsa kısa hata ve
/// "Tekrar dene".
class GunlukBolumu extends ConsumerStatefulWidget {
  const GunlukBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.alanlar,
    required this.etkinlik,
  });

  final GunlukKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  /// Kaydın alanları (bileşenin `fields` parametresi).
  final List<CatalogField> alanlar;

  final Event etkinlik;

  @override
  ConsumerState<GunlukBolumu> createState() => _GunlukBolumuState();
}

class _GunlukBolumuState extends ConsumerState<GunlukBolumu> {
  bool _mesgul = false;

  GunlukNotifier get _notifier =>
      ref.read(gunlukProvider(widget.kimlik).notifier);

  Future<void> _ekle(EventLogEntryList bilgi) => aracFormuAc<void>(
    context,
    (_) => KayitFormu(
      tayfaId: widget.kimlik.tayfaId,
      alanlar: widget.alanlar,
      konumAcik: bilgi.locationEnabled,
      varsayilanGorunurluk: bilgi.locationDefault,
      merkez: widget.etkinlik.meetingPoint,
      gonder: (istek) => _notifier.ekle(istek),
    ),
  );

  Future<void> _cikar(EventLogEntry kayit) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(context, baslik: m.bilesen_log_cikar_onay);
    if (!onay || !mounted || _mesgul) return;
    setState(() => _mesgul = true);
    final hata = await _notifier.cikar(kayit.id);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(gunlukProvider(widget.kimlik));
    final liste = okunan.value;
    final bilgi = _notifier.bilgi;
    final alanlarTanindi =
        widget.alanlar.isNotEmpty && alanlarTaniniyor(widget.alanlar);
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_log_ad,
      sag: bilgi != null && bilgi.callerCanAdd && alanlarTanindi
          ? CerceveliHapEylem(
              etiket: m.bilesen_log_ekle,
              ikon: Icons.add,
              onPressed: _mesgul ? null : () => unawaited(_ekle(bilgi)),
            )
          : null,
    );
    if (liste == null || bilgi == null) {
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
    final dogrulanmadi =
        !bilgi.callerCanAdd &&
        !katilimDogrulandi(etkinlik) &&
        !iptalEdildi(etkinlik);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracListesi(
          bos: m.bilesen_log_yok,
          satirlar: [
            for (final kayit in liste.ogeler)
              KayitSatiri(
                key: ValueKey(kayit.id),
                kayit: kayit,
                alanlar: widget.alanlar,
                mesgul: _mesgul,
                onCikar: () => unawaited(_cikar(kayit)),
              ),
          ],
        ),
        if (liste.dahaHatasi case final hata?) HataSatiri.hatadan(hata),
        if (liste.dahaYukleniyor)
          const Center(child: TayfamYukleniyor())
        else if (liste.dahaVar)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: m.etkinlik_daha_fazla,
              onPressed: () => unawaited(_notifier.dahaFazla()),
            ),
          ),
        if (bilgi.callerCanAdd && !alanlarTanindi) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_log_guncelle),
        ] else if (dogrulanmadi) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_log_ekle_bilgi),
        ],
      ],
    );
  }
}

/// Bir günlük kaydı: fotoğraf (varsa), ilk dolu alanın değeri başlık,
/// diğer alanlar "Ad: değer" olarak; kaydı giren, zamanı, kendi kaydında
/// yerin kime göründüğü ve sunucu döndürdüyse "Yeri haritada aç".
/// `caller_can_remove` ise "Kaydı çıkar".
class KayitSatiri extends ConsumerWidget {
  const KayitSatiri({
    super.key,
    required this.kayit,
    required this.alanlar,
    required this.mesgul,
    required this.onCikar,
  });

  final EventLogEntry kayit;
  final List<CatalogField> alanlar;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  final VoidCallback onCikar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final dil = katalogDili(context);
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    final degerler = <(String, String)>[
      for (final alan in alanlar)
        if (katalogAlanDegeriMetni(context, alan, kayit.values[alan.key])
            case final deger?)
          (katalogAlanAdi(alan, dil), deger),
    ];
    final baslik = degerler.isEmpty ? m.bilesen_log_kayit : degerler.first.$2;
    final digerleri = degerler.skip(1).toList();
    final yer = kayit.location;
    final gorunurluk = switch (kayit.locationVisibility) {
      LogLocationVisibility.self => m.bilesen_log_yeri_sende,
      LogLocationVisibility.participants => m.bilesen_log_yeri_katilimcilarda,
      LogLocationVisibility.tayfa => m.bilesen_log_yeri_tayfada,
      LogLocationVisibility.unknown || null => null,
    };
    final fotograf = kayit.photoUploadId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fotograf != null && fotograf.isNotEmpty) ...[
          ClipRRect(
            borderRadius: TayfamRadii.onizlemeKoseleri,
            child: SizedBox.square(
              dimension: TayfamSizes.fotografKucukResim,
              child: MedyaGorseli(
                uploadId: fotograf,
                etiket: m.bilesen_log_fotograf_etiketi,
              ),
            ),
          ),
          const SizedBox(width: TayfamSpacing.s12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik, style: context.yazi.titleSmall),
              if (digerleri.isNotEmpty)
                Text(
                  [
                    for (final (ad, deger) in digerleri)
                      m.bilesen_log_alan_degeri(ad, deger),
                  ].join(ozetAyraci),
                  style: ikincil,
                ),
              // Kaydı girenin adına dokununca kişi profili (#185).
              KisiyeDokun(
                kullaniciId: kayit.userId,
                child: KullaniciAdiMetni(
                  kullaniciId: kayit.userId,
                  style: ikincil,
                ),
              ),
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(etkinlikZamani(m, kayit.createdAt), style: ikincil),
                    if (yer != null && gorunurluk != null)
                      Text(gorunurluk, style: ikincil),
                  ],
                ),
              ),
              if (yer != null)
                TextButton.icon(
                  onPressed: () => unawaited(_haritadaAc(context, ref, yer)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(m.bilesen_log_yeri_ac),
                ),
            ],
          ),
        ),
        if (kayit.callerCanRemove)
          AracIkonDugmesi(
            ipucu: m.bilesen_log_cikar,
            ikon: Icons.delete_outline,
            onPressed: mesgul ? null : onCikar,
          ),
      ],
    );
  }

  Future<void> _haritadaAc(
    BuildContext context,
    WidgetRef ref,
    LatLng yer,
  ) async {
    final acildi = await ref
        .read(etkinlikBaglantiAciciProvider)
        .haritadaAc(yer.lat, yer.lng);
    if (!acildi && context.mounted) {
      aracBildir(
        context,
        AppLocalizations.of(context).etkinlik_harita_acilamadi,
      );
    }
  }
}
