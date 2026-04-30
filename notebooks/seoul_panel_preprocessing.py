"""
서울 자치구 × 연도(2020~2024) 통합 패널 데이터셋 생성
=======================================================
실행 방법:
    python3 seoul_panel_preprocessing.py

요구사항:
    - Python 3.8+
    - pandas, numpy

데이터 파일은 UPLOAD_DIR 디렉토리에 위치해야 합니다.
"""

import pandas as pd
import numpy as np
import os
import warnings
warnings.filterwarnings('ignore')

# ============================================================
# 경로 설정 (필요에 따라 수정)
# ============================================================
UPLOAD_DIR = '/mnt/user-data/uploads'   # 원본 데이터 경로
OUTPUT_DIR = '/mnt/user-data/outputs'   # 출력 경로
YEARS = [2020, 2021, 2022, 2023, 2024]

log_messages = []

def log(msg):
    print(msg)
    log_messages.append(msg)

log("=" * 70)
log("서울 자치구 패널 데이터 전처리 시작")
log("=" * 70)

# ============================================================
# 1. 등록인구 (연령별)
# ============================================================
log("\n[1] 등록인구 데이터 처리")
df_pop = pd.read_csv(
    os.path.join(UPLOAD_DIR, '등록인구_연령별_동별__20260430162035.csv'),
    encoding='utf-8-sig'
)
# '합계' 행(서울시 전체) 제거, 2020~2024 필터링
df_pop = df_pop[df_pop['동별(1)'] != '합계'].copy()
df_pop = df_pop[df_pop['시점'].astype(str).isin([str(y) for y in YEARS])].copy()
df_pop['year'] = df_pop['시점'].astype(int)
df_pop.rename(columns={'동별(1)': 'district'}, inplace=True)

# 연령 구간 정의
age_cols_0_14  = ['0~4세', '5~9세', '10~14세']
age_cols_15_64 = ['15~19세', '20~24세', '25~29세', '30~34세', '35~39세',
                  '40~44세', '45~49세', '50~54세', '55~59세', '60~64세']
age_cols_65p   = ['65~69세', '70~74세', '75~79세', '80~84세', '85~89세',
                  '90~94세', '95~99세', '100세 이상']

for c in age_cols_0_14 + age_cols_15_64 + age_cols_65p + ['합계']:
    df_pop[c] = pd.to_numeric(df_pop[c], errors='coerce')

df_pop['total_population'] = df_pop['합계']
df_pop['pop_0_14']         = df_pop[age_cols_0_14].sum(axis=1)
df_pop['pop_15_64']        = df_pop[age_cols_15_64].sum(axis=1)
df_pop['pop_65p']          = df_pop[age_cols_65p].sum(axis=1)

pop_df = df_pop[['district', 'year', 'total_population',
                  'pop_0_14', 'pop_15_64', 'pop_65p']].copy()
log(f"  → 자치구 수: {pop_df['district'].nunique()}, 연도: {sorted(pop_df['year'].unique())}")

# ============================================================
# 2. 행정구역 면적
# ============================================================
log("\n[2] 행정구역(면적) 데이터 처리")
df_area = pd.read_csv(
    os.path.join(UPLOAD_DIR, '행정구역_구별__20260430162601.csv'),
    encoding='utf-8-sig'
)
# 첫 행(헤더 레이블) 및 서울시 전체 합계 제거
df_area = df_area[df_area['자치구별(1)'] != '자치구별(1)'].copy()
df_area = df_area[df_area['자치구별(2)'] != '소계'].copy()
df_area = df_area[df_area['시점'].astype(str).isin([str(y) for y in YEARS])].copy()
df_area['year'] = df_area['시점'].astype(int)
df_area.rename(columns={'자치구별(2)': 'district', '면적': 'area'}, inplace=True)
df_area['area'] = pd.to_numeric(df_area['area'], errors='coerce')
area_df = df_area[['district', 'year', 'area']].copy()  # 단위: km²

log(f"  → 자치구 수: {area_df['district'].nunique()}, 연도: {sorted(area_df['year'].unique())}")
area_var = area_df.groupby('district')['area'].std().max()
log(f"  → 연도간 면적 최대 표준편차: {area_var:.4f} km² (매우 안정적)")

# ============================================================
# 3. 가구 데이터 (총가구)
# ============================================================
log("\n[3] 가구 데이터 처리")
df_hh = pd.read_csv(
    os.path.join(UPLOAD_DIR, '가구형태별_가구_및_가구원-_읍면동_연도_끝자리_0_5___시군구_그_외_연도__20260430162908.csv'),
    encoding='utf-8-sig'
)
df_hh = df_hh[df_hh['동별(1)'] != '동별(1)'].copy()   # 헤더 레이블 행 제거
df_hh = df_hh[df_hh['동별(2)'] != '소계'].copy()       # 서울시 합계 제거
df_hh = df_hh[df_hh['시점'].astype(str).isin([str(y) for y in YEARS])].copy()
df_hh['year'] = df_hh['시점'].astype(int)
df_hh.rename(columns={'동별(2)': 'district', '총가구': 'total_households'}, inplace=True)
df_hh['total_households'] = pd.to_numeric(df_hh['total_households'], errors='coerce')
hh_df = df_hh[['district', 'year', 'total_households']].copy()

log(f"  → 자치구 수: {hh_df['district'].nunique()}, 연도: {sorted(hh_df['year'].unique())}")

# ============================================================
# 4. 1인가구 데이터
# ============================================================
log("\n[4] 1인가구 데이터 처리")
df_single = pd.read_csv(
    os.path.join(UPLOAD_DIR, '1인가구_연령별__20260430163056.csv'),
    encoding='utf-8-sig'
)
df_single = df_single[df_single['자치구별(2)'] != '소계'].copy()  # 서울시 합계 제거
df_single = df_single[df_single['성별(1)'] == '계'].copy()          # 전체 성별 합계만
df_single = df_single[df_single['시점'].astype(str).isin([str(y) for y in YEARS])].copy()
df_single['year'] = df_single['시점'].astype(int)
df_single.rename(columns={'자치구별(2)': 'district', '합계': 'single_households'}, inplace=True)
df_single['single_households'] = pd.to_numeric(df_single['single_households'], errors='coerce')
single_df = df_single[['district', 'year', 'single_households']].copy()

log(f"  → 자치구 수: {single_df['district'].nunique()}, 연도: {sorted(single_df['year'].unique())}")

# ============================================================
# 5. 사업체 현황 (사업체수, 종사자수)
# ============================================================
log("\n[5] 사업체 데이터 처리")
df_biz = pd.read_csv(
    os.path.join(UPLOAD_DIR, '사업체현황_종사자규모별_동별__20260430163439.csv'),
    encoding='utf-8-sig'
)
df_biz = df_biz[df_biz['동별(1)'] != '동별(1)'].copy()  # 헤더 레이블 행 제거
df_biz = df_biz[df_biz['동별(2)'] != '소계'].copy()      # 서울시 합계 제거
df_biz = df_biz[df_biz['시점'].astype(str).isin([str(y) for y in YEARS])].copy()
df_biz['year'] = df_biz['시점'].astype(int)
df_biz.rename(columns={
    '동별(2)': 'district',
    '합계':    'num_businesses',
    '합계.1':  'num_workers'
}, inplace=True)
df_biz['num_businesses'] = pd.to_numeric(df_biz['num_businesses'], errors='coerce')
df_biz['num_workers']    = pd.to_numeric(df_biz['num_workers'],    errors='coerce')
biz_df = df_biz[['district', 'year', 'num_businesses', 'num_workers']].copy()

log(f"  → 자치구 수: {biz_df['district'].nunique()}, 연도: {sorted(biz_df['year'].unique())}")

# ============================================================
# 6. 상권분석 소비 데이터
# ============================================================
log("\n[6] 소비 데이터 처리")
df_cons = pd.read_csv(
    os.path.join(UPLOAD_DIR, '서울시_상권분석서비스_소비-자치구_.csv'),
    encoding='euc-kr'
)
df_cons['year'] = df_cons['기준_년분기_코드'].astype(str).str[:4].astype(int)
df_cons = df_cons[df_cons['year'].isin(YEARS)].copy()
df_cons.rename(columns={'행정동_코드_명': 'district'}, inplace=True)
df_cons['지출_총금액'] = pd.to_numeric(df_cons['지출_총금액'], errors='coerce')

# 분기별 → 연도별 합산 (4개 분기의 지출 총액 합)
cons_df = df_cons.groupby(['district', 'year'])['지출_총금액'].sum().reset_index()
cons_df.rename(columns={'지출_총금액': 'consumption_total'}, inplace=True)

log(f"  → 자치구 수: {cons_df['district'].nunique()}, 연도: {sorted(cons_df['year'].unique())}")
log(f"  → 분기별 → 연도별 합산 완료")

# ============================================================
# 7. 상권분석 직장인구 데이터
# ============================================================
log("\n[7] 직장인구 데이터 처리")
df_work = pd.read_csv(
    os.path.join(UPLOAD_DIR, '서울시_상권분석서비스_직장인구-자치구_.csv'),
    encoding='euc-kr'
)
df_work['year'] = df_work['기준_년분기_코드'].astype(str).str[:4].astype(int)
df_work = df_work[df_work['year'].isin(YEARS)].copy()
df_work.rename(columns={'자치구_코드_명': 'district'}, inplace=True)
df_work['총_직장_인구_수'] = pd.to_numeric(df_work['총_직장_인구_수'], errors='coerce')

# 분기별 → 연도별 평균 (연간 평균 직장인구)
work_df = df_work.groupby(['district', 'year'])['총_직장_인구_수'].mean().reset_index()
work_df.rename(columns={'총_직장_인구_수': 'working_population'}, inplace=True)

log(f"  → 자치구 수: {work_df['district'].nunique()}, 연도: {sorted(work_df['year'].unique())}")
log(f"  → 분기별 → 연도별 평균 완료")

# ============================================================
# 8. 생활인구 데이터
# ============================================================
log("\n[8] 생활인구 데이터 처리")
df_living = pd.read_csv(
    os.path.join(UPLOAD_DIR, '자치구단위_서울생활인구_일별_집계표.csv'),
    encoding='euc-kr'
)
df_living['year'] = df_living['기준일ID'].astype(str).str[:4].astype(int)
df_living = df_living[df_living['year'].isin(YEARS)].copy()
# 서울시 전체 합계 제외, 자치구만 사용
df_living = df_living[df_living['시군구명'] != '서울시'].copy()
df_living.rename(columns={'시군구명': 'district'}, inplace=True)
df_living['총생활인구수'] = pd.to_numeric(df_living['총생활인구수'], errors='coerce')

# 일별 → 연도별 평균 (연평균 일별 생활인구)
living_df = df_living.groupby(['district', 'year'])['총생활인구수'].mean().reset_index()
living_df.rename(columns={'총생활인구수': 'living_population'}, inplace=True)

log(f"  → 자치구 수: {living_df['district'].nunique()}, 연도: {sorted(living_df['year'].unique())}")
log(f"  → 일별 → 연도별 평균 완료")

# ============================================================
# 9. 용도지역 현황 (주거/상업)
# ============================================================
log("\n[9] 용도지역 데이터 처리")

# 구 파일: 2020~2023
df_land_old = pd.read_csv(
    os.path.join(UPLOAD_DIR, '용도지역_현황_20260430170720.csv'),
    encoding='utf-8-sig'
)
df_land_old = df_land_old[df_land_old['자치구별(1)'] != '자치구별(1)'].copy()
df_land_old = df_land_old[df_land_old['자치구별(2)'] != '소계'].copy()
df_land_old = df_land_old[df_land_old['시점'].astype(str).isin([str(y) for y in YEARS])].copy()
df_land_old['year'] = df_land_old['시점'].astype(int)
df_land_old.rename(columns={
    '자치구별(2)':      'district',
    '용도지역총합계.1': 'residential_area',
    '용도지역총합계.2': 'commercial_area'
}, inplace=True)
df_land_old['residential_area'] = pd.to_numeric(df_land_old['residential_area'], errors='coerce')
df_land_old['commercial_area']  = pd.to_numeric(df_land_old['commercial_area'],  errors='coerce')
land_old_df = df_land_old[['district', 'year', 'residential_area', 'commercial_area']].copy()

# 신 파일: 2024 (열 구조 다름 - 자치구가 자치구별(1)에 직접 위치)
df_land_new = pd.read_csv(
    os.path.join(UPLOAD_DIR, '용도지역_현황_2024년_이후__20260430170853.csv'),
    encoding='utf-8-sig'
)
df_land_new = df_land_new[df_land_new['자치구별(1)'] != '자치구별(1)'].copy()
df_land_new = df_land_new[df_land_new['자치구별(1)'] != '서울시'].copy()  # 서울시 합계 제거
df_land_new['year'] = df_land_new['시점'].astype(int)
df_land_new.rename(columns={
    '자치구별(1)': 'district',
    '도시지역':    'residential_area',
    '도시지역.1':  'commercial_area'
}, inplace=True)
df_land_new['residential_area'] = pd.to_numeric(df_land_new['residential_area'], errors='coerce')
df_land_new['commercial_area']  = pd.to_numeric(df_land_new['commercial_area'],  errors='coerce')
land_new_df = df_land_new[['district', 'year', 'residential_area', 'commercial_area']].copy()

# 두 파일 수직 병합
land_df = pd.concat([land_old_df, land_new_df], ignore_index=True)
land_df = land_df[land_df['year'].isin(YEARS)].copy()
land_df = land_df.drop_duplicates(subset=['district', 'year'])
land_df = land_df.sort_values(['district', 'year']).reset_index(drop=True)

log(f"  → 구 파일 (2020~2023): {land_old_df.shape[0]}행")
log(f"  → 신 파일 (2024): {land_new_df.shape[0]}행")
log(f"  → 병합 후: {land_df.shape[0]}행")

# 단위 변환: m² → km²
land_df['residential_area'] = land_df['residential_area'] / 1e6
land_df['commercial_area']  = land_df['commercial_area']  / 1e6
log(f"  → 단위 변환 완료: m² → km²")

# ============================================================
# 10. 주택 데이터
# ============================================================
log("\n[10] 주택 데이터 처리")
df_house = pd.read_csv(
    os.path.join(UPLOAD_DIR, '주택종류별_주택-_읍면동_연도_끝자리_0_5___시군구_그_외_연도__20260430171728.csv'),
    encoding='utf-8-sig'
)
df_house = df_house[df_house['동별(1)'] != '동별(1)'].copy()  # 헤더 레이블 행 제거
df_house = df_house[df_house['동별(2)'] != '소계'].copy()     # 서울시 합계 제거
df_house = df_house[df_house['시점'].astype(str).isin([str(y) for y in YEARS])].copy()
df_house['year'] = df_house['시점'].astype(int)
df_house.rename(columns={
    '동별(2)':        'district',
    '종류별 주택수':   'total_housing',
    '종류별 주택수.1': 'detached_housing',  # 단독주택
    '종류별 주택수.2': 'apartment_count',   # 아파트
    '종류별 주택수.3': 'row_housing',       # 연립주택
    '종류별 주택수.4': 'multi_housing'      # 다세대주택
}, inplace=True)

for c in ['total_housing', 'detached_housing', 'apartment_count', 'row_housing', 'multi_housing']:
    df_house[c] = pd.to_numeric(df_house[c], errors='coerce')

# 비아파트 = 단독주택 + 연립주택 + 다세대주택
df_house['non_apartment_count'] = (
    df_house['detached_housing'] + df_house['row_housing'] + df_house['multi_housing']
)

house_df = df_house[['district', 'year', 'total_housing',
                       'apartment_count', 'non_apartment_count']].copy()
log(f"  → 자치구 수: {house_df['district'].nunique()}, 연도: {sorted(house_df['year'].unique())}")

# ============================================================
# 11. 기준 패널 생성 및 순차 병합
# ============================================================
log("\n[11] 데이터 병합")

districts = sorted(pop_df['district'].unique())
log(f"  → 기준 자치구 목록 ({len(districts)}개): {districts}")

panel_index = pd.MultiIndex.from_product([districts, YEARS], names=['district', 'year'])
panel = pd.DataFrame(index=panel_index).reset_index()
log(f"  → 기준 패널: {panel.shape[0]}행 ({len(districts)} 자치구 × {len(YEARS)} 연도)")

merge_sources = [
    ('pop_df',    pop_df),
    ('area_df',   area_df),
    ('hh_df',     hh_df),
    ('single_df', single_df),
    ('biz_df',    biz_df),
    ('cons_df',   cons_df),
    ('work_df',   work_df),
    ('living_df', living_df),
    ('land_df',   land_df),
    ('house_df',  house_df),
]

df_final = panel.copy()
for name, df_src in merge_sources:
    before = df_final.shape[1]
    df_final = df_final.merge(df_src, on=['district', 'year'], how='left')
    log(f"    병합: {name:12s} → 컬럼 +{df_final.shape[1] - before}개")

log(f"  → 병합 후 shape: {df_final.shape}")

# ============================================================
# 12. 결측값 처리
# ============================================================
log("\n[12] 결측값 처리")

missing_before = df_final.isnull().sum()
missing_cols = missing_before[missing_before > 0]
if len(missing_cols) > 0:
    log(f"  → 결측 컬럼:\n{missing_cols.to_string()}")
else:
    log("  → 결측값 없음 (모든 데이터 완전 병합)")

numeric_cols = [c for c in df_final.select_dtypes(include=[np.number]).columns if c != 'year']

# 처리 순서: ① 자치구 내 ffill/bfill → ② 전체 평균 대체
df_final = df_final.sort_values(['district', 'year'])
df_final[numeric_cols] = df_final.groupby('district')[numeric_cols].transform(
    lambda x: x.ffill().bfill()
)

for c in numeric_cols:
    n_miss = df_final[c].isnull().sum()
    if n_miss > 0:
        fill_val = df_final[c].mean()
        df_final[c] = df_final[c].fillna(fill_val)
        log(f"    '{c}': {n_miss}건 → 전체 평균({fill_val:.2f}) 대체")

log(f"  → 처리 후 총 결측: {df_final.isnull().sum().sum()}개")

# ============================================================
# 13. 파생변수 생성
# ============================================================
log("\n[13] 파생변수 생성")

df_final['population_density']    = df_final['total_population'] / df_final['area']
df_final['age_0_14_ratio']         = df_final['pop_0_14']         / df_final['total_population']
df_final['age_15_64_ratio']        = df_final['pop_15_64']        / df_final['total_population']
df_final['age_65_plus_ratio']      = df_final['pop_65p']          / df_final['total_population']
df_final['avg_household_size']     = df_final['total_population'] / df_final['total_households']
df_final['single_household_ratio'] = df_final['single_households']/ df_final['total_households']
df_final['worker_density']         = df_final['num_workers']      / df_final['total_population']
df_final['working_pop_ratio']      = df_final['working_population']/ df_final['total_population']
df_final['living_pop_ratio']       = df_final['living_population'] / df_final['total_population']
df_final['residential_ratio']      = df_final['residential_area'] / df_final['area']
df_final['commercial_ratio']       = df_final['commercial_area']  / df_final['area']
df_final['apartment_ratio']        = df_final['apartment_count']  / df_final['total_housing']
df_final['non_apartment_ratio']    = df_final['non_apartment_count']/ df_final['total_housing']
df_final['housing_density']        = df_final['total_housing']    / df_final['area']

log("  → 14개 파생변수 생성 완료")

# ============================================================
# 14. 최종 컬럼 순서 정렬 및 저장
# ============================================================
final_cols = [
    # 식별자
    'district', 'year',
    # 인구
    'total_population', 'pop_0_14', 'pop_15_64', 'pop_65p',
    'population_density',
    'age_0_14_ratio', 'age_15_64_ratio', 'age_65_plus_ratio',
    # 면적
    'area',
    # 가구
    'total_households', 'single_households',
    'avg_household_size', 'single_household_ratio',
    # 사업체
    'num_businesses', 'num_workers', 'worker_density',
    # 소비
    'consumption_total',
    # 직장인구
    'working_population', 'working_pop_ratio',
    # 생활인구
    'living_population', 'living_pop_ratio',
    # 용도지역
    'residential_area', 'commercial_area',
    'residential_ratio', 'commercial_ratio',
    # 주택
    'total_housing', 'apartment_count', 'non_apartment_count',
    'apartment_ratio', 'non_apartment_ratio', 'housing_density',
]

df_final = df_final[final_cols].copy()
df_final = df_final.sort_values(['district', 'year']).reset_index(drop=True)

log(f"\n최종 데이터셋 shape: {df_final.shape}")
log(f"컬럼 수: {len(df_final.columns)}")

# ============================================================
# 저장
# ============================================================
os.makedirs(OUTPUT_DIR, exist_ok=True)
out_csv = os.path.join(OUTPUT_DIR, 'final_dataset.csv')
df_final.to_csv(out_csv, index=False, encoding='utf-8-sig')
log(f"\n최종 CSV 저장: {out_csv}")

log("\n상위 5행:")
print(df_final.head(5).to_string())

# 로그 저장
log_path = os.path.join(OUTPUT_DIR, 'processing_log.txt')
with open(log_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(log_messages))
print(f"\n로그 저장: {log_path}")
