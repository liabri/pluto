# Navigate to your public JS folder
mkdir -p static/js
cd static/js

# Set the version to 0.4.0 (Proven UMD paths)
VER="0.18.0"

# --- 1. Dependencies ---
curl -L -o react.min.js "https://unpkg.com/react@18.3.1/umd/react.production.min.js"
curl -L -o react-dom.min.js "https://unpkg.com/react-dom@18.3.1/umd/react-dom.production.min.js"
curl -L -o rxjs.min.js "https://unpkg.com/rxjs@7.8.1/dist/bundles/rxjs.umd.min.js"
curl -L -o echarts.min.js "https://unpkg.com/echarts@5.6.0/dist/echarts.min.js"
curl -L -o univer-protocol.js "https://unpkg.com/@univerjs/protocol@0.1.48/lib/umd/index.js"

# --- 2. Univer Core (Crucial for the 'UniverCore' namespace) ---
curl -L -o univer-core.js "https://unpkg.com/@univerjs/core@${VER}/lib/umd/index.js"

# --- 3. Univer Presets & Sheets ---
curl -L -o univer-presets.js "https://unpkg.com/@univerjs/presets@${VER}/lib/umd/index.js"
curl -L -o univer-sheets-core.js "https://unpkg.com/@univerjs/preset-sheets-core@${VER}/lib/umd/index.js"
curl -L -o univer-themes.js "https://unpkg.com/@univerjs/themes@0.18.0/lib/umd/index.js"

# --- 4. The Locale (Verified path for 0.4.0) ---
curl -L -o univer-sheets-en-US.js "https://unpkg.com/@univerjs/preset-sheets-core@${VER}/lib/umd/locales/en-US.js"

# --- 5. CSS ---
curl -L -o univer-sheets.css "https://unpkg.com/@univerjs/preset-sheets-core@${VER}/lib/index.css"
curl -L -o univer-design.css "https://unpkg.com/@univerjs/design@0.5.2/lib/index.css"

echo "All files successfully downloaded via curl!"
