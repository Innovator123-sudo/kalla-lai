import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kalla_lai/core/theme/kalla_lai_theme.dart';
import 'package:kalla_lai/features/auth/application/entry_journey_cubit.dart';
import 'package:kalla_lai/features/settings/presentation/settings_screen.dart';

/// First choice after the intro video: work or hire.
///
/// Deliberately one question with two large tap targets, so the next screen is
/// always predictable even on a small phone.
class IntentSelectionScreen extends StatefulWidget {
  const IntentSelectionScreen({super.key});

  @override
  State<IntentSelectionScreen> createState() => _IntentSelectionScreenState();
}

class _IntentSelectionScreenState extends State<IntentSelectionScreen> {
  EntryIntent? _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<EntryJourneyCubit>().state.intent;
  }

  void _continue() {
    final intent = _selected;
    if (intent == null) return;
    context.read<EntryJourneyCubit>().chooseIntent(intent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'settings_intent',
        tooltip: 'Settings',
        onPressed: () => openSettings(context),
        child: const Icon(Icons.settings_outlined),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/kalla_lai_logo.png',
                    height: 88,
                    fit: BoxFit.contain,
                    semanticLabel: 'कल्ला-लाई',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'How do you want to start?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick the path that fits you today. You can switch later.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.72),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _IntentCard(
                    intent: EntryIntent.worker,
                    icon: Icons.engineering_outlined,
                    selected: _selected == EntryIntent.worker,
                    onTap: () => setState(() => _selected = EntryIntent.worker),
                  ),
                  const SizedBox(height: 12),
                  _IntentCard(
                    intent: EntryIntent.employer,
                    icon: Icons.business_center_outlined,
                    selected: _selected == EntryIntent.employer,
                    onTap:
                        () => setState(() => _selected = EntryIntent.employer),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _selected == null ? null : _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      _selected?.continueLabel ?? 'Choose one to continue',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.intent,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final EntryIntent intent;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? KallaLaiColors.indigo : KallaLaiColors.outline;
    return Semantics(
      button: true,
      selected: selected,
      label: intent.title,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KallaLaiRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KallaLaiRadii.lg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KallaLaiRadii.lg),
              border: Border.all(color: border, width: selected ? 2 : 1),
              color:
                  selected
                      ? KallaLaiColors.indigo.withValues(alpha: 0.04)
                      : Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: KallaLaiColors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: KallaLaiColors.indigo, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        intent.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        intent.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: KallaLaiColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color:
                      selected
                          ? KallaLaiColors.indigo
                          : const Color(0xFFCBD5E1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
