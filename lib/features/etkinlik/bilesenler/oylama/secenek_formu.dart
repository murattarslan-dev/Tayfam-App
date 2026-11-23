import 'dart:async';

import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/oylama/oylama_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Serbest oylamaya seçenek ekleme formu (alttan sayfa): tek metin alanı
/// (kırpıldıktan sonra 1–100 karakter). Sunucu hatası (ör.
/// `vote-option-exists`) formda gösterilir, form açık kalır.
class OylamaSecenekFormu extends StatefulWidget {
  const OylamaSecenekFormu({super.key, required this.gonder});

  /// Seçeneği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(String etiket) gonder;

  @override
  State<OylamaSecenekFormu> createState() => _OylamaSecenekFormuState();
}

class _OylamaSecenekFormuState extends State<OylamaSecenekFormu> {
  final TextEditingController _metin = TextEditingController();
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
    final etiket = oylamaEtiketi(_metin.text);
    if (etiket == null) {
      setState(() => _metinHatasi = true);
      return;
    }
    setState(() {
      _metinHatasi = false;
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(etiket);
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
      baslik: m.bilesen_vote_secenek_ekle,
      onayEtiketi: m.bilesen_vote_ekle,
      onOnay: _mesgul ? null : () => unawaited(_gonder()),
      alanlar: [
        TextField(
          controller: _metin,
          autofocus: true,
          enabled: !_mesgul,
          maxLength: oylamaEtiketiEnCok,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => unawaited(_gonder()),
          decoration: InputDecoration(
            labelText: m.bilesen_vote_secenek_alani,
            errorText: _metinHatasi
                ? m.bilesen_vote_secenek_hata(oylamaEtiketiEnCok)
                : null,
            errorMaxLines: 2,
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
