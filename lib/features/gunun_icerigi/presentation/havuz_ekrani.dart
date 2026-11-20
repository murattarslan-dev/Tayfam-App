import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/gunun_icerigi/application/gunun_icerigi.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/icerik_formu.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Günün içeriği havuzu (`/t/<tayfaId>/gunun-icerigi`; App ADR-0024 §6,
/// Tayfam-Api ADR-0027 §5).
///
/// Her üye havuzu sırasıyla okur. Sunucu `caller_can_manage` derse
/// (moderatör, yönetici) ekle, düzenle, sil, sırala ve "Silinenler"
/// açılır. Sıra sürükle-bırakla değişir ve hemen gönderilir; sürüklemenin
/// erişilebilir alternatifi her satırdaki "Yukarı taşı" / "Aşağı taşı"
/// düğmeleridir. Aynı güne ikinci sabitleme reddedilmez; sunucu
/// `pin_conflict` derse uyarı gösterilir.
class HavuzEkrani extends ConsumerStatefulWidget {
  const HavuzEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  ConsumerState<HavuzEkrani> createState() => _HavuzEkraniState();
}

class _HavuzEkraniState extends ConsumerState<HavuzEkrani> {
  bool _mesgul = false;

  HavuzNotifier get _havuz => ref.read(havuzProvider(widget.tayfaId).notifier);

  Future<void> _calistir(Future<void> Function() is_) async {
    setState(() => _mesgul = true);
    try {
      await is_();
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _form({DailyItem? mevcut}) async {
    final m = AppLocalizations.of(context);
    final kayit = await icerikFormunuAc(
      context,
      widget.tayfaId,
      mevcut: mevcut,
    );
    if (kayit == null || !mounted) return;
    if (kayit.pinConflict) {
      await sabitlemeCakismasiniBildir(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m.gunun_icerigi_kaydedildi)));
    }
  }

  Future<void> _sil(DailyItem icerik) async {
    final m = AppLocalizations.of(context);
    final onay = await _silmeOnayi(context);
    if (!onay || !mounted) return;
    await _calistir(() async {
      await _havuz.sil(icerik.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m.gunun_icerigi_silindi),
          action: SnackBarAction(
            label: m.gunun_icerigi_geri_al,
            onPressed: () => unawaited(_geriAl(icerik.id)),
          ),
        ),
      );
    });
  }

  Future<void> _geriAl(String icerikId) => _calistir(() async {
    final kayit = await _havuz.geriAl(icerikId);
    if (kayit.pinConflict && mounted) {
      await sabitlemeCakismasiniBildir(context);
    }
  });

  Future<void> _tasi(int eski, int yeni) =>
      _calistir(() => _havuz.tasi(eski, yeni));

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = havuzProvider(widget.tayfaId);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    final yonetir = liste?.callerCanManage ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(m.gunun_icerigi_ad),
        actions: [
          if (yonetir)
            IconButton(
              onPressed: () =>
                  unawaited(context.push(silinenlerAdresi(widget.tayfaId))),
              tooltip: m.gunun_icerigi_silinenler,
              icon: const Icon(Icons.restore_from_trash_outlined),
            ),
        ],
      ),
      floatingActionButton: yonetir
          ? FloatingActionButton.extended(
              onPressed: _mesgul ? null : () => unawaited(_form()),
              icon: const Icon(Icons.add),
              label: Text(m.gunun_icerigi_ekle),
            )
          : null,
      body: SafeArea(
        top: false,
        child: switch ((liste, hata)) {
          (final liste?, _) => _Liste(
            liste: liste,
            yonetir: yonetir && !_mesgul,
            onTasi: (eski, yeni) => unawaited(_tasi(eski, yeni)),
            onDuzenle: (icerik) => unawaited(_form(mevcut: icerik)),
            onSil: (icerik) => unawaited(_sil(icerik)),
          ),
          (null, final hata?) => YuklemeHatasi(
            hata: hata,
            onTekrarDene: () => ref.invalidate(saglayici),
          ),
          (null, null) => Center(
            child: TayfamYukleniyor(etiket: m.gunun_icerigi_yukleniyor),
          ),
        },
      ),
    );
  }
}

/// Aynı güne sabitlenmiş başka içerik var: kaydedildi, ama o gün havuz
/// sırasında önce gelen gösterilir.
Future<void> sabitlemeCakismasiniBildir(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (pencere) {
        final m = AppLocalizations.of(pencere);
        return AlertDialog(
          title: Text(m.gunun_icerigi_cakisma_baslik),
          scrollable: true,
          content: Text(m.gunun_icerigi_cakisma_metni),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(pencere).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.gunun_icerigi_tamam),
            ),
          ],
        );
      },
    );

/// Silme onayı; son adım dolu yıkıcı düğmedir (ADR-0004 Notlar).
Future<bool> _silmeOnayi(BuildContext context) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) {
      final m = AppLocalizations.of(pencere);
      return AlertDialog(
        title: Text(m.gunun_icerigi_sil_baslik),
        scrollable: true,
        content: Text(m.gunun_icerigi_sil_metni),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.gunun_icerigi_vazgec),
          ),
          YikiciEylem(
            etiket: m.gunun_icerigi_sil,
            dolu: true,
            onPressed: () => Navigator.of(pencere).pop(true),
          ),
        ],
      );
    },
  );
  return onay ?? false;
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.liste,
    required this.yonetir,
    required this.onTasi,
    required this.onDuzenle,
    required this.onSil,
  });

  final DailyItemList liste;
  final bool yonetir;
  final void Function(int eski, int yeni) onTasi;
  final ValueChanged<DailyItem> onDuzenle;
  final ValueChanged<DailyItem> onSil;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final ogeler = liste.items;
    final aciklama = Text(
      liste.callerCanManage
          ? m.gunun_icerigi_havuz_aciklama_yonetici
          : m.gunun_icerigi_havuz_aciklama_uye,
      style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
    );
    if (ogeler.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s12,
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s40,
        ),
        children: [
          aciklama,
          const SizedBox(height: TayfamSpacing.s24),
          TayfamKart(
            child: Text(
              liste.callerCanManage
                  ? m.gunun_icerigi_bos_yonetici
                  : m.gunun_icerigi_bos_uye,
              style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          ),
        ],
      );
    }
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s12,
        TayfamSpacing.kenarMobil,
        // Alttaki "İçerik ekle" düğmesi son satırı örtmesin.
        TayfamSpacing.s64 + TayfamSpacing.s40,
      ),
      header: Padding(
        padding: const EdgeInsets.only(bottom: TayfamSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            aciklama,
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              m.gunun_icerigi_sayi(ogeler.length),
              style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
          ],
        ),
      ),
      itemCount: ogeler.length,
      onReorderItem: yonetir ? onTasi : (_, _) {},
      itemBuilder: (context, sira) {
        final icerik = ogeler[sira];
        return Padding(
          key: ValueKey(icerik.id),
          padding: const EdgeInsets.only(bottom: TayfamSpacing.s12),
          child: _IcerikSatiri(
            sira: sira,
            toplam: ogeler.length,
            icerik: icerik,
            yonetir: yonetir,
            onYukari: () => onTasi(sira, sira - 1),
            onAsagi: () => onTasi(sira, sira + 1),
            onDuzenle: () => onDuzenle(icerik),
            onSil: () => onSil(icerik),
          ),
        );
      },
    );
  }
}

/// Havuzdaki bir içerik: sürükleme tutamacı, sıra numarası, metin (en çok
/// dört satır), söyleyen ve sabitleme; altında düzenle, sil ve
/// yukarı/aşağı düğmeleri (yalnızca yönetene).
class _IcerikSatiri extends StatelessWidget {
  const _IcerikSatiri({
    required this.sira,
    required this.toplam,
    required this.icerik,
    required this.yonetir,
    required this.onYukari,
    required this.onAsagi,
    required this.onDuzenle,
    required this.onSil,
  });

  final int sira;
  final int toplam;
  final DailyItem icerik;
  final bool yonetir;
  final VoidCallback onYukari;
  final VoidCallback onAsagi;
  final VoidCallback onDuzenle;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final no = sira + 1;
    final sabit = icerik.pin;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (yonetir)
                ReorderableDragStartListener(
                  index: sira,
                  child: Semantics(
                    container: true,
                    label: m.gunun_icerigi_surukle(no),
                    child: SizedBox.square(
                      dimension: TayfamSizes.dokunmaMin,
                      child: Icon(Icons.drag_indicator, color: r.metinIkincil),
                    ),
                  ),
                ),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.gunun_icerigi_sira_no(no),
                        style: context.yazi.labelMedium?.copyWith(
                          color: r.metinIkincil,
                        ),
                      ),
                      const SizedBox(height: TayfamSpacing.s4),
                      IcerikMetni(icerik: icerik, enCokSatir: 4),
                      if (sabit != null) ...[
                        const SizedBox(height: TayfamSpacing.s8),
                        SabitlemeEtiketi(sabit: sabit),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (yonetir)
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s4,
              children: [
                TextButton.icon(
                  onPressed: onDuzenle,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(
                    m.gunun_icerigi_duzenle,
                    semanticsLabel: m.gunun_icerigi_duzenle_etiketi(no),
                  ),
                ),
                YikiciEylem(
                  etiket: m.gunun_icerigi_sil,
                  semantikEtiketi: m.gunun_icerigi_sil_etiketi(no),
                  ikon: Icons.delete_outline,
                  onPressed: onSil,
                ),
                IconButton(
                  onPressed: sira > 0 ? onYukari : null,
                  tooltip: m.gunun_icerigi_yukari(no),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: sira < toplam - 1 ? onAsagi : null,
                  tooltip: m.gunun_icerigi_asagi(no),
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
