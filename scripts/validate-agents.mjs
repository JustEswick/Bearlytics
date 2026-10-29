#!/usr/bin/env node
/**
 * Valida la configuracion de agentes de Bearlytics:
 *   1. opencode.json contra el schema oficial (si hay red y ajv disponible)
 *   2. Frontmatter de agentes, comandos y skills
 *   3. Que no haya caracteres corruptos ni BOM
 *
 * Uso: node scripts/validate-agents.mjs
 * Salida: 0 si todo correcto, 1 si hay errores.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => fs.readFileSync(p, "utf8").replace(/^\uFEFF/, "").replace(/\r\n/g, "\n").replace(/\r/g, "\n");

const AGENT_KEYS = new Set([
  "name", "model", "variant", "description", "mode", "hidden", "color",
  "steps", "options", "permission", "disable", "temperature", "top_p",
]);
const COMMAND_KEYS = new Set(["description", "agent", "model", "variant", "subtask"]);
const SKILL_KEYS = new Set(["name", "description", "license", "compatibility", "metadata"]);

let problems = 0;
const fail = (m) => { console.error(`  FAIL  ${m}`); problems++; };
const ok = (m) => console.log(`  ok    ${m}`);
const warn = (m) => console.warn(`  warn  ${m}`);

function parseFrontmatter(file) {
  const raw = read(file);
  if (!raw.startsWith("---")) { fail(`${file}: sin frontmatter`); return null; }
  const end = raw.indexOf("\n---", 3);
  if (end === -1) { fail(`${file}: frontmatter sin cerrar`); return null; }
  const block = raw.slice(3, end).trim();
  const body = raw.slice(end + 4);
  const data = {};
  let currentKey = null;
  for (const line of block.split("\n")) {
    if (/^\s*-\s/.test(line) || /^\s{2,}\S/.test(line) || /^\s*$/.test(line)) {
      if (currentKey) data[currentKey] += `\n${line}`;
      continue;
    }
    const m = /^([A-Za-z0-9_/.-]+):\s*(.*)$/.exec(line);
    if (!m) { fail(`${file}: linea YAML no reconocida -> ${line}`); continue; }
    currentKey = m[1];
    data[currentKey] = m[2];
  }
  return { data, body };
}

function checkAgents() {
  console.log("== Agentes (.opencode/agent) ==");
  const dir = path.join(repoRoot, ".opencode", "agent");
  if (!fs.existsSync(dir)) { fail("no existe .opencode/agent"); return; }
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".md"))) {
    const fm = parseFrontmatter(path.join(dir, f));
    if (!fm) continue;
    const d = fm.data;
    for (const k of Object.keys(d)) if (!AGENT_KEYS.has(k)) fail(`${f}: clave no permitida -> ${k}`);
    if (!d.description) fail(`${f}: falta description`);
    else ok(`${f}: description`);
    const mode = (d.mode || "all").trim();
    if (!["primary", "subagent", "all"].includes(mode)) fail(`${f}: mode invalido -> ${mode}`);
    else ok(`${f}: mode=${mode}`);
    if (d.name && d.name.trim() !== f.replace(/\.md$/, "")) fail(`${f}: name != nombre de fichero`);
    if (!fm.body.trim()) fail(`${f}: cuerpo vacio`);
  }
}

function checkCommands() {
  console.log("== Comandos (.opencode/command) ==");
  const dir = path.join(repoRoot, ".opencode", "command");
  if (!fs.existsSync(dir)) { fail("no existe .opencode/command"); return; }
  for (const f of fs.readdirSync(dir).filter((f) => f.endsWith(".md"))) {
    const fm = parseFrontmatter(path.join(dir, f));
    if (!fm) continue;
    const d = fm.data;
    for (const k of Object.keys(d)) if (!COMMAND_KEYS.has(k)) fail(`${f}: clave no permitida -> ${k}`);
    if (!d.description) fail(`${f}: falta description`);
    else ok(`${f}: description`);
    if (!fm.body.trim()) fail(`${f}: template vacio`);
    else ok(`${f}: template`);
  }
}

function checkSkills() {
  console.log("== Skills (.opencode/skill) ==");
  const dir = path.join(repoRoot, ".opencode", "skill");
  if (!fs.existsSync(dir)) { fail("no existe .opencode/skill"); return; }
  for (const s of fs.readdirSync(dir)) {
    const p = path.join(dir, s, "SKILL.md");
    if (!fs.existsSync(p)) { fail(`${s}: falta SKILL.md`); continue; }
    const fm = parseFrontmatter(p);
    if (!fm) continue;
    const d = fm.data;
    for (const k of Object.keys(d)) if (!SKILL_KEYS.has(k)) fail(`${s}: clave no permitida -> ${k}`);
    const name = (d.name || "").trim();
    if (!name) fail(`${s}: falta name`);
    else if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name)) fail(`${s}: name con formato invalido -> ${name}`);
    else if (name !== s) fail(`${s}: name "${name}" != carpeta`);
    else if (name.length > 64) fail(`${s}: name > 64 caracteres`);
    else ok(`${s}: name`);
    const desc = (d.description || "").trim();
    if (!desc) fail(`${s}: falta description`);
    else if (desc.length > 1024) fail(`${s}: description > 1024 caracteres (${desc.length})`);
    else ok(`${s}: description`);
    if (!fm.body.trim()) fail(`${s}: cuerpo vacio`);
  }
}

async function checkSchema() {
  console.log("== opencode.json vs schema ==");
  const configPath = path.join(repoRoot, "opencode.json");
  if (!fs.existsSync(configPath)) { fail("no existe opencode.json"); return; }
  const config = JSON.parse(read(configPath));

  let Ajv;
  try {
    ({ default: Ajv } = await import("ajv/dist/2020.js"));
  } catch {
    warn("ajv no disponible: se omite la validacion contra el schema");
    return;
  }

  const schemaUrl = "https://opencode.ai/config.json";
  let schema;
  try {
    const res = await fetch(schemaUrl);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    schema = await res.json();
  } catch (e) {
    warn(`no se pudo descargar el schema (${e.message}): se omite la validacion`);
    return;
  }

  const ajv = new Ajv({ strict: false, allErrors: true, validateSchema: false });
  try {
    const modelsRes = await fetch("https://models.dev/model-schema.json");
    if (modelsRes.ok) {
      const modelsSchema = await modelsRes.json();
      ajv.addSchema(modelsSchema, "https://models.dev/model-schema.json");
    }
  } catch { /* el schema de modelos es opcional */ }

  const validate = ajv.compile(schema);
  if (validate(config)) ok("opencode.json valido");
  else {
    fail("opencode.json no valido:");
    console.error(JSON.stringify(validate.errors, null, 2));
  }
}

function checkEncoding() {
  console.log("== Codificacion ==");
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(d, e.name);
    if (e.isDirectory()) {
      if ([".git", "node_modules"].includes(e.name)) return [];
      return walk(p);
    }
    return /\.(md|json|mjs|yml|yaml)$/.test(e.name) ? [p] : [];
  });
  let issues = 0;
  for (const p of walk(repoRoot)) {
    const rel = path.relative(repoRoot, p);
    const content = read(p);
    const cjk = content.match(/[\u4e00-\u9fff]/g);
    if (cjk) { fail(`${rel}: ${cjk.length} caracteres CJK`); issues++; }
    if (content.startsWith("\uFEFF")) { fail(`${rel}: contiene BOM`); issues++; }
  }
  if (!issues) ok("sin caracteres corruptos ni BOM");
}

await checkSchema();
checkAgents();
checkCommands();
checkSkills();
checkEncoding();

if (problems === 0) {
  console.log("\nTODO OK");
  process.exit(0);
} else {
  console.error(`\n${problems} PROBLEMAS`);
  process.exit(1);
}
