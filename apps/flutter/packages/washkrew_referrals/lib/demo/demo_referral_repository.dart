import '../src/model.dart';

/// DESIGN FIXTURE ONLY. Never include this file in production integration.
/// The real repository must read server-derived progress and awards.
class DemoReferralRepository extends ReferralRepository {
  DemoReferralRepository({required this.actorId, int progress = 4}) {
    final role = identity.role;
    if (actorId == 'captain_raju') {
      _links.add(
        ReferralProgress(
          id: 'cap_maya',
          referrerId: actorId,
          referredId: 'captain_maya',
          name: 'Maya S.',
          role: role,
          completedWashes: progress,
        ),
      );
    } else if (actorId == 'customer_ananya') {
      _links.add(
        ReferralProgress(
          id: 'cust_neha',
          referrerId: actorId,
          referredId: 'customer_neha',
          name: 'Neha S.',
          role: role,
          completedWashes: progress,
        ),
      );
      _links.add(
        const ReferralProgress(
          id: 'cust_rohan',
          referrerId: 'customer_ananya',
          referredId: 'customer_rohan',
          name: 'Rohan K.',
          role: ReferralRole.customer,
          completedWashes: 2,
        ),
      );
    }
    _settleFixtures();
  }
  final String actorId;
  static const identities = <ReferralIdentity>[
    ReferralIdentity(
      id: 'customer_new',
      role: ReferralRole.customer,
      name: 'New Customer',
      code: 'WKNEWC62',
    ),
    ReferralIdentity(
      id: 'captain_raju',
      role: ReferralRole.captain,
      name: 'Raju Yadav',
      code: 'WKRAJU7X',
    ),
    ReferralIdentity(
      id: 'captain_maya',
      role: ReferralRole.captain,
      name: 'Maya S.',
      code: 'WKMAYA42',
    ),
    ReferralIdentity(
      id: 'captain_new',
      role: ReferralRole.captain,
      name: 'New Captain',
      code: 'WKNEW8K2',
    ),
    ReferralIdentity(
      id: 'customer_ananya',
      role: ReferralRole.customer,
      name: 'Ananya Rao',
      code: 'WKANAY84',
    ),
    ReferralIdentity(
      id: 'customer_neha',
      role: ReferralRole.customer,
      name: 'Neha S.',
      code: 'WKNEHA52',
    ),
    ReferralIdentity(
      id: 'customer_rohan',
      role: ReferralRole.customer,
      name: 'Rohan K.',
      code: 'WKROHN39',
    ),
  ];
  final _links = <ReferralProgress>[];
  final _rewards = <String, ReferralReward>{};
  final _processedWashIds = <String>{};
  @override
  ReferralIdentity get identity =>
      identities.firstWhere((u) => u.id == actorId);
  @override
  List<ReferralProgress> get outgoing =>
      List.unmodifiable(_links.where((r) => r.referrerId == actorId));
  @override
  ReferralProgress? get incoming =>
      _links.where((r) => r.referredId == actorId).firstOrNull;
  @override
  List<ReferralReward> get rewards => List.unmodifiable(
    _rewards.values.where((r) => r.beneficiaryId == actorId),
  );
  List<ReferralReward> get adminRewards => List.unmodifiable(_rewards.values);
  List<ReferralProgress> get adminLinks => List.unmodifiable(_links);
  @override
  String get inviteUrl =>
      // v2: on a phone there is no local studio; show the public site link shape.
      Uri.base.scheme == 'http' || Uri.base.scheme == 'https'
      ? '${Uri.base.origin}/app/${identity.role == ReferralRole.captain ? 'captain/?start=signup' : '?start=referral-join'}&ref=${identity.code}'
      : 'https://washkrew.com/?ref=${identity.code}';
  @override
  String? validateCode(String raw) {
    final code = ReferralPolicy.normalizeCode(raw);
    if (code.isEmpty) return null;
    final match = identities.where((u) => u.code == code).firstOrNull;
    if (match == null)
      return 'That code was not found. Check it and try again.';
    if (match.role != identity.role)
      return 'Use a ${identity.role.name} referral code.';
    if (match.id == actorId) return 'You cannot use your own referral code.';
    if (_links.any((r) => r.referrerId == actorId && r.referredId == match.id))
      return 'A referral cannot link back to your own invitee.';
    if (incoming != null && incoming!.referrerId != match.id)
      return 'A referral is already linked to this account.';
    return null;
  }

  @override
  Future<void> attachCode(String raw) async {
    final code = ReferralPolicy.normalizeCode(raw);
    if (code.isEmpty) return;
    final error = validateCode(code);
    if (error != null) throw StateError(error);
    if (incoming != null) return;
    final referrer = identities.firstWhere((u) => u.code == code);
    _links.add(
      ReferralProgress(
        id: '${identity.role.name}_${referrer.id}_$actorId',
        referrerId: referrer.id,
        referredId: actorId,
        name: identity.name,
        role: identity.role,
        completedWashes: 0,
      ),
    );
    notifyListeners();
  }

  /// Scenario control outside the product screens. Represents server-verified,
  /// completed washes, never booking purchases or a client countdown.
  void simulateVerifiedCompletion({
    required String referralId,
    required String washId,
    bool completed = true,
    bool paid = true,
    bool cancelled = false,
    bool disputed = false,
    bool freeRewardWash = false,
  }) {
    if (!completed || cancelled || disputed) return;
    final link = _links.firstWhere((r) => r.id == referralId);
    if (link.role == ReferralRole.customer && (!paid || freeRewardWash)) return;
    if (!_processedWashIds.add(washId)) return;
    final i = _links.indexOf(link);
    _links[i] = link.withCount(link.completedWashes + 1);
    _settleFixtures();
    notifyListeners();
  }

  void _award(
    ReferralProgress p,
    String beneficiary,
    int milestone,
    RewardKind kind,
    int paise,
  ) {
    final id =
        '${ReferralPolicy.version}/${p.id}/$milestone/$beneficiary/${kind.name}';
    _rewards.putIfAbsent(
      id,
      () => ReferralReward(
        id: id,
        beneficiaryId: beneficiary,
        referralId: p.id,
        milestone: milestone,
        kind: kind,
        state: kind == RewardKind.cash
            ? RewardState.payoutPending
            : RewardState.available,
        amountPaise: paise,
      ),
    );
  }

  void _settleFixtures() {
    for (final p in _links) {
      if (p.completedWashes < 5) continue;
      if (p.role == ReferralRole.customer) {
        _award(p, p.referrerId, 5, RewardKind.premiumWash, 0);
      } else {
        _award(p, p.referrerId, 5, RewardKind.cash, 5000);
        _award(p, p.referredId, 5, RewardKind.cash, 5000);
        if (p.completedWashes >= 50)
          _award(p, p.referrerId, 50, RewardKind.cash, 50000);
      }
    }
  }

  @override
  Future<String> reservePremiumWash(String id) async {
    final r = _rewards[id];
    if (r == null ||
        r.beneficiaryId != actorId ||
        r.kind != RewardKind.premiumWash)
      throw StateError('This reward is unavailable.');
    if (r.state == RewardState.reserved) return id;
    if (r.state != RewardState.available)
      throw StateError('This reward is already used.');
    _rewards[id] = r.withState(RewardState.reserved);
    notifyListeners();
    return id;
  }

  @override
  Future<void> releasePremiumWash(String id) async {
    final r = _rewards[id];
    if (r != null &&
        r.beneficiaryId == actorId &&
        r.state == RewardState.reserved) {
      _rewards[id] = r.withState(RewardState.available);
      notifyListeners();
    }
  }

  @override
  Future<void> confirmPremiumWashUse(String id) async {
    final r = _rewards[id];
    if (r == null || r.beneficiaryId != actorId)
      throw StateError('Reward not found.');
    if (r.state == RewardState.redeemed) return;
    if (r.state != RewardState.reserved)
      throw StateError('Reserve the reward first.');
    _rewards[id] = r.withState(RewardState.redeemed);
    notifyListeners();
  }
}
