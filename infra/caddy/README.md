# Caddy reverse proxy — HTTPS

DMCShop'un Blazor uygulaması default `http://...:80` üzerinde çalışır. Bu klasör
**Caddy 2** ile otomatik HTTPS ekler. İki mod:

## 1 — Custom domain ile Let's Encrypt (önerilen, production)

Önkoşul:
- Domain DNS A-record: `demo.dmcshop.dmcteknoloji.com` → VM public IP
- NSG: 80 ve 443 dışarıya açık (port 80 Let's Encrypt HTTP-01 challenge için)

VM'de:
```bash
export DOMAIN=demo.dmcshop.dmcteknoloji.com
cd ~/dmcshop-sql2025
docker compose -f infra/caddy/docker-compose.yml up -d

# Otomatik sertifika almayı izle:
docker logs -f dmcshop-caddy
```

İlk başlangıçta ~30 saniye içinde sertifika alır, yenileme otomatik (her 60 günde bir).

## 2 — Self-signed (workshop / local)

DOMAIN set etmeden çalıştır:
```bash
docker compose -f infra/caddy/docker-compose.yml up -d
```

Tarayıcı "güvenli değil" uyarısı verir → "Detayları göster" → "yine de devam et".
Workshop demoları için yeterli ama gerçek paylaşım için Let's Encrypt'e geç.

## DMCShop ile birlikte çalıştırma

Caddy `network_mode: host` kullanır ve `host.docker.internal:80`'e proxy yapar. Bu:
- VM üzerinde: `dmcshop-web.service` systemd unit'i port 80'i dinler — Caddy direkt
  bu unit'e bağlanır
- Local docker'da: dmcshop-web Blazor'u 5295'te koşar, Caddyfile içindeki port güncellenir

VM için Caddy + systemd dmcshop-web çakışması:
1. Önce dmcshop-web'in port'unu 5000'e taşı:
   ```bash
   sudo systemctl edit dmcshop-web.service
   # [Service] Environment=ASPNETCORE_URLS=http://0.0.0.0:5000
   sudo systemctl restart dmcshop-web
   ```
2. Caddyfile'da `reverse_proxy host.docker.internal:5000` yap.
3. Caddy'i ayağa kaldır.

## Health check

```bash
curl -I https://demo.dmcshop.dmcteknoloji.com   # 200 + valid cert
echo | openssl s_client -connect demo.dmcshop.dmcteknoloji.com:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

## Geri al

```bash
docker compose -f infra/caddy/docker-compose.yml down -v
# NSG'de 443'ü tekrar kapatabilirsin (kullanılmıyor)
```
