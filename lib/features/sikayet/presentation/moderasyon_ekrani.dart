import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sikayet/application/moderasyon_kuyrugu.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Moderasyon kuyruğunun tayfa ayarları altındaki yolu
/// (`/t/<tayfaId>/ayarlar/moderasyon`).
const String moderasyonYolu = 'moderasyon';

/// Moderasyon kuyruğunun [tayfaId] tayfasındaki adresi.
String moderasyonAdresi(String tayfaId) =>
    '${Adresler.tayfaAyarlari(tayfaId)}/$moderasyonYolu';

/// Tayfanın moderasyon kuyruğu (`/t/<tayfaId>/ayarlar/moderasyon`;
/// ADR-0018 §8): "Açık" ve "Sonuçlanan" sekmeleri.
///
/// Her şikâyette hedefin türü, gerekçe, şikâyet edenin notu, şikâyet
/// edilen kişi, içeriğin önizlemesi ve (öncelikliyse) "Öncelikli" etiketi
/// görünür. Şikâyet edenin kimliği ve tarafların yaşı sözleşmede yoktur;
/// "Öncelikli" yalnızca taraflardan birinin 18 yaşından küçük olabileceğini
/// söyler, kim olduğunu söylemez.
///
/// Kararlar: içeriği kaldırıp sonuçlandırma (duyuru, soru, cevap, anket),
/// başka yerde yapılmış işleme bağlayarak sonuçlandırma (içerik kaldırıldı,
/// üyeye yaptırım uygulandı, işlem gerekmiyor) ve kaldırılan içeriği geri
/// alma (duyuru, soru, cevap; 30 gün). Ekrana rol bakılmadan gidilebilir;
/// yetkiyi sunucu verir (kesin kural 5).
class ModerasyonKuyruguEkrani extends StatelessWidget {
  const ModerasyonKuyruguEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(m.sikayet_kuyruk_baslik),
          bottom: TabBar(
            tabs: [
              Tab(text: m.sikayet_kuyruk_acik),
              Tab(text: m.sikayet_kuyruk_sonuclanan),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _KuyrukListesi(anahtar: (tayfaId: tayfaId, acik: true)),
            _KuyrukListesi(anahtar: (tayfaId: tayfaId, acik: false)),
          ],
        ),
      ),
    );
  }
}

class _KuyrukListesi extends ConsumerWidget {
  const _KuyrukListesi({required this.anahtar});

  final KuyrukAnahtari anahtar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = moderasyonKuyruguProvider(anahtar);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    final govde = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(saglayici.notifier).yenile();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        children: [
          Text(
            anahtar.acik
                ? m.sikayet_kuyruk_acik_aciklama
                : m.sikayet_kuyruk_sonuclanan_aciklama,
            style: govde,
          ),
          const SizedBox(height: TayfamSpacing.s16),
          if (liste != null) ...[
            if (liste.ogeler.isEmpty)
              Text(
                anahtar.acik
                    ? m.sikayet_kuyruk_acik_bos
                    : m.sikayet_kuyruk_sonuclanan_bos,
                style: context.yazi.bodyLarge?.copyWith(
                  color: context.renkler.metinGovde,
                ),
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
              Center(
                child: TayfamYukleniyor(etiket: m.sikayet_yukleniyor),
              )
            else if (liste.dahaVar)
              Center(
                child: TextButton(
                  onPressed: () =>
                      unawaited(ref.read(saglayici.notifier).dahaFazla()),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.sikayet_daha_fazla),
                ),
              ),
          ] else if (hata != null) ...[
            HataSatiri.hatadan(hata),
            _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
          ] else
            Center(
              child: TayfamYukleniyor(boyut: TayfamSizes.yukleniyorTamEkran, etiket: m.sikayet_yukleniyor, gecikmeli: true,),
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
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(AppLocalizations.of(context).sikayet_tekrar_dene),
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
    );
    if (!onay || !mounted) return;
    await _calistir(
      () => _notifier.kaldirVeSonuclandir(widget.sikayet),
      m.sikayet_kaldirildi,
    );
  }

  Future<void> _sonuclandir() async {
    final m = AppLocalizations.of(context);
    final sonuc = await showModalBottomSheet<ModerationReportResolution>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
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
    final m = AppLocalizations.of(context);
    final s = widget.sikayet;
    final yazi = context.yazi;
    final ikincil = yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    final acik = s.status == ModerationReportStatus.open;
    final tur = s.targetType;
    final onizleme = onizlenebilirTurler.contains(tur)
        ? ref.watch(hedefOnizlemesiProvider(_hedef)).value
        : null;
    final not = s.description?.trim() ?? '';
    final konu = s.subjectUserId;
    final cozen = s.handledByUserId;
    final cozulme = s.resolvedAt;
    final geriAlinabilir =
        geriAlinabilirTurler.contains(tur) &&
        (s.resolution == ModerationReportResolution.contentRemoved ||
            (onizleme?.gorunmuyor ?? false));
    final acilabilir =
        tur == ReportTargetType.announcement || tur == ReportTargetType.event;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: TayfamSpacing.s8,
            runSpacing: TayfamSpacing.s8,
            children: [
              Etiket(metin: hedefTuruMetni(m, tur)),
              if (s.priority == ModerationReportPriority.minorInvolved)
                const _OncelikEtiketi(),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Text(gerekceMetni(m, s.reason), style: yazi.titleMedium),
          if (onizleme?.baslik case final baslik?) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(m.sikayet_kuyruk_onizleme(baslik), style: ikincil),
          ],
          if (onizleme?.gorunmuyor ?? false) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(m.sikayet_kuyruk_icerik_gorunmuyor, style: ikincil),
          ],
          if (not.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(m.sikayet_kuyruk_not(not), style: ikincil),
          ],
          if (tur != ReportTargetType.tayfa) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Wrap(
              spacing: TayfamSpacing.s4,
              children: [
                Text(m.sikayet_kuyruk_sikayet_edilen, style: ikincil),
                if (konu != null)
                  KullaniciAdiMetni(kullaniciId: konu, style: ikincil)
                else
                  Text(m.kullanici_silinmis, style: ikincil),
              ],
            ),
          ],
          Text(m.sikayet_kuyruk_zamani(s.createdAt.toLocal()), style: ikincil),
          if (!acik) ...[
            const SizedBox(height: TayfamSpacing.s8),
            Text(
              sonucMetni(m, s.resolution),
              style: yazi.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (cozen != null)
              Wrap(
                spacing: TayfamSpacing.s4,
                children: [
                  Text(m.sikayet_kuyruk_sonuclandiran, style: ikincil),
                  KullaniciAdiMetni(kullaniciId: cozen, style: ikincil),
                ],
              ),
            if (cozulme != null)
              Text(
                m.sikayet_kuyruk_sonuc_zamani(cozulme.toLocal()),
                style: ikincil,
              ),
          ],
          if (acik || geriAlinabilir || acilabilir) ...[
            const SizedBox(height: TayfamSpacing.s12),
            Wrap(
              spacing: TayfamSpacing.s8,
              runSpacing: TayfamSpacing.s8,
              children: [
                if (acik)
                  BirincilEylem(
                    etiket: m.sikayet_sonuclandir,
                    ikon: Icons.gavel_outlined,
                    onPressed: _mesgul ? null : () => unawaited(_sonuclandir()),
                  ),
                if (acik && kaldirilabilirTurler.contains(tur))
                  IkincilEylem(
                    etiket: m.sikayet_kaldir,
                    ikon: Icons.delete_outline,
                    onPressed: _mesgul ? null : () => unawaited(_kaldir()),
                  ),
                if (acilabilir)
                  IkincilEylem(
                    etiket: m.sikayet_icerigi_ac,
                    ikon: Icons.open_in_new,
                    onPressed: _mesgul ? null : _icerigiAc,
                  ),
                if (geriAlinabilir)
                  IkincilEylem(
                    etiket: m.sikayet_geri_al,
                    ikon: Icons.restore,
                    onPressed: _mesgul ? null : () => unawaited(_geriAl()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Öncelikli" etiketi: taraflardan biri 18 yaşından küçük olabilir
/// (`priority: minor_involved`). Kimin olduğu ve yaş gösterilmez.
class _OncelikEtiketi extends StatelessWidget {
  const _OncelikEtiketi();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final m = AppLocalizations.of(context);
    return Semantics(
      label: m.sikayet_oncelikli_aciklama,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: r.tintMango,
            borderRadius: TayfamRadii.hapKoseleri,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s12,
              vertical: TayfamSpacing.s4,
            ),
            child: Text(
              m.sikayet_oncelikli,
              style: context.yazi.labelMedium?.copyWith(color: r.tintMangoUstu),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sonuçlandırma seçimi. Çözüm başka yerde (içeriğin ya da üyenin kendi
/// ekranında) önceden yapılmış işleme bağlanır; yapılmadıysa sunucu
/// `report-action-missing` döndürür. "İçerik kaldırıldı" üye ve tayfa
/// şikâyetinde gösterilmez (sözleşme).
class _SonucSecimi extends StatelessWidget {
  const _SonucSecimi({required this.icerik});

  final bool icerik;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    final govde = yazi.bodyMedium?.copyWith(color: context.renkler.metinGovde);
    Widget secenek(
      ModerationReportResolution sonuc,
      IconData ikon,
      String baslik,
      String aciklama,
    ) => ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: TayfamSizes.dokunmaMin,
      leading: Icon(ikon),
      title: Text(baslik),
      subtitle: Text(aciklama, style: govde),
      onTap: () => Navigator.of(context).pop(sonuc),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        0,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(m.sikayet_sonuclandir, style: yazi.headlineSmall),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(m.sikayet_sonuc_secim_aciklama, style: govde),
          const SizedBox(height: TayfamSpacing.s8),
          if (icerik)
            secenek(
              ModerationReportResolution.contentRemoved,
              Icons.delete_outline,
              m.sikayet_sonuc_kaldirildi,
              m.sikayet_sonuc_kaldirildi_aciklama,
            ),
          secenek(
            ModerationReportResolution.memberSanctioned,
            Icons.person_off_outlined,
            m.sikayet_sonuc_yaptirim,
            m.sikayet_sonuc_yaptirim_aciklama,
          ),
          secenek(
            ModerationReportResolution.dismissed,
            Icons.check_circle_outline,
            m.sikayet_sonuc_islem_yok,
            m.sikayet_sonuc_islem_yok_aciklama,
          ),
        ],
      ),
    );
  }
}

/// Onay penceresi; onaylanırsa `true`.
Future<bool> _onayIste(
  BuildContext context, {
  required String baslik,
  required String aciklama,
  required String onay,
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
