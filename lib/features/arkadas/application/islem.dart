import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';

/// Bir arkadaşlık işlemini çalıştırır. Başarıda `null`, aksi halde
/// gösterilecek hata (metni ortak eşlemeden, ADR-0005 §4). Oturum
/// kapandıysa ([OturumYok]) giriş ekranına dönülür. Hata log'a yazılmaz.
Future<Object?> arkadasIslemi(Ref ref, Future<void> Function() islem) async {
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

