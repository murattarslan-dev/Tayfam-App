import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/tayfa_ayarlari.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa bilgileri (`/t/<tayfaId>/ayarlar/bilgiler`; ADR-0018 §1): ad,
/// açıklama, ilgi alanları, katılım politikası ve üyelerin etkinlik açıp
/// açamayacağı. Yalnızca değişen alanlar gönderilir (`PATCH`).
class TayfaBilgileriEkrani extends ConsumerWidget {
  const TayfaBilgileriEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final tayfa = ref.watch(tayfaOzetiProvider(tayfaId)).tayfa;
    final gorunum = ref.watch(tayfaGorunumuProvider(tayfaId));
    return Scaffold(
      appBar: AppBar(title: Text(m.yonetim_bilgiler)),
      body: tayfa == null
          ? Padding(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              child: ListeDurumu<Tayfa>(
                deger: null,
                hata: gorunum.error,
                onTekrar: () => ref.invalidate(tayfaGorunumuProvider(tayfaId)),
                icerik: (_) => const SizedBox.shrink(),
              ),
            )
          // Tayfa değişince (kayıttan sonra) form yeni değerlerle kurulur.
          : _BilgiFormu(
              key: ValueKey(tayfa.updatedAt),
              tayfaId: tayfaId,
              tayfa: tayfa,
            ),
    );
  }
}

class _BilgiFormu extends ConsumerStatefulWidget {
  const _BilgiFormu({super.key, required this.tayfaId, required this.tayfa});

  final String tayfaId;
  final Tayfa tayfa;

  @override
  ConsumerState<_BilgiFormu> createState() => _BilgiFormuState();
}

class _BilgiFormuState extends ConsumerState<_BilgiFormu> {
  late final TextEditingController _ad = TextEditingController(
    text: widget.tayfa.name,
  );
  late final TextEditingController _aciklama = TextEditingController(
    text: widget.tayfa.description,
  );
  late final Set<EventType> _ilgi = widget.tayfa.interests
      .where(ilgiAlanlari.contains)
      .toSet();
  late JoinPolicy _katilim = widget.tayfa.joinPolicy == JoinPolicy.unknown
      ? JoinPolicy.approval
      : widget.tayfa.joinPolicy;
  late bool _uyeEtkinlikAcar = widget.tayfa.membersCanCreateEvents;
  BilgiHatasi? _hata;

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final m = AppLocalizations.of(context);
    final hata = bilgiHatasi(ad: _ad.text, aciklama: _aciklama.text);
    setState(() => _hata = hata);
    if (hata != null) return;
    final istek = bilgiDegisiklikleri(
      widget.tayfa,
      ad: _ad.text,
      aciklama: _aciklama.text,
      ilgi: _ilgi,
      katilim: _katilim,
      uyeEtkinlikAcar: _uyeEtkinlikAcar,
    );
    final bildirici = SonucBildirici.al(context);
    if (istek == null) {
      bildirici.bildir(null, m.yonetim_kaydedildi);
      return;
    }
    final sonuc = await ref
        .read(tayfaAyarlariProvider(widget.tayfaId).notifier)
        .bilgileriKaydet(istek);
    bildirici.bildir(sonuc, m.yonetim_kaydedildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final mesgul = ref.watch(tayfaAyarlariProvider(widget.tayfaId));
    final govde = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return ListView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      children: [
        TextField(
          controller: _ad,
          maxLength: tayfaAdiEnCok,
          textCapitalization: TextCapitalization.sentences,
          enabled: !mesgul,
          decoration: InputDecoration(
            labelText: m.yonetim_ad_etiketi,
            errorText: _hata == BilgiHatasi.adUzunlugu
                ? m.yonetim_ad_hata
                : null,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        TextField(
          controller: _aciklama,
          maxLength: tayfaAciklamasiEnCok,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          enabled: !mesgul,
          decoration: InputDecoration(
            labelText: m.yonetim_aciklama_etiketi,
            errorText: _hata == BilgiHatasi.aciklamaUzunlugu
                ? m.yonetim_aciklama_hata
                : null,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        BolumBasligi(baslik: m.yonetim_ilgi_baslik),
        const SizedBox(height: TayfamSpacing.s8),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final tur in ilgiAlanlari)
              IlgiCipi(
                tur: tur,
                secili: _ilgi.contains(tur),
                onDegisti: mesgul
                    ? null
                    : () => setState(() {
                        if (!_ilgi.remove(tur)) _ilgi.add(tur);
                      }),
              ),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s24),
        BolumBasligi(baslik: m.yonetim_katilim_baslik),
        RadioGroup<JoinPolicy>(
          groupValue: _katilim,
          onChanged: (secim) {
            if (secim != null && !mesgul) setState(() => _katilim = secim);
          },
          child: Column(
            children: [
              RadioListTile<JoinPolicy>(
                value: JoinPolicy.approval,
                contentPadding: EdgeInsets.zero,
                title: Text(m.olusturma_onayli),
                subtitle: Text(m.olusturma_onayli_aciklama),
              ),
              RadioListTile<JoinPolicy>(
                value: JoinPolicy.open,
                contentPadding: EdgeInsets.zero,
                title: Text(m.olusturma_acik),
                subtitle: Text(m.olusturma_acik_aciklama),
              ),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(m.yonetim_uye_etkinlik),
          subtitle: Text(m.yonetim_uye_etkinlik_aciklama, style: govde),
          value: _uyeEtkinlikAcar,
          onChanged: mesgul
              ? null
              : (yeni) => setState(() => _uyeEtkinlikAcar = yeni),
        ),
        const SizedBox(height: TayfamSpacing.s24),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BirincilEylem(
            etiket: m.yonetim_kaydet,
            ikon: Icons.check,
            onPressed: mesgul ? null : () => unawaited(_kaydet()),
          ),
        ),
      ],
    );
  }
}
