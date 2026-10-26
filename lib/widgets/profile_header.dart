import 'package:flutter/material.dart';

import '../models.dart';

/// Banner, avatar and identity for a profile, using the owner's chosen colours.
class ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final String displayName;
  final String handle;
  final String? photoUrl;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.displayName,
    required this.handle,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent =
        profile.accent == null ? scheme.primary : Color(profile.accent!);
    final start = profile.bannerStart == null
        ? scheme.primaryContainer
        : Color(profile.bannerStart!);
    final end = profile.bannerEnd == null
        ? scheme.secondaryContainer
        : Color(profile.bannerEnd!);

    final ink = Color.lerp(start, end, 0.5)!.computeLuminance() > 0.45
        ? const Color(0xFF1A1020)
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [start, end],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: accent),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: scheme.secondaryContainer,
                      backgroundImage:
                          photoUrl == null ? null : NetworkImage(photoUrl!),
                      child: photoUrl == null
                          ? Icon(Icons.person_outline,
                              size: 42, color: scheme.onSecondaryContainer)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                              color: ink, fontWeight: FontWeight.bold),
                        ),
                        if (handle.isNotEmpty)
                          Text('@$handle',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: ink.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.pronouns.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  profile.pronouns,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: ink, fontWeight: FontWeight.w600),
                ),
              ],
              if (profile.status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '\u201C${profile.status}\u201D',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic, color: ink),
                ),
              ],
              if (profile.location.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: ink),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(profile.location,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: ink)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (profile.interests.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final interest in profile.interests)
                Chip(
                  label: Text(interest),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: accent.withValues(alpha: 0.6)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class ProfileAbout extends StatelessWidget {
  final UserProfile profile;
  const ProfileAbout({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(profile.bio.isEmpty ? 'No bio yet.' : profile.bio),
          ],
        ),
      ),
    );
  }
}

/// One tappable count inside a [StatGrid].
class StatTile extends StatelessWidget {
  final String label;
  final int? value;

  /// Live count; overrides [value] once it emits.
  final Stream<int>? stream;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.label,
    this.value,
    this.stream,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stream == null) return _body(context, value);
    return StreamBuilder<int>(
      stream: stream,
      initialData: value,
      builder: (context, snapshot) => _body(context, snapshot.data),
    );
  }

  Widget _body(BuildContext context, int? count) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: icon == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(count == null ? '–' : '$count',
                      style: theme.textTheme.titleMedium),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 6),
                  Text(count == null ? '–' : '$count',
                      style: theme.textTheme.titleSmall),
                ],
              ),
      ),
    );
  }
}

/// Compact single card holding rows of stat tiles with thin dividers.
class StatGrid extends StatelessWidget {
  final List<List<StatTile>> rows;
  const StatGrid({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final row in rows) {
      if (children.isNotEmpty) children.add(const Divider(height: 1));
      children.add(IntrinsicHeight(
        child: Row(
          children: [
            for (var j = 0; j < row.length; j++) ...[
              if (j > 0) const VerticalDivider(width: 1),
              Expanded(child: row[j]),
            ],
          ],
        ),
      ));
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
