import 'package:flutter/material.dart';

class AnimatedGradientPanel extends StatefulWidget {
  const AnimatedGradientPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.colors,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Color>? colors;

  @override
  State<AnimatedGradientPanel> createState() => _AnimatedGradientPanelState();
}

class _AnimatedGradientPanelState extends State<AnimatedGradientPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> palette = widget.colors ??
        <Color>[
          Theme.of(context).colorScheme.primary.withOpacity(0.13),
          Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          Colors.white,
        ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            ),
            gradient: LinearGradient(
              begin: Alignment(-1 + (t * 2), -1),
              end: Alignment(1 - (t * 2), 1),
              colors: palette,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: widget.padding,
            child: widget.child,
          ),
        );
      },
    );
  }
}
