'use strict';

var gulp   = require('gulp');
var coffee = require('gulp-coffee');
var uglify = require('gulp-uglify');
var gutil  = require('gulp-util');
var rename = require('gulp-rename');

gulp.task('coffee', function coffeee() {
    gulp.src(['reflinks.coffee'])
        .pipe(coffee({bare: false}))
        .on('error', gutil.log)
        .pipe(gulp.dest('./build'));
});

gulp.task('minify', function minify() {
    gulp.src(['build/reflinks.js'])
        .pipe(uglify())
        .pipe(rename('reflinks.min.js'))
        .pipe(gulp.dest('./build'));
});

gulp.task('watch', ['coffee', 'minify'], function() {
    gulp.watch('reflinks.coffee', ['coffee']);
    gulp.watch('build/reflinks.js', ['minify']);
});
