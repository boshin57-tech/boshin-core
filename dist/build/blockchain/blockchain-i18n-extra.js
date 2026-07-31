(() => {
  "use strict";

  const TEXT = {
    en: {
      status: "Status: Not Created",
      sui: "SUI",
      goldpeg: "GOLDPEG"
    },
    ko: {
      status: "상태: 생성되지 않음",
      sui: "수이",
      goldpeg: "골드페그"
    },
    zh: {
      status: "状态：尚未创建",
      sui: "苏伊",
      goldpeg: "黄金锚定币"
    },
    ja: {
      status: "状態：未作成",
      sui: "スイ",
      goldpeg: "ゴールドペッグ"
    },
    ru: {
      status: "Статус: не создан",
      sui: "СУИ",
      goldpeg: "ГОЛДПЕГ"
    },
    ar: {
      status: "الحالة: لم يتم الإنشاء",
      sui: "سوي",
      goldpeg: "غولدبيغ"
    }
  };

  const ALL_STATUS = Object.values(TEXT).map(x => x.status);
  const ALL_SUI = Object.values(TEXT).map(x => x.sui);
  const ALL_GOLDPEG = Object.values(TEXT).map(x => x.goldpeg);

  function getLang() {
    const select = document.getElementById("blockchain-language");
    const query = new URLSearchParams(location.search).get("lang");
    const saved = localStorage.getItem("tobmate_language");
    const lang = select?.value || query || saved || "en";
    return TEXT[lang] ? lang : "en";
  }

  function apply() {
    const lang = getLang();

    document.querySelectorAll("h1,h2,h3,h4,p,span,div").forEach(el => {
      if (el.children.length) return;

      const value = el.textContent.trim();

      if (ALL_STATUS.includes(value)) {
        el.textContent = TEXT[lang].status;
      } else if (ALL_SUI.includes(value)) {
        el.textContent = TEXT[lang].sui;
      } else if (ALL_GOLDPEG.includes(value)) {
        el.textContent = TEXT[lang].goldpeg;
      }
    });
  }

  function init() {
    apply();
    setTimeout(apply, 300);
    setTimeout(apply, 1000);

    const select = document.getElementById("blockchain-language");
    if (select) {
      select.addEventListener("change", () => {
        setTimeout(apply, 50);
        setTimeout(apply, 400);
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();

(() => {
  const T = {
    en: ["Language","Send","Receive","Swap","Marketplace","Lending","Staking","Transactions"],
    ko: ["언어","보내기","받기","교환","마켓플레이스","대출","스테이킹","거래 내역"],
    zh: ["语言","发送","接收","兑换","市场","借贷","质押","交易记录"],
    ja: ["言語","送信","受取","交換","マーケットプレイス","レンディング","ステーキング","取引履歴"],
    ru: ["Язык","Отправить","Получить","Обмен","Маркетплейс","Кредитование","Стейкинг","Транзакции"],
    ar: ["اللغة","إرسال","استلام","مبادلة","السوق","الإقراض","التخزين","المعاملات"]
  };

  const KEYS = T.en;

  function getLang() {
    const select = document.getElementById("blockchain-language");
    const query = new URLSearchParams(location.search).get("lang");
    const saved = localStorage.getItem("tobmate_language");
    const lang = select?.value || query || saved || "en";
    return T[lang] ? lang : "en";
  }

  function apply() {
    const lang = getLang();

    document.querySelectorAll("label,button,a,span,div").forEach(el => {
      if (el.children.length) return;

      const text = el.textContent.trim();

      let index = -1;

      for (let i = 0; i < KEYS.length; i++) {
        if (Object.values(T).some(words => words[i] === text)) {
          index = i;
          break;
        }
      }

      if (index >= 0) {
        el.textContent = T[lang][index];
      }
    });
  }

  function init() {
    apply();

    const select = document.getElementById("blockchain-language");
    if (select) {
      select.addEventListener("change", () => setTimeout(apply, 30));
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();

(() => {
  const TEXT = {
    en: "Status: Not Created",
    ko: "상태: 생성되지 않음",
    zh: "状态：尚未创建",
    ja: "状態：未作成",
    ru: "Статус: Не создан",
    ar: "الحالة: لم يتم الإنشاء"
  };

  function applyStatusOnly() {
    const select = document.getElementById("blockchain-language");
    const query = new URLSearchParams(location.search).get("lang");
    const saved = localStorage.getItem("tobmate_language");
    const lang = select?.value || query || saved || "en";
    const target = TEXT[lang] || TEXT.en;

    document.querySelectorAll("p,span,div").forEach(el => {
      if (el.children.length) return;

      const value = el.textContent.trim();

      if (Object.values(TEXT).includes(value)) {
        el.textContent = target;
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", applyStatusOnly, { once: true });
  } else {
    applyStatusOnly();
  }

  const select = document.getElementById("blockchain-language");
  if (select) {
    select.addEventListener("change", () => setTimeout(applyStatusOnly, 30));
  }
})();
