# infra/ — Azure VM Deployment

DMCShop demo'sunu Azure'da tek bir VM üzerinde ayağa kaldırır. Local docker-compose ile **aynı stack**, sadece VM Ubuntu 24.04 LTS üzerinde çalışır.

## Önkoşullar

- Azure CLI (`az login` yapılmış, doğru subscription aktif)
- `rsync` (macOS/Linux'ta varsayılan)
- `jq`
- SSH erişimi 22'den dışarı

## Tek komutla deploy

```bash
./infra/deploy.sh
```

Sırayla şunları yapar:

1. `~/.ssh/dmcshop_ed25519` yoksa SSH key üretir
2. `rg-dmcshop-demo` Resource Group oluşturur
3. `main.bicep` deploy eder — VNet, NSG, Public IP, VM (B2ms Ubuntu 24.04)
4. cloud-init bitmesini bekler (~5-8 dk; Docker + .NET 10 + sqlcmd kurulur)
5. Repo'yu `rsync` ile VM'ye gönderir (`bin/`, `obj/`, `.git/` hariç)
6. Remote'ta `docker compose up` + `bootstrap.sh` + Ollama model pull + `dmcshop embed-products`
7. `dmcshop-web.service` systemd unit'ini başlatır (port 80)

Sonunda demo URL: `http://dmcshop-<hash>.germanywestcentral.cloudapp.azure.com`

İlk kurulum toplam ~15-20 dakika.

## Maliyet tahmini

- **VM (B2ms, Linux)**: ~$60/ay running. Pause edilirse sadece disk ~$10/ay.
- **Public IP (Static)**: ~$3/ay
- **Disk (64 GB Premium SSD)**: ~$10/ay
- **Toplam**: ~$70-75/ay continuous. Workshop bittiyse `teardown.sh` ile sıfırlanır.

## Kod değişikliklerini gönder

```bash
./infra/sync.sh
```

Sadece rsync + `dotnet build` + `systemctl restart dmcshop-web`. Bootstrap'a dokunmaz.

## Logları izle

```bash
ssh -i ~/.ssh/dmcshop_ed25519 dmcshop@<fqdn> 'sudo journalctl -u dmcshop-web -f'
```

## Tamamen sil

```bash
./infra/teardown.sh
```

`az group delete --yes --no-wait` çağırır; geri alınamaz.

## Güvenlik notları

- NSG default `*` (dünyaya açık). Production için `DMCSHOP_ALLOWED_CIDR=<ip>/32` env var ile daralt.
- SQL Server (1433) ve Ollama (11434) **container'da localhost only** — NSG'de açık değil.
- Blazor public 80 üzerinden HTTP (HTTPS yok). Workshop demo için yeterli; HTTPS için Caddy + Let's Encrypt sonraki iterasyonda eklenir.
- `MSSQL_SA_PASSWORD` script default'u zayıf — production'da `DMCSHOP_SA_PASSWORD=<güçlü>` ile override et.

## Dosyalar

| Dosya | Amaç |
|---|---|
| `main.bicep` | Tüm Azure kaynakları (tek dosya, modülsüz) |
| `cloud-init.yaml` | VM ilk boot hazırlığı: docker + .NET 10 + sqlcmd + systemd unit |
| `deploy.sh` | İlk kurulum — RG + Bicep + remote bootstrap |
| `sync.sh` | Sonraki güncellemeler — sadece kod + restart |
| `teardown.sh` | RG sil |
