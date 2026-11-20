import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Düzeltilen oyunun sonucu, istek türünde.
EventBracketGameRequestAOutcome? _istekSonucu(EventBracketGameAOutcome? s) =>
    switch (s) {
      EventBracketGameAOutcome.win => EventBracketGameRequestAOutcome.win,
      EventBracketGameAOutcome.draw => EventBracketGameRequestAOutcome.draw,
      EventBracketGameAOutcome.loss => EventBracketGameRequestAOutcome.loss,
      _ => null,
    };

/// Bir maçın oyununu girme ya da düzeltme formu (alttan sayfa). Puan
/// kuralında iki tarafın puanı birlikte, galibiyet/beraberlik/mağlubiyet
/// kuralında tek seçim ("Ayşe kazandı", "Berabere", "Can kazandı").
/// Elemede berabere biten maçın ek oyunla süreceği yazılır.
class AgacOyunFormu extends ConsumerStatefulWidget {
  const AgacOyunFormu({
    super.key,
    required this.kimlik,
    required this.agac,
    required this.mac,
    required this.oyun,
    required this.gonder,
    this.duzeltilen,
  });

  final AgacKimligi kimlik;
  final EventBracket agac;
  final EventBracketMatch mac;

  /// Oyunun numarası.
  final int oyun;

  final EventBracketGame? duzeltilen;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(EventBracketGameRequest istek) gonder;

  @override
  ConsumerState<AgacOyunFormu> createState() => _AgacOyunFormuState();
}

class _AgacOyunFormuState extends ConsumerState<AgacOyunFormu> {
  late final TextEditingController _a;
  late final TextEditingController _b;
  EventBracketGameRequestAOutcome? _sonuc;
  Set<String> _hatalilar = const {};
  bool _bos = false;
  bool _mesgul = false;
  Object? _hata;

  bool get _sonucModu => widget.agac.result == EventBracketResult.wdl;

  @override
  void initState() {
    super.initState();
    final d = widget.duzeltilen;
    _a = TextEditingController(text: d?.aPoints?.toString() ?? '');
    _b = TextEditingController(text: d?.bPoints?.toString() ?? '');
    _sonuc = _istekSonucu(d?.aOutcome);
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _degisti() => setState(() {
    _hatalilar = const {};
    _bos = false;
    _hata = null;
  });

  Future<void> _kaydet() async {
    if (_mesgul) return;
    EventBracketGameRequest? istek;
    if (_sonucModu) {
      final sonuc = _sonuc;
      if (sonuc != null) istek = EventBracketGameRequest(aOutcome: sonuc);
    } else {
      final sonuc = agacPuanIstegi(_a.text, _b.text);
      istek = sonuc.istek;
      if (istek == null && sonuc.hatali.isNotEmpty) {
        setState(() => _hatalilar = sonuc.hatali);
        return;
      }
    }
    if (istek == null) {
      setState(() => _bos = true);
      return;
    }
    setState(() {
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

  Widget _puanAlani(
    AppLocalizations m,
    String taraf,
    String ad,
    TextEditingController c,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: TayfamSpacing.s8),
    child: TextField(
      key: ValueKey('agac-puan-$taraf'),
      controller: c,
      enabled: !_mesgul,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp('[-0-9]')),
        LengthLimitingTextInputFormatter(8),
      ],
      onChanged: (_) => _degisti(),
      decoration: InputDecoration(
        labelText: m.bilesen_bracket_puan_alani(ad),
        errorText: _hatalilar.contains(taraf)
            ? m.bilesen_bracket_puan_hatali
            : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final hata = _hata;
    final agac = widget.agac;
    final mac = widget.mac;
    final takimlar = agacTakimlari(widget.kimlik, agac);
    final aAd = agacYerAdi(ref, m, agac, takimlar, mac.aPosition);
    final bAd = agacYerAdi(ref, m, agac, takimlar, mac.bPosition);
    return AracFormSayfasi(
      baslik: widget.duzeltilen == null
          ? m.bilesen_bracket_oyun_baslik(widget.oyun)
          : m.bilesen_bracket_duzelt_baslik(widget.oyun),
      onayEtiketi: m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        AracBilgisi(
          metin: m.bilesen_bracket_mac_basligi(
            m.bilesen_bracket_ozet(mac.round, mac.slot),
            aAd,
            bAd,
          ),
        ),
        if (agac.format == EventBracketFormat.elimination) ...[
          const SizedBox(height: TayfamSpacing.s4),
          AracBilgisi(metin: m.bilesen_bracket_ek_oyun(agacOyunEnCok)),
        ],
        const SizedBox(height: TayfamSpacing.s8),
        if (_sonucModu)
          Semantics(
            label: m.bilesen_bracket_sonuc_alani,
            child: SecimCipleri<EventBracketGameRequestAOutcome>(
              secenekler: [
                (
                  EventBracketGameRequestAOutcome.win,
                  m.bilesen_bracket_kazandi(aAd),
                ),
                (
                  EventBracketGameRequestAOutcome.draw,
                  m.bilesen_bracket_berabere,
                ),
                (
                  EventBracketGameRequestAOutcome.loss,
                  m.bilesen_bracket_kazandi(bAd),
                ),
              ],
              secili: _sonuc,
              onSecildi: _mesgul
                  ? null
                  : (sonuc) {
                      _sonuc = sonuc;
                      _degisti();
                    },
            ),
          )
        else ...[
          _puanAlani(m, 'a', aAd, _a),
          _puanAlani(m, 'b', bAd, _b),
        ],
        if (_bos)
          HataSatiri(
            metin: _sonucModu
                ? m.bilesen_bracket_sonuc_yok
                : m.bilesen_bracket_puan_yok,
          ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}
