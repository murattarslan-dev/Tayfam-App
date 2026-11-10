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
