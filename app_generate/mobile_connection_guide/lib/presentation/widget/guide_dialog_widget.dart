// GuideDialogWidget — Shared widget (가이드 본문: 설명 이미지 + 설명 문구)
//
// Figma: Contents 프레임 (모든 가이드/사운드셰어 화면 공통)
//   inset-[456px_0_360px_0], px 324, pt 72, column gap 84
//   Image  1860x864, radius/container 36
//   Text   min-h 252, gap 12, centered
//          main = body/66-semibold, bodytext/label-main (white)
//          sub  = body/54-regular,  bodytext/label-sub  (#b3b3b3)
//
// 화면 전체가 뷰포트(2160)에 들어오고 Figma 어디에도 스크롤 인디케이터가
// 없으므로 이 위젯은 스크롤하지 않는다 (P5).
import 'package:elemental/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 가이드 화면 본문 — 설명 이미지 1장 + 주/보조 설명 문구.
///
/// [inlineIcon] 은 문구 중간에 들어가는 아이콘(설정/캐스팅/AirPlay)이다.
/// Figma 에서는 문구에 공백을 두고 그 위에 아이콘을 절대 배치했는데, 여기서는
/// [WidgetSpan] 으로 문구 흐름 안에 넣어 줄바꿈·번역에 안전하게 만든다.
class GuideDialogWidget extends StatelessWidget {
  const GuideDialogWidget({
    super.key,
    required this.imageAsset,
    required this.description,
    this.secondaryDescriptions = const <String>[],
    this.inlineIcon,
    this.inlineIconPlaceholder,
    this.imageKey,
    this.descriptionKey,
    this.secondaryKey,
  });

  /// 설명 이미지 — Figma img_connect_* 를 1860x864 로 export 한 asset.
  final String imageAsset;

  /// 주 설명 문구 — body/66-semibold.
  final String description;

  /// 보조 설명 문구 — body/54-regular. 비면 렌더하지 않는다.
  ///
  /// 사운드셰어 화면(5.4)처럼 보조 문구가 2줄(기기 이름 / 최근 연결한 기기)인
  /// 경우가 있어 리스트로 받는다.
  final List<String> secondaryDescriptions;

  /// 문구 중간에 삽입할 아이콘. null 이면 문구를 그대로 렌더한다.
  final Widget? inlineIcon;

  /// [description] 안에서 [inlineIcon] 이 대체할 부분 문자열.
  /// 예: 'Go to Settings {%androidset_icon}' 의 '{%androidset_icon}'.
  final String? inlineIconPlaceholder;

  /// 설명 이미지 노드 키 (IR test-scenarios `guideImage`).
  final Key? imageKey;

  /// 주 설명 문구 노드 키 (IR test-scenarios `descriptionText`).
  final Key? descriptionKey;

  /// 보조 문구 노드 키 — 인덱스별 (IR test-scenarios `secondaryHintText` /
  /// `recentDeviceLabel`).
  ///
  /// [secondaryDescriptions] 가 리스트이므로 키도 인덱스로 준다. 예를 들어 5.4 는
  /// 보조 문구가 2개(기기 이름, 최근 연결 기기)이고 시나리오는 두 번째를
  /// `recentDeviceLabel` 로 참조한다 → `{1: Key('recentDeviceLabel')}`.
  final Map<int, Key>? secondaryKey;

  /// Figma img_connect_* 크기 (UHD 원본값 — 반으로 줄이지 않는다).
  static const double _imageWidth = 1860;
  static const double _imageHeight = 864;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Figma Contents: px 324, pt 72
      padding: EdgeInsets.only(left: 324.h, right: 324.h, top: 72.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            key: imageKey,
            borderRadius: BorderRadius.all(ERadiusTokens.radius.container.r),
            child: EImage(
              src: imageAsset,
              width: _imageWidth.h,
              height: _imageHeight.h,
              fit: BoxFit.cover,
            ),
          ),
          // Figma Contents gap: spacing/84
          SizedBox(height: 84.h),
          _buildTextBlock(),
        ],
      ),
    );
  }

  Widget _buildTextBlock() {
    final EFontStyleToken main = EFontTokens.semantic.body66.semibold;
    final EFontStyleToken sub = EFontTokens.semantic.body54.regular;

    final TextStyle mainStyle = TextStyle(
      color: EColorTokens.bodyText.labelMain,
      fontSize: main.fontSize.sp,
      fontWeight: main.fontWeight,
      height: 90 / 66, // Figma: line-height 90 on fontSize 66
    );
    final TextStyle subStyle = TextStyle(
      color: EColorTokens.bodyText.labelSub,
      fontSize: sub.fontSize.sp,
      fontWeight: sub.fontWeight,
      height: 72 / 54, // Figma: line-height 72 on fontSize 54
    );

    return ConstrainedBox(
      // Figma Text: min-h 252
      constraints: BoxConstraints(minHeight: 252.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildDescription(mainStyle),
          for (int i = 0; i < secondaryDescriptions.length; i++) ...<Widget>[
            // Figma Text gap: spacing/12
            SizedBox(height: 12.h),
            Text(
              secondaryDescriptions[i],
              key: secondaryKey?[i],
              textAlign: TextAlign.center,
              style: subStyle,
            ),
          ],
        ],
      ),
    );
  }

  /// 아이콘이 필요한 문구는 [WidgetSpan] 으로 흐름 안에 아이콘을 끼워 넣는다.
  Widget _buildDescription(TextStyle style) {
    final Widget? icon = inlineIcon;
    final String? placeholder = inlineIconPlaceholder;

    if (icon == null || placeholder == null) {
      return Text(
        description,
        key: descriptionKey,
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final int at = description.indexOf(placeholder);
    if (at < 0) {
      // 번역문에 플레이스홀더가 없으면 문구만 렌더한다.
      return Text(
        description,
        key: descriptionKey,
        textAlign: TextAlign.center,
        style: style,
      );
    }

    return Text.rich(
      key: descriptionKey,
      TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(text: description.substring(0, at)),
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: icon),
          TextSpan(text: description.substring(at + placeholder.length)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
