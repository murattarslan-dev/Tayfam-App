# Mimari

Tayfam istemcisi tek bir Flutter kod tabanıdır: Android, iOS ve tam web
sürümü. İlk hedef platform Android. Web sürümü `tayfam.app` adresinde,
Cloudflare Pages üzerinde yayınlanır.

İstemci yalnızca Tayfam-Api'nin gateway'iyle konuşur (dev:
`https://api-dev.tayfam.app`). Sözleşme Tayfam-Api reposundaki
`api/openapi/gateway.yaml`'dır; gerçek zamanlı iletişim `GET /v1/realtime`
WebSocket'iyle yapılır.

```
Flutter istemcisi (Android / iOS / web)
        │  HTTPS (REST, problem+json)  ·  WebSocket
        ▼
gateway ──gRPC──▶ identity · core · chat      (Tayfam-Api)
```

Bu belge mimari kararlar alındıkça genişler. Kararlar ve gerekçeleri:
[docs/adr/](docs/adr/README.md).
