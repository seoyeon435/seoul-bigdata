# 📊 seoul-bigdata

---

## 🗂️ Branch Structure

```
├── dashboard
│   ├── MM-DD/
│   │   ├── index.html
│   │   ├── data.js
│   │   └── 99.export.R
│
├── data
│   ├── raw
│   │   ├── cluster
│   │   │   └── 자치구 유형화 관련 원본 CSV
│   │   ├── waste
│   │   │   └── 폐기물 관련 원본 CSV
│   │
│   ├── processed
│   │   ├── 01_waste_by_district_year.csv
│   │   ├── 02_district_population.csv
│   │   ├── 03_district_coords.csv
│   │   ├── 04_facility_2024.csv
│   │
│   ├── external
│   │   ├── gu.csv
│   │
│   └── data_dictionary.csv
│
├── notebooks
│   ├── 01_waste_by_district_year.ipynb
│   ├── 02_district_population.ipynb
│   ├── 03_district_coords.ipynb
│
└── README.md
```

---

## 📁 data 구조

### 📌 raw
- `cluster/`  
  자치구 유형화 분석에 사용된 원본 데이터

- `waste/`  
  폐기물 관련 원본 데이터

---

### 📌 processed
전처리 완료된 데이터

- `01_waste_by_district_year.csv`  
  자치구 × 연도 폐기물 데이터

- `02_district_population.csv`  
  자치구 × 연도 인구 / 종사자 수 데이터

- `03_district_coords.csv`  
  자치구별 위도 / 경도 좌표

- `04_facility_2024.csv`  
  시설별 월별 소각 처리 데이터


---

### 📌 `data_dictionary.csv`
- 전처리 데이터 구조 및 변수 설명서

---

## 🔄 Data Flow

```
raw data
   ↓
notebooks (preprocessing)
   ↓
processed data
   ↓
dashboard (visualization)
```