-- CoinList Forwarder 생성 수 (users)를 월별로 집계하는 CTE
WITH new_users AS (
    SELECT
        DATE_TRUNC('month', call_block_time) AS month,
        -- call_block_time을 월 단위로 잘라서 그룹핑 기준 만들기
        COUNT(*) AS users -- 해당 월에 생성된 Forwarder 총 개수 (신규 사용자 수)
    FROM
        bitgo_ethereum.ForwarderFactory_call_createForwarder
    WHERE
        parent = 0x8d1f2ebfaccf1136db76fdd1b86f1dede2d23852 -- CoinList ForwarderFactory 컨트랙트 주소로 필터링
    GROUP BY
        1 -- 위에서 만든 month 컬럼 기준으로 그룹핑
),
-- ETH 월별 평균 가격을 계산하는 CTE
eth_prices AS (
    SELECT
        DATE_TRUNC('month', minute) AS month,
        -- 가격 데이터도 월 단위로 잘라서 정렬
        AVG(price) AS avg_eth_price -- 해당 월의 ETH 평균 가격 계산
    FROM
        prices.usd
    WHERE
        symbol = 'ETH' -- 심볼이 ETH인 데이터만 선택
        AND minute >= CAST('2021-03-01' AS TIMESTAMP) -- 2021년 3월 이후 데이터만 사용 (기간 제한)
    GROUP BY
        1
) -- 최종 결과 출력
SELECT
    p1.month,
    -- 기준 월
    COALESCE(u.users, 0) AS users,
    -- 해당 월의 Forwarder 생성 수 (없으면 0으로 처리)
    p1.avg_eth_price AS price_at_month,
    -- 기준 월의 ETH 평균 가격
    p2.avg_eth_price AS price_after_1m,
    -- 기준 월 +1개월 후의 ETH 평균 가격
    p3.avg_eth_price AS price_after_3m,
    -- 기준 월 +3개월 후의 ETH 평균 가격
    -- 1개월 후 수익률 (%) 계산
    ROUND(
        (
            (
                p2.avg_eth_price - p1.avg_eth_price
            ) / p1.avg_eth_price
        ) * 100,
        2
    ) AS return_after_1m_pct,
    -- 3개월 후 수익률 (%) 계산
    ROUND(
        (
            (
                p3.avg_eth_price - p1.avg_eth_price
            ) / p1.avg_eth_price
        ) * 100,
        2
    ) AS return_after_3m_pct
FROM
    eth_prices AS p1 -- 월 기준으로 +1개월 후 가격을 LEFT JOIN
    LEFT JOIN eth_prices AS p2 ON p2.month = p1.month + INTERVAL '1' month -- 월 기준으로 +3개월 후 가격을 LEFT JOIN
    LEFT JOIN eth_prices AS p3 ON p3.month = p1.month + INTERVAL '3' month -- Forwarder 사용자 수를 LEFT JOIN
    LEFT JOIN new_users AS u ON u.month = p1.month -- 2021년 3월 이후 데이터만 선택
WHERE
    p1.month >= CAST('2021-03-01' AS TIMESTAMP) -- 시간 순서대로 정렬
ORDER BY
    p1.month