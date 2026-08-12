import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/user_service.dart';

import '../l10n.dart';
import '../services/api_client.dart';
import '../services/prediction_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../app_routes.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.initialImageBytes,
    this.initialImagePath,
    this.initialImageName,
  });

  final Uint8List? initialImageBytes;
  final String? initialImagePath;
  final String? initialImageName;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _predictionService = PredictionService();
  final _imagePicker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImagePath;
  String? _selectedImageName;
  bool _analyzing = false;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _selectedImageBytes = widget.initialImageBytes;
    _selectedImagePath = widget.initialImagePath;
    _selectedImageName = widget.initialImageName;
    _recoverLostImageIfAny();
  }

  Future<void> _recoverLostImageIfAny() async {
    if (kIsWeb) return;
    try {
      final lostData = await _imagePicker.retrieveLostData();
      if (lostData.isEmpty) {
        return;
      }

      final file = lostData.file;
      if (file == null || !mounted) {
        return;
      }

      try {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImagePath = null;
          _selectedImageName = file.name.isNotEmpty ? file.name : 'capture.jpg';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = null;
          _selectedImagePath = file.path;
          _selectedImageName = file.name.isNotEmpty ? file.name : 'capture.jpg';
        });
      }
    } catch (_) {
    }
  }

  Future<void> _pickFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> _pickFromGallery() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _selectedImageBytes = file.bytes;
          _selectedImagePath = null;
          _selectedImageName = file.name.isNotEmpty ? file.name : 'imported.jpg';
        });
      } else if (file.path != null) {
        setState(() {
          _selectedImageBytes = null;
          _selectedImagePath = file.path;
          _selectedImageName = file.name.isNotEmpty ? file.name : 'imported.jpg';
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('scan.error.image_retrieval')} $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_pickingImage) {
      return;
    }

    setState(() {
      _pickingImage = true;
    });

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false,
      );

      if (file == null || !mounted) {
        return;
      }

      try {
        final bytes = await file.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImagePath = null;
          _selectedImageName = file.name.isNotEmpty ? file.name : 'capture.jpg';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _selectedImageBytes = null;
          _selectedImagePath = file.path;
          _selectedImageName = file.name.isNotEmpty ? file.name : 'capture.jpg';
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('scan.error.image_retrieval')} $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pickingImage = false;
        });
      }
    }
  }

  Future<void> _analyzeImage() async {
    final hasBytes = _selectedImageBytes != null;
    final hasPath = _selectedImagePath != null;
    if (_selectedImageName == null || (!hasBytes && !hasPath)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t('scan.error.no_image_selected'),
          ),
        ),
      );
      return;
    }

    setState(() {
      _analyzing = true;
    });

    try {
      final result = await _predictionService.predictImage(
        bytes: _selectedImageBytes,
        filePath: _selectedImagePath,
        filename: _selectedImageName!,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacementNamed(
        AppRoutes.result,
        arguments: <String, dynamic>{
          'prediction': result,
          'imageBytes': _selectedImageBytes,
        },
      );
    } on OfflineQueuedException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t('scan.offline.queued'),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      final msg = error.statusCode == 0
          ? '${AppLocalizations.of(context).t('scan.error.analysis_failed')} ${error.message}'
          : _friendlyAnalyzeError(context, error.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('scan.error.analysis_failed')} $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
        });
      }
    }
  }

  String _friendlyAnalyzeError(BuildContext context, String message) {
    if (message.contains('Unsupported image MIME type') ||
        message.contains('Invalid or corrupted image file')) {
      return AppLocalizations.of(context).t('scan.error.image_unrecognized');
    }
    if (message.contains('Image file is too large')) {
      return AppLocalizations.of(context).t('scan.error.image_too_large');
    }
    return '${AppLocalizations.of(context).t('scan.error.analysis_failed')} $message';
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const green = Color(0xFF35CF72);
    const darkGreen = Color(0xFF0A8A52);
    const border = Color(0xFFD6DDD0);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppBrand(
                          logoSize: 32,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context)
                                .pushReplacementNamed(AppRoutes.settings);
                          },
                          child: ValueListenableBuilder(
                            valueListenable: UserService.currentUser,
                            builder: (context, user, child) {
                              return Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDFF4E8),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFF19A85E),
                                    width: 2,
                                  ),
                                  image:
                                      user?.profileImageUrl.isNotEmpty == true
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                  user!.profileImageUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                ),
                                child: user?.profileImageUrl.isNotEmpty == true
                                    ? null
                                    : const Icon(
                                        Icons.person_rounded,
                                        color: darkGreen,
                                      ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      AppLocalizations.of(context).t('scan.title'),
                      style: const TextStyle(
                        fontSize: 31,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF162117),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context).t('scan.subtitle'),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: Color(0xFF4F5E52),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      height: 430,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FBF3),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: border, width: 2),
                      ),
                      child: Center(
                        child: _selectedImageBytes != null
                            ? Padding(
                                padding: const EdgeInsets.all(18),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    width: double.infinity,
                                    height: double.infinity,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        cacheWidth: 1600,
                                        cacheHeight: 1600,
                                      ),
                                ),
                              )
                            : _selectedImagePath != null && !kIsWeb
                                ? Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: Image.file(
                                        io.File(_selectedImagePath!),
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    cacheWidth: 1600,
                                    cacheHeight: 1600,
                                      ),
                                    ),
                                  )
                                : const _PreviewPlaceholder(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.camera_alt_outlined,
                            label: AppLocalizations.of(context)
                                .t('scan.action.take_photo'),
                            onTap: _pickFromCamera,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.image_outlined,
                            label: AppLocalizations.of(context)
                                .t('scan.action.pick_gallery'),
                            onTap: _pickFromGallery,
                          ),
                        ),
                      ],
                    ),
                    if (_pickingImage) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD9FBE1), Color(0xFFE7FBE2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color(0xFFD0EFCF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 42,
                            height: 42,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0xFF58EC85),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(14)),
                              ),
                              child: Icon(
                                Icons.tips_and_updates_outlined,
                                color: darkGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)
                                      .t('scan.tip_card.title'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: darkGreen,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppLocalizations.of(context).t('scan.tip'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.45,
                                    color: Color(0xFF39503C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton.icon(
                        onPressed: _analyzing ? null : _analyzeImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: const Color(0xFF13311F),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: _analyzing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Color(0xFF13311F),
                                ),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: Text(
                          _analyzing
                              ? AppLocalizations.of(context)
                                  .t('scan.action.analyzing')
                              : AppLocalizations.of(context)
                                  .t('scan.action.analyze'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNavBar(
              selectedIndex: 1,
              onChanged: (index) {
                if (index == 0) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.home);
                } else if (index == 2) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.history);
                } else if (index == 3) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.settings);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 118,
          height: 118,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF6EA),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.document_scanner_outlined,
            size: 52,
            color: Color(0xFF0A8A52),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          AppLocalizations.of(context).t('scan.preview.ready'),
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3930),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).t('scan.preview.placeholder'),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF738076),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 122,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FCF5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD5DDD1)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 34, color: const Color(0xFF0A8A52)),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF232B25),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

