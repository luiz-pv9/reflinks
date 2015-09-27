'use strict';

var gulp   = require('gulp');
var coffee = require('gulp-coffee');
var uglify = require('gulp-uglify');
var gutil  = require('gulp-util');
var rename = require('gulp-rename');
var concat = require('gulp-concat');

var defaultFiles = ['reflinks.coffee'];

var plugins = {
  'default': {
    files: defaultFiles,
    build: 'reflinks.min.js'
  },
  'angular': {
    files: defaultFiles.concat(['reflinks-angular.coffee']),
    build: 'reflinks-angular.min.js'
  },
  'jquery': {
    files: defaultFiles.concat(['reflinks-jquery.coffee']),
    build: 'reflinks-angular.min.js'
  }
};

Object.keys(plugins).forEach(function(pluginName) {
  var plugin = plugins[pluginName];
  var compiledFile = 'reflinks-' + pluginName + '.js';
  var coffeeTask = 'coffee-' + pluginName;
  var minifyTask = 'minify-' + pluginName;
  gulp.task(coffeeTask, function() {
    return gulp.src(plugin.files)
      .pipe(concat(compiledFile))
      .pipe(coffee({bare: false}))
      .on('error', gutil.log)
      .pipe(gulp.dest('./build'));
  });

  gulp.task(minifyTask, ['coffee-' + pluginName], function() {
    return gulp.src('./build/' + compiledFile)
      .pipe(uglify())
      .pipe(rename(plugin.build))
      .pipe(gulp.dest('./build'));
  });

  gulp.task('watch-' + pluginName, [coffeeTask, minifyTask], function() {
    gulp.watch(plugin.files, [minifyTask]);
  });
});
