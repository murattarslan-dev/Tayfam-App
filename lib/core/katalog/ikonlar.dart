import 'package:flutter/material.dart';

/// Katalogdaki `icon` anahtarlarının sabit ikon haritası (ADR-0024 §2).
///
/// - Anahtarlar Material Symbols adlarıdır; ikonlar uygulamaya gömülüdür,
///   ağdan ikon yüklenmez.
/// - Haritaya yeni ikon eklemek sürüm ister. Tayfam-Api platform panelinin
///   ikon listesi bu haritadaki anahtarlarla aynı olmalıdır; anahtar
///   listesini `tool/katalog_ikonlari` yazar ve karşılaştırır.
/// - Her satır tek bir `'anahtar': Icons.ad,` çiftidir (araç bu biçimi
///   okur).
const Map<String, IconData> katalogIkonlari = {
  'account_balance': Icons.account_balance,
  'agriculture': Icons.agriculture,
  'anchor': Icons.anchor,
  'auto_awesome': Icons.auto_awesome,
  'auto_stories': Icons.auto_stories,
  'bakery_dining': Icons.bakery_dining,
  'bloodtype': Icons.bloodtype,
  'brush': Icons.brush,
  'build': Icons.build,
  'cabin': Icons.cabin,
  'calculate': Icons.calculate,
  'calendar_month': Icons.calendar_month,
  'camping': Icons.cabin,
  'casino': Icons.casino,
  'celebration': Icons.celebration,
  'cleaning_services': Icons.cleaning_services,
  'code': Icons.code,
  'cruelty_free': Icons.cruelty_free,
  'directions_bike': Icons.directions_bike,
  'directions_car': Icons.directions_car,
  'directions_run': Icons.directions_run,
  'diversity_3': Icons.diversity_3,
  'downhill_skiing': Icons.downhill_skiing,
  'eco': Icons.eco,
  'edit': Icons.edit,
  'emoji_events': Icons.emoji_events,
  'event': Icons.event,
  'extension': Icons.extension,
  'favorite': Icons.favorite,
  'festival': Icons.festival,
  'fitness_center': Icons.fitness_center,
  'flag': Icons.flag,
  'forest': Icons.forest,
  'garage': Icons.garage,
  'grass': Icons.grass,
  'groups': Icons.groups,
  'handshake': Icons.handshake,
  'hiking': Icons.hiking,
  'history_edu': Icons.history_edu,
  'kayaking': Icons.kayaking,
  'landscape': Icons.landscape,
  'lightbulb': Icons.lightbulb,
  'local_dining': Icons.local_dining,
  'local_florist': Icons.local_florist,
  'map': Icons.map,
  'menu_book': Icons.menu_book,
  'mic': Icons.mic,
  'museum': Icons.museum,
  'music_note': Icons.music_note,
  'nightlight': Icons.nightlight,
  'palette': Icons.palette,
  'park': Icons.park,
  'pets': Icons.pets,
  'phishing': Icons.phishing,
  'photo_camera': Icons.photo_camera,
  'pool': Icons.pool,
  'quiz': Icons.quiz,
  'recycling': Icons.recycling,
  'restaurant': Icons.restaurant,
  'sailing': Icons.sailing,
  'school': Icons.school,
  'science': Icons.science,
  'scuba_diving': Icons.scuba_diving,
  'self_improvement': Icons.self_improvement,
  'snowboarding': Icons.snowboarding,
  'soup_kitchen': Icons.soup_kitchen,
  'spa': Icons.spa,
  'sports': Icons.sports,
  'sports_basketball': Icons.sports_basketball,
  'sports_esports': Icons.sports_esports,
  'sports_soccer': Icons.sports_soccer,
  'sports_tennis': Icons.sports_tennis,
  'sports_volleyball': Icons.sports_volleyball,
  'star': Icons.star,
  'surfing': Icons.surfing,
  'terrain': Icons.terrain,
  'theater_comedy': Icons.theater_comedy,
  'timer': Icons.timer,
  'tour': Icons.tour,
  'translate': Icons.translate,
  'two_wheeler': Icons.two_wheeler,
  'videogame_asset': Icons.videogame_asset,
  'volunteer_activism': Icons.volunteer_activism,
  'water': Icons.water,
};

/// Haritada olmayan anahtarların ve henüz gelmemiş kataloğun genel ikonu.
const IconData katalogGenelIkonu = Icons.event;

/// [anahtar]'ın ikonu. Bilinmeyen anahtar → [ilgiAlaniIkonu] anahtarının
/// ikonu → genel ikon (ADR-0024 §2).
IconData katalogIkonu(String? anahtar, {String? ilgiAlaniIkonu}) =>
    katalogIkonlari[anahtar] ??
    katalogIkonlari[ilgiAlaniIkonu] ??
    katalogGenelIkonu;
