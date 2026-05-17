-- ============================================================================
-- 10-sp-embed.sql
-- ops.sp_embed_text — sorgu metnini aktif provider üzerinden vektöre çevirir.
-- Provider seçimi ops.provider_config tablosundan okunur.
-- T-SQL içinden doğrudan VECTOR_SEARCH çağrılarına vektör hazırlayan workshop
-- showcase'i. Uygulama tarafı (DMCShop.Web /asistan) DI üzerinden gider.
--
-- Önkoşullar:
--   sp_configure 'allow polybase export' bağımsız; ihtiyaç YOK
--   sp_configure 'external rest endpoint enabled' = 1  RECONFIGURE
--   (Database master key + DATABASE SCOPED CREDENTIAL Azure OpenAI içindir;
--    Ollama localhost endpoint'ine kimlik gerektirmediği için sade.)
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE ops.sp_embed_text
    @text     NVARCHAR(MAX),
    @provider NVARCHAR(20) = NULL,            -- NULL ise ops.provider_config'ten alır
    @vec_json NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @endpoint NVARCHAR(400);
    DECLARE @model    NVARCHAR(120);
    DECLARE @cred     NVARCHAR(200);

    IF @provider IS NULL
        SELECT TOP (1)
               @provider = provider, @endpoint = endpoint_url,
               @model    = model_name, @cred     = credential_name
        FROM   ops.provider_config
        WHERE  config_key = 'default_embed' AND is_active = 1
        ORDER BY updated_at DESC;
    ELSE
        SELECT TOP (1)
               @endpoint = endpoint_url, @model = model_name, @cred = credential_name
        FROM   ops.provider_config
        WHERE  config_key = 'default_embed' AND provider = @provider AND is_active = 1
        ORDER BY updated_at DESC;

    IF @endpoint IS NULL
    BEGIN
        RAISERROR(N'ops.provider_config içinde default_embed kaydı bulunamadı.', 16, 1);
        RETURN;
    END

    DECLARE @payload NVARCHAR(MAX);
    DECLARE @response NVARCHAR(MAX);
    DECLARE @ret INT;
    DECLARE @t0 DATETIME2(3) = SYSUTCDATETIME();

    IF @provider = 'ollama'
    BEGIN
        SET @payload = (SELECT @model AS model, @text AS prompt FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        EXEC @ret = sp_invoke_external_rest_endpoint
            @url     = @endpoint,
            @method  = 'POST',
            @headers = N'{"Content-Type":"application/json"}',
            @payload = @payload,
            @response = @response OUTPUT;

        IF @ret <> 0
        BEGIN
            RAISERROR(N'Ollama embedding çağrısı başarısız (ret=%d).', 16, 1, @ret);
            RETURN;
        END

        -- {"embedding":[0.12, -0.34, ...]}  →  '[0.12,-0.34,...]'
        SET @vec_json = JSON_QUERY(@response, '$.result.embedding');
    END
    ELSE IF @provider = 'openai'
    BEGIN
        SET @payload = (SELECT @model AS model, @text AS input FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        EXEC @ret = sp_invoke_external_rest_endpoint
            @url        = @endpoint,
            @method     = 'POST',
            @headers    = N'{"Content-Type":"application/json"}',
            @payload    = @payload,
            @credential = @cred,
            @response   = @response OUTPUT;

        IF @ret <> 0
        BEGIN
            RAISERROR(N'Azure OpenAI embedding çağrısı başarısız (ret=%d).', 16, 1, @ret);
            RETURN;
        END

        SET @vec_json = JSON_QUERY(@response, '$.result.data[0].embedding');
    END
    ELSE
    BEGIN
        RAISERROR(N'Bilinmeyen provider: %s', 16, 1, @provider);
        RETURN;
    END

    INSERT INTO ops.rest_call_log (provider, endpoint_url, http_status, latency_ms, error_text, created_at)
    VALUES (@provider, @endpoint, 200,
            DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()),
            NULL, SYSUTCDATETIME());
END
GO

PRINT '> ops.sp_embed_text hazır';
GO
