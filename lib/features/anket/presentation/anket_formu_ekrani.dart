import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_formu_notifier.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anket oluşturma formu (ADR-0018 §5): soru, 2–10 seçenek, tek ya da
/// çoklu seçim, açık ya da gizli, isteğe bağlı kapanma zamanı.
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
        d.denendi &&
        kapanis != null &&
        !anketKapanisiGecerli(kapanis, simdi);
    final gizliNotu = [
      m.anket_gizli_aciklama,
      m.anket_form_gizli_notu,
    ].join(' ');
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return Scaffold(
      appBar: AppBar(title: Text(m.anket_form_baslik)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.etkinlikId != null) ...[
                    Text(m.anket_form_etkinlik_notu, style: ikincil),
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
                  const SizedBox(height: TayfamSpacing.s16),
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
                            icon: const Icon(Icons.close),
                          ),
                      ],
                    ),
                    const SizedBox(height: TayfamSpacing.s8),
                  ],
                  if (d.secenekEklenebilir)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: kilitli ? null : _secenekEkle,
                        style: TextButton.styleFrom(
                          minimumSize: const Size.square(
                            TayfamSizes.dokunmaMin,
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(m.anket_form_secenek_ekle),
                      ),
                    ),
                  const SizedBox(height: TayfamSpacing.s16),
                  SwitchListTile(
                    value: d.coklu,
                    onChanged: kilitli
                        ? null
                        : (v) => _notifier.cokluAyarla(coklu: v),
                    title: Text(m.anket_form_coklu),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: d.gizli,
                    onChanged: kilitli
                        ? null
                        : (v) => _notifier.gizliAyarla(gizli: v),
                    title: Text(m.anket_form_gizli),
                    subtitle: Text(gizliNotu),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  if (kapanis == null)
                    Text(m.anket_form_kapanis_yok, style: ikincil)
                  else
                    _KapanisSatiri(kapanis: kapanis),
                  if (kapanisHatali) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri(metin: m.anket_form_kapanis_hatasi),
                  ],
                  Wrap(
                    spacing: TayfamSpacing.s8,
                    children: [
                      TextButton(
                        onPressed: kilitli
                            ? null
                            : () => unawaited(_kapanisSec()),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.square(
                            TayfamSizes.dokunmaMin,
                          ),
                        ),
                        child: Text(m.anket_form_kapanis_sec),
                      ),
                      if (kapanis != null)
                        TextButton(
                          onPressed: kilitli
                              ? null
                              : () => _notifier.kapanisAyarla(null),
                          style: TextButton.styleFrom(
                            minimumSize: const Size.square(
                              TayfamSizes.dokunmaMin,
                            ),
                          ),
                          child: Text(m.anket_form_kapanis_kaldir),
                        ),
                    ],
                  ),
                  if (d.hata case final hata?) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                  ],
                  const SizedBox(height: TayfamSpacing.s24),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: BirincilEylem(
                      etiket: m.anket_form_gonder,
                      onPressed: kilitli
                          ? null
                          : () => unawaited(_notifier.gonder()),
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

class _KapanisSatiri extends StatelessWidget {
  const _KapanisSatiri({required this.kapanis});

  final DateTime kapanis;

  @override
  Widget build(BuildContext context) {
    final yerel = kapanis.toLocal();
    return Text(
      AppLocalizations.of(context).anket_kapanis(yerel, yerel),
      style: context.yazi.bodyLarge,
    );
  }
}
