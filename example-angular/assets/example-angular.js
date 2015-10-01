var app = angular.module('reflinks-angular', ['reflinks'])

.config(function(reflinksProvider) {
  reflinksProvider.compileWhen('/home');
});

app.controller('AppController', function AppController() {
});

