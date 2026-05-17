-- ============================================================================
-- 11-sp-chat.sql
-- ops.sp_chat_complete — verilen sistem ve kullanıcı mesajıyla chat completion.
-- Aktif provider (default_chat) ops.provider_config'ten okunur.
--
-- T-SQL içinde RAG asistanı showcase'i içindir. Uygulama tarafı .NET IChatProvider
-- ile gider; bu sp, kitap workshop'unda "T-SQL'den LLM çağrısı" demosu için.
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE ops.sp_chat_complete
    @system_prompt NVARCHAR(MAX),
    @user_prompt   NVARCHAR(MAX),
    @response_text NVARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @provider NVARCHAR(20);
    DECLARE @endpoint NVARCHAR(400);
    DECLARE @model    NVARCHAR(120);
    DECLARE @cred     NVARCHAR(200);

    SELECT TOP (1)
           @provider = provider, @endpoint = endpoint_url,
           @model    = model_name, @cred     = credential_name
    FROM   ops.provider_config
    WHERE  config_key = 'default_chat' AND is_active = 1
    ORDER BY updated_at DESC;

    IF @endpoint IS NULL
    BEGIN
        RAISERROR(N'ops.provider_config içinde default_chat kaydı bulunamadı.', 16, 1);
        RETURN;
    END

    DECLARE @payload NVARCHAR(MAX);
    DECLARE @response NVARCHAR(MAX);
    DECLARE @ret INT;
    DECLARE @t0 DATETIME2(3) = SYSUTCDATETIME();

    IF @provider = 'ollama'
    BEGIN
        SET @payload = N'{
            "model":"' + @model + N'",
            "stream": false,
            "messages":[
                {"role":"system","content":' + STRING_ESCAPE(@system_prompt, 'json') + N'},
                {"role":"user",  "content":' + STRING_ESCAPE(@user_prompt,   'json') + N'}
            ]
        }';

        EXEC @ret = sp_invoke_external_rest_endpoint
            @url     = @endpoint,
            @method  = 'POST',
            @headers = N'{"Content-Type":"application/json"}',
            @payload = @payload,
            @response = @response OUTPUT;

        SET @response_text = JSON_VALUE(@response, '$.result.message.content');
    END
    ELSE IF @provider = 'openai'
    BEGIN
        SET @payload = N'{
            "model":"' + @model + N'",
            "messages":[
                {"role":"system","content":' + STRING_ESCAPE(@system_prompt, 'json') + N'},
                {"role":"user",  "content":' + STRING_ESCAPE(@user_prompt,   'json') + N'}
            ]
        }';

        EXEC @ret = sp_invoke_external_rest_endpoint
            @url        = @endpoint,
            @method     = 'POST',
            @headers    = N'{"Content-Type":"application/json"}',
            @payload    = @payload,
            @credential = @cred,
            @response   = @response OUTPUT;

        SET @response_text = JSON_VALUE(@response, '$.result.choices[0].message.content');
    END

    INSERT INTO ops.rest_call_log (provider, endpoint_url, http_status, latency_ms, error_text, created_at)
    VALUES (@provider, @endpoint, IIF(@ret = 0, 200, 500),
            DATEDIFF(MILLISECOND, @t0, SYSUTCDATETIME()),
            IIF(@ret <> 0, N'sp_invoke_external_rest_endpoint ret=' + CAST(@ret AS NVARCHAR(10)), NULL),
            SYSUTCDATETIME());
END
GO

PRINT '> ops.sp_chat_complete hazır';
GO
