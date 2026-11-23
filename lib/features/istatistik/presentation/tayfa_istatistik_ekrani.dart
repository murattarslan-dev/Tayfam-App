import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/istatistik/application/tayfa_istatistikleri.dart';
import 'package:tayfam/features/istatistik/data/istatistik_deposu.dart';
import 'package:tayfam/features/istatistik/presentation/istatistik_listesi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa istatistikleri (`/t/<tayfaId>/istatistik`; Tayfam-Api ADR-0026
/// §3): dönem seçimi (tüm zamanlar ya da istatistiği olan yıllar), tayfa
/// toplamları ve yalnızca çağıranın kendi katkısı ("Senin katkın", #322).
/// Her etkin üyeye açıktır; yetkiyi sunucu verir (kesin kural 5).
///
/// Grafik yoktur: her değer metin olarak yazılır, anlam renge dayanmaz.
/// Veriler yalnızca bellektedir (ADR-0006).
class TayfaIstatistikEkrani extends ConsumerStatefulWidget {
  const TayfaIstatistikEkrani({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  ConsumerState<TayfaIstatistikEkrani> createState() =>
      _TayfaIstatistikEkraniState();
}

class _TayfaIstatistikEkraniState extends ConsumerState<TayfaIstatistikEkrani> {
  int _yil = tumZamanlar;

  /// Son okunan cevaptaki yıllar; dönem değişirken seçici yerinde kalır.
  List<int> _yillar = const [];

  IstatistikSorgusu get _sorgu => (tayfaId: widget.tayfaId, yil: _yil);

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(tayfaIstatistikleriProvider(_sorgu));
    final veri = durum.value;
    if (veri != null) _yillar = veri.years;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.istatistik_baslik)),
      body: TayfamYenile(
        onRefresh: () =>
            ref.refresh(tayfaIstatistikleriProvider(_sorgu).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s40,
          ),
          children: [
            DonemSecici(
              yillar: _yillar,
              secili: _yil,
              onSec: (yil) => setState(() => _yil = yil),
            ),
            if (veri != null)
              _Icerik(veri: veri)
            else if (hata != null)
              YuklemeHatasi(
                hata: hata,
                onTekrarDene: () =>
                    ref.invalidate(tayfaIstatistikleriProvider(_sorgu)),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TayfamSpacing.s24,
                ),
                child: Center(
                  child: TayfamYukleniyor(etiket: m.istatistik_yukleniyor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dönem seçici: "Tüm zamanlar" ve istatistiği olan yıllar (yeniden
/// eskiye). Seçili çipte onay işareti vardır (yalnızca renge dayanmaz);
/// ekran okuyucu çipleri seçilebilir düğmeler olarak okur. Dar ekranda
/// ve büyük yazıda alt satıra kayar.
class DonemSecici extends StatelessWidget {
  const DonemSecici({
    super.key,
    required this.yillar,
    required this.secili,
    required this.onSec,
  });

  final List<int> yillar;
  final int secili;
  final ValueChanged<int> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final donemler = [
      tumZamanlar,
      for (final yil in yillar)
        if (yil != tumZamanlar) yil,
      if (secili != tumZamanlar && !yillar.contains(secili)) secili,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.istatistik_donem),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final donem in donemler)
              ChoiceChip(
                label: Text(
                  donem == tumZamanlar ? m.istatistik_tum_zamanlar : '$donem',
                ),
                selected: donem == secili,
                onSelected: (_) => onSec(donem),
              ),
          ],
        ),
      ],
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.veri});

  final TayfaStats veri;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.istatistik_toplamlar),
        if (veri.totals.isEmpty)
          IstatistikNotu(metin: m.istatistik_bos, ikincil: false)
        else
          IstatistikListesi(statlar: veri.totals, bosMetin: m.istatistik_bos),
        KatkiBolumu(katkilar: veri.ownContributions),
        const SizedBox(height: TayfamSpacing.s16),
        IstatistikNotu(metin: m.istatistik_not),
      ],
    );
  }
}

/// "Senin katkın" (Tayfam-Api ADR-0026 §3, #322): çağıranın bu tayfadaki
/// kendi ölçüm ve günlük katkısı (`TayfaStats.own_contributions`),
/// sunucunun sırasıyla ve toplamlarla aynı satır biçiminde. Başka üyenin
/// katkısı sunucudan gelmez; eski `contributions` alanı okunmaz. Sıra
/// numarası ya da "en çok" vurgusu yoktur. Gösterilebilir satır yoksa
/// (boş liste ya da katalogda karşılığı olmayan metrik) bölüm çizilmez.
class KatkiBolumu extends StatelessWidget {
  const KatkiBolumu({super.key, required this.katkilar});

  final List<TayfaStat> katkilar;

  @override
  Widget build(BuildContext context) {
    if (katkilar.isEmpty) return const SizedBox.shrink();
    final m = AppLocalizations.of(context);
    return KatalogBekleyici(
      builder: (context, katalog) {
        final satirlar = istatistikSatirlari(
          m,
          katkilar,
          katalog,
          katalogDili(context),
        );
        if (satirlar.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BolumEtiketi(baslik: m.istatistik_kendi_katkin),
            ListeKarti(
              children: [
                for (final s in satirlar)
                  ListeKartiSatiri(
                    child: IstatistikSatiri(
                      gorunum: s.gorunum,
                      etkinlikSayisi: s.etkinlik,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: TayfamSpacing.s8),
            IstatistikNotu(metin: m.istatistik_kendi_katkin_notu),
          ],
        );
      },
    );
  }
}
