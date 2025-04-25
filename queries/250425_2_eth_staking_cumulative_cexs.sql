-- ✅ 1. 날짜별, 스테이커 유형별 스테이킹 데이터 집계
WITH data AS (
    SELECT
        date_trunc('day', block_time) AS day,
        -- 날짜 단위로 정규화 (일 단위 누적 계산을 위해)
        entity_category,
        -- 예치 주체 유형 (예: CEXs, Liquid Staking 등)
        SUM(amount_staked) AS staked -- 해당 일자에 새로 예치된 ETH 총량
    FROM
        query_2393816 -- 커스텀된 validator staking 데이터셋
    WHERE
        validator_index >= 0 -- 유효한 validator만 필터링
        AND block_time >= CURRENT_TIMESTAMP - INTERVAL '30' day -- 최근 30일 범위
    GROUP BY
        1,
        2
) -- ✅ 2. 'CEXs' 카테고리만 필터링하고 누적값 계산
SELECT
    day,
    entity_category,
    -- 누적 스테이킹 양 (일 단위 누적)
    SUM(staked) OVER (
        PARTITION BY entity_category
        ORDER BY
            day
    ) AS cum_staked_eth,
    -- 누적 검증자 수 (32 ETH = 1 validator 기준)
    SUM(staked / 32) OVER (
        PARTITION BY entity_category
        ORDER BY
            day
    ) AS cum_validators
FROM
    data
WHERE
    entity_category = 'CEXs' -- 거래소 기반 예치만 필터링
ORDER BY
    day;