import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../utils/url_helper.dart';

class PdfViewerWidget extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerWidget({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<PdfViewerWidget> {
  String? localPath;
  bool isLoading = true;
  String? error;
  int currentPage = 0;
  int totalPages = 0;
  PDFViewController? pdfViewController;

  @override
  void initState() {
    super.initState();
    _downloadAndSavePdf();
  }

  Future<void> _downloadAndSavePdf() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Vérifier si c'est déjà un fichier local
      if (await File(widget.pdfUrl).exists()) {
        // C'est déjà un fichier local
        if (mounted) {
          setState(() {
            localPath = widget.pdfUrl;
            isLoading = false;
          });
        }
        return;
      }

      // Construire l'URL complète pour téléchargement
      final fullUrl = UrlHelper.getFullUrl(widget.pdfUrl);

      debugPrint('📄 Téléchargement PDF depuis: $fullUrl');

      // Télécharger le PDF
      final response = await http.get(Uri.parse(fullUrl)).timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Erreur ${response.statusCode}: ${response.reasonPhrase}');
      }

      // Sauvegarder temporairement
      final dir = await getTemporaryDirectory();
      final fileName = '${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      debugPrint('✅ PDF sauvegardé: ${file.path}');

      if (mounted) {
        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur PDF: $e');
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    if (localPath != null) {
      await Share.shareXFiles(
        [XFile(localPath!)],
        subject: widget.title,
      );
    }
  }

  void _zoomIn() {
    // Zoom avant via controller si disponible
  }

  void _zoomOut() {
    // Zoom arrière via controller si disponible
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (localPath != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePdf,
              tooltip: 'Partager',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: _zoomIn,
              tooltip: 'Zoom avant',
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: _zoomOut,
              tooltip: 'Zoom arrière',
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: localPath != null && totalPages > 0
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: currentPage > 0
                        ? () {
                            pdfViewController?.setPage(currentPage - 1);
                          }
                        : null,
                  ),
                  Text(
                    'Page ${currentPage + 1} / $totalPages',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: currentPage < totalPages - 1
                        ? () {
                            pdfViewController?.setPage(currentPage + 1);
                          }
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement du PDF...'),
          ],
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _downloadAndSavePdf,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (localPath == null) {
      return const Center(child: Text('Aucun PDF disponible'));
    }

    return PDFView(
      filePath: localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: currentPage,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        setState(() {
          totalPages = pages ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          this.error = error.toString();
        });
      },
      onPageError: (page, error) {
        setState(() {
          this.error = 'Erreur page $page: $error';
        });
      },
      onViewCreated: (PDFViewController controller) {
        pdfViewController = controller;
      },
      onPageChanged: (int? page, int? total) {
        setState(() {
          currentPage = page ?? 0;
          totalPages = total ?? 0;
        });
      },
    );
  }
}
