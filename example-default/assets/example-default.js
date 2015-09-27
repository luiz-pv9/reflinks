window.addEventListener('load', onLoad);
document.addEventListener('reflinks:load', onLoad);
document.addEventListener('reflinks:timeout', onTimeout);

Reflinks.logTransitions();
Reflinks.xhrTimeout = 500;

Reflinks.when('/items', itemsCallback1);
function itemsCallback1(ev) {
  console.log("First items callback");
};

Reflinks.when('/items', itemsCallback2);
function itemsCallback2(ev) {
  console.log("Second items callback");
};

Reflinks.when('/', function(ev) {
  console.log("home page... clear /items callbacks");
  Reflinks.clearNavigation('/items', itemsCallback1);
});

Reflinks.when('/items/:id', function(nav) {
  console.log("navigation to items/:id");
  console.log(nav.params);
}, {
  'id': function(param) {
    return param === '1';
  }
});

function onLoad() {
  Reflinks.cache();
};

function onTimeout(ev) {
  console.log("timed out... but just keep on");
};
