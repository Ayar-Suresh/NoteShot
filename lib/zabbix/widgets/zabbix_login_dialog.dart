import 'package:flutter/material.dart';

class ZabbixLoginDialog extends StatefulWidget {
  final Future<bool> Function(String username, String password) onLogin;
  final String? initialUsername;
  final String? initialPassword;

  const ZabbixLoginDialog({super.key, required this.onLogin, this.initialUsername, this.initialPassword});

  @override
  State<ZabbixLoginDialog> createState() => _ZabbixLoginDialogState();
}

class _ZabbixLoginDialogState extends State<ZabbixLoginDialog> {
  late final _usernameController = TextEditingController(text: widget.initialUsername);
  late final _passwordController = TextEditingController(text: widget.initialPassword);
  bool _isLoading = false;
  String? _error;

  void _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await widget.onLogin(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Login failed. Please check credentials or network.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A2735),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.security, color: Color(0xFF00E5CC), size: 48),
            const SizedBox(height: 16),
            const Text(
              'ZABBIX LOGIN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00E5CC),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person, color: Color(0xFF556677)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock, color: Color(0xFF556677)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF0F1923)),
                      ),
                    )
                  : const Text('SIGN IN'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
