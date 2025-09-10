import 'package:flutter/material.dart';

/// Универсальная кнопка "?" для показа подсказки.
/// Использование: в AppBar.actions: [HelpButton(title: '...', text: '...')]
class HelpButton extends StatelessWidget {
  final String title;
  final String text;

  const HelpButton({super.key, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Подсказка',
      icon: const Icon(Icons.help_outline),
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
      },
    );
  }
}
