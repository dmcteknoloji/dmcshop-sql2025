namespace DMCShop.Domain.Dtos;

/// <summary>
/// Senaryo 5 — vector + graph hibrit kişiselleştirilmiş öneri.
/// Müşterinin son siparişlerinin embedding centroid'ine vector-yakın ürünler;
/// graph'tan social proof (kaç müşteri aldı) ile yeniden sıralanmış.
/// </summary>
public sealed record PersonalizedRecommendation(
    int     ProductId,
    string  Sku,
    string  Name,
    string  CategoryName,
    decimal Price,
    string? Preview,
    double  VectorDistance,    // cosine [0, 2], küçük = daha yakın
    int     SocialBuyerCount,  // bu ürünü satın alan farklı müşteri sayısı (graph)
    double  HybridScore);      // distance + 1/(1+social) — küçük = daha iyi

public sealed record PersonalizationContext(
    int                CustomerId,
    string             CustomerName,
    int                BasisProductCount,    // centroid'i oluşturan ürün sayısı
    IReadOnlyList<int> BasisProductIds,
    int                EmbeddingDim);
