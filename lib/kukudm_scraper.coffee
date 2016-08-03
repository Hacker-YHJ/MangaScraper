fs = require 'fs'
path = require 'path'
_ = require './util'

BaseUrl = 'http://www.kukudm.com'
ImgBaseUrl = 'http://n.kukudm.com/'

class KukudmManga
  constructor: (@url) ->
    _.getRawRetry(@url)
    .then (buffer) =>
      @$ = _.$(_.reEncode(buffer, 'GBK', 'UTF-8'))
      @getEpisodes()
    .then (episodes) => @episodes = episodes
    .catch (e) -> throw e

  getEpisodes: =>
    @title = @$('meta[name="keywords"]').attr('content')
    @title = @title.split(',')[0][0...-4]
    episodes = @$('dl#comiclistn dd').map (i, elem) =>
      anchor = @$(elem).find('a').eq(0)
      url = anchor.attr 'href'
      idx = anchor.text()[@title.length..-1].replace(/_/g, ' ').trim()
      new KukudmEpisode(BaseUrl + url, @url, @title, idx)
    Promise.all episodes.get()

  download: =>
    p = Promise.resolve()
    @episodes.forEach (e) ->
      p = p.then e.download
    p.catch (e) -> throw e

class KukudmEpisode
  constructor: (@url, @homeUrl, @title, @idx) ->
    @urlBase = @url[0...-5]
    @total = null
    @idx = @idx || 1
    @getHomeMeta()
    .then @getTotal
    .then @getPages
    .catch (e) -> throw e

  getHomeMeta: =>
    return Promise.resolve() if @homeUrl
    @homeUrl = @url.match(/comiclist\/(\d+)\//)[1]
    @homeUrl = "#{BaseUrl}/comiclist/#{idxUrl}/index.htm"
    _.getRawRetry @homeUrl
    .then (buffer) =>
      $ = _.$ _.reEncode(buffer, 'GBK', 'UTF-8')
      pageTitle = $('head title').text()
      titleArr = pageTitle.split ' '
      if titleArr.length < 2
        titleArr = pageTitle.split '_'
      @title = titleArr[0]
      @idx = @title[@title.length..-1].replace(/_/g, ' ').trim()
    .catch (e) -> throw e

  getTotal: =>
    _.getRawRetry @url
    .then (buffer) =>
      page = _.reEncode buffer, 'GBK', 'UTF-8'
      @total = page.toString().match(/&nbsp; 共(\d+)页 \|/)[1]
      @total = Number @total

  getPages: =>
    @pages = [1..@total].map (page) =>
      pageUrl = "#{@urlBase}#{page}.htm"
      new KukudmPage(pageUrl, @title, @idx, page)

  download: =>
    Promise.all @pages.map((page) -> page.download())

class KukudmPage
  constructor: (@url, @title, @idx, @page) -> @

  getImgUrl: =>
    @imgUrl = @$('script:not(src)').text().split('\r\n')[1]
    @imgUrl = @imgUrl.match(/\+"(.*)'><span/)[1]
    @imgUrl = ImgBaseUrl + @imgUrl

  download: =>
    dirLocation = path.join process.env.HOME, 'Downloads/', @title, @idx
    fileLocation = path.join dirLocation, "#{@page}.jpg"
    _.exists fileLocation
    .then (existed) =>
      if existed then Promise.reject "existed #{@idx}, #{@page}"
    .then -> _.mkdir dirLocation
    .then => _.getRawRetry(@url)
    .then (buffer) =>
      @$ = _.$ _.reEncode(buffer, 'GBK', 'UTF-8')
      @getImgUrl()
    .then =>
      console.log "downloading #{@idx}, #{@page}"
      _.getRawRetry encodeURI(@imgUrl)
    .then (body) =>
      console.log "complete #{@idx}, #{@page}"
      return unless body
      fs.writeFile fileLocation, body
    .catch (e) -> console.log e

module.exports = KukudmManga
