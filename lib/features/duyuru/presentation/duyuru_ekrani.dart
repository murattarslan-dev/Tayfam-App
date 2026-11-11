import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/duyuru/application/duyuru_notifier.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_karti.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ortak.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Duyuru işlemleri menüsünün seçenekleri.
enum DuyuruIslemi { duzenle, sabitle, sabitlemeyiKaldir, sil, sikayet }

/// Tek bir duyuru (`/t/<tayfaId>/duyurular/<duyuruId>`; ADR-0015 §2):
/// başlık, yayın zamanı ve gövde. Gövde düz metindir; markdown ya da HTML
/// yorumlanmaz, bağlantılar dokunulabilir değildir.
///
/// Adresteki [duyuruId] girdi kabul edilir: UUID biçiminde değilse istek
/// gönderilmez, "bulunamadı" gösterilir. Moderatör ve yöneticiye düzenleme,
/// sabitleme ve (onaylı) silme menüsü gösterilir; kararı sunucu verir.
/// Başkasının duyurusunda menüde "Şikâyet et" vardır (ADR-0018 §8).
class DuyuruEkrani extends ConsumerWidget {
  const DuyuruEkrani({
    super.key,
    required this.tayfaId,
    required this.duyuruId,
  });

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  /// Adresteki duyuru kimliği; biçimi burada doğrulanır.
  final String duyuruId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    if (!uuidBicimindeMi(duyuruId)) {
      return Scaffold(
        appBar: AppBar(title: Text(metinler.duyuru_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: metinler.hata_announcement_not_found),
        ),
      );
    }
    final saglayici = duyuruProvider((tayfaId: tayfaId, duyuruId: duyuruId));
    final durum = ref.watch(saglayici);
    final yonetimde = ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde;
    final duyuru = durum.value;
    final hata = durum.error;
    final yazar = duyuru?.authorUserId;
    final sikayetEdilebilir =
        duyuru != null &&
        (yazar == null || !ref.watch(kendisiMiProvider(yazar)));
    return Scaffold(
      appBar: AppBar(
        title: Text(metinler.duyuru_baslik),
        actions: [
          if (duyuru != null && (yonetimde || sikayetEdilebilir))
            _IslemMenusu(
              duyuru: duyuru,
              yonetimde: yonetimde,
              sikayetEdilebilir: sikayetEdilebilir,
              onSecildi: (islem) =>
                  unawaited(_islemiYap(context, ref, duyuru, islem)),
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: ListView(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              children: [
                if (duyuru != null)
                  _DuyuruIcerigi(duyuru: duyuru)
                else if (hata != null) ...[
                  HataSatiri.hatadan(hata),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => ref.invalidate(saglayici),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                      ),
                      child: Text(metinler.tayfa_ana_tekrar_dene),
                    ),
                  ),
                ] else
                  Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: metinler.duyuru_yukleniyor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _islemiYap(
    BuildContext context,
    WidgetRef ref,
    Announcement duyuru,
    DuyuruIslemi islem,
  ) async {
    final metinler = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final notifier = ref.read(
      duyuruProvider((tayfaId: tayfaId, duyuruId: duyuruId)).notifier,
    );
    switch (islem) {
      case DuyuruIslemi.duzenle:
        await duyuruFormunuAc(context, tayfaId: tayfaId, duzenlenen: duyuru);
      case DuyuruIslemi.sabitle || DuyuruIslemi.sabitlemeyiKaldir:
        final sabit = islem == DuyuruIslemi.sabitle;
        final hata = await notifier.sabitle(sabit: sabit);
        if (!context.mounted) return;
        if (hata != null) {
          islemHatasiniBildir(context, hata);
          return;
        }
        final metin = sabit
            ? metinler.duyuru_sabitlendi
            : metinler.duyuru_sabitleme_kaldirildi;
        bildirimGoster(bildirim, metin);
      case DuyuruIslemi.sil:
        if (!await _silmeyiOnayla(context)) return;
        final hata = await notifier.sil();
        if (!context.mounted) return;
        if (hata != null) {
          islemHatasiniBildir(context, hata);
          return;
        }
        bildirimGoster(bildirim, metinler.duyuru_silindi);
        await Navigator.of(context).maybePop();
      case DuyuruIslemi.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: tayfaId,
            tur: ReportTargetType.announcement,
            id: duyuru.id,
          ),
        );
    }
  }
}

/// Silme onayı; onaylanırsa `true`.
Future<bool> _silmeyiOnayla(BuildContext context) async {
  final metinler = AppLocalizations.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(metinler.duyuru_sil_onay_baslik),
      content: Text(metinler.duyuru_sil_onay_aciklama),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          child: Text(metinler.duyuru_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          child: Text(metinler.duyuru_sil),
        ),
      ],
    ),
  );
  return onay ?? false;
}

class _IslemMenusu extends StatelessWidget {
  const _IslemMenusu({
    required this.duyuru,
    required this.yonetimde,
    required this.sikayetEdilebilir,
    required this.onSecildi,
  });

  final Announcement duyuru;
  final bool yonetimde;
  final bool sikayetEdilebilir;
  final ValueChanged<DuyuruIslemi> onSecildi;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return PopupMenuButton<DuyuruIslemi>(
      tooltip: metinler.duyuru_islemler,
      icon: const Icon(Icons.more_vert),
      onSelected: onSecildi,
      itemBuilder: (_) => [
        if (yonetimde) ...[
          PopupMenuItem(
            value: DuyuruIslemi.duzenle,
            child: Text(metinler.duyuru_duzenle),
          ),
          if (duyuru.pinned)
            PopupMenuItem(
              value: DuyuruIslemi.sabitlemeyiKaldir,
              child: Text(metinler.duyuru_sabitlemeyi_kaldir),
            )
          else
            PopupMenuItem(
              value: DuyuruIslemi.sabitle,
              child: Text(metinler.duyuru_sabitle),
            ),
          PopupMenuItem(
            value: DuyuruIslemi.sil,
            child: Text(metinler.duyuru_sil),
          ),
        ],
        if (sikayetEdilebilir)
          PopupMenuItem(
            value: DuyuruIslemi.sikayet,
            child: Text(metinler.sikayet_et),
          ),
      ],
    );
  }
}

class _DuyuruIcerigi extends StatelessWidget {
  const _DuyuruIcerigi({required this.duyuru});

  final Announcement duyuru;

  @override
  Widget build(BuildContext context) {
    final yazi = context.yazi;
    final govde = duyuru.body.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (duyuru.pinned) ...[
          const SabitEtiketi(),
          const SizedBox(height: TayfamSpacing.s12),
        ],
        Semantics(
          header: true,
          child: Text(duyuru.title, style: yazi.headlineSmall),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        DuyuruTarihi(zaman: duyuru.createdAt),
        if (govde.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s16),
          // Düz metin: biçim ve bağlantı yorumlanmaz (ADR-0015 §2).
          SelectableText(
            govde,
            style: yazi.bodyLarge?.copyWith(color: context.renkler.metinGovde),
          ),
        ],
      ],
    );
  }
}
