# ════════════════════════════════════════════════════════════════
# 99_export.R — 전처리 CSV → data.js 파이프라인
# 입력 파일 (DATA_DIR):
#   per_capita.csv          자치구별 일 발생량·주민수·1인당 (2024 스냅샷)
#   trash_process.csv       자치구별 처리현황 비율 (재활용/소각/매립, 2024)
#   food_split.csv          음식물폐기물 가정/사업장 비중 (2024)
#   recycle_industry.csv    폐기물 유형별 발생 비중 (생활/사업장/건설/지정)
#   waste_integrated.csv    자치구×연도 통합 데이터셋 (2020-2024)
# 출력 파일 (DASH_DIR):
#   data.js                 GU 배열 + RECYCLE_INDUSTRY 객체 + YEARLY 객체
# ════════════════════════════════════════════════════════════════

library(jsonlite)
library(dplyr)

# ── 경로 설정 (팀 환경에 맞게 수정) ────────────────────────────
DATA_DIR <- "C:/Users/USER/OneDrive - 동국대학교/바탕 화면/유영우/빅콘/data"
DASH_DIR <- "C:/Users/USER/OneDrive - 동국대학교/바탕 화면/유영우/빅콘/dashboard"

# ── 안전 CSV 읽기 (UTF-8 / CP949 자동 fallback) ─────────────────
read_csv_safe <- function(path) {
  tryCatch(
    read.csv(path, fileEncoding = "UTF-8",  check.names = FALSE, stringsAsFactors = FALSE),
    error = function(e)
      read.csv(path, fileEncoding = "CP949", check.names = FALSE, stringsAsFactors = FALSE)
  )
}

# ════════════════════════════════════════════════════════════════
# 1. CSV 로드
# ════════════════════════════════════════════════════════════════
cat("── 1. CSV 로드 중...\n")

per_cap     <- read_csv_safe(file.path(DATA_DIR, "per_capita.csv"))
trash_pr    <- read_csv_safe(file.path(DATA_DIR, "trash_process.csv"))
food_sp     <- read_csv_safe(file.path(DATA_DIR, "food_split.csv"))
recycle_ind <- read_csv_safe(file.path(DATA_DIR, "recycle_industry.csv"))
waste_int   <- read_csv_safe(file.path(DATA_DIR, "waste_integrated.csv"))

cat("  per_capita      :", nrow(per_cap),      "행\n")
cat("  trash_process   :", nrow(trash_pr),    "행\n")
cat("  food_split      :", nrow(food_sp),     "행\n")
cat("  recycle_industry:", nrow(recycle_ind), "행\n")
cat("  waste_integrated:", nrow(waste_int),   "행\n")

# ════════════════════════════════════════════════════════════════
# 2. GU 배열 — 자치구별 2024 스냅샷
# ════════════════════════════════════════════════════════════════
cat("\n── 2. GU 배열 생성 중...\n")

# 2-1. 기본 (일 발생량 / 주민수 / 1인당)
gu <- per_cap %>%
  rename(n = district)

# 2-2. 처리현황 비율 (% 변환)
tp <- trash_pr %>%
  rename(n = district) %>%
  mutate(
    recycle = round(recycle_pct  * 100, 1),
    inc     = round(incin_pct    * 100, 1),
    land    = round(landfill_pct * 100, 1)
  ) %>%
  select(n, recycle, inc, land)

gu <- gu %>% left_join(tp, by = "n")

# 2-3. 음식물 비중 — waste_integrated 2024 food_intensity (%)
wi2024 <- waste_int %>%
  filter(year == 2024) %>%
  mutate(food = round(food_intensity * 100, 1)) %>%
  select(district, food) %>%
  rename(n = district)

gu <- gu %>% left_join(wi2024, by = "n")

# 2-4. 음식물 가정/사업장 비중
fs <- food_sp %>%
  rename(n = district) %>%
  mutate(
    homeProp = round(home_prop * 100, 1),
    bizProp  = round(biz_prop  * 100, 1)
  ) %>%
  select(n, homeProp, bizProp)

gu <- gu %>% left_join(fs, by = "n")

# 2-5. 좌표 (25개 자치구 고정값)
coords <- data.frame(
  n   = c("강남구","강동구","강북구","강서구","관악구","광진구","구로구","금천구","노원구",
           "도봉구","동대문구","동작구","마포구","서대문구","서초구","성동구","성북구","송파구",
           "양천구","영등포구","용산구","은평구","종로구","중구","중랑구"),
  lat = c(37.517,37.530,37.640,37.550,37.478,37.538,37.495,37.457,37.655,37.669,37.574,
          37.512,37.566,37.579,37.483,37.563,37.606,37.515,37.517,37.526,37.532,37.603,
          37.573,37.564,37.606),
  lng = c(127.047,127.124,127.025,126.849,126.952,127.082,126.886,126.896,127.056,127.047,
          127.040,126.940,126.902,126.937,127.033,127.037,127.017,127.105,126.867,126.896,
          126.990,126.929,126.979,126.998,127.093),
  stringsAsFactors = FALSE
)

gu <- gu %>% left_join(coords, by = "n")

# 2-6. 클러스터 (기존 KMeans 결과 유지 — daily/pop 기반)
cluster_map <- c(
  "종로구"=1,"중구"=1,"용산구"=1,"성동구"=3,"광진구"=1,"동대문구"=1,"중랑구"=4,
  "성북구"=1,"강북구"=1,"도봉구"=1,"노원구"=4,"은평구"=4,"서대문구"=4,"마포구"=4,
  "양천구"=4,"강서구"=0,"구로구"=4,"금천구"=1,"영등포구"=1,"동작구"=1,"관악구"=3,
  "서초구"=1,"강남구"=2,"송파구"=2,"강동구"=1
)
gu$cluster <- cluster_map[gu$n]

# 2-7. 더미 컬럼 (외부 데이터 미확보 — 추후 교체)
gu$livingPop <- 0L
gu$card      <- 0L
gu$delivery  <- 0L
gu$growth    <- 0.0

# 2-8. 컬럼 순서 정렬 및 NA → 0 처리
gu_out <- gu %>%
  select(n, lat, lng, daily, pop, perCap,
         recycle, food, inc, land,
         homeProp, bizProp,
         livingPop, card, delivery, growth, cluster)

gu_out[is.na(gu_out)] <- 0

cat("  자치구 수:", nrow(gu_out), "\n")
print(head(gu_out[, c("n","daily","recycle","inc","land","food","cluster")]))

# ════════════════════════════════════════════════════════════════
# 3. RECYCLE_INDUSTRY 객체
# ════════════════════════════════════════════════════════════════
cat("\n── 3. RECYCLE_INDUSTRY 생성 중...\n")

ri <- recycle_ind %>%
  rename(n = district) %>%
  mutate(
    life         = round(life_pct,         1),
    industry     = round(industry_pct,     1),
    construction = round(construction_pct, 1),
    designated   = round(designated_pct,   1)
  ) %>%
  select(n, life, industry, construction, designated)

ri_list <- setNames(
  lapply(seq_len(nrow(ri)), function(i) {
    list(life         = ri$life[i],
         industry     = ri$industry[i],
         construction = ri$construction[i],
         designated   = ri$designated[i])
  }),
  ri$n
)

cat("  자치구 수:", length(ri_list), "\n")

# ════════════════════════════════════════════════════════════════
# 4. YEARLY 객체 — waste_integrated 연도별 서울 합계
# ════════════════════════════════════════════════════════════════
cat("\n── 4. YEARLY 집계 중...\n")

yearly_raw <- waste_int %>%
  group_by(year) %>%
  summarise(
    living_waste_sum        = sum(living_waste,          na.rm = TRUE),
    living_recycle_sum      = sum(living_recycle,        na.rm = TRUE),
    living_incineration_sum = sum(living_incineration,   na.rm = TRUE),
    living_landfill_sum     = sum(living_landfill,       na.rm = TRUE),
    food_waste_sum          = sum(food_waste,             na.rm = TRUE),
    per_capita_mean         = mean(per_capita_living_waste, na.rm = TRUE),
    recycle_rate_mean       = mean(recycle_rate,          na.rm = TRUE),
    incineration_rate_mean  = mean(incineration_rate,     na.rm = TRUE),
    landfill_rate_mean      = mean(landfill_rate,         na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    total            = round(living_waste_sum        / 10000, 1),
    recycle          = round(living_recycle_sum      / 10000, 1),
    incineration     = round(living_incineration_sum / 10000, 1),
    landfill         = round(living_landfill_sum     / 10000, 1),
    food             = round(food_waste_sum          / 10000, 1),
    perCap           = round(per_capita_mean, 3),
    recycle_pct      = round(recycle_rate_mean      * 100, 1),
    incineration_pct = round(incineration_rate_mean * 100, 1),
    landfill_pct     = round(landfill_rate_mean     * 100, 1),
    daily_avg        = round(living_waste_sum / 365, 1),
    etc_pct          = round(100 - recycle_pct - incineration_pct - landfill_pct, 1)
  )

yearly_list <- setNames(
  lapply(seq_len(nrow(yearly_raw)), function(i) {
    r <- yearly_raw[i, ]
    list(
      total            = r$total,
      recycle          = r$recycle,
      incineration     = r$incineration,
      landfill         = r$landfill,
      food             = r$food,
      perCap           = r$perCap,
      recycle_pct      = r$recycle_pct,
      incineration_pct = r$incineration_pct,
      landfill_pct     = r$landfill_pct,
      etc_pct          = r$etc_pct,
      daily_avg        = r$daily_avg
    )
  }),
  as.character(yearly_raw$year)
)

cat("  연도 범위:", paste(names(yearly_list), collapse = ", "), "\n")
print(yearly_raw[, c("year","total","recycle_pct","incineration_pct","landfill_pct","perCap","daily_avg")])

# ════════════════════════════════════════════════════════════════
# 5. data.js 출력
# ════════════════════════════════════════════════════════════════
cat("\n── 5. data.js 생성 중...\n")

out_file <- file.path(DASH_DIR, "data.js")

write_block <- function(name, obj, file, append = TRUE) {
  json <- toJSON(obj, auto_unbox = TRUE, pretty = FALSE)
  cat(paste0("const ", name, " = ", json, ";\n\n"),
      file = file, append = append)
}

cat(paste0(
  "/* Auto-generated: ", as.character(Sys.time()), " */\n",
  "/* 소스: per_capita.csv + trash_process.csv + food_split.csv */\n",
  "/*       recycle_industry.csv + waste_integrated.csv          */\n\n"
), file = out_file, append = FALSE)

write_block("GU",               gu_out,      out_file, append = TRUE)
write_block("RECYCLE_INDUSTRY", ri_list,     out_file, append = TRUE)
write_block("YEARLY",           yearly_list, out_file, append = TRUE)

cat("✓ data.js 생성 완료:", out_file, "\n")
cat("  파일 크기:", file.size(out_file), "bytes\n")
