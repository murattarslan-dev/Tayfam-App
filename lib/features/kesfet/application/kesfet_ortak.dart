import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';

/// Bir etkinliğin kimliği (tayfa + etkinlik); `family` anahtarı.
typedef KesfetEtkinligi = ({String tayfaId, String etkinlikId});

/// [hata] sunucunun "özellik kapalı" cevabı mı (`404 feature-disabled`;
/// Tayfam-Api ADR-0033 §1). İstemci bayrağı ayrıca sormaz; ilgili ucun
/// cevabına bakar ve girişi gizler (ADR-0027 §2). Bu bir yetki kararı
/// değildir: sunucu kapalı özelliği zaten çalıştırmaz.
bool ozellikKapali(Object? hata) =>
    hata is ApiProblem && hata.type == ProblemType.featureDisabled;

/// [hata] belirtilen [tur]'de bir sunucu cevabı mı.
bool problemMi(Object? hata, ProblemType tur) =>
    hata is ApiProblem && hata.type == tur;

/// Bir işlemi çalıştırır. Başarıda `null`, aksi halde gösterilecek hata
/// (metni ortak eşlemeden, ADR-0005 §4). Oturum kapandıysa ([OturumYok])
/// giriş ekranına dönülür. Hata log'a yazılmaz (kesin kural 3).
Future<Object?> kesfetIslemi(Ref ref, Future<void> Function() islem) async {
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

/// Oturum açık değilse okuma yapılmaz.
void oturumuDenetle(Ref ref) {
  if (ref.watch(oturumDurumuProvider) != OturumDurumu.acik) {
    throw const OturumYok();
  }
}

/// Hata otomatik yeniden denenmez; ekranlar "Tekrar dene" sunar.
Duration? yenidenDenemeYok(int deneme, Object hata) => null;
