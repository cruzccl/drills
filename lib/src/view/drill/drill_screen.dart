import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/drill/drill_controller.dart';
import 'package:lichess_mobile/src/model/puzzle/puzzle_controller.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/immersive_mode.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/view/drill/drill_strings.dart';
import 'package:lichess_mobile/src/view/drill/drill_summary.dart';
import 'package:lichess_mobile/src/view/puzzle/puzzle_feedback_widget.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/board.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:material_ui/material_ui.dart';

/// The screen of the Drill being played: its puzzles one after the other, then its Drill Summary.
///
/// While the Drill runs, only its progress is shown (zen mode): nothing about the previous
/// puzzles, nor the player's rating.
class const DrillScreen({super.key}) extends ConsumerWidget {
  static Route<dynamic> buildRoute() {
    return buildScreenRoute(screen: const DrillScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drill = ref.watch(drillControllerProvider);

    return WakelockWidget(
      child: PlatformScaffold(
        extendBodyBehindAppBar: false,
        appBar: PlatformAppBar(
          title: Text(
            drill == null || drill.isOver
                ? DrillStrings.summaryTitle
                : '${drill.puzzleNumber} / ${drill.drill.config.nbPuzzles}',
          ),
          actions: [
            if (drill != null && !drill.isOver)
              TextButton(
                onPressed: () => showConfirmDialog<void>(
                  context,
                  title: const Text(DrillStrings.endDrillConfirmation),
                  onConfirm: () {
                    // Ended before any puzzle was solved, the Drill is discarded: no summary.
                    final hasSummary = ref.read(drillControllerProvider.notifier).end();
                    if (!hasSummary) Navigator.of(context).pop();
                  },
                ),
                child: const Text(DrillStrings.endDrill),
              ),
          ],
        ),
        body: switch (drill) {
          null => const SizedBox.shrink(),
          DrillState(isOver: true) => DrillSummary(drill.drill),
          _ => _DrillPuzzle(drill),
        },
      ),
    );
  }
}

class const _DrillPuzzle(final DrillState drill) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DrillPuzzle> createState() => _DrillPuzzleState();
}

class _DrillPuzzleState() extends ConsumerState<_DrillPuzzle> {
  final _boardKey = GlobalKey(debugLabel: 'boardOnDrillScreen');
  late final ChessboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChessboardController(game: _buildGameData());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PlayerSide _playerSide(PuzzleState state) {
    return state.mode == .load ||
            state.currentPosition.isGameOver ||
            (state.mode == .play && state.canGoNext)
        ? .none
        : state.mode == .view
        ? .both
        : state.pov == .white
        ? .white
        : .black;
  }

  GameData _buildGameData() {
    final state = ref.read(puzzleControllerProvider(widget.drill.puzzleContext));
    final boardPreferences = ref.read(boardPreferencesProvider);
    return buildGameData(
      fen: state.currentPosition.fen,
      variant: .standard,
      position: state.currentPosition,
      playerSide: _playerSide(state),
      lastMove: state.lastMove,
      castlingMethod: boardPreferences.castlingMethod,
      boardHighlights: boardPreferences.boardHighlights,
    );
  }

  void _applyBoardUpdate() {
    _controller.updatePosition(_buildGameData());
  }

  @override
  Widget build(BuildContext context) {
    final boardPreferences = ref.watch(boardPreferencesProvider);
    final ctrlProvider = puzzleControllerProvider(widget.drill.puzzleContext);
    final puzzleState = ref.watch(ctrlProvider);

    // Drive the board on position/interactivity changes without rebuilding it.
    ref.listen(
      ctrlProvider.select(
        (s) => (fen: s.currentPosition.fen, lastMoveUci: s.lastMove?.uci, side: _playerSide(s)),
      ),
      (_, _) => _applyBoardUpdate(),
    );
    ref.listen(
      boardPreferencesProvider.select((p) => (p.castlingMethod, p.boardHighlights)),
      (_, _) => _applyBoardUpdate(),
    );
    ref.listen(ctrlProvider.select((s) => (s.puzzle.puzzle.id, s.currentPath)), (prev, next) {
      if (prev != null && prev != next) {
        _controller.clearDrawnShapes();
      }
    });

    final shapes = puzzleState.hintSquare != null
        ? <Shape>{Circle(color: ShapeColor.green.color, orig: puzzleState.hintSquare!)}
        : const <Shape>{};

    final feedback = PuzzleFeedbackWidget(
      puzzle: puzzleState.puzzle,
      state: puzzleState,
      onStreak: false,
    );
    final bottomBar = _DrillBottomBar(widget.drill);

    return SafeArea(
      maintainBottomViewPadding: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          final isTablet = isTabletOrLarger(context);
          final settings = boardPreferences
              .toBoardSettings(.standard)
              .copyWith(
                borderRadius: isTablet ? Styles.boardBorderRadius : BorderRadius.zero,
                boxShadow: isTablet ? boardShadows : const <BoxShadow>[],
                drawShape: DrawShapeOptions(
                  enable: boardPreferences.enableShapeDrawings,
                  newShapeColor: boardPreferences.shapeColor.color,
                ),
              );

          BoardWidget board(double size) => BoardWidget(
            boardKey: _boardKey,
            size: size,
            controller: _controller,
            onMove: (move, {viaDragAndDrop}) => ref.read(ctrlProvider.notifier).onUserMove(move),
            orientation: puzzleState.pov,
            shapes: shapes,
            settings: settings,
          );

          if (isLandscape) {
            final boardSize = constraints.biggest.shortestSide - kTabletBoardTableSidePadding * 2;
            return Padding(
              padding: const EdgeInsets.all(kTabletBoardTableSidePadding),
              child: Row(
                children: [
                  board(boardSize),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        Expanded(child: Center(child: feedback)),
                        bottomBar,
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final boardSize = isTablet
              ? constraints.biggest.shortestSide - kTabletBoardTableSidePadding * 2
              : constraints.biggest.shortestSide;
          final sidePadding = EdgeInsets.symmetric(
            horizontal: isTablet ? kTabletBoardTableSidePadding : 12.0,
          );
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: sidePadding,
                  child: Center(child: feedback),
                ),
              ),
              Padding(
                padding: isTablet
                    ? const EdgeInsets.symmetric(horizontal: kTabletBoardTableSidePadding)
                    : EdgeInsets.zero,
                child: board(boardSize),
              ),
              const Spacer(),
              bottomBar,
            ],
          );
        },
      ),
    );
  }
}

class const _DrillBottomBar(final DrillState drill) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DrillBottomBar> createState() => _DrillBottomBarState();
}

class _DrillBottomBarState() extends ConsumerState<_DrillBottomBar> {
  /// As in the official app, the hint and the solution are only offered after a while.
  static const _helpDelay = Duration(seconds: 4);

  Timer? _helpTimer;
  bool _canGetHelp = false;

  @override
  void initState() {
    super.initState();
    _startHelpTimer();
    ref.listenManual(
      puzzleControllerProvider(widget.drill.puzzleContext).select((s) => s.puzzle.puzzle.id),
      (_, _) {
        setState(_startHelpTimer);
      },
    );
  }

  @override
  void dispose() {
    _helpTimer?.cancel();
    super.dispose();
  }

  void _startHelpTimer() {
    _canGetHelp = false;
    _helpTimer?.cancel();
    _helpTimer = Timer(_helpDelay, () => setState(() => _canGetHelp = true));
  }

  @override
  Widget build(BuildContext context) {
    final ctrlProvider = puzzleControllerProvider(widget.drill.puzzleContext);
    final puzzleState = ref.watch(ctrlProvider);
    final puzzleCtrl = ref.read(ctrlProvider.notifier);
    final canGetHelp = _canGetHelp && !puzzleState.canGoNext;
    final isViewing = puzzleState.mode == .view;

    return BottomBar(
      mainAxisAlignment: .spaceAround,
      children: [
        if (!isViewing) ...[
          BottomBarButton(
            icon: Icons.lightbulb_outline,
            label: context.l10n.getAHint,
            highlighted: puzzleState.hintSquare != null,
            onTap: canGetHelp ? puzzleCtrl.toggleHint : null,
          ),
          BottomBarButton(
            icon: Icons.flag_outlined,
            label: context.l10n.viewTheSolution,
            onTap: canGetHelp ? puzzleCtrl.viewSolution : null,
          ),
        ],
        BottomBarButton(
          onTap: puzzleState.canGoBack ? puzzleCtrl.userPrevious : null,
          label: DrillStrings.previousMove,
          icon: CupertinoIcons.chevron_back,
          showTooltip: false,
        ),
        BottomBarButton(
          onTap: puzzleState.canGoNext ? puzzleCtrl.userNext : null,
          label: context.l10n.next,
          icon: CupertinoIcons.chevron_forward,
          showTooltip: false,
          blink: puzzleState.shouldBlinkNextArrow,
        ),
        if (isViewing)
          BottomBarButton(
            onTap: widget.drill.drill.isLimitReached || puzzleState.nextContext != null
                ? ref.read(drillControllerProvider.notifier).continueDrill
                : null,
            highlighted: true,
            label: context.l10n.puzzleContinueTraining,
            icon: CupertinoIcons.play_arrow_solid,
          ),
      ],
    );
  }
}
