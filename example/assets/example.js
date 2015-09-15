window.addEventListener('load', onLoad);
document.addEventListener('after:reflinks:load', onLoad);

function onLoad() {
  Reflinks.cache();
};