import 'package:flutter/material.dart';

import 'format.dart';
import 'i18n.dart';
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
      child: Text(statusLabel(status),
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

/// Five stars, filled to the nearest half.
class Stars extends StatelessWidget {
  const Stars(this.rating, {super.key, this.size = 18});
  final num rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = (rating * 2).round() / 2;
    return Semantics(
      label: tr('$r out of 5 stars', '$r sa 5 bituin'),
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            r >= i ? Icons.star_rounded : (r >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: Palette.mango,
          ),
      ]),
    );
  }
}

/// FIL / EN switch for app bars.
class LangButton extends StatelessWidget {
  const LangButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Only on the main tabs: screens opened on top wouldn't switch until reopened
    if (ModalRoute.of(context)?.isFirst == false) return const SizedBox.shrink();
    return TextButton(
        onPressed: () => setLang(isFil ? 'en' : 'fil'),
        child: Semantics(
          label: isFil ? 'Read in English' : 'Basahin sa Filipino',
          excludeSemantics: true,
          child: Text(isFil ? 'EN' : 'FIL', style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
        ),
      );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.top = 28});
  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 10),
        child: Text(text, style: displayStyle(context, 22)),
      );
}

/// A tinted message box: good news, a warning, or an error.
class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.color = Palette.sea});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: color)),
      );
}
