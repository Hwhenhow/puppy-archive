/* ============================================================
   config.sample.js —— 复制成 config.js 再填自己的值
   ------------------------------------------------------------
   不创建 config.js 也能跑：应用会自动进入「仅本机」模式，
   建档案、编辑、导出全部可用，只是不会同步到云端。

   下面的三项来自你的云应用后台（WorkBuddy 云 / 自建网关同理）：
     endpoint       : 云应用对外域名，例如 https://xxx.app.workbuddy.host
     publishableKey : 公开可用的发布密钥
     oauthRelayBaseUrl : 登录中转；本应用不用登录，保留默认即可

   找不到三项时想先跑起来？直接跳到 README 的「三、只用本机」。
   ============================================================ */
window.PA_CONFIG = {
  endpoint: 'https://YOUR-APP.app.workbuddy.host',
  oauthRelayBaseUrl: 'https://www.workbuddy.cn/v2/as/genie-baas/oauth',
  publishableKey: 'wbpk_XXXXXXXXXXXXXXXX_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
};
