import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import 'package:mason/mason.dart';
import 'package:yaml/yaml.dart';

Future<void> run(HookContext context) async {
  final excludePaths = context.vars['excludePaths'] as String?;
  final searchingCallback = context.logger.progress('Searching for packages.');
  final pubspecs = await getPackages(excludePaths?.split(' '));
  searchingCallback.complete('Found ${pubspecs.length} packages.');
  final depGraph = buildDependencyGraph(pubspecs);
  final jobs = depGraph.keys
      .map((package) {
        final currentDependencies = depGraph[package]!
            .map((dep) => '      - ${dep.packageDir}/**')
            .toList();

        currentDependencies.sort();
        num getMinCov(Package package, Map<String, dynamic> vars) {
          if (package.minimumCoverage is num) {
            return package.minimumCoverage!;
          }
          if (context.vars['minCoverage'] is num) {
            return context.vars['minCoverage'];
          }
          if (context.vars['minCoverage'] is String) {
            return num.parse(context.vars['minCoverage']!);
          }
          return 100;
        }

        return Job(
          name: package.pubspec.name,
          packageDir: package.packageDir,
          globPath: package.packageGlobPath,
          usesFlutter: package.pubspec.dependencies.containsKey('flutter'),
          dependenciesDirs: currentDependencies.join('\n'),
          coverageExclude: package.coverageExclude,
          minimumCoverage: getMinCov(package, context.vars),
        );
      })
      .map((job) => job.toJson())
      .toList()
    ..sort(((a, b) => a['name'].compareTo(b['name'])));

  var exclude = context.vars['exclude'];
  if (exclude is String) {
    exclude = List<String>.from(exclude.split(' '));
  } else {
    throw Exception(
      'Exclude var must be a list of strings separated by spaces',
    );
  }
  context.vars = {
    ...context.vars,
    'jobs': jobs.where((job) => !exclude.contains(job['name'])).toList(),
  };
}

Future<List<Package>> getPackages(List<String>? excludedPaths) async {
  final pubspecMatcher = Glob("**pubspec.yaml");
  final defaultExcludedPaths = ['ios', 'macos', '.dart_tool', 'bricks', '.fvm'];
  final badMatcher =
      RegExp([...defaultExcludedPaths, ...?excludedPaths].join('|'));

  final packages = <Package>[];

  await for (final entry in pubspecMatcher.list()) {
    if (!badMatcher.hasMatch(entry.path)) {
      final file = File(entry.path);
      final fileString = await file.readAsString();
      final fileJson = loadYaml(fileString);
      final pubspec = Pubspec.fromJson(fileJson);

      final parentPath = entry.parent.path;
      final String globPath;
      if (parentPath.startsWith('./')) {
        globPath = '${parentPath.substring(2)}/**';
      } else if (parentPath.startsWith('.')) {
        globPath = '**';
      } else {
        globPath = parentPath;
      }

      final coverageExclude = fileJson['coverage_exclude'];
      final minimumCoverage = fileJson['minimum_coverage'] as num?;
      packages.add(
        Package(
          packageGlobPath: globPath,
          packageDir: parentPath.startsWith('./')
              ? parentPath.substring(2)
              : parentPath,
          pubspec: pubspec,
          coverageExclude: coverageExclude is YamlList
              ? List<String>.from(coverageExclude)
              : [],
          minimumCoverage: minimumCoverage,
        ),
      );
    }
  }

  return packages;
}

Map<Package, Set<Package>> buildDependencyGraph(List<Package> packages) {
  final packageMap = Map.fromEntries(
    packages.map((pubspec) => MapEntry(pubspec.pubspec.name, pubspec)),
  );

  final depGraph = <Package, Set<Package>>{};

  for (final package in packages) {
    depGraph[package] ??= Set<Package>();
    // Search packages dependencies for local dependency
    for (final depEntry in [
      ...package.pubspec.dependencies.entries,
      ...package.pubspec.devDependencies.entries
    ]) {
      final depName = depEntry.key;
      final dep = depEntry.value;

      if (dep is PathDependency) {
        if (packageMap.containsKey(depName)) {
          depGraph[package]!.add(packageMap[depName]!);
          depGraph[package]!
              .addAll(_findDependencies(graph: depGraph, package: package));
        }
      }
    }
  }

  for (final package in packages) {
    depGraph[package]!
        .addAll(_findDependencies(graph: depGraph, package: package));
  }

  return depGraph;
}

Set<Package> _findDependencies({
  required Map<Package, Set<Package>> graph,
  required Package package,
}) {
  final ans = Set<Package>();
  if (graph.containsKey(package)) {
    for (final dep in graph[package]!) {
      ans.add(dep);
      ans.addAll(
        _findDependencies(graph: graph, package: dep),
      );
    }
  }
  return ans;
}

class Job {
  const Job({
    required this.usesFlutter,
    required this.name,
    required this.packageDir,
    required this.dependenciesDirs,
    required this.coverageExclude,
    required this.minimumCoverage,
    required this.globPath,
  });

  Map<String, dynamic> toJson() => {
        'usesFlutter': usesFlutter,
        'name': name,
        'packageDir': packageDir,
        'globPath': globPath,
        'dependenciesDirs': dependenciesDirs,
        'coverageExclude': coverageExclude.join(' '),
        'hasCoverageExcludes': hasCoverageExcludes,
        'minCoverage': minimumCoverage,
      };

  final bool usesFlutter;
  final String name;
  final String packageDir;
  final String dependenciesDirs;
  final List<String> coverageExclude;
  final num minimumCoverage;
  final String globPath;

  bool get hasCoverageExcludes => coverageExclude.isNotEmpty;
}

class Package {
  const Package({
    required this.packageDir,
    required this.pubspec,
    required this.coverageExclude,
    required this.packageGlobPath,
    this.minimumCoverage,
  });
  final String packageDir;
  final Pubspec pubspec;
  final List<String> coverageExclude;
  final String packageGlobPath;
  final num? minimumCoverage;
}
