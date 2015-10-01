var app = angular.module('reflinks-angular', ['reflinks'])

.config(function(reflinksConfigProvider) {
  console.log(">>>", reflinksConfigProvider);
});

app.controller('AppController', function AppController() {
});

