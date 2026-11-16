/// Sözleşmedeki `format: uuid` kimliklerinin biçim denetimi.
///
/// Adresten, derin linkten veya bildirimden gelen bir kimlik girdi kabul
/// edilir (CLAUDE.md, güvenlik ilkesi "Doğrula"). Bu denetim yalnızca biçimi
/// doğrular; kimliğin var olduğunu veya kullanıcının ona erişebildiğini
/// sunucu söyler (kesin kural 5).
library;

final RegExp _uuidBicimi = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// [deger] 8-4-4-4-12 onaltılık biçiminde bir UUID ise `true`.
bool uuidBicimindeMi(String deger) => _uuidBicimi.hasMatch(deger);

/// İki UUID aynı kimlik mi (onaltılık harflerin büyük/küçük farkı yok
/// sayılır). Biçim denetlemez; yalnızca ASCII harfleri katlar (Türkçe
/// harf dönüşümü değildir).
bool ayniKimlik(String a, String b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (_katla(a.codeUnitAt(i)) != _katla(b.codeUnitAt(i))) return false;
  }
  return true;
}

int _katla(int c) => c >= 0x41 && c <= 0x5A ? c + 0x20 : c;
