-- ✅ 거래소(CEX) 주소를 불러온다
WITH cex_addresses AS (
    SELECT
        address
    FROM
        cex_evms.addresses
),
-- ✅ USDC 전송 중에서 조건에 맞는 트랜잭션만 필터링
-- - 특정 토큰(contract_address)
-- - 이더리움 메인넷에서 발생
-- - 최근 N일간(block_time >= now() - interval ...)
usdc_transfers AS (
    SELECT
        DATE_TRUNC('day', block_time) AS day,
        -- 날짜별 그룹화를 위한 day 필드 생성
        amount AS usdc_amount,
        -- 전송된 USDC 양 (이미 소수점 반영된 상태로 가정)
        "from",
        -- 송신 주소
        "to" -- 수신 주소
    FROM
        tokens.transfers
    WHERE
        contract_address = { { token_parameter } } -- 파라미터로 받은 토큰 주소 (ex: USDC)
        AND blockchain = 'ethereum' -- 이더리움 체인 필터
        AND block_time >= CURRENT_TIMESTAMP - INTERVAL '{{interval_value_parameter}}' day -- 최근 N일 기준
),
-- ✅ 거래소에서 출금된 USDC의 일별 합계를 계산
cex_outflows AS (
    SELECT
        day,
        SUM(usdc_amount) AS total_outflow -- 해당 날짜에 거래소에서 빠져나간 USDC 총량
    FROM
        usdc_transfers
    WHERE
        "from" IN (
            SELECT
                address
            FROM
                cex_addresses -- 송신자가 거래소 주소에 포함되는 경우만 필터링
        )
    GROUP BY
        day
) -- ✅ 최종 출력: 일자별 거래소 출금 USDC 합계
SELECT
    *
FROM
    cex_outflows
ORDER BY
    day DESC;