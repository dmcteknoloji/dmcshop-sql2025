using FluentAssertions;

namespace DMCShop.Tests.Unit;

/// <summary>
/// ProductImage bileşeninin monogram üreteci — iki kelimenin baş harfleri,
/// tek kelimede ilk iki harf. Workshop demo'sundaki placeholder görsellerinin
/// tutarlı görünmesi için kontrat.
/// </summary>
public class MonogramTests
{
    [Theory]
    [InlineData("Etiyopya Kahve Çekirdeği", "EK")]
    [InlineData("Logitech MX Master 3S",   "LM")]
    [InlineData("Tek",                     "TE")]
    [InlineData("İstanbul",                "İS")]
    [InlineData("",                        "—")]
    [InlineData("  ",                      "—")]
    public void Monogram_iki_harf_uretir(string input, string expected)
    {
        BuildMonogram(input).Should().Be(expected);
    }

    [Fact]
    public void Tire_ve_slash_ayirici()
    {
        BuildMonogram("Slim-Fit Pamuklu").Should().Be("SF");
        BuildMonogram("Erkek/Kadın").Should().Be("EK");
    }

    private static string BuildMonogram(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return "—";
        var words = name.Split(new[] { ' ', '-', '/' }, StringSplitOptions.RemoveEmptyEntries);
        if (words.Length == 0) return "—";
        if (words.Length == 1)
            return words[0].Length >= 2
                ? words[0][..2].ToUpper()
                : words[0][..1].ToUpper();
        return $"{char.ToUpper(words[0][0])}{char.ToUpper(words[1][0])}";
    }
}
