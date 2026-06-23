import { select, multiselect, confirm, text, intro, outro, note, isCancel } from '@clack/prompts';
import kleur from 'kleur';
import fs from 'fs';
import path from 'path';
import https from 'https';
import { spawnSync } from 'child_process';

const { bold, green, yellow, cyan, gray, red } = kleur;

const REPO = 'ivan-cavero/opencode-research-agent';
const RAW = `https://raw.githubusercontent.com/${REPO}/main`;
const HOME = process.env.HOME || process.env.USERPROFILE || '~';
const CONFIG_DIR = path.join(HOME, '.config', 'opencode');
const AGENTS_DIR = path.join(CONFIG_DIR, 'agents');

function getJSON(url) {
    return new Promise((resolve) => {
        https.get(url, { timeout: 5000 }, (res) => {
            let d = '';
            res.on('data', (c) => d += c);
            res.on('end', () => { try { resolve(JSON.parse(d)); } catch { resolve(null); } });
        }).on('error', () => resolve(null));
    });
}

function getText(url) {
    return new Promise((resolve) => {
        https.get(url, { timeout: 10000 }, (res) => {
            let d = '';
            res.on('data', (c) => d += c);
            res.on('end', () => resolve(d));
        }).on('error', () => resolve(null));
    });
}

function download(url, dest) {
    return new Promise((resolve) => {
        const file = fs.createWriteStream(dest);
        https.get(url, { timeout: 15000 }, (res) => {
            res.pipe(file);
            file.on('finish', () => { file.close(); resolve(true); });
        }).on('error', () => { file.close(); try { fs.unlinkSync(dest); } catch {} resolve(false); });
    });
}

function run(cmd) {
    const sh = process.platform === 'win32';
    return spawnSync(sh ? 'cmd' : 'bash', [sh ? '/c' : '-c', cmd], { stdio: 'pipe' });
}

async function writeProvider(configFile, id, name, url, key, model) {
    try {
        const cfg = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
        if (!cfg.provider) cfg.provider = {};
        cfg.provider[id] = {
            npm: '@ai-sdk/openai-compatible',
            name,
            options: { baseURL: url, ...(key ? { apiKey: key } : {}) },
            models: { [model]: { name: `${name} ${model}`, tool_call: true, limit: { context: 128000, output: 65536 } } }
        };
        cfg.model = `${id}/${model}`;
        fs.writeFileSync(configFile, JSON.stringify(cfg, null, 2));
    } catch (e) { note(red(`Error: ${e.message}`)); }
}

async function main() {
    intro(bold('OpenCode Research Agent Installer'));

    // Runtime
    const hasNode = !!(process.versions && process.versions.node);
    const hasBun = typeof Bun !== 'undefined';
    if (hasNode) note(`Node ${process.version}`);
    if (hasBun) note(`Bun v${Bun.version}`);
    if (!hasNode && !hasBun) { outro(red('Node.js or Bun required')); process.exit(1); }

    // OpenCode detection
    let hasCLI = false, hasDesktop = false;
    if (spawnSync('opencode', ['--version'], { stdio: 'pipe' }).status === 0) hasCLI = true;
    if (fs.existsSync('/opt/OpenCode/ai.opencode.desktop')) hasDesktop = true;
    if (fs.existsSync('/Applications/OpenCode.app')) hasDesktop = true;
    if (process.platform === 'win32') {
        const ld = process.env.LOCALAPPDATA || '';
        if (fs.existsSync(path.join(ld, 'Programs', 'opencode-desktop'))) hasDesktop = true;
        if (fs.existsSync(path.join(process.env.ProgramFiles || 'C:\\Program Files', 'OpenCode'))) hasDesktop = true;
    }
    note(`${hasCLI ? green('CLI') : yellow('CLI')} detected`);
    note(`${hasDesktop ? green('Desktop') : yellow('Desktop')} detected`);

    if (!hasCLI && !hasDesktop) { outro(red('No OpenCode found')); process.exit(1); }

    // Target
    const target = await select({
        message: 'Install for?',
        options: [
            { label: 'CLI (terminal)', value: 'cli' },
            { label: 'Desktop (GUI)', value: 'desktop' },
            ...(hasCLI && hasDesktop ? [{ label: 'Both CLI + Desktop', value: 'both' }] : []),
        ]
    });
    if (isCancel(target)) process.exit(0);
    note(`Target: ${target === 'both' ? 'cli desktop' : target}`);

    // Agents
    fs.mkdirSync(AGENTS_DIR, { recursive: true });
    for (const agent of ['research.md', 'deep-research.md', 'verifier.md', 'code.md', 'docs-writer.md']) {
        const ok = await download(`${RAW}/agents/${agent}`, path.join(AGENTS_DIR, agent));
        note(`${ok ? green('✓') : yellow('✗')} ${agent}`);
    }

    // Config
    let configFile = '';
    if (fs.existsSync(path.join(CONFIG_DIR, 'opencode.jsonc'))) configFile = path.join(CONFIG_DIR, 'opencode.jsonc');
    else if (fs.existsSync(path.join(CONFIG_DIR, 'opencode.json'))) configFile = path.join(CONFIG_DIR, 'opencode.json');
    if (!configFile) {
        const fmt = await select({
            message: 'Config format',
            options: [{ label: 'opencode.jsonc', value: 'jsonc', hint: 'recommended' }, { label: 'opencode.json', value: 'json' }]
        });
        configFile = path.join(CONFIG_DIR, `opencode.${fmt}`);
        fs.mkdirSync(CONFIG_DIR, { recursive: true });
        fs.writeFileSync(configFile, JSON.stringify({ $schema: 'https://opencode.ai/config.json', default_agent: 'research' }, null, 2));
    }
    note(`Config: ${configFile}`);

    // MCPs
    const mcps = await multiselect({
        message: 'MCP Servers (optional)',
        options: [
            { label: 'searxng', value: 'searxng', hint: 'web search (needs Docker)', selected: true },
            { label: 'arxiv', value: 'arxiv', hint: 'academic papers', selected: true },
        ]
    });
    if (isCancel(mcps)) process.exit(0);

    if (mcps.length > 0) {
        const frag = await getText(`${RAW}/opencode.json`);
        if (frag) {
            try {
                const cfg = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
                const fragment = JSON.parse(frag);
                if (!cfg.mcp) cfg.mcp = {};
                for (const key of mcps) { if (fragment.mcp && fragment.mcp[key]) cfg.mcp[key] = fragment.mcp[key]; }
                if (!cfg.default_agent) cfg.default_agent = 'research';
                fs.writeFileSync(configFile, JSON.stringify(cfg, null, 2));
                note(`MCPs added: ${mcps.join(', ')}`);
            } catch (e) { note(yellow(`MCP merge failed: ${e.message}`)); }
        }
    }

    // Default agent
    const agent = await select({
        message: 'Default agent',
        options: [
            { label: 'research', value: 'research', hint: 'web search & comparisons', selected: true },
            { label: 'deep-research', value: 'deep-research', hint: 'exhaustive investigation' },
            { label: 'verifier', value: 'verifier', hint: 'challenge conclusions' },
            { label: 'code', value: 'code', hint: 'code review & writing' },
            { label: 'docs-writer', value: 'docs-writer', hint: 'documentation' },
        ]
    });
    if (!isCancel(agent)) {
        try { const cfg = JSON.parse(fs.readFileSync(configFile, 'utf-8')); cfg.default_agent = agent; fs.writeFileSync(configFile, JSON.stringify(cfg, null, 2)); note(`Default agent: ${agent}`); } catch {}
    }

    // Provider
    const addProvider = await confirm('Add a custom provider?', { initialValue: false });
    if (!isCancel(addProvider) && addProvider) {
        const providerChoice = await select({
            message: 'Select provider',
            options: [
                { label: 'NaN', value: 'nan', hint: 'nan.builders — free credits included', selected: true },
                { label: 'OpenAI', value: 'openai', hint: 'api.openai.com' },
                { label: 'Custom', value: 'custom', hint: 'any OpenAI-compatible API' },
            ]
        });
        if (isCancel(providerChoice)) process.exit(0);

        let pid, pname, purl, pkey, pmodel;
        if (providerChoice === 'nan') {
            pid = 'nan'; pname = 'NaN'; purl = 'https://api.nan.builders/v1';
            pkey = await text({ message: 'API key (optional, press Enter to skip)', initialValue: '' });
            const models = await getJSON(`${purl}/models`);
            if (models && models.data && models.data.length > 0) {
                const modelChoices = models.data.map(m => ({
                    label: m.id, value: m.id,
                    hint: m.id.includes('deepseek') ? '1M context, reasoning' : '',
                    selected: m.id.includes('deepseek') || m.id.includes('flash'),
                }));
                pmodel = await select({ message: 'Default model', options: modelChoices });
            } else { pmodel = await text({ message: 'Model name', initialValue: 'deepseek-v4-flash' }); }
        } else if (providerChoice === 'openai') {
            pid = 'openai'; pname = 'OpenAI'; purl = 'https://api.openai.com/v1';
            pkey = await text({ message: 'API key', initialValue: '' });
            pmodel = await text({ message: 'Model', initialValue: 'gpt-4o' });
        } else {
            pid = await text({ message: 'Provider ID (e.g. myprovider)', initialValue: 'myprovider' });
            pname = await text({ message: 'Display name', initialValue: 'My Provider' });
            purl = await text({ message: 'Base URL', initialValue: 'https://api.example.com/v1' });
            pkey = await text({ message: 'API key (optional)', initialValue: '' });
            const models = await getJSON(`${purl}/models`);
            if (models && models.data && models.data.length > 0) {
                pmodel = await select({ message: 'Default model', options: models.data.map(m => ({ label: m.id, value: m.id })) });
            } else { pmodel = await text({ message: 'Model name', initialValue: 'gpt-4o' }); }
        }
        if (!isCancel(pmodel)) {
            await writeProvider(configFile, pid, pname, purl, pkey, pmodel);
            note(`Provider '${pid}' + model '${pmodel}'`);
        }
    }

    // Pre-download MCPs
    if (mcps.length > 0) {
        for (const mcp of mcps) {
            const cmd = mcp === 'searxng'
                ? 'bunx -y -p one-search-mcp one-search-mcp --version 2>/dev/null; npx -y -p one-search-mcp one-search-mcp --version 2>/dev/null'
                : 'bunx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version 2>/dev/null; npx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version 2>/dev/null';
            const ok = run(cmd).status === 0;
            note(`${ok ? green('✓') : yellow('⚠')} ${mcp}`);
        }
    }

    outro(bold('Installation complete!'));
    note(`  Runtime:  ${hasBun ? 'Bun' : 'Node'}`);
    note(`  Target:   ${target === 'both' ? 'cli desktop' : target}`);
    note(`  Config:   ${configFile}`);
    note(`  MCPs:     ${mcps.length ? mcps.join(', ') : 'none'}`);
    note(`  Agent:    ${!isCancel(agent) ? agent : 'none'}`);
    if (mcps.includes('searxng')) {
        note('');
        note(yellow('→ Start SearXNG:'));
        note('    docker run -d --name searxng -p 8080:8080 searxng/searxng');
    }
    note('');
    note('  Restart OpenCode. Agents appear as tabs.');
}

main().catch((e) => { outro(red(e.message)); process.exit(1); });
