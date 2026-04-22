import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final email = context.read<AuthController>().session?.email;
      if (email == null) return;
      await context.read<ProfileController>().load(email);
      final profile = context.read<ProfileController>().profile;
      if (profile != null) _nameCtrl.text = profile.displayName;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await context.read<ProfileController>().updateAvatar(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final profileCtrl = context.watch<ProfileController>();
    final profile = profileCtrl.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body:
          profileCtrl.loading && profile == null
              ? const Center(child: CircularProgressIndicator())
              : profile == null
              ? const Center(child: Text('No se pudo cargar el perfil'))
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: _AvatarView(
                      base64Image: profile.avatarBase64,
                      radius: 52,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.photo),
                        label: const Text('Cambiar foto'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            profile.avatarBase64 == null
                                ? null
                                : () =>
                                    context
                                        .read<ProfileController>()
                                        .clearAvatar(),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Quitar foto'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre visible',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Correo: ${profile.email}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () async {
                      await context.read<ProfileController>().updateName(
                        _nameCtrl.text,
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Perfil actualizado')),
                      );
                    },
                    child: const Text('Guardar cambios'),
                  ),
                ],
              ),
    );
  }
}

class _AvatarView extends StatelessWidget {
  final String? base64Image;
  final double radius;

  const _AvatarView({required this.base64Image, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (base64Image == null || base64Image!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: const Icon(Icons.person, size: 42),
      );
    }
    final bytes = base64Decode(base64Image!);
    return CircleAvatar(
      radius: radius,
      backgroundImage: MemoryImage(Uint8List.fromList(bytes)),
    );
  }
}
