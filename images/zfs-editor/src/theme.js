import { EditorView } from "@codemirror/view";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags as t } from "@lezer/highlight";

// 1. UI Theme: Defines the editor's structural colors (background, gutters, cursor)
export const plateauDarkTheme = EditorView.theme({
  "&": {
    color: "#e7dfdfff", // editor.foreground
    backgroundColor: "#1b1818ff" // editor.background
  },
  ".cm-content": {
    caretColor: "#7272caff" // players[0].cursor
  },
  "&.cm-focused .cm-cursor": {
    borderLeftColor: "#7272caff" //
  },
  "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection": {
    backgroundColor: "#7272ca3d" // players[0].selection
  },
  ".cm-gutters": {
    backgroundColor: "#1b1818ff", // editor.gutter.background
    color: "#666262", // editor.line_number
    border: "none"
  },
  ".cm-activeLine": {
    backgroundColor: "#252020bf" // editor.active_line.background
  },
  ".cm-activeLineGutter": {
    backgroundColor: "#252020bf", //
    color: "#e6e5e5" // editor.active_line_number
  },
  ".cm-searchMatch": {
    backgroundColor: "#7272ca66" // search.match_background
  },
  ".cm-panels": { backgroundColor: "#252020ff", color: "#f4ececff" }, // panel.background
  ".cm-textfield": {
    backgroundColor: "#1b1818ff",
    color: "#f4ececff",
    border: "1px solid #564e4eff" // border
  }
}, { dark: true });

// 2. Syntax Highlighting: Maps Zed syntax tokens to CodeMirror tags
export const plateauDarkHighlightStyle = HighlightStyle.define([
  { tag: t.keyword, color: "#8464c4ff" }, // keyword
  { tag: t.operator, color: "#8a8585ff" }, // operator
  { tag: t.string, color: "#4b8b8bff" }, // string
  { tag: [t.variableName, t.definition(t.variableName)], color: "#e7dfdfff" }, // variable
  { tag: t.comment, color: "#655d5dff" }, // comment
  { tag: [t.function(t.variableName), t.method], color: "#7272caff" }, // function
  { tag: [t.typeName, t.className, t.typeOperator], color: "#a06d3aff" }, // type
  { tag: t.number, color: "#b4593bff" }, // number
  { tag: t.bool, color: "#4b8b8bff" }, // boolean
  { tag: t.punctuation, color: "#e7dfdfff" }, // punctuation
  { tag: t.propertyName, color: "#ca4848ff" }, // property
  { tag: t.attributeName, color: "#7272caff" }, // attribute
  { tag: t.labelName, color: "#7272caff" }, // label
  { tag: t.heading, color: "#f4ececff", fontWeight: "700" }, // title
  { tag: t.url, color: "#4b8b8bff" } // link_uri
].filter(spec => {
    // filter out any specs where the tag is undefined to avoid id error
    if (Array.isArray(spec.tag)) return spec.tag.every(tag => tag !== undefined);
    return spec.tag !== undefined;
  })
);

// 3. Helper: Combines both into a single extension array for easy use
export const plateauDark = [
  plateauDarkTheme,
  syntaxHighlighting(plateauDarkHighlightStyle)
];
