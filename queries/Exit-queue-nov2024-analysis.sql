-- 📊 Exit Queue, ETH Staking, ETH Price - 시간 축 기반 통합 시계열 쿼리
-- 📆 분석 기간: 2020-12-01 ~ 2025-04-23

-- 1️⃣ Exit Queue 데이터를 날짜별로 집계
WITH exit_data AS (
    SELECT
        date_trunc('day', es.block_date) AS time,       -- 에포크 단위 블록 날짜를 '일(day)' 단위로 자름
        COUNT(*) AS exit_queue                          -- 해당 날짜에 exit_epoch가 기록된 검증자 수 (탈출 대기 수)
    FROM
        beacon.validators v
        JOIN beacon.epoch_summaries es ON v.exit_epoch = es.epoch  -- exit_epoch를 날짜 정보가 포함된 테이블과 조인
    WHERE
        v.exit_epoch IS NOT NULL                        -- exit 요청이 실제로 존재하는 경우만 필터링
    GROUP BY
        1                                               -- GROUP BY time
),

-- 2️⃣ ETH Staked 및 Validator 수 누적 계산
staked_data AS (
    SELECT
        date_trunc('day', block_time) AS time,          -- 블록 생성 시간을 일 단위로 정리
        SUM(SUM(amount_staked) - SUM(amount_full_withdrawn)) OVER (
            ORDER BY date_trunc('day', block_time)
        ) AS eth_staked,                                -- 누적 스테이킹 양 (총 스테이킹 - 총 인출)
        SUM(
            (SUM(amount_staked) - SUM(amount_full_withdrawn)) / 32
        ) OVER (
            ORDER BY date_trunc('day', block_time)
        ) AS validator_count                            -- 유효 검증자 수 추정 (32 ETH 기준으로 나눔)
    FROM
        query_2393816                                   -- Beacon Chain 스테이킹/인출 기록 뷰 (Dune 내부 쿼리 뷰)
    WHERE
        validator_index >= 0                            -- 유효한 validator만 포함
    GROUP BY
        1
),

-- 3️⃣ ETH 가격: 날짜별 평균
price_data AS (
    SELECT
        date_trunc('day', minute) AS time,              -- 가격 기록 시간도 일 단위로 자름
        AVG(price) AS eth_price                         -- 해당 날짜의 평균 ETH 가격 (USD 기준)
    FROM
        prices.usd
    WHERE
        symbol = 'ETH'                                  -- ETH 가격만 필터
        AND contract_address IS NULL                    -- spot price (contract 없이)
        AND minute >= TIMESTAMP '2020-12-01'            -- 분석 시작일
        AND minute <= TIMESTAMP '2025-04-23'            -- 분석 종료일
    GROUP BY
        1
    ORDER BY
        1
)

-- 4️⃣ 세 가지 데이터를 날짜 기준으로 병합 (FULL OUTER JOIN)
SELECT
    COALESCE(e.time, s.time, p.time) AS time,           -- 3개 테이블 중 존재하는 시간 중 가장 앞에 있는 것을 기준으로 통합
    e.exit_queue,                                       -- Exit 대기 중인 검증자 수
    s.eth_staked,                                       -- 누적 스테이킹 ETH
    s.validator_count,                                  -- 추정 검증자 수
    p.eth_price                                         -- ETH 평균 가격
FROM
    exit_data e
    FULL OUTER JOIN staked_data s ON e.time = s.time    -- Exit ↔ Staking을 날짜 기준으로 병합
    FULL OUTER JOIN price_data p ON COALESCE(e.time, s.time) = p.time
    -- (e.time, s.time 중 먼저 존재하는 것과 price를 병합 → 전체 날짜 범위 보존)
ORDER BY
    time;                                               -- 시간순 정렬
