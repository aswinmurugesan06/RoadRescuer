import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_text_field.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'Billing Dispute';
  final _reqIdController = TextEditingController(text: 'req001');
  final _descController = TextEditingController();
  bool _isLoading = false;

  final List<String> _categories = [
    'Billing Dispute',
    'Excessive Delay in Arrival',
    'Poor Repair Quality / Issue Reoccurred',
    'Unprofessional Technician Behavior',
    'Safety / Damage Concern',
    'Other Issue',
  ];

  @override
  void dispose() {
    _reqIdController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Support ticket #TKT-4891 submitted. Our team will review within 2 hours.'),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We are here to help',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Submit your complaint or feedback regarding a roadside assistance request.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 24),

                // Category dropdown
                RRDropdownField<String>(
                  label: 'Issue Category',
                  value: _selectedCategory,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                ),
                const SizedBox(height: 18),

                // Request ID
                RRTextField(
                  label: 'Assistance Request ID',
                  controller: _reqIdController,
                  prefixIcon: Icons.tag_rounded,
                  hint: 'e.g. req001 or INV-0042',
                  validator: (v) => v == null || v.isEmpty ? 'Request ID is required' : null,
                ),
                const SizedBox(height: 18),

                // Description
                RRTextField(
                  label: 'Describe the Problem in Detail',
                  controller: _descController,
                  hint: 'Provide as much detail as possible to help our dispute team investigate...',
                  maxLines: 4,
                  validator: (v) {
                    if (v == null || v.trim().length < 10) {
                      return 'Please provide at least 10 characters description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Upload attachment mock
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Photo / receipt attached to ticket')),
                    );
                  },
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Attach Photos / Bill Receipt'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 36),

                // Submit button
                RRButton(
                  label: 'Submit Ticket',
                  icon: Icons.send_rounded,
                  isLoading: _isLoading,
                  onPressed: _submitComplaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
