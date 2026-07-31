(() => {
  "use strict";

  const LANGS = ["en", "ko", "zh", "ja", "ru", "ar"];

  const LABELS = {
    en: "English",
    ko: "한국어",
    zh: "中文",
    ja: "日本語",
    ru: "Русский язык",
    ar: "العربية"
  };

  const T = {
    en: {
      "TOBMATE Blockchain": "TOBMATE Blockchain",
      "Wallet": "Wallet",
      "Status: Not Created": "Status: Not Created",
      "Bind Wallet": "Bind Wallet",
      "TMID ↔ Wallet: Not Bound": "TMID ↔ Wallet: Not Bound",
      "Register Passkey": "Register Passkey",
      "Create Wallet": "Create Wallet",
      "Connect Existing Wallet": "Connect Existing Wallet",
      "Assets": "Assets",
      "Gold NFT": "Gold NFT",
      "Transaction Security": "Transaction Security",
      "Test Passkey Transaction Approval": "Test Passkey Transaction Approval",
      "Status: Not Authorized": "Status: Not Authorized",
      "Functions": "Functions"
    },

    ko: {
      "TOBMATE Blockchain": "TOBMATE 블록체인",
      "Wallet": "지갑",
      "Status: Not Created": "상태: 생성되지 않음",
      "Bind Wallet": "지갑 연결",
      "TMID ↔ Wallet: Not Bound": "TMID ↔ 지갑: 연결되지 않음",
      "Register Passkey": "패스키 등록",
      "Create Wallet": "지갑 생성",
      "Connect Existing Wallet": "기존 지갑 연결",
      "Assets": "자산",
      "Gold NFT": "금 NFT",
      "Transaction Security": "거래 보안",
      "Test Passkey Transaction Approval": "패스키 거래 승인 테스트",
      "Status: Not Authorized": "상태: 승인되지 않음",
      "Functions": "기능"
    },

    zh: {
      "TOBMATE Blockchain": "TOBMATE 区块链",
      "Wallet": "钱包",
      "Status: Not Created": "状态：尚未创建",
      "Bind Wallet": "绑定钱包",
      "TMID ↔ Wallet: Not Bound": "TMID ↔ 钱包：未绑定",
      "Register Passkey": "注册通行密钥",
      "Create Wallet": "创建钱包",
      "Connect Existing Wallet": "连接现有钱包",
      "Assets": "资产",
      "Gold NFT": "黄金 NFT",
      "Transaction Security": "交易安全",
      "Test Passkey Transaction Approval": "测试通行密钥交易批准",
      "Status: Not Authorized": "状态：未授权",
      "Functions": "功能"
    },
    ja: {
      "TOBMATE Blockchain":"TOBMATE ブロックチェーン",
      "Wallet":"ウォレット",
      "Status: Not Created":"状態：未作成",
      "Bind Wallet":"ウォレット連携",
      "TMID ↔ Wallet: Not Bound":"TMID ↔ ウォレット：未連携",
      "Register Passkey":"パスキー登録",
      "Create Wallet":"ウォレット作成",
      "Connect Existing Wallet":"既存ウォレット接続",
      "Assets":"資産",
      "Gold NFT":"ゴールドNFT",
      "Transaction Security":"取引セキュリティ",
      "Test Passkey Transaction Approval":"パスキー取引承認テスト",
      "Status: Not Authorized":"状態：未承認",
      "Functions":"機能"
    },

    ru: {
      "TOBMATE Blockchain":"Блокчейн TOBMATE",
      "Wallet":"Кошелёк",
      "Status: Not Created":"Статус: Не создан",
      "Bind Wallet":"Привязать кошелёк",
      "TMID ↔ Wallet: Not Bound":"TMID ↔ Кошелёк: не привязан",
      "Register Passkey":"Зарегистрировать Passkey",
      "Create Wallet":"Создать кошелёк",
      "Connect Existing Wallet":"Подключить существующий кошелёк",
      "Assets":"Активы",
      "Gold NFT":"Золотой NFT",
      "Transaction Security":"Безопасность транзакций",
      "Test Passkey Transaction Approval":"Проверка Passkey",
      "Status: Not Authorized":"Статус: Не авторизовано",
      "Functions":"Функции"
    },

    ar: {
      "TOBMATE Blockchain":"بلوكشين TOBMATE",
      "Wallet":"المحفظة",
      "Status: Not Created":"الحالة: لم يتم الإنشاء",
      "Bind Wallet":"ربط المحفظة",
      "TMID ↔ Wallet: Not Bound":"TMID ↔ المحفظة: غير مرتبطة",
      "Register Passkey":"تسجيل مفتاح المرور",
      "Create Wallet":"إنشاء محفظة",
      "Connect Existing Wallet":"ربط محفظة موجودة",
      "Assets":"الأصول",
      "Gold NFT":"رمز الذهب NFT",
      "Transaction Security":"أمان المعاملات",
      "Test Passkey Transaction Approval":"اختبار اعتماد Passkey",
      "Status: Not Authorized":"الحالة: غير مصرح",
      "Functions":"الوظائف"
    }
  };

  let lang =
    new URLSearchParams(location.search).get("lang") ||
    localStorage.getItem("tobmate_language") ||
    "en";

  if (!LANGS.includes(lang)) lang = "en";

  function saveOriginals() {
    document.querySelectorAll(
      "header,h1,h2,h3,h4,p,span,button,a,label,div"
    ).forEach(el => {
      if (el.children.length) return;

      const text = el.textContent.trim();

      if (T.en[text] !== undefined && !el.dataset.i18nOriginal) {
        el.dataset.i18nOriginal = text;
      }
    });
  }

  function translatePage() {
    saveOriginals();

    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";

    document.querySelectorAll("[data-i18n-original]").forEach(el => {
      const original = el.dataset.i18nOriginal;
      el.textContent = T[lang]?.[original] || original;
    });

    const select = document.getElementById("blockchain-language");
    if (select) select.value = lang;
  }

  function installSelector() {
    if (document.getElementById("blockchain-language-box")) return;

    const box = document.createElement("div");
    box.id = "blockchain-language-box";

    const label = document.createElement("label");
    label.textContent = "Language";

    const select = document.createElement("select");
    select.id = "blockchain-language";

    LANGS.forEach(code => {
      const option = document.createElement("option");
      option.value = code;
      option.textContent = LABELS[code];
      select.appendChild(option);
    });

    select.value = lang;

    select.addEventListener("change", () => {
      lang = select.value;
      localStorage.setItem("tobmate_language", lang);

      const url = new URL(location.href);
      url.searchParams.set("lang", lang);
      history.replaceState(null, "", url);

      translatePage();
    });

    box.append(label, select);
    document.body.prepend(box);
  }

  function installStyle() {
    const style = document.createElement("style");

    style.textContent = `
      #blockchain-language-box {
        position: fixed;
        top: 18px;
        right: 22px;
        z-index: 9999;
        display: flex;
        align-items: center;
        gap: 10px;
        color: white;
      }

      #blockchain-language {
        min-width: 150px;
        padding: 9px 12px;
        color: white;
        background: #19324e;
        border: 1px solid #355470;
        border-radius: 8px;
      }

      #blockchain-language option {
        color: black;
        background: white;
      }

      html[dir="rtl"] #blockchain-language-box {
        right: auto;
        left: 22px;
      }
    `;

    document.head.appendChild(style);
  }

  function init() {
    installStyle();
    installSelector();
    translatePage();

    window.TobmateBlockchainI18n = {
      apply: translatePage
    };
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
