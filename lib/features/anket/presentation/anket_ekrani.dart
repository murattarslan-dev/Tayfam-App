import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/features/anket/presentation/anket_sonuclari.dart';
import 'package:tayfam/features/anket/presentation/oy_verenler_sayfasi.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tek bir anket (`/t/<tayfaId>/anketler/<anketId>`; ADR-0018 §5): soru,
/// durum, oy verme (tek ya da çoklu seçim), oy değiştirme ve geri çekme,
/// sonuçlar ve kapatma.
///
/// Adresteki [anketId] girdi kabul edilir: UUID biçiminde değilse istek
/// gönderilmez, "bulunamadı" gösterilir. Kapatma menüsü anketi açana ve
/// yönetime gösterilir; kararı sunucu verir (kesin kural 5). Gizlilik
/// vaatleri [AnketSonuclari]'ndadır (kesin kural 7).
class AnketEkrani extends ConsumerWidget {
  const AnketEkrani({super.key, required this.tayfaId, required this.anketId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  /// Adresteki anket kimliği; biçimi burada doğrulanır.
  final String anketId;

  AnketAnahtari get _anahtar => (tayfaId: tayfaId, anketId: anketId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    if (!uuidBicimindeMi(anketId)) {
      return Scaffold(
        appBar: AppBar(title: Text(m.anket_baslik)),
        body: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          child: HataSatiri(metin: m.hata_poll_not_found),
        ),
      );
    }
    final saglayici = anketProvider(_anahtar);
    final durum = ref.watch(saglayici);
    final anket = durum.value;
    final hata = durum.error;
    final simdi = ref.watch(anketSaatiProvider)().toUtc();
    final kapatabilir =
        anket != null && !anketKapali(anket, simdi) && _yonetebilir(ref, anket);
    final acan = anket?.createdByUserId;
    // Başkasının anketi şikâyet edilebilir (ADR-0018 §8).
    final sikayetEdilebilir =
        anket != null && (acan == null || !ref.watch(kendisiMiProvider(acan)));
    return Scaffold(
      appBar: AppBar(
        title: Text(m.anket_baslik),
        actions: [
          if (kapatabilir || sikayetEdilebilir)
            PopupMenuButton<_AnketIslemi>(
              tooltip: m.anket_islemler,
              icon: const Icon(Icons.more_vert),
              onSelected: (islem) => unawaited(switch (islem) {
                _AnketIslemi.kapat => _kapat(context, ref),
                _AnketIslemi.sikayet => sikayetSayfasiniAc(
                  context,
                  SikayetHedefi.tayfada(
                    tayfaId: tayfaId,
                    tur: ReportTargetType.poll,
                    id: anketId,
                  ),
                ),
              }),
              itemBuilder: (_) => [
                if (kapatabilir)
                  PopupMenuItem(
                    value: _AnketIslemi.kapat,
                    child: Text(m.anket_kapat),
                  ),
                if (sikayetEdilebilir)
                  PopupMenuItem(
                    value: _AnketIslemi.sikayet,
                    child: Text(m.sikayet_et),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: RefreshIndicator(
              onRefresh: () => _yenile(context, ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                children: [
                  if (anket != null)
                    _AnketIcerigi(
                      anahtar: _anahtar,
                      anket: anket,
                      kapali: anketKapali(anket, simdi),
                    )
                  else if (hata != null) ...[
                    HataSatiri.hatadan(hata),
                    AnketTekrarDene(onPressed: () => ref.invalidate(saglayici)),
                  ] else
                    Center(
                      child: TayfamYukleniyor(boyut: TayfamSizes.yukleniyorTamEkran, etiket: m.anket_yukleniyor, gecikmeli: true,),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Anketi sunucudan yeniden okur. Okunamazsa eldeki anket kalır ve hata
  /// kısa bildirimle gösterilir.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = anketProvider(_anahtar);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) anketHatasiniBildir(context, hata);
  }

  /// Kapatma menüsü gösterilsin mi: yönetim ya da anketi açan. Yalnızca
  /// kolaylıktır; kararı sunucu verir (kesin kural 5).
  bool _yonetebilir(WidgetRef ref, Poll anket) {
    if (ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde) return true;
    final acan = anket.createdByUserId;
    return acan != null && ref.watch(kendisiMiProvider(acan));
  }

  Future<void> _kapat(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (pencere) => AlertDialog(
        title: Text(m.anket_kapat_onay_baslik),
        content: Text(m.anket_kapat_onay_aciklama),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            child: Text(m.anket_vazgec),
          ),
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(true),
            child: Text(m.anket_kapat),
          ),
        ],
      ),
    );
    if (onay != true || !context.mounted) return;
    final hata = await ref.read(anketProvider(_anahtar).notifier).kapat();
    if (!context.mounted) return;
    if (hata != null) {
      anketHatasiniBildir(context, hata);
      return;
    }
    anketBildirimi(bildirim, m.anket_kapatildi);
  }
}

enum _AnketIslemi { kapat, sikayet }

class _AnketIcerigi extends ConsumerWidget {
  const _AnketIcerigi({
    required this.anahtar,
    required this.anket,
    required this.kapali,
  });

  final AnketAnahtari anahtar;
  final Poll anket;
  final bool kapali;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final oylama = ref.watch(oylamaProvider(anahtar));
    final simdi = ref.watch(anketSaatiProvider)().toUtc();
    final secim = secimGosterilir(anket, oylama, simdi);
    final acan = anket.createdByUserId;
    final etkinlikId = anket.eventId;
    final ikincil = context.yazi.bodyMedium?.copyWith(color: r.metinGovde);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AnketEtiketleri(anket: anket, kapali: kapali),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Semantics(
          header: true,
          child: Text(anket.question, style: context.yazi.headlineSmall),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          anket.multipleChoice ? m.anket_coklu_secim : m.anket_tek_secim,
          style: ikincil,
        ),
        if (anket.anonymous) ...[
          const SizedBox(height: TayfamSpacing.s4),
          Text(m.anket_gizli_aciklama, style: ikincil),
        ],
        const SizedBox(height: TayfamSpacing.s4),
        AnketKapanisMetni(anket: anket, kapali: kapali),
        const SizedBox(height: TayfamSpacing.s4),
        Wrap(
          spacing: TayfamSpacing.s4,
          children: [
            Text(m.anket_acan, style: ikincil),
            if (acan == null)
              Text(m.kullanici_silinmis, style: ikincil)
            else
              KullaniciAdiMetni(kullaniciId: acan, style: ikincil),
          ],
        ),
        if (etkinlikId != null && uuidBicimindeMi(etkinlikId))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  context.go(Adresler.etkinlik(anahtar.tayfaId, etkinlikId)),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.event_outlined),
              label: Text(m.anket_etkinlige_git),
            ),
          ),
        const SizedBox(height: TayfamSpacing.s24),
        if (secim)
          _Secim(anahtar: anahtar, anket: anket, durum: oylama)
        else
          AnketSonuclari(
            anket: anket,
            onSecenek: (secenek) => unawaited(
              oyVerenleriGoster(
                context,
                tayfaId: anahtar.tayfaId,
                anket: anket,
                secenek: secenek,
              ),
            ),
          ),
        const SizedBox(height: TayfamSpacing.s24),
        if (!kapali)
          _Eylemler(
            anahtar: anahtar,
            anket: anket,
            durum: oylama,
            secim: secim,
          ),
      ],
    );
  }
}

/// Oy verme seçimi: tek seçimlide radyo düğmeleri, çok seçimlide kutular.
/// Sayılar burada gösterilmez.
class _Secim extends ConsumerWidget {
  const _Secim({
    required this.anahtar,
    required this.anket,
    required this.durum,
  });

  final AnketAnahtari anahtar;
  final Poll anket;
  final OylamaDurumu durum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(oylamaProvider(anahtar).notifier);
    final secenekler = siraliSecenekler(anket);
    if (anket.multipleChoice) {
      return Column(
        children: [
          for (final s in secenekler)
            CheckboxListTile(
              value: durum.secim.contains(s.id),
              onChanged: durum.gonderiliyor
                  ? null
                  : (_) => notifier.sec(anket, s.id),
              title: Text(s.text, style: context.yazi.bodyLarge),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
        ],
      );
    }
    final secili = durum.secim.length == 1 ? durum.secim.first : null;
    return RadioGroup<String>(
      groupValue: secili,
      onChanged: (deger) {
        if (deger != null) notifier.sec(anket, deger);
      },
      child: Column(
        children: [
          for (final s in secenekler)
            RadioListTile<String>(
              value: s.id,
              title: Text(s.text, style: context.yazi.bodyLarge),
              contentPadding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

/// Açık anketin düğmeleri: seçimdeyken "Oy ver" ve "Sonuçları gör" ya da
/// "Vazgeç"; sonuçlardayken "Oyunu değiştir" ve "Oyunu geri çek" ya da
/// "Oy vermeye dön".
class _Eylemler extends ConsumerWidget {
  const _Eylemler({
    required this.anahtar,
    required this.anket,
    required this.durum,
    required this.secim,
  });

  final AnketAnahtari anahtar;
  final Poll anket;
  final OylamaDurumu durum;
  final bool secim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final notifier = ref.read(oylamaProvider(anahtar).notifier);
    final kilitli = durum.gonderiliyor;
    final metinDugmesi = TextButton.styleFrom(
      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
    );
    final List<Widget> dugmeler;
    if (secim) {
      dugmeler = [
        BirincilEylem(
          etiket: m.anket_oy_ver,
          onPressed: kilitli || !secimGecerli(anket, durum.secim)
              ? null
              : () => unawaited(_oyVer(context, notifier)),
        ),
        if (durum.duzenleniyor)
          TextButton(
            onPressed: kilitli ? null : notifier.vazgec,
            style: metinDugmesi,
            child: Text(m.anket_vazgec),
          )
        else
          TextButton(
            onPressed: kilitli
                ? null
                : () => notifier.sonuclaraGec(sonuclarda: true),
            style: metinDugmesi,
            child: Text(m.anket_sonuclari_gor),
          ),
      ];
    } else if (oyVerdi(anket)) {
      dugmeler = [
        IkincilEylem(
          etiket: m.anket_oyu_degistir,
          onPressed: kilitli ? null : () => notifier.degistir(anket),
        ),
        TextButton(
          onPressed: kilitli
              ? null
              : () => unawaited(_geriCek(context, notifier)),
          style: metinDugmesi,
          child: Text(m.anket_oyu_geri_cek),
        ),
      ];
    } else {
      dugmeler = [
        IkincilEylem(
          etiket: m.anket_oy_vermeye_don,
          onPressed: kilitli
              ? null
              : () => notifier.sonuclaraGec(sonuclarda: false),
        ),
      ];
    }
    return Wrap(
      spacing: TayfamSpacing.s12,
      runSpacing: TayfamSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: dugmeler,
    );
  }

  Future<void> _oyVer(BuildContext context, OylamaNotifier notifier) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await notifier.gonder(anket);
    if (!context.mounted) return;
    if (hata != null) {
      anketHatasiniBildir(context, hata);
      return;
    }
    anketBildirimi(bildirim, m.anket_oy_kaydedildi);
  }

  Future<void> _geriCek(BuildContext context, OylamaNotifier notifier) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await notifier.geriCek();
    if (!context.mounted) return;
    if (hata != null) {
      anketHatasiniBildir(context, hata);
      return;
    }
    anketBildirimi(bildirim, m.anket_oy_geri_cekildi);
  }
}
