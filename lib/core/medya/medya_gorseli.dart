import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/bilesenler/tayfam_yukleniyor.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/fotograf_yukleme.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/core/medya/yukleyici.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir görselin anahtarı: dosya ve varyant.
typedef MedyaGorselAnahtari = ({String uploadId, MedyaVaryanti varyant});

/// Bir dosya varyantının baytları (bellek önbelleğinden ya da indirilerek);
/// görülemiyorsa `null`. Görsel kapanınca bırakılır; baytlar
/// [MedyaOnbellegi]'nde kalır.
class MedyaGorselNotifier extends AsyncNotifier<Uint8List?> {
  MedyaGorselNotifier(this.anahtar);

  final MedyaGorselAnahtari anahtar;

  @override
  Future<Uint8List?> build() =>
      ref.watch(medyaOnbellegiProvider).bayt(anahtar.uploadId, anahtar.varyant);
}

/// Bir dosya varyantının baytları. Hata otomatik yeniden denenmez.
final medyaGorselProvider = AsyncNotifierProvider.autoDispose
    .family<MedyaGorselNotifier, Uint8List?, MedyaGorselAnahtari>(
      MedyaGorselNotifier.new,
      name: 'medyaGorselProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Yüklenmiş bir fotoğraf (ADR-0021 §5): linki toplu uçtan, baytları
/// bellek önbelleğinden. Yüklenirken ve hata ya da görülemeyen dosyada
/// [yerTutucu] gösterilir (yoksa nötr bir yüzey ve ikon). Ekran okuyucu
/// [etiket]'i tek bir görsel olarak okur.
///
/// Görsel kendi baytlarımızla `Image.memory` ile çizilir: ağ görseli
/// sağlayıcısı hata mesajına adresi yazdığı için kullanılmaz (CLAUDE.md
/// kesin kural 3).
class MedyaGorseli extends ConsumerWidget {
  const MedyaGorseli({
    super.key,
    required this.uploadId,
    required this.etiket,
    this.varyant = MedyaVaryanti.onizleme,
    this.fit = BoxFit.cover,
    this.yerTutucu,
  });

  final String uploadId;
  final MedyaVaryanti varyant;

  /// Ekran okuyucu etiketi.
  final String etiket;
  final BoxFit fit;
  final Widget? yerTutucu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(
      medyaGorselProvider((uploadId: uploadId, varyant: varyant)),
    );
    final Widget icerik;
    switch (durum) {
      case AsyncData(value: final Uint8List baytlar):
        icerik = Image.memory(
          baytlar,
          fit: fit,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _bos(context, Icons.broken_image_outlined),
        );
      case AsyncLoading():
        icerik = Stack(
          fit: StackFit.expand,
          children: [
            _bos(context, Icons.image_outlined),
            Center(
              child: TayfamYukleniyor(etiket: m.medya_gorsel_yukleniyor, gecikmeli: true,),
            ),
          ],
        );
      default:
        icerik = _bos(context, Icons.image_not_supported_outlined);
    }
    return Semantics(
      image: true,
      label: etiket,
      excludeSemantics: true,
      child: icerik,
    );
  }

  Widget _bos(BuildContext context, IconData ikon) =>
      yerTutucu ?? GorselYuzeyi(ikon: ikon);
}

/// Görsel yokken ya da yüklenirken nötr yüzey ve ikon.
class GorselYuzeyi extends StatelessWidget {
  const GorselYuzeyi({super.key, this.ikon = Icons.image_outlined});

  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ColoredBox(
      color: r.tintMarka,
      child: Center(child: Icon(ikon, color: r.tintMarkaUstu)),
    );
  }
}

/// Kullanıcının avatarı: fotoğrafı varsa o, yoksa adının baş harfi
/// (ADR-0021 §5). [ad] bilinmiyorsa kişi ikonu gösterilir.
class KullaniciAvatari extends StatelessWidget {
  const KullaniciAvatari({
    super.key,
    this.ad,
    this.avatarUploadId,
    this.cap = TayfamSizes.avatarKucuk,
  });

  final String? ad;
  final String? avatarUploadId;
  final double cap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final ad = this.ad?.trim();
    final etiket = ad == null || ad.isEmpty
        ? m.medya_avatar_etiketi_adsiz
        : m.medya_avatar_etiketi(ad);
    final basHarf = _basHarf(context, ad);
    final id = avatarUploadId;
    return SizedBox.square(
      dimension: cap,
      child: ClipOval(
        child: id == null || id.isEmpty
            ? Semantics(
                image: true,
                label: etiket,
                excludeSemantics: true,
                child: basHarf,
              )
            : MedyaGorseli(uploadId: id, etiket: etiket, yerTutucu: basHarf),
      ),
    );
  }

  Widget _basHarf(BuildContext context, String? ad) {
    final r = context.renkler;
    final harf = ad == null || ad.isEmpty
        ? null
        : String.fromCharCode(ad.runes.first);
    return ColoredBox(
      color: r.tintMarka,
      child: Center(
        child: harf == null
            ? Icon(Icons.person_outline, color: r.tintMarkaUstu)
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(TayfamSpacing.s4),
                  child: Text(
                    harf,
                    textScaler: TextScaler.noScaling,
                    style: context.yazi.titleMedium?.copyWith(
                      color: r.tintMarkaUstu,
                      fontSize: cap * 0.4,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Fotoğraf işinin hatasının metni (ADR-0021 §6).
///
/// Hazırlama ve ret hataları kendi metinlerini alır; `unavailable` (503)
/// medya kapalı demektir (depo henüz bağlanmamış ya da ulaşılamıyor);
/// geri kalan sunucu hataları ortak eşlemeden ([hataMetni]) gelir
/// (`upload-rate-limited`, `upload-quota-exceeded`, `upload-not-found`,
/// `upload-not-ready`, `upload-in-use` …).
String fotografHataMetni(AppLocalizations m, Object hata) => switch (hata) {
  GoruntuHatasi(tur: GoruntuHatasiTuru.okunamadi) => m.medya_hata_okunamadi,
  GoruntuHatasi(tur: GoruntuHatasiTuru.cokBuyuk) => m.medya_hata_cok_buyuk,
  GoruntuHatasi(tur: GoruntuHatasiTuru.islenemedi) => m.medya_hata_islenemedi,
  YuklemeReddedildi() => m.medya_hata_reddedildi,
  ApiProblem(type: ProblemType.unavailable) => m.medya_hata_kapali,
  MedyaTasimaHatasi() => m.medya_hata_baglanti,
  _ => hataMetni(m, hata),
};

/// Fotoğrafın kaynağını sorar (galeri ya da kamera); vazgeçilirse `null`.
Future<FotografKaynagi?> fotografKaynagiSor(BuildContext context) {
  final m = AppLocalizations.of(context);
  return showModalBottomSheet<FotografKaynagi>(
    context: context,
    showDragHandle: true,
    builder: (sayfa) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.kenarMobil,
            ),
            child: Text(
              m.medya_kaynak_baslik,
              style: sayfa.yazi.titleMedium,
              semanticsLabel: m.medya_kaynak_baslik,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(m.medya_kaynak_galeri),
            onTap: () => Navigator.of(sayfa).pop(FotografKaynagi.galeri),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(m.medya_kaynak_kamera),
            onTap: () => Navigator.of(sayfa).pop(FotografKaynagi.kamera),
          ),
        ],
      ),
    ),
  );
}

/// Formdaki fotoğraf alanının görünümü.
enum FotografAlaniBicimi {
  /// 16:9 kapak.
  kapak,

  /// Kare küçük resim (av fotoğrafı).
  kare,
}

/// Bir formdaki isteğe bağlı fotoğraf (kapak, av fotoğrafı; ADR-0021 §6).
///
/// [deger] alanın şimdiki dosyasıdır (`null`: fotoğraf yok). Kullanıcı yeni
/// fotoğraf seçince hazırlanıp yüklenir ve hazır olunca [onDegisti] yeni
/// kimlikle çağrılır; "Kaldır" `null` ile çağırır. İçeriğe bağlama formun
/// kaydında yapılır; yetki kararı sunucudadır (kesin kural 5).
class FotografAlani extends ConsumerStatefulWidget {
  const FotografAlani({
    super.key,
    required this.amac,
    required this.deger,
    required this.onDegisti,
    required this.etiket,
    this.tayfaId,
    this.bicim = FotografAlaniBicimi.kapak,
    this.etkin = true,
  });

  final UploadPurpose amac;
  final String? tayfaId;
  final String? deger;
  final ValueChanged<String?> onDegisti;

  /// Görselin ekran okuyucu etiketi (ör. "Kapak fotoğrafı").
  final String etiket;
  final FotografAlaniBicimi bicim;
  final bool etkin;

  @override
  ConsumerState<FotografAlani> createState() => _FotografAlaniState();
}

class _FotografAlaniState extends ConsumerState<FotografAlani> {
  /// Bu alanın kimliği (form her açıldığında yeni).
  final Object _alan = Object();

  FotografAlaniAnahtari get _anahtar =>
      (alan: _alan, amac: widget.amac, tayfaId: widget.tayfaId);

  Future<void> _sec() async {
    final kaynak = await fotografKaynagiSor(context);
    if (kaynak == null || !mounted) return;
    await ref.read(fotografYuklemeProvider(_anahtar).notifier).sec(kaynak);
  }

  void _kaldir() {
    ref.read(fotografYuklemeProvider(_anahtar).notifier).sifirla();
    widget.onDegisti(null);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    ref.listen(fotografYuklemeProvider(_anahtar), (_, yeni) {
      if (yeni is FotografHazir) widget.onDegisti(yeni.uploadId);
    });
    final durum = ref.watch(fotografYuklemeProvider(_anahtar));
    final notifier = ref.read(fotografYuklemeProvider(_anahtar).notifier);
    final deger = widget.deger;
    final isleniyor = durum is FotografIsleniyor;
    final etkin = widget.etkin && !isleniyor;
    final hataDurumu = durum is FotografYuklemeHatasi ? durum : null;

    final Widget gorsel = switch (durum) {
      FotografHazir(:final uploadId, :final onizleme) when uploadId == deger =>
        Semantics(
          image: true,
          label: widget.etiket,
          excludeSemantics: true,
          child: Image.memory(onizleme, fit: BoxFit.cover),
        ),
      _ when deger != null => MedyaGorseli(
        uploadId: deger,
        etiket: widget.etiket,
      ),
      _ => const GorselYuzeyi(ikon: Icons.add_photo_alternate_outlined),
    };
    final kutu = ClipRRect(
      borderRadius: TayfamRadii.onizlemeKoseleri,
      child: switch (widget.bicim) {
        FotografAlaniBicimi.kapak => AspectRatio(
          aspectRatio: TayfamSizes.kapakOrani,
          child: gorsel,
        ),
        FotografAlaniBicimi.kare => SizedBox.square(
          dimension: TayfamSizes.fotografKucukResim,
          child: gorsel,
        ),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.bicim == FotografAlaniBicimi.kare)
          Align(alignment: AlignmentDirectional.centerStart, child: kutu)
        else
          kutu,
        const SizedBox(height: TayfamSpacing.s8),
        if (durum case FotografIsleniyor(:final yukleniyor))
          Row(
            children: [
              const SizedBox.square(
                dimension: TayfamSizes.ikon,
                child: TayfamYukleniyor(boyut: TayfamSizes.ikon),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: Text(
                  yukleniyor ? m.medya_yukleniyor : m.medya_hazirlaniyor,
                  style: context.yazi.bodyMedium,
                ),
              ),
            ],
          ),
        if (hataDurumu != null) ...[
          HataSatiri(metin: fotografHataMetni(m, hataDurumu.hata)),
          if (hataDurumu.tekrarlanabilir)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: widget.etkin
                    ? () => unawaited(notifier.tekrarDene())
                    : null,
                child: Text(m.medya_tekrar_dene),
              ),
            ),
        ],
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            TextButton.icon(
              onPressed: etkin ? () => unawaited(_sec()) : null,
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                deger == null
                    ? m.medya_fotograf_ekle
                    : m.medya_fotograf_degistir,
              ),
            ),
            if (deger != null)
              TextButton.icon(
                onPressed: etkin ? _kaldir : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(m.medya_fotograf_kaldir),
              ),
          ],
        ),
      ],
    );
  }
}
