import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/liste/liste_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/liste/madde_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart'
    show ozetAyraci;
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Liste bileşeni (`checklist`; Tayfam-Api ADR-0025 §4, ADR-0037, #241;
/// App ADR-0024 §3): kim ne getiriyor, hangi görevi, bölümü ya da nöbeti
/// alıyor. Bir etkinlikte birden çok liste olabilir (tanımdaki `key`:
/// `gear`, `duty` …); kampın Faz 1 malzeme listesi `gear` anahtarlı
/// listedir.
///
/// Maddeyi organizatör, moderatör ve yönetici ekler ve çıkarır
/// (`caller_can_manage`); bileşenin `assignment` parametresi açıksa
/// "Geliyorum" diyen üye boştaki maddeyi üstlenir (`caller_can_take`).
/// Liste etkinlik bitince kapanır. Düğmeleri gizlemek kolaylıktır; yetkiyi
/// sunucu verir, hatası her durumda gösterilir (kesin kural 5).
///
/// Maddeler etkinlik oluşturulurken yazılmaz; sihirbazda form bölümü
/// yoktur.
final class ListeBileseni extends KayitliBilesen {
  const ListeBileseni() : super('checklist');

  @override
  String ad(AppLocalizations m) => m.bilesen_checklist_ad;

  @override
  Widget? detayBolumu(BilesenBaglami b) {
    final tayfaId = b.tayfaId;
    final etkinlik = b.etkinlik;
    if (tayfaId == null || etkinlik == null) return null;
    return ListeBolumu(
      kimlik: (tayfaId: tayfaId, etkinlikId: etkinlik.id, anahtar: b.anahtar),
      tanim: b.tanim,
      etkinlik: etkinlik,
    );
  }
}

/// Bir liste işlemi: bileşenin durumunda çalışır, hatayı döndürür.
typedef ListeIslemi = Future<Object?> Function(ListeNotifier liste);

/// Liste bileşeninin detaydaki bölümü: başlık, maddeler ve "Malzeme
/// ekle". Okunurken yer tutmaz; okunamazsa kısa hata ve "Tekrar dene".
class ListeBolumu extends ConsumerStatefulWidget {
  const ListeBolumu({
    super.key,
    required this.kimlik,
    required this.tanim,
    required this.etkinlik,
  });

  final ListeKimligi kimlik;

  /// Bileşenin tür tanımındaki kaydı (katalogdaki adı için).
  final CatalogComponent tanim;

  final Event etkinlik;

  @override
  ConsumerState<ListeBolumu> createState() => _ListeBolumuState();
}

class _ListeBolumuState extends ConsumerState<ListeBolumu> {
  bool _mesgul = false;

  ListeNotifier get _notifier =>
      ref.read(listeProvider(widget.kimlik).notifier);

  /// [islem]'i çalıştırır; hatada kısa bildirim gösterir (`event-item-taken`
  /// gibi bayat liste hatalarında liste ayrıca yeniden okunur). Aynı anda
  /// tek işlem yapılır.
  Future<void> _calistir(ListeIslemi islem) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final hata = await islem(_notifier);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (hata != null) hataBildir(context, hata);
  }

  Future<void> _ekle(Checklist liste) => aracFormuAc<void>(
    context,
    (_) => MaddeFormu(
      kimlik: widget.kimlik,
      etiket: listeEtiketi(liste),
      adetAcik: liste.quantityEnabled,
      atamaAcik: liste.assignmentEnabled,
      gonder: (istek) => _notifier.ekle(istek),
    ),
  );

  Future<void> _cikar(ChecklistItem madde) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_checklist_cikar_onay,
    );
    if (!onay || !mounted) return;
    await _calistir((l) => l.cikar(madde.id));
  }

  Future<void> _atamayiKaldir(ChecklistItem madde) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.bilesen_checklist_atamayi_kaldir_onay,
      eylem: m.bilesen_checklist_atamayi_kaldir,
    );
    if (!onay || !mounted) return;
    await _calistir((l) => l.ata(madde.id, null));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final okunan = ref.watch(listeProvider(widget.kimlik));
    final liste = okunan.value;
    final maddeler = liste?.items ?? const <ChecklistItem>[];
    final ustlenilen = maddeler.where((d) => d.assignedUserId != null).length;
    final baslik = AracBasligi(
      metin:
          katalogAdi(widget.tanim.labels, katalogDili(context)) ??
          m.bilesen_checklist_ad,
      sag: liste == null || !liste.assignmentEnabled || maddeler.isEmpty
          ? null
          : AracBasligiNotu(
              metin: m.bilesen_checklist_ustlenilen(
                ustlenilen,
                maddeler.length,
              ),
            ),
    );
    if (liste == null) {
      if (!okunan.hasError) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          baslik,
          HataSatiri.hatadan(okunan.error!),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BaglantiEylemi(
              etiket: m.etkinlik_tekrar_dene,
              onPressed: () => unawaited(_notifier.yenile()),
            ),
          ),
        ],
      );
    }
    final etkinlik = widget.etkinlik;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final etiket = listeEtiketi(liste);
    final bitti = !iptalEdildi(etkinlik) && !simdi.isBefore(etkinlik.endsAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        baslik,
        AracListesi(
          bos: m.bilesen_checklist_yok,
          satirlar: [
            for (final madde in maddeler)
              MaddeSatiri(
                key: ValueKey(madde.id),
                madde: madde,
                liste: liste,
                mesgul: _mesgul,
                onAta: (kullaniciId) =>
                    unawaited(_calistir((l) => l.ata(madde.id, kullaniciId))),
                onAtamayiKaldir: () => unawaited(_atamayiKaldir(madde)),
                onCikar: () => unawaited(_cikar(madde)),
              ),
          ],
        ),
        if (liste.callerCanManage) ...[
          const SizedBox(height: TayfamSpacing.s12),
          AracDugmesi(
            etiket: m.bilesen_checklist_ekle(etiket),
            ikon: Icons.add,
            onPressed: _mesgul ? null : () => unawaited(_ekle(liste)),
          ),
        ] else if (bitti) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_checklist_kapandi),
        ] else if (liste.assignmentEnabled &&
            !liste.callerCanTake &&
            etkinlik.callerRsvp != RsvpStatus.going &&
            katilimAcik(etkinlik, simdi)) ...[
          const SizedBox(height: TayfamSpacing.s8),
          AracBilgisi(metin: m.bilesen_checklist_ustlen_bilgi),
        ],
      ],
    );
  }
}

/// Madde satırındaki atama düğmesi.
enum _Atama {
  /// "Ben getiririm": boştaki maddeyi kendine alır.
  ustlen,

  /// "Vazgeç": kendi üstlendiği maddeyi bırakır.
  birak,
}

/// Bu yazı ölçeğinin üstünde atama düğmesi metnin altına iner.
const double _dugmeYanYanaEnBuyukOlcek = 1.3;

/// Bir madde (tasarım: Etkinlik-Malzeme-Liste): ad; alt satırda adet
/// (yalnızca `quantity` açıksa) ve kimin üstlendiği. Boştaki maddede
/// "Geliyorum" diyene "Ben getiririm", kendi üstlendiğinde "Vazgeç";
/// yönetim başkasının atamasını kaldırabilir ve maddeyi çıkarabilir.
class MaddeSatiri extends ConsumerWidget {
  const MaddeSatiri({
    super.key,
    required this.madde,
    required this.liste,
    required this.mesgul,
    required this.onAta,
    required this.onAtamayiKaldir,
    required this.onCikar,
  });

  final ChecklistItem madde;

  /// Maddenin listesi (parametreler ve çağıranın yetkileri için).
  final Checklist liste;

  /// Bir işlem sürüyor: düğmeler geçici olarak kapalı.
  final bool mesgul;

  /// Atama isteği: kendi kimliği ("Ben getiririm") ya da `null`
  /// ("Vazgeç").
  final ValueChanged<String?> onAta;

  /// Yönetimin başkasının atamasını kaldırması.
  final VoidCallback onAtamayiKaldir;

  final VoidCallback onCikar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final etiket = listeEtiketi(liste);
    final ustlenen = madde.assignedUserId;
    final benim = ustlenen != null && ref.watch(kendisiMiProvider(ustlenen));
    final ikincil = context.yazi.bodySmall;
    final atamaAcik = liste.assignmentEnabled;
    final _Atama? atama = !atamaAcik
        ? null
        : ustlenen == null
        ? (liste.callerCanTake ? _Atama.ustlen : null)
        : (benim && (liste.callerCanTake || liste.callerCanManage)
              ? _Atama.birak
              : null);
    final Widget? dugme = switch (atama) {
      null => null,
      _Atama.ustlen => _SatirHapi(
        etiket: m.bilesen_checklist_ustlen(etiket),
        dolu: true,
        onPressed: mesgul
            ? null
            : () {
                final ben = ref.read(kendiKimligimProvider).value;
                if (ben != null) onAta(ben);
              },
      ),
      _Atama.birak => _SatirHapi(
        etiket: m.bilesen_checklist_vazgec,
        dolu: false,
        onPressed: mesgul ? null : () => onAta(null),
      ),
    };
    final yanYana =
        MediaQuery.textScalerOf(context).scale(1) <= _dugmeYanYanaEnBuyukOlcek;
    final adet = madde.quantity < 1 ? 1 : madde.quantity;
    final altSatir = <Widget>[
      if (liste.quantityEnabled)
        Text(m.bilesen_checklist_adet(etkinlikSayi(m, adet)), style: ikincil),
      if (atamaAcik)
        if (ustlenen == null)
          Text(m.bilesen_checklist_kimse_ustlenmedi, style: ikincil)
        else if (benim)
          Text(
            m.bilesen_checklist_ustlenen_sen(etiket),
            style: ikincil?.copyWith(
              color: context.renkler.tintMarkaUstu,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          // Üstlenen kişinin adına dokununca kişi profili (#185).
          KisiyeDokun(
            kullaniciId: ustlenen,
            ipucu: m.bilesen_checklist_ustlenen(etiket),
            child: Wrap(
              spacing: TayfamSpacing.s4,
              children: [
                Text(m.bilesen_checklist_ustlenen(etiket), style: ikincil),
                KullaniciAdiMetni(kullaniciId: ustlenen, style: ikincil),
              ],
            ),
          ),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(madde.name, style: context.yazi.titleSmall),
                if (altSatir.isNotEmpty)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (sira, parca) in altSatir.indexed) ...[
                        if (sira > 0)
                          ExcludeSemantics(
                            child: Text(ozetAyraci, style: ikincil),
                          ),
                        parca,
                      ],
                    ],
                  ),
                if (dugme != null && !yanYana)
                  Padding(
                    padding: const EdgeInsets.only(top: TayfamSpacing.s4),
                    child: dugme,
                  ),
              ],
            ),
          ),
          if (dugme != null && yanYana) ...[
            const SizedBox(width: TayfamSpacing.s12),
            dugme,
          ],
          if (liste.callerCanManage && ustlenen != null && !benim)
            AracIkonDugmesi(
              ipucu: m.bilesen_checklist_atamayi_kaldir,
              ikon: Icons.person_remove_outlined,
              onPressed: mesgul ? null : onAtamayiKaldir,
            ),
          if (liste.callerCanManage)
            AracIkonDugmesi(
              ipucu: m.bilesen_checklist_cikar,
              ikon: Icons.delete_outline,
              onPressed: mesgul ? null : onCikar,
            ),
        ],
      ),
    );
  }
}

/// Satır içi küçük hap düğme (tasarım: Etkinlik-Malzeme-Liste): [dolu]
/// marka zemin + beyaz metin ("Ben getiririm"; iki temada aynı), değilse
/// kart zemin, çizgi kenar, ana metin ("Vazgeç"). Dokunma alanı en az
/// 48 px; `onPressed` `null` ise (istek sürerken) kilitlidir.
class _SatirHapi extends StatelessWidget {
  const _SatirHapi({
    required this.etiket,
    required this.dolu,
    required this.onPressed,
  });

  final String etiket;
  final bool dolu;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final (zemin, yazi) = dolu
        ? (r.markaYuzey, r.markaYuzeyUstu)
        : (r.kart, r.metin);
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: zemin,
          foregroundColor: yazi,
          disabledBackgroundColor: r.pasif,
          disabledForegroundColor: r.pasifUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s16),
          shape: StadiumBorder(
            side: dolu
                ? BorderSide.none
                : BorderSide(
                    color: onPressed == null ? r.pasif : r.cizgi,
                    width: TayfamSizes.vurguKenari,
                  ),
          ),
          textStyle: context.yazi.labelLarge,
        ),
        child: Text(etiket, textAlign: TextAlign.center),
      ),
    );
  }
}
