/// The shared past-only period browser behind the merged 概览 dashboard's day,
/// week and month views.
///
/// Every dashboard view answers "what did I eat / burn in this period?" for a
/// period that is either the current one or a past one. This widget supplies
/// the two things they share:
///
/// * a **period header** with a ‹ button, a › button that only appears once
///   the user has gone back in time (there is no future to navigate to from
///   the current period, so showing an inert arrow would be a dead end), the
///   formatted period label, and a "back to now" action that likewise only
///   appears in history;
/// * a **horizontal [PageView] with no future pages**: page [historyTodayPage]
///   IS the current period and is the last (rightmost) page, so every lower
///   page index is an older period. Swiping the finger **right** (or tapping
///   ‹) reveals the previous, older page; swiping **left** (or tapping ›) moves
///   forward in time and is simply clamped at the current period.
///
/// The widget owns no data: the caller maps a page [offset] (0 = current
/// period, 1 = previous one, …) to its own label and page body. The page body
/// is expected to scope its data providers itself, so each page is rendered
/// from its own period while the header is shared.
library;

import 'package:flutter/material.dart';

/// Page index of the current period ("now") in a [HistoryPeriodPager].
///
/// The pager is past-only and this is the LAST page, so a large constant keeps
/// history effectively unbounded (10,000 days is > 27 years) without ever
/// generating a future page. `offset = historyTodayPage - page`.
const int historyTodayPage = 10000;

/// Key of the pager's [PageView] for the instance with [id].
Key historyPagerKey(String id) => Key('history_pager_$id');

/// Key of the “previous / older period” (‹) button for [id].
Key historyOlderKey(String id) => Key('history_older_$id');

/// Key of the “next / newer period” (›) button for [id].
///
/// The button is only mounted while a newer period exists, i.e. once the user
/// has stepped back into history; on the current period it is absent.
Key historyNewerKey(String id) => Key('history_newer_$id');

/// Key of the “back to now” action for [id] (only mounted when in history).
Key historyBackToNowKey(String id) => Key('history_back_to_now_$id');

/// Key of the header's period label for [id].
Key historyPeriodLabelKey(String id) => Key('history_period_label_$id');

/// A swipeable, past-only period browser with a shared header.
///
/// The header is fixed above the [PageView], so it stays put while a page is
/// dragged. [periodBuilder] is called with the page's history offset
/// (0 = current period, 1 = the previous one, …) and must return the whole
/// page body for that period; it is called lazily by the [PageView].
class HistoryPeriodPager extends StatefulWidget {
  /// Creates a history period pager.
  const HistoryPeriodPager({
    required this.id,
    required this.periodLabel,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.backToNowLabel,
    required this.periodBuilder,
    super.key,
  });

  /// Stable identity used for the widget keys of this instance.
  ///
  /// The merged 概览 dashboard keeps one pager per view (day / week / month)
  /// mounted at the same time inside an [IndexedStack], so every test key
  /// carries an id instead of being global.
  final String id;

  /// The header label for the period [offset] (`0` = current period):
  /// `今天` / `2026年1月4日 周日` / `本周` / `2025年12月29日 - 1月4日`.
  final String Function(int offset) periodLabel;

  /// Tooltip of the ‹ (older) button, e.g. `前一天` / `上一周`.
  final String previousTooltip;

  /// Tooltip of the › (newer) button, e.g. `后一天` / `下一周`.
  final String nextTooltip;

  /// Text of the "back to now" action, e.g. `回到今天` / `回到本周`.
  final String backToNowLabel;

  /// Builds the page body for the period [offset] (`0` = current period).
  final Widget Function(BuildContext context, int offset) periodBuilder;

  @override
  State<HistoryPeriodPager> createState() => _HistoryPeriodPagerState();
}

class _HistoryPeriodPagerState extends State<HistoryPeriodPager> {
  /// One page per day of history, "now" being the rightmost page.
  late final PageController _controller = PageController(
    initialPage: historyTodayPage,
  );

  /// How many periods back the visible page is (0 = current period).
  int _offset = 0;

  static const Duration _slideDuration = Duration(milliseconds: 220);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    final int offset = historyTodayPage - page;
    if (offset != _offset) {
      setState(() => _offset = offset);
    }
  }

  /// Moves one period into the past (the page to the left).
  void _goOlder() {
    if (_offset >= historyTodayPage) {
      return;
    }
    _controller.previousPage(
      duration: _slideDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// Moves one period towards the present (the page to the right).
  void _goNewer() {
    if (_offset <= 0) {
      return;
    }
    _controller.nextPage(duration: _slideDuration, curve: Curves.easeOutCubic);
  }

  /// Jumps straight back to the current period.
  void _goNow() {
    if (_offset == 0) {
      return;
    }
    _controller.animateToPage(
      historyTodayPage,
      duration: _slideDuration,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _PeriodBar(
          id: widget.id,
          label: widget.periodLabel(_offset),
          inHistory: _offset > 0,
          previousTooltip: widget.previousTooltip,
          nextTooltip: widget.nextTooltip,
          backToNowLabel: widget.backToNowLabel,
          onOlder: _offset < historyTodayPage ? _goOlder : null,
          onNewer: _offset > 0 ? _goNewer : null,
          onBackToNow: _offset > 0 ? _goNow : null,
        ),
        Expanded(
          child: PageView.builder(
            key: historyPagerKey(widget.id),
            controller: _controller,
            itemCount: historyTodayPage + 1,
            onPageChanged: _onPageChanged,
            itemBuilder: (BuildContext context, int page) =>
                widget.periodBuilder(context, historyTodayPage - page),
          ),
        ),
      ],
    );
  }
}

/// The fixed header: ‹ label › and, only in history, "back to now".
///
/// The › button is mounted only when [onNewer] is non-null: on the current
/// period there is no future page, so the arrow would lead nowhere. The slot
/// it would occupy stays reserved (as an inert [SizedBox]) in that state so the
/// period label does not jump sideways when the arrow appears or disappears.
class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.id,
    required this.label,
    required this.inHistory,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.backToNowLabel,
    required this.onOlder,
    required this.onNewer,
    required this.onBackToNow,
  });

  final String id;
  final String label;
  final bool inHistory;
  final String previousTooltip;
  final String nextTooltip;
  final String backToNowLabel;
  final VoidCallback? onOlder;
  final VoidCallback? onNewer;
  final VoidCallback? onBackToNow;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            key: historyOlderKey(id),
            onPressed: onOlder,
            tooltip: previousTooltip,
            icon: const Icon(Icons.chevron_left),
            color: colors.onSurfaceVariant,
          ),
          Expanded(
            child: Text(
              label,
              key: historyPeriodLabelKey(id),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          // No newer period from the current one: keep the slot reserved so
          // the label stays centred, but render nothing tappable there.
          if (onNewer != null)
            IconButton(
              key: historyNewerKey(id),
              onPressed: onNewer,
              tooltip: nextTooltip,
              icon: const Icon(Icons.chevron_right),
              color: colors.onSurfaceVariant,
            )
          else
            const SizedBox(width: kMinInteractiveDimension),
          if (inHistory)
            TextButton(
              key: historyBackToNowKey(id),
              onPressed: onBackToNow,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(backToNowLabel),
            ),
        ],
      ),
    );
  }
}
