import 'package:flutter/material.dart';
import 'package:path_mobile/ui/core/app_theme.dart';
import 'package:path_mobile/ui/core/page_frame.dart';
import 'package:path_mobile/ui/core/responsive.dart';

enum _AiRoleFilter { all, guru, siswa }

enum _AiSortOption { nama, penggunaan }

class _AiUsageItem {
  final String nama;
  final bool isGuru;
  final String detail;
  final int aiUsage;

  const _AiUsageItem({
    required this.nama,
    required this.isGuru,
    required this.detail,
    required this.aiUsage,
  });
}

/// Placeholder Admin Beranda screen displaying school statistics summary
/// and AI usage overview styled after `Beranda Admin.png`.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _guruColor = AppColors.color1;
  static const Color _siswaColor = Color(0xFF8E54E9);
  static const Color _eventColor = Color(0xFF34C759);

  static const List<_AiUsageItem> _placeholderUsage = [
    _AiUsageItem(
      nama: 'Eko Kusnandar',
      isGuru: true,
      detail: 'Pemrograman Web (Kelas X PPLG 1, X PPLG 2)',
      aiUsage: 25,
    ),
    _AiUsageItem(
      nama: 'Siti Rahmawati',
      isGuru: true,
      detail: 'Basis Data (Kelas XI PPLG 1)',
      aiUsage: 14,
    ),
    _AiUsageItem(
      nama: 'Budi Santoso',
      isGuru: true,
      detail: 'Matematika Wajib (Kelas X PPLG 1)',
      aiUsage: 8,
    ),
    _AiUsageItem(
      nama: 'Aji Sasongko',
      isGuru: false,
      detail: 'Kelas X PPLG 1',
      aiUsage: 7,
    ),
    _AiUsageItem(
      nama: 'Dewi Lestari',
      isGuru: false,
      detail: 'Kelas X PPLG 1',
      aiUsage: 5,
    ),
    _AiUsageItem(
      nama: 'Rizky Pratama',
      isGuru: false,
      detail: 'Kelas X PPLG 2',
      aiUsage: 3,
    ),
    _AiUsageItem(
      nama: 'Nadia Putri',
      isGuru: false,
      detail: 'Kelas X PPLG 2',
      aiUsage: 2,
    ),
  ];

  _AiRoleFilter _roleFilter = _AiRoleFilter.all;
  _AiSortOption _sortOption = _AiSortOption.nama;

  List<_AiUsageItem> get _displayedItems {
    final items = _placeholderUsage.where((item) {
      return switch (_roleFilter) {
        _AiRoleFilter.all => true,
        _AiRoleFilter.guru => item.isGuru,
        _AiRoleFilter.siswa => !item.isGuru,
      };
    }).toList();

    switch (_sortOption) {
      case _AiSortOption.nama:
        items.sort((a, b) => a.nama.compareTo(b.nama));
      case _AiSortOption.penggunaan:
        items.sort((a, b) => b.aiUsage.compareTo(a.aiUsage));
    }
    return items;
  }

  void _toggleRole(_AiRoleFilter tapped) {
    setState(() {
      _roleFilter = _roleFilter == tapped ? _AiRoleFilter.all : tapped;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _displayedItems;

    return PageFrame(
      breadcrumb: const ['Admin'],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final hPad = responsiveHorizontalInset(width, maxWidth: 900);
          final fourCol = width >= 820;

          final statCards = const [
            _StatSummaryCard(
              title: 'Total Guru',
              value: '3 Guru',
              badgeLabel: 'Pakai AI: 25x',
              badgeColor: _guruColor,
            ),
            _StatSummaryCard(
              title: 'Total Siswa',
              value: '4 Siswa',
              badgeLabel: 'Pakai AI: 17x',
              badgeColor: _siswaColor,
            ),
            _StatSummaryCard(
              title: 'Total Pakai AI (Semua)',
              value: '42 Kali',
              badgeLabel: 'Bulan ini',
              badgeColor: AppColors.error,
            ),
            _StatSummaryCard(
              title: 'Total Event',
              value: '3 Event',
              badgeLabel: 'September',
              badgeColor: _eventColor,
            ),
          ];

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              const Text(
                'Rangkuman Statistik Sekolah',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              if (fourCol)
                Row(
                  children: [
                    for (var i = 0; i < statCards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: statCards[i]),
                    ],
                  ],
                )
              else ...[
                _StatRowPair(left: statCards[0], right: statCards[1]),
                const SizedBox(height: 12),
                _StatRowPair(left: statCards[2], right: statCards[3]),
              ],
              const SizedBox(height: 24),
              const Text(
                'Ringkasan Penggunaan AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 170,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Urutkan berdasarkan',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        DropdownButton<_AiSortOption>(
                          value: _sortOption,
                          isExpanded: true,
                          isDense: true,
                          underline: Container(
                            height: 1,
                            color: AppColors.text.withValues(alpha: 0.7),
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.text,
                            fontWeight: FontWeight.w500,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: _AiSortOption.nama,
                              child: Text('Nama'),
                            ),
                            DropdownMenuItem(
                              value: _AiSortOption.penggunaan,
                              child: Text('Penggunaan AI'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _sortOption = v);
                          },
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _RoleFilterChip(
                        key: const Key('admin_ai_filter_guru'),
                        label: 'Guru',
                        color: _siswaColor,
                        selected: _roleFilter == _AiRoleFilter.guru,
                        dimmed: _roleFilter == _AiRoleFilter.siswa,
                        onTap: () => _toggleRole(_AiRoleFilter.guru),
                      ),
                      _RoleFilterChip(
                        key: const Key('admin_ai_filter_siswa'),
                        label: 'Siswa',
                        color: _guruColor,
                        selected: _roleFilter == _AiRoleFilter.siswa,
                        dimmed: _roleFilter == _AiRoleFilter.guru,
                        onTap: () => _toggleRole(_AiRoleFilter.siswa),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: Colors.black26),
                _AiUsageRow(
                  item: items[i],
                  accentColor: items[i].isGuru ? _guruColor : _siswaColor,
                ),
              ],
            ],
            ),
          );
        },
      ),
    );
  }
}

class _StatRowPair extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _StatRowPair({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String badgeLabel;
  final Color badgeColor;

  const _StatSummaryCard({
    required this.title,
    required this.value,
    required this.badgeLabel,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black26),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
              _PillBadge(label: badgeLabel, color: badgeColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _RoleFilterChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dimmed ? color.withValues(alpha: 0.45) : color,
      elevation: selected ? 4 : 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiUsageRow extends StatelessWidget {
  final _AiUsageItem item;
  final Color accentColor;

  const _AiUsageRow({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final roleLabel = item.isGuru ? 'Guru' : 'Siswa';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accentColor,
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.nama} ($roleLabel)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PillBadge(
            label: 'Pakai AI: ${item.aiUsage}x',
            color: accentColor,
          ),
        ],
      ),
    );
  }
}
