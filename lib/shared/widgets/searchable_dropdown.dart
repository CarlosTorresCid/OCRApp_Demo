import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Selector con búsqueda integrada como overlay bajo el campo.
/// El campo es de solo lectura; al pulsar se despliega una lista
/// con buscador sin abrir ningún popup ni modal.
class SearchableDropdown<T> extends StatefulWidget {
  const SearchableDropdown({
    super.key,
    required this.controller,
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.onSelected,
    required this.hintText,
    this.prefixIcon,
    this.fillColor = AppColors.surfaceCard,
    this.enabledBorderColor = AppColors.border,
    this.hasError = false,
    this.errorText,
    this.onTap,
  });

  final TextEditingController controller;
  final Future<List<T>> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, T) itemBuilder;
  final void Function(T) onSelected;
  final String hintText;
  final Widget? prefixIcon;
  final Color fillColor;
  final Color enabledBorderColor;
  final bool hasError;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  State<SearchableDropdown<T>> createState() =>
      _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _close() {
    _removeOverlay();

    if (!mounted) return;

    setState(() => _isOpen = false);
  }

  void _open() {
    widget.onTap?.call();
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: SearchDropdownPanel<T>(
                  width: size.width,
                  suggestionsCallback: widget.suggestionsCallback,
                  itemBuilder: widget.itemBuilder,
                  hintText: widget.hintText,
                  onSelected: (item) {
                    _close();
                    widget.onSelected(item);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }


  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) {
                final hasValue = value.text.isNotEmpty;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: widget.hasError
                        ? AppColors.errorLight
                        : widget.fillColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isOpen
                          ? AppColors.primary
                          : widget.hasError
                              ? AppColors.error
                              : widget.enabledBorderColor,
                      width: _isOpen ? 2 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (widget.prefixIcon != null) ...[
                        widget.prefixIcon!,
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          hasValue ? value.text : widget.hintText,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasValue
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: widget.hasError
                              ? AppColors.error
                              : _isOpen
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.hasError && widget.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                widget.errorText!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

class SearchDropdownPanel<T> extends StatefulWidget {
  const SearchDropdownPanel({
    super.key,
    required this.width,
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.hintText,
    required this.onSelected,
  });

  final double width;
  final Future<List<T>> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, T) itemBuilder;
  final String hintText;
  final void Function(T) onSelected;

  @override
  State<SearchDropdownPanel<T>> createState() => _SearchDropdownPanelState<T>();
}

class _SearchDropdownPanelState<T> extends State<SearchDropdownPanel<T>> {
  final _searchCtrl = TextEditingController();
  List<T> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final results = await widget.suggestionsCallback(q);
    if (mounted) setState(() { _items = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              onChanged: _search,
              decoration: InputDecoration(
                hintText: widget.hintText,
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                filled: true,
                fillColor: AppColors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
                minHeight: 2, color: AppColors.primary)
          else
            const Divider(height: 1),
          Flexible(
            child: _items.isEmpty && !_loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.search_off_rounded,
                          size: 14, color: AppColors.textMuted),
                      SizedBox(width: 6),
                      Text('Sin resultados',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted)),
                    ]),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => InkWell(
                      onTap: () => widget.onSelected(_items[i]),
                      child: widget.itemBuilder(ctx, _items[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Abre el panel de búsqueda directamente como diálogo (para uso en celdas
/// de grid donde no hay un campo fijo al que anclar el overlay).
Future<T?> showSearchPicker<T>({
  required BuildContext context,
  required Future<List<T>> Function(String) suggestionsCallback,
  required Widget Function(BuildContext, T) itemBuilder,
  required String hintText,
}) =>
    showDialog<T>(
      context: context,
      builder: (_) => _SearchPickerDialog<T>(
        suggestionsCallback: suggestionsCallback,
        itemBuilder: itemBuilder,
        hintText: hintText,
      ),
    );

class _SearchPickerDialog<T> extends StatefulWidget {
  const _SearchPickerDialog({
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.hintText,
  });

  final Future<List<T>> Function(String) suggestionsCallback;
  final Widget Function(BuildContext, T) itemBuilder;
  final String hintText;

  @override
  State<_SearchPickerDialog<T>> createState() =>
      _SearchPickerDialogState<T>();
}

class _SearchPickerDialogState<T>
    extends State<_SearchPickerDialog<T>> {
  final _searchCtrl = TextEditingController();
  List<T> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final results = await widget.suggestionsCallback(q);
    if (mounted) setState(() { _items = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 420, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 18),
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(
                  minHeight: 2, color: AppColors.primary)
            else
              const Divider(height: 1),
            Flexible(
              child: _items.isEmpty && !_loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding:
                          const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) => InkWell(
                        onTap: () =>
                            Navigator.of(context).pop(_items[i]),
                        child: widget.itemBuilder(ctx, _items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
