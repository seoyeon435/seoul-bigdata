# 서울시 자치구별 쓰레기 발생 구조 진단 대시보드

> 2026 서울시 빅데이터 활용 경진대회 — 시각화 부문

---

## 📌 프로젝트 개요

서울시 25개 자치구의 폐기물 발생·처리 구조를 진단하고, 2026년 직매립 금지 시행 + 공공 소각시설 정비 공백기에 대응하는 **민간 소각장 매칭 시뮬레이터**를 제공하는 정책 의사결정 지원 대시보드.

### 핵심 메시지

- **진단(What)** — 자치구마다 발생량·처리방식이 다르고 위기 시점이 다르다
- **분석(Why)** — 인구·소비·생활양식 등 구조적 요인이 차이를 만든다
- **처방(How)** — 빈 용량을 어디서 어떻게 메울지 시뮬레이션 가능

### 주 사용자

서울시 자원순환과 · 자치구 환경부서 · 정책 입안자  
(주민은 정책 효과의 **수혜자**로 포지셔닝)

---

## 🗂️ 폴더 구조

```
빅콘/
├── data/
│   ├── (원본 csv 5개)
│   └── preprocess/                   ← EDA 정제 결과
│       ├── per_capita.csv            1인당 배출량
│       ├── trash_process.csv         처리현황(재활용/소각/매립)
│       ├── food_split.csv            음식물 가정/사업장
│       └── recycle_industry.csv      생활/사업장/건설/지정 비중
├── notebooks/
│   ├── EDA_0325.ipynb                탐색 + preprocess csv 생성
│   └── 99_export.R                   preprocess csv → data.js
├── dashboard/
│   ├── index_0428.html               피드백 반영 전 어두운 버전 대시보드
│   ├── index_light.html              피드백 반영 전 밝은 버전 대시보드
│   ├── index_chat_gpt_0429.html      피드백 반영 후 chatgpt가 만든 대시보드
│   ├── index_claude_0429.html        피드백 반영 후 claude가 만든 대시보드    
│   └── data.js                       ← 99_export.R이 자동 생성
├── data_layout.csv                   변수 사전
└── README.md                         이 문서
```

---

## 🔄 데이터 흐름

```
원본 CSV (5개)
     ↓ EDA (R)
preprocess/*.csv (4개) — 정제·집계
     ↓ 99_export.R
dashboard/data.js — JS 변수 형태
     ↓ <script src=...>
dashboard/index.html — 차트·지도 렌더링
```

---

## 📊 대시보드 구조 (3챕터)

### Ch.1 진단 — What
- 직매립 금지 카운트다운 + 4개 공공 소각시설 정비 타임라인
- 핵심 KPI 4개 (총량 / 1인당 / 재활용률 / 최고-최저 격차)
- 자치구별 발생량 지도 (Leaflet 코로플레스)
- 자치구별 처리방식 구성 (Stacked Bar)
- 음식물 가정/사업장 분리, 재활용률 분포
- 내 자치구 카드 (주민용 검색 인터페이스)

### Ch.2 분석 — Why
- 자치구 5개 유형화 (KMeans Clustering)
  - 🏠 주거형 / 🏢 상업형 / 🚶 유동집중형 / 📦 물류소비형 / 🔀 혼합형
- 군집 결과 지도 + 유형별 레이더 차트
- 요인 분석 (산점도 + 회귀선)
- 변수 중요도 (RandomForest)
- 특이 사례 분석 (강서구 — 사업장 폐기물이 범인, 종로·중구 — 유동인구 폭주)
- 발생량 예측 (SARIMA + 신뢰구간)

### Ch.3 처방 — How
- 자치구별 처리 리스크 진단 (히트맵 + 우선순위 매트릭스)
- **민간 소각장 매칭 시뮬레이터**
  - 자치구 × 위탁톤수 × 가중치(비용/거리/CO₂)
  - TOP3 추천 카드 + 출발지→시설 경로 지도
  - 충남(🔴) 자동 제외, Min-Max 정규화
- 자치구별 처리 부담 상세 테이블
- 데이터 한계 안내 (추정치 표기)

---

## 🛠️ 기술 스택

| 영역 | 도구 |
|---|---|
| 분석/모델 | R (dplyr, jsonlite, kmeans) |
| EDA | Jupyter Notebook + IRkernel |
| 시각화 | Chart.js 4.4 + Leaflet 1.9 |
| 지도 데이터 | seoul-maps GeoJSON (인라인) |
| 타일 | CartoDB Voyager |
| 폰트 | Noto Sans KR + JetBrains Mono |

---

## 📅 작업 진행 타임라인

### Phase 1. 대시보드 구조 설계 ✅
- 6탭 → 3챕터로 재구성 (진단/분석/처방)
- 각 챕터에 인트로 박스 + 핵심 질문 배치

### Phase 2. 신규 컴포넌트 추가 ✅
- 직매립 금지 카운트다운
- 공공 소각시설 정비 타임라인
- 강서구 / 종로·중구 케이스 박스
- 매칭 시뮬레이터
- 내 자치구 카드 (주민용)
- 데이터 한계 안내 패널

### Phase 3. 지도 강화 ✅
- Canvas 사각형 → Leaflet 코로플레스
- 서울 25개 자치구 GeoJSON 인라인 (28KB)
- 매칭 시뮬레이터에 출발지→시설 경로 지도

### Phase 4. 데이터 파이프라인 구축 ✅
- EDA 노트북에서 preprocess csv 4개 자동 생성
- 99_export.R: csv 4개 → data.js
- KMeans 클러스터링 결과 export
- 강서구 케이스 차트 실데이터 연결

### Phase 5. 라이트 테마 ✅
- 다크 → 라이트 일괄 전환
- 차트·지도 색상 라이트 배경에 맞춰 조정
- 발표 환경(프로젝터/인쇄) 가독성 향상

### Phase 6. 문서화 ✅
- 데이터 사전 (data_layout.csv)
- README.md

---

## 📋 변수 사전

자세한 설명은 **data_layout.csv** 참조.

### `GU` 배열 핵심 필드 요약

| 필드 | 의미 | 단위 | 상태 |
|---|---|---|---|
| `n`, `lat`, `lng` | 자치구명, 좌표 | - | ✅ 실 |
| `daily`, `pop`, `perCap` | 발생량·주민수·1인당 | 톤/일 / 명 / kg/인일 | ✅ 실 |
| `recycle`, `food`, `inc`, `land` | 재활용/음식물/소각/매립 비중 | % | ✅ 실 |
| `homeProp`, `bizProp` | 음식물 가정/사업장 비중 | % | ✅ 실 |
| `cluster` | KMeans 라벨 | 0~4 | ✅ 모델 |
| `livingPop`, `card`, `delivery`, `growth` | 외부 데이터 4종 | - | ⚠️ 더미 |

### `RECYCLE_INDUSTRY` 객체

자치구명 → `{life, industry, construction, designated}` 비중(%).

---

## 🚀 실행 방법

### 1. R 환경 준비

```r
install.packages(c("dplyr", "tidyr", "jsonlite", "readr",
                   "ggplot2", "scales", "showtext", "ggrepel"))
```

### 2. EDA 노트북 실행

```
notebooks/EDA_0325.ipynb 모든 셀 실행
→ data/preprocess/ 에 csv 4개 생성
```

### 3. data.js 생성

```r
source("notebooks/99_export.R")
# → dashboard/data.js 갱신
```

### 4. 대시보드 열기

```
dashboard/index.html을 브라우저로 더블클릭
```

---

## ⏳ 진행 상황

### ✅ 완료
- [x] 대시보드 3챕터 구조
- [x] Leaflet 자치구 코로플레스 지도
- [x] 매칭 시뮬레이터
- [x] 데이터 파이프라인 (preprocess → data.js)
- [x] 4개 핵심 폐기물 지표 실데이터 연결
- [x] 강서구 케이스 차트 실데이터
- [x] KMeans 클러스터링
- [x] 라이트 테마 전환
- [x] 데이터 사전 + README

### 🟡 진행 중
- [ ] 외부 데이터 확보 (생활인구 / 카드소비 / 택배 / 증가율)

### 📋 To-Do
- [ ] 회귀/상관 lookup 사전 계산 (Ch.2 산점도)
- [ ] SARIMA 시계열 예측 (Ch.2 예측 차트) — `forecast` 패키지
- [ ] RandomForest 변수 중요도 (Ch.2 RF 차트)
- [ ] 리스크 점수 공식 합의 (Ch.3 히트맵·테이블)
- [ ] 민간 소각장 후보 데이터 (현재 12개 더미)
- [ ] 발표 narrative 정리

---

## ⚠️ 데이터 신뢰도

대시보드 일부는 **추정치/더미**를 사용 중:

| 항목 | 상태 | 출처 또는 가정 |
|---|---|---|
| 생활인구 | 더미 | 서울 열린데이터광장 "서울 생활인구" |
| 카드소비 | 더미 | 자치구별 신한카드 등 |
| 택배 물동량 | 더미 | 통계청 또는 추정 |
| 증가율 | 더미 | 시계열 모델 적용 후 교체 |
| 민간 소각장 단가/잔여용량 | 추정 | 환경부 통계 + 거리비례 추정 |

발표 시 **데이터 한계 안내** 패널에서 명시.

---

## 🔗 데이터 출처

- 서울 열린데이터광장 — 폐기물 통계 5종
- southkorea/seoul-maps (GitHub, MIT) — 자치구 GeoJSON
- CartoDB — 베이스맵 타일

---

## 📝 변경 이력

| 버전 | 주요 변경 |
|---|---|
| v1 | 초기 6탭 다크 대시보드 |
| v2 | 3챕터 재구성, 신규 컴포넌트 추가 |
| v3 | Leaflet 지도, 데이터 파이프라인, 실데이터 연결 |
| v3.1 | 라이트 테마 전환, 문서화 |
