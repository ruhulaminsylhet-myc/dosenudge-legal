import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/strings.dart';
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
    final t = Strings.of(context);
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
            'email-already-in-use' => t.emailInUse,
            'weak-password' => t.weakPassword,
            _ => t.registrationFailed,
          });
    } catch (_) {
      setState(() => _error = t.registrationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        );
    String? req(String? v) => v == null || v.trim().isEmpty ? t.required : null;

    return Scaffold(
      appBar: AppBar(title: Text(t.driverApplication)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.yourDetails, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(controller: _name, decoration: deco(t.fullName), validator: req),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: deco(t.phoneNumber),
                  validator: req,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: deco(t.email),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : t.enterValidEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: deco(t.password),
                  validator: (v) =>
                      v != null && v.length >= 8 ? null : t.min8Chars,
                ),
                const SizedBox(height: 24),
                Text(t.vehicle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextFormField(controller: _make, decoration: deco(t.make), validator: req),
                const SizedBox(height: 12),
                TextFormField(controller: _model, decoration: deco(t.model), validator: req),
                const SizedBox(height: 12),
                TextFormField(controller: _color, decoration: deco(t.colour), validator: req),
                const SizedBox(height: 12),
                TextFormField(controller: _plate, decoration: deco(t.plate), validator: req),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? t.submitting : t.submitApplication),
                ),
                const SizedBox(height: 8),
                Text(
                  t.reviewNotice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
