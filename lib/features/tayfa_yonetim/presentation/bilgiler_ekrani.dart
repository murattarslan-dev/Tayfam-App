import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/tayfa_ayarlari.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa bilgileri (`/t/<tayfaId>/ayarlar/bilgiler`; ADR-0018 §1; tasarım:
/// Ayar-Bilgiler): kapak fotoğrafı (ADR-0021), ad, açıklama, ilgi
/// alanları, katılım politikası ve üyelerin etkinlik açıp açamayacağı.
/// Yalnızca değişen alanlar gönderilir (`PATCH`).
///
/// Alttaki çubukta kaydedilmemiş değişiklik sayısı; değişiklik yoksa
/// "Kaydet" kapalıdır. Kaydedilmemiş değişiklikle geri çıkılırken onay
/// istenir.
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
  late String? _kapak = widget.tayfa.coverUploadId;
  BilgiHatasi? _hata;

  @override
  void initState() {
    super.initState();
    _ad.addListener(_degisti);
    _aciklama.addListener(_degisti);
  }

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  void _degisti() => setState(() {});

  /// Formdaki değerlerin sunucudaki tayfadan farkı; değişiklik yoksa
  /// `null` (değişen alanların sayısı çubukta gösterilir).
  TayfaUpdateRequest? get _degisiklikler => bilgiDegisiklikleri(
    widget.tayfa,
    ad: _ad.text,
    aciklama: _aciklama.text,
    ilgi: _ilgi,
    katilim: _katilim,
    uyeEtkinlikAcar: _uyeEtkinlikAcar,
    kapak: _kapak,
  );

  /// Kaydedilmemiş değişiklikle geri çıkılırken onay ister.
  Future<void> _cikmayiSor() async {
    final m = AppLocalizations.of(context);
    final cik = await onayIste(
      context,
      baslik: m.yonetim_cikis_baslik,
      aciklama: m.yonetim_cikis_aciklama,
      onay: m.yonetim_cikis_onayla,
      yikici: true,
    );
    if (cik && mounted) Navigator.of(context).pop();
  }

  Future<void> _kaydet() async {
    final m = AppLocalizations.of(context);
    final hata = bilgiHatasi(ad: _ad.text, aciklama: _aciklama.text);
    setState(() => _hata = hata);
    if (hata != null) return;
    final istek = _degisiklikler;
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
    final mesgul = ref.watch(tayfaAyarlariProvider(widget.tayfaId));
    final r = context.renkler;
    final govde = context.yazi.bodyMedium?.copyWith(color: r.metinGovde);
    final degisiklik = _degisiklikler?.toJson().length ?? 0;
    return PopScope(
      canPop: degisiklik == 0,
      onPopInvokedWithResult: (cikti, _) {
        if (!cikti) unawaited(_cikmayiSor());
      },
      child: Column(
        children: [
          Expanded(
            child: _alanlar(context, mesgul: mesgul, govde: govde),
          ),
          _KaydetCubugu(
            degisiklik: degisiklik,
            onKaydet: mesgul || degisiklik == 0
                ? null
                : () => unawaited(_kaydet()),
          ),
        ],
      ),
    );
  }

  Widget _alanlar(
    BuildContext context, {
    required bool mesgul,
    required TextStyle? govde,
  }) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return ListView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      children: [
        BolumBasligi(baslik: m.medya_kapak_etiketi),
        const SizedBox(height: TayfamSpacing.s8),
        Text(m.yonetim_kapak_aciklama, style: govde),
        const SizedBox(height: TayfamSpacing.s8),
        FotografAlani(
          amac: UploadPurpose.cover,
          tayfaId: widget.tayfaId,
          deger: _kapak,
          etiket: m.medya_kapak_etiketi,
          etkin: !mesgul,
          onDegisti: (yeni) => setState(() => _kapak = yeni),
        ),
        const SizedBox(height: TayfamSpacing.s16),
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
        const SizedBox(height: TayfamSpacing.s8),
        RadioGroup<JoinPolicy>(
          groupValue: _katilim,
          onChanged: (secim) {
            if (secim != null && !mesgul) setState(() => _katilim = secim);
          },
          child: Column(
            children: [
              _SecimKarti(
                secili: _katilim == JoinPolicy.approval,
                child: RadioListTile<JoinPolicy>(
                  value: JoinPolicy.approval,
                  title: Text(m.olusturma_onayli),
                  subtitle: Text(m.olusturma_onayli_aciklama, style: govde),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s8),
              _SecimKarti(
                secili: _katilim == JoinPolicy.open,
                child: RadioListTile<JoinPolicy>(
                  value: JoinPolicy.open,
                  title: Text(m.olusturma_acik),
                  subtitle: Text(m.olusturma_acik_aciklama, style: govde),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        _SecimKarti(
          secili: false,
          child: SwitchListTile(
            title: Text(m.yonetim_uye_etkinlik),
            subtitle: Text(m.yonetim_uye_etkinlik_aciklama, style: govde),
            value: _uyeEtkinlikAcar,
            activeTrackColor: r.marka,
            onChanged: mesgul
                ? null
                : (yeni) => setState(() => _uyeEtkinlikAcar = yeni),
          ),
        ),
      ],
    );
  }
}

/// Seçenek kartı: seçiliyse brand kenar (2 px), değilse çizgi kenar.
class _SecimKarti extends StatelessWidget {
  const _SecimKarti({required this.secili, required this.child});

  final bool secili;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.secimKoseleri,
        side: BorderSide(
          color: secili ? r.marka : r.cizgi,
          width: secili ? TayfamSizes.alanOdakKenari : TayfamSizes.vurguKenari,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Bilgiler ekranının altındaki çubuk: değişiklik sayısı ve "Kaydet"
/// (değişiklik yoksa kapalı).
class _KaydetCubugu extends StatelessWidget {
  const _KaydetCubugu({required this.degisiklik, required this.onKaydet});

  final int degisiklik;
  final VoidCallback? onKaydet;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
            vertical: TayfamSpacing.s12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    m.yonetim_degisiklik_sayisi(degisiklik),
                    style: context.yazi.bodySmall,
                  ),
                ),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              BirincilEylem(etiket: m.yonetim_kaydet, onPressed: onKaydet),
            ],
          ),
        ),
      ),
    );
  }
}
