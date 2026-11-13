import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kanal adının en uzun hâli (sözleşme: 1–40).
const int kanalAdiEnUzun = 40;

/// Kanal adının önündeki işaret (tasarım: Kanal-Formu); adın parçası
/// değildir, sunucuya gitmez.
const String kanalOneki = '#';

/// Yavaş mod seçenekleri (saniye; sözleşme: 0–3600).
const List<int> yavasModSecenekleri = [0, 10, 30, 60, 300, 900, 3600];

/// Kanal açma ya da (verilirse [kanal]) düzenleme formunu alttan açılan
/// sayfada gösterir (yönetim; ADR-0018 §9; 2026-11-13 tasarım:
/// Kanal-Formu). Düzenlemede arşivleme ve arşivden çıkarma da buradadır.
/// Yetkiyi sunucu verir; hata satır içinde gösterilir.
Future<void> kanalFormunuAc(
  BuildContext context, {
  required String tayfaId,
  Channel? kanal,
}) => altSayfaAc<void>(
  context,
  builder: (context) => KanalFormu(tayfaId: tayfaId, kanal: kanal),
);

/// Kanal formu.
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
  late bool _yonetim = widget.kanal?.visibility == ChannelVisibility.staff;
  late int _yavas = widget.kanal?.slowModeSeconds ?? 0;
  bool _gonderiliyor = false;
  bool _adHatali = false;
  Object? _hata;

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final ad = _ad.text.trim();
    if (ad.isEmpty || ad.length > kanalAdiEnUzun) {
      setState(() => _adHatali = true);
      return;
    }
    setState(() {
      _adHatali = false;
      _gonderiliyor = true;
      _hata = null;
    });
    final notifier = ref.read(kanallarProvider(widget.tayfaId).notifier);
    try {
      final kanal = widget.kanal;
      if (kanal == null) {
        await notifier.olustur(
          ad: ad,
          yonetimKanali: _yonetim,
          yavasModSaniye: _yavas,
        );
      } else {
        await notifier.guncelle(
          kanal,
          ad: ad,
          yonetimKanali: _yonetim,
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

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kanal = widget.kanal;
    final secenekler = {...yavasModSecenekleri, _yavas}.toList()..sort();
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
                const SizedBox(height: TayfamSpacing.s8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _yonetim,
                  onChanged: _gonderiliyor
                      ? null
                      : (deger) => setState(() => _yonetim = deger),
                  title: Text(m.sohbet_form_yonetim),
                  subtitle: Text(
                    m.sohbet_form_yonetim_aciklama,
                    style: context.yazi.bodySmall?.copyWith(
                      color: r.metinIkincil,
                    ),
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s12),
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
