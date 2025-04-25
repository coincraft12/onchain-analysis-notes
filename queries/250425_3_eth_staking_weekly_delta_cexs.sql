-- ✅ 1. 날짜별, 엔티티별 스테이킹 데이터 집계
WITH data AS (
    SELECT
        date_trunc('day', block_time) AS time,
        -- 일 단위로 시간 정규화 (주 단위로 보려면 'week'로 변경 가능)
        entity_category,
        -- 예치 주체 (CEXs, Liquid Staking, Solo Stakers 등)
        SUM(amount_staked) AS staked -- 해당 일자 + 카테고리의 총 스테이킹 양
    FROM
        query_2393816 -- 커스텀된 validator staking 데이터셋 (파생 테이블로 추정)
    WHERE
        validator_index >= 0 -- 유효한 validator만 필터링
        AND block_time >= CURRENT_TIMESTAMP - INTERVAL '30' day -- 최근 30일로 범위 제한
    GROUP BY
        1,
        2
),
-- ✅ 2. 'CEXs' 카테고리만 필터링
filtered AS (
    SELECT
        *
    FROM
        data
    WHERE
        entity_category = 'CEXs'
),
-- ✅ 3. 누적 스테이킹 데이터를 기반으로 주간 변화량 계산
weekly_change AS (
    SELECT
        time,
        staked,
        -- 현재 날짜의 스테이킹 양
        LAG(staked) OVER (
            ORDER BY
                time
        ) AS prev_staked,
        -- 바로 이전 날짜의 스테이킹 양
        staked - LAG(staked) OVER (
            ORDER BY
                time
        ) AS weekly_diff -- 두 값의 차이로 증가량 도출
    FROM
        filtered
) -- ✅ 4. 최종 출력: 날짜별 순 증가량(변화량) 계산
SELECT
    time,
    COALESCE(weekly_diff, staked) AS weekly_staked_eth -- 첫날은 이전 값이 없으므로 NULL → staked로 대체
FROM
    weekly_change
ORDER BY
    time;