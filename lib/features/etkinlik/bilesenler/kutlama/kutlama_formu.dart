import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kutlama/kutlama_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// İlanın onayı: ilan geri alınamaz ve tayfaya bildirim gider.
Future<bool> kutlamaIlanOnayi(BuildContext context) {
  final m = AppLocalizations.of(context);
  return cikarmaOnayi(
    context,
    baslik: m.bilesen_celebration_ilan_onay,
    metin: m.bilesen_celebration_ilan_onay_aciklama,
    eylem: m.bilesen_celebration_ilan_et,
  );
}

/// Elle seçilen kutlamada kazananları seçme formu (alttan sayfa):
/// etkinliğe "Geliyorum" diyenlerden 1–10 kişi. [onayGerekli] ise (ilk
/// ilan) göndermeden önce ilanın geri alınamayacağı söylenip onay istenir.
/// Sunucu hatası (ör. `celebration-not-participant`) formda gösterilir,
/// form açık kalır.
class KutlamaFormu extends ConsumerStatefulWidget {
  const KutlamaFormu({
    super.key,
    required this.baslik,
    required this.katilimcilar,
    required this.ilkSecim,
    required this.onayGerekli,
    required this.gonder,
  });

  final String baslik;

  /// Seçilebilen kişiler (etkinliğe gelenler).
  final KatilimcilarAnahtari katilimcilar;

  /// Yeniden ilanda şimdiki kazananlar.
  final List<String> ilkSecim;

  final bool onayGerekli;

  /// Seçilen kişileri ilan eder; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(List<String> kazananlar) gonder;

  @override
  ConsumerState<KutlamaFormu> createState() => _KutlamaFormuState();
}

class _KutlamaFormuState extends ConsumerState<KutlamaFormu> {
  late final List<String> _secilenler = [...widget.ilkSecim];
  bool _secimHatasi = false;
  bool _mesgul = false;
  Object? _hata;

  void _degistir(String kisi, bool secili) {
    setState(() {
      if (secili) {
        if (!_secilenler.contains(kisi) &&
            _secilenler.length < kutlamaKazananEnCok) {
          _secilenler.add(kisi);
        }
      } else {
        _secilenler.remove(kisi);
      }
      _secimHatasi = false;
      _hata = null;
    });
  }

  Future<void> _kaydet() async {
    if (_mesgul) return;
    if (_secilenler.length < kutlamaKazananEnAz) {
      setState(() => _secimHatasi = true);
      return;
    }
    if (widget.onayGerekli) {
      final onay = await kutlamaIlanOnayi(context);
      if (!onay || !mounted) return;
    }
    setState(() {
      _hata = null;
      _mesgul = true;
    });
    final hata = await widget.gonder(List<String>.of(_secilenler));
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
      baslik: widget.baslik,
      onayEtiketi: widget.onayGerekli
          ? m.bilesen_celebration_ilan_et
          : m.etkinlik_kaydet,
      onOnay: _mesgul ? null : () => unawaited(_kaydet()),
      alanlar: [
        AracBilgisi(
          metin: m.bilesen_celebration_sec_aciklama(kutlamaKazananEnCok),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        _GelenSecici(
          anahtar: widget.katilimcilar,
          secilenler: _secilenler,
          onDegisti: _mesgul ? null : _degistir,
        ),
        if (_secimHatasi) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri(metin: m.bilesen_celebration_sec_hata),
        ],
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// Etkinliğe "Geliyorum" diyenler (ilk sayfa ve "Daha fazla"), çoklu
/// seçimle. Sınıra ulaşınca seçilmemiş kutular kapanır.
class _GelenSecici extends ConsumerWidget {
  const _GelenSecici({
    required this.anahtar,
    required this.secilenler,
    required this.onDegisti,
  });

  final KatilimcilarAnahtari anahtar;
  final List<String> secilenler;

  /// `null`: seçim geçici olarak kapalı (gönderim sürüyor).
  final void Function(String kisi, bool secili)? onDegisti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katilimcilarProvider(anahtar));
    final notifier = ref.read(katilimcilarProvider(anahtar).notifier);
    final onDegisti = this.onDegisti;
    final dolu = secilenler.length >= kutlamaKazananEnCok;
    return durum.when(
      data: (liste) {
        if (liste.ogeler.isEmpty) {
          return AracBilgisi(metin: m.bilesen_celebration_gelen_yok);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final kisi in liste.ogeler)
              CheckboxListTile(
                value: secilenler.contains(kisi.userId),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged:
                    onDegisti == null ||
                        (dolu && !secilenler.contains(kisi.userId))
                    ? null
                    : (deger) => onDegisti(kisi.userId, deger ?? false),
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
        );
      },
      error: (hata, _) => HataSatiri.hatadan(hata),
      loading: () => const Center(child: TayfamYukleniyor(gecikmeli: true)),
    );
  }
}
