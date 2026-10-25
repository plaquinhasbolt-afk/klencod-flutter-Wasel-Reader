
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaselReaderApp());
}

class AppColors {
  static const background = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const surfaceAlt = Color(0xFF21262D);
  static const border = Color(0xFF30363D);
  static const primary = Color(0xFF3478F6);
  static const text = Color(0xFFE6EDF3);
  static const muted = Color(0xFF8B949E);
  static const green = Color(0xFF2EA043);
}

class WaselReaderApp extends StatelessWidget {
  const WaselReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wasel Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class RecentFile {
  final String name;
  final String extension;
  final Uint8List bytes;

  RecentFile({
    required this.name,
    required this.extension,
    required this.bytes,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<RecentFile> _recentFiles = [];
  final TextEditingController _searchController =
      TextEditingController();

  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'bmp',
        ],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final extension = (file.extension ?? '').toLowerCase();

      const supported = {
        'pdf', 'doc', 'docx', 'ppt', 'pptx',
        'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp',
      };

      if (!supported.contains(extension)) {
        _message('نوع الملف غير مدعوم.');
        return;
      }

      setState(() => _loading = true);

      final bytes = file.bytes ??
          (file.path != null
              ? await File(file.path!).readAsBytes()
              : null);

      if (!mounted) return;

      if (bytes == null) {
        _message('تعذر قراءة الملف المحدد.');
        return;
      }

      final recent = RecentFile(
        name: file.name,
        extension: extension,
        bytes: bytes,
      );

      if (extension == 'pdf') {
        _addRecent(recent);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPage(
              name: file.name,
              bytes: bytes,
            ),
          ),
        );
      } else if ({
        'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp',
      }.contains(extension)) {
        _addRecent(recent);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePage(
              name: file.name,
              bytes: bytes,
            ),
          ),
        );
      } else {
        await _openOfficeFile(file.name, bytes);
        if (mounted) _addRecent(recent);
      }
    } catch (e) {
      _message('حدث خطأ أثناء فتح الملف.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _addRecent(RecentFile file) {
    setState(() {
      _recentFiles.removeWhere((item) => item.name == file.name);
      _recentFiles.insert(0, file);

      // الاحتفاظ بآخر 20 ملفًا في الذاكرة.
      if (_recentFiles.length > 20) {
        _recentFiles.removeLast();
      }
    });
  }

  Future<void> _openOfficeFile(
    String name,
    Uint8List bytes,
  ) async {
    final directory = await getTemporaryDirectory();

    final safeName = name.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final file = File('${directory.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path);

    if (!mounted) return;

    if (result.type != ResultType.done) {
      _message(
        'تعذر فتح الملف. تأكد من تثبيت تطبيق يدعم صيغته.',
      );
    }
  }

  void _message(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  IconData _fileIcon(String extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.image_rounded;
    }
  }

  Color _fileColor(String extension) {
    switch (extension) {
      case 'pdf':
        return const Color(0xFFFF6B6B);
      case 'doc':
      case 'docx':
        return const Color(0xFF58A6FF);
      case 'ppt':
      case 'pptx':
        return const Color(0xFFFFA657);
      default:
        return AppColors.green;
    }
  }

  Future<void> _reopenFile(RecentFile file) async {
    if (file.extension == 'pdf') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPage(
            name: file.name,
            bytes: file.bytes,
          ),
        ),
      );
    } else if ({
      'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp',
    }.contains(file.extension)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePage(
            name: file.name,
            bytes: file.bytes,
          ),
        ),
      );
    } else {
      await _openOfficeFile(file.name, file.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _recentFiles.where((file) {
      return file.name.toLowerCase().contains(
            _query.trim().toLowerCase(),
          );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              color: AppColors.primary,
              size: 27,
            ),
            SizedBox(width: 9),
            Text(
              'Wasel Reader',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'اختيار ملف',
            onPressed: _loading ? null : _pickFile,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcome(),
            _buildSearch(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الملفات الأخيرة',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filtered.length} ملف',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        16, 0, 16, 100,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final file = filtered[index];

                        return Card(
                          color: AppColors.surface,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.all(12),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _fileColor(file.extension)
                                    .withOpacity(0.13),
                                borderRadius:
                                    BorderRadius.circular(13),
                              ),
                              child: Icon(
                                _fileIcon(file.extension),
                                color: _fileColor(file.extension),
                                size: 27,
                              ),
                            ),
                            title: Text(
                              file.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding:
                                  const EdgeInsets.only(top: 6),
                              child: Text(
                                file.extension.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.muted,
                            ),
                            onTap: () => _reopenFile(file),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _pickFile,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.folder_open_rounded),
        label: Text(_loading ? 'جارٍ فتح الملف' : 'اختيار ملف'),
      ),
    );
  }

  Widget _buildWelcome() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2463D9),
            Color(0xFF133A83),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 38,
          ),
          const SizedBox(height: 16),
          const Text(
            'كل ملفاتك في مكان واحد',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'افتح مستنداتك، اقرأ محاضراتك، '
            'ونظّم ملفاتك بسهولة.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _FormatChip(label: 'PDF'),
              _FormatChip(label: 'Word'),
              _FormatChip(label: 'PowerPoint'),
              _FormatChip(label: 'Images'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _query = value);
        },
        decoration: InputDecoration(
          hintText: 'ابحث عن ملف...',
          hintStyle: const TextStyle(color: AppColors.muted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.muted,
          ),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _query.isEmpty
                    ? Icons.folder_open_rounded
                    : Icons.search_off_rounded,
                size: 55,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _query.isEmpty
                  ? 'لم تفتح أي ملف بعد'
                  : 'لم يتم العثور على ملفات',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'اختر ملفًا من هاتفك لبدء القراءة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
            if (_query.isEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.add_rounded),
                label: const Text('فتح أول ملف'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;

  const _FormatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class PdfPage extends StatelessWidget {
  final String name;
  final Uint8List bytes;

  const PdfPage({
    super.key,
    required this.name,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SfPdfViewer.memory(bytes),
    );
  }
}

class ImagePage extends StatelessWidget {
  final String name;
  final Uint8List bytes;

  const ImagePage({
    super.key,
    required this.name,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Text('تعذر عرض الصورة.');
            },
          ),
        ),
      ),
    );
  }
}