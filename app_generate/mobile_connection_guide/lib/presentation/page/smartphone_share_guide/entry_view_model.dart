// EntryViewModel — ViewModel (5 · 스마트폰 공유 가이드 진입 화면)
//
// IR unresolved(view5-vs-view5.1-relation) 에 따라 view 5 와 5.1 을 같은 화면의
// 2단 명세로 보고 하나로 구현했다. 상태/동작은 전부 MainViewModel 에 있다.
//
// 두 화면이 실제로 분리돼야 한다면 여기에 진입 화면 전용 상태를 넣는다.
// (지금 별도 상태를 만들면 MainViewModel 과 구독이 중복된다.)
//
// See: main_view_model.dart · entry_page.dart
