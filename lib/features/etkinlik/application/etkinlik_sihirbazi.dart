import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/istek_kimligi.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Etkinlik oluşturmanın `client_request_id` üreticisi; testlerde sabit
/// değer verilir.
final etkinlikIstekKimligiProvider = Provider<String Function()>(
  (ref) => yeniIstekKimligi,
  name: 'etkinlikIstekKimligiProvider',
);

/// Sihirbazın anahtarı: tayfa ve (düzenlemede) düzenlenen etkinlik.
/// [tayfaId] `null` ise anlık etkinliktir (ADR-0026; [AnlikSihirbazNotifier]).
typedef SihirbazAnahtari = ({String? tayfaId, Event? duzenlenen});

/// Etkinlik oluşturma ve düzenleme sihirbazı (ADR-0015 §3 ve Notlar
/// 2026-11-13): tür → başlık, açıklama, başlangıç, bitiş → yer → türe
/// özel alanlar, kontenjan ve tekrar → önizleme. Önizlemedeki "Değiştir"
/// ilgili adıma götürür; o adımda "İleri" yeniden önizlemeye döner.
///
/// Kurallar ADR-0014 §4'teki gibidir: girilenler adımlar arasında korunur,
/// `client_request_id` sihirbaz açılınca bir kez üretilir ve tekrar
/// gönderimde aynen kullanılır. Düzenlemede tür değişmez, tekrar
/// düzenlenmez; ilk adım başlık ve zamandır.
class EtkinlikSihirbaziNotifier extends Notifier<EtkinlikTaslagi> {
  EtkinlikSihirbaziNotifier(this.anahtar);

  final SihirbazAnahtari anahtar;

  /// Düzenleme mi.
  bool get duzenleme => anahtar.duzenlenen != null;

  /// Anlık (bireysel) etkinlik mi (ADR-0026): tayfa yoktur, sunucu gizli
  /// bir tayfa açar. Tekrar ve kapak yoktur; ayrıntıdan sonra arkadaş
  /// seçimi adımı gelir.
  bool get anlik => anahtar.tayfaId == null;

  /// Önizleme ("Her şey doğru mu?") adımı.
  int get onizlemeAdimi =>
      anlik ? SihirbazAdimi.anlikOnizleme : SihirbazAdimi.onizleme;

  /// Adım sayısı.
  int get adimSayisi => anlik ? anlikAdimSayisi : etkinlikAdimSayisi;

  /// Sihirbazın ilk adımı: oluşturmada tür, düzenlemede başlık ve zaman.
  int get ilkAdim => duzenleme ? 1 : 0;

  /// Sihirbaz açıldığındaki taslak ("Vazgeçilsin mi?" sorusu için).
  late EtkinlikTaslagi _ilk;

  @override
  EtkinlikTaslagi build() {
    final kimlik = ref.read(etkinlikIstekKimligiProvider)();
    final eski = anahtar.duzenlenen;
    _ilk = eski == null
        ? EtkinlikTaslagi(istekKimligi: kimlik)
        : duzenlemeTaslagi(eski, kimlik);
    return _ilk;
  }

  /// Kullanıcı bir şey girdi ya da değiştirdi mi (kapatırken onay
  /// sorulur).
  bool get girdiVar => !ayniGirdi(state, _ilk);

  DateTime get _simdi => ref.read(etkinlikSaatiProvider)().toUtc();

  Set<TaslakHatasi> _hatalar(int adim, EtkinlikTaslagi t) =>
      adimHatalari(adim, t, simdi: _simdi, eski: anahtar.duzenlenen);

  /// Taslağı değiştirir. Gösterilen hatalar varsa yeniden hesaplanır;
  /// düzeltilen alanın hatası kalkar.
  void _ayarla(EtkinlikTaslagi yeni) {
    state = yeni.hatalar.isEmpty
        ? yeni
        : yeni.kopya(hatalar: _hatalar(yeni.adim, yeni));
  }

  bool get _kilitli => state.gonderiliyor || state.sonuc != null;

  /// Türü katalogdaki [tanim]'ıyla seçer (yalnızca oluşturmada). Emekli
  /// tür ve alan türü tanınmayan tür seçilemez (ADR-0024 §3, §4). Tür
  /// değişince önceki türün alan değerleri bırakılır ve mod, yeni türün
  /// izin verdiği modlardan biri değilse ilk izin verilene çekilir.
  void turSec(CatalogEventType tanim) {
    if (_kilitli ||
        duzenleme ||
        tanim.status != CatalogStatus.active ||
        !katalogAnahtariMi(tanim.key) ||
        !alanlarTaniniyor(turAlanlari(tanim))) {
      return;
    }
    if (state.turTanimi == tanim) return;
    final modlar = turModlari(tanim);
    final yer = state.yer;
    _ayarla(
      state.kopya(
        tur: tanim.key,
        turTanimi: tanim,
        alanlar: state.tur == tanim.key ? null : const {},
        yer: modlar.contains(yer.mod) ? null : yer.kopya(mod: modlar.first),
      ),
    );
  }

  /// Düzenlemede etkinliğin tür sürümünün tanımı sonradan okundu: katalog
  /// alanlarının değerleri etkinlikten doldurulur. Kullanıcının girdisi
  /// sayılmaz (vazgeç onayı sorulmaz).
  void tanimGeldi(CatalogEventType tanim) {
    final eski = anahtar.duzenlenen;
    if (_kilitli || eski == null || state.turTanimi != null) return;
    if (tanim.key != eski.type || tanim.version != eski.typeVersion) return;
    final alanlar = alanDegerleriOku(turAlanlari(tanim), eski.fields);
    _ilk = _ilk.kopya(turTanimi: tanim, alanlar: alanlar);
    state = state.kopya(
      turTanimi: tanim,
      alanlar: alanlar,
      hata: state.hata,
      gonderiliyor: state.gonderiliyor,
    );
  }

  /// Katalogdaki tür alanlarının değerleri.
  void alanlariAyarla(AlanDegerleri alanlar) {
    if (_kilitli) return;
    _ayarla(state.kopya(alanlar: alanlar, alanlarDegisti: true));
  }

  void baslikAyarla(String baslik) {
    if (_kilitli) return;
    _ayarla(state.kopya(baslik: baslik));
  }

  void aciklamaAyarla(String aciklama) {
    if (_kilitli) return;
    _ayarla(state.kopya(aciklama: aciklama));
  }

  /// Kapak fotoğrafını ayarlar ya da kaldırır (`null`; ADR-0021 §6).
  /// Anlık etkinlikte kapak yoktur (sözleşme; sonra düzenlemeyle eklenir).
  void kapakAyarla(String? uploadId) {
    if (_kilitli || anlik) return;
    _ayarla(state.kopya(kapak: uploadId));
  }

  /// Başlangıcı ayarlar. Bitiş yoksa ya da başlangıçtan önceyse bitiş
  /// başlangıçtan iki saat sonraya alınır (kolaylık; kullanıcı değiştirir).
  void baslangicAyarla(DateTime baslangic) {
    if (_kilitli) return;
    final utc = baslangic.toUtc();
    final bitis = state.bitis;
    _ayarla(
      state.kopya(
        baslangic: utc,
        bitis: bitis == null || !bitis.isAfter(utc)
            ? utc.add(varsayilanSure)
            : null,
      ),
    );
  }

  void bitisAyarla(DateTime bitis) {
    if (_kilitli) return;
    _ayarla(state.kopya(bitis: bitis.toUtc()));
  }

  /// Yer adımı.
  void yerAyarla(YerBilgisi yer) {
    if (_kilitli) return;
    _ayarla(state.kopya(yer: yer));
  }

  /// Harita seçicinin sonucu: nokta; yer adı, il ve ilçe boşsa öneriyle
  /// doldurulur.
  void noktaSec(LatLng nokta, {String? ad, String? il, String? ilce}) {
    if (_kilitli) return;
    final yer = state.yer;
    String doldur(String mevcut, String? oneri) =>
        mevcut.trim().isEmpty && oneri != null ? oneri : mevcut;
    _ayarla(
      state.kopya(
        yer: yer.kopya(
          nokta: nokta,
          noktaAdi: doldur(
            yer.noktaAdi,
            ad == null ? null : _kisalt(ad, etkinlikYerAdiEnCok),
          ),
          il: doldur(yer.il, il),
          ilce: doldur(yer.ilce, ilce),
        ),
      ),
    );
  }

  void kontenjanAyarla(String kontenjan) {
    if (_kilitli) return;
    _ayarla(state.kopya(kontenjan: kontenjan));
  }

  /// Tekrarı ayarlar; `null` tek seferlik (yalnızca oluşturmada).
  void tekrarAyarla(TekrarSecimi? tekrar) {
    if (_kilitli || duzenleme || anlik) return;
    _ayarla(state.kopya(tekrar: tekrar));
  }

  /// Türe özel alanlar.
  void ayrintiAyarla(TurAyrintisi ayrinti) {
    if (_kilitli) return;
    _ayarla(state.kopya(ayrinti: ayrinti, ayrintiDegisti: true));
  }

  /// Anlık etkinlikte [kullaniciId] arkadaşını davetlilere ekler ya da
  /// çıkarır. En çok [anlikDavetliEnCok] kişi seçilir; fazlası yok sayılır.
  void davetliDegistir(String kullaniciId) {
    if (_kilitli || !anlik || !uuidBicimindeMi(kullaniciId)) return;
    final secili = [...state.davetliler];
    if (!secili.remove(kullaniciId)) {
      if (secili.length >= anlikDavetliEnCok) return;
      secili.add(kullaniciId);
    }
    _ayarla(state.kopya(davetliler: List.unmodifiable(secili)));
  }

  /// Sonraki adıma geçer; adımda hata varsa geçmez ve hatalar gösterilir.
  /// Adıma önizlemeden gelindiyse önizlemeye döner. Son adımda (önizleme)
  /// bir şey yapmaz ([gonder] kullanılır).
  void ileri() {
    if (_kilitli) return;
    final hatalar = _hatalar(state.adim, state);
    if (hatalar.isNotEmpty) {
      state = state.kopya(hatalar: hatalar);
      return;
    }
    if (state.adim >= onizlemeAdimi) return;
    state = state.kopya(
      adim: state.onizlemeyeDon ? onizlemeAdimi : state.adim + 1,
      onizlemeyeDon: false,
      hatalar: const {},
    );
  }

  /// Önceki adıma döner; ilk adımda `false` döner (sihirbaz kapanabilir).
  bool geri() {
    if (_kilitli || state.adim <= ilkAdim) return false;
    state = state.kopya(
      adim: state.adim - 1,
      onizlemeyeDon: false,
      hatalar: const {},
    );
    return true;
  }

  /// Önizlemedeki "Değiştir": [adim]'a gider; o adımda "İleri" önizlemeye
  /// döner. Yalnızca önizlemeden ve gösterilen adımlar için.
  void adimaGit(int adim) {
    if (_kilitli ||
        state.adim != onizlemeAdimi ||
        adim < ilkAdim ||
        adim >= onizlemeAdimi) {
      return;
    }
    state = state.kopya(adim: adim, onizlemeyeDon: true, hatalar: const {});
  }

  /// Etkinliği oluşturur ya da düzenler. Hatalı adım varsa o adıma dönülür.
  /// Sürerken ikinci çağrı yok sayılır; tekrar denemede aynı
  /// `client_request_id` gönderilir.
  Future<void> gonder() async {
    final mevcut = state;
    if (_kilitli) return;
    for (var adim = ilkAdim; adim < adimSayisi; adim++) {
      final hatalar = _hatalar(adim, mevcut);
      if (hatalar.isNotEmpty) {
        // Düzeltilince "İleri" önizlemeye döner.
        state = mevcut.kopya(
          adim: adim,
          hatalar: hatalar,
          onizlemeyeDon: mevcut.adim == onizlemeAdimi,
        );
        return;
      }
    }
    final tayfaId = anahtar.tayfaId;
    if (tayfaId == null) return _anlikGonder(mevcut);
    final islemler = ref.read(etkinlikDeposuProvider);
    final eski = anahtar.duzenlenen;
    state = mevcut.kopya(gonderiliyor: true, hatalar: const {});
    final Event etkinlik;
    try {
      if (eski == null) {
        etkinlik = await islemler.olustur(tayfaId, olusturmaIstegi(mevcut));
      } else {
        final istek = duzenlemeIstegi(mevcut, eski);
        if (istek == null) {
          if (ref.mounted) state = mevcut.kopya(sonuc: eski.id);
          return;
        }
        etkinlik = await islemler.duzenle(tayfaId, eski.id, istek);
      }
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut.kopya(hata: hata);
      return;
    }
    if (!ref.mounted) return;
    ref.invalidate(
      etkinlikDetayProvider((tayfaId: tayfaId, etkinlikId: etkinlik.id)),
    );
    etkinlikListeleriniYenile(ref, tayfaId);
    state = mevcut.kopya(sonuc: etkinlik.id);
  }

  /// `POST /v1/instant-events`. Başarıda gizli tayfa tayfa listesine
  /// eklenir (etkinlik adresi açılınca aktif tayfa adrese göre değişir,
  /// ADR-0014 §1) ve liste arka planda yenilenir; "Etkinlik açıldı" ekranı
  /// yanıttaki veriyle çizilir.
  Future<void> _anlikGonder(EtkinlikTaslagi mevcut) async {
    state = mevcut.kopya(gonderiliyor: true, hatalar: const {});
    final InstantEvent sonuc;
    try {
      sonuc = await ref
          .read(etkinlikDeposuProvider)
          .anlikOlustur(anlikIstegi(mevcut));
    } on OturumYok {
      if (!ref.mounted) return;
      ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      return;
    } on Exception catch (hata) {
      if (ref.mounted) state = mevcut.kopya(hata: hata);
      return;
    }
    if (!ref.mounted) return;
    final tayfa = sonuc.tayfa;
    final liste = ref.read(tayfalarimProvider.notifier);
    if (uuidBicimindeMi(tayfa.id)) {
      liste.ekle(
        MyTayfa(
          tayfaId: tayfa.id,
          name: tayfa.name,
          kind: tayfa.kind,
          role: Role.admin,
          status: MyTayfaStatus.active,
          tayfa: tayfa,
        ),
      );
    }
    unawaited(liste.yenile());
    state = mevcut.kopya(sonuc: sonuc.event.id, anlikSonuc: sonuc);
  }
}

/// Anlık etkinlik sihirbazının açılış değerleri; adresten gelir ve
/// [anlikBaslangicCoz] ile doğrulanır. [gun] yerel takvim günü (yalnızca
/// yıl, ay, gün), [davetli] önceden seçili arkadaş ("Boşum" rozetindeki
/// "Bir şey yapalım"; ADR-0026).
typedef AnlikAnahtari = ({DateTime? gun, String? davetli});

/// "Bir şey yapalım"da en çok kaç gün sonrası kabul edilir (Boşum: en
/// fazla 30 gün ileri; Notion Faz 2 §3).
const int anlikGunEnCok = 30;

/// "Bir şey yapalım"da önerilen başlangıç saati (yerel).
const int anlikVarsayilanSaat = 19;

final RegExp _gunBicimi = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Adresteki `gun` ve `davetli` parametrelerini doğrular (adres girdi
/// kabul edilir, ADR-0003). Gün `YYYY-MM-DD` biçiminde, geçerli bir takvim
/// günü ve bugünden (yerel) [anlikGunEnCok] gün sonrasına kadar olmalıdır;
/// davetli UUID biçiminde olmalıdır. Geçmeyen değer yok sayılır.
AnlikAnahtari anlikBaslangicCoz(
  String? gunMetni,
  String? davetli, {
  required DateTime simdi,
}) {
  DateTime? gun;
  final eslesme = gunMetni == null ? null : _gunBicimi.firstMatch(gunMetni);
  if (eslesme != null) {
    final yil = int.parse(eslesme.group(1)!);
    final ay = int.parse(eslesme.group(2)!);
    final gunNo = int.parse(eslesme.group(3)!);
    final aday = DateTime(yil, ay, gunNo);
    final yerel = simdi.toLocal();
    final bugun = DateTime(yerel.year, yerel.month, yerel.day);
    final sinir = DateTime(bugun.year, bugun.month, bugun.day + anlikGunEnCok);
    final gecerli = aday.year == yil && aday.month == ay && aday.day == gunNo;
    if (gecerli && !aday.isBefore(bugun) && !aday.isAfter(sinir)) gun = aday;
  }
  return (
    gun: gun,
    davetli: davetli != null && uuidBicimindeMi(davetli) ? davetli : null,
  );
}

/// [gun] için önerilen başlangıç (UTC): o gün [anlikVarsayilanSaat]:00;
/// bu an bir saatten yakınsa ya da geçtiyse bir sonraki tam saatten bir
/// saat sonrası.
DateTime anlikOnerilenBaslangic(DateTime gun, {required DateTime simdi}) {
  final yerel = simdi.toLocal();
  final oneri = DateTime(gun.year, gun.month, gun.day, anlikVarsayilanSaat);
  if (oneri.difference(yerel) >= const Duration(hours: 1)) {
    return oneri.toUtc();
  }
  final tamSaat = DateTime(yerel.year, yerel.month, yerel.day, yerel.hour);
  return tamSaat.add(const Duration(hours: 2)).toUtc();
}

/// Anlık etkinlik sihirbazı (ADR-0026): etkinlik sihirbazının kendisi,
/// tayfasız. Açılış değerleri ([AnlikAnahtari]) taslağa işlenir ama
/// "girilen" sayılmaz; kullanıcı bir şey değiştirmeden kapatırsa vazgeç
/// onayı sorulmaz.
class AnlikSihirbazNotifier extends EtkinlikSihirbaziNotifier {
  AnlikSihirbazNotifier(this.baslangic)
    : super((tayfaId: null, duzenlenen: null));

  final AnlikAnahtari baslangic;

  @override
  EtkinlikTaslagi build() {
    var taslak = super.build();
    final gun = baslangic.gun;
    if (gun != null) {
      final bas = anlikOnerilenBaslangic(gun, simdi: _simdi);
      taslak = taslak.kopya(baslangic: bas, bitis: bas.add(varsayilanSure));
    }
    final davetli = baslangic.davetli;
    if (davetli != null) taslak = taslak.kopya(davetliler: [davetli]);
    _ilk = taslak;
    return taslak;
  }
}

/// Başlangıç seçilince önerilen süre.
const Duration varsayilanSure = Duration(hours: 2);

String _kisalt(String metin, int enCok) {
  final harfler = metin.runes;
  if (harfler.length <= enCok) return metin;
  return String.fromCharCodes(harfler.take(enCok));
}

/// Anlık etkinlik sihirbazının notifier'ı (ADR-0026); sihirbaz kapanınca
/// bırakılır.
final anlikSihirbazProvider = NotifierProvider.autoDispose
    .family<EtkinlikSihirbaziNotifier, EtkinlikTaslagi, AnlikAnahtari>(
      AnlikSihirbazNotifier.new,
      name: 'anlikSihirbazProvider',
    );

/// Sihirbazın notifier'ı; sihirbaz kapanınca bırakılır ve yeniden açılınca
/// yeni bir `client_request_id` üretilir.
final etkinlikSihirbaziProvider = NotifierProvider.autoDispose
    .family<EtkinlikSihirbaziNotifier, EtkinlikTaslagi, SihirbazAnahtari>(
      EtkinlikSihirbaziNotifier.new,
      name: 'etkinlikSihirbaziProvider',
    );
