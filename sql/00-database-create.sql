-- ============================================================================
-- 00-database-create.sql
-- dmcshop veritabanı ve ana schema'lar.
-- Önkoşul: SQL Server 2025 (RTM veya CU1+); sysadmin yetkili oturum.
-- ============================================================================

SET NOCOUNT ON;
GO

USE master;
GO

IF DB_ID(N'dmcshop') IS NULL
BEGIN
    PRINT '> dmcshop veritabanı yaratılıyor';
    CREATE DATABASE dmcshop
        COLLATE Turkish_100_CI_AS_SC_UTF8;
END
ELSE
BEGIN
    PRINT '> dmcshop veritabanı zaten var, atlanıyor';
END
GO

ALTER DATABASE dmcshop SET RECOVERY SIMPLE;
ALTER DATABASE dmcshop SET COMPATIBILITY_LEVEL = 170;   -- SQL Server 2025
ALTER DATABASE dmcshop SET QUERY_STORE = ON;
GO

USE dmcshop;
GO

-- ----------------------------------------------------------------------------
-- Schema'lar
--   shop   : transactional veri (müşteri, ürün, sipariş, cihaz, ödeme)
--   graph  : NODE/EDGE tabloları; shop'a FK ile köprülenir
--   vector : embedding, query log, DiskANN index
--   ops    : provider config, audit, ortak truth (T-SQL ↔ .NET)
-- ----------------------------------------------------------------------------

IF SCHEMA_ID(N'shop')   IS NULL EXEC(N'CREATE SCHEMA shop');
IF SCHEMA_ID(N'graph')  IS NULL EXEC(N'CREATE SCHEMA graph');
IF SCHEMA_ID(N'vector') IS NULL EXEC(N'CREATE SCHEMA vector');
IF SCHEMA_ID(N'ops')    IS NULL EXEC(N'CREATE SCHEMA ops');
GO

PRINT '> dmcshop hazır. Sıra: 01-schema-shop.sql';
GO
