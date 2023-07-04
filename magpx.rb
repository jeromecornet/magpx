#!env ruby
# frozen_string_literal: true

require 'optparse'
require './magpx/configuration'
require 'debug'

module MagGPX
  class MagGPX
    attr_accessor :options

    def initialize
      self.options = Configuration.configure
    end

    def run
      if options[:login]
        Configuration.login(options[:username], options[:password])
      elsif ! Configuration.authenticated?
        raise StandardError, "Please login first using -l --username email@example.com --password 'your_password' --mapbox-token 'pk.your_mapbox_token'"
      elsif options[:import_prefix].present?
        import_prefix
      elsif options[:import_gpx].present? && require_mapbox_token
        import_gpx
      else
        raise StandardError, 'Please use -g <gpx file>'
      end
    end

    def import_gpx
      require './magpx/gpx'

      gpx = GPX.mapbox_route(options[:import_gpx])
      import_route(gpx[:legs], trackpoints: gpx[:trackpoints], name: gpx[:name])
    end

    def import_prefix
      legs = Dir.glob(options[:import_prefix] + "-*.json").map do |path|
        File.open(path) do |file|
          JSON.load(file)
        end
      end

      if options[:import_gpx].present?
        require './magpx/gpx'

        import_route(legs, name: GPX.name(options[:import_gpx]), trackpoints: GPX.trackpoints(options[:import_gpx]))
      else
        import_route(legs)
      end
    end

    private

    def import_route(legs, name: "Imported name", trackpoints: [])
      require './magpx/onelapfit'
      data = Onelapfit.convert_mapbox_steps(legs, name: name, trackpoints: trackpoints)

      Onelapfit.save_route(data)
    end

    def require_mapbox_token
      raise StandardError, 'Please specify mapbox_token' if options[:mapbox_token].nil?
      require 'mapbox-sdk'
      Mapbox.access_token = options[:mapbox_token]
    end
  end
end

begin
  MagGPX::MagGPX.new.run
rescue StandardError => e
  $stderr.write(sprintf(e.message + "\n"))
  exit 1
end

