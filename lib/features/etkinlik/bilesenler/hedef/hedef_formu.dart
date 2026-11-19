import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Hedef koyma ve değiştirme formu (alttan sayfa): sayı alanı (bağlı
/// ölçümün birimi sonunda, Türkçe ondalık ayracı; nokta da kabul edilir).
/// Değer sıfırdan büyük olmalı; ölçümün üst sınırını sunucu denetler ve
/// hatası (`invalid-request` vb.) formda gösterilir, form açık kalır.
class HedefFormu extends StatefulWidget {
  const HedefFormu({
    super.key,
    required this.hedef,
    required this.gonder,
  });

  final EventGoal hedef;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(double deger) gonder;

  @override
  State<HedefFormu> createState() => _HedefFormuState();
}

class _HedefFormuState extends State<HedefFormu> {
  late final TextEditingController _deger;
  AlanHatasi? _alanHatasi;
  bool _mesgul = false;
  Object? _hata;

  /// Sayı alanının en çok karakteri (10 basamak, ayraç, 3 basamak).
  static const int _sayiUzunlugu = 15;

  @override
  void initState() {
    super.initState();
    _deger = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ilk = widget.hedef.target;
    if (_deger.text.isEmpty && ilk != null) {
      _deger.text = olcumSayisi(
        AppLocalizations.of(context),
        ilk,
        hedefBasamagi(widget.hedef),
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
    final okunan = hedefGirdisiniOku(widget.hedef, _deger.text);
    final deger = okunan.deger;
    if (deger == null) {
      setState(() => _alanHatasi = okunan.hata);
      return;
    }
    setState(() {
      _alanHatasi = null;
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(deger);
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

  String _hataMetni(AppLocalizations m, AlanHatasi hata) => switch (hata) {
    AlanHatasi.aralik => m.bilesen_goal_hedef_pozitif,
    AlanHatasi.basamak => m.katalog_alan_basamak(hedefBasamagi(widget.hedef)),
    AlanHatasi.zorunlu => m.katalog_alan_zorunlu,
    _ => m.katalog_alan_sayi,
  };

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hedef = widget.hedef;
    final basamak = hedefBasamagi(hedef);
    final alanHatasi = _alanHatasi;
    // Hata metni ana metin rengindedir (ADR-0004); hatayı kenar rengi ve
    // metin taşır.
    final hataStili = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metin,
    );
    final hata = _hata;
    final varsayilan = hedef.defaultTarget;
    return AracFormSayfasi(
      baslik: hedef.targetSet || hedef.target != null
          ? m.bilesen_goal_degistir
          : m.bilesen_goal_koy,
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        TextField(
          key: const ValueKey('hedef-degeri'),
          controller: _deger,
          autofocus: true,
          enabled: !_mesgul,
          keyboardType: TextInputType.numberWithOptions(decimal: basamak > 0),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(basamak > 0 ? r'[0-9.,]' : r'[0-9]'),
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
            labelText: m.bilesen_goal_deger_alani,
            suffixText: katalogBirimAdi(m, hedef.unit),
            helperText: varsayilan == null
                ? m.bilesen_goal_hedef_pozitif
                : m.bilesen_goal_varsayilan_ipucu(
                    hedefDegeriMetni(m, hedef, varsayilan),
                  ),
            helperMaxLines: 3,
            errorText: alanHatasi == null ? null : _hataMetni(m, alanHatasi),
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
