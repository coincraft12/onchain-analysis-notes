# Exit Queue vs ETH Staking & Price – Nov 2024 On-Chain Correlation

이 분석은 2024년 11월 당시 온체인 가설 — *“검증자 탈출 신호가 ETH 가격 하락과 관련 있다”* — 를 데이터로 검증하기 위해 시작되었습니다. 이 리포트는 Exit Queue, ETH 스테이킹량, 이더리움 가격 데이터를 하나의 시계열 차트에 결합하여 상관관계를 시각화

---

## 1. 분석 배경
- 2024년 11월, ETH Staked 및 Validator 수가 처음으로 하락세로 전환됨
- 같은 시기에 ETH 가격이 급락
- 가설: **락업 해제 기대감 및 검증자 탈출 시도가 시장 하락 압력으로 작용했을 수 있다**

---

## 2. 사용된 온체인 지표

| 지표 | 설명 |
|------|------|
| `exit_queue` | 해당 날짜에 탈출 예정으로 잡힌 검증자 수 (Exit Epoch 기준) |
| `eth_staked` | 누적 스테이킹된 ETH 수량 (풀 인출 제외) |
| `validator_count` | 동 시점 기준 활성 검증자 수 (약 32 ETH 기준) |
| `eth_price` | CoinGecko 제공 ETH 일 평균 가격 (USD 기준) |

---

## 3. 시각화 목적

> 서로 다른 세 지표를 동일 타임라인 상에서 비교하여, **Exit Queue가 증가할 때 ETH 가격과 스테이킹량이 어떤 반응을 보였는지** 확인

- 좌측 Y축: `eth_staked`, `validator_count`
- 우측 Y축 (Secondary Axis): `exit_queue`
- 하단 Y축: `eth_price`

> 필요한 경우, `exit_queue`를 시각화를 위해 스케일링하거나 보조 차트로 분리

---

## 4. 실행 쿼리
```sql
WITH exit_data AS (
  SELECT
    date_trunc('day', es.block_date) AS time, -- 에포크를 날짜 단위로 정규화
    COUNT(*) AS exit_queue -- 해당 날짜에 exit_epoch에 진입한 검증자 수
  FROM beacon.validators v
  JOIN beacon.epoch_summaries es ON v.exit_epoch = es.epoch
  WHERE v.exit_epoch IS NOT NULL
  GROUP BY 1
),

-- ETH Staked & Validator 수: 누적 스테이킹 ETH와 그에 해당하는 검증자 수 (32ETH 기준)
staked_data AS (
  SELECT
    date_trunc('day', block_time) AS time,
    SUM(SUM(amount_staked) - SUM(amount_full_withdrawn)) OVER (ORDER BY date_trunc('day', block_time)) AS eth_staked, -- 누적 스테이킹 ETH
    SUM((SUM(amount_staked) - SUM(amount_full_withdrawn)) / 32) OVER (ORDER BY date_trunc('day', block_time)) AS validator_count -- 추정 검증자 수
  FROM query_2393816
  WHERE validator_index >= 0
  GROUP BY 1
),

-- ETH 가격: 일자별 평균 가격 추출
price_data AS (
  SELECT
    date_trunc('day', minute) AS time,
    AVG(price) AS eth_price
  FROM prices.usd
  WHERE symbol = 'ETH'
    AND contract_address IS NULL
  GROUP BY 1
)

-- 모든 지표를 날짜 기준으로 FULL OUTER JOIN하여 결합
SELECT
  COALESCE(e.time, s.time, p.time) AS time, -- 시간 기준 통합 (누락 방지)
  e.exit_queue,
  s.eth_staked,
  s.validator_count,
  p.eth_price
FROM exit_data e
FULL OUTER JOIN staked_data s ON e.time = s.time
FULL OUTER JOIN price_data p ON COALESCE(e.time, s.time) = p.time
ORDER BY time;
```

---

## 5. 분석 결과

- 실제로 2024년 11월 초부터 **Exit Queue가 증가**함
- 같은 시점에 **ETH 가격이 하락**하고, **스테이킹량 증가 속도도 둔화**
- 온체인에서 읽어낸 이 움직임은 **시장 불안정성과 검증자들의 심리적 탈출이 맞물렸을 가능성**을 시사함

> 이 분석은 단순 수치 이상의 의미를 지니며, *온체인 데이터를 통해 시장 구조와 참여자의 움직임을 추적할 수 있다*는 가능성을 보여wna.

---

## 6. 다음 단계
- Exit Queue 증가 이후 실제 **Withdrawn ETH 양** 추적
- **Slashed validator 비율**과 비교하여 리스크 분석 보완
- `ETH/stETH 비율`, `LST 시장 동향`, `Restaking 수요`까지 확장

---

### ⛳️ 분석가: Coincraft
**Ethereum & On-Chain Data Analyst**

> “내 가설이 데이터로 증명되는 순간, 분석가는 서사꾼이 된다.”
