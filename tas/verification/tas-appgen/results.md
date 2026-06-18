# tas-appgen 검증 결과

| TC | 스키마/불변식 | 참조무결성(refs) | IR-xref | 커버리지 | 계측(app_test) | 종합 |
|---|---|---|---|---|---|---|
| _(아직 실제 appgen_output 산출물 없음)_ | — | — | — | — | — | — |

## 체커 자체 검증 (2026-06-16)

실제 `/tas-appgen` 산출물(appgen_output)이 아직 없어, 체커 로직만 합성 fixture로 검증함
(ground truth = `output/tas-parse/TVDEVTC-23796.ir.yaml`):

- **PASS**: 9개 target action + 7개 expected 전부 binding, 모든 typeName∈widgets, key 노출 일치,
  app_test.dart에 toStringMap·전 TypeName 등록 → exit 0.
- **FAIL**: 의도적으로 5개 위반 심음 → 전부 포착 (exit 1):
  - typeName이 widgets에 없음 / find.method 무효(`byMagic`)
  - property_value.key가 widgets[typeName]에 미노출
  - **non-target action(key_press)에 binding** 부착
  - IR에 없는 expected ref `(99,5)` (dangling)
- **ESCALATE**: 스키마는 깨끗하나 `unsupported` 비어있지 않음 + binding 누락 → coverage gap 14건 (exit 2).

→ 체커 동작 확인됨. 실제 TC를 `/tas-appgen`으로 돌려 `output/tas-appgen/<KEY>.appgen.yaml`이
나오면 이 표를 채운다.

## 검증 루프 (실제 산출물 생길 때)

1. `/tas-parse` IR → `output/tas-parse/<KEY>.ir.yaml` (= ground truth)
2. `/tas-appgen` 실행 → appgen_output을 `output/tas-appgen/<KEY>.appgen.yaml`,
   app repo의 `integration_test/app_test.dart` 직접 수정
3. 체커 실행 → 스키마·참조·IR-xref·커버리지 자동 판정
   ```bash
   cd verification/tas-appgen
   python3 tas-appgen-check.py \
     ../../output/tas-appgen/<KEY>.appgen.yaml \
     ../../output/tas-parse/<KEY>.ir.yaml \
     <app_repo>/integration_test/app_test.dart
   ```
4. 사람이 `lib/` 소스 대조 → typeName/find/property가 **실제로 맞는** 위젯·필드인지 판정
5. 이 표에 종합 기록
