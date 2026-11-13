import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/etkinlik_secici.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ortak.dart';
import 'package:tayfam/features/sohbet/presentation/katilimcilar_ekrani.dart';
import 'package:tayfam/features/sohbet/presentation/kisi_secici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kanal adının önündeki işaret (tasarım: Kanal-Formu); adın parçası
/// değildir, sunucuya gitmez.
const String kanalOneki = '#';

/// Yavaş mod seçenekleri (saniye; sözleşme: 0–3600).
const List<int> yavasModSecenekleri = [0, 10, 30, 60, 300, 900, 3600];

/// Formdaki seçili kişi satırında gösterilen en çok avatar.
const int formAvatarSayisi = 3;

/// Kanal açma ya da (verilirse [kanal]) düzenleme formunu alttan açılan
/// sayfada gösterir (yönetim; ADR-0018 §9; 2026-11-13 tasarım:
/// Kanal-Formu, Kanal-Kitle). Düzenlemede arşivleme ve arşivden çıkarma da
/// buradadır. Yetkiyi sunucu verir; hata satır içinde gösterilir.
Future<void> kanalFormunuAc(
  BuildContext context, {
  required String tayfaId,
  Channel? kanal,
}) => altSayfaAc<void>(
  context,
  builder: (context) => KanalFormu(tayfaId: tayfaId, kanal: kanal),
);

/// Kanal formu.
///
/// - Yeni kanalda "Kimler görsün?": bütün tayfa, yalnızca yönetim, bir
///   etkinliğe gelenler (etkinlik seçici), seçtiğim kişiler (kişi
///   seçici; Tayfam-Api #183).
/// - Düzenlemede yalnızca bütün tayfa ile yönetim arasında geçilir;
///   etkinlik ve seçili kişi kanallarının kitlesi değişmez (sözleşme),
///   onlarda "Katılımcılar" girişi vardır.
class KanalFormu extends ConsumerStatefulWidget {
  const KanalFormu({super.key, required this.tayfaId, this.kanal});

  final String tayfaId;

  /// Düzenlenen kanal; `null` ise yeni kanal açılır.
  final Channel? kanal;

  @override
  ConsumerState<KanalFormu> createState() => _KanalFormuState();
}

class _KanalFormuState extends ConsumerState<KanalFormu> {
  late final TextEditingController _ad = TextEditingController(
    text: widget.kanal?.name ?? '',
  );
  late KanalKitlesi _kitle = switch (widget.kanal) {
    final kanal? => KanalKitlesi.kanaldan(kanal),
    null => KanalKitlesi.herkes,
  };
  late int _yavas = widget.kanal?.slowModeSeconds ?? 0;
  List<String> _kisiler = const [];
  Event? _etkinlik;
  bool _gonderiliyor = false;
  bool _adHatali = false;
  bool _etkinlikEksik = false;
  Object? _hata;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _kisileriSec() async {
    final secilen = await kisiSeciciyiAc(
      context,
      tayfaId: widget.tayfaId,
      kanalAdi: _ad.text.trim(),
      secili: _kisiler,
    );
    if (secilen != null && mounted) setState(() => _kisiler = secilen);
  }

  Future<void> _etkinlikSec() async {
    final secilen = await etkinlikSeciciyiAc(
      context,
      tayfaId: widget.tayfaId,
      secili: _etkinlik,
    );
    if (secilen == null || !mounted) return;
    setState(() {
      _etkinlik = secilen;
      _etkinlikEksik = false;
      if (_ad.text.trim().isEmpty) _ad.text = etkinlikKanalAdi(secilen.title);
    });
  }

  void _kitleSec(KanalKitlesi? kitle) {
    if (kitle == null || kitle == _kitle) return;
    setState(() => _kitle = kitle);
    // Seçimi henüz yapılmamış kitlede seçici hemen açılır.
    if (kitle == KanalKitlesi.secili && _kisiler.isEmpty) {
      unawaited(_kisileriSec());
    } else if (kitle == KanalKitlesi.etkinlik && _etkinlik == null) {
      unawaited(_etkinlikSec());
    }
  }

  Future<void> _kaydet() async {
    final ad = _ad.text.trim();
    final adHatali = ad.isEmpty || ad.runes.length > kanalAdiEnUzun;
    final etkinlikEksik =
        widget.kanal == null &&
        _kitle == KanalKitlesi.etkinlik &&
        _etkinlik == null;
    if (adHatali || etkinlikEksik) {
      setState(() {
        _adHatali = adHatali;
        _etkinlikEksik = etkinlikEksik;
      });
      return;
    }
    setState(() {
      _adHatali = false;
      _etkinlikEksik = false;
      _gonderiliyor = true;
      _hata = null;
    });
    final notifier = ref.read(kanallarProvider(widget.tayfaId).notifier);
    try {
      final kanal = widget.kanal;
      if (kanal == null) {
        await notifier.olustur(
          ad: ad,
          kitle: _kitle,
          yavasModSaniye: _yavas,
          etkinlikId: _etkinlik?.id,
          kisiler: _kisiler,
        );
      } else {
        await notifier.guncelle(
          kanal,
          ad: ad,
          yonetimKanali: _kitle == KanalKitlesi.yonetim,
          yavasModSaniye: _yavas,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (hata) {
      if (mounted) {
        setState(() {
          _gonderiliyor = false;
          _hata = hata;
        });
      }
    }
  }

  Future<void> _arsivle(Channel kanal) async {
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      await ref
          .read(kanallarProvider(widget.tayfaId).notifier)
          .arsivle(kanal.id, arsivde: kanal.archivedAt == null);
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (hata) {
      if (mounted) {
        setState(() {
          _gonderiliyor = false;
          _hata = hata;
        });
      }
    }
  }

  String _yavasEtiketi(AppLocalizations m, int saniye) {
    if (saniye == 0) return m.sohbet_yavas_kapali;
    if (saniye >= 3600) return m.sohbet_yavas_saat;
    if (saniye >= 60 && saniye % 60 == 0) {
      return m.sohbet_yavas_dakika(saniye ~/ 60);
    }
    return m.sohbet_yavas_saniye(saniye);
  }

  /// Seçili kitlenin altındaki seçim satırı (kişiler ya da etkinlik).
  Widget? _secimSatiri(AppLocalizations m, KanalKitlesi kitle) {
    if (widget.kanal != null || kitle != _kitle) return null;
    switch (kitle) {
      case KanalKitlesi.secili:
        return _SecimSatiri(
          on: KisiYigini(
            kimlikler: _kisiler.take(formAvatarSayisi).toList(),
          ),
          metin: _kisiler.isEmpty
              ? m.sohbet_kitle_kisi_sec
              : m.sohbet_kitle_secilen_sayi(_kisiler.length),
          eylem: _kisiler.isEmpty ? null : m.sohbet_kitle_duzenle,
          onTap: _gonderiliyor ? null : () => unawaited(_kisileriSec()),
        );
      case KanalKitlesi.etkinlik:
        final etkinlik = _etkinlik;
        return _SecimSatiri(
          on: etkinlik == null || etkinlik.type == EventType.unknown
              ? null
              : EtkinlikTuruCipi(tur: etkinlik.type),
          metin: etkinlik?.title ?? m.sohbet_kitle_etkinlik_sec,
          eylem: etkinlik == null ? null : m.sohbet_kitle_degistir,
          onTap: _gonderiliyor ? null : () => unawaited(_etkinlikSec()),
        );
      case KanalKitlesi.herkes || KanalKitlesi.yonetim:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kanal = widget.kanal;
    final secenekler = {...yavasModSecenekleri, _yavas}.toList()..sort();
    final kitleler = kanal == null
        ? KanalKitlesi.values
        : (_kitle.sabit
              ? const <KanalKitlesi>[]
              : const [KanalKitlesi.herkes, KanalKitlesi.yonetim]);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AltSayfaIcerigi(
        baslik: kanal == null ? m.sohbet_form_yeni : m.sohbet_form_duzenle,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ad,
                  maxLength: kanalAdiEnUzun,
                  enabled: !_gonderiliyor,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: m.sohbet_form_ad,
                    prefixText: kanalOneki,
                    errorText: _adHatali ? m.sohbet_form_ad_hata : null,
                  ),
                ),
                if (kitleler.isNotEmpty) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  Semantics(
                    header: true,
                    child: Text(
                      m.sohbet_kitle_baslik,
                      style: context.yazi.titleMedium,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  RadioGroup<KanalKitlesi>(
                    groupValue: _kitle,
                    onChanged: _gonderiliyor ? (_) {} : _kitleSec,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (sira, kitle) in kitleler.indexed) ...[
                          if (sira > 0)
                            const SizedBox(height: TayfamSpacing.s8),
                          _KitleSecenegi(
                            kitle: kitle,
                            secili: kitle == _kitle,
                            alt: _secimSatiri(m, kitle),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_etkinlikEksik) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri(metin: m.sohbet_kitle_etkinlik_gerekli),
                  ],
                ],
                if (kanal != null && _kitle.sabit) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  ListeKarti(
                    children: [
                      MenuSatiri.kartta(
                        ikon: kitleIkonu(_kitle),
                        baslik: m.sohbet_katilimcilar_baslik,
                        aciklama: kanal.memberCount == null
                            ? null
                            : m.sohbet_kanal_kisi_sayisi(kanal.memberCount!),
                        sag: const SatirOku(),
                        onTap: () => unawaited(
                          katilimcilariAc(context, (
                            tayfaId: widget.tayfaId,
                            kanalId: kanal.id,
                          )),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: TayfamSpacing.s16),
                Semantics(
                  header: true,
                  child: Text(
                    m.sohbet_form_yavas_mod,
                    style: context.yazi.titleMedium,
                  ),
                ),
                Text(
                  m.sohbet_form_yavas_aciklama,
                  style: context.yazi.bodySmall?.copyWith(
                    color: r.metinIkincil,
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s8),
                Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s8,
                  children: [
                    for (final s in secenekler)
                      ChoiceChip(
                        label: Text(_yavasEtiketi(m, s)),
                        selected: s == _yavas,
                        showCheckmark: false,
                        onSelected: _gonderiliyor
                            ? null
                            : (_) => setState(() => _yavas = s),
                      ),
                  ],
                ),
                if (_hata case final hata?) ...[
                  const SizedBox(height: TayfamSpacing.s16),
                  HataSatiri.hatadan(hata),
                ],
                const SizedBox(height: TayfamSpacing.s24),
                BirincilEylem(
                  etiket: kanal == null
                      ? m.sohbet_form_olustur
                      : m.sohbet_form_kaydet,
                  onPressed: _gonderiliyor ? null : _kaydet,
                ),
                if (kanal != null) ...[
                  const SizedBox(height: TayfamSpacing.s12),
                  CerceveliHapEylem(
                    etiket: kanal.archivedAt == null
                        ? m.sohbet_arsivle
                        : m.sohbet_arsivden_cikar,
                    ikon: Icons.inventory_2_outlined,
                    notr: true,
                    onPressed: _gonderiliyor ? null : () => _arsivle(kanal),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Kimler görsün?" seçeneği (tasarım: Kanal-Kitle): ikon, ad, açıklama ve
/// sağda seçim düğmesi; seçiliyse altında seçim satırı ([alt]).
class _KitleSecenegi extends StatelessWidget {
  const _KitleSecenegi({
    required this.kitle,
    required this.secili,
    required this.alt,
  });

  final KanalKitlesi kitle;
  final bool secili;
  final Widget? alt;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final (ad, aciklama) = switch (kitle) {
      KanalKitlesi.herkes => (
        m.sohbet_kitle_herkes,
        m.sohbet_kitle_herkes_aciklama,
      ),
      KanalKitlesi.yonetim => (
        m.sohbet_kitle_yonetim,
        m.sohbet_kitle_yonetim_aciklama,
      ),
      KanalKitlesi.etkinlik => (
        m.sohbet_kitle_etkinlik,
        m.sohbet_kitle_etkinlik_aciklama,
      ),
      KanalKitlesi.secili => (
        m.sohbet_kitle_secili,
        m.sohbet_kitle_secili_aciklama,
      ),
    };
    final alt = this.alt;
    return SecimKarti(
      secili: secili,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<KanalKitlesi>(
            value: kitle,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: ExcludeSemantics(
              child: Icon(kitleIkonu(kitle), color: r.tintMarkaUstu),
            ),
            title: Text(ad),
            subtitle: Text(
              aciklama,
              style: context.yazi.bodySmall?.copyWith(color: r.metinGovde),
            ),
          ),
          if (alt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.s12,
                0,
                TayfamSpacing.s12,
                TayfamSpacing.s12,
              ),
              child: alt,
            ),
        ],
      ),
    );
  }
}

/// Seçili kitlenin altındaki satır (tasarım: Kanal-Kitle "5 kişi seçildi
/// · Düzenle"): kart zemin, solda avatarlar ya da tür çipi, metin ve
/// sağda bağlantı.
class _SecimSatiri extends StatelessWidget {
  const _SecimSatiri({
    required this.on,
    required this.metin,
    required this.eylem,
    required this.onTap,
  });

  final Widget? on;
  final String metin;

  /// Sağdaki bağlantı metni; seçim yokken yoktur.
  final String? eylem;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final on = this.on;
    final eylem = this.eylem;
    return Material(
      color: r.kart,
      borderRadius: TayfamRadii.dugmeKoseleri,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s12,
              vertical: TayfamSpacing.s8,
            ),
            child: Row(
              children: [
                if (on != null) ...[
                  on,
                  const SizedBox(width: TayfamSpacing.s8),
                ],
                Expanded(
                  child: Text(
                    metin,
                    style: context.yazi.titleSmall?.copyWith(color: r.metin),
                  ),
                ),
                if (eylem != null) ...[
                  const SizedBox(width: TayfamSpacing.s8),
                  Text(
                    eylem,
                    style: context.yazi.titleSmall?.copyWith(color: r.marka),
                  ),
                ] else
                  const SatirOku(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
