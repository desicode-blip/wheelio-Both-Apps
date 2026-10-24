import 'package:flutter_test/flutter_test.dart';
import 'package:wheelio_customer/data/models.dart';
void main(){
 test('repeating a booking retains the approved typed-address reference',(){
  const society=Society('served','Building','Area','Hyderabad','500089');
  final place=Place(society,tower:'Tower A',floor:'B1',slot:'42',addressKey:'approved-address');
  expect(place.copy().addressKey,'approved-address');
  expect(place.key,isNot(Place(society,tower:'Tower A',floor:'B1',slot:'42').key));
 });
}
