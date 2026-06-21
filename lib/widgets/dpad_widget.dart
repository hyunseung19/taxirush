import 'package:flutter/material.dart';
import '../models/game_models.dart';

class DPadWidget extends StatelessWidget {
  final void Function(Direction) onDirectionStart;
  final void Function() onDirectionEnd;

  const DPadWidget({
    super.key,
    required this.onDirectionStart,
    required this.onDirectionEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        children: [
          // Background circle
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
              border: Border.all(color: Colors.white12),
            ),
          ),

          // Center dot
          Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),

          // Up
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(
              child: _DPadButton(
                icon: Icons.keyboard_arrow_up,
                onStart: () => onDirectionStart(Direction.up),
                onEnd: onDirectionEnd,
              ),
            ),
          ),

          // Down
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(
              child: _DPadButton(
                icon: Icons.keyboard_arrow_down,
                onStart: () => onDirectionStart(Direction.down),
                onEnd: onDirectionEnd,
              ),
            ),
          ),

          // Left
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: _DPadButton(
                icon: Icons.keyboard_arrow_left,
                onStart: () => onDirectionStart(Direction.left),
                onEnd: onDirectionEnd,
              ),
            ),
          ),

          // Right
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: _DPadButton(
                icon: Icons.keyboard_arrow_right,
                onStart: () => onDirectionStart(Direction.right),
                onEnd: onDirectionEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DPadButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  const _DPadButton({
    required this.icon,
    required this.onStart,
    required this.onEnd,
  });

  @override
  State<_DPadButton> createState() => _DPadButtonState();
}

class _DPadButtonState extends State<_DPadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        widget.onStart();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onEnd();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        widget.onEnd();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _pressed ? Colors.white38 : Colors.white12,
            width: 1.5,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(widget.icon, color: Colors.white, size: 24),
      ),
    );
  }
}
