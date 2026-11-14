import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_gruplari.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_bolumu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın yaklaşan etkinlikleri (`/t/<tayfaId>/etkinlikler`; ana
/// sayfadaki "Tümü"; 2026-11-13 tasarım: Etkinlikler): başlık ve tayfa
/// adı, "Bu hafta", "Gelecek hafta" ve ay adına göre gruplanmış satırlar
/// (tarih kutusu, başlık, "Tür · gün saat · yer", cevap ya da "Cevap
/// ver"). Sayfalı; aşağı çekince yenilenir.
///
/// Yalnızca yaklaşanlar listelenir: sözleşmede geçmiş etkinlik listesi
/// yoktur. Satıra dokununca detay açılır. Etkinlik açabilen kullanıcıya
/// (yönetim ya da tayfa izin veriyorsa üye) başlıkta "Etkinlik aç"
/// gösterilir; kararı sunucu verir (kesin kural 5).
class EtkinliklerEkrani extends ConsumerWidget {
  const EtkinliklerEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final saglayici = etkinlikListesiProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final liste = durum.value;
    final hata = durum.error;
    final gruplar = liste == null
        ? const <EtkinlikGrubu>[]
        : etkinlikGruplari(liste.ogeler, simdi);
    final yukleniyor = Center(
      child: TayfamYukleniyor(
        boyut: TayfamSizes.yukleniyorTamEkran,
        etiket: metinler.tayfa_ana_etkinlikler_yukleniyor,
        gecikmeli: true,
      ),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _yenile(context, ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s8,
              TayfamSpacing.kenarMobil,
              TayfamSpacing.s40,
            ),
            children: [
              _Baslik(tayfaId: tayfaId),
              if (liste == null && hata != null) ...[
                const SizedBox(height: TayfamSpacing.s16),
                HataSatiri.hatadan(hata),
                _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
              ] else if (liste == null)
                yukleniyor
              else if (liste.ogeler.isEmpty) ...[
                const SizedBox(height: TayfamSpacing.s16),
                Text(
                  metinler.tayfa_ana_etkinlikler_bos,
                  style: context.yazi.bodyLarge?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
              ] else ...[
                for (final grup in gruplar)
                  _Grup(
                    tayfaId: tayfaId,
                    baslik: etkinlikGrubuBasligi(metinler, grup, simdi),
                    grup: grup,
                  ),
                const SizedBox(height: TayfamSpacing.s16),
                if (liste.dahaHatasi case final dahaHatasi?) ...[
                  HataSatiri.hatadan(dahaHatasi),
                  _TekrarDene(onPressed: () => _dahaFazla(ref)),
                ] else if (liste.dahaYukleniyor)
                  yukleniyor
                else if (liste.dahaVar)
                  Center(
                    child: TextButton(
                      onPressed: () => _dahaFazla(ref),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                      ),
                      child: Text(metinler.tayfa_ana_daha_fazla),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref) => unawaited(
    ref.read(etkinlikListesiProvider(tayfaId).notifier).dahaFazla(),
  );

  /// Listeyi yeniler. Yenileme başarısız olursa eldeki liste kalır ve
  /// hata kısa bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = etkinlikListesiProvider(tayfaId);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) hataBildir(context, hata);
  }
}

/// Grubun başlığı: "Bu hafta", "Gelecek hafta" ya da ay adı; ay bu yıl
/// değilse yılıyla ("Ocak 2027"). Ay adı `intl`'den, büyük harfe
/// çevrilmeden (ADR-0008).
String etkinlikGrubuBasligi(
  AppLocalizations m,
  EtkinlikGrubu grup,
  DateTime simdi,
) {
  final ay = grup.ay;
  if (grup.tur == EtkinlikGrubuTuru.buHafta) return m.etkinlik_listesi_bu_hafta;
  if (grup.tur == EtkinlikGrubuTuru.gelecekHafta || ay == null) {
    return m.etkinlik_listesi_gelecek_hafta;
  }
  final bicim = ay.year == simdi.toLocal().year
      ? DateFormat.MMMM(m.localeName)
      : DateFormat.yMMMM(m.localeName);
  return bicim.format(ay);
}

/// Bir grubun başlığı ve satırları bir liste kartında. Satıra dokununca
/// etkinliğin detayı açılır.
class _Grup extends StatelessWidget {
  const _Grup({
    required this.tayfaId,
    required this.baslik,
    required this.grup,
  });

  final String tayfaId;
  final String baslik;
  final EtkinlikGrubu grup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: baslik),
        ListeKarti(
          children: [
            for (final etkinlik in grup.etkinlikler)
              YaklasanSatiri(
                key: ValueKey(etkinlik.id),
                etkinlik: etkinlik,
                onTap: () =>
                    context.go(Adresler.etkinlik(tayfaId, etkinlik.id)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Başlık (tasarım: Etkinlikler): geri düğmesi, "Etkinlikler" ve altında
/// tayfanın adı; etkinlik açabilene sağda "Etkinlik aç". Büyük yazıda
/// düğme başlığın altına iner.
class _Baslik extends ConsumerWidget {
  const _Baslik({required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final tayfaAdi = ref.watch(tayfaAdiProvider(tayfaId));
    final acabilir = ref.watch(tayfaOzetiProvider(tayfaId)).etkinlikAcabilir;
    final geri = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return Row(
      children: [
        if (geri) const BackButton(),
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: TayfamSpacing.s8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        m.etkinlik_listesi_baslik,
                        style: context.yazi.headlineSmall,
                      ),
                    ),
                    if (tayfaAdi != null)
                      Text(
                        tayfaAdi,
                        style: context.yazi.bodySmall?.copyWith(
                          color: r.metinIkincil,
                        ),
                      ),
                  ],
                ),
                if (acabilir)
                  OdakCercevesi(
                    koseler: TayfamRadii.hapKoseleri,
                    child: FilledButton(
                      onPressed: () =>
                          context.go(Adresler.etkinlikOlustur(tayfaId)),
                      style: FilledButton.styleFrom(
                        backgroundColor: r.tintMarka,
                        foregroundColor: r.tintMarkaUstu,
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                        padding: const EdgeInsets.symmetric(
                          horizontal: TayfamSpacing.s16,
                        ),
                        shape: const StadiumBorder(),
                        // Odak çerçevesini OdakCercevesi çizer.
                        side: BorderSide.none,
                        textStyle: context.yazi.labelLarge,
                      ),
                      child: EylemIcerigi(
                        etiket: m.etkinlik_listesi_ac,
                        ikon: Icons.add,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TekrarDene extends StatelessWidget {
  const _TekrarDene({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(AppLocalizations.of(context).tayfa_ana_tekrar_dene),
      ),
    );
  }
}
