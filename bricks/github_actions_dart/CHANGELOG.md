## 2.0.3

- Adds back Very Good CLI to the `verify_github_actions.yaml` as the current solution was not reliable.

## 2.0.2

- Make `dart pub get` command run in shell so it works on github actions.

## 2.0.1

- Removed installing Very Good CLI from `verify_github_actions.yaml` as it's not needed.
- `verify_github_actions.yaml` now manually fetches the workflow so that it still works if it's not included in your `mason.yaml` file (ie if it's installed globally).

## 2.0.0

- **Breaking**: This brick now searches for Flutter in the `pubspec.lock` file, not the `pubspec.yaml`. This means
  1. If you have not done a `dart pub get` in a particular package (ie it couldn't find a `pubspec.lock` file), the brick will run pub get in that file.
  2. It will now choose the Flutter builder if Flutter is used IN ANY transitive dependency. This means you won't have to add Flutter as a dependency just to force the correct workflow to run.
- **Breaking**: Removed the `generateLicenseCheck` variable. Now variables are configured in the `actions_config.yaml` for each individual package. See the README for details.
- **Breaking**: Rename `dependabot.yml` to `dependabot.yaml` for consistency with the other workflows.
- **Breaking**: Renames package check files to `[PACKAGE_NAME].yaml` from `[PACKAGE_NAME]_verify_and_test.yaml`.
- Added the ability to delete all other workflow files not controlled by this brick by setting the `clearOldWorkflows` to `true`.
- Added the `mainJobName` and `licenseCheckJobName` variables, which allows you to customize the name of the jobs generated.
- Bumped the default Flutter version to 3.24.4.

## 1.1.0

- Added a parameter to add license checking workflow to make sure your dependencies have appropriate licenses
- Upgraded default Flutter parameter to 3.22.1
- Fixed issue where dependencies with dependencies that needed Flutter weren't marked as needing Flutter
- Added `cancel-in-progress: true` to all workflows

## 1.0.0

- **Breaking**: Package specific configurations now are read from a `actions_config.yaml` file, not the package's `pubspec`. See README for details.
- Added `generate_github_actions.sh` file with configured options to quickly update files.
- Bumped Flutter version to 3.13.6
- Changed defaults for workflowRef, cspell config
- Added flags to prevent generating semantic pull request and spell checker

## 0.0.17

- Bumped default flutter version to `3.10.0`
- Added `workflowRef` variable

## 0.0.16

- Added `spellCheckConfig` variable

## 0.0.15

- Fixed some issues ing 0.0.14

## 0.0.14

- Added spell check workflow
- Added concurrency helper
- Added semantic pull request job to verify and check

## 0.0.13

- Added the ability to generate a dependabot.yml file in addition to workflow files.

## 0.0.12

- Added an exclude paths variable, which can be used to exclude any `pubspec.yaml` files that match a particular path.
- Updated default flutter version to `3.3.0`

## 0.0.10

- Fixed verify github actions workflow to include dartChannel variable

## 0.0.9

- Fixed top level packages not activating in Github actions
- Added variable for Dart SDK

## 0.0.8

- Fixed issue where packages in current directory wouldn't generate
- Bump default flutter version to `3.0.4`

## 0.0.7

- Fix parsing issues for minimum coverage
- Bump default flutter version to `3.0.1`

## 0.0.6

- Make minimum configurable by package from the pubspec

## 0.0.5

- Make verification Github action set flutter version and channel

## 0.0.4

- Added variables to control Flutter channel and version
- Update default Flutter to version 3.0.0!

## 0.0.3

- Make prehook ignore macos pubspecs

## 0.0.2

- Make flutter workflows specify flutter version

## 0.0.1

- Initial release! Generate Github Actions for your Dart Monorepos!
