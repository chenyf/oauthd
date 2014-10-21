Q = require 'q'
exec = require('child_process').exec
nodegit = require('nodegit')
fs = require 'fs'


module.exports = (env, plugin_name, fetch) ->
	try 
		plugin_data = require process.cwd() + '/plugins/' + plugin_name
	catch e
		return;

	plugin_location = process.cwd() + '/plugins/' + plugin_name
	fetched = false
	execGit = (commands, callback) ->
		full_command = 'cd ' + plugin_location + ';'
		if (fetch && not fetched)
			full_command += ' git fetch;'
			fetched = true
		for k,v of commands
			full_command += ' git ' + v + ';'
		exec full_command , () ->
			callback.apply null, arguments

	git =
		getCurrentVersion: () ->
			defer = Q.defer()
			
			execGit ['branch -v'], (error, stdout, stderr) ->
				return defer.reject error if error
				tag = stdout.match /\* \(detached from (.*)\)/
				tag = tag?[1]

				if not tag
					head = stdout.match /\* ([^\s]*)/
					head = head?[1]

					behind = stdout.match /\*.*\[behind (\d+)\]/
					behind = behind?[1]
				version = {}
				if tag?
					version.version = tag
					if tag.match /(\d+)\.(\d+)\.(\d+)/
						version.type = 'tag_n'
					else
						version.type = 'tag_a'
				else if head?
					version.version = head
					version.type = 'branch'
					if behind?
						version.uptodate = false
					else
						version.uptodate = true
				else
					version.version = 'No version information'
					version.type = 'unversionned'
				defer.resolve(version)
			defer.promise

		getVersionDetail: (version) ->
			version_detail = version.match /(\d+)\.(\d+)\.(\d+)/
			changes = version_detail[3]
			minor = version_detail[2]
			major = version_detail[1]
			
			major: major
			minor: minor
			changes: changes

		compareVersions: (a, b) ->
			if a == b
				return 0
			vd_a = git.getVersionDetail a
			vd_b = git.getVersionDetail b
			if vd_a.major > vd_b.major
				return 1
			else if vd_a.major == vd_b.major
				if vd_a.minor > vd_b.minor
					return 1
				else if vd_a.minor == vd_b.minor
					if vd_a.changes > vd_b.changes
						return 1
					else
						return -1
				else
					return -1
			else
				return -1

		matchVersion: (mask, version) ->
			mask_ = mask.match /(\d+)\.(\d+|x)\.(\d+|x)/
			md = 
				major: mask_[1]
				minor: mask_[2]
				changes: mask_[3]
			vd = git.getVersionDetail(version)
			if vd.major == md.major
				if vd.minor == md.minor || md.minor == 'x'
					if vd.changes ==  md.changes || md.changes == 'x'
						return true
					else
						return false
				else
					return false
			else
				return false


		getAllVersions: (mask) ->
			defer = Q.defer()
			execGit ['tag'], (error, stdout, stderr) ->
				tags = stdout.match /(\d+)\.(\d+)\.(\d+)/g
				matched_tags = []
				if mask
					for k,tag of tags
						if git.matchVersion mask, tag
							matched_tags.push tag
					tags = matched_tags
				tags.sort git.compareVersions
				defer.resolve(tags)
			defer.promise


		getLatestVersion: (mask) ->
			defer = Q.defer()
			git.getAllVersions(mask)
				.then (versions) ->
					latest = versions[versions.length - 1]
					defer.resolve(latest)
			defer.promise

		getVersionMask: () ->
			defer = Q.defer()

			fs.readFile process.cwd() + '/plugins.json', {'encoding': 'UTF-8'}, (err, data) ->
				try
					info = JSON.parse data
					mask = info[plugin_name]?.match(/\#(.*)$/)
					mask = mask?[1]
					defer.resolve(mask)
				catch e
					defer.reject e

			defer.promise

		getRemote: () ->
			defer = Q.defer()
			fs.readFile process.cwd() + '/plugins.json', {'encoding': 'UTF-8'}, (err, data) ->
				try
					info = JSON.parse data
					remote = info[plugin_name]?.match(/^(.*)\#/)
					remote = remote?[1]
					defer.resolve(remote)
				catch e
					defer.reject e
			defer.promise

		pullBranch: (branch) ->
			defer = Q.defer()

			execGit ['pull origin ' + branch], (err, stdout, stderr) ->
				if not err?
					defer.resolve()
				else
					defer.reject()
			defer.promise

		checkout: (version) ->
			defer = Q.defer()
			execGit ['checkout ' + version], (err, stdout, stderr) ->
				if not err?
					defer.resolve()
				else
					defer.reject()
			defer.promise
	git
