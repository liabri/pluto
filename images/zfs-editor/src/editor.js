import { EditorView, basicSetup } from "codemirror"
import { markdown } from "@codemirror/lang-markdown"
import { oneDark } from "@codemirror/theme-one-dark"
import { keymap } from "@codemirror/view"
import { indentWithTab } from "@codemirror/commands";

const saveFile = async (view, filename) => {
	const content = view.state.doc.toString();
	try {
		const response = await fetch(`api/save?file=${filename}`, {
			method: `POST`,
			body: content
		});
		if (response.ok) {
			console.log(`Successfully saved: ${filename}`);
		}
	} catch (err) {
		console.error("Saving of file failed:", err);
	}
	return true;
};


document.addEventListener("DOMContentLoaded", async () => {
	const params = new URLSearchParams(window.location.search);
	const filename = params.get('file');
	if (!filename) return;

	// create the editor
	const view = new EditorView({
		doc: "",
		extensions: [
			basicSetup, 
			markdown(), 
			oneDark, 
			keymap.of([
				{
					key: "Mod-s",
					run: (view) => saveFile(view, filename)
				},
				indentWithTab
			])
		],
		parent: document.getElementById("editor")
	});

	// load the file content from orchestrator api
	try {
		const response = await fetch(`api/load?file=${filename}`);
		if (response.ok) {
			const data = await response.text();	
			view.dispatch({ 
				changes: { from: 0, to: view.state.doc.length, insert: data }
			});
		}
	} catch (e) {
		console.error("Loading of file failed:", e)
	}
});
