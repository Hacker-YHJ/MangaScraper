Iconv = require('iconv').Iconv
request = require 'request'
cheerio = require 'cheerio'
mkdirp = require 'mkdirp'
fs = require 'fs'

class Util
  @mkdir: (path) ->
    handler = (rsv, rej) ->
      mkdirp path, (err) ->
        rej err if err
        rsv()
    new Promise(handler)

  @getRaw: (url) ->
    handler = (rsv, rej) ->
      request.get { url: url, encoding: null }, (error, response, body) ->
        rej error if error
        if response?.statusCode isnt 200
          rej "response: #{response?.statusCode}"
        rsv body
    new Promise(handler)

  @getRawRetry: (url, retry = 5) =>
    p = @getRaw(url)
    i = 0
    while i++ < retry
      p = p.catch => @getRaw(url)
    p

  @reEncode: (buffer, from, to) ->
    iconv = new Iconv(from, to)
    iconv.convert buffer

  @$: (body) -> cheerio.load body

  @writeFile: (path, body) ->
    handler = (rsv, rej) ->
      fs.writeFile path, body, (err) ->
        rej err if err
        rsv()
    new Promise(handler)

  @exists: (path) ->
    handler = (rsv, rej) ->
      fs.stat path, (err, stats) ->
        if !err? then rsv stats.isFile()
        if err?.code is 'ENOENT'
          rsv false
        else
          rej err
    new Promise(handler)

module.exports = Util
