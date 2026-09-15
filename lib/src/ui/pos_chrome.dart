import 'package:flutter/material.dart';
import 'package:thermal_print/src/theme/pos_theme.dart';

class PosScrollPage extends StatelessWidget {
  const PosScrollPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 28),
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
                    const SizedBox(height: 2),
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

class PosWorkbenchHeader extends StatelessWidget {
  const PosWorkbenchHeader({
    super.key,
    required this.title,
    required this.staffName,
    this.printerConnected = false,
    this.printerLabel,
  });

  final String title;
  final String staffName;
  final bool printerConnected;
  final String? printerLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(staffName, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          StatusPill(
            label: printerConnected
                ? (printerLabel?.isNotEmpty == true ? 'Printer' : 'Printer on')
                : 'No printer',
            ok: printerConnected,
          ),
        ],
      ),
    );
  }
}

class StaffChip extends StatelessWidget {
  const StaffChip({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PosColors.forestSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.badge_outlined, size: 15, color: PosColors.forest),
          const SizedBox(width: 6),
          Flexible(
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
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class PosPanel extends StatelessWidget {
  const PosPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line),
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
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PosColors.dangerSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFECACA)),
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
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: PosColors.mutedFill,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 26, color: PosColors.forest),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(body, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class ScanHeroButton extends StatelessWidget {
  const ScanHeroButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.label = 'Scan / add product',
  });

  final VoidCallback? onPressed;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: PosColors.forest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: enabled ? PosColors.forest : PosColors.line,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, color: enabled ? Colors.white : PosColors.muted),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: enabled ? Colors.white : PosColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return Text(
      '₱${amount.toStringAsFixed(2)}',
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: strike ? TextDecoration.lineThrough : null,
      ),
    );
  }
}

class QtyIconButton extends StatelessWidget {
  const QtyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: PosColors.mutedFill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: PosColors.ink),
          ),
        ),
      ),
    );
  }
}

class CartLineRow extends StatelessWidget {
  const CartLineRow({
    super.key,
    required this.title,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
    required this.onRemove,
    this.qtyEditable = false,
    this.onDec,
    this.onInc,
  });

  final String title;
  final double unitPrice;
  final int qty;
  final double lineTotal;
  final VoidCallback onRemove;
  final bool qtyEditable;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  '₱${unitPrice.toStringAsFixed(2)} each',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (qtyEditable && onDec != null && onInc != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      QtyIconButton(
                        icon: Icons.remove,
                        onPressed: onDec!,
                        semanticLabel: 'Decrease quantity',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      QtyIconButton(
                        icon: Icons.add,
                        onPressed: onInc!,
                        semanticLabel: 'Increase quantity',
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text('Qty $qty', style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(lineTotal, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Semantics(
                button: true,
                label: 'Remove $title',
                child: IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
        ],
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
    this.itemCount = 0,
  });

  final double subtotal;
  final bool enabled;
  final bool busy;
  final VoidCallback onFull;
  final VoidCallback onTen;
  final VoidCallback onTwenty;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      shadowColor: const Color(0x220F172A),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    itemCount > 0 ? '$itemCount item${itemCount == 1 ? '' : 's'}' : 'Cart',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  MoneyText(subtotal, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: enabled && !busy ? onFull : null,
                style: FilledButton.styleFrom(
                  backgroundColor: PosColors.charge,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: PosColors.line,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(
                        'Charge ₱${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
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

Future<String?> promptProductCode(BuildContext context, {String title = 'Scan product'}) async {
  final controller = TextEditingController();
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Point the scanner or type the barcode, then tap Add.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Barcode / SKU',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final color = ok ? PosColors.chargeDeep : PosColors.muted;
    final bg = ok ? const Color(0xFFD1FAE5) : PosColors.mutedFill;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.print : Icons.print_disabled_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
