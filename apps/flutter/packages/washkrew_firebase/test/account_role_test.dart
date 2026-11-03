import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_firebase/washkrew_firebase.dart';

void main(){
 test('only the current active role can restore an account; tombstones and pending state cannot',(){
  expect(appAccountRoleState(null,'customer'),AppAccountRoleState.absent);
  expect(appAccountRoleState({},'customer'),AppAccountRoleState.absent);
  expect(appAccountRoleState({'roles':['captain'],'name':'Old'},'customer'),AppAccountRoleState.absent);
  expect(appAccountRoleState({'roles':['captain'],'deletingRole':'captain'},'captain'),AppAccountRoleState.deleting);
  expect(appAccountRoleState({'deletionStatus':'completed'},'customer'),AppAccountRoleState.deleted);
  expect(appAccountRoleState({'roles':['customer'],'deletedRoles':{'captain':1}},'captain'),AppAccountRoleState.deleted);
  expect(appAccountRoleState({'roles':['customer'],'deletedRoles':{'captain':1}},'customer'),AppAccountRoleState.active);
  expect(appAccountRoleState({'phone':'+919000000001','name':'Legacy'},'customer'),AppAccountRoleState.active);
 });
 test('a recreated role with a blank name does not inherit the other role name',(){
  expect(appAccountName({'name':'Captain','customerName':''},'customer'),'');
  expect(appAccountName({'name':'Legacy'},'customer'),'Legacy');
 });
}
