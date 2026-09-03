import 'package:flutter/material.dart';

/// כרטיס אחיד להצגת קבוצת הגדרות עם כותרת ואייקון, בשימוש במסכי ההגדרות.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SectionCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
