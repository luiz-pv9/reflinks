// The example project is a simple CRUD application that has all elements of
// a website: link navigation, forms and redirects.
var express = require('express');
var app = express();

// This is required to receive data through forms.
var bodyParser = require('body-parser');

// Jade is the template engine for this example project
app.set('view engine', 'jade');

// The templates are located in the views directory
app.set('views', __dirname + '/views');

// The only static file we're serving is the reflinks file.
app.use(express.static(__dirname + '/../build'));
app.use(express.static(__dirname + '/assets'));

// Parsing the body of the request in POST requests
app.use(bodyParser.urlencoded({ extended: false }));

// Counter used to generate unique ids for items.
var latestId = 0;

// All items for the example app. They live in memory and are never persisted.
var items = [];

// Returns the item with the specified id or null if nothing is found.
function findItem(id) {
  for(var i = 0; i < items.length; i++) {
    if(items[i].id == id) {
      return items[i];
    }
  }
  return null;
}

app.get('/', function(req, res) {
  res.render('dashboard');
});

app.get('/home', function(req, res) {
  res.render('home');
});

app.get('/items', function(req, res) {
  res.json(items);
});

app.get('/items/:id', function(req, res) {
  res.json(findItem(req.params.id));
});

app.post('/items', function(req, res) {
  var label = req.body.label;
  var item = {
    id: ++latestId,
    label: label,
    done: false
  };
  items.push(item);
  res.json(item);
});

app.put('/items/:id', function(req, res) {
  var item = findItem(req.params.id);
  item.label = req.body.label;
  item.done = req.body.done;
  res.json(item);
});

app.get('/google', function(req, res) {
  res.status(280);
  res.header('Location', 'https://google.com');
  res.header('Method', 'GET');
  res.end();
});

app.get('/exception', function(req, res) {
  res.status(500).send('Something broke!');
});

app.get('/timeout', function(req, res) {
  setTimeout(function() {
    res.end("Hello timeout");
  }, 6000);
});

app.listen(3000, function() {
  console.log("Server running on localhost:3000");
});
