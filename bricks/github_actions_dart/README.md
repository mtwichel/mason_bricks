# Github Actions Generator for Dart & Flutter Monorepos

## Set Up

Run `mason make github_actions_dart` in the root of your monorepo. This will:

1. Scan your project for any `pubspec.yaml` files to grab their name and if they use Flutter. If will also find any path dependencies in the repo and create a small dependency tree.
2. Create a `[PACKAGE_NAME]_verify_and_test.yaml` file for each package under the `.github/workflows` directory that calls the corresponding [Very Good Workflow](https://github.com/VeryGoodOpenSource/very_good_workflows). These will trigger on pull requests and pushes to the main/master branch, and will trigger if the current package has changes, or any of its path dependencies.
3. Creates a `verify_github_actions.yaml` that will enforce `mason make github_actions_dart` has been run to make sure all your packages are covered.

Optionally, it can also generate

- A spell check workflow from Very Good Workflows
- A semantic pull request workflow from Very Good Workflows
- A license checker workflow from Very Good Workflows
- A dependabot file

## Updating

If new packages are added, you will need to update your actions workflows. A file (`.github/update_github_actions.sh`) is generated to easily update the workflow files. Before running it, you need to give permission to run it.

```bash
chmod u+x .github/update_github_actions.sh
```

Then run it

```bash
.github/update_github_actions.sh
```

## Individual Package Specifications

You can override properties for individual packages. They should be added to a `actions_config.yaml` file in the same directory as the `pubspec.yaml`.

- `coverage_exclude`: Glob patters to match file names that should be excluded from code coverage (ie `**/*.g.dart`)
- `analyze_directories`: Directories that should be analyzed
- `format_directories`: Directories that should be checked for formatting
- `report_on`: Directories that should be reported in coverage reports
- `minimum_coverage`: The lowest coverage threshold considered passing

For more information, check out the [Very Good Workflows docs](https://workflows.vgv.dev/docs/category/workflows).
