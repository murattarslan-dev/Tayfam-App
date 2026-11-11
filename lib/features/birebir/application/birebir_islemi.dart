import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';

/// Bir birebir mesaj işlemini çalıştırır. Başarıda `null`, aksi halde
/// gösterilecek hata (metni ortak eşlemeden, ADR-0005 §4). Oturum
/// kapandıysa ([OturumYok]) giriş ekranına dönülür. Hata log'a yazılmaz.
Future<Object?> birebirIslemi(Ref ref, Future<void> Function() islem) async {
  try {
    await islem();
    return null;
  } on OturumYok catch (hata) {
    oturumKapandi(ref);
    return hata;
  } on Exception catch (hata) {
    return hata;
  }
}

/// Oturum kapandıysa ([OturumYok]) giriş ekranına dönülür.
void oturumKapandi(Ref ref) {
  if (!ref.mounted) return;
  ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
}

/// Hata otomatik yeniden denenmez; ekranlar "Tekrar dene" sunar.
Duration? yenidenDenemeYok(int deneme, Object hata) => null;
