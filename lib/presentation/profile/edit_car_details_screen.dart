import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user_model.dart';

class EditCarDetailsScreen extends StatefulWidget {
  const EditCarDetailsScreen({super.key});

  @override
  State<EditCarDetailsScreen> createState() => _EditCarDetailsScreenState();
}

class _EditCarDetailsScreenState extends State<EditCarDetailsScreen> {
  final _authService = AuthService();
  final _makeController  = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController  = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving  = false;
  bool _hasAC     = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final user = await _authService.getCurrentUserProfile();
    if (mounted && user?.carDetails != null) {
      final car = user!.carDetails!;
      _makeController.text  = car.make;
      _modelController.text = car.model;
      _colorController.text = car.color;
      _plateController.text = car.plateNumber;
      _yearController.text  = car.year.toString();
      _hasAC = car.hasAC;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = await _authService.getCurrentUserProfile();
      if (user == null) throw Exception('User not found');

      final car = CarDetails(
        make:        _makeController.text.trim(),
        model:       _modelController.text.trim(),
        color:       _colorController.text.trim(),
        plateNumber: _plateController.text.trim().toUpperCase(),
        year:        int.tryParse(_yearController.text.trim()) ?? 2020,
        hasAC:       _hasAC,
      );

      await _authService.updateCarDetails(uid: user.uid, carDetails: car);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Car details saved!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Car Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppTheme.primary, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'These details are shown to riders when you offer a ride.',
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Center(
                      child: Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.directions_car,
                            color: AppTheme.primary, size: 40),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const _SectionLabel('Make (Brand)'),
                    _FormField(
                      controller: _makeController,
                      hint: 'e.g. Toyota, Honda, Suzuki',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter car make'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const _SectionLabel('Model'),
                    _FormField(
                      controller: _modelController,
                      hint: 'e.g. Corolla, Civic, Swift',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter car model'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const _SectionLabel('Color'),
                    _FormField(
                      controller: _colorController,
                      hint: 'e.g. White, Silver, Black',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter car color'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const _SectionLabel('License Plate Number'),
                    _FormField(
                      controller: _plateController,
                      hint: 'e.g. LHR-1234',
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter plate number'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const _SectionLabel('Year'),
                    _FormField(
                      controller: _yearController,
                      hint: 'e.g. 2020',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter year';
                        }
                        final year = int.tryParse(v);
                        if (year == null || year < 1990 || year > 2026) {
                          return 'Enter a valid year (1990–2026)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const _SectionLabel('Air Conditioning'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: const Text(
                          'AC Available',
                          style: TextStyle(fontSize: 15, color: AppTheme.textDark),
                        ),
                        subtitle: Text(
                          _hasAC ? 'AC is available in your car' : 'No AC in your car',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                        ),
                        secondary: Icon(
                          Icons.ac_unit,
                          color: _hasAC ? AppTheme.primary : AppTheme.textLight,
                        ),
                        value: _hasAC,
                        activeColor: AppTheme.primary,
                        onChanged: (val) => setState(() => _hasAC = val),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Save Car Details',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark)),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 15, color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textLight, fontSize: 14),
        filled: true,
        fillColor: AppTheme.bgWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
      ),
    );
  }
}
