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
-- 📊 Exit Queue, ETH Staking, ETH Price - 시간 축 기반 통합 시계열 쿼리
-- 📆 분석 기간: 2020-12-01 ~ 2025-04-23

-- 1️⃣ Exit Queue 데이터를 날짜별로 집계
WITH exit_data AS (
    SELECT
        date_trunc('day', es.block_date) AS time,       -- 에포크 단위 블록 날짜를 '일(day)' 단위로 자름
        COUNT(*) AS exit_queue                          -- 해당 날짜에 exit_epoch가 기록된 검증자 수 (탈출 대기 수)
    FROM
        beacon.validators v
        JOIN beacon.epoch_summaries es ON v.exit_epoch = es.epoch  -- exit_epoch를 날짜 정보가 포함된 테이블과 조인
    WHERE
        v.exit_epoch IS NOT NULL                        -- exit 요청이 실제로 존재하는 경우만 필터링
    GROUP BY
        1                                               -- GROUP BY time
),

-- 2️⃣ ETH Staked 및 Validator 수 누적 계산
staked_data AS (
    SELECT
        date_trunc('day', block_time) AS time,          -- 블록 생성 시간을 일 단위로 정리
        SUM(SUM(amount_staked) - SUM(amount_full_withdrawn)) OVER (
            ORDER BY date_trunc('day', block_time)
        ) AS eth_staked,                                -- 누적 스테이킹 양 (총 스테이킹 - 총 인출)
        SUM(
            (SUM(amount_staked) - SUM(amount_full_withdrawn)) / 32
        ) OVER (
            ORDER BY date_trunc('day', block_time)
        ) AS validator_count                            -- 유효 검증자 수 추정 (32 ETH 기준으로 나눔)
    FROM
        query_2393816                                   -- Beacon Chain 스테이킹/인출 기록 뷰 (Dune 내부 쿼리 뷰)
    WHERE
        validator_index >= 0                            -- 유효한 validator만 포함
    GROUP BY
        1
),

-- 3️⃣ ETH 가격: 날짜별 평균
price_data AS (
    SELECT
        date_trunc('day', minute) AS time,              -- 가격 기록 시간도 일 단위로 자름
        AVG(price) AS eth_price                         -- 해당 날짜의 평균 ETH 가격 (USD 기준)
    FROM
        prices.usd
    WHERE
        symbol = 'ETH'                                  -- ETH 가격만 필터
        AND contract_address IS NULL                    -- spot price (contract 없이)
        AND minute >= TIMESTAMP '2020-12-01'            -- 분석 시작일
        AND minute <= TIMESTAMP '2025-04-23'            -- 분석 종료일
    GROUP BY
        1
    ORDER BY
        1
)

-- 4️⃣ 세 가지 데이터를 날짜 기준으로 병합 (FULL OUTER JOIN)
SELECT
    COALESCE(e.time, s.time, p.time) AS time,           -- 3개 테이블 중 존재하는 시간 중 가장 앞에 있는 것을 기준으로 통합
    e.exit_queue,                                       -- Exit 대기 중인 검증자 수
    s.eth_staked,                                       -- 누적 스테이킹 ETH
    s.validator_count,                                  -- 추정 검증자 수
    p.eth_price                                         -- ETH 평균 가격
FROM
    exit_data e
    FULL OUTER JOIN staked_data s ON e.time = s.time    -- Exit ↔ Staking을 날짜 기준으로 병합
    FULL OUTER JOIN price_data p ON COALESCE(e.time, s.time) = p.time
    -- (e.time, s.time 중 먼저 존재하는 것과 price를 병합 → 전체 날짜 범위 보존)
ORDER BY
    time;                                               -- 시간순 정렬

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

[🔗 Dune에서 차트 직접 보기](https://dune.com/coincraft12/validator-exit-queue-vs-eth-staking-and-price-nov-2024-on-chain-correlation)

---


### ⛳️ 분석가: Coincraft
**Ethereum & On-Chain Data Analyst**

> “내 가설이 데이터로 증명되는 순간, 분석가는 서사꾼이 된다.”
