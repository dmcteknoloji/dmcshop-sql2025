namespace DMCShop.Domain.Dtos;

public sealed record CoPurchaseRow(
    int RecommendedProductId,
    string RecommendedName,
    string CategoryName,
    decimal Price,
    int CoBuyerCount);
