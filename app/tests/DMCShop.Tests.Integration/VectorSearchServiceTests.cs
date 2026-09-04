using DMCShop.Data;
using DMCShop.Search;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

namespace DMCShop.Tests.Integration;

/// <summary>
/// VectorSearchService'in siralama mantigini gercek SQL Server 2025 uzerinde
/// dogrular. Embedding saglayicisi sahte ve deterministik, yani olculen sey
/// model kalitesi degil servisin kendi davranisi.
///
/// Kurgu, 4 Eylul 2026'da canli demoda yasanan durumu taklit ediyor:
///   - "kazak" sorgusu hem anlamsal olarak yakin hem adinda gecen urunu bulmali
///   - kelime ortusmesi olmayan sorguda hibrit ile saf vektor ayni sonucu verir
/// </summary>
[Collection(nameof(SqlServer2025Collection))]
public sealed class VectorSearchServiceTests(SqlServer2025Fixture db) : IAsyncLifetime
{
    // Eksenler: 10 = kislik giyim, 20 = mutfak, 30 = alakasiz
    private static readonly float[] KislikSorgu = SahteEmbeddingProvider.Eksen(10);
    private static readonly float[] MutfakSorgu = SahteEmbeddingProvider.Eksen(20);

    private VectorSearchService servis = default!;
    private DMCShopDbContext ctx = default!;

    public async Task InitializeAsync()
    {
        await db.ExecuteAsync(AramaSemasi.Sema);
        await db.ExecuteAsync("""
            IF OBJECT_ID('vector.product_embedding') IS NOT NULL DROP TABLE vector.product_embedding;
            IF OBJECT_ID('shop.product')             IS NOT NULL DROP TABLE shop.product;
            IF OBJECT_ID('shop.product_category')    IS NOT NULL DROP TABLE shop.product_category;
            """);
        await db.ExecuteAsync(AramaSemasi.Tablolar);
        await db.ExecuteAsync("""
            INSERT INTO shop.product_category (category_id, name)
            VALUES (1, N'Giyim'), (2, N'Ev');
            """);

        // 1: anlamsal olarak kislik, adinda "kazak" geciyor
        await AramaSemasi.UrunEkleAsync(db.ConnectionString, 1, "GY-001", "Kazak Yün Boğazlı",
            "Merinos yünü boğazlı kazak", 920m, 1,
            SahteEmbeddingProvider.Eksen(10), "Kazak Yün Boğazlı. Giyim. Merinos yünü kazak.");

        // 2: anlamsal olarak kislik ama adinda "kazak" yok
        await AramaSemasi.UrunEkleAsync(db.ConnectionString, 2, "GY-002", "Atkı Yün Gri",
            "Yün atkı", 240m, 1,
            SahteEmbeddingProvider.Karisim(10, 0.96f, 30, 0.28f), "Atkı Yün Gri. Giyim. Yün atkı.");

        // 3: anlamsal olarak uzak ama adinda "kazak" geciyor.
        //    Saf vektorde bulunamaz, keyword rerank'in yakalamasi gereken urun.
        await AramaSemasi.UrunEkleAsync(db.ConnectionString, 3, "EV-001", "Kazak Desenli Yastık",
            "Kazak deseni işlemeli yastık", 180m, 2,
            SahteEmbeddingProvider.Eksen(30), "Kazak Desenli Yastık. Ev. Kazak deseni işlemeli.");

        // 4: mutfak, her iki sorgudan da uzak
        await AramaSemasi.UrunEkleAsync(db.ConnectionString, 4, "EV-002", "French Press Cam",
            "600 ml cam french press", 450m, 2,
            SahteEmbeddingProvider.Eksen(20), "French Press Cam. Ev. Cam french press.");

        await db.ExecuteAsync(AramaSemasi.Indeks);

        var opts = new DbContextOptionsBuilder<DMCShopDbContext>()
            .UseSqlServer(db.ConnectionString).Options;
        ctx = new DMCShopDbContext(opts);

        servis = new VectorSearchService(ctx, new SahteEmbeddingProvider(
            new Dictionary<string, float[]>
            {
                ["kazak"]           = KislikSorgu,
                ["kışlık bir şey"]  = KislikSorgu,
                ["kahve demleme"]   = MutfakSorgu,
            }));
    }

    public Task DisposeAsync() { ctx.Dispose(); return Task.CompletedTask; }

    [Fact]
    public async Task Saf_vektor_aramasi_mesafeye_gore_siraliyor()
    {
        var sonuc = await servis.SearchAsync("kışlık bir şey", topK: 3);

        sonuc.Should().NotBeEmpty();
        sonuc[0].ProductId.Should().Be(1, "sorgu vektoru bu urunle birebir ayni");
        sonuc.Select(h => h.Distance).Should().BeInAscendingOrder();
    }

    [Fact]
    public async Task Kelime_ortusmesi_olmayan_sorguda_hibrit_ile_saf_vektor_ayni()
    {
        // Canli demoda olculen davranis: "kahvaltı" gibi katalogda gecmeyen bir
        // kelimede rerank devreye giremiyor, geriye yalniz vektor kalitesi kaliyor.
        var saf    = await servis.SearchAsync("kahve demleme", topK: 3);
        var hibrit = await servis.HybridSearchAsync("kahve demleme", topK: 3);

        hibrit.Select(h => h.ProductId).Should().Equal(saf.Select(h => h.ProductId));
    }

    [Fact]
    public async Task Hibrit_arama_vektorde_uzak_ama_adinda_gecen_urunu_yukari_cekiyor()
    {
        // 3 numarali urun anlamsal olarak tamamen alakasiz bir eksende duruyor;
        // yalnizca adindaki "Kazak" kelimesi sayesinde listeye girmeli.
        var saf    = await servis.SearchAsync("kazak", topK: 2);
        var hibrit = await servis.HybridSearchAsync("kazak", topK: 3);

        saf.Select(h => h.ProductId).Should().NotContain(3,
            "saf vektor bu urunu bulamaz, kurgunun on kosulu bu");
        hibrit.Select(h => h.ProductId).Should().Contain(3,
            "keyword rerank ad eslesmesini yakalamali");
    }

    [Fact]
    public async Task Bos_sorgu_bos_liste_donduruyor()
    {
        (await servis.SearchAsync("   ")).Should().BeEmpty();
        (await servis.HybridSearchAsync("   ")).Should().BeEmpty();
    }
}
