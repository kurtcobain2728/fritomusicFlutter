import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repository/hidden_items_manager.dart';
import '../../providers/home_provider.dart';

class HiddenItemsScreen extends StatefulWidget {
  final HomeProvider homeProvider;
  final VoidCallback onBack;
  final AppColors appColors;

  const HiddenItemsScreen({
    super.key,
    required this.homeProvider,
    required this.onBack,
    required this.appColors,
  });

  @override
  State<HiddenItemsScreen> createState() => _HiddenItemsScreenState();
}

class _HiddenItemsScreenState extends State<HiddenItemsScreen> {
  final HiddenItemsManager _hiddenManager = HiddenItemsManager.instance;
  int _selectedTab = 0; // 0: Todos, 1: Carpetas, 2: Canciones

  @override
  void initState() {
    super.initState();
    _hiddenManager.addListener(_refresh);
  }

  @override
  void dispose() {
    _hiddenManager.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final allItems = _hiddenManager.hiddenItems;

    final filteredItems = _selectedTab == 1
        ? allItems.where((i) => i.isFolder).toList()
        : _selectedTab == 2
            ? allItems.where((i) => !i.isFolder).toList()
            : allItems;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 16),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onBack();
          },
        ),
        title: Text(
          'Elementos Ocultos',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs Bencho Glass
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos (${allItems.length})', 0),
                  const SizedBox(width: 8),
                  _buildFilterChip('Carpetas (${allItems.where((i) => i.isFolder).length})', 1),
                  const SizedBox(width: 8),
                  _buildFilterChip('Canciones (${allItems.where((i) => !i.isFolder).length})', 2),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: colors.isDark ? const Color(0x4418181C) : const Color(0xA0F6F6F8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.visibility_off_rounded, color: Color(0xFF1DB954), size: 34),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No hay elementos ocultos',
                            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Los archivos o carpetas que ocultes desde Inicio aparecerán aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 120),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (item.isFolder ? const Color(0xFFFFB300) : const Color(0xFF1DB954)).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item.isFolder ? Icons.folder_rounded : Icons.music_note_rounded,
                                  color: item.isFolder ? const Color(0xFFFFB300) : const Color(0xFF1DB954),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.path,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  await _hiddenManager.unhideItem(item.path);
                                  await widget.homeProvider.rescan();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1DB954).withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.restore_rounded, color: Color(0xFF1DB954), size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Mostrar',
                                        style: TextStyle(
                                          color: Color(0xFF1DB954),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final colors = widget.appColors;
    final isSelected = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1DB954)
              : (colors.isDark ? const Color(0x441C1C22) : const Color(0xB8FFFFFF)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1DB954)
                : (colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1DB954).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
