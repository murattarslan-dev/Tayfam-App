import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/moduller/uye_islemleri.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/sikayet/application/moderasyon_kuyrugu.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Moderasyon kuyruğunun tayfa ayarları altındaki yolu
/// (`/t/<tayfaId>/ayarlar/moderasyon`).
const String moderasyonYolu = 'moderasyon';

/// Moderasyon kuyruğunun [tayfaId] tayfasındaki adresi.
String moderasyonAdresi(String tayfaId) =>
    '${Adresler.tayfaAyarlari(tayfaId)}/$moderasyonYolu';

/// Tayfanın moderasyon kuyruğu (`/t/<tayfaId>/ayarlar/moderasyon`;
/// ADR-0018 §8; 2026-11-13 tasarım: Moderasyon-Kuyruk,
/// Moderasyon-Sonuclandir, Moderasyon-Sonuclanan). Başlığın altında
/// tayfanın adı; "Açık · N" ve "Sonuçlanan" seçicisi ve sekmenin
/// açıklaması.
///
/// Açık şikâyet kartında tür, göreli zaman, gerekçe, içeriğin önizlemesi
/// (ya da "İçerik artık görünmüyor"), şikâyet edenin notu ve şikâyet
/// edilen kişi görünür. Öncelikli şikâyet (`minor_involved`) nar kenarlı
/// karttır ve "Taraflardan biri 18 yaşından küçük olabilir." der; kimin
/// olduğu ve yaş gösterilmez. Şikâyet edenin kimliği sözleşmede yoktur,
/// hiçbir yerde gösterilmez.
///
/// Eylemler: içerikte "İçeriği aç" (duyuru, etkinlik), "İçeriği kaldır"
/// (duyuru, soru, cevap, anket; onaylı, kaldırıp sonuçlandırır) ve
/// "Sonuçlandır"; üye şikâyetinde "Üye işlemleri" (Üyeler ekranındaki üye
/// alttan sayfası) ve "Sonuçlandır". Sonuçlandırma alttan sayfada üç sonuç
/// kartıyla seçilir. Sonuçlananda sonuç, sonuçlandıran ve zaman;
/// kaldırılan duyuru, soru ve cevapta "Geri al" (30 gün; süreyi sunucu
/// uygular). Ekrana rol bakılmadan gidilebilir; yetkiyi sunucu verir
/// (kesin kural 5).
class ModerasyonKuyruguEkrani extends ConsumerStatefulWidget {
  const ModerasyonKuyruguEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  ConsumerState<ModerasyonKuyruguEkrani> createState() =>
      _ModerasyonKuyruguEkraniState();
}

class _ModerasyonKuyruguEkraniState
    extends ConsumerState<ModerasyonKuyruguEkrani> {
  bool _acik = true;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final ad = ref.watch(tayfaOzetiProvider(widget.tayfaId)).ad;
    // "Açık · N": okunan ilk sayfadaki adet; devamı varsa "N+" (toplam
    // sözleşmede yok, sayı uydurulmaz).
    final acikAnahtar = (tayfaId: widget.tayfaId, acik: true);
    final acikListe = ref.watch(moderasyonKuyruguProvider(acikAnahtar)).value;
    var acikEtiketi = m.sikayet_kuyruk_acik;
    if (acikListe != null && acikListe.ogeler.isNotEmpty) {
      final sayi = acikListe.ogeler.length;
      acikEtiketi = acikListe.dahaVar
          ? m.sikayet_kuyruk_acik_sayili_fazla(sayi)
          : m.sikayet_kuyruk_acik_sayili(sayi);
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.sikayet_kuyruk_baslik),
            if (ad != null) Text(ad, style: yazi.bodySmall),
          ],
        ),
      ),
      body: _KuyrukListesi(
        key: ValueKey(_acik),
        anahtar: (tayfaId: widget.tayfaId, acik: _acik),
        ust: _SekmeSecici(
          acik: _acik,
          acikEtiketi: acikEtiketi,
          onSec: (acik) => setState(() => _acik = acik),
        ),
      ),
    );
  }
}

/// "Açık · N | Sonuçlanan" seçicisi (tasarım: Moderasyon-Kuyruk): kart
/// zeminli hap; seçili parça marka zemin.
class _SekmeSecici extends StatelessWidget {
  const _SekmeSecici({
    required this.acik,
    required this.acikEtiketi,
    required this.onSec,
  });

  final bool acik;
  final String acikEtiketi;
  final ValueChanged<bool> onSec;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: r.kart,
        shape: StadiumBorder(
          side: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s4),
        child: Row(
          children: [
            Expanded(
              child: _SekmeParcasi(
                etiket: acikEtiketi,
                secili: acik,
                onTap: () => onSec(true),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s4),
            Expanded(
              child: _SekmeParcasi(
                etiket: m.sikayet_kuyruk_sonuclanan,
                secili: !acik,
                onTap: () => onSec(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SekmeParcasi extends StatelessWidget {
  const _SekmeParcasi({
    required this.etiket,
    required this.secili,
    required this.onTap,
  });

  final String etiket;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Semantics(
      container: true,
      button: true,
      selected: secili,
      label: etiket,
      onTap: onTap,
      excludeSemantics: true,
      child: OdakCercevesi(
        koseler: TayfamRadii.hapKoseleri,
        child: Material(
          type: secili ? MaterialType.canvas : MaterialType.transparency,
          color: secili ? r.marka : null,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s8,
                  vertical: TayfamSpacing.s4,
                ),
                child: Center(
                  child: Text(
                    etiket,
                    textAlign: TextAlign.center,
                    style: context.yazi.labelLarge?.copyWith(
                      color: secili ? r.markaUstu : r.metin,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KuyrukListesi extends ConsumerWidget {
  const _KuyrukListesi({super.key, required this.anahtar, required this.ust});

  final KuyrukAnahtari anahtar;

  /// Listenin üstündeki seçici.
  final Widget ust;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = moderasyonKuyruguProvider(anahtar);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(saglayici.notifier).yenile();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s4,
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s24,
        ),
        children: [
          ust,
          const SizedBox(height: TayfamSpacing.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
            child: Text(
              anahtar.acik
                  ? m.sikayet_kuyruk_acik_aciklama
                  : m.sikayet_kuyruk_sonuclanan_aciklama,
              style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          if (liste != null) ...[
            if (liste.ogeler.isEmpty)
              Text(
                anahtar.acik
                    ? m.sikayet_kuyruk_acik_bos
                    : m.sikayet_kuyruk_sonuclanan_bos,
                style: context.yazi.bodyLarge?.copyWith(color: r.metinGovde),
              ),
            for (final (sira, sikayet) in liste.ogeler.indexed) ...[
              if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
              _SikayetKarti(anahtar: anahtar, sikayet: sikayet),
            ],
            const SizedBox(height: TayfamSpacing.s16),
            if (liste.dahaHatasi case final dahaHatasi?) ...[
              HataSatiri.hatadan(dahaHatasi),
              _TekrarDene(
                onPressed: () =>
                    unawaited(ref.read(saglayici.notifier).dahaFazla()),
              ),
            ] else if (liste.dahaYukleniyor)
              Center(child: TayfamYukleniyor(etiket: m.sikayet_yukleniyor))
            else if (liste.dahaVar)
              Center(
                child: BaglantiEylemi(
                  etiket: m.sikayet_daha_fazla,
                  onPressed: () =>
                      unawaited(ref.read(saglayici.notifier).dahaFazla()),
                ),
              ),
          ] else if (hata != null) ...[
            HataSatiri.hatadan(hata),
            _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
          ] else
            Center(
              child: TayfamYukleniyor(
                boyut: TayfamSizes.yukleniyorTamEkran,
                etiket: m.sikayet_yukleniyor,
                gecikmeli: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _TekrarDene extends StatelessWidget {
  const _TekrarDene({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: BaglantiEylemi(
        etiket: AppLocalizations.of(context).sikayet_tekrar_dene,
        onPressed: onPressed,
      ),
    );
  }
}

class _SikayetKarti extends ConsumerStatefulWidget {
  const _SikayetKarti({required this.anahtar, required this.sikayet});

  final KuyrukAnahtari anahtar;
  final ModerationReport sikayet;

  @override
  ConsumerState<_SikayetKarti> createState() => _SikayetKartiState();
}

class _SikayetKartiState extends ConsumerState<_SikayetKarti> {
  bool _mesgul = false;

  ModerasyonKuyruguNotifier get _notifier =>
      ref.read(moderasyonKuyruguProvider(widget.anahtar).notifier);

  HedefAnahtari get _hedef => (
    tayfaId: widget.anahtar.tayfaId,
    tur: widget.sikayet.targetType,
    id: widget.sikayet.targetId,
  );

  /// [islem]'i çalıştırır ve sonucu kısa bildirimle gösterir.
  Future<void> _calistir(
    Future<Object?> Function() islem,
    String basari,
  ) async {
    final bildirim = ScaffoldMessenger.of(context);
    final m = AppLocalizations.of(context);
    setState(() => _mesgul = true);
    final hata = await islem();
    if (mounted) setState(() => _mesgul = false);
    if (hata is OturumYok) return;
    bildirim
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(hata == null ? basari : hataMetni(m, hata))),
      );
  }

  Future<void> _kaldir() async {
    final m = AppLocalizations.of(context);
    final onay = await _onayIste(
      context,
      baslik: m.sikayet_kaldir_baslik,
      aciklama: m.sikayet_kaldir_aciklama,
      onay: m.sikayet_kaldir_onayla,
      yikici: true,
    );
    if (!onay || !mounted) return;
    await _calistir(
      () => _notifier.kaldirVeSonuclandir(widget.sikayet),
      m.sikayet_kaldirildi,
    );
  }

  Future<void> _sonuclandir() async {
    final m = AppLocalizations.of(context);
    final sonuc = await altSayfaAc<ModerationReportResolution>(
      context,
      builder: (_) => _SonucSecimi(icerik: icerikMi(widget.sikayet.targetType)),
    );
    if (sonuc == null || !mounted) return;
    await _calistir(
      () => _notifier.sonuclandir(widget.sikayet, sonuc),
      m.sikayet_sonuclandi,
    );
  }

  Future<void> _geriAl() async {
    final m = AppLocalizations.of(context);
    final onay = await _onayIste(
      context,
      baslik: m.sikayet_geri_al_baslik,
      aciklama: m.sikayet_geri_al_aciklama,
      onay: m.sikayet_geri_al,
    );
    if (!onay || !mounted) return;
    await _calistir(
      () => _notifier.geriAl(widget.sikayet),
      m.sikayet_geri_alindi,
    );
  }

  /// Şikâyet edilen üyenin işlemlerini (Üyeler ekranındaki alttan sayfa)
  /// açar; işlemden sonra moderatör şikâyeti ayrıca sonuçlandırır.
  void _uyeIslemleri(UyeIslemleri ac) => unawaited(
    ac(
      context,
      tayfaId: widget.anahtar.tayfaId,
      kullaniciId: widget.sikayet.targetId,
    ),
  );

  void _icerigiAc() {
    final s = widget.sikayet;
    final tayfaId = widget.anahtar.tayfaId;
    final adres = switch (s.targetType) {
      ReportTargetType.announcement => Adresler.duyuru(tayfaId, s.targetId),
      ReportTargetType.event => Adresler.etkinlik(tayfaId, s.targetId),
      _ => null,
    };
    if (adres != null) unawaited(context.push(adres));
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final s = widget.sikayet;
    final tur = s.targetType;
    final acik = s.status == ModerationReportStatus.open;
    final oncelikli = s.priority == ModerationReportPriority.minorInvolved;
    final onizleme = onizlenebilirTurler.contains(tur)
        ? ref.watch(hedefOnizlemesiProvider(_hedef)).value
        : null;
    return Material(
      color: r.kart,
      shape: RoundedRectangleBorder(
        borderRadius: TayfamRadii.kartKoseleri,
        side: oncelikli && acik
            ? BorderSide(color: r.narMetin, width: TayfamSizes.vurguKenari)
            : BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: acik
              ? _acikIcerik(context, onizleme, oncelikli)
              : _sonuclananIcerik(context, onizleme),
        ),
      ),
    );
  }

  /// Sonuçlanan şikâyet kartının satırları (tasarım:
  /// Moderasyon-Sonuclanan): tür ve sonuç etiketi, gerekçe, sonuçlandıran
  /// ve zaman; kaldırılan duyuru, soru ve cevapta "Geri al".
  List<Widget> _sonuclananIcerik(
    BuildContext context,
    HedefOnizlemesi? onizleme,
  ) {
    final m = AppLocalizations.of(context);
    final s = widget.sikayet;
    final tur = s.targetType;
    final geriAlinabilir =
        geriAlinabilirTurler.contains(tur) &&
        (s.resolution == ModerationReportResolution.contentRemoved ||
            (onizleme?.gorunmuyor ?? false));
    return [
      Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s4,
        children: [
          Etiket(metin: hedefTuruMetni(m, tur)),
          Etiket(metin: sonucMetni(m, s.resolution), ton: EtiketTonu.teal),
        ],
      ),
      const SizedBox(height: TayfamSpacing.s8),
      Text(gerekceMetni(m, s.reason), style: context.yazi.titleMedium),
      _SonuclandiranSatiri(kullaniciId: s.handledByUserId, zaman: s.resolvedAt),
      if (geriAlinabilir) ...[
        const SizedBox(height: TayfamSpacing.s8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CerceveliHapEylem(
            etiket: m.sikayet_geri_al,
            ikon: Icons.undo,
            onPressed: _mesgul ? null : () => unawaited(_geriAl()),
          ),
        ),
      ],
    ];
  }

  /// Açık şikâyet kartının satırları (tasarım: Moderasyon-Kuyruk).
  List<Widget> _acikIcerik(
    BuildContext context,
    HedefOnizlemesi? onizleme,
    bool oncelikli,
  ) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final s = widget.sikayet;
    final tur = s.targetType;
    final ikincil = yazi.bodyMedium?.copyWith(color: r.metinIkincil);
    final not = s.description?.trim() ?? '';
    final konu = s.subjectUserId;
    final uye = tur == ReportTargetType.user;
    final uyeIslemleri = ref.watch(uyeIslemleriProvider);
    final acilabilir =
        tur == ReportTargetType.announcement || tur == ReportTargetType.event;
    final simdi = ref.watch(simdiProvider)();
    // Önizleme: üyede adı, içerikte başlığı ya da "İçerik artık
    // görünmüyor"; başlığı olmayan türde (cevap, av kaydı) kutu yok.
    final baslik = onizleme?.baslik;
    final Widget? onizlemeIcerigi;
    if (uye) {
      onizlemeIcerigi = KullaniciAdiMetni(
        kullaniciId: s.targetId,
        style: yazi.bodyMedium,
      );
    } else if (baslik != null) {
      onizlemeIcerigi = Text(
        m.sikayet_kuyruk_onizleme(baslik),
        style: yazi.bodyMedium,
      );
    } else if (onizleme?.gorunmuyor ?? false) {
      onizlemeIcerigi = Text(
        m.sikayet_kuyruk_icerik_gorunmuyor,
        style: ikincil,
      );
    } else {
      onizlemeIcerigi = null;
    }
    return [
      Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (oncelikli) const _OncelikEtiketi(),
          Etiket(metin: hedefTuruMetni(m, tur)),
          Text(
            goreliGecmis(m, s.createdAt, simdi),
            style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
          ),
        ],
      ),
      const SizedBox(height: TayfamSpacing.s8),
      Text(gerekceMetni(m, s.reason), style: yazi.titleMedium),
      if (oncelikli)
        Text(
          m.sikayet_oncelikli_not,
          style: yazi.bodySmall?.copyWith(color: r.narMetin),
        ),
      if (onizlemeIcerigi != null) ...[
        const SizedBox(height: TayfamSpacing.s8),
        _OnizlemeKutusu(child: onizlemeIcerigi),
      ],
      if (not.isNotEmpty) ...[
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          m.sikayet_kuyruk_not(not),
          style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
        ),
      ],
      if (tur != ReportTargetType.tayfa) ...[
        const SizedBox(height: TayfamSpacing.s8),
        Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(m.sikayet_kuyruk_sikayet_edilen, style: ikincil),
            KimlikAvatari(kullaniciId: konu, cap: TayfamSizes.avatarYigini),
            if (konu != null)
              KullaniciAdiMetni(
                kullaniciId: konu,
                style: yazi.bodyMedium?.copyWith(
                  color: r.metin,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(m.kullanici_silinmis, style: ikincil),
          ],
        ),
      ],
      const SizedBox(height: TayfamSpacing.s12),
      Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: [
          if (uye && uyeIslemleri != null)
            CerceveliHapEylem(
              etiket: m.sikayet_uye_islemleri,
              onPressed: _mesgul ? null : () => _uyeIslemleri(uyeIslemleri),
            ),
          if (acilabilir)
            CerceveliHapEylem(
              etiket: m.sikayet_icerigi_ac,
              onPressed: _mesgul ? null : _icerigiAc,
            ),
          if (kaldirilabilirTurler.contains(tur))
            YikiciEylem(
              etiket: m.sikayet_kaldir,
              onPressed: _mesgul ? null : () => unawaited(_kaldir()),
            ),
          BirincilEylem(
            etiket: m.sikayet_sonuclandir,
            onPressed: _mesgul ? null : () => unawaited(_sonuclandir()),
          ),
        ],
      ),
    ];
  }
}

/// İçerik önizlemesi kutusu: zemin rengi, ince kenar, 12 px köşe.
class _OnizlemeKutusu extends StatelessWidget {
  const _OnizlemeKutusu({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        borderRadius: TayfamRadii.dugmeKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: child,
      ),
    );
  }
}

/// Sonuçlanan şikâyette "Sonuçlandıran: Ad · zaman". Sonuçlandıran
/// bilinmiyorsa yalnızca zaman. Ad, ad önbelleğinden istenir (yalnızca
/// bellek).
class _SonuclandiranSatiri extends ConsumerWidget {
  const _SonuclandiranSatiri({required this.kullaniciId, required this.zaman});

  final String? kullaniciId;
  final DateTime? zaman;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final zaman = this.zaman;
    final kimlik = kullaniciId;
    if (zaman == null) return const SizedBox.shrink();
    final goreli = goreliGecmis(m, zaman, ref.watch(simdiProvider)());
    final stil = context.yazi.bodySmall?.copyWith(
      color: context.renkler.metinIkincil,
    );
    if (kimlik == null) return Text(goreli, style: stil);
    ref.read(kullaniciAdlariProvider.notifier).iste(kimlik);
    final bilinen = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[kimlik]),
    );
    final ad = switch (bilinen) {
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
    return Text(m.sikayet_kuyruk_sonuclandiran_satiri(ad, goreli), style: stil);
  }
}

/// "Öncelikli" etiketi: dolu nar zemin ve uyarı ikonu (tasarım:
/// Moderasyon-Kuyruk). Taraflardan biri 18 yaşından küçük olabilir
/// (`priority: minor_involved`); kimin olduğu ve yaş gösterilmez.
class _OncelikEtiketi extends StatelessWidget {
  const _OncelikEtiketi();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final m = AppLocalizations.of(context);
    final renk = r.yikiciDolguUstu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.yikiciDolgu,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s8,
          vertical: TayfamSpacing.s4,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: TayfamSizes.ikonKucuk,
                    color: renk,
                  ),
                ),
              ),
              const WidgetSpan(child: SizedBox(width: TayfamSpacing.s4)),
              TextSpan(text: m.sikayet_oncelikli),
            ],
          ),
          style: context.yazi.labelMedium?.copyWith(color: renk),
        ),
      ),
    );
  }
}

/// Sonuçlandırma alttan sayfası (tasarım: Moderasyon-Sonuclandir): sonuç
/// kartları ve "Sonuçlandır". Çözüm başka yerde (içeriğin ya da üyenin
/// kendi ekranında) önceden yapılmış işleme bağlanır; yapılmadıysa sunucu
/// `report-action-missing` döndürür. "İçerik kaldırıldı" üye ve tayfa
/// şikâyetinde gösterilmez (sözleşme). Seçilmeden "Sonuçlandır" pasiftir.
class _SonucSecimi extends StatefulWidget {
  const _SonucSecimi({required this.icerik});

  final bool icerik;

  @override
  State<_SonucSecimi> createState() => _SonucSecimiState();
}

class _SonucSecimiState extends State<_SonucSecimi> {
  ModerationReportResolution? _secim;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final secim = _secim;
    final secenekler = [
      if (widget.icerik)
        (
          ModerationReportResolution.contentRemoved,
          m.sikayet_sonuc_kaldirildi,
          m.sikayet_sonuc_kaldirildi_aciklama,
        ),
      (
        ModerationReportResolution.memberSanctioned,
        m.sikayet_sonuc_yaptirim,
        m.sikayet_sonuc_yaptirim_aciklama,
      ),
      (
        ModerationReportResolution.dismissed,
        m.sikayet_sonuc_islem_yok,
        m.sikayet_sonuc_islem_yok_aciklama,
      ),
    ];
    return AltSayfaIcerigi(
      baslik: m.sikayet_sonuclandir,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
          child: Text(
            m.sikayet_sonuc_secim_aciklama,
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        RadioGroup<ModerationReportResolution>(
          groupValue: secim,
          onChanged: (yeni) {
            if (yeni != null) setState(() => _secim = yeni);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, secenek) in secenekler.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                _SonucKarti(
                  sonuc: secenek.$1,
                  baslik: secenek.$2,
                  aciklama: secenek.$3,
                  secili: secenek.$1 == secim,
                  onTap: () => setState(() => _secim = secenek.$1),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        BirincilEylem(
          etiket: m.sikayet_sonuclandir,
          onPressed: secim == null
              ? null
              : () => Navigator.of(context).pop(secim),
        ),
      ],
    );
  }
}

/// Sonuç kartı: radyo, başlık ve açıklama; seçili kart marka kenarlı ve
/// tint-brand zeminli.
class _SonucKarti extends StatelessWidget {
  const _SonucKarti({
    required this.sonuc,
    required this.baslik,
    required this.aciklama,
    required this.secili,
    required this.onTap,
  });

  final ModerationReportResolution sonuc;
  final String baslik;
  final String aciklama;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    return MergeSemantics(
      child: Material(
        color: secili ? r.tintMarka : r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.secimKoseleri,
          side: secili
              ? BorderSide(color: r.marka, width: TayfamSizes.alanOdakKenari)
              : BorderSide(color: r.cizgi, width: TayfamSizes.vurguKenari),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Radio<ModerationReportResolution>(value: sonuc),
                const SizedBox(width: TayfamSpacing.s8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(baslik, style: yazi.titleMedium),
                      const SizedBox(height: TayfamSpacing.s4),
                      Text(
                        aciklama,
                        style: yazi.bodySmall?.copyWith(color: r.metinGovde),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Onay penceresi; onaylanırsa `true`. [yikici] ise (içeriği kaldır) onay
/// düğmesi dolu yıkıcı düğmedir (ADR-0004 Notlar 2026-11-13).
Future<bool> _onayIste(
  BuildContext context, {
  required String baslik,
  required String aciklama,
  required String onay,
  bool yikici = false,
}) async {
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (pencere) {
      final m = AppLocalizations.of(pencere);
      return AlertDialog(
        title: Text(baslik),
        scrollable: true,
        content: Text(aciklama),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(pencere).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.sikayet_vazgec),
          ),
          if (yikici)
            YikiciEylem(
              etiket: onay,
              dolu: true,
              onPressed: () => Navigator.of(pencere).pop(true),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(pencere).pop(true),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(onay),
            ),
        ],
      );
    },
  );
  return sonuc ?? false;
}
