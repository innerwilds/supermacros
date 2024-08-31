import 'dart:async';

import 'package:macros/macros.dart';
import 'package:xmacros/xmacros.dart';

/// A macro that overrides [toString] to print name of target class
/// and its fields:
/// ExampleClassName(
///   fieldA: 1,
///   fieldB: "2",
///   fieldC: true,
///   fieldD: [Instance of "E"]
/// );
macro class Printable implements ClassDefinitionMacro, ClassDeclarationsMacro {
  /// Default ctor
  const Printable({
    this.getters = true,
    this.indent = 2,
    this.inline = false,
    this.private = false,
    this.methods = '',
  });

  /// Whether to include getters.
  final bool getters;

  /// Whether to include private fields.
  final bool private;

  /// Whether to include line-terminator or not.
  final bool inline;

  /// Space-indent size.
  final int indent;

  /// Comma-separated methods to print.
  final String methods;

  String get _terminator => inline ? '' : '\\n';
  String get _indentSpaces => ' ' * (indent < 0 ? 0 : indent);

  @override
  FutureOr<void> buildDefinitionForClass(
    ClassDeclaration clazz,
    TypeDefinitionBuilder builder,
  ) async {
    final printableMethods = methods.trim().split(',').map((e) => e.trim());
    final membersToPrint = [
      for (final method in await builder.methodsOf(clazz))
        if (getters && method.isGetter ||
            printableMethods.contains(method.identifier.name))
          method,
      ...await builder.allFieldsOf(clazz, includePrivate: private),
    ];

    final method = await builder.methodOf(clazz, 'toString');

    if (method == null) {
      return;
    }

    final methodBuilder = await builder.buildMethod(method.identifier);

    String constructMemberName(Declaration declaration) {
      return switch (declaration) {
        MethodDeclaration() when !declaration.isGetter =>
          '${declaration.identifier.name}()',
        MethodDeclaration() when declaration.isGetter =>
          declaration.identifier.name,
        FieldDeclaration() => declaration.identifier.name,
        _ => throw UnimplementedError(
          'Unimplemented type declaration $declaration',
        ),
      };
    }

    String constructMemberCall(Declaration declaration) {
      return switch (declaration) {
        MethodDeclaration() when !declaration.isGetter =>
          '${declaration.identifier.name}()',
        MethodDeclaration() when declaration.isGetter =>
          declaration.identifier.name,
        FieldDeclaration() => declaration.identifier.name,
        _ => throw UnimplementedError(
          'Unimplemented type declaration $declaration',
        ),
      };
    }

    String createKey(MemberDeclaration member) {
      return '$_indentSpaces${constructMemberName(member)}';
    }

    String createValue(MemberDeclaration member) {
      return '\${${constructMemberCall(member)}}';
    }

    String createPairs(List<MemberDeclaration> members) {
      return [
        for (final member in membersToPrint)
          '    "${createKey(member)}: ${createValue(member)}',
      ].join(',$_terminator"\n');
    }

    methodBuilder.augment(
      FunctionBodyCode.fromParts([
        '=> "${clazz.identifier.name}($_terminator"\n',
        createPairs(membersToPrint),
        '  ")";',
      ]),
    );
  }

  @override
  FutureOr<void> buildDeclarationsForClass(
    ClassDeclaration clazz,
    MemberDeclarationBuilder builder,
  ) {
    builder.declareInType(
      DeclarationCode.fromParts([
        '  @override\n',
        '  external String toString();',
      ]),
    );
  }
}
