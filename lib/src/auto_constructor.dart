import 'dart:async';

import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';

/// Creates constructor with the [name] or unnamed with initializers for all
/// fields.
macro class AutoCtor implements ClassDeclarationsMacro, ClassDefinitionMacro {
  /// Default ctor
  const AutoCtor({
    this.name,
    this.constant = true,
  });

  /// Creates named constructor if set and non-empty.
  final String? name;

  /// Whether built constructor should be constant.
  final bool constant;

  _InitializeIt _membersToInitialize({
    required List<FieldDeclaration> fields,
  }) {
    return _InitializeIt([
      for (final field in fields)
        if (!(field.hasFinal && field.hasInitializer))
          field,
    ]);
  }

  @override
  FutureOr<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) async {
    final constructorDeclaration =
      await builder.constructorOf(clazz, name ?? '');

    if (constructorDeclaration != null) {
      builder.error(
        "AutoCtor can't generate constructor due to this one",
        constructorDeclaration.asDiagnosticTarget,
      );
      return;
    }

    final fields = await builder.fieldsOf(clazz);
    final membersToInitialize = _membersToInitialize(fields: fields);

    final shouldBeConst = constant && !fields.any((field) => field.hasLate);
    final ctorName = name != null && name!.isNotEmpty ? '.$name' : '';
    final className = clazz.identifier.name;
    final constructor = "${shouldBeConst ? 'const' : ''} $className$ctorName";

    Code createNamedArgumentsDeclaration() {
      return DeclarationCode.fromParts([
        '{\n',
        membersToInitialize.createArgumentsDeclaration(),
        '  }',
      ]);
    }

    builder.declareInType(
      DeclarationCode.fromParts([
      '  external $constructor(',
      if (membersToInitialize.isNotEmpty)
        createNamedArgumentsDeclaration(),
      ');',
      ]),
    );
  }

  @override
  FutureOr<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final ctor = await builder.constructorOf(clazz, name ?? '');

    if (ctor == null) {
      return;
    }

    final ctorBuilder = await builder.buildConstructor(ctor.identifier);
    final fields = await builder.fieldsOf(clazz);
    final membersToInitialize = _membersToInitialize(fields: fields);

    ctorBuilder.augment(
      initializers: membersToInitialize.createInitializers(),
    );
  }
}

extension on String {
  String trimUnderscoreLeft() {
    var index = 0;

    while (this[index] == '_') {
      if (index > 100) {
        break;
      }
      index++;
    }

    return index >= length ? '' : substring(index);
  }
}

final class _InitializeIt {
  _InitializeIt(this.fields);

  final List<FieldDeclaration> fields;

  bool get isNotEmpty => fields.isNotEmpty;

  List<Code> createInitializers() {
    final code = <Code>[];
    final declaredNamesCountable = <String, int>{};

    for (final field in fields) {
      var argumentName = field.identifier.name.trimUnderscoreLeft();

      final argumentNameCount = declaredNamesCountable[argumentName] ??= 0;

      if (argumentNameCount > 0) {
        declaredNamesCountable[argumentName] = argumentNameCount + 1;
        argumentName += '$argumentNameCount';
      }
      else {
        declaredNamesCountable[argumentName] = argumentNameCount + 1;
      }

      declaredNamesCountable[argumentName] = argumentNameCount + 1;

      code.add(
        RawCode.fromParts([
          field.identifier, ' = ', argumentName,
        ]),
      );
    }

    return code;
  }

  DeclarationCode createArgumentsDeclaration() {
    final code = <Object>[];
    final declaredNamesCountable = <String, int>{};

    for (final field in fields) {
      var argumentName = field.identifier.name.trimUnderscoreLeft();

      final argumentNameCount = declaredNamesCountable[argumentName] ??= 0;

      if (argumentNameCount > 0) {
        declaredNamesCountable[argumentName] = argumentNameCount + 1;
        argumentName += '$argumentNameCount';
      }
      else {
        declaredNamesCountable[argumentName] = argumentNameCount + 1;
      }

      code.add(
        createArgumentDeclaration(
          field.type.code,
          argumentName,
          isRequired: !field.type.isNullable && !field.hasInitializer,
        ),
      );
    }

    return DeclarationCode.fromParts(code);
  }

  RawCode createArgumentDeclaration(
      TypeAnnotationCode type, String argumentName, {
        required bool isRequired,
      }) {
    return RawCode.fromParts([
      '    ',
      if (isRequired) 'required ',
      type,
      ' ',
      argumentName,
      ',\n',
    ]);
  }
}
