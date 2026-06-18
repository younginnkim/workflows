#!/usr/bin/env bash
# tas-verify.sh — TAS ④ 결정론 실행
#   TV 자동탐지 → flag+조건부reboot → 빌드 → libapp.so 배포 → qa-test-runner 실행·판정
# 전제: PC→TV 무암호(key) ssh. 모든 단계 실패 시 비0 종료 + 실제 출력(추측 없음).
set -euo pipefail

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4 -o BatchMode=yes)

err(){ echo "[tas-verify][ERROR] $*" >&2; exit 1; }
log(){ echo "[tas-verify] $*"; }

CONFIG="" IP="" REUSE=0 FORCE_REBOOT=0 DRYRUN=0 EXEC_ONLY=0
TCS=()   # --tc 여러 번 허용: A~D는 1회, E(테스트 실행)만 TC마다 반복
while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="${2:-}"; shift 2;;
    --tc)     TCS+=("${2:-}"); shift 2;;
    --ip)     IP="${2:-}"; shift 2;;
    --reuse)  REUSE=1; shift;;
    --exec-only) EXEC_ONLY=1; shift;;   # B(flag/reboot)·C(빌드)·D(배포/mount) 생략, 기존 mount로 E만
    --force-reboot) FORCE_REBOOT=1; shift;;
    --dry-run) DRYRUN=1; shift;;
    -h|--help) echo "usage: tas-verify.sh --config <conf> --tc <TC> [--tc <TC> ...] [--ip IP] [--reuse] [--exec-only] [--force-reboot] [--dry-run]"; exit 0;;
    *) err "unknown arg: $1";;
  esac
done

[ -n "$CONFIG" ] || err "--config 필요"
[ -f "$CONFIG" ] || err "config 없음: $CONFIG"
[ "${#TCS[@]}" -gt 0 ] || err "--tc 필요(1개 이상)"
# shellcheck disable=SC1090
source "$CONFIG"
for v in APP_REPO AUTOMATION_TESTS FLAG_FILE FLUTTER_APP_ID SAM_APP_ID; do
  [ -n "${!v:-}" ] || err "config에 $v 없음: $CONFIG"
done
APP_REPO="${APP_REPO/#\~/$HOME}"
AUTOMATION_TESTS="${AUTOMATION_TESTS/#\~/$HOME}"

# 서브넷: config SUBNET > PC 기본경로 src에서 유추 > 192.168.0
SUBNET_PREFIX="${SUBNET:-}"
if [ -z "$SUBNET_PREFIX" ]; then
  src=$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}') || true
  SUBNET_PREFIX="${src%.*}"; [ -n "$SUBNET_PREFIX" ] || SUBNET_PREFIX="192.168.0"
fi

# ── A. TV 탐지 (webOS = /usr/palm/applications/$SAM_APP_ID 존재로 판별) ──
discover_tv(){
  log "A. TV 탐지 ($SUBNET_PREFIX.0/24, webOS = /usr/palm/applications/$SAM_APP_ID)"
  if [ "$DRYRUN" = 1 ]; then
    echo "  + ping sweep $SUBNET_PREFIX.1-254 → ip neigh → ssh 각 후보 '[ -d /usr/palm/applications/$SAM_APP_ID ]'"
    IP="<auto>"; return
  fi
  seq 1 254 | xargs -P64 -I{} ping -c1 -W1 "$SUBNET_PREFIX.{}" >/dev/null 2>&1 || true
  local found=() ip
  for ip in $(ip neigh | grep -E "^${SUBNET_PREFIX//./\\.}\\." | grep -E 'REACHABLE|STALE|DELAY' | awk '{print $1}' | sort -u); do
    if ssh "${SSH_OPTS[@]}" "root@$ip" "[ -d /usr/palm/applications/$SAM_APP_ID ]" >/dev/null 2>&1; then
      found+=("$ip")
    fi
  done
  case "${#found[@]}" in
    1) IP="${found[0]}"; log "  TV = $IP";;
    0) err "webOS TV($SAM_APP_ID) 안 보임 — TV 켜고/네트워크 연결 후 다시. (또는 --ip 지정)";;
    *) err "TV 여러 대 발견: ${found[*]} — --ip 로 하나 지정";;
  esac
}

# ── B. flag + 조건부 reboot ──
flag_and_reboot(){
  log "B. flag + 조건부 reboot"
  if [ "$DRYRUN" = 1 ]; then
    echo "  + (flag 없거나 --force-reboot면) ssh root@$IP 'touch $FLAG_FILE; sync; reboot'"
    echo "  + 복귀 대기: sleep 5 + ssh uname 폴링 (~180s)"
    return
  fi
  local has_flag=1
  ssh "${SSH_OPTS[@]}" "root@$IP" "[ -f $FLAG_FILE ]" >/dev/null 2>&1 || has_flag=0
  if [ "$FORCE_REBOOT" = 1 ] || [ "$has_flag" = 0 ]; then
    log "  flag touch + reboot (has_flag=$has_flag, force=$FORCE_REBOOT)"
    timeout 10 ssh "${SSH_OPTS[@]}" "root@$IP" "touch $FLAG_FILE; sync; reboot" >/dev/null 2>&1 || true
    log "  reboot 전송 — 복귀 대기"
    local up=0 i
    for i in $(seq 1 36); do
      sleep 5
      if ssh "${SSH_OPTS[@]}" "root@$IP" "uname -m" >/dev/null 2>&1; then up=1; log "  TV UP (~$((i*5))s)"; break; fi
      log "  ...대기 $((i*5))s"
    done
    [ "$up" = 1 ] || err "reboot 후 TV 복귀 실패(~180s) — IP=$IP"
    ssh "${SSH_OPTS[@]}" "root@$IP" "[ -f $FLAG_FILE ]" >/dev/null 2>&1 || err "복귀했으나 flag 없음: $FLAG_FILE"
  else
    log "  flag 존재 → reboot 생략 (배포 kill-재시작이 flag 재독)"
  fi
}

# ── C. 빌드 ──
LIBAPP=""
build_app(){
  LIBAPP="$APP_REPO/build/webos/arm/release/bundle/lib/libapp.so"
  if [ "$REUSE" = 1 ]; then
    log "C. 빌드 생략 (--reuse) — 기존 산출물 사용"
  else
    log "C. 빌드 (flutter-webos, --tas-service-name $FLUTTER_APP_ID)"
    if [ "$DRYRUN" = 1 ]; then
      echo "  + cd $APP_REPO && flutter-webos build webos --ipk --release -t integration_test/app_test.dart --tas-service-name $FLUTTER_APP_ID"
    else
      ( cd "$APP_REPO" && flutter-webos build webos --ipk --release -t integration_test/app_test.dart --tas-service-name "$FLUTTER_APP_ID" )
    fi
  fi
  [ "$DRYRUN" = 1 ] && return
  [ -f "$LIBAPP" ] || err "libapp.so 없음: $LIBAPP (빌드 실패 또는 --reuse인데 산출물 없음)"
}

# ── D. 배포 (앱 폴더 전체 mount-bind hot-swap) ──
deploy(){
  local bundle="$APP_REPO/build/webos/arm/release/bundle"
  local tgt="/usr/palm/applications/$SAM_APP_ID"
  local stage="/mnt/lg/appstore/$SAM_APP_ID"
  log "D. 배포 (앱 폴더 전체 mount-bind → $tgt)"
  [ "$DRYRUN" = 1 ] || [ -d "$bundle" ] || err "bundle 디렉토리 없음: $bundle"
  if [ "$DRYRUN" = 1 ]; then
    echo "  + ssh root@$IP 'umount $tgt 2>/dev/null; rm -rf $stage; mkdir -p $stage'"
    echo "  + tar -C $bundle -cf - . | ssh root@$IP 'tar -C $stage -xf -'"
    echo "  + ssh root@$IP 'mount --bind $stage $tgt && ls -l $tgt; kill $SAM_APP_ID'"
    return
  fi
  ssh "${SSH_OPTS[@]}" "root@$IP" "umount $tgt 2>/dev/null; rm -rf $stage; mkdir -p $stage" >/dev/null 2>&1 || true
  # 임베디드 scp(dropbear/busybox)는 소스 끝 '/.' 를 파일명으로 거부 → tar 파이프로 폴더 통째 전송
  tar -C "$bundle" -cf - . | ssh "${SSH_OPTS[@]}" "root@$IP" "tar -C $stage -xf -"
  ssh "${SSH_OPTS[@]}" "root@$IP" \
    "mount --bind $stage $tgt && ls -l $tgt; ps -aux | grep $SAM_APP_ID | grep -v grep | awk '{print \$2}' | xargs -r kill -9" \
    >/dev/null 2>&1 || true
  log "  배포 + 앱 재시작 완료"
}

# ── E. 실행 + 판정 (TC 1개) ──
VERDICTS=()   # "✅ PASS\t<tc>" 형태로 누적 (전체 요약용)
run_test(){
  local TC="$1" idx="$2" n="$3" stem
  stem="$(basename "$TC")"
  log "E[$idx/$n]. qa-test-runner 실행 + 판정 — $stem"
  if [ "$DRYRUN" = 1 ]; then
    echo "  + cd $AUTOMATION_TESTS && ./qa-test-runner.py -i $IP --results-files ./job_attachments_tas $TC"
    VERDICTS+=("· DRYRUN	$stem"); return 0
  fi
  local out rc
  set +e
  out=$( cd "$AUTOMATION_TESTS" && ./qa-test-runner.py -i "$IP" --results-files ./job_attachments_tas "$TC" 2>&1 )
  rc=$?
  set -e
  echo "$out" | tail -40
  local total passed pwarn skipped failed
  total=$(echo "$out" | grep -E "^ *TOTAL" | tail -1)
  read -r _ passed pwarn skipped failed <<<"$total"
  if   [ "${failed:-0}" -gt 0 ] 2>/dev/null; then log "판정: ❌ FAIL (failed=$failed)"; VERDICTS+=("❌ FAIL	$stem"); return 1
  elif [ "${passed:-0}" -gt 0 ] 2>/dev/null; then log "판정: ✅ PASS (passed=$passed)"; VERDICTS+=("✅ PASS	$stem"); return 0
  else log "판정: ⚠️ 불명확 (runner rc=$rc) — 위 출력 확인"; VERDICTS+=("⚠️ 불명확	$stem"); return 2; fi
}

# ── main ──
log "config=$CONFIG  TCs=${#TCS[@]}개  reuse=$REUSE  exec_only=$EXEC_ONLY  force_reboot=$FORCE_REBOOT  dry_run=$DRYRUN"

# A. TV (항상: E에도 IP 필요)
if [ -n "$IP" ]; then log "A. TV IP(지정) = $IP"; else discover_tv; fi

# B·C·D — 첫 1회만 (--exec-only면 통째 생략, 기존 mount 재사용)
if [ "$EXEC_ONLY" = 1 ]; then
  log "B·C·D 생략 (--exec-only) — 기존 빌드/배포/mount 재사용. E만 TC마다 실행."
else
  flag_and_reboot   # B
  build_app         # C (--reuse면 빌드만 생략)
  deploy            # D (mount-bind 1회)
fi

# E — TC마다 반복 (.py만 갈아끼우며 실행)
n="${#TCS[@]}"; i=0; fail_any=0
for tc in "${TCS[@]}"; do
  i=$((i+1))
  run_test "$tc" "$i" "$n" || fail_any=1
done

# 전체 요약
if [ "$n" -gt 1 ]; then
  echo "[tas-verify] ===== 전체 판정 요약 ($n개) ====="
  for v in "${VERDICTS[@]}"; do printf '[tas-verify]   %b\n' "$v"; done
fi
exit "$fail_any"
