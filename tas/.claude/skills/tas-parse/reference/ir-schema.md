# Stage ① semantic IR — 스키마 & 생성 규칙

webOS Flutter TAS TestCase를 **app-agnostic semantic IR**로 변환할 때 따르는 규칙.
출력은 "의미(역할 + 식별 단서 + 액션 + 기대결과)"만 담는다.

IR은 **각 TC sub-check(시나리오)를 자기완결 `step`으로** 담는다 —
`step = {id, name, preconditions, actions, expected}`. FeatureBAT처럼 한 티켓에 여러
독립 체크가 있을 때, 이를 하나의 선형 흐름으로 평탄화하지 않기 위함이다.

## HARD RULES (반드시 지킨다)

- **명시된 것만 추출.** TC가 말하지 않은 위젯·식별자·키·스텝을 지어내지 않는다(위젯 유추 금지).
- **TypeName/property 금지.** 위젯 클래스명이나 property 값을 IR에 넣지 않는다.
- **모든 요소에 `source_span`.** preconditions/actions/expected의 각 항목은 그 근거가 된 TC
  원문을 **그대로 인용한 `source_span`**을 가진다(역추적 = 환각 검출 근거).
- **모호하면 추측 대신 `unresolved`.** "그 버튼", "적당히", "화면이 바뀜"처럼 식별자/기대상태가
  불명확하면 `unresolved`에 `{reason, source_span}`으로 남긴다. (unresolved가 비어있지 않으면
  최종 상태는 ESCALATE가 된다.)
- **foreground == `app_lifecycle` value `resumed`.**
- **각 TC sub-check는 별도 `step`.** TC가 여러 독립 체크(예: "X is shown", "Y is shown",
  "Z를 선택하면 앱 실행")를 담으면 각각을 자기 `preconditions/actions/expected`를 가진 `step`으로
  분리한다. 한 `step`의 actions를 다른 `step`이 이어받는다고 가정하지 않는다(각 step은 자기 precondition
  에서 새로 시작).

## Lowering 규칙 (webOS TV 관례 — 지어내는 게 아니라 도메인 사실)

webOS TV는 터치가 없고 리모컨 포커스+OK로만 조작한다. 따라서 다음은 **추측이 아니라 결정적 변환**이며,
verbatim source_span만 지키면 HARD RULE을 깨지 않는다.

- **"버튼/항목 클릭·선택·누름" → 같은 step의 `actions`에 두 항목:** `focus_move`(target) →
  `key_press: OK`. 두 action은 **같은 TC 원문 한 줄을 source_span으로 공유**한다(분해 문장을 새로
  짓지 않는다). `tap`은 **실제 터치/포인터가 명시된 경우에만** 쓴다(TV 리모컨 시나리오엔 거의 안 씀).
- **"앱을 실행한다/켠다" → 그 step의 `preconditions` `app_lifecycle: resumed`** (해당 appId).
  `launch` intent는 없다. 그 앱이 components/본문에 명시되면 `target_app`도 채운다.
- **TC 전체에 공통인 환경·설정 사전조건**("network connected", "user agreements allowed",
  "ad setting on" 등)은 step별이 아니라 **top-level `preconditions`**(kind `environment`)에 둔다.
- **`expected.value`는 문장이 아니라 토큰.** "검색(voice) 앱이 실행된다" → `app_launch` / `value: voice`
  (괄호 안 식별 토큰이 TC에 있으면 그걸 쓴다; 없으면 보이는 앱 이름). `②`가 appId/launchPointId로 푼다.
- **title/test_case_id/step.name:** summary가 `[TEST] …`처럼 비서술적이면 시나리오에서 유도한다
  (title=한글 시나리오 한 줄, test_case_id=짧은 snake_case). 각 step의 `name`은 그 체크를 나타내는
  snake_case 슬러그(예: `hero_banner_shown`)로 — ③이 `<app>_<name>.py` 분리에 쓴다.
  단 `source_ticket`은 보유한 키를 항상 채운다(추적성).

## IR 모양 (YAML)

```yaml
test_case_id: <title에서 파생한 snake_case slug>
title: <문자열>
source_ticket: <Zephyr 키 또는 null>
target_app: <appId, TC에 명시됐을 때만; 없으면 null>
preconditions:            # TC 전체 공통 사전조건 (주로 environment). 비어있어도 됨.
  - kind: app_lifecycle | focused | property_value | environment
    value: >
      <app_lifecycle: resumed|inactive|paused|detached|hidden /
       environment: 필요한 환경·설정 상태 서술(자유 문자열, 예: "network connected",
       "user agreements allowed", "ad setting on")>
    app: <appId 또는 null>
    source_span: <TC 원문 인용>
    # environment = 디바이스 환경/설정 사전조건. UI 인터랙션이 아니라 ④ 환경셋업(또는 수동)이
    # 보장한다 → 생성되는 TAS 스크립트 본문 코드로는 안 들어간다(설정 항목으로 분리).
steps:                    # 각 TC sub-check = 자기완결 시나리오
  - id: <1부터 오름차순 정수>
    name: <snake_case 슬러그, 예: hero_banner_shown>
    preconditions:        # 이 시나리오에만 필요한 사전조건 (예: 앱 실행). 비어있어도 됨.
      - kind: app_lifecycle | focused | property_value | environment
        value: <위와 동일>
        app: <appId 또는 null>
        source_span: <TC 원문 인용>
    actions:              # lowered intents (이 step 안에서만 유효, id 1부터)
      - id: <step 내 1부터 오름차순 정수>
        intent: find | focus_move | key_press | tap | scroll | wait | read_property
        target:                 # find/focus_move/tap/scroll/read_property 일 때 필수
          role: button | list | item | banner | icon | text | container   # 의미적 힌트(열린 집합)
          match:                # TC가 명시한 식별 단서만 채운다 (없으면 null)
            text: <보이는 라벨/문구 또는 null>     # → findByText 후보
            key: <TC에 명시된 식별자 또는 null>    # → findByKey 후보
            index: <위치 정수("첫 번째" 등) 또는 null>  # → findAt 후보
          container: <의미적 부모 맥락 또는 null>
        key: OK | UP | DOWN | LEFT | RIGHT | BACK | HOME   # key_press 일 때만 필수
        source_span: <TC 원문 인용>
    expected:             # 이 시나리오의 기대결과 (1개 이상)
      - kind: app_launch | widget_visible | property_value | state_change | navigation
        value: <문자열>
        params: <맵 또는 null>   # TC에 명시된 경우만 (예: {launchPointId: search})
        source_span: <TC 원문 인용>
unresolved: []   # 모호한 부분: [{reason: <설명>, source_span: <TC 원문 인용>}, ...]
```

## 불변식 (생성 시 반드시 지킨다)

- 필수 top 필드: `test_case_id`, `title`, `steps`.
- 각 `step`: `id`(정수, top레벨 1부터 오름차순, 불리언 불가), `name`(snake_case 문자열),
  `actions`(1개 이상), `expected`(1개 이상).
- `actions[].id`는 그 step 안에서 1부터 오름차순 정수(불리언 불가).
- `intent`는 enum, `key_press`는 유효한 `key` 필수, `find/focus_move/tap/scroll/read_property`는
  `target` 필수.
- 모든 preconditions(top + step)/actions/expected 항목에 `source_span` 존재.
- `preconditions[].kind`/`expected[].kind`는 위 enum, `app_lifecycle`의 value는 LIFECYCLE enum.
- `target.match`의 키는 `text`/`key`/`index`만(TypeName/property 누수 금지).
- `role`은 검사하지 않음(열린 힌트 집합).

## grounding (실제 TAS API와의 대응 — 왜 이 어휘인가)

IR은 다음 단계에서 실제 TAS 코드로 실현된다. 어휘는 실제 API 안에서만 정의된다:

- **find 차원**: TAS는 위젯을 `byKey` / `byText` / `byTypeName` / `findAt(index)`로 찾는다.
  → `target.match`는 `text`(byText) / `key`(byKey) / `index`(findAt)만. byTypeName은 ①에서 안 정함.
- **키**: `sendKey` — OK=`KEY_ENTER`(4294967309), UP/DOWN/LEFT/RIGHT 등.
- **lifecycle**: `resumed`(표시+입력=foreground) / inactive / paused(백그라운드) / detached / hidden.
- **property**: `getProperty`가 반환하는 필드는 앱의 `toStringMap`(②가 생성)이 노출한 것뿐.

### intent → TAS primitive (다음 단계가 이렇게 실현)

| intent | 실현 |
| --- | --- |
| find | find(byKey/byText) (+ findAt) |
| focus_move | find… → setFocus |
| key_press | sendKey(keyId) |
| tap | tap / tapAt |
| scroll | 방향키 sendKey 반복 또는 drag |
| wait | 폴링/sleep |
| read_property | getProperty |

### expected.kind → 확인 방법

| kind | 확인 |
| --- | --- |
| app_launch | 대상 appId가 resumed로 전환 |
| widget_visible | find… count > 0 |
| property_value | getProperty 결과 필드 == 기대값 |
| state_change / navigation | getProperty/lifecycle/foreground 조합 |

## 다운스트림 계약 (이 구조에 맞춰 ②③ 정렬 완료)

step별 `actions`/`expected` 구조에 맞게 ②③도 갱신됐다:

- **②(appgen)** `appgen-schema.md`: binding이 IR step을 가리킨다 — action은 `(step_id, action_id)`,
  expected는 `(step_id, expected_index)`.
- **③(tasgen)** `tasgen-mapping.md`: **IR step 1개 = 스크립트 파일 1개**
  (`<appName>_<step.name>.py`, 예: `home_hero_banner_shown.py`). 그 step의 actions→expected만 담는다.
