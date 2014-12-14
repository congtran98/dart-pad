
library editor.ace;

import 'dart:async';
import 'dart:html' as html;

import 'package:ace/ace.dart' as ace;
import 'package:ace/proxy.dart';

import 'editor.dart';

export 'editor.dart';

final AceFactory aceFactory = new AceFactory._();

// TODO: remove line numbers

// TODO: underline errors and warnings

// TODO: improve the styling for error and warning icons

// TODO: how to show errors and warnings that are off screen?

class AceFactory extends EditorFactory {
  static final String cssRef = 'packages/liftoff/editing/editor_ace.css';
  static final String jsRef = 'packages/ace/src/js/ace.js';

  AceFactory._();

  List<String> get modes => ace.Mode.MODES;
  List<String> get themes => ace.Theme.THEMES;

  bool get inited => ace.implementation != null;

  Future init() {
    // TODO: This injection is slower then hardcoding in the html file.
    html.Element head = html.querySelector('html head');

    // <link href="packages/liftoff/editing/editor_codemirror.css" rel="stylesheet">
    html.LinkElement link = new html.LinkElement();
    link.rel = 'stylesheet';
    link.href = cssRef;
    Future cssFuture = _appendNode(head, link);

    // <script src="packages/ace/src/js/ace.js"></script>
    html.ScriptElement script = new html.ScriptElement();
    script.src = jsRef;
    Future jsFuture = _appendNode(head, script);

    // <script src="packages/ace/src/js/ext-language_tools.js"></script>
    script = new html.ScriptElement();
    script.src = 'packages/ace/src/js/ext-language_tools.js';
    jsFuture = jsFuture.then((_) {
      return _appendNode(head, script);
    });

    return Future.wait([cssFuture, jsFuture]).then((_) {
      ace.implementation = ACE_PROXY_IMPLEMENTATION;
      ace.require('ace/ext/language_tools');
    });
  }

  Editor createFromElement(html.Element element, {Map options}) {
    ace.Editor editor = ace.edit(element);

    //editor.renderer.showGutter = false;
    editor.renderer.fixedWidthGutter = true;
    editor.theme = new ace.Theme.named('monokai');
    editor.highlightActiveLine = false;
    editor.highlightGutterLine = false;
    //fadeFoldWidgets = true

    if (options == null) {
      options = {'enableBasicAutocompletion': true};
    }

    editor.setOptions(options);
    // Remove the `ctrl-,` binding.
    editor.commands.removeCommand('showSettingsMenu');
    // Remove the default find and goto line dialogs - they're UI is awful.
    editor.commands.removeCommand('gotoline');
    editor.commands.removeCommand('find');

    return new _AceEditor._(this, editor);
  }
}

class _AceEditor extends Editor {
  final ace.Editor editor;

  _AceDocument _document;

  _AceEditor._(AceFactory factory, this.editor) : super(factory) {
    _document = new _AceDocument._(this, editor.session);
  }

  Document createDocument({String content, String mode}) {
    if (content == null) content = '';
    ace.EditSession session = ace.createEditSession(
        content, new ace.Mode.named(mode));
    session.tabSize = 2;
    session.useSoftTabs = true;
    session.useWorker = false;

    return new _AceDocument._(this, session);
  }

  String get mode => _document.session.mode.name;
  set mode(String str) => _document.session.mode = new ace.Mode.named(str);

  String get theme => editor.theme.name;
  set theme(String str) {
    editor.theme = new ace.Theme.named(str);
  }

  void focus() => editor.focus();
  void resize() => editor.resize(true);

  void swapDocument(Document document) {
    _document = document;
    editor.session = _document.session;
  }
}

class _AceDocument extends Document {
  final ace.EditSession session;

  bool _dirty = false;

  _AceDocument._(_AceEditor editor, this.session) : super(editor) {
    onChange.listen((_) {
      _dirty = true;
    });
  }

  String get value => session.value;
  set value(String str) {
    session.value = str;
  }

  // TODO: ace.dart should expose undoManager.isClean

  bool get isClean => !_dirty;
  void markClean() {
    _dirty = false;
  }

  void setAnnotations(List<Annotation> annotations) {
    // Sort annotations so that the errors are set first.
    annotations.sort();

    // TODO: Use the charStart and charLength information.

    session.setAnnotations(annotations.map((Annotation annotation) {
      return new ace.Annotation(text: annotation.message,
          type: annotation.type, row: annotation.line - 1);
    }).toList());
  }

  void clearAnnotations() => session.clearAnnotations();

  Stream get onChange => session.onChange;
}

Future _appendNode(html.Element parent, html.Element child) {
  Completer completer = new Completer();
  child.onLoad.listen((e) {
    completer.complete();
  });
  parent.nodes.add(child);
  return completer.future;
}