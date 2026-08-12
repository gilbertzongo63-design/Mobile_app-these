import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/user_service.dart';

import '../services/export_helper.dart';

import '../models/prediction_result.dart';
import '../services/api_client.dart';
import '../services/prediction_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import '../l10n.dart';
import '../app_routes.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _predictionService = PredictionService();

  bool _loading = true;
  int? _editingPredictionId;
  int? _deletingPredictionId;
  String? _error;
  bool _requiresAuth = false;
  List<PredictionResult> _predictions = const [];
  String _searchQuery = '';
  String _statusFilter = 'all';

  List<PredictionResult> get _filteredPredictions {
    return _predictions.where((prediction) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          [
            prediction.imageFilename,
            prediction.classLabel,
            prediction.triageLabel,
            prediction.reasonLabel,
          ].join(' ').toLowerCase().contains(query);
      final matchesFilter = switch (_statusFilter) {
        'recyclable' => prediction.isRecyclable,
        'non_recyclable' => prediction.isNonRecyclable,
        'review' => prediction.requiresReview,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    setState(() {
      _loading = true;
      _error = null;
      _requiresAuth = false;
    });

    try {
      final items = await _predictionService.fetchPredictions();
      if (!mounted) {
        return;
      }
      setState(() {
        _predictions = items;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _requiresAuth = error.statusCode == 401;
        _predictions = const [];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = AppLocalizations.of(context).t('history.load_error');
        _predictions = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openAuthScreen() async {
    Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
  }

  bool _isNetworkError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('failed to fetch') ||
        message.contains('clientexception') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('network is unreachable') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('network');
  }

  String _getExportErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return AppLocalizations.of(context).t('history.export_unauthorized');
      }
      if (error.statusCode >= 500) {
        return AppLocalizations.of(context).t('history.export_server_error');
      }
      return '${AppLocalizations.of(context).t('history.export_error')} (${error.statusCode})';
    }
    if (_isNetworkError(error)) {
      return AppLocalizations.of(context).t('history.export_network_error');
    }
    return '${AppLocalizations.of(context).t('history.export_unexpected')}: $error';
  }

  Future<void> _exportHistory() async {
    if (_predictions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('history.export_none')),
        ),
      );
      return;
    }

    try {
      final response = await ApiClient().getRawResponse(
        '/history/export',
        queryParameters: {'format': 'csv'},
        authRequired: true,
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 401) {
        throw ApiException(
          message:
              AppLocalizations.of(context).t('history.export_unauthorized'),
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode != 200) {
        throw ApiException(
          message:
              AppLocalizations.of(context).t('history.export_server_error'),
          statusCode: response.statusCode,
        );
      }

      final filename =
          'history_export_${DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '_')}.csv';

      final savedPath = await saveExportFile(filename, response.body);

      if (!mounted) return;
      final displayPath = savedPath ?? filename;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)
                .t('history.exported_file')
                .replaceAll('{file}', displayPath),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getExportErrorMessage(error)),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getExportErrorMessage(error)),
        ),
      );
    }
  }

  Future<void> _editPrediction(PredictionResult prediction) async {
    if (_editingPredictionId != null) {
      return;
    }

    final selectedClass = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final classes = [
          {
            'value': 'Plastic',
            'label': AppLocalizations.of(context).t('classes.plastic'),
            'icon': Icons.local_drink_outlined,
          },
          {
            'value': 'Glass',
            'label': AppLocalizations.of(context).t('classes.glass'),
            'icon': Icons.wine_bar_outlined,
          },
          {
            'value': 'PaperCardboard',
            'label': AppLocalizations.of(context).t('classes.paper_cardboard'),
            'icon': Icons.inventory_2_outlined,
          },
          {
            'value': 'Metal',
            'label': AppLocalizations.of(context).t('classes.metal'),
            'icon': Icons.sports_bar_outlined,
          },
          {
            'value': 'Other',
            'label': AppLocalizations.of(context).t('classes.other'),
            'icon': Icons.delete_outline_rounded,
          },
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE7DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  AppLocalizations.of(context).t('history.edit_class_title'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17211C),
                  ),
                ),
                const SizedBox(height: 12),
                ...classes.map(
                  (item) => ListTile(
                    leading: Icon(item['icon'] as IconData,
                        color: const Color(0xFF0A8A52)),
                    title: Text(item['label'] as String),
                    trailing:
                        prediction.recommendedClass == (item['value'] as String)
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF0A8A52),
                              )
                            : null,
                    onTap: () =>
                        Navigator.of(context).pop(item['value'] as String),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedClass == null || selectedClass == prediction.recommendedClass) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _editingPredictionId = prediction.predictionId;
    });

    try {
      final updatedPrediction = await _predictionService.updatePredictionClass(
        predictionId: prediction.predictionId,
        predictedClass: selectedClass,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _predictions = _predictions
            .map(
              (item) => item.predictionId == updatedPrediction.predictionId
                  ? updatedPrediction
                  : item,
            )
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).t('history.modified'))),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).t('history.modify_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _editingPredictionId = null;
        });
      }
    }
  }

  Future<void> _deletePrediction(PredictionResult prediction) async {
    if (_deletingPredictionId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              AppLocalizations.of(context).t('history.confirm_delete.title')),
          content: Text(
              AppLocalizations.of(context).t('history.confirm_delete.body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppLocalizations.of(context).t('common.cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB22234),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppLocalizations.of(context)
                  .t('history.confirm_delete.action')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deletingPredictionId = prediction.predictionId;
    });

    try {
      await _predictionService.deletePrediction(prediction.predictionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _predictions = _predictions
            .where((item) => item.predictionId != prediction.predictionId)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).t('history.deleted'))),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).t('history.delete_failed'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingPredictionId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F9F0);
    const darkGreen = Color(0xFF0A8A52);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPredictions,
                color: darkGreen,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  children: [
                    Row(
                      children: [
                        const AppBrand(),
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
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDFF4E8),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF20BD6C),
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
                    const SizedBox(height: 28),
                    Text(
                      AppLocalizations.of(context).t('history.title'),
                      style: const TextStyle(
                        fontSize: 29,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17211C),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _requiresAuth
                                ? AppLocalizations.of(context)
                                    .t('history.require_auth')
                                : AppLocalizations.of(context)
                                    .t('history.intro'),
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.45,
                              color: Color(0xFF56635B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: !_loading && _predictions.isNotEmpty
                              ? _exportHistory
                              : null,
                          icon: const Icon(Icons.download_rounded,
                              color: Color(0xFF0A8A52)),
                          label: Text(
                            AppLocalizations.of(context).t('history.export'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0A8A52),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            backgroundColor:
                                !_loading && _predictions.isNotEmpty
                                    ? const Color(0xFFE8F4E8)
                                    : const Color(0xFFF2F5F1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const SizedBox(height: 26),
                    if (_loading)
                      const _LoadingHistoryCard()
                    else if (_requiresAuth)
                      _AuthHistoryCard(onPressed: _openAuthScreen)
                    else if (_predictions.isEmpty)
                      const _EmptyHistoryCard()
                    else ...[
                      _HistoryFilters(
                        searchQuery: _searchQuery,
                        statusFilter: _statusFilter,
                        onSearchChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        onFilterChanged: (value) {
                          setState(() {
                            _statusFilter = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_filteredPredictions.isEmpty)
                        const _EmptyFilterCard()
                      else
                        ..._filteredPredictions.map(
                          (prediction) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _HistoryCard(
                              prediction: prediction,
                              editing: _editingPredictionId ==
                                  prediction.predictionId,
                              deleting: _deletingPredictionId ==
                                  prediction.predictionId,
                              onTap: () {
                                Navigator.of(context).pushReplacementNamed(
                                  AppRoutes.result,
                                  arguments: <String, dynamic>{
                                    'prediction': prediction,
                                  },
                                );
                              },
                              onEdit: () => _editPrediction(prediction),
                              onDelete: () => _deletePrediction(prediction),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _ImpactSummaryCard(predictions: _filteredPredictions),
                    ],
                    if (_error != null && !_requiresAuth) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0ED),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB4543C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            AppBottomNavBar(
              selectedIndex: 2,
              onChanged: (index) {
                if (index == 0) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.home,
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.scan);
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.prediction,
    required this.editing,
    required this.deleting,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final PredictionResult prediction;
  final bool editing;
  final bool deleting;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _getTitle(BuildContext context) => prediction.requiresReview
      ? AppLocalizations.of(context).t('history.card.to_review')
      : AppLocalizations.of(context).t('history.card.detected').replaceAll('{class}', prediction.classLabel);

  String _getActionText(BuildContext context) {
    if (prediction.requiresReview) {
      return AppLocalizations.of(context).t('history.card.retake_photo');
    }

    switch (prediction.recommendedClass.toLowerCase()) {
      case 'plastic':
        return AppLocalizations.of(context).t('history.card.sorting_instructions');
      case 'glass':
        return AppLocalizations.of(context).t('history.card.adapted_container');
      case 'metal':
        return AppLocalizations.of(context).t('history.card.find_line');
      case 'papercardboard':
        return AppLocalizations.of(context).t('history.card.sorting_details');
      default:
        return AppLocalizations.of(context).t('history.card.local_instructions');
    }
  }

  String _getDateText(BuildContext context) {
    if (prediction.createdAt.isEmpty) {
      return AppLocalizations.of(context).t('history.card.recent_analysis');
    }
    final date = DateTime.tryParse(prediction.createdAt);
    if (date == null) {
      return prediction.createdAt;
    }
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _PredictionThumb(prediction: prediction),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _getTitle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF202821),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Badge(prediction: prediction),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDateText(context),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF505C55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getActionText(context),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF117A49),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: AppLocalizations.of(context).t('common.edit'),
                        onPressed: editing || deleting ? null : onEdit,
                        icon: editing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF117A49),
                              ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: AppLocalizations.of(context).t('common.delete'),
                        onPressed: editing || deleting ? null : onDelete,
                        icon: deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFB22234),
                              ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF117A49),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionThumb extends StatelessWidget {
  const _PredictionThumb({required this.prediction});

  final PredictionResult prediction;

  @override
  Widget build(BuildContext context) {
    final hasImage = prediction.imageUrl.isNotEmpty;
    final className = prediction.recommendedClass.toLowerCase();
    final icon = prediction.requiresReview
        ? Icons.search_off_rounded
        : switch (className) {
            'plastic' => Icons.local_drink_outlined,
            'glass' => Icons.wine_bar_outlined,
            'metal' => Icons.sports_bar_outlined,
            'papercardboard' => Icons.inventory_2_outlined,
            _ => Icons.delete_outline_rounded,
          };
    final colors = prediction.requiresReview
        ? const [Color(0xFFD9C590), Color(0xFFF6EDD0)]
        : switch (className) {
            'plastic' => const [Color(0xFF15371B), Color(0xFF6F945E)],
            'glass' => const [Color(0xFF94A7A8), Color(0xFFE3EFEA)],
            'metal' => const [Color(0xFF89928D), Color(0xFFDCE3DE)],
            'papercardboard' => const [Color(0xFFC88D57), Color(0xFFF1DFC6)],
            _ => const [Color(0xFFB56A5F), Color(0xFFEFC9C5)],
          };

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              prediction.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(icon, color: Colors.white, size: 34),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Icon(icon, color: Colors.white, size: 34);
              },
            )
          : Icon(icon, color: Colors.white, size: 34),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.prediction});

  final PredictionResult prediction;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;

    if (prediction.requiresReview) {
      background = const Color(0xFFF7E7BE);
      foreground = const Color(0xFF9B680B);
    } else if (prediction.isNonRecyclable) {
      background = const Color(0xFFFBD5D6);
      foreground = const Color(0xFFB22234);
    } else {
      background = const Color(0xFFE0F9E4);
      foreground = const Color(0xFF15904E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        prediction.triageLabel.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: foreground,
        ),
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.searchQuery,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final String searchQuery;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('all', AppLocalizations.of(context).t('history.filter.all')),
      ('recyclable', AppLocalizations.of(context).t('history.filter.recyclable')),
      ('non_recyclable', AppLocalizations.of(context).t('history.filter.non_recyclable')),
      ('review', AppLocalizations.of(context).t('history.filter.to_check')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onSearchChanged,
          controller: TextEditingController(text: searchQuery)
            ..selection = TextSelection.collapsed(offset: searchQuery.length),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).t('history.search_hint'),
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              final selected = statusFilter == filter.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter.$2),
                  selected: selected,
                  onSelected: (_) => onFilterChanged(filter.$1),
                  selectedColor: const Color(0xFFDDF6E4),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF0A8A52)
                        : const Color(0xFF4C5B52),
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF33CB72)
                        : const Color(0xFFE0E9DD),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _EmptyFilterCard extends StatelessWidget {
  const _EmptyFilterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.filter_alt_off_outlined,
            color: Color(0xFF0A8A52),
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).t('history.filter.empty_title'),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17211C),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).t('history.filter.empty_subtitle'),
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Color(0xFF58655D),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactSummaryCard extends StatelessWidget {
  const _ImpactSummaryCard({required this.predictions});

  final List<PredictionResult> predictions;

  @override
  Widget build(BuildContext context) {
    final recyclableCount =
        predictions.where((item) => item.isRecyclable).length;
    final nonRecyclableCount =
        predictions.where((item) => item.isNonRecyclable).length;
    final reviewCount = predictions.where((item) => item.requiresReview).length;
    final estimatedKg = (recyclableCount * 0.8).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF08793E),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.eco_rounded,
                color: Color(0xFFE6F8EA),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).t('history.impact.title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF4FFF6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$estimatedKg kg',
            style: const TextStyle(
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).t('history.impact.recyclable_count').replaceAll('{count}', '$recyclableCount'),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFFE1F5E7),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ImpactMiniMetric(
                  value: '$nonRecyclableCount',
                  label: AppLocalizations.of(context).t('history.impact.non_recyclable'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ImpactMiniMetric(
                  value: '$reviewCount',
                  label: AppLocalizations.of(context).t('history.impact.to_check'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                final text =
                    'EcoSort - Mon impact du mois\n\n'
                    '$estimatedKg kg de déchets recyclés\n'
                    '$recyclableCount objets recyclables\n'
                    '$nonRecyclableCount non recyclables\n'
                    '$reviewCount à vérifier\n\n'
                    'Rejoins-moi sur EcoSort !';
                Share.share(text);
              },
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                AppLocalizations.of(context).t('common.share'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactMiniMetric extends StatelessWidget {
  const _ImpactMiniMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFE1F5E7),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingHistoryCard extends StatelessWidget {
  const _LoadingHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              AppLocalizations.of(context).t('history.loading'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF304136),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_toggle_off_rounded,
            color: Color(0xFF0A8A52),
            size: 34,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).t('history.empty.title'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C261F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).t('history.empty.subtitle'),
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF58655D),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHistoryCard extends StatelessWidget {
  const _AuthHistoryCard({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).t('history.auth_required.title'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17211C),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).t('history.auth_required.description'),
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF55645B),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF33CB72),
                foregroundColor: const Color(0xFF112D1D),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Se connecter',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
