# Güvenlik sıkılaştırma

Bu doküman, **demo amaçlı varsayılan ayarlardan** **production-benzeri sıkılaştırılmış**
bir kuruluma geçmek için yapılacak işleri listeler. Hepsi opsiyonel — workshop demosu
için varsayılanlar yeterlidir.

> Repo şu anda **private**. Public yapma kararı verilirse, aşağıdaki adımların 1-4 numarası
> *zorunlu* hale gelir.

---

## 1 — NSG: SSH'i kendi IP/32'e daralt

`infra/main.bicep` varsayılanı `allowedClientCidr = '*'` (dünyaya açık). SSH brute-force
riski içerir. Mevcut public IP'ni öğren ve daralt:

```bash
MY_IP="$(curl -s https://api.ipify.org)"
echo "${MY_IP}/32"

# Bicep parametresi olarak
DMCSHOP_ALLOWED_CIDR="${MY_IP}/32" ./infra/deploy.sh
```

Veya mevcut NSG'yi direkt güncelle:

```bash
az network nsg rule update \
    -g rg-dmcshop-demo \
    --nsg-name dmcshop-nsg \
    -n AllowSSH \
    --source-address-prefixes "${MY_IP}/32"
```

> HTTPS sertifikası eklendiğinde HTTP (80) kapatılabilir. Sertifika öncesi her ikisi açık.

---

## 2 — SA password rotation

Repo'da varsayılan parola **yok**. `scripts/sa-password.sh` ilk çalıştırmada
rastgele üretip `scripts/.env` içine (0600) yazar; Azure tarafında `infra/deploy.sh`
her dağıtımda yeni parola üretir.

```bash
# Yeni güçlü password
NEW_PW='$(openssl rand -base64 24 | tr -d "=+/" | head -c 20)A1!'
echo "${NEW_PW}"

# Container'da güncelle (down/up gerektirir — volume kalır)
docker compose -f scripts/docker-compose.yml down
# .env dosyasını güncelle: DMCSHOP_SA_PASSWORD=${NEW_PW}
docker compose -f scripts/docker-compose.yml up -d

# Hem mevcut SQL'de hem container env'inde güncel olmalı.
# İlk başlangıçtan sonra SA password kalıcı veritabanına yazılır;
# tekrar başlatma SP yeni değeri kullanır.
```

Azure VM'de: `.env` yerine `appsettings.Production.json` veya **Azure Key Vault**.

---

## 3 — Azure Key Vault entegrasyonu

Connection string + SA password + Azure OpenAI API key:

```bash
KV_NAME="kv-dmcshop-$(uuidgen | cut -c1-8)"
az keyvault create -g rg-dmcshop-demo -n "${KV_NAME}" -l westeurope

az keyvault secret set --vault-name "${KV_NAME}" --name SAPassword     --value "<güçlü>"
az keyvault secret set --vault-name "${KV_NAME}" --name OpenAIApiKey   --value "<key>"
az keyvault secret set --vault-name "${KV_NAME}" --name OpenAIEndpoint --value "https://..."
```

.NET tarafı `Azure.Extensions.AspNetCore.Configuration.Secrets` paketi + `IConfiguration`:

```csharp
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{Environment.GetEnvironmentVariable("KV_NAME")}.vault.azure.net/"),
    new DefaultAzureCredential());
```

VM Managed Identity üzerinden erişim — IAM rolü: "Key Vault Secrets User".

---

## 4 — TLS / HTTPS

[infra/caddy/README.md](caddy/README.md) içinde Caddy reverse proxy + Let's Encrypt
talimatı. Domain ihtiyacı var (`demo.dmcshop.dmcteknoloji.com` gibi A-record).

Self-signed alternatif (workshop için yeterli, tarayıcı uyarısı verir):
```bash
# Container içinde Kestrel HTTPS endpoint
# appsettings.json: Kestrel.Endpoints.Https sertifika referansı
# Veya Caddy self-signed mode
```

---

## 5 — Log retention

`vector.query_log` ve `ops.rest_call_log` sürekli büyür. **`sql/40-retention.sql`**
`ops.sp_purge_logs` proc'unu kurar. Günlük cron:

```bash
# crontab -e
0 3 * * * /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "${DMCSHOP_SA_PASSWORD}" -d dmcshop -Q "EXEC ops.sp_purge_logs @days = 90"
```

---

## 6 — Cost optimization: scheduled stop

`scripts/vm-schedule.sh start|stop` ile manuel veya GitHub Actions cron:

```yaml
# .github/workflows/vm-schedule.yml
on:
  schedule:
    - cron: '0 6 * * 1-5'    # hafta içi 06:00 UTC start
    - cron: '0 18 * * 1-5'   # hafta içi 18:00 UTC stop
jobs:
  toggle:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: |
          if [ "$(date -u +%H)" = "06" ]; then ./scripts/vm-schedule.sh start
          else ./scripts/vm-schedule.sh stop; fi
```

Maliyet düşüşü: B4ms 16h × 5 gün/hafta ≈ 80h/ay → ~$25/ay (eskiden ~$130/ay).

---

## 7 — Backup

VM içinde `crontab -e`:

```cron
0 2 * * *  /home/dmcshop/dmcshop-sql2025/scripts/backup.sh
```

`BACKUP_DIR=/backups`, `RETAIN_DAYS=7` env değişkenleriyle özelleştirilebilir.

Azure tarafı için **Azure Backup** veya **Azure SQL Managed Instance auto-backup** daha
sağlam — VM disk snapshot eklenebilir:
```bash
az snapshot create -g rg-dmcshop-demo -n dmcshop-vm-osdisk-snap-$(date +%Y%m%d) \
    --source $(az vm show -g rg-dmcshop-demo -n dmcshop-vm --query storageProfile.osDisk.managedDisk.id -o tsv)
```

---

## 8 — Container security

`scripts/docker-compose.yml`:
- ✅ `restart: unless-stopped` (eklendi)
- ⚠ Container root user — production için non-root user
- ⚠ `MSSQL_PID=Developer` — production için Enterprise lisansı

---

## 9 — Audit & monitoring

- **Application Insights** entegrasyonu: `services.AddApplicationInsightsTelemetry()`
- **Query Store**: `ALTER DATABASE dmcshop SET QUERY_STORE = ON` zaten açık — yavaş sorguları izle
- **vector.query_log** dashboard'u: hangi sorgular kaç kez geldi, ortalama latency

---

## 10 — Bağımlılık tarama

```bash
dotnet list package --outdated
dotnet list package --vulnerable
```

Azure Defender for Cloud → Container vulnerabilities.

## Sızmış varsayılan parola hakkında

Deponun ilk sürümlerinde kurulum betiklerinde sabit bir SA parolası vardı ve depo
herkese açık. Parola yedi commit'te, on dosyada geçti.

Durum ölçüldü ve şöyle kapatıldı:

- Parola **döndürüldü**. Kurulum artık her seferinde rastgele üretiyor
  (`scripts/sa-password.sh`, `infra/deploy.sh`), canlı sunucuda farklı bir değer
  kullanılıyor ve eski parolayla giriş denemesi reddediliyor. Ölçülerek doğrulandı.
- Bugünkü ağaçta parola metni **hiçbir dosyada geçmiyor**, açıklama satırlarında bile.
- Git **geçmişi yeniden yazılmadı**. Yazmak mevcut bütün klonları ve çatalları
  bozar, üstelik sızmış bir sırrı geçmişten silmek onu güvenli yapmaz: doğru
  karşılık döndürmektir ve döndürüldü.

Aynı durumla karşılaşırsanız sıra şudur: önce döndür, sonra ağaçtan temizle,
geçmişi yeniden yazmayı yalnızca sır hâlâ geçerliyse ve döndürülemiyorsa düşün.
