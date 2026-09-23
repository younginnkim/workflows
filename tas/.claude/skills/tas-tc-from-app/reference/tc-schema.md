# Stage ⓪ TC 텍스트 — 포맷 & Sample App 도출 규칙

Sample App 페이지 소스에서 **관측 가능한 동작**을 자연어 TC로 만들 때 따르는 규칙.
출력은 `① /tas-parse`가 `source`(TC 텍스트)로 그대로 먹을 수 있는 자연어 시나리오다.

TC는 사람이 읽는 자연어다. **위젯 TypeName·property를 넣지 않는다**(그건 ①→②가 소스에서 해석).
TC엔 "화면에 보이는 라벨/문구"와 "리모컨으로 하는 행동"과 "관측되는 결과"만 담는다.

## HARD RULES (반드시 지킨다)

- **소스에서 관측 가능한 것만.** 페이지 `build`/`State`에서 실제로 화면에 나타나거나 `setState`로
  바뀌는 것만 TC로 쓴다. 소스에 없는 성공 흐름·화면·검증을 **지어내지 않는다.**
- **데모 stub의 한계를 미화하지 않는다.** 예: login이 항상 에러를 띄우면 TC는 "에러 메시지가 보인다"
  까지만 — "로그인 성공 후 홈으로 이동" 같은 없는 흐름을 만들지 않는다.
- **위젯 TypeName/property 금지.** `EButton`/`EInputField` 같은 클래스명을 TC에 쓰지 않는다.
  대신 보이는 라벨("Sign In 버튼")과 역할("입력란")로 쓴다.
- **리모컨 조작으로 표현.** webOS TV는 터치가 없다. "버튼을 누른다" = "그 버튼으로 포커스를 옮기고
  OK를 누른다". 자연어에선 "~ 버튼을 선택한다"로 쓰면 ①이 focus_move+OK로 lowering한다.
- **독립 체크는 별도 시나리오.** 한 페이지가 여러 독립 동작을 보이면(예: 빈 입력 시 에러 / 입력 후
  제출 시 로딩) 각각을 별도 시나리오로 나눈다 — ①이 자기완결 step으로 분리하기 좋게.
- **모호하면 TC에 넣지 말고 확인.** 소스로 확정 못하는 결과는 추측해 쓰지 말고 사용자에게 확인한다.

## TC 텍스트 포맷

`/tas-parse`는 `source`가 텍스트면 그대로 받고, 그 안의 `[pre-condition]` / `[test-sequence]` 등
관용 섹션 라벨을 사전조건·스텝 추출 단서로 활용한다(tas-parse SKILL.md의 인테이크 규칙 참조).
아래 마크다운 포맷으로 쓴다(한 sample = 한 파일 = 여러 시나리오 가능):

```markdown
# TC: <sample name> — <한 줄 요약>

- app: elemental_showcase (Sample App)
- sample id: <id>
- source: Sample App 페이지 소스 (Zephyr 키 없음)

## [pre-condition]
- Elemental Showcase 앱이 실행되어 있다.
- Sample App의 "<sample name>" 화면에 진입해 있다.
- <사용자가 추가한 precondition, 있을 때만>

## 시나리오 1: <시나리오 제목>
### [test-sequence]
1. <행동> — 예: "이메일 입력란과 비밀번호 입력란을 비운 채 'Sign In' 버튼을 선택한다."
### [expected]
- <관측 가능한 결과> — 예: "'Invalid credentials. Please try again.' 문구가 화면에 표시된다."

## 시나리오 2: <다른 독립 체크>
### [test-sequence]
1. ...
### [expected]
- ...
```

규칙:
- **행동/기대는 소스 인용에 근거**한다. 실제 라벨 문구는 소스에서 본 그대로 따옴표로 인용
  (예: `'Sign In'`, `'Invalid credentials. Please try again.'`, `'Submitted!'`).
- 각 시나리오는 자기 pre-condition을 공유(top `[pre-condition]`)하고, 시작 상태에서 새로 출발한다고
  가정한다(시나리오 간 상태를 이어받지 않는다).
- 기대결과는 **한 가지 관측**으로 좁힌다("화면이 바뀐다" 금지 → "'Submitted!' 문구가 보인다").

## Sample App 도출 규칙 (소스 → TC)

페이지 소스에서 다음을 읽어 위 포맷을 채운다.

### 1. 관측 가능한 UI 요소 (→ 행동/기대의 대상)
- 화면에 **보이는 라벨/문구**: 버튼 텍스트(`text:`), 본문 텍스트(`EBodyText(child: ...)`),
  헤딩(`EHeading(text: ...)`), 입력 placeholder(`placeHolder:`), 드롭다운 항목 등.
- 이 문구들을 TC에서 대상 지칭에 쓴다 — "'Sign In' 버튼", "이메일 입력란(placeholder 'user@example.com')".
- **조건부로만 나타나는 요소**(`if (_showError) ...`, `if (_submitted) ...`)는 그 조건이 언제 참이
  되는지(어떤 행동 후)와 함께 기대결과로 쓴다.

### 2. 상호작용 (→ [test-sequence])
- `onPressed`/`onTap`/`onChanged`/`onSelect`가 붙은 요소 = 사용자가 조작 가능.
- 입력(`onChange`) → "~ 입력란에 값을 입력한다". 버튼/항목(`onPressed`/`onTap`) → "~ 를 선택한다".
- 드롭다운(`onSelect`)·슬라이더(`onChanged`)·체크박스(`onTap` toggle) 등은 그 조작을 자연어로.

### 3. 상태 전이/기대결과 (→ [expected])
- 핸들러가 `setState`로 바꾸는 필드를 추적해 **관측 가능한 결과**만 기대로 쓴다:
  - 새 문구/위젯이 보인다 (조건부 렌더가 참이 됨).
  - 화면 내용이 다른 뷰로 바뀐다 (예: form의 `_submitted`가 true → "Submitted!" 뷰).
  - 로딩 표시가 나타난다 (예: login의 `_loading` → 스피너).
- **지연(`Future.delayed`)**이 있으면 "잠시 후(약 N초 뒤)"로 명시한다(예: login은 2초 뒤 에러).
- 핸들러가 아무 관측 결과도 안 만들면(`onPressed: () {}`) TC 기대로 쓰지 않는다 — 관측 불가.

### 4. preconditions
- 항상: "앱 실행" + "해당 sample 화면 진입"(Sample App 그리드에서 그 카드를 선택해 진입).
- 그 외 사람만 아는 사전조건은 스킬이 `AskUserQuestion`으로 물어 추가.

## 예시 (login 페이지 → TC)

`sample_login_page.dart`에서 관측: 두 입력란(placeholder `user@example.com`/`Password`),
`'Sign In'` 버튼, `'Create Account'` 버튼(핸들러 비어있음 → 관측 결과 없음),
빈 입력 시 `_showError` → `'Invalid credentials. Please try again.'`,
입력 후 `_onLogin` → 로딩 스피너 → **2초 뒤** `_showError` 다시 참(성공 흐름 없음, 항상 에러).

```markdown
# TC: Login — 자격 증명 입력과 로그인 시도

- app: elemental_showcase (Sample App)
- sample id: login
- source: Sample App 페이지 소스 (Zephyr 키 없음)

## [pre-condition]
- Elemental Showcase 앱이 실행되어 있다.
- Sample App의 "Login" 화면에 진입해 있다.

## 시나리오 1: 빈 자격 증명으로 로그인 시도 시 에러 표시
### [test-sequence]
1. 이메일 입력란과 비밀번호 입력란을 비운 채 'Sign In' 버튼을 선택한다.
### [expected]
- 'Invalid credentials. Please try again.' 문구가 화면에 표시된다.

## 시나리오 2: 자격 증명 입력 후 로그인 시도 시 로딩 후 에러 표시
### [test-sequence]
1. 이메일 입력란에 'user@example.com' 을 입력한다.
2. 비밀번호 입력란에 임의의 값을 입력한다.
3. 'Sign In' 버튼을 선택한다.
### [expected]
- 로딩 표시(스피너)가 나타난다.
- 약 2초 뒤 'Invalid credentials. Please try again.' 문구가 화면에 표시된다.
```

`'Create Account'` 버튼은 핸들러가 비어 있어(`onPressed: () {}`) 관측 가능한 결과가 없으므로
TC 기대로 쓰지 않는다 — 지어내지 않는다는 HARD RULE.

## ①로의 핸드오프

- 생성한 TC 텍스트를 `/tas-parse`의 `source`로 넘긴다(파일 경로 또는 텍스트).
- Sample App은 Zephyr 키가 없으므로 IR의 `source_ticket`은 null이 된다.
- app-config(`sam_app_id` 등)는 ① 인테이크에서 받는다 — ⓪은 TC 텍스트만 책임진다.
