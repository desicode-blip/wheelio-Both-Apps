import 'package:flutter/foundation.dart';

enum ReferralRole { customer, captain }

enum RewardKind { cash, premiumWash }

enum RewardState { available, reserved, redeemed, payoutPending, paid }

enum ReferralLanguage { en, hi, te }

class ReferralIdentity {
  const ReferralIdentity({
    required this.id,
    required this.role,
    required this.name,
    required this.code,
  });
  final String id, name, code;
  final ReferralRole role;
}

class ReferralProgress {
  const ReferralProgress({
    required this.id,
    required this.referrerId,
    required this.referredId,
    required this.name,
    required this.role,
    required this.completedWashes,
  });
  final String id, referrerId, referredId, name;
  final ReferralRole role;
  final int completedWashes;
  int get firstRemaining => (5 - completedWashes).clamp(0, 5);
  int get finalRemaining => (50 - completedWashes).clamp(0, 50);
  ReferralProgress withCount(int count) => ReferralProgress(
    id: id,
    referrerId: referrerId,
    referredId: referredId,
    name: name,
    role: role,
    completedWashes: count,
  );
}

class ReferralReward {
  const ReferralReward({
    required this.id,
    required this.beneficiaryId,
    required this.referralId,
    required this.milestone,
    required this.kind,
    required this.state,
    this.amountPaise = 0,
  });
  final String id, beneficiaryId, referralId;
  final int milestone, amountPaise;
  final RewardKind kind;
  final RewardState state;
  ReferralReward withState(RewardState value) => ReferralReward(
    id: id,
    beneficiaryId: beneficiaryId,
    referralId: referralId,
    milestone: milestone,
    kind: kind,
    state: value,
    amountPaise: amountPaise,
  );
}

/// Pure milestone specification. This does not grant money/credits on a client.
class ReferralPolicy {
  static const version = 'owner-2026-11-06-v1';
  static const firstMilestone = 5;
  static const finalCaptainMilestone = 50;
  static const firstCaptainRewardPaise = 5000;
  static const finalCaptainRewardPaise =
      50000; // ADDITIONAL: referrer total ₹550.
  static int referrerCashEntitlement(int completed) => completed < 5
      ? 0
      : completed < 50
      ? 5000
      : 55000;
  static int inviteeCashEntitlement(int completed) => completed >= 5 ? 5000 : 0;
  static int premiumWashEntitlement(int completed) => completed >= 5 ? 1 : 0;
  static String normalizeCode(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();
}

/// Read models and authenticated commands only. Qualification and award issuance
/// belong to a server transaction. No wash-count increment API is exposed here.
abstract class ReferralRepository extends ChangeNotifier {
  ReferralIdentity get identity;
  List<ReferralProgress> get outgoing;
  ReferralProgress? get incoming;
  List<ReferralReward> get rewards;
  String? validateCode(String raw);
  Future<void> attachCode(String raw);
  Future<String> reservePremiumWash(String rewardId);
  Future<void> releasePremiumWash(String rewardId);
  Future<void> confirmPremiumWashUse(String rewardId);
  String get inviteUrl;
  int get pendingCashPaise => rewards
      .where(
        (r) =>
            r.kind == RewardKind.cash && r.state == RewardState.payoutPending,
      )
      .fold(0, (s, r) => s + r.amountPaise);
  List<ReferralReward> get availablePremiumWashes => rewards
      .where(
        (r) =>
            r.kind == RewardKind.premiumWash &&
            r.state == RewardState.available,
      )
      .toList();
}

class ReferralCopy {
  const ReferralCopy(this.language);
  final ReferralLanguage language;
  String t(String en, String hi, String te) => switch (language) {
    ReferralLanguage.en => en,
    ReferralLanguage.hi => hi,
    ReferralLanguage.te => te,
  };
  String get referrals => t('Referrals', 'रेफ़रल', 'రిఫరల్స్');
  String get inviteCaptain =>
      t('Invite a Captain', 'कैप्टन को बुलाएँ', 'కెప్టెన్‌ను ఆహ్వానించండి');
  String get inviteCustomer =>
      t('Invite a friend', 'दोस्त को बुलाएँ', 'స్నేహితుడిని ఆహ్వానించండి');
  String get yourCode =>
      t('Your referral code', 'आपका रेफ़रल कोड', 'మీ రిఫరల్ కోడ్');
  String get copyLink =>
      t('Copy invite link', 'लिंक कॉपी करें', 'లింక్ కాపీ చేయండి');
  String get progress => t('Your referrals', 'आपके रेफ़रल', 'మీ రిఫరల్స్');
  String get rewards => t('Your rewards', 'आपके इनाम', 'మీ రివార్డులు');
  String get completed =>
      t('completed washes', 'पूरे किए गए वॉश', 'పూర్తయిన వాష్‌లు');
  String get pending => t(
    'Earned · payout pending',
    'कमाया · भुगतान बाकी',
    'సంపాదించారు · చెల్లింపు పెండింగ్',
  );
  String get paid => t('Paid', 'भुगतान हुआ', 'చెల్లించారు');
  String get referred =>
      t('Referred by someone?', 'किसी ने रेफ़र किया?', 'ఎవరైనా రిఫర్ చేశారా?');
  String get codeLabel => t(
    'Referral code (optional)',
    'रेफ़रल कोड (वैकल्पिक)',
    'రిఫరల్ కోడ్ (ఐచ్ఛికం)',
  );
  String get useWash => t(
    'Use a free Premium wash',
    'मुफ़्त Premium वॉश इस्तेमाल करें',
    'ఉచిత Premium వాష్ వాడండి',
  );
}
