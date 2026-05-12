// ai-task-obs: auto-generated
// Node.js Web 项目入口薄壳 (main.js shim)。
// 读取 /config/config.toml 配置，初始化 APM/CLS 观测，然后启动上游服务。

'use strict';

const fs = require('fs');
const path = require('path');

function loadConfig() {
  const cfgPath = process.env.APP_CONFIG_PATH || '/config/config.toml';
  if (!fs.existsSync(cfgPath)) {
    return {};
  }
  try {
    const content = fs.readFileSync(cfgPath, 'utf-8');
    // Simple TOML parser for our needs
    const result = {};
    let currentSection = null;
    const lines = content.split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        currentSection = trimmed.slice(1, -1);
        result[currentSection] = {};
      } else if (currentSection && trimmed.includes('=')) {
        const idx = trimmed.indexOf('=');
        const key = trimmed.slice(0, idx).trim();
        let value = trimmed.slice(idx + 1).trim();
        // Remove quotes if present
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.slice(1, -1);
        }
        // Parse booleans and numbers
        if (value === 'true') value = true;
        else if (value === 'false') value = false;
        else if (!isNaN(value) && value !== '') value = Number(value);
        result[currentSection][key] = value;
      }
    }
    return result;
  } catch (e) {
    console.error('Failed to load config:', e.message);
    return {};
  }
}

const cfg = loadConfig();

// >>> ai-task-obs:logging >>>
process.stdout.write('ai-task-obs:beacon kind=logging client_id=0 message_id=272 beacon_id=55a62d2bb49a42bfa83decb3dcc06cf5\n');
// <<< ai-task-obs:logging <<<

// >>> ai-task-obs:apm >>>
// OpenTelemetry APM 接入 - 读取 [apm] 配置
if (cfg.apm && cfg.apm.enabled) {
  let _ai_task_obs_apm_ok = false;
  try {
    const { NodeSDK } = require('@opentelemetry/sdk-node');
    const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
    const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
    const { Resource } = require('@opentelemetry/resources');

    const sdk = new NodeSDK({
      resource: new Resource({
        'service.name': cfg.apm.service_name || 'wewe-rss',
        'deployment.environment': cfg.apm.env || process.env.NODE_ENV || 'production',
        'host.name': process.env.HOST_HOSTNAME || '',
        'container.name': process.env.CONTAINER_NAME || '',
      }),
      traceExporter: new OTLPTraceExporter({
        url: cfg.apm.endpoint || 'grpc://localhost:4317',
        headers: { authentication: cfg.apm.token || '' },
      }),
      instrumentations: [getNodeAutoInstrumentations()],
    });
    sdk.start();
    _ai_task_obs_apm_ok = true;
  } catch (e) {
    console.error('[ai-task-obs] APM init failed (non-fatal):', e.message);
  }
  if (_ai_task_obs_apm_ok) {
    // >>> ai-task-obs:apm-beacon >>>
    process.stdout.write('ai-task-obs:beacon kind=apm client_id=0 message_id=272 beacon_id=55a62d2bb49a42bfa83decb3dcc06cf5\n');
    // <<< ai-task-obs:apm-beacon <<<
  }
}
// <<< ai-task-obs:apm <<<

// >>> ai-task-obs:logging >>>
// JSON 行日志输出 - 让节点 CLS agent 采集
const log = (level, msg, fields) => {
  const entry = {
    ts: new Date().toISOString(),
    level,
    msg,
    host: process.env.HOST_HOSTNAME || '',
    container: process.env.CONTAINER_NAME || '',
    service: 'wewe-rss',
    ...(fields || {}),
  };
  process.stdout.write(JSON.stringify(entry) + '\n');
};

// Override console methods to output JSON logs
const originalConsoleLog = console.log;
const originalConsoleError = console.error;
const originalConsoleWarn = console.warn;
const originalConsoleInfo = console.info;

console.log = (...args) => {
  log('INFO', args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '));
};
console.info = (...args) => {
  log('INFO', args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '));
};
console.warn = (...args) => {
  log('WARN', args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '));
};
console.error = (...args) => {
  log('ERROR', args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' '));
};
// <<< ai-task-obs:logging <<<

// >>> ai-task-obs:entry >>>
// 设置默认端口为 8080（可在配置中覆盖）
if (!process.env.PORT) {
  process.env.PORT = cfg.server?.port || process.env.APP_SERVER_PORT || '8080';
}
// <<< ai-task-obs:entry <<<

// 启动上游 NestJS 服务
// 假设 server dist/main.js 在 apps/server/dist/main
const serverPath = path.join(__dirname, 'apps/server/dist/main.js');
if (fs.existsSync(serverPath)) {
  log('INFO', 'ai-task-obs: starting wewe-rss server', { serverPath });
  require(serverPath);
} else {
  // Fallback: 尝试其他路径
  const altPath = path.join(__dirname, 'dist/main.js');
  if (fs.existsSync(altPath)) {
    log('INFO', 'ai-task-obs: starting wewe-rss server (alt path)', { serverPath: altPath });
    require(altPath);
  } else {
    log('ERROR', 'ai-task-obs: server entry not found', {
      tried: [serverPath, altPath]
    });
    process.exit(1);
  }
}

log('INFO', 'ai-task-obs: entry_shim booted, watching for upstream startup...');
