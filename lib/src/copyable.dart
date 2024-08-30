import 'dart:async';
import 'dart:core';

import 'package:collection/collection.dart';
import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';

macro class Copyable implements ClassDefinitionMacro, ClassDeclarationsMacro {
  final String constructorName;

  const Copyable([this.constructorName = '']);

  @override
  FutureOr<void> buildDefinitionForClass(ClassDeclaration clazz, TypeDefinitionBuilder builder) async {
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
        "Can't find an $constructorName constructor", clazz.asDiagnosticTarget);
      return;
    }

    final defBuilder = await builder.buildMethod(method.identifier);
    final parts = [
      '=>\n'
      '    ', clazz.identifier, '(\n',
      for (final pos in [...ctor.namedParameters, ...ctor.positionalParameters])
        ...['      ', pos.name, ': ', pos.name, ' ?? this.', pos.name, ',\n'],
      '    ',
      ');'
    ];

    //builder.error(parts.map((e) => e is Identifier ? e.name : e.toString()).join());

    defBuilder.augment(FunctionBodyCode.fromParts(parts));
  }

  @override
  FutureOr<void> buildDeclarationsForClass(ClassDeclaration clazz, MemberDeclarationBuilder builder) async {
    final ctor = (await builder.constructorsOf(clazz)).firstWhereOrNull((e) => e.identifier.name == constructorName);

    if (ctor == null) {
      return;
    }

    final named = [...ctor.namedParameters, ...ctor.positionalParameters];

    if (named.isEmpty) {
      builder.declareInType(DeclarationCode.fromParts([
        '  external ', ctor.definingType, ' copyWith();'
      ]));
    }

    builder.declareInType(DeclarationCode.fromParts([
      '  external ',ctor.definingType.name, ' copyWith(\n',
      '  ${ named.isNotEmpty ? '{' : '' }\n',
      for (final pos in named)
        ...['    ', (await pos.type.getFieldNamedType(pos, ctor, builder))!.identifier, '? ', pos.name, ', \n'],
      '  ${ named.isNotEmpty ? '}' : '' });',
    ]));
  }
}

extension on TypeAnnotation {
  FutureOr<NamedTypeAnnotation?> getFieldNamedType(FormalParameterDeclaration decl, ConstructorDeclaration ctor, DeclarationBuilder builder) async {
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

    builder.error("Can't found type for ${decl.name} declaration on ${ctor.definingType.name}${ctorName.isEmpty ? '' : '.'}${ctorName} constructor");
    return null;
  }

  FutureOr<NamedTypeAnnotation?> _maybeExtractFromClassFieldDeclaration(FormalParameterDeclaration decl, ConstructorDeclaration ctor, DeclarationBuilder builder) async {
    final clazz = await builder.typeDeclarationOf(ctor.definingType);
    final fields = await builder.fieldsOf(clazz);
    final fieldWithSameName = fields.firstWhereOrNull((e) => e.identifier.name == decl.name);

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