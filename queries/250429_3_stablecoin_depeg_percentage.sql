-- True Positive(TP)와 Predicted Positive(PP)를 계산하는 CTE를 정의
WITH tp AS (
    SELECT
        COUNT(*) AS true_positive_count -- TP: 예측도 1이고 실제도 1인 경우의 총 개수를 센다
    FROM
        (
            SELECT
                date,
                symbol,
                MAX(actual_depeg_evt) AS actual_depeg,
                -- 날짜+코인별로 하루 동안 실제 depeg 발생 여부를 하나로 집계
                MAX(predicted_depegging_evt) AS predicted_depeg -- 날짜+코인별로 하루 동안 depeg 예측 여부를 하나로 집계
            FROM
                query_4012445
            WHERE
                symbol IN ('USDC', 'USDT', 'DAI', 'PYUSD', 'FDUSD', 'USDE') -- 분석 대상 스테이블코인 필터링
            GROUP BY
                1,
                2 -- date, symbol 별로 묶는다
        ) AS sub
    WHERE
        predicted_depeg = 1 -- 예측이 있었던 경우 중
        AND actual_depeg = 1 -- 실제로도 depeg이 발생한 경우만 필터링
),
pp AS (
    SELECT
        COUNT(*) AS predicted_positive_count -- PP: 예측을 1로 한 경우(성공 여부와 무관)의 총 개수를 센다
    FROM
        (
            SELECT
                date,
                symbol,
                MAX(actual_depeg_evt) AS actual_depeg,
                -- 날짜+코인별 실제 depeg 발생 여부 집계
                MAX(predicted_depegging_evt) AS predicted_depeg -- 날짜+코인별 예측 depeg 여부 집계
            FROM
                query_4012445
            WHERE
                symbol IN ('USDC', 'USDT', 'DAI', 'PYUSD', 'FDUSD', 'USDE') -- 분석 대상 스테이블코인 필터링
            GROUP BY
                1,
                2 -- date, symbol 별로 묶는다
        ) AS sub
    WHERE
        predicted_depeg = 1 -- 예측이 1인 경우만 필터링
) -- 최종 Precision 계산
SELECT
    (
        CAST(tp.true_positive_count AS DOUBLE) / CAST(pp.predicted_positive_count AS DOUBLE)
    ) * 100 AS precision_percentage -- TP / PP를 한 뒤, 100을 곱해서 퍼센트(%) 단위로 변환
    -- CAST를 통해 정수 나눗셈이 아닌 소수점 정확도를 유지하는 실수(Double) 나눗셈 수행
FROM
    tp,
    pp;