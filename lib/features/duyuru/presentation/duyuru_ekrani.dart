import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/duyuru/application/duyuru_notifier.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_karti.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ortak.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Duyuru işlemleri sayfasının seçenekleri.
enum DuyuruIslemi { duzenle, sabitle, sabitlemeyiKaldir, sil, sikayet }

/// Tek bir duyuru (`/t/<tayfaId>/duyurular/<duyuruId>`; ADR-0015 §2;
/// tasarım: Duyuru-Detay): "Sabitlendi" etiketi, büyük başlık, yazar
/// (avatar + ad, ad önbelleğinden; yazar yalnızca burada görünür), yayın
/// tarihi ("düzenlendi" `updated_at` > `created_at` ise) ve gövde. Gövde
/// düz metindir; markdown ya da HTML yorumlanmaz, bağlantılar dokunulabilir
/// değildir.
///
/// Adresteki [duyuruId] girdi kabul edilir: UUID biçiminde değilse istek
/// gönderilmez, "bulunamadı" gösterilir. ⋯ alttan sayfayı açar
/// (tasarım: Duyuru-Menu): moderatör ve yöneticiye Düzenle, Sabitle /
/// Sabitlemeyi kaldır ve (onaylı) Sil; kararı sunucu verir. Başkasının
/// duyurusunda "Şikâyet et" vardır (ADR-0018 §8).
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
        actions: [
          if (duyuru != null && (yonetimde || sikayetEdilebilir))
            IconButton(
              tooltip: metinler.duyuru_islemler,
              icon: const Icon(Icons.more_horiz),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              onPressed: () => unawaited(
                _menuyuAc(
                  context,
                  ref,
                  duyuru,
                  yonetimde: yonetimde,
                  sikayetEdilebilir: sikayetEdilebilir,
                ),
              ),
            ),
          const SizedBox(width: TayfamSpacing.s8),
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
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.s20,
                TayfamSpacing.s4,
                TayfamSpacing.s20,
                TayfamSpacing.s32,
              ),
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
                    child: TayfamYukleniyor(
                      boyut: TayfamSizes.yukleniyorTamEkran,
                      etiket: metinler.duyuru_yukleniyor,
                      gecikmeli: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⋯ alttan sayfası (tasarım: Duyuru-Menu): başlıkta duyurunun adı.
  Future<void> _menuyuAc(
    BuildContext context,
    WidgetRef ref,
    Announcement duyuru, {
    required bool yonetimde,
    required bool sikayetEdilebilir,
  }) async {
    final m = AppLocalizations.of(context);
    final secim = await altSayfaAc<DuyuruIslemi>(
      context,
      builder: (sayfa) {
        void sec(DuyuruIslemi islem) => Navigator.of(sayfa).pop(islem);
        return AltSayfaIcerigi(
          baslik: duyuru.title,
          children: [
            if (yonetimde) ...[
              MenuSatiri(
                baslik: m.duyuru_duzenle,
                ikon: Icons.edit_outlined,
                onTap: () => sec(DuyuruIslemi.duzenle),
              ),
              if (duyuru.pinned)
                MenuSatiri(
                  baslik: m.duyuru_sabitlemeyi_kaldir,
                  aciklama: m.duyuru_menu_sabitlemeyi_kaldir_aciklama,
                  ikon: Icons.push_pin_outlined,
                  onTap: () => sec(DuyuruIslemi.sabitlemeyiKaldir),
                )
              else
                MenuSatiri(
                  baslik: m.duyuru_sabitle,
                  aciklama: m.duyuru_menu_sabitle_aciklama,
                  ikon: Icons.push_pin_outlined,
                  onTap: () => sec(DuyuruIslemi.sabitle),
                ),
              MenuSatiri(
                baslik: m.duyuru_sil,
                aciklama: m.duyuru_menu_sil_aciklama,
                ikon: Icons.delete_outline,
                tur: MenuSatiriTuru.yikici,
                onTap: () => sec(DuyuruIslemi.sil),
              ),
            ],
            if (sikayetEdilebilir)
              MenuSatiri(
                baslik: m.sikayet_et,
                ikon: Icons.flag_outlined,
                onTap: () => sec(DuyuruIslemi.sikayet),
              ),
          ],
        );
      },
    );
    if (secim == null || !context.mounted) return;
    await _islemiYap(context, ref, duyuru, secim);
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

/// Silme onayı; onaylanırsa `true`. Son adım dolu yıkıcı düğmedir
/// (ADR-0004 Notlar 2026-11-13).
Future<bool> _silmeyiOnayla(BuildContext context) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) {
      final metinler = AppLocalizations.of(pencere);
      return AlertDialog(
        title: Text(metinler.duyuru_sil_onay_baslik),
        scrollable: true,
        content: Text(metinler.duyuru_sil_onay_aciklama),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(metinler.duyuru_vazgec),
          ),
          YikiciEylem(
            etiket: metinler.duyuru_sil,
            dolu: true,
            onPressed: () => Navigator.of(pencere).pop(true),
          ),
        ],
      );
    },
  );
  return onay ?? false;
}

class _DuyuruIcerigi extends StatelessWidget {
  const _DuyuruIcerigi({required this.duyuru});

  final Announcement duyuru;

  @override
  Widget build(BuildContext context) {
    final yazi = context.yazi;
    final r = context.renkler;
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
          child: Text(duyuru.title, style: yazi.headlineMedium),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        _YazarSatiri(duyuru: duyuru),
        const SizedBox(height: TayfamSpacing.s12),
        Divider(
          height: TayfamSizes.kenar,
          thickness: TayfamSizes.kenar,
          color: r.cizgi,
        ),
        if (govde.isNotEmpty) ...[
          const SizedBox(height: TayfamSpacing.s16),
          // Düz metin: biçim ve bağlantı yorumlanmaz (ADR-0015 §2).
          SelectableText(govde, style: yazi.bodyLarge),
        ],
      ],
    );
  }
}

/// Yazar (avatar + ad, ad önbelleğinden; hesap silindiyse "Silinmiş
/// kullanıcı") ve yayın tarihi. Avatar süstür; ad metni okunur.
class _YazarSatiri extends StatelessWidget {
  const _YazarSatiri({required this.duyuru});

  final Announcement duyuru;

  @override
  Widget build(BuildContext context) {
    final yazi = context.yazi;
    final yazar = duyuru.authorUserId;
    final adStili = yazi.titleSmall;
    return MergeSemantics(
      child: Row(
        children: [
          KimlikAvatari(kullaniciId: yazar, cap: TayfamSizes.ustCubukKutusu),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (yazar != null)
                  KullaniciAdiMetni(kullaniciId: yazar, style: adStili)
                else
                  Text(
                    AppLocalizations.of(context).kullanici_silinmis,
                    style: adStili,
                  ),
                DuyuruTarihi(
                  zaman: duyuru.createdAt,
                  duzenlendi: duyuru.updatedAt.isAfter(duyuru.createdAt),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
