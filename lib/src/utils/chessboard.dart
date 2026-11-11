import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';

/// Computes the set of squares that should have an atomic explosion animation
/// after [move] was played from [positionBefore].
///
/// Returns `null` if [positionBefore] is not an atomic position, [move] is
/// null, or the move was not a capture (no explosion occurs).
Set<Square>? atomicExplosionSquares(Position positionBefore, Move? move) {
  if (move == null || positionBefore is! Atomic) return null;
  final squareSet = positionBefore.explosionSquares(move);
  return squareSet.isEmpty ? null : squareSet.squares.toSet();
}

/// Preload piece images from the specified [PieceSet] into Chessground's image cache.
///
/// This method clears the cache before loading the images.
Future<void> precachePieceImages(PieceSet pieceSet) async {
  try {
    final devicePixelRatio =
        WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio ?? 1.0;

    ChessgroundImages.instance.clear();

    await Future.wait([
      for (final asset in pieceSet.assets.values)
        ChessgroundImages.instance.load(asset, devicePixelRatio: devicePixelRatio),
    ]);
  } catch (e) {
    debugPrint('Failed to preload piece images: $e');
  }
}

/// Keeps the background image of the board [colorScheme], if it has one, loaded in Flutter's image
/// cache, in place of the one kept for the previous board theme.
///
/// Chessground draws an image background with an [Image] widget, which shows nothing until the
/// image is decoded, while it draws the pieces from its own cache: a board whose background isn't
/// in Flutter's image cache draws its pieces a few frames before its squares. Flutter empties that
/// cache when the system is short of memory, as when the app is in the background, but not of the
/// images still listened to: this one is listened to for as long as the board theme is used.
///
/// The returned future completes once the image is loaded.
Future<void> keepBoardBackgroundLoaded(ChessboardColorScheme colorScheme) {
  final background = colorScheme.background;
  return _keepImagesLoaded('boardBackground', [
    if (background is ImageChessboardBackground) background.image,
  ]);
}

/// Keeps the images of the [pieceSet] loaded in Flutter's image cache, in place of the ones kept
/// for the previous piece set, for the [Image] widgets that show a piece outside a board: see
/// [keepBoardBackgroundLoaded].
///
/// The returned future completes once the images are loaded.
Future<void> keepPieceImagesLoaded(PieceSet pieceSet) =>
    _keepImagesLoaded('pieces', pieceSet.assets.values);

/// The images kept loaded by [_keepImagesLoaded], and how they are listened to.
final _keptImages = <String, List<(ImageStream, ImageStreamListener)>>{};

/// Keeps the [images] loaded in Flutter's image cache, listening to them, in place of the ones kept
/// before for the same [purpose].
Future<void> _keepImagesLoaded(String purpose, Iterable<ImageProvider> images) async {
  final configuration = ImageConfiguration(
    devicePixelRatio:
        WidgetsBinding.instance.platformDispatcher.implicitView?.devicePixelRatio ?? 1.0,
  );
  final loads = <Future<void>>[];
  // The new images are listened to before the previous ones are let go, so that an image kept for
  // both stays in the cache.
  final kept = [
    for (final image in images)
      () {
        final loaded = Completer<void>();
        loads.add(loaded.future);
        final stream = image.resolve(configuration);
        final listener = ImageStreamListener(
          (_, _) {
            if (!loaded.isCompleted) loaded.complete();
          },
          onError: (Object error, StackTrace? stackTrace) {
            if (!loaded.isCompleted) loaded.complete();
            debugPrint('Failed to load the image $image: $error');
          },
        );
        stream.addListener(listener);
        return (stream, listener);
      }(),
  ];
  for (final (stream, listener)
      in _keptImages[purpose] ?? const <(ImageStream, ImageStreamListener)>[]) {
    stream.removeListener(listener);
  }
  _keptImages[purpose] = kept;
  await Future.wait(loads);
}
