import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_listesi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik detayındaki "Sohbet" bölümü (2026-11-13 tasarım:
/// Etkinlik-Sohbet; Tayfam-Api #183). Etkinlik paketi kabuktaki kayıtla
/// yerleştirir (`shell/kayitlar.dart`).
///
/// - Görebildiğin bir etkinlik kanalı varsa "Etkinlik sohbeti" kartı:
///   kişi sayısı, okunmamış rozeti; dokununca kanal açılır.
/// - Yoksa organizatöre (`caller_can_manage`) ve yönetime "Etkinlik
///   sohbetini aç" kartı; kanal etkinlik başlığından türetilen adla açılır.
///   Bitişinin ya da iptalinin üzerinden 7 gün geçtiyse gösterilmez.
///   Yetkiyi sunucu verir (kesin kural 5).
/// - İkisi de yoksa bölüm (başlığıyla) hiç görünmez.
/// - Katılım cevabın değişince kanal listesi yenilenir: "Geliyorum"
///   diyen kitleye girer, cevabını değiştiren çıkar.
class EtkinlikSohbeti extends ConsumerStatefulWidget {
  const EtkinlikSohbeti({
    super.key,
    required this.etkinlik,
    required this.baslik,
  });

  final Event etkinlik;

  /// Bölüm başlığı; bölüm görünürse üstüne konur.
  final Widget baslik;

  @override
  ConsumerState<EtkinlikSohbeti> createState() => _EtkinlikSohbetiState();
}

class _EtkinlikSohbetiState extends ConsumerState<EtkinlikSohbeti> {
  bool _aciliyor = false;

  @override
  void didUpdateWidget(EtkinlikSohbeti eski) {
    super.didUpdateWidget(eski);
    if (eski.etkinlik.callerRsvp != widget.etkinlik.callerRsvp) {
      unawaited(
        ref.read(kanallarProvider(widget.etkinlik.tayfaId).notifier).yenile(),
      );
    }
  }

  Future<void> _ac() async {
    final etkinlik = widget.etkinlik;
    setState(() => _aciliyor = true);
    final notifier = ref.read(kanallarProvider(etkinlik.tayfaId).notifier);
    try {
      final kanal = await notifier.olustur(
        ad: etkinlikKanalAdi(etkinlik.title),
        kitle: KanalKitlesi.etkinlik,
        yavasModSaniye: 0,
        etkinlikId: etkinlik.id,
      );
      if (mounted) context.go(Adresler.kanal(etkinlik.tayfaId, kanal.id));
    } on Exception catch (hata) {
      if (!mounted) return;
      setState(() => _aciliyor = false);
      hataBildir(context, hata);
      // Görmediğin bir kanal varsa liste tazelenir.
      if (hata is ApiProblem && hata.type == ProblemType.eventChannelExists) {
        unawaited(notifier.yenile());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final etkinlik = widget.etkinlik;
    final kanallar = ref.watch(kanallarProvider(etkinlik.tayfaId)).value;
    if (kanallar == null) return const SizedBox.shrink();
    final kanal = etkinlikKanali(kanallar, etkinlik.id);
    final Widget icerik;
    if (kanal != null) {
      icerik = _KanalKarti(kanal: kanal);
    } else {
      final yonetimde = ref
          .watch(tayfaOzetiProvider(etkinlik.tayfaId))
          .yonetimde;
      final simdi = ref.read(simdiProvider)();
      if (!(etkinlik.callerCanManage || yonetimde) ||
          !etkinlikKanaliAcilabilir(etkinlik, simdi)) {
        return const SizedBox.shrink();
      }
      icerik = _AcmaKarti(onAc: _aciliyor ? null : () => unawaited(_ac()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [widget.baslik, icerik],
    );
  }
}

/// Var olan etkinlik kanalının kartı.
class _KanalKarti extends StatelessWidget {
  const _KanalKarti({required this.kanal});

  final Channel kanal;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final sayi = kanal.memberCount;
    final arsivde = kanal.archivedAt != null;
    final okunmamis = arsivde ? 0 : (kanal.unreadCount ?? 0);
    return ListeKarti(
      children: [
        MenuSatiri.kartta(
          ikonKutusu: KanalIkonKutusu(
            ikon: arsivde ? Icons.inventory_2_outlined : Icons.event_outlined,
            boyut: TayfamSizes.menuIkonKutusu,
          ),
          baslik: m.sohbet_etkinlik_sohbeti,
          aciklama: arsivde
              ? m.sohbet_kanal_alt_arsiv
              : (sayi == null
                    ? m.sohbet_etkinlik_sohbeti_alt_sayisiz
                    : m.sohbet_etkinlik_sohbeti_alt(sayi)),
          sag: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (okunmamis > 0) ...[
                SayiRozeti(
                  metin: okunmamis >= okunmamisUstSinir
                      ? m.gezinme_rozet_cok
                      : m.gezinme_rozet_sayi(okunmamis),
                  etiket: m.sohbet_kanal_okunmamis(okunmamis),
                  marka: true,
                ),
                const SizedBox(width: TayfamSpacing.s8),
              ],
              const SatirOku(),
            ],
          ),
          onTap: () => context.go(Adresler.kanal(kanal.tayfaId, kanal.id)),
        ),
      ],
    );
  }
}

/// Kanal yokken organizatöre ve yönetime "Etkinlik sohbetini aç" kartı.
class _AcmaKarti extends StatelessWidget {
  const _AcmaKarti({required this.onAc});

  final VoidCallback? onAc;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: TayfamRadii.kartKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.vurguKenari),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.sohbet_etkinlik_sohbeti_soru,
              style: context.yazi.titleMedium,
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              m.sohbet_etkinlik_sohbeti_aciklama,
              style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
            const SizedBox(height: TayfamSpacing.s12),
            BirincilEylem(
              etiket: m.sohbet_etkinlik_sohbeti_ac,
              ikon: Icons.chat_bubble_outline,
              onPressed: onAc,
            ),
          ],
        ),
      ),
    );
  }
}
