import 'package:flutter/widgets.dart';
import 'components.dart';

/// A choice for this booking only, never a blanket or preselected permission.
const aiPhotoConsentVersion = 'vehicle-after-photos-v1';

Future<bool?> requestAiPhotoConsent(BuildContext context) async {
  bool? allowed;
  await showWAlert(
    context,
    title: 'Allow Google AI photo check?',
    message:
        'Send this booking’s 4 after-wash vehicle photos to Google Vertex AI (Gemini) for dirt/photo-quality suggestions? Plates and surroundings may be visible. Aadhaar, selfies and bank details are excluded.\n\nOptional: without AI, the Customer still reviews the photos. AI does not approve washes or decide disputes.',
    actions: [
      AlertAction(
        'Continue without AI',
        cancel: true,
        onTap: () => allowed = false,
      ),
      AlertAction('Allow AI check', onTap: () => allowed = true),
    ],
  );
  return allowed;
}
