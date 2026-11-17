# Sürüm çıkarma

Dal modeli ve gerekçeler: [ADR-0029](../adr/0029-dal-modeli-dev-main-ve-surum.md).
Özet: iş PR'ları `dev`'e squash ile birleşir; `main` prod'dur ve yalnızca
`dev` → `main` sürüm PR'ıyla (merge commit) ilerler. `main`'e her birleşme
Play kapalı test kanalına yüklenir, site değiştiyse tayfam.app yayınlanır ve
`vX.Y.Z` etiketi otomatik atılır.

## Kim

Mimari oturumu hazırlar ve birleştirir; **birleştirmeden önce platform
sahibinin sohbette onayı gerekir.** Platform sahibinin elle bir şey yapması
gerekmez.

## Adımlar

1. **Sürüm numarası PR'ı (`dev`'e).**
   - Dal: `chore/surum-X.Y.Z`. Başlık: `chore(surum): X.Y.Z`.
   - `pubspec.yaml`: `version: X.Y.Z+1` (`+N` yalnızca yereldir; yayında
     versionCode CI'da hesaplanır, artırmak gerekmez).
     - Kullanıcıya görünen yeni özellik → `Y` artar, `Z` sıfırlanır.
     - Yalnızca düzeltme → `Z` artar.
     - `X` genel yayına kadar `0`.
   - `play/surum-notu.tr-TR.txt`: Play'deki "Yenilikler" metni (tr-TR, en
     çok 500 karakter, `#` satırları gitmez; biçim:
     [`docs/surum-notu-sablonu.md`](../surum-notu-sablonu.md)).
   - CI yeşil olunca `dev`'e squash ile birleşir.
2. **Sürüm PR'ı (`dev` → `main`).**
   - Başlık: `release: X.Y.Z`. Açıklama: `dev`'de son sürümden bu yana
     birleşen PR'ların listesi (`git log --first-parent --oneline
     origin/main..origin/dev`), hassas alana dokunanlar ayrıca işaretli.
   - CI'da `kaynak-dal` (baş dal `dev` mi) ve `surum-numarasi`
     (`vX.Y.Z` yeni mi, öncekinden büyük mü) dahil bütün kontroller yeşil
     olmalı.
3. **Onay.** Platform sahibine sohbette sürüm numarasını ve değişiklik
   listesini gönder; onay gelince PR açıklamasına "Sohbette onaylandı
   (tarih)" yaz.
4. **Birleştir: "Create a merge commit".** Squash ya da rebase değil
   (ADR-0029 §2); `main` kural seti zaten yalnızca merge commit'e izin
   verir.
5. **İzle.** Actions → "Yayın (Play + sürüm etiketi)":
   - `surum` → `aab` → `yukle` → `etiket` yeşil olmalı. İş özetinde
     versionName, versionCode, yükleme sertifikası parmak izi ve etiket var.
   - `site/` değiştiyse "Site yayını" da çalışır.
   - `vX.Y.Z` etiketi Tags'te görünür.

## Bir şey ters giderse

- **`surum-numarasi` kırmızı:** `pubspec.yaml` artırılmamış ya da geri
  gitmiş. Adım 1'deki PR'ı `dev`'e birleştir; sürüm PR'ı kendiliğinden
  güncellenir.
- **`kaynak-dal` kırmızı:** PR `dev`'den değil. Kapat; değişikliği `dev`'e
  aç.
- **`aab` ya da `yukle` düştü:** etiket atılmaz. Hatayı gider (iş akışı ya
  da Play tarafı); "Re-run failed jobs" aynı commit'i aynı versionCode'la
  dener. Kod değişikliği gerekiyorsa `dev`'e PR + yeni sürüm numarası + yeni
  sürüm PR'ı.
- **Play "versionCode zaten kullanıldı" diyor:** bu commit önceden
  yüklenmiş; yeniden çalıştırmaya gerek yok. Etiket eksikse yalnızca
  `etiket` işini yeniden çalıştır.
- **Yanlış sürüm yayına çıktı:** etiketler silinmez ve taşınmaz. Düzeltme
  `dev`'e girer ve yeni bir yama sürümüyle (`Z+1`) çıkar. Play'de kanaldaki
  sürüm Play Console'dan durdurulabilir (platform sahibi).

## Yapılmayanlar

- `main`'e doğrudan push, `dev` dışından `main`'e PR, sıcak düzeltme dalı.
- Elle `v*` etiketi atmak (hiçbir şey tetiklemez, sürüm sırasını bozar).
- `pubspec.yaml`'ı CI'a yazdırmak, PAT eklemek.
