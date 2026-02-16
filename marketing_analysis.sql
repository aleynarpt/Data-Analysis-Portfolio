-------------------------------------------------------------------------
-- QUERY 1: AD PLATFORM COMPARISON (Facebook vs Google)
-- Amaç: Facebook ve Google reklam harcamalarını tek bir tabloda birleştirip 
-- günlük bazda ortalama, maksimum ve minimum harcamaları analiz etmek.
-- Kullanılan Teknikler: CTE (Common Table Expressions), UNION ALL, Aggregation.
-------------------------------------------------------------------------
WITH facebook_data AS (
    SELECT
        ad_date,
        'facebook' AS media_source,
        spend
    FROM public.facebook_ads_basic_daily
),
google_data AS (
    SELECT
        ad_date,
        'google' AS media_source,
        spend
    FROM public.google_ads_basic_daily
)
SELECT
    ad_date,
    media_source,
    ROUND(AVG(spend), 2) AS avg_spend,
    MAX(spend) AS max_spend,
    MIN(spend) AS min_spend
FROM (
    -- Farklı kaynaklardan gelen verileri dikey olarak birleştiriyoruz
    SELECT * FROM facebook_data
    UNION ALL
    SELECT * FROM google_data
) AS combined
GROUP BY ad_date, media_source
ORDER BY ad_date, media_source;


-------------------------------------------------------------------------
-- QUERY 2: TOTAL ROMI CALCULATION (Daily ROI)
-- Amaç: Tüm platformların toplam maliyet ve getirisini hesaplayarak 
-- günlük ROMI (Yatırım Getirisi) değerini bulmak. En başarılı 5 günü listeler.
-- Kullanılan Teknikler: COALESCE (NULL yönetimi), LEFT JOIN, Matematiksel Cast İşlemi.
-------------------------------------------------------------------------
WITH facebook_daily AS (
    SELECT ad_date, value AS fb_value, spend AS fb_spend
    FROM public.facebook_ads_basic_daily
),
google_daily AS (
    SELECT ad_date, value AS g_value, spend AS g_spend
    FROM public.google_ads_basic_daily
),
all_dates AS (
    -- Benzersiz tarih listesi oluşturuyoruz
    SELECT ad_date FROM facebook_daily
    UNION
    SELECT ad_date FROM google_daily
),
combined AS (
    SELECT
        d.ad_date,
        -- Veri olmayan günler için 0 atayarak hesaplama hatasını önlüyoruz
        COALESCE(f.fb_value,0) AS fb_value,
        COALESCE(f.fb_spend,0) AS fb_spend,
        COALESCE(g.g_value,0) AS g_value,
        COALESCE(g.g_spend,0) AS g_spend
    FROM all_dates d
    LEFT JOIN facebook_daily f ON d.ad_date = f.ad_date
    LEFT JOIN google_daily g ON d.ad_date = g.ad_date
)
SELECT
    ad_date,
    ROUND(
        (fb_value + g_value)::numeric
        / (fb_spend + g_spend)
    , 2) AS total_romi
FROM combined
-- Bölme işleminde 0 hatasını (division by zero) engellemek için filtreleme
WHERE (fb_spend + g_spend) > 0
ORDER BY total_romi DESC
LIMIT 5;


-------------------------------------------------------------------------
-- QUERY 3: WEEKLY TOP CAMPAIGN PERFORMANCE
-- Amaç: Haftalık bazda en yüksek geliri getiren kampanyayı tespit etmek.
-- Kullanılan Teknikler: DATE_TRUNC (Zaman gruplandırma), INNER JOIN, Unified Reporting.
-------------------------------------------------------------------------
WITH fb AS (
    -- Facebook verilerini kampanya ve adset isimleriyle zenginleştiriyoruz
    SELECT
        f.ad_date,
        'facebook' AS media_source,
        COALESCE(f.spend,0) AS spend,
        COALESCE(f.value,0) AS value,
        COALESCE(fc.campaign_name,'Unknown') AS campaign_name,
        COALESCE(fa.adset_name,'Unknown') AS adset_name
    FROM facebook_ads_basic_daily f
    INNER JOIN facebook_adset fa
        ON f.adset_id = fa.adset_id
    INNER JOIN facebook_campaign fc
        ON f.campaign_id = fc.campaign_id
),
gg AS (
    SELECT
        g.ad_date,
        'google' AS media_source,
        COALESCE(g.spend,0) AS spend,
        COALESCE(g.value,0) AS value,
        COALESCE(g.campaign_name,'Unknown') AS campaign_name,
        COALESCE(g.adset_name,'Unknown') AS adset_name
    FROM google_ads_basic_daily g
),
unified AS (
    SELECT * FROM fb
    UNION ALL
    SELECT * FROM gg
),
weekly AS (
    -- Tarihi haftalık periyotlara çekiyoruz
    SELECT
        DATE_TRUNC('week', ad_date)::date AS week_start,
        campaign_name,
        SUM(value) AS weekly_value
    FROM unified
    GROUP BY 1,2
)
SELECT *
FROM weekly
ORDER BY weekly_value DESC
LIMIT 1;


-------------------------------------------------------------------------
-- QUERY 4: MONTHLY REACH GROWTH ANALYSIS (Window Functions)
-- Amaç: Kampanyaların aylık erişim (reach) büyümesini bir önceki aya göre analiz etmek.
-- Kullanılan Teknikler: LAG() Window Function, REGEXP_REPLACE (URL'den veri çekme).
-------------------------------------------------------------------------
WITH fb_daily AS (
    SELECT
        f.ad_date,
        -- Eğer kampanya ismi tabloda yoksa URL içindeki UTM parametresinden temizleyip alıyoruz
        COALESCE(fc.campaign_name,
                 REGEXP_REPLACE(SPLIT_PART(f.url_parameters, 'utm_campaign=', 2), '&.*$', ''),
                 'Unknown') AS campaign_name,
        f.reach
    FROM facebook_ads_basic_daily f
    LEFT JOIN facebook_campaign fc ON f.campaign_id = fc.campaign_id
),
gg_daily AS (
    SELECT
        ad_date,
        campaign_name,
        reach
    FROM google_ads_basic_daily
),
all_daily AS (
    SELECT * FROM fb_daily
    UNION ALL
    SELECT * FROM gg_daily
),
monthly_total AS (
    SELECT
        DATE_TRUNC('month', ad_date)::date AS ad_month,
        campaign_name,
        SUM(COALESCE(reach,0)) AS monthly_reach
    FROM all_daily
    GROUP BY 1,2
),
monthly_growth AS (
    SELECT
        ad_month,
        campaign_name,
        monthly_reach,
        -- Bir önceki ayın verisini getirerek büyüme miktarını hesaplıyoruz
        COALESCE(
            monthly_reach - LAG(monthly_reach) OVER (PARTITION BY campaign_name ORDER BY ad_month),
            0
        ) AS monthly_growth
    FROM monthly_total
)
SELECT *
FROM monthly_growth
ORDER BY monthly_growth DESC
LIMIT 1;


-------------------------------------------------------------------------
-- QUERY 5: ADSET STREAK ANALYSIS (Gelişmiş Analiz)
-- Amaç: Bir reklam setinin (adset) kesintisiz olarak kaç gün yayınlandığını (streak) bulmak.
-- Kullanılan Teknikler: ROW_NUMBER(), Tarih Aritmetiği, Gaps and Islands Mantığı.
-------------------------------------------------------------------------
WITH all_ads_data AS (
    SELECT fabd.ad_date,
           fa.adset_name,
           'Facebook' AS ad_source
    FROM facebook_ads_basic_daily fabd
    LEFT JOIN facebook_adset fa 
           ON fa.adset_id = fabd.adset_id
    UNION ALL
    SELECT gabd.ad_date,
           gabd.adset_name,
           'Google' AS ad_source
    FROM google_ads_basic_daily gabd
),
adset_days AS (
    SELECT DISTINCT adset_name, ad_date
    FROM all_ads_data
),
ranked AS (
    -- Her adset için tarihleri sıraya koyuyoruz
    SELECT adset_name,
           ad_date,
           ROW_NUMBER() OVER (PARTITION BY adset_name ORDER BY ad_date) AS rn
    FROM adset_days
),
grouped AS (
    -- Tarihten sıra sayısını çıkararak "gruplama" (Island) oluşturuyoruz
    SELECT adset_name,
           ad_date,
           ad_date - rn * interval '1 day' AS grp
    FROM ranked
),
streaks AS (
    -- Oluşan grupların uzunluğunu sayarak kesintisiz yayın süresini buluyoruz
    SELECT adset_name,
           MIN(ad_date) AS streak_start,
           MAX(ad_date) AS streak_end,
           COUNT(*) AS streak_length
    FROM grouped
    GROUP BY adset_name, grp
)
SELECT adset_name, streak_start, streak_end, streak_length
FROM streaks
ORDER BY streak_length DESC
LIMIT 1;
