# Sürüm notu şablonu

Play Console'da her sürümün "Bu sürümdeki yenilikler" alanına yazılır
(ADR-0018 §10, issue #71). Play bir dil için en fazla **500 karakter** kabul
eder. Metin Türkçe ve sen dilindedir; kullanıcı verisi, iç adres veya
teknik ayrıntı içermez.

## Sürüm hazırlığı

Adımlar [`docs/runbooks/surum-cikarma.md`](runbooks/surum-cikarma.md)'dedir
(ADR-0029). Not, `play/surum-notu.tr-TR.txt`'ye yazılır ve sürüm numarası
PR'ıyla `dev`'e girer; `main`'e birleşmede Play'e otomatik gider, etiket
otomatik atılır, `versionCode` CI'da hesaplanır.

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
