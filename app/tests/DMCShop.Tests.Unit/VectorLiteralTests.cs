using System.Globalization;
using System.Text;
using FluentAssertions;

namespace DMCShop.Tests.Unit;

/// <summary>
/// VectorSearchService ve PersonalizedRecommendService'ün centroid + JSON
/// literal'ini SQL'e geçirirken kullandığı encoding kontratı.
/// </summary>
public class VectorLiteralTests
{
    [Fact]
    public void Empty_array_geçerli_literal_uretir()
    {
        ToVectorLiteral(Array.Empty<float>()).Should().Be("[]");
    }

    [Fact]
    public void Tek_eleman_literal()
    {
        ToVectorLiteral(new[] { 0.5f }).Should().Be("[0.5]");
    }

    [Fact]
    public void Negatif_ve_pozitif_karisik()
    {
        var v = new[] { -0.5f, 0.25f, -1.0f };
        ToVectorLiteral(v).Should().Be("[-0.5,0.25,-1]");
    }

    [Fact]
    public void Invariant_culture_kullanir__nokta_ondalik()
    {
        var prev = Thread.CurrentThread.CurrentCulture;
        try
        {
            Thread.CurrentThread.CurrentCulture = new CultureInfo("tr-TR");
            var v = new[] { 1.5f, 2.5f };
            ToVectorLiteral(v).Should().Contain(".");
            ToVectorLiteral(v).Should().NotContain(",5");   // "1,5" değil
        }
        finally
        {
            Thread.CurrentThread.CurrentCulture = prev;
        }
    }

    [Fact]
    public void Parse_literal_roundtrip()
    {
        var original = new[] { 0.123f, -0.456f, 0.789f };
        var lit      = ToVectorLiteral(original);
        var parsed   = ParseVectorJson(lit);
        parsed.Length.Should().Be(3);
        parsed[0].Should().BeApproximately(0.123f, 1e-6f);
        parsed[1].Should().BeApproximately(-0.456f, 1e-6f);
        parsed[2].Should().BeApproximately(0.789f, 1e-6f);
    }

    private static string ToVectorLiteral(float[] v)
    {
        var sb = new StringBuilder(v.Length * 8);
        sb.Append('[');
        for (var i = 0; i < v.Length; i++)
        {
            if (i > 0) sb.Append(',');
            sb.Append(v[i].ToString("R", CultureInfo.InvariantCulture));
        }
        sb.Append(']');
        return sb.ToString();
    }

    private static float[] ParseVectorJson(string json)
    {
        var trimmed = json.AsSpan().Trim();
        if (trimmed.Length > 0 && trimmed[0] == '[')  trimmed = trimmed[1..];
        if (trimmed.Length > 0 && trimmed[^1] == ']') trimmed = trimmed[..^1];
        if (trimmed.IsEmpty) return Array.Empty<float>();

        var count = 1;
        for (var i = 0; i < trimmed.Length; i++) if (trimmed[i] == ',') count++;
        var arr = new float[count];
        var idx = 0;
        var start = 0;
        for (var i = 0; i <= trimmed.Length; i++)
        {
            if (i == trimmed.Length || trimmed[i] == ',')
            {
                arr[idx++] = float.Parse(trimmed[start..i].Trim(), CultureInfo.InvariantCulture);
                start = i + 1;
            }
        }
        return arr;
    }
}
