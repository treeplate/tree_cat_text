import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

String username = "TODO";

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
  MyHomePage({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tree Cat Text"),
      ),
      body: ListView(
        children: [
          /*
          Editor('/Users/$username/.tct'),
          TextButton(
            child: Text("Open File"),
            onPressed: () => setState(() {}),
          ),
          */
          Editor(
              '/Users/$username/${(File('/Users/$username/.tct')..createSync()).readAsStringSync()}'),
        ],
      ),
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
            _text = "Load...";
            try {
              if (File(filename).existsSync()) {
                _text = File(filename).readAsStringSync();
              } else {
                File(filename).createSync();
              }
            } on FileSystemException catch (e, st) {
              print("======\n$e\n$st\n=========");
            }
          });
        }
      },
    );
  }

  String _text = "Loading...";
  int cursorPos = 0;
  String get filename => widget.filename;
  void _handleKeyEvent(RawKeyEvent event) {
    try {
      if (event is RawKeyDownEvent) {
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
          } else if (event.logicalKey != LogicalKeyboardKey.arrowLeft &&
              event.logicalKey != LogicalKeyboardKey.arrowRight &&
              event.logicalKey != LogicalKeyboardKey.arrowUp &&
              event.logicalKey != LogicalKeyboardKey.arrowDown &&
              !(event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.delete)) {
            _text = _text.replaceRange(cursorPos, cursorPos, event.character);
            cursorPos++;
          }
        });
        File file = File(filename);
        file.writeAsStringSync(_text);
      }
    } on NoSuchMethodError catch (e, st) {
      print("=====\ncaught error $e\n$st\n=======");
    }
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
    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyEvent,
      child: AnimatedBuilder(
        animation: _focusNode,
        builder: (BuildContext context, Widget child) {
          if (!_focusNode.hasFocus) {
            return GestureDetector(
              onTap: () {
                FocusScope.of(context).requestFocus(_focusNode);
                _text = "Load...";
                cursorPos = 0;
                try {
                  if (File(filename).existsSync()) {
                    _text = File(filename).readAsStringSync();
                  } else {
                    File(filename).createSync();
                  }
                } on FileSystemException catch (e, st) {
                  print("======\n$e\n$st\n=========");
                }
              },
              child: Text('Tap to focus'),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              decoration:
                  BoxDecoration(border: Border.all(color: Colors.black)),
              child: ListBody(
                  children: text
                      .split("\n")
                      .map(
                        (e) => Text(
                          e,
                          style: TextStyle(fontFamily: 'RobotoMono'),
                        ),
                      )
                      .toList()),
            ),
          );
        },
      ),
    );
  }
}
