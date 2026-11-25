/* ============================================================
   config.js —— 云端连接参数
   ------------------------------------------------------------
   现在是空值：应用会以「仅本机」模式运行。
   建档案、编辑、导入导出全部可用，只是不会同步到云端。

   想开启跨设备同步，把下面两项填成你自己云应用的值
   （先按 init.sql 把 vault 表和两个函数建好）：

     endpoint       : 云应用对外域名
                      例：'https://my-pet.app.workbuddy.host'
     publishableKey : 公开可用的发布密钥（可暴露在前端，
                      但别提交到公开仓库）
                      例：'wbpk_xxxxxxxx_yyyyyyyyyyyyyyyyyyyyyyyy'

   oauthRelayBaseUrl 只在需要账号登录时才用，本应用不用登录，
   留空即可。三项都为空 = 仅本机，不会发任何网络请求。
   ============================================================ */
window.PA_CONFIG = {
  endpoint: '',
  oauthRelayBaseUrl: '',
  publishableKey: ''
};
