-- ✅ ETH 가격 시계열 생성 (일 단위 기준)
WITH eth_price AS (
    SELECT
        -- 시간을 '일(day)' 단위로 정규화
        DATE_TRUNC('day', minute) AS time,
        -- 해당 날짜의 ETH 평균 가격 계산
        AVG(price) AS eth_price
    FROM
        prices.usd
    WHERE
        -- 분석 대상은 ETH
        symbol = 'ETH' -- 최근 360일치 데이터 사용
        AND minute >= CURRENT_TIMESTAMP - INTERVAL '360' day
    GROUP BY
        1 -- GROUP BY time
),
-- ✅ AAVE V3에서 발생한 청산 이벤트 집계 (일 단위)
liquidations AS (
    SELECT
        -- 청산 발생 시점을 '일(day)' 단위로 정규화
        DATE_TRUNC('day', evt_block_time) AS time,
        -- 해당 일자의 전체 청산 규모 합산
        SUM(debtToCover) AS total_liquidated_tokens
    FROM
        aave_v3_ethereum."Pool_evt_LiquidationCall"
    WHERE
        -- 분석 기간: 최근 360일
        evt_block_time >= CURRENT_TIMESTAMP - INTERVAL '360' day
    GROUP BY
        1 -- GROUP BY time
) -- ✅ ETH 가격과 청산 데이터를 시간 축 기준으로 결합
SELECT
    p.time,
    -- 공통 시간 축 (day 단위)
    eth_price,
    -- ETH 평균 가격
    -- 청산 데이터가 없는 날은 0으로 처리해 시계열 연속성 유지
    COALESCE(l.total_liquidated_tokens, 0) AS liquidated_tokens
FROM
    eth_price AS p
    LEFT JOIN liquidations AS l ON p.time = l.time -- 시간 축 기준으로 병합
ORDER BY
    p.time;

-- 시계열 정렬 (오름차순)