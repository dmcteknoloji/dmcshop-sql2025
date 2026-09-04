using Microsoft.Data.SqlClient;
using Testcontainers.MsSql;

namespace DMCShop.Tests.Integration;

/// <summary>
/// Testcontainers ile gercek bir SQL Server 2025 ayaga kaldirir.
/// Imaj etiketi bilerek sabit: `2025-latest` her kosuda farkli bir CU
/// indirebilir ve testler sessizce baska bir motoru olcmeye baslar.
/// </summary>
public sealed class SqlServer2025Fixture : IAsyncLifetime
{
    // Uretimdeki compose dosyasiyla ayni etiket.
    private const string Image = "mcr.microsoft.com/mssql/server:2025-CU8-ubuntu-24.04";

    private readonly MsSqlContainer container = new MsSqlBuilder(Image)
        .WithEnvironment("MSSQL_PID", "Developer")
        .Build();

    public string ConnectionString { get; private set; } = string.Empty;

    private const string Database = "dmcshop_test";

    public async Task InitializeAsync()
    {
        await container.StartAsync();

        // Testcontainers master'a baglaniyor, ama PREVIEW_FEATURES sistem
        // veritabanlarinda acilamiyor ("Preview Features cannot be enabled or
        // disabled on system databases"). Once kendi veritabanimizi kuruyoruz.
        var master = container.GetConnectionString();
        await ExecuteOnAsync(master, $"CREATE DATABASE {Database};");

        ConnectionString = new SqlConnectionStringBuilder(master)
        {
            InitialCatalog = Database
        }.ConnectionString;

        // VECTOR tipi preview bayragi olmadan kullanilamiyor.
        await ExecuteAsync("ALTER DATABASE SCOPED CONFIGURATION SET PREVIEW_FEATURES = ON;");
    }

    private static async Task ExecuteOnAsync(string connectionString, string sql)
    {
        await using var conn = new SqlConnection(connectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.CommandTimeout = 180;
        await cmd.ExecuteNonQueryAsync();
    }

    public Task DisposeAsync() => container.DisposeAsync().AsTask();

    public async Task ExecuteAsync(string sql)
    {
        await using var conn = new SqlConnection(ConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.CommandTimeout = 180;
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<T?> ScalarAsync<T>(string sql)
    {
        await using var conn = new SqlConnection(ConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.CommandTimeout = 180;
        var value = await cmd.ExecuteScalarAsync();
        return value is null or DBNull ? default : (T)Convert.ChangeType(value, typeof(T));
    }

    /// <summary>Beklenen hatayi yakalamak icin: calisirsa null, patlarsa SqlException.</summary>
    public async Task<SqlException?> CaptureErrorAsync(string sql)
    {
        try
        {
            await ExecuteAsync(sql);
            return null;
        }
        catch (SqlException ex)
        {
            return ex;
        }
    }
}

[CollectionDefinition(nameof(SqlServer2025Collection))]
public sealed class SqlServer2025Collection : ICollectionFixture<SqlServer2025Fixture>;
