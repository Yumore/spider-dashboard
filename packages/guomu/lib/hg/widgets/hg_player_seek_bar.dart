import 'package:flutter/material.dart';

import '../theme/hg_theme.dart';

class HgPlayerSeekBar extends StatefulWidget {
  const HgPlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.scrubbing,
    this.seeking = false,
    this.buffered = Duration.zero,
    required this.showTimeLabels,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final Duration position;
  final Duration duration;
  final bool scrubbing;
  final bool seeking;
  final Duration buffered;
  final bool showTimeLabels;
  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;

  @override
  State<HgPlayerSeekBar> createState() => HgPlayerSeekBarState();
}

class HgPlayerSeekBarState extends State<HgPlayerSeekBar> {
  double? _dragFraction;

  double get _currentFraction {
    final durationMs = widget.duration.inMilliseconds;
    if (durationMs <= 0) return 0;
    return (widget.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant HgPlayerSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.scrubbing && !widget.seeking) {
      _dragFraction = null;
    }
  }

  String _time(Duration value) {
    final seconds = value.inSeconds.clamp(0, 99 * 60 * 60);
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (_dragFraction ?? _currentFraction).clamp(0.0, 1.0);
    final durationMs = widget.duration.inMilliseconds;
    final previewPosition = Duration(
      milliseconds: (durationMs * fraction).round(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final trackWidth = (width - 16).clamp(1.0, width);
        final bubbleLeft = (8 + trackWidth * fraction - 29).clamp(
          0.0,
          width - 58,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showTimeLabels)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Row(
                  children: [
                    Text(
                      _time(previewPosition),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _time(widget.duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.5,
                      activeTrackColor: widget.scrubbing
                          ? Colors.white
                          : HgColors.orange,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                      secondaryActiveTrackColor: Colors.white.withValues(
                        alpha: 0.4,
                      ),
                      thumbColor: Colors.white,
                      disabledThumbColor: Colors.white,
                      disabledActiveTrackColor: HgColors.orange,
                      disabledInactiveTrackColor: Colors.white.withValues(
                        alpha: 0.22,
                      ),
                      disabledSecondaryActiveTrackColor: Colors.white
                          .withValues(alpha: 0.4),
                      overlayColor: Colors.transparent,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: widget.scrubbing ? 6.5 : 4.5,
                        elevation: 0,
                        pressedElevation: 0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 0,
                      ),
                      tickMarkShape: SliderTickMarkShape.noTickMark,
                      showValueIndicator: ShowValueIndicator.never,
                      trackShape: const RoundedRectSliderTrackShape(),
                    ),
                    child: Slider(
                      value: fraction,
                      secondaryTrackValue: durationMs <= 0
                          ? 0
                          : (widget.buffered.inMilliseconds / durationMs).clamp(
                              fraction,
                              1.0,
                            ),
                      semanticFormatterCallback: (value) =>
                          '${_time(Duration(milliseconds: (durationMs * value).round()))}，共 ${_time(widget.duration)}',
                      min: 0,
                      max: 1,
                      allowedInteraction: SliderInteraction.tapAndSlide,
                      onChangeStart: durationMs <= 0 || widget.seeking
                          ? null
                          : (value) {
                              setState(() => _dragFraction = value);
                              widget.onScrubStart(value);
                            },
                      onChanged: durationMs <= 0 || widget.seeking
                          ? null
                          : (value) {
                              setState(() => _dragFraction = value);
                              widget.onScrubUpdate(value);
                            },
                      onChangeEnd: durationMs <= 0 || widget.seeking
                          ? null
                          : (value) {
                              setState(() => _dragFraction = value);
                              widget.onScrubEnd(value);
                            },
                    ),
                  ),
                  if (widget.scrubbing)
                    Positioned(
                      left: bubbleLeft,
                      top: -18,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _time(previewPosition),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
