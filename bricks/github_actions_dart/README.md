# Github Actions Generator for Dart & Flutter Monorepos

Run `mason make github_actions_dart` in the root of your monorepo. This will:
1. Scan your project for any `pubspec.yaml` files to grab their name and if they use Flutter. If will also find any path dependencies in the repo and create a small dependency tree.
2. Create a `[PACKAGE_NAME]_verify_and_test.yaml` file for each package under the `.github/workflows` directory that calls the corresponding [Very Good Workflow](https://github.com/VeryGoodOpenSource/very_good_workflows). These will trigger on pull requests and pushes to the main/master branch, and will trigger if the current package has changes, or any of its path dependencies.
3. Creates a `verify_github_actions.yaml` that will enforce `mason make github_actions_dart` has been run to make sure all your packages are covered.

## Tips
- You can exclude packages from the generation by changing the `exclude` variable. Just make sure it's formatted as an array of strings.
- You can control the test coverage threshold by changing the `minCoverage` variable.
- You can exclude lines of code from coverage on the packages by adding a *coverage_exclude* section to the package's `pubspec.yaml` file.

`pubspec.yaml`
```yaml
name: my_awesome_dart_package

dependencies:
  ...

coverage_exclude:
  - "**/*.g.dart"
  - "**/*.ignorethis"
```