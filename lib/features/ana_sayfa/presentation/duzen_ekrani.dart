import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/ana_sayfa/application/duzen.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ayarları → Ana sayfa (`/t/<tayfaId>/ayarlar/ana-sayfa`; App
/// ADR-0024 §6, Tayfam-Api ADR-0027 §2): sunucunun bildiği bütün
/// bileşenler, kapalılar dahil, sırasıyla.
///
/// - Sıra sürükle-bırakla değişir; sürüklemenin erişilebilir alternatifi
///   her satırdaki "Yukarı taşı" / "Aşağı taşı" düğmeleridir.
/// - Her satırda aç/kapa; ayarı olan bileşende "Ayarla". Ayarsız
///   açılamayan bileşen açılırken önce ayarı istenir.
/// - Bu sürümün tanımadığı bileşen "Uygulamayı güncelle" etiketiyle,
///   değiştirilemez olarak listelenir; geri gönderilemeyen bir ayarı
///   varsa kaydetme kapanır.
/// - "Kaydet" bütün listeyi tek istekle gönderir; kaydedilmemiş değişiklik
///   varken çıkmak onay ister.
///
/// Düzenlemeyi yalnızca yönetici görür; anlık tayfada ana sayfa düzeni
/// yoktur. Rol yalnızca ekranı sadeleştirir, yetkiyi sunucu verir (kesin
/// kural 5).
class AnaSayfaDuzenEkrani extends ConsumerStatefulWidget {
  const AnaSayfaDuzenEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  ConsumerState<AnaSayfaDuzenEkrani> createState() =>
      _AnaSayfaDuzenEkraniState();
}

class _AnaSayfaDuzenEkraniState extends ConsumerState<AnaSayfaDuzenEkrani> {
  /// Ekrandaki taslak; `null` iken sunucunun düzeni gösterilir.
  DuzenTaslagi? _taslak;
  bool _kaydediliyor = false;

  void _degistir(DuzenTaslagi yeni) => setState(() => _taslak = yeni);

  Future<void> _kaydet(DuzenTaslagi taslak) async {
    final m = AppLocalizations.of(context);
    setState(() => _kaydediliyor = true);
    try {
      await ref
          .read(anaSayfaDuzeniProvider(widget.tayfaId).notifier)
          .kaydet(taslak);
      if (!mounted) return;
      setState(() => _taslak = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m.anasayfa_kaydedildi)));
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  Future<void> _cikisOnayi() async {
    final m = AppLocalizations.of(context);
    final cik = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(m.anasayfa_cikis_baslik),
        content: Text(m.anasayfa_cikis_metni),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(m.anasayfa_cikis_vazgec),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(m.anasayfa_cikis_onay),
          ),
        ],
      ),
    );
    if ((cik ?? false) && mounted) {
      setState(() => _taslak = null);
      Navigator.of(context).pop();
    }
  }

  Future<void> _acKapa(
    DuzenTaslagi taslak,
    int sira,
    AnaSayfaBileseni? bilesen, {
    required bool acik,
  }) async {
    final satir = taslak.satirlar[sira];
    final ayar = bilesen?.ayar;
    if (acik && ayar != null && ayar.zorunlu && satir.ayar == null) {
      final yeni = await ayar.duzenle(context, widget.tayfaId, null);
      if (yeni == null || !mounted) return;
      _degistir((_taslak ?? taslak).ayarla(sira, yeni, ac: true));
      return;
    }
    _degistir(taslak.acKapa(sira, acik: acik));
  }

  Future<void> _ayarla(DuzenTaslagi taslak, int sira, BilesenAyari ayar) async {
    final yeni = await ayar.duzenle(
      context,
      widget.tayfaId,
      taslak.satirlar[sira].ayar,
    );
    if (yeni == null || !mounted) return;
    _degistir((_taslak ?? taslak).ayarla(sira, yeni));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ozet = ref.watch(tayfaOzetiProvider(widget.tayfaId));
    final duzenleyebilir = ozet.rol == Role.admin && !ozet.anlik;
    final kayit = ref.watch(anaSayfaBilesenKaydiProvider);
    final saglayici = anaSayfaDuzeniProvider(widget.tayfaId);
    final durum = ref.watch(saglayici);
    final sunucudaki = durum.value;
    final ilk = sunucudaki == null ? null : DuzenTaslagi.sunucudan(sunucudaki);
    final taslak = _taslak ?? ilk;
    final degisti = taslak != null && ilk != null && taslak != ilk;
    final kaydedebilir =
        taslak != null &&
        duzenleyebilir &&
        degisti &&
        !_kaydediliyor &&
        taslak.kaydedilebilir;
    final hata = durum.error;
    return PopScope(
      canPop: !degisti,
      onPopInvokedWithResult: (cikti, _) {
        if (!cikti) unawaited(_cikisOnayi());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(m.anasayfa_duzen_baslik),
          actions: [
            if (duzenleyebilir)
              _kaydediliyor
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TayfamSpacing.s16,
                      ),
                      child: TayfamYukleniyor(etiket: m.anasayfa_kaydediliyor),
                    )
                  : TextButton(
                      onPressed: kaydedebilir
                          ? () => unawaited(_kaydet(taslak))
                          : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                      ),
                      child: Text(m.anasayfa_ayar_kaydet),
                    ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: switch ((taslak, hata)) {
            (final taslak?, _) => _Liste(
              taslak: taslak,
              kayit: kayit,
              duzenleyebilir: duzenleyebilir && !_kaydediliyor,
              onTasi: (eski, yeni) => _degistir(taslak.tasi(eski, yeni)),
              onYukari: (sira) => _degistir(taslak.yukari(sira)),
              onAsagi: (sira) => _degistir(taslak.asagi(sira)),
              onAcKapa: (sira, bilesen, acik) =>
                  unawaited(_acKapa(taslak, sira, bilesen, acik: acik)),
              onAyarla: (sira, ayar) => unawaited(_ayarla(taslak, sira, ayar)),
            ),
            (null, final hata?) => YuklemeHatasi(
              hata: hata,
              onTekrarDene: () => ref.invalidate(saglayici),
            ),
            (null, null) => Center(
              child: TayfamYukleniyor(etiket: m.anasayfa_yukleniyor),
            ),
          },
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.taslak,
    required this.kayit,
    required this.duzenleyebilir,
    required this.onTasi,
    required this.onYukari,
    required this.onAsagi,
    required this.onAcKapa,
    required this.onAyarla,
  });

  final DuzenTaslagi taslak;
  final List<AnaSayfaBileseni> kayit;
  final bool duzenleyebilir;
  final void Function(int eski, int yeni) onTasi;
  final ValueChanged<int> onYukari;
  final ValueChanged<int> onAsagi;
  final void Function(int sira, AnaSayfaBileseni? bilesen, bool acik) onAcKapa;
  final void Function(int sira, BilesenAyari ayar) onAyarla;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final satirlar = taslak.satirlar;
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s12,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s40,
      ),
      header: Padding(
        padding: const EdgeInsets.only(bottom: TayfamSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              duzenleyebilir
                  ? m.anasayfa_duzen_aciklama
                  : m.anasayfa_duzen_yalnizca_yonetici,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
            if (!taslak.kaydedilebilir) ...[
              const SizedBox(height: TayfamSpacing.s8),
              HataSatiri(metin: m.anasayfa_duzen_guncelle_uyarisi),
            ],
          ],
        ),
      ),
      itemCount: satirlar.length,
      onReorderItem: duzenleyebilir ? onTasi : (_, _) {},
      itemBuilder: (context, sira) {
        final satir = satirlar[sira];
        final bilesen = anaSayfaBileseniBul(kayit, satir.anahtar);
        return Padding(
          key: ValueKey(satir.anahtar),
          padding: const EdgeInsets.only(bottom: TayfamSpacing.s12),
          child: _BilesenSatiri(
            sira: sira,
            toplam: satirlar.length,
            satir: satir,
            bilesen: bilesen,
            duzenleyebilir: duzenleyebilir && bilesen != null,
            onYukari: () => onYukari(sira),
            onAsagi: () => onAsagi(sira),
            onAcKapa: (acik) => onAcKapa(sira, bilesen, acik),
            onAyarla: switch (bilesen?.ayar) {
              final ayar? => () => onAyarla(sira, ayar),
              null => null,
            },
          ),
        );
      },
    );
  }
}

/// Düzenleme listesindeki bir bileşen: sürükleme tutamacı, ikon, ad,
/// durum metni, aç/kapa; altında "Ayarla" ve yukarı/aşağı düğmeleri.
/// Tanınmayan bileşende yalnızca "Uygulamayı güncelle" etiketi vardır.
class _BilesenSatiri extends StatelessWidget {
  const _BilesenSatiri({
    required this.sira,
    required this.toplam,
    required this.satir,
    required this.bilesen,
    required this.duzenleyebilir,
    required this.onYukari,
    required this.onAsagi,
    required this.onAcKapa,
    required this.onAyarla,
  });

  final int sira;
  final int toplam;
  final DuzenSatiri satir;
  final AnaSayfaBileseni? bilesen;
  final bool duzenleyebilir;
  final VoidCallback onYukari;
  final VoidCallback onAsagi;
  final ValueChanged<bool> onAcKapa;
  final VoidCallback? onAyarla;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final bilesen = this.bilesen;
    final ad = bilesen?.ad(context) ?? m.anasayfa_bilinmeyen_ad;
    final ayarEksik =
        bilesen?.ayar?.zorunlu == true && satir.ayar == null && !satir.acik;
    final durumMetni = switch (bilesen) {
      null => null,
      final b when ayarEksik => m.anasayfa_ayar_gerekli(b.aciklama(context)),
      final b => b.aciklama(context),
    };
    final onAyarla = this.onAyarla;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (duzenleyebilir)
                ReorderableDragStartListener(
                  index: sira,
                  child: Semantics(
                    container: true,
                    label: m.anasayfa_surukle(ad),
                    child: SizedBox.square(
                      dimension: TayfamSizes.dokunmaMin,
                      child: Icon(Icons.drag_indicator, color: r.metinIkincil),
                    ),
                  ),
                ),
              ExcludeSemantics(
                child: Icon(
                  bilesen?.ikon ?? Icons.system_update_outlined,
                  color: r.marka,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: MergeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ad,
                              style: yazi.titleSmall?.copyWith(color: r.metin),
                            ),
                            if (durumMetni != null)
                              Text(
                                durumMetni,
                                style: yazi.bodySmall?.copyWith(
                                  color: r.metinIkincil,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (bilesen != null)
                        Switch(
                          value: satir.acik,
                          onChanged: duzenleyebilir ? onAcKapa : null,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (bilesen == null) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Etiket(
                metin: m.anasayfa_guncelle_etiketi,
                ton: EtiketTonu.mango,
                ikon: Icons.system_update_outlined,
              ),
            ),
          ] else if (duzenleyebilir)
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s4,
              children: [
                if (onAyarla != null)
                  TextButton.icon(
                    onPressed: onAyarla,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    icon: const Icon(Icons.tune),
                    label: Text(m.anasayfa_ayarla),
                  ),
                IconButton(
                  onPressed: sira > 0 ? onYukari : null,
                  tooltip: m.anasayfa_yukari(ad),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: sira < toplam - 1 ? onAsagi : null,
                  tooltip: m.anasayfa_asagi(ad),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
