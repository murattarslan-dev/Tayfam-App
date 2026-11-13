import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/tayfa/application/tayfa_gorunumu.dart';

/// Yeni tayfanın kurulum dönemi: tayfanın açıldığı andan itibaren 7 gün
/// (Notion: Proje Planı §7, "7 günde 3 üye" temizlik kuralı).
const Duration kurulumDonemi = Duration(days: 7);

/// Temizlik kuralının üye eşiği: ilk 7 günde en az 3 üye.
const int kurulumUyeEsigi = 3;

/// Ana sayfanın saati (kurulum dönemi). Testlerde sabit bir saat verilir.
final tayfaSaatiProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'tayfaSaatiProvider',
);

/// "Tayfanı birlikte kuralım" kartı gösterilsin mi (2026-11-13; ADR-0015
/// Notlar). Yalnızca sunucudan gelen veriden hesaplanır, diske yazılmaz:
///
/// - kullanıcı tayfanın yöneticisi (kurulum adımları yönetici işidir), ve
/// - tayfa kurulum dönemindeyse (`created_at` üzerinden 7 gün geçmemiş) ya
///   da tayfayı bu oturumda kendisi oluşturduysa ([yeniOlusturuldu]).
///
/// Adımların hepsi tamamlanınca kart kendini gizler (bkz. ana sayfa).
/// Rol yalnızca arayüzü sadeleştirir; adımların işlemlerini sunucu
/// yetkilendirir (kesin kural 5).
bool kurulumGosterilsin(
  TayfaOzeti ozet, {
  required DateTime simdi,
  required bool yeniOlusturuldu,
}) {
  final tayfa = ozet.tayfa;
  if (ozet.rol != Role.admin || tayfa == null) return false;
  return yeniOlusturuldu || kurulumDonemindeMi(tayfa, simdi);
}

/// "7 günde 3 üye" kuralının metni gösterilsin mi: yöneticiye, kurulum
/// döneminde ve üye sayısı eşiğin altındayken.
bool kuralGosterilsin(TayfaOzeti ozet, {required DateTime simdi}) {
  final tayfa = ozet.tayfa;
  if (ozet.rol != Role.admin || tayfa == null) return false;
  return kurulumDonemindeMi(tayfa, simdi) &&
      tayfa.memberCount < kurulumUyeEsigi;
}

/// [tayfa] açılalı [kurulumDonemi]'nden az mı oldu.
bool kurulumDonemindeMi(Tayfa tayfa, DateTime simdi) =>
    simdi.toUtc().difference(tayfa.createdAt.toUtc()) < kurulumDonemi;

/// Davet adımı tamam mı: tayfada kurucu dışında en az bir üye var.
bool davetAdimiTamam(Tayfa tayfa) => tayfa.memberCount > 1;
