import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/surum/guncelleme.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';
import 'package:tayfam/features/birebir/birebir.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';
import 'package:tayfam/features/profil/profil.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/shell/derin_link/derin_link_rotalari.dart';
import 'package:tayfam/shell/kabuk_iskeleti.dart';
import 'package:tayfam/shell/yer_tutucu.dart';
import 'package:tayfam/shell/yonlendirme.dart';

/// Tayfa sekmesinin kökündeki rota parametresi.
const String tayfaIdParametresi = Adresler.tayfaIdParametresi;

/// Uygulamanın yönlendiricisi (ADR-0003).
///
/// Uygulama boyunca yaşar (Riverpod 3'te `autoDispose` olmayan provider
/// kalıcıdır). Oturum durumu, aktif tayfa, tayfa listesi, güncelleme veya
/// tanıtım durumu değişince korumalar ([yonlendir]) yeniden çalışır.
///
/// Adresteki `/t/<id>` aktif tayfa değilse ve etkin üyeliklerdeyse aktif
/// tayfa adrese göre değişir (ADR-0014 §1; [adresleEsitle]).
///
/// Platformdan gelen derin link (Android App Links: soğuk açılışta ilk
/// adres, sıcak açılışta `pushRouteInformation`) korumalardan önce
/// bellekteki kutuya alınır ve yönlendirme kök adresle sürer; token
/// adreste, gezinme geçmişinde ve log'da kalmaz (ADR-0018 §6, kesin kural
/// 9). Bekleyen davet giriş, kayıt ve tanıtımdan sonra işlenir; referans
/// kodu kayıt formunu doldurur ve oturum açılınca bırakılır.
///
/// `debugLogDiagnostics` kapalıdır: go_router açıkken tam adresleri
/// loglar (CLAUDE.md, kesin kural 3).
final yonlendiriciProvider = Provider<GoRouter>((ref) {
  final moduller = ref.watch(tayfaModulleriProvider);
  final kutu = ref.watch(derinLinkKutusuProvider);

  final yenile = ValueNotifier<int>(0);
  ref.listen(oturumDurumuProvider, (_, _) => yenile.value++);
  ref.listen(aktifTayfaIdProvider, (_, _) => yenile.value++);
  ref.listen(guncellemeProvider, (_, _) => yenile.value++);
  ref.listen(etkinTayfaIdleriProvider, (_, _) => yenile.value++);
  ref.listen(tayfalarYukleniyorProvider, (_, _) => yenile.value++);
  ref.listen(tanitimProvider, (_, _) => yenile.value++);
  // Kayıt bitince (oturum açık) referans kodunun işi biter.
  ref.listen(oturumDurumuProvider, (_, durum) {
    if (durum == OturumDurumu.acik) kutu.referansiBirak();
  });

  final yonlendirici = GoRouter(
    initialLocation: Adresler.kok,
    refreshListenable: yenile,
    redirect: (context, state) {
      final oturum = ref.read(oturumDurumuProvider);
      final konum = kutu.yakala(
        state.uri,
        oturumAcik: oturum == OturumDurumu.acik,
      );
      final hedef = yonlendir(
        oturum: oturum,
        aktifTayfaId: ref.read(aktifTayfaIdProvider),
        konum: konum,
        guncellemeGerekli: ref.read(guncellemeProvider),
        etkinTayfalar: ref.read(etkinTayfaIdleriProvider),
        tayfalarBekleniyor: ref.read(tayfalarYukleniyorProvider),
        tanitim: ref.read(tanitimProvider),
        davetBekliyor: kutu.davetBekliyor,
      );
      if (hedef != null) return hedef;
      return identical(konum, state.uri) ? null : konum.toString();
    },
    errorBuilder: (context, state) => const BulunamadiSayfasi(),
    routes: rotalariOlustur(moduller, kutu: kutu),
  );

  var kapandi = false;
  void esitle() {
    if (kapandi) return;
    final konum = yonlendirici.routerDelegate.currentConfiguration.uri;
    final tayfaId = adresleEsitle(
      konum: konum,
      aktifTayfaId: ref.read(aktifTayfaIdProvider),
      etkinTayfalar: ref.read(etkinTayfaIdleriProvider),
    );
    if (tayfaId != null) ref.read(aktifTayfaIdProvider.notifier).sec(tayfaId);
  }

  // Gezinme bildirimi çizim sırasında gelebilir; provider değişikliği
  // sonraya bırakılır.
  void esitlemeyiPlanla() => scheduleMicrotask(esitle);
  yonlendirici.routerDelegate.addListener(esitlemeyiPlanla);
  ref.listen(etkinTayfaIdleriProvider, (_, _) => esitlemeyiPlanla());

  ref.onDispose(() {
    kapandi = true;
    yonlendirici.routerDelegate.removeListener(esitlemeyiPlanla);
    yonlendirici.dispose();
    yenile.dispose();
  });
  return yonlendirici;
}, name: 'yonlendiriciProvider');

/// Uygulamanın rota ağacı.
///
/// Dört sekme `StatefulShellRoute.indexedStack` ile kurulur; her sekmenin
/// kendi gezinme yığını vardır, sekme değişince geçmiş ve kaydırma durumu
/// korunur, Android geri tuşu önce açık sekmenin yığınında geri gider.
///
/// [moduller]'ün rotaları `/t/:tayfaId` altına eklenir. Derin link
/// rotaları (`shell/derin_link/`) bu listenin üst düzeyine eklenir; kayıt
/// formu [kutu]'daki referans koduyla dolar.
List<RouteBase> rotalariOlustur(
  List<TayfaModule> moduller, {
  DerinLinkKutusu? kutu,
}) {
  return [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          KabukIskeleti(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Adresler.karsilama,
              builder: (context, state) => const KarsilamaEkrani(),
            ),
            GoRoute(
              path: '/${Adresler.tayfaOneki}/:$tayfaIdParametresi',
              builder: (context, state) => TayfaAnaSayfa(
                tayfaId: state.pathParameters[tayfaIdParametresi]!,
              ),
              routes: [
                for (final modul in moduller) ...modul.rotalar,
                // Tayfa yönetimi modül değildir; her tayfada vardır
                // (ADR-0002, ADR-0018 §1).
                ...tayfaYonetimRotalari(),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Adresler.sohbet,
              // Birebir konuşmalar (ADR-0018 §9); kanallar #63 ile eklenir.
              builder: (context, state) => const BirebirKonusmalarEkrani(),
              routes: birebirRotalari(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Adresler.bildirimler,
              builder: (context, state) => const BildirimlerEkrani(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Adresler.profil,
              builder: (context, state) => const ProfilEkrani(),
              // Arkadaşlık ekranları da profilin altındadır (ADR-0018 §7).
              routes: [...profilRotalari, ...arkadasRotalari],
            ),
          ],
        ),
      ],
    ),
    // Açılış ve oturum korumalarının gönderdiği ekranlar (ADR-0012).
    GoRoute(
      path: Adresler.acilis,
      builder: (context, state) => const AcilisEkrani(),
    ),
    GoRoute(
      path: Adresler.guncelleme,
      builder: (context, state) => const GuncellemeEkrani(),
    ),
    // İlk açılıştaki hoş geldin tanıtımı (ADR-0017). Hedef yol girdi kabul
    // edilir ve doğrulanır.
    GoRoute(
      path: Adresler.hosGeldin,
      builder: (context, state) => HosGeldinEkrani(
        hedef: guvenliHedef(
          state.uri.queryParameters[Adresler.hedefParametresi],
        ),
      ),
    ),
    GoRoute(
      path: Adresler.giris,
      builder: (context, state) => const GirisEkrani(),
    ),
    GoRoute(
      path: Adresler.kayit,
      builder: (context, state) =>
          KayitEkrani(referansKodu: kutu?.referansKodu),
    ),
    GoRoute(
      path: Adresler.onay,
      builder: (context, state) => const OnayEkrani(),
    ),
    // Tayfa oluşturma sihirbazı kabuğun üstünde tam ekran açılır
    // (ADR-0014 §4). Kodla katılım alttan açılan bir sayfadır, rotası yok.
    GoRoute(
      path: Adresler.tayfaOlustur,
      builder: (context, state) => const OlusturmaEkrani(),
    ),
    // Davet linkinin ekranı (ADR-0018 §6); adreste token yoktur.
    ...derinLinkRotalari(),
    // Kişi profili her sekmeden açılır; sekmelerin üstündedir
    // (ADR-0018 §7).
    kisiProfiliRotasi,
  ];
}
