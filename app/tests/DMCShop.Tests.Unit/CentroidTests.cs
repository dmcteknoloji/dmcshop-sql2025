using FluentAssertions;

namespace DMCShop.Tests.Unit;

/// <summary>
/// PersonalizedRecommendService.Centroid — basit aritmetik ortalama.
/// SQL Server 2025 RTM'de VECTOR için AVG aggregate'i public yok; .NET'te
/// hesaplanır, string literal'e dönüştürülüp SQL'e geçirilir.
/// </summary>
public class CentroidTests
{
    [Fact]
    public void Tek_vektor__kendisi_centroid()
    {
        var v = new[] { 1.0f, 2.0f, 3.0f };
        Centroid(new() { v }).Should().BeEquivalentTo(v);
    }

    [Fact]
    public void Iki_vektor__ortalama()
    {
        var c = Centroid(new()
        {
            new[] { 0.0f, 0.0f },
            new[] { 1.0f, 1.0f }
        });
        c[0].Should().BeApproximately(0.5f, 1e-6f);
        c[1].Should().BeApproximately(0.5f, 1e-6f);
    }

    [Fact]
    public void Ortalama_negatifleri_de_kapsar()
    {
        var c = Centroid(new()
        {
            new[] { -1.0f, 2.0f },
            new[] {  1.0f, -2.0f },
            new[] {  0.0f, 0.0f }
        });
        c[0].Should().BeApproximately(0.0f, 1e-6f);
        c[1].Should().BeApproximately(0.0f, 1e-6f);
    }

    [Fact]
    public void Bos_liste__exception()
    {
        var act = () => Centroid(new List<float[]>());
        act.Should().Throw<ArgumentException>();
    }

    private static float[] Centroid(List<float[]> vectors)
    {
        if (vectors.Count == 0) throw new ArgumentException("vectors empty");
        var dim = vectors[0].Length;
        var sum = new double[dim];
        foreach (var v in vectors)
            for (var i = 0; i < dim; i++) sum[i] += v[i];
        var result = new float[dim];
        for (var i = 0; i < dim; i++) result[i] = (float)(sum[i] / vectors.Count);
        return result;
    }
}
