import 'dart:io';
import 'package:flutter/material.dart';

class PdfViewerOverlay extends StatelessWidget {
  const PdfViewerOverlay({
    super.key,
    required this.filePath,
    required this.onClose,
  });

  final String filePath;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    // Viewer-only placeholder.
    // Later you can swap in a proper PDF package (pdfx/syncfusion_pdfviewer).
    return Material(
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Container(
          width: 900,
          height: 560,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filePath.split(Platform.pathSeparator).last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              const Expanded(
                child: Center(
                  child: Text(
                    "PDF Viewer Placeholder\n\nAdd a PDF viewer package when ready.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
