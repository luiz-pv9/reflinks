# Store all user-defined formats
inputFormats = {}

# Registers the specified formatter
Reflinks.format = (name, formatter) ->
  inputFormats[name] = formatter

# Every time a form is submited, the reflinks-format addon
# checks for `data-format` attribute in every input element
# in the form and updates the serialized object with new values.
document.addEventListener(EVENTS.SUBMIT, (ev) ->
  form = ev.detail.target
  data = ev.detail.serialized

  requiresFormatting = form.querySelectorAll('*[data-format]')
  for node in requiresFormatting
    nodeFormatter = node.getAttribute('data-format')
    formatter = inputFormats[nodeFormatter]
    unless formatter
      console.warn("reflinks-format: " + nodeFormatter + " not registered")
      continue
    # Actually updates the serialized form data with the formatter
    data[node.name] = formatter(data[node.name])
)
