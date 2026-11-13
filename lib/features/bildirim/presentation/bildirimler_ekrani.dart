import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/bildirim/application/bildirim_gruplari.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/application/bildirim_listesi_notifier.dart';
import 'package:tayfam/features/bildirim/application/okunmamis_bildirim_notifier.dart';
import 'package:tayfam/features/bildirim/application/sekme_durumu.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_satiri.dart';
import 'package:tayfam/features/bildirim/presentation/sekme_kartlari.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bildirimler sekmesi (`/bildirimler`; ADR-0018 §3, 2026-11-13 tasarım:
/// Bildirimler, Bildirimler-Koyu, Bildirimler-Bos): bütün tayfaların
/// bildirimleri tek listede, en yeni önce, sayfalı; zamana göre gruplu
/// (Bugün / Dün / Bu hafta / Daha eski). Aşağı çekince yenilenir.
///
/// - Başlıkta, okunmamış varken "Hepsini okundu say".
/// - Bildirim izni verilmemişse listenin üstünde mor izin kartı.
/// - Okunmamış güvenlik uyarıları (`hike_overdue`) okunana kadar en üstte
///   sabit nar kartta.
/// - Bildirime dokununca okundu işaretlenir ve hedefi açılır
///   ([bildirimAdresi]); hedefin ekranı yoksa yalnızca okundu işaretlenir.
/// - Okunmamış/tümü filtresi yoktur: sözleşmede süzme parametresi yok.
class BildirimlerEkrani extends ConsumerStatefulWidget {
  const BildirimlerEkrani({super.key});

  @override
  ConsumerState<BildirimlerEkrani> createState() => _BildirimlerEkraniState();
}

class _BildirimlerEkraniState extends ConsumerState<BildirimlerEkrani> {
  bool _hepsiIsleniyor = false;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(bildirimListesiProvider);
    final sayi = ref.watch(okunmamisBildirimProvider).value ?? 0;
    final liste = durum.value;
    final hata = durum.error;
    final okunmamisVar =
        sayi > 0 || (liste?.ogeler.any((b) => !b.read) ?? false);
    final simdi = ref.watch(simdiProvider)();
    final izinKarti = _izinKartiGosterilsin();
    final uyarilar = [...?liste?.ogeler.where(sabitUyariMi)];
    final gruplar = liste == null
        ? const <(BildirimGrubu, List<Notification>)>[]
        : bildirimleriGrupla(
            liste.ogeler.where((b) => !sabitUyariMi(b)),
            simdi,
          );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _yenile,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s8,
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s24,
                ),
                children: [
                  _Baslik(
                    goster: liste != null && okunmamisVar,
                    hepsiniOkunduSay: _hepsiIsleniyor
                        ? null
                        : _hepsiniOkunduSay,
                  ),
                  if (izinKarti) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    const IzinKarti(),
                  ],
                  for (final uyari in uyarilar) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    GuvenlikUyarisiKarti(
                      bildirim: uyari,
                      simdi: simdi,
                      onTap: () => _ac(uyari),
                    ),
                  ],
                  if (liste == null && hata != null) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                    _MetinDugmesi(
                      etiket: m.tayfa_ana_tekrar_dene,
                      onPressed: () => ref.invalidate(bildirimListesiProvider),
                    ),
                  ] else if (liste == null)
                    Padding(
                      padding: const EdgeInsets.only(top: TayfamSpacing.s32),
                      child: Center(
                        child: TayfamYukleniyor(
                          boyut: TayfamSizes.yukleniyorTamEkran,
                          etiket: m.bildirim_yukleniyor,
                          gecikmeli: true,
                        ),
                      ),
                    )
                  else if (liste.ogeler.isEmpty)
                    const BosBildirimler()
                  else ...[
                    for (final (grup, bildirimler) in gruplar) ...[
                      BolumEtiketi(baslik: bildirimGrubuBasligi(m, grup)),
                      ListeKarti(
                        children: [
                          for (final bildirim in bildirimler)
                            BildirimSatiri(
                              bildirim: bildirim,
                              simdi: simdi,
                              onTap: () => _ac(bildirim),
                              onIncele: () => _incele(bildirim),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: TayfamSpacing.s16),
                    if (liste.dahaHatasi case final dahaHatasi?) ...[
                      HataSatiri.hatadan(dahaHatasi),
                      _MetinDugmesi(
                        etiket: m.tayfa_ana_tekrar_dene,
                        onPressed: _dahaFazla,
                      ),
                    ] else if (liste.dahaYukleniyor)
                      Center(
                        child: TayfamYukleniyor(etiket: m.bildirim_yukleniyor),
                      )
                    else if (liste.dahaVar)
                      Center(
                        child: _MetinDugmesi(
                          etiket: m.tayfa_ana_daha_fazla,
                          onPressed: _dahaFazla,
                        ),
                      ),
                    const SizedBox(height: TayfamSpacing.s16),
                    Text(
                      m.bildirim_saklama,
                      textAlign: TextAlign.center,
                      style: context.yazi.labelSmall?.copyWith(
                        color: context.renkler.metinIkincil,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mor izin kartı (karar 5): push'un olduğu derlemede izin verilmemişse
  /// ve açıklama kartı daha önce kapatılmadıysa. Kabuğun alttaki açıklama
  /// kartı o an açıksa ikinci kez gösterilmez.
  bool _izinKartiGosterilsin() {
    if (!ref.watch(pushPlatformuProvider).etkin) return false;
    final izin = ref.watch(bildirimIzniProvider);
    if (izin.izin == null ||
        izin.izin == BildirimIzni.verildi ||
        izin.aciklamaGoster) {
      return false;
    }
    return ref.watch(izinKartiProvider).value ?? false;
  }

  /// Bildirimi okundu işaretler ve hedefini açar. Hedef yoksa yalnızca
  /// okundu işaretlenir.
  void _ac(Notification bildirim) {
    unawaited(
      ref.read(bildirimListesiProvider.notifier).okunduIsaretle(bildirim.id),
    );
    _git(bildirimAdresi(bildirim));
  }

  /// Katılım isteğinde "İncele": okundu işaretlenir ve tayfanın katılım
  /// istekleri ekranı açılır (karar 2).
  void _incele(Notification bildirim) {
    unawaited(
      ref.read(bildirimListesiProvider.notifier).okunduIsaretle(bildirim.id),
    );
    _git(katilimIstekleriAdresi(bildirim) ?? bildirimAdresi(bildirim));
  }

  void _git(String? adres) {
    if (adres == null) return;
    // Kişi profili sekmelerin üstünde açılır; geri tuşu bildirimlere döner.
    if (adres.startsWith('${Adresler.kisiOneki}/')) {
      unawaited(context.push(adres));
    } else {
      context.go(adres);
    }
  }

  void _dahaFazla() =>
      unawaited(ref.read(bildirimListesiProvider.notifier).dahaFazla());

  Future<void> _hepsiniOkunduSay() async {
    setState(() => _hepsiIsleniyor = true);
    final hata = await ref
        .read(bildirimListesiProvider.notifier)
        .hepsiniOkunduSay();
    if (!mounted) return;
    setState(() => _hepsiIsleniyor = false);
    if (hata != null && hata is! OturumYok) hataBildir(context, hata);
  }

  /// Listeyi ve rozeti yeniler. Liste yenilenemezse eldeki liste kalır ve
  /// hata kısa bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile() async {
    final rozet = ref.read(okunmamisBildirimProvider.notifier).yenile();
    final hata = await ref.read(bildirimListesiProvider.notifier).yenile();
    await rozet;
    if (!mounted) return;
    if (hata == null || hata is OturumYok) return;
    if (ref.read(bildirimListesiProvider).hasValue) hataBildir(context, hata);
  }
}

/// Sekme başlığı (tasarım: 26 px "Bildirimler") ve okunmamış varken
/// sağında "Hepsini okundu say". Dar ekranda ve büyük yazıda düğme alt
/// satıra iner.
class _Baslik extends StatelessWidget {
  const _Baslik({required this.goster, required this.hepsiniOkunduSay});

  final bool goster;
  final VoidCallback? hepsiniOkunduSay;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TayfamSpacing.s8,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: TayfamSpacing.s4),
          child: Semantics(
            header: true,
            child: Text(
              m.gezinme_sekme_bildirimler,
              style: context.yazi.headlineMedium,
            ),
          ),
        ),
        if (goster)
          BaglantiEylemi(
            etiket: m.bildirim_hepsini_okundu_say,
            onPressed: hepsiniOkunduSay,
          ),
      ],
    );
  }
}

class _MetinDugmesi extends StatelessWidget {
  const _MetinDugmesi({required this.etiket, this.onPressed});

  final String etiket;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
      ),
      child: Text(etiket),
    );
  }
}
