-- ============================================================================
-- 40-retention.sql
-- vector.query_log + ops.rest_call_log retention policy.
-- 90 günden eski kayıtları siler. Audit trail boyutunu sınırlı tutar.
--
-- SQL Server Agent yoksa (Linux container'larda Agent default kapalı):
--   - Cron job ile: sqlcmd ... -Q "EXEC ops.sp_purge_logs @days = 90"
--   - Veya app tarafından periyodik IHostedService
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE ops.sp_purge_logs
    @days INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cutoff DATETIME2 = DATEADD(DAY, -@days, SYSUTCDATETIME());
    DECLARE @rag_deleted INT, @rest_deleted INT;

    DELETE FROM vector.query_log    WHERE created_at < @cutoff;
    SET @rag_deleted = @@ROWCOUNT;

    DELETE FROM ops.rest_call_log   WHERE created_at < @cutoff;
    SET @rest_deleted = @@ROWCOUNT;

    SELECT
        @cutoff       AS cutoff_utc,
        @days         AS retention_days,
        @rag_deleted  AS query_log_deleted,
        @rest_deleted AS rest_log_deleted;
END
GO

PRINT '> ops.sp_purge_logs hazır';
PRINT '> Manuel çalıştırma: EXEC ops.sp_purge_logs @days = 90';
PRINT '> Önerilen cron: günlük gece 03:00 — scripts/cron.daily.sh içinden';
GO
