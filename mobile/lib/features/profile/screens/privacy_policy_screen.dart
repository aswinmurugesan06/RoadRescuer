import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/glass.dart';
import '../../../widgets/rr_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <Map<String, String>>[
    {
      'title': 'Information we collect',
      'body':
          'We collect your name, email address, mobile number, role, vehicle details and service history when you create or use a RoadRescue account. During an active request we also process your approximate or precise location, the issue description, and any damage photo you choose to upload.',
    },
    {
      'title': 'How we use your information',
      'body':
          'Your data is used to authenticate you, match your request with a suitable provider, calculate distance and cost estimates, show live assistance status, prepare the technician with tools and parts, process payments, and provide customer support. We do not sell your personal information.',
    },
    {
      'title': 'Location data',
      'body':
          'Location is used to detect your breakdown spot, estimate provider travel distance, and show live tracking while a request is active. You can disable device location permissions, but GPS confirmation is required to dispatch a provider.',
    },
    {
      'title': 'Damage photos and AI analysis',
      'body':
          'Damage photos are compressed before upload. They may be stored in Cloudinary or as a Base64 image on the service request when Cloudinary is unavailable. The image and a description of the visible damage are sent to Google Gemini Vision to suggest a category, severity, tools and spare parts. The AI result is an estimate and is not a certified inspection.',
    },
    {
      'title': 'Sharing with providers',
      'body':
          'Before a provider accepts your request, contact details are masked. After acceptance, the assigned provider can see the customer name, mobile number, vehicle, breakdown location, damage report and invoice details needed to complete the job.',
    },
    {
      'title': 'Payments and billing',
      'body':
          'Payment transactions are processed through Razorpay or recorded as cash settlements. RoadRescue stores invoice totals, payment status and transaction references, but does not store full card numbers or UPI credentials.',
    },
    {
      'title': 'Security',
      'body':
          'Authentication is handled by Firebase Authentication. Firestore security rules restrict customer, provider and admin access to the data they need. Traffic between the app and our services uses encrypted HTTPS connections.',
    },
    {
      'title': 'Retention and deletion',
      'body':
          'Service and payment records are retained for support, accounting and dispute resolution. You can request deletion of your account and personal profile data by contacting support. Some records may be retained where required by law.',
    },
    {
      'title': 'Your choices',
      'body':
          'You can update your profile details, notification preference and vehicle information from the app. You can cancel an active request before work begins. You may contact us to access, correct or delete your personal data.',
    },
    {
      'title': 'Contact us',
      'body':
          'For privacy questions, use Profile → Support & Feedback → File a Complaint / Report Issue, or email privacy@roadrescue.in. Include your registered email or mobile number so we can locate your account.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Privacy Policy & Terms')),
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
                      icon: Icons.privacy_tip_outlined,
                      size: 44,
                      iconSize: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your privacy matters',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Last updated: November 2026',
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
              const SizedBox(height: 12),
              ..._sections.map(
                (section) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: RRCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section['title']!,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          section['body']!,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Questions about this policy?',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Read the FAQ or send a privacy request to our support team.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.35,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.faq,
                            ),
                            icon: const Icon(
                              Icons.help_outline_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Read FAQ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.complaint,
                            ),
                            icon: const Icon(
                              Icons.report_problem_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Contact support',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
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
