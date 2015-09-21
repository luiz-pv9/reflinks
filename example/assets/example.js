window.addEventListener('load', onLoad);
document.addEventListener('reflinks:load', onLoad);
document.addEventListener('reflinks:timeout', onTimeout);

Reflinks.xhrTimeout = 500;

function onLoad() {
  Reflinks.cache();
};

function onTimeout(ev) {
	document.location.href = ev.data.url;
};
