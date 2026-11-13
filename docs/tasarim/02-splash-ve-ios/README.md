# Splash animasyonu ve iOS girişi

## Ekranlar

| Dosya | Ne gösteriyor |
| --- | --- |
| [`Splash-Animasyon.dc.html`](Splash-Animasyon.dc.html) | Splash · animasyon |
| [`Giris-iOS.dc.html`](Giris-iOS.dc.html) | Giriş · iOS açık |
| [`Giris-iOS-Koyu.dc.html`](Giris-iOS-Koyu.dc.html) | Giriş · iOS koyu |

## Kararlar ve notlar

Animasyon ~850 ms: önce mor L yerine oturur (0 ms), sonra mango (80 ms), nar (140 ms) ve turkuaz (200 ms) bloklar dışarıdan hafif taşarak gelir; her blok 420 ms. Yazı 520 ms'de 300 ms'lik bir yükselmeyle belirir. Android 12+: blok hareketi SplashScreen'in animasyonlu ikonu (AnimatedVectorDrawable, 1000 ms sınırı) olarak; iOS: launch ekranı statik, aynı hareket Flutter'ın ilk karesinde oynar. Hareketi azalt açıksa animasyon yok, logo doğrudan görünür.

iOS'ta Apple ile giriş, Google'dan en az onun kadar görünür olmalı; bu yüzden üstte. Apple simgesi yer tutucu: kodda Apple'ın kendi düğmesi (ASAuthorizationAppleIDButton ya da sign_in_with_apple paketinin yerel düğmesi) kullanılmalı. Açık temada siyah, koyu temada beyaz stil.
