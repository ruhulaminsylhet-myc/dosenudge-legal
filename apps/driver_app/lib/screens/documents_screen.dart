import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/models.dart';
import '../services/driver_service.dart';

/// Upload the documents an admin needs before approving the driver.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _picker = ImagePicker();
  DriverDocument? _uploading;
  String? _error;

  Future<void> _pickAndUpload(DriverDocument doc) async {
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
      setState(() => _error = 'Upload failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification documents')),
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
                'Upload a clear photo of each document. Our team reviews them '
                'before approving your account.',
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
                    title: Text(doc.label),
                    subtitle: Text(
                      profile.documents.containsKey(doc.key)
                          ? 'Uploaded'
                          : 'Not uploaded yet',
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
                                  ? 'Replace'
                                  : 'Upload',
                            ),
                          ),
                  ),
                ),
              const SizedBox(height: 16),
              if (profile.hasAllDocuments)
                const Card(
                  color: Color(0xFFE8F5E9),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'All documents uploaded. Your application is ready '
                            'for review.',
                          ),
                        ),
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
