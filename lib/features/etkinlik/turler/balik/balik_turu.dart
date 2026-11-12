import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/arac_formlari.dart';
import 'package:tayfam/features/etkinlik/application/av_gunlugu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/harita_secici_ekrani.dart';
import 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Balık (ADR-0015 §6): av günlüğü; listeleme, ekleme ve çıkarma.
///
/// - Av eklemek için katılım doğrulanmış olmalıdır (sunucu:
///   `not-attended`); düğme yalnızca o zaman görünür.
/// - Mera gizliliği sunucunundur: avın yeri yalnızca sunucu döndürdüyse
///   gösterilir. Yer, kullanıcının haritada bilerek işaretlediği noktadır;
///   cihaz konumu kullanılmaz (kesin kural 3).
/// - Kendi avını herkes, başkasınınkini moderatör ve yönetici çıkarır.
final class BalikTuru extends KayitliEtkinlikTuru {
  const BalikTuru() : super(EventType.fishing);

  @override
  Widget? aracBolumu(BuildContext context, Event etkinlik) =>
      AvGunluguBolumu(etkinlik: etkinlik);
}

/// Av günlüğünün detaydaki bölümü.
class AvGunluguBolumu extends ConsumerWidget {
  const AvGunluguBolumu({super.key, required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final anahtar = (tayfaId: etkinlik.tayfaId, etkinlikId: etkinlik.id);
    final liste = ref.watch(avGunluguProvider(anahtar));
    final listeNotifier = ref.read(avGunluguProvider(anahtar).notifier);
    final mesgul = ref.watch(aracEylemProvider(anahtar));
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final yonetimde = ref.watch(tayfaOzetiProvider(etkinlik.tayfaId)).yonetimde;
    final eklenebilir = avEklenebilir(etkinlik, simdi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(metin: m.etkinlik_av_gunlugu),
        const SizedBox(height: TayfamSpacing.s4),
        ...liste.when<List<Widget>>(
          data: (sayfali) => [
            if (sayfali.ogeler.isEmpty) AracBilgisi(metin: m.etkinlik_av_yok),
            for (final av in sayfali.ogeler)
              _AvSatiri(
                anahtar: anahtar,
                av: av,
                yonetimde: yonetimde,
                mesgul: mesgul,
              ),
            if (sayfali.dahaHatasi case final hata?) HataSatiri.hatadan(hata),
            if (sayfali.dahaYukleniyor)
              const Center(child: CircularProgressIndicator())
            else if (sayfali.dahaVar)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => unawaited(listeNotifier.dahaFazla()),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.etkinlik_daha_fazla),
                ),
              ),
          ],
          error: (hata, _) => [
            HataSatiri.hatadan(hata),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => unawaited(listeNotifier.yenile()),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.etkinlik_tekrar_dene),
              ),
            ),
          ],
          loading: () => [const Center(child: CircularProgressIndicator())],
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (eklenebilir)
          AracDugmesi(
            etiket: m.etkinlik_av_ekle,
            ikon: Icons.add,
            onPressed: mesgul
                ? null
                : () => unawaited(_ekle(context, ref, anahtar)),
          )
        else if (!katilimDogrulandi(etkinlik))
          AracBilgisi(metin: m.etkinlik_av_ekle_bilgi),
      ],
    );
  }

  Future<void> _ekle(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AvFormu(anahtar: anahtar, merkez: etkinlik.meetingPoint),
    );
  }
}

class _AvSatiri extends ConsumerWidget {
  const _AvSatiri({
    required this.anahtar,
    required this.av,
    required this.yonetimde,
    required this.mesgul,
  });

  final EtkinlikAnahtari anahtar;
  final FishingCatch av;
  final bool yonetimde;
  final bool mesgul;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final benim = ref.watch(kendisiMiProvider(av.userId));
    final yer = av.location;
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    final fotograf = av.photoUploadId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fotograf != null && fotograf.isNotEmpty) ...[
            ClipRRect(
              borderRadius: TayfamRadii.onizlemeKoseleri,
              child: SizedBox.square(
                dimension: TayfamSizes.fotografKucukResim,
                child: MedyaGorseli(
                  uploadId: fotograf,
                  etiket: m.medya_av_fotografi_etiketi,
                ),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.etkinlik_av_ozet(
                          av.species,
                          etkinlikSayi(m, av.lengthCm),
                        ),
                        style: context.yazi.bodyLarge,
                      ),
                      KullaniciAdiMetni(kullaniciId: av.userId, style: ikincil),
                      Text(etkinlikZamani(m, av.createdAt), style: ikincil),
                      if (benim && yer != null)
                        Text(
                          av.visibility == FishingCatchVisibility.tayfa
                              ? m.etkinlik_av_yeri_tayfada
                              : m.etkinlik_av_yeri_sende,
                          style: ikincil,
                        ),
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
                    label: Text(m.etkinlik_av_yeri_ac),
                  ),
              ],
            ),
          ),
          if (benim || yonetimde)
            AracIkonDugmesi(
              ipucu: m.etkinlik_av_cikar,
              ikon: Icons.delete_outline,
              onPressed: mesgul ? null : () => unawaited(_cikar(context, ref)),
            ),
        ],
      ),
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

  Future<void> _cikar(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(context, baslik: m.etkinlik_av_cikar_onay);
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(aracEylemProvider(anahtar).notifier)
        .avCikar(av.id);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

/// Av ekleme formu. `client_request_id` form açılınca bir kez üretilir;
/// gönderim başarısız olursa form açık kalır ve tekrar denemede aynı id
/// gönderilir (ADR-0005).
class AvFormu extends ConsumerStatefulWidget {
  const AvFormu({super.key, required this.anahtar, this.merkez});

  final EtkinlikAnahtari anahtar;

  /// Harita seçicinin açılacağı nokta (buluşma noktası); yoksa Türkiye.
  final LatLng? merkez;

  @override
  ConsumerState<AvFormu> createState() => _AvFormuState();
}

class _AvFormuState extends ConsumerState<AvFormu> {
  final TextEditingController _tur = TextEditingController();
  final TextEditingController _boy = TextEditingController();
  late final String _istekKimligi = ref.read(etkinlikIstekKimligiProvider)();
  LatLng? _yer;
  FishingCatchCreateRequestVisibility _gorunurluk =
      FishingCatchCreateRequestVisibility.self;
  String? _fotograf;
  Set<AvHatasi> _hatalar = const {};
  Object? _hata;

  @override
  void dispose() {
    _tur.dispose();
    _boy.dispose();
    super.dispose();
  }

  Future<void> _yerSec() async {
    final secim = await haritaSeciciAc(
      context,
      baslangic: _yer ?? widget.merkez,
    );
    if (secim == null || !mounted) return;
    setState(() => _yer = secim.nokta);
  }

  Future<void> _ekle() async {
    final sonuc = avIstegi(
      tur: _tur.text,
      boy: _boy.text,
      yer: _yer,
      gorunurluk: _gorunurluk,
      fotograf: _fotograf,
      istekKimligi: _istekKimligi,
    );
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() => _hatalar = sonuc.hatalar);
      return;
    }
    setState(() {
      _hatalar = const {};
      _hata = null;
    });
    final hata = await ref
        .read(aracEylemProvider(widget.anahtar).notifier)
        .avEkle(istek);
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop();
    } else {
      setState(() => _hata = hata);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(aracEylemProvider(widget.anahtar));
    final yer = _yer;
    final hata = _hata;
    return AracFormDiyalogu(
      baslik: m.etkinlik_av_ekle,
      onayEtiketi: m.etkinlik_ekle,
      onOnay: mesgul ? null : () => unawaited(_ekle()),
      alanlar: [
        TextField(
          controller: _tur,
          autofocus: true,
          maxLength: avTuruEnCok,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.etkinlik_av_turu,
            errorText: _hatalar.contains(AvHatasi.tur)
                ? m.etkinlik_av_turu_hata
                : null,
          ),
        ),
        TextField(
          controller: _boy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: m.etkinlik_av_boyu,
            errorText: _hatalar.contains(AvHatasi.boy)
                ? m.etkinlik_av_boyu_hata
                : null,
            errorMaxLines: 2,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Text(m.etkinlik_av_fotografi, style: context.yazi.titleSmall),
        const SizedBox(height: TayfamSpacing.s8),
        FotografAlani(
          amac: UploadPurpose.catchPhoto,
          tayfaId: widget.anahtar.tayfaId,
          deger: _fotograf,
          etiket: m.medya_av_fotografi_etiketi,
          bicim: FotografAlaniBicimi.kare,
          etkin: !mesgul,
          onDegisti: (yeni) => setState(() => _fotograf = yeni),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        if (yer == null)
          AracDugmesi(
            etiket: m.etkinlik_av_yer_sec,
            ikon: Icons.add_location_alt_outlined,
            onPressed: () => unawaited(_yerSec()),
          )
        else ...[
          Text(m.etkinlik_av_yer_secildi, style: context.yazi.bodyLarge),
          AracDugmesi(
            etiket: m.etkinlik_av_yer_kaldir,
            ikon: Icons.location_off_outlined,
            onPressed: () => setState(() => _yer = null),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.etkinlik_av_yer_kimin, style: context.yazi.titleSmall),
          RadioGroup<FishingCatchCreateRequestVisibility>(
            groupValue: _gorunurluk,
            onChanged: (v) {
              if (v != null) setState(() => _gorunurluk = v);
            },
            child: Column(
              children: [
                for (final (g, etiket) in [
                  (
                    FishingCatchCreateRequestVisibility.self,
                    m.etkinlik_av_yer_self,
                  ),
                  (
                    FishingCatchCreateRequestVisibility.tayfa,
                    m.etkinlik_av_yer_tayfa,
                  ),
                ])
                  RadioListTile<FishingCatchCreateRequestVisibility>(
                    value: g,
                    contentPadding: EdgeInsets.zero,
                    title: Text(etiket),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s8),
        AracBilgisi(metin: m.etkinlik_av_yer_notu),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}
