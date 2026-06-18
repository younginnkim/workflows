# tas-parse IR — step별 precondition/expected 구조 변경

날짜: 2026-06-16
범위: TAS 자동화 stage ①(`/tas-parse`)만. ②③은 문서로 영향만 명시(코드 변경 X).

## 문제

기존 IR은 top-level `preconditions[]` + flat `steps[]`(lowered intent) + top-level
`expected[]` 구조다. FeatureBAT 티켓(예: TVDEVTC-23796)은 7개의 **독립 sub-check**를
한 티켓에 담는데, 이를 단일 선형 `steps[]`로 평탄화하면 의미가 깨진다:
step 8(Media Discovery 실행) 후 home이 foreground가 아니게 되어 그 뒤 step이
선형 실행 시 잘못된다. 7개는 "공통 precondition을 공유하는 독립 체크"지 한 줄 흐름이
아니다. (실제 featureBAT는 체크별 `.py` 파일로 분리되어 있다.)

## 해결: step을 자기완결 단위로

각 TC sub-check = `{id, name, preconditions, actions, expected}`를 가지는 자기완결
시나리오. precondition/expected를 step별로 둔다.

### 새 IR 구조

```yaml
test_case_id: <TC 전체 snake_case slug>
title: <문자열>
source_ticket: <Zephyr 키 또는 null>
target_app: <appId 또는 null>
preconditions:                 # TC 전체 공통(주로 environment; 스크립트 코드 미생성)
  - { kind, value, app, source_span }
steps:                         # 각 TC sub-check = 자기완결 시나리오
  - id: <1부터 오름차순 정수>
    name: <snake_case 슬러그 — ③ 파일명 힌트, 예: hero_banner_shown>
    preconditions:             # 이 시나리오에만 필요(예: app_lifecycle resumed)
      - { kind, value, app, source_span }
    actions:                   # 구 steps(lowered intent)
      - id: <step 내 1부터 오름차순>
        intent: find | focus_move | key_press | tap | scroll | wait | read_property
        target: {...}          # target-intent일 때
        key: OK|UP|DOWN|LEFT|RIGHT|BACK|HOME   # key_press일 때
        source_span: ...
    expected:                  # 이 시나리오의 기대결과
      - { kind, value, params, source_span }
unresolved: []
```

### 현재 대비 변화

1. `steps[]`가 바깥 그룹으로 승격 — 각 step = `{id, name, preconditions, actions, expected}`
2. lowered intent: top-level `steps` → step별 `actions`(개명)
3. `expected`: top-level → step별
4. `preconditions`: top-level(글로벌) + step별(시나리오) 하이브리드
5. step별 `name`(snake_case) 신설 — 다운스트림 파일명 힌트
6. action `id`: 각 step 안에서 1부터

### 불변식 (갱신)

- 필수 top 필드: `test_case_id`, `title`, `steps`
- 각 step: `id`(정수, top레벨 1부터 오름차순, bool 불가), `name`(snake_case),
  `actions`≥1, `expected`≥1
- action `id`: step 내 1부터 오름차순 정수(bool 불가)
- `intent` enum, `key_press`→유효 `key`, target-intent→`target` 필수
- `target.match`는 `text/key/index`만 (TypeName/property 누수 금지)
- precond/expected `kind` enum, `app_lifecycle` value는 LIFECYCLE enum
- 모든 precondition/action/expected 항목에 verbatim `source_span`
- `unresolved` 비어있지 않으면 ESCALATE

### lowering 규칙 (변경점만)

- "버튼/항목 클릭·선택" → 같은 step의 `actions`에 `focus_move`+`key_press: OK` 두 개로,
  원문 한 줄 source_span 공유 (기존과 동일, 단 위치가 step.actions).
- "앱을 실행/foreground" → 해당 step의 `preconditions` `app_lifecycle: resumed`.
  TC 전체 공통 환경 설정(network/agreements/ad 등)은 top-level `preconditions`.

## 다운스트림 영향 (②③ 정렬 — 후속으로 완료됨)

- **appgen-schema.md / tas-appgen SKILL.md**: binding이 IR step을 가리키도록 —
  target action은 `(step_id, action_id)`, expected는 `(step_id, expected_index)`. 해소 절차는
  "모든 step 순회"로. ✅ 완료
- **tasgen-mapping.md / tas-tasgen SKILL.md**: **IR step 1개 = 스크립트 파일 1개**
  (`<appName>_<step.name>.py`, 예: `home_hero_banner_shown.py`). 그 step의 actions→expected만 담음.
  dispatch 표·워크드 예시도 step별로 갱신. ✅ 완료

## 손댈 파일 (stage 1)

1. `.claude/skills/tas-parse/reference/ir-schema.md` — 새 스키마/불변식/lowering/다운스트림 경고
2. `.claude/skills/tas-parse/SKILL.md` — 생성 지침 갱신(각 Zephyr step→IR step, 글로벌 env→top-level)
3. `verification/tas-parse/tas-parse-check.py` — 중첩 스키마 검증

## 검증

TVDEVTC-23796을 새 구조로 재생성 → 체커 PASS, 그리고 평탄화 갭 소멸(각 step 자기완결)을
results.md에 기록. 이게 변경 성공의 증거.
