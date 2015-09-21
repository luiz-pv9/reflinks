unless window.history and window.history.pushState
  console.warn("Reflinks not available in this browser")
  return

# Global reference to the Reflinks object
Reflinks = @Reflinks = {}

# Returns true if the specified suffix is at the end of the of the specified str
strEndsWith = (str, suffix) ->
  str.indexOf(suffix, str.length - suffix.length) isnt -1

# Returns true if the specified element should be kept on the page, and false
# if not. The only usage of this now is the ProgressBar that should always
# be on the page.
shouldKeepOnPage = (elm) ->
  keepElements.indexOf(elm) isnt -1

# Returns the specified url without the protocol prefix (http, https and file
# are checked for)
urlWithoutProtocol = (url) ->
  url.replace('http://', '').replace('https://', '').replace('file://', '')

# Returns the specified url without the hash part
urlWithoutHash = (url) ->
  console.error("TODO")

# Returns true if the specified URL is a hash navigation (focusing an element
# with an ID)
isHashNavigation = (url) ->
  currentUrl = urlWithoutProtocol(document.location.href)
  url = urlWithoutProtocol(url)
  console.log(currentUrl, url)
  url.indexOf('#') is 0

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

# Updates the title of the page that appears in the browser's tab.
updateTitle = (title) ->
  document.title = title

# Showing the progress bar for fast requests makes the application seem
# slower. The 'progressBarDelay' variable specifies the amount of time
# in milliseconds that a request must take before the progress bar is
# displayed.
Reflinks.progressBarDelay = 400

# 4 seconds to identify a request as timed out.
Reflinks.xhrTimeout = 4000

# Elements that will be kept in the page when updating the content.
keepElements = []

# Number of pages to keep in the cache
cacheReferences = {}

# A reference to the cache of the current page.
currentCacheRef = null

EVENTS =
  LOAD: 'reflinks:load'
  BEFORE_REQUEST: 'reflinks:before-request'
  TIMEOUT: 'reflinks:timeout'
  BEFORE_UNLOAD: 'reflinks:before-unload'
  BEFORE_LOAD: 'reflinks:before-load'
  LOAD: 'reflinks:load'
  BEFORE_RELOAD: 'reflinks:before-reload'

# Functions that will execute after a request is completed. This is useful
# for restoring the state of elements that have data-processing attributes.
rollbackAfterLoad = []

# Caches the current page associated with the specified name.
cache = Reflinks.cache = (name = document.location.href, once = false) ->
  currentCacheRef = cacheReferences[name] =
    location: document.location.href
    documentRoot: documentRoot
    once: once

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
  for cache of cacheReferences
    if cacheReferences[cache].location is location or strEndsWith(cacheReferences[cache].location, location)
      return cacheReferences[cache]
  null

# Returns true if the specified page should is cached and false if not.
isLocationCached = (location) ->
  getLocationCache(location) isnt null

# Returns true if the current page should be cached and false if not.
isCurrentPageCached = -> isLocationCached(document.location.href)

# Calls all rollback functions to restore the state of processing elements.
rollbackProcessingElements = ->
  while rollbackAfterLoad.length > 0
    rollbackAfterLoad.pop().call()

# Called after the page is rendered to autofocus any field
maybeAutofocusElement = ->
  autofocusElement = (list = document.querySelectorAll 'input[autofocus], textarea[autofocus]')[list.length - 1]
  if autofocusElement and document.activeElement isnt autofocusElement
    autofocusElement.focus()

document.addEventListener(EVENTS.LOAD, rollbackProcessingElements)
document.addEventListener(EVENTS.LOAD, maybeAutofocusElement)

# The app must have a document root. It defaults to the whole body, but the
# user can change it with the data-reflinks-root attribute. Everything
# outside of the content will be kept on the page.
documentRoot = document.body

# Assigns the document root of the application to the documentRoot variable.
# This function is called when the page finishes loading.
findDocumentRootInPage = ->
  customRoot = document.querySelector('*[data-reflinks-root]')
  documentRoot = customRoot or document.body

# Returns the document root for the specified elements. This function, different
# from findDocumentRootInPage, searches for the document root 
findDocumentRoot = (elements) ->
  for element in elements
    if element.getAttribute('data-reflinks-root')
      return element
    docRoot = element.querySelector('*[data-reflinks-root]')
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
)

# popstate event is called when the user presses the 'back' and 'forward'
# buttons in the browser.
window.addEventListener('popstate', ->
  currentState = window.history.state
  currentUrl = document.location.href
  method = currentState?.method or 'GET'
  if isLocationCached(currentUrl)
    restoreFromCache(method, currentUrl, true)
  else
    asyncRequest(method, currentUrl, null, true)
)

# Intercepts clicks on all links on the page. The element might specify the HTTP
# method throug the data-method attribute.
document.addEventListener('click', (ev) ->
  if ev.target and ev.target.tagName is 'A'
    currentCacheRef?.scroll = currentPageScroll()
    handleAnchorNavigation(ev.target, ev)
)

# Intercepts all form submissions on the page.
document.addEventListener('submit', (ev) ->
  ev.preventDefault()
  form = ev.target
  serialized = {}
  for element in form.elements
    maybeUpdateProcessingFeedback(element)
    serialized[element.name] = element.value
  method = form.attributes['method'].value or 'POST'
  url = form.attributes['action'].value
  currentCacheRef?.scroll = currentPageScroll()
  asyncRequest(method, url, serialized)
)

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
  return if elm.getAttribute 'data-noreflink'
  method = elm.getAttribute('data-method') or 'GET'
  href = elm.href
  if isHashNavigation(href)
    console.log "is hash navigation"
    return true
  triggerEvent EVENTS.BEFORE_REQUEST, {elm, method, href}
  ev.preventDefault()
  maybeUpdateProcessingFeedback(elm)
  if isLocationCached(href)
    # restoreFromCache returns the cache reference or null if nothing was found
    cache = restoreFromCache(method, href)
    # After restoring the cache to improve the user experience a new
    # request is issued to grab the updated version of the page
    if cache
      refreshCurrentPage(method, href, cache) unless cache.once
  else
    asyncRequest(method, href)

# Serializes the specified object to the query string format
serializeToQueryString = (obj) ->
  str = []
  for p of obj
    if obj.hasOwnProperty(p)
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]))
  return str.join "&"

# Performs an AJAX request to the specified url. The request is then handleded
# by onRequestSuccess if it succeeds or by onRequestFailure if it fails.
asyncRequest = (method, url, data, skipPushHistory, ors = onRequestSuccess, orf = onRequestFailure) ->
  Reflinks.xhr?.abort()
  Reflinks.xhr = xhr = new XMLHttpRequest()
  xhr.open(method, url, true)
  xhr.setRequestHeader 'Accept', 'text/html, application/xhtml+xml, application/xml'
  xhr.setRequestHeader 'Content-type', 'application/x-www-form-urlencoded'
  xhr.timeout = Reflinks.xhrTimeout
  xhr.ontimeout = ->
    triggerEvent EVENTS.TIMEOUT, {method, url, data}
  xhr.onerror = ->
    onRequestFailure()
  xhr.onreadystatechange = () ->
    if xhr.readyState is 4
      if xhr.status is 200
        ors(xhr.responseText, url, skipPushHistory)
      else if xhr.status isnt 0
        orf(xhr.responseText, url)
  # I can't think of a reason why not to include cookies.
  xhr.withCredentials = true
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
cacheRootContents = ->
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
  cache = getLocationCache location
  return asyncRequest(method, location) unless cache
  triggerEvent EVENTS.BEFORE_UNLOAD, {method, location}
  restoreCache(cache)
  restorePageScroll(cache.scroll) if cache.scroll
  window.history.pushState({reflinks: true}, "", location) unless skipPushHistory
  cache

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

# Callback called when an AJAX request succeeds.
onRequestSuccess = (content, url, skipPushHistory) ->
  Reflinks.xhr = null
  ProgressBar.done()
  updateTitle(getTitle(content))
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
  window.history.pushState({reflinks: true}, "", url) unless skipPushHistory
  triggerEvent EVENTS.LOAD, {nodes: rootNodes}

# Callback called when an AJAX request to update the current page succeeds.
onRefreshSuccess = (content) ->
  Reflinks.xhr = null
  ProgressBar.done()
  updateTitle(getTitle(content))
  rootNodes = toElements(getBody(content))
  customRootNode = findDocumentRoot(rootNodes)
  rootNodes = customRootNode.childNodes if customRootNode
  triggerEvent EVENTS.BEFORE_RELOAD, {nodes: rootNodes}
  removeRootContents()
  appendRootContents(rootNodes)
  triggerEvent EVENTS.LOAD, {nodes: rootNodes}

# Callback called when an AJAX request fails.
onRequestFailure = (content, href) ->
  Reflinks.xhr = null
  # Just normaly visit the page
  document.location.href = href

# Returns the title of the specified HTML. The HTML should be a string and not
# a DOM element.
getTitle = (html) ->
  matches = /<title>(.*?)<\/title>/.exec(html)
  if matches and matches[1] then matches[1] else ""

# Returns the body of the specified HTML. The HTML should be a string and not
# a DOM element.
getBody = (html) ->
  matches = /<body>([^]*?)<\/body>/.exec(html)
  if matches and matches[1] then matches[1] else ""

# This function returns the scroll offset of the current page
currentPageScroll = ->
  {positionX: window.pageXOffset, positionY: window.pageYOffset}

# Scrolls the current page to the specified offset
restorePageScroll = (offset) ->
  window.scrollTo offset.positionX, offset.positionY
