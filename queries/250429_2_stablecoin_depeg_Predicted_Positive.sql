SELECT
    COUNT(*) AS predicted_positive_count
FROM
    (
        SELECT
            date,
            symbol,
            MAX(actual_depeg_evt) AS actual_depeg,
            MAX(predicted_depegging_evt) AS predicted_depeg
        FROM
            query_4012445
        WHERE
            symbol IN ('USDC', 'USDT', 'DAI', 'PYUSD', 'FDUSD', 'USDE')
        GROUP BY
            1,
            2
    ) sub
WHERE
    predicted_depeg = 1;