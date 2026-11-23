import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/derece/derece_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Derece girme ve düzeltme formu (alttan sayfa): süre (`1:02:03,45`;
/// virgül de nokta da ondalık ayracı) ya da sıra (tam sayı) ve
/// [kisiSecimi] verildiyse "Kimin derecesi?" (etkinliğe "Geliyorum"
/// diyenler). Sunucu hatası (ör. `ranking-not-participant`) formda
/// gösterilir, form açık kalır.
class DereceFormu extends ConsumerStatefulWidget {
  const DereceFormu({
    super.key,
    required this.derece,
    required this.baslik,
    required this.gonder,
    this.ilkDeger,
    this.kisiSecimi,
  });

  final EventRanking derece;
  final String baslik;

  /// Düzeltmede kayıtlı değer.
  final double? ilkDeger;

  /// Verilirse önce kişi seçilir.
  final KatilimcilarAnahtari? kisiSecimi;

  /// İsteği gönderir ([kisi]: seçilen kişi, seçim yoksa `null`); başarıda
  /// `null`, değilse hata döner.
  final Future<Object?> Function(String? kisi, double deger) gonder;

  @override
  ConsumerState<DereceFormu> createState() => _DereceFormuState();
}

class _DereceFormuState extends ConsumerState<DereceFormu> {
  late final TextEditingController _deger;
  DereceHatasi? _alanHatasi;
  String? _secilenKisi;
  bool _kisiHatasi = false;
  bool _mesgul = false;
  Object? _hata;

  /// Alanın en çok karakteri (`277:46:40,00` ve biraz pay).
  static const int _uzunluk = 16;

  bool get _sira => widget.derece.metric == EventRankingMetric.rank;

  @override
  void initState() {
    super.initState();
    _deger = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deger.text.isEmpty && widget.ilkDeger != null) {
      _deger.text = dereceGirdisi(
        AppLocalizations.of(context),
        widget.derece,
        widget.ilkDeger,
      );
    }
  }

  @override
  void dispose() {
    _deger.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_mesgul) return;
    final okunan = dereceGirdisiniOku(widget.derece, _deger.text);
    final kisiEksik = widget.kisiSecimi != null && _secilenKisi == null;
    final deger = okunan.deger;
    if (deger == null || kisiEksik) {
      setState(() {
        _alanHatasi = okunan.hata;
        _kisiHatasi = kisiEksik;
      });
      return;
    }
    setState(() {
      _alanHatasi = null;
      _kisiHatasi = false;
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(_secilenKisi, deger);
    if (!mounted) return;
    if (hata == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _mesgul = false;
        _hata = hata;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final alanHatasi = _alanHatasi;
    // Alan hata metni kontrastı sağlayan nar tonundadır (`hataMetni`,
    // ADR-0004 Notlar 2026-11-23); hatayı kenar rengi ve metin taşır.
    final hataStili = context.yazi.bodySmall?.copyWith(
      color: context.renkler.hataMetni,
    );
    final kisiSecimi = widget.kisiSecimi;
    final hata = _hata;
    return AracFormSayfasi(
      baslik: widget.baslik,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        if (kisiSecimi != null) ...[
          Text(m.bilesen_ranking_kisi_sec, style: context.yazi.titleSmall),
          const SizedBox(height: TayfamSpacing.s8),
          _GelenSecici(
            anahtar: kisiSecimi,
            secili: _secilenKisi,
            onSecildi: _mesgul
                ? null
                : (id) => setState(() {
                    _secilenKisi = id;
                    _kisiHatasi = false;
                    _hata = null;
                  }),
          ),
          if (_kisiHatasi) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: m.bilesen_ranking_kisi_sec_hata),
          ],
          const SizedBox(height: TayfamSpacing.s16),
        ],
        TextField(
          key: const ValueKey('derece-degeri'),
          controller: _deger,
          autofocus: kisiSecimi == null,
          enabled: !_mesgul,
          // Süre için ":" gereken klavye (Android'de tarih-saat, iOS'ta
          // rakam ve noktalama).
          keyboardType: _sira ? TextInputType.number : TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(_sira ? r'[0-9]' : r'[0-9:.,]'),
            ),
            LengthLimitingTextInputFormatter(_uzunluk),
          ],
          onChanged: (_) {
            if (_alanHatasi != null || _hata != null) {
              setState(() {
                _alanHatasi = null;
                _hata = null;
              });
            }
          },
          onSubmitted: (_) => unawaited(_kaydet()),
          decoration: InputDecoration(
            labelText: _sira
                ? m.bilesen_ranking_sira_alani
                : m.bilesen_ranking_sure_alani,
            helperText: _sira
                ? m.katalog_alan_aralik('$dereceSiraEnAz', '$dereceSiraEnCok')
                : m.bilesen_ranking_sure_ornek,
            helperMaxLines: 2,
            errorText: alanHatasi == null
                ? null
                : dereceHataMetni(m, widget.derece, alanHatasi),
            errorStyle: hataStili,
            errorMaxLines: 3,
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// "Kimin derecesi?": etkinliğe "Geliyorum" diyenler (ilk sayfa ve "Daha
/// fazla").
class _GelenSecici extends ConsumerWidget {
  const _GelenSecici({
    required this.anahtar,
    required this.secili,
    required this.onSecildi,
  });

  final KatilimcilarAnahtari anahtar;
  final String? secili;

  /// `null`: seçim geçici olarak kapalı (gönderim sürüyor).
  final ValueChanged<String>? onSecildi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katilimcilarProvider(anahtar));
    final notifier = ref.read(katilimcilarProvider(anahtar).notifier);
    final onSecildi = this.onSecildi;
    return durum.when(
      data: (liste) {
        if (liste.ogeler.isEmpty) {
          return AracBilgisi(metin: m.bilesen_ranking_gelen_yok);
        }
        return RadioGroup<String>(
          groupValue: secili,
          onChanged: (id) {
            if (id != null) onSecildi?.call(id);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final kisi in liste.ogeler)
                RadioListTile<String>(
                  value: kisi.userId,
                  contentPadding: EdgeInsets.zero,
                  title: KullaniciAdiMetni(kullaniciId: kisi.userId),
                ),
              if (liste.dahaVar)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: liste.dahaYukleniyor
                        ? null
                        : () => unawaited(notifier.dahaFazla()),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.etkinlik_daha_fazla),
                  ),
                ),
            ],
          ),
        );
      },
      error: (hata, _) => HataSatiri.hatadan(hata),
      loading: () => const Center(child: TayfamYukleniyor(gecikmeli: true)),
    );
  }
}
