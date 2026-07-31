(() => {
  const TEXT = {
    en: ["Status:", "Not Created"],
    ko: ["상태:", "생성되지 않음"],
    zh: ["状态：", "尚未创建"],
    ja: ["状態：", "未作成"],
    ru: ["Статус:", "Не создан"],
    ar: ["الحالة:", "لم يتم الإنشاء"]
  };

  function applyStatus() {
    const select = document.getElementById("blockchain-language");
    const query = new URLSearchParams(location.search).get("lang");
    const saved = localStorage.getItem("tobmate_language");
    const lang = TEXT[select?.value] ? select.value :
                 TEXT[query] ? query :
                 TEXT[saved] ? saved : "en";

    document.querySelectorAll("p,div").forEach(parent => {
      const full = parent.textContent.replace(/\s+/g, " ").trim();

      const isWalletStatus = Object.values(TEXT).some(
        ([a, b]) => full === `${a} ${b}`
      );

      if (!isWalletStatus) return;

      const child = parent.querySelector("strong,b,span");

      if (child) {
        child.textContent = TEXT[lang][1];

        for (const node of parent.childNodes) {
          if (node.nodeType === Node.TEXT_NODE && node.textContent.trim()) {
            node.textContent = `${TEXT[lang][0]} `;
            break;
          }
        }
      } else {
        parent.textContent = `${TEXT[lang][0]} ${TEXT[lang][1]}`;
      }
    });
  }

  function init() {
    applyStatus();

    const select = document.getElementById("blockchain-language");
    select?.addEventListener("change", () => setTimeout(applyStatus, 20));
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
