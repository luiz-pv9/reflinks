window.addEventListener('load', onLoad);
document.addEventListener('reflinks:load', onLoad);

function onLoad() {
  Reflinks.cache();
};