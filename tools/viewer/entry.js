import { basicSetup, EditorView } from 'codemirror';
import { EditorState, Compartment } from '@codemirror/state';
import { keymap } from '@codemirror/view';
import { StreamLanguage } from '@codemirror/language';
import { javascript } from '@codemirror/lang-javascript';
import { python } from '@codemirror/lang-python';
import { json } from '@codemirror/lang-json';
import { html } from '@codemirror/lang-html';
import { css } from '@codemirror/lang-css';
import { sql } from '@codemirror/lang-sql';
import { xml } from '@codemirror/lang-xml';
import { markdown } from '@codemirror/lang-markdown';
import { go } from '@codemirror/legacy-modes/mode/go';
import { rust } from '@codemirror/legacy-modes/mode/rust';
import { c, cpp, java, kotlin, csharp } from '@codemirror/legacy-modes/mode/clike';
import { shell } from '@codemirror/legacy-modes/mode/shell';
import { yaml } from '@codemirror/legacy-modes/mode/yaml';
import { toml } from '@codemirror/legacy-modes/mode/toml';
import { swift } from '@codemirror/legacy-modes/mode/swift';
import { lua } from '@codemirror/legacy-modes/mode/lua';
import { ruby } from '@codemirror/legacy-modes/mode/ruby';
import { properties } from '@codemirror/legacy-modes/mode/properties';
import { oneDark } from '@codemirror/theme-one-dark';

function extensionOf(fileName) {
  const name = fileName || '';
  const index = name.lastIndexOf('.');
  return index >= 0 ? name.slice(index + 1).toLowerCase() : '';
}

function languageFor(fileName) {
  switch (extensionOf(fileName)) {
    case 'js':
    case 'jsx':
    case 'mjs':
    case 'cjs':
      return javascript({ jsx: true });
    case 'ts':
    case 'tsx':
      return javascript({ typescript: true, jsx: true });
    case 'json':
      return json();
    case 'py':
      return python();
    case 'html':
    case 'htm':
      return html();
    case 'css':
    case 'scss':
    case 'less':
      return css();
    case 'sql':
      return sql();
    case 'xml':
    case 'svg':
      return xml();
    case 'md':
    case 'markdown':
      return markdown();
    case 'dart':
      // No dedicated Dart mode in legacy-modes; C-like highlighting is close.
      return StreamLanguage.define(java);
    case 'go':
      return StreamLanguage.define(go);
    case 'rs':
      return StreamLanguage.define(rust);
    case 'java':
      return StreamLanguage.define(java);
    case 'kt':
    case 'kts':
      return StreamLanguage.define(kotlin);
    case 'c':
    case 'h':
      return StreamLanguage.define(c);
    case 'cpp':
    case 'cc':
    case 'cxx':
    case 'hpp':
      return StreamLanguage.define(cpp);
    case 'cs':
      return StreamLanguage.define(csharp);
    case 'sh':
    case 'bash':
    case 'zsh':
      return StreamLanguage.define(shell);
    case 'yml':
    case 'yaml':
      return StreamLanguage.define(yaml);
    case 'toml':
      return StreamLanguage.define(toml);
    case 'swift':
      return StreamLanguage.define(swift);
    case 'lua':
      return StreamLanguage.define(lua);
    case 'php':
      return html();
    case 'rb':
      return StreamLanguage.define(ruby);
    case 'ini':
    case 'conf':
      return StreamLanguage.define(properties);
    default:
      return [];
  }
}

window.createEditor = function (opts) {
  const languageCompartment = new Compartment();
  const readOnlyCompartment = new Compartment();
  const themeCompartment = new Compartment();
  const saveKeymap = keymap.of([
    {
      key: 'Mod-s',
      preventDefault: true,
      run: () => {
        if (opts.onSave) opts.onSave();
        return true;
      },
    },
  ]);

  const view = new EditorView({
    parent: document.getElementById('editor'),
    state: EditorState.create({
      doc: opts.initialDoc || '',
      extensions: [
        basicSetup,
        EditorView.lineWrapping,
        saveKeymap,
        languageCompartment.of(languageFor(opts.fileName)),
        readOnlyCompartment.of(EditorState.readOnly.of(!!opts.readOnly)),
        themeCompartment.of(opts.dark ? oneDark : []),
        EditorView.updateListener.of((update) => {
          if (!update.docChanged) return;
          if (opts.onChange) opts.onChange(update.state.doc.toString());
        }),
      ],
    }),
  });

  window.__setDoc = (text) => {
    view.dispatch({
      changes: { from: 0, to: view.state.doc.length, insert: text || '' },
    });
  };
  window.__getDoc = () => view.state.doc.toString();
  window.__setReadOnly = (value) => {
    view.dispatch({
      effects: readOnlyCompartment.reconfigure(
        EditorState.readOnly.of(!!value)
      ),
    });
  };
  window.__setLanguage = (fileName) => {
    view.dispatch({
      effects: languageCompartment.reconfigure(languageFor(fileName)),
    });
  };

  if (opts.onReady) opts.onReady();
};
