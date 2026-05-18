using FluentAssertions;

namespace DMCShop.Tests.Unit;

/// <summary>
/// Senaryo 5 hibrit skor formülü:
///   hybrid = distance + 1 / (1 + social_count)
///   - distance küçük olmalı (vector yakınlık)
///   - social_count büyük olmalı (graph proof)
///   - hybrid küçük olan üst sırada
/// </summary>
public class HybridScoreTests
{
    [Fact]
    public void Vector_yakin_ve_yuksek_social__en_iyi_skor()
    {
        var s = HybridScore(distance: 0.1, social: 50);
        s.Should().BeLessThan(0.15);
    }

    [Fact]
    public void Vector_uzak_ve_dusuk_social__kotu_skor()
    {
        var s = HybridScore(distance: 0.8, social: 1);
        s.Should().BeGreaterThan(1.0);
    }

    [Fact]
    public void Social_0_iken_skor_distance_arti_1()
    {
        var s = HybridScore(distance: 0.3, social: 0);
        s.Should().BeApproximately(1.3, 0.001);
    }

    [Theory]
    [InlineData(0.10, 100, 0.20, 100)]   // distance daha iyi → 1 < 2
    [InlineData(0.20,  50, 0.20,  10)]   // social daha iyi → 1 < 2
    public void Karsilastirma_dogru_sirayi_uretir(double d1, int s1, double d2, int s2)
    {
        var first  = HybridScore(d1, s1);
        var second = HybridScore(d2, s2);
        first.Should().BeLessThan(second);
    }

    private static double HybridScore(double distance, int social)
        => distance + 1.0 / (1.0 + social);
}
