import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/download_task.dart';
import '../../services/download_service.dart';

class DownloadsManagerScreen extends StatefulWidget {
  final VoidCallback onBack;
  final AppColors appColors;

  const DownloadsManagerScreen({
    super.key,
    required this.onBack,
    required this.appColors,
  });

  @override
  State<DownloadsManagerScreen> createState() => _DownloadsManagerScreenState();
}

class _DownloadsManagerScreenState extends State<DownloadsManagerScreen> {
  final DownloadService _downloadService = DownloadService.instance;

  @override
  void initState() {
    super.initState();
    _downloadService.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  String _statusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.enqueued:
        return 'En cola';
      case DownloadStatus.running:
        return 'Descargando';
      case DownloadStatus.complete:
        return 'Completado';
      case DownloadStatus.failed:
        return 'Fallido';
      case DownloadStatus.paused:
        return 'Pausado';
      case DownloadStatus.canceled:
        return 'Cancelado';
    }
  }

  Color _statusColor(DownloadStatus status, AppColors colors) {
    switch (status) {
      case DownloadStatus.complete:
        return const Color(0xFF10B981);
      case DownloadStatus.failed:
        return const Color(0xFFEF4444);
      case DownloadStatus.running:
        return const Color(0xFFF59E0B);
      case DownloadStatus.enqueued:
        return const Color(0xFF3B82F6);
      default:
        return colors.textSecondary;
    }
  }

  IconData _statusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.complete:
        return Icons.check_circle_rounded;
      case DownloadStatus.failed:
        return Icons.error_outline_rounded;
      case DownloadStatus.running:
        return Icons.downloading_rounded;
      case DownloadStatus.enqueued:
        return Icons.hourglass_top_rounded;
      default:
        return Icons.pause_circle_outline_rounded;
    }
  }

  void _clearCompleted() {
    final completed = _downloadService.tasks
        .where((t) => t.status == DownloadStatus.complete || t.status == DownloadStatus.canceled)
        .toList();
    for (final task in completed) {
      _downloadService.removeTask(task.taskId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final tasks = _downloadService.tasks;
    final activeCount = tasks.where((t) => t.status == DownloadStatus.running).length;
    final completeCount = tasks.where((t) => t.status == DownloadStatus.complete).length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Center(
          child: GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 16),
            ),
          ),
        ),
        title: Text(
          'Gestor de Descargas',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (completeCount > 0)
            IconButton(
              icon: Icon(Icons.cleaning_services_rounded, color: colors.textSecondary, size: 20),
              tooltip: 'Limpiar completados',
              onPressed: _clearCompleted,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colors.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent.withOpacity(0.12),
                        border: Border.all(color: colors.accent.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.cloud_download_rounded, color: colors.accent, size: 36),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Sin descargas recientes',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Las pistas que descargues desde Stream aparecerán aquí con seguimiento en tiempo real y audio HD.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary.withOpacity(0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              children: [
                // Mini estadísticas resumen
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      _StatBadge(
                        label: 'Total',
                        count: '${tasks.length}',
                        color: colors.textPrimary,
                      ),
                      const SizedBox(width: 16),
                      _StatBadge(
                        label: 'Activas',
                        count: '$activeCount',
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 16),
                      _StatBadge(
                        label: 'Completadas',
                        count: '$completeCount',
                        color: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),

                // Lista de tareas con Bencho Cards
                ...tasks.map((task) => _BenchoDownloadCard(
                      task: task,
                      colors: colors,
                      statusColor: _statusColor(task.status, colors),
                      statusText: _statusText(task.status),
                      statusIcon: _statusIcon(task.status),
                      onDelete: () => _downloadService.removeTask(task.taskId),
                    )),
              ],
            ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        Text(
          count,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}

class _BenchoDownloadCard extends StatelessWidget {
  final DownloadTask task;
  final AppColors colors;
  final Color statusColor;
  final String statusText;
  final IconData statusIcon;
  final VoidCallback onDelete;

  const _BenchoDownloadCard({
    required this.task,
    required this.colors,
    required this.statusColor,
    required this.statusText,
    required this.statusIcon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = task.status == DownloadStatus.running;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.48),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning
              ? colors.accent.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Mini carátula con squircle Bencho
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.06),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty
                      ? Image.network(
                          task.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _fallbackCover(),
                        )
                      : _fallbackCover(),
                ),
              ),
              const SizedBox(width: 14),

              // Título y artista
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      task.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Chip de estado
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Chip de calidad
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.graphic_eq_rounded, color: colors.textSecondary, size: 11),
                              const SizedBox(width: 3),
                              Text(
                                task.quality,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botón borrar / descartar
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(Icons.close_rounded, color: colors.textSecondary, size: 16),
                ),
              ),
            ],
          ),

          // Barra de progreso si está descargando
          if (isRunning) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 6,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        FractionallySizedBox(
                          widthFactor: (task.progress / 100.0).clamp(0.0, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.accent,
                                  const Color(0xFF10B981),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accent.withOpacity(0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${task.progress}%',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fallbackCover() {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        color: colors.accent.withOpacity(0.6),
        size: 26,
      ),
    );
  }
}
