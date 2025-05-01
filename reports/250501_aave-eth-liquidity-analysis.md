
# 🧠 AAVE 청산 및 유동성 분석 (ETH 가격과의 상관 관계)

> 📅 분석 날짜: 2025-05-01

## 📌 분석 요약

| 분석 주제 | 분석 목적 | 관찰 결과 | 시계열 단위 | 사용 테이블 |
|-----------|-----------|------------|--------------|--------------|
| ETH 가격 vs AAVE 청산량 | 청산이 ETH 가격 급락과 연관되는가? | ETH 급락 시 청산량 급증 → 상관관계 높음 | hour | aave_v3_ethereum.Pool_evt_LiquidationCall |
| ETH 가격 vs Stablecoin Withdrawn | 유동성 이탈이 가격 하락과 함께 발생했는가? | 2024년 12월 이후 withdrawn 급증 + ETH 하락 추세 | day | aave_v3_multichain.pool_evt_withdraw |
| ETH 가격 vs Stablecoin Deposited | 예치 흐름이 가격 상승과 관련이 있는가? | Deposit은 뚜렷한 상관 없음 (시장 대기자금으로 추정) | day | aave_v3_multichain.pool_evt_deposit |

## 🔍 주요 인사이트

- **청산량과 ETH 급락은 직접적 연관**이 있으며, panic sell 시점 포착 가능
- **Withdraw 증가 = 유동성 이탈 시그널**로 작동, 특히 2024년 12월 이후 뚜렷
- **Deposit은 단기 가격과 직접 연결되지 않음**, 대기자금 성격이 강할 가능성

## 🛠 사용한 기술 및 분석 기법

### 📊 온체인 데이터 처리
- AAVE V3 멀티체인 이벤트 로그를 사용해 `deposit`, `withdraw`, `liquidation` 활동을 시간 단위로 집계
- `reserve` 주소 필터링을 통해 USDC/USDT/BUSD 등 스테이블코인만 선별

### ⏱ 시계열 데이터 정규화
- `DATE_TRUNC`를 사용해 `hour`/`day` 단위로 시간 그룹핑
- 가격 데이터(`prices.usd`)는 분 단위 평균을 일/시간 단위로 집계하여 이벤트 데이터와 정렬

### 🔗 데이터 결합 및 정합성 보정
- `LEFT JOIN` + `COALESCE`로 시계열 누락 방지 및 모든 시간 축 유지
- ETH 가격은 항상 존재하므로 기준 축으로 활용, 금융 시계열 continuity 유지

### 📈 유동성 흐름 추적
- `deposit - withdraw` 차이로 AAVE 내 자금의 순유입/유출(Net Flow) 계산
- 이를 기반으로 **시장 공포 구간**, **패닉성 탈출 시점**, **스테이블코인 행동 패턴** 도출

### 📉 시장 행동과의 상관 분석
- ETH 가격과 청산량/인출량/예치량 간의 시계열 비교를 통해 직접적, 간접적 상관성 여부 판단
- 차트 기반의 패턴 식별을 통해 추세 전환 구간 포착 시도

