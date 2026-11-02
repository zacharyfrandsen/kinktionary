import 'package:flutter/material.dart';

import '../instant_route.dart';
import '../data_store.dart';
import '../screens/consent_screen.dart';
import 'pattern_background.dart';

/// Search field shared by the Feed and Glossary, with the safety shortcut beside it.
class SearchRow extends StatelessWidget {
  final DataStore store;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool showSafety;

  const SearchRow({
    super.key,
    required this.store,
    required this.hintText,
    required this.controller,
    required this.onChanged,
    this.showSafety = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, showSafety ? 8 : 16, 8),
      child: Row(
        children: [
          Expanded(
            child: SearchBar(
              controller: controller,
              hintText: hintText,
              leading: const Icon(Icons.search),
              trailing: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
          if (showSafety)
            IconButton(
              tooltip: 'Safety & consent',
              onPressed: () => Navigator.of(context).push(
                instantRoute(PatternScaffold(
                    appBar: AppBar(title: const Text('Safety & consent')),
                    body: ConsentScreen(store: store),
                  )),
              ),
              icon: const Icon(Icons.verified_user_outlined),
            ),
        ],
      ),
    );
  }
}
