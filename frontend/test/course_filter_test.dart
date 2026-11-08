import 'package:edutrack/viewmodels/course_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_env.dart';

void main() {
  late TestEnv env;
  late CourseViewModel vm;

  setUp(() async {
    env = TestEnv.create();
    await env.courses.create(env.courseFields('Mobile App Development', 'CI6330'));
    await env.courses.create(env.courseFields('Databases', 'CI5100'));
    await env.courses.create(env.courseFields('Algorithms', 'CI4200'));
    vm = CourseViewModel(env.courses);
    await vm.load();
  });
  tearDown(() => env.db.close());

  test('search matches name or code, case-insensitive', () {
    vm.setQuery('data');
    expect(vm.filtered.map((c) => c.name), ['Databases']);
    vm.setQuery('ci6330');
    expect(vm.filtered.map((c) => c.name), ['Mobile App Development']);
    vm.setQuery('zzz');
    expect(vm.filtered, isEmpty);
  });

  test('sort by name and by code', () {
    vm.setSort(CourseSort.nameAsc);
    expect(vm.filtered.map((c) => c.name), ['Algorithms', 'Databases', 'Mobile App Development']);
    vm.setSort(CourseSort.codeAsc);
    expect(vm.filtered.map((c) => c.code), ['CI4200', 'CI5100', 'CI6330']);
  });
}
