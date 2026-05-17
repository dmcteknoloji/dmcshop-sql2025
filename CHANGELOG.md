# Changelog

Bu projenin tüm önemli değişiklikleri burada izlenir. Format [Keep a Changelog](https://keepachangelog.com/) standardına göredir.

## [Unreleased]

### Eklendi (Milestone 1 — skeleton)
- Repo iskeleti: README, LICENSE (MIT), .gitignore, .editorconfig, global.json
- Directory.Build.props ve Directory.Packages.props (CPM)
- SQL schema: `shop`, `graph`, `vector`, `ops` (sql/00-04)
- .NET 10 solution + 7 src projesi (Domain, Data, Providers, Search, Api, Web, Cli) + 2 test projesi
- Docker compose: SQL Server 2025 + Ollama
- Bootstrap script: sqlcmd ile sql/ dosyalarını sırayla çalıştırır

## Roadmap

- **Milestone 2**: Senaryo 1 (semantic search) + Senaryo 4 (co-purchase) end-to-end
- **Milestone 3**: Senaryo 2 (RAG) + Senaryo 3 (fraud ring) + workshop akışı dökümanları
