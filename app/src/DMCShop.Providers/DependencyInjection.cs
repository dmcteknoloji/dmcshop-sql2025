using DMCShop.Domain.Abstractions;
using DMCShop.Providers.Ollama;
using DMCShop.Providers.OpenAI;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace DMCShop.Providers;

public static class DependencyInjection
{
    public static IServiceCollection AddDMCShopProviders(this IServiceCollection services, IConfiguration config)
    {
        services.Configure<ProviderOptions>(config.GetSection(ProviderOptions.SectionName));

        var active = (config[$"{ProviderOptions.SectionName}:Active"] ?? "ollama").ToLowerInvariant();

        switch (active)
        {
            case "openai":
                services.AddSingleton<IEmbeddingProvider, OpenAIEmbeddingProvider>();
                services.AddSingleton<IChatProvider, OpenAIChatProvider>();
                break;

            case "ollama":
                services.AddHttpClient("ollama");
                services.AddSingleton<IEmbeddingProvider, OllamaEmbeddingProvider>();
                services.AddSingleton<IChatProvider, OllamaChatProvider>();
                break;

            default:
                throw new InvalidOperationException(
                    $"Provider:Active beklenmeyen değer: '{active}'. Geçerli: openai, ollama.");
        }

        return services;
    }
}
