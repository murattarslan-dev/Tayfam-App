import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Etkinlik detayındaki "Sohbet" bölümünü çizen fonksiyon (2026-11-13
/// tasarım: Etkinlik-Sohbet; Tayfam-Api #183). Sohbet paketi kabuktaki
/// kayıtla doldurur (`shell/kayitlar.dart`); bölüm görünürse [baslik]'ı
/// üstüne koyar, görünmezse başlık da çizilmez.
typedef EtkinlikSohbetiYuvasi = Widget Function(
  BuildContext context,
  Event etkinlik,
  Widget baslik,
);

/// Etkinlik detayının sohbet bölümü; verilmezse bölüm yoktur.
final etkinlikSohbetiYuvasiProvider = Provider<EtkinlikSohbetiYuvasi?>(
  (ref) => null,
  name: 'etkinlikSohbetiYuvasiProvider',
);
