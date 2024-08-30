import 'dart:async';

import 'package:meta/meta.dart';
import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';

final _dartCore = Uri.parse('dart:core');
final setBaskets = <String, Set<Object>>{};

enum _BasketType {
  set("Set"),
  list("List"),
  map("Map");

  const _BasketType(this._dartCoreName);
  final String _dartCoreName;
}

@immutable
final class BasketValue {
  const BasketValue(String name, Object value) :
    assert(value is String || value is bool || value is num);
}

// ignore: camel_case_types
macro class Basket implements VariableDefinitionMacro {
  const Basket.set(this._basketName) : _type = _BasketType.set;
  const Basket.list(this._basketName) : _type = _BasketType.list;
  const Basket.map(this._basketName) : _type = _BasketType.map;

  final String _basketName;
  final _BasketType? _type;

  @override
  FutureOr<void> buildDefinitionForVariable(VariableDeclaration variable, VariableDefinitionBuilder builder) async {
    final allTypes = await builder.typesOf(variable.library);
    final values = [
      for (final type in allTypes)
        for (final meta in type.metadata)
          if (meta is ConstructorMetadataAnnotation &&
              meta.constructor.name == 'add' &&
              meta.type.identifier.name == 'basket' &&
              meta.positionalArguments.first.kind == CodeKind.expression &&
              meta.positionalArguments.first.parts.last.unquoted == _basketName)
            meta.positionalArguments.last.parts.last.unquoted,
    ];

    final varType = variable.type;

    if (varType is! NamedTypeAnnotation) {
      builder.error('You must use named type annotation: YourType yourVarOrFinal = maybeAnInitializer', variable.asDiagnosticTarget);
      return;
    }

    final varTypeDeclaration = await builder.typeDeclarationOf(varType.identifier);

    bool isVarTypeSupported = varTypeDeclaration.isExactly(_type?._dartCoreName ?? '', _dartCore);

    if (!isVarTypeSupported) {
      builder.error("Variable type is not supported. Supported types are: Set, Map, List", variable.asDiagnosticTarget);
      return;
    }

    builder.augment(
      initializer: ExpressionCode.fromParts([
        '{\n',
        for (final value in values)
          '"$value",\n',
        '}'
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