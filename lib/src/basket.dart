import 'dart:async';

import 'package:macros/macros.dart';
import 'package:meta/meta.dart';
import 'package:xmacros/xmacros.dart';

final _dartCore = Uri.parse('dart:core');

/// Describes basket value
/// Put it anywhere you want
@immutable
final class BasketValue {
  /// Default constructor
  const BasketValue(String name, Object value) :
    assert(
      value is String || value is bool || value is num,
      'Basket value must be a String, a bool or a num',
    );

  // /// Keyed value for [MapBasket]
  // const BasketValue.keyed(String name, Object key, Object value) :
  //   assert(
  //     key is String || key is num || key is Type,
  //     'BasketValue.keyed key must be a String, a num or a Type',
  //   ),
  //   assert(
  //     value is String || value is bool || value is num,
  //     'BasketValue value must be a String, a bool or a num',
  //   );
}

/// Basket is a macro that creates const/final variable with values from all
/// [BasketValue].
///
/// Define it like:
/// main.dart
/// ```dart
/// @SetBasket('myInts')
/// const Set<String> ints = {};
/// ```
///
/// anywhere_in_the_library.dart
/// ```dart
/// @BasketValue('myInts', 2)
/// class A {}
///
/// @BasketValue('myInts', 3)
/// extension A {}
///
/// // and etc.
/// ```
///
/// It produces augmented code like:
/// ```dart
/// augment const ints = <String>{
///   2,
///   3,
/// };
/// ```
// ignore: camel_case_types
class SetBasket implements VariableDefinitionMacro {
  /// Default constructor
  const SetBasket(this.name);

  /// Basket name
  final String name;

  @override
  FutureOr<void> buildDefinitionForVariable(
    VariableDeclaration variable,
    VariableDefinitionBuilder builder,
  ) async {
    final allTypes = await builder.typesOf(variable.library);

    // Currently, at build step metadata is fully omitted from dart code,
    // so here will be zero elements.
    // 3.6.0-198 Dart version
    final values = [
      for (final type in allTypes)
        for (final meta in type.metadata)
          if (meta is ConstructorMetadataAnnotation &&
              meta.constructor.name == 'add' &&
              meta.type.identifier.name == 'basket' &&
              meta.positionalArguments.first.kind == CodeKind.expression &&
              meta.positionalArguments.first.parts.last.unquoted == name)
            meta.positionalArguments.last.parts.last.unquoted,
    ];

    final varType = variable.type;

    if (varType is! NamedTypeAnnotation) {
      builder.error(
        'You must use named type annotation: '
        'YourType yourVarOrFinal = maybeAnInitializer',
        variable.asDiagnosticTarget,
      );
      return;
    }

    final varTypeDeclaration = await builder
      .typeDeclarationOf(varType.identifier);
    final isVarTypeSupported = varTypeDeclaration.isExactly('Set', _dartCore);

    if (!isVarTypeSupported) {
      builder.error(
        'Variable type is not supported. Supported type is Set',
        variable.asDiagnosticTarget,
      );
      return;
    }

    builder.augment(
      initializer: ExpressionCode.fromParts([
        '{\n',
        for (final value in values)
          '"$value",\n',
        '}',
      ]),
    );
  }
}

extension on TypeDeclaration {
  /// Cheaper than checking types using a [StaticType].
  bool isExactly(String name, Uri library) =>
      identifier.name == name && this.library.uri == library;
}

extension on Object {
  String get unquoted {
    final quoted = '$this';
    return quoted.substring(1, quoted.length - 1);
  }
}
