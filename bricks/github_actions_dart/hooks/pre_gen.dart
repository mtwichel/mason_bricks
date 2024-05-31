import 'dart:io';

import 'package:collection/collection.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:mason/mason.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

Future<void> run(HookContext context) async {
  final searchingCallback = context.logger.progress('Searching for packages.');
  final pubspecs = await getPackages();
  searchingCallback.complete('Found ${pubspecs.length} packages.');
  final depGraph = buildDependencyGraph(pubspecs);
  final jobs = depGraph.keys.map((package) {
    final currentDependencies = depGraph[package]!
        .map((dep) => '      - "${dep.packageDir}/**"')
        .sorted();

    final config =
        readConfigFile(logger: context.logger, path: package.packageDir);

    final rawConfigCoverageExclude = config['coverage_exclude'];
    final configCoverageExclude = switch (rawConfigCoverageExclude) {
      String() => [rawConfigCoverageExclude],
      List<String>() => rawConfigCoverageExclude,
      List() => List<String>.from(rawConfigCoverageExclude),
      _ => null,
    };

    final rawConfigReportOn = config['report_on'];
    final configReportOn = switch (rawConfigReportOn) {
      String() => [rawConfigReportOn],
      List<String>() => rawConfigReportOn,
      List() => List<String>.from(rawConfigReportOn),
      _ => null,
    };

    final rawConfigAnalyzeDirectories = config['analyze_directories'];
    final configAnalyzeDirectories = switch (rawConfigAnalyzeDirectories) {
      String() => [rawConfigAnalyzeDirectories],
      List<String>() => rawConfigAnalyzeDirectories,
      List() => List<String>.from(rawConfigAnalyzeDirectories),
      _ => null,
    };

    final rawConfigFormatDirectories = config['format_directories'];
    final configFormatDirectories = switch (rawConfigFormatDirectories) {
      String() => [rawConfigFormatDirectories],
      List<String>() => rawConfigFormatDirectories,
      List() => List<String>.from(rawConfigFormatDirectories),
      _ => null,
    };

    bool usesFlutter(Package package) {
      return package.usesFlutter ||
          depGraph[package]!.any((dependency) => usesFlutter(dependency));
    }

    return Job(
      name: package.pubspec.name,
      packageDir: package.packageDir,
      globPath: package.packageGlobPath,
      usesFlutter: usesFlutter(package),
      dependenciesDirs: currentDependencies.join('\n'),
      minimumCoverage: getMinCov(
        package: package,
        context: context,
        config: config,
      ),
      coverageExcludes: configCoverageExclude ?? [],
      analyzeDirectories: configAnalyzeDirectories ?? [],
      formatDirectories: configFormatDirectories ?? [],
      reportOnDirectories: configReportOn ?? [],
    );
  });

  final rawExclude = context.vars['exclude'];
  final exclude = switch (rawExclude) {
    String() => rawExclude.split(' '),
    _ => const <String>[],
  };

  final finalJobs = jobs
      .whereNot((job) => exclude.contains(job.name))
      .sorted(((a, b) => a.name.compareTo(b.name)))
      .map((e) => e.toJson())
      .toList();

  context.vars = {
    ...context.vars,
    'jobs': finalJobs,
  };
}

Future<List<Package>> getPackages() async {
  final pubspecMatcher = Glob("**pubspec.yaml");
  final defaultExcludedPaths = [
    'ios',
    'macos',
    '.dart_tool',
    'bricks',
    '.fvm',
    'build'
  ];
  final badMatcher = RegExp(defaultExcludedPaths.join('|'));

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

      packages.add(
        Package(
          packageGlobPath: globPath,
          packageDir: parentPath.startsWith('./')
              ? parentPath.substring(2)
              : parentPath,
          pubspec: pubspec,
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

Map<String, dynamic> readConfigFile({
  required String path,
  required Logger logger,
}) {
  final file = File('$path/actions_config.yaml');

  if (!file.existsSync()) {
    return const {};
  }
  final fileText = file.readAsStringSync();
  try {
    final fileJson = loadYaml(fileText) as YamlMap;
    return {
      for (final MapEntry(:key, :value) in fileJson.entries)
        key.toString(): switch (value) {
          YamlMap() => {...value},
          YamlList() => [...value],
          _ => value,
        }
    };
  } on YamlException catch (e) {
    logger.warn(e.message);
    return const {};
  } catch (e) {
    logger.warn(e.toString());
    return const {};
  }
}

num getMinCov({
  required Package package,
  required HookContext context,
  required Map<String, dynamic> config,
}) {
  final configMinimumCoverage = config['minimum_coverage'];
  if (configMinimumCoverage is num) {
    return configMinimumCoverage;
  }
  if (context.vars['minCoverage'] is num) {
    return context.vars['minCoverage'];
  }
  if (context.vars['minCoverage'] is String) {
    return num.parse(context.vars['minCoverage']!);
  }
  return 100;
}

class Job {
  const Job({
    required this.usesFlutter,
    required this.name,
    required this.packageDir,
    required this.dependenciesDirs,
    required this.coverageExcludes,
    required this.minimumCoverage,
    required this.globPath,
    required this.analyzeDirectories,
    required this.formatDirectories,
    required this.reportOnDirectories,
  });

  Map<String, dynamic> toJson() => {
        'usesFlutter': usesFlutter,
        'name': name,
        'packageDir': packageDir,
        'globPath': globPath,
        'dependenciesDirs': dependenciesDirs,
        'coverageExclude': coverageExcludes.join(' '),
        'hasCoverageExcludes': coverageExcludes.isNotEmpty,
        'minCoverage': minimumCoverage,
        'analyzeDirectories': analyzeDirectories.join(' '),
        'formatDirectories': formatDirectories.join(' '),
        'reportOnDirectories': reportOnDirectories.join(','),
        'hasAnalyzeDirectories': analyzeDirectories.isNotEmpty,
        'hasFormatDirectories': formatDirectories.isNotEmpty,
        'hasReportOnDirectories': reportOnDirectories.isNotEmpty,
      };

  final bool usesFlutter;
  final String name;
  final String packageDir;
  final String dependenciesDirs;
  final List<String> coverageExcludes;
  final List<String> analyzeDirectories;
  final List<String> reportOnDirectories;
  final List<String> formatDirectories;
  final num minimumCoverage;
  final String globPath;

  bool get hasAnalyzeDirectories => analyzeDirectories.isNotEmpty;
  bool get hasFormatDirectories => formatDirectories.isNotEmpty;
  bool get hasReportOnDirectories => reportOnDirectories.isNotEmpty;
}

class Package {
  const Package({
    required this.packageDir,
    required this.pubspec,
    required this.packageGlobPath,
  });
  final String packageDir;
  final Pubspec pubspec;
  final String packageGlobPath;
}

extension on Package {
  bool get usesFlutter => pubspec.dependencies.containsKey('flutter');
}
