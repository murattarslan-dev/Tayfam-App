import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// İptal edilen etkinliğin soluk görünümünün saydamlığı.
const double iptalSaydamligi = .6;

/// Etkinlik listesindeki satır (ADR-0015 §3): tür çipi, başlık, tarih ve
/// saat, yer adı ya da "Çevrimiçi", gelen/kontenjan ve kullanıcının cevabı.
/// İptal edilen etkinlik soluk görünür ve "İptal edildi" etiketi taşır.
/// Dokununca [onTap] (detay) çağrılır.
class EtkinlikSatiri extends ConsumerWidget {
  const EtkinlikSatiri({super.key, required this.etkinlik, this.onTap});

  final Event etkinlik;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final iptal = iptalEdildi(etkinlik);
    final cevap = etkinlik.callerRsvp;
    final ikincil = context.yazi.bodyMedium?.copyWith(color: r.metinIkincil);
    final icerik = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EtkinlikTuruCipi(tur: etkinlik.type),
            if (iptal) Etiket(metin: m.etkinlik_iptal_edildi),
          ],
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Text(etkinlik.title, style: context.yazi.titleMedium),
        const SizedBox(height: TayfamSpacing.s4),
        Text(
          etkinlikZamani(m, etkinlik.startsAt, simdi: simdi),
          style: ikincil,
        ),
        Text(_yer(m), style: ikincil),
        const SizedBox(height: TayfamSpacing.s8),
        Text(_gelen(m), style: context.yazi.bodyMedium),
        if (cevap != null)
          Text(
            m.etkinlik_cevabin(cevapAdi(m, cevap)),
            style: context.yazi.labelLarge?.copyWith(color: r.marka),
          ),
      ],
    );
    return Opacity(
      opacity: iptal ? iptalSaydamligi : 1,
      child: TayfamKart(onTap: onTap, child: icerik),
    );
  }

  String _yer(AppLocalizations m) {
    if (etkinlik.mode == EventMode.online) return m.etkinlik_cevrimici;
    final ad = etkinlik.meetingPointName;
    if (ad != null && ad.trim().isNotEmpty) return ad;
    final yer = [
      etkinlik.district,
      etkinlik.city,
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');
    return yer.isEmpty ? m.etkinlik_yer_gizli : yer;
  }

  String _gelen(AppLocalizations m) {
    final gelen = etkinlikSayi(m, etkinlik.goingCount);
    return etkinlik.capacity > 0
        ? m.etkinlik_gelen_kontenjan(
            gelen,
            etkinlikSayi(m, etkinlik.capacity),
          )
        : m.etkinlik_gelen(etkinlik.goingCount, gelen);
  }
}
