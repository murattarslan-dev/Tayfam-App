import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadas_bulma_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Arkadaş ekle" alttan sayfasını açar (tasarım: Profil-Arkadas-Ekle;
/// 2026-11-13): referans kodu alanı, bulunan kişi ve "Arkadaşlık isteği
/// gönder". Profil sekmesinden ve Arkadaşlar ekranından açılır.
Future<void> arkadasEkleSayfasiniAc(BuildContext context) {
  return altSayfaAc<void>(
    context,
    builder: (sayfa) => Padding(
      // Klavye açılınca alan ve sonuç klavyenin üstünde kalır.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sayfa).bottom),
      child: AltSayfaIcerigi(
        baslik: AppLocalizations.of(sayfa).arkadas_bul_baslik,
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: ArkadasEkleIcerigi(),
          ),
        ],
      ),
    ),
  );
}

/// Referans koduyla arkadaş bulma (`/profil/arkadaslar/bul`; ADR-0018 §7).
/// Aynı içerik alttan sayfada da açılır ([arkadasEkleSayfasiniAc]); bu
/// adres derin bağlantı ve geri uyumluluk içindir.
class ArkadasBulEkrani extends StatelessWidget {
  const ArkadasBulEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_bul_baslik)),
      body: ListView(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        children: const [ArkadasEkleIcerigi()],
      ),
    );
  }
}

/// Arkadaş ekleme içeriği: açıklama, kod alanı, "Bul" ve sonuç. Kod
/// girilir, sahibi gösterilir, arkadaşlık isteği gönderilir. Kod yalnızca
/// istek gövdesinde gider; saklanmaz.
class ArkadasEkleIcerigi extends ConsumerStatefulWidget {
  const ArkadasEkleIcerigi({super.key});

  @override
  ConsumerState<ArkadasEkleIcerigi> createState() =>
      _ArkadasEkleIcerigiState();
}

class _ArkadasEkleIcerigiState extends ConsumerState<ArkadasEkleIcerigi> {
  final TextEditingController _kod = TextEditingController();

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  void _ara() {
    FocusScope.of(context).unfocus();
    unawaited(ref.read(arkadasBulmaProvider.notifier).ara(_kod.text));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(arkadasBulmaProvider);
    final araniyor = durum.isLoading;
    final bulunan = durum.value;
    final hata = durum.hasError ? durum.error : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          m.arkadas_bul_aciklama,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        TextField(
          controller: _kod,
          enabled: !araniyor,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          style: context.yazi.titleLarge,
          inputFormatters: [
            LengthLimitingTextInputFormatter(referansKoduEnFazla),
          ],
          decoration: InputDecoration(
            labelText: m.arkadas_bul_kod_etiketi,
            hintText: m.arkadas_bul_kod_ornek,
          ),
          onSubmitted: (_) => _ara(),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CerceveliEylem(
            etiket: m.arkadas_bul_ara,
            ikon: Icons.search,
            onPressed: araniyor ? null : _ara,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        if (araniyor)
          Center(child: TayfamYukleniyor(etiket: m.arkadas_yukleniyor))
        else if (hata != null)
          HataSatiri.hatadan(hata)
        else if (bulunan != null)
          _BulunanKarti(bulunan: bulunan),
      ],
    );
  }
}

/// Bulunan kişi (tasarım: Profil-Arkadas-Ekle): avatar, ad, "Bu kodun
/// sahibi" ve "Arkadaşlık isteği gönder"; istek gönderildiyse durum.
class _BulunanKarti extends ConsumerStatefulWidget {
  const _BulunanKarti({required this.bulunan});

  final BulunanKisi bulunan;

  @override
  ConsumerState<_BulunanKarti> createState() => _BulunanKartiState();
}

class _BulunanKartiState extends ConsumerState<_BulunanKarti> {
  bool _gonderiliyor = false;

  Future<void> _gonder() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    setState(() => _gonderiliyor = true);
    final hata = await ref.read(arkadasBulmaProvider.notifier).istekGonder();
    if (mounted) setState(() => _gonderiliyor = false);
    final durum = ref.read(arkadasBulmaProvider).value?.durum;
    bildirici.bildir(
      hata,
      durum == FriendState.friends
          ? m.arkadas_artik_arkadassiniz
          : m.arkadas_istek_gonderildi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kisi = widget.bulunan.kisi;
    final kendisi = ref.watch(kendisiMiProvider(kisi.userId));
    final durumMetni = switch (widget.bulunan.durum) {
      FriendState.friends => m.arkadas_durum_arkadas,
      FriendState.outgoing => m.arkadas_durum_giden,
      FriendState.incoming => m.arkadas_durum_gelen,
      FriendState.unknown || null => null,
    };
    final altMetin = kendisi
        ? m.arkadas_bul_kendi_kodun
        : durumMetni ?? m.arkadas_bul_kod_sahibi;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: TayfamRadii.secimKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              child: Row(
                children: [
                  KullaniciAvatari(
                    ad: kisi.displayName,
                    avatarUploadId: kisi.avatarUploadId,
                    cap: TayfamSizes.avatarOrta,
                  ),
                  const SizedBox(width: TayfamSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kisi.displayName, style: context.yazi.titleMedium),
                        Text(altMetin, style: context.yazi.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!kendisi && durumMetni == null) ...[
              const SizedBox(height: TayfamSpacing.s16),
              BirincilEylem(
                etiket: m.arkadas_istek_gonder,
                ikon: Icons.person_add_alt,
                onPressed: _gonderiliyor ? null : () => unawaited(_gonder()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
