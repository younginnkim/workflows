# tas-verify(④) 결정론 스크립트화 — 설계

2026-06-15. stage④ `/tas-verify`를 "에이전트 추론"에서 "결정론적 스크립트 실행"으로 전환한다.

## 문제
스킬이 단계 설명 + 에이전트 추론이라, 실제 빌드·배포·실행 대신 곁가지(TV IP 탐지, host-key 변경 대응,
반복 재확인, 진단)로 계속 새어나가 검증을 끝내지 못함. 오늘 실측: .2가 DHCP로 딴 장비에 재할당,
.5 host-key 변경, reboot 대기 루프가 'refused' 즉반환으로 헛돎.

## 목표
④의 기계적 로직을 **단일 스크립트 `tas-verify.sh`**에 가두고, 스킬은 입력 확보 + 1회 호출 + 판정만.
에이전트가 추론으로 샐 여지를 제거.

## 구성요소

### 1. Config 파일 `~/.tas/<appName>.conf` (앱당 1회, shell-sourceable)
```sh
APP_REPO=/home/younginkim/project/app/ref/com.webos.app.home
AUTOMATION_TESTS=/home/younginkim/project/TAS/automation-tests
FLAG_FILE=/var/luna/preferences/tas_home_enabled
FLUTTER_APP_ID=com.webos.tas.home
SAM_APP_ID=com.webos.app.home
```
= ① app-config + ②③ repo 경로. 없으면 스킬이 세션값으로 1회 생성.

### 2. `tas-verify.sh` (스킬 디렉토리에 번들)
```
tas-verify.sh --config <conf> --tc <TC경로> [--ip <IP>] [--reuse] [--force-reboot] [--dry-run]
```
공통: 모든 ssh/scp에 `-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=4`
→ host-key 변경이 영영 안 막음. `set -euo pipefail`, 각 단계 실패 시 비0 종료 + 실제 출력(추측 없음).
`--dry-run`은 실행 대신 명령만 출력.

- **A. TV 해소** (`--ip` 있으면 생략): ping sweep(`seq|xargs -P64 ping`) → `ip neigh` reachable →
  각 후보 ssh `[ -d /usr/palm/applications/$SAM_APP_ID ]`로 판별(**LGwebOSTV grep 아님**).
  정확히 1대=사용 / 0대=에러("TV 켜고 다시") / 2대+=목록 출력 후 `--ip` 요구(비0 종료).
- **B. flag + 조건부 reboot**: flag 없으면(또는 `--force-reboot`) touch+reboot.
  **대기 = `sleep 5` + ssh `uname` 성공까지 폴링**(즉반환 refused 버그 제거), ~3분 캡, 복귀 후 flag 확인.
  flag 이미 있으면 reboot 생략(D의 kill-재시작이 flag 재독).
- **C. 빌드** (`--reuse`면 생략): `cd $APP_REPO && flutter-webos build webos --ipk --release
  -t integration_test/app_test.dart --tas-service-name $FLUTTER_APP_ID` →
  `build/webos/arm/release/bundle/lib/libapp.so` 존재 확인(없으면 에러).
- **D. 배포** (libapp.so만): `scp …/bundle/lib/libapp.so root@$IP:/mnt/lg/appstore/` →
  ssh `umount …/$SAM_APP_ID/lib/libapp.so 2>/dev/null; mount --bind /mnt/lg/appstore/libapp.so
  /usr/palm/applications/$SAM_APP_ID/lib/libapp.so` → 앱 프로세스 kill.
- **E. 실행+판정**: `cd $AUTOMATION_TESTS && ./qa-test-runner.py -i $IP
  --results-files ./job_attachments_tas $TC` → 출력에서 PASS/FAIL 파싱, 종료코드 반영, 명확히 출력.

### 3. 얇은 `/tas-verify` 스킬 (SKILL.md 재작성)
(a) config 있으면 그대로, 없으면 세션 app-config로 생성 → (b) TC 결정(③ 세션 산출 또는 ASK) →
(c) `tas-verify.sh` 1회 실행 → (d) 출력 그대로 판정. 탐지·host-key·reboot 추론은 전부 스크립트 안.

## 에러 처리
각 단계 비0 종료 + 실제 명령 출력. TV 0/≥2 → actionable 에러. reboot 타임아웃 → 마지막 ssh 상태와 함께 에러.

## 파일 위치
- 스크립트: `~/project/AI/skills/tas/.claude/skills/tas-verify/tas-verify.sh`
- config: `~/.tas/<appName>.conf`
- SKILL.md: 위 (a)~(d)만 남기고 재작성

## 테스트
`--dry-run`으로 로직 검증 + TV(.5) 복귀 시 실측 1회(home_hero_banner_shown).
