using Microsoft.Extensions.DependencyInjection;

namespace DMCShop.Search;

public static class DependencyInjection
{
    public static IServiceCollection AddDMCShopSearch(this IServiceCollection services)
    {
        services.AddScoped<VectorSearchService>();
        services.AddScoped<GraphRecommendService>();
        return services;
    }
}
