// EntryPage — View (5 · 스마트폰 공유 가이드 진입 화면)
//
// IR unresolved(view5-vs-view5.1-relation):
//   "page 2 (5. 스마트폰 공유 가이드) 와 page 3 (5. 스마트폰 공유 카드 >
//    메인 화면) 의 목업이 동일. page 2 는 컴포넌트 구성(1/2/3 그룹) 명세,
//    page 3 은 개별 카드 동작 명세로 읽었으나, 서로 다른 화면인지 같은 화면의
//    2단 명세인지 PDF에 명시 없음."  → user_decision: needs_design_input
//
// Figma 에도 진입 화면 프레임이 274:116181 하나뿐이고 5.1 에 해당하는 별도
// 프레임이 없다. 따라서 같은 화면의 2단 명세로 보고 [MainPage] 하나로 구현한다.
// 두 화면이 실제로 분리돼야 한다면 여기에 별도 트리를 넣으면 된다.
import 'package:flutter/widgets.dart';

import 'main_page.dart';

/// 진입 화면 = 메인 화면 (동일 목업).
class EntryPage extends StatelessWidget {
  const EntryPage({super.key});

  @override
  Widget build(BuildContext context) => const MainPage();
}
