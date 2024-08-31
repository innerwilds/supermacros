import 'dart:async';

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';

// ignore_for_file: parameter_assignments

/// Returns a `hashCode` for [props].
int mapPropsToHashCode(Iterable<Object?> props) {
  return _finish(props.fold(0, _combine));
}

const DeepCollectionEquality _equality = DeepCollectionEquality();

/// Determines whether [list1] and [list2] are equal.
bool equals(List<Object?>? list1, List<Object?>? list2) {
  if (identical(list1, list2)) return true;
  if (list1 == null || list2 == null) return false;
  final length = list1.length;
  if (length != list2.length) return false;

  for (var i = 0; i < length; i++) {
    final unit1 = list1[i];
    final unit2 = list2[i];

    if (unit1 is Iterable || unit1 is Map) {
      if (!_equality.equals(unit1, unit2)) return false;
    } else if (unit1?.runtimeType != unit2?.runtimeType) {
      return false;
    } else if (unit1 != unit2) {
      return false;
    }
  }
  return true;
}

/// Jenkins Hash Functions
/// https://en.wikipedia.org/wiki/Jenkins_hash_function
int _combine(int hash, Object? object) {
  if (object is Map) {
    object.keys
        .sorted((Object? a, Object? b) => a.hashCode - b.hashCode)
        .forEach((Object? key) {
      hash = hash ^ _combine(hash, [key, (object! as Map)[key]]);
    });
    return hash;
  }
  if (object is Set) {
    object = object.sorted((Object? a, Object? b) => a.hashCode - b.hashCode);
  }
  if (object is Iterable) {
    for (final value in object) {
      hash = hash ^ _combine(hash, value);
    }
    return hash ^ object.length;
  }

  hash = 0x1fffffff & (hash + object.hashCode);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}

int _finish(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}

final _core = Uri.parse('package:data_class/src/equatable.dart');
final _dartCore = Uri.parse('dart:core');

/// Creates override of [hashCode] getter and [==] method based on all fields
/// or only on public.
macro class Equatable implements ClassDeclarationsMacro, ClassDefinitionMacro {
  /// Default ctor
  const Equatable({
    this.includePrivate = true,
  });

  /// Whether to include private fields or not
  final bool includePrivate;

  @override
  FutureOr<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final fields = await builder.allFieldsOf(
      clazz,
      includePrivate: includePrivate,
    );

    if (fields.isEmpty) {
      return;
    }

    final hashCodeDeclaration = await builder.getterOf(clazz, 'hashCode');
    final equalityOperatorDeclaration = await builder.getterOf(clazz, '==');

    if (hashCodeDeclaration == null) {
      builder.declareInType(
        DeclarationCode.fromParts([
          '  @override\n',
          '  external int get hashCode;\n\n',
        ]),
      );
    }

    if (equalityOperatorDeclaration == null) {
      builder.declareInType(
        DeclarationCode.fromParts([
          '  @override\n',
          '  external bool operator ==(Object other);\n',
        ]),
      );
    }
  }

  @override
  FutureOr<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final fields = await builder.allFieldsOf(
      clazz,
      includePrivate: includePrivate,
    );
    final hashCodeDeclaration = await builder.getterOf(clazz, 'hashCode');
    final equalityOperatorDeclaration = await builder.methodOf(clazz, '==');

    if (fields.isEmpty) {
      return;
    }

    if (hashCodeDeclaration != null) {
      final mapPropsToHashCodeIdentifier =
        await builder.resolveIdentifier(_core, 'mapPropsToHashCode');
      final getterBuilder =
        await builder.buildMethod(hashCodeDeclaration.identifier);
      final parts = [
        '=> runtimeType.hashCode ^ ', mapPropsToHashCodeIdentifier ,'([\n',
        for (final field in fields)
          ...['    ', field.identifier.name, ',\n'],
        '  ]);',
      ];

      getterBuilder.augment(FunctionBodyCode.fromParts(parts));
    }

    if (equalityOperatorDeclaration != null) {
      final identicalIdentifier =
        await builder.resolveIdentifier(_dartCore, 'identical');
      final equalsIdentifier = await builder.resolveIdentifier(_core, 'equals');
      final methodBuilder =
        await builder.buildMethod(equalityOperatorDeclaration.identifier);

      final thisFieldNames = <Object>[];
      final otherFieldNames = <Object>[];

      for (final field in fields) {
        thisFieldNames.addAll([
          '      ', field.identifier, ',\n',
        ]);

        otherFieldNames.addAll([
          '      ', 'other.', field.identifier.name, ',\n',
        ]);
      }

      methodBuilder.augment(
        FunctionBodyCode.fromParts([
          '=>\n',
          '    ', identicalIdentifier ,'(this, other) ||\n',
          '    ', 'other is ', clazz.identifier ,' &&\n',
          '    ', equalsIdentifier, '([\n',
            ...thisFieldNames ,
          '    ', '], [\n',
            ...otherFieldNames,
          '    ', ']);',
        ]),
      );
    }
    else {
      builder.error("Can't find == operator");
    }
  }
}
