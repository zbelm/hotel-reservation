import 'package:flutter/material.dart';

import 'format.dart';
import 'theme.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
}

class ErrorNote extends StatelessWidget {
  const ErrorNote(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(message, style: const TextStyle(color: Palette.bad)),
      );
}

class Counter extends StatelessWidget {
  const Counter({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        IconButton.outlined(
            onPressed: value > min ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove), tooltip: 'Fewer $label'),
        SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))),
        IconButton.outlined(
            onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add), tooltip: 'More $label'),
      ]);
}

/// Calm placeholder picture for rooms without photos.
class RoomArt extends StatelessWidget {
  const RoomArt({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final hue = name.codeUnits.fold<int>(0, (a, c) => a + c) % 40;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, 168.0 + hue, 0.32, 0.34).toColor(),
            HSLColor.fromAHSL(1, 30.0 + hue, 0.45, 0.78).toColor(),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'held' => Palette.sun,
      'confirmed' => Palette.good,
      'checked_in' => Palette.sea,
      'cancelled' || 'no_show' => Palette.bad,
      _ => Palette.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(bookingStatusLabel[status] ?? status,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ]),
      );
}
