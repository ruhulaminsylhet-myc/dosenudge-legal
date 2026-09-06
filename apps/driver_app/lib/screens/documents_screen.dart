import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models.dart';
import '../l10n/strings.dart';
import '../services/driver_service.dart';

/// Upload the documents an admin needs before approving the driver, together
/// with the dates the ones that expire run out on.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

String _documentLabel(Strings t, DriverDocument doc) => switch (doc) {
      DriverDocument.licence => t.drivingLicence,
      DriverDocument.insurance => t.insuranceCertificate,
      DriverDocument.vehiclePhoto => t.vehiclePhoto,
    };

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _picker = ImagePicker();
  DriverDocument? _busy;
  String? _error;

  /// Documents are only valid while in date, so a renewed one is worthless to
  /// us without its new date — we ask for both in one go.
  Future<DateTime?> _askExpiry(DriverDocument doc, {DateTime? initial}) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      helpText: '${_documentLabel(Strings.of(context), doc)} — '
          '${Strings.of(context).expiryDate}',
      initialDate: initial ?? now.add(const Duration(days: 365)),
      // A document that expired yesterday is no use, so today is the floor.
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
  }

  Future<void> _pickAndUpload(DriverDocument doc) async {
    final t = Strings.of(context);
    setState(() => _error = null);

    DateTime? expiresAt;
    if (doc.requiresExpiry) {
      expiresAt = await _askExpiry(doc);
      if (expiresAt == null) return; // cancelled — nothing to upload against
    }

    setState(() => _busy = doc);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      await DriverService.instance
          .uploadDocument(doc, File(picked.path), expiresAt: expiresAt);
    } catch (e) {
      setState(() => _error = t.uploadFailed);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _editExpiry(DriverDocument doc, DateTime? current) async {
    final t = Strings.of(context);
    final picked = await _askExpiry(doc, initial: current);
    if (picked == null) return;
    setState(() {
      _busy = doc;
      _error = null;
    });
    try {
      await DriverService.instance.setDocumentExpiry(doc, picked);
    } catch (e) {
      setState(() => _error = t.uploadFailed);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.verificationDocuments)),
      body: StreamBuilder<DriverProfile>(
        stream: DriverService.instance.profileStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t.documentsIntro,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                t.expiryRequiredNotice,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              for (final doc in DriverDocument.values)
                _DocumentCard(
                  doc: doc,
                  entry: profile.documents[doc.key],
                  busy: _busy == doc,
                  disabled: _busy != null,
                  onUpload: () => _pickAndUpload(doc),
                  onEditExpiry: (current) => _editExpiry(doc, current),
                ),
              const SizedBox(height: 16),
              if (profile.hasAllDocuments && profile.expiredDocuments.isEmpty)
                Card(
                  color: const Color(0xFFE8F5E9),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t.allDocumentsUploaded)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.entry,
    required this.busy,
    required this.disabled,
    required this.onUpload,
    required this.onEditExpiry,
  });

  final DriverDocument doc;
  final DriverDocumentEntry? entry;
  final bool busy;
  final bool disabled;
  final VoidCallback onUpload;
  final void Function(DateTime? current) onEditExpiry;

  @override
  Widget build(BuildContext context) {
    final t = Strings.of(context);
    final uploaded = entry != null;
    final expiresAt = entry?.expiresAt;
    final needsExpiry = uploaded && doc.requiresExpiry && expiresAt == null;
    final expired = entry?.isExpired ?? false;

    final (IconData icon, Color colour, String status) = switch (entry) {
      null => (Icons.upload_file, Colors.grey, t.notUploaded),
      final e => switch (e) {
          _ when expired => (Icons.error, Colors.red, t.expired),
          _ when needsExpiry =>
            (Icons.event_busy, Colors.orange, t.expiryMissing),
          _ when e.isExpiringSoon => (
              Icons.warning_amber,
              Colors.orange,
              t.expiresInDays(e.daysRemaining!),
            ),
          _ when expiresAt != null => (
              Icons.check_circle,
              Colors.green,
              t.expiresOn(_formatDate(expiresAt)),
            ),
          _ => (Icons.check_circle, Colors.green, t.uploaded),
        },
    };

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: colour),
            title: Text(_documentLabel(t, doc)),
            subtitle: Text(status, style: TextStyle(color: colour)),
            trailing: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: disabled ? null : onUpload,
                    child: Text(uploaded ? t.replace : t.upload),
                  ),
          ),
          // Lets a driver correct a date without re-photographing the document.
          if (uploaded && doc.requiresExpiry)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.expiryDate,
                      style: TextStyle(color: Colors.grey.shade600)),
                  TextButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(expiresAt != null
                        ? _formatDate(expiresAt)
                        : t.setExpiryDate),
                    onPressed: disabled ? null : () => onEditExpiry(expiresAt),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
