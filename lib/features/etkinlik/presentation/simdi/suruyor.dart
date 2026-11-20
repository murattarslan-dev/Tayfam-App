import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Açık uçlu (Şimdi başlat) etkinlik şu an sürüyor mu (App ADR-0032 §3,
/// Tayfam-Api ADR-0038 §1): `open_ended`, iptal edilmemiş, başlamış ve en
/// geç bitişi (`ends_at`) gelmemiş. `open_ended` 12 saatlik otomatik
/// bitişten sonra da `true` kaldığı için sürüp sürmediğine yalnızca
/// `ends_at` ile şimdiye bakılarak karar verilir.
bool acikUcluSuruyor(Event etkinlik, DateTime simdi) =>
    etkinlik.openEnded &&
    etkinlik.status != EventStatus.cancelled &&
    !etkinlik.startsAt.isAfter(simdi) &&
    etkinlik.endsAt.isAfter(simdi);

/// Başlangıçtan bu yana geçen süre (dakikaya yuvarlanmış, aşağı).
Duration gecenSure(Event etkinlik, DateTime simdi) {
  final fark = simdi.difference(etkinlik.startsAt);
  return fark.isNegative ? Duration.zero : Duration(minutes: fark.inMinutes);
}

/// Geçen sürenin kısa metni: "25 dk", "1 sa 5 dk".
String gecenSureMetni(AppLocalizations m, Duration sure) {
  final dakika = sure.inMinutes % Duration.minutesPerHour;
  final saat = sure.inHours;
  return saat == 0
      ? m.simdi_sure_dakika(dakika)
      : m.simdi_sure_saat(saat, dakika);
}

/// Geçen sürenin ekran okuyucu metni: "25 dakika", "1 saat 5 dakika".
String gecenSureOkunusu(AppLocalizations m, Duration sure) {
  final dakika = sure.inMinutes % Duration.minutesPerHour;
  final saat = sure.inHours;
  return saat == 0
      ? m.simdi_sure_okunus_dakika(dakika)
      : m.simdi_sure_okunus_saat(saat, dakika);
}

/// "En geç" bitiş saati ("23:15"), cihazın saatinde (ADR-0008).
String enGecSaat(AppLocalizations m, DateTime bitis) =>
    DateFormat.Hm(m.localeName).format(bitis.toLocal());

/// Açık uçlu etkinliğin "sürüyor" halini izleyen yapıcı: [builder]'a
/// etkinliğin sürüp sürmediği ve geçen süre verilir.
///
/// Süre **dakikada bir** güncellenir (saniye gösterilmez): bir sonraki
/// dakika başında (ya da en geç bitişte, hangisi önceyse) tek bir
/// zamanlayıcı kurulur. Böylece hareket kuralına uyulur ve ekran okuyucu
/// sürekli anons almaz; metin canlı bölge (`liveRegion`) değildir.
/// Etkinlik sürmüyorsa zamanlayıcı kurulmaz. Saat `etkinlikSaatiProvider`,
/// zamanlayıcı `zamanlayiciProvider`'dandır (testlerde sahte).
class SuruyorIzleyici extends ConsumerStatefulWidget {
  const SuruyorIzleyici({
    super.key,
    required this.etkinlik,
    required this.builder,
  });

  final Event etkinlik;
  final Widget Function(BuildContext context, bool suruyor, Duration gecen)
  builder;

  @override
  ConsumerState<SuruyorIzleyici> createState() => _SuruyorIzleyiciState();
}

class _SuruyorIzleyiciState extends ConsumerState<SuruyorIzleyici> {
  Timer? _zamanlayici;

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  void _kur(DateTime simdi) {
    _zamanlayici?.cancel();
    _zamanlayici = null;
    final etkinlik = widget.etkinlik;
    if (!acikUcluSuruyor(etkinlik, simdi)) return;
    final gecenSaniye = simdi.difference(etkinlik.startsAt).inSeconds;
    var bekle = Duration(
      seconds:
          Duration.secondsPerMinute - gecenSaniye % Duration.secondsPerMinute,
    );
    final bitiseKalan = etkinlik.endsAt.difference(simdi);
    if (bitiseKalan < bekle) bekle = bitiseKalan;
    _zamanlayici = ref.read(zamanlayiciProvider)(bekle, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Saat her çizimde yeniden okunur; zamanlayıcı yalnızca yeniden
    // çizdirir.
    final simdi = ref.watch(etkinlikSaatiProvider)().toUtc();
    _kur(simdi);
    final suruyor = acikUcluSuruyor(widget.etkinlik, simdi);
    return widget.builder(
      context,
      suruyor,
      suruyor ? gecenSure(widget.etkinlik, simdi) : Duration.zero,
    );
  }
}

/// Kart ve detay üst bölümündeki "Sürüyor · 25 dk" etiketi; etkinlik
/// sürmüyorsa hiçbir şey çizmez. Ekran okuyucu "Sürüyor, başlayalı 25
/// dakika oldu" okur; süre dakikada bir değişir, anons edilmez.
class SuruyorEtiketi extends StatelessWidget {
  const SuruyorEtiketi({super.key, required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return SuruyorIzleyici(
      etkinlik: etkinlik,
      builder: (context, suruyor, gecen) {
        if (!suruyor) return const SizedBox.shrink();
        return suruyorEtiketi(m, gecen);
      },
    );
  }
}

/// "Sürüyor · 25 dk" etiketinin kendisi (izleyicisiz); [gecen] geçen süre.
Widget suruyorEtiketi(AppLocalizations m, Duration gecen) => Semantics(
  label: m.simdi_suruyor_okunus(gecenSureOkunusu(m, gecen)),
  excludeSemantics: true,
  child: Etiket(
    metin: m.simdi_suruyor_etiketi(gecenSureMetni(m, gecen)),
    ton: EtiketTonu.teal,
    ikon: Icons.play_circle_outline,
  ),
);
