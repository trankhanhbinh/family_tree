import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Thẻ nhóm ô nhập: tiêu đề chữ lớn + các ô bên dưới.
class FormCard extends StatelessWidget {
  const FormCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

/// Ô nhập chữ, cỡ chữ 18.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.maxLength = 200,
    this.minLines = 1,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.sentences,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final TextCapitalization capitalization;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 18),
        minLines: minLines,
        maxLines: maxLines,
        keyboardType:
            maxLines > 1 ? TextInputType.multiline : TextInputType.text,
        textCapitalization: capitalization,
        inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 16),
          errorText: errorText,
          errorStyle: const TextStyle(fontSize: 16),
          errorMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => onChanged?.call(),
      ),
    );
  }
}

/// Ô nhập số (chỉ cho gõ chữ số).
class AppNumberField extends StatelessWidget {
  const AppNumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.maxDigits,
    this.hasError = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final int maxDigits;
  final bool hasError;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 20),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxDigits),
      ],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 16),
        border: const OutlineInputBorder(),
        enabledBorder: hasError
            ? OutlineInputBorder(
                borderSide: BorderSide(color: errorColor, width: 2),
              )
            : null,
      ),
      onChanged: (_) => onChanged?.call(),
    );
  }
}

/// Bộ ba ô Ngày / Tháng / Năm + dòng lỗi.
class DateFieldsRow extends StatelessWidget {
  const DateFieldsRow({
    super.key,
    required this.day,
    required this.month,
    required this.year,
    this.error,
    this.onChanged,
  });

  final TextEditingController day;
  final TextEditingController month;
  final TextEditingController year;
  final String? error;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppNumberField(
                  controller: day,
                  label: 'Ngày',
                  maxDigits: 2,
                  hasError: hasError,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppNumberField(
                  controller: month,
                  label: 'Tháng',
                  maxDigits: 2,
                  hasError: hasError,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: AppNumberField(
                  controller: year,
                  label: 'Năm',
                  maxDigits: 4,
                  hasError: hasError,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          if (error != null) ErrorText(error!),
        ],
      ),
    );
  }
}

/// Dãy nút ngang cho lựa chọn NGẮN (ví dụ Nam / Nữ / Khác).
/// selected = null nghĩa là chưa chọn.
class BigSegmented<T> extends StatelessWidget {
  const BigSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final Set<T> current = {?selected};
    return SegmentedButton<T>(
      showSelectedIcon: false,
      emptySelectionAllowed: true,
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 56),
        textStyle: const TextStyle(fontSize: 18),
      ),
      segments: [
        for (final option in options)
          ButtonSegment<T>(value: option.$1, label: Text(option.$2)),
      ],
      selected: current,
      onSelectionChanged: (values) {
        if (values.isNotEmpty) {
          onChanged(values.first);
        }
      },
    );
  }
}

/// Danh sách nút to xếp dọc cho lựa chọn DÀI (mỗi lựa chọn một nút cao 56).
class BigChoiceList<T> extends StatelessWidget {
  const BigChoiceList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: selected == option.$1
                  ? FilledButton.icon(
                      onPressed: () => onChanged(option.$1),
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: Text(
                        option.$2,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: () => onChanged(option.$1),
                      child: Text(
                        option.$2,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}