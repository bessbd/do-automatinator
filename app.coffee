#!/usr/bin/env coffee
require 'coffee-script/register'
path = require 'path'
config = require path.join(process.env[if process.platform == 'win32' then 'USERPROFILE' else 'HOME'], '.doautomator.json')
request = require 'request'
_ = require 'underscore'
async = require 'async'
moment = require 'moment'
fs = require 'fs'

if !String::startsWith
  String::startsWith = (searchString, position) ->
    position = position or 0
    @indexOf(searchString, position) == position

authedv2 = (url) ->
  url = if url.startsWith('https://api.digitalocean.com/v2/') then url else 'https://api.digitalocean.com/v2/' + url
  {url, headers: 'Authorization': "Bearer #{config.token}"}

digitalocean =
  list: (cb) ->
    request authedv2('droplets'), (error, response, body) ->
      # console.log JSON.parse body
      cb error, JSON.parse(body)['droplets']
  listsizes: (cb) ->
    request authedv2('sizes'), (error, response, body) ->
      # console.log JSON.parse body
      cb error, JSON.parse(body)['sizes']
  listsnapshots: (cb) ->
    snlist = []
    crawl = (crawlcb, url = 'images?private=true') -> request authedv2(url), (error, response, body) ->
      parsebod = JSON.parse body
      snlist = snlist.concat (image for image in parsebod['images'] when image['type'] is 'snapshot')
      if nl = parsebod['links']?['pages']?['next']
        crawl crawlcb, nl
      else
        crawlcb error
    crawl (err) ->
      cb err, _.sortBy(snlist, 'created_at')
  dlstatus: (dl, cb) ->
    request authedv2("droplets/#{dl['id']}"), (error, response, body) ->
      status = JSON.parse(body)['droplet']['status']
      console.log "Droplet is #{status}"
      cb error, status
  shutdown: (dl, cb) ->
    async.during(
      (cb) -> setTimeout (-> digitalocean.dlstatus(dl, (err, status) -> cb err, status isnt 'off')), 2000,
      ((cb) ->
        request.post _.extend(
            authedv2("droplets/#{dl['id']}/actions"),
            form: type: 'shutdown'
          ), (error, response, body) ->
            # console.log JSON.parse body
            cb error
      ),
      cb
    )
  poweron: (dl, cb) ->
    if dl['status'] isnt 'off'
      cb null
    else
      request.post _.extend(
          authedv2("droplets/#{dl['id']}/actions"),
          form: type: 'power_on'
        ), (error, response, body) ->
          if (JSON.parse body)['action'] isnt undefined
            console.log "Powering on #{dl['name']}"
            setTimeout (-> digitalocean.poweron dl['name'], cb), 3000
          else
            cb null
  delete: (dlid, cb) ->
    console.log 'Deleting droplet'
    request.del authedv2("droplets/#{dlid}"), (error, response, body) ->
      try
        parsebod = JSON.parse body
        if parsebod['id'] is 'unprocessable_entity'
          setTimeout (-> digitalocean.delete dlid, cb), 2000
        else
          cb error
      catch error
        cb null
  snapshot: (dl, ssname, cb) ->
    request.post _.extend(
        authedv2("droplets/#{dl['id']}/actions"),
        form: {type: 'snapshot', name: ssname}
      ), (error, response, body) ->
        parsebod = JSON.parse body
        if parsebod['id'] is 'unprocessable_entity'
          digitalocean.snapshot dl, ssname, cb
        else
          cb error, parsebod
  save: (dl, ssname, cb) ->
    digitalocean.snapshot dl, ssname, (err, body) ->
      console.log 'Snapshot done'
      digitalocean.delete dl['id'], (err) ->
        console.log 'Delete done'
        cb err

  create: (name, region, size, image, cb) ->
    request.post _.extend(
        authedv2("droplets"),
        formData: {name, region, size, image}
      ), (error, response, body) ->
        cb error, JSON.parse body


actions =
  list: ->
    digitalocean.list (err, lst) ->
      console.log (_.pluck lst, 'name').join '\n'
  shutdown: ->
    digitalocean.list (err, lst) ->
      digitalocean.shutdown _.find(lst, ((droplet) -> droplet['name'] is process.argv[3])), (err) ->
        console.log 'Shutdown done'
  poweron: ->
    digitalocean.list (err, lst) ->
      digitalocean.poweron _.find(lst, ((droplet) -> droplet['name'] is process.argv[3])), (err) ->
        console.log 'Poweron done'
  save: ->
    digitalocean.list (err, lst) ->
      dl = _.find lst, ((droplet) -> droplet['name'] is process.argv[3])
      console.log 'Shutting down'
      digitalocean.shutdown dl, (err) ->
        console.log 'Creating snapshot'
        digitalocean.save dl, dl['name'] + '-' + moment().format('YYYYMMDDHHmmss'), (err) ->
          console.log 'Save done'
  settoken: ->
    fs.writeFile path.join(process.env[if process.platform == 'win32' then 'USERPROFILE' else 'HOME'], '.doautomator.json'),
                           JSON.stringify(token: process.argv[3])
  restore: ->
    async.parallel
      snapshot: (cb) ->
        digitalocean.listsnapshots (err, list) ->
          cb err, list[_.findLastIndex list, (image) -> image['name'].startsWith process.argv[3] + '-']
      sizes: (cb) ->
        digitalocean.listsizes (err, sizes) ->
          cb err, _.sortBy(sizes, 'price_monthly')
      , (err, res) ->
        digitalocean.create process.argv[3],
          res.snapshot['regions'][0],
          _.find(res.sizes, (size) -> size['disk'] >= res.snapshot['min_disk_size'])['slug'],
          res.snapshot['id'],
          (err, ret) ->
            console.log 'Droplet being created, check mails'


if process.argv[2] in Object.keys actions
  actions[process.argv[2]]()
else
  console.log 'Available commands: \n' + Object.keys(actions).join '\n'
