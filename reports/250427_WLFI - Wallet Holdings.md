
# 온체인 쿼리 해부 기록 (2025-04-27)

## 오늘의 목표
- 특정 대시보드를 선정하지 않고, 복잡한 온체인 분석 쿼리를 해부하여 내부 구조와 논리를 정확히 이해하는 것.

## 해부한 쿼리 흐름 요약

### 1. 조회할 주소 지정
```sql
WITH ethereum_addresses (address) AS (
    VALUES (0x5be9a4959308A0D0c7bC0870E319314d8D957dBB)
)
```
- 특정 지갑(address)만 분석 대상.

### 2. Ethereum + Base 체인 balance 합치기
```sql
SELECT * FROM tokens_ethereum.balances
UNION ALL
SELECT * FROM tokens_base.balances
```
- 메인넷과 Base 체인 잔액 데이터 합침.
- 중복 제거하지 않고 모두 이어붙이기 (UNION ALL).

### 3. 하루 중 가장 최신 balance 선택
```sql
ROW_NUMBER() OVER (PARTITION BY blockchain, address, token_address, DATE_TRUNC('day', block_time) ORDER BY block_time DESC) AS row_num
```
- 하루에 여러 balance 변경이 있을 수 있으므로 최신(block_time DESC) 하나만 남김.

### 4. 연속된 날짜 시퀀스 생성
```sql
UNNEST(SEQUENCE(MIN(balance.day), CURRENT_DATE, INTERVAL '1' day)) AS day_series(date)
```
- balance 기록 시작일부터 오늘까지 하루 단위 date 리스트 생성.

### 5. all_symbols 생성
```sql
SELECT DISTINCT symbol, blockchain, token_address FROM balance
```
- 지갑이 보유했던 모든 토큰(symbol) 목록 확보.

### 6. 가격 데이터 준비
```sql
SELECT FROM prices.usd_daily + prices.usd_latest (UNION ALL)
```
- 과거 일별 가격(`usd_daily`) + 최신 가격(`usd_latest`) 합치기.
- 필요한 token_address만 필터링 (INNER JOIN all_symbols).

### 7. 날짜 × 토큰 조합 및 carry forward balance
```sql
CROSS JOIN date_series × all_symbols
LEFT JOIN balance ON date & token_address 매칭
COALESCE(balance, LAST_VALUE(balance) IGNORE NULLS OVER (PARTITION BY token_address, blockchain ORDER BY date ASC))
```
- 모든 날짜, 모든 토큰 조합 생성.
- 없는 날짜는 가장 최근 balance를 이어받음.

### 8. 최종 결과 추출
```sql
SELECT
  날짜, 토큰주소, 체인, 심볼, 잔액, 가격, 시가총액(balance × price)
WHERE
  시가총액 > 100달러
  AND 매주 7일 간격 (2020-10-13 기준)
ORDER BY
  날짜 DESC, 시가총액 DESC
```
- 시가총액 100달러 이상
- 매주 한 번 데이터만 추출
- 최신날짜부터 정렬

---

## 오늘 정리한 주요 개념

| 주제 | 요약 |
|:---|:---|
| ROW_NUMBER() + PARTITION | 하루 중 가장 마지막 balance 고르기 |
| UNION ALL | Ethereum + Base 체인 balance 합치기 (중복 제거 안 함) |
| CROSS JOIN | 날짜 × 토큰 전체 조합 만들기 |
| LAST_VALUE IGNORE NULLS | 잔액 없는 날은 마지막 값 carry forward |
| 가격 테이블 JOIN | usd_daily + usd_latest로 가격 보완 |
| 스냅샷 필터링 | 7일 간격, 100달러 이상 시가총액만 추출 |

---

## 오늘의 성과
- 복잡한 온체인 분석 쿼리 구조를 처음부터 끝까지 완벽히 해부.
- 시간 기반(on-chain time series) 분석 기법 체득.
- 가격 데이터 매칭과 carry forward 테크닉 이해.
- Dune, 온체인 분석 실전 감각 레벨업.

---

> **Note:**
> 이 기록은 온체인 분석가 성장 여정의 소중한 이정표로 저장합니다.
> 앞으로 복잡한 대시보드도 쿼리만 보면 해부할 수 있는 힘을 키우자!

작성 일자: 2025-04-27
