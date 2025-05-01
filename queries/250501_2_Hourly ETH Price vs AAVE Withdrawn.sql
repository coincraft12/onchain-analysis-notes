-- ✅ 1. 일(day) 단위 ETH 가격 시계열 생성
WITH eth_price AS (
    SELECT
        -- 가격 정보를 하루 단위로 그룹핑
        DATE_TRUNC('day', minute) AS time,
        -- 하루 평균 ETH 가격 계산
        AVG(price) AS eth_price
    FROM
        prices.usd
    WHERE
        -- ETH 가격만 필터링
        symbol = 'ETH' -- 최근 360일 데이터만 사용
        AND minute >= CURRENT_TIMESTAMP - INTERVAL '360' day
    GROUP BY
        1
),
-- ✅ 2. AAVE에서 발생한 stablecoin 인출(Withdraw) 데이터 집계
withdrawn AS (
    SELECT
        -- 인출 이벤트 발생 시간을 '일 단위'로 정규화
        DATE_TRUNC('day', evt_block_time) AS time,
        -- 인출된 스테이블코인 양 합산 (decimals 6 기준 보정: USDC, USDT, BUSD)
        SUM(amount / POWER(10, 6)) AS withdrawn_stablecoin
    FROM
        aave_v3_multichain.pool_evt_withdraw
    WHERE
        -- 이더리움 메인넷에서 발생한 이벤트만 필터링
        chain = 'ethereum' -- USDC, USDT, BUSD만 대상 자산으로 필터링
        AND reserve IN (
            0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48,
            -- USDC
            0xdac17f958d2ee523a2206206994597c13d831ec7,
            -- USDT
            0x4fabb145d64652a948d72533023f6e7a623c7c53 -- BUSD
        ) -- 최근 360일간 인출 기록만 대상
        AND evt_block_time >= CURRENT_TIMESTAMP - INTERVAL '360' day
    GROUP BY
        1
    ORDER BY
        1
),
-- ✅ 3. AAVE에서 발생한 stablecoin 예치(Deposit) 데이터 집계
deposit AS (
    SELECT
        -- 예치 호출 시점을 '일 단위'로 정규화
        DATE_TRUNC('day', call_block_time) AS time,
        -- 예치된 스테이블코인 양 합산 (USDC, USDT, BUSD 기준)
        SUM(amount / POWER(10, 6)) AS deposit_stablecoin
    FROM
        aave_v3_multichain.pool_call_deposit
    WHERE
        -- 이더리움 메인넷에서 발생한 예치
        chain = 'ethereum' -- 동일한 세 개 스테이블코인만 필터링
        AND asset IN (
            0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48,
            -- USDC
            0xdac17f958d2ee523a2206206994597c13d831ec7,
            -- USDT
            0x4fabb145d64652a948d72533023f6e7a623c7c53 -- BUSD
        ) -- 최근 360일간의 예치 이벤트만 포함
        AND call_block_time >= CURRENT_TIMESTAMP - INTERVAL '360' day
    GROUP BY
        1
    ORDER BY
        1
) -- ✅ 4. 세 데이터(ETH 가격, 인출량, 예치량)를 일 기준으로 병합
SELECT
    p.time,
    -- 기준 시간 (일 단위)
    eth_price,
    -- 해당 일의 평균 ETH 가격
    COALESCE(w.withdrawn_stablecoin, 0) AS withdrawn,
    -- 인출량 (없으면 0)
    COALESCE(d.deposit_stablecoin, 0) AS deposited -- 예치량 (없으면 0)
FROM
    eth_price AS p -- ETH 가격을 기준으로 인출 데이터 병합
    LEFT JOIN withdrawn AS w ON p.time = w.time -- 예치 데이터도 병합
    LEFT JOIN deposit AS d ON p.time = d.time -- 시간 순으로 정렬
ORDER BY
    p.time;