/// Maps a horizontal drag distance to an absolute playback position.
///
/// A drag across the full video surface covers the complete episode. Targets
/// are clamped so an oversized fling can never seek beyond either boundary.
Duration hgHorizontalSeekTarget({
  required Duration start,
  required Duration duration,
  required double deltaPixels,
  required double width,
}) {
  if (duration <= Duration.zero || width <= 0 || !deltaPixels.isFinite) {
    return start < Duration.zero ? Duration.zero : start;
  }
  final target =
      start.inMilliseconds +
      (duration.inMilliseconds * deltaPixels / width).round();
  return Duration(milliseconds: target.clamp(0, duration.inMilliseconds));
}
