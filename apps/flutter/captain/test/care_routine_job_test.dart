import 'package:flutter_test/flutter_test.dart';
import 'package:washkrew_captain/features/v2_job.dart';

// v2 CU-CARE (12 Nov): the owner's vehicle details and care routine reach the job.
void main() {
  test('vehicle profile and care routine are read from the order', () {
    final e = JobExtras.fromOrder({
      'vehicleProfile': {'make': 'Hyundai', 'model': 'Creta', 'color': 'White', 'finish': 'matte', 'seats': 'leather', 'source': 'ai'},
      'careRoutine': [{'title': 'Matte-safe wash', 'detail': 'No wax or polish.'}, {'title': 'Leather seats: no water'}],
    });
    expect(e.vehicleName, 'Hyundai Creta · White · Matte paint · Leather seats');
    expect(e.care, [('Matte-safe wash', 'No wax or polish.'), ('Leather seats: no water', '')]);
    expect(JobExtras.fromOrder({}).vehicleName, isNull);
  });
}
