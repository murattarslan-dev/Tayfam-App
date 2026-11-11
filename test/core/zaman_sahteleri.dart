import 'dart:async';

/// Elle çalıştırılan sahte zamanlayıcı: kurulan işler [calistir] ile
/// çalışır; gerçek bekleme yoktur.
final class SahteZamanlayici {
  final List<SahteTimer> kurulan = [];

  /// `ZamanlayiciKurucu` olarak verilir.
  Timer kur(Duration sure, void Function() gorev) {
    final t = SahteTimer(sure, gorev);
    kurulan.add(t);
    return t;
  }

  /// Etkin zamanlayıcılar.
  List<SahteTimer> get etkin => [
    for (final t in kurulan)
      if (t.isActive) t,
  ];

  /// [sure]'li etkin zamanlayıcıları çalıştırır (verilmezse hepsini).
  void calistir([Duration? sure]) {
    for (final t in etkin) {
      if (sure == null || t.sure == sure) t.calistir();
    }
  }
}

/// [SahteZamanlayici]'nın kurduğu zamanlayıcı.
final class SahteTimer implements Timer {
  SahteTimer(this.sure, this._is);

  final Duration sure;
  final void Function() _is;
  bool _etkin = true;

  void calistir() {
    if (!_etkin) return;
    _etkin = false;
    _is();
  }

  @override
  void cancel() => _etkin = false;

  @override
  bool get isActive => _etkin;

  @override
  int get tick => _etkin ? 0 : 1;
}
