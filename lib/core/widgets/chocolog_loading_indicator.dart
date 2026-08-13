import 'package:chocolog/app/theme.dart';
import 'package:flutter/material.dart';

class ChocoLogLoadingIndicator extends StatefulWidget {
  const ChocoLogLoadingIndicator({super.key, this.size = 10});

  final double size;

  @override
  State<ChocoLogLoadingIndicator> createState() =>
      _ChocoLogLoadingIndicatorState();
}

class _ChocoLogLoadingIndicatorState extends State<ChocoLogLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '読み込み中',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++) ...[
              if (index > 0) SizedBox(width: widget.size * 0.65),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final phase = (_controller.value - index * 0.16) % 1.0;
                  final lift = phase < 0.5 ? 4 * phase * (1 - phase * 2) : 0.0;
                  final emphasis = phase < 0.5
                      ? 0.85 + (0.15 * (1 - (phase * 2 - 0.5).abs() * 2))
                      : 0.85;
                  return Transform.translate(
                    offset: Offset(0, -lift * widget.size),
                    child: Transform.scale(scale: emphasis, child: child),
                  );
                },
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: const BoxDecoration(
                    color: ChocoLogColors.yellow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChocoLogRefreshIndicator extends StatefulWidget {
  const ChocoLogRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  State<ChocoLogRefreshIndicator> createState() =>
      _ChocoLogRefreshIndicatorState();
}

class _ChocoLogRefreshIndicatorState extends State<ChocoLogRefreshIndicator> {
  RefreshIndicatorStatus? _status;

  @override
  Widget build(BuildContext context) {
    final visible =
        _status == RefreshIndicatorStatus.armed ||
        _status == RefreshIndicatorStatus.refresh;
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: (status) => setState(() => _status = status),
          child: widget.child,
        ),
        Positioned(
          top: 14,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: visible
                ? const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ChocoLogColors.surface,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        child: ChocoLogLoadingIndicator(size: 7),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
