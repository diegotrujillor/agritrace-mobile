import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/users_provider.dart';
import '../../utils/constants.dart';
import '../../utils/error_parser.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _exportBusy = false;
  bool _deleteBusy = false;

  Future<void> _export() async {
    setState(() => _exportBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref.read(usersServiceProvider).exportMe();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = const Utf8Encoder().convert(json);
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/json', name: 'agritrace-datos.json')],
        subject: 'AgriTrace — Mis datos personales',
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(parseApiError(e))));
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esto eliminará permanentemente tu cuenta, fincas, lotes, '
          'actividades y alertas. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleteBusy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(usersServiceProvider).deleteMe();
      // logout clears tokens and router redirects to welcome automatically
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(parseApiError(e))));
    } finally {
      if (mounted) setState(() => _deleteBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).valueOrNull;
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      backgroundColor: AppColors.lightGreen,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        children: [
          _UserCard(user: user),
          const SizedBox(height: AppSpacing.sm),
          _ActionTile(
            icon: Icons.download_outlined,
            iconColor: AppColors.primaryGreen,
            title: 'Exportar mis datos',
            subtitle: 'Descarga un JSON con tu información (Ley 1581)',
            busy: _exportBusy,
            onTap: _export,
          ),
          const Divider(height: 1, indent: AppSpacing.lg),
          _ActionTile(
            icon: Icons.logout,
            iconColor: AppColors.grey,
            title: 'Cerrar sesión',
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
          const Divider(height: 1, indent: AppSpacing.lg),
          _ActionTile(
            icon: Icons.delete_forever_outlined,
            iconColor: AppColors.error,
            title: 'Eliminar mi cuenta',
            titleColor: AppColors.error,
            subtitle: 'Borra permanentemente tu cuenta y datos',
            busy: _deleteBusy,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryGreen,
            child: Icon(Icons.person, color: AppColors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.fullName ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkGreen),
                ),
                const SizedBox(height: 2),
                Text(user?.email ?? '', style: const TextStyle(color: AppColors.grey)),
                if (user?.phone.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(user!.phone, style: const TextStyle(color: AppColors.grey)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.subtitle,
    this.busy = false,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: AppColors.white,
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
            )
          : const Icon(Icons.chevron_right, color: AppColors.grey),
      onTap: busy ? null : onTap,
    );
  }
}
