import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_listesi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Birebir bölümünü çizen fonksiyon. Birebir mesaj paketi kabuktaki
/// kayıtla doldurur (`shell/kayitlar.dart`); verilmezse bölüm sade bir
/// bilgi metni gösterir.
typedef BirebirBolumu = Widget Function(BuildContext context);

/// Sohbet sekmesinin Birebir bölümü (ADR-0003, ADR-0018 §9).
final birebirBolumuProvider = Provider<BirebirBolumu?>(
  (ref) => null,
  name: 'birebirBolumuProvider',
);

/// Birebir konuşmaların okunmamış toplamı (parça seçicideki sayı); liste
/// henüz okunmadıysa `null`. Birebir mesaj paketi kabuktaki kayıtla
/// doldurur; verilmezse `null`.
final birebirOkunmamisYuvasiProvider = Provider<int?>(
  (ref) => null,
  name: 'birebirOkunmamisYuvasiProvider',
);

/// Sohbet sekmesinin iki parçası.
enum SohbetParcasi { kanallar, birebir }

/// Açılışta seçili gelen parça (2026-11-13 kararı): okunmamışı olan parça;
/// ikisinde de varsa Kanallar. Sayılar `null` ise henüz bilinmiyordur.
///
/// Karar verilemiyorsa (sayılar bilinmiyor ya da ikisi de 0) `null` döner:
/// Kanallar gösterilir, seçim henüz sabitlenmez. Kanal sayısı bilinmeden
/// Birebir seçilmez; böylece sayılar geldikçe parça gidip gelmez.
SohbetParcasi? acilisParcasi({required int? kanal, required int? birebir}) {
  if (kanal == null) return null;
  if (kanal > 0) return SohbetParcasi.kanallar;
  if (birebir != null && birebir > 0) return SohbetParcasi.birebir;
  return null;
}

/// Sohbet sekmesinin kökü (ADR-0003; 2026-11-13 tasarım: Sohbet-Kanallar,
/// Sohbet-Birebir): başlık, iki parçalı seçici (Kanallar | Birebir; her
/// parçada okunmamış toplamı) ve seçili parça.
///
/// Seçim yalnızca bellektedir. Kullanıcı seçene kadar açılış kuralına göre
/// ([acilisParcasi]) belirlenir; okunmamış bilgisi ilk geldiğinde sabitlenir
/// ki sayılar değişince parça kendiliğinden değişmesin.
class SohbetEkrani extends ConsumerStatefulWidget {
  const SohbetEkrani({super.key});

  @override
  ConsumerState<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends ConsumerState<SohbetEkrani> {
  SohbetParcasi? _secim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final tayfaId = ref.watch(aktifTayfaIdProvider);
    final birebir = ref.watch(birebirBolumuProvider);
    final kanalSayisi = ref.watch(okunmamisKanalSayisiProvider);
    final kanalBilinen =
        tayfaId == null || !ref.watch(kanallarProvider(tayfaId)).isLoading;
    final birebirBilinen = ref.watch(birebirOkunmamisYuvasiProvider);
    final birebirSayisi = birebirBilinen ?? 0;
    _secim ??= acilisParcasi(
      kanal: kanalBilinen ? kanalSayisi : null,
      birebir: birebirBilinen,
    );
    final secim = _secim ?? SohbetParcasi.kanallar;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    TayfamSpacing.kenarMobil,
                    TayfamSpacing.s8,
                    TayfamSpacing.kenarMobil,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: TayfamSpacing.s4,
                        ),
                        child: Semantics(
                          header: true,
                          child: Text(
                            m.gezinme_sekme_sohbet,
                            style: context.yazi.headlineMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s12),
                      ParcaSecici(
                        secim: secim,
                        kanalSayisi: kanalSayisi,
                        birebirSayisi: birebirSayisi,
                        onSec: (parca) => setState(() => _secim = parca),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (secim) {
                    SohbetParcasi.kanallar when tayfaId == null => _BilgiMetni(
                      m.sohbet_tayfa_yok,
                    ),
                    SohbetParcasi.kanallar => KanalListesi(
                      key: ValueKey(tayfaId),
                      tayfaId: tayfaId!,
                    ),
                    SohbetParcasi.birebir when birebir != null => Builder(
                      builder: birebir,
                    ),
                    SohbetParcasi.birebir => _BilgiMetni(
                      m.sohbet_birebir_yakinda,
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İki parçalı seçici (tasarım: Sohbet-Kanallar): kart zeminli hap; seçili
/// parça marka zemin. Her parçada okunmamış toplamı ("99+" üstü); ekran
/// okuyucu parçayı adı, seçili olup olmadığı ve okunmamış sayısıyla okur.
class ParcaSecici extends StatelessWidget {
  const ParcaSecici({
    super.key,
    required this.secim,
    required this.kanalSayisi,
    required this.birebirSayisi,
    required this.onSec,
  });

  final SohbetParcasi secim;
  final int kanalSayisi;
  final int birebirSayisi;
  final ValueChanged<SohbetParcasi> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: r.kart,
        shape: StadiumBorder(
          side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s4),
        child: Row(
          children: [
            for (final (sira, parca) in SohbetParcasi.values.indexed) ...[
              if (sira > 0) const SizedBox(width: TayfamSpacing.s4),
              Expanded(
                child: _Parca(
                  etiket: switch (parca) {
                    SohbetParcasi.kanallar => m.sohbet_sekme_kanallar,
                    SohbetParcasi.birebir => m.sohbet_sekme_birebir,
                  },
                  sayi: switch (parca) {
                    SohbetParcasi.kanallar => kanalSayisi,
                    SohbetParcasi.birebir => birebirSayisi,
                  },
                  secili: parca == secim,
                  onTap: () => onSec(parca),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Parca extends StatelessWidget {
  const _Parca({
    required this.etiket,
    required this.sayi,
    required this.secili,
    required this.onTap,
  });

  final String etiket;
  final int sayi;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = secili ? r.markaUstu : r.metin;
    final (rozetZemini, rozetYazisi) = secili
        ? (r.markaUstu, r.marka)
        : (r.marka, r.markaUstu);
    return Semantics(
      container: true,
      button: true,
      selected: secili,
      label: etiket,
      value: sayi > 0 ? m.gezinme_sohbet_okunmamis(sayi) : null,
      onTap: onTap,
      excludeSemantics: true,
      child: OdakCercevesi(
        koseler: TayfamRadii.hapKoseleri,
        child: Material(
          type: secili ? MaterialType.canvas : MaterialType.transparency,
          color: secili ? r.marka : null,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s8,
                  vertical: TayfamSpacing.s4,
                ),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TayfamSpacing.s8,
                    runSpacing: TayfamSpacing.s4,
                    children: [
                      Text(
                        etiket,
                        textAlign: TextAlign.center,
                        style: context.yazi.labelLarge?.copyWith(color: yazi),
                      ),
                      if (sayi > 0)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: rozetZemini,
                            borderRadius: TayfamRadii.hapKoseleri,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: TayfamSizes.parcaRozeti,
                              minHeight: TayfamSizes.parcaRozeti,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: TayfamSpacing.s8,
                              ),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  okunmamisRozetMetni(m, sayi),
                                  style: context.yazi.labelMedium?.copyWith(
                                    color: rozetYazisi,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Okunmamış rozetinin metni: 100 ve üstü "99+".
String okunmamisRozetMetni(AppLocalizations m, int sayi) {
  if (sayi >= okunmamisUstSinir) return m.gezinme_rozet_cok;
  return m.gezinme_rozet_sayi(sayi);
}

class _BilgiMetni extends StatelessWidget {
  const _BilgiMetni(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: Text(
          metin,
          textAlign: TextAlign.center,
          style: context.yazi.bodyLarge?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
      ),
    );
  }
}
