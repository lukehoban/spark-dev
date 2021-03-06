SelectListView = require('atom').SelectListView

$ = null
$$ = null
Subscriber = null
SerialHelper = null
SettingsHelper = null
fs = null
path = null

module.exports =
class CompileErrorsView extends SelectListView
  initialize: ->
    super

    {$, $$} = require 'atom'
    {Subscriber} = require 'emissary'

    @subscriber = new Subscriber()
    @subscriber.subscribeToCommand atom.workspaceView, 'core:cancel core:close', => @hide()

    @addClass 'overlay from-top'
    @prop 'id', 'spark-dev-compile-errors-view'

  # Parse gcc errors into array
  @parseErrors: (raw) ->
    path ?= require 'path'

    lines = raw.split "\n"
    errors = []
    for line in lines
      result = line.match /^([^:]+):(\d+):(\d+):\s(\w+\s*\w*):(.*)$/
      if result and result[4].indexOf('error') > -1
        errors.push {
          file: result[1],
          row: result[2],
          col: result[3],
          type: result[4],
          message: result[5]
        }
      else
        result = line.match /^([^:]+):(\d+):\s(.*)$/
        if result
          # This is probably "undefined" error
          errors.push {
            file: path.basename(result[1]),
            row: result[2],
            col: 0,
            type: 'error',
            message: result[3]
          }
    errors

  destroy: ->
    @remove()

  show: =>
    if !@hasParent()
      SettingsHelper ?= require '../utils/settings-helper'

      atom.workspaceView.append(this)

      compileStatus = SettingsHelper.getLocal 'compile-status'
      if compileStatus?.errors
        @setItems compileStatus.errors
      else
        @setLoading 'There were no compile errors'
      @focusFilterEditor()

  hide: ->
    if @hasParent()
      @detach()

  fixInoFile: (filename) ->
    fs ?= require 'fs-plus'
    path ?= require 'path'

    rootPath = atom.project.getPaths()[0]
    files = fs.listTreeSync rootPath
    for file in files
      if file.replace(rootPath + path.sep, '') == filename
        return file.slice(rootPath.length + 1)
    return filename.replace '.cpp', '.ino'

  viewForItem: (item) ->
    self = @
    $$ ->
      @li class: 'two-lines', =>
        @div class: 'primary-line', item.message
        @div class: 'secondary-line', self.fixInoFile(item.file) + ':' + item.row + ':' + item.col

  confirmed: (item) ->
    filename = @fixInoFile item.file

    # Open file with error in editor
    opening = atom.workspaceView.open filename, { searchAllPanes: true }
    opening.done (editor) =>
      editor.setCursorBufferPosition [item.row-1, item.col-1],
    @cancel()

  getFilterKey: ->
    'message'
