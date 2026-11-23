import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/liste/liste_durumu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/sihirbaz_ogeleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Kim?" seçenekleri (tasarım: Etkinlik-Malzeme-Ekle).
enum MaddeUstlenen {
  /// Kendisi (`assigned_user_id` = kendi kimliği).
  ben,

  /// Henüz kimse (alan gönderilmez).
  kimse,

  /// Etkinliğe gelenlerden biri.
  kisi,
}

/// Madde ekleme formu (tasarım: Etkinlik-Malzeme-Ekle): ad (60), adet
/// sayacı (1–999; yalnızca [adetAcik]) ve "Kim getirecek?" Ben / Henüz
/// kimse / Kişi seç (yalnızca [atamaAcik]). Formu yalnızca yönetim açar;
/// "Kişi seç" "Geliyorum" diyenlerden seçer. Atanan kişi `going` değilse
/// sunucu `event-not-going` döner; form açık kalır ve hatayı gösterir.
///
/// [etiket] listenin `label`'ıdır (`gear`, `task`, `section`, `duty`,
/// `item`); metinler ona göre seçilir.
class MaddeFormu extends ConsumerStatefulWidget {
  const MaddeFormu({
    super.key,
    required this.kimlik,
    required this.etiket,
    required this.adetAcik,
    required this.atamaAcik,
    required this.gonder,
  });

  final ListeKimligi kimlik;
  final String etiket;
  final bool adetAcik;
  final bool atamaAcik;

  /// İsteği gönderir; başarıda `null`, değilse hata döner.
  final Future<Object?> Function(ChecklistItemRequest istek) gonder;

  @override
  ConsumerState<MaddeFormu> createState() => _MaddeFormuState();
}

class _MaddeFormuState extends ConsumerState<MaddeFormu> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _adet = TextEditingController(text: '1');
  MaddeUstlenen _ustlenen = MaddeUstlenen.kimse;
  String? _secilenKisi;
  Set<MaddeHatasi> _hatalar = const {};
  bool _kisiHatasi = false;
  bool _mesgul = false;
  Object? _hata;

  KatilimcilarAnahtari get _gelenler => (
    tayfaId: widget.kimlik.tayfaId,
    etkinlikId: widget.kimlik.etkinlikId,
    durum: ListEventAttendeesStatus.going,
  );

  @override
  void dispose() {
    _ad.dispose();
    _adet.dispose();
    super.dispose();
  }

  Future<void> _ekle() async {
    if (_mesgul) return;
    final String? ustlenen;
    switch (widget.atamaAcik ? _ustlenen : MaddeUstlenen.kimse) {
      case MaddeUstlenen.ben:
        ustlenen = ref.read(kendiKimligimProvider).value;
      case MaddeUstlenen.kimse:
        ustlenen = null;
      case MaddeUstlenen.kisi:
        ustlenen = _secilenKisi;
    }
    final sonuc = maddeIstegi(
      ad: _ad.text,
      adet: _adet.text,
      adetAcik: widget.adetAcik,
      ustlenen: ustlenen,
    );
    final kisiEksik =
        widget.atamaAcik &&
        _ustlenen != MaddeUstlenen.kimse &&
        ustlenen == null;
    final istek = sonuc.istek;
    if (istek == null || kisiEksik) {
      setState(() {
        _hatalar = sonuc.hatalar;
        _kisiHatasi = kisiEksik;
      });
      return;
    }
    setState(() {
      _hatalar = const {};
      _kisiHatasi = false;
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
    final etiket = widget.etiket;
    final hata = _hata;
    final benBilinir = ref.watch(kendiKimligimProvider).value != null;
    return AracFormSayfasi(
      baslik: m.bilesen_checklist_ekle(etiket),
      onayEtiketi: m.etkinlik_ekle,
      onOnay: _mesgul ? null : () => unawaited(_ekle()),
      alanlar: [
        TextField(
          controller: _ad,
          autofocus: true,
          maxLength: maddeAdiEnCok,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.bilesen_checklist_ad_alani(etiket),
            errorText: _hatalar.contains(MaddeHatasi.ad)
                ? m.bilesen_checklist_ad_hata(maddeAdiEnCok)
                : null,
            errorMaxLines: 2,
          ),
        ),
        if (widget.adetAcik) ...[
          const SizedBox(height: TayfamSpacing.s8),
          SayiSayaci(
            denetleyici: _adet,
            etiket: m.bilesen_checklist_adet_etiketi,
            enAz: 1,
            enCok: maddeAdediEnCok,
            etkin: !_mesgul,
            onDegisti: (_) => setState(() {}),
          ),
          if (_hatalar.contains(MaddeHatasi.adet))
            Padding(
              padding: const EdgeInsets.only(top: TayfamSpacing.s4),
              child: HataSatiri(metin: m.etkinlik_sayi_hata(maddeAdediEnCok)),
            ),
        ],
        if (widget.atamaAcik) ...[
          const SizedBox(height: TayfamSpacing.s16),
          Text(m.bilesen_checklist_kim(etiket), style: context.yazi.titleSmall),
          const SizedBox(height: TayfamSpacing.s8),
          SecimCipleri<MaddeUstlenen>(
            secenekler: [
              if (benBilinir) (MaddeUstlenen.ben, m.bilesen_checklist_kim_ben),
              (MaddeUstlenen.kimse, m.bilesen_checklist_kim_kimse),
              (MaddeUstlenen.kisi, m.bilesen_checklist_kim_kisi),
            ],
            secili: _ustlenen,
            onSecildi: _mesgul
                ? null
                : (u) => setState(() {
                    _ustlenen = u;
                    _kisiHatasi = false;
                    _hata = null;
                  }),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_checklist_kisi_sec_notu),
          if (_ustlenen == MaddeUstlenen.kisi) ...[
            const SizedBox(height: TayfamSpacing.s8),
            _GelenSecici(
              anahtar: _gelenler,
              secili: _secilenKisi,
              onSecildi: (id) => setState(() {
                _secilenKisi = id;
                _kisiHatasi = false;
              }),
            ),
          ],
          if (_kisiHatasi) ...[
            const SizedBox(height: TayfamSpacing.s8),
            HataSatiri(metin: m.bilesen_checklist_kisi_sec_hata),
          ],
        ],
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          HataSatiri.hatadan(hata),
        ],
      ],
    );
  }
}

/// "Kişi seç": etkinliğe "Geliyorum" diyenler (ilk sayfa ve "Daha fazla").
class _GelenSecici extends ConsumerWidget {
  const _GelenSecici({
    required this.anahtar,
    required this.secili,
    required this.onSecildi,
  });

  final KatilimcilarAnahtari anahtar;
  final String? secili;
  final ValueChanged<String> onSecildi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katilimcilarProvider(anahtar));
    final notifier = ref.read(katilimcilarProvider(anahtar).notifier);
    return durum.when(
      data: (liste) {
        if (liste.ogeler.isEmpty) {
          return AracBilgisi(metin: m.bilesen_checklist_gelen_yok);
        }
        return RadioGroup<String>(
          groupValue: secili,
          onChanged: (id) {
            if (id != null) onSecildi(id);
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
