using Microsoft.Data.SqlClient;

namespace DMCShop.Tests.Integration;

/// <summary>
/// Arama testleri icin en kucuk sema. Depodaki sql/ betiklerinin tamamini
/// kurmak yerine yalniz VectorSearchService'in sorguladigi tablolar acilir:
/// urun, kategori ve embedding.
/// </summary>
public static class AramaSemasi
{
    public const string Sema = """
        IF SCHEMA_ID('shop')   IS NULL EXEC('CREATE SCHEMA shop');
        IF SCHEMA_ID('vector') IS NULL EXEC('CREATE SCHEMA vector');
        """;

    public const string Tablolar = """
        CREATE TABLE shop.product_category (
            category_id INT           NOT NULL PRIMARY KEY,
            name        NVARCHAR(100) NOT NULL);

        CREATE TABLE shop.product (
            product_id     INT            NOT NULL PRIMARY KEY,
            sku            NVARCHAR(40)   NOT NULL,
            name           NVARCHAR(200)  NOT NULL,
            description_tr NVARCHAR(MAX)  NULL,
            price          DECIMAL(12,2)  NOT NULL,
            category_id    INT            NOT NULL
                REFERENCES shop.product_category(category_id));

        CREATE TABLE vector.product_embedding (
            product_id         INT           NOT NULL PRIMARY KEY
                REFERENCES shop.product(product_id),
            embedding_bge_1024 VECTOR(1024)  NULL,
            source_text        NVARCHAR(MAX) NOT NULL);
        """;

    public const string Indeks = """
        CREATE VECTOR INDEX vix_test ON vector.product_embedding (embedding_bge_1024)
        WITH (METRIC = 'cosine', TYPE = 'DiskANN');
        """;

    public static async Task UrunEkleAsync(
        string baglanti, int id, string sku, string ad, string aciklama,
        decimal fiyat, int kategoriId, float[] vektor, string kaynakMetin)
    {
        var literal = "[" + string.Join(",", vektor.Select(f =>
            f.ToString("R", System.Globalization.CultureInfo.InvariantCulture))) + "]";

        await using var conn = new SqlConnection(baglanti);
        await conn.OpenAsync();

        await using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = """
                INSERT INTO shop.product (product_id, sku, name, description_tr, price, category_id)
                VALUES (@id, @sku, @ad, @aciklama, @fiyat, @kat);
                INSERT INTO vector.product_embedding (product_id, embedding_bge_1024, source_text)
                VALUES (@id, CAST(@vek AS VECTOR(1024)), @kaynak);
                """;
            cmd.Parameters.AddWithValue("@id", id);
            cmd.Parameters.AddWithValue("@sku", sku);
            cmd.Parameters.AddWithValue("@ad", ad);
            cmd.Parameters.AddWithValue("@aciklama", aciklama);
            cmd.Parameters.AddWithValue("@fiyat", fiyat);
            cmd.Parameters.AddWithValue("@kat", kategoriId);
            cmd.Parameters.AddWithValue("@vek", literal);
            cmd.Parameters.AddWithValue("@kaynak", kaynakMetin);
            await cmd.ExecuteNonQueryAsync();
        }
    }
}
