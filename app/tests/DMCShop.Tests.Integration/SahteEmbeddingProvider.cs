using DMCShop.Domain.Abstractions;

namespace DMCShop.Tests.Integration;

/// <summary>
/// Testlerde Ollama'ya cikmadan calisan embedding saglayicisi.
///
/// Vektorler deterministik: her metin icin onceden verilmis bir sozluge bakar.
/// Boylece hangi urunun hangi sorguya yakin oldugu testin kendi kontrolunde
/// olur ve model kalitesi degil, servisin siralama mantigi olculur.
///
/// Name = "ollama" cunku VectorSearchService kolon adini saglayici adindan
/// seciyor (embedding_bge_1024).
/// </summary>
public sealed class SahteEmbeddingProvider(IReadOnlyDictionary<string, float[]> sozluk) : IEmbeddingProvider
{
    public string Name       => "ollama";
    public string ModelName  => "sahte-test-modeli";
    public int    Dimensions => 1024;

    public Task<float[]> EmbedAsync(string text, CancellationToken cancellationToken = default)
        => Task.FromResult(sozluk.TryGetValue(text, out var v) ? v : Sifir());

    public Task<IReadOnlyList<float[]>> EmbedBatchAsync(IReadOnlyList<string> texts, CancellationToken cancellationToken = default)
        => Task.FromResult<IReadOnlyList<float[]>>(
            texts.Select(t => sozluk.TryGetValue(t, out var v) ? v : Sifir()).ToList());

    /// <summary>Belirtilen eksende 1, digerlerinde 0 olan birim vektor.</summary>
    public static float[] Eksen(int indeks)
    {
        var v = new float[1024];
        v[indeks] = 1f;
        return v;
    }

    /// <summary>Iki ekseni verilen agirliklarla karistirir.</summary>
    public static float[] Karisim(int a, float agirlikA, int b, float agirlikB)
    {
        var v = new float[1024];
        v[a] = agirlikA;
        v[b] = agirlikB;
        return v;
    }

    private static float[] Sifir()
    {
        var v = new float[1024];
        v[1023] = 1f;   // tamamen sifir vektor cosine'de tanimsiz
        return v;
    }
}
