window.addEventListener('load', onLoad);
document.addEventListener('reflinks:load', onLoad);
document.addEventListener('reflinks:timeout', onTimeout);

Reflinks.xhrTimeout = 500;

function onLoad() {
  Reflinks.cache();
};

function onTimeout(ev) {
  console.log("timed out... but just keep on");
  // Just keep going
	// document.location.href = ev.data.url;
};
