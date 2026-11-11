import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/arac_formlari.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Detaydaki rota önizlemesinin yüksekliği.
const double rotaOnizlemeYuksekligi = 180;

/// Rota önizlemesinin yakınlığı (ilk noktadan).
const double rotaOnizlemeYakinligi = 10;

/// Konvoy (ADR-0015 §6): rota önizlemesi ve araç listesi. Herkes kendi
/// aracını ekler ve değiştirir (plaka isteğe bağlı); kendi aracını ve,
/// yönetebiliyorsa, başkasının aracını çıkarır.
final class KonvoyTuru extends KayitliEtkinlikTuru {
  const KonvoyTuru() : super(EventType.convoy);

  @override
  Widget? aracBolumu(BuildContext context, Event etkinlik) =>
      KonvoyBolumu(etkinlik: etkinlik);
}

/// Konvoyun detaydaki bölümü.
class KonvoyBolumu extends ConsumerWidget {
  const KonvoyBolumu({super.key, required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final anahtar = (tayfaId: etkinlik.tayfaId, etkinlikId: etkinlik.id);
    final mesgul = ref.watch(aracEylemProvider(anahtar));
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final rota = etkinlik.convoy?.route ?? const <LatLng>[];
    final araclar = etkinlik.convoy?.vehicles ?? const <ConvoyVehicle>[];
    ConvoyVehicle? benimki;
    for (final arac in araclar) {
      if (ref.watch(kendisiMiProvider(arac.userId))) benimki = arac;
    }
    final eklenebilir = aracEklenebilir(etkinlik, simdi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(metin: m.etkinlik_konvoy_baslik),
        if (rota.length > 1) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.etkinlik_konvoy_rota, style: context.yazi.titleSmall),
          AracBilgisi(
            metin: m.etkinlik_konvoy_rota_noktalari(
              etkinlikSayi(m, rota.length),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          ClipRRect(
            borderRadius: TayfamRadii.onizlemeKoseleri,
            child: SizedBox(
              height: rotaOnizlemeYuksekligi,
              child: OsmHarita(
                merkez: rota.first,
                yakinlik: rotaOnizlemeYakinligi,
                rota: rota,
                etkilesimli: false,
              ),
            ),
          ),
        ],
        const SizedBox(height: TayfamSpacing.s12),
        Text(m.etkinlik_konvoy_araclar, style: context.yazi.titleSmall),
        const SizedBox(height: TayfamSpacing.s4),
        if (araclar.isEmpty) AracBilgisi(metin: m.etkinlik_konvoy_arac_yok),
        for (final arac in araclar)
          _AracSatiri(
            anahtar: anahtar,
            arac: arac,
            benim: identical(arac, benimki),
            degistirilebilir: eklenebilir && !mesgul,
            cikarilabilir:
                !mesgul &&
                (identical(arac, benimki) || etkinlik.callerCanManage),
          ),
        const SizedBox(height: TayfamSpacing.s8),
        if (eklenebilir && benimki == null)
          AracDugmesi(
            etiket: m.etkinlik_konvoy_arac_ekle,
            ikon: Icons.add,
            onPressed: mesgul
                ? null
                : () => unawaited(_aracKaydet(context, ref, anahtar, null)),
          )
        else if (benimki == null && katilimAcik(etkinlik, simdi))
          AracBilgisi(metin: m.etkinlik_konvoy_ekle_bilgi),
      ],
    );
  }
}

Future<void> _aracKaydet(
  BuildContext context,
  WidgetRef ref,
  EtkinlikAnahtari anahtar,
  ConvoyVehicle? mevcut,
) async {
  final istek = await showDialog<ConvoyVehicleCreateRequest>(
    context: context,
    builder: (_) => AracFormu(mevcut: mevcut),
  );
  if (istek == null || !context.mounted) return;
  final hata = await ref
      .read(aracEylemProvider(anahtar).notifier)
      .aracKaydet(istek);
  if (hata != null && context.mounted) hataBildir(context, hata);
}

class _AracSatiri extends ConsumerWidget {
  const _AracSatiri({
    required this.anahtar,
    required this.arac,
    required this.benim,
    required this.degistirilebilir,
    required this.cikarilabilir,
  });

  final EtkinlikAnahtari anahtar;
  final ConvoyVehicle arac;
  final bool benim;
  final bool degistirilebilir;
  final bool cikarilabilir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final ad = [
      arac.make,
      arac.model,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' ');
    final yil = arac.modelYear;
    final ayrinti = [
      if (yil != null && yil > 0) '$yil',
      arac.color,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
    final plaka = arac.plate?.trim();
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: TayfamSpacing.s4),
            child: Icon(Icons.directions_car_outlined, size: TayfamSizes.ikon),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad, style: context.yazi.bodyLarge),
                  if (ayrinti.isNotEmpty) Text(ayrinti, style: ikincil),
                  if (plaka != null && plaka.isNotEmpty)
                    Text(m.etkinlik_konvoy_plaka(plaka), style: ikincil),
                  KullaniciAdiMetni(kullaniciId: arac.userId, style: ikincil),
                ],
              ),
            ),
          ),
          if (benim)
            AracIkonDugmesi(
              ipucu: m.etkinlik_konvoy_arac_degistir,
              ikon: Icons.edit_outlined,
              onPressed: degistirilebilir
                  ? () => unawaited(_aracKaydet(context, ref, anahtar, arac))
                  : null,
            ),
          if (cikarilabilir)
            AracIkonDugmesi(
              ipucu: m.etkinlik_konvoy_arac_cikar,
              ikon: Icons.delete_outline,
              onPressed: () => unawaited(_cikar(context, ref)),
            ),
        ],
      ),
    );
  }

  Future<void> _cikar(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.etkinlik_konvoy_arac_cikar_onay,
    );
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(aracEylemProvider(anahtar).notifier)
        .aracCikar(arac.id);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

/// Kendi aracını ekleme ve değiştirme formu; kaydedilirse istek döner.
class AracFormu extends ConsumerStatefulWidget {
  const AracFormu({super.key, this.mevcut});

  /// Değiştirilen araç; yeni araçta `null`.
  final ConvoyVehicle? mevcut;

  @override
  ConsumerState<AracFormu> createState() => _AracFormuState();
}

class _AracFormuState extends ConsumerState<AracFormu> {
  late final TextEditingController _marka = TextEditingController(
    text: widget.mevcut?.make,
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.mevcut?.model,
  );
  late final TextEditingController _yil = TextEditingController(
    text: switch (widget.mevcut?.modelYear) {
      final yil? when yil > 0 => '$yil',
      _ => '',
    },
  );
  late final TextEditingController _renk = TextEditingController(
    text: widget.mevcut?.color,
  );
  late final TextEditingController _plaka = TextEditingController(
    text: widget.mevcut?.plate,
  );
  Set<AracHatasi> _hatalar = const {};

  int get _buYil => ref.read(etkinlikSaatiProvider)().toLocal().year;

  @override
  void dispose() {
    _marka.dispose();
    _model.dispose();
    _yil.dispose();
    _renk.dispose();
    _plaka.dispose();
    super.dispose();
  }

  void _kaydet() {
    final sonuc = aracIstegi(
      marka: _marka.text,
      model: _model.text,
      yil: _yil.text,
      renk: _renk.text,
      plaka: _plaka.text,
      buYil: _buYil,
    );
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() => _hatalar = sonuc.hatalar);
      return;
    }
    Navigator.of(context).pop(istek);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final h = _hatalar;
    return AracFormDiyalogu(
      baslik: widget.mevcut == null
          ? m.etkinlik_konvoy_arac_ekle
          : m.etkinlik_konvoy_arac_degistir,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _kaydet,
      alanlar: [
        TextField(
          controller: _marka,
          autofocus: true,
          maxLength: aracMarkaEnCok,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: m.etkinlik_arac_marka,
            errorText: h.contains(AracHatasi.marka)
                ? m.etkinlik_arac_marka_hata
                : null,
          ),
        ),
        TextField(
          controller: _model,
          maxLength: aracModelEnCok,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: m.etkinlik_arac_model,
            errorText: h.contains(AracHatasi.model)
                ? m.etkinlik_uzunluk_hata(aracModelEnCok)
                : null,
          ),
        ),
        TextField(
          controller: _yil,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: m.etkinlik_arac_yil,
            errorText: h.contains(AracHatasi.yil)
                ? m.etkinlik_arac_yil_hata(_buYil + 1)
                : null,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        TextField(
          controller: _renk,
          maxLength: aracRenkEnCok,
          decoration: InputDecoration(
            labelText: m.etkinlik_arac_renk,
            errorText: h.contains(AracHatasi.renk)
                ? m.etkinlik_uzunluk_hata(aracRenkEnCok)
                : null,
          ),
        ),
        TextField(
          controller: _plaka,
          maxLength: plakaEnCok,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: m.etkinlik_arac_plaka,
            helperText: m.etkinlik_arac_plaka_notu,
            helperMaxLines: 3,
            errorText: h.contains(AracHatasi.plaka)
                ? m.etkinlik_arac_plaka_hata
                : null,
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }
}
