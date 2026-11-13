import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/presentation/cevap_formu_ekrani.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_formu_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru formunu kabuğun üstünde tam ekran açar (ADR-0018 §4). Yeni soru
/// için [duzenlenen] `null`'dır; soru sorulunca sorunun ekranına gidilir.
/// Sonuç liste ve detaya form içinde yansır.
Future<void> soruFormunuAc(
  BuildContext context, {
  required String tayfaId,
  Question? duzenlenen,
}) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<Question>(
      fullscreenDialog: true,
      builder: (_) => SoruFormuEkrani(tayfaId: tayfaId, duzenlenen: duzenlenen),
    ),
  );
  if (sonuc == null) return;
  if (duzenlenen == null) {
    bildirimGoster(bildirim, metinler.soru_soruldu);
    if (!context.mounted) return;
    GoRouter.maybeOf(context)?.go(Adresler.soru(tayfaId, sonuc.id));
  } else {
    bildirimGoster(bildirim, metinler.soru_kaydedildi);
  }
}

/// Cevap formunu kabuğun üstünde tam ekran açar. Yeni cevap için
/// [duzenlenen] `null`'dır. [soruBasligi] formun üstünde alıntılanır
/// (tasarım: Cevap-Form). Sonuç cevap listesine form içinde yansır.
Future<void> cevapFormunuAc(
  BuildContext context, {
  required String tayfaId,
  required String soruId,
  required String soruBasligi,
  Answer? duzenlenen,
}) async {
  final metinler = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sonuc = await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<Answer>(
      fullscreenDialog: true,
      builder: (_) => CevapFormuEkrani(
        tayfaId: tayfaId,
        soruId: soruId,
        soruBasligi: soruBasligi,
        duzenlenen: duzenlenen,
      ),
    ),
  );
  if (sonuc == null) return;
  bildirimGoster(
    bildirim,
    duzenlenen == null
        ? metinler.soru_cevap_gonderildi
        : metinler.soru_kaydedildi,
  );
}

/// Ekranın altında kısa süreli bildirim gösterir; öncekinin yerini alır.
void bildirimGoster(ScaffoldMessengerState bildirim, String metin) {
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// Bir işlemin hatasını gösterir ([hataBildir]). Oturum kapandıysa
/// ([OturumYok]) giriş ekranına dönülür; ayrı hata gösterilmez.
void islemHatasiniBildir(BuildContext context, Object hata) {
  if (hata is OturumYok) return;
  hataBildir(context, hata);
}

/// Silme onayı; onaylanırsa `true`. Son adım dolu yıkıcı düğmedir
/// (ADR-0004 Notlar 2026-11-13).
Future<bool> silmeyiOnayla(
  BuildContext context, {
  required String baslik,
  required String aciklama,
}) async {
  final metinler = AppLocalizations.of(context);
  final onay = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(baslik),
      scrollable: true,
      content: Text(aciklama),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(metinler.soru_vazgec),
        ),
        YikiciEylem(
          etiket: metinler.soru_sil,
          dolu: true,
          onPressed: () => Navigator.of(pencere).pop(true),
        ),
      ],
    ),
  );
  return onay ?? false;
}

/// Soru ve cevap ⋯ menüsünün seçenekleri.
enum IcerikIslemi { duzenle, sil, sikayet }

/// Soru ya da cevap işlemleri için alttan sayfa (tasarım: Soru-Detay;
/// ADR-0004 Notlar 2026-11-13 madde 5). [yonetebilir] (yazar ya da
/// yönetim) ise Düzenle ve yıkıcı Sil, değilse Şikâyet et. Menü yalnızca
/// arayüzü sadeleştirir; kararı sunucu verir (kesin kural 5).
Future<IcerikIslemi?> icerikIslemiSec(
  BuildContext context, {
  required String baslik,
  required bool yonetebilir,
}) {
  final m = AppLocalizations.of(context);
  return altSayfaAc<IcerikIslemi>(
    context,
    builder: (sayfa) => AltSayfaIcerigi(
      baslik: baslik,
      children: [
        if (yonetebilir) ...[
          MenuSatiri(
            baslik: m.soru_duzenle,
            ikon: Icons.edit_outlined,
            onTap: () => Navigator.of(sayfa).pop(IcerikIslemi.duzenle),
          ),
          MenuSatiri(
            baslik: m.soru_sil,
            ikon: Icons.delete_outline,
            tur: MenuSatiriTuru.yikici,
            onTap: () => Navigator.of(sayfa).pop(IcerikIslemi.sil),
          ),
        ] else
          MenuSatiri(
            baslik: m.sikayet_et,
            ikon: Icons.flag_outlined,
            onTap: () => Navigator.of(sayfa).pop(IcerikIslemi.sikayet),
          ),
      ],
    ),
  );
}

/// Soru-cevap formlarındaki ve arama kutusundaki alanların görünümü
/// (tasarım: Soru-Form, Sorular): kart zemin, 1.5 px giriş kenarı,
/// odakta 2 px marka kenar; köşe 14 px ya da [koseler].
InputDecoration soruAlanGorunumu(
  BuildContext context, {
  BorderRadius koseler = TayfamRadii.onizlemeKoseleri,
}) {
  final r = context.renkler;
  OutlineInputBorder kenar(Color renk, double kalinlik) => OutlineInputBorder(
    borderRadius: koseler,
    borderSide: BorderSide(color: renk, width: kalinlik),
  );
  return InputDecoration(
    filled: true,
    fillColor: r.kart,
    border: kenar(r.girisKenari, TayfamSizes.vurguKenari),
    enabledBorder: kenar(r.girisKenari, TayfamSizes.vurguKenari),
    focusedBorder: kenar(r.marka, TayfamSizes.alanOdakKenari),
    errorBorder: kenar(r.narMetin, TayfamSizes.vurguKenari),
    focusedErrorBorder: kenar(r.narMetin, TayfamSizes.alanOdakKenari),
    disabledBorder: kenar(r.pasif, TayfamSizes.vurguKenari),
  );
}

/// Tam ekran formun sağ üstündeki gönder düğmesi (tasarım: Soru-Form
/// "Sor", Cevap-Form "Gönder").
class FormUstEylemi extends StatelessWidget {
  const FormUstEylemi({
    super.key,
    required this.etiket,
    required this.onPressed,
  });

  final String etiket;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: TayfamSpacing.s12),
      child: Center(
        child: BirincilEylem(etiket: etiket, onPressed: onPressed),
      ),
    );
  }
}

/// İçeriğin yazarı (avatar ve ad) ve yazıldığı gün ve saat (cihazın
/// saatine göre; tasarım: Soru-Detay). Yazarın hesabı silindiyse
/// "Silinmiş kullanıcı" yazar.
///
/// Soruda ad ve zaman aynı satırdadır ("Ad · tarih"); cevapta ([cevapta])
/// ad kalın, zaman altında küçük. [sag] verilirse (ör. "En faydalı"
/// etiketi) satırın sonundadır; dar ekranda ve büyük yazıda alta iner.
class YazarSatiri extends StatelessWidget {
  const YazarSatiri({
    super.key,
    required this.yazarId,
    required this.zaman,
    this.cevapta = false,
    this.sag,
  });

  /// Yazarın kimliği; hesap silindiyse `null`.
  final String? yazarId;

  /// Sunucudan gelen zaman (UTC).
  final DateTime zaman;

  final bool cevapta;
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final yazarId = this.yazarId;
    final sag = this.sag;
    final yerel = zaman.toLocal();
    final tarih = metinler.soru_tarih(yerel, yerel);
    final adStili = cevapta
        ? yazi.titleSmall
        : yazi.bodySmall?.copyWith(color: r.metin, fontWeight: FontWeight.w700);
    final zamanStili = (cevapta ? yazi.labelSmall : yazi.bodySmall)?.copyWith(
      color: r.metinIkincil,
    );
    final ad = yazarId == null
        ? Text(metinler.kullanici_silinmis, style: adStili)
        : KullaniciAdiMetni(kullaniciId: yazarId, style: adStili);
    final Widget kimlik = cevapta
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ad,
              Text(tarih, style: zamanStili),
            ],
          )
        : Wrap(
            spacing: TayfamSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ad,
              // Ayraç süstür; ekran okuyucu ad ve tarihi okur.
              ExcludeSemantics(child: Text('·', style: zamanStili)),
              Text(tarih, style: zamanStili),
            ],
          );
    return Row(
      children: [
        KimlikAvatari(kullaniciId: yazarId, cap: TayfamSizes.mesajAvatari),
        const SizedBox(width: TayfamSpacing.s12),
        Expanded(
          child: sag == null
              ? kimlik
              : Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s4,
                  children: [kimlik, sag],
                ),
        ),
      ],
    );
  }
}

/// Sorunun etiketleri (ADR-0004 etiket bileşeni).
class SoruEtiketleri extends StatelessWidget {
  const SoruEtiketleri({super.key, required this.etiketler});

  final List<Tag> etiketler;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TayfamSpacing.s8,
      runSpacing: TayfamSpacing.s8,
      children: [for (final e in etiketler) Etiket(metin: e.name)],
    );
  }
}
