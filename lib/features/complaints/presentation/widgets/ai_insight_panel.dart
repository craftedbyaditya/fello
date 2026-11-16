import 'package:flutter/material.dart';

import '../../../../core/theme/fello_colors.dart';
import '../../../../domain/entities/complaint_task.dart';
import '../../../../domain/entities/feedback_analysis.dart';

class AiInsightPanel extends StatelessWidget {
  const AiInsightPanel({
    super.key,
    required this.analysis,
    this.task,
    this.onOpenTask,
  });

  final FeedbackAnalysis analysis;
  final ComplaintTask? task;
  final VoidCallback? onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FelloColors.accentSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FelloColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: FelloColors.accentDeep),
              SizedBox(width: 6),
              Text(
                'AI insights',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: FelloColors.accentDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(analysis.summary),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Tag(analysis.sentiment.label),
              _Tag(analysis.urgency.label),
              _Tag(analysis.primaryCategory),
              ...analysis.categories
                  .where((c) => c != analysis.primaryCategory)
                  .take(3)
                  .map(_Tag.new),
            ],
          ),
          if (analysis.positiveAspects.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Positives: ${analysis.positiveAspects.join(', ')}',
              style: const TextStyle(fontSize: 13, color: FelloColors.inkSoft),
            ),
          ],
          if (task != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onOpenTask,
              icon: const Icon(Icons.task_alt, size: 18),
              label: Text('Complaint: ${task!.status.label}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FelloColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FelloColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
