import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;
  bool _isSaving = false;
  File? _pickedImage;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _carMakeController;
  late TextEditingController _carModelController;
  late TextEditingController _carColorController;
  late TextEditingController _carPlateController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _authService.getCurrentUserProfile();
    if (user == null || !mounted) return;
    setState(() {
      _user = user;
      _nameController = TextEditingController(text: user.name);
      _phoneController = TextEditingController(text: user.phone);
      _carMakeController = TextEditingController(text: user.carDetails?.make ?? '');
      _carModelController = TextEditingController(text: user.carDetails?.model ?? '');
      _carColorController = TextEditingController(text: user.carDetails?.color ?? '');
      _carPlateController = TextEditingController(text: user.carDetails?.plateNumber ?? '');
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _carMakeController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    // update their own profile
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || _user == null || currentUid != _user!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unauthorized: You can only edit your own profile.'),
        backgroundColor: Colors.red));
      return;
    }
    if (!_formKey.currentState!.validate() || _user == null) return;
    setState(() => _isSaving = true);

    try {
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      if (_user!.role != 'passenger') {
        updateData['carDetails'] = CarDetails(
          make: _carMakeController.text.trim(),
          model: _carModelController.text.trim(),
          color: _carColorController.text.trim(),
          plateNumber: _carPlateController.text.trim(),
          year: _user!.carDetails?.year ?? DateTime.now().year,
        ).toMap();
      }

      await _authService.updateProfile(uid: _user!.uid, data: updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update failed. Try again.'),
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                  : const Text('Save',
                      style: TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile photo
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppTheme.primaryLight,
                        backgroundImage: _pickedImage != null
                            ? FileImage(_pickedImage!) as ImageProvider
                            : null,
                        child: _pickedImage == null
                            ? Text(
                                _user?.name.substring(0, 1).toUpperCase() ?? 'U',
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const _SectionTitle(title: 'Personal Information'),
              const SizedBox(height: 12),

              _Field(label: 'Full Name',
                child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.textLight)),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                )),

              const SizedBox(height: 14),

              _Field(label: 'Phone Number',
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textLight)),
                )),

              const SizedBox(height: 14),

              _Field(label: 'Email',
                child: TextFormField(
                  initialValue: _user?.email,
                  enabled: false,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textLight)),
                )),

              // Car details (for drivers)
              if (_user?.role != 'passenger') ...[
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Car Details'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _Field(label: 'Make',
                        child: TextFormField(
                          controller: _carMakeController,
                          decoration: const InputDecoration(hintText: 'Toyota'),
                        )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(label: 'Model',
                        child: TextFormField(
                          controller: _carModelController,
                          decoration: const InputDecoration(hintText: 'Corolla'),
                        )),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _Field(label: 'Color',
                        child: TextFormField(
                          controller: _carColorController,
                          decoration: const InputDecoration(hintText: 'White'),
                        )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(label: 'Plate Number',
                        child: TextFormField(
                          controller: _carPlateController,
                          decoration: const InputDecoration(hintText: 'LHR-1234'),
                        )),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
      style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark));
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textMedium)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}