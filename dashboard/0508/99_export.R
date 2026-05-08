# ════════════════════════════════════════════════════════════════
# 99_export.R — 전처리 CSV → data.js 파이프라인
#
# 입력 파일 (DATA_DIR):
#   01_waste_by_district_year.csv   자치구×연도 폐기물 통합 데이터
#   02_district_population.csv      자치구별 주민등록인구·종사자수
#   03_district_coords.csv          자치구별 위도·경도
#   04_facility_2024.csv            4개 자원회수시설 월별 소각 현황
#
# 출력 파일 (DASH_DIR):
#   data.js    DISTRICT_YEAR / POP_DATA / COORD_DATA /
#              SEOUL_YEARLY / FACILITY_MONTHLY / MAINTENANCE_SCHEDULE / YEARS
#
# 규칙:
#   - 하드코딩 금지 — 모든 값은 데이터 기반 계산
#   - MAINTENANCE_SCHEDULE 은 data.js 내부에서만 관리
#   - 시설 데이터는 연도 슬라이더와 무관 (2024 스냅샷)
# ════════════════════════════════════════════════════════════════

library(dplyr)
library(tidyr)
library(readr)
library(jsonlite)

# ── 경로 설정 ──────────────────────────────────────────────────
DATA_DIR <- "."          # CSV 파일 위치 (프로젝트 루트 기준)
DASH_DIR <- "."          # data.js 출력 위치

# ── 안전 읽기 헬퍼 ────────────────────────────────────────────
read_csv_safe <- function(path) {
  tryCatch(
    read_csv(path, locale = locale(encoding = "UTF-8"),
             show_col_types = FALSE, name_repair = "minimal"),
    error = function(e)
      read_csv(path, locale = locale(encoding = "CP949"),
               show_col_types = FALSE, name_repair = "minimal")
  )
}

cat("── 1. CSV 로드 중...\n")

waste  <- read_csv_safe(file.path(DATA_DIR, "01_waste_by_district_year.csv"))
pop    <- read_csv_safe(file.path(DATA_DIR, "02_district_population.csv"))
coords <- read_csv_safe(file.path(DATA_DIR, "03_district_coords.csv"))
fac    <- read_csv_safe(file.path(DATA_DIR, "04_facility_2024.csv"))

cat(sprintf("  waste   : %d 행  |  pop: %d 행  |  coords: %d 행  |  facility: %d 행\n",
            nrow(waste), nrow(pop), nrow(coords), nrow(fac)))

# ════════════════════════════════════════════════════════════════
# 2. DISTRICT_YEAR  — 자치구 × 연도 중첩 객체
# ════════════════════════════════════════════════════════════════
cat("\n── 2. DISTRICT_YEAR 생성 중...\n")

# 사용할 컬럼 목록
waste_cols <- c(
  "living_waste", "living_recycle", "living_incineration", "living_landfill",
  "industrial_waste", "construction_waste", "designated_waste",
  "per_capita_living_waste",
  "total_waste", "total_recycle", "total_incineration", "total_landfill",
  "household_waste", "biz_nonbiz_waste",
  "recycle_rate", "incineration_rate", "landfill_rate",
  "total_recycle_rate", "total_incineration_rate", "total_landfill_rate"
)

# 불필요한 빈 컬럼 제거 후 정수/실수 변환
waste_clean <- waste %>%
  select(district, year, all_of(waste_cols)) %>%
  mutate(across(all_of(waste_cols), ~ suppressWarnings(as.numeric(.)))) %>%
  filter(!is.na(district))

# 중첩 리스트: district → year → {fields}
district_year_list <- waste_clean %>%
  group_by(district) %>%
  group_map(~ {
    yr_list <- .x %>%
      group_by(year) %>%
      group_map(~ {
        row <- as.list(.x[1, waste_cols])
        # 정수형 컬럼 강제 변환
        int_cols <- c("living_waste","living_recycle","living_incineration","living_landfill",
                      "industrial_waste","construction_waste","designated_waste",
                      "total_waste","total_recycle","total_incineration","total_landfill",
                      "household_waste","biz_nonbiz_waste")
        for (col in int_cols) row[[col]] <- as.integer(round(row[[col]], 0))
        # 실수형 컬럼 반올림
        flt_cols <- setdiff(waste_cols, int_cols)
        for (col in flt_cols) row[[col]] <- round(as.numeric(row[[col]]), 4)
        row
      }, .keep = TRUE) %>%
      setNames(as.character(unique(.x$year)))
    yr_list
  }, .keep = TRUE) %>%
  setNames(unique(waste_clean$district))

cat(sprintf("  자치구 수: %d  |  연도 범위: %s\n",
            length(district_year_list),
            paste(sort(unique(waste_clean$year)), collapse = "~")))

# ════════════════════════════════════════════════════════════════
# 3. POP_DATA  — 자치구 × 연도 인구·종사자
# ════════════════════════════════════════════════════════════════
cat("\n── 3. POP_DATA 생성 중...\n")

pop_clean <- pop %>%
  mutate(population = as.integer(population),
         workers    = as.integer(workers)) %>%
  filter(!is.na(district))

pop_list <- pop_clean %>%
  group_by(district) %>%
  group_map(~ {
    setNames(
      lapply(seq_len(nrow(.x)), function(i)
        list(population = .x$population[i], workers = .x$workers[i])),
      as.character(.x$year)
    )
  }, .keep = TRUE) %>%
  setNames(unique(pop_clean$district))

cat(sprintf("  자치구 수: %d\n", length(pop_list)))

# ════════════════════════════════════════════════════════════════
# 4. COORD_DATA  — 자치구별 위도·경도
# ════════════════════════════════════════════════════════════════
cat("\n── 4. COORD_DATA 생성 중...\n")

coord_list <- setNames(
  lapply(seq_len(nrow(coords)), function(i)
    list(lat = as.numeric(coords$lat[i]),
         lng = as.numeric(coords$lng[i]))),
  coords$district
)

cat(sprintf("  자치구 수: %d\n", length(coord_list)))

# ════════════════════════════════════════════════════════════════
# 5. SEOUL_YEARLY  — 서울 전체 연도별 집계
# ════════════════════════════════════════════════════════════════
cat("\n── 5. SEOUL_YEARLY 집계 중...\n")

seoul_agg <- waste_clean %>%
  group_by(year) %>%
  summarise(
    living_waste        = sum(living_waste,        na.rm = TRUE),
    living_recycle      = sum(living_recycle,      na.rm = TRUE),
    living_incineration = sum(living_incineration, na.rm = TRUE),
    living_landfill     = sum(living_landfill,     na.rm = TRUE),
    total_waste         = sum(total_waste,         na.rm = TRUE),
    total_recycle       = sum(total_recycle,       na.rm = TRUE),
    total_incineration  = sum(total_incineration,  na.rm = TRUE),
    total_landfill      = sum(total_landfill,      na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    daily_avg               = round(living_waste / 365, 1),
    recycle_rate            = round(living_recycle / living_waste * 100, 1),
    incineration_rate       = round(living_incineration / living_waste * 100, 1),
    landfill_rate           = round(living_landfill / living_waste * 100, 1),
    total_recycle_rate      = round(total_recycle / total_waste * 100, 1),
    total_incineration_rate = round(total_incineration / total_waste * 100, 1),
    total_landfill_rate     = round(total_landfill / total_waste * 100, 1)
  )

seoul_yearly_list <- setNames(
  lapply(seq_len(nrow(seoul_agg)), function(i) {
    r <- seoul_agg[i, ]
    list(
      living_waste            = as.integer(r$living_waste),
      living_recycle          = as.integer(r$living_recycle),
      living_incineration     = as.integer(r$living_incineration),
      living_landfill         = as.integer(r$living_landfill),
      total_waste             = as.integer(r$total_waste),
      total_recycle           = as.integer(r$total_recycle),
      total_incineration      = as.integer(r$total_incineration),
      total_landfill          = as.integer(r$total_landfill),
      daily_avg               = r$daily_avg,
      recycle_rate            = r$recycle_rate,
      incineration_rate       = r$incineration_rate,
      landfill_rate           = r$landfill_rate,
      total_recycle_rate      = r$total_recycle_rate,
      total_incineration_rate = r$total_incineration_rate,
      total_landfill_rate     = r$total_landfill_rate
    )
  }),
  as.character(seoul_agg$year)
)

cat(sprintf("  연도: %s\n", paste(names(seoul_yearly_list), collapse = ", ")))
cat(sprintf("  2024 daily_avg: %.1f / recycle_rate: %.1f%%\n",
            seoul_yearly_list[["2024"]]$daily_avg,
            seoul_yearly_list[["2024"]]$recycle_rate))

# ════════════════════════════════════════════════════════════════
# 6. FACILITY_MONTHLY  — 4개 시설 × 월별 소각 현황 (2024)
# ════════════════════════════════════════════════════════════════
cat("\n── 6. FACILITY_MONTHLY 생성 중...\n")

# 컬럼명 정리 (빈 컬럼 제거)
fac_clean <- fac %>%
  select(facility, year, month, in_ton, in_avg, inc_ton, inc_avg, util_rate) %>%
  mutate(
    in_ton    = as.integer(suppressWarnings(gsub("[^0-9]", "", in_ton))),
    in_avg    = as.integer(suppressWarnings(gsub("[^0-9]", "", in_avg))),
    inc_ton   = as.integer(suppressWarnings(gsub("[^0-9]", "", inc_ton))),
    inc_avg   = as.integer(suppressWarnings(gsub("[^0-9]", "", inc_avg))),
    util_rate = as.integer(suppressWarnings(gsub("[^0-9]", "", util_rate)))
  )

fac_facilities <- unique(fac_clean$facility)

facility_monthly_list <- setNames(
  lapply(fac_facilities, function(f) {
    rows <- fac_clean %>% filter(facility == f)

    annual_row <- rows %>% filter(month == "total")
    annual <- if (nrow(annual_row) > 0) {
      list(
        in_ton    = annual_row$in_ton[1],
        in_avg    = annual_row$in_avg[1],
        inc_ton   = annual_row$inc_ton[1],
        inc_avg   = annual_row$inc_avg[1],
        util_rate = annual_row$util_rate[1]
      )
    } else list()

    monthly_rows <- rows %>%
      filter(month != "total") %>%
      mutate(month_int = as.integer(month)) %>%
      filter(!is.na(month_int))

    monthly <- setNames(
      lapply(seq_len(nrow(monthly_rows)), function(i)
        list(
          in_avg    = monthly_rows$in_avg[i],
          inc_avg   = monthly_rows$inc_avg[i],
          util_rate = monthly_rows$util_rate[i]
        )),
      as.character(monthly_rows$month_int)
    )

    list(annual = annual, monthly = monthly)
  }),
  fac_facilities
)

cat(sprintf("  시설: %s\n", paste(fac_facilities, collapse = ", ")))
for (f in fac_facilities) {
  cat(sprintf("    %s  annual inc_avg: %d  월별 수: %d\n",
              f,
              facility_monthly_list[[f]]$annual$inc_avg %||% 0L,
              length(facility_monthly_list[[f]]$monthly)))
}

# ════════════════════════════════════════════════════════════════
# 7. MAINTENANCE_SCHEDULE  — 2026년 정비 일정 (스냅샷, 연도 무관)
# ════════════════════════════════════════════════════════════════
cat("\n── 7. MAINTENANCE_SCHEDULE 정의 중...\n")

# 출처: rrf.seoul.go.kr (2026년 실제 정비 일정)
# 이 데이터는 시계열 분석 대상이 아닌 현재 상태 스냅샷으로 취급
# capacity 단위: 톤/일 (설계 기준)
maintenance_schedule <- list(
  list(facility = "양천", capacity = 400L, start_date = "2026-04-15", end_date = "2026-05-21"),
  list(facility = "강남", capacity = 900L, start_date = "2026-06-04", end_date = "2026-07-05"),
  list(facility = "노원", capacity = 800L, start_date = "2026-09-13", end_date = "2026-10-06"),
  list(facility = "마포", capacity = 750L, start_date = "2026-10-21", end_date = "2026-11-28")
)

cat(sprintf("  시설 수: %d\n", length(maintenance_schedule)))

# ════════════════════════════════════════════════════════════════
# 8. YEARS  — 데이터에 존재하는 연도 배열
# ════════════════════════════════════════════════════════════════
years_vec <- sort(unique(waste_clean$year))
cat(sprintf("\n── 8. YEARS: %s\n", paste(years_vec, collapse = ", ")))

# ════════════════════════════════════════════════════════════════
# 9. data.js 출력
# ════════════════════════════════════════════════════════════════
cat("\n── 9. data.js 출력 중...\n")

out_path <- file.path(DASH_DIR, "data.js")

write_block <- function(name, obj, file, first = FALSE) {
  json <- toJSON(obj, auto_unbox = TRUE, pretty = FALSE, digits = 6)
  line <- sprintf("const %s = %s;\n\n", name, json)
  cat(line, file = file, append = !first)
}

# 헤더 작성
cat(
  sprintf(
    "/* Auto-generated: %s */\n/* 소스: 01_waste_by_district_year.csv, 02_district_population.csv */\n/*       03_district_coords.csv, 04_facility_2024.csv              */\n\n",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  ),
  file = out_path,
  append = FALSE
)

write_block("DISTRICT_YEAR",        district_year_list,     out_path, first = FALSE)
write_block("POP_DATA",             pop_list,               out_path)
write_block("COORD_DATA",           coord_list,             out_path)
write_block("SEOUL_YEARLY",         seoul_yearly_list,      out_path)
write_block("FACILITY_MONTHLY",     facility_monthly_list,  out_path)
write_block("MAINTENANCE_SCHEDULE", maintenance_schedule,   out_path)

# YEARS + LATEST_YEAR + DISTRICTS 는 JS 표현식으로 추가
cat(
  sprintf("const YEARS = [%s];\n\n", paste(years_vec, collapse = ",")),
  file = out_path, append = TRUE
)
cat(
  "const LATEST_YEAR = Math.max(...YEARS);\nconst DISTRICTS = Object.keys(DISTRICT_YEAR).sort();\n",
  file = out_path, append = TRUE
)

file_size <- file.size(out_path)
cat(sprintf("✓ data.js 생성 완료: %s\n  파일 크기: %s KB\n",
            normalizePath(out_path),
            round(file_size / 1024, 1)))

# ── 검증 출력 ──────────────────────────────────────────────────
cat("\n── 검증 ──────────────────────────────────\n")
ly <- as.character(max(years_vec))
cat(sprintf("  최신 연도: %s\n", ly))
cat(sprintf("  서울 생활계 연간 발생량: %s 톤\n",
            format(seoul_yearly_list[[ly]]$living_waste, big.mark = ",")))
cat(sprintf("  서울 일평균 발생량: %.1f 톤/일\n",
            seoul_yearly_list[[ly]]$daily_avg))
cat(sprintf("  서울 생활계 재활용률: %.1f%%\n",
            seoul_yearly_list[[ly]]$recycle_rate))
cat(sprintf("  서울 총폐기물 재활용률: %.1f%%\n",
            seoul_yearly_list[[ly]]$total_recycle_rate))
fac_sum <- sum(sapply(fac_facilities, function(f)
  facility_monthly_list[[f]]$annual$inc_avg %||% 0L))
cat(sprintf("  4개 시설 연간 평균 소각 합계: %d 톤/일\n", fac_sum))
incineration_demand <- round(seoul_yearly_list[[ly]]$living_incineration / 365)
cat(sprintf("  소각 처리 대상량 (생활계 일평균): %d 톤/일\n", incineration_demand))
cat("─────────────────────────────────────────\n")
