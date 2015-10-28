unless window.history and window.history.pushState
  console.warn("Reflinks not available in this browser")
  return

# The Url class represents a single URL and provides helper methods to decide
# things such as: does the url have hash? does it has query params? is it
# in the same domain as the current application?
class Url
  constructor: (arg) ->
    if arg instanceof Url
      @storeUrl(arg)
    if typeof arg is 'string'
      @storeAndSplit(arg)
    else if arg and arg.href and arg.pathname # location object
      @storeLocation(arg)

  # Copies all properties from the brother url! :)
  # Called by the constructor.
  storeUrl: (url) ->
    @protocol = url.protocol
    @domain = url.domain
    @hash = url.hash
    @query = url.query
    @path = url.path

  # Splits the specified url to help answer questions about the URL
  storeAndSplit: (url) ->
    @protocol = 'http' if url.indexOf('http://') isnt -1
    @protocol = 'https' if url.indexOf('https://') isnt -1
    url = url.replace(@protocol + '://', '')
    indexOfHash = url.indexOf('#')
    indexOfSlash = if url.indexOf('/') is -1 then url.length else url.indexOf('/')
    indexOfQuestionMark = if url.indexOf('?', indexOfSlash) is -1 then url.length else url.indexOf('?', indexOfSlash)
    endQuery = if indexOfHash is -1 then url.length else indexOfHash
    @domain = url.substring(0, indexOfSlash)
    if indexOfHash isnt -1
      @hash = url.substring(indexOfHash, url.length)
      @path = url.substring(indexOfSlash, Math.min(indexOfHash, indexOfQuestionMark))
    else
      @hash = ''
      @path = url.substring(indexOfSlash, indexOfQuestionMark)
    # Substring works backwards if the first index is greater than the second.
    # The url might have a hash but no @query, resulting in this backwards search.
    # This check prevents it.
    if indexOfQuestionMark < endQuery
      @query = url.substring(indexOfQuestionMark, endQuery)
    else
      @query = ''

  # Stores the instance variables from the specified location object
  storeLocation: (location) ->
    @domain = location.host
    @hash = location.hash
    @path = location.pathname
    @protocol = location.protocol.replace(':', '')
    @query = location.search

  # Returns the full url
  full: -> @fullWithoutHash() + @hash

  # Returns the full url except the hash part
  fullWithoutHash: ->
    url = if @protocol then @protocol else currentLocationUrl.protocol
    url += '://'
    url + @domainOrCurrent() + @path + @query

  # Returns the domain of the URL or the current domain if it is
  # not specified.
  domainOrCurrent: ->
    @domain or currentLocationUrl.domain

  # Adds the specified key=value to the query param of the url
  setQueryParam: (key, value) ->
    if @query.indexOf('?') is 0
      @query += '&' + key + '=' + value
    else
      @query = '?' + key + '=' + value

  # Returns true if this url and the specified one are the same. The URLs
  # are considered the same if protocol, domain, path and query are the same.
  # (Yes, the hash part is ignored.)
  isSame: (url) ->
    return @fullWithoutHash() is url.fullWithoutHash()

  # Returns true if this url and the specified one have the same path (and domain).
  isSamePath: (url) ->
    @isSameDomain(url) and @path is url.path

  # Retunrs true if the current url (!! and not the url in the arguments !!) path
  # placeholders matches the specified url path (and domain).
  matches: (url) ->
    urlParts = url.path?.split('/')
    parts = @path.split('/')
    return false unless urlParts.length is parts.length
    @latestMatchedParams = {}
    for i in [0..parts.length]
      part = parts[i]
      urlPart = urlParts[i]
      unless part is urlPart or part.indexOf(':') is 0
        return false
      if part and part.indexOf(':') is 0
        @latestMatchedParams[part.replace(':', '')] = urlPart
    true

  # Returns true if this url and the specified one are in the same domain 
  isSameDomain: (url) ->
    @domainOrCurrent() is url.domainOrCurrent()

# CSRF token used by many frameworks. This value is passed along all requests.
csrfToken = ''

# Reference to the Reflinks object. Available globaly.
Reflinks = @Reflinks = {}

# Name of the attribute that the CSRF token will be assigned to when sending to
# the server. 'authenticity_token' is the name used by Rails.
Reflinks.csrfTokenAttribute = 'authenticity_token'

# Name of the <meta> tag that contains the csrf token
Reflinks.csrfMetaTagName = 'csrf-token'

# Showing the progress bar for fast requests makes the application seem
# slower. The 'progressBarDelay' variable specifies the amount of time
# in milliseconds that a request must take before the progress bar is
# displayed.
Reflinks.progressBarDelay = 400

# 4 seconds to identify a request as timed out.
Reflinks.xhrTimeout = 4000

# XHR redirects are tricky. This variable specifies a custom status code
# that Reflinks will understand as a redirect.
Reflinks.redirectStatusCode = 280

# Maximum number of pages cached at the same time.
Reflinks.cacheSize = 10

# Elements that will be kept in the page when updating the content.
keepElements = []

# Number of pages to keep in the cache
cacheReferences = {}

# A reference to the cache of the current page.
currentCacheRef = null

# A refenrece to the current location url (Url class instance)
currentLocationUrl = null

# Constants for all events emitted
EVENTS =
  LOAD: 'reflinks:load'
  BEFORE_REQUEST: 'reflinks:before-request'
  TIMEOUT: 'reflinks:timeout'
  BEFORE_UNLOAD: 'reflinks:before-unload'
  BEFORE_LOAD: 'reflinks:before-load'
  BEFORE_RELOAD: 'reflinks:before-reload'
  RESTORE: 'reflinks:restore'
  # The transition event is emitted whenever the page is loaded (for new content)
  # or restored from a cache. It's pretty much the same thing as registering for
  # for LOAD and RESTORE events.
  TRANSITION: 'reflinks:transition'
  CLICK: 'reflinks:click'
  SUBMIT: 'reflinks:submit'
  REDIRECT: 'reflinks:redirect'
  TARGET_LOAD: 'reflinks:target-load'
  STARTED: 'reflinks:started'

# Event aliases that trigger other events in the application.
# The TRANSITION event will be triggered whenever LOAD or RESTORE are
# triggered.
EVENT_ALIASES = {}
EVENT_ALIASES[EVENTS.LOAD] = [EVENTS.TRANSITION]
EVENT_ALIASES[EVENTS.RESTORE] = [EVENTS.TRANSITION]

# Functions that will execute after a request is completed. This is useful
# for restoring the state of elements that have data-processing attributes.
rollbackAfterLoad = []

# Visits the specified url.
Reflinks.visit = (href, method = 'GET', target, elm, forceRefresh) ->
  url = new Url(href).fullWithoutHash()
  if target
    ors = onRequestTargetSuccess.bind(null, target, elm)
  if isLocationCached(url) and !ors
    # restoreFromCache returns the cache reference or null if nothing was found
    cache = restoreFromCache(method, url)
    # After restoring the cache to improve the user experience a new
    # request is issued to grab the updated version of the page
    if cache
      if forceRefresh or not cache.once
        refreshCurrentPage(method, url, cache)
  else
    asyncRequest(method, href, undefined, undefined, ors)

# Stores in the cache the latest n visited pages in the website.
Reflinks.cacheLatest = (config = {except: []}, once = false) ->
  # Caches the current page when it finishes loading
  maybeCache = ->
    for url in config.except
      url = new Url(url)
      return 'ignore this..' if url.isSame(currentLocationUrl)
    Reflinks.cache(undefined, once)

  window.addEventListener('load', maybeCache)
  # Cache every other page when the page loads
  document.addEventListener(EVENTS.LOAD, maybeCache)

# Stores in the cache the latest n visited pages in the website caching once (the pages
# are not updated after visiting).
Reflinks.cacheLatestOnce = (config) -> Reflinks.cacheLatest(config, true)

# Store all navigation callbacks specified by the user using the 'Reflinks.when'
# method.
navigationCallbacks = []

# Iterates through the navigationCallbacks array and tries to match the specified
# url. Returns the found navigationCallback object or undefined if nothing is found.
findNavigationCallback = (url) ->
  url = new Url(url)
  for nc in navigationCallbacks
    return nc if nc.url.matches(url)

# Tries to find the navigationCallback for the specified url and returns it.
# If nothing is found a new object is created and inserted in the navigationCallbacks
# array.
findOrCreateNavigationCallback = (url) ->
  url = new Url(url)
  navigationCallback = findNavigationCallback url
  return navigationCallback if navigationCallback
  navigationCallback = {url}
  navigationCallbacks.push(navigationCallback)
  navigationCallback

# This method associates the callback to the specified url. When the
# user navigates to the url the callback is called with the title of
# and document root of the page. This is useful for defining behaviour
# that should only happen on specific pages.
# Important: the callback is only fired if the page is updated through
# an async request. If the page is only restore from cache (back button in
# the browser) the callback will not be fired.
Reflinks.when = (url, callback, config = {}) ->
  nc = findOrCreateNavigationCallback(url)
  nc.callbacks = nc.callbacks or []
  callback._config = config
  nc.callbacks.push(callback)

# Removes the navigation callback for the specified url.
# If no callback is specified (second argument) all callbacks
# are removed.
Reflinks.clearNavigation = (url, callback) ->
  nc = findNavigationCallback(url)
  return 'no navigation callback found' unless nc
  if callback
    nc.callbacks.splice(nc.callbacks.indexOf(callback), 1)
  else
    nc.callbacks = []

# This method is called every time the 'load' event is fired. It tries
# to find callbacks for the specified event and calls them.
callNavigationCallbacks = (ev) ->
  navigationCallback = findNavigationCallback ev.data.url
  if navigationCallback
    for callback in navigationCallback.callbacks
      latestMatchedParams = navigationCallback.url.latestMatchedParams
      callbackConfigPass = true
      for param of callback._config
        unless callback._config[param](latestMatchedParams[param])
          callbackConfigPass = false
          break
      callback({ev, params: latestMatchedParams}) if callbackConfigPass

# Tries to store the current page scroll position in the cache (if it exists)
# This method is called when the event BEFORE_UNLOAD is triggered.
storeCurrentPageScroll = -> currentCacheRef?.scroll = currentPageScroll()

# Registers the navigation callbacks check to the 'reflinks:load' event.
document.addEventListener(EVENTS.LOAD, callNavigationCallbacks)
document.addEventListener(EVENTS.BEFORE_UNLOAD, storeCurrentPageScroll)

# The callbacks should be fired when the page loads the first time.
# The object passed to 'callNavigationCallbacks'
window.addEventListener('load', -> callNavigationCallbacks({data: {url: document.location.href}}))

# Prints to the console everytime a page transitions happens. This is
# only useful for debugging issues.
Reflinks.logTransitions = ->
  document.addEventListener(EVENTS.LOAD, -> console.log("[TRANSITION]", currentLocationUrl.full()))
  document.addEventListener(EVENTS.RESTORE, -> console.log("[TRANSITION]", currentLocationUrl.full()))

# Returns true if the specified suffix is at the end of the of the specified str
strEndsWith = (str, suffix) ->
  str.indexOf(suffix, str.length - suffix.length) isnt -1

# Returns true if the specified element should be kept on the page, and false
# if not. The only usage of this now is the ProgressBar that should always
# be on the page.
shouldKeepOnPage = (elm) ->
  keepElements.indexOf(elm) isnt -1

# Returns true if the specified URL is a hash navigation (focusing an element
# with an ID)
isHashNavigation = (url) ->
  url = new Url(url)
  return url.hash and currentLocationUrl.isSame(url)

# Converts the specified html string to DOM elements. An array is always
# returned even if the specified string describes a single element.
toElements = (htmlString) ->
  div = document.createElement 'div'
  div.innerHTML = htmlString
  div.childNodes

# Emits the specified event to the document variable
triggerEvent = (eventName, data) ->
  event = document.createEvent 'Events'
  event.data = data if data
  event.initEvent eventName, true, true
  document.dispatchEvent event
  aliases = EVENT_ALIASES[eventName]
  if aliases
    triggerEvent(eventName, data) for eventName in aliases
  return event

# Updates the title of the page that appears in the browser's tab.
updateTitle = (title) ->
  document.title = title

# Caches the specified target inside the currentCacheRef object. This cache will be
# used when popstate is fired.
cacheTarget = (target) ->

# Caches the current page associated with the specified name.
cache = Reflinks.cache = (name = new Url(document.location), once = false) ->
  key = if typeof name is 'string' then name else name.fullWithoutHash()
  location = new Url(document.location)
  previousCache = getLocationCache(location.fullWithoutHash())
  if previousCache
    # If there was already a cache, just update currentCacheRef
    # and make sure documentRoot points to the correct DOM element.
    currentCacheRef = previousCache
    currentCacheRef.once = if currentCacheRef.once is true then true else once
    currentCacheRef.documentRoot = documentRoot
    currentCacheRef.cachedAt = new Date().getTime()
  else
    currentCacheSize = Object.keys(cacheReferences).length

    # If we're trying to cache something but the cache hits the limit
    # specified by Reflinks.cacheSize, the oldest cache reference must
    # be deleted - otherwise reflinks would only grow in memory usage.
    if Reflinks.cacheSize <= currentCacheSize
      oldest = Number.POSITIVE_INFINITY
      cacheKey = null
      for key, cache of cacheReferences
        if cache.cachedAt < oldest
          oldest = cache.cachedAt
          cacheKey = key
      if cacheKey
        clearCache(cacheKey)

    # Stores the new cache and references it to the currentCacheRef
    # variable.
    currentCacheRef = cacheReferences[key] =
      location: location
      documentRoot: documentRoot
      cachedAt: new Date().getTime()
      once: once
  console.log(cacheReferences)

# Removes the documentRoot of the cache and deletes the entry in the
# cacheRef object searching for the location inside of the cache.
clearLocationCache = Reflinks.clearLocationCache = (url) ->
  _cache = getLocationCache(url)
  if _cache
    _cache.documentRoot.remove()
    for key, __cache of cacheReferences
      if __cache == _cache
        delete cacheReferences[key]
        return

# Removes the documentRoot of the cache and deletes the entry in the
# cacheRef object.
clearCache = Reflinks.clearCache = (key) ->
  cacheRef = cacheReferences[key]
  if cacheRef
    cacheRef.documentRoot.remove()
    delete cacheReferences[key]
    true
  false

# Caches the current page with the 'once' flag to true. The once flag
# indicates to Reflinks if a new request must be made to the server to retreive
# the last updated view.
cacheOnce = Reflinks.cacheOnce = (name) ->
  Reflinks.cache(name, true)

# Returns the cache object for the specified location and null if nothing
# is found. There is a check for strEndsWith because redirects from the server
# only specify the path location and not the full url. The browser only accepts
# redirects from the same origin, so we're safe here.
getLocationCache = (location) ->
  locationUrl = new Url(location)
  for cache of cacheReferences
    if cacheReferences[cache].location.isSame(locationUrl) or strEndsWith(cacheReferences[cache].location.fullWithoutHash(), location)
      return cacheReferences[cache]
  null

# Returns true if the specified page should is cached and false if not.
isLocationCached = (location) ->
  getLocationCache(location) isnt null

# Returns true if the current page should be cached and false if not.
isCurrentPageCached = -> isLocationCached(currentLocationUrl.fullWithoutHash())

# Calls all rollback functions to restore the state of processing elements.
rollbackProcessingElements = ->
  while rollbackAfterLoad.length > 0
    rollbackAfterLoad.pop().call()

# Called after the page is rendered to autofocus any field
maybeAutofocusElement = ->
  autofocusElement = (list = document.querySelectorAll 'input[autofocus], textarea[autofocus]')[list.length - 1]
  if autofocusElement and document.activeElement isnt autofocusElement
    autofocusElement.focus()

# Stores the current location to the currentLocationUrl variable and updates
# currentCacheRef to (maybe) the cache of the current page.
storeCurrentLocationUrl = ->
  currentLocationUrl = new Url(document.location)
  currentCacheRef = getLocationCache(currentLocationUrl.fullWithoutHash())

# Default events of Reflinks
document.addEventListener(EVENTS.LOAD, rollbackProcessingElements)
document.addEventListener(EVENTS.LOAD, maybeAutofocusElement)
document.addEventListener(EVENTS.TRANSITION, storeCurrentLocationUrl)
storeCurrentLocationUrl()

# The app must have a document root. It defaults to the whole body, but the
# user can change it with the data-reflinks-root attribute. Everything
# outside of the content will be kept on the page.
documentRoot = document.body

# Assigns the document root of the application to the documentRoot variable.
# This function is called when the page finishes loading.
findDocumentRootInPage = ->
  customRoot = document.querySelector('*[data-reflinks-root]')
  documentRoot = customRoot or document.body

# Returns the element that is considered the root. If the target is found, it is returned.
# If no target is found, the document root is returned.
findTargetOrDocumentRoot = (target, elements) ->
  for element in elements
    if element.hasAttribute and element.hasAttribute('data-reflinks-view') and element.getAttribute('data-reflinks-view') is target
      return element
    docRoot = element.querySelector and element.querySelector('*[data-reflinks-view="'+target+'"]')
    return docRoot if docRoot
  return findDocumentRoot(elements)


# Returns the document root for the specified elements. This function, different
# from findDocumentRootInPage, searches for the document root 
findDocumentRoot = (elements) ->
  for element in elements
    if element.hasAttribute and element.hasAttribute('data-reflinks-root')
      return element
    docRoot = element.querySelector and element.querySelector('*[data-reflinks-root]')
    return docRoot if docRoot
  null

# Because reflinks sends requests without reloading the page, traditional
# browser reload is not displayed. To fill this void, an HTML progress bar
# is displayed at the top of page to simulate page loading process.
ProgressBar =
  # Actual element of the progress bar
  elm: toElements('<div style="width: 0%; position: absolute; height: 3px; ' +
    'background-color: red; top: 0; left: 0;"></div>')[0]

  # Sets the bar loading percentage to 0% and starts the animation. The
  # animation won't stop untill 'done' is called.
  start: ->
    if ProgressBar.delayTimeoutId
      clearTimeout(ProgressBar.delayTimeoutId)
      ProgressBar.delayTimeoutId = null
    if ProgressBar.interval
      clearInterval(ProgressBar.interval)
      ProgressBar.interval = null
    ProgressBar.delayTimeoutId = setTimeout(->
      ProgressBar.elm.style.display = 'block'
      ProgressBar.elm.style.width = '1%'
      progress = 0
      ProgressBar.interval = setInterval(() ->
        distance = 100 - progress
        if progress <= 100
          progress += Math.min((Math.floor(Math.random() * 7) + 1), distance)
        ProgressBar.elm.style.width = progress + '%'
      , 100)
    , Reflinks.progressBarDelay)

  # Moves the bar indicator to the specified percentage. The value must be
  # between 0 and 1.
  moveTo: (percentage) ->
    ProgressBar.elm.style.width = percentage + '%'

  # Finishes the animation and hides the progress bar.
  done: ->
    if ProgressBar.delayTimeoutId
      clearTimeout(ProgressBar.delayTimeoutId)
      ProgressBar.delayTimeoutId = null
    if ProgressBar.interval
      clearInterval(ProgressBar.interval)
      ProgressBar.interval = null
    ProgressBar.elm.style.width = '100%'
    setTimeout(->
      ProgressBar.elm.style.display = 'none'
    , 10)

# Appends the progressbar to the page body.
window.addEventListener('load', ->
  findDocumentRootInPage()
  document.body.appendChild ProgressBar.elm
  # The progress bar should never be removed from the body
  keepElements.push ProgressBar.elm

  # Tries to find csrf-token meta attribute
  metas = document.getElementsByTagName 'meta'
  for meta in metas
    if meta.getAttribute('name') == Reflinks.csrfMetaTagName
      csrfToken = meta.getAttribute('content')
      break

  triggerEvent EVENTS.STARTED
)

# popstate event is called when the user presses the 'back' and 'forward'
# buttons in the browser.
window.addEventListener('popstate', (ev) ->
  targetLocation = new Url(ev.target.location)
  return 'just a hash change...' if currentLocationUrl.isSame(targetLocation)
  currentState = window.history.state
  currentUrl = document.location.href
  method = currentState?.method or 'GET'
  if isLocationCached(currentUrl)
    restoreFromCache(method, currentUrl, true)
  else
    asyncRequest(method, currentUrl, null, true)
)

# This method is called by the 'click' event on the page to maybe
# identify an anchor tag.
maybeAnchorParent = (elm) ->
  while elm.parentNode
    return elm.parentNode if elm.parentNode.tagName is 'A'
    elm = elm.parentNode
  null

# Intercepts clicks on all links on the page. The element might specify the HTTP
# method throug the data-method attribute.
document.addEventListener('click', (ev) ->
  if ev.target and ev.target.tagName is 'A'
    handleAnchorNavigation(ev.target, ev)
  anchorParent = maybeAnchorParent(ev.target)
  if anchorParent
    handleAnchorNavigation(anchorParent, ev)
)

# Intercepts all form submissions on the page.
document.addEventListener('submit', (ev) ->
  return if shouldIgnoreElement(ev.target)
  ev.preventDefault()
  form = ev.target
  serialized = {}
  for element in form.elements
    maybeUpdateProcessingFeedback(element)
    serialized[element.name] = element.value
  method = 'POST'
  if serialized['_method']
    method = serialized['_method']
  if form.hasAttribute('data-reflinks-method')
    method = form.getAttribute('data-reflinks-method')
  url = form.attributes['action'].value
  ev = triggerEvent(EVENTS.SUBMIT, {target: form, url: new Url(url).fullWithoutHash(), method, serialized})
  return 'user stopped...' if ev.defaultPrevented
  currentCacheRef?.scroll = currentPageScroll()
  asyncRequest(method, url, serialized)
)

# Returns true if Reflinks should ignore the element. Reflinks
# ignores elmenets when: 
#  * it specifies 'data-no-reflinks' attribute
#  * any of it's parents specifies 'data-no-reflinks' attribute.
shouldIgnoreElement = (elm) ->
  return true if elm.getAttribute 'data-no-reflinks'
  while elm.parentNode
    return true if elm.getAttribute 'data-no-reflinks'
    elm = elm.parentNode
  false


# Disable the specified element if the attribute 'data-processing-disable'
# is present.
maybeUpdateDisableFeedback = (elm) ->
  if elm.getAttribute 'data-processing-disable'
    elm.disabled = true
    rollbackAfterLoad.push(-> elm.disabled = false)

# Updates the elm content to the same value as data-processing-feedback 
# attribute. This is useful for showing the user a visual feedback (besides the
# progress bar) that the website is doing something. The 'maybe' in the name
# is because the elm might not have a processing-feedback attribute.
maybeUpdateTextFeedback = (elm) ->
  processingFeedback = elm.getAttribute 'data-processing-feedback'
  if processingFeedback
    if elm.tagName == 'INPUT'
      previousValue = elm.value
      elm.value = processingFeedback
      rollbackAfterLoad.push(-> elm.value = previousValue)
    else
      previousValue = elm.innerHTML
      elm.innerHTML = processingFeedback
      rollbackAfterLoad.push(-> elm.innerHTML = previousValue)

# Updates the specified element to show a feedback to the user.
maybeUpdateProcessingFeedback = (elm) ->
  maybeUpdateDisableFeedback(elm)
  maybeUpdateTextFeedback(elm)

# Callback called when the user clicks an anchor element in the page
handleAnchorNavigation = (elm, ev) ->
  return if shouldIgnoreElement(elm)
  method = elm.getAttribute('data-method') or 'GET'
  return 'no href attr' unless elm.getAttribute('href')
  href = elm.href
  return 'hash change, nothing to do here' if isHashNavigation(href)
  ev.preventDefault()
  ev = triggerEvent EVENTS.CLICK, {target: elm, href, method}
  return 'user stoped request' if ev.defaultPrevented
  maybeUpdateProcessingFeedback(elm)
  target = elm.getAttribute('data-reflinks-target')
  Reflinks.visit(href, method, target, elm)

# Serializes the specified object to the query string format
serializeToQueryString = (obj) ->
  str = []
  for p of obj
    if obj.hasOwnProperty(p)
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]))
  return str.join "&"

# Appends the csrf token parameter to the url and returns the modified
# url string.
addcsrfTokenToUrl = (url) ->
  url = new Url(url)
  # adds a possible ?csrf_token=... to the URL.
  if csrfToken and csrfToken isnt ''
    url.setQueryParam(Reflinks.csrfTokenAttribute, csrfToken)
  return url.fullWithoutHash()


# Performs an AJAX request to the specified url. The request is then handleded
# by onRequestSuccess if it succeeds or by onRequestFailure if it fails.
asyncRequest = (method, url, data, skipPushHistory, ors = onRequestSuccess, orf = onRequestFailure, headers = {}) ->
  method = method.toUpperCase()
  Reflinks.xhr?.abort()
  Reflinks.xhr = xhr = new XMLHttpRequest()
  xhr.open(method, url, true)
  xhr.setRequestHeader 'Accept', 'text/html, application/xhtml+xml, application/xml'
  xhr.setRequestHeader 'Content-type', 'application/x-www-form-urlencoded'
  xhr.setRequestHeader 'X-CSRF-TOKEN', csrfToken
  xhr.setRequestHeader 'X-REFLINKS', 'true'
  for header, value of headers
    xhr.setRequestHeader(header, value)
  xhrTimeout = setTimeout(->
    triggerEvent EVENTS.TIMEOUT, {xhr, method, url, data}
  , Reflinks.xhrTimeout)
  xhr.onerror = -> onRequestFailure()
  xhr.onreadystatechange = () ->
    if xhr.readyState is 4
      clearTimeout(xhrTimeout)
      if xhr.status is 200
        ors(xhr.responseText, url, skipPushHistory)
      else if xhr.status is Reflinks.redirectStatusCode
        onRedirectSuccess(xhr)
      else
        orf(xhr.responseText, url)
  # I can't think of a reason why not to include cookies.
  xhr.withCredentials = true
  triggerEvent EVENTS.BEFORE_REQUEST, {method, url, data, xhr}
  if method isnt 'GET' and csrfToken
    data = data or {}
    data[Reflinks.csrfTokenAttribute] = csrfToken
  xhr.send(if data then serializeToQueryString(data) else undefined)
  ProgressBar.start()

# Remove all child elements of the root content in the page that should not
# be kept on the page (such as ProgressBar and navbars).
removeRootContents = () ->
  childNodes = documentRoot.childNodes
  nodesToRemove = []
  for node in childNodes
    nodesToRemove.push(node) unless shouldKeepOnPage(node)
  documentRoot.removeChild node for node in nodesToRemove

# Hides the current documentRoot and creates a new one
cacheRootContents = (cache) ->
  documentRoot.style.display = 'none'

# Appends the specified nodes to the root content of the page.
appendRootContents = (nodes) ->
  for node in nodes
    documentRoot.appendChild(node.cloneNode(true, true))

# This method is called when the previous documentRoot is cached and a new
# one must be created with the specified nodes.
insertRootContents = (nodes) ->
  clonedRoot = documentRoot.cloneNode(false, true)
  clonedRoot.appendChild(node.cloneNode(true, true)) for node in nodes
  clonedRoot.style.display = 'block' # In case the cached node was hidden
  documentRoot.parentNode.appendChild(clonedRoot) # Append the new one
  documentRoot = clonedRoot

# Restores the page for the specified location. If the cache is flagged as
# 'once' a new request isn't made to the server.
restoreFromCache = (method, location, skipPushHistory) ->
  _cache = getLocationCache(location)
  unless _cache
    return asyncRequest(method, location)
  triggerEvent(EVENTS.BEFORE_UNLOAD, {method, location})
  restoreCache(_cache)
  storeCurrentLocationUrl()
  restorePageScroll(_cache.scroll) if _cache.scroll
  window.history.pushState({reflinks: true}, "", location) unless skipPushHistory
  triggerEvent EVENTS.RESTORE, {method, location}
  _cache

# Hides the current documentRoot and shows the element stored in the specified
# cache.
restoreCache = (cache) ->
  documentRoot.style.display = 'none'
  documentRoot = cache.documentRoot
  documentRoot.style.display = 'block'

# Requests an update version of the current page to the server and updates
# the document root with the returned content. This is used when a cached
# page is automatically displayed.
refreshCurrentPage = (method, location, cache) ->
  asyncRequest(method, location, cache.data, true, onRefreshSuccess)

# If the user is requesting a page that already exists in the cache (such as 
# a redirect from the server), the contents of the cache must be updated to
# reflect the new data, instead of creating a new dom element.
# This methods updates the existing cache with the specified rootNodes.
updateCacheAndTransitionTo = (url, rootNodes) ->
  cache = getLocationCache(url)
  if cache
    # Always store the full path to the reference
    cache.location = url if url.length > cache.location.length
    restoreCache(cache)
    removeRootContents()
    appendRootContents(rootNodes)
  else
    cacheRootContents()
    insertRootContents(rootNodes)

# This callback is called when the server sends a redirect to Reflinks.redirectStatusCode
onRedirectSuccess = (xhr) ->
  Reflinks.xhr = null
  desiredLocation = xhr.getResponseHeader('Location')
  desiredMethod = xhr.getResponseHeader('Method') or 'GET'
  return console.error("'Location' header not found") unless desiredLocation
  desiredMethod = xhr.getResponseHeader('Method') or 'GET'
  currentUrl = new Url(document.location)
  desiredUrl = new Url(desiredLocation)
  ev = triggerEvent EVENTS.REDIRECT, {location: desiredLocation, method: desiredMethod, xhr}
  return 'user just prevented...' if ev.defaultPrevented
  if currentUrl.isSameDomain(desiredUrl)
    console.log("Reflinks.visit...", desiredUrl.full())
    Reflinks.visit(desiredUrl.full(), desiredMethod, null, null, true)
  else
    document.location.href = desiredUrl.full()

# This method is called when the response of a request that is intended
# to be inserted in the specified target
onRequestTargetSuccess = (target, elm, content, url) ->
  Reflinks.xhr = null
  ProgressBar.done()
  csrfToken = getCsrfToken(content)
  rootNodes = toElements(getBody(content))
  customRootNode = findTargetOrDocumentRoot(target, rootNodes)
  console.log("customRootNode", customRootNode)
  rootNodes = customRootNode.childNodes if customRootNode
  targetElm = document.getElementById(target)
  return console.warn("couldn't find target with id: " + target) unless targetElm
  while targetElm.firstChild
    targetElm.removeChild(targetElm.firstChild)
  nodesToAdd = []
  for node in rootNodes
    nodesToAdd.push(node)
  targetElm.appendChild(node) for node in nodesToAdd
  triggerEvent EVENTS.TARGET_LOAD, {target, nodes: rootNodes, elm}
  unless elm.hasAttribute('data-reflinks-keep-state')
    cacheTarget(target)
    window.history.pushState({reflinks: true, href: document.location.href, target: target}, "", url)

# Callback called when an AJAX request succeeds.
onRequestSuccess = (content, url, skipPushHistory) ->
  Reflinks.xhr = null
  ProgressBar.done()
  pageTitle = getTitle(content)
  updateTitle(pageTitle)
  csrfToken = getCsrfToken(content)
  rootNodes = toElements(getBody(content))
  customRootNode = findDocumentRoot(rootNodes)
  rootNodes = customRootNode.childNodes if customRootNode
  triggerEvent EVENTS.BEFORE_LOAD, {nodes: rootNodes}
  if isCurrentPageCached()
    if isLocationCached(url)
      updateCacheAndTransitionTo(url, rootNodes)
    else
      cacheRootContents()
      insertRootContents(rootNodes)
  else
    removeRootContents()
    appendRootContents(rootNodes)
  window.history.pushState({reflinks: true, href: document.location.href}, "", url) unless skipPushHistory
  storeCurrentLocationUrl()
  triggerEvent EVENTS.LOAD, {nodes: rootNodes, url, title: pageTitle}

# Callback called when an AJAX request to update the current page succeeds. The
# currentLocationUrl is already updated when this function runs.
onRefreshSuccess = (content, url) ->
  Reflinks.xhr = null
  ProgressBar.done()
  pageTitle = getTitle(content)
  updateTitle(pageTitle)
  csrfToken = getCsrfToken(content)
  rootNodes = toElements(getBody(content))
  customRootNode = findDocumentRoot(rootNodes)
  rootNodes = customRootNode.childNodes if customRootNode
  triggerEvent EVENTS.BEFORE_RELOAD, {nodes: rootNodes}
  removeRootContents()
  appendRootContents(rootNodes)
  triggerEvent EVENTS.LOAD, {nodes: rootNodes, url, title: pageTitle}

# Callback called when an AJAX request fails.
onRequestFailure = (content, href) ->
  Reflinks.xhr = null
  # Just normaly visit the page
  console.log(content)
  document.location.href = href

# Returns the title of the specified HTML. The HTML should be a string and not
# a DOM element.
getTitle = (html) ->
  matches = /<title>(.*?)<\/title>/.exec(html)
  if matches and matches[1] then matches[1] else ""

# Returns the body of the specified HTML. The HTML should be a string and not
# a DOM element.
getBody = (html) ->
  matches = /<body[\s\S]*?>([\s\S]*?)<\/body>/i.exec(html)
  if matches and matches[1] then matches[1] else ""

# escape all special characters for use in regex
escapeRegExp = (str) ->
  str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")

# Returns the content of the csrf meta tag in the HTML body
getCsrfToken = (html) ->
  regexp = new RegExp('<meta[\\s\\S]*?name\\=\\"' + escapeRegExp(Reflinks.csrfMetaTagName) +
    '\\"[\\s\\S]*?content\\=\\"([^\\"]*?)\\"[\\s\\S]*?\\/>')
  matches = regexp.exec(html)
  if matches and matches[1] then matches[1] else ""

# This function returns the scroll offset of the current page
currentPageScroll = ->
  {positionX: window.pageXOffset, positionY: window.pageYOffset}

# Scrolls the current page to the specified offset
restorePageScroll = (offset) ->
  window.scrollTo offset.positionX, offset.positionY

