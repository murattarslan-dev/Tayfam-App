import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/arac_formlari.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/features/etkinlik/turler/etkinlik_turu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kamp (ADR-0015 §6): ortak malzeme listesi. Ekleme ve çıkarma yalnızca
/// yönetebilen kullanıcıya (organizatör, moderatör, yönetici;
/// `caller_can_manage`) görünür; yetkiyi sunucu verir.
final class KampTuru extends KayitliEtkinlikTuru {
  const KampTuru() : super(EventType.camp);

  @override
  Widget? aracBolumu(BuildContext context, Event etkinlik) =>
      KampBolumu(etkinlik: etkinlik);
}

/// Kampın detaydaki bölümü.
class KampBolumu extends ConsumerWidget {
  const KampBolumu({super.key, required this.etkinlik});

  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final anahtar = (tayfaId: etkinlik.tayfaId, etkinlikId: etkinlik.id);
    final mesgul = ref.watch(aracEylemProvider(anahtar));
    final malzemeler = etkinlik.camp?.items ?? const <CampItem>[];
    final yonetebilir = etkinlik.callerCanManage && !iptalEdildi(etkinlik);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AracBasligi(
          metin: m.etkinlik_kamp_malzemeler,
          sag: yonetebilir
              ? CerceveliHapEylem(
                  etiket: m.etkinlik_kamp_malzeme_ekle,
                  ikon: Icons.add,
                  onPressed: mesgul
                      ? null
                      : () => unawaited(_ekle(context, ref, anahtar)),
                )
              : null,
        ),
        AracListesi(
          bos: m.etkinlik_kamp_malzeme_yok,
          satirlar: [
            for (final malzeme in malzemeler)
              _MalzemeSatiri(
                malzeme: malzeme,
                onCikar: !yonetebilir || mesgul
                    ? null
                    : () => unawaited(_cikar(context, ref, anahtar, malzeme)),
                cikarilabilir: yonetebilir,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _ekle(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
  ) async {
    final istek = await showDialog<CampItemCreateRequest>(
      context: context,
      builder: (_) => const MalzemeFormu(),
    );
    if (istek == null || !context.mounted) return;
    final hata = await ref
        .read(aracEylemProvider(anahtar).notifier)
        .malzemeEkle(istek);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }

  Future<void> _cikar(
    BuildContext context,
    WidgetRef ref,
    EtkinlikAnahtari anahtar,
    CampItem malzeme,
  ) async {
    final m = AppLocalizations.of(context);
    final onay = await cikarmaOnayi(
      context,
      baslik: m.etkinlik_kamp_malzeme_cikar_onay,
    );
    if (!onay || !context.mounted) return;
    final hata = await ref
        .read(aracEylemProvider(anahtar).notifier)
        .malzemeCikar(malzeme.id);
    if (hata != null && context.mounted) hataBildir(context, hata);
  }
}

class _MalzemeSatiri extends StatelessWidget {
  const _MalzemeSatiri({
    required this.malzeme,
    required this.onCikar,
    required this.cikarilabilir,
  });

  final CampItem malzeme;
  final VoidCallback? onCikar;
  final bool cikarilabilir;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final getiren = malzeme.assignedUserId;
    // Sözleşme: 0 ya da yok, 1 adet.
    final adet = malzeme.quantity < 1 ? 1 : malzeme.quantity;
    final ikincil = context.yazi.bodySmall;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
      child: Row(
        children: [
          Expanded(
            child: MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(malzeme.name, style: context.yazi.titleSmall),
                        if (getiren != null)
                          Wrap(
                            spacing: TayfamSpacing.s4,
                            children: [
                              Text(m.etkinlik_kamp_getirecek, style: ikincil),
                              KullaniciAdiMetni(
                                kullaniciId: getiren,
                                style: ikincil,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Text(
                    m.etkinlik_kamp_adet(etkinlikSayi(m, adet)),
                    style: ikincil,
                  ),
                ],
              ),
            ),
          ),
          if (cikarilabilir)
            AracIkonDugmesi(
              ipucu: m.etkinlik_kamp_malzeme_cikar,
              ikon: Icons.delete_outline,
              onPressed: onCikar,
            ),
        ],
      ),
    );
  }
}

/// Kamp malzemesi ekleme formu; eklenirse istek döner.
class MalzemeFormu extends StatefulWidget {
  const MalzemeFormu({super.key});

  @override
  State<MalzemeFormu> createState() => _MalzemeFormuState();
}

class _MalzemeFormuState extends State<MalzemeFormu> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _adet = TextEditingController();
  Set<MalzemeHatasi> _hatalar = const {};

  @override
  void dispose() {
    _ad.dispose();
    _adet.dispose();
    super.dispose();
  }

  void _ekle() {
    final sonuc = malzemeIstegi(ad: _ad.text, adet: _adet.text);
    final istek = sonuc.istek;
    if (istek == null) {
      setState(() => _hatalar = sonuc.hatalar);
      return;
    }
    Navigator.of(context).pop(istek);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return AracFormDiyalogu(
      baslik: m.etkinlik_kamp_malzeme_ekle,
      onayEtiketi: m.etkinlik_ekle,
      onOnay: _ekle,
      alanlar: [
        TextField(
          controller: _ad,
          autofocus: true,
          maxLength: malzemeAdiEnCok,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: m.etkinlik_kamp_malzeme_adi,
            errorText: _hatalar.contains(MalzemeHatasi.ad)
                ? m.etkinlik_kamp_malzeme_adi_hata
                : null,
          ),
        ),
        TextField(
          controller: _adet,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: m.etkinlik_kamp_malzeme_adedi,
            errorText: _hatalar.contains(MalzemeHatasi.adet)
                ? m.etkinlik_sayi_hata(malzemeAdediEnCok)
                : null,
          ),
        ),
      ],
    );
  }
}
