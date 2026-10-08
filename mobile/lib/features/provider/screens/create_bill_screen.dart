import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../services/billing_service.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_card.dart';
import '../../../widgets/rr_text_field.dart';

class CreateBillScreen extends StatefulWidget {
  /// The active service request the bill is being created for.
  final ServiceRequestModel? request;

  const CreateBillScreen({super.key, this.request});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  // Start with a default service labor item
  final List<_DraftItem> _items = [
    _DraftItem('Roadside Assistance — Labor Charges', 1, 500),
  ];

  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  double get _subtotal => _items.fold(0.0, (sum, i) => sum + i.total);
  double get _tax => _subtotal * 0.18;
  double get _total => _subtotal + _tax;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showAddItemDialog() {
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bill Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: 'Item Description',
                hintText: 'e.g. Brake fluid top-up',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit Price (₹)',
                hintText: 'e.g. 400',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: '1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final desc = descCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text) ?? 0;
              final qty = int.tryParse(qtyCtrl.text) ?? 1;
              if (desc.isNotEmpty && price > 0 && qty > 0) {
                setState(() => _items.add(_DraftItem(desc, qty, price)));
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in valid description, price, and quantity.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitBill() async {
    final req = widget.request;
    if (req == null || req.id.isEmpty) {
      setState(() => _errorMessage = 'No service request linked to this bill.');
      return;
    }
    if (_items.isEmpty) {
      setState(() => _errorMessage = 'At least one bill item is required.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await BillingService.createBill(
        requestId: req.id,
        items: _items
            .map((i) => {
                  'description': i.description,
                  'quantity': i.quantity,
                  'unitPrice': i.unitPrice,
                })
            .toList(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice sent to customer! Awaiting payment.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.provider,
        (r) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('ApiException', '').trim();
        if (_errorMessage!.startsWith('(')) {
          _errorMessage = _errorMessage!.substring(_errorMessage!.indexOf('):') + 2).trim();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final req = widget.request;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Customer Invoice'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    RRCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.request_quote_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req != null
                                      ? '${req.vehicleModel} (${req.vehiclePlate})'
                                      : 'Vehicle Details',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  req != null
                                      ? 'Customer: ${req.customerName ?? "Customer"} • ${req.serviceType}'
                                      : 'Roadside Assistance',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Line items list
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SectionHeader(title: 'Billed Items & Labor'),
                        TextButton.icon(
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RRCard(
                      child: Column(
                        children: [
                          for (int i = 0; i < _items.length; i++) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _items[i].description,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Qty: ${_items[i].quantity} × ₹${_items[i].unitPrice.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${_items[i].total.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => setState(() => _items.removeAt(i)),
                                  ),
                                ],
                              ),
                            ),
                            if (i < _items.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Calculations — shown for transparency (server recalculates)
                    RRCard(
                      child: Column(
                        children: [
                          InfoRow(label: 'Subtotal', value: '₹${_subtotal.toStringAsFixed(2)}'),
                          const Divider(),
                          InfoRow(label: 'Tax (GST 18%)', value: '₹${_tax.toStringAsFixed(2)}'),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Invoice Amount',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '₹${_total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Final amount is calculated & verified by the server.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Technician notes
                    RRTextField(
                      label: 'Technician Notes for Customer (optional)',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),

            // Submit bill
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: RRButton(
                label: 'Send Invoice to Customer (₹${_total.toStringAsFixed(0)})',
                icon: Icons.send_rounded,
                isLoading: _isSubmitting,
                onPressed: _items.isEmpty ? null : _submitBill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Internal draft item model ─────────────────────────────────────────────────

class _DraftItem {
  String description;
  int quantity;
  double unitPrice;

  _DraftItem(this.description, this.quantity, this.unitPrice);

  double get total => quantity * unitPrice;
}
