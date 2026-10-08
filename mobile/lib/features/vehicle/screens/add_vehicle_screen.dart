import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/mock_data.dart';
import '../../../services/vehicle_service.dart';
import '../../../services/api_client.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/rr_text_field.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedType = AppConstants.vehicleTypes.first;
  String? _selectedManufacturer;
  String? _selectedModel;
  final _plateController = TextEditingController();
  final _yearController = TextEditingController(text: '2022');
  final _colorController = TextEditingController(text: 'White');
  bool _isDefault = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get _manufacturers =>
      MockData.manufacturersByType[_selectedType] ??
      ['Tata', 'Ashok Leyland', 'Mahindra'];

  List<String> get _models {
    if (_selectedManufacturer == null) return [];
    return MockData.modelsByManufacturer[_selectedManufacturer] ??
        ['Standard Model'];
  }

  @override
  void initState() {
    super.initState();
    _selectedManufacturer = _manufacturers.first;
    _selectedModel = _models.isNotEmpty ? _models.first : null;
  }

  @override
  void dispose() {
    _plateController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? newType) {
    if (newType == null) return;
    setState(() {
      _selectedType = newType;
      final mfgList = MockData.manufacturersByType[newType] ?? [];
      _selectedManufacturer = mfgList.isNotEmpty ? mfgList.first : null;
      final mdlList = _selectedManufacturer != null
          ? (MockData.modelsByManufacturer[_selectedManufacturer] ?? [])
          : <String>[];
      _selectedModel = mdlList.isNotEmpty ? mdlList.first : null;
    });
  }

  void _onManufacturerChanged(String? newMfg) {
    if (newMfg == null) return;
    setState(() {
      _selectedManufacturer = newMfg;
      final mdlList = MockData.modelsByManufacturer[newMfg] ?? [];
      _selectedModel = mdlList.isNotEmpty ? mdlList.first : null;
    });
  }

  void _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await VehicleService.addVehicle(
        type: _selectedType,
        manufacturer: _selectedManufacturer ?? '',
        model: _selectedModel ?? '',
        plateNumber: _plateController.text.trim(),
        year: _yearController.text.trim().isNotEmpty
            ? _yearController.text.trim()
            : null,
        color: _colorController.text.trim().isNotEmpty
            ? _colorController.text.trim()
            : null,
        isDefault: _isDefault,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Vehicle ${_plateController.text.toUpperCase()} added successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      // Return true so MyVehiclesScreen knows to refresh
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        if (e.errors != null) _errorMessage = e.errors!.join('\n');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add vehicle. Check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Register your vehicle',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Vehicles, lorries, trucks and all commercial vehicles.',
                              style: TextStyle(
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

                // Error banner
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Vehicle Type Dropdown
                RRDropdownField<String>(
                  label: 'Vehicle Category',
                  value: _selectedType,
                  items: AppConstants.vehicleTypes
                      .map((t) =>
                          DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 18),

                // Manufacturer Dropdown
                RRDropdownField<String>(
                  label: 'Manufacturer / Make',
                  value: _selectedManufacturer,
                  items: _manufacturers
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: _onManufacturerChanged,
                ),
                const SizedBox(height: 18),

                // Model Dropdown or Text
                if (_models.isNotEmpty)
                  RRDropdownField<String>(
                    label: 'Model',
                    value: _selectedModel,
                    items: _models
                        .map((mod) =>
                            DropdownMenuItem(value: mod, child: Text(mod)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedModel = val),
                  )
                else
                  RRTextField(
                    label: 'Model Name',
                    hint: 'e.g. 2820 Tipper',
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Model name is required' : null,
                  ),
                const SizedBox(height: 18),

                // License Plate Number
                RRTextField(
                  label: 'Registration / Plate Number',
                  hint: 'e.g. TN 38 AB 1234',
                  controller: _plateController,
                  prefixIcon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Plate number is required';
                    }
                    if (v.trim().length < 5) {
                      return 'Enter a valid license plate number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Row with Year and Color
                Row(
                  children: [
                    Expanded(
                      child: RRTextField(
                        label: 'Year',
                        hint: '2022',
                        controller: _yearController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.calendar_today_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: RRTextField(
                        label: 'Color',
                        hint: 'White',
                        controller: _colorController,
                        prefixIcon: Icons.palette_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Default switch
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Set as Default Vehicle',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pre-selected during emergency requests',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isDefault,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _isDefault = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                RRButton(
                  label: 'Add Vehicle',
                  icon: Icons.check_rounded,
                  isLoading: _isLoading,
                  onPressed: _saveVehicle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
