# Sürüm notu şablonu

Play Console'da her sürümün "Bu sürümdeki yenilikler" alanına yazılır
(ADR-0018 §10, issue #71). Play bir dil için en fazla **500 karakter** kabul
eder. Metin Türkçe ve sen dilindedir; kullanıcı verisi, iç adres veya
teknik ayrıntı içermez.

## Sürüm hazırlığı

1. `pubspec.yaml` `version`'ını artır: `X.Y.Z+N`. `N` (Play `versionCode`)
   her yüklemede bir artar ve hiç geri gitmez.
2. Sürüm PR'ı birleşince `main`'de etiketi at: `git tag vX.Y.Z` ve
   `git push origin vX.Y.Z`. Etiket `version`'la eşleşmezse iş akışı durur.
3. "Sürüm" iş akışının artefaktındaki `.aab`'ı Play Console'a yükle ve
   aşağıdaki şablonla notu yaz.

## Şablon

```
<tr-TR>
Tayfam X.Y.Z
• Yeni: <bir cümle>
• İyileştirme: <bir cümle>
• Düzeltme: <bir cümle>
Geri bildirimini test grubuna iletebilirsin.
</tr-TR>
```

## Örnek (ilk dahili test)

```
<tr-TR>
Tayfam 0.1.0 – ilk dahili test
• Tayfalar, etkinlikler, duyurular, anketler ve soru-cevap
• Davet linkleri, arkadaşlık ve sohbet
Bir sorun görürsen test grubuna yazman yeterli.
</tr-TR>
```
