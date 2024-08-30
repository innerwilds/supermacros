// ignore: camel_case_types
import 'dart:async';
import 'dart:collection';

import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';
import 'package:supermacros/supermacros.dart';

enum TypeKind {
  clazz,
  extension,
}

/// Collect an [methodName] method from all types in [Library] that conform
/// the constraints: [superclass], [implementsRaw], [kind].
macro class CollectTypesMethods implements VariableDefinitionMacro {
  const CollectTypesMethods({
    required this.methodName,
    this.kind = TypeKind.clazz,
    this.superclass,
    this.implementsRaw,
  });

  final TypeKind kind;
  final String? superclass;
  final String? implementsRaw;
  final String methodName;

  @override
  FutureOr<void> buildDefinitionForVariable(VariableDeclaration variable, VariableDefinitionBuilder builder) async {
    final allTypes = await builder.typesOf(variable.library);
    final map = HashSet<MethodDeclaration>();

    for (final type in allTypes) {
      if (!conforms(type)) {
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

    builder.augment(
      initializer: ExpressionCode.fromParts([
        '{\n',
        for (final method in map)
          ...['  ', method.definingType, ': ', '(\n',
          for (final arg in method.positionalParameters)
            ...['    ', arg.type.code, ' ', arg.identifier.name, ', \n'], if (method.namedParameters.isNotEmpty) '{',
          for (final arg in method.namedParameters)
            ...['    ', arg.isRequired ? 'required ' : '', arg.type.code, ' ', arg.identifier.name, if (!arg.type.isNullable && !arg.isRequired) ...[' = ', arg.code], ', \n'],
          if (method.namedParameters.isNotEmpty) '}',
          '  ) => ', method.identifier, '(\n',
            for (final arg in method.positionalParameters)
              ...['      ', arg.identifier.name, ', \n'],
            for (final arg in method.namedParameters)
              ...['    ', arg.identifier.name, ': ', arg.identifier.name, ', \n'],
          '    ),\n'],
        '}',
      ])
    );
  }

  bool conforms(TypeDeclaration decl) {
    switch (kind) {
      case TypeKind.clazz:
        if (decl is! ClassDeclaration) {
          return false;
        }
      case TypeKind.extension:
        if (decl is! ExtensionDeclaration) {
          return false;
        }
    }

    if (decl is ClassDeclaration) {
      if (superclass != null && superclass != decl.superclass?.identifier.name) {
        return false;
      }

      if (implementsRaw != null) {
        final interfaces = implementsRaw!.split(',').map((e) => e.trim()).toList();
        if (!interfaces.every((interface) => decl.interfaces.any((decl) {
          return decl.identifier.name == interface;
        }))) {
          return false;
        }
      }
    }

    return true;
  }
}