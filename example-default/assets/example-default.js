Reflinks.when('/', function() {
  console.log("fui chamado do root");
});

Reflinks.when('/items', function() {
  Reflinks.cache();
  console.log("fui chamado do items");
});
