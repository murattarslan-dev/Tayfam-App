#!/usr/bin/env python3
# ADR-0021 §3: test/core/medya/ornekler/ altındaki metadata'lı JPEG örneklerini üretir.
# Kullanım: python3 tool/medya/ornek_jpeg_uret.py test/core/medya/ornekler (Pillow gerekir).
# Test fixture: metadata'lı JPEG'ler (sahte GPS; gerçek veri yok).
import io, struct, sys
from PIL import Image, ImageDraw
out = sys.argv[1]

def seg(marker, payload):
    return bytes([0xFF, marker]) + struct.pack('>H', len(payload) + 2) + payload

def build(progressive):
    im = Image.new('RGB', (64, 48), (200, 80, 40))
    d = ImageDraw.Draw(im); d.rectangle([10, 10, 40, 30], fill=(20, 120, 200))
    ex = Image.Exif()
    ex[0x0112] = 6  # Orientation: 90° CW
    ex[0x010F] = 'TAYFAM-SAHTE-URETICI'
    gps = {1: 'N', 2: (41.0, 2.0, 3.0), 3: 'E', 4: (29.0, 1.0, 2.0)}
    ex[0x8825] = gps
    bio = io.BytesIO()
    im.save(bio, 'JPEG', quality=80, exif=ex.tobytes(), progressive=progressive,
            icc_profile=b'\x00' * 128)
    b = bio.getvalue()
    assert b[:2] == b'\xff\xd8'
    xmp = seg(0xE1, b'http://ns.adobe.com/xap/1.0/\x00<x:xmpmeta>TAYFAM-SAHTE-XMP</x:xmpmeta>')
    iptc = seg(0xED, b'Photoshop 3.0\x008BIM\x04\x04\x00\x00\x00\x00\x00\x10TAYFAM-SAHTE-IPTC')
    mpf = seg(0xE2, b'MPF\x00II*\x00TAYFAM-SAHTE-MPF')
    com = seg(0xFE, b'TAYFAM-SAHTE-YORUM')
    jfxx = seg(0xE0, b'JFXX\x00\x10TAYFAM-SAHTE-JFXX')
    # JFIF + küçük resim (1x1 RGB)
    jfif = seg(0xE0, b'JFIF\x00\x01\x02\x00\x00\x01\x00\x01\x01\x01' + b'\xAB\xCD\xEF')
    # PIL'in kendi JFIF'ini kaldır (varsa) ve ekleri SOI'den sonra koy
    rest = b[2:]
    if rest[:2] == b'\xff\xe0':
        n = struct.unpack('>H', rest[2:4])[0]
        rest = rest[2 + n:]
    ikinci = bio.getvalue()  # MPF tarzı: EOI'den sonra ikinci resim
    return (b'\xff\xd8' + jfif + jfxx + xmp + iptc + mpf + com + rest
            + b'TAYFAM-SAHTE-SONEK' + ikinci)

open(out + '/metadata_temel.jpg', 'wb').write(build(False))
open(out + '/metadata_ilerlemeli.jpg', 'wb').write(build(True))
