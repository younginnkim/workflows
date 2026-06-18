# tasgen 매핑 — IR + appgen_output → per-step Python TAS 스크립트

stage③은 ②가 이미 다 풀어놓은 **IR(semantic)** + **appgen_output(resolved bindings)** 을 받아
**얇은 Python 테스트 스크립트**를 작성한다. 새 판단·위젯 유추 없음 — 슬롯 채우기다.
**`reference/tasbase.py`에 정의된 primitive만** 호출한다(없는 메서드를 지어내지 말 것).

**핵심: IR `steps[]`의 각 step = 자기완결 시나리오 = 스크립트 파일 1개.** 한 step의 actions를 다른
step이 이어받지 않는다(평탄화 금지). 실제 featureBAT 레이아웃(`home_hero_banner_shown.py`처럼 체크별
파일)과 일치한다.

## 입력

- **IR** (`/tas-parse` 산출): `test_case_id`, `title`, `source_ticket`,
  top-level `preconditions[]`,
  `steps[{id, name, preconditions[], actions[{id, intent, target, key?, source_span}], expected[{kind, source_span}]}]`.
- **appgen_output** (`/tas-appgen` 산출):
  - `app`: `{flutter_app_id, sam_app_id, flag_file, base_class_name, jira_id?}`
  - `widgets`: `{TypeName: [property keys]}` — getProperty가 줄 수 있는 키(=②의 toStringMap 노출분).
  - `bindings`: IR action/expected를 concrete하게 해소한 것:
    - target action용: `{step_id, action_id, typeName, find:{method: byText|byKey|byTypeName, value, index?}}`
    - expected용: `{step_id, expected_index, kind, ...}`(kind별 필드는 아래 표).

## 출력 — 대상 repo의 `Functional/flutter/<appName>/featureBAT/` 에 직접 쓴다

생성 스크립트는 `automation-tests` 프레임워크 안에서 돈다. 라이선스 헤더(다른 TAS 스크립트와
동일한 LG 헤더)를 각 파일 맨 위에 붙인다. `<appName>` = `sam_app_id` 마지막 세그먼트(예: home).

**step stem 규칙(공통):** 각 step의 식별자 stem = `<NN>_<step.name>`, 여기서 `NN` = `step.id`를
**2자리 zero-pad**(1→`01`, 5→`05`, 12→`12`). 파일명·클래스명·`test_name` 모두 이 stem을 쓴다.
예) step.id=1, name=`hero_banner_shown` → stem `01_hero_banner_shown`.

대상 폴더에 쓰는 파일:
- **base 파일 `<snake_case(base_class_name)>.py`** — 단일 base (앱당 1개, 아래 1번). 번호 없음.
  파일명은 base_class_name에서 파생(예: `homeTasBase` → `home_tas_base.py`) → golden `<appName>_base.py`와 안 겹침.
  **이미 있으면 재사용, 없으면 생성**(golden home_base.py만 있고 이 base가 없으면 반드시 만든다).
- **IR step마다 `<appName>_<stem>.py`** — step당 1개 (아래 2번). 예: step.id=1, name `hero_banner_shown`
  → `home_01_hero_banner_shown.py`.

1. **base `<snake_case(base_class_name)>.py`** (앱당 1개 단일 base, 예: `home_tas_base.py`) — **`reference/tasbase.py` 본문 그대로**
   쓰되 class명을 `<base_class_name>`으로, meta·`test_name`을 app-config 값으로 채운다(별도 tasbase.py 없음):
   ```python
   # ... reference/tasbase.py 의 webos.utils import + primitive 전체 ...
   class HomeTasBase(ZephyrTest):          # class명 = base_class_name
       FLUTTER_APP_ID = '<app.flutter_app_id>'
       SAM_APP_ID = '<app.sam_app_id>'
       FLAG_FILE = '<app.flag_file>'
       JIRA_ID = '<app.jira_id>'           # 있을 때만
       test_name = '<base_class_name>'
       # __init__ / _run / find / focus / send_key / assert_* ... (tasbase.py 그대로)
   ```
2. **`<appName>_<stem>.py`** (IR step당, stem = `<NN>_<step.name>`) — 얇은 클래스(그 step의 actions→expected만 실행):
   ```python
   from Functional.flutter.<appName>.featureBAT.<snake_case(base_class_name)> import <base_class_name>

   class <PascalCase(appName_stem)>(<base_class_name>):
       def __init__(self):
           self.test_name = '<appName>_<stem>'
           <base_class_name>.__init__(self)

       def run_flutter_test(self):
           <그 step의 actions(id 오름차순) → 그 step의 expected 순서대로 primitive 호출>
   ```
   - 클래스명 = `<appName>_<stem>`을 `_`/`-`/공백으로 쪼개 각 토큰 capitalize 후 결합
     (예: step.id=1 `home_01_hero_banner_shown` → `Home01HeroBannerShown`). 유효 식별자가 안 되면 escalate.
     (숫자 토큰 `01`은 capitalize해도 `01` 그대로 → 클래스 중간에 위치하므로 식별자 유효.)
   - 한 step의 body는 **그 step의 actions/expected만** 쓴다. 다른 step의 action/expected를 섞지 않는다.

## dispatch 표 (IR 요소 + binding → primitive 호출)

> action은 `(step_id, action_id)`, expected는 `(step_id, expected_index)`로 binding을 찾는다.

| IR 요소 | binding | 출력 호출 |
|---|---|---|
| action `focus_move` | typeName + find | `self.focus('<typeName>', by_text='<v>')` (byKey→`by_key=`, byTypeName→인자 typeName만, index 있으면 `index=<n>`) |
| action `key_press` (key=OK/UP/DOWN/LEFT/RIGHT/BACK/HOME) | — | `self.send_key('OK')` |
| action `find` | typeName + find | `self.find('<typeName>', by_text='<v>')` |
| action `tap` | typeName + find | `self.focus(...)` 줄 + `self.tap()` 줄 |
| action `scroll` | — | `self.send_key('<direction, 기본 DOWN>')` |
| action `wait` | — | `self.wait(<seconds, 기본 1>)` |
| action `read_property` | typeName | `self.find('<typeName>')` 줄 + `self.get_property()` 줄 |
| expected `app_launch` | `appId` | `self.assert_app_launch('<appId>')` |
| expected `widget_visible` | typeName (+`where`) | `self.assert_widget_present('<typeName>')` 또는 `..., where={'text':'<v>'})` |
| expected `widget_visible` (다중 OR) | `options[]` | `self.assert_any_present([{'typeName': '...', 'where': {...}}, ...])` |
| expected `property_value` | typeName, key, op, value, group? | `self.assert_property('<typeName>', '<key>', '<op>', <value>)` (+`, group='<group>'`) |

## 규칙

- **없는 primitive 호출 금지** — 위 표 + `reference/tasbase.py`의 `def`로 정의된 것만 쓴다.
- property key는 `widgets[typeName]`에 **존재하는 것만** 쓴다.
- 한 step 파일 안에서 `actions`는 `id` 오름차순 그대로, 그 다음 그 step의 `expected`.
- preconditions(top-level + step별)는 body 코드로 안 들어간다(app 실행은 base/프레임워크, environment는 ④).
- **escalate(추측 금지)** — 다음이면 코드를 지어내지 말고 사람에게 확인한다(해당 step만 스텁):
  - 루프·셸·멀티앱 등 IR 선형 시퀀스로 표현 안 되는 bespoke,
  - target action에 binding이 없음,
  - 다중 수락(OR)인데 `options` 리스트가 없음,
  - v1 미지원 expected kind(`state_change`/`navigation`).

## 워크드 예시

**입력 IR** (한 step만 발췌)
```yaml
test_case_id: home_featurebat_basic_widgets_and_launch
source_ticket: TVDEVTC-23796
preconditions:
  - {kind: environment, value: network connected, source_span: "network connected"}
steps:
  - id: 6
    name: media_discovery_launch
    preconditions: []
    actions:
      - {id: 1, intent: focus_move, target: {match: {text: "App List"}}, source_span: "Move to App List shelf"}
      - {id: 2, intent: focus_move, target: {match: {text: "Media Discovery App"}}, source_span: "Select Media Discovery App"}
      - {id: 3, intent: key_press, key: OK, source_span: "Select Media Discovery App"}
    expected:
      - {kind: app_launch, source_span: "Media Discovery App is launched."}
```
**입력 appgen_output**
```yaml
app: {flutter_app_id: com.webos.tas.home, sam_app_id: com.webos.app.home,
      flag_file: /var/luna/preferences/tas_home_enabled, base_class_name: HomeTasBase, jira_id: TVDEVTC-23796}
widgets: {Shelf: [], Tile: [text]}
bindings:
  - {step_id: 6, action_id: 1, typeName: Shelf, find: {method: byText, value: "App List"}}
  - {step_id: 6, action_id: 2, typeName: Tile, find: {method: byText, value: "Media Discovery App"}}
  - {step_id: 6, expected_index: 0, kind: app_launch, appId: com.webos.app.mediadiscovery}
```
**출력 `home_06_media_discovery_launch.py`** (라이선스 헤더 생략) — step 1개 = 파일 1개
(stem = `06_media_discovery_launch`: step.id=6 → `06`)
```python
from Functional.flutter.home.featureBAT.home_tas_base import HomeTasBase

class Home06MediaDiscoveryLaunch(HomeTasBase):
    def __init__(self):
        self.test_name = 'home_06_media_discovery_launch'
        HomeTasBase.__init__(self)

    def run_flutter_test(self):
        self.focus('Shelf', by_text='App List')                 # step6 action1 focus_move
        self.focus('Tile', by_text='Media Discovery App')       # step6 action2 focus_move
        self.send_key('OK')                                     # step6 action3 key_press
        self.assert_app_launch('com.webos.app.mediadiscovery')  # step6 expected0
```
**출력 `home_tas_base.py`** (단일 base = snake_case(base_class_name) = tasbase.py 본문 + meta, 별도 tasbase.py 없음)
```python
# ... reference/tasbase.py 의 import + _KEYNAME + 모든 primitive 그대로 ...
class HomeTasBase(ZephyrTest):
    FLUTTER_APP_ID = 'com.webos.tas.home'
    SAM_APP_ID = 'com.webos.app.home'
    FLAG_FILE = '/var/luna/preferences/tas_home_enabled'
    JIRA_ID = 'TVDEVTC-23796'
    test_name = 'HomeTasBase'
    # __init__ / _run / find / focus / send_key / assert_* ... (tasbase.py 그대로)
```

> 같은 TC의 다른 step들(`hero_banner_shown`, `q_card_list_shown`, …)은 각각
> `home_hero_banner_shown.py`, `home_q_card_list_shown.py` … 로 같은 방식으로 생성한다.
> (step 7 `live_tv_launch`는 expected kind=`navigation`이라 v1 미지원 → escalate.)
