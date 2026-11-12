import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/shell/derin_link/davet_notifier.dart';
import 'package:tayfam/shell/derin_link/derin_link_kutusu.dart';

/// Kayıttan hemen sonra bekleyen daveti mevcut davet akışıyla
/// ([DavetNotifier]: önizleme `POST /v1/invite-previews`, katılım
/// `POST /v1/invite-joins`) işler; hoş geldin ekranı sonucu gösterir
/// (ADR-0012 §3, ADR-0018 §6).
///
/// - Bekleyen davet yoksa `null` (linksiz gelen kullanıcı).
/// - Zaten üyeyse istek gönderilmez, davet bırakılır.
/// - Önizleme ya da katılım hata verirse davet kutuda kalır; hoş geldin
///   ekranı kullanıcıyı ayrıntıyı ve "Tekrar dene"yi gösteren davet
///   ekranına yönlendirir.
///
/// Token yalnızca kutudadır; burada tutulmaz, loglanmaz (kesin kural 9).
class KabukKayitDavetNotifier extends KayitDavetNotifier {
  @override
  Future<KayitDavetSonucu?> build() async {
    final kutu = ref.read(derinLinkKutusuProvider);
    if (!kutu.davetBekliyor) return null;
    // Davet akışı ekran açıkken yaşasın (autoDispose).
    ref.listen(davetProvider, (_, _) {});
    final onizleme = (await ref.read(davetProvider.future)).onizleme;
    if (onizleme.alreadyMember) {
      kutu.davetiBirak();
      return KayitDavetSonucu(
        durum: KayitDavetDurumu.zatenUye,
        tayfaAdi: onizleme.name,
      );
    }
    await ref.read(davetProvider.notifier).katil();
    final son = ref.read(davetProvider).value;
    switch (son?.sonuc) {
      case DavetSonucu.etkin:
        return KayitDavetSonucu(
          durum: KayitDavetDurumu.etkin,
          tayfaAdi: onizleme.name,
          tayfaId: son?.tayfaId,
        );
      case DavetSonucu.bekliyor:
        return KayitDavetSonucu(
          durum: KayitDavetDurumu.bekliyor,
          tayfaAdi: onizleme.name,
        );
      case null:
        throw son?.hata ?? const DavetYok();
    }
  }
}
