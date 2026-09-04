namespace DMCShop.Web.Components.Shared;

/// <summary>
/// Urun adindan basit bir cizim (glif) secer. Amac stok fotografi taklit etmek
/// degil; monogram yerine taninabilir bir sekil koymak. Eslesme yoksa null
/// doner ve ProductImage monograma duser.
///
/// Yollar 24x24 kutusuna cizilmistir, stroke ile kullanilir.
/// </summary>
public static class ProductGlyph
{
    private const string Kitap     = "M4 4h11a3 3 0 0 1 3 3v13H7a3 3 0 0 1-3-3V4zM7 20a3 3 0 0 1 3-3h8";
    private const string Klavye    = "M2 7h20v10H2zM6 11h1M9 11h1M12 11h1M15 11h1M18 11h1M8 14h8";
    private const string Mouse     = "M12 3a6 6 0 0 1 6 6v6a6 6 0 0 1-12 0V9a6 6 0 0 1 6-6zM12 6v4";
    private const string Kulaklik  = "M4 14v-2a8 8 0 0 1 16 0v2M4 14h3v6H5a1 1 0 0 1-1-1zM20 14h-3v6h2a1 1 0 0 0 1-1z";
    private const string Monitor   = "M3 4h18v12H3zM9 20h6M12 16v4";
    private const string Kamera    = "M3 7h4l2-2h6l2 2h4v12H3zM12 16a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z";
    private const string Saat      = "M12 8v4l2 2M8 3h8M8 21h8M12 19a7 7 0 1 0 0-14 7 7 0 0 0 0 14z";
    private const string Cip       = "M7 7h10v10H7zM9 3v4M15 3v4M9 17v4M15 17v4M3 9h4M3 15h4M17 9h4M17 15h4";
    private const string Tablet    = "M6 3h12v18H6zM11 18h2";
    private const string Hoparlor  = "M6 3h12v18H6zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM12 7h.01";
    private const string Kahve     = "M4 8h13v6a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5zM17 10h2a2 2 0 0 1 0 4h-2M6 3v2M10 3v2M14 3v2";
    private const string Sise      = "M10 2h4v4l3 5v11H7V11l3-5zM7 14h10";
    private const string Kavanoz   = "M7 3h10v3H7zM6 6h12v15H6zM9 11h6";
    private const string Tisort    = "M8 3l-5 3 2 4 3-1v12h8V9l3 1 2-4-5-3-3 2z";
    private const string Ayakkabi  = "M3 16h11l3-2 4 2v3H3zM3 16v-5l4-1 2 3";
    private const string Sapka     = "M4 16a8 8 0 0 1 16 0zM2 16h20M8 9a4 4 0 0 1 8 0";
    private const string Canta     = "M4 8h16v13H4zM9 8V6a3 3 0 0 1 6 0v2";
    private const string Mum       = "M9 8h6v13H9zM12 8V5M12 3c1.5 1 1.5 2 0 2s-1.5-1 0-2z";
    private const string Yastik    = "M3 7h18v10H3zM6 7v10M18 7v10";
    private const string Lamba     = "M8 3h8l3 8H5zM12 11v7M8 21h8";
    private const string Tencere   = "M4 9h16v8a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3zM2 11h2M20 11h2M9 6v-2M15 6v-2";
    private const string Dambil    = "M2 12h20M5 8v8M8 6v12M16 6v12M19 8v8";
    private const string Palet     = "M12 3a9 9 0 1 0 0 18h2a2 2 0 0 0 0-4 2 2 0 0 1 2-2h1a4 4 0 0 0 4-4 8 8 0 0 0-9-8zM7 10h.01M10 7h.01M15 7h.01";
    private const string Dag       = "M2 20l7-12 4 6 2-3 7 9zM8 6h.01";
    private const string Yildiz    = "M12 3l2.7 5.8 6.3.8-4.6 4.4 1.2 6.4L12 17.3 6.4 20.4l1.2-6.4L3 9.6l6.3-.8z";

    private static readonly (string[] Anahtar, string Yol)[] Harita =
    [
        (["klavye"], Klavye),
        (["mouse", "fare"], Mouse),
        (["kulaklık", "kulaklik", "airpods", "soundlink", "headphone"], Kulaklik),
        (["monitör", "monitor", "display", "ekran"], Monitor),
        (["kamera", "webcam", "gopro", "drone", "fotoğraf", "fotograf"], Kamera),
        (["saat"], Saat),
        (["ssd", "hub", "şarj", "sarj", "raspberry", "mikrofon", "adaptör", "adaptor"], Cip),
        (["ipad", "tablet", "kindle", "e-kitap"], Tablet),
        (["hoparlör", "hoparlor", "speaker", "bose"], Hoparlor),
        (["kahve", "coffee", "french press", "espresso", "çay", "cay", "tea", "demleme"], Kahve),
        (["yağı", "yagi", "zeytinyağ", "zeytinyag", "sirke", "vinegar", "şurup", "surup", "oil", "syrup", "mineral su", "içme suyu", "icme suyu", "water"], Sise),
        (["bal", "pekmez", "reçel", "recel", "granola", "lokum", "fıstık", "fistik", "kuru", "baharat", "çikolata", "cikolata", "vanilya", "mantar"], Kavanoz),
        (["kazak", "tişört", "tisort", "gömlek", "gomlek", "elbise", "pantolon", "şort", "sort", "ceket", "yağmurluk", "yagmurluk", "hırka", "hirka", "etek", "bluz"], Tisort),
        (["ayakkabı", "ayakkabi", "bot", "sneaker", "mokasen", "terlik", "çizme", "cizme"], Ayakkabi),
        (["şapka", "sapka", "atkı", "atki", "bere", "eldiven", "fötr", "fotr"], Sapka),
        (["çanta", "canta", "cüzdan", "cuzdan", "sırt", "sirt", "valiz"], Canta),
        (["mum"], Mum),
        (["yastık", "yastik", "örtü", "ortu", "nevresim", "battaniye", "havlu", "perde", "kilim", "halı", "hali"], Yastik),
        (["lamba", "aydınlatma", "aydinlatma", "avize", "ampul"], Lamba),
        (["tencere", "tava", "bardak", "tabak", "çaydanlık", "caydanlik", "kase", "bıçak", "bicak"], Tencere),
        (["yoga", "mat", "dambıl", "dambil", "koşu", "kosu", "spor", "fitness", "akrobat"], Dambil),
        (["boya", "mandala", "tuval", "akrilik", "fırça", "firca", "resim"], Palet),
        (["bisiklet", "trekking", "kamp", "çadır", "cadir", "tırmanış", "tirmanis", "dağcı", "dagci"], Dag),
        (["kitap", "dergi", "atlas", "sözlük", "sozluk", "roman", "antoloji", "el kitabı", "el kitabi", "masal", "seti"], Kitap),
    ];

    private static readonly Dictionary<string, string> KategoriYedegi = new()
    {
        ["Kitap"]      = Kitap,
        ["Elektronik"] = Cip,
        ["Gıda"]       = Kavanoz,
        ["Giyim"]      = Tisort,
        ["Ev"]         = Yastik,
        ["Hobi"]       = Palet,
    };

    /// <summary>Urun adina, olmazsa kategoriye gore glif yolu. Bulunamazsa null.</summary>
    public static string? Bul(string? ad, string? kategori)
    {
        var metin = (ad ?? string.Empty).ToLowerInvariant();

        foreach (var (anahtarlar, yol) in Harita)
            foreach (var a in anahtarlar)
                if (metin.Contains(a, StringComparison.Ordinal))
                    return yol;

        if (kategori is not null && KategoriYedegi.TryGetValue(kategori, out var kyol))
            return kyol;

        return Yildiz;
    }
}
