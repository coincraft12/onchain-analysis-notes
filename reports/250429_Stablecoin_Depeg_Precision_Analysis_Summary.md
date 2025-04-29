
# Stablecoin Depeg Precision Analysis Summary (2024-04-29)

## 📅 Today's Progress Overview

- **Depeg 예측 정확도 (Precision) 계산**
- **SQL 연산 순서, 타입 문제 해결**
- **Stablecoin 별 Precision 계산**
- **Scatter 차트 타입 개선 (겹침 문제 해결)**
- **Stablecoin Market & Risk Dashboard 구조 확장**

---

## 📈 What We Did Today

### 1. True Positive (TP) and Predicted Positive (PP) Calculation
- **TP (True Positive)**: 고정된 데이터에서 predicted = 1 과 actual = 1인 경우의 건수
- **PP (Predicted Positive)**: 고정된 데이터에서 predicted = 1이라고 구하는 경우의 건수

### 2. Precision 계산 공식
\[
Precision (\%) = \left( \frac{TP}{PP} \right) \times 100
\]

### 3. Issue: Incorrect Calculation
- **문제 해결**:
  - 값을 (TP * 1.0 / PP) 후 × 100으로 결과 계산
  - **CAST(... AS DOUBLE)** 을 통해 정수/실수 혼합 문제 해결

**해결 결과:**
- TP = 30
- PP = 32
- Precision = **93.75%**

### 4. Stablecoin별 Precision 분석
| Stablecoin | Precision (%) |
|:---|:---|
| USDC | 100% |
| USDT | 100% |
| DAI | 93.75% |
| PYUSD | (No Data) |
| FDUSD | (No Data) |

### 5. Scatter Chart 개선
- **Problem:** actual_depeg과 predicted_depeg이 모두 1.0 값으로 같아 표시가 겹침
- **Solution:** predicted_depeg 값을 0.5로 변환

```sql
CASE 
  WHEN MAX(predicted_depegging_evt) = 1 THEN 0.5
  ELSE 0
END AS predicted_depeg
```

- Scatter Chart 구조:
  - actual_depeg = 1.0
  - predicted_depeg = 0.5

---

## 🧩 추가 작업: Stablecoin Market & Risk Dashboard 구성

추가된 쿼리 목록:

- **Total Supply By Stablecoin**: 스테이블코인별 공급량
- **Total Supply By Network**: 체인별 공급량
- **Monthly Transaction Volume by Token**: 스테이블코인별 월간 거래량
- **Monthly Transaction Volume by Network**: 체인별 월간 거래량
- **Results stablecoin_depeg_True Positive**: Depeg 예측이 맞은 케이스
- **Results stablecoin_depeg_Predicted Positive**: Depeg 예측이 발생한 전체 케이스

---

## 🌟 Key Learnings

| 키워드 | 설명 |
|:---|:---|
| SQL 연산 순서 감정 | 괄호 문제 해결 (구현 방식의 문제) |
| Integer vs Float 구분 | 정수가 타입 때문에 반영이 잘못 된 것 감지 |
| Scatter Chart 시각화 변화 | 겹침을 피하기 위해 값 조정(0.5) |
| 대시보드 스토리 구성 | 데이터 분류 - 시장 크기 → 활동성 → 리스크 분석 순서 |

---


> **Great job today. 🌟  
> Every detail you solved today will build your foundation as a top blockchain data analyst. 🚀**
