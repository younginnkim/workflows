# TAS! Stage ① — 자연어 TC → semantic IR 설계

- 작성일: 2026-06-09
- 출처: collab "1조 타스형!" (TSA, pageId 3689851303), "Sprint 5 - 2차 모임"(3694255649),
  Flutter TAS API 레퍼런스(2485690510, 2582680993). 전체 링크는 부록 C.
- 범위: TAS! 4단계 워크플로우 중 **① TestCase 파싱**만. ②③④는 별도 스펙.
- 단계 네이밍(팀 합의): **① `/tas-parse` → ② `/tas-appgen` → ③ `/tas-tasgen` → ④ `/tas-verify`**.
  본 스펙은 `/tas-parse`다.

## 1. 배경 / 문제

TAS! 워크플로우는 자연어 Zephyr TestCase를 받아 App 코드(②)·TAS 코드(③)를
생성하고 빌드·검증(④)까지 진행하는 도구다. 본 스펙은 그 **첫 단계 ①**, 즉
자연어 TC 텍스트를 구조화된 IR(Intermediate Representation)로 변환하는 부분만 다룬다.

**TAS란**: webOS Flutter 앱을 위한 Python 기반 integration-test 자동화 프레임워크.
파이썬 스크립트가 luna command(`luna://com.webos.tas.<app>/request`)로 Flutter UI를
조회·조작한다. 위젯은 `find(byKey|byTypeName|byText)` + `findAt(index)`로 찾고,
`setFocus`/`sendKey`/`tap`으로 조작하며, `getProperty`로 상태를 읽는다. `getProperty`가
반환하는 필드는 앱의 `toStringMap`(②가 생성)이 노출한 것뿐이다. 자세한 API는 부록 A.

핵심 고객은 **앱을 갓 구현하고 바로 TAS 코드를 짜고 싶은 개발자**다. 따라서 다음을
전제한다:

- 앱에 `toStringMap`/`app_test.dart` 매퍼가 **미리 만들어져 있지 않다** (대부분 케이스).
- 어떤 앱은 위젯이 익명/제네릭/private라 정적 분석으로도 TypeName이 안 잡힌다.
- 실제 위젯 TypeName은 ④ 런타임 위젯트리 덤프에서야 확정될 수 있다.

이 전제 때문에 stage ①은 "실제 위젯에 grounding"을 책임지지 않는다. (아래 2장)

## 2. 책임과 경계 (단일 책임)

> **입력: 자연어 TC 텍스트 1건. 출력: app-agnostic semantic IR(yaml).**
> **앱 소스·디바이스를 보지 않는다. TypeName/property 해석은 전부 ②의 책임.**

- stage ①은 "텍스트 → 의미 구조화" 한 가지만 한다.
- 앱·디바이스가 없어도 단독으로 동작하고 단독으로 검증된다.
- IR은 ②(app 코드)·③(TAS 코드)의 공통 입력이 된다.

**입력 소싱(2026-06-11 갱신).** 입력 "텍스트"는 두 경로로 들어온다 — (a) 사용자가 직접 준
TC 문장, (b) **`zephyr-tc` MCP**(`mcp__zephyr-tc__get_tc(key)`)가 Zephyr ZAPI
(`/rest/zapi/latest/teststep`)에서 받아온 구조화 steps `[{step, data, expected}]`. 이로써 과거
"ZAPI per-step 텍스트는 MCP로 도달 불가 → 자연어로 우회" 전제는 깨졌다. **이 변경은 ①의 책임을
바꾸지 않는다**: 여전히 텍스트→semantic IR이고 TypeName은 ②가 결정한다. 소싱은 `/tas-parse`
스킬의 런타임 관심사이며 결정론 코어(`stage1_parse/` 스키마·Gate A)는 입력 출처와 무관하다
(헤드리스 `parse.py`는 MCP를 못 부르므로 `--text/--file`만 유지). `source_span`은 사용자 NL이
아니라 **받아온 ZAPI step/data/expected 원문을 verbatim 인용**한다.

**핵심 원칙 — 위젯 유추 금지(명시된 것만 추출).** stage ①은 TC가 *말한 것*만
구조화한다. TC에 없는 위젯·식별자·동작을 지어내지 않는다. 모호하면 추측 대신
`unresolved[]`에 남긴다. (자매 조 5조 "네탓이오"가 Stage 1에서 동일 교훈을 채택:
*"위젯 유추 금지, 명시 식별자만 추출"*. 이것이 Gate B 충실도 검사의 근거이기도 하다.)

## 3. semantic IR 스키마

semantic IR은 **의미(역할 + 식별 단서 + 액션 + 기대결과)** 만 담는다. 구체 TypeName/
property는 넣지 않는다(그건 ②가 채운다). 단, 스키마의 모든 필드는 부록 A의 실제 TAS
API에 1:1로 매핑되도록 설계한다(부록 B 매핑표) — 그래야 ③이 IR을 코드로 실현할 수 있다.

```yaml
test_case_id: globalline_search_launches_voice   # title에서 파생한 slug
title: "홈 앱 글로벌 라인 Search 버튼 동작 검증"
source_ticket: TVDEVTC-23796            # 있으면, 없으면 null
target_app: com.webos.app.home          # TC에 명시됐을 때만 (hint), 없으면 null
preconditions:
  - kind: app_lifecycle                 # enum (아래)
    value: resumed                      # foreground == AppLifecycleState.resumed
    app: com.webos.app.home
    source_span: "Precondition: 홈 앱이 foreground"
steps:
  - id: 1
    intent: focus_move                  # enum (아래)
    target:                             # semantic target — TypeName 아님
      role: button                      # 의미적 역할 (hint): button|list|item|...
      match:                            # TC가 실제로 준 식별 단서만 채움 (부록 A find 전략)
        text: "Search"                  # → findByText 후보 (보이는 라벨/문구)
        key: null                       # → findByKey 후보 (TC에 명시된 식별자만)
        index: null                     # → findAt 후보 (positional, "첫 번째" 등)
      container: "Global Line"          # optional, semantic 부모 맥락
    source_span: "Step 1: 글로벌 라인에서 Search 버튼으로 포커스 이동"
  - id: 2
    intent: key_press
    key: OK                             # 정규화 키: OK|UP|DOWN|LEFT|RIGHT|BACK|HOME
    source_span: "Step 2: OK 키 입력"
expected:
  - kind: app_launch                    # enum
    value: "com.webos.app.voice (search 모드)"
    params: { launchPointId: search }   # optional, TC에 명시된 경우만
    source_span: "Expected: com.webos.app.voice 가 search 모드로 launch"
unresolved: []                          # 모호해서 못 정한 부분, judge가 채움
```

### enum 정의 (초기값, 확장 가능 — 부록 A·B에 grounding)

- `steps[].intent`: `find | focus_move | key_press | tap | scroll | wait | read_property`
  (각 intent의 TAS primitive 매핑은 부록 B)
- `steps[].key`(정규화): `OK | UP | DOWN | LEFT | RIGHT | BACK | HOME` — ③에서 부록 A의
  keyId(예: OK=`KEY_ENTER`=4294967309)로 변환.
- `target.match`: `text`(findByText) / `key`(findByKey) / `index`(findAt) 중 **TC가 명시한
  것만** 채운다. 위젯 TYPE(byTypeName)은 semantic 단계에 넣지 않는다(②가 결정).
- `target.role`: `button | list | item | banner | icon | text | container` (열린 집합, hint).
- `preconditions[].kind` / 일부 `expected[].kind`: `app_lifecycle`(value=AppLifecycleState:
  `resumed|inactive|paused|detached|hidden`, foreground=resumed) | `focused` | `property_value`.
- `expected[].kind`: `app_launch | widget_visible | property_value | state_change | navigation`.

매칭 단서를 하나도 못 잡으면(예: "그 버튼") → 추측하지 말고 `unresolved`에 표시(2장 원칙).

### 불변식

- **모든** preconditions/steps/expected 요소는 `source_span`(TC 원문 인용)을 가진다.
  → 역추적이 가능해야 환각(추가된 내용)을 검출할 수 있다.
- `steps`는 순서를 보존한다(`id` 오름차순 = 실행 순서).
- `target.match`는 TC에 명시된 단서만 담는다(위젯 유추 금지, 2장).

## 4. 검증: 두 종류로 분리 (런타임 vs 저자 전용)

검증은 **answer key(정답지)가 필요한가**로 두 종류로 나뉜다. 이 구분이 stage ①
구조의 핵심이다.

| 검증 | answer key | 어디 속하나 | 공유물(고객)에 ships? |
|---|---|---|---|
| Gate A — 스키마 게이트 | 불필요(결정적 규칙) | 런타임 파이프라인 | ✅ 항상 |
| Gate B — 충실도 judge | 불필요(TC 텍스트만 대조) | 런타임 파이프라인(옵션 토글) | ✅ 기본 ON |
| 골든 회귀 | 필요(손으로 쓴 golden IR) | **저자 eval 하네스** | ❌ |
| negative fixture | 필요(망가뜨린 고정 입력) | **저자 eval 하네스** | ❌ |

→ 골든·fixture는 고객의 새 TC엔 정답지가 없으므로 **본질적으로 저자 전용**이다.
stage ① 파이프라인이 아니라 별도 `tests/`·`golden/`에 둔다(6장 참조).

### 4-1. 런타임 파이프라인 (공유물 — 모든 고객이 실행)

```
TC 텍스트
   │  generator (LLM, 논리적 서브에이전트) → IR.yaml
   ▼
[Gate A] 스키마 게이트 — 결정적 코드
   · yaml 파싱 OK / 필수 필드 / intent·kind·role enum 유효 / 모든 요소에 source_span
   ▼
[Gate B] 충실도 judge — LLM, generator와 분리 (옵션 토글, 기본 ON)
   · coverage : TC의 모든 step·expected가 IR에 매핑됐는가 (누락 0)
   · faithful : IR의 모든 요소가 source_span으로 TC에 역추적되는가 (환각 0)
   · 출력: { verdict: pass|fail, defects: [...] }
   ▼
 PASS                → IR 확정
 FAIL (A 또는 B)     → defects를 generator에 피드백 → 재생성 (최대 N회, 기본 N=3)
 N회 초과 / unresolved 존재 → 사람에게 에스컬레이션
```

- judge는 **정답지가 필요 없다** — 그래서 골든 회귀와 달리 공유물에 들어갈 수 있는
  유일한 검증이다. 고객도 정답지 없이 self-check + 재생성의 혜택을 받는다.
- `--no-judge` 같은 플래그로 OFF 가능(비용·지연 절감). OFF면 `generator → Gate A → 끝`.
- generator와 judge는 **분리된 LLM 호출**이다(생성 주체가 스스로 채점하지 않음).
- collab 피드백("직접 기준 세우고 통과 못 하면 다시 구현")의 런타임 실현이 Gate B다.
- 이 "결정론 게이트(A) + evidence 인용(source_span) 기반 LLM judge(B)" 구성은 자매 조
  9조 "LGTM"의 하이브리드 린트(결정론 룰 + LLM + verbatim source_quote + adversarial
  judge)와 수렴하는 설계다 — 외부 검증된 패턴.

### 4-2. 저자 eval 하네스 (공유물에 미포함 — 도구 개발/회귀용)

```
[골든 회귀] 알려진 TC → 생성 IR vs 손으로 쓴 golden IR, semantic 동치 비교
[negative fixture] 일부러 누락/환각 넣은 IR → Gate B(judge)가 잡는지 측정
```

- 목적: "내 generator·judge가 충분히 좋은가"를 측정. 고객은 쓰지 않는다.
- golden 코퍼스는 점진적으로 성장(5장 참조).

## 5. 에러 / 경계 처리

- **yaml 파싱 실패** → 재생성 루프로 처리(Gate A 불합격).
- **judge 모호 판정** → 해당 부분을 `unresolved[]`에 남기고 사람 확인 요청
  (구 도구의 UNMATCHED 역할). 추측으로 채우지 않는다.
- **N회 재생성 후에도 실패** → 마지막 IR + judge defects를 함께 사람에게 에스컬레이션.
- **골든 코퍼스 성장(저자 작업)**: 저자가 새 TC의 IR을 손으로 확정하면 golden으로
  적립 → 4-2의 회귀 커버리지가 점진적으로 넓어진다. (런타임 경로 아님)

## 6. 런타임 / 아키텍처

**Python 코어 + 교체 가능한 LLM 어댑터.**

- 결정적 로직(스키마 검증 / 골든 diff / 재생성 루프 제어)은 **Python**.
- LLM이 필요한 두 지점(generator, judge)은 `llm.generate(prompt) -> text` 한 함수
  뒤로 추상화한다.
- 기본 어댑터 = **Anthropic API**. 동일 인터페이스로 향후 Claude Code 서브에이전트
  어댑터로 교체 가능 → 오케스트레이션 코드는 안 건드리고 CC 스킬로 래핑 가능.
- 이 구조로 **양쪽 용도**를 모두 만족: CI/회귀 게이트(헤드리스 반복 실행) +
  개발자 대화형 사용(CC 스킬).

### 모듈 (초안)

```
tas-tool/
  stage1_parse/          # ── 공유물(런타임). 고객에게 그대로 나감 ──
    schema.py            # IR 스키마 정의 + Gate A (결정적 검증)
    generator.py         # TC → IR 프롬프트 + llm.generate 호출
    judge.py             # 충실도 judge 프롬프트 + 결과 파싱 (Gate B)
    loop.py              # generate→A→B 루프 제어 + 에스컬레이션 (judge 토글)
    llm.py               # LLM 어댑터 인터페이스 (기본: Anthropic API)
  parse.py               # CLI 진입점(= /tas-parse): parse.py --text <TC> [--ticket KEY] [--no-judge]
  tests/                 # ── 저자 전용 eval 하네스. 공유물에 미포함 ──
    golden/              # 손으로 쓴 golden IR (알려진 TC, 예: TVDEVTC-23796)
    fixtures/            # negative fixture (일부러 망가뜨린 IR)
    test_golden.py       # 골든 회귀
    test_judge.py        # negative fixture로 judge 검증
    test_schema.py       # Gate A 단위테스트
```

런타임 파이프라인은 `stage1_parse/` + `parse.py`만으로 완결된다. `tests/`는 도구를
개발·회귀할 때만 쓰며 공유 패키지에서 빠진다.

## 7. 테스트 전략 (= 4-2 저자 eval 하네스, 공유물 미포함)

- **골든 회귀**: 알려진 TC N건 → 생성 IR이 golden과 semantic 동치 (디바이스 불필요).
- **judge 자기검증(negative fixture)**: step 누락/환각을 넣은 IR을 judge가 잡는지.
- **스키마 단위테스트**: 잘못된 enum·누락 source_span·순서 깨짐을 Gate A가 거부하는지.

이 테스트들은 "내 generator·judge가 충분히 좋은가"를 저자가 측정하는 용도다. 고객
런타임에는 실행되지 않는다.

## 8. 비범위 (이 스펙에서 다루지 않음)

- ② app_test.dart 매퍼 생성, ③ Python TAS 스크립트 생성, ④ 빌드/디바이스 검증.
- 앱 소스 정적 분석 및 실제 위젯 TypeName grounding (전부 ② 이후).
- Recorder를 통한 앱 동작 자동 캡처 (collab의 Phase 2).

---

## 부록 A — Flutter TAS API 사실 (grounding 근거)

stage ① IR의 모든 동작·식별 어휘는 이 실제 API 집합 안에서만 정의된다. (출처: 부록 C)

**위젯 찾기 / 조작 (Python `Flutter` 클래스 → luna `…/request`)**

| method | parameter | 설명 | luna command 예 |
| --- | --- | --- | --- |
| `findByKey` | `<String, bool>` | key로 찾기, from root | `{"command":"find","method":"byKey","value":"app-list"}` |
| `findByTypeName` | `<String, bool>` | TypeName으로 찾기 | `{"command":"find","method":"byTypeName","value":"WAnimatedCarousel"}` |
| `findByText` | `<String, bool>` | Text로 찾기 | `{"command":"find","method":"byText","value":"Search"}` |
| `findAt` | `<Integer>` | 찾은 목록 중 index 선택 | `{"command":"findAt","index":7}` |
| `tap` / `tapAt` | `-` / `<dx,dy>` | 탭 | |
| `setFocus` / `unFocus` | `-` | 포커스 설정/해제 | `{"command":"setFocus"}` |
| `sendKey` | `<String>` | 키 입력(아래 keyId) | `{"command":"sendKey","keyId":4294968067}` |
| `getProperty` | `-` | 현재 타깃의 property 조회(`toStringMap` 노출분) | `{"command":"getProperty"}` |
| `getCenter` | `-` | 중심 좌표 | `{"command":"getCenter"}` |
| `drag` / `hover` | `<dx,dy>` / `<dx,dy,count>` | 드래그/호버 | |

**keyId 상수**: `KEY_ENTER`(OK)=4294967309, `KEY_DOWN`=4294968065, `KEY_LEFT`=4294968066,
`KEY_RIGHT`=4294968067, `KEY_UP`=4294968068.

**AppLifecycleState**(앱 프로세스 상태): `resumed`(표시+입력응답=foreground) / `inactive` /
`paused`(백그라운드) / `detached`(엔진만) / `hidden`(짧게). → precondition·expected의
foreground/background 의미를 정규화하는 근거.

**핵심 함의**: TAS가 위젯을 찾는 차원은 **byKey · byTypeName · byText · findAt(index)** 넷뿐.
그래서 IR의 `target.match`도 이 차원으로만 표현한다(byTypeName은 ②가 결정하므로 ①에선 제외).

## 부록 B — semantic intent → TAS primitive 매핑

IR의 추상 intent가 ③에서 실제 코드로 어떻게 실현되는지(=어휘가 realizable함을 보증).

| IR intent | 의미 | ③의 TAS primitive 시퀀스 |
| --- | --- | --- |
| `find` | 대상 위젯 지목 | `find(by{Key\|Text})` (+ `findAt(index)`) — TypeName은 ②가 보강 |
| `focus_move` | 포커스 이동 | `find…` → `setFocus` |
| `key_press` | 리모컨 키 입력 | `sendKey(keyId)` (OK→KEY_ENTER 등 부록 A) |
| `tap` | 탭/클릭 | `tap` 또는 `tapAt(dx,dy)` |
| `scroll` | 스크롤/이동 | 방향키 `sendKey` 반복 또는 `drag` |
| `wait` | 대기 | 폴링/sleep (timeout) |
| `read_property` | 상태 읽기(검증용) | `getProperty` |

| IR expected.kind | ③/④의 확인 방법 |
| --- | --- |
| `app_launch` | 대상 appId가 `resumed`로 전환됐는지 (lifecycle/foreground) |
| `widget_visible` | `find…` count > 0 |
| `property_value` | `getProperty` 결과의 특정 필드 == 기대값 (필드는 ②의 `toStringMap`이 노출) |
| `state_change` / `navigation` | `getProperty`/lifecycle/foreground 조합 |

## 부록 C — 참고 collab 페이지

- 1조 타스형! 상세: pageId **3689851303** (TSA)
- Sprint 5 - 2차 모임 (단계 네이밍·조별 현황): **3694255649** (TSA)
- TAS for Flutter (API 메서드 표): **2485690510**
- [검토] flutter home tas 구현 (home 기준 API + AppLifecycleState): **2582680993**
- Flutter TAS (스크립트 구조·주요 함수): **2485982339**
- 수정한 Flutter 앱 TAS miniBAT 스크립트 구동 방법 (빌드/실행): **3015559311**
- TAS Implementation for flutter-webOS embedder (통합 구조): **2208558236**

자매 조 설계 참고(검증 패턴 수렴):
- 5조 "네탓이오" — Stage 1 위젯 유추 금지/명시 식별자만: **3687757708**
- 9조 "LGTM" — 결정론+LLM 하이브리드 + evidence 인용 + adversarial judge: **3689844268**
