# ① IR 고도화 — focus_move 도달 경로(navigation) 설계

날짜: 2026-06-18
대상 스킬: tas-parse(①), 파급: tas-appgen(②) · tas-tasgen(③)

## 문제

현재 ① IR의 `focus_move`는 **타깃만**(role + match{text/key/index} + container) 담고,
"리모컨으로 그 타깃까지 어떻게 도달하는지"는 담지 않는다. 다음 단계가 `find→setFocus`로
바로 점프한다고 가정하지만, 실제 webOS TV는 방향키 포커스 이동이라 그 가정이 깨진다
(예: App List에서 특정 앱 타일까지 RIGHT로 스캔해야 도달). 그래서 임시로 `focus_scan`을
디바이스 base에만 손으로 넣어야 했다. 도달 경로를 ①에서 일급으로 표현·입력받게 한다.

## 결정 사항

- **출처:** ① 파싱 단계에서 **사용자가 대화형으로 보충 입력**(TC 원문엔 키 경로가 없음).
- **지원 방법:** `direct`(기본) · `scan`(방향 스캔) · `key_sequence`(고정 키 열).
- **입력 시점:** 파싱 끝에 **focus_move 목록을 일괄로** 보여주고 항목별로 입력.
- **스키마 형태:** focus_move에 선택적 `navigation` 서브필드(접근 A — 국소·최소 변경).

## ① 스키마 변경 (ir-schema.md)

`focus_move`(및 `tap`) action에 선택적 `navigation` 추가:

```yaml
- id: 2
  intent: focus_move
  target: { role: item, match: { text: "Media Discovery App" }, container: "App List" }
  navigation:                      # 선택. 없으면 method=direct (현행 동작과 100% 호환)
    method: direct | scan | key_sequence
    direction: UP|DOWN|LEFT|RIGHT  # method=scan 일 때 필수
    keys: [DOWN, DOWN, RIGHT]      # method=key_sequence 일 때 필수 (key enum 재사용)
    max_steps: 40                  # scan 선택값(기본 40)
  source_span: "..."
```

규칙:
- `navigation` 없음 = `direct`. 기존 IR 호환.
- 스캔 **정지 대상 식별자는 ①에 담지 않는다** — 기존 `target.match`를 ②가 해소(책임 분리).
- HARD RULES 정합: `navigation`은 TC 원문이 아닌 **사용자 보충값**이므로 "명시된 것만 추출"의
  명시적 예외(리모컨 도메인 + 사용자 입력). `source_span`은 `"user-supplied (navigation)"` 표식.
- 불변식: `method=scan` → `direction` 필수; `method=key_sequence` → `keys`(유효 key enum) 필수.

## ① 입력 UX (파싱 끝 일괄)

1. ①이 초안 IR을 먼저 완성.
2. IR의 모든 `focus_move`를 목록으로 제시, **항목마다 AskUserQuestion**: method 선택 →
   scan이면 방향, key_sequence면 키 열을 이어 입력.
3. 고른 값으로 `navigation`을 채워 최종 IR 저장.

## 파급 — ② appgen (appgen-schema.md)

- `navigation.method=scan` 이면 binding의 `find`가 **정지 id/key**를 `target.match`에서 해소하고,
  그 위젯의 `widgets[typeName]`에 **focus_scan이 비교할 id property(`id_key`, 기본 `id`)를 노출**해야
  한다. 노출 불가면 `unsupported`. (예: home_04의 `AppItemWidget.id`.)
- `key_sequence`는 앱 의존 해소가 없어 ②가 그대로 통과.

## 파급 — ③ tasgen

dispatch 표에서 `focus_move`를 `navigation.method`로 분기 (tasgen-mapping.md):

| method | 출력 |
|---|---|
| direct(또는 navigation 없음) | `self.focus('<typeName>', by_key/by_text=…)` (현행) |
| scan | `self.focus_scan('<typeName>', '<정지 id/key>', '<DIRECTION>')` (+ max_steps) |
| key_sequence | `keys` 각각 `self.send_key('<K>')` 나열 (그 step의 OK는 별도 key_press) |

base 템플릿 `reference/tasbase.py`에 **`focus_scan` primitive를 반영**한다(현재 디바이스
`home_tas_base.py`에만 손으로 들어가 있고 템플릿엔 없음). 같은 파일에 사용자가 넣은
**홈-격리(_run에서 매 TC 홈 foreground) · `assert_app_launch` 폴링**도 템플릿과 어긋나 있으므로
함께 sync(네비와 별개지만 같이 반영 권장).

## 비목표 (YAGNI)

- "컨테이너 진입 후 스캔" 조합형(reach 리스트)은 지금 범위 밖(필요 시 후속).
- 런타임 자동 네비 탐색은 안 함(사용자 입력이 출처).

## 영향 파일

- `tas-parse/reference/ir-schema.md` — navigation 필드 + 불변식 + HARD RULE 예외
- `tas-parse/SKILL.md` — 파싱 끝 일괄 입력 단계
- `tas-appgen/reference/appgen-schema.md` — scan 정지 id 해소 + id property 노출 규칙
- `tas-tasgen/reference/tasgen-mapping.md` — focus_move dispatch 분기
- `tas-tasgen/reference/tasbase.py` — focus_scan(+ 홈격리·app_launch 폴링 sync)
