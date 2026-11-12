import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Oturumdaki kullanıcının kimliğini sunucudan okur.
typedef KendiKimligiOkuyucu = Future<String> Function();

/// `GET /v1/me/account`'un `user_id` alanı (Tayfam-Api #150). Testlerde
/// sahtesi verilir.
final kendiKimligiOkuyucuProvider = Provider<KendiKimligiOkuyucu>((ref) {
  final api = MeApi(ref.watch(apiClientProvider));
  return () async => (await api.getAccount()).userId;
}, name: 'kendiKimligiOkuyucuProvider');

/// Oturumdaki kullanıcının kimliği ("kendi satırım / kendi aracım"
/// ayrımları için; profil ucunun `self` alanına dolaylı başvuru yerine).
///
/// - Yalnızca bellektedir (ADR-0006); oturum durumu değişince (çıkış,
///   başka hesapla giriş) yeniden okunur, oturum açık değilken `null`.
/// - Kimlik log'a yazılmaz.
/// - Yalnızca arayüzü sadeleştirmek içindir; bir işlemin yapılıp
///   yapılamayacağına sunucu karar verir (kesin kural 5).
class KendiKimligimNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    if (ref.watch(oturumDurumuProvider) != OturumDurumu.acik) return null;
    return ref.watch(kendiKimligiOkuyucuProvider)();
  }
}

/// Oturum boyunca yaşayan kendi kimliğin (açıkça kalıcı: `autoDispose`
/// değil; ADR-0001 kural 4). Hata otomatik yeniden denenmez; okunamazsa
/// "kendisi" ayrımı yapılmaz ve oturum değişince yeniden denenir.
final kendiKimligimProvider =
    AsyncNotifierProvider<KendiKimligimNotifier, String?>(
      KendiKimligimNotifier.new,
      name: 'kendiKimligimProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
