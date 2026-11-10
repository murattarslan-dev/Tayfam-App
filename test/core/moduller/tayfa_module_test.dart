import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/moduller/tayfa_module.dart';

import '../../yardimcilar.dart';

void main() {
  const etkinlikler = DenemeModulu();
  const duyurular = DenemeModulu(sunucuAnahtari: 'announcements');
  const kayit = <TayfaModule>[etkinlikler, duyurular];

  test('sunucunun bilinmeyen modül anahtarı yok sayılıyor', () {
    final gorunur = gorunurModuller(kayit, [
      'gelecekte_eklenecek_modul',
      'events',
    ]);
    expect(gorunur, [etkinlikler]);
  });

  test('görünür modüller kayıt sırasıyla dönüyor', () {
    final gorunur = gorunurModuller(kayit, ['announcements', 'events']);
    expect(gorunur, [etkinlikler, duyurular]);
  });

  test('sunucu modül göndermezse hiçbir modül görünmüyor', () {
    expect(gorunurModuller(kayit, const []), isEmpty);
  });

  test('gezinme girişinin adresi tayfa kimliğini taşıyor', () {
    expect(
      etkinlikler.gezinmeGirisi.adres(ornekTayfaId),
      '/t/$ornekTayfaId/deneme',
    );
  });
}
