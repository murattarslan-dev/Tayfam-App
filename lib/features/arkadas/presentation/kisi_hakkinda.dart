import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/sosyal_medya.dart';
import 'package:tayfam/core/metin/diller.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kişi profilindeki "Hakkında" kartı (tasarım: Kisi-Profili-Tanitim;
/// issue #185, #186): hakkımda metni, ilgi çipleri, doğum günü, meslek,
/// takım, diller ve sosyal medya.
///
/// Ne döneceğine sunucu karar verir (`about_visibility`, doğum günü
/// yalnızca arkadaşlara, sosyal medya yalnızca arkadaşlara); boş ya da
/// dönmeyen alanın satırı hiç çizilmez, hiçbiri yoksa kart da yoktur. Kendi
/// profilinde tam doğum tarihi ve yaş görünür.
///
/// Sosyal medya satırı platformun bilinen adresini dış tarayıcıda açar;
/// kullanıcı adı sözleşmedeki kurala uymuyorsa satır çizilmez (sunucudan
/// gelen değer de girdi kabul edilir).
class KisiHakkinda extends ConsumerWidget {
  const KisiHakkinda({super.key, required this.profil});

  final UserProfile profil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final p = profil;
    final hakkimda = p.about?.trim() ?? '';
    final ilgiler = [
      for (final t in p.interests ?? const <EventType>[])
        if (t != EventType.unknown) t,
    ];
    final dogumGunu = dogumGunuMetni(m, p.birthday);
    final meslek = p.occupation?.trim() ?? '';
    final takim = p.team?.trim() ?? '';
    final diller = dilListesi(m, p.languages ?? const <String>[]);
    final satirlar = <Widget>[
      if (dogumGunu != null)
        _Satir(
          ikon: Icons.cake_outlined,
          etiket: m.profil_alan_dogum_gunu,
          deger: dogumGunu,
        ),
      if (meslek.isNotEmpty)
        _Satir(
          ikon: Icons.work_outline,
          etiket: m.profil_alan_meslek,
          deger: meslek,
        ),
      if (takim.isNotEmpty)
        _Satir(
          ikon: Icons.sports_soccer_outlined,
          etiket: m.profil_alan_takim,
          deger: takim,
        ),
      if (diller.isNotEmpty)
        _Satir(
          ikon: Icons.translate,
          etiket: m.profil_alan_diller,
          deger: diller,
        ),
      for (final hesap in p.socialAccounts ?? const <SocialAccount>[])
        if ((sosyalMedyaAdresi(hesap), sosyalPlatformAdi(m, hesap.platform))
            case (final adres?, final platform?))
          _Satir(
            key: ValueKey('kisi-sosyal-${hesap.platform.name}'),
            ikon: Icons.alternate_email,
            etiket: platform,
            deger: m.arkadas_sosyal_kullanici_adi(hesap.username),
            onTap: () => unawaited(disBaglantiyiAc(context, ref, adres)),
          ),
    ];
    final ust = hakkimda.isNotEmpty || ilgiler.isNotEmpty;
    if (!ust && satirlar.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.arkadas_hakkinda),
        ListeKarti(
          children: [
            if (ust)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hakkimda.isNotEmpty)
                      Text(hakkimda, style: context.yazi.bodyLarge),
                    if (hakkimda.isNotEmpty && ilgiler.isNotEmpty)
                      const SizedBox(height: TayfamSpacing.s12),
                    if (ilgiler.isNotEmpty)
                      Wrap(
                        spacing: TayfamSpacing.s8,
                        runSpacing: TayfamSpacing.s8,
                        children: [
                          for (final tur in ilgiler) EtkinlikTuruCipi(tur: tur),
                        ],
                      ),
                  ],
                ),
              ),
            ...satirlar,
          ],
        ),
      ],
    );
  }
}

/// Doğum gününün metni: yıl yoksa gün ve ay ("14 Mart"), yıl ve yaş
/// varsa "14 Mart 1990 · 36 yaşında" (`tr_TR`). Değer girdi kabul edilir:
/// geçersiz gün ya da ay için `null` (satır çizilmez).
String? dogumGunuMetni(AppLocalizations m, Birthday? dogumGunu) {
  if (dogumGunu == null) return null;
  final ay = dogumGunu.month;
  final gun = dogumGunu.day;
  final yil = dogumGunu.year;
  if (ay < 1 || ay > 12 || gun < 1 || gun > 31) return null;
  // Yıl yoksa artık yıl alınır ki 29 Şubat da gösterilebilsin.
  final tarih = DateTime(yil ?? 2000, ay, gun);
  if (tarih.month != ay || tarih.day != gun) return null;
  if (yil == null) return DateFormat.MMMMd(m.localeName).format(tarih);
  final tam = DateFormat.yMMMMd(m.localeName).format(tarih);
  final yas = dogumGunu.age;
  return yas == null ? tam : m.arkadas_dogum_gunu_yasli(tam, yas);
}

/// "Hakkında" kartındaki satır: ikon, ikincil renkte ad ve değer. Dokunulan
/// satırda (sosyal medya) değer marka renginde ve sağda dış bağlantı ikonu.
/// Büyük yazıda değer adın altına iner.
class _Satir extends StatelessWidget {
  const _Satir({
    super.key,
    required this.ikon,
    required this.etiket,
    required this.deger,
    this.onTap,
  });

  final IconData ikon;
  final String etiket;
  final String deger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final onTap = this.onTap;
    return ListeKartiSatiri(
      onTap: onTap,
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(ikon, size: TayfamSizes.ikon, color: r.metinIkincil),
          ),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Wrap(
              spacing: TayfamSpacing.s12,
              runSpacing: TayfamSpacing.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  etiket,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: r.metinIkincil,
                  ),
                ),
                Text(
                  deger,
                  style: context.yazi.titleSmall?.copyWith(
                    color: onTap == null ? null : r.tintMarkaUstu,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: TayfamSpacing.s8),
            ExcludeSemantics(
              child: Icon(
                Icons.open_in_new,
                size: TayfamSizes.ikon,
                color: r.metinIkincil,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
