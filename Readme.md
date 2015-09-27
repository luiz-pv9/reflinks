reflinks
========

Reflinks changes the default behaviour of browser's anchor handling and
form submissions in order to provide a more responsive navigation user experience.

Known issues
============

* Assets

All Javascript and CSS files must be present in all pages in the application, generaly
using a build system (gulp, grunt, rails, elixir, etc). Most frameworks works this way
by default.

* Redirects

If a XHR request returns a 302 Redirect the browser seemlesly issues a new request to
the location specified in the header `Location` and the callback

* jQuery

If you're going to use jQuery with Reflinks beware that the `ready` event is only fired
once. You might do something like the following to check for both `ready' and `reflinks:load`
event.

`$(document).on('ready reflinks:load', callback);`

Just make sure you're not doing something like this or you might begin seein events
firing multiple times.

```javascript

// Don't do this
$(document).on('ready reflinks:load', function() {
    $(document).bind('click', callback);
});

```


