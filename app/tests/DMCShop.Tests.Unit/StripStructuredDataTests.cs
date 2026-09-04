using DMCShop.Search;
using FluentAssertions;

namespace DMCShop.Tests.Unit;

/// <summary>
/// Modelin cevabindan urun numarasi ve fiyat temizleniyor mu. Ornekler canli
/// demoda gercekten uretilmis cevaplardan alindi.
/// </summary>
public class StripStructuredDataTests
{
    [Theory]
    [InlineData("#1083 Kahve Demleme French Press — Bu ürün sıcak kahve için idealdir.",
                "Kahve Demleme French Press — Bu ürün sıcak kahve için idealdir.")]
    [InlineData("#1072 Kazak Yün Boğazlı — Giyim — 920,00 ₺.", "Kazak Yün Boğazlı — Giyim.")]
    [InlineData("#1022 Logitech MX Master 3S — 3.200,00 ₺.", "Logitech MX Master 3S.")]
    public void Urun_numarasi_ve_fiyat_temizleniyor(string input, string expected)
    {
        RagAssistantService.StripStructuredData(input).Should().Be(expected);
    }

    [Fact]
    public void Duz_cumleye_dokunmuyor()
    {
        const string text = "Logitech MX Master 3S öneriyorum. Ergonomik ve uzun kullanıma uygun.";
        RagAssistantService.StripStructuredData(text).Should().Be(text);
    }

    [Fact]
    public void Bos_metin_bos_kaliyor()
    {
        RagAssistantService.StripStructuredData("").Should().BeEmpty();
    }
}
