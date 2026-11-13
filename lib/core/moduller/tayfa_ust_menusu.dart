import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tayfa ana sayfasının mor üst bölümündeki menü düğmesini kuran işlev
/// (ADR-0018 §1): "Tayfa ayarları", "Bildirimleri sessize al", "Tayfadan
/// ayrıl".
///
/// Menü tayfa yönetimi özelliğindedir; tayfa özelliği onu import edemez
/// (yönetim tayfa özelliğini kullanır, döngü olurdu; ADR-0002). Bu yüzden
/// [tayfaModulleriProvider] gibi kayıtla bağlanır: `shell/kayitlar.dart`
/// bu provider'ı override eder.
typedef TayfaUstMenusu = Widget Function(BuildContext context, String tayfaId);

/// Uygulamaya kayıtlı tayfa üst menüsü. Varsayılanı `null`'dır (`core/`
/// `shell/`'i import edemez); `null` iken menü düğmesi gösterilmez.
final tayfaUstMenusuProvider = Provider<TayfaUstMenusu?>(
  (ref) => null,
  name: 'tayfaUstMenusuProvider',
);

/// Tayfaya davet (tasarım: Ana-Ilk-Ekran kişi+ ikonu, "Oluştur" sayfasındaki
/// "Tayfaya davet et", kurulum kartındaki "Davet linkini paylaş"): yeni
/// davet linki oluşturma sayfasını açar. Her üye link açabilir; yetkiyi
/// sunucu verir (sözleşme, `POST /v1/tayfas/{tayfa_id}/invites`).
///
/// Davet linki tayfa yönetimi özelliğindedir; [tayfaUstMenusuProvider]
/// gibi kayıtla bağlanır. `null` iken davet girişleri gösterilmez.
typedef TayfaDaveti = Future<void> Function(
  BuildContext context,
  String tayfaId,
);

/// Uygulamaya kayıtlı davet akışı; varsayılanı `null`.
final tayfaDavetiProvider = Provider<TayfaDaveti?>(
  (ref) => null,
  name: 'tayfaDavetiProvider',
);

/// Silinmesi planlanmış tayfanın durum şeridindeki "Silmeyi iptal et"
/// düğmesini kuran işlev (tasarım: Ayar-Silme). Yalnızca yöneticiye
/// gösterilir; iptali sunucu yetkilendirir. Tayfa yönetimi kaydıyla
/// bağlanır; `null` iken düğme gösterilmez.
typedef TayfaSilmeIptali = Widget Function(
  BuildContext context,
  String tayfaId,
);

/// Uygulamaya kayıtlı "Silmeyi iptal et" düğmesi; varsayılanı `null`.
final tayfaSilmeIptaliProvider = Provider<TayfaSilmeIptali?>(
  (ref) => null,
  name: 'tayfaSilmeIptaliProvider',
);
