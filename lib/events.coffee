mongoose = require 'mongoose'
User = require './models/user'
Char = require './models/char'
Zone = require './models/zone'
Room = require './models/room'

module.exports = (app) ->

  clients = []

  generateCode = (done) ->
    code = ('000000' + ( Math.random() * 0xFFFFFF << 0 ).toString( 16 )).slice( -6 )
    Zone
    .findOne code : code
    .exec (err, data) ->
      if err? then console.log err
      else if data? then generateCode done
      else done code

  commands =
    'create' :
      'char'   : (req) -> req.io.emit 'create-char'
      'room'   : (req) -> req.io.emit 'message', "I'm sorry, I cannot create rooms at this time."
      'object' : (req) -> req.io.emit 'message', "I'm sorry, I cannot creat objects at this time."
      'zone'   : (req) -> req.io.emit 'create-zone'

    'edit' :

      'self' : (req) ->
        User
        .findById req.session.passport.user
        .exec (err, user) ->
          if err? then req.io.emit 'error', err
          else
            Char
            .findById user.chars[0]
            .exec (err, char) ->
              if err? then req.io.emit 'error', err
              else
                req.session.editId = user.chars[0]._id ? user.chars[0]
                req.io.emit 'edit-char', char

      'char' : (req) ->
        unless req.data[1]?
          User
          .findById req.session.passport.user
          .populate 'chars'
          .exec (err, user) ->
            if user.chars.length < 2
              req.io.emit 'message', "You don't have any characters to edit."
            else
              charList = ""
              for char, index in user.chars when index > 0
                charList += '    ' + char.name
              req.io.emit 'prompt',
                message : "Which character would you like to edit?\n" + charList
                command : 'edit'
                args    : req.data
        else
          Char
          .findOne name : req.data[1]
          .exec (err, char) ->
            if err? then req.io.emit 'error', err
            else unless char?
              req.io.emit 'message', "Sorry, you can't edit character \"#{req.data[1]}\".\n    TIP: Did you spell it correctly?\n    TIP: If your character's name has a space in it, you must enclose it in quotes."
            else unless char.owner.toString() is req.session.passport.user
              req.io.emit 'message', "Sorry, you don't have permission to edit \"#{req.data[1]}\"."
            else
              req.session.editId = char._id
              req.io.emit 'edit-char', char

      'room' : (req) -> req.io.emit 'message', "Sorry, I can't edit rooms at this time."

      'object' : (req) -> req.io.emit 'message', "Sorry, I can't edit objects at this time."

      'zone' : (req) ->
        unless req.data[1]?
          req.io.emit 'prompt',
            message : "Which zone would you like to edit?"
            command : 'edit'
            args    : req.data
        else
          Zone
          .findOne code : req.data[1]
          .populate 'parent zones rooms'
          .exec (err, zone) ->
            if err? then req.io.emit 'error', err
            else unless zone? then req.io.emit 'message', "Sorry, you cannot edit zone #{req.data[1]}."
            else unless zone.owner.toString() is req.session.passport.user
              req.io.emit 'message', "Sorry, you don't have permission to edit zone #{req.data[1]}."
            else
              req.session.editId = zone._id
              console.log zone
              req.io.emit 'edit-zone', zone

  getClients = (done) ->
    User
    .find()
    .where '_id'
    .in clients
    .populate 'chars'
    .exec (err, users) ->
      if err? then done err, null
      else
        list = []
        for user in users
          list.push( user.chars[0]?.name ? user.email )
        done null, list

  app.io.route 'ready', (req) ->
    clients.push req.session.passport.user
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? then req.io.emit 'error', err
      else unless user.chars[0]?
        req.io.emit 'tutorial'
      else
        req.io.emit 'update', user
        getClients (err, clients) ->
          if err? then req.io.emit 'error', err
          else app.io.broadcast 'who', clients

  app.io.route 'disconnect', (req) ->
    clients.splice(clients.indexOf(req.session.passport?.user), 1);
    getClients (err, clients) ->
      if err? then req.io.emit 'error', err
      else app.io.broadcast 'who', clients

  app.io.route 'command', (req) ->
    req.io.emit 'message', '''

[[;white;black]COMMAND     ARGUMENTS         DESCRIPTION]

command                       List of commands
help                          Launch tutorial page
proto                         Launch prototype help page

who                           Get a list of who is online
ooc                           Post to the OOC channel

create                        Create anything
            char              Create a new character

edit                          Edit anything
            self              Edit your out-of-character self
            char              Edit a character
            char, <name>      Edit the character <name>

status                        Gives your current character, location, and whether or not you are visible
vis                           Become visible
invis                         Become invisible
char                          Switch characters
            self              "Take off" your character
            <name>            Switch to character <name>

look                          Look at the room
            self              Look at your OOC self
            me                Look at your current character
            <name>            Look at character <name> in the room
list                          List the contents of the room

say                           Speak to the room
pose                          Act in the room
spoof                         Act anonymously in the room

'''

  app.io.route 'status', (req) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? then emit 'error', err
      else
        req.io.emit 'message', "Hello, #{user.chars[0].name}."
        if user.currentChar == 0
          req.io.emit 'message', "You do not have a character active."
        else req.io.emit 'message', "You are currently masquerading as #{user.chars[user.currentChar].name}."
        if user.visible
          req.io.emit 'message', "You are visible."
        else req.io.emit 'message', "You are invisible."
        Room
        .findOne code : user.room
        .exec (err2, room) ->
          if err? then emit 'error', err2
          else req.io.emit 'message', "You are in \"#{room.name}\"."

  app.io.route 'who', (req) ->
    getClients (err, users) ->
      msg = "[[;white;black]Online now: ]"
      for user in users
        msg += '\n' + user
      msg += '\n    ' + "[[;gray;black]TIP: If you don't appear in this list, please refesh your window.]"
      req.io.emit 'message', msg

  app.io.route 'vis', (req) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? then req.io.emit 'error', err
      else if user.visible is true
        req.io.emit 'message', "You are already visible."
      else
        user.visible = true
        user.save (err2, user2) ->
          if err? then req.io.emit 'error', err2
          else
            req.io.emit 'update', user2
            char = user2.chars[user2.currentChar]
            req.io.emit 'message', "[[;white;black]You appear #{char.appear}.]"
            req.io.broadcast 'message', "[[;white;black]#{char.name} appears #{char.appear}.]"

  disappear = (req, done) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? then done err
      else if user.visible is false
        req.io.emit 'message', "You are already invisible."
        done null
      else
        user.visible = false
        user.save (err2, user2) ->
          if err? then done err2
          else
            req.io.emit 'update', user2
            char = user2.chars[user2.currentChar]
            req.io.emit 'message', "[[;white;black]You disappear #{char.appear}.]"
            req.io.broadcast 'message', "[[;white;black]#{char.name} disappears #{char.appear}.]"
            done null

  app.io.route 'invis', (req) ->
    disappear req, (err) ->
      if err? then req.io.emit 'error', err

  app.io.route 'char', (req) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      unless req.data[0]?
        list = '    0: ' + user.chars[0].name + ' (self)'
        for char, index in user.chars when index > 0
          list += '    ' + index + ': ' + char.name
        req.io.emit 'prompt',
          message : "Which character would you like to activate? (enter the number)\n" + list
          command : 'char'
          args : req.data
      #else if req.data[0] is 'self' then req.data[0] = 0
      else unless user.chars[req.data[0]]?
        req.io.emit 'message', "Character #{req.data[0]} does not exist."
        req.io.emit 'message', "[[;gray;black]    TIP: Use the character's number. Type \"char\" to get a list."
      else if user.currentChar is req.data[0]
        req.io.emit 'message', "That character is already active."
      else if user.visible is true then disappear req, (dErr) ->
        if dErr? then req.io.emit 'error', dErr
        else
          user.currentChar = req.data[0]
          user.save (err2, user2) ->
            if err2? then req.io.emit 'error', err2
            else
              req.io.emit 'update', user2
              if user.currentChar is 0
                req.io.emit 'message', "You are now out of character."
              else req.io.emit 'message', "You activated character #{user2.chars[user2.currentChar].name}."
      else
        user.currentChar = req.data[0]
        user.save (err2, user2) ->
          if err2? then req.io.emit 'error', err2
          else
            req.io.emit 'update', user2
            if user.currentChar is 0
              req.io.emit 'message', "You are now out of character."
            else req.io.emit 'message', "You activated character #{user2.chars[user2.currentChar].name}."

  app.io.route 'look', (req) ->
    User
    .findById req.session.passport.user
    .exec (err, user) ->
      if err? then req.io.emit 'error', err
      else unless req.data[0]?
        Room
        .findOne code : '000001'
        .exec (err2, room) ->
          if err2? then req.io.emit 'error', err2
          else
            msg = '\n[[b;lime;black]' + room.name + ']\n\n[[;white;black]' + room.look + ']\n'
            User
            .find()
            .where '_id'
            .in clients
            .populate 'chars'
            .exec (err3, users) ->
              if err3? then req.io.emit 'error', err3
              else
                for u in users when u.chars[0]? and u.visible is true
                  c = u.chars[u.currentChar]
                  msg += '\n    [[;darkorchid;black]' + c.name + ', ' + c.list + ', is here.]'
                req.io.emit 'message', msg
      else
        Char
        .findOne name : req.data[0]
        .populate 'owner'
        .exec (err4, char) ->
          if err4? then req.io.emit 'error', err4
          else unless char?
            req.io.emit 'message', "There is no such person."
          else unless char.owner._id.toString() in clients
            req.io.emit 'message', "#{char.name} is nowhere to be seen."
          else if char.owner.visible is false
            req.io.emit 'message', "#{char.name} is nowhere to be seen."
          else char.owner.populate 'chars', (err5, owner) ->
            if err5? then req.io.emit 'error', err5
            else if owner.chars[owner.currentChar].name isnt char.name
              req.io.emit 'message', "#{char.name} is nowhere to be seen."
            else
              msg = '[[b;white;black]' + char.name + ']\n'
              msg += '[[;white;black]' + char.look + ']'
              req.io.emit 'message', msg

  app.io.route 'create', (req) ->
    unless commands['create'][req.data[0]]?(req)
      unless req.data[0]?
        req.io.emit 'prompt',
        message : "What would you like to create?\n    char    room    object    zone"
        command : 'create'
        args : req.data
      else req.io.emit 'message', "I cannot edit \"#{req.data[0]}\"."

  app.io.route 'edit', (req) ->
    unless commands['edit'][req.data[0]]?(req)
      unless req.data[0]?
        req.io.emit 'prompt',
          message : 'What would you like to edit?\n    self    char    room    object'
          command : 'edit'
          args : req.data
      else req.io.emit 'message', "I cannot edit \"#{req.data[0]}\"."

  validateChar = (char, req) ->
    flag = true
    if not char.name? or char.name == ''
      req.io.emit 'message', "The character must have a name."
      flag = false
    if not char.list? or char.list == ''
      req.io.emit 'message', "The character must have a short description (\"list\" command)."
      flag = false
    if not char.look? or char.look == ''
      req.io.emit 'message', "The character must have a long description (\"look\" command)."
      flag = false
    if not char.move? or char.move == ''
      req.io.emit 'message', "The character must have a movement description."
      flag = false
    if not char.appear? or char.appear == ''
      req.io.emit 'message', "The character must have a [dis]appearance description."
      flag = false
    return flag

  createChar = (char, req, done) ->
    Char.create char, (charErr, charData) ->
      if charErr? then done charErr, null
      else User.findById charData.owner, (userErr, userData) ->
        if userErr? then done userErr, null
        else userData.addChar charData._id, (addErr, addData) ->
          if addErr? then done addErr, null
          else addData.populate 'chars', (popErr, popData) ->
            req.io.emit 'update', popData
            done null, charData

  app.io.route 'create-char', (req) ->
    newChar = req.data
    newChar.owner = req.session.passport.user
    if validateChar newChar, req
      createChar newChar, req, (err, data) ->
        if err?
          if err.code == 11000
            req.io.emit 'message', "A character with the name \"#{req.data.name}\" already exists."
          else
            req.io.emit 'error', err
        else req.io.emit 'message', "The character \"#{req.data.name}\" was created!"

  app.io.route 'edit-char', (req) ->
    if validateChar req.data, req
      Char
      .findByIdAndUpdate req.session.editId, $set : req.data
      .exec (err, data) ->
        if err?
          if err.code == 11000
            req.io.emit 'message', "A character with that name already exists."
          else req.io.emit 'error', err
        else
          req.io.emit 'message', "The character \"#{req.data.name}\" was saved!"
          User
          .findById req.session.passport.user
          .populate 'chars'
          .exec (popErr, popData) ->
            if popErr? then req.io.emit 'error', popErr
            else req.io.emit 'update', popData

# THIS IS GOING TO EXPLODE IF THERE ISN'T A PARENT
# I.E. DO NOT USE THIS TO CREATE THE HIDDEN ROOT ZONE
  createZone = (zone, done) ->
    Zone.create zone, (zoneErr, newZone) ->
      if zoneErr? then done zoneErr, null
      else newZone.populate 'parent', (popErr, popZone) ->
        if popErr? then done popErr, null
        else  popZone.parent.addZone newZone._id, (addErr, addZone) ->
          if addErr? then done addErr, null
          else done null, newZone

  app.io.route 'create-zone', (req) ->
    newZone = req.data
    newZone.owner = req.session.passport.user
    if not newZone.parent? or newZone.parent == ''
      newZone.parent = '000000'
    Zone
    .findOne code : newZone.parent
    .exec (err, parent) ->
      if err? then req.io.emit 'error', err
      else unless parent? then req.io.emit 'message', "That super-zone does not exist."
      else
        newZone.parent = parent._id
        generateCode (code) ->
          newZone.code = code
          createZone newZone, (saveErr, saveZone) ->
            if saveErr?
              if saveErr.errors?.name?
                req.io.emit 'message', "The zone must have a name."
              else if saveErr.code == 11000
                req.io.emit 'message', "A zone with that name already exists."
              else req.io.emit 'error', saveErr
            else req.io.emit 'message', "The zone #{req.data.name} was created!"

  app.io.route 'edit-zone', (req) ->
    req.io.emit 'message', "I'm sorry, I cannot edit zones at this time."
    # redo this to work from the zones you are CURRENTLY IN and CAN edit

  app.io.route 'ooc', (req) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? req.io.emit 'error', err
      else app.io.broadcast 'ooc',
        user    : user.chars[0].name
        message : req.data

  app.io.route 'say', (req) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? then req.io.emit 'error', err
      else if user.visible is false
        req.io.emit 'message', "You are invisible."
      else
        req.io.emit 'say',
          user    : null
          message : req.data
        req.io.broadcast 'say',
          user    : user.chars[user.currentChar].name
          message : req.data

  app.io.route 'pose', (req) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? then req.io.emit 'error', err
      else if user.visible is false
        req.io.emit 'message', "You are invisible."
      else app.io.broadcast 'pose',
        user    : user.chars[user.currentChar].name
        message : req.data

  app.io.route 'spoof', (req) ->
    User
    .findById req.session.passport.user
    .populate 'chars'
    .exec (err, user) ->
      if err? then req.io.emit 'error', err
      else if user.visible is false
        req.io.emit 'message', "You are invisible."
      else app.io.broadcast 'spoof',
        user    : user.chars[user.currentChar].name
        message : req.data