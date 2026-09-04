-- ============================================================================
-- 09-server-memory.sql
-- SQL Server'in bellek tavanini ayarlar.
--
-- Neden: varsayilan max server memory 2.147.483.647 MB, yani sinirsiz. Tek
-- makinede SQL Server'in yaninda Ollama da calisiyor ve sohbet modeli bellekte
-- tutuluyor (OLLAMA_KEEP_ALIVE). Tavan konulmazsa ikisi ayni bellegi ister,
-- OOM killer devreye girer ve genelde once veritabani duser.
--
-- 3 GB, 8 GB'lik demo VM'i icin secildi:
--   SQL Server 3,0 GB + Ollama ~2,5 GB + web ~0,3 GB + isletim sistemi ~0,8 GB
-- Daha buyuk makinede bu degeri buyutun.
-- ============================================================================

SET NOCOUNT ON;
GO

EXEC sys.sp_configure N'show advanced options', 1;
RECONFIGURE;
GO

DECLARE @target INT = TRY_CONVERT(INT, N'$(DMCSHOP_MAX_MEMORY_MB)');
IF @target IS NULL OR @target < 1024 SET @target = 3072;

EXEC sys.sp_configure N'max server memory (MB)', @target;
RECONFIGURE;

PRINT CONCAT('> max server memory (MB) = ', @target);
GO

EXEC sys.sp_configure N'show advanced options', 0;
RECONFIGURE;
GO
