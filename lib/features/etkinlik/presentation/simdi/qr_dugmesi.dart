import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/qr_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinliğin QR durumu (App ADR-0032 §3).
enum QrDugmesi {
  /// Düğme yok (çevrimiçi, iptal, bitmiş ya da henüz başlamamış).
  yok,

  /// "QR göster": organizatör ya da tayfa yöneticisi.
  goster,

  /// "QR okut": diğer üyeler, etkinlik sürerken.
  okut,
}

/// Detayda hangi QR düğmesinin görüneceği. Yalnızca yüz yüze, iptal
/// edilmemiş ve bitmemiş etkinlikte. Organizatör ya da yönetici
/// (`caller_can_manage`) QR'ı her zaman gösterebilir; diğerleri yalnızca
/// etkinlik başladıktan sonra okutur. Bu arayüz kolaylığıdır; karar
/// sunucunundur (kesin kural 5).
QrDugmesi qrDugmesi(Event etkinlik, DateTime simdi) {
  if (etkinlik.mode != EventMode.inPerson ||
      etkinlik.status == EventStatus.cancelled ||
      !simdi.isBefore(etkinlik.endsAt)) {
    return QrDugmesi.yok;
  }
  if (etkinlik.callerCanManage) return QrDugmesi.goster;
  return simdi.isBefore(etkinlik.startsAt) ? QrDugmesi.yok : QrDugmesi.okut;
}

/// Etkinlik detayındaki QR düğmesi: "QR göster" katılım QR'ı ekranını,
/// "QR okut" QR ile katılım ekranını (`/q`) açar.
class QrKatilimDugmesi extends ConsumerWidget {
  const QrKatilimDugmesi({
    super.key,
    required this.anahtar,
    required this.etkinlik,
  });

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final dugme = switch (qrDugmesi(etkinlik, simdi)) {
      QrDugmesi.yok => null,
      QrDugmesi.goster => CerceveliHapEylem(
        key: const ValueKey('qr-goster'),
        etiket: m.simdi_qr_goster,
        ikon: Icons.qr_code_2,
        onPressed: () => unawaited(
          katilimQruAc(context, anahtar: anahtar, baslik: etkinlik.title),
        ),
      ),
      QrDugmesi.okut => CerceveliHapEylem(
        key: const ValueKey('qr-okut'),
        etiket: m.simdi_qr_okut,
        ikon: Icons.qr_code_scanner,
        onPressed: () => unawaited(context.push<void>(Adresler.qrKatilim)),
      ),
    };
    if (dugme == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s16),
      child: Align(alignment: AlignmentDirectional.centerStart, child: dugme),
    );
  }
}
