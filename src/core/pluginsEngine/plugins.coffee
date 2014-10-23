async = require 'async'
jf = require 'jsonfile'
fs = require 'fs'
colors = require 'colors'
Q = require 'q'
restify = require 'restify'
Url = require 'url'

module.exports = (env) ->
	env.debug 'Initializing plugins engine'
	pluginsEngine = {
		plugin: {}
	}
	pluginsEngine.cwd = process.cwd()
	env.plugins = pluginsEngine.plugin
	env.hooks = {
		'connect.auth': []
		'connect.callback': []
		'connect.backend': []
	}
	env.callhook = -> # (name, ..., callback)
		name = Array.prototype.slice.call(arguments)
		args = name.splice(1)
		name = name[0]
		callback = args.splice(-1)
		callback = callback[0]
		return callback() if not env.hooks[name]
		cmds = []
		args[args.length] = null
		for hook in env.hooks[name]
			do (hook) ->
				cmds.push (cb) ->
					args[args.length - 1] = cb
					hook.apply pluginsEngine.data, args
		async.series cmds, callback

	env.addhook = (name, fn) ->
		env.hooks[name] ?= []
		env.hooks[name].push fn

	
	global_interface = undefined
	pluginsEngine.load = (plugin_name) ->
		
		try 
			plugin_data = require(env.pluginsEngine.cwd + '/plugins/' + plugin_name + '/plugin.json')
		catch e
			env.debug 'Error loading plugin.json (' + plugin_name + ')'
			console.log e.message.yellow
			plugin_data = {
				name: plugin_name
			}

		if plugin_data.main?
			prefix = '/' if plugin_data.main[0] != '/'
			plugin_data.main = prefix + plugin_data.main
		else
			plugin_data.main = '/index'

		if not plugin_data.name? or plugin_data.name != plugin_name
			plugin_data.name = plugin_name
		

		if plugin_data.type != 'global-interface'
			loadPlugin(plugin_data)
		else
			global_interface = plugin_data


	loadPlugin = (plugin_data) ->
		env.debug "Loading " + plugin_data.name.blue
		try
			plugin = require(env.pluginsEngine.cwd + '/plugins/' + plugin_data.name + plugin_data.main)(env)
			pluginsEngine.plugin[plugin_data.name] = plugin
			if not pluginsEngine.plugin[plugin_data.name].config?
				pluginsEngine.plugin[plugin_data.name].config = plugin_data
		catch e
			env.debug "Error while loading plugin " + plugin_data.name
			env.debug e.message.yellow + ' at line ' + e.lineNumber?.red		  

	pluginsEngine.init = (cwd, callback) ->
		env.pluginsEngine.cwd = cwd
		jf.readFile env.pluginsEngine.cwd + '/plugins.json', (err, obj) ->
			if err
				env.debug 'An error occured: ' + err
				return callback true
			if not obj?
				obj = {}
			for pluginname, pluginversion of obj
				stat = fs.statSync cwd + '/plugins/' + pluginname
				if stat.isDirectory()
					pluginsEngine.load pluginname
			if global_interface?
				loadPlugin(global_interface)
			return callback false

	pluginsEngine.list = (callback) ->
		list = []
		jf.readFile env.pluginsEngine.cwd + '/plugins.json', (err, obj) ->
			if err
				env.debug 'An error occured: ' + err
				return callback err
			if obj?
				for key, value of obj
					list.push key
			return callback null, list

	pluginsEngine.run = (name, args, callback) ->
		if typeof args == 'function'	
			callback = args
			args = []
		args.push null
		calls = []
		for k,plugin of pluginsEngine.plugin
			if typeof plugin[name] == 'function'
				do (plugin) ->
					calls.push (cb) ->
						args[args.length-1] = cb
						plugin[name].apply env, args
		async.series calls, ->
			args.pop()
			callback.apply null,arguments
			return
		return

	pluginsEngine.runSync = (name, args) ->
		for k,plugin of pluginsEngine.plugin
			if typeof plugin[name] == 'function'
				plugin[name].apply env, args
		return

	pluginsEngine.loadPluginPages = (server) ->
		defer = Q.defer()
		env.scaffolding.plugins.info.getAllFullInfo()
			.then (plugins) ->
				for k, plugin of plugins

					if plugin.interface_enabled
						do (plugin) ->
							server.get new RegExp("^/plugins/" + plugin.name + "/(.*)"), (req, res, next) ->
								req.params[0] ?= ""
								req.url = req.params[0]
								req._url = Url.parse req.url
								req._path = req._url.pathname

								fs.stat process.cwd() + '/plugins/' + plugin.name + '/public/' + req.params[0], (err, stat) ->

									if stat?.isFile() && req.params[0] != 'index.html'
										next()
										return
									else
										fs.readFile process.cwd() + '/plugins/' + plugin.name + '/public/index.html', {encoding: 'UTF-8'}, (err, data) ->
											if err
												res.send 404
												return
											res.setHeader 'Content-Type', 'text/html'
											data2 = data.replace(/\{\{ plugin_name \}\}/g, plugin.name)
											res.send 200, data2
											return
							, restify.serveStatic
								directory: process.cwd() + '/plugins/' + plugin.name + '/public'
				defer.resolve()
		defer.promise


	pluginsEngine