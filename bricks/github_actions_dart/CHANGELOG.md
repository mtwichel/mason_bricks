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
