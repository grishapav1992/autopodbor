import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'data.dart';
import 'models.dart';
import 'utils.dart';

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.required = false,
  });

  final String label;
  final Widget child;
  final String? hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: uiTokens.gray900,
            ),
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: uiTokens.red600),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null && hint!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hint!,
              style: TextStyle(fontSize: 12, color: uiTokens.gray600),
            ),
          ),
      ],
    );
  }
}

class AppInput extends StatelessWidget {
  const AppInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.keyboardType,
    this.onFocus,
    this.onBlur,
    this.enabled = true,
    this.focusNode,
    this.obscureText = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final TextInputType? keyboardType;
  final VoidCallback? onFocus;
  final VoidCallback? onBlur;
  final bool enabled;
  final FocusNode? focusNode;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value);
    controller.selection = TextSelection.collapsed(offset: value.length);
    return Focus(
      onFocusChange: (f) => f ? onFocus?.call() : onBlur?.call(),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        enabled: enabled,
        focusNode: focusNode,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: placeholder,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: uiTokens.gray300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: uiTokens.gray300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: uiTokens.gray300),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: uiTokens.gray300),
          ),
        ),
      ),
    );
  }
}

class AppTextarea extends StatelessWidget {
  const AppTextarea({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.rows = 3,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value);
    controller.selection = TextSelection.collapsed(offset: value.length);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: rows,
      maxLines: 8,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: placeholder,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: uiTokens.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: uiTokens.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: uiTokens.gray300),
        ),
      ),
    );
  }
}

class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  final T? value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : null;
    return DropdownButtonFormField<T>(
      value: safeValue,
      items: items
          .map((e) => DropdownMenuItem<T>(value: e, child: Text(label(e))))
          .toList(),
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: uiTokens.gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: uiTokens.gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: uiTokens.gray300),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: uiTokens.gray300),
        ),
      ),
    );
  }
}

enum ButtonVariant { primary, secondary, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = ButtonVariant.primary,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final ButtonVariant variant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    Color bg;
    Color fg;
    Color border;
    if (variant == ButtonVariant.primary) {
      bg = uiTokens.gray900;
      fg = Colors.white;
      border = uiTokens.gray900;
    } else if (variant == ButtonVariant.danger) {
      bg = uiTokens.red100;
      fg = const Color(0xFF991B1B);
      border = uiTokens.red200;
    } else {
      bg = Colors.white;
      fg = uiTokens.gray900;
      border = uiTokens.gray300;
    }

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: uiTokens.gray300),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor[status] ?? uiTokens.gray900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        statusLabel[status] ?? '',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
  });

  final int step;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: uiTokens.gray900,
          ),
        ),
        const Spacer(),
        Text(
          'Шаг $step / $total',
          style: TextStyle(fontSize: 12, color: uiTokens.gray600),
        ),
      ],
    );
  }
}

class PreviewKV extends StatelessWidget {
  const PreviewKV({
    super.key,
    required this.k,
    required this.v,
    this.stacked = false,
  });

  final String k;
  final String v;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    if (stacked) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: uiTokens.gray300, style: BorderStyle.solid),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k, style: TextStyle(fontSize: 12, color: uiTokens.gray600)),
            const SizedBox(height: 2),
            Text(
              v,
              style: TextStyle(fontSize: 13, color: uiTokens.gray900),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child:
                Text(k, style: TextStyle(fontSize: 13, color: uiTokens.gray600)),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(fontSize: 13, color: uiTokens.gray900),
            ),
          ),
        ],
      ),
    );
  }
}

class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.footer,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x730F172A)),
            ),
          ),
        ),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: uiTokens.gray300),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E0F172A),
                  blurRadius: 60,
                  offset: Offset(0, 25),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: uiTokens.gray900,
                      ),
                    ),
                    const Spacer(),
                    AppButton(
                      label: '???????',
                      variant: ButtonVariant.secondary,
                      onTap: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 13,
                    color: uiTokens.gray900,
                    height: 1.5,
                  ),
                  child: child,
                ),
                if (footer != null) ...[
                  const SizedBox(height: 12),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AppDrawerRight extends StatelessWidget {
  const AppDrawerRight({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    required this.isSmall,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x590F172A)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: isSmall ? MediaQuery.of(context).size.width : 420,
            height: MediaQuery.of(context).size.height,
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: uiTokens.gray900,
                      ),
                    ),
                    const Spacer(),
                    AppButton(
                      label: 'Закрыть',
                      variant: ButtonVariant.secondary,
                      onTap: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(child: child),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Stars extends StatelessWidget {
  const Stars({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final full = value.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Text(
          '★',
          style: TextStyle(
            fontSize: 14,
            color: i < full ? uiTokens.gray900 : const Color(0xFFCBD5E1),
          ),
        );
      }),
    );
  }
}

class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: uiTokens.gray300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: uiTokens.gray600)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: uiTokens.gray900,
            ),
          ),
        ],
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.onRemove,
    this.maxWidth,
  });

  final String label;
  final VoidCallback? onRemove;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: uiTokens.gray300),
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? 220),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: uiTokens.gray900,
              ),
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onRemove,
              child: Text(
                '×',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: uiTokens.gray600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MultiSelectPicker extends StatelessWidget {
  const MultiSelectPicker({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChange,
    this.hint,
    this.disabled = false,
  });

  final String label;
  final List<String> value;
  final List<String> options;
  final ValueChanged<List<String>> onChange;
  final String? hint;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: uiTokens.gray900,
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Выбрать',
                variant: ButtonVariant.secondary,
                onTap: disabled
                    ? null
                    : () async {
                        final next = await showDialog<List<String>>(
                          context: context,
                          barrierColor: const Color(0x730F172A),
                          builder: (_) => _MultiSelectDialog(
                            title: label,
                            options: options,
                            initial: value,
                          ),
                        );
                        if (next != null) onChange(next);
                      },
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasValue)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...value.take(12).map(
                      (x) => AppChip(
                        label: x,
                        onRemove: disabled
                            ? null
                            : () =>
                                onChange(value.where((v) => v != x).toList()),
                      ),
                    ),
                if (value.length > 12)
                  Text(
                    '+${value.length - 12}',
                    style: TextStyle(fontSize: 12, color: uiTokens.gray600),
                  ),
              ],
            )
          else if (hint != null && hint!.isNotEmpty)
            Text(
              hint!,
              style: TextStyle(fontSize: 12, color: uiTokens.gray600),
            ),
          if (hasValue && hint != null && hint!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(hint!, style: TextStyle(fontSize: 12, color: uiTokens.gray600)),
          ],
        ],
      ),
    );
  }
}

class FilterMultiSelect extends StatefulWidget {
  const FilterMultiSelect({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChange,
    this.searchAliases = const {},
    this.maxVisibleItems = 10,
    this.maxSelection,
    this.placeholder,
    this.disabled = false,
    this.closeOnSelect = false,
    this.requireApply = true,
  });

  final String label;
  final List<String> options;
  final List<String> value;
  final ValueChanged<List<String>> onChange;
  final Map<String, String> searchAliases;
  final int maxVisibleItems;
  final int? maxSelection;
  final String? placeholder;
  final bool disabled;
  final bool closeOnSelect;
  final bool requireApply;

  @override
  State<FilterMultiSelect> createState() => _FilterMultiSelectState();
}

class _FilterMultiSelectState extends State<FilterMultiSelect> {
  String _q = '';
  bool _open = false;
  final FocusNode _focusNode = FocusNode();
  List<String> _draft = [];

  @override
  void didUpdateWidget(covariant FilterMultiSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.value, widget.value) && !_open) {
      _draft = [...widget.value];
    }
  }

  @override
  void initState() {
    super.initState();
    _draft = [...widget.value];
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _q.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.options
        : widget.options.where((opt) {
            if (opt.toLowerCase().contains(query)) return true;
            final alias = widget.searchAliases[opt];
            return alias != null && alias.toLowerCase().contains(query);
          }).toList();

    final visibleCount =
        min(widget.maxVisibleItems, max(1, filtered.length));
    final listHeight = visibleCount * 44.0;

    return Opacity(
      opacity: widget.disabled ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: uiTokens.gray900,
            ),
          ),
          const SizedBox(height: 8),
          AppInput(
            value: _q,
            placeholder: widget.placeholder ?? 'Введите название',
            enabled: !widget.disabled,
            onChanged: (v) => setState(() => _q = v),
            focusNode: _focusNode,
            onFocus: () => setState(() => _open = true),
            onBlur: () {},
          ),
          const SizedBox(height: 8),
          if (_open)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: uiTokens.gray300),
              ),
              child: SizedBox(
                height: listHeight,
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final opt = filtered[i];
                    final checked = _draft.contains(opt);
                    void applyChange() {
                      final next = [..._draft];
                      if (checked) {
                        next.remove(opt);
                      } else {
                        if (widget.maxSelection != null &&
                            next.length >= widget.maxSelection!) {
                          if (widget.maxSelection == 1) {
                            next
                              ..clear()
                              ..add(opt);
                          } else {
                            return;
                          }
                        } else {
                          next.add(opt);
                        }
                      }
                      _draft = next;
                      if (!widget.requireApply) {
                        widget.onChange(next);
                      }
                      if (widget.closeOnSelect) {
                        _focusNode.unfocus();
                        setState(() => _open = false);
                      } else {
                        _focusNode.requestFocus();
                        setState(() => _open = true);
                      }
                    }

                    return InkWell(
                      onTap: widget.disabled ? null : applyChange,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: checked,
                              onChanged: widget.disabled ? null : (_) => applyChange(),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Expanded(
                              child: Text(
                                opt,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: uiTokens.gray900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_open && widget.requireApply)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Применить',
                    onTap: widget.disabled
                        ? null
                        : () {
                            widget.onChange([..._draft]);
                            _focusNode.unfocus();
                            setState(() => _open = false);
                          },
                  ),
                ],
              ),
            ),
          if (widget.value.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.value
                  .map(
                    (x) => AppChip(
                      label: x,
                      onRemove: widget.disabled
                          ? null
                          : () => widget.onChange(
                                widget.value.where((v) => v != x).toList(),
                              ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.initial,
  });

  final String title;
  final List<String> options;
  final List<String> initial;

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late List<String> selected;
  String q = '';

  @override
  void initState() {
    super.initState();
    selected = [...widget.initial];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = q.trim().isEmpty
        ? widget.options
        : widget.options
            .where((x) => x.toLowerCase().contains(q.toLowerCase()))
            .toList();

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: uiTokens.gray300),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E0F172A),
              blurRadius: 60,
              offset: Offset(0, 25),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: uiTokens.gray900,
                  ),
                ),
                const Spacer(),
                AppButton(
                  label: 'Закрыть',
                  variant: ButtonVariant.secondary,
                  onTap: () => Navigator.of(context).pop(selected),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AppInput(
              value: q,
              placeholder: 'Начните вводить…',
              onChanged: (v) => setState(() => q = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 280,
              child: ListView.builder(
                itemCount: min(filtered.length, 120),
                itemBuilder: (_, i) {
                  final opt = filtered[i];
                  final checked = selected.contains(opt);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (checked) {
                          selected.remove(opt);
                        } else {
                          selected.add(opt);
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: checked ? uiTokens.gray900 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: uiTokens.gray300),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: checked,
                            onChanged: (_) {
                              setState(() {
                                if (checked) {
                                  selected.remove(opt);
                                } else {
                                  selected.add(opt);
                                }
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Expanded(
                            child: Text(
                              opt,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color:
                                    checked ? Colors.white : uiTokens.gray900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (filtered.length > 120)
              Text(
                'Показано 120 из списка. Уточните запрос.',
                style: TextStyle(fontSize: 12, color: uiTokens.gray600),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: 'Очистить',
                  variant: ButtonVariant.secondary,
                  onTap: () => setState(() => selected.clear()),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Применить',
                  onTap: () => Navigator.of(context).pop(selected),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AvitoDropdownSelect extends StatefulWidget {
  const AvitoDropdownSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChange,
    this.placeholder = 'Введите название',
    this.hint,
    this.disabled = false,
    this.mode = AvitoSelectMode.multi,
    this.withCountryFilter = false,
    this.onSearchChanged,
    this.onOpen,
    this.searchAliases = const {},
  });

  final String label;
  final List<String> value;
  final List<String> options;
  final ValueChanged<List<String>> onChange;
  final String placeholder;
  final String? hint;
  final bool disabled;
  final AvitoSelectMode mode;
  final bool withCountryFilter;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onOpen;
  final Map<String, String> searchAliases;

  @override
  State<AvitoDropdownSelect> createState() => _AvitoDropdownSelectState();
}

enum AvitoSelectMode { single, multi }

class _AvitoDropdownSelectState extends State<AvitoDropdownSelect> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;

  bool _open = false;
  String _q = '';
  bool _showAll = false;
  bool _showAllCountries = false;
  List<String> _country = [];

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  bool get _useOverlay => widget.mode == AvitoSelectMode.single;

  @override
  void didUpdateWidget(covariant AvitoDropdownSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No immediate refresh here to avoid markNeedsBuild during build.
  }

  void _openOverlay() {
    if (widget.disabled) return;
    if (!_useOverlay) {
      if (!_open) {
        setState(() => _open = true);
        widget.onOpen?.call();
      }
      return;
    }
    if (_open) return;
    _open = true;
    _overlay = _createOverlay();
    Overlay.of(context).insert(_overlay!);
    widget.onOpen?.call();
    setState(() {});
  }

  void _closeOverlay() {
    if (!_open) return;
    _open = false;
    _q = '';
    _showAll = false;
    if (_useOverlay) _removeOverlay();
    setState(() {});
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  OverlayEntry _createOverlay() {
    final canDismiss = _useOverlay;
    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !canDismiss,
                child: GestureDetector(
                  onTap: canDismiss ? _closeOverlay : null,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.transparent),
                  ),
                ),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              offset: const Offset(0, 54),
              showWhenUnlinked: true,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: uiTokens.gray300),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F0F172A),
                        blurRadius: 50,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: _buildDropdownBody(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> _effectiveOptions() {
    if (!widget.withCountryFilter || _country.isEmpty) return widget.options;
    final selected = _country.toSet();
    return widget.options
        .where((mk) => selected.contains(getMakeCountry(mk)))
        .toList();
  }

  List<String> _filteredOptions() {
    final base = _effectiveOptions();
    if (_q.trim().isEmpty) return base;
    final query = _q.toLowerCase();
    return base.where((opt) {
      if (opt.toLowerCase().contains(query)) return true;
      final alias = widget.searchAliases[opt];
      return alias != null && alias.toLowerCase().contains(query);
    }).toList();
  }

  void _refreshOverlay() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_useOverlay) {
        _overlay?.markNeedsBuild();
      } else {
        setState(() {});
      }
    });
  }

  void _toggle(String opt) {
    if (widget.disabled) return;
    if (widget.mode == AvitoSelectMode.single) {
      widget.onChange(opt.isNotEmpty ? [opt] : []);
      _closeOverlay();
      return;
    }
    final checked = widget.value.contains(opt);
    if (checked) {
      widget.onChange(widget.value.where((x) => x != opt).toList());
    } else {
      widget.onChange([...widget.value, opt]);
    }
    _refreshOverlay();
  }

  Widget _buildDropdownBody() {
    final filtered = _filteredOptions();
    const initialLimit = 4;
    const itemHeight = 52.0;
    const itemGap = 6.0;
    final listToRender = () {
      if (_q.trim().isNotEmpty) return filtered;
      if (_showAll) return _effectiveOptions();
      return _effectiveOptions().take(initialLimit).toList();
    }();
    final listHeight = listToRender.isEmpty
        ? itemHeight
        : listToRender.length * (itemHeight + itemGap) - itemGap;
    final maxHeight = (_showAll || _q.trim().isNotEmpty) ? 220.0 : listHeight;

    final countryMain = [
      {'label': 'Отечественные', 'children': <String>[]},
      {
        'label': 'Иномарки',
        'children': <String>['Китай', 'Корея', 'Япония']
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.withCountryFilter) ...[
          Text(
            'Страна бренда',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: uiTokens.gray900,
            ),
          ),
          const SizedBox(height: 8),
          ...countryMain.map((row) {
            final label = row['label'] as String;
            final children = row['children'] as List<String>;
            final checked = _country.contains(label);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dropdownCheckbox(
                    label: label,
                    checked: checked,
                    onTap: () {
                      if (widget.disabled) return;
                      setState(() {
                        if (checked) {
                          _country.remove(label);
                        } else {
                          _country.add(label);
                        }
                      });
                      _refreshOverlay();
                    },
                  ),
                  if (children.isNotEmpty && (checked || _showAllCountries))
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 6),
                      child: Column(
                        children: children.map((ch) {
                          final chChecked = _country.contains(ch);
                          return _dropdownCheckbox(
                            label: ch,
                            checked: chChecked,
                            onTap: () {
                              if (widget.disabled) return;
                              setState(() {
                                if (chChecked) {
                                  _country.remove(ch);
                                } else {
                                  _country.add(ch);
                                }
                              });
                              _refreshOverlay();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            );
          }),
          InkWell(
            onTap: () {
              setState(() => _showAllCountries = !_showAllCountries);
              _refreshOverlay();
            },
            child: Text(
              _showAllCountries ? 'Свернуть' : 'Показать ещё',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: uiTokens.blue600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 6,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: uiTokens.gray300)),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: min(maxHeight, listHeight),
          child: SingleChildScrollView(
            child: Column(
              children: listToRender.take(250).map((opt) {
                final checked = widget.value.contains(opt);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: itemGap),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: uiTokens.gray300),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: checked,
                        onChanged: (_) => _toggle(opt),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _toggle(opt),
                          child: Text(
                            opt,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: uiTokens.gray900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (listToRender.length > 250)
          Text(
            'Показано 250 из ${listToRender.length}. Уточните запрос.',
            style: TextStyle(fontSize: 12, color: uiTokens.gray600),
          ),
        if (_q.trim().isEmpty && _effectiveOptions().length > initialLimit)
          InkWell(
            onTap: () {
              setState(() => _showAll = !_showAll);
              _refreshOverlay();
            },
            child: Text(
              _showAll ? 'Свернуть' : 'Показать ещё',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: uiTokens.blue600,
              ),
            ),
          ),
        if (widget.mode == AvitoSelectMode.multi)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.value.isNotEmpty)
                AppButton(
                  label: 'Очистить',
                  variant: ButtonVariant.secondary,
                  onTap: widget.disabled ? null : () => widget.onChange([]),
                ),
              const SizedBox(width: 10),
              AppButton(
                label: 'Готово',
                variant: ButtonVariant.secondary,
                onTap: _closeOverlay,
              ),
            ],
          ),
      ],
    );
  }

  Widget _dropdownCheckbox({
    required String label,
    required bool checked,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: (_) => onTap(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: uiTokens.gray900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.disabled ? 0.6 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: uiTokens.gray900,
            ),
          ),
          const SizedBox(height: 8),
          CompositedTransformTarget(
            link: _link,
            child: AppInput(
              value: _q,
              placeholder: widget.placeholder,
              enabled: !widget.disabled,
              onChanged: (v) {
                _q = v;
                if (!_open) _openOverlay();
                if (_open) _refreshOverlay();
                widget.onSearchChanged?.call(_q);
              },
              onFocus: _openOverlay,
              onBlur: () {},
            ),
          ),
          if (!_useOverlay && _open)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: uiTokens.gray300),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F0F172A),
                      blurRadius: 50,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: _buildDropdownBody(),
              ),
            ),
          if (widget.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...widget.value.take(12).map(
                        (x) => AppChip(
                          label: x,
                          onRemove: widget.disabled
                              ? null
                              : () {
                                  _toggle(x);
                                },
                        ),
                      ),
                  if (widget.value.length > 12)
                    Text(
                      '+${widget.value.length - 12}',
                      style: TextStyle(fontSize: 12, color: uiTokens.gray600),
                    ),
                ],
              ),
            ),
          if (widget.hint != null && widget.hint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.hint!,
                style: TextStyle(fontSize: 12, color: uiTokens.gray600),
              ),
            ),
        ],
      ),
    );
  }
}
