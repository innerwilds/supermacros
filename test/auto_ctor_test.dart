import 'package:supermacros/supermacros.dart';
import 'package:test/test.dart';

@AutoCtor()
@AutoCtor(name: 'named')
class BeeBaaBoo {
  final int bee;
  final int _baa;
  final int? boo;
  final int? _bee;
  final int? __bee;
  final int? ___bee;
}

void main() {
  test("BeeBaaBoo has auto-generated class", () {
    expect(() {
      BeeBaaBoo.named(bee: 1, baa: 2, boo: 2, bee2: 3, bee3: 4, bee1: 2);
      BeeBaaBoo(bee: 1, baa: 2, boo: 2, bee2: 3, bee3: 4, bee1: 2);
    }, returnsNormally);
  });
}