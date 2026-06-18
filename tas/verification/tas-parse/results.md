# tas-parse 검증 결과

| TC | 스키마/불변식 | 환각(source_span) | 완전성 | 종합 |
|---|---|---|---|---|
| TVDEVTC-23796 (step별 구조) | PASS | PASS | PASS | **PASS** |

## TVDEVTC-23796 [Home] FeatureBAT — step별 IR 구조 (2026-06-16~)
- 7개 sub-check를 각각 자기완결 `step{id,name,preconditions,actions,expected}`로 분리.
- 체커 PASS: 스키마/불변식, 모든 source_span verbatim, unresolved 없음.
- 완전성(눈): 7개 전부 반영, lowering(클릭→focus_move+OK) 정확.
- **이전 갭(멀티-시나리오 평탄화) 해소됨**: 각 step이 자기 precondition에서 새로 시작하므로
  step 6(Media Discovery 실행)이 step 7·1~5의 맥락을 오염시키지 않음. step `name`으로
  ③이 `home_<name>.py`로 분리 가능.
- 비고: step 6·7은 TC에 "Launch home app"이 명시되지 않아(steps 1~5만 명시) home-foreground
  precondition을 verbatim으로 못 넣음 → 해당 step preconditions는 비움(명시된 것만 추출 원칙).
  실제 실행 시 home-foreground는 ④ 환경/직전 step이 보장.
- 다운스트림: ②③ 정렬 완료 — ②(appgen) binding이 `(step_id, action_id)`/`(step_id, expected_index)`,
  ③(tasgen) IR step 1개 = 파일 1개(`<appName>_<step.name>.py`). (ir-schema.md 하단 참조)
