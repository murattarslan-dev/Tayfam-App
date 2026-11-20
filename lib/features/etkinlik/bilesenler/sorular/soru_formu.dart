import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/istek_kimligi.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sorular/sorular_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru sorma formu (alttan sayfa): metin (1–500) ve bileşen izin
/// veriyorsa ([anonimAcik]) "Anonim sor" anahtarı. Anonim soruda adın
/// kimseye (yöneticilere de) gösterilmez; bu, anahtarın altında yazılıdır.
///
/// `client_request_id` form açılırken bir kez üretilir: hata sonrası
/// tekrar gönderim aynı soruyu iki kez oluşturmaz. Sunucu hatası formda
/// gösterilir, form açık kalır.
class SoruFormu extends StatefulWidget {
  const SoruFormu({super.key, required this.anonimAcik, required this.gonder});

  /// Bileşenin `anonymous` parametresi (`anonymous_allowed`).
  final bool anonimAcik;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventQuestionCreateRequest istek) gonder;

  @override
  State<SoruFormu> createState() => _SoruFormuState();
}

class _SoruFormuState extends State<SoruFormu> {
  final TextEditingController _metin = TextEditingController();
  final String _istekKimligi = yeniIstekKimligi();
  bool _anonim = false;
  bool _metinHatasi = false;
  bool _mesgul = false;
  Object? _hata;

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (_mesgul) return;
    final istek = soruIstegi(
      metin: _metin.text,
      anonim: widget.anonimAcik && _anonim,
      istekKimligi: _istekKimligi,
    );
    if (istek == null) {
      setState(() => _metinHatasi = true);
      return;
    }
    setState(() {
      _metinHatasi = false;
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(istek);
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
    final hata = _hata;
    return AracFormSayfasi(
      baslik: m.bilesen_questions_sor,
      onayEtiketi: m.bilesen_questions_gonder,
      onOnay: _mesgul ? null : () => unawaited(_gonder()),
      alanlar: [
        TextField(
          controller: _metin,
          autofocus: true,
          enabled: !_mesgul,
          maxLength: soruMetniEnCok,
          minLines: 2,
          maxLines: 6,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.bilesen_questions_metin_alani,
            errorText: _metinHatasi
                ? m.bilesen_questions_metin_hata(soruMetniEnCok)
                : null,
            errorMaxLines: 2,
          ),
        ),
        if (widget.anonimAcik)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              m.bilesen_questions_anonim_sor,
              style: context.yazi.titleMedium,
            ),
            subtitle: Text(
              m.bilesen_questions_anonim_aciklama,
              style: context.yazi.bodySmall?.copyWith(
                color: context.renkler.metinIkincil,
              ),
            ),
            value: _anonim,
            onChanged: _mesgul ? null : (v) => setState(() => _anonim = v),
          ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}
