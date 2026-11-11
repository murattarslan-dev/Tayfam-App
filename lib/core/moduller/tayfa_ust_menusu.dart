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
