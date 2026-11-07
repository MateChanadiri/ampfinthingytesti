# AmpFin (modules)

Music player with Apple Music-style tabs (Home, New, Radio, Library, Search), iOS 26 Liquid Glass, and a JavaScript module system. No server login: music comes from `.js` modules you add in the app.

## Get the IPA
1. Push this folder to a GitHub repo (branch `main`). Make sure `.github/workflows/build-ipa.yml` is included.
2. Repo → **Actions** → **Build IPA** → wait for green (also runs on every push, or use *Run workflow*).
3. Open the run → **Artifacts** → `AmpFin-ipa` → download the zip → unzip → `AmpFin.ipa`.
4. The IPA is **unsigned**. Install it with AltStore, SideStore, Sideloadly or TrollStore.

## Add a module
Library tab → **Add Module** (or the button on Home) → pick a `.js` file. Try `modules/example-itunes.js` first.

A module is CommonJS. Every function is optional and may be `async`. `fetch(url, {method, headers, body})` and `setTimeout` are available.

```js
module.exports = {
  name: "My Source",
  home:   async () => [{ title: "Top", items: [song, song] }],  // Home tab
  new:    async () => [{ title: "Fresh", items: [song] }],       // New tab
  radio:  async () => [{ title: "Chill", items: [song] }],       // Radio tab
  search: async (query) => [song],                               // Search tab
  resolve:  async (song) => "https://…/audio.mp3",               // stream URL (optional if song.url set)
  download: async (song) => "https://…/audio.mp3"                // download URL (falls back to resolve, then song.url)
};
// song = { id, title, artist, album, artwork, url, duration }
```
Downloads are saved in the app's `Music` folder (visible in the Files app) and play offline.

Limits: modules can't set custom HTTP headers on the audio request; no ES-module `import`/`export` syntax.
