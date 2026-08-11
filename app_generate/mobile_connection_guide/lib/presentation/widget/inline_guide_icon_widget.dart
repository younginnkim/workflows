// InlineGuideIconWidget — Shared widget (설명 문구 중간에 들어가는 아이콘)
//
// Figma: 각 가이드 화면의 Text 블록 안에 84x84 아이콘이 절대 배치돼 있다.
//   5.2-1  ic_setting_aos    (안드로이드 설정)   — 흰 원 + 톱니, bg #4298fd
//   5.2-2  ic_googlecast     (캐스팅)           — 흰 원 + 캐스트 글리프
//   5.3-1  ic_setting_ios    (아이폰 설정)
//   5.3-2  ic_mirroring      (AirPlay 미러링)   — 흰 라운드 사각 + 벡터
//
// Figma 원본은 벡터/래스터 혼합이라, 실행 가능한 자산이 있는 것만 이미지로
// 쓰고 나머지는 LimestoneIcons 글리프로 대체한다. 아이콘 크기는 .dh 를 쓴다
// (SKILL Audit 8 — .w/.h 는 비 16:9 뷰포트에서 아이콘을 왜곡시킨다).
// .dh (ResponsiveScaleExtension) 는 widgets.dart 배럴에 없어서 직접 import 한다.
import 'package:elemental/foundation/responsive_screen_utils.dart';
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';

/// 문구 흐름 안에 들어가는 84x84 원형 아이콘.
class InlineGuideIconWidget extends StatelessWidget {
  const InlineGuideIconWidget({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    this.backgroundColor,
  });

  /// 아이콘 글리프.
  final IconData icon;

  /// Audio Guidance 발화용 라벨 (IR: sn_home_0117 'Cast' 등).
  final String semanticsLabel;

  /// Figma 의 아이콘 배경색. null 이면 흰 원.
  final Color? backgroundColor;

  /// Figma 아이콘 박스 84x84 (UHD 원본값).
  static const double _boxSize = 84;

  /// 원 안쪽 글리프 — Figma 비율(약 0.5)에 맞춘다.
  static const double _glyphSize = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        width: _boxSize.dh,
        height: _boxSize.dh,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor ?? EColorTokens.bodyText.labelWhite,
          shape: BoxShape.circle,
        ),
        child: EIcon(
          icon,
          size: _glyphSize.dh,
          // 흰 배경 위 글리프는 검정, 컬러 배경 위에서는 흰색.
          color: backgroundColor == null
              ? EColorTokens.bodyText.labelBlack
              : EColorTokens.bodyText.labelWhite,
        ),
      ),
    );
  }
}
