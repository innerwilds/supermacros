// ignore: camel_case_types
import 'dart:async';
import 'dart:collection';

import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';

/// Kind of type whether to search for a [CollectTypesMethods.methodName]
enum TypeKind {
  /// Search in classes
  clazz,
  /// Search in extensions
  extension,
}

/// Collect an [methodName] method from all types in [Library] that conform
/// the constraints: [superclass], [implementsRaw], [kind].
macro class CollectTypesMethods implements VariableDefinitionMacro {
  /// Default ctor
  const CollectTypesMethods({
    required this.methodName,
    this.kind = TypeKind.clazz,
    this.superclass,
    this.implementsRaw,
  });

  /// Kind of place where to search for a [methodName]
  final TypeKind kind;

  /// Superclass of classes where to search for a [methodName]
  /// Compatible only with [kind] set to [TypeKind.clazz]
  final String? superclass;

  /// Comma-separated list of interfaces of classes where to search
  /// for a [methodName]
  final String? implementsRaw;

  /// Method name to search for
  final String methodName;

  @override
  FutureOr<void> buildDefinitionForVariable(
    VariableDeclaration variable,
    VariableDefinitionBuilder builder,
  ) async {
    final allTypes = await builder.typesOf(variable.library);
    final map = HashSet<MethodDeclaration>();

    for (final type in allTypes) {
      if (!_conforms(type)) {
        continue;
      }

      final method =
        await builder.methodOf(type, methodName) ??
        await builder.constructorOf(type, methodName);

      if (method != null) {
        map.add(method);
      }
    }

    if (map.isEmpty) {
      return;
    }

    Code createMapKeyDeclaration(MethodDeclaration method) {
      return RawCode.fromParts([
        '  ', method.definingType, ': ',
      ]);
    }

    Code createPositionalArgumentDeclaration(FormalParameterDeclaration param) {
      return RawCode.fromParts([
        '    ', param.type.code, ' ', param.identifier.name, ', \n',
      ]);
    }

    Code createPositionalArgumentsListDeclaration(MethodDeclaration method) {
      return RawCode.fromParts([
        for (final param in method.positionalParameters)
          createPositionalArgumentDeclaration(param),
      ]);
    }

    Code createNamedArgumentDeclaration(FormalParameterDeclaration param) {
      return RawCode.fromParts([
        '    ',
        if (param.isRequired)
          'required ', param.type.code, ' ', param.identifier.name,
        if (!param.type.isNullable && !param.isRequired)
          ...[' = ', param.code],
        ', \n',
      ]);
    }

    Code createNamedArgumentsListDeclaration(MethodDeclaration method) {
      return RawCode.fromParts([
        if (method.namedParameters.isNotEmpty) '{',
        for (final arg in method.namedParameters)
          createNamedArgumentDeclaration(arg),
        if (method.namedParameters.isNotEmpty) '}',
      ]);
    }

    // On 08/30/2024 I noticed a problem with assigning a reference
    // to the found method, so as a temporary (yes??)))) solution I chose
    // to repeat the signature of the found method and pass its arguments
    // to the original one.
    // So instead of "TypeName: TypeName.methodName,", we create here
    // "TypeName: (args) => TypeName.methodName(args)"
    builder.augment(
      initializer: ExpressionCode.fromParts([
        '{\n',
        for (final method in map)
          ...[
            createMapKeyDeclaration(method), // TypeName:
            '(\n',
            createPositionalArgumentsListDeclaration(method),
            createNamedArgumentsListDeclaration(method),
          '  ) => ', method.identifier, '(\n',
            for (final arg in method.positionalParameters)
              ...['      ', arg.identifier.name, ', \n'],
            for (final arg in method.namedParameters)
              ...[
                '    ', arg.identifier.name, ': ', arg.identifier.name, ', \n',
              ],
          '    ),\n',
          ],
        '}',
      ]),
    );
  }

  bool _conforms(TypeDeclaration declaration) {
    switch (kind) {
      case TypeKind.clazz:
        if (declaration is! ClassDeclaration) {
          return false;
        }
      case TypeKind.extension:
        if (declaration is! ExtensionDeclaration) {
          return false;
        }
    }

    if (declaration is ClassDeclaration) {
      if (superclass != null &&
          superclass != declaration.superclass?.identifier.name) {
        return false;
      }

      if (implementsRaw != null) {
        final interfaces = implementsRaw!
          .split(',')
          .map((e) => e.trim())
          .toList();

        bool isImplements() {
          return interfaces.every(
            (interface) => declaration.interfaces.any(
              (decl) {
                return decl.identifier.name == interface;
              },
            ),
          );
        }

        if (!isImplements()) {
          return false;
        }
      }
    }

    return true;
  }
}
