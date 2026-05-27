import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';

class RateDonorScreen extends StatefulWidget {
  final String donorId;
  final String donorName;
  final String requestId;

  const RateDonorScreen({
    super.key,
    required this.donorId,
    required this.donorName,
    required this.requestId,
  });

  @override
  State<RateDonorScreen> createState() => _RateDonorScreenState();
}

class _RateDonorScreenState extends State<RateDonorScreen> {
  int _stars = 5;
  bool _punctual = false;
  bool _professional = false;
  bool _helpful = false;
  bool _isSubmitting = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate Donor')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Donor header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.volunteer_activism,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.donorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thank you for donating!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Star rating
            Text(
              'Overall Rating',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _stars = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _stars ? Icons.star : Icons.star_border,
                      color: AppColors.urgent,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Quick tags
            Text(
              'Quick Feedback',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FeedbackChip(
                  label: '⏰ Punctual',
                  selected: _punctual,
                  onTap: () => setState(() => _punctual = !_punctual),
                ),
                _FeedbackChip(
                  label: '👔 Professional',
                  selected: _professional,
                  onTap: () =>
                      setState(() => _professional = !_professional),
                ),
                _FeedbackChip(
                  label: '🤝 Helpful',
                  selected: _helpful,
                  onTap: () => setState(() => _helpful = !_helpful),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Optional comment
            Text(
              'Additional Comments (Optional)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Any feedback for this donor...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.eligible,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Rating',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Skip',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitRating() async {
    setState(() => _isSubmitting = true);

    try {
      final tags = <String>[];
      if (_punctual) tags.add('punctual');
      if (_professional) tags.add('professional');
      if (_helpful) tags.add('helpful');

      await Supabase.instance.client.from('donor_ratings').insert({
        'donor_id': widget.donorId,
        'request_id': widget.requestId,
        'stars': _stars,
        'rating_score': _stars,
        'punctual': _punctual,
        'professional': _professional,
        'helpful': _helpful,
        'tags': tags,
        'comment': _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted! Thank you.'),
            backgroundColor: AppColors.eligible,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _FeedbackChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FeedbackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.eligible.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.eligible : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.eligible : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
