#!/usr/bin/env node
/**
 * Launch cc-wechat browser-based QR login.
 * Uses the browser mode: starts a local HTTP server and opens Chrome
 * with a proper QR code image.
 */
import { loginBrowser } from 'file:///C:/Users/yvan1/AppData/Local/npm-cache/_npx/19953a4e823081bf/node_modules/cc-wechat/dist/auth.js';
import { saveAccount } from 'file:///C:/Users/yvan1/AppData/Local/npm-cache/_npx/19953a4e823081bf/node_modules/cc-wechat/dist/store.js';

console.log('正在启动浏览器登录页面...\n');
try {
  const result = await loginBrowser();
  saveAccount({
    token: result.token,
    baseUrl: result.baseUrl ?? '',
    botId: result.accountId.replace(/@/g, '-').replace(/\./g, '-'),
    savedAt: new Date().toISOString(),
  });
  console.log('\n✅ 登录成功！账号已保存。');
  console.log('Bot ID:', result.accountId);
  console.log('\n启动 Claude Code 时使用:');
  console.log('  claude --dangerously-load-development-channels server:wechat-channel');
} catch (err) {
  console.error('登录失败:', err.message);
  process.exit(1);
}
