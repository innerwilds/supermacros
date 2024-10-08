import 'dart:async';

import 'package:macros/macros.dart';
import 'package:supermacros/src/auto_constructor.dart';
import 'package:xmacros/xmacros.dart';

final _startUnderscore = RegExp('^_+');

/// Creates get for target field
@AutoCtor()
macro class AutoGet implements FieldDeclarationsMacro, FieldDefinitionMacro {
  @override
  FutureOr<void> buildDeclarationsForField(
    FieldDeclaration field,
    MemberDeclarationBuilder builder,
  ) async {
    final clazz = await builder.maybeClassOf(field);

    if (!field.identifier.name.startsWith('_') || clazz == null) {
      builder.error(
        '@autoget must be defined on private member only, and only within a '
        'class');
      return;
    }

    final publicName = field.identifier.name.replaceFirst(_startUnderscore, '');
    final definedGetter = await builder.getterOf(clazz, publicName);

    if (definedGetter != null) {
      builder.warn(
        'there is @autoget defined for ${field.identifier.name}',
        definedGetter.asDiagnosticTarget,
      );
      return;
    }

    final type = field.type;

    if (type is! NamedTypeAnnotation) {
      builder.error(
        '@autoget() must be defined on NamedTypeAnnotation. '
        'The field type is $type');
      return;
    }

    builder.declareInType(
      DeclarationCode.fromParts([
        '  external ', type.identifier, ' get ', publicName, ';',
      ]),
    );
  }

  @override
  FutureOr<void> buildDefinitionForField(
    FieldDeclaration field,
    VariableDefinitionBuilder builder,
  ) async {
    final clazz = await builder.maybeClassOf(field);

    if (clazz == null) {
      builder.error(
        '@autoget must be defined on private member only, '
        'and only within a class'
      );
      return;
    }

    final publicName = field.identifier.name.replaceFirst(_startUnderscore, '');
    final getter = await builder.getterOf(clazz, publicName);

    if (getter == null) {
      return;
    }

    final type = field.type;

    if (type is! NamedTypeAnnotation) {
      builder.error(
        '@autoget() must be defined on NamedTypeAnnotation. '
        'The field type is $type'
      );
      return;
    }

    builder.augment(
      getter: DeclarationCode.fromParts([
        type.identifier, ' get ', publicName, ' => ', field.identifier, ';',
      ]),
    );
  }
}

/// Creates setter for a target field
@AutoCtor()
macro class AutoSet implements FieldDeclarationsMacro, FieldDefinitionMacro {
  /// Controls whether the setter accepts nullable value or not, or uses
  /// annotated type.
  final bool? nullable;

  @override
  FutureOr<void> buildDeclarationsForField(
    FieldDeclaration field,
    MemberDeclarationBuilder builder,
  ) async {
    final clazz = await builder.maybeClassOf(field);

    if (!field.identifier.name.startsWith('_') || clazz == null) {
      builder.error(
        '@autoset must be defined on private member only, and only '
        'within a class'
      );
      return;
    }

    final publicName = field.identifier.name.replaceFirst(_startUnderscore, '');
    final definedGetter = await builder.getterOf(clazz, publicName);

    if (definedGetter != null) {
      builder.warn(
        'there is @autoset defined for ${field.identifier.name}',
        definedGetter.asDiagnosticTarget,
      );
      return;
    }

    final type = field.type;

    if (type is! NamedTypeAnnotation) {
      builder.error(
        '@autoget() must be defined on NamedTypeAnnotation. '
        'The field type is $type'
      );
      return;
    }

    builder.declareInType(
      DeclarationCode.fromParts([
        '  external set ', publicName, '(', switch (nullable) {
          null => type.code,
          true => type.code.asNullable,
          false => type.code.asNonNullable,
        } , r' _$$newValue);',
      ]),
    );
  }

  @override
  FutureOr<void> buildDefinitionForField(
    FieldDeclaration field,
    VariableDefinitionBuilder builder,
  ) async {
    final clazz = await builder.maybeClassOf(field);

    if (clazz == null) {
      builder.error(
        '@autoset must be defined on private member only, and only '
        'within a class'
      );
      return;
    }

    final publicName = field.identifier.name.replaceFirst(_startUnderscore, '');
    final getter = await builder.setterOf(clazz, publicName);

    if (getter == null) {
      return;
    }

    final type = field.type;

    if (type is! NamedTypeAnnotation) {
      builder.error(
        '@autoget() must be defined on NamedTypeAnnotation. '
        'The field type is $type'
      );
      return;
    }

    builder.augment(
      getter: DeclarationCode.fromParts([
        'set ', publicName, '(', type.identifier , r' _$$newValue)', '{\n',
        '    ', field.identifier, r' = _$$newValue;', '\n',
        '  }',
      ]),
    );
  }
}

/// Creates public getter and setter for a target field
@AutoCtor()
macro class Accessor implements FieldDeclarationsMacro, FieldDefinitionMacro {
  @override
  FutureOr<void> buildDeclarationsForField(
    FieldDeclaration field,
    MemberDeclarationBuilder builder,
  ) {
    AutoGet().buildDeclarationsForField(field, builder);
    AutoSet().buildDeclarationsForField(field, builder);
  }

  @override
  FutureOr<void> buildDefinitionForField(
    FieldDeclaration field,
    VariableDefinitionBuilder builder,
  ) {
    AutoGet().buildDefinitionForField(field, builder);
    AutoSet().buildDefinitionForField(field, builder);
  }
}
