import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../ui/theme/app_radius.dart';

class UsageGuideDemoCard extends StatefulWidget {
  const UsageGuideDemoCard({
    super.key,
    required this.duration,
    required this.label,
    required this.builder,
  });

  final Duration duration;
  final String label;
  final Widget Function(BuildContext context, Animation<double> animation)
  builder;

  @override
  State<UsageGuideDemoCard> createState() => _UsageGuideDemoCardState();
}

class _UsageGuideDemoCardState extends State<UsageGuideDemoCard>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.reset();
    } else if (!_animation.isAnimating) {
      _repeat();
    }
  }

  void _repeat() {
    _animation.reset();
    _animation.repeat(period: widget.duration);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: widget.label,
      hint: reduceMotion
          ? null
          : AppLocalizations.of(context).usageGuideReplayDemo,
      child: Material(
        color: const Color(0xFF141416),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: reduceMotion ? null : _repeat,
          child: ExcludeSemantics(child: widget.builder(context, _animation)),
        ),
      ),
    );
  }
}
