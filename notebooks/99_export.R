# ════════════════════════════════════════════════
# 99_export.R — 데이터 → data.js 파이프라인
# ════════════════════════════════════════════════

library(jsonlite)

DATA_DIR <- "C:/Users/USER/OneDrive - 동국대학교/바탕 화면/유영우/빅콘/data"
DASH_DIR <- "C:/Users/USER/OneDrive - 동국대학교/바탕 화면/유영우/빅콘/dashboard"

read_csv_safe <- function(path) {
  tryCatch(
    read.csv(path, fileEncoding="UTF-8", header=FALSE, check.names=FALSE, stringsAsFactors=FALSE),
    error = function(e) read.csv(path, fileEncoding="CP949", header=FALSE, check.names=FALSE, stringsAsFactors=FALSE)
  )
}

# ════════════════════════════════════════════════
# 1. 1인당 배출량 파일 파싱 (가장 깔끔한 파일)
# ════════════════════════════════════════════════
path1 <- file.path(DATA_DIR, "주민+1인당+생활계폐기물(쓰레기)+배출량_20260325104957.csv")
raw <- read_csv_safe(path1)

# 컬럼 구조: V1=자치구명, V2~V13 = (1인당, 총량, 주민수) × 4년치
# 2024년 데이터만 사용 (V11=1인당, V12=총량, V13=주민수)
gu_2024 <- data.frame(
  n     = raw$V1[4:nrow(raw)],
  perCap= as.numeric(raw$V11[4:nrow(raw)]),  # kg/인일
  daily = as.numeric(raw$V12[4:nrow(raw)]),  # 톤/일
  pop   = as.numeric(raw$V13[4:nrow(raw)]),  # 주민수
  stringsAsFactors = FALSE
)

# 합계행 제거 (혹시 남아있으면)
gu_2024 <- gu_2024[!gu_2024$n %in% c("계","합계","소계","서울시"), ]
gu_2024 <- gu_2024[!is.na(gu_2024$daily), ]

cat("✓ 자치구 수:", nrow(gu_2024), "\n")
print(head(gu_2024))

# ════════════════════════════════════════════════
# 2. 좌표 매핑 (HTML에 박혀있던 lat/lng 그대로)
# ════════════════════════════════════════════════
coords <- data.frame(
  n = c("강남구","강동구","강북구","강서구","관악구","광진구","구로구","금천구","노원구",
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

gu <- merge(gu_2024, coords, by="n", all.x=TRUE)

# ════════════════════════════════════════════════
# 3. 임시 더미값 (실제 데이터 연결은 다음 단계)
# ════════════════════════════════════════════════
set.seed(42)
gu$recycle  <- round(runif(nrow(gu), 57, 63), 1)  # 재활용률
gu$food     <- round(runif(nrow(gu), 28, 41), 1)  # 음식물 비중
gu$inc      <- round(runif(nrow(gu), 33, 39), 1)  # 소각 비중
gu$land     <- 4
gu$livingPop<- round(gu$pop / 10000 * runif(nrow(gu), 1.0, 2.5))  # 생활인구 추정
gu$card     <- round(runif(nrow(gu), 190, 890))
gu$delivery <- round(runif(nrow(gu), 32, 96))
gu$growth   <- round(runif(nrow(gu), 0.7, 2.4), 1)

# ════════════════════════════════════════════════
# 4. 클러스터링 (KMeans 5개)
# ════════════════════════════════════════════════
features <- gu[, c("daily","livingPop","card","delivery")]
features_scaled <- scale(features)
set.seed(42)
km <- kmeans(features_scaled, centers=5, nstart=25)
gu$cluster <- km$cluster - 1   # JS는 0-indexed!

cat("\n✓ 클러스터링 결과:\n")
print(table(gu$cluster))

# ════════════════════════════════════════════════
# 5. data.js로 export
# ════════════════════════════════════════════════
# 컬럼 순서를 JS 코드가 기대하는 순서로
gu_out <- gu[, c("n","lat","lng","daily","pop","recycle","food","inc","land",
                 "cluster","livingPop","card","delivery","growth")]

write_block <- function(name, obj, file, append=TRUE) {
  json <- toJSON(obj, auto_unbox=TRUE, pretty=FALSE)
  cat(paste0("const ", name, " = ", json, ";\n\n"),
      file=file, append=append)
}

out_file <- file.path(DASH_DIR, "data.js")
cat("/* Auto-generated: ", as.character(Sys.time()), " */\n\n", 
    file=out_file, append=FALSE)
write_block("GU", gu_out, out_file)

cat("\n✓ data.js 생성 완료:", out_file, "\n")
cat("  크기:", file.size(out_file), "bytes\n")
