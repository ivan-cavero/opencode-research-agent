import { select, multiselect, confirm, text, password, intro, outro, note, isCancel } from '@clack/prompts';
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

// ─── Helpers ──────────────────────────────────────────────

function getJSON(url, headers = {}) {
    return new Promise((resolve) => {
        const opts = { timeout: 8000, headers };
        https.get(url, opts, (res) => {
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

function detectOpenCode() {
    const hasCLI = spawnSync('opencode', ['--version'], { stdio: 'pipe' }).status === 0;
    let hasDesktop = false;
    if (fs.existsSync('/opt/OpenCode/ai.opencode.desktop')) hasDesktop = true;
    if (fs.existsSync('/Applications/OpenCode.app')) hasDesktop = true;
    if (process.platform === 'win32') {
        const ld = process.env.LOCALAPPDATA || '';
        if (fs.existsSync(path.join(ld, 'Programs', 'opencode-desktop'))) hasDesktop = true;
        if (fs.existsSync(path.join(process.env.ProgramFiles || 'C:\\Program Files', 'OpenCode'))) hasDesktop = true;
    }
    return { hasCLI, hasDesktop };
}

// ─── Provider writer ──────────────────────────────────────

function writeProvider(configFile, id, name, url, key, models, defaultModel) {
    const cfg = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
    if (!cfg.provider) cfg.provider = {};

    cfg.provider[id] = {
        npm: '@ai-sdk/openai-compatible',
        name,
        options: { baseURL: url, ...(key ? { apiKey: key } : {}) },
        models,
    };
    cfg.model = `${id}/${defaultModel}`;
    fs.writeFileSync(configFile, JSON.stringify(cfg, null, 2));
}

// ─── Rich model config for NaN ──────────────────────────

function getNaNModelConfig(id) {
    const common = { tool_call: true, reasoning: true };

    if (id === 'deepseek-v4-flash') {
        return { ...common, name: 'NaN deepseek-v4-flash', limit: { context: 1_048_576, output: 65536 } };
    }
    if (id === 'mimo-v2.5') {
        return {
            ...common,
            name: 'NaN mimo-v2.5',
            limit: { context: 1_048_576, output: 65536 },
            modalities: { input: ['text', 'image', 'audio'], output: ['text'] },
        };
    }
    if (id === 'gemma4') {
        return {
            ...common,
            name: 'NaN gemma4',
            limit: { context: 262_144, output: 65536 },
            modalities: { input: ['text', 'image'], output: ['text'] },
        };
    }
    if (id === 'qwen3.6') {
        return {
            ...common,
            name: 'NaN qwen3.6',
            limit: { context: 262_144, output: 65536 },
            modalities: { input: ['text', 'image'], output: ['text'] },
        };
    }

    return { name: `NaN ${id}`, tool_call: true };
}

// ─── Model hints for NaN ─────────────────────────────────

function modelHint(id) {
    if (id.includes('deepseek')) return '284B MoE · 1M ctx · reasoning';
    if (id.includes('mimo')) return '310B MoE · omnimodal (text+vision+audio)';
    if (id.includes('gemma')) return '26B MoE · multimodal · vision';
    if (id.includes('qwen')) return '35B MoE · 256K ctx · multimodal';
    return '';
}

// ─── Main ─────────────────────────────────────────────────

async function main() {
    intro(bold('OpenCode Research Agent Installer'));

    // ── Runtime ───────────────────────────────────────────
    const hasNode = !!(process.versions && process.versions.node);
    const hasBun = typeof Bun !== 'undefined';

    if (!hasNode && !hasBun) {
        outro(red('Node.js or Bun is required'));
        process.exit(1);
    }

    let runtime = hasNode ? 'node' : 'bun';

    if (hasNode && hasBun) {
        runtime = await select({
            message: 'Runtime',
            options: [
                { label: `Bun ${Bun.version}`, value: 'bun', hint: 'faster startup' },
                { label: `Node ${process.version}`, value: 'node', hint: 'stable' },
            ],
        });
        if (isCancel(runtime)) process.exit(0);
    }

    // ── OpenCode detection (silent) ──────────────────────
    const { hasCLI, hasDesktop } = detectOpenCode();

    if (!hasCLI && !hasDesktop) {
        outro(red('No OpenCode installation found — install OpenCode first'));
        process.exit(1);
    }

    // ── Target ────────────────────────────────────────────
    let target = 'both';

    if (!hasCLI) target = 'desktop';
    else if (!hasDesktop) target = 'cli';
    else {
        target = await select({
            message: 'Install for',
            options: [
                { label: 'CLI', value: 'cli' },
                { label: 'Desktop', value: 'desktop' },
                { label: 'Both', value: 'both' },
            ],
            initialValue: 'both',
        });
        if (isCancel(target)) process.exit(0);
    }

    // ── Config file ──────────────────────────────────────
    let configFile = '';

    if (fs.existsSync(path.join(CONFIG_DIR, 'opencode.jsonc'))) {
        configFile = path.join(CONFIG_DIR, 'opencode.jsonc');
    } else if (fs.existsSync(path.join(CONFIG_DIR, 'opencode.json'))) {
        configFile = path.join(CONFIG_DIR, 'opencode.json');
    }

    if (!configFile) {
        const fmt = await select({
            message: 'Config format',
            options: [
                { label: 'opencode.jsonc', value: 'jsonc', hint: 'recommended (supports comments)' },
                { label: 'opencode.json', value: 'json' },
            ],
        });
        if (isCancel(fmt)) process.exit(0);

        configFile = path.join(CONFIG_DIR, `opencode.${fmt}`);
        fs.mkdirSync(CONFIG_DIR, { recursive: true });
        fs.writeFileSync(
            configFile,
            JSON.stringify(
                { $schema: 'https://opencode.ai/config.json', default_agent: 'code' },
                null,
                2,
            ),
        );
    }

    // ── Agents (multiselect, all on) ─────────────────────
    const agents = await multiselect({
        message: 'Agents',
        options: [
            { label: 'research', value: 'research.md', hint: 'web search & comparisons' },
            { label: 'deep-research', value: 'deep-research.md', hint: 'exhaustive multi-round' },
            { label: 'verifier', value: 'verifier.md', hint: 'devil\'s advocate' },
            { label: 'code', value: 'code.md', hint: 'review · refactor · write code' },
            { label: 'docs-writer', value: 'docs-writer.md', hint: 'documentation' },
        ],
        initialValues: ['research.md', 'deep-research.md', 'verifier.md', 'code.md', 'docs-writer.md'],
    });
    if (isCancel(agents)) process.exit(0);

    // Download selected agents
    fs.mkdirSync(AGENTS_DIR, { recursive: true });
    for (const agent of agents) {
        await download(`${RAW}/agents/${agent}`, path.join(AGENTS_DIR, agent));
    }

    // ── MCPs (searxng + arxiv pre-selected) ─────────────
    const mcps = await multiselect({
        message: 'MCP Servers',
        options: [
            { label: 'searxng', value: 'searxng', hint: 'web search — needs Docker' },
            { label: 'arxiv', value: 'arxiv', hint: 'academic papers' },
            { label: 'clickhouse', value: 'clickhouse', hint: 'ClickHouse database queries' },
            { label: 'sentry', value: 'sentry', hint: 'error tracking & issues (needs auth)' },
            { label: 'azure', value: 'azure', hint: 'Azure resources (40+ services)' },
            { label: 'database', value: 'database', hint: 'MySQL · PostgreSQL · SQLite · SQL Server' },
        ],
        initialValues: ['searxng', 'arxiv'],
    });
    if (isCancel(mcps)) process.exit(0);

    // Merge MCP definitions into config
    if (mcps.length > 0) {
        const frag = await getText(`${RAW}/opencode.json`);
        if (frag) {
            try {
                const cfg = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
                const fragment = JSON.parse(frag);
                if (!cfg.mcp) cfg.mcp = {};
                for (const key of mcps) {
                    if (fragment.mcp?.[key]) cfg.mcp[key] = fragment.mcp[key];
                }
                if (!cfg.default_agent) cfg.default_agent = 'code';
                fs.writeFileSync(configFile, JSON.stringify(cfg, null, 2));
            } catch (e) {
                note(yellow(`MCP merge failed: ${e.message}`));
            }
        }
    }

    // ── Default agent ─────────────────────────────────────
    const defaultAgent = await select({
        message: 'Default agent',
        options: [
            { label: 'research', value: 'research', hint: 'web search & comparisons' },
            { label: 'deep-research', value: 'deep-research', hint: 'exhaustive multi-round' },
            { label: 'verifier', value: 'verifier', hint: 'devil\'s advocate' },
            { label: 'code', value: 'code', hint: 'code · refactor · review' },
            { label: 'docs-writer', value: 'docs-writer', hint: 'documentation' },
        ],
        initialValue: 'code',
    });
    if (!isCancel(defaultAgent)) {
        const cfg = JSON.parse(fs.readFileSync(configFile, 'utf-8'));
        cfg.default_agent = defaultAgent;
        fs.writeFileSync(configFile, JSON.stringify(cfg, null, 2));
    }

    // ── Provider ──────────────────────────────────────────
    const addProvider = await confirm({
        message: 'Add a provider?',
        initialValue: true,
    });

    let pid, pmodel;

    if (!isCancel(addProvider) && addProvider) {
        const providerChoice = await select({
            message: 'Provider',
            options: [
                {
                    label: 'NaN',
                    value: 'nan',
                    hint: '70 €/month · unlimited tokens · cloud.nan.builders/r/F6K91G94',
                },
                { label: 'Custom', value: 'custom', hint: 'any OpenAI-compatible API' },
            ],
        });
        if (isCancel(providerChoice)) process.exit(0);

        if (providerChoice === 'nan') {
            pid = 'nan';
            const pname = 'NaN';
            const purl = 'https://api.nan.builders/v1';

            note(gray('Get unlimited tokens → ') + cyan('https://cloud.nan.builders/r/F6K91G94') + gray(' (70 €/month)'));

            const pkey = await password({
                message: 'NaN API key (get one at cloud.nan.builders)',
                mask: '*',
            });
            if (isCancel(pkey)) process.exit(0);

            // Fetch models with auth (NaN requires Bearer token)
            const authHeader = pkey ? { Authorization: `Bearer ${pkey}` } : {};
            const models = await getJSON(`${purl}/models`, authHeader);

            if (models?.data?.length > 0) {
                // Filter to only LLM/chat models (exclude embeddings, tts, etc.)
                const chatModels = models.data.filter((m) =>
                    !m.id.includes('embedding') &&
                    !m.id.includes('rerank') &&
                    !m.id.includes('kokoro') &&
                    !m.id.includes('whisper')
                );

                if (chatModels.length > 0) {
                    const modelOptions = chatModels.map((m) => ({
                        label: m.id,
                        value: m.id,
                        hint: modelHint(m.id),
                    }));

                    pmodel = await select({
                        message: 'Default model',
                        options: modelOptions,
                    });
                } else {
                    pmodel = await text({
                        message: 'Model name',
                        initialValue: 'deepseek-v4-flash',
                    });
                }

                if (!isCancel(pmodel)) {
                    const modelIds = chatModels.length > 0
                        ? chatModels.map((m) => m.id)
                        : [pmodel];

                    // Build rich model configs with reasoning, context, modalities
                    const models = {};
                    for (const mId of modelIds) {
                        models[mId] = getNaNModelConfig(mId);
                    }

                    writeProvider(configFile, pid, pname, purl, pkey, models, pmodel);
                }
            } else {
                // Fallback: couldn't fetch models, use manual input
                note(yellow('Could not fetch model list — enter manually'));

                pmodel = await text({
                    message: 'Model name',
                    initialValue: 'deepseek-v4-flash',
                });

                if (!isCancel(pmodel)) {
                    writeProvider(configFile, pid, pname, purl, pkey, { [pmodel]: getNaNModelConfig(pmodel) }, pmodel);
                }
            }
        } else {
            // Custom provider
            pid = await text({ message: 'Provider ID (e.g. myprovider)', initialValue: 'myprovider' });
            if (isCancel(pid)) process.exit(0);

            const pname = await text({ message: 'Display name', initialValue: 'My Provider' });
            if (isCancel(pname)) process.exit(0);

            const purl = await text({ message: 'Base URL', initialValue: 'https://api.example.com/v1' });
            if (isCancel(purl)) process.exit(0);

            const pkey = await password({ message: 'API key (optional)', mask: '*' });
            if (isCancel(pkey)) process.exit(0);

            const authHeader = pkey ? { Authorization: `Bearer ${pkey}` } : {};
            const models = await getJSON(`${purl}/models`, authHeader);

            if (models?.data?.length > 0) {
                pmodel = await select({
                    message: 'Default model',
                    options: models.data.map((m) => ({ label: m.id, value: m.id })),
                });
            } else {
                pmodel = await text({ message: 'Model name', initialValue: 'gpt-4o' });
            }

            if (!isCancel(pmodel)) {
                const modelIds = models?.data?.length > 0
                    ? models.data.map((m) => m.id)
                    : [pmodel];

                const customModels = {};
                for (const mId of modelIds) {
                    customModels[mId] = { name: `${pname} ${mId}`, tool_call: true };
                }

                writeProvider(configFile, pid, pname, purl, pkey, customModels, pmodel);
            }
        }
    }

    // ── Plugins (TimeFly pre-selected) ────────────────────
    const plugins = await multiselect({
        message: 'Plugins',
        options: [
            { label: 'timefly', value: 'timefly', hint: 'AI-assisted development metrics' },
        ],
        initialValues: ['timefly'],
    });
    if (isCancel(plugins)) process.exit(0);

    if (plugins.includes('timefly')) {
        note('Setting up TimeFly plugin...');
        run('bunx @timefly/opencode-plugin setup-opencode -- --target user 2>/dev/null || npx @timefly/opencode-plugin setup-opencode -- --target user 2>/dev/null');

        // Interactive login — user authenticates in the terminal
        const doLogin = await confirm({ message: 'Log in to TimeFly?', initialValue: true });
        if (doLogin) {
            run('bunx @timefly/opencode-plugin login 2>/dev/null || npx @timefly/opencode-plugin login 2>/dev/null');
        }
    }

    // ── Pre-download MCP packages silently ──────────────
    if (mcps.length > 0) {
        const pkgs = {
            searxng: 'one-search-mcp',
            arxiv: '@cyanheads/arxiv-mcp-server',
            clickhouse: 'clickhouse-mcp-server',
            sentry: '@sentry/mcp-server',
            azure: '@azure/mcp',
            database: '@executeautomation/database-server',
        };
        for (const mcp of mcps) {
            const pkg = pkgs[mcp];
            if (pkg) run(`npm pack ${pkg} 2>/dev/null`);
        }
    }

    // ── Summary ──────────────────────────────────────────
    const summary = [
        `  Runtime:  ${runtime}`,
        `  Target:   ${target}`,
        `  Config:   ${configFile}`,
        `  Agents:   ${agents.length}`,
        `  MCPs:     ${mcps.length ? mcps.join(', ') : 'none'}`,
        `  Default:  ${defaultAgent}`,
        ...(pid && pmodel ? [`  Provider: ${pid} / ${pmodel}`] : []),
    ].join('\n');

    note(summary);

    if (mcps.includes('searxng')) {
        note([
            yellow('SearXNG (needs Docker):'),
            gray('  docker run -d --name searxng -p 8080:8080 searxng/searxng'),
        ].join('\n'));
    }

    outro(bold('Done! Restart OpenCode. Agents appear as tabs.'));
}

main().catch((e) => {
    outro(red(e.message));
    process.exit(1);
});
