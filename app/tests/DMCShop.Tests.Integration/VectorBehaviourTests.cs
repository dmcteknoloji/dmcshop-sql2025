using FluentAssertions;

namespace DMCShop.Tests.Integration;

/// <summary>
/// README'de "SQL Server 2025'te yakalanan nuanslar" basligi altinda anlatilan
/// davranislari gercek motora karsi dogrular. Bir sonraki CU bunlardan birini
/// degistirirse test kirmizi olur ve dokumanin bayatladigini haber verir.
/// </summary>
[Collection(nameof(SqlServer2025Collection))]
public sealed class VectorBehaviourTests(SqlServer2025Fixture db)
{
    private const string Table = "dbo.emb_test";

    private async Task ResetAsync(bool withIndex)
    {
        await db.ExecuteAsync($"DROP TABLE IF EXISTS {Table};");
        await db.ExecuteAsync($"CREATE TABLE {Table} (id INT NOT NULL PRIMARY KEY, v VECTOR(4) NULL);");
        await db.ExecuteAsync($"""
            INSERT INTO {Table} (id, v) VALUES
                (1, '[1,0,0,0]'), (2, '[0,1,0,0]'), (3, '[0,0,1,0]'),
                (4, '[0.9,0.1,0,0]'), (5, '[0,0,0,1]');
            """);

        if (withIndex)
        {
            await db.ExecuteAsync($"""
                CREATE VECTOR INDEX vix_emb_test ON {Table} (v)
                WITH (METRIC = 'cosine', TYPE = 'DiskANN');
                """);
        }
    }

    [Fact]
    public async Task Vector_tipi_preview_bayragiyla_kullanilabiliyor()
    {
        await ResetAsync(withIndex: false);

        var count = await db.ScalarAsync<int>($"SELECT COUNT(*) FROM {Table} WHERE v IS NOT NULL;");

        count.Should().Be(5);
    }

    [Theory]
    [InlineData("INSERT INTO dbo.emb_test (id, v) VALUES (6, '[0,0,0.5,0.5]');")]
    [InlineData("UPDATE dbo.emb_test SET v = '[0.8,0.2,0,0]' WHERE id = 4;")]
    [InlineData("DELETE FROM dbo.emb_test WHERE id = 5;")]
    public async Task DiskANN_indeksi_varken_hicbir_DML_calismiyor(string dml)
    {
        await ResetAsync(withIndex: true);

        var error = await db.CaptureErrorAsync(dml);

        error.Should().NotBeNull("vector index varken DML reddedilmeli");
        error!.Number.Should().Be(42231);
    }

    [Fact]
    public async Task Indeks_dusurulunce_DML_yeniden_calisiyor()
    {
        await ResetAsync(withIndex: true);
        await db.ExecuteAsync($"DROP INDEX vix_emb_test ON {Table};");

        var error = await db.CaptureErrorAsync(
            $"INSERT INTO {Table} (id, v) VALUES (6, '[0,0,0.5,0.5]');");

        error.Should().BeNull();
        (await db.ScalarAsync<int>($"SELECT COUNT(*) FROM {Table};")).Should().Be(6);
    }

    [Fact]
    public async Task Vector_uzerinde_AVG_aggregate_yok()
    {
        await ResetAsync(withIndex: false);

        var error = await db.CaptureErrorAsync($"SELECT AVG(v) FROM {Table};");

        // Centroid'i .NET tarafinda hesaplamamizin sebebi bu.
        error.Should().NotBeNull();
        error!.Number.Should().Be(8117);
    }

    [Fact]
    public async Task VECTOR_SEARCH_CTE_icinde_calisiyor_ve_TOP_N_kadar_donuyor()
    {
        await ResetAsync(withIndex: true);

        var count = await db.ScalarAsync<int>($"""
            DECLARE @q VECTOR(4) = '[1,0,0,0]';
            WITH hits AS (
                SELECT * FROM VECTOR_SEARCH(
                    TABLE = {Table}, COLUMN = v, SIMILAR_TO = @q,
                    METRIC = 'cosine', TOP_N = 3)
            )
            SELECT COUNT(*) FROM hits;
            """);

        count.Should().Be(3);
    }

    [Fact]
    public async Task VECTOR_SEARCH_ciktisina_CTE_olmadan_JOIN_atilamiyor()
    {
        await ResetAsync(withIndex: true);

        var error = await db.CaptureErrorAsync($"""
            DECLARE @q VECTOR(4) = '[1,0,0,0]';
            SELECT h.id
            FROM VECTOR_SEARCH(
                TABLE = {Table}, COLUMN = v, SIMILAR_TO = @q,
                METRIC = 'cosine', TOP_N = 3) AS h
            JOIN {Table} e ON e.id = h.id;
            """);

        // sql/20-vector-search.sql'deki CTE sarmalayicisinin sebebi bu.
        error.Should().NotBeNull();
        error!.Number.Should().Be(207);   // Invalid column name
    }

    [Fact]
    public async Task En_yakin_komsu_dogru_sirada_donuyor()
    {
        await ResetAsync(withIndex: true);

        var first = await db.ScalarAsync<int>($"""
            DECLARE @q VECTOR(4) = '[1,0,0,0]';
            WITH hits AS (
                SELECT * FROM VECTOR_SEARCH(
                    TABLE = {Table}, COLUMN = v, SIMILAR_TO = @q,
                    METRIC = 'cosine', TOP_N = 2)
            )
            SELECT TOP (1) id FROM hits ORDER BY distance;
            """);

        first.Should().Be(1, "sorgu vektoru id=1 ile birebir ayni");
    }
}
