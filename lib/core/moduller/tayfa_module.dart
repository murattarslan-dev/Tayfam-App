import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Tayfa başına açılıp kapanan bir modül (ADR-0002): `announcements`,
/// `events`, `qa`, `polls`. Sohbet ve tayfa yönetimi modül değildir.
///
/// Modülü görünür yapan sunucudan gelen `modules` alanıdır
/// ([gorunurModuller]); istemcinin gizlemesi yetki değildir ve
/// `module-disabled` cevabı her zaman ele alınır (CLAUDE.md, kesin kural 5).
abstract interface class TayfaModule {
  /// Sözleşmedeki `Module` değeri (ör. `events`).
  String get sunucuAnahtari;

  /// Modülün rotaları. Göreli yollardır ve `/t/:tayfaId` rotasının altına
  /// eklenir; böylece her modül adresi tayfa kimliğini taşır ve Tayfa
  /// sekmesinin geçmişinde kalır.
  List<RouteBase> get rotalar;

  /// Tayfa ana sayfasında gösterilen bölüm (ADR-0015 §1, Notlar
  /// 2026-11-13): başlık, kısa içerik ve "Tümü" bağlantısı. Kayıt sırasıyla
  /// gösterilir. Boş bölümde kısa bir boş durum metni vardır; oluşturma
  /// kısayolları bölümde değil, "Oluştur" sayfasındadır
  /// ([olusturmaSecenegi]).
  Widget anaSayfaKarti(BuildContext context, String tayfaId);

  /// Mor üst bölüme taşan öne çıkan kart (etkinlik modülünde "Sıradaki"
  /// etkinlik); modülün böyle bir kartı yoksa `null`. Gösterecek bir şey
  /// yokken kart kendini boş (sıfır yükseklik) çizer.
  Widget? anaSayfaOneCikan(BuildContext context, String tayfaId);

  /// Ana sayfadaki "Oluştur" sayfasında modülün seçeneği ("Etkinlik aç",
  /// "Duyuru yaz" …); modül bir şey oluşturmuyorsa `null`.
  OlusturmaSecenegi? get olusturmaSecenegi;

  /// Yeni kurulan tayfanın "Tayfanı birlikte kuralım" kartındaki adımı
  /// ("İlk etkinliği aç", "Bir duyuru sabitle"); yoksa `null`.
  KurulumAdimi? get kurulumAdimi;

  /// Ana sayfa aşağı çekilince bölümün verisini yeniden okur. Dönen
  /// `Future` yenileme bitince tamamlanır; hata fırlatmaz (hata bölümde
  /// gösterilir).
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId);
}

/// Kullanıcının bir tayfadaki rolü ve tayfanın izinleri: "Oluştur"
/// sayfasındaki seçenekleri sadeleştirmek için. Yetki kararı değildir;
/// işlemi sunucu yetkilendirir (CLAUDE.md, kesin kural 5).
@immutable
final class TayfaYetkisi {
  const TayfaYetkisi({this.rol, this.uyelerEtkinlikAcabilir = false});

  /// Kullanıcının rolü; bilinmiyorsa `null`.
  final Role? rol;

  /// Tayfanın `members_can_create_events` ayarı.
  final bool uyelerEtkinlikAcabilir;

  /// Moderatör ya da yönetici.
  bool get yonetimde => rol == Role.moderator || rol == Role.admin;
}

/// "Oluştur" sayfasındaki bir modül seçeneği (tasarım: Ana-Yonetici).
@immutable
class OlusturmaSecenegi {
  const OlusturmaSecenegi({
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    required this.izinli,
    required this.ac,
  });

  /// Seçeneğin ikonu; yanında her zaman [baslik] gösterilir.
  final IconData ikon;

  /// Çeviri dosyasından gelen başlık ("Etkinlik aç").
  final String Function(BuildContext context) baslik;

  /// Çeviri dosyasından gelen kısa açıklama ("Konvoy, kamp, maç…").
  final String Function(BuildContext context) aciklama;

  /// Seçenek bu kullanıcıya gösterilsin mi. Yalnızca sadeleştirir; sunucu
  /// izin vermezse `permission-denied` gösterilir.
  final bool Function(TayfaYetkisi yetki) izinli;

  /// Oluşturma akışını açar.
  final void Function(BuildContext context, String tayfaId) ac;
}

/// Yeni kurulan tayfanın kurulum adımı (tasarım: Ana-Yeni-Tayfa).
@immutable
class KurulumAdimi {
  const KurulumAdimi({
    required this.baslik,
    required this.aciklama,
    required this.tamamMi,
    required this.ac,
  });

  /// Çeviri dosyasından gelen başlık ("İlk etkinliği aç").
  final String Function(BuildContext context) baslik;

  /// Çeviri dosyasından gelen açıklama.
  final String Function(BuildContext context) aciklama;

  /// Adım tamam mı; yalnızca sunucudan gelen veriden hesaplanır (ör. en az
  /// bir yaklaşan etkinlik var), diske yazılmaz. Veri henüz yoksa `null`.
  /// Ana sayfanın `build`'inde çağrılır; [ref] ile izleyebilir.
  final bool? Function(WidgetRef ref, String tayfaId) tamamMi;

  /// Adımın akışını açar.
  final void Function(BuildContext context, String tayfaId) ac;
}

/// [kayit]'taki modüllerden sunucunun açık dediği ([sunucuModulleri])
/// olanları kayıt sırasıyla döndürür.
///
/// Sunucunun bizim bilmediğimiz bir modül anahtarı göndermesi hata
/// değildir; o anahtar yok sayılır (ADR-0002).
List<TayfaModule> gorunurModuller(
  List<TayfaModule> kayit,
  Iterable<String> sunucuModulleri,
) {
  final acik = sunucuModulleri.toSet();
  return [
    for (final modul in kayit)
      if (acik.contains(modul.sunucuAnahtari)) modul,
  ];
}

/// Sunucunun `modules` alanında açık (`true`) olan modüllerin anahtarları.
/// Alanı olmayan ya da `false` olan modül kapalı sayılır; istemci kapalı
/// modülü gizler, yetki yine sunucudadır (kesin kural 5).
Set<String> acikModulAnahtarlari(TayfaModules moduller) => {
  if (moduller.announcements == true) Module.announcements.wire,
  if (moduller.events == true) Module.events.wire,
  if (moduller.qa == true) Module.qa.wire,
  if (moduller.polls == true) Module.polls.wire,
};

/// Uygulamaya kayıtlı tayfa modülleri.
///
/// Liste `shell/kayitlar.dart`'ta tutulur ve uygulamanın kökünde bu
/// provider'a verilir; `core/` `shell/`'i import edemediği için
/// varsayılan değer boş listedir. Testler kendi modüllerini override ile
/// verir (ADR-0001, kural 7).
final tayfaModulleriProvider = Provider<List<TayfaModule>>(
  (ref) => const [],
  name: 'tayfaModulleriProvider',
);
