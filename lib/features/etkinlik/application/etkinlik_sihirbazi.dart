import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/istek_kimligi.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_islemleri.dart';

/// Etkinlik oluşturmanın `client_request_id` üreticisi; testlerde sabit
/// değer verilir.
final etkinlikIstekKimligiProvider = Provider<String Function()>(
  (ref) => yeniIstekKimligi,
  name: 'etkinlikIstekKimligiProvider',
);

/// Sihirbazın anahtarı: tayfa ve (düzenlemede) düzenlenen etkinlik.
typedef SihirbazAnahtari = ({String tayfaId, Event? duzenlenen});

/// Etkinlik oluşturma ve düzenleme sihirbazı (ADR-0015 §3): tür → başlık,
/// açıklama, başlangıç, bitiş → yer → türe özel alanlar, kontenjan ve
/// tekrar.
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

  /// Sihirbazın ilk adımı: oluşturmada tür, düzenlemede başlık ve zaman.
  int get ilkAdim => duzenleme ? 1 : 0;

  @override
  EtkinlikTaslagi build() {
    final kimlik = ref.read(etkinlikIstekKimligiProvider)();
    final eski = anahtar.duzenlenen;
    return eski == null
        ? EtkinlikTaslagi(istekKimligi: kimlik)
        : duzenlemeTaslagi(eski, kimlik);
  }

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

  /// Türü seçer (yalnızca oluşturmada).
  void turSec(EventType tur) {
    if (_kilitli || duzenleme || tur == EventType.unknown) return;
    _ayarla(state.kopya(tur: tur));
  }

  void baslikAyarla(String baslik) {
    if (_kilitli) return;
    _ayarla(state.kopya(baslik: baslik));
  }

  void aciklamaAyarla(String aciklama) {
    if (_kilitli) return;
    _ayarla(state.kopya(aciklama: aciklama));
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
    if (_kilitli || duzenleme) return;
    _ayarla(state.kopya(tekrar: tekrar));
  }

  /// Türe özel alanlar.
  void ayrintiAyarla(TurAyrintisi ayrinti) {
    if (_kilitli) return;
    _ayarla(state.kopya(ayrinti: ayrinti, ayrintiDegisti: true));
  }

  /// Sonraki adıma geçer; adımda hata varsa geçmez ve hatalar gösterilir.
  /// Son adımda bir şey yapmaz ([gonder] kullanılır).
  void ileri() {
    if (_kilitli) return;
    final hatalar = _hatalar(state.adim, state);
    if (hatalar.isNotEmpty) {
      state = state.kopya(hatalar: hatalar);
      return;
    }
    if (state.adim >= etkinlikAdimSayisi - 1) return;
    state = state.kopya(adim: state.adim + 1, hatalar: const {});
  }

  /// Önceki adıma döner; ilk adımda `false` döner (sihirbaz kapanabilir).
  bool geri() {
    if (_kilitli || state.adim <= ilkAdim) return false;
    state = state.kopya(adim: state.adim - 1, hatalar: const {});
    return true;
  }

  /// Etkinliği oluşturur ya da düzenler. Hatalı adım varsa o adıma dönülür.
  /// Sürerken ikinci çağrı yok sayılır; tekrar denemede aynı
  /// `client_request_id` gönderilir.
  Future<void> gonder() async {
    final mevcut = state;
    if (_kilitli) return;
    for (var adim = ilkAdim; adim < etkinlikAdimSayisi; adim++) {
      final hatalar = _hatalar(adim, mevcut);
      if (hatalar.isNotEmpty) {
        state = mevcut.kopya(adim: adim, hatalar: hatalar);
        return;
      }
    }
    final islemler = ref.read(etkinlikIslemleriProvider);
    final tayfaId = anahtar.tayfaId;
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
}

/// Başlangıç seçilince önerilen süre.
const Duration varsayilanSure = Duration(hours: 2);

String _kisalt(String metin, int enCok) {
  final harfler = metin.runes;
  if (harfler.length <= enCok) return metin;
  return String.fromCharCodes(harfler.take(enCok));
}

/// Sihirbazın notifier'ı; sihirbaz kapanınca bırakılır ve yeniden açılınca
/// yeni bir `client_request_id` üretilir.
final etkinlikSihirbaziProvider = NotifierProvider.autoDispose
    .family<EtkinlikSihirbaziNotifier, EtkinlikTaslagi, SihirbazAnahtari>(
      EtkinlikSihirbaziNotifier.new,
      name: 'etkinlikSihirbaziProvider',
    );
