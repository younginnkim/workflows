---
name: tas-tc-from-app
description: "TAS 자동화 0단계(TC 생성) — Elemental Showcase의 Sample App 페이지 소스에서 관측 가능한 동작을 읽어 자연어 TC 텍스트를 만든다(①/tas-parse의 입력). 사용 시점: Zephyr TC가 없는 Sample App을 TAS로 만들고 싶을 때. 호출: `/tas-tc-from-app {sample id 또는 페이지 소스 경로}` (예: `/tas-tc-from-app login`). 다음: /tas-parse(①)."
---

# /tas-tc-from-app — Sample App 소스 → 자연어 TC 텍스트 (Stage ⓪)

Elemental UI Showcase의 **Sample App 페이지 소스**를 읽어, 그 화면에서 **실제로 관측 가능한 동작**을
자연어 TC 텍스트로 **생성**한다. 산출 TC 텍스트는 그대로 `① /tas-parse`의 `source`(TC 텍스트)로 넣는다.
생성 전에 **반드시** `reference/tc-schema.md`(TC 텍스트 포맷 + Sample App 도출 규칙)를 읽는다.

이 스킬은 파이프라인 앞단(⓪)을 채운다. Sample App에는 Zephyr TC가 없으므로, 소스에서 TC를 만들어
`/tas-parse`가 먹을 수 있게 한다. **Zephyr에 티켓을 만들지 않는다 — 로컬 텍스트 파일만 출력한다.**

## 대상 (Elemental Showcase의 Sample App만)

- 프로젝트: `/home/younginkim/project/2026/elemental_showcase`
- 카탈로그: `lib/features/sample_app/catalog/sample_page_catalog.dart` (id/name/description)
- 페이지: `lib/features/sample_app/pages/sample_<id>_page.dart`
- 현재 sample id: `home` `login` `settings` `form` `list` `wizard` `dialog` `empty` `error`

위젯 showcase(`widget_book/widgets/*_showcase.dart`)는 **대상이 아니다** — 단일 위젯 데모라 TAS
가치가 낮다(그쪽은 generate-showcase audit이 담당).

## 입력 받기 (인테이크)

인자는 **sample id**(예: `login`) 또는 **페이지 소스 경로**(예: `.../pages/sample_login_page.dart`).

- 인자가 없으면 → `AskUserQuestion`으로 카탈로그의 sample id 목록을 객관식으로 보여주고 고르게 한다
  (옵션에 '전체' 포함 — 전체 선택 시 카탈로그의 모든 페이지를 순회한다).
- 인자가 sample id면 카탈로그에서 name/description을 읽고, `pages/sample_<id>_page.dart`를 읽는다.
- 인자가 경로면 그 파일을 직접 읽는다. 카탈로그에 매칭되는 entry가 있으면 name/description도 참고.
- 파일을 못 찾으면 → 지어내지 말고 `AskUserQuestion`으로 정확한 경로/ id를 되묻는다.

## 실행

`reference/tc-schema.md`의 HARD RULES대로 한다.

1. **소스 정독** — 대상 페이지의 `build`/`State`를 읽어 다음만 추출한다(`reference/tc-schema.md`의
   도출 규칙 참조):
   - **관측 가능한 UI 요소** — 화면에 보이는 라벨/버튼/입력/텍스트(예: `EButton(text: 'Sign In')`,
     `EBodyText(child: 'Invalid credentials...')`). **위젯 TypeName은 TC에 넣지 않는다**(①의 몫).
   - **상호작용** — 사용자가 리모컨으로 할 수 있는 것(포커스 이동 + OK, 입력).
   - **상태 전이/기대결과** — `setState`가 실제로 바꾸는 관측 가능한 결과만
     (예: login은 2초 뒤 에러 메시지 표시, form은 동의 체크 후 submit 시 "Submitted!" 화면 전환).
2. **관측 가능한 것만 TC화** — 소스에 **없는 성공 흐름/화면/검증을 지어내지 않는다.** 데모 stub이
   특정 결과만 보이면(예: login이 항상 에러) 그 결과만 TC로 쓴다. 모호하거나 소스로 확정 못하는
   부분은 TC에 넣지 말고 "확인 필요"로 남겨 사용자에게 `AskUserQuestion`으로 확인한다.
3. **preconditions 확인** — 페이지 진입 상태(앱 실행/해당 sample 화면 진입)를 preconditions로 적는다.
   그 밖에 사람만 아는 사전조건이 있으면 `AskUserQuestion`으로 "추가 precondition 있으면 적어줘,
   없으면 '없음'"을 묻는다('없음'/'추가 있음'→Other 자유 입력; 평문 텍스트 질문 금지).
4. **TC 텍스트 생성** — `reference/tc-schema.md`의 포맷으로 자연어 TC를 만든다. 각 독립 체크는
   별도 시나리오로 나눈다(①이 step으로 분리하기 좋게).
5. **저장** — 스킬을 발동한 **현재 작업 디렉터리(cwd, `pwd`로 확인)** 기준
   `output/tas-tc/sample_<id>.tc.md`에 저장한다(`output/tas-tc/`가 없으면 만든다).
   '전체'면 각 sample마다 파일 하나씩.
6. **출력** — 저장한 파일의 **절대경로**와 내용을 보여주고 안내한다:
   "다음 단계 `/tas-parse`(①)에 이 TC 텍스트(또는 파일 경로)를 `source`로 넘기면 됩니다.
   Sample App은 Zephyr 키가 없으니 `source_ticket`은 비웁니다."

## 원칙

- **모르는/안 보이는 동작을 지어내지 말 것.** 소스에서 관측 가능한 것만 TC화한다. 데모 stub의 한계
  (항상 에러 등)를 실제 앱 흐름처럼 미화하지 않는다.
- **위젯 TypeName/property를 TC에 넣지 않는다.** TC는 자연어(사람이 읽는 시나리오)다 — 위젯 해석은
  ①→②의 책임이다. TC엔 "보이는 라벨/문구"와 "리모컨으로 하는 행동"만.
- **Zephyr에 쓰지 않는다.** 로컬 `output/tas-tc/*.tc.md`만 만든다(되돌리기 쉬움, 안전).
- **사용자에게 묻는 모든 것은 항상 `AskUserQuestion`으로** — 평문 텍스트 질문 금지.
- 이 스킬은 ⓪이다. 이후 ①②③④는 기존 `/tas` 또는 개별 스킬을 그대로 재사용한다(로직 재구현 금지).
