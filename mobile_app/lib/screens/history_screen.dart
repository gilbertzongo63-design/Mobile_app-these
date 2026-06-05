import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import '../services/api_client.dart';
import '../services/prediction_service.dart';
import '../widgets/app_bottom_nav_bar.dart';
import '../widgets/app_logo.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'result_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

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
        _error = 'Impossible de charger votre historique pour le moment.';
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AuthScreen(
          redirectTo: HistoryScreen(),
          initialMode: AuthMode.login,
        ),
      ),
    );
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
        const classes = [
          ('Plastic', 'Plastique', Icons.local_drink_outlined),
          ('Glass', 'Verre', Icons.wine_bar_outlined),
          ('PaperCardboard', 'Papier / Carton', Icons.inventory_2_outlined),
          ('Metal', 'Métal', Icons.sports_bar_outlined),
          ('Other', 'Autre déchet', Icons.delete_outline_rounded),
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
                const Text(
                  'Modifier la classe',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17211C),
                  ),
                ),
                const SizedBox(height: 12),
                ...classes.map(
                  (item) => ListTile(
                    leading: Icon(item.$3, color: const Color(0xFF0A8A52)),
                    title: Text(item.$2),
                    trailing: prediction.recommendedClass == item.$1
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF0A8A52),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(item.$1),
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
        const SnackBar(content: Text('Historique modifié.')),
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
        const SnackBar(content: Text('Impossible de modifier cet historique.')),
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
          title: const Text('Supprimer ce scan ?'),
          content: const Text(
            'Cette action retirera ce scan de votre historique. Elle ne pourra pas être annulée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB22234),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
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
        const SnackBar(content: Text('Scan supprimé.')),
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
        const SnackBar(content: Text('Impossible de supprimer ce scan.')),
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
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDFF4E8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFF20BD6C),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: darkGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Historique des analyses',
                      style: TextStyle(
                        fontSize: 29,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17211C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _requiresAuth
                          ? 'Connectez-vous pour retrouver vos scans récents et votre impact écologique.'
                          : 'Consultez vos scans récents et votre impact écologique.',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        color: Color(0xFF56635B),
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (_loading)
                      const _LoadingHistoryCard()
                    else if (_requiresAuth)
                      _AuthHistoryCard(onPressed: _openAuthScreen)
                    else if (_predictions.isEmpty)
                      const _EmptyHistoryCard()
                    else ...[
                      ..._predictions.map(
                        (prediction) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _HistoryCard(
                            prediction: prediction,
                            editing: _editingPredictionId ==
                                prediction.predictionId,
                            deleting: _deletingPredictionId ==
                                prediction.predictionId,
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => ResultScreen(
                                    prediction: prediction,
                                  ),
                                ),
                              );
                            },
                            onEdit: () => _editPrediction(prediction),
                            onDelete: () => _deletePrediction(prediction),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ImpactSummaryCard(predictions: _predictions),
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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                } else if (index == 3) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
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

  String get _title {
    switch (prediction.recommendedClass.toLowerCase()) {
      case 'plastic':
        return 'Plastique détecté';
      case 'glass':
        return 'Verre détecté';
      case 'metal':
        return 'Métal détecté';
      case 'papercardboard':
        return 'Papier / Carton';
      default:
        return prediction.requiresReview ? 'Objet à vérifier' : 'Autre déchet';
    }
  }

  String get _actionText {
    if (prediction.requiresReview) {
      return 'Reprendre la photo';
    }

    switch (prediction.recommendedClass.toLowerCase()) {
      case 'plastic':
        return 'Voir les consignes de tri';
      case 'glass':
        return 'Voir le conteneur adapté';
      case 'metal':
        return 'Trouver la bonne filière';
      case 'papercardboard':
        return 'Détails du tri';
      default:
        return 'Consignes locales';
    }
  }

  String get _dateText {
    if (prediction.createdAt.isEmpty) {
      return 'Analyse récente';
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
                          _title,
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
                    _dateText,
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
                          _actionText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF117A49),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Modifier',
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
                        tooltip: 'Supprimer',
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
      child: Icon(icon, color: Colors.white, size: 34),
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

class _ImpactSummaryCard extends StatelessWidget {
  const _ImpactSummaryCard({required this.predictions});

  final List<PredictionResult> predictions;

  @override
  Widget build(BuildContext context) {
    final recyclableCount = predictions.where((item) => item.isRecyclable).length;
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
          const Row(
            children: [
              Icon(
                Icons.eco_rounded,
                color: Color(0xFFE6F8EA),
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre impact du mois',
                  style: TextStyle(
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
            '$recyclableCount objets recyclables identifiés',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFFE1F5E7),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Partager',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
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
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Chargement de votre historique...',
              style: TextStyle(
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            color: Color(0xFF0A8A52),
            size: 34,
          ),
          SizedBox(height: 16),
          Text(
            'Aucune analyse enregistrée',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C261F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vos prochaines prédictions apparaîtront ici automatiquement.',
            style: TextStyle(
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
          const Text(
            'Connexion requise',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17211C),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Connectez-vous pour récupérer votre historique de scans et vos prédictions sauvegardées.',
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
