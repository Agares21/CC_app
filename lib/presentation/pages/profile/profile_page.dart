import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:cloud_api_cc/core/theme/app_colors.dart';
import 'package:cloud_api_cc/core/theme/app_text_styles.dart';
import 'package:cloud_api_cc/data/api/api_client.dart';
import 'package:cloud_api_cc/data/api/profile_api.dart';
import 'package:cloud_api_cc/data/models/user_model.dart';
import 'package:cloud_api_cc/presentation/bloc/auth/auth_bloc.dart';
import 'package:cloud_api_cc/presentation/widgets/authenticated_user_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileApi _api;
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _picker = ImagePicker();

  var _initialized = false;
  var _savingProfile = false;
  var _savingPassword = false;
  var _avatarBusy = false;
  var _profileErrors = <String, String>{};
  var _passwordErrors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _api = ProfileApi(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  void _initializeForm(UserModel user) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = user.name;
    _lastNameController.text = user.lastName;
  }

  Future<void> _saveProfile(UserModel user) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _savingProfile = true;
      _profileErrors = {};
    });

    try {
      final response = await _api.updateProfile(
        name: _nameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      _applyUser(response);
      _showMessage('Perfil actualizado.');
    } catch (error) {
      final errors = _validationErrors(error);
      if (mounted) {
        setState(() => _profileErrors = errors);
        if (errors.isEmpty) _showMessage('No se pudo guardar el perfil.');
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _savingPassword = true;
      _passwordErrors = {};
    });

    if (_passwordController.text != _passwordConfirmationController.text) {
      setState(() {
        _savingPassword = false;
        _passwordErrors = {
          'password': 'La confirmación de la contraseña no coincide.',
        };
      });
      return;
    }

    try {
      await _api.updatePassword(
        currentPassword: _currentPasswordController.text,
        password: _passwordController.text,
        passwordConfirmation: _passwordConfirmationController.text,
      );
      _currentPasswordController.clear();
      _passwordController.clear();
      _passwordConfirmationController.clear();
      _showMessage('Contraseña actualizada.');
    } catch (error) {
      final errors = _validationErrors(error);
      if (mounted) {
        setState(() => _passwordErrors = errors);
        if (errors.isEmpty) _showMessage('No se pudo cambiar la contraseña.');
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) return;

    setState(() => _avatarBusy = true);
    try {
      final response = await _api.uploadAvatar(
        path: file.path,
        filename: file.name,
      );
      _applyUser(response);
      _showMessage('Foto de perfil actualizada.');
    } catch (error) {
      final message = _validationErrors(error)['avatar'];
      _showMessage(message ?? 'No se pudo subir la foto.');
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _deleteAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar foto'),
        content: const Text('¿Quieres eliminar tu foto de perfil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Quitar',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _avatarBusy = true);
    try {
      final response = await _api.deleteAvatar();
      _applyUser(response);
      _showMessage('Foto de perfil eliminada.');
    } catch (_) {
      _showMessage('No se pudo eliminar la foto.');
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  void _applyUser(Map<String, dynamic> response) {
    final userData = response['user'] as Map<String, dynamic>;
    context.read<AuthBloc>().add(AuthUserUpdated(userData));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) return const SizedBox.shrink();
        final user = state.user;
        _initializeForm(user);

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mi perfil', style: AppTextStyles.headingMd),
                  const SizedBox(height: 2),
                  Text(
                    'Administra tu cuenta y tus datos de acceso.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _profileCard(user),
            const SizedBox(height: 12),
            _passwordCard(),
          ],
        );
      },
    );
  }

  Widget _profileCard(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AuthenticatedUserAvatar(user: user, size: 78),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Foto de perfil', style: AppTextStyles.headingSm),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _avatarBusy ? null : _pickAvatar,
                            icon: _avatarBusy
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              user.avatarUrl == null ? 'Subir' : 'Cambiar',
                            ),
                          ),
                          if (user.avatarUrl != null)
                            TextButton.icon(
                              onPressed: _avatarBusy ? null : _deleteAvatar,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.destructive,
                              ),
                              label: const Text(
                                'Quitar',
                                style: TextStyle(color: AppColors.destructive),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'JPG, PNG o WEBP. Máximo 4 MB.',
                        style: AppTextStyles.captionXs,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('Nombre', style: AppTextStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                errorText: _profileErrors['name'],
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            Text('Apellido', style: AppTextStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: _lastNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                errorText: _profileErrors['last_name'],
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Text('Correo electrónico', style: AppTextStyles.label),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.mail_outline,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(user.email, style: AppTextStyles.body)),
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.shield_outlined,
                  label: user.role?.name ?? 'Sin rol',
                ),
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: 'Desde ${_memberSince(user.createdAt)}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _savingProfile ? null : () => _saveProfile(user),
              child: _savingProfile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cambiar contraseña', style: AppTextStyles.headingSm),
            const SizedBox(height: 3),
            Text(
              'Confirma primero tu contraseña actual.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 18),
            Text('Contraseña actual', style: AppTextStyles.label),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _currentPasswordController,
              errorText: _passwordErrors['current_password'],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            Text('Nueva contraseña', style: AppTextStyles.label),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _passwordController,
              errorText: _passwordErrors['password'],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            Text('Repetir nueva contraseña', style: AppTextStyles.label),
            const SizedBox(height: 6),
            _PasswordField(
              controller: _passwordConfirmationController,
              textInputAction: TextInputAction.done,
              onSubmitted: _savingPassword ? null : _changePassword,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Mínimo 8 caracteres, con una letra, un número y un símbolo.',
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _savingPassword ? null : _changePassword,
              child: _savingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Cambiar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? errorText;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        errorText: widget.errorText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.brand),
          ),
        ],
      ),
    );
  }
}

Map<String, String> _validationErrors(Object error) {
  if (error is! DioException || error.response?.statusCode != 422) {
    return {};
  }

  final data = error.response?.data;
  if (data is! Map || data['errors'] is! Map) return {};
  final errors = data['errors'] as Map;
  final result = <String, String>{};
  errors.forEach((key, value) {
    final messages = value is List ? value : const [];
    result['$key'] = messages.isEmpty ? 'Dato inválido.' : '${messages.first}';
  });
  return result;
}

String _memberSince(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return '—';
  return DateFormat('dd/MM/yyyy').format(parsed.toLocal());
}
