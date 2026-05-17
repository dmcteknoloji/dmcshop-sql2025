namespace DMCShop.Domain.Dtos;

public sealed record ProductHit(
    int ProductId,
    string Sku,
    string Name,
    string CategoryName,
    decimal Price,
    string? Preview,
    double Distance);
