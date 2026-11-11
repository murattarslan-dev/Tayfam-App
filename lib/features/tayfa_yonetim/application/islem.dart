import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Bir yönetim işlemini çalıştırır. Başarıda `null`, aksi halde
/// gösterilecek hata (metni ortak eşlemeden, ADR-0005 §4). Oturum
/// kapandıysa ([OturumYok]) giriş ekranına dönülür. Hata log'a yazılmaz.
Future<Object?> yonetimIslemi(Ref ref, Future<void> Function() islem) async {
  try {
    await islem();
    return null;
  } on OturumYok catch (hata) {
    if (ref.mounted) {
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
    }
    return hata;
  } on Exception catch (hata) {
    return hata;
  }
}

/// Hata otomatik yeniden denenmez; ekranlar "Tekrar dene" sunar.
Duration? yenidenDenemeYok(int deneme, Object hata) => null;

/// Açıksa tayfanın tam görünümünü (ad, üye sayısı, modüller, kod, silinme
/// zamanı) sunucudan yeniden okur. Ayarlar ekranları tayfa ana sayfasının
/// altında açıldığı için görünüm genellikle açıktır.
Future<void> gorunumuYenile(Ref ref, String tayfaId) async {
  final gorunum = tayfaGorunumuProvider(tayfaId);
  if (!ref.mounted || !ref.read(gorunum.exists)) return;
  await ref.read(gorunum.notifier).yenile();
}
