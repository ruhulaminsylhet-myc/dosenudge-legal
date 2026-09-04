import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models.dart';
import '../l10n/strings.dart';
import '../services/driver_service.dart';

/// Upload the documents an admin needs before approving the driver.
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

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _picker = ImagePicker();
  DriverDocument? _uploading;
  String? _error;

  Future<void> _pickAndUpload(DriverDocument doc) async {
    final t = Strings.of(context);
    setState(() {
      _uploading = doc;
      _error = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (picked == null) return;
      await DriverService.instance.uploadDocument(doc, File(picked.path));
    } catch (e) {
      setState(() => _error = t.uploadFailed);
    } finally {
      if (mounted) setState(() => _uploading = null);
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              for (final doc in DriverDocument.values)
                Card(
                  child: ListTile(
                    leading: Icon(
                      profile.documents.containsKey(doc.key)
                          ? Icons.check_circle
                          : Icons.upload_file,
                      color: profile.documents.containsKey(doc.key)
                          ? Colors.green
                          : Colors.grey,
                    ),
                    title: Text(_documentLabel(t, doc)),
                    subtitle: Text(
                      profile.documents.containsKey(doc.key)
                          ? t.uploaded
                          : t.notUploaded,
                    ),
                    trailing: _uploading == doc
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: _uploading != null
                                ? null
                                : () => _pickAndUpload(doc),
                            child: Text(
                              profile.documents.containsKey(doc.key)
                                  ? t.replace
                                  : t.upload,
                            ),
                          ),
                  ),
                ),
              const SizedBox(height: 16),
              if (profile.hasAllDocuments)
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
