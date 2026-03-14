import { readFileSync, writeFileSync, readdirSync } from "fs";
import { join } from "path";

const dir = "node_modules/aniwatch/dist";

function walk(folder) {
    for (const file of readdirSync(folder, { withFileTypes: true })) {
        const full = join(folder, file.name);
        if (file.isDirectory()) {
            walk(full);
        } else if (file.name.endsWith(".js")) {
            const content = readFileSync(full, "utf-8");
            if (content.includes("hianime.to")) {
                writeFileSync(full, content.replaceAll("hianime.to", "hianime.cv"));
                console.log("Patched:", full);
            }
        }
    }
}

walk(dir);
console.log("Done patching aniwatch.");
