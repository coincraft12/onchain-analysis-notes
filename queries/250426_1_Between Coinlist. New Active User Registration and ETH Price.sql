-- 월별 CoinList Forwarder 신규 사용자 수를 집계하는 CTE
WITH new_users AS (
    SELECT
        DATE_TRUNC('month', call_block_time) AS month,
        -- call_block_time을 월 단위로 잘라서 그룹핑 기준으로 사용
        COUNT(*) AS users -- 해당 월에 생성된 Forwarder 개수(= 신규 사용자 수)
    FROM
        bitgo_ethereum.ForwarderFactory_call_createForwarder
    WHERE
        parent = 0x8D1f2eBFACCf1136dB76FDD1b86f1deDE2D23852 -- CoinList 전용 ForwarderFactory 스마트 컨트랙트 주소로 필터링
    GROUP BY
        1 -- 1번 컬럼(DATE_TRUNC로 만든 month) 기준으로 그룹핑
),
-- 앞에서 계산한 월별 사용자 수를 기반으로 전월 대비 증가율을 계산하는 CTE
growth_calc AS (
    SELECT
        month,
        -- 기준 월
        users,
        -- 해당 월 신규 사용자 수
        LAG(users) OVER (
            ORDER BY
                month
        ) AS prev_users,
        -- LAG 함수로 바로 직전(month-1) 월의 사용자 수를 가져옴
        CASE
            WHEN LAG(users) OVER (
                ORDER BY
                    month
            ) IS NULL THEN NULL -- 첫 번째 row는 이전 값이 없으니까 NULL 처리
            ELSE (
                users - LAG(users) OVER (
                    ORDER BY
                        month
                )
            ) * 100.0 / LAG(users) OVER (
                ORDER BY
                    month
            ) -- 전월 대비 증가율(%) 계산
        END AS growth_rate -- 최종 증가율(%) 컬럼
    FROM
        new_users
),
-- ETH 월별 평균 가격을 가져오는 CTE
price_data AS (
    SELECT
        DATE_TRUNC('month', minute) AS month,
        -- 시간(minute)을 월 단위로 잘라서 그룹핑
        AVG(price) AS avg_eth_price -- 해당 월의 ETH 평균 가격
    FROM
        prices.usd
    WHERE
        symbol = 'ETH' -- 심볼이 ETH인 데이터만 추출
    GROUP BY
        1
) -- 최종 결과를 출력하는 메인 쿼리
SELECT
    new_users.month,
    -- 기준 월
    new_users.users,
    -- 그 달의 CoinList Forwarder 생성 수
    price_data.avg_eth_price,
    -- 그 달의 ETH 평균 가격
    CASE
        WHEN growth_calc.growth_rate >= 50 THEN 1
        ELSE NULL
    END AS surge_marker -- Forwarder 사용자 수 증가율이 50% 이상이면 급등(surge) 마커 1 찍기
FROM
    new_users
    LEFT JOIN growth_calc ON new_users.month = growth_calc.month -- 월 기준으로 증가율 데이터 연결
    LEFT JOIN price_data ON new_users.month = price_data.month -- 월 기준으로 ETH 가격 데이터 연결
ORDER BY
    new_users.month -- 시간순으로 정렬