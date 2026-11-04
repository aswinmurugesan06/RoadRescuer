import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/glass.dart';
import '../../../widgets/rr_card.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = <Map<String, String>>[
    {
      'q': 'How do I request roadside assistance?',
      'a':
          'Open the customer home, tap “Request Instant Assistance”, choose your vehicle and service, describe the problem, confirm your GPS location, and send the request. Nearby providers are notified immediately.',
    },
    {
      'q': 'Which services are available?',
      'a':
          'RoadRescue supports mechanical repairs, tyre and puncture service, towing and recovery, battery jump-start, and emergency fuel delivery. Availability depends on the providers online near you.',
    },
    {
      'q': 'How is the repair cost calculated?',
      'a':
          'Your estimate includes a ₹199 emergency callout, ₹15/km beyond the first 5 km, auto-allocated labour at ₹250/hour, any estimated spare parts, a vehicle-type multiplier, and 18% GST. A provider may adjust the final invoice after on-site inspection.',
    },
    {
      'q': 'How does the AI damage assessment work?',
      'a':
          'You can take or upload a photo from Request Assistance or the Dynamic Cost Estimator. Gemini Vision identifies visible damage, suggests tools and spare parts, and fills the labour and parts estimate. If AI is unavailable, a safe smart fallback is used.',
    },
    {
      'q': 'What is the service PIN?',
      'a':
          'The 4-digit service PIN is shown on your Active Assistance screen. Share it with the technician only after they arrive in person. The provider must enter it before starting the repair.',
    },
    {
      'q': 'Can I track my provider?',
      'a':
          'Yes. Once a provider accepts your request, Active Assistance shows their live location, ETA and contact details when available.',
    },
    {
      'q': 'What payment methods are accepted?',
      'a':
          'You can pay through Razorpay UPI, credit or debit card, or cash directly to the technician. The invoice shows labour, parts and GST before payment.',
    },
    {
      'q': 'How do I cancel a request?',
      'a':
          'Open Active Assistance and use the cancel action while the request is still pending or before the provider starts the repair. Cancellation may not be available after work has begun.',
    },
    {
      'q': 'How do I contact support?',
      'a':
          'Use “File a Complaint / Report Issue” in Profile → Support & Feedback. Include your request ID and a short description so the team can investigate quickly.',
    },
    {
      'q': 'Is my data safe?',
      'a':
          'RoadRescue uses Firebase Authentication, Firestore security rules and encrypted HTTPS connections. Location and contact details are shared with a provider only when needed to fulfil your request.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Help & FAQ')),
      body: GlassBackground(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              const GlassCard(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    GlassIconBox(
                      icon: Icons.help_outline_rounded,
                      size: 44,
                      iconSize: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Frequently Asked Questions',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Tap a question to see the answer.',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._faqs.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FaqTile(
                    question: item['q']!,
                    answer: item['a']!,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Still need help?',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Send us your request ID and a short description. Our support team will follow up.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.complaint,
                        ),
                        icon: const Icon(
                          Icons.report_problem_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'File a Complaint / Report Issue',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return RRCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondaryLight,
          title: Text(
            question,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
