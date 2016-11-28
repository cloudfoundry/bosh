#!/usr/bin/env ruby

def replace_message(commit)
	message = File.read(commit)
	url_string = 'https://www.pivotaltracker.com/story/show/'

	unless message.match(/#{Regexp.escape(url_string)}[0-9]+/)
		File.open(commit, 'w') do |file|
			begin
				file.puts message.sub(/\[#([0-9]+)\]/, "[#\\1](#{url_string}\\1)")
			rescue
				puts "Failed to expand story ID. Committing anyway."
				file.puts message
			end
		end
	end

rescue
	puts "Failed to expand story ID. Committing anyway."
end

replace_message(ARGV[0])
