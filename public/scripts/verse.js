// Generated by CoffeeScript 1.7.1
(function() {
  jQuery(function($) {
    var channels, commands, greeting, handler, options, socket, term;
    socket = io.connect();
    commands = {
      'help': function() {
        return window.open('/tutorial');
      },
      'command': function() {
        return socket.emit('command');
      },
      'edit': function(args) {
        return socket.emit('edit', args);
      },
      'create': function(args) {
        return socket.emit('create', args);
      }
    };
    channels = {
      'ooc': function(msg) {
        return socket.emit('ooc', msg);
      }
    };
    handler = function(command, term) {
      var parse, _name, _name1;
      parse = $.terminal.parseCommand(command);
      if (!(typeof commands[_name = parse.name] === "function" ? commands[_name](parse.args) : void 0)) {
        if (!(typeof channels[_name1 = parse.name] === "function" ? channels[_name1](parse.rest) : void 0)) {
          term.echo("I'm sorry, I didn't understand the command \"" + parse.name + "\".");
        }
      }
    };
    greeting = '[[b;red;black]Welcome to WinterMUTE, a multi-user text empire.]\n[[;white;black]For the detailed help pages, type "help".\nFor a list of commands, type "command".\nAs we are in development, the database cannot be trusted. Anything created here is drawn in the sand at low tide.\nVersion control is currently OFF. Edits cannot be undone.]\n';
    options = {
      history: true,
      prompt: '> ',
      greetings: greeting,
      processArguments: false,
      outputLimit: -1,
      linksNoReferer: false,
      exit: false,
      clear: false,
      enabled: true,
      onBlur: function(terminal) {
        return false;
      },
      historySize: false,
      height: $('body').height(),
      checkArity: false
    };
    term = $('#console').terminal(handler, options);
    $.getScript('./scripts/palette.js');
    $.getScript('./scripts/events.js');
    $.getScript('./scripts/forms.js');
    $('#console').css({
      "height": $('body').height() + "px"
    });
    return $(window).resize(function() {
      return $('#console').css({
        "height": $('body').height() + "px"
      });
    });
  });

}).call(this);
