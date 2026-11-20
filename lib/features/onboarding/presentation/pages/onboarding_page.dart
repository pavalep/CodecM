import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final Set<String> _selectedTopics = {
    'Frontier AI & LLMs',
    'Venture & Startups',
    'Semiconductor Physics',
  };

  final List<String> _allTopics = [
    'Frontier AI & LLMs',
    'Venture & Startups',
    'Semiconductor Physics',
    'Bio & Synthetic Genomics',
    'Epistemology & Philosophy',
    'Macroeconomics & Markets',
    'Space & Theoretical Physics',
    'Deep Investigative Tech',
    'Founder Psychology & Leadership',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Progress and Skip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 28, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Container(width: 28, height: 4, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Container(width: 28, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                    ],
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Skip', style: AppTypography.labelLg(color: AppColors.textSecondary)),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '100% On-Device Personalization',
                  style: AppTypography.labelSm(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Calibrate Your Neural\nListening Space',
                style: AppTypography.displayEditorial(fontSize: 26, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Select topics to tune recommendations on your device. Your taste graph stays strictly private.',
                style: AppTypography.bodyLg(color: AppColors.textSecondary, fontSize: 13.5),
              ),

              const SizedBox(height: 24),

              // Topic Chips Wrap
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _allTopics.map((topic) {
                      final isSelected = _selectedTopics.contains(topic);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTopics.remove(topic);
                            } else {
                              _selectedTopics.add(topic);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: 1.0,
                            ),
                            boxShadow: isSelected ? AppColors.primaryGlow(blur: 10) : AppColors.cardShadow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                topic,
                                style: AppTypography.labelLg(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Bottom Action Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Synthesize My First Mix',
                        style: AppTypography.labelLg(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
