import 'dart:io';

import 'package:args/args.dart';

import 'download.dart';

bool verbose = false;
bool lyrics = false;

final parser = ArgParser();

void log(Object? o) {
  if (verbose) print(o.toString());
}

String help() {
  return "ezmd: Easily download songs from a query, file of queries or a spotify playlist\n" +
      parser.usage;
}

final download = Download(log: log);

void main(List<String> arguments) async {
  String? outPath;
  String? query;

  parser.addFlag("help", abbr: "h");
  parser.addOption("folder",
      abbr: "f", help: "Target folder", defaultsTo: null);
  parser.addOption("intype",
      abbr: "t",
      help: "How to interpret the input",
      allowed: ["query", "file", "spotify-song", "spotify-playlist"],
      defaultsTo: "query");
  parser.addFlag("lyrics",
      abbr: "l",
      help: "Append ' Lyrics' to the Youtube query",
      defaultsTo: false);
  parser.addFlag("verbose",
      abbr: "v", help: "Print out extra information", defaultsTo: false);
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (_) {
    stderr.writeln("Argument error\n${help()}");
    return;
  }
  if (results["help"] == true) {
    print(help());
    return;
  }

  lyrics = results["lyrics"] == true;
  verbose = results["verbose"] == true;

  // Get target folder
  outPath = results["folder"] ?? "./";
  if (outPath == null || outPath.isEmpty) {
    stderr.writeln("Invalid output path");
    return;
  }

  // Get query and download song
  switch (results["intype"]) {
    case "query":
      query = results.rest.join(" ");
      download.fromQuery(query, outPath);
      break;
    case "file":
      for (final filename in results.rest) {
        for (final query in File(filename).readAsLinesSync()) {
          try {
            download.fromQuery(query.trim(), outPath);
          } catch (e) {
            stderr.writeln("Failed to download $query");
            continue;
          }
        }
      }
      break;
    case "spotify-song":
      break;
    case "spotify-playlist":
      for (final link in results.rest) {
        final tracks = await download.playlistTracks(link);
        if (tracks == null) {
          stderr.writeln("Something went wrong while downloading $link");
          return;
        }
        for (final track in tracks) {
          print("current: $track");
          try {
            download.fromTrack(track, outPath);
          } catch (e) {
            stderr.writeln("Failed to download ${track.name}");
            continue;
          }
        }
      }
      break;
  }
}
