enum AppAccountRoleState { absent, active, deleting, deleted }

AppAccountRoleState appAccountRoleState(Map<String,dynamic>? profile,String role) {
  if(profile==null)return AppAccountRoleState.absent;
  if(profile['deletingRole']==role)return AppAccountRoleState.deleting;
  if(profile['deletionStatus']=='completed'||profile['deletedRoles']?[role]!=null)return AppAccountRoleState.deleted;
  final roles=profile['roles'];
  if(roles is List&&!roles.contains(role))return AppAccountRoleState.absent;
  if(profile['deletionStatus']=='pending')return AppAccountRoleState.deleting;
  if(roles is! List && profile['phone'] is! String)return AppAccountRoleState.absent;
  // Compatibility for an existing profile created before explicit role lists.
  return AppAccountRoleState.active;
}

String appAccountName(Map<String,dynamic> profile,String role) =>
    profile[role+'Name'] as String? ?? profile['name'] as String? ?? '';
