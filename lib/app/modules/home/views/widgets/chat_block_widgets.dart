// lib/app/modules/home/views/widgets/chat_block_widgets.dart
//
// Renders the structured `blocks` array that the backend sends alongside
// every assistant_text response. The backend sends one of these block types:
//   • table       — a scrollable data table (attendance, approvals, etc.)
//   • actions     — clickable pill buttons ("Correct 2026-09-02", etc.)
//   • kpi_cards   — a horizontal row of stat cards
//   • info        — a highlighted info/warning panel
//
// Usage: ChatBlockList(blocks: message.blocks, onAction: (text) => sendMessage(text))

import 'package:flutter/material.dart';

// ─── Main entry point ────────────────────────────────────────────────────────

class ChatBlockList extends StatelessWidget {
  const ChatBlockList({
    super.key,
    required this.blocks,
    required this.onAction,
  });

  final List<Map<String, dynamic>> blocks;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks) ...[
          const SizedBox(height: 10),
          _buildBlock(block, context),
        ],
      ],
    );
  }

  Widget _buildBlock(Map<String, dynamic> block, BuildContext context) {
    final type = block['type']?.toString() ?? '';
    switch (type) {
      case 'table':
        return _TableBlock(block: block, onAction: onAction);
      case 'actions':
        return _ActionsBlock(block: block, onAction: onAction);
      case 'kpi_cards':
        return _KpiCardsBlock(block: block);
      case 'info':
        return _InfoBlock(block: block);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Table Block ─────────────────────────────────────────────────────────────

class _TableBlock extends StatefulWidget {
  const _TableBlock({required this.block, required this.onAction});
  final Map<String, dynamic> block;
  final ValueChanged<String> onAction;

  @override
  State<_TableBlock> createState() => _TableBlockState();
}

class _TableBlockState extends State<_TableBlock> {
  static const _initialRowCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.block['title']?.toString() ?? 'Data';
    final rawColumns = widget.block['columns'] as List? ?? [];
    final rawRows = widget.block['rows'] as List? ?? [];

    final columns = rawColumns.map((c) => c.toString()).toList();
    final allRows = rawRows
        .map((r) => (r as List).map((cell) => cell.toString()).toList())
        .toList();
    final visibleRows =
        _expanded ? allRows : allRows.take(_initialRowCount).toList();
    final hasMore = allRows.length > _initialRowCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EDF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E6A9B).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A8C6A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${allRows.length} rows',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // ── Table ────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 44,
              horizontalMargin: 12,
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFF1F8F5),
              ),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: const Color(0xFFE8EFF5),
                  width: 1,
                ),
              ),
              columns: columns
                  .map(
                    (col) => DataColumn(
                      label: Text(
                        col.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              rows: visibleRows.asMap().entries.map((entry) {
                final isEven = entry.key.isEven;
                final cells = entry.value;
                return DataRow(
                  color: WidgetStateProperty.all(
                    isEven ? Colors.white : const Color(0xFFF8FCFA),
                  ),
                  cells: cells
                      .map(
                        (cell) => DataCell(
                          Text(
                            cell,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
          ),
          // ── Show More / Less toggle ──────────────────────────────
          if (hasMore)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A8C6A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(
                  _expanded
                      ? 'Show less'
                      : 'Show all ${allRows.length} rows',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─── Actions Block ────────────────────────────────────────────────────────────

class _ActionsBlock extends StatelessWidget {
  const _ActionsBlock({required this.block, required this.onAction});
  final Map<String, dynamic> block;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final title = block['title']?.toString() ?? 'Available actions';
    final items = (block['items'] as List? ?? []).map((i) => i.toString()).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EDF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E6A9B).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded,
                  size: 15, color: Color(0xFF1A8C6A)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => _ActionChip(
                      label: item,
                      onTap: () => onAction(item),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  const _ActionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0xFF158A66)
                : const Color(0xFF1A8C6A),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A8C6A).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── KPI Cards Block ─────────────────────────────────────────────────────────

class _KpiCardsBlock extends StatelessWidget {
  const _KpiCardsBlock({required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final title = block['title']?.toString();
    final cards = (block['cards'] as List? ?? [])
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _KpiCard(card: cards[i], index: i),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.card, required this.index});
  final Map<String, dynamic> card;
  final int index;

  static const _palette = [
    Color(0xFF1A8C6A),
    Color(0xFF1E6A9B),
    Color(0xFF7758A1),
    Color(0xFFB76514),
    Color(0xFF3769A5),
  ];

  @override
  Widget build(BuildContext context) {
    final label = card['label']?.toString() ?? card['title']?.toString() ?? '';
    final value = card['value']?.toString() ?? '';
    final sub = card['sub']?.toString() ?? card['subtitle']?.toString();
    final colorIdx = (card['color_index'] as int?) ?? index;
    final color = _palette[colorIdx % _palette.length];

    return Container(
      width: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withOpacity(0.75)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Info Block ────────────────────────────────────────────────────────────────

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.block});
  final Map<String, dynamic> block;

  @override
  Widget build(BuildContext context) {
    final text =
        block['text']?.toString() ?? block['message']?.toString() ?? '';
    final isWarning = block['level']?.toString() == 'warning';
    if (text.isEmpty) return const SizedBox.shrink();

    const warnColor = Color(0xFFB76514);
    const infoColor = Color(0xFF1A8C6A);
    final color = isWarning ? warnColor : infoColor;
    final bgColor = isWarning
        ? const Color(0xFFFFF7ED)
        : const Color(0xFFEFF9F5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
