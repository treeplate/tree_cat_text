import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.dark(),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key});

  @override
  State<StatefulWidget> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  File? file;
  Directory dir = Directory.current;

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tree Dog Text"),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                file = null;
              });
            },
            child: Text('Open File'),
          )
        ],
      ),
      body: file == null
          ? FilePicker(dir, (file2) {
              setState(() {
                file = file2;
                dir = file2.parent;
              });
            })
          : Editor(file!.path),
    );
  }
}

class FilePicker extends StatefulWidget {
  final Directory startDir;
  final void Function(File) callback;
  const FilePicker(this.startDir, this.callback, {super.key});

  @override
  State<FilePicker> createState() => _FilePickerState();
}

class _FilePickerState extends State<FilePicker> {
  late Directory dir;

  @override
  void initState() {
    dir = widget.startDir;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text("Directory ${dir.path}"),
        TextButton(
          onPressed: () {
            setState(() {
              dir = dir.parent;
            });
          },
          child: Text('.. (directory)'),
        ),
        ...(dir.listSync()..sort((a, b) => a.path.compareTo(b.path))).map(
          (e) => e is File
              ? TextButton(
                  onPressed: () {
                    widget.callback(e);
                  },
                  child: Text('${e.uri.pathSegments.last} (file)'),
                )
              : TextButton(
                  onPressed: () {
                    setState(() {
                      dir = e as Directory;
                    });
                  },
                  child: Text('${(e.path.split('/')).last} (directory)'),
                ),
        )
      ],
    );
  }
}

class Editor extends StatefulWidget {
  Editor(this.filename);
  final String filename;

  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  void initState() {
    super.initState();
    try {
      if (File(filename).existsSync()) {
        _text = File(filename).readAsStringSync();
      } else {
        File(filename).createSync();
      }
    } on FileSystemException catch (e, st) {
      print("===caught error===\n$e\n$st\n=========");
    }
    Timer.periodic(
      Duration(seconds: 1),
      (Timer x) {
        if (mounted) {
          setState(() {
            if (running == null) {
              _text = "(loading file some more...)";
              try {
                if (File(filename).existsSync()) {
                  _text = File(filename).readAsStringSync();
                } else {
                  File(filename).createSync();
                }
              } on FileSystemException catch (e, st) {
                print("======\n$e\n$st\n=========");
              }
            } else {
              running!.stdin.write('r\n');
            }
          });
        }
      },
    );
  }

  String _text = "(loading file...)";
  int cursorPos = 0;
  String get filename => widget.filename;
  Process? running;
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    try {
      if (event is KeyDownEvent) {
        setState(() {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              cursorPos > 0) {
            cursorPos--;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              cursorPos < _text.length) {
            cursorPos++;
          } else if ((event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.delete) &&
              cursorPos > 0) {
            _text = _text.replaceRange(cursorPos - 1, cursorPos, "");
            cursorPos--;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _text = _text.replaceRange(cursorPos, cursorPos, "\n");
            cursorPos++;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            int pos = 0;
            while (cursorPos != 0 && _text[cursorPos - 1] != "\n") {
              pos++;
              cursorPos--;
            }
            cursorPos--;
            while (cursorPos > 0 && _text[cursorPos - 1] != "\n") cursorPos--;
            while (pos > 0) {
              if (cursorPos > _text.length - 1 ||
                  cursorPos < 0 ||
                  _text[cursorPos] == "\n") break;
              pos--;
              cursorPos++;
            }
            if (cursorPos < 0) cursorPos = 0;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            int pos = 0;
            int cursor = cursorPos;
            while (cursorPos > 0 && _text[cursorPos - 1] != "\n") cursorPos--;
            while (cursor != cursorPos) {
              pos++;
              cursorPos++;
              if (_text.length == cursorPos) return;
            }
            //print(pos);
            //print(_text[cursorPos]);
            while (cursorPos < _text.length && _text[cursorPos] != "\n")
              cursorPos++;
            if (cursorPos >= _text.length) {
              return;
            }
            cursorPos++;
            while (pos > 0) {
              if (_text.length == cursorPos || _text[cursorPos] == "\n") break;
              //print(_text[cursorPos]);
              //print(pos);
              pos--;
              cursorPos++;
            }
            //print(_text[cursorPos]);
          } else if (event.logicalKey == LogicalKeyboardKey.f5) {
            if (running != null) {
              running!.stdin.write('R\n');
              _text = 'Restarting process...';
              return;
            }
            List<String> command =
                File(File(filename).parent.path + '/.tct/run.txt')
                    .readAsLinesSync();
            Process.start(command.first, command.skip(1).toList(),
                    workingDirectory: File(filename).parent.path)
                .then(
              (value) {
                running = value;
                _text = 'Process started.';
                running!.stdout.listen((event) {
                  String t = utf8.decode(event);
                  _text += t;
                });
                running!.stderr.listen((event) {
                  _text += utf8.decode(event);
                });
                running!.exitCode.then((i) {
                  running = null;
                });
              },
            );
          } else if (event.logicalKey != LogicalKeyboardKey.arrowLeft &&
              event.logicalKey != LogicalKeyboardKey.arrowRight &&
              event.logicalKey != LogicalKeyboardKey.arrowUp &&
              event.logicalKey != LogicalKeyboardKey.arrowDown &&
              !(event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.delete)) {
            _text =
                _text.replaceRange(cursorPos, cursorPos, event.character ?? '');
            cursorPos += event.character == null ? 0 : 1;
          } else {}
        });
        File file = File(filename);
        file.writeAsStringSync(_text);
      }
    } on NoSuchMethodError catch (e, st) {
      print("=====\ncaught error $e\n$st\n=======");
    }
    return KeyEventResult.handled;
  }

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String get text => (' ' + _text.split('').join(' ') + ' ')
      .replaceRange(cursorPos * 2, cursorPos * 2 + 1, "|");
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Focus(
          onKeyEvent: _handleKeyEvent,
          autofocus: true,
          child: AnimatedBuilder(
            animation: _focusNode,
            builder: (BuildContext context, Widget? child) {
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: Container(
                  decoration:
                      BoxDecoration(border: Border.all(color: Colors.black)),
                  child: ListBody(
                      children: text.split("\n").map(
                    (e) {
                      return Text(
                        e,
                        style: TextStyle(fontFamily: 'RobotoMono'),
                      );
                    },
                  ).toList()),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}
