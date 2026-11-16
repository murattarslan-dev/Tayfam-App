import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/features/sikayet/application/moderasyon_kuyrugu.dart';
import 'package:tayfam/features/sikayet/application/sikayet_formu.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';

import '../../core/medya/sahteler.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const String _kanitId = '7d0e8c4a-5b6f-4a1e-9c3d-2f1a0b9e8d7c';
const String _kanalId = '3c4d5e6f-0000-4000-8000-00000000c0a1';
const String _kanalMesajId = '3c4d5e6f-0000-4000-8000-00000000c0a2';
const String _mesajSilYolu =
    '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages/{message_id}';

void _yuklemeYanitlari(SahteTayfaTasima t) {
  t.yanitlar['POST /v1/uploads'] = (istek) {
    final v =
        (istek.govde! as Map<String, Object?>)['variants']! as List<Object?>;
    int boyut(int i) => (v[i]! as Map<String, Object?>)['size_bytes']! as int;
    return yuklemeAcildiJson(
      id: _kanitId,
      onizlemeBoyutu: boyut(0),
      tamBoyutu: boyut(1),
    );
  };
  t.yanitlar['POST /v1/uploads/{upload_id}/complete'] = (_) => {
    'upload': yuklemeJson(id: _kanitId),
  };
}

/// Kodlayıcının tanıdığı kaynak (şikâyet edilen görüntü).
final _foto = ornekJpeg();

List<Override> _overridelar(SahteTayfaTasima t) {
  final k = _foto;
  return [
    ...sikayetOverridelari(t),
    ...medyaOverridelari(
      tasima: t,
      kodlayici: SahteKodlayici(
        kaynak: k,
        kaynakOlcusu: const JpegOlculeri(1600, 1200),
      ),
    ),
  ];
}

void main() {
  group('birebir fotoğraf kanıtı (Tayfam-Api ADR-0031 §6)', () {
    test('fotoğraf report_evidence olarak yüklenir, şikâyet '
        'evidence_upload_id ile gider; tekrarda yeniden yüklenmez', () async {
      final t = SahteTayfaTasima();
      _yuklemeYanitlari(t);
      var deneme = 0;
      t.yanitlar['POST $benimSikayetlerimYolu'] = (_) {
        if (deneme++ == 0) throw Exception('ağ');
        return benimSikayetimJson(
          tur: 'dm_message',
          hedef: mesajId,
          tayfa: null,
        );
      };
      final kap = ProviderContainer.test(overrides: _overridelar(t));
      final hedef = SikayetHedefi.birebirMesaj(
        id: mesajId,
        kanitFotografi: _foto,
      );
      final saglayici = sikayetFormuProvider(hedef);
      kap.listen(saglayici, (_, _) {});
      expect(
        await kap
            .read(saglayici.notifier)
            .gonder(ReportReason.sexualContent, ''),
        isFalse,
      );
      expect(
        await kap
            .read(saglayici.notifier)
            .gonder(ReportReason.sexualContent, ''),
        isTrue,
      );
      final yukleme = t.giden('POST', '/v1/uploads');
      expect(yukleme, hasLength(1));
      final ac = yukleme.single.govde! as Map<String, Object?>;
      expect(ac['purpose'], 'report_evidence');
      expect(ac.containsKey('tayfa_id'), isFalse);
      expect(t.giden('POST', benimSikayetlerimYolu).last.govde, {
        'target_type': 'dm_message',
        'target_id': mesajId,
        'reason': 'sexual_content',
        'evidence_upload_id': _kanitId,
      });
    });

    testWidgets('şikâyet sayfası iletilecek fotoğrafı gösterir (koyu, 2×)', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      ikiKatYazi(tester);
      final t = SahteTayfaTasima();
      await widgetAc(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => birebirMesajiSikayetEt(
                context,
                mesajId: mesajId,
                fotograf: _foto,
              ),
              child: const Text('ac'),
            ),
          ),
        ),
        themeMode: ThemeMode.dark,
        tayfa: _overridelar(t),
      );
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
      expect(
        find.text(arbMetni('sikayet_fotograf_iletilecek')),
        findsOneWidget,
      );
      expect(find.text(arbMetni('sikayet_fotograf_aciklama')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('kanal mesajı şikâyeti', () {
    test('tayfa ucuna channel_message olarak gider', () async {
      final t = SahteTayfaTasima({
        'POST $sikayetlerYolu': yanit(
          benimSikayetimJson(tur: 'channel_message', hedef: _kanalMesajId),
        ),
      });
      final kap = ProviderContainer.test(overrides: sikayetOverridelari(t));
      const hedef = SikayetHedefi.tayfada(
        tayfaId: ornekTayfaId,
        tur: ReportTargetType.channelMessage,
        id: _kanalMesajId,
      );
      final saglayici = sikayetFormuProvider(hedef);
      kap.listen(saglayici, (_, _) {});
      await kap.read(saglayici.notifier).gonder(ReportReason.spam, '');
      expect(t.giden('POST', sikayetlerYolu).single.govde, {
        'target_type': 'channel_message',
        'target_id': _kanalMesajId,
        'reason': 'spam',
      });
    });

    test('kuyrukta kaldırma kanal mesajını gizler (channel_id ile)', () async {
      final t = SahteTayfaTasima({
        'GET $sikayetlerYolu': yanit(
          kuyrukJson([
            {
              ...kuyrukSikayetiJson(
                tur: 'channel_message',
                hedef: _kanalMesajId,
              ),
              'channel_id': _kanalId,
            },
          ]),
        ),
        'DELETE $_mesajSilYolu': yanit(null),
        'POST $cozumYolu': yanit(
          kuyrukSikayetiJson(durum: 'resolved', sonuc: 'content_removed'),
        ),
      });
      final kap = ProviderContainer.test(overrides: sikayetOverridelari(t));
      final saglayici = moderasyonKuyruguProvider((
        tayfaId: ornekTayfaId,
        acik: true,
      ));
      kap.listen(saglayici, (_, _) {});
      final liste = await kap.read(saglayici.future);
      expect(icerigeErisilebilir(liste.ogeler.single), isTrue);
      expect(
        await kap
            .read(saglayici.notifier)
            .kaldirVeSonuclandir(liste.ogeler.single),
        isNull,
      );
      final sil = t.giden('DELETE', _mesajSilYolu).single;
      expect(sil.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'channel_id': _kanalId,
        'message_id': _kanalMesajId,
      });
    });

    test('channel_id yoksa (kanalı okuyamayan moderatör) içeriğe '
        'dokunulamaz', () {
      final s = ModerationReport.fromJson(
        kuyrukSikayetiJson(tur: 'channel_message', hedef: _kanalMesajId),
      );
      expect(icerigeErisilebilir(s), isFalse);
    });
  });
}
