window.addEventListener('load', onLoad);
document.addEventListener('reflinks:load', onLoad);
document.addEventListener('reflinks:timeout', onTimeout);

Reflinks.logTransitions();
Reflinks.xhrTimeout = 500;

setTimeout(function() {
  Reflinks.visit('/items');
}, 2000);

function onLoad() {
  Reflinks.cache();
};

function onTimeout(ev) {
  console.log("timed out... but just keep on");
};
