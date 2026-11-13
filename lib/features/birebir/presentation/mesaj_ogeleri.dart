import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/giden_mesaj.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Akıştaki bir birebir mesaj (2026-11-13 tasarım: Birebir-Konusma):
/// sohbet balonu (kendi mesajın sağda mor; gelen kart zemin + kenar);
/// silinmişse "Bu mesaj silindi". Birebirde ad ve avatar yoktur. Aynı
/// yazarın ardışık mesajlarında yalnızca grubun son balonunun kuyruğu
/// vardır ve saat ([saat]) onun altındadır. Karşı taraf okuduysa son kendi
/// mesajın altında "Görüldü" (ADR-0020).
///
/// [metin] gösterilecek içeriktir: bellekte çözülmüş içerik ya da yer
/// tutucu metin.
///
/// Uzun basınca [onIslemler] çağrılır (sil, şikâyet et); işlem yoksa
/// `null` verilir. Metin yalnızca ekrandadır; hiçbir yere yazılmaz.
class MesajOgesi extends StatelessWidget {
  const MesajOgesi({
    super.key,
    required this.mesaj,
    required this.giden,
    this.metin,
    this.goruldu = false,
    this.kuyruk = true,
    this.grupBasi = true,
    this.saat,
    this.onIslemler,
  });

  final DirectMessage mesaj;

  /// Balondaki metin; `null` ya da mesaj silinmişse "Bu mesaj silindi".
  final String? metin;

  /// Kullanıcının kendi mesajı.
  final bool giden;

  /// Son kendi mesajın ve karşı taraf okudu.
  final bool goruldu;

  /// Grubun son balonu (kuyruklu).
  final bool kuyruk;

  /// Grubun ilk balonu (üstte daha geniş boşluk).
  final bool grupBasi;

  /// Grubun sonunda balonun altındaki saat ("14:32").
  final String? saat;

  final VoidCallback? onIslemler;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final govde = metin;
    final silinmis = govde == null || mesaj.deleted;
    final balon = SohbetBalonu(
      metin: govde == null || mesaj.deleted ? m.birebir_mesaj_silindi : govde,
      giden: giden,
      tur: silinmis ? BalonTuru.silinmis : BalonTuru.akis,
      kuyruk: kuyruk,
    );
    final saat = this.saat;
    return Padding(
      padding: EdgeInsets.only(
        top: grupBasi ? TayfamSpacing.s12 : TayfamSpacing.s4,
      ),
      child: Column(
        crossAxisAlignment: giden
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (onIslemler case final islemler?)
            Semantics(
              onLongPressHint: m.birebir_mesaj_islemleri,
              child: GestureDetector(onLongPress: islemler, child: balon),
            )
          else
            balon,
          if (saat != null || goruldu)
            MesajAltSatiri(
              children: [
                if (saat != null) Text(saat),
                if (goruldu) Text(m.birebir_goruldu),
              ],
            ),
        ],
      ),
    );
  }
}

/// Sunucu henüz kabul etmemiş giden mesaj (ADR-0006): gönderilirken saat
/// ikonuyla "Gönderiliyor"; gönderilemediyse nar kenarlı balon, hata metni,
/// "Tekrar dene" (aynı `client_request_id`) ve "Sil".
class GidenOgesi extends StatelessWidget {
  const GidenOgesi({
    super.key,
    required this.giden,
    required this.onTekrarDene,
    required this.onSil,
  });

  final GidenMesaj giden;

  final VoidCallback onTekrarDene;

  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final basarisiz = giden.durum == GidenDurumu.basarisiz;
    final hata = giden.hata;
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SohbetBalonu(
            metin: giden.metin,
            giden: true,
            tur: basarisiz ? BalonTuru.gonderilemedi : BalonTuru.akis,
          ),
          if (basarisiz) ...[
            if (hata != null)
              Padding(
                padding: const EdgeInsets.only(top: TayfamSpacing.s4),
                child: HataSatiri.hatadan(hata),
              ),
            GonderilemediSatiri(
              durum: m.birebir_gonderilemedi,
              tekrarDene: m.birebir_tekrar_dene,
              sil: m.birebir_bekleyeni_sil,
              onTekrarDene: onTekrarDene,
              onSil: onSil,
            ),
          ] else
            MesajAltSatiri(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.schedule,
                    size: TayfamSizes.ikonKucuk,
                    color: r.metinIkincil,
                  ),
                ),
                Text(m.birebir_gonderiliyor),
              ],
            ),
        ],
      ),
    );
  }
}
