mongoose = require 'mongoose'

Char = mongoose.Schema
  name:
  	type: String
  	unique: true
  	required: true
  list:
  	type: String
  	required: true
  look: 
  	type: String
  	required: true
  move:
  	type: String
  	required: true
  appear:
  	type: String
  	required: true

module.exports = mongoose.model 'Char', Char
