-- 특정 지갑 주소를 지정하는 임시 테이블 생성
WITH ethereum_addresses (address) AS (
    VALUES
        (0x5be9a4959308A0D0c7bC0870E319314d8D957dBB) -- WLFI 관련 지갑
) -- Ethereum + Base 체인 balance 데이터를 합치고
,
-- 하루 단위로 가장 최신 balance만 남기기 위한 준비
balance_staging AS ( 
    SELECT
        b.blockchain,
        -- 어떤 체인(Ethereum, Base 등)
        block_time,
        -- balance가 기록된 블록 시간
        DATE_TRUNC('day', block_time) as day,
        -- 날짜 단위로 잘라서 저장
        b.address,
        -- 지갑 주소
        b.token_address,
        -- 토큰 주소
        b.balance,
        -- 해당 시간 기준 잔액
        b.token_symbol AS symbol,
        -- 토큰 심볼
        ROW_NUMBER() OVER (
            PARTITION BY b.blockchain,
            b.address,
            b.token_address,
            DATE_TRUNC('day', b.block_time)
            ORDER BY
                b.block_time DESC
        ) AS row_num -- 하루 동안 여러 balance 중 가장 최신순으로 번호 부여
    FROM
        (
            SELECT
                *
            FROM
                tokens_ethereum.balances
            UNION
            ALL
            SELECT
                *
            FROM
                tokens_base.balances
        ) b
        INNER JOIN ethereum_addresses a ON a.address = b.address -- 분석 대상 지갑에 해당하는 balance만 필터
) 
,
-- 하루에 하나만 남긴 balance
balance AS ( -- 하루에 하나만 남긴 balance
    SELECT
        blockchain,
        day,
        address,
        token_address,
        balance,
        symbol
    FROM
        balance_staging
    WHERE
        row_num = 1 -- 하루 중 가장 마지막 balance만 남김
) 
,
-- balance 기록이 시작된 날부터 오늘까지 모든 날짜를 생성
date_series AS (
    SELECT
        day_series.date
    FROM
        UNNEST(
            SEQUENCE(
                TRY_CAST(
                    (
                        SELECT
                            MIN(day)
                        FROM
                            balance
                    ) AS DATE
                ),
                -- balance가 가장 처음 기록된 날짜
                CURRENT_DATE,
                -- 오늘 날짜까지
                INTERVAL '1' day -- 하루 간격
            )
        ) AS day_series(date)
) 
,
-- 지갑이 보유한 모든 토큰(symbol, blockchain, token_address 조합)을 고유하게 추출
all_symbols AS (
    SELECT
        DISTINCT symbol,
        blockchain,
        token_address
    FROM
        balance
) 
,
-- 가격(price) 데이터 준비: 과거 가격과 실시간 가격 모두 합치기
prices AS ( 
    SELECT
        DISTINCT p.day,
        p.contract_address,
        p.blockchain,
        p.price
    FROM
        prices.usd_daily p
        INNER JOIN all_symbols alls ON alls.token_address = p.contract_address -- prices.usd_daily 테이블에서 필요한 토큰만 추출 (과거 가격 데이터)
    UNION
    ALL
    SELECT
        DISTINCT DATE_TRUNC('day', p.minute) AS day,
        p.contract_address,
        p.blockchain,
        p.price
    FROM
        prices.usd_latest p
        INNER JOIN all_symbols alls ON alls.token_address = p.contract_address -- prices.usd_latest 테이블에서 필요한 토큰만 추출 (최신 실시간 가격 데이터)
) 
,
-- 날짜 × 토큰 전체 조합 생성 + balance 채우기
-- 없는 날짜는 마지막 balance를 carry forward
daily_snapshot AS (
    SELECT
        ds.date,
        alls.token_address,
        alls.blockchain,
        alls.symbol,
        COALESCE(
            b.balance,
            LAST_VALUE(b.balance) IGNORE NULLS OVER (
                PARTITION BY alls.token_address,
                alls.blockchain
                ORDER BY
                    ds.date ASC
            )
        ) AS balance -- balance가 NULL이면 가장 최근 balance를 가져옴 (carry forward)
    FROM
        date_series ds
        CROSS JOIN all_symbols alls -- 모든 날짜 × 모든 토큰 조합
        LEFT JOIN balance b ON ds.date = b.day
        AND alls.token_address = b.token_address
        AND alls.blockchain = b.blockchain -- 날짜와 토큰이 매칭되면 balance 가져오고, 없으면 NULL
) 
-- 최종 출력
SELECT
    DISTINCT ds.date,
    -- 날짜
    ds.token_address,
    -- 토큰 주소
    ds.blockchain,
    -- 체인
    CASE
        WHEN ds.token_address = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee THEN 'ETH' -- ETH인 경우는 특별히 symbol을 'ETH'로 설정
        ELSE ds.symbol
    END as symbol,
    ds.balance,
    -- 잔액
    p.price,
    -- 해당 날짜의 가격
    ds.balance * p.price as mv -- 시가총액 (Market Value)
FROM
    daily_snapshot ds
    LEFT JOIN prices p ON p.day = ds.date
    AND ds.token_address = p.contract_address -- 날짜와 토큰을 기준으로 가격과 매칭
WHERE
    ds.balance * p.price > 100 -- 시가총액이 100달러 이상인 경우만
    AND DATE_DIFF(
        'day',
        DATE_TRUNC('week', DATE '2020-10-13'),
        ds.date
    ) % 7 = 0 -- 2020-10-13을 기준으로 매주 7일마다 스냅샷 찍기
ORDER BY
    ds.date DESC,
    -- 최신 날짜 순 정렬
    mv DESC -- 같은 날짜에서는 시가총액 큰 순 정렬