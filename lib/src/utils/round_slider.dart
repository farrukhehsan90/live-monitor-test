import 'package:flutter/material.dart';

class CustomThumbShape extends SliderComponentShape {
  final double thumbRadius;

  CustomThumbShape({this.thumbRadius = 10.0});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(PaintingContext context, Offset center,
      {Animation<double>? activationAnimation,
      Animation<double>? enableAnimation,
      bool? isDiscrete,
      TextPainter? labelPainter,
      RenderBox? parentBox,
      SliderThemeData? sliderTheme,
      TextDirection? textDirection,
      double? value,
      double? textScaleFactor,
      Size? sizeWithOverflow}) {
    final canvas = context.canvas;
    final paint = Paint()
      ..color = sliderTheme!.thumbColor!
      ..style = PaintingStyle.fill;

    final rRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: thumbRadius * 1.5,
          height: thumbRadius * 2.5,
        ),
        Radius.elliptical(thumbRadius, thumbRadius / 3));

    canvas.drawRRect(rRect, paint);
  }
}

class ColoredTrackShape extends SliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2.0;
    final thumbHeight =
        sliderTheme.thumbShape!.getPreferredSize(false, false).height;
    const gap =
        2.0; // Adjust this value to control the gap between track sections

    final top = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final bottom = top + trackHeight;

    final left = offset.dx + thumbHeight / 2;
    final right = offset.dx + parentBox.size.width - thumbHeight / 2;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Animation<double>? enableAnimation,
    TextDirection? textDirection,
    double? value,
    Offset? secondaryOffset,
    required Offset thumbCenter,
    double? thumbRadius,
    bool? isDiscrete,
    bool? isEnabled,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );

    // Calculate the width of each section
    final sectionWidth = trackRect.width / 207;
    int interval = 0;
    // Paint the green, orange, and red sections
    for (int i = 0; i < 207; i++) {
      final sectionLeft = trackRect.left + i * sectionWidth;
      final sectionRight = sectionLeft + sectionWidth;
      if (interval == 10) {
        canvas.drawRect(
          Rect.fromLTRB(
              sectionLeft, trackRect.top, sectionRight, trackRect.bottom),
          Paint()..color = const Color(0xFF222223),
        );
        canvas.drawRect(
          Rect.fromLTRB(
              sectionLeft, trackRect.top, sectionRight, trackRect.bottom),
          Paint()..color = const Color(0xFF222223),
        );
        canvas.drawRect(
          Rect.fromLTRB(
              sectionLeft, trackRect.top, sectionRight, trackRect.bottom),
          Paint()..color = const Color(0xFF222223),
        );
        interval = 0;
        continue;
      }
      if (i < 66) {
        canvas.drawRect(
          Rect.fromLTRB(
              sectionLeft, trackRect.top, sectionRight, trackRect.bottom),
          Paint()..color = const Color(0xFF6DCB95),
        );
      } else if (i < 130) {
        canvas.drawRect(
          Rect.fromLTRB(
              sectionLeft, trackRect.top, sectionRight, trackRect.bottom),
          Paint()..color = const Color(0xFFCB8C51),
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(
              sectionLeft, trackRect.top, sectionRight, trackRect.bottom),
          Paint()..color = const Color(0xFFCB3B3C),
        );
      }
      interval++;
    }
  }
}

class CustomOverlayShape extends SliderComponentShape {
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size(
        0, 0); // This shape is invisible, used only for layout purposes
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    // This shape is invisible and does not need to paint anything
  }
}
