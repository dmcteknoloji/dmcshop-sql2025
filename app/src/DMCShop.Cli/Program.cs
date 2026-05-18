using DMCShop.Cli.Commands;
using DMCShop.Data;
using DMCShop.Providers;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

var config = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: true)
    .AddJsonFile("appsettings.Local.json", optional: true)
    .AddEnvironmentVariables(prefix: "DMCSHOP_")
    .AddUserSecrets<Program>(optional: true)
    .Build();

var services = new ServiceCollection()
    .AddLogging(b => b.AddSimpleConsole(o => { o.SingleLine = true; o.TimestampFormat = "HH:mm:ss "; }))
    .AddSingleton<IConfiguration>(config)
    .AddDMCShopData(config)
    .AddDMCShopProviders(config)
    .BuildServiceProvider();

return args switch
{
    [] or ["-h"] or ["--help"]            => PrintUsage(),
    ["health"]                            => await new HealthCommand(services).RunAsync(),
    ["embed-products", .. var tail]       => await new EmbedProductsCommand(services).RunAsync(tail),
    ["build-map", .. var mapArgs]         => await new BuildMapCommand(services).RunAsync(mapArgs),
    _                                     => PrintUsage()
};

static int PrintUsage()
{
    Console.WriteLine("""
        dmcshop — DMCShop CLI

        Komutlar:
          dmcshop health                              DB ve provider bağlantı kontrolü
          dmcshop embed-products [--batch N]          embedding üret ve vector.product_embedding'a yaz
          dmcshop build-map [--sample N]              50K vector'den 2D harita JSON üret (/harita sayfası için)
        """);
    return 1;
}

internal partial class Program;
