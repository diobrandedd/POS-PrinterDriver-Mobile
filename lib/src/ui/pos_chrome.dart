import 'package:flutter/material.dart';
import 'package:thermal_print/src/theme/pos_theme.dart';

class PosPage extends StatelessWidget {
  const PosPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: padding,
            children: [child],
          ),
        ),
        if (bottom != null) bottom!,
      ],
    );
  }
}

class PosScrollPage extends StatelessWidget {
  const PosScrollPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: padding,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

class StaffChip extends StatelessWidget {
  const StaffChip({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PosColors.forestSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined, size: 16, color: PosColors.forest),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: PosColors.forestDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PosSection extends StatelessWidget {
  const PosSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class PosPanel extends StatelessWidget {
  const PosPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A14201C),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class PosErrorBanner extends StatelessWidget {
  const PosErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8C4BF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: PosColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: PosColors.danger,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PosEmptyHint extends StatelessWidget {
  const PosEmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PosPanel(
      child: Column(
        children: [
          Icon(icon, size: 28, color: PosColors.forest),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(body, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style, this.strike = false});

  final double amount;
  final TextStyle? style;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final text = '₱${amount.toStringAsFixed(2)}';
    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: strike ? TextDecoration.lineThrough : null,
      ),
    );
  }
}

class CheckoutBar extends StatelessWidget {
  const CheckoutBar({
    super.key,
    required this.subtotal,
    required this.enabled,
    required this.busy,
    required this.onFull,
    required this.onTen,
    required this.onTwenty,
  });

  final double subtotal;
  final bool enabled;
  final bool busy;
  final VoidCallback onFull;
  final VoidCallback onTen;
  final VoidCallback onTwenty;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: const Color(0x2214201C),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Subtotal', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  MoneyText(subtotal, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: enabled && !busy ? onFull : null,
                style: FilledButton.styleFrom(backgroundColor: PosColors.gold, foregroundColor: Colors.white),
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Pay full · ₱${subtotal.toStringAsFixed(2)}'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: enabled && !busy ? onTen : null,
                      child: Text('10% · ₱${(subtotal * 0.9).toStringAsFixed(2)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: enabled && !busy ? onTwenty : null,
                      child: Text('20% · ₱${(subtotal * 0.8).toStringAsFixed(2)}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> promptProductCode(BuildContext context, {String title = 'Add product'}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Barcode / SKU',
            hintText: 'Scan or type code',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (result == null || result.isEmpty) return null;
  return result;
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? PosColors.forest : PosColors.muted;
    final bg = ok ? PosColors.forestSoft : const Color(0xFFEEF1EF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle : Icons.circle_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
