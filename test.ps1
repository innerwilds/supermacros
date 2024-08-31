Remove-Item .dart_tool -Force -Recurse
Remove-Item build -Force -Recurse
flutter test --enable-experiment=macros,augmentations
dart pub get