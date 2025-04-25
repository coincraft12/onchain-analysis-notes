# 🧠 온체인 분석 요약 (2025-04-25)

## ✅ 1. CEX 출금된 USDC 분석 (`usdc_cex_outflow_daily`)
- **목표**: CEX 지갑에서 출금된 USDC 양을 날짜별로 집계
- **활용 테이블**: `tokens.transfers`, `cex_evms.addresses`
- **의미**: 거래소에서 자금이 온체인으로 이동하는 흐름을 추적하여 시장의 리스크 온 타이밍 파악
- **추가 아이디어**:
  - 스테이블코인 시총, TVL, 가격과 비교
  - 출금량 급증일 분석 → 뉴스 이벤트 연결

---

## ✅ 2. CEX Staking 누적 예치량 (`eth_staking_cumulative_cexs`)
- **목표**: CEX가 누적으로 얼마나 ETH를 예치했는지 추적
- **활용 테이블**: `query_2393816` (validator staking dataset)
- **필터 조건**: `entity_category = 'CEXs'`
- **의미**: CEX 기관들의 중장기적 ETH 네트워크 참여 규모를 시계열로 분석

---

## ✅ 3. CEX Staking 주차별 변화량 (`eth_staking_weekly_delta_cexs`)
- **목표**: 매주 얼마나 신규 ETH를 스테이킹했는지 파악
- **기술**: 누적값에서 `LAG()` 함수로 변화량 도출
- **시각화 팁**: 막대그래프로 예치량 급증/감소 구간 파악

---

## 🎯 주요 인사이트 요약

- **월요일 USDC 출금량 증가** → 시장 참여 재개 타이밍 가능성
- **CEX Staking 흐름과 직접적 연관은 뚜렷하지 않음**
- **두 지표 사이에 중간 고리 필요 (예: Lido, Curve 등 경유 분석)**
- **데이터 디버깅 능력 + 시계열 인사이트 감각 향상됨**

