import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';

/// Bir kanal mesajının gösterilecek içeriği (Tayfam-Api ADR-0031 §1,
/// istemci ADR-0028 §1). Sunucudan gelen mesaj girdidir: türün beklenen
/// alanı yoksa ya da sınır dışındaysa [KanalIcerikBilinmeyen] olur.
@immutable
sealed class KanalIcerigi {
  const KanalIcerigi();
}

/// Metin mesajı.
final class KanalIcerikMetin extends KanalIcerigi {
  const KanalIcerikMetin(this.metin);

  final String metin;
}

/// Fotoğraf mesajı (`chat_photo` yüklemesi).
final class KanalIcerikFotograf extends KanalIcerigi {
  const KanalIcerikFotograf(this.uploadId);

  final String uploadId;
}

/// Paylaşılan yer.
final class KanalIcerikYer extends KanalIcerigi {
  const KanalIcerikYer(this.yer);

  final PaylasilanYer yer;
}

/// Tanınmayan tür ya da geçersiz alan; "Bu mesaj bu sürümde
/// gösterilemiyor".
final class KanalIcerikBilinmeyen extends KanalIcerigi {
  const KanalIcerikBilinmeyen();
}

/// [mesaj]'ın içeriği. Silinmiş mesajı çağıran ayrıca ele alır (alanları
/// yoktur).
KanalIcerigi kanalMesajIcerigi(ChannelMessage mesaj) {
  switch (mesaj.kind) {
    case ChannelMessageKind.text:
      final body = mesaj.body;
      return body == null
          ? const KanalIcerikBilinmeyen()
          : KanalIcerikMetin(body);
    case ChannelMessageKind.photo:
      final id = mesaj.photoUploadId;
      return id != null && uuidBicimindeMi(id)
          ? KanalIcerikFotograf(id)
          : const KanalIcerikBilinmeyen();
    case ChannelMessageKind.place:
      final p = mesaj.place;
      if (p == null) return const KanalIcerikBilinmeyen();
      final yer = PaylasilanYer(
        enlem: p.latitude,
        boylam: p.longitude,
        ad: p.name,
      );
      return yer.gecerliMi
          ? KanalIcerikYer(yer)
          : const KanalIcerikBilinmeyen();
    case ChannelMessageKind.unknown:
      return const KanalIcerikBilinmeyen();
  }
}
