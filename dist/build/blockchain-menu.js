(function () {
  function addBlockchainMenu() {
    if (document.getElementById('tobmate-blockchain-menu')) return;

    var buttons = Array.from(
      document.querySelectorAll('button.MuiButtonBase-root, button, a.MuiButtonBase-root')
    );

    var clockBtn = buttons.find(function (b) {
      var t = (b.textContent || '').trim();
      var href = b.getAttribute('href') || '';

      return (
        t === '시계' ||
        t === 'TimeClock' ||
        href.indexOf('/time_clock') >= 0
      );
    });

    if (!clockBtn || !clockBtn.parentNode) return;

    var blockchainBtn = clockBtn.cloneNode(true);

    blockchainBtn.id = 'tobmate-blockchain-menu';
    blockchainBtn.removeAttribute('href');

    var label =
      blockchainBtn.querySelector('.MuiButton-label') ||
      blockchainBtn;

    label.textContent = 'Blockchain';

    blockchainBtn.onclick = function (e) {
      e.preventDefault();
      window.location.href = '/blockchain/';
    };

    clockBtn.parentNode.insertBefore(
      blockchainBtn,
      clockBtn.nextSibling
    );
  }

  setInterval(addBlockchainMenu, 1000);
  addBlockchainMenu();
})();
