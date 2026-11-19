import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Değer girme ve düzeltme formu (alttan sayfa): sayı alanı (birimi
/// sonunda, Türkçe ondalık ayracı; nokta da kabul edilir) ve
/// [kisiSecimi] verildiyse "Kimin değeri?" (etkinliğe "Geliyorum"
/// diyenler). Sınırlar ve basamak ölçümün kendisindendir; sunucu hatası
/// (ör. `measurement-not-participant`) formda gösterilir, form açık kalır.
class OlcumFormu extends ConsumerStatefulWidget {
  const OlcumFormu({
    super.key,
    required this.olcum,
    required this.baslik,
    required this.gonder,
    this.ilkDeger,
    this.kisiSecimi,
  });

  final EventMeasure olcum;
  final String baslik;

  /// Düzeltmede kayıtlı ya da önerilen değer.
  final double? ilkDeger;

  /// Verilirse önce kişi seçilir (organizatörün girdiği kişisel ölçüm).
  final KatilimcilarAnahtari? kisiSecimi;

  /// İsteği gönderir ([kisi]: seçilen kişi, seçim yoksa `null`); başarıda
  /// `null`, değilse hata döner.
  final Future<Object?> Function(String? kisi, double deger) gonder;

  @override
  ConsumerState<OlcumFormu> createState() => _OlcumFormuState();
}

class _OlcumFormuState extends ConsumerState<OlcumFormu> {
  late final TextEditingController _deger;
  AlanHatasi? _alanHatasi;
  String? _secilenKisi;
  bool _kisiHatasi = false;
  bool _mesgul = false;
  Object? _hata;

  /// Sayı alanının en çok karakteri (işaret, 10 basamak, ayraç, 3 basamak).
  static const int _sayiUzunlugu = 16;

  @override
  void initState() {
    super.initState();
    _deger = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deger.text.isEmpty && widget.ilkDeger != null) {
      _deger.text = olcumGirdisi(
        AppLocalizations.of(context),
        widget.olcum,
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
    final okunan = olcumGirdisiniOku(widget.olcum, _deger.text);
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
    final olcum = widget.olcum;
    final basamak = olcumBasamagi(olcum);
    final alanHatasi = _alanHatasi;
    // Hata metni ana metin rengindedir (ADR-0004); hatayı kenar rengi ve
    // metin taşır.
    final hataStili = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metin,
    );
    final kisiSecimi = widget.kisiSecimi;
    final hata = _hata;
    return AracFormSayfasi(
      baslik: widget.baslik,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        if (kisiSecimi != null) ...[
          Text(m.bilesen_measure_kisi_sec, style: context.yazi.titleSmall),
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
            HataSatiri(metin: m.bilesen_measure_kisi_sec_hata),
          ],
          const SizedBox(height: TayfamSpacing.s16),
        ],
        TextField(
          key: const ValueKey('olcum-degeri'),
          controller: _deger,
          autofocus: kisiSecimi == null,
          enabled: !_mesgul,
          keyboardType: TextInputType.numberWithOptions(
            decimal: basamak > 0,
            signed: olcum.min < 0,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(basamak > 0 ? r'[0-9.,-]' : r'[0-9-]'),
            ),
            LengthLimitingTextInputFormatter(_sayiUzunlugu),
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
            labelText: m.bilesen_measure_deger_alani,
            suffixText: katalogBirimAdi(m, olcum.unit),
            helperText: m.bilesen_measure_aralik(
              olcumSayisi(m, olcum.min, basamak),
              olcumSayisi(m, olcum.max, basamak),
            ),
            helperMaxLines: 2,
            errorText: alanHatasi == null
                ? null
                : olcumHataMetni(m, olcum, alanHatasi),
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

/// "Kimin değeri?": etkinliğe "Geliyorum" diyenler (ilk sayfa ve "Daha
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
          return AracBilgisi(metin: m.bilesen_measure_gelen_yok);
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
