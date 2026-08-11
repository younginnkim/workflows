# mobileconnectionguide — Behavior IR

`mobileconnectionguide.pdf` (11p, v1.0.0 / 2025.08.12) 를 `/ir-from-ux` 전체 분석 모드로
변환한 IR입니다. **코드가 아니라 IR**이며, 하위 skill들이 이 파일들을 읽어 코드를 만듭니다.

## 분석 결과

| 항목 | 값 |
|---|---|
| 모드 | whole-app (전체 분석) |
| 연결된 view 그룹 | 1 (chapter 5) |
| View | 10 |
| Component | 61 |
| Luna 결정 | 8 (사용자 확인 6 / auto 2) |
| i18n key | 30 |
| Voice 패턴 | 0 (PDF에 Voice Foreground 영역 없음) |
| 통합 테스트 시나리오 | 69 (+ skip 8) |
| 미해결 | 16 |

## 파일 구조

```
mobileconnectionguide/
├── README.md                    ← 이 파일
├── SESSION-LOG.md                  생성 과정 기록 (결정 근거·환경 이슈·검증 결과)
├── app-overview.md              ★ 앱 전체 흐름 + 그룹 인덱스 + 공유 컴포넌트
├── app-flow.yaml                ★ 기계 판독용 앱 흐름
├── manifest.json                   그룹/view 목록
├── decisions.yaml               ★ Luna API 결정 캐시 (luna-writer가 직접 소비)
├── flows/
│   └── navigation.yaml             화면 전환 그래프 (28 transitions)
├── shared/
│   ├── i18n-keys.yaml              문구태그 카탈로그 (+ 누락 태그 4건)
│   └── voice-patterns.yaml         (빈 목록 — 근거 기록됨)
└── groups/5-smartphone-share-guide/
    ├── requirements.md          ★ 그룹 요구사항 문서 (사람이 읽는 용도)
    ├── behaviors.yaml           ★ 주 IR — view 10개 동작 명세
    ├── accessibility.yaml          Audio Guidance / 포커스 규칙
    ├── components.yaml             ux_tag → figma_hint (+ 자기검증)
    ├── test-scenarios.yaml      ★ 통합(behavior) 테스트 시나리오
    └── mockups/                    view별 목업 이미지 10장
```

## 하위 skill 연결

| Skill | 읽는 파일 |
|---|---|
| `widget-from-figma` | `components.yaml` (figma_hint), `behaviors.yaml` (render/on_select) |
| `luna-writer` | `decisions.yaml`, `behaviors.yaml` (impl 블록) |
| `widget-finder` | `components.yaml` (visual_role) |
| build/test loop | `test-scenarios.yaml` |

`test-scenarios.yaml`은 Figma 없이 도출 가능한 통합 시나리오만 담습니다.
**시각 assert(크기/폰트/색/위치)는 Figma 검증 단계의 책임**이며 여기 없습니다
(`deferred_figma_unit: true`로 표시).

## 다음 단계

```bash
# 항상 (레거시 코드 유무와 무관)
/mvvm-structure --ir mobileconnectionguide --out <project>/lib

# 마이그레이션할 레거시 코드가 있다면 먼저
/gap-analyze --ir mobileconnectionguide --code <source-code dir>

# 그 다음 구현
/widget-from-figma <Figma_URL> <target_file.dart>
/luna-writer
```

## 주의사항

1. **범위** — 이 PDF는 상위 시나리오 문서의 chapter 5 발췌본입니다. 앱 전체가 아니라
   단일 연결 view 그룹만 담고 있습니다.
2. **appId 3건 미확정** — Google Cast / Sound Share appId는 `luna-api-docs` 전체 grep에서
   0건이라 추측하지 않고 `{UNRESOLVED:...}` 로 남겼습니다. 메소드(`launch`)는 확정입니다.
3. **외부 문서 4건 참조** — Mobile Connection / Settings_Sound 시나리오, Wizardview 패턴,
   공통 UX 정책(Back)은 이 PDF 범위 밖입니다. 해당 시나리오를 함께 분석하면 미해결
   항목 상당수가 해소됩니다.
4. **`confirmed_by_user: false`** 가 붙은 항목은 사용자 확인 없이 자동 추론된 값입니다.
   `test-scenarios.yaml`에서는 `confidence: low`로 표시됩니다.
