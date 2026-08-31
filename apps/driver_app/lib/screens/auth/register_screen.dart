import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _make, _model, _color, _plate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.registerDriver(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        vehicle: Vehicle(
          make: _make.text.trim(),
          model: _model.text.trim(),
          color: _color.text.trim(),
          plate: _plate.text.trim().toUpperCase(),
        ),
      );
      if (mounted) Navigator.of(context).pop(); // auth stream takes over
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'email-already-in-use' => 'An account with this email already exists.',
            'weak-password' => 'Password is too weak.',
            _ => 'Registration failed (${e.code}).',
          });
    } catch (_) {
      setState(() => _error = 'Registration failed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        );
    String? req(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Driver Application')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Your details', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(controller: _name, decoration: deco('Full name'), validator: req),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: deco('Phone number'),
                  validator: req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: deco('Email'),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Enter a valid email',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: deco('Password'),
                  validator: (v) =>
                      v != null && v.length >= 8 ? null : 'Min 8 characters',
                ),
                const SizedBox(height: 24),
                Text('Vehicle', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(controller: _make, decoration: deco('Make (e.g. Toyota)'), validator: req),
                const SizedBox(height: 12),
                TextFormField(controller: _model, decoration: deco('Model (e.g. Prius)'), validator: req),
                const SizedBox(height: 12),
                TextFormField(controller: _color, decoration: deco('Colour'), validator: req),
                const SizedBox(height: 12),
                TextFormField(controller: _plate, decoration: deco('Registration plate'), validator: req),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Submitting…' : 'Submit application'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your application will be reviewed by our team. '
                  'You can go online once approved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
