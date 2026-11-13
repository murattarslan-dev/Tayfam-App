import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/tayfa/application/kurulum.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

/// 2026-11-01T10:00Z'de açılmış tayfa (sahte JSON'un `created_at`'i).
TayfaOzeti _ozet({String rol = 'admin', int uyeSayisi = 1}) {
  final tayfa = Tayfa.fromJson(
    tayfaJson(id: ornekTayfaId, uyeSayisi: uyeSayisi),
  );
  return TayfaOzeti(ad: tayfa.name, tayfa: tayfa, rol: Role.fromWire(rol));
}

void main() {
  final ucGunSonra = DateTime.utc(2026, 11, 4);
  final sekizGunSonra = DateTime.utc(2026, 11, 9);

  group('kurulum kartı (ADR-0015 Notlar 2026-11-13)', () {
    test('yöneticiye kurulum döneminde', () {
      expect(
        kurulumGosterilsin(_ozet(), simdi: ucGunSonra, yeniOlusturuldu: false),
        isTrue,
      );
    });

    test('dönem bitince yalnızca bu oturumda oluşturulduysa', () {
      expect(
        kurulumGosterilsin(
          _ozet(),
          simdi: sekizGunSonra,
          yeniOlusturuldu: false,
        ),
        isFalse,
      );
      expect(
        kurulumGosterilsin(
          _ozet(),
          simdi: sekizGunSonra,
          yeniOlusturuldu: true,
        ),
        isTrue,
      );
    });

    test('moderatöre ve üyeye yok', () {
      for (final rol in ['moderator', 'member']) {
        expect(
          kurulumGosterilsin(
            _ozet(rol: rol),
            simdi: ucGunSonra,
            yeniOlusturuldu: true,
          ),
          isFalse,
          reason: rol,
        );
      }
    });

    test('tayfa bilinmiyorsa yok', () {
      expect(
        kurulumGosterilsin(
          const TayfaOzeti(rol: Role.admin),
          simdi: ucGunSonra,
          yeniOlusturuldu: true,
        ),
        isFalse,
      );
    });
  });

  group('7 günde 3 üye kuralı', () {
    test('dönemde ve 3 üyenin altında', () {
      expect(kuralGosterilsin(_ozet(uyeSayisi: 2), simdi: ucGunSonra), isTrue);
      expect(kuralGosterilsin(_ozet(uyeSayisi: 3), simdi: ucGunSonra), isFalse);
      expect(
        kuralGosterilsin(_ozet(uyeSayisi: 1), simdi: sekizGunSonra),
        isFalse,
      );
      expect(
        kuralGosterilsin(_ozet(rol: 'member', uyeSayisi: 1), simdi: ucGunSonra),
        isFalse,
      );
    });
  });

  test('davet adımı kurucu dışında üye olunca tamam', () {
    final tek = Tayfa.fromJson(tayfaJson(id: ornekTayfaId, uyeSayisi: 1));
    final iki = Tayfa.fromJson(tayfaJson(id: ornekTayfaId, uyeSayisi: 2));
    expect(davetAdimiTamam(tek), isFalse);
    expect(davetAdimiTamam(iki), isTrue);
  });
}
