import 'package:flutter/material.dart';

import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir işlemin hatasını kısa bildirimle gösterir ([hataBildir]). Oturum
/// kapandıysa ([OturumYok]) giriş ekranına dönülür; ayrı hata
/// gösterilmez.
void birebirHatasiniBildir(BuildContext context, Object hata) {
  if (hata is OturumYok) return;
  hataBildir(context, hata);
}

/// Ekranın altında kısa süreli bildirim gösterir; öncekinin yerini alır.
/// [bildirim] işlemden önce alınır (satır işlem sırasında kalkabilir).
void birebirBildir(ScaffoldMessengerState bildirim, String metin) {
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(metin)));
}

/// İşlem sonucunu [bildirim]'le gösterir: hata varsa metni ortak
/// eşlemeden (oturum kapandıysa hiçbir şey), yoksa verildiyse [basari].
void birebirSonucunuBildir(
  ScaffoldMessengerState bildirim,
  AppLocalizations metinler,
  Object? hata, [
  String? basari,
]) {
  if (hata is OturumYok) return;
  final metin = hata == null ? basari : hataMetni(metinler, hata);
  if (metin != null) birebirBildir(bildirim, metin);
}

/// Konuşmanın karşı tarafının adı; hesabı silinmişse "Silinmiş
/// kullanıcı".
class KarsiTarafAdi extends StatelessWidget {
  const KarsiTarafAdi({super.key, required this.kullaniciId, this.style});

  /// Karşı tarafın kimliği; hesabı silinmişse `null`.
  final String? kullaniciId;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final kimlik = kullaniciId;
    if (kimlik == null) {
      return Text(
        AppLocalizations.of(context).kullanici_silinmis,
        style: style,
      );
    }
    return KullaniciAdiMetni(kullaniciId: kimlik, style: style);
  }
}

/// Uygulama ön plana dönünce [onResume]'u çağırır (ADR-0006: listeler
/// ekran açılınca ve uygulama ön plana dönünce yenilenir). Kendisi bir şey
/// çizmez.
class OnPlanaDonunce extends StatefulWidget {
  const OnPlanaDonunce({
    super.key,
    required this.onResume,
    required this.child,
  });

  final VoidCallback onResume;

  final Widget child;

  @override
  State<OnPlanaDonunce> createState() => _OnPlanaDonunceState();
}

class _OnPlanaDonunceState extends State<OnPlanaDonunce> {
  late final AppLifecycleListener _dinleyici;

  @override
  void initState() {
    super.initState();
    _dinleyici = AppLifecycleListener(onResume: () => widget.onResume());
  }

  @override
  void dispose() {
    _dinleyici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// "Tekrar dene" düğmesi.
class BirebirTekrarDene extends StatelessWidget {
  const BirebirTekrarDene({super.key, required this.onPressed});

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
        child: Text(AppLocalizations.of(context).birebir_tekrar_dene),
      ),
    );
  }
}

/// Ortalanmış ilerleme göstergesi; ekran okuyucu [etiket]'i okur.
class BirebirYukleniyor extends StatelessWidget {
  const BirebirYukleniyor({super.key, required this.etiket});

  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s16),
        child: CircularProgressIndicator(semanticsLabel: etiket),
      ),
    );
  }
}

/// Ekranlardaki açıklama metni (gövde rengi).
class BirebirAciklama extends StatelessWidget {
  const BirebirAciklama(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Text(
      metin,
      style: context.yazi.bodyMedium?.copyWith(
        color: context.renkler.metinGovde,
      ),
    );
  }
}
