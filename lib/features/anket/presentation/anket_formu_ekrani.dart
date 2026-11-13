import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_formu_notifier.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anket oluşturma formu (tasarım: Anket-Form; ADR-0018 §5): üstte kapat
/// (X), "Yeni anket" ve "Anketi aç"; soru, 2–10 seçenek (ekle/kaldır),
/// "Birden çok seçenek seçilebilsin" ve "Gizli anket" anahtarları ve
/// isteğe bağlı kapanış zamanı kutusu.
///
/// Kabuğun üstünde tam ekran açılır. Bağlantı yoksa form açık kalır ve
/// girilenler korunur (ADR-0006). Başarıda form kapanır ve anketi
/// döndürür.
class AnketFormuEkrani extends ConsumerStatefulWidget {
  const AnketFormuEkrani({super.key, required this.tayfaId, this.etkinlikId});

  final String tayfaId;

  /// Anketin bağlanacağı etkinlik; yoksa `null`.
  final String? etkinlikId;

  @override
  ConsumerState<AnketFormuEkrani> createState() => _AnketFormuEkraniState();
}

class _AnketFormuEkraniState extends ConsumerState<AnketFormuEkrani> {
  final TextEditingController _soru = TextEditingController();
  final List<TextEditingController> _secenekler = [
    TextEditingController(),
    TextEditingController(),
  ];

  AnketFormuAnahtari get _anahtar =>
      (tayfaId: widget.tayfaId, etkinlikId: widget.etkinlikId);

  AnketFormuNotifier get _notifier =>
      ref.read(anketFormuProvider(_anahtar).notifier);

  @override
  void dispose() {
    _soru.dispose();
    for (final c in _secenekler) {
      c.dispose();
    }
    super.dispose();
  }

  void _secenekEkle() {
    if (!ref.read(anketFormuProvider(_anahtar)).secenekEklenebilir) return;
    _notifier.secenekEkle();
    setState(() => _secenekler.add(TextEditingController()));
  }

  void _secenekKaldir(int sira) {
    if (!ref.read(anketFormuProvider(_anahtar)).secenekKaldirilabilir) return;
    _notifier.secenekKaldir(sira);
    setState(() => _secenekler.removeAt(sira).dispose());
  }

  /// Kapanış günü ve saatini seçtirir; seçim cihazın saatidir, UTC'ye
  /// çevrilir.
  Future<void> _kapanisSec() async {
    final simdi = ref.read(anketSaatiProvider)().toLocal();
    final mevcut = ref.read(anketFormuProvider(_anahtar)).kapanis?.toLocal();
    final baslangic = mevcut ?? simdi.add(const Duration(days: 1));
    final ilkGun = DateTime(simdi.year, simdi.month, simdi.day);
    final sonGun = ilkGun.add(anketKapanisEnCok);
    final secilen = DateTime(baslangic.year, baslangic.month, baslangic.day);
    final gun = await showDatePicker(
      context: context,
      initialDate: secilen.isBefore(ilkGun)
          ? ilkGun
          : (secilen.isAfter(sonGun) ? sonGun : secilen),
      firstDate: ilkGun,
      lastDate: sonGun,
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: baslangic.hour, minute: baslangic.minute),
    );
    if (saat == null || !mounted) return;
    _notifier.kapanisAyarla(
      DateTime(gun.year, gun.month, gun.day, saat.hour, saat.minute).toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = anketFormuProvider(_anahtar);
    ref.listen(saglayici, (_, sonraki) {
      final anket = sonraki.tamamlanan;
      if (anket != null) Navigator.of(context).pop(anket);
    });
    final d = ref.watch(saglayici);
    final kilitli = d.gonderiliyor;
    final simdi = ref.watch(anketSaatiProvider)().toUtc();
    final secenekHatasi = d.denendi
        ? secenekHatalari(d.secenekler)
        : const <int, SecenekHatasi>{};
    final kapanis = d.kapanis;
    final kapanisHatali =
        d.denendi && kapanis != null && !anketKapanisiGecerli(kapanis, simdi);
    final gizliNotu = [
      m.anket_gizli_aciklama,
      m.anket_form_gizli_notu,
    ].join(' ');
    final aciklama = context.yazi.labelSmall?.copyWith(
      color: r.metinIkincil,
      fontWeight: FontWeight.w400,
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: sohbetUstCubukYuksekligi(context),
        title: Text(
          m.anket_form_baslik,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          BirincilEylem(
            etiket: m.anket_form_gonder,
            onPressed: kilitli ? null : () => unawaited(_notifier.gonder()),
          ),
          const SizedBox(width: TayfamSpacing.s12),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.s20,
                TayfamSpacing.s8,
                TayfamSpacing.s20,
                TayfamSpacing.s40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d.hata case final hata?) ...[
                    HataSatiri.hatadan(hata),
                    const SizedBox(height: TayfamSpacing.s16),
                  ],
                  if (widget.etkinlikId != null) ...[
                    Text(
                      m.anket_form_etkinlik_notu,
                      style: context.yazi.bodySmall,
                    ),
                    const SizedBox(height: TayfamSpacing.s16),
                  ],
                  TextField(
                    controller: _soru,
                    autofocus: true,
                    enabled: !kilitli,
                    maxLength: anketSorusuEnCok,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onChanged: _notifier.soruAyarla,
                    decoration: InputDecoration(
                      labelText: m.anket_form_soru,
                      errorText: d.denendi && !anketSorusuGecerli(d.soru)
                          ? m.anket_form_soru_hatasi
                          : null,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: m.anket_form_secenekler),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: m.anket_form_secenek_araligi(
                              anketSecenekEnAz,
                              anketSecenekEnCok,
                            ),
                            style: TextStyle(
                              color: r.metinIkincil,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      style: context.yazi.titleSmall,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  for (final (sira, kontrol) in _secenekler.indexed) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: kontrol,
                            enabled: !kilitli,
                            maxLength: anketSecenegiEnCok,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.next,
                            onChanged: (v) => _notifier.secenekAyarla(sira, v),
                            decoration: InputDecoration(
                              labelText: m.anket_form_secenek(sira + 1),
                              errorText: switch (secenekHatasi[sira]) {
                                SecenekHatasi.gecersiz =>
                                  m.anket_form_secenek_hatasi,
                                SecenekHatasi.tekrar =>
                                  m.anket_form_secenek_tekrar,
                                null => null,
                              },
                            ),
                          ),
                        ),
                        if (d.secenekKaldirilabilir)
                          IconButton(
                            tooltip: m.anket_form_secenek_kaldir,
                            onPressed: kilitli
                                ? null
                                : () => _secenekKaldir(sira),
                            icon: Icon(Icons.close, color: r.metinIkincil),
                          ),
                      ],
                    ),
                    const SizedBox(height: TayfamSpacing.s4),
                  ],
                  if (d.secenekEklenebilir)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BaglantiEylemi(
                        etiket: m.anket_form_secenek_ekle,
                        ikon: Icons.add,
                        onPressed: kilitli ? null : _secenekEkle,
                      ),
                    ),
                  const SizedBox(height: TayfamSpacing.s8),
                  Divider(
                    height: TayfamSizes.kenar,
                    thickness: TayfamSizes.kenar,
                    color: r.cizgi,
                  ),
                  SwitchListTile(
                    value: d.coklu,
                    onChanged: kilitli
                        ? null
                        : (v) => _notifier.cokluAyarla(coklu: v),
                    title: Text(m.anket_form_coklu),
                    subtitle: Text(
                      m.anket_form_coklu_aciklama,
                      style: aciklama,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: d.gizli,
                    onChanged: kilitli
                        ? null
                        : (v) => _notifier.gizliAyarla(gizli: v),
                    title: Text(m.anket_form_gizli),
                    subtitle: Text(gizliNotu, style: aciklama),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: TayfamSpacing.s12),
                  _KapanisKutusu(
                    kapanis: kapanis,
                    hatali: kapanisHatali,
                    onPressed: kilitli ? null : () => unawaited(_kapanisSec()),
                  ),
                  if (kapanisHatali) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri(metin: m.anket_form_kapanis_hatasi),
                  ],
                  if (kapanis != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BaglantiEylemi(
                        etiket: m.anket_form_kapanis_kaldir,
                        onPressed: kilitli
                            ? null
                            : () => _notifier.kapanisAyarla(null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kapanış zamanı kutusu (tasarım: Anket-Form): saat ikonu, "Kapanış" ve
/// seçilen gün ve saat ya da "Elle kapatılana kadar açık", sağda ok.
/// Dokununca tarih ve saat seçicisi açılır.
class _KapanisKutusu extends StatelessWidget {
  const _KapanisKutusu({
    required this.kapanis,
    required this.hatali,
    required this.onPressed,
  });

  final DateTime? kapanis;
  final bool hatali;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yerel = kapanis?.toLocal();
    return OdakCercevesi(
      koseler: TayfamRadii.onizlemeKoseleri,
      child: Material(
        color: r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.onizlemeKoseleri,
          side: hatali
              ? BorderSide(color: r.narMetin, width: TayfamSizes.alanOdakKenari)
              : BorderSide(color: r.cizgi, width: TayfamSizes.vurguKenari),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          hint: m.anket_form_kapanis_sec,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TayfamSpacing.s56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s12,
                  vertical: TayfamSpacing.s8,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.schedule,
                        size: TayfamSizes.ikon,
                        color: r.tintMarkaUstu,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.anket_form_kapanis,
                            style: context.yazi.labelSmall?.copyWith(
                              color: r.metinIkincil,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            yerel == null
                                ? m.anket_elle_kapanana_kadar
                                : m.anket_kapanis_degeri(yerel, yerel),
                            style: context.yazi.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    const SatirOku(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
