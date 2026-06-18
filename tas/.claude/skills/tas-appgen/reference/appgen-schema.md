# appgen_output 스키마 & 해소 절차

①이 미룬 TypeName/find/property 구체화를 앱 소스로 끝내 `appgen_output`을 만든다(= ③ 입력).

## 출력 — appgen_output (YAML)

```yaml
app:                                    # ①의 app-config 그대로 + jira_id(=IR.source_ticket)
  sam_app_id: <앱 SAM id>
  flutter_app_id: <TAS service id>      # = ③ FLUTTER_APP_ID
  flag_file: <flag 파일 경로>
  base_class_name: <{App}TasBase>
  jira_id: <Zephyr 키 또는 생략>
widgets:                                # TypeName → getProperty가 노출하는 property key (소스에서 확인)
  <TypeName>: [<property key>, ...]
bindings:                               # 값은 전부 대상 앱 소스에서 해소한 것 (베끼는 게 아님)
  # ── target action용 (IR step.actions 중 find/focus_move/tap/scroll/read_property) ──
  #    참조 = (step_id, action_id). action_id는 그 step 안에서의 id.
  - { step_id: <n>, action_id: <m>, typeName: <TypeName>, find: { method: byText|byKey|byTypeName, value: <값>, index?: <i> } }
  # ── expected용 (IR step.expected) ── 참조 = (step_id, expected_index).
  - { step_id: <n>, expected_index: <i>, kind: app_launch, appId: <실행 앱 id> }
  # property_value: { step_id, expected_index, kind: property_value, typeName, key, op, value, group? }
  # widget_visible: { step_id, expected_index, kind: widget_visible, typeName, where? }
  # any_present  : { step_id, expected_index, kind: any_present, options: [{typeName, where}, ...] }
unsupported: []                          # 못 풀었거나 bespoke (사유 문자열) — ③이 escalate
```

규칙: `bindings[].typeName`은 `widgets`에 존재해야 한다. property_value의 `key`, where 키는
`widgets[typeName]`에 노출돼 있어야 한다(없으면 → toStringMap 보강 필요로 `unsupported`).
모든 binding은 자신이 속한 IR step을 `step_id`로 가리킨다(action은 `+action_id`, expected는 `+expected_index`).

## find 차원 결정

- IR `match.key` 있음 → `byKey`(그 키).
- 보이는 라벨/문구(`match.text`) → `byText`(그 텍스트). 소스에서 그 텍스트를 렌더하는 위젯 확인.
- 둘 다 없음 → 소스에서 찾은 위젯 클래스로 `byTypeName`. `index`는 "첫 번째" 등 위치 단서일 때.

## 해소 절차

IR은 `steps[]`, 각 step에 `actions[]`(target/intent)와 `expected[]`가 있다. **모든 step을 순회**하며
각 step의 actions·expected를 해소한다(글로벌·step preconditions는 손대지 않는다).

1. app repo `lib/` 스캔 — 각 step의 action target `role`/`container`/`text` 단서로 해당 위젯 클래스(또는 그
   텍스트를 렌더하는 위젯)를 찾는다. 후보가 여럿/불명확이면 → 사용자에게(AskUserQuestion, 후보 옵션 ≥2).
   → target action마다 `{step_id, action_id, typeName, find}`.
2. expected의 `appId`/property — TC expected + 소스로 확정. 불명확이면 → 사용자에게(텍스트).
   → step.expected 항목마다 `{step_id, expected_index, kind, ...}`.
3. widgets contract: 쓰인 TypeName이 노출할 property key(소스의 위젯 필드에서). presence만 필요하면 빈 리스트.
4. **app_test.dart 생성**: 그 TypeName/property가 getProperty로 노출되도록 매퍼를 작성한다(아래 템플릿).
   기존 `integration_test/app_test.dart`가 있으면 거기에 맞춰 보강(매퍼·printProperties·toStringMap 인자).
5. preconditions(top-level + step별)는 손대지 않는다(binding 대상 아님).

## 매핑 형식 (값은 예시 아님 — 반드시 소스에서 확인)

> 아래는 IR 한 줄이 어떤 binding **필드로** 가는지 **형식**만 보여준다. TypeName/appId/property
> **값을 베끼지 말 것** — 매번 대상 앱 `lib/`에서 실제로 확인해 채운다(못 찾으면 질문/`unsupported`).

```
IR action  focus_move {match:{text:"<라벨>"}}  →  {step_id, action_id, typeName: <소스에서 찾은 위젯 클래스>,
                                                  find:{method: byText, value: "<라벨>"}}
IR expected  app_launch                        →  {step_id, expected_index, kind: app_launch,
                                                  appId: <TC/소스에서 확정한 실행 앱 id>}
IR expected  widget_visible (단일)             →  {step_id, expected_index, kind: widget_visible,
                                                  typeName: <위젯>, where?: {<key>: <val>}}
IR expected  widget_visible (A 또는 B …)       →  {step_id, expected_index, kind: any_present,
                                                  options: [{typeName, where?}, ...]}   # 못 정하면 unsupported
IR expected  property_value                    →  {step_id, expected_index, kind: property_value,
                                                  typeName, key, op, value, group?}      # key는 widgets[typeName]에 있어야
```

각 `typeName`은 `widgets`에 등록하고, 그 TypeName이 `getProperty`로 노출하는 key를
`widgets[typeName]`에 적는다. **그 노출은 ②가 app_test.dart 매퍼로 만든다(아래).**

## app_test.dart (계측) — **입력받은 repo의 파일을 직접 수정** (별도 산출물 아님)

`<repo>/integration_test/app_test.dart`를 직접 고친다. `widgets`의 각 TypeName마다 `to<TypeName>`
매퍼를 만들어 `printProperties`에 등록하고 `testWebosApplication`에 `toStringMap`으로 넘긴다.
기존(주석 처리된) 매퍼는 보존. property field·import 경로는 **소스에서 확인**.

```dart
// integration_test/app_test.dart
import 'package:flutter/widgets.dart';
import 'package:<pkg>/main.dart' as app;                 // app-config의 package_main
import 'package:webos_flutter_test/webos_flutter_test.dart';
import 'package:<pkg>/<위젯 정의 파일 경로>';              // widgets의 각 TypeName 클래스 (lib 스캔에서)

String to<TypeName>(Widget w) {
  Map<String, dynamic> properties = {};
  if (w is <TypeName>) {
    properties['<key>'] = w.<소스에서 본 필드>;            // widgets[TypeName]의 각 key (없으면 본문 비움)
  }
  return properties.toString();
}

void main() {
  Map<String, WebOSTestGetProperty> printProperties = {
    '<TypeName>': to<TypeName>,                           // 모든 TypeName 등록 (presence-only도 빈 매퍼로)
  };
  testWebosApplication('<test_label>', '<flutter_app_id>', app.main,
      flagFileName: '<flag_file>',
      toStringMap: printProperties);                      // ← 이 인자가 있어야 getProperty가 동작
}
```

규칙: `widgets`의 모든 TypeName이 `printProperties`에 있어야 한다(presence-only면 매퍼 본문은 비움 — 등록만으로 getProperty가 카운트). `import` 경로/필드는 지어내지 말고 lib 스캔으로 확인한 것만.
