SELECT
    date,
    symbol,
    MAX(actual_depeg_evt) AS actual_depeg,
    -- 실제 depeg 발생 여부
    CASE
        WHEN MAX(predicted_depegging_evt) = 1 THEN 0.5
        ELSE 0
    END AS predicted_depeg -- 예측된 depeg 여부
FROM
    query_4012445
WHERE
    symbol IN ('USDC', 'USDT', 'DAI', 'PYUSD', 'FDUSD', 'USDE')
GROUP BY
    1,
    2
ORDER BY
    1 ASC,
    2 ASC;