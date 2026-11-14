import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/tayfa_gorunumu.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_avatari.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa değiştirme panelini alttan açar (ADR-0003, ADR-0014 §2; tasarım:
/// Ana-Tayfa-Degistir).
///
/// Panel kök navigator'da açılır; gezinme çubuğunun da üstünü örter.
/// Seçenekler paneli kapatıp akışı [context]'in yönlendiricisiyle açar.
///
/// [tayfayaGit] `false` ise (Sohbet sekmesindeki "Kanalları gösterilen
/// tayfa" satırı) seçilen tayfa yalnızca aktif olur; bulunulan sekmede
/// kalınır.
Future<void> tayfaDegistirmePaneliniAc(
  BuildContext context, {
  bool tayfayaGit = true,
}) {
  return altSayfaAc<void>(
    context,
    builder: (panelContext) {
      void kapat() => Navigator.of(panelContext).pop();

      return TayfaDegistirmePaneli(
        onTayfaSec: (tayfaId) {
          kapat();
          if (tayfayaGit) context.go(Adresler.tayfa(tayfaId));
        },
        onKodlaKatil: () {
          kapat();
          unawaited(kodlaKatilmaSayfasiniAc(context));
        },
        onTayfaOlustur: () {
          kapat();
          // Sihirbaz yığının üstüne itilmez: başarıda aktif tayfa değişince
          // yönlendirici alttaki adresi ana sayfaya çevirir ve "Tayfa
          // kuruldu" ekranı kaybolurdu (ADR-0014 Notlar 2026-11-13).
          context.go(Adresler.tayfaOlustur);
        },
      );
    },
  );
}

/// Tayfa değiştirme panelinin içeriği: etkin tayfalar (avatar, üye sayısı
/// ve rol; seçili olan tint zeminli ve işaretli), "Onay bekliyor"
/// etiketli bekleyen istekler ("İsteği geri çek"), "Tayfa kodum var" ve
/// "Tayfa oluştur".
///
/// Bekleyen tayfanın yalnızca adı görünür; dokununca isteği geri çekme
/// onayı açılır (ADR-0014 §2).
class TayfaDegistirmePaneli extends ConsumerWidget {
  const TayfaDegistirmePaneli({
    super.key,
    required this.onTayfaSec,
    required this.onKodlaKatil,
    required this.onTayfaOlustur,
  });

  /// Etkin bir tayfa seçildiğinde (aktif tayfa zaten değişmiştir).
  final ValueChanged<String> onTayfaSec;

  /// "Tayfa kodum var" seçildiğinde.
  final VoidCallback onKodlaKatil;

  /// "Tayfa oluştur" seçildiğinde.
  final VoidCallback onTayfaOlustur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    final durum = ref.watch(tayfalarimProvider);
    final aktif = ref.watch(aktifTayfaIdProvider);
    final liste = durum.value;
    final etkinler = liste == null ? const <MyTayfa>[] : etkinTayfalar(liste);
    final bekleyenler = liste == null
        ? const <MyTayfa>[]
        : bekleyenTayfalar(liste);
    final hata = durum.error;

    return AltSayfaIcerigi(
      baslik: metinler.tayfa_tayfalarim,
      children: [
        if (liste == null && hata == null)
          Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s16),
            child: Center(
              child: TayfamYukleniyor(
                etiket: metinler.tayfa_yukleniyor,
                gecikmeli: true,
              ),
            ),
          )
        else if (liste == null && hata != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s8,
              vertical: TayfamSpacing.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HataSatiri.hatadan(hata),
                const SizedBox(height: TayfamSpacing.s8),
                TextButton(
                  onPressed: () =>
                      unawaited(ref.read(tayfalarimProvider.notifier).yenile()),
                  child: Text(metinler.tayfa_tekrar_dene),
                ),
              ],
            ),
          )
        else if (etkinler.isEmpty && bekleyenler.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s8,
              vertical: TayfamSpacing.s8,
            ),
            child: Text(
              metinler.tayfa_tayfalarim_bos,
              style: yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
          ),
        for (final tayfa in etkinler)
          _EtkinTayfaSatiri(
            tayfa: tayfa,
            secili: tayfa.tayfaId == aktif,
            onTap: () {
              ref.read(aktifTayfaIdProvider.notifier).sec(tayfa.tayfaId);
              onTayfaSec(tayfa.tayfaId);
            },
          ),
        for (final tayfa in bekleyenler)
          _BekleyenTayfaSatiri(
            ad: _ad(metinler, tayfa),
            onGeriCek: () => unawaited(
              geriCekmeyiSor(context, ref, tayfa.tayfaId, _ad(metinler, tayfa)),
            ),
          ),
        const SizedBox(height: TayfamSpacing.s8),
        const Divider(),
        MenuSatiri(
          ikon: Icons.vpn_key_outlined,
          tur: MenuSatiriTuru.sade,
          baslik: metinler.tayfa_kodla_katil,
          onTap: onKodlaKatil,
        ),
        MenuSatiri(
          ikon: Icons.add_circle_outline,
          tur: MenuSatiriTuru.sade,
          baslik: metinler.tayfa_olustur,
          onTap: onTayfaOlustur,
        ),
      ],
    );
  }
}

String _ad(AppLocalizations metinler, MyTayfa tayfa) =>
    tayfa.name.isEmpty ? metinler.tayfa_adi_bilinmiyor : tayfa.name;

/// Rolün kısa adı ("Yönetici", "Moderatör", "Üye"); bilinmiyorsa `null`.
String? rolAdi(AppLocalizations m, Role? rol) => switch (rol) {
  Role.admin => m.yonetim_rol_admin,
  Role.moderator => m.yonetim_rol_moderator,
  Role.member => m.yonetim_rol_member,
  Role.unknown || null => null,
};

class _EtkinTayfaSatiri extends StatelessWidget {
  const _EtkinTayfaSatiri({
    required this.tayfa,
    required this.secili,
    required this.onTap,
  });

  final MyTayfa tayfa;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final ad = _ad(metinler, tayfa);
    final rol = rolAdi(metinler, tayfa.role);
    final uyeSayisi = tayfa.tayfa?.memberCount;
    // Onay bekleyen katılım isteği sayısı; yalnızca moderatör ve yöneticiye
    // gelir (`pending_join_request_count`). `null` ise rozet yok.
    final bekleyen = bekleyenIstekRozeti(tayfa.tayfa);
    final ozet = switch ((uyeSayisi, rol)) {
      (final int sayi, final String rol) => metinler.tayfa_panel_ozet(
        sayi,
        rol,
      ),
      (final int sayi, null) => metinler.tayfa_uye_sayisi(sayi),
      (null, final String rol) => rol,
      (null, null) => null,
    };
    return MenuSatiri(
      ikonKutusu: TayfaAvatari.tayfadan(tayfa.tayfa, ad: ad),
      tur: secili ? MenuSatiriTuru.vurgulu : MenuSatiriTuru.olagan,
      icBosluk: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s12,
        vertical: TayfamSpacing.s8,
      ),
      baslik: ad,
      aciklama: ozet,
      sag: !secili && bekleyen == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bekleyen != null)
                  Semantics(
                    label: metinler.tayfa_bekleyen_istek_sayisi(bekleyen),
                    child: ExcludeSemantics(
                      child: Badge(
                        label: Text(bekleyenRozetMetni(metinler, bekleyen)),
                      ),
                    ),
                  ),
                if (bekleyen != null && secili)
                  const SizedBox(width: TayfamSpacing.s8),
                if (secili)
                  Icon(
                    Icons.check,
                    color: context.renkler.marka,
                    semanticLabel: metinler.tayfa_secili,
                  ),
              ],
            ),
      onTap: onTap,
    );
  }
}

/// Onay bekleyen katılım isteği: soluk avatar, ad, "Onay bekliyor"
/// etiketi ve "İsteği geri çek". Satıra dokunmak da geri çekme onayını
/// açar.
class _BekleyenTayfaSatiri extends StatelessWidget {
  const _BekleyenTayfaSatiri({required this.ad, required this.onGeriCek});

  final String ad;
  final VoidCallback onGeriCek;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return MenuSatiri(
      ikonKutusu: TayfaAvatari(ad: ad, pasif: true),
      icBosluk: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s12,
        vertical: TayfamSpacing.s8,
      ),
      baslik: ad,
      // Dar ekranda ve büyük yazıda düğme etiketin altına iner.
      altOge: Wrap(
        spacing: TayfamSpacing.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Etiket(
            metin: metinler.tayfa_onay_bekliyor,
            ton: EtiketTonu.mango,
            ikon: Icons.schedule,
          ),
          TextButton(
            onPressed: onGeriCek,
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            ),
            child: Text(metinler.tayfa_geri_cek_dugmesi),
          ),
        ],
      ),
      onTap: onGeriCek,
    );
  }
}

/// Bekleyen isteği geri çekme onayı (ADR-0014 §2; panel ve karşılama
/// ekranı). Onaylanırsa `DELETE /v1/tayfas/{tayfa_id}/membership`; sonuç
/// kısa bir bildirimle gösterilir.
Future<void> geriCekmeyiSor(
  BuildContext context,
  WidgetRef ref,
  String tayfaId,
  String ad,
) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(metinler.tayfa_geri_cek_baslik),
      content: Text(metinler.tayfa_geri_cek_aciklama(ad)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          child: Text(metinler.tayfa_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          child: Text(metinler.tayfa_geri_cek_onayla),
        ),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  final hata = await ref.read(tayfalarimProvider.notifier).geriCek(tayfaId);
  if (!context.mounted) return;
  if (hata != null) {
    hataBildir(context, hata);
    return;
  }
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metinler.tayfa_geri_cekildi)));
}
