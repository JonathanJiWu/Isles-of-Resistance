// Stamps the game icon and version information into an exported Windows
// executable (replaces Godot's icon and "Godot Engine" file details), then
// re-reads the result to verify it.
//
//   node stamp_exe.mjs <game.exe> <icon.ico> <version> <x64|arm64>
//
// Pure JavaScript (resedit), so it runs on Linux and macOS without Wine.
// Godot 4.4 would otherwise need rcedit for this.
import fs from "node:fs";
import * as ResEdit from "resedit";

const [exePath, icoPath, version, arch] = process.argv.slice(2);
if (!exePath || !icoPath || !version || !["x64", "arm64"].includes(arch)) {
	console.error("usage: node stamp_exe.mjs <game.exe> <icon.ico> <version> <x64|arm64>");
	process.exit(2);
}

const MACHINE = { x64: 0x8664, arm64: 0xaa64 };
const STRINGS = {
	ProductName: "Isles of Resistance",
	FileDescription: "Isles of Resistance",
	CompanyName: "JonathanJiWu",
	LegalCopyright: "Copyright (c) 2025 JonathanJiWu. MIT License. Built with Godot Engine.",
	OriginalFilename: "IslesOfResistance.exe",
	InternalName: "IslesOfResistance",
	ProductVersion: version,
	FileVersion: version,
};

function fail(msg) {
	console.error(`stamp_exe: ${exePath}: ${msg}`);
	process.exit(1);
}

const exe = ResEdit.NtExecutable.from(fs.readFileSync(exePath), { ignoreCert: true });
if (exe.newHeader.fileHeader.machine !== MACHINE[arch]) {
	fail(`expected a ${arch} executable, found machine 0x${exe.newHeader.fileHeader.machine.toString(16)}`);
}
const res = ResEdit.NtExecutableResource.from(exe);

// Icon: replace every icon group (Godot ships one named GODOT_ICON).
const ico = ResEdit.Data.IconFile.from(fs.readFileSync(icoPath));
const groups = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries);
if (groups.length === 0) fail("no icon group to replace");
for (const g of groups) {
	ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, g.id, g.lang, ico.icons.map((i) => i.data));
}

// Version information, for every language the template declares.
const infos = ResEdit.Resource.VersionInfo.fromEntries(res.entries);
if (infos.length === 0) fail("no version resource");
const parts = version.split(".").map((n) => parseInt(n, 10) || 0);
while (parts.length < 4) parts.push(0);
for (const vi of infos) {
	// The numeric versions first: they also overwrite the version strings.
	vi.setFileVersion(parts[0], parts[1], parts[2], parts[3]);
	vi.setProductVersion(parts[0], parts[1], parts[2], parts[3]);
	for (const lang of vi.getAllLanguagesForStringValues()) {
		vi.removeStringValue(lang, "Info");
		vi.setStringValues(lang, STRINGS);
	}
	vi.outputToResourceEntries(res.entries);
}

res.outputResource(exe);
fs.writeFileSync(exePath, Buffer.from(exe.generate()));

// Verify what was written.
const check = ResEdit.NtExecutable.from(fs.readFileSync(exePath), { ignoreCert: true });
const checkRes = ResEdit.NtExecutableResource.from(check);
if (check.newHeader.fileHeader.machine !== MACHINE[arch]) fail("machine type changed");
const checkGroups = ResEdit.Resource.IconGroupEntry.fromEntries(checkRes.entries);
const sizes = checkGroups[0].icons.map((i) => i.width || 256).sort((a, b) => a - b);
if (checkGroups[0].icons.length !== ico.icons.length) fail("icon group size mismatch");
const vi = ResEdit.Resource.VersionInfo.fromEntries(checkRes.entries)[0];
const strings = vi.getStringValues(vi.getAllLanguagesForStringValues()[0]);
if (strings.ProductName !== STRINGS.ProductName || strings.FileVersion !== version) fail("version strings not written");
console.log(`stamped ${exePath} (${arch}): ${strings.ProductName} ${strings.FileVersion}, icon sizes ${sizes.join("/")}`);
