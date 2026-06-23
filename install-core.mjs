#!/usr/bin/env node

// OpenCode Research Agent Installer — Cross-platform Node.js TUI
// Single self-contained file. Works on Windows, macOS, Linux.
// Uses only Node.js built-in modules — zero npm dependencies.

import fs from 'fs';
import path from 'path';
import { spawnSync, execSync } from 'child_process';
import https from 'https';
import readline from 'readline';
import { stdin, stdout, stderr } from 'process';
import { createInterface } from 'readline';

// ── Config ────────────────────────────────────────────────────────────
const REPO = 'ivan-cavero/opencode-research-agent';
const BRANCH = 'main';
const RAW = `https://raw.githubusercontent.com/${REPO}/${BRANCH}`;
const HOME_CONFIG_DIR = path.join(os_homedir(), '.config', 'opencode');
const AGENTS_DIR = path.join(HOME_CONFIG_DIR, 'agents');

function os_homedir() {
    return process.env.HOME || process.env.USERPROFILE || '~';
}

// ── ANSI helpers ───────────────────────────────────────────────────────
const isTTY = stdout.isTTY && stdin.isTTY;

const c = {
    bold:     (s) => `\x1b[1m${s}\x1b[22m`,
    dim:      (s) => `\x1b[2m${s}\x1b[22m`,
    green:    (s) => `\x1b[32m${s}\x1b[39m`,
    yellow:   (s) => `\x1b[33m${s}\x1b[39m`,
    cyan:     (s) => `\x1b[36m${s}\x1b[39m`,
    red:      (s) => `\x1b[31m${s}\x1b[39m`,
    gray:     (s) => `\x1b[90m${s}\x1b[39m`,
    blue:     (s) => `\x1b[34m${s}\x1b[39m`,
    magenta:  (s) => `\x1b[35m${s}\x1b[39m`,
    reset:    (s) => `\x1b[0m${s}`,
};

// ── Spinner ────────────────────────────────────────────────────────────
class Spinner {
    constructor(message) {
        this.message = message;
        this.frames = ['⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'];
        this.i = 0;
        this.timer = null;
        this._running = false;
    }

    start() {
        if (!isTTY) { stdout.write(`${this.message}...\n`); return this; }
        this._running = true;
        this.timer = setInterval(() => {
            stdout.write(`\r${c.cyan(this.frames[this.i])} ${this.message}`);
            this.i = (this.i + 1) % this.frames.length;
        }, 80);
        return this;
    }

    update(msg) { this.message = msg; }

    stop(success = true) {
        if (this.timer) clearInterval(this.timer);
        this._running = false;
        if (isTTY) {
            stdout.write(`\r${success ? c.green('✓') : c.yellow('⚠')} ${this.message}\n`);
        } else {
            stdout.write(`${success ? 'ok' : 'skipped'}\n`);
        }
    }

    async run(command, args) {
        this.start();
        return new Promise((resolve) => {
            try {
                const result = spawnSync(command, args, { stdio: 'pipe' });
                this.stop(result.status === 0);
                resolve(result.status === 0);
            } catch (e) {
                this.stop(false);
                resolve(false);
            }
        });
    }

    async runShell(cmd) {
        this.start();
        return new Promise((resolve) => {
            try {
                // Use bash -c on Unix, cmd /c on Windows
                const shell = process.platform === 'win32' ? 'cmd' : 'bash';
                const shellFlag = process.platform === 'win32' ? '/c' : '-c';
                const result = spawnSync(shell, [shellFlag, cmd], { stdio: 'pipe' });
                this.stop(result.status === 0);
                resolve(result.status === 0);
            } catch (e) {
                this.stop(false);
                resolve(false);
            }
        });
    }
}

// ── HTTP helper ────────────────────────────────────────────────────────
function httpsGet(url) {
    return new Promise((resolve, reject) => {
        https.get(url, { timeout: 5000 }, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                try {
                    resolve(data ? JSON.parse(data) : null);
                } catch { resolve(null); }
            });
        }).on('error', () => resolve(null));
    });
}

function httpsGetText(url) {
    return new Promise((resolve) => {
        https.get(url, { timeout: 10000 }, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', () => resolve(null));
    });
}

function httpsDownload(url, dest) {
    return new Promise((resolve) => {
        const file = fs.createWriteStream(dest);
        https.get(url, { timeout: 15000 }, (res) => {
            res.pipe(file);
            file.on('finish', () => { file.close(); resolve(true); });
        }).on('error', () => { file.close(); fs.unlinkSync(dest); resolve(false); });
    });
}

// ── TUI ────────────────────────────────────────────────────────────────

// Enable raw mode for keyboard input
function enableRaw() {
    if (!isTTY) return;
    try { stdin.setRawMode(true); } catch {}
    stdin.resume();
    readline.emitKeypressEvents(stdin);
}

function disableRaw() {
    if (!isTTY) return;
    stdin.setRawMode(false);
    stdin.pause();
}

// Banner
function banner() {
    const lines = [
        `  ${c.bold('┌──────────────────────────────────────────┐')}`,
        `  ${c.bold('│')}  ${c.cyan('OpenCode Research Agent Installer')}      ${c.bold('│')}`,
        `  ${c.bold('│')}  ${c.gray('arrows · space · enter · cross-platform')}  ${c.bold('│')}`,
        `  ${c.bold('└──────────────────────────────────────────┘')}`,
    ];
    stdout.write('\n' + lines.join('\n') + '\n\n');
}

// Frame box
function frame(title, ...items) {
    stdout.write(`\n  ${c.bold(`┌─ ${title}`)}\n`);
    stdout.write(`  ${c.bold('│')}\n`);
    for (const item of items) {
        stdout.write(`  ${c.bold('│')}   ${item}\n`);
    }
    stdout.write(`  ${c.bold('│')}\n`);
    stdout.write(`  ${c.bold('└─')}\n\n`);
}

// Multiselect with arrows + space + enter
async function multiselect(opts) {
    const { message, choices } = opts;
    const state = choices.map(c => ({
        ...c,
        selected: c.checked === true
    }));
    let cursor = 0;

    if (!isTTY) {
        return state.filter(s => s.selected).map(s => s.value);
    }

    enableRaw();

    const render = () => {
        // Move cursor up to redraw
        const totalLines = 2 + choices.length + 1;
        stdout.write(`\x1b[${totalLines}A`);

        stdout.write(`\n  ${c.bold(message)}\n`);
        for (let i = 0; i < state.length; i++) {
            const s = state[i];
            const mark = s.selected ? c.green('◉') : c.gray('○');
            const ptr = i === cursor ? c.cyan('❯') : ' ';
            const hint = s.hint ? `  ${c.gray(s.hint)}` : '';
            stdout.write(` ${ptr} ${mark} ${c.bold(s.name)}${hint}\n`);
        }
        stdout.write(`  ${c.gray('arrows · space · enter')}`);
    };

    render();

    return new Promise((resolve) => {
        const onKey = (str, key) => {
            if (key.name === 'up') {
                cursor = (cursor - 1 + state.length) % state.length;
                render();
            } else if (key.name === 'down') {
                cursor = (cursor + 1) % state.length;
                render();
            } else if (key.name === 'space') {
                state[cursor].selected = !state[cursor].selected;
                render();
            } else if (key.name === 'return' || key.name === 'enter') {
                disableRaw();
                stdin.removeListener('keypress', onKey);
                // Clear last line
                stdout.write('\n');
                resolve(state.filter(s => s.selected).map(s => s.value));
            }
        };

        stdin.on('keypress', onKey);
    });
}

// Select (single choice — arrows + enter)
async function select(opts) {
    const { message, choices } = opts;
    let cursor = 0;

    if (!isTTY) {
        // Return first checked, or first item
        const checked = choices.find(c => c.checked);
        return checked ? checked.value : choices[0].value;
    }

    enableRaw();

    const render = () => {
        const totalLines = 2 + choices.length + 1;
        stdout.write(`\x1b[${totalLines}A`);

        stdout.write(`\n  ${c.bold(message)}\n`);
        for (let i = 0; i < choices.length; i++) {
            const ch = choices[i];
            const mark = i === cursor ? c.cyan('●') : c.gray('○');
            const ptr = i === cursor ? c.cyan('❯') : ' ';
            const hint = ch.hint ? `  ${c.gray(ch.hint)}` : '';
            stdout.write(` ${ptr} ${mark} ${i === cursor ? c.bold(ch.name) : ch.name}${hint}\n`);
        }
        stdout.write(`  ${c.gray('arrows · enter')}`);
    };

    render();

    return new Promise((resolve) => {
        const onKey = (str, key) => {
            if (key.name === 'up') {
                cursor = (cursor - 1 + choices.length) % choices.length;
                render();
            } else if (key.name === 'down') {
                cursor = (cursor + 1) % choices.length;
                render();
            } else if (key.name === 'return' || key.name === 'enter') {
                disableRaw();
                stdin.removeListener('keypress', onKey);
                stdout.write('\n');
                resolve(choices[cursor].value);
            }
        };

        stdin.on('keypress', onKey);
    });
}

// Text input
async function textInput(prompt, defaultValue = '') {
    if (!isTTY) { return defaultValue; }

    const rl = createInterface({ input: stdin, output: stdout });
    return new Promise((resolve) => {
        rl.question(`  ${c.cyan('❯')} ${prompt}${defaultValue ? ` ${c.gray(`[${defaultValue}]`)}` : ''}: `, (answer) => {
            rl.close();
            resolve(answer || defaultValue);
        });
    });
}

// Confirm
async function confirm(prompt, defaultYes = true) {
    if (!isTTY) { return defaultYes; }
    const rl = createInterface({ input: stdin, output: stdout });
    return new Promise((resolve) => {
        const def = defaultYes ? 'Y/n' : 'y/N';
        rl.question(`  ${c.cyan('❯')} ${prompt} (${def}): `, (answer) => {
            rl.close();
            if (!answer) resolve(defaultYes);
            else resolve(answer.toLowerCase() === 'y');
        });
    });
}

// Info/warn messages
function info(msg) { stdout.write(`  ${c.green('✓')} ${msg}\n`); }
function warn(msg) { stdout.write(`  ${c.yellow('⚠')} ${msg}\n`); }
function note(msg) { stdout.write(`  ${c.gray(msg)}\n`); }
function error(msg) { stderr.write(`  ${c.red('✗')} ${msg}\n`); }

// ═══════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════

async function main() {
    banner();

    // ── Step 1: Runtime detection ──────────────────────────────────────
    frame('Runtime',
        `Node ${process.version}`,
        c.cyan('Running on Node.js — cross-platform')
    );

    // ── Step 2: Detect OpenCode ────────────────────────────────────────
    let hasCLI = false;
    let hasDesktop = false;

    // Check CLI
    const cliCheck = spawnSync('opencode', ['--version'], { stdio: 'pipe' });
    if (cliCheck.status === 0) {
        hasCLI = true;
    }

    // Check common desktop paths
    const platform = process.platform;
    // Linux: /opt/OpenCode/
    if (platform === 'linux' && fs.existsSync('/opt/OpenCode/ai.opencode.desktop')) {
        hasDesktop = true;
    }
    // macOS
    if (platform === 'darwin' && fs.existsSync('/Applications/OpenCode.app')) {
        hasDesktop = true;
    }
    // Windows: %LOCALAPPDATA%\Programs\opencode-desktop
    if (platform === 'win32') {
        const localAppData = process.env.LOCALAPPDATA || '';
        if (localAppData && fs.existsSync(path.join(localAppData, 'Programs', 'opencode-desktop'))) {
            hasDesktop = true;
        }
        // Also check Program Files
        if (fs.existsSync(path.join(process.env.ProgramFiles || 'C:\\Program Files', 'OpenCode'))) {
            hasDesktop = true;
        }
    }

    frame('OpenCode',
        hasCLI ? c.green('CLI detected') : c.yellow('CLI not detected'),
        hasDesktop ? c.green('Desktop detected') : c.yellow('Desktop not detected')
    );

    if (!hasCLI && !hasDesktop) {
        error('No OpenCode installation found. Install from https://opencode.ai/download');
        process.exit(1);
    }

    // Target selection
    const targetChoices = [];
    if (hasCLI && hasDesktop) {
        targetChoices.push({ name: 'CLI (terminal)', value: 'cli', hint: '', checked: false });
        targetChoices.push({ name: 'Desktop (GUI)', value: 'desktop', hint: '', checked: false });
        targetChoices.push({ name: 'Both CLI + Desktop', value: 'both', hint: c.green('recommended'), checked: true });
    } else if (hasCLI) {
        targetChoices.push({ name: 'CLI (terminal)', value: 'cli', hint: '', checked: true });
    } else {
        targetChoices.push({ name: 'Desktop (GUI)', value: 'desktop', hint: '', checked: true });
    }

    const targetResult = await select({
        message: 'Install for?',
        choices: targetChoices
    });
    const target = targetResult === 'both' ? 'cli desktop' : targetResult;
    info(`Target: ${target}`);

    // ── Step 3: Download agents ────────────────────────────────────────
    fs.mkdirSync(AGENTS_DIR, { recursive: true });

    const agents = ['research.md', 'deep-research.md', 'verifier.md', 'code.md', 'docs-writer.md'];
    for (const agent of agents) {
        const sp = new Spinner(`Downloading ${agent}`);
        sp.start();
        const ok = await httpsDownload(`${RAW}/agents/${agent}`, path.join(AGENTS_DIR, agent));
        sp.stop(ok);
    }

    // ── Step 4: Config ─────────────────────────────────────────────────
    let configFile = '';
    if (fs.existsSync(path.join(HOME_CONFIG_DIR, 'opencode.jsonc'))) {
        configFile = path.join(HOME_CONFIG_DIR, 'opencode.jsonc');
    } else if (fs.existsSync(path.join(HOME_CONFIG_DIR, 'opencode.json'))) {
        configFile = path.join(HOME_CONFIG_DIR, 'opencode.json');
    }

    if (!configFile) {
        const format = await select({
            message: 'Config format',
            choices: [
                { name: 'opencode.jsonc', value: 'jsonc', hint: c.gray('recommended'), checked: true },
                { name: 'opencode.json', value: 'json', hint: '' },
            ]
        });
        configFile = path.join(HOME_CONFIG_DIR, `opencode.${format}`);
        fs.mkdirSync(HOME_CONFIG_DIR, { recursive: true });
        fs.writeFileSync(configFile, JSON.stringify({
            $schema: 'https://opencode.ai/config.json',
            default_agent: 'research'
        }, null, 2));
        info(`Created ${configFile}`);
    } else {
        note(`Config: ${configFile}`);
    }

    // ── Step 5: MCPs ────────────────────────────────────────────────────
    const mcpResult = await multiselect({
        message: 'MCP Servers (optional)',
        choices: [
            { name: 'searxng', value: 'searxng', hint: c.gray('web search (needs Docker)'), checked: true },
            { name: 'arxiv', value: 'arxiv', hint: c.gray('academic papers'), checked: true },
        ]
    });
    const mcpSelected = mcpResult.join(' ');

    // ── Step 6: Merge MCPs ──────────────────────────────────────────────
    if (mcpResult.length > 0) {
        const sp = new Spinner('Downloading MCP config');
        sp.start();
        const fragmentRaw = await httpsGetText(`${RAW}/opencode.json`);
        sp.stop(!!fragmentRaw);

        if (fragmentRaw) {
            try {
                const fragment = JSON.parse(fragmentRaw);
                const config = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
                if (!config.mcp) config.mcp = {};
                for (const key of mcpResult) {
                    if (fragment.mcp && fragment.mcp[key]) {
                        config.mcp[key] = fragment.mcp[key];
                    }
                }
                if (!config.default_agent) config.default_agent = 'research';
                fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
                info('MCPs merged into config');
            } catch (e) {
                warn(`Could not merge MCPs: ${e.message}`);
            }
        }
    }

    // ── Step 7: Default agent ───────────────────────────────────────────
    const agentResult = await select({
        message: 'Default agent',
        choices: [
            { name: 'research', value: 'research', hint: c.gray('web search & comparisons') },
            { name: 'deep-research', value: 'deep-research', hint: c.gray('exhaustive investigation') },
            { name: 'verifier', value: 'verifier', hint: c.gray('challenge conclusions') },
            { name: 'code', value: 'code', hint: c.gray('code review & writing') },
            { name: 'docs-writer', value: 'docs-writer', hint: c.gray('documentation') },
        ]
    });

    try {
        const config = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
        config.default_agent = agentResult;
        fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
        info(`Default agent: ${agentResult}`);
    } catch (e) {
        warn(`Could not set default agent: ${e.message}`);
    }

    // ── Step 8: Provider ────────────────────────────────────────────────
    const addProvider = await confirm('Add a provider?', false);
    if (addProvider) {
        // Pre-defined providers
        const providerChoice = await select({
            message: 'Select provider',
            choices: [
                { name: 'NaN', value: 'nan', hint: c.gray('nan.builders — free credits included') },
                { name: 'OpenAI', value: 'openai', hint: c.gray('api.openai.com') },
                { name: 'Custom', value: 'custom', hint: c.gray('any OpenAI-compatible API') },
            ]
        });

        let providerId, displayName, baseUrl, apiKey;

        if (providerChoice === 'nan') {
            providerId = 'nan';
            displayName = 'NaN';
            baseUrl = 'https://api.nan.builders/v1';
            info('NaN pre-configured: api.nan.builders/v1');
            apiKey = await textInput('API key (optional, press Enter to skip)', '');

            // Fetch models
            const sp = new Spinner('Fetching models from NaN API');
            sp.start();
            let modelsUrl = `${baseUrl}/models`;
            const modelsData = await httpsGet(modelsUrl);
            sp.stop(!!modelsData);

            if (modelsData && modelsData.data && modelsData.data.length > 0) {
                const modelChoices = modelsData.data.map(m => ({
                    name: m.id,
                    value: m.id,
                    hint: c.gray(m.id.includes('deepseek') ? '1M context, reasoning' : ''),
                    checked: m.id.includes('deepseek') || m.id.includes('flash'),
                }));
                const modelResult = await select({
                    message: 'Default model',
                    choices: modelChoices
                });

                await writeProvider(configFile, providerId, displayName, baseUrl, apiKey, modelResult);
            } else {
                warn('Could not fetch models');
                const modelName = await textInput('Model name', 'deepseek-v4-flash');
                await writeProvider(configFile, providerId, displayName, baseUrl, apiKey, modelName);
            }

        } else if (providerChoice === 'openai') {
            providerId = 'openai';
            displayName = 'OpenAI';
            baseUrl = 'https://api.openai.com/v1';
            apiKey = await textInput('API key', '');
            const modelName = await textInput('Model', 'gpt-4o');
            await writeProvider(configFile, providerId, displayName, baseUrl, apiKey, modelName);

        } else {
            // Custom provider
            providerId = await textInput('Provider ID (e.g. myprovider)', 'myprovider');
            displayName = await textInput('Display name', 'My Provider');
            baseUrl = await textInput('Base URL', 'https://api.example.com/v1');
            apiKey = await textInput('API key (optional)', '');

            // Try to fetch models
            const sp = new Spinner('Fetching models');
            sp.start();
            const modelsData = await httpsGet(`${baseUrl}/models`);
            sp.stop(!!modelsData);

            if (modelsData && modelsData.data && modelsData.data.length > 0) {
                const modelChoices = modelsData.data.map(m => ({
                    name: m.id, value: m.id, checked: false
                }));
                const modelResult = await select({
                    message: 'Default model',
                    choices: modelChoices
                });
                await writeProvider(configFile, providerId, displayName, baseUrl, apiKey, modelResult);
            } else {
                const modelName = await textInput('Model name', 'gpt-4o');
                await writeProvider(configFile, providerId, displayName, baseUrl, apiKey, modelName);
            }
        }
    }

    // ── Step 9: Pre-download MCPs ───────────────────────────────────────
    if (mcpResult.length > 0) {
        for (const mcp of mcpResult) {
            if (mcp === 'searxng') {
                await new Spinner('Pre-downloading one-search-mcp').runShell('bunx -y -p one-search-mcp one-search-mcp --version 2>/dev/null; npx -y -p one-search-mcp one-search-mcp --version 2>/dev/null');
            } else if (mcp === 'arxiv') {
                await new Spinner('Pre-downloading arxiv-mcp-server').runShell('bunx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version 2>/dev/null; npx -y -p @cyanheads/arxiv-mcp-server arxiv-mcp-server --version 2>/dev/null');
            }
        }
    }

    // ── Done ────────────────────────────────────────────────────────────
    stdout.write(`\n  ${c.bold('┌──────────────────────────────────────────┐')}\n`);
    stdout.write(`  ${c.bold('│')}  ${c.green('Installation complete!')}                         ${c.bold('│')}\n`);
    stdout.write(`  ${c.bold('│')}                                            ${c.bold('│')}\n`);
    stdout.write(`  ${c.bold('│')}  Runtime: Node.js ${process.version}\n`);
    stdout.write(`  ${c.bold('│')}  Targets: ${target}\n`);
    stdout.write(`  ${c.bold('│')}  Config:  ${configFile}\n`);
    stdout.write(`  ${c.bold('│')}  MCPs:    ${mcpSelected}\n`);
    stdout.write(`  ${c.bold('│')}  Agent:   ${agentResult}\n`);
    stdout.write(`  ${c.bold('│')}                                            ${c.bold('│')}\n`);
    if (mcpResult.includes('searxng')) {
        stdout.write(`  ${c.bold('│')}  ${c.yellow('→ Start SearXNG:')}                                   ${c.bold('│')}\n`);
        stdout.write(`  ${c.bold('│')}    docker run -d --name searxng -p 8080:8080 searxng/searxng\n`);
    }
    stdout.write(`  ${c.bold('│')}                                            ${c.bold('│')}\n`);
    stdout.write(`  ${c.bold('│')}  Restart OpenCode. Agents appear as tabs.\n`);
    stdout.write(`  ${c.bold('└──────────────────────────────────────────┘')}\n\n`);
}

// ── Helper: write provider to config ──────────────────────────────────
async function writeProvider(configFile, providerId, displayName, baseUrl, apiKey, modelName) {
    try {
        const config = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
        if (!config.provider) config.provider = {};

        config.provider[providerId] = {
            npm: '@ai-sdk/openai-compatible',
            name: displayName,
            options: { baseURL: baseUrl },
            models: {}
        };
        if (apiKey) {
            config.provider[providerId].options.apiKey = apiKey;
        }
        config.provider[providerId].models[modelName] = {
            name: `${displayName} ${modelName}`,
            tool_call: true,
            limit: { context: 128000, output: 65536 }
        };
        config.model = `${providerId}/${modelName}`;
        fs.writeFileSync(configFile, JSON.stringify(config, null, 2));
        info(`Provider '${providerId}' + model '${modelName}'`);
    } catch (e) {
        warn(`Could not write provider: ${e.message}`);
    }
}

main().catch((e) => {
    error(e.message);
    process.exit(1);
});
