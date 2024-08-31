import 'dart:async';
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';

/// Create copyWith() method for a constructor [constructorName].
macro class Copyable implements ClassDefinitionMacro, ClassDeclarationsMacro {
  /// Default constructor
  const Copyable([this.constructorName = '']);

  /// Constructor name. Unnamed, if empty or whitespace.
  final String constructorName;

  @override
  FutureOr<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final method = await builder.methodOf(clazz, 'copyWith');

    if (method == null) {
      return;
    }

    final constructors = await builder.constructorsOf(clazz);

    final ctor = constructors.firstWhereOrNull((ctor) {
      return ctor.identifier.name == constructorName;
    });

    if (ctor == null) {
      builder.error(
        constructorName.isEmpty ? "Can't find an unnamed default constructor" :
        "Can't find an $constructorName constructor",
        clazz.asDiagnosticTarget,
      );
      return;
    }

    final defBuilder = await builder.buildMethod(method.identifier);
    final parts = [
      '=>\n',
      '    ', clazz.identifier, '(\n',
      for (final pos in [...ctor.namedParameters, ...ctor.positionalParameters])
        ...['      ', pos.name, ': ', pos.name, ' ?? this.', pos.name, ',\n'],
      '    ',
      ');',
    ];

    defBuilder.augment(FunctionBodyCode.fromParts(parts));
  }

  @override
  FutureOr<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final ctor = (await builder.constructorsOf(clazz))
      .firstWhereOrNull((e) => e.identifier.name == constructorName);

    if (ctor == null) {
      return;
    }

    final named = [...ctor.namedParameters, ...ctor.positionalParameters];

    if (named.isEmpty) {
      builder.declareInType(
        DeclarationCode.fromParts([
        '  external ', ctor.definingType, ' copyWith();',
        ]),
      );
    }

    Future<Code> createArgumentDeclaration(
      FormalParameterDeclaration parameterDeclaration,
    ) async {
      final namedType =
        await parameterDeclaration.type.getFieldNamedType(
          parameterDeclaration, ctor, builder,
        );
      return DeclarationCode.fromParts([
        '    ', namedType!.identifier, '? ', parameterDeclaration.name, ', \n',
      ]);
    }

    builder.declareInType(
      DeclarationCode.fromParts([
        '  external ', ctor.definingType.name, ' copyWith(\n',
        '  ${ named.isNotEmpty ? '{' : '' }\n',
        for (final declaration in named) createArgumentDeclaration(declaration),
        '  ${ named.isNotEmpty ? '}' : '' });',
      ]),
    );
  }
}

extension on TypeAnnotation {
  FutureOr<NamedTypeAnnotation?> getFieldNamedType(
    FormalParameterDeclaration decl,
    ConstructorDeclaration ctor,
    DeclarationBuilder builder,
  ) async {
    final type = decl.type;

    NamedTypeAnnotation? named;

    if (type is NamedTypeAnnotation) {
      named = type;
    }
    else if (type is OmittedTypeAnnotation) {
      named = await _maybeExtractFromClassFieldDeclaration(decl, ctor, builder);
    }

    if (named != null) {
      return named;
    }

    final ctorName = ctor.identifier.name;

    builder.error(
      "Can't found type for ${decl.name} declaration on "
      "${ctor.definingType.name}${ctorName.isEmpty ? '' : '.'}$ctorName "
      'constructor');
    return null;
  }

  FutureOr<NamedTypeAnnotation?> _maybeExtractFromClassFieldDeclaration(
    FormalParameterDeclaration declaration,
    ConstructorDeclaration constructor,
    DeclarationBuilder builder,
  ) async {
    final clazz = await builder.typeDeclarationOf(constructor.definingType);
    final fields = await builder.fieldsOf(clazz);
    final fieldWithSameName = fields
      .firstWhereOrNull((e) => e.identifier.name == declaration.name);

    if (fieldWithSameName != null) {
      return await _named(fieldWithSameName.type);
    }
    return null;
  }

  FutureOr<NamedTypeAnnotation?> _named(TypeAnnotation type) {
    if (type is NamedTypeAnnotation) {
      return type;
    }
    return null;
  }
}
