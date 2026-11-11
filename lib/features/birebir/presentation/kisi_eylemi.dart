import 'package:flutter/widgets.dart';

import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/birebir/presentation/kisi_konusmasi_ekrani.dart';

/// Kişi profilindeki "Mesaj gönder" eylemi (ADR-0018 §9;
/// `kisiProfiliEylemleriProvider` kancası, `shell/kayitlar.dart`).
///
/// Sunucu yalnızca arkadaşa ya da ortak aktif tayfası olana yazdırır
/// (`direct-message-not-allowed`); düğme bu yüzden yalnızca o durumda
/// gösterilir. Bu yalnızca sadeleştirmedir; mesaj isteği dahil kararı
/// sunucu verir (kesin kural 5).
Widget? mesajGonderEylemi(BuildContext context, KisiProfiliBilgisi kisi) {
  if (!kisi.arkadas && !kisi.ortakTayfaVar) return null;
  return MesajGonderDugmesi(kullaniciId: kisi.kullaniciId);
}
