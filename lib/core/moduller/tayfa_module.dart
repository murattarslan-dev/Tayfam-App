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

  /// Tayfa ana sayfasında, mor üst bölümün altında gösterilen bölüm
  /// (ADR-0015 §1). Kayıt sırasıyla gösterilir.
  Widget anaSayfaKarti(BuildContext context, String tayfaId);

  /// Ana sayfa aşağı çekilince bölümün verisini yeniden okur. Dönen
  /// `Future` yenileme bitince tamamlanır; hata fırlatmaz (hata bölümde
  /// gösterilir).
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId);
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
