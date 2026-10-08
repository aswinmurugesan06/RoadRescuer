import 'package:flutter/material.dart';

class RRTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final int maxLines;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final void Function(String)? onFieldSubmitted;
  final String? initialValue;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  const RRTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.onFieldSubmitted,
    this.initialValue,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<RRTextField> createState() => _RRTextFieldState();
}

class _RRTextFieldState extends State<RRTextField> {
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      obscureText: _obscured,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      onFieldSubmitted: widget.onFieldSubmitted,
      initialValue: widget.initialValue,
      maxLength: widget.maxLength,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20)
            : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(
                  _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : widget.suffix,
        counterText: '',
      ),
    );
  }
}

// ── Dropdown Field ────────────────────────────────────────────────────
class RRDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;
  final IconData? prefixIcon;
  final bool enabled;

  const RRDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
    );
  }
}
