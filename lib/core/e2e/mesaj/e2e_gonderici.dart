import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/direct_messages_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/mesaj/dolgu.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_oturumlari.dart';

/// Uçtan uca şifreli birebir mesaj gönderimi (ADR-0020 "Gönderim").
///
/// 1. Alıcının ve kendi diğer cihazlarımızın listesi (bellek önbelleği).
/// 2. Oturumu olmayan cihazlar için ön anahtar paketi çekilir.
/// 3. Her cihaz için adres kilidi altında şifrelenir, oturum depoya yazılır.
/// 4. `POST /v1/direct-messages` (`envelopes`), yalnızca REST.
/// 5. `e2e-devices-changed`: listeler tazelenir (eskimiş cihazların
///    oturumu silinir, eksikler için paket çekilir) ve **aynı**
///    `client_request_id` ile en çok [enCokTekrar] kez yeniden denenir.
///
/// Düz metin yalnızca bellektedir; şifreleme gönderim anında yapılır
/// (çevrimdışı kuyruk düz metni bellekte tutar).
final class E2eGonderici {
  E2eGonderici({
    required this.oturumlar,
    required ApiTransport api,
    required this.kullaniciKimligi,
    required this.cihazKimligi,
    this.yayin,
  }) : _api = DirectMessagesApi(api);

  /// `e2e-devices-changed` sonrası en çok yeniden deneme.
  static const int enCokTekrar = 3;

  final E2eOturumlari oturumlar;
  final DirectMessagesApi _api;

  /// Oturumun kullanıcı kimliği.
  final Future<String> Function() kullaniciKimligi;

  /// Bu cihazın sunucudaki kimliği; kayıtlı değilse `null`.
  final String? Function() cihazKimligi;

  /// Gönderilen mesajın geçmiş arşivine yazılması için yayın (E3).
  final E2eMesajYayini? yayin;

  /// [aliciId]'ye [metin]'i şifreli gönderir. Başarıda sunucunun yazdığı
  /// mesaj ve gönderilen içerik döner.
  Future<(DirectMessageSent, CozulmusBirebirMesaj)> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) async {
    final benId = await kullaniciKimligi();
    final kendi = cihazKimligi();
    if (kendi == null) throw const E2eHazirDegil();
    final duz = zarfIcerigiKodla(metin);
    var tazele = false;
    for (var deneme = 0; ; deneme++) {
      final alicilar = await oturumlar.cihazlar(aliciId, tazele: tazele);
      if (alicilar.isEmpty) {
        throw const ApiProblem(
          type: ProblemType.e2eRecipientUnavailable,
          status: 409,
        );
      }
      final benimkiler = await oturumlar.cihazlar(benId, tazele: tazele);
      final hedefler = <ZarfHedefi>[
        for (final c in alicilar) (kullaniciId: aliciId, cihaz: c),
        for (final c in benimkiler)
          if (c.id != kendi) (kullaniciId: benId, cihaz: c),
      ];
      await oturumlar.oturumlariKur(hedefler);
      final zarflar = <OutgoingEnvelope>[
        for (final h in hedefler) await oturumlar.sifrele(h, duz),
      ];
      try {
        final sonuc = await _api.sendDirectMessage(
          body: DirectMessageCreateRequest(
            recipientUserId: aliciId,
            envelopes: zarflar,
            clientRequestId: istekKimligi,
          ),
        );
        final icerik = CozulmusBirebirMesaj(
          mesajId: sonuc.message.id,
          konusmaId: sonuc.message.conversationId,
          gonderenKullaniciId: benId,
          metin: metin,
          olusturma: sonuc.message.createdAt,
          kaynak: CozulmusMesajKaynagi.gonderildi,
        );
        yayin?.yay(icerik);
        return (sonuc, icerik);
      } on ApiProblem catch (hata) {
        if (hata.type != ProblemType.e2eDevicesChanged ||
            deneme >= enCokTekrar) {
          rethrow;
        }
        tazele = true;
      }
    }
  }
}
