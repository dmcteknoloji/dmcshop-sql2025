-- ============================================================================
-- 22-fraud-ring.sql
-- Senaryo 3: Fraud ring tespiti — graph + relational karması.
-- Üç temel pattern + bir SHORTEST_PATH evidence chain örneği.
--
-- Workshop akışı:
--   1) Üç pattern'i ayrı ayrı çalıştır (paylaşılan cihaz/IP/kart)
--   2) SHORTEST_PATH ile "iki müşteri arasında 2-3 hop ağı" göster
-- ============================================================================

USE dmcshop;
GO
SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- (1) Aynı cihazı paylaşan müşteriler — relational
-- ----------------------------------------------------------------------------
SELECT
    'shared_device'                          AS pattern,
    d.device_id,
    LEFT(d.fingerprint, 12) + N'…'           AS fingerprint,
    d.ip_address,
    COUNT(DISTINCT cd.customer_id)           AS cust_n,
    STRING_AGG(c.full_name, N', ')
        WITHIN GROUP (ORDER BY c.full_name)  AS customers,
    CASE WHEN COUNT(DISTINCT cd.customer_id) >= 4 THEN 'HIGH' ELSE 'MEDIUM' END AS risk_level
FROM   shop.customer_device cd
JOIN   shop.device   d ON d.device_id   = cd.device_id
JOIN   shop.customer c ON c.customer_id = cd.customer_id
GROUP BY d.device_id, d.fingerprint, d.ip_address
HAVING COUNT(DISTINCT cd.customer_id) >= 2
ORDER BY cust_n DESC;
GO

-- ----------------------------------------------------------------------------
-- (2) Aynı IP'yi paylaşan müşteriler
-- ----------------------------------------------------------------------------
SELECT
    'shared_ip'                              AS pattern,
    d.ip_address,
    COUNT(DISTINCT cd.customer_id)           AS cust_n,
    STRING_AGG(c.full_name, N', ')
        WITHIN GROUP (ORDER BY c.full_name)  AS customers,
    CASE WHEN COUNT(DISTINCT cd.customer_id) >= 5 THEN 'HIGH' ELSE 'MEDIUM' END AS risk_level
FROM   shop.customer_device cd
JOIN   shop.device   d ON d.device_id   = cd.device_id
JOIN   shop.customer c ON c.customer_id = cd.customer_id
GROUP BY d.ip_address
HAVING COUNT(DISTINCT cd.customer_id) >= 3
ORDER BY cust_n DESC;
GO

-- ----------------------------------------------------------------------------
-- (3) Aynı kart parmak izini paylaşan müşteriler
-- ----------------------------------------------------------------------------
SELECT
    'shared_card'                            AS pattern,
    LEFT(pm.card_fingerprint, 8) + N'…'      AS card_fp,
    COUNT(DISTINCT pm.customer_id)           AS cust_n,
    STRING_AGG(c.full_name, N', ')
        WITHIN GROUP (ORDER BY c.full_name)  AS customers,
    CASE WHEN COUNT(DISTINCT pm.customer_id) >= 3 THEN 'HIGH' ELSE 'MEDIUM' END AS risk_level
FROM   shop.payment_method pm
JOIN   shop.customer       c ON c.customer_id = pm.customer_id
WHERE  pm.card_fingerprint IS NOT NULL
GROUP BY pm.card_fingerprint
HAVING COUNT(DISTINCT pm.customer_id) >= 2
ORDER BY cust_n DESC;
GO

-- ----------------------------------------------------------------------------
-- (4) Graph SHORTEST_PATH — iki müşteri arası evidence chain
--     Pattern: customer → device → ip → device → customer
--     Workshop'ta seed'deki Ring B'yi sergiler.
-- ----------------------------------------------------------------------------
SELECT *
FROM (
    SELECT
        cn1.display_name AS start_customer,
        LAST_VALUE(cn2.display_name) WITHIN GROUP (GRAPH PATH) AS end_customer,
        STRING_AGG(cn2.display_name, N' → ')
            WITHIN GROUP (GRAPH PATH) AS hops,
        COUNT(cn2.display_name)
            WITHIN GROUP (GRAPH PATH) AS hop_count
    FROM
        graph.customer_node AS cn1,
        graph.uses_device   FOR PATH AS ud1,
        graph.device_node   FOR PATH AS dn,
        graph.uses_device   FOR PATH AS ud2,
        graph.customer_node FOR PATH AS cn2
    WHERE  MATCH(SHORTEST_PATH(cn1(-(ud1)->dn<-(ud2)-cn2)+))
      AND  cn1.customer_id = 10            -- müşteri 10 (Ring B üyesi)
) AS sp
WHERE sp.end_customer IS NOT NULL
  AND sp.hop_count BETWEEN 2 AND 6
ORDER BY hop_count;
GO

PRINT '> fraud ring sorguları tamam';
GO
