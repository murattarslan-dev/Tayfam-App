import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Bir kullanıcının bilinen adı: görünen ad ya da hesabın silindiği
/// (erişilemediği) bilgisi; profilin oturumdaki kullanıcıya ait olup
/// olmadığı ([ben], sözleşmedeki `UserProfile.self`).
@immutable
final class KullaniciAdi {
  /// Görünen ad.
  const KullaniciAdi(String this.ad, {this.ben = false});

  /// Kullanıcı bulunamadı (hesap silinmiş ya da erişilemiyor).
  const KullaniciAdi.silinmis() : ad = null, ben = false;

  /// Görünen ad; silinmiş kullanıcıda `null`.
  final String? ad;

  /// Profil oturumdaki kullanıcının kendisi (`self`). Yalnızca arayüzü
  /// sadeleştirmek içindir ("Aracını değiştir" gibi); yetki sunucudadır
  /// (kesin kural 5).
  final bool ben;

  /// Kullanıcı silinmiş ya da erişilemiyor.
  bool get silinmis => ad == null;

  @override
  bool operator ==(Object other) =>
      other is KullaniciAdi && other.ad == ad && other.ben == ben;

  @override
  int get hashCode => Object.hash(ad, ben);
}

/// Bir kullanıcının görünen adını (ve kendisi olup olmadığını) sunucudan
/// okur.
typedef ProfilOkuyucu = Future<KullaniciAdi> Function(String kullaniciId);

/// `GET /v1/users/{user_id}/profile` ile görünen ad ve `self`. Testlerde
/// sahtesi verilir.
final profilOkuyucuProvider = Provider<ProfilOkuyucu>((ref) {
  final api = UsersApi(ref.watch(apiClientProvider));
  return (kullaniciId) async {
    final profil = await api.getUserProfile(userId: kullaniciId);
    return KullaniciAdi(profil.displayName, ben: profil.self);
  };
}, name: 'profilOkuyucuProvider');

/// Kullanıcı kimliği → görünen ad önbelleği (ADR-0015 Notlar, 2026-11-11).
///
/// Katılımcı listesi gibi uçlar yalnızca kimlik döndürdüğü için ad profil
/// ucundan okunur:
///
/// - Yalnızca bellektedir (ADR-0006) ve oturum boyunca yaşar; oturum
///   durumu değişince (çıkış, yeni giriş) sıfırlanır.
/// - Ad yalnızca ekrana gelen satır için istenir ([iste]; satır `build`
///   olunca çağrılır).
/// - Aynı kimlik için istekler tek uçuşta birleşir; aynı anda en çok
///   [enCokEszamanli] profil isteği yapılır, gerisi sırada bekler.
/// - Bulunamayan kullanıcı "silinmiş" olarak tutulur; başka hatalar
///   önbelleğe alınmaz, satır yeniden çizilince tekrar istenir.
/// - Adlar log'a yazılmaz.
class KullaniciAdlariNotifier extends Notifier<Map<String, KullaniciAdi>> {
  /// Aynı anda en çok profil isteği.
  static const int enCokEszamanli = 4;

  final Queue<String> _sira = Queue();
  final Set<String> _bekleyen = {};
  int _calisan = 0;
  int _nesil = 0;

  @override
  Map<String, KullaniciAdi> build() {
    // Oturum değişince (çıkış, başka hesapla giriş) önbellek boşalır;
    // eski oturumun süren istekleri sonuç yazmaz.
    ref.watch(oturumDurumuProvider);
    _nesil++;
    _sira.clear();
    _bekleyen.clear();
    _calisan = 0;
    return const {};
  }

  /// Şu an sürmekte olan profil isteği sayısı (testler için).
  @visibleForTesting
  int get calisan => _calisan;

  /// [kullaniciId]'nin adını ister. Biliniyorsa, sıradaysa ya da okunuyorsa
  /// bir şey yapmaz. Durumu hemen değiştirmez; bu yüzden `build` içinden
  /// çağrılabilir.
  void iste(String kullaniciId) {
    if (kullaniciId.isEmpty ||
        state.containsKey(kullaniciId) ||
        !_bekleyen.add(kullaniciId)) {
      return;
    }
    _sira.add(kullaniciId);
    _isle();
  }

  void _isle() {
    while (_calisan < enCokEszamanli && _sira.isNotEmpty) {
      final kullaniciId = _sira.removeFirst();
      _calisan++;
      unawaited(_oku(kullaniciId, _nesil));
    }
  }

  Future<void> _oku(String kullaniciId, int nesil) async {
    KullaniciAdi? sonuc;
    try {
      sonuc = await ref.read(profilOkuyucuProvider)(kullaniciId);
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.userNotFound ||
          problem.type == ProblemType.notFound) {
        sonuc = const KullaniciAdi.silinmis();
      }
    } on Exception {
      // Önbelleğe alınmaz; satır yeniden çizilince tekrar istenir.
    }
    if (!ref.mounted || nesil != _nesil) return;
    _calisan--;
    _bekleyen.remove(kullaniciId);
    if (sonuc != null) state = {...state, kullaniciId: sonuc};
    _isle();
  }
}

/// Oturum boyunca yaşayan ad önbelleği (açıkça kalıcı: `autoDispose`
/// değil; ADR-0001 kural 4).
final kullaniciAdlariProvider =
    NotifierProvider<KullaniciAdlariNotifier, Map<String, KullaniciAdi>>(
      KullaniciAdlariNotifier.new,
      name: 'kullaniciAdlariProvider',
    );

/// [kullaniciId] oturumdaki kullanıcının kendisi mi (profilin `self`
/// alanı). Bilinmiyorsa profil istenir ve gelene kadar `false` döner.
///
/// Yalnızca arayüzü sadeleştirmek içindir (ör. kendi aracında "Değiştir");
/// bir işlemin yapılıp yapılamayacağına sunucu karar verir (kesin kural 5).
final kendisiMiProvider = Provider.autoDispose.family<bool, String>((
  ref,
  kullaniciId,
) {
  ref.read(kullaniciAdlariProvider.notifier).iste(kullaniciId);
  return ref.watch(
    kullaniciAdlariProvider.select((adlar) => adlar[kullaniciId]?.ben ?? false),
  );
}, name: 'kendisiMiProvider');
