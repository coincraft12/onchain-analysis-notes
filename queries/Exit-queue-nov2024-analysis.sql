WITH exit_data AS (
  SELECT
    date_trunc('day', es.block_date) AS time,
    COUNT(*) AS exit_queue
  FROM beacon.validators v
  JOIN beacon.epoch_summaries es ON v.exit_epoch = es.epoch
  WHERE v.exit_epoch IS NOT NULL
  GROUP BY 1
),

staked_data AS (
  SELECT
    date_trunc('day', block_time) AS time,
    SUM(SUM(amount_staked) - SUM(amount_full_withdrawn)) OVER (ORDER BY date_trunc('day', block_time)) AS eth_staked,
    SUM((SUM(amount_staked) - SUM(amount_full_withdrawn)) / 32) OVER (ORDER BY date_trunc('day', block_time)) AS validator_count
  FROM query_2393816
  WHERE validator_index >= 0
  GROUP BY 1
),

price_data AS (
  SELECT
    date_trunc('day', minute) AS time,
    AVG(price) AS eth_price
  FROM prices.usd
  WHERE symbol = 'ETH'
    AND contract_address IS NULL
  GROUP BY 1
)

SELECT
  COALESCE(e.time, s.time, p.time) AS time,
  e.exit_queue,
  s.eth_staked,
  s.validator_count,
  p.eth_price
FROM exit_data e
FULL OUTER JOIN staked_data s ON e.time = s.time
FULL OUTER JOIN price_data p ON COALESCE(e.time, s.time) = p.time
ORDER BY time;