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
			updatePreview();
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

lastModified = null;
async function updatePreview() {
	const iframe = document.querySelector("iframe");
	const url = new URL(iframe.src);

	const res = await fetch(url, { method: "HEAD", cache: "no-store" });
	lastModified = res.headers.get("Last-Modified");

	// start polling
	const poll = setInterval(async () => {
		const res = await fetch(url, { method: "HEAD", cache: "no-store" });
		const mod = res.headers.get("Last-Modified");

		if (mod && mod !== lastModified) {
			// file updated, therefore reload iframe
			url.searchParams.set("t", Date.now()); // cache-bust
			iframe.src = url.toString();

			clearInterval(poll);
		}
	}, 500);
}
