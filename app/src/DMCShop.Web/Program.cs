using DMCShop.Data;
using DMCShop.Providers;
using DMCShop.Search;
using DMCShop.Web.Components;
using Microsoft.FluentUI.AspNetCore.Components;

var builder = WebApplication.CreateBuilder(args);

// CLI `DMCSHOP_` onekli ortam degiskeni okuyor, Web okumuyordu: ayni baglanti
// dizesini iki farkli isimle vermek gerekiyordu ve dagitimda Web sessizce
// appsettings.json'daki (PUBLIC depodaki) varsayilan parolaya dusuyordu.
// Bu satir onekli ismi Web tarafinda da gecerli kilar; oneksiz olan
// CreateBuilder tarafindan zaten ekleniyor.
builder.Configuration.AddEnvironmentVariables(prefix: "DMCSHOP_");

builder.Services
    .AddDMCShopData(builder.Configuration)
    .AddDMCShopProviders(builder.Configuration)
    .AddDMCShopSearch()
    .AddFluentUIComponents();

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
app.UseHttpsRedirection();
app.UseAntiforgery();
app.MapStaticAssets();

// Hybrid retrieval debug endpoint — workshop'ta vector vs hybrid karşılaştırması için.
// Çıktı: top-K {productId, name, score} JSON. Kullanım: /api/retrieve?q=...&mode=hybrid|vector
app.MapGet("/api/retrieve", async (string q, string mode, int? k, int? pool, VectorSearchService search) =>
{
    var topK = k.GetValueOrDefault(5);
    var hits = mode == "vector"
        ? await search.SearchAsync(q, topK)
        : await search.HybridSearchAsync(q, topK, pool.GetValueOrDefault(0));
    return Results.Json(hits.Select(h => new { h.ProductId, h.Name, h.CategoryName, score = h.Distance }));
});

// /asistan akışını HTTP üzerinden tetikler (SignalR olmadan), final response döner.
// Workshop'ta cURL ile retrieval+LLM zincirini canlı göstermek için.
app.MapGet("/api/rag/ask", async (string q, int? k, RagAssistantService rag, CancellationToken ct) =>
{
    var topK = k.GetValueOrDefault(5);
    var ans = await rag.AskAsync(q, topK, ct);
    return Results.Json(new
    {
        ans.Question,
        ans.Response,
        UsedProductIds = ans.UsedProducts.Select(h => h.ProductId).ToArray(),
        ans.RetrievalLatencyMs,
        ans.LlmLatencyMs,
        ans.TotalLatencyMs
    });
});

// Belirli bir ürün vector pool'unun kaçıncı sırasında? — retrieval diagnostic.
app.MapGet("/api/rank-of", async (string q, int productId, int? pool, VectorSearchService search) =>
{
    var poolSize = pool.GetValueOrDefault(200);
    var hits = await search.SearchAsync(q, poolSize);
    int idx = -1;
    for (int i = 0; i < hits.Count; i++) if (hits[i].ProductId == productId) { idx = i; break; }
    return Results.Json(new { productId, rank = idx, totalScanned = hits.Count, distance = idx >= 0 ? hits[idx].Distance : (double?)null });
});

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
